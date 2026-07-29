extension Evaluator {

    // MARK: - fn / defmacro

    /// `expandMacros` pre-expands all macro calls in the body once, here at
    /// definition time (see `macroexpandAll`), so a macro inside a hot loop /
    /// lazy-seq body isn't re-expanded on every evaluation. It's `true` for
    /// `fn`/`defn`/`deftype`-method bodies (ordinary code) and **`false`** for a
    /// `defmacro`'s body (a template that must stay unexpanded — see
    /// `evalDefmacro`).
    func buildFnArity(from clause: Expr, functionName: String, validateRecur: Bool,
                      outerLocals: Set<String> = [], expandMacros: Bool = true) throws -> FnArity {
        guard case .list(let elems, _) = clause, !elems.isEmpty,
              case .vector(let paramExprs, _) = elems[0]
        else {
            throw EvaluatorError.invalidArgument(function: functionName, message: "invalid arity clause")
        }
        let (params, destructuredBody) = expandDestructuredParams(paramExprs.elements, body: Array(elems.dropFirst()))
        // Validate recur on the UN-expanded body — `validateRecurTailPosition` is
        // macro-aware (treats `when`/`cond`/… tails as tail positions), so it must
        // see the source forms, not the expansion (which relocates those tails into
        // `if`/`let` and would trip the check). Macros never introduce `recur`, so
        // validating first and expanding after is equivalent and safe.
        if validateRecur { try validateRecurTailPosition(in: destructuredBody) }
        // Pre-expand macros once, here, so a macro inside a hot loop / lazy-seq
        // body isn't re-expanded on every evaluation.
        let rawBody = expandMacros ? try destructuredBody.map { try macroexpandAll($0) } : destructuredBody
        let allLocals = collectAllParamLocals(paramExprs.elements).union(outerLocals)
        return FnArity(params: params, body: expandAliases(in: rawBody, locals: allLocals))
    }

    func evalFn(_ elements: [Expr], in env: Environment) throws -> Expr {
        var offset = 1
        var name: String? = nil
        if elements.count > 2, case .symbol(let n, _) = elements[1] {
            let next = elements[2]
            if case .vector = next { name = n; offset = 2 }
            else if case .list = next { name = n; offset = 2 }
        }
        let remaining = Array(elements.dropFirst(offset))
        if let first = remaining.first, case .list = first {
            let outerLocals = env.allNames()
            let arities = try remaining.map { try buildFnArity(from: $0, functionName: "fn", validateRecur: true, outerLocals: outerLocals) }
            return .multiArityFunction(SwishMultiArityFunction(name: name, arities: arities, capturedEnv: env, metadata: nil))
        }
        let arity = try buildFnArity(from: .list(SwishPersistentList(remaining), metadata: nil), functionName: "fn",
            validateRecur: true, outerLocals: env.allNames())
        return .function(SwishFunction(name: name, params: arity.params, body: arity.body, capturedEnv: env, metadata: nil))
    }

    func evalDefmacro(_ elements: [Expr]) throws -> Expr {
        guard elements.count >= 3, case .symbol(let name, let symMeta) = elements[1]
        else {
            throw EvaluatorError.invalidArgument(function: "defmacro", message: "invalid syntax")
        }
        let (docString, attrMap, idx) = extractDocAndAttr(elements, startingAt: 2)
        guard idx < elements.count else {
            throw EvaluatorError.invalidArgument(function: "defmacro", message: "invalid syntax")
        }
        var meta = buildMeta(from: symMeta, attrMap: attrMap, docString: docString)
        let restElems = Array(elements.dropFirst(idx))
        if meta[.keyword("arglists")] == nil {
            if case .vector(let paramExprs, _) = restElems.first {
                meta[.keyword("arglists")] = .list([.vector(paramExprs, metadata: nil)], metadata: nil)
            }
            else {
                let vecs = restElems.compactMap { form -> Expr? in
                    guard case .list(let parts, _) = form, case .vector(let p, _) = parts.first else { return nil }
                    return .vector(p, metadata: nil)
                }
                if !vecs.isEmpty { meta[.keyword("arglists")] = .list(SwishPersistentList(vecs), metadata: nil) }
            }
        }
        let macroMeta: [Expr: Expr]? = meta.isEmpty ? nil : meta
        // Pre-qualify syntax-quote templates using the current (defining) namespace.
        // This matches Clojure's compile-time syntax-quote behavior.
        let expandedRestElems = preExpandSyntaxQuotesInBody(restElems)
        let macroValue: Expr
        switch expandedRestElems.first {
        case .vector(let paramExprs, _):
            let params = extractParamNames(paramExprs.elements)
            let rawBody = Array(expandedRestElems.dropFirst())
            macroValue = .macro(name: name, params: params,
                                body: expandAliases(in: rawBody, locals: Set(params)),
                                metadata: macroMeta)
        case .list:
            let arities = try expandedRestElems.map {
                // expandMacros: false — a macro's body is a template, not code to
                // pre-expand.
                try buildFnArity(from: $0, functionName: "defmacro", validateRecur: false, expandMacros: false)
            }
            macroValue = .multiArityMacro(name: name, arities: arities, metadata: macroMeta)
        default:
            throw EvaluatorError.invalidArgument(function: "defmacro", message: "invalid syntax")
        }
        let v = currentNs().intern(name: name, value: macroValue)
        v.metadata = macroMeta
        return .symbol(name, metadata: nil)
    }
}
