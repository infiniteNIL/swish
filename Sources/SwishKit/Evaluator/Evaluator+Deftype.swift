extension Evaluator {
    /// One parsed method implementation clause. `clause` is `([params] body...)` —
    /// the same shape `buildFnArity` (used by `fn`/`defn`) already expects, so
    /// method bodies get the exact same alias-expansion/destructuring/recur-tail
    /// validation as ordinary functions.
    struct ProtocolMethodImpl {
        let name: String
        let clause: Expr
    }

    /// One protocol-name-followed-by-its-method-clauses group, as found trailing
    /// `deftype`/`defrecord` forms — or, for `extend-protocol`, one type-name-
    /// followed-by-its-method-clauses group (the grouping shape is identical,
    /// only the meaning of the leading symbol differs).
    struct ProtocolImplGroup {
        let leadingSymbol: Expr
        let methods: [ProtocolMethodImpl]
    }

    /// Groups a flat trailing-forms list — e.g. `Protocol1 (m1 [this a] body) (m2 [this] body) Protocol2 (m3 [this] body)`
    /// — into groups keyed by the leading symbol. Shared by `deftype`, the
    /// `defrecord` retrofit, and `extend-type`/`extend-protocol`.
    func parseProtocolImplGroups(_ trailingForms: [Expr], formName: String) throws -> [ProtocolImplGroup] {
        var groups: [ProtocolImplGroup] = []
        var i = 0
        while i < trailingForms.count {
            guard case .symbol = trailingForms[i] else {
                throw EvaluatorError.invalidArgument(
                    function: formName, message: "expected a name, got \(corePrinter.printString(trailingForms[i]))")
            }
            let leadingSymbol = trailingForms[i]
            i += 1
            var methods: [ProtocolMethodImpl] = []
            while i < trailingForms.count, case .list(let elems, _) = trailingForms[i],
                  elems.count >= 2, case .symbol(let methodName, _) = elems[0], case .vector = elems[1] {
                let clause = Expr.list(Array(elems.dropFirst(1)), metadata: nil)
                methods.append(ProtocolMethodImpl(name: methodName, clause: clause))
                i += 1
            }
            groups.append(ProtocolImplGroup(leadingSymbol: leadingSymbol, methods: methods))
        }
        return groups
    }

    /// Builds `{method-name-keyword -> impl}` from a group's method clauses,
    /// grouping same-named clauses (multiple arities of one method) into a
    /// `.multiArityFunction`, matching `fn`'s own multi-arity handling.
    ///
    /// `fields`, when non-empty, injects unqualified field access into each
    /// arity's body — `(let [field1 (deftype-field-value this :field1) ...] body)`
    /// ahead of the original body — matching real Clojure's deftype/defrecord
    /// semantics where a type's own method bodies can reference its fields
    /// directly. Only the *inline* (deftype/defrecord's own trailing clauses)
    /// case passes `fields`; `extend-type`/`extend-protocol` don't (matching real
    /// Clojure, where only a type's own compiled methods get direct field access —
    /// retroactive `extend-type` methods don't).
    func buildProtocolMethodImpls(_ methods: [ProtocolMethodImpl], in env: Environment, formName: String, fields: [String] = []) throws -> [Expr: Expr] {
        let methodsByName = Dictionary(grouping: methods, by: { $0.name })
        var result: [Expr: Expr] = [:]
        let outerLocals = env.allNames()
        for (methodName, clauses) in methodsByName {
            let arities = try clauses.map { clause -> FnArity in
                let arity = try buildFnArity(from: clause.clause, functionName: methodName, validateRecur: true, outerLocals: outerLocals)
                guard !fields.isEmpty, let firstParam = arity.params.first else { return arity }
                return FnArity(params: arity.params, body: wrapWithFieldBindings(arity.body, firstParam: firstParam, fields: fields))
            }
            result[.keyword(methodName)] = arities.count == 1
                ? .function(SwishFunction(name: methodName, params: arities[0].params, body: arities[0].body, capturedEnv: env, metadata: nil))
                : .multiArityFunction(SwishMultiArityFunction(name: methodName, arities: arities, capturedEnv: env, metadata: nil))
        }
        return result
    }

    private func wrapWithFieldBindings(_ body: [Expr], firstParam: String, fields: [String]) -> [Expr] {
        var letBindings: [Expr] = []
        for f in fields {
            letBindings.append(.symbol(f, metadata: nil))
            letBindings.append(.list(
                [.symbol("deftype-field-value", metadata: nil), .symbol(firstParam, metadata: nil), .keyword(f)],
                metadata: nil))
        }
        return [.list([.symbol("let", metadata: nil), .vector(letBindings, metadata: nil)] + body, metadata: nil)]
    }

    /// The dispatch-key string for an already-evaluated "type value" argument, as
    /// passed to `extend`/`extend-type`/`extends?`/`instance?`. `nil` dispatches
    /// as `"nil"` (matching `Expr.nil.description`, and real Clojure's own
    /// `(extend nil Proto {...})` idiom); a `deftype`/`defrecord` bare type-var
    /// evaluates to `.keyword(qualifiedTypeName)`. Built-in Swish types have no
    /// first-class type value to extend onto — deferred, see CLAUDE.md.
    func dispatchTypeName(for atype: Expr, formName: String) throws -> String {
        switch atype {
        case .nil:
            return "nil"
        case .keyword(let k):
            return k
        default:
            throw EvaluatorError.invalidArgument(
                function: formName,
                message: "\(corePrinter.printString(atype)) is not a deftype/defrecord type or nil — extending built-in Swish types is not yet supported")
        }
    }

    /// Registers `methodImpls` as `typeName`'s implementation of `protoValue`'s
    /// protocol, mutating the protocol var directly (`Var.value` is a plain
    /// mutable property — no need to round-trip through the `alter-var-root`
    /// native function for the same effect). Throws if `typeName` already has an
    /// *inline*-declared implementation of this protocol — mirrors real Clojure's
    /// `extend` "already directly implements" check, which only fires for
    /// inline-vs-{inline,extend} conflicts, never extend-over-extend.
    func registerProtocolImpl(protoValue: Expr, typeName: String, methodImpls: [Expr: Expr], inline: Bool, formName: String) throws {
        guard case .map(let protoMap) = protoValue,
              case .varRef(let protoVar)? = protoMap.dict[.keyword("var")],
              case .map(let currentProtoMap)? = protoVar.value
        else {
            throw EvaluatorError.invalidArgument(
                function: formName, message: "\(corePrinter.printString(protoValue)) is not a protocol")
        }

        var impls: [Expr: Expr] = [:]
        if case .map(let existingImpls)? = currentProtoMap.dict[.keyword("impls")] {
            impls = existingImpls.dict
        }
        var inlineImpls: Set<Expr> = []
        if case .set(let existingInline)? = currentProtoMap.dict[.keyword("inline-impls")] {
            inlineImpls = existingInline.elements
        }

        let typeKey = Expr.keyword(typeName)
        if inlineImpls.contains(typeKey) {
            var protoName = "protocol"
            if case .symbol(let n, _)? = currentProtoMap.dict[.keyword("name")] { protoName = n }
            throw EvaluatorError.invalidArgument(
                function: formName,
                message: "\(typeName) already directly implements #'\(protoName) for protocol:\(protoName)")
        }

        var existingMethods: [Expr: Expr] = [:]
        if case .map(let m)? = impls[typeKey] { existingMethods = m.dict }
        for (k, v) in methodImpls { existingMethods[k] = v }
        impls[typeKey] = .map(existingMethods, metadata: nil)
        if inline { inlineImpls.insert(typeKey) }

        var newProtoMap = currentProtoMap.dict
        newProtoMap[.keyword("impls")] = .map(impls, metadata: nil)
        newProtoMap[.keyword("inline-impls")] = .set(inlineImpls, metadata: nil)
        protoVar.value = .map(newProtoMap, metadata: nil)
    }

    /// `(deftype Name [fields...] Protocol1 (method [this a] body)... ...)`.
    /// Field mutability annotations (`^:unsynchronized-mutable`/`^:volatile-mutable`)
    /// are accepted (already ignored, same as any other symbol metadata) but have
    /// no effect — mutable fields need a `set!` special form Swish doesn't have
    /// yet, see CLAUDE.md.
    func evalDeftype(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard elements.count >= 3,
              case .symbol(let typeName, _) = elements[1],
              case .vector(let fieldExprs, _) = elements[2]
        else {
            throw EvaluatorError.invalidArgument(
                function: "deftype", message: "expected (deftype TypeName [field ...] & opts+specs)")
        }
        let fields: [String] = try fieldExprs.map {
            guard case .symbol(let name, _) = $0 else {
                throw EvaluatorError.invalidArgument(function: "deftype", message: "fields must be symbols")
            }
            return name
        }
        let qualifiedName = "\(currentNs().name)/\(typeName)"

        let groups = try parseProtocolImplGroups(Array(elements.dropFirst(3)), formName: "deftype")
        for group in groups {
            let protoValue = try eval(group.leadingSymbol, in: env)
            let methodImpls = try buildProtocolMethodImpls(group.methods, in: env, formName: "deftype", fields: fields)
            try registerProtocolImpl(protoValue: protoValue, typeName: qualifiedName, methodImpls: methodImpls, inline: true, formName: "deftype")
        }

        let positionalCtor: @Sendable ([Expr]) throws -> Expr = { [fields, qualifiedName, typeName] args in
            guard args.count == fields.count else {
                throw EvaluatorError.noMatchingArity(name: typeName, got: args.count)
            }
            var data: [Expr: Expr] = [:]
            for (f, v) in zip(fields, args) { data[.keyword(f)] = v }
            return .deftype(typeName: qualifiedName, fields: fields, data: data, metadata: nil)
        }

        let ns = currentNs()
        let arrowName = "->\(typeName)"
        ns.intern(name: arrowName, value: .nativeFunction(name: arrowName, arity: .fixed(fields.count), body: positionalCtor))
        ns.intern(name: typeName, value: .keyword(qualifiedName))

        return .symbol(qualifiedName, metadata: nil)
    }

    /// `(extend-type AType Protocol1 (method [this] body)... Protocol2 (method2 [this] body)...)`.
    func evalExtendType(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard elements.count >= 2 else {
            throw EvaluatorError.invalidArgument(
                function: "extend-type", message: "expected (extend-type AType Protocol (method [args] body) ...)")
        }
        let atype = try eval(elements[1], in: env)
        let typeName = try dispatchTypeName(for: atype, formName: "extend-type")
        let groups = try parseProtocolImplGroups(Array(elements.dropFirst(2)), formName: "extend-type")
        for group in groups {
            let protoValue = try eval(group.leadingSymbol, in: env)
            let methodImpls = try buildProtocolMethodImpls(group.methods, in: env, formName: "extend-type")
            try registerProtocolImpl(protoValue: protoValue, typeName: typeName, methodImpls: methodImpls, inline: false, formName: "extend-type")
        }
        return .nil
    }

    /// `(extend-protocol Protocol AType1 (method [this] body)... AType2 (method [this] body)...)`.
    func evalExtendProtocol(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard elements.count >= 2 else {
            throw EvaluatorError.invalidArgument(
                function: "extend-protocol", message: "expected (extend-protocol Protocol AType (method [args] body) ...)")
        }
        let protoValue = try eval(elements[1], in: env)
        let groups = try parseProtocolImplGroups(Array(elements.dropFirst(2)), formName: "extend-protocol")
        for group in groups {
            let atype = try eval(group.leadingSymbol, in: env)
            let typeName = try dispatchTypeName(for: atype, formName: "extend-protocol")
            let methodImpls = try buildProtocolMethodImpls(group.methods, in: env, formName: "extend-protocol")
            try registerProtocolImpl(protoValue: protoValue, typeName: typeName, methodImpls: methodImpls, inline: false, formName: "extend-protocol")
        }
        return .nil
    }
}
