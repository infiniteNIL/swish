func registerMap(into evaluator: Evaluator) {
    evaluator.register(name: "get",    arity: .variadic, body: coreGet)
    evaluator.register(name: "get-in", arity: .variadic, body: coreGetIn)
    evaluator.register(name: "find",   arity: .fixed(2), body: coreFind)
    evaluator.register(name: "assoc",  arity: .variadic, body: coreAssoc)
    evaluator.register(name: "dissoc", arity: .variadic, body: coreDissoc)
    evaluator.register(name: "merge",  arity: .variadic, body: coreMerge)
    evaluator.register(name: "keys",   arity: .fixed(1), body: coreKeys)
    evaluator.register(name: "vals",   arity: .fixed(1), body: coreVals)
    evaluator.register(name: "map?",   arity: .fixed(1), body: coreIsMap)
}

private func coreFind(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .nil:
        return .nil

    case .map(let dict, _):
        guard let value = dict[args[1]] else { return .nil }
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

private func coreDissoc(_ args: [Expr]) throws -> Expr {
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

private func coreIsMap(_ args: [Expr]) throws -> Expr {
    if case .map = args[0] { return .boolean(true) }
    return .boolean(false)
}

private func coreAssoc(_ args: [Expr]) throws -> Expr {
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

    default:
        return notFound
    }
}
