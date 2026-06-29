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
        case .map, .record: return .boolean(true)
        default: return .boolean(false)
        }
    }
}

private func coreFind(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .nil:
        return .nil

    case .map(let dict, _):
        guard let value = dict[args[1]] else { return .nil }
        return .vector([args[1], value], metadata: nil)

    case .record(_, _, let data, _):
        guard let value = data[args[1]] else { return .nil }
        return .vector([args[1], value], metadata: nil)

    default:
        throw EvaluatorError.invalidArgument(
            function: "find",
            message: "first argument must be a map or nil, got \(corePrinter.printString(args[0]))")
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

    case .list(let elems, _):
        keys = elems

    case .nil:
        keys = []

    default:
        throw EvaluatorError.invalidArgument(
            function: "get-in",
            message: "ks must be a sequential collection")
    }
    var current = args[0]
    for key in keys {
        switch current {
        case .map(let dict, _):
            guard let value = dict[key] else { return notFound }
            current = value

        case .vector(let elems, _):
            guard case .integer(let idx) = key, idx >= 0, idx < elems.count else { return notFound }
            current = elems[idx]

        case .nil:
            return notFound

        default:
            return notFound
        }
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

    case .map(var dict, _):
        for key in args.dropFirst() {
            dict.removeValue(forKey: key)
        }
        return .map(dict, metadata: nil)

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

private func coreKeys(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .nil:
        return .nil

    case .map(let dict, _):
        let keys = Array(dict.keys)
        return keys.isEmpty ? .nil : .list(keys, metadata: nil)

    case .record(_, _, let data, _):
        let keys = Array(data.keys)
        return keys.isEmpty ? .nil : .list(keys, metadata: nil)

    default:
        throw EvaluatorError.invalidArgument(
            function: "keys",
            message: "argument must be a map or nil, got \(corePrinter.printString(args[0]))")
    }
}

private func coreVals(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .nil:
        return .nil

    case .map(let dict, _):
        let vals = Array(dict.values)
        return vals.isEmpty ? .nil : .list(vals, metadata: nil)

    case .record(_, _, let data, _):
        let vals = Array(data.values)
        return vals.isEmpty ? .nil : .list(vals, metadata: nil)

    default:
        throw EvaluatorError.invalidArgument(
            function: "vals",
            message: "argument must be a map or nil, got \(corePrinter.printString(args[0]))")
    }
}

private func coreMerge(_ args: [Expr]) throws -> Expr {
    var result: [Expr: Expr] = [:]
    var hadMapArg = false
    for arg in args {
        switch arg {
        case .map(let d, _):
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

    var dict: [Expr: Expr]
    switch args[0] {
    case .map(let d, _):
        dict = d

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

    case .vector(let elements, _):
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
        return .vector(result, metadata: nil)

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
    return .map(dict, metadata: nil)
}

private func coreGet(_ args: [Expr]) throws -> Expr {
    guard args.count == 2 || args.count == 3 else {
        throw EvaluatorError.invalidArgument(
            function: "get",
            message: "requires 2 or 3 arguments, got \(args.count)")
    }

    let notFound: Expr = args.count == 3 ? args[2] : .nil

    switch args[0] {
    case .nil:
        return notFound

    case .map(let dict, _):
        return dict[args[1]] ?? notFound

    case .record(_, _, let data, _):
        return data[args[1]] ?? notFound

    case .vector(let elements, _):
        guard case .integer(let idx) = args[1], idx >= 0, idx < elements.count else {
            return notFound
        }
        return elements[idx]

    case .string(let s):
        guard case .integer(let idx) = args[1], idx >= 0 else { return notFound }
        guard let i = s.index(s.startIndex, offsetBy: idx, limitedBy: s.endIndex),
              i < s.endIndex
        else { return notFound }
        return .character(s[i])

    case .set(let elements, _):
        return elements.contains(args[1]) ? args[1] : notFound

    case .sortedSet(let elements, _):
        return ((try? sortedSetContains(elements, args[1])) == true) ? args[1] : notFound

    case .transient(let tc):
        return try coreGet([tc.value] + Array(args.dropFirst()))

    default:
        return notFound
    }
}
