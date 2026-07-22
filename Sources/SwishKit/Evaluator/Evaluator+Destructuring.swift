private let destructuringSpecialKeys: Set<Expr> = [
    .keyword("keys"), .keyword("strs"), .keyword("syms"), .keyword("as"), .keyword("or")
]

extension Evaluator {

    // MARK: - Runtime syntax-quote expansion

    /// Recursively expands a syntax-quote template, substituting (unquote ...) and
    /// splicing (unquote-splicing ...) sub-forms. Auto-gensyms symbols ending in #.
    /// Unqualified symbols are auto-qualified to their defining namespace (like real Clojure).
    func syntaxQuoteExpand(_ expr: Expr, in env: Environment, gensyms: inout [String: String]) throws -> Expr {
        switch expr {
        case .symbol(let name, _) where name.hasSuffix("#"):
            let base = String(name.dropLast()) + "__"
            let generated = gensyms[name] ?? gensym(prefix: base)
            gensyms[name] = generated
            return .symbol(generated, metadata: nil)

        case .symbol(let name, let meta):
            if name == "nil" || name == "true" || name == "false" || name == "&" {
                return expr
            }
            if name.contains("/") {
                if let (nsAlias, varName) = splitQualified(name),
                   let resolvedNs = currentNs().findAlias(nsAlias) {
                    return .symbol("\(resolvedNs.name)/\(varName)", metadata: meta)
                }
                return expr
            }
            if syntaxQuoteSpecialForms.contains(name) { return expr }
            if env.get(name) != nil { return expr }
            if let v = resolveVar(name: name, in: currentNs()) {
                return .symbol("\(v.namespace.name)/\(v.name)", metadata: meta)
            }
            return .symbol("\(currentNs().name)/\(name)", metadata: meta)

        case .list(let elements, let listMeta):
            if case .symbol("unquote", _) = elements.first {
                guard elements.count == 2
                else {
                    throw EvaluatorError.invalidArgument(function: "unquote",
                                                         message: "requires exactly 1 argument")
                }
                return try eval(elements[1], in: env)
            }
            var result: [Expr] = []
            try expandSplicingElements(elements, into: &result, in: env, gensyms: &gensyms)
            return .list(SwishPersistentList(result), metadata: listMeta)

        case .vector(let elements, let vecMeta):
            var result: [Expr] = []
            try expandSplicingElements(elements, into: &result, in: env, gensyms: &gensyms)
            return .vector(result, metadata: vecMeta)

        case .map(let sm):
            var result: [Expr: Expr] = [:]
            for (k, v) in sm.dict {
                result[try syntaxQuoteExpand(k, in: env, gensyms: &gensyms)] = try syntaxQuoteExpand(v, in: env, gensyms: &gensyms)
            }
            return .map(result, metadata: sm.metadata)

        case .sortedMap(let dict, let mapMeta):
            return try transformSortedMap(dict, metadata: mapMeta) { try syntaxQuoteExpand($0, in: env, gensyms: &gensyms) }

        case .set(let ss):
            var result: Set<Expr> = []
            for element in ss.elements {
                result.insert(try syntaxQuoteExpand(element, in: env, gensyms: &gensyms))
            }
            return .set(SwishSet(elements: result, metadata: ss.metadata))

        case .sortedSet(let elements, let setMeta):
            var result: [Expr] = []
            for element in elements {
                result.append(try syntaxQuoteExpand(element, in: env, gensyms: &gensyms))
            }
            return .sortedSet(result, metadata: setMeta)

        default:
            return expr
        }
    }

    private func expandSplicingElements(
        _ elements: some Sequence<Expr>,
        into result: inout [Expr],
        in env: Environment,
        gensyms: inout [String: String]
    ) throws {
        for element in elements {
            if case .list(let sub, _) = element,
               case .symbol("unquote-splicing", _) = sub.first {
                guard sub.count == 2
                else {
                    throw EvaluatorError.invalidArgument(function: "unquote-splicing",
                                                         message: "requires exactly 1 argument")
                }
                let spliced = try eval(sub[1], in: env)
                switch spliced {
                case .list(let elems, _):    result.append(contentsOf: elems)
                case .vector(let elems, _):  result.append(contentsOf: elems)
                case .nil:                   break
                case .lazySeq:               result.append(contentsOf: try seqOf(spliced, function: "unquote-splicing"))
                default:
                    throw EvaluatorError.invalidArgument(
                        function: "unquote-splicing",
                        message: "value must be a list or vector")
                }
            }
            else {
                result.append(try syntaxQuoteExpand(element, in: env, gensyms: &gensyms))
            }
        }
    }

