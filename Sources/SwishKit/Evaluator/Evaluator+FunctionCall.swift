extension Evaluator {

    // MARK: - Function call dispatch

    func evalArgs(_ args: ArraySlice<Expr>, in env: Environment) throws -> [Expr] {
        try args.map { try eval($0, in: env) }
    }

    func selectArity(from arities: [FnArity], argCount: Int, name: String) throws -> FnArity {
        for arity in arities where !arity.params.contains("&") {
            if arity.params.count == argCount { return arity }
        }
        for arity in arities {
            if let ampIdx = arity.params.firstIndex(of: "&"), argCount >= ampIdx {
                return arity
            }
        }
        throw EvaluatorError.noMatchingArity(name: name, got: argCount)
    }

    func callFunction(_ callee: Expr, args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        switch callee {
        case .macro(let name, let params, let body, _):
            return try callMacro(name: name, params: params, body: body, args: args, in: env)

        case .multiArityMacro(let name, let arities, _):
            let chosen = try selectArity(from: arities, argCount: args.count, name: name ?? "macro")
            return try callMacro(name: name, params: chosen.params, body: chosen.body, args: args, in: env)

        case .nativeFunction(let name, let arity, let body):
            return try callNativeFunction(name: name, arity: arity, body: body, args: evalArgs(args, in: env))

        case .function(let f):
            return try callUserFunction(name: f.name, params: f.params, body: f.body,
                                        args: evalArgs(args, in: env), in: f.capturedEnv ?? env,
                                        selfExpr: callee)

        case .multiArityFunction(let maf):
            let evaluated = try evalArgs(args, in: env)
            let chosen = try selectArity(from: maf.arities, argCount: evaluated.count, name: maf.name ?? "fn")
            return try callUserFunction(name: maf.name, params: chosen.params, body: chosen.body,
                                        args: evaluated, in: maf.capturedEnv ?? env,
                                        selfExpr: callee)

        case .map, .sortedMap, .keyword, .vector, .sharedVector, .mapEntry, .set, .sortedSet, .record, .transient, .symbol, .varRef, .promise:
            return try call(callee, args: evalArgs(args, in: env))

        default:
            throw EvaluatorError.notAFunction(callee)
        }
    }

    /// Calls an already-evaluated callee with already-evaluated args. Used by HOFs and meta functions.
    /// Does NOT re-evaluate args — use callFunction for unevaluated args.
    public func call(_ callee: Expr, args: [Expr]) throws -> Expr {
        switch callee {
        case .nativeFunction(let name, let arity, let body):
            return try callNativeFunction(name: name, arity: arity, body: body, args: args)

        case .function(let f):
            return try callUserFunction(name: f.name, params: f.params, body: f.body,
                                        args: args, in: f.capturedEnv ?? Environment(),
                                        selfExpr: callee)

        case .multiArityFunction(let maf):
            let chosen = try selectArity(from: maf.arities, argCount: args.count, name: maf.name ?? "fn")
            return try callUserFunction(name: maf.name, params: chosen.params, body: chosen.body,
                                        args: args, in: maf.capturedEnv ?? Environment(),
                                        selfExpr: callee)

        case .macro(let name, let params, let body, _):
            return try callMacro(name: name, params: params, body: body, args: args[...], in: Environment())

        case .multiArityMacro(let name, let arities, _):
            let chosen = try selectArity(from: arities, argCount: args.count, name: name ?? "macro")
            return try callMacro(name: name, params: chosen.params, body: chosen.body, args: args[...], in: Environment())

        default:
            return try callCollection(callee, args: args)
        }
    }

    private func callMacro(name: String?, params: [String], body: [Expr], args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        let threadState = currentThreadState()
        guard threadState.callDepth < maxCallDepth else {
            throw EvaluatorError.stackOverflow(maxDepth: maxCallDepth)
        }
        threadState.callDepth += 1
        defer { threadState.callDepth -= 1 }
        let expanded = try expandMacro(name: name ?? "macro", params: params, body: body, args: Array(args))
        return try eval(expanded, in: env)
    }

    func callNativeFunction(name: String, arity: Arity, body: @Sendable ([Expr]) throws -> Expr, args: [Expr]) throws -> Expr {
        if case .fixed(let n) = arity, args.count != n {
            throw EvaluatorError.arityMismatch(name: name, expected: arity, got: args.count)
        }
        if case .atLeastOne = arity, args.isEmpty {
            throw EvaluatorError.arityMismatch(name: name, expected: arity, got: 0)
        }
        return try body(args)
    }

    func callUserFunction(name: String?, params: [String], body: [Expr], args: [Expr],
                          in env: Environment, rest: Expr? = nil, selfExpr: Expr? = nil) throws -> Expr {
        let threadState = currentThreadState()
        guard threadState.callDepth < maxCallDepth else {
            throw EvaluatorError.stackOverflow(maxDepth: maxCallDepth)
        }
        threadState.callDepth += 1
        defer { threadState.callDepth -= 1 }
        var currentArgs = args
        var currentRest = rest
        while true {
            if interruptionCheck?() == true { throw EvaluatorError.interrupted }
            let fnEnv = Environment(parent: env)
            try bindParams(params, to: currentArgs, in: fnEnv, name: name ?? "fn",
                           prebuiltRest: currentRest)
            if let fnName = name {
                fnEnv.set(fnName, selfExpr ?? .function(SwishFunction(name: name, params: params,
                                                                      body: body, capturedEnv: env,
                                                                      metadata: nil)))
            }
            do {
                return try evalBody(body, in: fnEnv)
            } catch let signal as RecurSignal {
                currentArgs = signal.args
                currentRest = nil
            }
        }
    }

    /// Calls callee with pre-evaluated args and a pre-built lazy rest binding.
    /// `rest` is bound directly to the `& rest` parameter without wrapping in a list.
    /// Used by `apply` when the spread argument is a lazy seq that must not be forced.
    public func call(_ callee: Expr, args: [Expr], rest: Expr) throws -> Expr {
        switch callee {
        case .function(let f):
            return try callUserFunction(name: f.name, params: f.params, body: f.body,
                                        args: args, in: f.capturedEnv ?? Environment(),
                                        rest: rest, selfExpr: callee)

        case .multiArityFunction(let maf):
            let chosen = try selectArity(from: maf.arities, argCount: args.count + 1, name: maf.name ?? "fn")
            return try callUserFunction(name: maf.name, params: chosen.params, body: chosen.body,
                                        args: args, in: maf.capturedEnv ?? Environment(),
                                        rest: rest, selfExpr: callee)
            
        default:
            throw EvaluatorError.notAFunction(callee)
        }
    }

    /// Expands a macro call one step. Returns nil if the form is not a macro call.
    public func macroexpand1(_ expr: Expr) throws -> Expr? {
        guard case .list(let elements, _) = expr,
              !elements.isEmpty,
              case .symbol(let name, _) = elements[0]
        else {
            return nil
        }
        // Try qualified lookup first (for auto-qualified names like user/b), then unqualified
        let varValue = (try? resolveQualifiedVar(name: name))?.value
                    ?? resolveVar(name: name, in: currentNs())?.value
        guard let value = varValue else {
            return nil
        }
        let args = Array(elements.dropFirst())
        switch value {
        case .macro(_, let params, let body, _):
            return try expandMacro(name: name, params: params, body: body, args: args)

        case .multiArityMacro(_, let arities, _):
            let chosen = try selectArity(from: arities, argCount: args.count, name: name)
            return try expandMacro(name: name, params: chosen.params, body: chosen.body, args: args)

        default:
            return nil
        }
    }

    /// Recursively expands every macro call in `expr` to fixpoint — the compile-
    /// time macroexpansion a tree-walker otherwise defers to (and re-does on) every
    /// evaluation. Run once over an `fn`/`defn` body at definition (`buildFnArity`)
    /// so a macro inside a hot loop / lazy-seq body isn't re-expanded per element.
    /// Skips `quote`/`syntax-quote` (literal data / macro templates). Conservative:
    /// a head that isn't a *currently-defined* macro is left untouched, so a
    /// forward-referenced macro still works (expanded at runtime as before), just
    /// unoptimized. Expansion is deterministic given the call form, so this yields
    /// the same result as per-call expansion — and stabilizes gensyms (one
    /// expansion), matching Clojure's compile-once behavior.
    func macroexpandAll(_ expr: Expr) throws -> Expr {
        switch expr {
        case .list(let elements, _):
            guard let head = elements.first
            else { return expr }
            if case .symbol("quote", _) = head { return expr }
            if case .symbol("syntax-quote", _) = head { return expr }
            // Expand the head to fixpoint, then recurse into the result's subforms.
            var current = expr
            while let expanded = try macroexpand1(current) {
                current = expanded
            }
            guard case .list(let curElems, let curMeta) = current
            else { return try macroexpandAll(current) }
            return .list(SwishPersistentList(try curElems.map { try macroexpandAll($0) }), metadata: curMeta)

        case .seq(let elements):
            // A macro expansion (via `cons`/`list`/…) can yield `.seq` code forms —
            // e.g. `when` expands to `(if test (do …))` where `(do …)` is a `.seq`.
            // Treat them exactly like `.list` and normalize the output to `.list`:
            // eval dispatches both to `evalList`, but the downstream `expandAliases`
            // only special-cases `.list`, so a stray `.seq` subform would slip
            // through un-qualified (its symbols never rewritten to their vars).
            return try macroexpandAll(.list(SwishPersistentList(elements), metadata: nil))

        case .vector(let elements, let meta):
            return .vector(SwishPersistentVector(try elements.map { try macroexpandAll($0) }), metadata: meta)

        case .map(let sm):
            var result: [Expr: Expr] = [:]
            for (k, v) in sm.dict {
                result[try macroexpandAll(k)] = try macroexpandAll(v)
            }
            return .map(result, metadata: sm.metadata)

        case .sortedMap(let ssm):
            return try transformSortedMap(ssm) { try macroexpandAll($0) }

        case .set(let ss):
            var result: Set<Expr> = []
            for e in ss.elements {
                result.insert(try macroexpandAll(e))
            }
            return .set(result, metadata: ss.metadata)

        case .sortedSet(let sss):
            return .sortedSet(try sss.elements.map { try macroexpandAll($0) },
                              comparator: sss.comparator, metadata: sss.metadata)

        default:
            return expr
        }
    }

    private func expandMacro(name: String, params: [String], body: [Expr], args: [Expr]) throws -> Expr {
        let macroEnv = Environment()
        try bindParams(params, to: args, in: macroEnv, name: name)
        return try evalBody(body, in: macroEnv)
    }

    func evalBody(_ forms: [Expr], in env: Environment) throws -> Expr {
        var result: Expr = .nil
        for form in forms {
            result = try eval(form, in: env)
        }
        return result
    }

    func bindParams(_ params: [String], to args: [Expr], in env: Environment, name: String,
                    prebuiltRest: Expr? = nil) throws {
        if let ampIdx = params.firstIndex(of: "&") {
            let fixedParams = Array(params[..<ampIdx])
            let restParam = params[ampIdx + 1]
            guard args.count >= fixedParams.count
            else {
                throw EvaluatorError.arityMismatch(
                    name: name, expected: .fixed(fixedParams.count), got: args.count)
            }
            for (param, arg) in zip(fixedParams, args) {
                env.set(param, arg)
            }
            if let rest = prebuiltRest {
                env.set(restParam, rest)
            } else {
                let restArgs = Array(args.dropFirst(fixedParams.count))
                env.set(restParam, restArgs.isEmpty ? .nil : .list(SwishPersistentList(restArgs), metadata: nil))
            }
        }
        else {
            guard args.count == params.count
            else {
                throw EvaluatorError.arityMismatch(
                    name: name, expected: .fixed(params.count), got: args.count)
            }
            for (param, arg) in zip(params, args) {
                env.set(param, arg)
            }
        }
    }
}
