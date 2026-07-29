extension Evaluator {

    // MARK: - binding / let / letfn / loop / recur

    private func requireBindingVector(_ elements: [Expr], function: String, message: String) throws -> [Expr] {
        guard elements.count >= 2, case .vector(let vec, _) = elements[1] else {
            throw EvaluatorError.invalidArgument(function: function, message: message)
        }
        return vec.elements
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

    /// `(set! var-symbol value)` — mutates the current thread-local binding of a
    /// dynamic var established by `binding`, returning the new value. Faithful to
    /// Clojure's `Var.doSet`: the var must be thread-bound (present in an active
    /// `binding` frame) or it throws "Can't change/establish root binding". No
    /// explicit `isDynamic` check is needed — a non-dynamic var can never be
    /// thread-bound (`binding` rejects them), so it hits the same error. Swish
    /// vars carry no validator and the dynamic `set!` path notifies no watches,
    /// matching Clojure, so this is a plain frame mutation. The mutable-`deftype`-
    /// field form of `set!` is deliberately unimplemented (see CLAUDE.md).
    func evalSet(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard elements.count == 3
        else {
            throw EvaluatorError.invalidArgument(function: "set!",
                message: "requires exactly 2 arguments: (set! var-symbol value)")
        }
        guard case .symbol(let name, _) = elements[1]
        else {
            throw EvaluatorError.invalidArgument(function: "set!",
                message: "target must be a symbol (Java-field/mutable-field set! is unsupported)")
        }
        // Resolve the target var exactly as `binding` does, so `set!` matches
        // `binding` and the alias-expansion path is handled identically.
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
        let newValue = try eval(elements[2], in: env)
        // Mutate the innermost (topmost) active binding frame holding this var.
        let id = ObjectIdentifier(v)
        var frames = bindingFrames
        var i = frames.count - 1
        while i >= 0 {
            if frames[i][id] != nil {
                frames[i][id] = newValue
                bindingFrames = frames
                return newValue
            }
            i -= 1
        }
        throw EvaluatorError.invalidArgument(function: "set!",
            message: "Can't change/establish root binding of: \(v.namespace.name)/\(v.name) with set")
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

    // Each `recur` iteration runs in a FRESH `Environment` (built from the current
    // binding values), exactly like `fn` recur in `callUserFunction`. This matters
    // for both correctness and thread-safety: a closure created in the loop body
    // captures *its* iteration's bindings (real Clojure semantics — e.g. building a
    // vector of `(fn [] i)` closures yields each iteration's `i`, not the final
    // value), and because an iteration's env is never mutated after the body might
    // capture and escape it, `Environment` needs no per-lookup locking (see
    // `Environment.swift`). Previously a single `loopEnv` was mutated in place
    // across iterations, which produced the final value for every captured closure
    // and was the one post-setup env mutation blocking a lock-free `Environment`.
    func evalLoop(_ elements: [Expr], in env: Environment) throws -> Expr {
        let bindingVec = try requireBindingVector(elements, function: "loop",
            message: "first argument must be a vector of bindings")
        // Evaluate the initial binding values once, sequentially, so a later
        // initializer can see an earlier binding (`(loop [a 1 b (inc a)] ...)`).
        let setupEnv = Environment(parent: env)
        var names: [String] = []
        var currentArgs: [Expr] = []
        var patternBindings: [(Expr, String)] = []
        for i in stride(from: 0, to: bindingVec.count, by: 2) {
            let pattern = bindingVec[i]
            let value = try eval(bindingVec[i + 1], in: setupEnv)
            if case .symbol(let name, _) = pattern {
                names.append(name)
                setupEnv.set(name, value)
                currentArgs.append(value)
            } else {
                let tmp = gensym(prefix: "lp__")
                names.append(tmp)
                setupEnv.set(tmp, value)
                currentArgs.append(value)
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
            body = [.list(SwishPersistentList([.symbol("let", metadata: nil), .vector(SwishPersistentVector(letVec), metadata: nil)] + body), metadata: nil)]
        }
        try validateRecurTailPosition(in: body)
        while true {
            if interruptionCheck?() == true { throw EvaluatorError.interrupted }
            let iterEnv = Environment(parent: env)
            for (name, value) in zip(names, currentArgs) {
                iterEnv.set(name, value)
            }
            do {
                return try evalBody(body, in: iterEnv)
            } catch let signal as RecurSignal {
                guard signal.args.count == names.count else {
                    throw EvaluatorError.arityMismatch(
                        name: "loop", expected: .fixed(names.count), got: signal.args.count)
                }
                currentArgs = signal.args
            }
        }
    }

    func evalRecur(_ elements: [Expr], in env: Environment) throws -> Expr {
        let args = try elements.dropFirst().map { try eval($0, in: env) }
        throw RecurSignal(args: args)
    }
}
