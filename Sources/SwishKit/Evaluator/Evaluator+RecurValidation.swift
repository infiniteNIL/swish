extension Evaluator {

    // MARK: - Recur tail-position validation

    func validateRecurTailPosition(in body: [Expr]) throws {
        try validateTailForms(body)
    }

    private func validateTailForms(_ forms: [Expr]) throws {
        for form in forms.dropLast() {
            if recurAppears(in: form) { throw EvaluatorError.recurNotInTailPosition }
        }
        if let last = forms.last { try validateTailExpr(last) }
    }

    private func validateTailExpr(_ expr: Expr) throws {
        guard case .list(let elements, _) = expr, !elements.isEmpty else {
            if recurAppears(in: expr) { throw EvaluatorError.recurNotInTailPosition }
            return
        }
        switch elements[0] {
        case .symbol("recur", _):
            return

        case .symbol("if", _):
            if elements.count > 1, recurAppears(in: elements[1]) {
                throw EvaluatorError.recurNotInTailPosition
            }
            if elements.count > 2 { try validateTailExpr(elements[2]) }
            if elements.count > 3 { try validateTailExpr(elements[3]) }

        case .symbol("do", _):
            try validateTailForms(Array(elements.dropFirst()))

        case .symbol("let", _):
            if elements.count > 1, case .vector(let bindings, _) = elements[1] {
                for i in stride(from: 1, to: bindings.count, by: 2) {
                    if recurAppears(in: bindings[i]) { throw EvaluatorError.recurNotInTailPosition }
                }
            }
            try validateTailForms(Array(elements.dropFirst(2)))

        case .symbol("fn", _), .symbol("loop", _):
            return

        case .symbol(let name, _):
            let resolved = (try? resolveQualifiedVar(name: name)) ?? resolveVar(name: name, in: currentNs())
            if let v = resolved?.value {
                switch v {
                case .macro, .multiArityMacro: return
                default: break
                }
            }
            for element in elements where recurAppears(in: element) {
                throw EvaluatorError.recurNotInTailPosition
            }

        default:
            for element in elements where recurAppears(in: element) {
                throw EvaluatorError.recurNotInTailPosition
            }
        }
    }

    private func recurAppears(in expr: Expr) -> Bool {
        switch expr {
        case .list(let elements, _):
            guard !elements.isEmpty else { return false }
            if case .symbol("fn", _)    = elements[0] { return false }
            if case .symbol("loop", _)  = elements[0] { return false }
            if case .symbol("recur", _) = elements[0] { return true }
            return elements.contains { recurAppears(in: $0) }

        case .vector(let elements, _):
            return elements.contains { recurAppears(in: $0) }

        case .map(let sm):
            return sm.dict.keys.contains { recurAppears(in: $0) }
                || sm.dict.values.contains { recurAppears(in: $0) }

        default:
            return false
        }
    }
}
