func registerMap(into evaluator: Evaluator) {
    evaluator.register(name: "get", arity: .variadic,
        doc: "Returns the value mapped to key, not-found or nil if key not present.",
        arglists: [["map", "key"], ["map", "key", "not-found"]],
        body: coreGet)

    evaluator.register(name: "get-in", arity: .variadic,
        doc: "Returns the value in a nested associative structure, where ks is a sequence of keys. Returns nil if the key is not present, or the not-found value if supplied.",
        arglists: [["m", "ks"], ["m", "ks", "not-found"]],
        body: coreGetIn)

    evaluator.register(name: "find", arity: .fixed(2),
        doc: "Returns the map entry for key, or nil if key not present.",
        arglists: [["map", "key"]],
        body: coreFind)

    evaluator.register(name: "assoc", arity: .variadic,
        doc: "assoc[iate]. When applied to a map, returns a new map of the same (hashed/sorted) type, that contains the mapping of key(s) to val(s). When applied to a vector, returns a new vector that contains val at index. Note - index must be <= (count vector).",
        arglists: [["map", "key", "val"], ["map", "key", "val", "&", "kvs"]],
        body: coreAssoc)

    evaluator.register(name: "dissoc", arity: .variadic,
        doc: "dissoc[iate]. Returns a new map of the same (hashed/sorted) type, that does not contain a mapping for key(s).",
        arglists: [["map"], ["map", "key"], ["map", "key", "&", "ks"]],
        body: coreDissoc)

    // Bootstrap: called by the `defn` macro at core.clj:40 before the
    // Clojure merge definition is loaded. The Clojure version (core.clj)
    // shadows this at runtime and handles vector map entries correctly.
    evaluator.register(name: "merge", arity: .variadic,
        doc: "Returns a map that consists of the rest of the maps conj-ed onto the first. If a key occurs in more than one map, the mapping from the latter (left-to-right) will be the mapping in the result.",
        arglists: [["&", "maps"]],
        body: coreMerge)

    evaluator.register(name: "keys", arity: .fixed(1),
        doc: "Returns a sequence of the map's keys, in the same order as (seq map).",
        arglists: [["map"]],
        body: coreKeys)

    evaluator.register(name: "vals", arity: .fixed(1),
        doc: "Returns a sequence of the map's values, in the same order as (seq map).",
        arglists: [["map"]],
        body: coreVals)

    evaluator.register(name: "map?", arity: .fixed(1), doc: "Return true if x implements IPersistentMap", arglists: [["x"]]) { args in
        switch args[0] {
        case .map, .sortedMap, .record: return .boolean(true)
        default: return .boolean(false)
        }
    }

    evaluator.register(name: "key", arity: .fixed(1),
        doc: "Returns the key of the map entry.",
        arglists: [["e"]]) { args in
        guard case .mapEntry(let k, _) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "key",
                message: "Doesn't implement IMapEntry: \(corePrinter.printString(args[0]))")
        }
        return k
    }

    evaluator.register(name: "val", arity: .fixed(1),
        doc: "Returns the value of the map entry.",
        arglists: [["e"]]) { args in
        guard case .mapEntry(_, let v) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "val",
                message: "Doesn't implement IMapEntry: \(corePrinter.printString(args[0]))")
        }
        return v
    }
}

private func coreFind(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .nil:
        return .nil

    case .map(let sm):
        guard let value = sm.dict[args[1]] else { return .nil }
        return .mapEntry(args[1], value)

    case .sortedMap(let dict, _):
        guard let value = dict[args[1]] else { return .nil }
        return .mapEntry(args[1], value)

    case .record(_, _, let data, _):
        guard let value = data[args[1]] else { return .nil }
        return .mapEntry(args[1], value)

    case .vector, .sharedVector:
        let elements = vectorElements(args[0]) ?? []
        guard case .integer(let idx) = args[1],
              idx >= 0, idx < elements.count
        else { return .nil }
        return .vector([args[1], elements[idx]], metadata: nil)

    default:
        throw EvaluatorError.invalidArgument(
            function: "find",
            message: "first argument must be a map, vector, or nil, got \(corePrinter.printString(args[0]))")
    }
}

