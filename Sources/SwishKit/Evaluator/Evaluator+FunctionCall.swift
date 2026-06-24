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

        case .function(let name, let params, let body, let capturedEnv, _):
            return try callUserFunction(name: name, params: params, body: body, args: evalArgs(args, in: env), in: capturedEnv ?? env)

        case .multiArityFunction(let name, let arities, let capturedEnv, _):
            let evaluated = try evalArgs(args, in: env)
            let chosen = try selectArity(from: arities, argCount: evaluated.count, name: name ?? "fn")
            return try callUserFunction(name: name, params: chosen.params, body: chosen.body, args: evaluated, in: capturedEnv ?? env)

        case .map(let dict, _):
            return try callMap(dict, args: args, in: env)

        case .keyword(let name):
            return try callKeyword(name, args: args, in: env)

        case .vector(let elements, _):
            return try callVector(elements, args: args, in: env)

        case .set(let elements, _):
            return try callSet(elements, args: args, in: env)

        case .record(_, _, let data, _):
            return try callMap(data, args: args, in: env)

        default:
            throw EvaluatorError.notAFunction(callee)
        }
    }

    private func evalLookupArgs(_ args: ArraySlice<Expr>, function: String, in env: Environment) throws -> (key: Expr, notFound: Expr) {
        let evaluated = try args.map { try eval($0, in: env) }
        guard evaluated.count == 1 || evaluated.count == 2 else {
            throw EvaluatorError.invalidArgument(function: function,
                message: "requires 1 or 2 arguments, got \(evaluated.count)")
        }
        return (evaluated[0], evaluated.count == 2 ? evaluated[1] : .nil)
    }

    private func callMap(_ dict: [Expr: Expr], args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        let (key, notFound) = try evalLookupArgs(args, function: "map", in: env)
        return dict[key] ?? notFound
    }

    private func callKeyword(_ name: String, args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        let (key, notFound) = try evalLookupArgs(args, function: "keyword", in: env)
        switch key {
        case .map(let dict, _):            return dict[.keyword(name)] ?? notFound
        case .record(_, _, let data, _):   return data[.keyword(name)] ?? notFound
        default:                           return notFound
        }
    }

    private func callVector(_ elements: [Expr], args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        let evaluated = try args.map { try eval($0, in: env) }
        guard evaluated.count == 1
        else {
            throw EvaluatorError.invalidArgument(
                function: "vector",
                message: "requires 1 argument, got \(evaluated.count)")
        }
        guard case .integer(let idx) = evaluated[0]
        else {
            throw EvaluatorError.invalidArgument(
                function: "vector",
                message: "index must be an integer")
        }
        guard idx >= 0, idx < elements.count
        else {
            throw EvaluatorError.invalidArgument(
                function: "vector",
                message: "index \(idx) out of bounds for vector of size \(elements.count)")
        }
        return elements[idx]
    }

    private func callSet(_ set: Set<Expr>, args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        let evaluated = try args.map { try eval($0, in: env) }
        guard evaluated.count == 1
        else {
            throw EvaluatorError.invalidArgument(
                function: "set",
                message: "requires 1 argument, got \(evaluated.count)")
        }
        return set.contains(evaluated[0]) ? evaluated[0] : .nil
    }

    /// Calls an already-evaluated callee with already-evaluated args. Used by HOFs and meta functions.
    /// Does NOT re-evaluate args — use callFunction for unevaluated args.
    public func call(_ callee: Expr, args: [Expr]) throws -> Expr {
        switch callee {
        case .nativeFunction(let name, let arity, let body):
            return try callNativeFunction(name: name, arity: arity, body: body, args: args)

        case .function(let name, let params, let body, let capturedEnv, _):
            return try callUserFunction(name: name, params: params, body: body, args: args, in: capturedEnv ?? Environment())

        case .multiArityFunction(let name, let arities, let capturedEnv, _):
            let chosen = try selectArity(from: arities, argCount: args.count, name: name ?? "fn")
            return try callUserFunction(name: name, params: chosen.params, body: chosen.body, args: args, in: capturedEnv ?? Environment())

        case .macro(let name, let params, let body, _):
            return try callMacro(name: name, params: params, body: body, args: args[...], in: Environment())

        case .multiArityMacro(let name, let arities, _):
            let chosen = try selectArity(from: arities, argCount: args.count, name: name ?? "macro")
            return try callMacro(name: name, params: chosen.params, body: chosen.body, args: args[...], in: Environment())

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

    func callUserFunction(name: String?, params: [String], body: [Expr], args: [Expr], in env: Environment) throws -> Expr {
        guard callDepth < maxCallDepth else {
            throw EvaluatorError.stackOverflow(maxDepth: maxCallDepth)
        }
        callDepth += 1
        defer { callDepth -= 1 }
        var currentArgs = args
        while true {
            if interruptionCheck?() == true { throw EvaluatorError.interrupted }
            let fnEnv = Environment(parent: env)
            try bindParams(params, to: currentArgs, in: fnEnv, name: name ?? "fn")
            if let fnName = name {
                fnEnv.set(fnName, .function(name: name, params: params, body: body,
                                            capturedEnv: env, metadata: nil))
            }
            do {
                return try evalBody(body, in: fnEnv)
            } catch let signal as RecurSignal {
                currentArgs = signal.args
            }
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

    func bindParams(_ params: [String], to args: [Expr], in env: Environment, name: String) throws {
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
            let restArgs = Array(args.dropFirst(fixedParams.count))
            env.set(restParam, restArgs.isEmpty ? .nil : .list(restArgs, metadata: nil))
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
