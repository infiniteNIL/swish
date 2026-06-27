private let destructuringSpecialKeys: Set<Expr> = [
    .keyword("keys"), .keyword("strs"), .keyword("syms"), .keyword("as"), .keyword("or")
]

/// Special-form names and magic identifiers that must not be auto-qualified in syntax-quote
/// expansions — either because the evaluator dispatches on their plain names, or because they
/// are Swish-specific identifiers (like `Exception` in catch clauses).
private let syntaxQuoteSpecialForms: Set<String> = [
    "quote", "syntax-quote", "unquote", "unquote-splicing",
    "def", "if", "do", "let", "letfn", "loop", "recur", "fn", "defmacro",
    "var", "ns", "lazy-seq", "binding", "throw", "try", "catch", "finally",
    "Exception"   // Swish magic catch-all type name in (catch Exception e ...)
]

extension Evaluator {

    // MARK: - Compile-time syntax-quote pre-expansion

    /// Walks `forms` and pre-qualifies all syntax-quote templates using the current namespace.
    /// Called from evalDefmacro so that macro bodies have symbols resolved at definition time,
    /// matching Clojure's compile-time syntax-quote behavior.
    func preExpandSyntaxQuotesInBody(_ forms: [Expr]) -> [Expr] {
        forms.map { preExpandSyntaxQuotesInExpr($0) }
    }

    private func preExpandSyntaxQuotesInExpr(_ expr: Expr) -> Expr {
        switch expr {
        case .list(let elements, let meta):
            guard !elements.isEmpty else { return expr }
            if case .symbol("syntax-quote", _) = elements[0], elements.count == 2 {
                var gensyms: [String: String] = [:]
                return .list([elements[0], preExpandSyntaxQuote(elements[1], gensyms: &gensyms)],
                             metadata: meta)
            }
            return .list(elements.map { preExpandSyntaxQuotesInExpr($0) }, metadata: meta)

        case .vector(let elements, let meta):
            return .vector(elements.map { preExpandSyntaxQuotesInExpr($0) }, metadata: meta)

        default:
            return expr
        }
    }

    /// Statically pre-qualifies all non-unquoted symbols inside a syntax-quote template.
    /// Does NOT evaluate anything — unquote/unquote-splicing forms are left as-is.
    /// Gensyms (name#) are left for the runtime expander to generate at call time.
    private func preExpandSyntaxQuote(_ expr: Expr, gensyms: inout [String: String]) -> Expr {
        switch expr {
        case .symbol(let name, _) where name.hasSuffix("#"):
            return expr  // Leave gensyms for runtime — pre-generated gensyms would be re-qualified

        case .symbol(let name, let meta):
            if name.contains("/") || name == "nil" || name == "true" || name == "false" || name == "&" {
                return expr
            }
            if syntaxQuoteSpecialForms.contains(name) { return expr }
            if let v = resolveVar(name: name, in: currentNs()) {
                return .symbol("\(v.namespace.name)/\(v.name)", metadata: meta)
            }
            return .symbol("\(currentNs().name)/\(name)", metadata: meta)

        case .list(let elements, let meta):
            guard !elements.isEmpty else { return expr }
            if case .symbol(let head, _) = elements[0] {
                if head == "unquote" || head == "unquote-splicing" {
                    guard elements.count == 2 else { return expr }
                    return .list([elements[0], preExpandSyntaxQuotesInExpr(elements[1])], metadata: meta)
                }
                if head == "syntax-quote" {
                    return expr  // Nested syntax-quote — Fix B would handle depth; skip for now
                }
            }
            return .list(elements.map { preExpandSyntaxQuote($0, gensyms: &gensyms) }, metadata: meta)

        case .vector(let elements, let meta):
            return .vector(elements.map { preExpandSyntaxQuote($0, gensyms: &gensyms) }, metadata: meta)

        case .map(let dict, let meta):
            return transformMap(dict, metadata: meta) { preExpandSyntaxQuote($0, gensyms: &gensyms) }

        case .set(let elements, let meta):
            return .set(Set(elements.map { preExpandSyntaxQuote($0, gensyms: &gensyms) }), metadata: meta)

        default:
            return expr
        }
    }

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
            // Special literals and already-qualified symbols — leave as-is
            if name.contains("/") || name == "nil" || name == "true" || name == "false" || name == "&" {
                return expr
            }
            // Special forms — must not be qualified or the evaluator won't dispatch them
            if syntaxQuoteSpecialForms.contains(name) {
                return expr
            }
            // Local binding (fn param, let binding) — leave as-is
            if env.get(name) != nil {
                return expr
            }
            // Resolve through the current namespace and qualify to the home namespace
            if let v = resolveVar(name: name, in: currentNs()) {
                return .symbol("\(v.namespace.name)/\(v.name)", metadata: meta)
            }
            // Unresolvable — qualify to current namespace (forward reference, like real Clojure)
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
            for element in elements {
                if case .list(let sub, _) = element,
                   case .symbol("unquote-splicing", _) = sub.first {
                    guard sub.count == 2
                    else {
                        throw EvaluatorError.invalidArgument(function: "unquote-splicing",
                                                             message: "requires exactly 1 argument")
                    }
                    let spliced = try eval(sub[1], in: env)
                    let splicedElements: [Expr]
                    switch spliced {
                    case .list(let elems, _):
                        splicedElements = elems

                    case .vector(let elems, _):
                        splicedElements = elems

                    case .nil:
                        splicedElements = []

                    case .lazySeq:
                        splicedElements = try seqOf(spliced, function: "unquote-splicing")

                    default:
                        throw EvaluatorError.invalidArgument(
                            function: "unquote-splicing",
                            message: "value must be a list or vector")
                    }
                    result.append(contentsOf: splicedElements)
                }
                else {
                    result.append(try syntaxQuoteExpand(element, in: env, gensyms: &gensyms))
                }
            }
            return .list(result, metadata: listMeta)

