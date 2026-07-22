extension Evaluator {
    /// Invokes a collection/keyword/symbol/reference "as a function" — Clojure's
    /// maps/sets/keywords/vectors/etc. are callable as 1-2-arg lookup functions.
    /// Split out from `call(_:args:)`, which handles genuine fn/macro/native-fn
    /// invocation and delegates here for everything else that's still callable.
    func callCollection(_ callee: Expr, args: [Expr]) throws -> Expr {
        switch callee {
        case .map(let sm):
            guard args.count == 1 || args.count == 2
            else {
                throw EvaluatorError.invalidArgument(function: "map",
                    message: "requires 1 or 2 arguments, got \(args.count)")
            }
            return sm.dict[args[0]] ?? (args.count == 2 ? args[1] : .nil)

        case .sortedMap(let dict, _):
            guard args.count == 1 || args.count == 2
            else {
                throw EvaluatorError.invalidArgument(function: "map",
                    message: "requires 1 or 2 arguments, got \(args.count)")
            }
            return dict[args[0]] ?? (args.count == 2 ? args[1] : .nil)

        case .record(_, _, let data, _):
            guard args.count == 1 || args.count == 2
            else {
                throw EvaluatorError.invalidArgument(function: "record",
                    message: "requires 1 or 2 arguments, got \(args.count)")
            }
            return data[args[0]] ?? (args.count == 2 ? args[1] : .nil)

        case .keyword(let name):
            guard args.count == 1 || args.count == 2
            else {
                throw EvaluatorError.invalidArgument(function: "keyword",
                    message: "requires 1 or 2 arguments, got \(args.count)")
            }
            let notFound: Expr = args.count == 2 ? args[1] : .nil
            switch args[0] {
            case .map(let sm):               return sm.dict[.keyword(name)] ?? notFound

            case .record(_, _, let data, _): return data[.keyword(name)] ?? notFound

            case .set(let ss):               return ss.elements.contains(.keyword(name)) ? .keyword(name) : notFound

            case .transient(let tc):
                switch tc.value {
                case .map(let sm):               return sm.dict[.keyword(name)] ?? notFound

                case .record(_, _, let data, _): return data[.keyword(name)] ?? notFound

                case .set(let ss):               return ss.elements.contains(.keyword(name)) ? .keyword(name) : notFound

                default:                         return notFound
                }

            default:                         return notFound
            }

        case .vector(let elements, _):
            guard args.count == 1
            else {
                throw EvaluatorError.invalidArgument(function: "vector",
                    message: "requires 1 argument, got \(args.count)")
            }
            guard case .integer(let idx) = args[0]
            else {
                throw EvaluatorError.invalidArgument(function: "vector",
                    message: "index must be an integer")
            }
            guard idx >= 0, idx < elements.count
            else {
                throw EvaluatorError.invalidArgument(function: "vector",
                    message: "index \(idx) out of bounds for vector of size \(elements.count)")
            }
            return elements[idx]

        case .sharedVector(let sa, _):
            guard args.count == 1
            else {
                throw EvaluatorError.invalidArgument(function: "vector",
                    message: "requires 1 argument, got \(args.count)")
            }
            guard case .integer(let idx) = args[0]
            else {
                throw EvaluatorError.invalidArgument(function: "vector",
                    message: "index must be an integer")
            }
            guard idx >= 0, idx < sa.elements.count
            else {
                throw EvaluatorError.invalidArgument(function: "vector",
                    message: "index \(idx) out of bounds for vector of size \(sa.elements.count)")
            }
            return sa.elements[idx]

        case .mapEntry(let k, let v):
            guard args.count == 1
            else {
                throw EvaluatorError.invalidArgument(function: "map-entry",
                    message: "requires 1 argument, got \(args.count)")
            }
            guard case .integer(let idx) = args[0], idx == 0 || idx == 1
            else {
                throw EvaluatorError.invalidArgument(function: "map-entry",
                    message: "index must be 0 or 1")
            }
            return idx == 0 ? k : v

        case .set(let ss):
            guard args.count == 1
            else {
                throw EvaluatorError.invalidArgument(function: "set",
                    message: "requires 1 argument, got \(args.count)")
            }
            return ss.elements.contains(args[0]) ? args[0] : .nil

        case .sortedSet(let elements, _):
            guard args.count == 1
            else {
                throw EvaluatorError.invalidArgument(function: "sorted-set",
                    message: "requires 1 argument, got \(args.count)")
            }
            return ((try? sortedSetContains(elements, args[0])) == true) ? args[0] : .nil

        case .transient(let tc):
            return try call(tc.value, args: args)

        case .symbol(let name, _):
            guard args.count == 1 || args.count == 2
            else {
                throw EvaluatorError.invalidArgument(function: "symbol",
                    message: "requires 1 or 2 arguments, got \(args.count)")
            }
            let notFound: Expr = args.count == 2 ? args[1] : .nil
            let sym = Expr.symbol(name, metadata: nil)
            switch args[0] {
            case .map(let sm):              return sm.dict[sym] ?? notFound
            case .sortedMap(let d, _):      return d[sym] ?? notFound
            case .set(let ss):              return ss.elements.contains(sym) ? sym : notFound
            case .sortedSet(let elems, _):  return ((try? sortedSetContains(elems, sym)) == true) ? sym : notFound
            default:                        return notFound
            }

        case .varRef(let v):
            guard let val = v.value else {
                throw EvaluatorError.unboundVar("\(v.namespace.name)/\(v.name)")
            }
            return try call(val, args: args)

        case .promise(let box):
            guard args.count == 1 else {
                throw EvaluatorError.invalidArgument(function: "promise", message: "requires exactly 1 argument, got \(args.count)")
            }
            return box.deliver(args[0]) ? callee : .nil

        default:
            throw EvaluatorError.notAFunction(callee)
        }
    }
}
