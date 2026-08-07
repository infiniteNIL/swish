extension Evaluator {

    // MARK: - Alias expansion

    func expandAliases(in forms: [Expr], locals: Set<String> = []) -> [Expr] {
        forms.map { expandAliasesInExpr($0, locals: locals) }
    }

    private func expandAliasesInExpr(_ expr: Expr, locals: Set<String> = []) -> Expr {
        switch expr {
        case .symbol(let name, let symMeta):
            if locals.contains(name) { return expr }
            if let (nsAlias, varName) = splitQualified(name),
               let ns = currentNs().findAlias(nsAlias) {
                return .symbol("\(ns.name)/\(varName)", metadata: symMeta)
            }
            if !name.contains("/"), let v = resolveVar(name: name, in: currentNs()) {
                return .symbol("\(v.namespace.name)/\(v.name)", metadata: symMeta)
            }
            return expr

        case .list(let elements, let listMeta):
            guard let head = elements.first
            else { return expr }
            if case .symbol("quote", _) = head { return expr }
            if case .symbol("syntax-quote", _) = head { return expr }
            // case's clauses mix literal, unevaluated test-constants (like quote's content)
            // with genuine code (the dispatch expr and result exprs) — unlike every other
            // macro's arguments, which are ordinary code throughout (e.g. cond, when, ->),
            // so case can't be blindly recursed into like they can. Treat it like quote:
            // leave it untouched here and let its own, separate macro-expansion path
            // (which understands its own clause structure) resolve everything correctly
            // when it actually runs.
            if case .symbol("case", _) = head { return expr }
            if case .symbol("fn", _) = head { return expandFnForm(elements, outerLocals: locals, listMeta: listMeta) }
            if case .symbol("let", _) = head { return expandLetForm(elements, outerLocals: locals, listMeta: listMeta) }
            if case .symbol("loop", _) = head { return expandLetForm(elements, outerLocals: locals, listMeta: listMeta) }
            if case .symbol("reify", _) = head { return expandReifyForm(elements, outerLocals: locals, listMeta: listMeta) }
            return .list(SwishPersistentList(elements.map { expandAliasesInExpr($0, locals: locals) }), metadata: listMeta)

        default:
            return expr.mappingChildren { expandAliasesInExpr($0, locals: locals) }
        }
    }

    private func expandFnForm(_ elements: SwishPersistentList, outerLocals: Set<String>, listMeta: [Expr: Expr]? = nil) -> Expr {
        var offset = 1
        var fnName: String? = nil
        if elements.count > 2, case .symbol(let n, _) = elements[1] {
            let next = elements[2]
            if case .vector = next { offset = 2; fnName = n }
            else if case .list = next { offset = 2; fnName = n }
        }
        // Include fn name so recursive self-calls aren't expanded to qualified globals.
        var baseLocals = outerLocals
        if let n = fnName { baseLocals.insert(n) }

        if offset < elements.count, case .list = elements[offset] {
            var result = Array(elements.prefix(offset))
            for clause in elements.dropFirst(offset) {
                guard case .list(let clauseElems, let clauseMeta) = clause,
                      !clauseElems.isEmpty,
                      case .vector(let paramExprs, _) = clauseElems[0]
                else { result.append(clause); continue }
                var clauseLocals = baseLocals
                for p in paramExprs { clauseLocals.formUnion(collectLocalNames(p)) }
                let expandedBody = Array(clauseElems.dropFirst()).map { expandAliasesInExpr($0, locals: clauseLocals) }
                result.append(.list(SwishPersistentList([clauseElems[0]] + expandedBody), metadata: clauseMeta))
            }
            return .list(SwishPersistentList(result), metadata: listMeta)
        }
        var newLocals = baseLocals
        if offset < elements.count, case .vector(let paramExprs, _) = elements[offset] {
            for p in paramExprs { newLocals.formUnion(collectLocalNames(p)) }
        }
        var result = Array(elements.prefix(offset + 1))
        result += Array(elements.dropFirst(offset + 1)).map { expandAliasesInExpr($0, locals: newLocals) }
        return .list(SwishPersistentList(result), metadata: listMeta)
    }

    /// `(reify Protocol (mname [params] body...) ... Protocol2 (m2 [params] body...))`.
    /// Qualify the leading protocol symbols (so they resolve even when the reify
    /// literal is later evaluated from another namespace), but leave each method
    /// clause `(mname [params] body...)` untouched — its `mname` is a method name,
    /// not a call, and its body is (re)expanded with the correct locals by
    /// `buildProtocolMethodImpls` at reify-eval time (`evalReify`). Recursing into
    /// a method clause uniformly (as the generic list case does) would wrongly
    /// qualify `mname` to `ns/mname`, so the per-instance method table would be
    /// keyed under a qualified name while `protocol-dispatch` looks up the bare
    /// keyword — a dispatch miss. This mirrors the same care `fn`/`let`/`case` take.
    private func expandReifyForm(_ elements: SwishPersistentList, outerLocals: Set<String>, listMeta: [Expr: Expr]? = nil) -> Expr {
        var result: [Expr] = [elements[0]]
        for el in elements.dropFirst() {
            if case .list = el {
                result.append(el)
            }
            else {
                result.append(expandAliasesInExpr(el, locals: outerLocals))
            }
        }
        return .list(SwishPersistentList(result), metadata: listMeta)
    }

    private func expandLetForm(_ elements: SwishPersistentList, outerLocals: Set<String>, listMeta: [Expr: Expr]? = nil) -> Expr {
        guard elements.count >= 2, case .vector(let bindings, let bindVecMeta) = elements[1]
        else {
            return .list(SwishPersistentList(elements.map { expandAliasesInExpr($0, locals: outerLocals) }), metadata: listMeta)
        }
        var newLocals = outerLocals
        var newBindings: [Expr] = []
        var i = 0
        while i + 1 < bindings.count {
            newBindings.append(bindings[i])
            newBindings.append(expandAliasesInExpr(bindings[i + 1], locals: newLocals))
            newLocals.formUnion(collectLocalNames(bindings[i]))
            i += 2
        }
        let body = Array(elements.dropFirst(2)).map { expandAliasesInExpr($0, locals: newLocals) }
        return .list(SwishPersistentList([elements[0], .vector(SwishPersistentVector(newBindings), metadata: bindVecMeta)] + body), metadata: listMeta)
    }
}
