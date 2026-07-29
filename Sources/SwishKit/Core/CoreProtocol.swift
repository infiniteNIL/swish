import Collections

private let protocolImplsKey = Expr.keyword("impls")

/// The built-in type keywords that count as numbers — the `Number` fan-out set.
/// These match `Expr.description` for the numeric `Expr` cases.
private let numericTypeKeywords: Set<String> = [
    "integer", "double", "float", "ratio", "bigInteger", "bigDecimal",
]

/// The fixed, data-modeled ancestor chain (parents only, most-specific first) of a
/// built-in type keyword — Swish's stand-in for the JVM class hierarchy real
/// Clojure's `find-protocol-impl` walks. Protocol dispatch and the
/// `satisfies?`/`instance?`/`extends?` predicates consult this on an exact-type
/// miss so `(extend-type Number …)`/`(extend-type Object …)` fan out correctly.
/// `nil` deliberately has no `Object` fallback (matching Clojure/Java, where
/// `null` is not an `Object`); `Object` is the root; `Number` is-a `Object`.
func builtinAncestors(ofTypeKeyword k: String) -> [String] {
    switch k {
    case "nil", "Object":
        return []

    case "Number":
        return ["Object"]

    default:
        return numericTypeKeywords.contains(k) ? ["Number", "Object"] : ["Object"]
    }
}

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
        doc: "Returns true if x is an instance of atype (a deftype/defrecord type, a built-in type name, or nil).",
        arglists: [["atype", "x"]]) { [evaluator] args in try coreInstance(evaluator, args) }
    evaluator.register(name: "builtin-ancestors", arity: .fixed(1),
        doc: "Internal. Returns the data-modeled ancestor chain (Number/Object) of a built-in type keyword — backs the miss-path hierarchy walk in protocol-dispatch.",
        arglists: [["type-kw"]]) { args in
        guard case .keyword(let k) = args[0] else { return .vector([], metadata: nil) }
        return .vector(SwishPersistentVector(builtinAncestors(ofTypeKeyword: k).map { .keyword($0) }), metadata: nil)
    }
    evaluator.register(name: "deftype-field-value", arity: .fixed(2),
        doc: "Internal. Reads field from a deftype/defrecord instance — backs the implicit unqualified field access injected into deftype/defrecord method bodies.",
        arglists: [["instance", "field"]]) { args in
        switch args[0] {
        case .record(_, _, let data, _): return data[args[1]] ?? .nil
        case .deftype(_, _, let data, _): return data[args[1]] ?? .nil
        default: return .nil
        }
    }
    evaluator.register(name: "reify-method-table", arity: .fixed(1),
        doc: "Internal. Returns a reify instance's inline method map, or nil for anything else — backs the reify fast-path in protocol-dispatch.",
        arglists: [["x"]]) { args in
        guard case .deftype(_, _, let data, _) = args[0],
              case .map? = data[reifyMethodsKey]
        else { return .nil }
        return data[reifyMethodsKey] ?? .nil
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
        try evaluator.registerProtocolImpl(protoValue: protoValue, typeName: typeName, methodImpls: mmap.dict.swiftDictionary, inline: false, formName: "extend")
        i += 2
    }
    return .nil
}

private func coreSatisfies(_ args: [Expr]) throws -> Expr {
    guard case .map(let protoMap) = args[0], case .map(let impls)? = protoMap.dict[protocolImplsKey] else {
        throw EvaluatorError.invalidArgument(function: "satisfies?", message: "first argument must be a protocol")
    }
    // A reify instance carries its implemented-protocol set inline rather than
    // registering into `:impls`, so check that set by the protocol's qualified
    // name (the `:name` symbol defprotocol stores).
    if case .deftype(_, _, let data, _) = args[1],
       case .set(let protocols)? = data[reifyProtocolsKey] {
        guard case .symbol(let protoName, _)? = protoMap.dict[.keyword("name")] else {
            return .boolean(false)
        }
        return .boolean(protocols.elements.contains(.string(protoName)))
    }
    let typeName = args[1].description
    return .boolean(hasImplForTypeOrAncestor(typeName, in: impls.dict))
}

/// True if `typeName` (or, on an exact miss, any of its built-in ancestors —
/// `Number`/`Object`) has an entry in a protocol's `:impls` map. Shared by
/// `satisfies?`/`extends?` so both respect the built-in type hierarchy.
private func hasImplForTypeOrAncestor(_ typeName: String, in impls: TreeDictionary<Expr, Expr>) -> Bool {
    if impls[.keyword(typeName)] != nil { return true }
    return builtinAncestors(ofTypeKeyword: typeName).contains { impls[.keyword($0)] != nil }
}

private func coreExtends(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .map(let protoMap) = args[0], case .map(let impls)? = protoMap.dict[protocolImplsKey] else {
        throw EvaluatorError.invalidArgument(function: "extends?", message: "first argument must be a protocol")
    }
    let typeName = try evaluator.dispatchTypeName(for: args[1], formName: "extends?")
    return .boolean(hasImplForTypeOrAncestor(typeName, in: impls.dict))
}

private func coreExtenders(_ args: [Expr]) throws -> Expr {
    guard case .map(let protoMap) = args[0], case .map(let impls)? = protoMap.dict[protocolImplsKey] else {
        throw EvaluatorError.invalidArgument(function: "extenders", message: "argument must be a protocol")
    }
    let types = impls.dict.keys.map { key -> Expr in
        if case .keyword("nil") = key { return .nil }
        return key
    }
    return .list(SwishPersistentList(types), metadata: nil)
}

private func coreInstance(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let typeName = try evaluator.dispatchTypeName(for: args[0], formName: "instance?")
    let valueType = args[1].description
    if valueType == typeName { return .boolean(true) }
    return .boolean(builtinAncestors(ofTypeKeyword: valueType).contains(typeName))
}
