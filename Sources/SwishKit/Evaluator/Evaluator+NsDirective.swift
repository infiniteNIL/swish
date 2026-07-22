extension Evaluator {

    // MARK: - ns / :require

    func extractDocAndAttr(_ elements: [Expr], startingAt idx: Int) -> (doc: String?, attrs: [Expr: Expr]?, nextIdx: Int) {
        var i = idx
        var doc: String? = nil
        var attrs: [Expr: Expr]? = nil
        if i < elements.count, case .string(let s) = elements[i] { doc = s; i += 1 }
        if i < elements.count, case .map(let sm) = elements[i] { attrs = sm.dict; i += 1 }
        return (doc, attrs, i)
    }

    func evalNs(_ elements: [Expr]) throws -> Expr {
        guard elements.count >= 2, case .symbol(let name, let symMeta) = elements[1]
        else {
            throw EvaluatorError.invalidArgument(function: "ns",
                message: "requires at least one symbol argument")
        }
        let (docString, attrMap, idx) = extractDocAndAttr(elements, startingAt: 2)
        let meta = buildMeta(from: symMeta, attrMap: attrMap, docString: docString)

        let ns = findOrCreateNs(name)
        setCurrentNs(ns)
        ns.metadata = meta.isEmpty ? nil : meta

        for directive in elements.dropFirst(idx) {
            guard case .list(let parts, _) = directive,
                  !parts.isEmpty,
                  case .keyword(let kind) = parts[0]
            else {
                throw EvaluatorError.invalidArgument(function: "ns",
                    message: "expected a directive list like (:require ...)")
            }
            switch kind {
            case "require":
                try processRequireDirective(Array(parts.dropFirst()), caller: "ns")

            default:
                throw EvaluatorError.invalidArgument(function: "ns",
                    message: "unknown directive ':\(kind)'")
            }
        }
        return .nil
    }

    func processRequireDirective(_ specs: [Expr], caller: String = "require") throws {
        for spec in specs {
            try processOneRequireSpec(spec, caller: caller)
        }
    }

    private func processOneRequireSpec(_ spec: Expr, caller: String) throws {
        switch spec {
        case .symbol(let nsName, _):
            _ = try requireNs(nsName)

        case .vector(let parts, _):
            guard !parts.isEmpty, case .symbol(let nsName, _) = parts[0]
            else {
                throw EvaluatorError.invalidArgument(function: caller,
                    message: ":require spec must start with a namespace symbol")
            }
            let loadedNs = try requireNs(nsName)
            var i = 1
            while i + 1 < parts.count {
                guard case .keyword(let key) = parts[i]
                else {
                    i += 1
                    continue
                }
                switch key {
                case "as":
                    guard case .symbol(let aliasName, _) = parts[i + 1]
                    else {
                        throw EvaluatorError.invalidArgument(function: caller,
                            message: ":as requires a symbol")
                    }
                    try currentNs().alias(name: aliasName, ns: loadedNs)

                case "refer":
                    switch parts[i + 1] {
                    case .keyword("all"):
                        for (_, v) in loadedNs.mappings where v.namespace === loadedNs {
                            try currentNs().refer(v)
                        }

                    case .vector(let syms, _):
                        let names = syms.compactMap { if case .symbol(let s, _) = $0 { s } else { nil } }
                        for symName in names {
                            guard let v = loadedNs.findVar(name: symName)
                            else {
                                throw EvaluatorError.undefinedSymbol("\(nsName)/\(symName)")
                            }
                            try currentNs().refer(v)
                        }

                    default:
                        throw EvaluatorError.invalidArgument(function: caller,
                            message: ":refer requires a vector of symbols or :all")
                    }

                default:
                    break
                }
                i += 2
            }

        default:
            throw EvaluatorError.invalidArgument(function: caller,
                message: ":require spec must be a symbol or vector")
        }
    }
}
