extension Evaluator {

    // MARK: - binding / let / letfn / loop / recur

    private func requireBindingVector(_ elements: [Expr], function: String, message: String) throws -> [Expr] {
        guard elements.count >= 2, case .vector(let vec, _) = elements[1] else {
            throw EvaluatorError.invalidArgument(function: function, message: message)
        }
        return vec
    }

    func evalBinding(_ elements: [Expr], in env: Environment) throws -> Expr {
        let bindingVec = try requireBindingVector(elements, function: "binding",
            message: "requires a vector of var/value pairs")
        guard bindingVec.count % 2 == 0
        else {
            throw EvaluatorError.invalidArgument(function: "binding",
                message: "requires an even number of forms in binding vector")
        }
        var frame: [ObjectIdentifier: Expr] = [:]
        var i = 0
        while i < bindingVec.count {
            guard case .symbol(let name, _) = bindingVec[i]
            else {
                throw EvaluatorError.invalidArgument(function: "binding",
                    message: "binding target must be a symbol")
            }
            let v: Var
            if let qualified = try resolveQualifiedVar(name: name) {
                v = qualified
            }
            else if let local = resolveVar(name: name, in: currentNs()) {
                v = local
            }
            else {
                throw EvaluatorError.undefinedSymbol(name)
            }
            guard v.isDynamic
            else {
                throw EvaluatorError.invalidArgument(function: "binding",
                    message: "\(name) is not a dynamic var")
            }
            frame[ObjectIdentifier(v)] = try eval(bindingVec[i + 1], in: env)
            i += 2
        }
        bindingFrames.append(frame)
        defer { bindingFrames.removeLast() }
        return try evalBody(Array(elements.dropFirst(2)), in: env)
    }

    func evalLet(_ elements: [Expr], in env: Environment) throws -> Expr {
        let bindingVec = try requireBindingVector(elements, function: "let",
            message: "first argument must be a vector of bindings")
        // Each binding gets its own child environment, evaluated in the chain
        // built from all PRIOR bindings only — not itself. A shared, mutable
        // frame here would let a closure created by one binding's initializer
        // (e.g. `(fn [] (f))`) capture that frame by reference, then "see" its
        // own name once the frame is mutated to add it a moment later —
        // causing self-reference (and, for a closure that calls itself,
        // infinite recursion) instead of correctly falling through to any
        // outer binding of the same name.
        var currentEnv = env
        for i in stride(from: 0, to: bindingVec.count, by: 2) {
            let bindings = try destructureBindings(bindingVec[i], bindingVec[i + 1])
            if bindings.isEmpty {
                _ = try eval(bindingVec[i + 1], in: currentEnv)
            }
            else {
                for (name, expr) in bindings {
                    let value = try eval(expr, in: currentEnv)
                    let nextEnv = Environment(parent: currentEnv)
                    nextEnv.set(name, value)
                    currentEnv = nextEnv
                }
            }
        }
        return try evalBody(Array(elements.dropFirst(2)), in: currentEnv)
    }

    func evalLetfn(_ elements: [Expr], in env: Environment) throws -> Expr {
        let specs = try requireBindingVector(elements, function: "letfn",
            message: "first argument must be a vector of function specs")
        let letfnEnv = Environment(parent: env)
        var bindings: [(String, Expr)] = []
        for spec in specs {
            guard case .list(let specElems, _) = spec,
                  !specElems.isEmpty,
                  case .symbol(let fnName, _) = specElems[0]
            else {
                throw EvaluatorError.invalidArgument(function: "letfn",
                    message: "each spec must be a list starting with a name symbol")
            }
            // Transform (fname params body...) → (fn fname params body...)
            let fnElements = [Expr.symbol("fn", metadata: nil),
                              Expr.symbol(fnName, metadata: nil)]
                             + Array(specElems.dropFirst())
            bindings.append((fnName, try evalFn(fnElements, in: letfnEnv)))
        }
        // Second pass: bind all fns into the shared env so they see each other
        for (name, fnValue) in bindings {
            letfnEnv.set(name, fnValue)
        }
        return try evalBody(Array(elements.dropFirst(2)), in: letfnEnv)
    }

    // NOTE (thread-safety retrofit): `loopEnv` below is one `Environment` instance
    // mutated repeatedly across `recur` iterations (locking makes each individual
    // `.set` call memory-safe, but doesn't make the sequence of mutations
    // logically race-free). If a closure created inside the loop body captures
    // `loopEnv` and escapes to background execution (not possible today — this
    // step adds no real threading — but will become possible once a later step
    // adds real agent/future execution), that closure's later `.get` could
    // observe any iteration's value depending on timing. Deferred until closures
    // can actually escape to another thread.
    func evalLoop(_ elements: [Expr], in env: Environment) throws -> Expr {
        let bindingVec = try requireBindingVector(elements, function: "loop",
            message: "first argument must be a vector of bindings")
        let loopEnv = Environment(parent: env)
        var names: [String] = []
        var patternBindings: [(Expr, String)] = []
        for i in stride(from: 0, to: bindingVec.count, by: 2) {
            let pattern = bindingVec[i]
            let valueExpr = bindingVec[i + 1]
            if case .symbol(let name, _) = pattern {
                names.append(name)
                loopEnv.set(name, try eval(valueExpr, in: loopEnv))
            } else {
                let tmp = gensym(prefix: "lp__")
                names.append(tmp)
                loopEnv.set(tmp, try eval(valueExpr, in: loopEnv))
                patternBindings.append((pattern, tmp))
            }
        }
        var body = Array(elements.dropFirst(2))
        if !patternBindings.isEmpty {
            var letVec: [Expr] = []
            for (pat, tmpName) in patternBindings {
                letVec.append(pat)
                letVec.append(.symbol(tmpName, metadata: nil))
            }
            body = [.list(SwishPersistentList([.symbol("let", metadata: nil), .vector(letVec, metadata: nil)] + body), metadata: nil)]
        }
        try validateRecurTailPosition(in: body)
        while true {
            if interruptionCheck?() == true { throw EvaluatorError.interrupted }
            do {
                return try evalBody(body, in: loopEnv)
            } catch let signal as RecurSignal {
                guard signal.args.count == names.count else {
                    throw EvaluatorError.arityMismatch(
                        name: "loop", expected: .fixed(names.count), got: signal.args.count)
                }
                for (name, value) in zip(names, signal.args) {
                    loopEnv.set(name, value)
                }
            }
        }
    }

    func evalRecur(_ elements: [Expr], in env: Environment) throws -> Expr {
        let args = try elements.dropFirst().map { try eval($0, in: env) }
        throw RecurSignal(args: args)
    }
}
