/// Special-form names and magic identifiers that must not be auto-qualified in syntax-quote
/// expansions — either because the evaluator dispatches on their plain names, or because they
/// are Swish-specific identifiers (like `Exception` in catch clauses).
let syntaxQuoteSpecialForms: Set<String> = [
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
    func preExpandSyntaxQuote(_ expr: Expr, gensyms: inout [String: String]) -> Expr {
        switch expr {
        case .symbol(let name, _) where name.hasSuffix("#"):
            return expr  // Leave gensyms for runtime — pre-generated gensyms would be re-qualified

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

        case .sortedMap(let dict, let meta):
            var result: [Expr: Expr] = [:]
            for (k, v) in dict {
                result[preExpandSyntaxQuote(k, gensyms: &gensyms)] = preExpandSyntaxQuote(v, gensyms: &gensyms)
            }
            return .sortedMap(result, metadata: meta)

        case .set(let elements, let meta):
            return .set(Set(elements.map { preExpandSyntaxQuote($0, gensyms: &gensyms) }), metadata: meta)

        case .sortedSet(let elements, let meta):
            return .sortedSet(elements.map { preExpandSyntaxQuote($0, gensyms: &gensyms) }, metadata: meta)

        default:
            return expr
        }
    }
}
