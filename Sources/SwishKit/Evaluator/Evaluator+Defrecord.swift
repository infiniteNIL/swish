extension Evaluator {
    func evalDefrecord(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard elements.count >= 3,
              case .symbol(let typeName, _) = elements[1],
              case .vector(let fieldExprs, _) = elements[2]
        else {
            throw EvaluatorError.invalidArgument(
                function: "defrecord",
                message: "expected (defrecord TypeName [field ...])")
        }
        let fields: [String] = try fieldExprs.map {
            guard case .symbol(let name, _) = $0 else {
                throw EvaluatorError.invalidArgument(
                    function: "defrecord", message: "fields must be symbols")
            }
            return name
        }
        let qualifiedName = "\(currentNs().name)/\(typeName)"

        let positionalCtor: @Sendable ([Expr]) throws -> Expr = { [fields, qualifiedName, typeName] args in
            guard args.count == fields.count else {
                throw EvaluatorError.noMatchingArity(name: typeName, got: args.count)
            }
            var data: [Expr: Expr] = [:]
            for (f, v) in zip(fields, args) { data[.keyword(f)] = v }
            return .record(typeName: qualifiedName, fields: fields, data: data, metadata: nil)
        }

        let mapCtor: @Sendable ([Expr]) throws -> Expr = { [fields, qualifiedName, typeName] args in
            guard args.count == 1, case .map(let dict, _) = args[0] else {
                throw EvaluatorError.invalidArgument(
                    function: "map->\(typeName)", message: "requires a single map")
            }
            var data: [Expr: Expr] = [:]
            for f in fields { data[.keyword(f)] = dict[.keyword(f)] ?? .nil }
            return .record(typeName: qualifiedName, fields: fields, data: data, metadata: nil)
        }

        let ns = currentNs()
        let dotName = "\(typeName)."
        ns.intern(name: dotName,
                  value: .nativeFunction(name: dotName, arity: .fixed(fields.count), body: positionalCtor))
        let arrowName = "->\(typeName)"
        ns.intern(name: arrowName,
                  value: .nativeFunction(name: arrowName, arity: .fixed(fields.count), body: positionalCtor))
        let mapArrowName = "map->\(typeName)"
        ns.intern(name: mapArrowName,
                  value: .nativeFunction(name: mapArrowName, arity: .fixed(1), body: mapCtor))

        return .symbol(qualifiedName, metadata: nil)
    }
}
