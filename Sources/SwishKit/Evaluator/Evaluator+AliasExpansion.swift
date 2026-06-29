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
            if case .symbol("fn", _) = head { return expandFnForm(elements, outerLocals: locals, listMeta: listMeta) }
            if case .symbol("let", _) = head { return expandLetForm(elements, outerLocals: locals, listMeta: listMeta) }
            if case .symbol("loop", _) = head { return expandLetForm(elements, outerLocals: locals, listMeta: listMeta) }
            return .list(elements.map { expandAliasesInExpr($0, locals: locals) }, metadata: listMeta)

        case .vector(let elements, let vecMeta):
            return .vector(elements.map { expandAliasesInExpr($0, locals: locals) }, metadata: vecMeta)

        case .map(let dict, let mapMeta):
            return transformMap(dict, metadata: mapMeta) { expandAliasesInExpr($0, locals: locals) }

        case .set(let elements, let setMeta):
            var result: Set<Expr> = []
            for element in elements {
                result.insert(expandAliasesInExpr(element, locals: locals))
            }
            return .set(result, metadata: setMeta)

        case .sortedSet(let elements, let setMeta):
            return .sortedSet(elements.map { expandAliasesInExpr($0, locals: locals) }, metadata: setMeta)

        default:
            return expr
        }
    }

    private func expandFnForm(_ elements: [Expr], outerLocals: Set<String>, listMeta: [Expr: Expr]? = nil) -> Expr {
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
                result.append(.list([clauseElems[0]] + expandedBody, metadata: clauseMeta))
            }
            return .list(result, metadata: listMeta)
        }
        var newLocals = baseLocals
        if offset < elements.count, case .vector(let paramExprs, _) = elements[offset] {
            for p in paramExprs { newLocals.formUnion(collectLocalNames(p)) }
        }
        var result = Array(elements.prefix(offset + 1))
        result += Array(elements.dropFirst(offset + 1)).map { expandAliasesInExpr($0, locals: newLocals) }
        return .list(result, metadata: listMeta)
    }

    private func expandLetForm(_ elements: [Expr], outerLocals: Set<String>, listMeta: [Expr: Expr]? = nil) -> Expr {
        guard elements.count >= 2, case .vector(let bindings, let bindVecMeta) = elements[1]
        else {
            return .list(elements.map { expandAliasesInExpr($0, locals: outerLocals) }, metadata: listMeta)
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
        return .list([elements[0], .vector(newBindings, metadata: bindVecMeta)] + body, metadata: listMeta)
    }
}
