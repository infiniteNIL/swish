import Collections

// Backed by `TreeDictionary` (swift-collections' HAMT persistent map): `assoc`/
// `dissoc` share structure (O(log n)) instead of full-copying, so building a map
// via `into`/`reduce`/`assoc` is O(n log n), not O(n²). The indexed-map analogue
// of `SwishPersistentList`/`SwishPersistentVector`. Iteration order is unchanged
// from the old Swift-`Dictionary` backing because `asSequence`/`Printer` sort map
// keys explicitly regardless of backing.
//
// `metadata` is only ever assigned in `init` (verified via a full-repo grep of
// mutation sites during the thread-safety retrofit) — `with-meta` on a map
// always constructs a new `SwishMap` rather than mutating one in place — so
// unlike `SwishAtom`/`Var`/`SwishFunction`, no `Mutex` is needed here.
public final class SwishMap: @unchecked Sendable {
    public let dict: TreeDictionary<Expr, Expr>
    public var metadata: [Expr: Expr]?

    init(dict: TreeDictionary<Expr, Expr>, metadata: [Expr: Expr]?) {
        self.dict = dict
        self.metadata = metadata
    }
}

extension SwishMap: Equatable {
    public static func == (lhs: SwishMap, rhs: SwishMap) -> Bool {
        lhs.dict == rhs.dict
    }
}

extension SwishMap: Hashable {
    public func hash(into hasher: inout Hasher) {
        // Backing-independent so a `.map` hashes equal to an equal `.sortedMap`
        // (they're cross-`==`); see `hashMapContents` in Expr+Hashable.swift.
        hasher.combine(hashMapContents(dict))
    }
}

extension TreeDictionary where Key == Expr, Value == Expr {
    /// Materializes a plain `[Expr: Expr]` — O(n). For cold paths that hand the
    /// map to Swift-`Dictionary`-typed APIs (metadata, protocol/record data,
    /// printing, destructuring); hot paths operate on the `TreeDictionary`
    /// directly to keep O(log n).
    var swiftDictionary: [Expr: Expr] {
        Dictionary(uniqueKeysWithValues: self.map { ($0.key, $0.value) })
    }
}

/// Shared mutable-subscript interface so `conj`/merge logic works uniformly over
/// both the persistent `.map` backing (`TreeDictionary`) and the `.sortedMap`
/// backing (Swift `Dictionary`), which otherwise share no such protocol.
protocol ExprMapStorage {
    subscript(key: Expr) -> Expr? { get set }
}

extension Dictionary: ExprMapStorage where Key == Expr, Value == Expr {}
extension TreeDictionary: ExprMapStorage where Key == Expr, Value == Expr {}