    // MARK: - Parameter helpers

    func extractParamNames(_ exprs: [Expr]) -> [String] {
        exprs.compactMap {
            if case .symbol(let s, _) = $0 {
                return s
            }
            else {
                return nil
            }
        }
    }

    /// Returns all variable names introduced by a destructuring pattern (recursively).
    func collectLocalNames(_ pattern: Expr) -> Set<String> {
        switch pattern {
        case .symbol("_", _), .symbol("&", _): return []
        case .symbol(let name, _): return [name]
        case .vector(let elements, _):
            var names = Set<String>()
            var i = 0
            while i < elements.count {
                if case .symbol("&", _) = elements[i] {
                    i += 1
                    if i < elements.count { names.formUnion(collectLocalNames(elements[i])) }
                    break
                }
                names.formUnion(collectLocalNames(elements[i]))
                i += 1
            }
            return names

        case .map(let sm):
            var names = Set<String>()
            let dict = sm.dict
            for key in [Expr.keyword("keys"), .keyword("strs"), .keyword("syms")] {
                if let vecExpr = dict[key], case .vector(let syms, _) = vecExpr {
                    for s in syms { if case .symbol(let n, _) = s { names.insert(n) } }
                }
            }
            if let asExpr = dict[.keyword("as")], case .symbol(let n, _) = asExpr { names.insert(n) }
            for (key, _) in dict where !destructuringSpecialKeys.contains(key) {
                names.formUnion(collectLocalNames(key))
            }
            return names

        default: return []
        }
    }

    /// Collects all local names introduced by a parameter list (including destructuring patterns).
    func collectAllParamLocals(_ paramExprs: [Expr]) -> Set<String> {
        paramExprs.reduce(into: Set<String>()) { $0.formUnion(collectLocalNames($1)) }
    }

    /// Expands any destructuring patterns in a param vector by replacing them with gensyms
    /// and prepending a `let` binding in the body. Returns (flat-param-names, expanded-body).
    func expandDestructuredParams(_ paramExprs: [Expr], body: [Expr]) -> ([String], [Expr]) {
        var flatParams: [String] = []
        var patternBindings: [(Expr, String)] = []
        for p in paramExprs {
            switch p {
            case .symbol(let name, _):
                flatParams.append(name)
            default:
                let tmp = gensym(prefix: "p__")
                flatParams.append(tmp)
                patternBindings.append((p, tmp))
            }
        }
        guard !patternBindings.isEmpty else { return (flatParams, body) }
        var letVec: [Expr] = []
        for (pat, tmpName) in patternBindings {
            letVec.append(pat)
            letVec.append(.symbol(tmpName, metadata: nil))
        }
        let wrappedBody = [Expr.list(SwishPersistentList([.symbol("let", metadata: nil), .vector(letVec, metadata: nil)] + body),
                                     metadata: nil)]
        return (flatParams, wrappedBody)
    }

    // MARK: - Destructuring

    /// Expands a single binding pair (pattern, valueExpr) into flat [(name, expr)] pairs
    /// evaluated sequentially. Uses `nth`/`drop`/`get` from the runtime.
    func destructureBindings(_ pattern: Expr, _ valueExpr: Expr) throws -> [(String, Expr)] {
        switch pattern {
        case .symbol("_", _):
            return []

        case .symbol(let name, _):
            return [(name, valueExpr)]

        case .vector(let elements, _):
            return try destructureVectorPattern(elements, value: valueExpr)

        case .map(let sm):
            return try destructureMapPattern(sm.dict, value: valueExpr)

        default:
            return []
        }
    }

