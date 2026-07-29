import Collections

// Backed by `TreeSet` (swift-collections' HAMT persistent set): `conj`/`disj`
// share structure (O(log n)) instead of full-copying, so building a set via
// `into`/`reduce`/`conj` is O(n log n), not O(n²). Iteration order is unchanged
// from the old Swift-`Set` backing because `asSequence`/`Printer` sort elements
// explicitly regardless of backing.
//
// `metadata` is only ever assigned in `init` (verified via a full-repo grep of
// mutation sites during the thread-safety retrofit) — `with-meta` on a set
// always constructs a new `SwishSet` rather than mutating one in place — so
// unlike `SwishAtom`/`Var`/`SwishFunction`, no `Mutex` is needed here.
public final class SwishSet: @unchecked Sendable {
    public let elements: TreeSet<Expr>
    public var metadata: [Expr: Expr]?

    init(elements: TreeSet<Expr>, metadata: [Expr: Expr]?) {
        self.elements = elements
        self.metadata = metadata
    }
}

extension SwishSet: Equatable {
    public static func == (lhs: SwishSet, rhs: SwishSet) -> Bool {
        lhs.elements == rhs.elements
    }
}

extension SwishSet: Hashable {
    public func hash(into hasher: inout Hasher) {
        // Backing-independent so a `.set` hashes equal to an equal `.sortedSet`
        // (they're cross-`==`); see `hashSetContents` in Expr+Hashable.swift.
        hasher.combine(hashSetContents(elements))
    }
}
