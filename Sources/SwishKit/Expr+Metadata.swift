extension Expr {
    /// Returns `self` with `additional` merged into its existing metadata.
    /// Returns `nil` for types that do not support metadata.
    func mergingMetadata(_ additional: [Expr: Expr]) -> Expr? {
        func merged(_ existing: [Expr: Expr]?) -> [Expr: Expr] {
            var result = existing ?? [:]
            for (k, v) in additional { result[k] = v }
            return result
        }
        switch self {
        case .symbol(let n, let m):                    return .symbol(n, metadata: merged(m))
        case .list(let e, let m):                      return .list(e, metadata: merged(m))
        case .vector(let e, let m):                    return .vector(e, metadata: merged(m))
        case .map(let sm):                             return .map(SwishMap(dict: sm.dict, metadata: merged(sm.metadata)))
        case .sortedMap(let d, let m):                 return .sortedMap(d, metadata: merged(m))
        case .set(let s):                              return .set(SwishSet(elements: s.elements, metadata: merged(s.metadata)))
        case .sortedSet(let s, let m):                 return .sortedSet(s, metadata: merged(m))
        case .function(let f):
            f.metadata = merged(f.metadata)
            return .function(f)
        case .macro(let n, let p, let b, let m):       return .macro(name: n, params: p, body: b, metadata: merged(m))
        case .multiArityFunction(let maf):
            maf.metadata = merged(maf.metadata)
            return .multiArityFunction(maf)
        case .multiArityMacro(let n, let a, let m):    return .multiArityMacro(name: n, arities: a, metadata: merged(m))
        default: return nil
        }
    }
}
