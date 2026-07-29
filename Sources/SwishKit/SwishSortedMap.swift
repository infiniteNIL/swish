// A sorted map backed by parallel comparator-sorted `keys`/`values` arrays. Unlike
// `.map` (an unordered HAMT), a sorted map maintains its keys in the order defined
// by `comparator` (nil = the default `compareExprValue`) and — per Clojure — treats
// two keys that compare `0` as the SAME key (dedup by the comparator, not by `=`).
// `get`/`assoc`/`dissoc` are binary-search O(log n) + O(n) array shift. The
// comparison is passed as a closure (a custom comparator is a Swish fn invoked via
// the evaluator — see `Evaluator.makeComparator`).
//
// `metadata` is only assigned in `init` (like `SwishMap`), so no `Mutex`.
public final class SwishSortedMap: @unchecked Sendable {
    public let keys: [Expr]          // sorted ascending per `comparator`
    public let values: [Expr]        // parallel to `keys`
    public let comparator: Expr?     // nil = default `compareExprValue`
    public var metadata: [Expr: Expr]?

    init(keys: [Expr], values: [Expr], comparator: Expr?, metadata: [Expr: Expr]?) {
        self.keys = keys
        self.values = values
        self.comparator = comparator
        self.metadata = metadata
    }

    public var count: Int { keys.count }
    public var isEmpty: Bool { keys.isEmpty }

    /// Sorted key→value entries as `.mapEntry`s (for `seq`/`asSequence`).
    public var entries: [Expr] {
        zip(keys, values).map { .mapEntry($0, $1) }
    }

    /// A plain `[Expr: Expr]` (for cross-`==`/hash with `.map`, and cold consumers).
    public var asDictionary: [Expr: Expr] {
        var d = [Expr: Expr](minimumCapacity: keys.count)
        for (k, v) in zip(keys, values) { d[k] = v }
        return d
    }

    func search(_ key: Expr, _ compare: (Expr, Expr) throws -> Int) rethrows -> (index: Int, found: Bool) {
        var lo = 0
        var hi = keys.count
        while lo < hi {
            let mid = (lo + hi) / 2
            let c = try compare(keys[mid], key)
            if c == 0 { return (mid, true) }
            if c < 0 { lo = mid + 1 }
            else { hi = mid }
        }
        return (lo, false)
    }

    func get(_ key: Expr, _ compare: (Expr, Expr) throws -> Int) rethrows -> Expr? {
        let (idx, found) = try search(key, compare)
        return found ? values[idx] : nil
    }

    func assoc(_ key: Expr, _ value: Expr, _ compare: (Expr, Expr) throws -> Int) rethrows -> SwishSortedMap {
        let (idx, found) = try search(key, compare)
        var k = keys
        var v = values
        if found {
            v[idx] = value   // replace value, keep the existing (equal) key
        }
        else {
            k.insert(key, at: idx)
            v.insert(value, at: idx)
        }
        return SwishSortedMap(keys: k, values: v, comparator: comparator, metadata: metadata)
    }

    func dissoc(_ key: Expr, _ compare: (Expr, Expr) throws -> Int) rethrows -> SwishSortedMap {
        let (idx, found) = try search(key, compare)
        if !found { return self }
        var k = keys
        var v = values
        k.remove(at: idx)
        v.remove(at: idx)
        return SwishSortedMap(keys: k, values: v, comparator: comparator, metadata: metadata)
    }

    func withMetadata(_ meta: [Expr: Expr]?) -> SwishSortedMap {
        SwishSortedMap(keys: keys, values: values, comparator: comparator, metadata: meta)
    }
}

extension SwishSortedMap: Equatable {
    // Equality ignores the comparator, comparing entries as maps (by `=`).
    public static func == (lhs: SwishSortedMap, rhs: SwishSortedMap) -> Bool {
        lhs.asDictionary == rhs.asDictionary
    }
}

extension SwishSortedMap: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(hashMapContents(asDictionary))   // cross-consistent with `.map`
    }
}
