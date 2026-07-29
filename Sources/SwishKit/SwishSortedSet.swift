// A sorted set backed by a comparator-sorted `[Expr]`. Unlike `.set` (an unordered
// HAMT), a sorted set maintains its elements in the order defined by `comparator`
// (nil = the default `compareExprValue`), and — per Clojure — treats two elements
// that compare `0` as the SAME element (dedup by the comparator, not by `=`).
// Membership/insert/remove are binary-search O(log n) + O(n) array shift (build is
// O(n²) incremental; batch constructors sort once). The comparison itself is passed
// in as a closure because a custom comparator is a Swish fn that must be invoked
// through the evaluator (see `Evaluator.makeComparator`).
//
// `metadata` is only assigned in `init` (like `SwishMap`/`SwishSet`), so no `Mutex`.
public final class SwishSortedSet: @unchecked Sendable {
    public let elements: [Expr]      // sorted ascending per `comparator`
    public let comparator: Expr?     // nil = default `compareExprValue`
    public var metadata: [Expr: Expr]?

    init(elements: [Expr], comparator: Expr?, metadata: [Expr: Expr]?) {
        self.elements = elements
        self.comparator = comparator
        self.metadata = metadata
    }

    public var count: Int { elements.count }
    public var isEmpty: Bool { elements.isEmpty }

    /// Lower-bound binary search: the insertion index for `item`, and whether an
    /// element comparing `0` to it is already present.
    func search(_ item: Expr, _ compare: (Expr, Expr) throws -> Int) rethrows -> (index: Int, found: Bool) {
        var lo = 0
        var hi = elements.count
        while lo < hi {
            let mid = (lo + hi) / 2
            let c = try compare(elements[mid], item)
            if c == 0 { return (mid, true) }
            if c < 0 { lo = mid + 1 }
            else { hi = mid }
        }
        return (lo, false)
    }

    func inserting(_ item: Expr, _ compare: (Expr, Expr) throws -> Int) rethrows -> SwishSortedSet {
        let (idx, found) = try search(item, compare)
        if found { return self }   // already present (compares 0) — dedup
        var e = elements
        e.insert(item, at: idx)
        return SwishSortedSet(elements: e, comparator: comparator, metadata: metadata)
    }

    func removing(_ item: Expr, _ compare: (Expr, Expr) throws -> Int) rethrows -> SwishSortedSet {
        let (idx, found) = try search(item, compare)
        if !found { return self }
        var e = elements
        e.remove(at: idx)
        return SwishSortedSet(elements: e, comparator: comparator, metadata: metadata)
    }

    func contains(_ item: Expr, _ compare: (Expr, Expr) throws -> Int) rethrows -> Bool {
        try search(item, compare).found
    }

    func withMetadata(_ meta: [Expr: Expr]?) -> SwishSortedSet {
        SwishSortedSet(elements: elements, comparator: comparator, metadata: meta)
    }
}

extension SwishSortedSet: Equatable {
    // Equality ignores the comparator and compares contents as a set (matching
    // Clojure: `(= (sorted-set-by < 1 2) (sorted-set-by > 1 2))` → true).
    public static func == (lhs: SwishSortedSet, rhs: SwishSortedSet) -> Bool {
        Set(lhs.elements) == Set(rhs.elements)
    }
}

extension SwishSortedSet: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(hashSetContents(elements))   // cross-consistent with `.set`
    }
}
