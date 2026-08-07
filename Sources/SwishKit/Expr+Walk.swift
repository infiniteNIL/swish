extension Expr {
    /// Rebuilds this expression's immediate collection children with `transform`,
    /// preserving the case, its metadata, and (for sorted collections) its comparator.
    /// Anything else — scalars, symbols, and the two *code-shaped* cases `.list` and
    /// `.seq` — is returned unchanged.
    ///
    /// This is the shared spine of the interpreter's AST rewriters: `expandAliasesInExpr`,
    /// `macroexpandAll`, `preExpandSyntaxQuote`, `syntaxQuoteExpand`, and
    /// `substituteMutableFields` each used to hand-roll these same five arms. A new
    /// rewriter should handle only the forms it genuinely treats specially and delegate
    /// the rest here, rather than adding a sixth copy.
    ///
    /// **`.list`/`.seq` are deliberately excluded.** Every rewriter special-cases them —
    /// to skip `quote` bodies, to scope `let`/`fn` locals, to expand a macro head, to
    /// splice `~@` — and no two do it the same way. Handling them here would silently
    /// give a caller the generic recursion when it needs its own, so they stay the
    /// caller's job and fall through untouched.
    ///
    /// **Sorted collections are transformed positionally**, not re-sorted: these walks
    /// rewrite *code* (a `#{…}`/`{…}` literal in a macro template or a method body), where
    /// the reader's ordering is what should survive. `Evaluator.eval` re-inserts through
    /// the comparator instead, which is the runtime path where ordering must be recomputed.
    ///
    /// **Set collisions drop**, matching what all five rewriters already did — unlike
    /// `Evaluator.eval`, which throws `duplicateSetElement`. A rewrite that maps two
    /// distinct source forms onto one value is not the reader duplicate that error is for.
    func mappingChildren(_ transform: (Expr) throws -> Expr) rethrows -> Expr {
        switch self {
        case .vector(let elements, let meta):
            return .vector(SwishPersistentVector(try elements.map(transform)), metadata: meta)

        case .map(let sm):
            var result: [Expr: Expr] = [:]
            for (k, v) in sm.dict {
                result[try transform(k)] = try transform(v)
            }
            return .map(result, metadata: sm.metadata)

        case .set(let ss):
            var result: Set<Expr> = []
            for element in ss.elements {
                result.insert(try transform(element))
            }
            return .set(result, metadata: ss.metadata)

        case .sortedMap(let ssm):
            return .sortedMap(sortedKeys: try ssm.keys.map(transform),
                              sortedValues: try ssm.values.map(transform),
                              comparator: ssm.comparator,
                              metadata: ssm.metadata)

        case .sortedSet(let sss):
            return .sortedSet(try sss.elements.map(transform),
                              comparator: sss.comparator,
                              metadata: sss.metadata)

        default:
            return self
        }
    }
}
