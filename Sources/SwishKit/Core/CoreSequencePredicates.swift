// MARK: - Registration

func registerSequencePredicates(into evaluator: Evaluator) {
    evaluator.register(name: "vector?", arity: .fixed(1), doc: "Return true if x implements IPersistentVector",    arglists: [["x"]]) { args in
        switch args[0] {
        case .vector, .sharedVector, .mapEntry: return .boolean(true)
        default:                                return .boolean(false)
        }
    }
    evaluator.register(name: "list?", arity: .fixed(1), doc: "Returns true if x implements IPersistentList",        arglists: [["x"]]) { args in if case .list = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "seq?",      arity: .fixed(1), doc: "Returns true if x implements ISeq",               arglists: [["x"]]) { args in switch args[0] { case .list, .seq, .lazySeq: return .boolean(true); default: return .boolean(false) } }
    evaluator.register(name: "seqable?", arity: .fixed(1),
        doc: "Return true if the seq function is supported for x",
        arglists: [["x"]]) { args in
        switch args[0] {
        case .lazySeq:
            // A lazy seq is seqable by construction — must not force it to
            // find out, or (seqable? (range)) would hang realizing an
            // infinite seq. Fall through to asSequence for everything else.
            return .boolean(true)

        default:
            return .boolean((try? asSequence(args[0])) != nil)
        }
    }
    evaluator.register(name: "lazy-seq?", arity: .fixed(1), doc: "Return true if x is a LazySeq.",                   arglists: [["x"]]) { args in if case .lazySeq = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "realized?", arity: .fixed(1),
        doc: "Returns true if a lazy sequence or delay has been forced.",
        arglists: [["x"]]) { args in
        switch args[0] {
        case .lazySeq(let box): return .boolean(box.isRealized)
        case .delay(let box):   return .boolean(box.isRealized)
        case .promise(let box): return .boolean(box.isRealized)
        case .future(let box):  return .boolean(box.isRealized)
        default:
            throw EvaluatorError.invalidArgument(function: "realized?",
                message: "realized? requires a lazy seq, delay, promise, or future, got \(corePrinter.printString(args[0]))")
        }
    }
}
