func registerNamespace(into evaluator: Evaluator) {
    evaluator.register(name: "create-ns", arity: .fixed(1)) { [evaluator] args in
        guard case .symbol(let name, _) = args[0] else {
            throw EvaluatorError.invalidArgument(
                function: "create-ns",
                message: "expected a symbol, got \(args[0])")
        }
        return .namespace(evaluator.findOrCreateNs(name))
    }

    evaluator.register(name: "in-ns", arity: .fixed(1)) { [evaluator] args in
        guard case .symbol(let name, _) = args[0] else {
            throw EvaluatorError.invalidArgument(
                function: "in-ns",
                message: "expected a symbol, got \(args[0])")
        }
        let ns = evaluator.findOrCreateNs(name)
        evaluator.setCurrentNs(ns)
        return .namespace(ns)
    }

    evaluator.register(name: "require", arity: .atLeastOne) { [evaluator] args in
        try evaluator.processRequireDirective(args, caller: "require")
        return .nil
    }

    evaluator.register(name: "alias", arity: .fixed(2)) { [evaluator] args in
        guard case .symbol(let aliasName, _) = args[0] else {
            throw EvaluatorError.invalidArgument(
                function: "alias",
                message: "first argument must be a symbol, got \(args[0])")
        }
        guard case .symbol(let nsName, _) = args[1] else {
            throw EvaluatorError.invalidArgument(
                function: "alias",
                message: "second argument must be a symbol, got \(args[1])")
        }
        guard let ns = evaluator.findNs(nsName) else {
            throw EvaluatorError.namespaceNotFound(nsName)
        }
        try evaluator.currentNs().alias(name: aliasName, ns: ns)
        return .nil
    }

    evaluator.register(name: "refer", arity: .atLeastOne) { [evaluator] args in
        guard case .symbol(let nsName, _) = args[0] else {
            throw EvaluatorError.invalidArgument(
                function: "refer",
                message: "first argument must be a symbol, got \(args[0])")
        }
        guard let srcNs = evaluator.findNs(nsName) else {
            throw EvaluatorError.namespaceNotFound(nsName)
        }
        var only: Set<String>?
        var exclude: Set<String> = []
        var i = 1
        while i + 1 < args.count {
            guard case .keyword(let key) = args[i] else {
                i += 1
                continue
            }
            switch key {
            case "only":
                if case .vector(let syms, _) = args[i + 1] {
                    only = Set(syms.compactMap { if case .symbol(let s, _) = $0 { s } else { nil } })
                }

            case "exclude":
                if case .vector(let syms, _) = args[i + 1] {
                    exclude = Set(syms.compactMap { if case .symbol(let s, _) = $0 { s } else { nil } })
                }

            default:
                break
            }
            i += 2
        }
        let currentNs = evaluator.currentNs()
        for (varName, v) in srcNs.mappings where v.namespace === srcNs {
            if let only {
                if only.contains(varName) { try currentNs.refer(v) }
            }
            else if !exclude.contains(varName) {
                try currentNs.refer(v)
            }
        }
        return .nil
    }
}