        case .vector(let elements, let vecMeta):
            var result: [Expr] = []
            for element in elements {
                if case .list(let sub, _) = element,
                   case .symbol("unquote-splicing", _) = sub.first {
                    guard sub.count == 2
                    else {
                        throw EvaluatorError.invalidArgument(function: "unquote-splicing",
                                                             message: "requires exactly 1 argument")
                    }
                    let spliced = try eval(sub[1], in: env)
                    let splicedElements: [Expr]
                    switch spliced {
                    case .list(let elems, _):      splicedElements = elems
                    case .vector(let elems, _):    splicedElements = elems
                    case .nil:                      splicedElements = []
                    case .lazySeq:                  splicedElements = try seqOf(spliced, function: "unquote-splicing")
                    default:
                        throw EvaluatorError.invalidArgument(
                            function: "unquote-splicing",
                            message: "value must be a list or vector")
                    }
                    result.append(contentsOf: splicedElements)
                }
                else {
                    result.append(try syntaxQuoteExpand(element, in: env, gensyms: &gensyms))
                }
            }
            return .vector(result, metadata: vecMeta)

        case .map(let dict, let mapMeta):
            return try transformMap(dict, metadata: mapMeta) { try syntaxQuoteExpand($0, in: env, gensyms: &gensyms) }

        case .set(let elements, let setMeta):
            var result: Set<Expr> = []
            for element in elements {
                result.insert(try syntaxQuoteExpand(element, in: env, gensyms: &gensyms))
            }
            return .set(result, metadata: setMeta)

        default:
            return expr
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

        case .map(let dict, _):
            var names = Set<String>()
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
        let wrappedBody = [Expr.list([.symbol("let", metadata: nil), .vector(letVec, metadata: nil)] + body,
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

        case .map(let dict, _):
            let tmpName = gensym(prefix: "ds__")
            let tmpSym = Expr.symbol(tmpName, metadata: nil)
            var result: [(String, Expr)] = [(tmpName, valueExpr)]

            let orMap: [Expr: Expr]
            if let orExpr = dict[.keyword("or")], case .map(let m, _) = orExpr { orMap = m } else { orMap = [:] }

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
                } else {
                    result.append((name, getExpr))
                }
            }

            if let keysExpr = dict[.keyword("keys")], case .vector(let keys, _) = keysExpr {
                for k in keys { if case .symbol(let n, _) = k {
                    addBinding(n, .list([.symbol("get", metadata: nil), tmpSym, .keyword(n)], metadata: nil))
                }}
            }
            if let strsExpr = dict[.keyword("strs")], case .vector(let strs, _) = strsExpr {
                for s in strs { if case .symbol(let n, _) = s {
                    addBinding(n, .list([.symbol("get", metadata: nil), tmpSym, .string(n)], metadata: nil))
                }}
            }
            if let symsExpr = dict[.keyword("syms")], case .vector(let syms, _) = symsExpr {
                for s in syms { if case .symbol(let n, _) = s {
                    addBinding(n, .list([.symbol("get", metadata: nil), tmpSym,
                                        .list([.symbol("quote", metadata: nil),
                                               .symbol(n, metadata: nil)], metadata: nil)], metadata: nil))
                }}
            }

            for (bindingPattern, lookupKey) in dict where !destructuringSpecialKeys.contains(bindingPattern) {
                let getExpr = Expr.list([.symbol("get", metadata: nil), tmpSym, lookupKey], metadata: nil)
                result += try destructureBindings(bindingPattern, getExpr)
            }

            if let asExpr = dict[.keyword("as")], case .symbol(let asName, _) = asExpr {
                result.append((asName, tmpSym))
            }
            return result

        default:
            return []
        }
    }
}