    private func destructureVectorPattern(_ elements: [Expr], value valueExpr: Expr) throws -> [(String, Expr)] {
        let tmpName = gensym(prefix: "ds__")
        let tmpSym = Expr.symbol(tmpName, metadata: nil)
        var result: [(String, Expr)] = [(tmpName, valueExpr)]
        for idx in 0..<elements.count {
            if case .keyword("as") = elements[idx] {
                guard idx + 1 < elements.count, case .symbol(let asName, _) = elements[idx + 1]
                else {
                    throw EvaluatorError.invalidArgument(function: "destructure",
                                                         message: ":as must be followed by a symbol")
                }
                result.append((asName, tmpSym))
                break
            }
        }
        var pos = 0
        var i = 0
        while i < elements.count {
            let elem = elements[i]
            if case .keyword("as") = elem {
                i += 2
            }
            else if case .symbol("&", _) = elem {
                i += 1
                guard i < elements.count
                else {
                    throw EvaluatorError.invalidArgument(function: "destructure",
                                                         message: "& must be followed by exactly one binding form")
                }
                let dropExpr = Expr.list([.symbol("drop", metadata: nil),
                                          .integer(pos), tmpSym], metadata: nil)
                let seqExpr = Expr.list([.symbol("seq", metadata: nil), dropExpr], metadata: nil)
                result += try destructureBindings(elements[i], seqExpr)
                break
            }
            else if case .symbol("_", _) = elem {
                pos += 1
                i += 1
            }
            else {
                let nthExpr = Expr.list([.symbol("nth", metadata: nil),
                                         tmpSym, .integer(pos), .nil], metadata: nil)
                result += try destructureBindings(elem, nthExpr)
                pos += 1
                i += 1
            }
        }
        return result
    }

    private func destructureMapPattern(_ dict: [Expr: Expr], value valueExpr: Expr) throws -> [(String, Expr)] {
        let tmpName = gensym(prefix: "ds__")
        let tmpSym = Expr.symbol(tmpName, metadata: nil)
        var result: [(String, Expr)] = [(tmpName, valueExpr)]

        let orMap: [Expr: Expr]
        if let orExpr = dict[.keyword("or")], case .map(let orSm) = orExpr { orMap = orSm.dict } else { orMap = [:] }

        func addBinding(_ name: String, _ getExpr: Expr) {
            let keySym = Expr.symbol(name, metadata: nil)
            if let defaultVal = orMap[keySym] {
                let vName = gensym(prefix: "or__")
                let vSym = Expr.symbol(vName, metadata: nil)
                let wrapped = Expr.list([
                    .symbol("let", metadata: nil),
                    .vector([vSym, getExpr], metadata: nil),
                    .list([.symbol("if", metadata: nil),
                           .list([.symbol("nil?", metadata: nil), vSym], metadata: nil),
                           defaultVal, vSym], metadata: nil)
                ], metadata: nil)
                result.append((name, wrapped))
            }
            else {
                result.append((name, getExpr))
            }
        }

        // :keys/:strs/:syms differ only in which keyword to look up and how the
        // lookup-key Expr is built from the bound symbol's name.
        let keyBuilders: [(Expr, (String) -> Expr)] = [
            (.keyword("keys"), { .keyword($0) }),
            (.keyword("strs"), { .string($0) }),
            (.keyword("syms"), { .list([.symbol("quote", metadata: nil), .symbol($0, metadata: nil)], metadata: nil) }),
        ]
        for (specKey, keyBuilder) in keyBuilders {
            if let specExpr = dict[specKey], case .vector(let syms, _) = specExpr {
                for s in syms {
                    if case .symbol(let n, _) = s {
                        addBinding(n, .list([.symbol("get", metadata: nil), tmpSym, keyBuilder(n)], metadata: nil))
                    }
                }
            }
        }

        for (bindingPattern, lookupKey) in dict where !destructuringSpecialKeys.contains(bindingPattern) {
            let getExpr = Expr.list([.symbol("get", metadata: nil), tmpSym, lookupKey], metadata: nil)
            result += try destructureBindings(bindingPattern, getExpr)
        }

        if let asExpr = dict[.keyword("as")], case .symbol(let asName, _) = asExpr {
            result.append((asName, tmpSym))
        }
        return result
    }
}
