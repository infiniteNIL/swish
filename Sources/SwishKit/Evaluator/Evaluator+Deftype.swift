private let protocolImplsKey = Expr.keyword("impls")
private let protocolInlineImplsKey = Expr.keyword("inline-impls")

/// Reserved `data` keys stashing a `reify` instance's inline method table and
/// the set of protocol names it implements. Module-internal (not `private`) so
/// `CoreProtocol.swift`'s `reify-method-table` accessor and `satisfies?` can read
/// them. The `__swish_reify_*__` names are chosen to never collide with a user
/// protocol-method name (which are bare, unqualified keywords).
let reifyMethodsKey = Expr.keyword("__swish_reify_methods__")
let reifyProtocolsKey = Expr.keyword("__swish_reify_protocols__")

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
                let clause = Expr.list(elems.dropFirst(1), metadata: nil)
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
    func buildProtocolMethodImpls(_ methods: [ProtocolMethodImpl], in env: Environment, formName: String, fields: [String] = [], mutableFields: [String] = []) throws -> [Expr: Expr] {
        let methodsByName = Dictionary(grouping: methods, by: { $0.name })
        var result: [Expr: Expr] = [:]
        let outerLocals = env.allNames()
        for (methodName, clauses) in methodsByName {
            let arities = try clauses.map { clause -> FnArity in
                let arity = try buildFnArity(from: clause.clause, functionName: methodName, validateRecur: true, outerLocals: outerLocals.union(fields))
                guard !fields.isEmpty, let firstParam = arity.params.first else { return arity }
                return FnArity(params: arity.params, body: wrapWithFieldBindings(arity.body, firstParam: firstParam, fields: fields, mutableFields: mutableFields))
            }
            result[.keyword(methodName)] = arities.count == 1
                ? .function(SwishFunction(name: methodName, params: arities[0].params, body: arities[0].body, capturedEnv: env, metadata: nil))
                : .multiArityFunction(SwishMultiArityFunction(name: methodName, arities: arities, capturedEnv: env, metadata: nil))
        }
        return result
    }

    /// Injects a method body's implicit field access. Mutable fields are rewritten
    /// to go through the instance's storage box **live** (so a read after a `set!`
    /// in the same method sees the new value); immutable fields keep the cheaper
    /// snapshot `let` (correct because they never change, and — unlike mutable
    /// fields — they stay closable by nested `fn`s). The two field sets are disjoint,
    /// so the transforms don't interact.
    private func wrapWithFieldBindings(_ body: [Expr], firstParam: String, fields: [String], mutableFields: [String]) -> [Expr] {
        let mutableSet = Set(mutableFields)
        let rewritten = mutableSet.isEmpty
            ? body
            : body.map { substituteMutableFields($0, thisParam: firstParam, mutableFields: mutableSet, shadowed: []) }
        let immutableFields = fields.filter { !mutableSet.contains($0) }
        guard !immutableFields.isEmpty else { return rewritten }
        var letBindings: [Expr] = []
        for f in immutableFields {
            letBindings.append(.symbol(f, metadata: nil))
            letBindings.append(.list(
                [.symbol("deftype-field-value", metadata: nil), .symbol(firstParam, metadata: nil), .keyword(f)],
                metadata: nil))
        }
        return [.list(SwishPersistentList([.symbol("let", metadata: nil), .vector(SwishPersistentVector(letBindings), metadata: nil)] + rewritten), metadata: nil)]
    }

    /// Heads whose forms are *not* descended into when rewriting mutable-field access:
    /// nested closures (`fn`/`fn*`) — Clojure forbids mutable-field access from a
    /// closure, so leaving a bare field symbol there yields an `Undefined symbol` at
    /// runtime (its compile-time error's analog) — and quoted data (literal, not code).
    private static let mutableFieldBoundaryHeads: Set<String> = ["fn", "fn*", "quote", "syntax-quote"]

    /// Definition-time rewrite (run once per `deftype`, never per call — so no hot-path
    /// cost) of a method body so its mutable fields are read/written through the
    /// instance's `MutableFieldStore`:
    /// - a bare, non-shadowed mutable-field symbol → `(deftype-mutable-field-get this :f)`
    /// - `(set! f v)` on a non-shadowed mutable field → `(deftype-mutable-field-set! this :f v)`
    /// `let`/`loop` binding names shadow within their body (so an inner rebinding of a
    /// field name is respected); `fn`/`fn*`/`quote`/`syntax-quote` are hard boundaries.
    private func substituteMutableFields(_ expr: Expr, thisParam: String, mutableFields: Set<String>, shadowed: Set<String>) -> Expr {
        switch expr {
        case .symbol(let name, _):
            guard mutableFields.contains(name), !shadowed.contains(name) else { return expr }
            return mutableFieldGet(thisParam: thisParam, field: name)

        case .list(let elems, let meta):
            let elements = elems.elements
            guard let head = elements.first else { return expr }

            if case .symbol(let h, _) = head, Self.mutableFieldBoundaryHeads.contains(h) {
                return expr
            }

            if case .symbol("set!", _) = head, elements.count == 3,
               case .symbol(let target, _) = elements[1],
               mutableFields.contains(target), !shadowed.contains(target) {
                let newValue = substituteMutableFields(elements[2], thisParam: thisParam, mutableFields: mutableFields, shadowed: shadowed)
                return mutableFieldSet(thisParam: thisParam, field: target, value: newValue)
            }

            if case .symbol(let h, _) = head, h == "let" || h == "loop",
               elements.count >= 2, case .vector(let bindingVec, _) = elements[1] {
                return substituteBindingForm(head: head, bindingVec: bindingVec.elements, body: Array(elements.dropFirst(2)),
                                             meta: meta, thisParam: thisParam, mutableFields: mutableFields, shadowed: shadowed)
            }

            let mapped = elements.map { substituteMutableFields($0, thisParam: thisParam, mutableFields: mutableFields, shadowed: shadowed) }
            return .list(SwishPersistentList(mapped), metadata: meta)

        case .vector(let vec, let meta):
            let mapped = vec.elements.map { substituteMutableFields($0, thisParam: thisParam, mutableFields: mutableFields, shadowed: shadowed) }
            return .vector(SwishPersistentVector(mapped), metadata: meta)

        case .map(let sm):
            var newDict: [Expr: Expr] = [:]
            for (k, v) in sm.dict {
                let nk = substituteMutableFields(k, thisParam: thisParam, mutableFields: mutableFields, shadowed: shadowed)
                let nv = substituteMutableFields(v, thisParam: thisParam, mutableFields: mutableFields, shadowed: shadowed)
                newDict[nk] = nv
            }
            return .map(newDict, metadata: sm.metadata)

        case .set(let ss):
            let mapped = ss.elements.map { substituteMutableFields($0, thisParam: thisParam, mutableFields: mutableFields, shadowed: shadowed) }
            return .set(Set(mapped), metadata: ss.metadata)

        default:
            return expr
        }
    }

    /// Rewrites a `let`/`loop` form: each init expr is rewritten with the names bound
    /// by *prior* pairs shadowed (left-to-right, matching `let` scoping), then the body
    /// with all bound names shadowed. Binding *patterns* are left untouched (they're
    /// targets, not reads); a name that any pattern binds shadows the field within.
    private func substituteBindingForm(head: Expr, bindingVec: [Expr], body: [Expr], meta: [Expr: Expr]?,
                                       thisParam: String, mutableFields: Set<String>, shadowed: Set<String>) -> Expr {
        var newBindings: [Expr] = []
        var scope = shadowed
        var i = 0
        while i < bindingVec.count {
            let pattern = bindingVec[i]
            newBindings.append(pattern)
            if i + 1 < bindingVec.count {
                let initExpr = substituteMutableFields(bindingVec[i + 1], thisParam: thisParam, mutableFields: mutableFields, shadowed: scope)
                newBindings.append(initExpr)
            }
            scope.formUnion(collectBoundSymbols(pattern))
            i += 2
        }
        let newBody = body.map { substituteMutableFields($0, thisParam: thisParam, mutableFields: mutableFields, shadowed: scope) }
        let rebuilt = [head, .vector(SwishPersistentVector(newBindings), metadata: nil)] + newBody
        return .list(SwishPersistentList(rebuilt), metadata: meta)
    }

    /// Every symbol appearing anywhere in a binding pattern — conservatively (any
    /// symbol in a destructuring vector/map counts as bound). Over-collecting is the
    /// safe direction: it can only *stop* a field rewrite (→ a resolvable local or an
    /// `Undefined symbol`), never wrongly rewrite a genuinely-shadowed name.
    private func collectBoundSymbols(_ pattern: Expr) -> Set<String> {
        switch pattern {
        case .symbol(let name, _):
            return [name]

        case .vector(let vec, _):
            return vec.elements.reduce(into: Set<String>()) { $0.formUnion(collectBoundSymbols($1)) }

        case .map(let sm):
            var names: Set<String> = []
            for (k, v) in sm.dict {
                names.formUnion(collectBoundSymbols(k))
                names.formUnion(collectBoundSymbols(v))
            }
            return names

        default:
            return []
        }
    }

    private func mutableFieldGet(thisParam: String, field: String) -> Expr {
        .list(
            [.symbol("deftype-mutable-field-get", metadata: nil), .symbol(thisParam, metadata: nil), .keyword(field)],
            metadata: nil)
    }

    private func mutableFieldSet(thisParam: String, field: String, value: Expr) -> Expr {
        .list(
            [.symbol("deftype-mutable-field-set!", metadata: nil), .symbol(thisParam, metadata: nil), .keyword(field), value],
            metadata: nil)
    }

    /// The dispatch-key string for an already-evaluated "type value" argument, as
    /// passed to `extend`/`extend-type`/`extends?`/`instance?`. `nil` dispatches
    /// as `"nil"` (matching `Expr.nil.description`, and real Clojure's own
    /// `(extend nil Proto {...})` idiom); a `deftype`/`defrecord` bare type-var
    /// evaluates to `.keyword(qualifiedTypeName)`, and a built-in type name
    /// (`String`, `Int`, `Vector`, `Number`, ... — all bound to their dispatch
    /// keyword in `core.clj`) likewise evaluates to a `.keyword`. So any keyword
    /// is accepted here; only a genuinely non-type value throws.
    func dispatchTypeName(for atype: Expr, formName: String) throws -> String {
        switch atype {
        case .nil:
            return "nil"
        case .keyword(let k):
            return k
        default:
            throw EvaluatorError.invalidArgument(
                function: formName,
                message: "\(corePrinter.printString(atype)) is not a deftype/defrecord type, a built-in type name, or nil")
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
        if case .map(let existingImpls)? = currentProtoMap.dict[protocolImplsKey] {
            impls = existingImpls.dict.swiftDictionary
        }
        var inlineImpls: Set<Expr> = []
        if case .set(let existingInline)? = currentProtoMap.dict[protocolInlineImplsKey] {
            inlineImpls = Set(existingInline.elements)
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
        if case .map(let m)? = impls[typeKey] { existingMethods = m.dict.swiftDictionary }
        for (k, v) in methodImpls { existingMethods[k] = v }
        impls[typeKey] = .map(existingMethods, metadata: nil)
        if inline { inlineImpls.insert(typeKey) }

        var newProtoMap = currentProtoMap.dict
        newProtoMap[protocolImplsKey] = .map(impls, metadata: nil)
        newProtoMap[protocolInlineImplsKey] = .set(inlineImpls, metadata: nil)
        protoVar.value = .map(SwishMap(dict: newProtoMap, metadata: nil))
    }

    /// Parses `(formName TypeName [field ...] & opts+specs)`'s header and registers any
    /// trailing inline protocol implementations — shared by `deftype`/`defrecord`, which
    /// diverge only in what they build once the type is registered (deftype: one `.deftype`-
    /// wrapping ctor; defrecord: a `.record`-wrapping ctor plus a `map->` ctor).
    func parseTypeHeaderAndRegisterInlineProtocols(
        _ elements: [Expr], formName: String, usage: String, allowMutableFields: Bool, in env: Environment
    ) throws -> (typeName: String, fields: [String], mutableFields: [String], qualifiedName: String) {
        guard elements.count >= 3,
              case .symbol(let typeName, _) = elements[1],
              case .vector(let fieldExprs, _) = elements[2]
        else {
            throw EvaluatorError.invalidArgument(function: formName, message: usage)
        }
        var fields: [String] = []
        var mutableFields: [String] = []
        for fieldExpr in fieldExprs.elements {
            guard case .symbol(let name, let meta) = fieldExpr else {
                throw EvaluatorError.invalidArgument(function: formName, message: "fields must be symbols")
            }
            fields.append(name)
            // Only `deftype` honors `^:unsynchronized-mutable`/`^:volatile-mutable`
            // (`defrecord` passes `allowMutableFields: false` — Clojure forbids mutable
            // record fields).
            if allowMutableFields, fieldIsMutable(meta) {
                mutableFields.append(name)
            }
        }
        let qualifiedName = "\(currentNs().name)/\(typeName)"

        let groups = try parseProtocolImplGroups(Array(elements.dropFirst(3)), formName: formName)
        for group in groups {
            let protoValue = try eval(group.leadingSymbol, in: env)
            let methodImpls = try buildProtocolMethodImpls(group.methods, in: env, formName: formName, fields: fields, mutableFields: mutableFields)
            try registerProtocolImpl(protoValue: protoValue, typeName: qualifiedName, methodImpls: methodImpls, inline: true, formName: formName)
        }

        return (typeName, fields, mutableFields, qualifiedName)
    }

    /// True if a field symbol's metadata marks it `^:unsynchronized-mutable` or
    /// `^:volatile-mutable` (Clojure's two mutable-field annotations). `^:kw x`
    /// reads as `{:kw true}`, so a truthy value under either key suffices.
    private func fieldIsMutable(_ metadata: [Expr: Expr]?) -> Bool {
        guard let metadata else { return false }
        for key in ["unsynchronized-mutable", "volatile-mutable"] {
            if let v = metadata[.keyword(key)], v != .nil, v != .boolean(false) {
                return true
            }
        }
        return false
    }

    /// `(deftype Name [fields...] Protocol1 (method [this a] body)... ...)`.
    /// Field mutability annotations (`^:unsynchronized-mutable`/`^:volatile-mutable`)
    /// are honored: such a field is stored in a per-instance `MutableFieldStore`
    /// (reference identity ⇒ Clojure's object semantics), its method-body reads/`set!`
    /// are rewritten to go through that box (`wrapWithFieldBindings`), and the presence
    /// of any mutable field flips the instance to identity `=`/hash. Immutable fields
    /// stay in the value-type `data`. See CLAUDE.md.
    func evalDeftype(_ elements: [Expr], in env: Environment) throws -> Expr {
        let (typeName, fields, mutableFields, qualifiedName) = try parseTypeHeaderAndRegisterInlineProtocols(
            elements, formName: "deftype",
            usage: "expected (deftype TypeName [field ...] & opts+specs)", allowMutableFields: true, in: env)

        let mutableSet = Set(mutableFields)
        let positionalCtor: @Sendable ([Expr]) throws -> Expr = { [fields, qualifiedName, typeName, mutableSet] args in
            guard args.count == fields.count else {
                throw EvaluatorError.noMatchingArity(name: typeName, got: args.count)
            }
            var data: [Expr: Expr] = [:]
            var mutableValues: [String: Expr] = [:]
            for (f, v) in zip(fields, args) {
                if mutableSet.contains(f) {
                    mutableValues[f] = v
                }
                else {
                    data[.keyword(f)] = v
                }
            }
            // A fresh box per instance ⇒ fresh identity; `nil` when no mutable fields.
            let box = mutableSet.isEmpty ? nil : MutableFieldStore(mutableValues)
            return .deftype(typeName: qualifiedName, fields: fields, data: data, mutableStorage: box, metadata: nil)
        }

        let ns = currentNs()
        let arrowName = "->\(typeName)"
        ns.intern(name: arrowName, value: .nativeFunction(name: arrowName, arity: .fixed(fields.count), body: positionalCtor))
        ns.intern(name: typeName, value: .keyword(qualifiedName))

        return .symbol(qualifiedName, metadata: nil)
    }

    /// `(reify Protocol1 (m1 [this a] body)... Protocol2 (m2 [this] body)...)`.
    /// Creates one anonymous instance implementing the given protocols. Unlike
    /// `deftype`, a reify method body closes over the surrounding lexical
    /// environment — which comes for free because `buildProtocolMethodImpls`
    /// builds each method as a `SwishFunction` with `capturedEnv: env`, and we
    /// pass the *local* `env` here. The instance is represented as an anonymous
    /// `.deftype` (unique gensym name, no fields) carrying its own method table
    /// and implemented-protocol set inline in `data` — no registration into any
    /// protocol's `:impls`, since reify methods capture per-evaluation locals and
    /// so can't share a type-name-keyed entry across evaluations. Only Swish
    /// protocols are supported (no Object/interface methods — no JVM classes).
    /// See CLAUDE.md.
    func evalReify(_ elements: [Expr], in env: Environment) throws -> Expr {
        let groups = try parseProtocolImplGroups(Array(elements.dropFirst(1)), formName: "reify")
        var methodTable: [Expr: Expr] = [:]
        var protocolNames: Set<Expr> = []
        for group in groups {
            let protoValue = try eval(group.leadingSymbol, in: env)
            guard case .map(let protoMap) = protoValue,
                  case .symbol(let pname, _)? = protoMap.dict[.keyword("name")]
            else {
                throw EvaluatorError.invalidArgument(function: "reify",
                    message: "\(corePrinter.printString(group.leadingSymbol)) is not a protocol")
            }
            protocolNames.insert(.string(pname))
            let impls = try buildProtocolMethodImpls(group.methods, in: env, formName: "reify")
            for (k, v) in impls { methodTable[k] = v }
        }
        let typeName = gensym(prefix: "reify__")
        let data: [Expr: Expr] = [
            reifyMethodsKey: .map(methodTable, metadata: nil),
            reifyProtocolsKey: .set(protocolNames, metadata: nil),
        ]
        return .deftype(typeName: typeName, fields: [], data: data, mutableStorage: nil, metadata: nil)
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
