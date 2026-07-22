private let protocolImplsKey = Expr.keyword("impls")

// MARK: - Registration

func registerProtocol(into evaluator: Evaluator) {
    evaluator.register(name: "extend", arity: .atLeastOne,
        doc: "Implementations of protocol methods can be provided using the extend construct: (extend AType AProtocol {:method-name method-fn ...} ...). atype may be a deftype/defrecord type or nil.",
        arglists: [["atype", "proto", "method-map"], ["atype", "proto", "method-map", "&", "etc"]]) { [evaluator] args in try coreExtend(evaluator, args) }
    evaluator.register(name: "satisfies?", arity: .fixed(2),
        doc: "Returns true if x satisfies the protocol.",
        arglists: [["protocol", "x"]]) { args in try coreSatisfies(args) }
    evaluator.register(name: "extends?", arity: .fixed(2),
        doc: "Returns true if atype extends protocol.",
        arglists: [["protocol", "atype"]]) { [evaluator] args in try coreExtends(evaluator, args) }
    evaluator.register(name: "extenders", arity: .fixed(1),
        doc: "Returns a collection of the types explicitly extending protocol.",
        arglists: [["protocol"]]) { args in try coreExtenders(args) }
    evaluator.register(name: "instance?", arity: .fixed(2),
        doc: "Returns true if x is an instance of atype (a deftype/defrecord type, or nil).",
        arglists: [["atype", "x"]]) { [evaluator] args in try coreInstance(evaluator, args) }
    evaluator.register(name: "deftype-field-value", arity: .fixed(2),
        doc: "Internal. Reads field from a deftype/defrecord instance — backs the implicit unqualified field access injected into deftype/defrecord method bodies.",
        arglists: [["instance", "field"]]) { args in
        switch args[0] {
        case .record(_, _, let data, _): return data[args[1]] ?? .nil
        case .deftype(_, _, let data, _): return data[args[1]] ?? .nil
        default: return .nil
        }
    }
}

// MARK: - Helpers

private func coreExtend(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard args.count >= 3, (args.count - 1) % 2 == 0 else {
        throw EvaluatorError.invalidArgument(function: "extend", message: "requires atype followed by proto/method-map pairs")
    }
    let typeName = try evaluator.dispatchTypeName(for: args[0], formName: "extend")
    var i = 1
    while i + 1 < args.count {
        let protoValue = args[i]
        guard case .map(let mmap) = args[i + 1] else {
            throw EvaluatorError.invalidArgument(function: "extend", message: "expected a map of method implementations")
        }
        try evaluator.registerProtocolImpl(protoValue: protoValue, typeName: typeName, methodImpls: mmap.dict, inline: false, formName: "extend")
        i += 2
    }
    return .nil
}

private func coreSatisfies(_ args: [Expr]) throws -> Expr {
    guard case .map(let protoMap) = args[0], case .map(let impls)? = protoMap.dict[protocolImplsKey] else {
        throw EvaluatorError.invalidArgument(function: "satisfies?", message: "first argument must be a protocol")
    }
    let typeName = args[1].description
    return .boolean(impls.dict[.keyword(typeName)] != nil)
}

private func coreExtends(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .map(let protoMap) = args[0], case .map(let impls)? = protoMap.dict[protocolImplsKey] else {
        throw EvaluatorError.invalidArgument(function: "extends?", message: "first argument must be a protocol")
    }
    let typeName = try evaluator.dispatchTypeName(for: args[1], formName: "extends?")
    return .boolean(impls.dict[.keyword(typeName)] != nil)
}

private func coreExtenders(_ args: [Expr]) throws -> Expr {
    guard case .map(let protoMap) = args[0], case .map(let impls)? = protoMap.dict[protocolImplsKey] else {
        throw EvaluatorError.invalidArgument(function: "extenders", message: "argument must be a protocol")
    }
    let types = impls.dict.keys.map { key -> Expr in
        if case .keyword("nil") = key { return .nil }
        return key
    }
    return .list(types, metadata: nil)
}

private func coreInstance(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let typeName = try evaluator.dispatchTypeName(for: args[0], formName: "instance?")
    return .boolean(args[1].description == typeName)
}