/// Shared lookup dispatch backing both `get` and `get-in`. Returns Swift `nil`
/// for "not found" and `.some(.nil)` for "found, and the value is Clojure nil"
/// — this distinction is what lets `get-in`'s per-step loop correctly tell
/// a missing key apart from a legitimately nil value without needing a
/// fake unique sentinel object.
private func lookupOptional(_ coll: Expr, _ key: Expr) throws -> Expr? {
    switch coll {
    case .nil:
        return nil

    case .map(let sm):
        return sm.dict[key]

    case .sortedMap(let dict, _):
        return dict[key]

    case .record(_, _, let data, _):
        return data[key]

    case .vector, .sharedVector:
        let elements = vectorElements(coll) ?? []
        guard case .integer(let idx) = key, idx >= 0, idx < elements.count else { return nil }
        return elements[idx]

    case .string(let s):
        guard case .integer(let idx) = key, idx >= 0,
              let i = s.index(s.startIndex, offsetBy: idx, limitedBy: s.endIndex), i < s.endIndex
        else { return nil }
        return .character(s[i])

    case .set(let ss):
        return ss.elements.contains(key) ? key : nil

    case .sortedSet(let elements, _):
        return ((try? sortedSetContains(elements, key)) == true) ? key : nil

    case .array(let sa):
        guard case .integer(let idx) = key, idx >= 0, idx < sa.elements.count else { return nil }
        return sa.elements[idx]

    case .transient(let tc):
        return try lookupOptional(tc.value, key)

    default:
        return nil
    }
}

private func coreGetIn(_ args: [Expr]) throws -> Expr {
    guard args.count == 2 || args.count == 3 else {
        throw EvaluatorError.invalidArgument(
            function: "get-in",
            message: "requires 2 or 3 arguments, got \(args.count)")
    }
    let notFound: Expr = args.count == 3 ? args[2] : .nil
    let keys: [Expr]
    switch args[1] {
    case .vector(let elems, _):
        keys = elems

    case .sharedVector(let sa, _):
        keys = sa.elements

    case .list(let elems, _):
        keys = elems.elements

    case .nil:
        keys = []

    default:
        throw EvaluatorError.invalidArgument(
            function: "get-in",
            message: "ks must be a sequential collection")
    }
    var current = args[0]
    for key in keys {
        guard let value = try lookupOptional(current, key) else { return notFound }
        current = value
    }
    return current
}

func coreDissoc(_ args: [Expr]) throws -> Expr {
    guard !args.isEmpty else {
        throw EvaluatorError.invalidArgument(
            function: "dissoc",
            message: "requires at least 1 argument")
    }
    switch args[0] {
    case .nil:
        return .nil

    case .map(let sm):
        var dict = sm.dict
        for key in args.dropFirst() { dict.removeValue(forKey: key) }
        return .map(dict, metadata: sm.metadata)

    case .sortedMap(var dict, let meta):
        for key in args.dropFirst() {
            dict.removeValue(forKey: key)
        }
        return .sortedMap(dict, metadata: meta)

    case .record(let typeName, let fields, var data, _):
        var removedBaseField = false
        for key in args.dropFirst() {
            if case .keyword(let k) = key, fields.contains(k) { removedBaseField = true }
            data.removeValue(forKey: key)
        }
        if removedBaseField { return .map(data, metadata: nil) }
        return .record(typeName: typeName, fields: fields, data: data, metadata: nil)

    default:
        throw EvaluatorError.invalidArgument(
            function: "dissoc",
            message: "first argument must be a map or nil, got \(corePrinter.printString(args[0]))")
    }
}

