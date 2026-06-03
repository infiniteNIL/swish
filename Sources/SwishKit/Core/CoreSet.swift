func registerSet(into evaluator: Evaluator) {
    evaluator.register(name: "set?", arity: .fixed(1),
        doc: "Returns true if x implements IPersistentSet",
        arglists: [["x"]]) { args in
        if case .set = args[0] { return .boolean(true) }
        return .boolean(false)
    }

    evaluator.register(name: "disj", arity: .atLeastOne,
        doc: "disj[oin]. Returns a new set that does not contain key(s).",
        arglists: [["set"], ["set", "key"], ["set", "key", "&", "ks"]]) { args in
        guard case .set(var elements, let meta) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "disj", message: "first argument must be a set")
        }
        for key in args.dropFirst() {
            elements.remove(key)
        }
        return .set(elements, metadata: meta)
    }
}
