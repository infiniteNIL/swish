// MARK: - Registration

func registerMeta(into evaluator: Evaluator) {
    evaluator.register(name: "meta", arity: .fixed(1),
        doc: "Returns the metadata of obj, returns nil if there is no metadata.",
        arglists: [["obj"]],
        body: coreMeta)
    evaluator.register(name: "with-meta", arity: .fixed(2),
        doc: "Returns an object of the same type and value as obj, with map m as its metadata.",
        arglists: [["obj", "m"]],
        body: coreWithMeta)
    evaluator.register(name: "vary-meta", arity: .variadic,
        doc: "Returns an object of the same type and value as obj, with (apply f (meta obj) args) as its metadata.",
        arglists: [["obj", "f", "&", "args"]]) { [evaluator] args in try coreVaryMeta(evaluator, args) }
    evaluator.register(name: "alter-meta!", arity: .variadic,
        doc: "Atomically sets the metadata for a namespace/var/ref/agent/atom to be: (apply f its-current-meta args) f must be free of side-effects.",
        arglists: [["iref", "f", "&", "args"]]) { [evaluator] args in try coreAlterMeta(evaluator, args) }
    evaluator.register(name: "reset-meta!", arity: .fixed(2),
        doc: "Atomically resets the metadata for a namespace/var/ref/agent/atom.",
        arglists: [["iref", "m"]],
        body: coreResetMeta)
}

// MARK: - Implementations

private func coreMeta(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .symbol(_, let m), .list(_, let m), .vector(_, let m), .sortedMap(_, let m), .sortedSet(_, let m):
        guard let m else { return .nil }
        return .map(m, metadata: nil)

    case .map(let sm):
        guard let m = sm.metadata else { return .nil }
        return .map(m, metadata: nil)

    case .set(let ss):
        guard let m = ss.metadata else { return .nil }
        return .map(m, metadata: nil)

    case .function(let f):
        guard let m = f.metadata else { return .nil }
        return .map(m, metadata: nil)

    case .macro(_, _, _, let m):
        guard let m else { return .nil }
        return .map(m, metadata: nil)

    case .multiArityFunction(let maf):
        guard let m = maf.metadata else { return .nil }
        return .map(m, metadata: nil)

    case .multiArityMacro(_, _, let m):
        guard let m else { return .nil }
        return .map(m, metadata: nil)

    case .varRef(let v):
        guard let m = v.metadata else { return .nil }
        return .map(m, metadata: nil)

    case .namespace(let ns):
        guard let m = ns.metadata else { return .nil }
        return .map(m, metadata: nil)

    case .atom(let a):
        guard let m = a.metadata else { return .nil }
        return .map(m, metadata: nil)

    case .ref(let r):
        guard let m = r.metadata else { return .nil }
        return .map(m, metadata: nil)

    default:
        return .nil
    }
}

private func coreWithMeta(_ args: [Expr]) throws -> Expr {
    let newMeta: [Expr: Expr]?
    switch args[1] {
    case .map(let sm):
        newMeta = sm.dict

    case .nil:
        newMeta = nil

    default:
        throw EvaluatorError.invalidArgument(
            function: "with-meta",
            message: "metadata must be a map or nil, got \(corePrinter.printString(args[1]))")
    }

    switch args[0] {
    case .symbol(let n, _):
        return .symbol(n, metadata: newMeta)

    case .list(let e, _):
        return .list(e, metadata: newMeta)

    case .vector(let e, _):
        return .vector(e, metadata: newMeta)

    case .map(let sm):
        return .map(SwishMap(dict: sm.dict, metadata: newMeta))

    case .set(let ss):
        return .set(SwishSet(elements: ss.elements, metadata: newMeta))

    case .sortedSet(let e, _):
        return .sortedSet(e, metadata: newMeta)

    case .sortedMap(let d, _):
        return .sortedMap(d, metadata: newMeta)

    case .function(let f):
        f.metadata = newMeta
        return .function(f)

    case .macro(let n, let p, let b, _):
        return .macro(name: n, params: p, body: b, metadata: newMeta)

    case .multiArityFunction(let maf):
        maf.metadata = newMeta
        return .multiArityFunction(maf)

    case .multiArityMacro(let n, let a, _):
        return .multiArityMacro(name: n, arities: a, metadata: newMeta)

    case .varRef(let v):
        v.metadata = newMeta
        return .varRef(v)

    case .namespace(let ns):
        ns.metadata = newMeta
        return .namespace(ns)

    default:
        throw EvaluatorError.invalidArgument(
            function: "with-meta",
            message: "\(corePrinter.printString(args[0])) does not support metadata")
    }
}

private func coreVaryMeta(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard args.count >= 2 else {
        throw EvaluatorError.invalidArgument(
            function: "vary-meta",
            message: "requires at least 2 arguments, got \(args.count)")
    }
    let currentMeta = try coreMeta([args[0]])
    let newMeta = try evaluator.call(args[1], args: [currentMeta] + Array(args.dropFirst(2)))
    return try coreWithMeta([args[0], newMeta])
}

private func coreAlterMeta(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard args.count >= 2 else {
        throw EvaluatorError.invalidArgument(
            function: "alter-meta!",
            message: "requires at least 2 arguments, got \(args.count)")
    }
    guard case .varRef(let v) = args[0] else {
        throw EvaluatorError.invalidArgument(
            function: "alter-meta!",
            message: "first argument must be a var reference")
    }
    while true {
        let old = v.metadata
        let currentMeta: Expr = old.map { Expr.map($0, metadata: nil) } ?? .nil
        let newMeta = try evaluator.call(args[1], args: [currentMeta] + Array(args.dropFirst(2)))
        let newMetaDict: [Expr: Expr]?
        switch newMeta {
        case .map(let sm):
            newMetaDict = sm.dict

        case .nil:
            newMetaDict = nil

        default:
            throw EvaluatorError.invalidArgument(
                function: "alter-meta!",
                message: "function must return a map or nil, got \(corePrinter.printString(newMeta))")
        }
        if v.compareAndSetMetadata(expected: old, newValue: newMetaDict) {
            return newMetaDict.map { Expr.map($0, metadata: nil) } ?? .nil
        }
    }
}

private func coreResetMeta(_ args: [Expr]) throws -> Expr {
    guard case .varRef(let v) = args[0] else {
        throw EvaluatorError.invalidArgument(
            function: "reset-meta!",
            message: "first argument must be a var reference")
    }
    switch args[1] {
    case .map(let sm):
        v.metadata = sm.dict
        return .map(sm.dict, metadata: nil)

    case .nil:
        v.metadata = nil
        return .nil

    default:
        throw EvaluatorError.invalidArgument(
            function: "reset-meta!",
            message: "metadata must be a map or nil, got \(corePrinter.printString(args[1]))")
    }
}
