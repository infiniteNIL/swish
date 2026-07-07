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

        case .map, .sortedMap, .keyword, .vector, .set, .record, .transient, .symbol, .varRef:
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

        case .map(let sm):
            guard args.count == 1 || args.count == 2
            else {
                throw EvaluatorError.invalidArgument(function: "map",
                    message: "requires 1 or 2 arguments, got \(args.count)")
            }
            return sm.dict[args[0]] ?? (args.count == 2 ? args[1] : .nil)

        case .sortedMap(let dict, _):
            guard args.count == 1 || args.count == 2
            else {
                throw EvaluatorError.invalidArgument(function: "map",
                    message: "requires 1 or 2 arguments, got \(args.count)")
            }
            return dict[args[0]] ?? (args.count == 2 ? args[1] : .nil)

        case .record(_, _, let data, _):
            guard args.count == 1 || args.count == 2
            else {
                throw EvaluatorError.invalidArgument(function: "record",
                    message: "requires 1 or 2 arguments, got \(args.count)")
            }
            return data[args[0]] ?? (args.count == 2 ? args[1] : .nil)

        case .keyword(let name):
            guard args.count == 1 || args.count == 2
            else {
                throw EvaluatorError.invalidArgument(function: "keyword",
                    message: "requires 1 or 2 arguments, got \(args.count)")
            }
            let notFound: Expr = args.count == 2 ? args[1] : .nil
            switch args[0] {
            case .map(let sm):               return sm.dict[.keyword(name)] ?? notFound
            case .record(_, _, let data, _): return data[.keyword(name)] ?? notFound
            case .set(let ss):               return ss.elements.contains(.keyword(name)) ? .keyword(name) : notFound
            default:                         return notFound
            }

        case .vector(let elements, _):
            guard args.count == 1
            else {
                throw EvaluatorError.invalidArgument(function: "vector",
                    message: "requires 1 argument, got \(args.count)")
            }
            guard case .integer(let idx) = args[0]
            else {
                throw EvaluatorError.invalidArgument(function: "vector",
                    message: "index must be an integer")
            }
            guard idx >= 0, idx < elements.count
            else {
                throw EvaluatorError.invalidArgument(function: "vector",
                    message: "index \(idx) out of bounds for vector of size \(elements.count)")
            }
            return elements[idx]

        case .set(let ss):
            guard args.count == 1
            else {
                throw EvaluatorError.invalidArgument(function: "set",
                    message: "requires 1 argument, got \(args.count)")
            }
            return ss.elements.contains(args[0]) ? args[0] : .nil

        case .sortedSet(let elements, _):
            guard args.count == 1
            else {
                throw EvaluatorError.invalidArgument(function: "sorted-set",
                    message: "requires 1 argument, got \(args.count)")
            }
            return ((try? sortedSetContains(elements, args[0])) == true) ? args[0] : .nil

        case .transient(let tc):
            return try call(tc.value, args: args)

        case .symbol(let name, _):
            guard args.count == 1 || args.count == 2
            else {
                throw EvaluatorError.invalidArgument(function: "symbol",
                    message: "requires 1 or 2 arguments, got \(args.count)")
            }
            let notFound: Expr = args.count == 2 ? args[1] : .nil
            let sym = Expr.symbol(name, metadata: nil)
            switch args[0] {
            case .map(let sm):              return sm.dict[sym] ?? notFound
            case .sortedMap(let d, _):      return d[sym] ?? notFound
            case .set(let ss):              return ss.elements.contains(sym) ? sym : notFound
            case .sortedSet(let elems, _):  return ((try? sortedSetContains(elems, sym)) == true) ? sym : notFound
            default:                        return notFound
            }

        case .varRef(let v):
            guard let val = v.value else {
                throw EvaluatorError.unboundVar("\(v.namespace.name)/\(v.name)")
            }
            return try call(val, args: args)

        default:
            throw EvaluatorError.notAFunction(callee)
        }
    }

    private func callMacro(name: String?, params: [String], body: [Expr], args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        guard callDepth < maxCallDepth else {
            throw EvaluatorError.stackOverflow(maxDepth: maxCallDepth)
        }
        callDepth += 1
        defer { callDepth -= 1 }
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
        guard callDepth < maxCallDepth else {
            throw EvaluatorError.stackOverflow(maxDepth: maxCallDepth)
        }
        callDepth += 1
        defer { callDepth -= 1 }
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
                env.set(restParam, restArgs.isEmpty ? .nil : .list(restArgs, metadata: nil))
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