private func mapCollection(_ coll: Expr, function: String, project: ([Expr: Expr]) -> [Expr]) throws -> Expr {
    switch coll {
    case .nil:
        return .nil

    case .map(let sm):
        let items = project(sm.dict)
        return items.isEmpty ? .nil : .list(SwishPersistentList(items), metadata: nil)

    case .sortedMap(let dict, _):
        let items = project(dict)
        return items.isEmpty ? .nil : .list(SwishPersistentList(items), metadata: nil)

    case .record(_, _, let data, _):
        let items = project(data)
        return items.isEmpty ? .nil : .list(SwishPersistentList(items), metadata: nil)

    default:
        // Empty seqable collections produce nil (Clojure: seq([]) → nil → KeySeq.create(nil) → nil).
        // Non-seqable values (integers, etc.) throw like Clojure's seq does.
        guard let elements = try? seqOf(coll, function: function), elements.isEmpty else {
            throw EvaluatorError.invalidArgument(function: function,
                message: "not a map: \(corePrinter.printString(coll))")
        }
        return .nil
    }
}

private func coreKeys(_ args: [Expr]) throws -> Expr {
    try mapCollection(args[0], function: "keys") { Array($0.keys) }
}

private func coreVals(_ args: [Expr]) throws -> Expr {
    try mapCollection(args[0], function: "vals") { Array($0.values) }
}

private func coreMerge(_ args: [Expr]) throws -> Expr {
    var result: [Expr: Expr] = [:]
    var hadMapArg = false
    for arg in args {
        switch arg {
        case .map(let sm):
            hadMapArg = true
            for (k, v) in sm.dict { result[k] = v }

        case .sortedMap(let d, _):
            hadMapArg = true
            for (k, v) in d { result[k] = v }

        case .nil:
            break

        default:
            throw EvaluatorError.invalidArgument(
                function: "merge",
                message: "arguments must be maps or nil, got \(corePrinter.printString(arg))")
        }
    }
    return hadMapArg ? .map(result, metadata: nil) : .nil
}

func coreAssoc(_ args: [Expr]) throws -> Expr {
    guard args.count >= 3, (args.count - 1) % 2 == 0 else {
        throw EvaluatorError.invalidArgument(
            function: "assoc",
            message: "requires a map and an even number of key/value pairs")
    }

    var isSortedMap = false
    var dict: [Expr: Expr]
    var inputMeta: [Expr: Expr]? = nil
    switch args[0] {
    case .map(let sm):
        dict = sm.dict
        inputMeta = sm.metadata

    case .sortedMap(let d, let m):
        dict = d
        isSortedMap = true
        inputMeta = m

    case .nil:
        dict = [:]

    case .record(let typeName, let fields, let d, _):
        var recordData = d
        var i = 1
        while i < args.count {
            recordData[args[i]] = args[i + 1]
            i += 2
        }
        return .record(typeName: typeName, fields: fields, data: recordData, metadata: nil)

    case .vector(let elements, let m):
        var result = elements
        var i = 1
        while i < args.count {
            guard case .integer(let idx) = args[i] else {
                throw EvaluatorError.invalidArgument(
                    function: "assoc",
                    message: "vector index must be an integer, got \(corePrinter.printString(args[i]))")
            }
            guard idx >= 0, idx <= result.count else {
                throw EvaluatorError.invalidArgument(
                    function: "assoc",
                    message: "index \(idx) out of bounds for vector of size \(result.count)")
            }
            if idx == result.count {
                result.append(args[i + 1])
            } else {
                result[idx] = args[i + 1]
            }
            i += 2
        }
        return .vector(result, metadata: m)

    case .sharedVector(let sa, let m):
        return try coreAssoc([.vector(sa.elements, metadata: m)] + Array(args.dropFirst()))

    default:
        throw EvaluatorError.invalidArgument(
            function: "assoc",
            message: "first argument must be a map, vector, or nil, got \(corePrinter.printString(args[0]))")
    }

    var i = 1
    while i < args.count {
        dict[args[i]] = args[i + 1]
        i += 2
    }
    return isSortedMap ? .sortedMap(dict, metadata: inputMeta) : .map(dict, metadata: inputMeta)
}

private func coreGet(_ args: [Expr]) throws -> Expr {
    guard args.count == 2 || args.count == 3 else {
        throw EvaluatorError.invalidArgument(
            function: "get",
            message: "requires 2 or 3 arguments, got \(args.count)")
    }
    let notFound: Expr = args.count == 3 ? args[2] : .nil
    return try lookupOptional(args[0], args[1]) ?? notFound
}
