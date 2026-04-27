func registerNamespace(into evaluator: Evaluator) {
    evaluator.register(name: "create-ns", arity: .fixed(1)) { [evaluator] args in
        guard case .symbol(let name) = args[0] else {
            throw EvaluatorError.invalidArgument(
                function: "create-ns",
                message: "expected a symbol, got \(args[0])")
        }
        return .namespace(evaluator.findOrCreateNs(name))
    }

    evaluator.register(name: "in-ns", arity: .fixed(1)) { [evaluator] args in
        guard case .symbol(let name) = args[0] else {
            throw EvaluatorError.invalidArgument(
                function: "in-ns",
                message: "expected a symbol, got \(args[0])")
        }
        let ns = evaluator.findOrCreateNs(name)
        evaluator.findNs("clojure.core")!.findVar(name: "*ns*")!.value = .namespace(ns)
        return .namespace(ns)
    }
}
