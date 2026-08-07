/// A persistent, immutable vector matching `clojure.lang.PersistentVector`'s design:
/// a 32-way bit-partitioned trie with a tail buffer. `conj`/`pop` are O(1)
/// amortized, indexed `subscript`/`assoc` are O(log₃₂ n) (≈O(1) in practice), and
/// updates share structure with the original (no O(n) copy per append) — the
/// indexed analogue of `SwishPersistentList`. A value-type facade
/// (`RandomAccessCollection`, `ExpressibleByArrayLiteral`) so every call site sees
/// ordinary array-like value semantics.
///
/// The trie stores all but the last ≤32 elements; those live in `tail`. A `Node`
/// is either a `.branch` of up to 32 child `Node`s (internal levels) or a `.leaf`
/// of up to 32 `Expr`s (bottom level). Slots are stored as exactly-sized arrays
/// (only used slots), appended as the vector grows.
public struct SwishPersistentVector: Sendable {
    private static let bits = 5
    private static let width = 1 << bits   // 32
    private static let mask = width - 1    // 31

    private final class Node: @unchecked Sendable {
        enum Content: Sendable {
            case branch([Node])
            case leaf([Expr])
        }
        let content: Content
        init(_ content: Content) { self.content = content }

        var children: [Node] {
            if case .branch(let n) = content { return n }
            return []
        }
        var values: [Expr] {
            if case .leaf(let v) = content { return v }
            return []
        }
    }

    private let count_: Int
    private let shift: Int      // bits from the root level of the tree (min = `bits`)
    private let root: Node      // a `.branch` node (the tree part, excluding tail)
    private let tail: [Expr]    // the last 1…32 elements (empty only when count == 0)

    // MARK: - Construction

    public init() {
        count_ = 0
        shift = Self.bits
        root = Node(.branch([]))
        tail = []
    }

    private init(count: Int, shift: Int, root: Node, tail: [Expr]) {
        self.count_ = count
        self.shift = shift
        self.root = root
        self.tail = tail
    }

    public init(_ elements: [Expr]) {
        // Build via repeated conj — O(n) amortized. Simple and correct; the trie's
        // structural sharing is what matters at runtime, not the one-time build.
        var v = SwishPersistentVector()
        for e in elements { v = v.conj(e) }
        self = v
    }

    // MARK: - Core

    public var count: Int { count_ }
    public var isEmpty: Bool { count_ == 0 }

    private var tailoff: Int {
        if count_ < Self.width { return 0 }
        return ((count_ - 1) >> Self.bits) << Self.bits
    }

    /// The leaf array containing index `i` (or `tail`), without copying — O(log₃₂ n).
    private func arrayFor(_ i: Int) -> [Expr] {
        if i >= tailoff { return tail }
        var node = root
        var level = shift
        while level > 0 {
            node = node.children[(i >> level) & Self.mask]
            level -= Self.bits
        }
        return node.values
    }

    public subscript(_ i: Int) -> Expr {
        precondition(i >= 0 && i < count_, "SwishPersistentVector index \(i) out of range 0..<\(count_)")
        return arrayFor(i)[i & Self.mask]
    }

    public var first: Expr? { count_ == 0 ? nil : self[0] }
    public var last: Expr? { count_ == 0 ? nil : self[count_ - 1] }

    // MARK: - conj (append)

    public func conj(_ val: Expr) -> SwishPersistentVector {
        // Room in the tail?
        if count_ - tailoff < Self.width {
            return SwishPersistentVector(count: count_ + 1, shift: shift, root: root, tail: tail + [val])
        }
        // Tail is full: push it into the tree as a leaf node; new tail is [val].
        let tailNode = Node(.leaf(tail))
        let newRoot: Node
        var newShift = shift
        if (count_ >> Self.bits) > (1 << shift) {
            // Root overflow — grow the tree one level.
            newRoot = Node(.branch([root, newPath(shift, tailNode)]))
            newShift += Self.bits
        }
        else {
            newRoot = pushTail(shift, root, tailNode)
        }
        return SwishPersistentVector(count: count_ + 1, shift: newShift, root: newRoot, tail: [val])
    }

    private func newPath(_ level: Int, _ node: Node) -> Node {
        if level == 0 { return node }
        return Node(.branch([newPath(level - Self.bits, node)]))
    }

    private func pushTail(_ level: Int, _ parent: Node, _ tailNode: Node) -> Node {
        let subidx = ((count_ - 1) >> level) & Self.mask
        var children = parent.children
        let nodeToInsert: Node
        if level == Self.bits {
            nodeToInsert = tailNode
        }
        else if subidx < children.count {
            nodeToInsert = pushTail(level - Self.bits, children[subidx], tailNode)
        }
        else {
            nodeToInsert = newPath(level - Self.bits, tailNode)
        }
        if subidx < children.count {
            children[subidx] = nodeToInsert
        }
        else {
            children.append(nodeToInsert)
        }
        return Node(.branch(children))
    }

    // MARK: - assoc (update at index)

    public func with(index i: Int, _ value: Expr) -> SwishPersistentVector {
        precondition(i >= 0 && i < count_, "SwishPersistentVector assoc index \(i) out of range 0..<\(count_)")
        if i >= tailoff {
            var newTail = tail
            newTail[i - tailoff] = value
            return SwishPersistentVector(count: count_, shift: shift, root: root, tail: newTail)
        }
        return SwishPersistentVector(count: count_, shift: shift, root: doAssoc(shift, root, i, value), tail: tail)
    }

    private func doAssoc(_ level: Int, _ node: Node, _ i: Int, _ value: Expr) -> Node {
        if level == 0 {
            var values = node.values
            values[i & Self.mask] = value
            return Node(.leaf(values))
        }
        let subidx = (i >> level) & Self.mask
        var children = node.children
        children[subidx] = doAssoc(level - Self.bits, children[subidx], i, value)
        return Node(.branch(children))
    }

    // MARK: - pop (remove last)

    public func popLast() -> SwishPersistentVector {
        precondition(count_ > 0, "can't pop empty vector")
        if count_ == 1 { return SwishPersistentVector() }
        if count_ - tailoff > 1 {
            return SwishPersistentVector(count: count_ - 1, shift: shift, root: root, tail: Array(tail.dropLast()))
        }
        // Exactly one element in the tail: pull the previous leaf up into the tail.
        let newTail = arrayFor(count_ - 2)
        var newRoot = popTail(shift, root) ?? Node(.branch([]))
        var newShift = shift
        if newShift > Self.bits, newRoot.children.count == 1 {
            newRoot = newRoot.children[0]
            newShift -= Self.bits
        }
        return SwishPersistentVector(count: count_ - 1, shift: newShift, root: newRoot, tail: newTail)
    }

    private func popTail(_ level: Int, _ node: Node) -> Node? {
        let subidx = ((count_ - 2) >> level) & Self.mask
        if level > Self.bits {
            let newChild = popTail(level - Self.bits, node.children[subidx])
            if newChild == nil && subidx == 0 { return nil }
            var children = node.children
            if let nc = newChild {
                children[subidx] = nc
            }
            else {
                children.removeLast()
            }
            return Node(.branch(children))
        }
        else if subidx == 0 {
            return nil
        }
        else {
            var children = node.children
            children.removeLast()
            return Node(.branch(children))
        }
    }

    // MARK: - Bulk / conversion

    /// All elements as a plain array — O(n), walking leaves + tail (not per-index).
    public var elements: [Expr] {
        var result = [Expr]()
        result.reserveCapacity(count_)
        appendLeaves(root, into: &result)
        result.append(contentsOf: tail)
        return result
    }

    private func appendLeaves(_ node: Node, into result: inout [Expr]) {
        switch node.content {
        case .leaf(let values):
            result.append(contentsOf: values)
        case .branch(let children):
            for child in children { appendLeaves(child, into: &result) }
        }
    }
}

// MARK: - Collection facade

extension SwishPersistentVector: RandomAccessCollection {
    public var startIndex: Int { 0 }
    public var endIndex: Int { count_ }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }

    /// Walks the leaf arrays directly. `arrayFor` hands back the *stored* leaf — a COW
    /// reference, not a copy — so a full traversal allocates **nothing** and pays one
    /// O(log₃₂ n) descent per 32 elements, i.e. amortized O(1) each.
    ///
    /// This used to return `elements.makeIterator()`, whose comment framed the O(n)
    /// array it built as the price of avoiding the default O(n log n) index+subscript
    /// walk. It isn't a real trade: this iterator is O(n) *and* allocation-free, beating
    /// both. It also makes partial traversals cheap, which is what lets `==` below bail
    /// on the first mismatch instead of materializing both sides first.
    public struct Iterator: IteratorProtocol {
        private let vector: SwishPersistentVector
        private var index = 0
        /// The leaf covering `[leafStart, leafEnd)`, refilled when `index` leaves it.
        private var leaf: [Expr] = []
        private var leafStart = 0
        private var leafEnd = 0

        fileprivate init(_ vector: SwishPersistentVector) {
            self.vector = vector
        }

        public mutating func next() -> Expr? {
            guard index < vector.count_ else { return nil }
            if index >= leafEnd {
                // Correct for the tail as well as for trie leaves: `tailoff` is always a
                // multiple of 32 and trie leaves are always exactly 32 wide (only `tail`
                // is ever partial), so this boundary lands right in both cases.
                leaf = vector.arrayFor(index)
                leafStart = index & ~SwishPersistentVector.mask
                leafEnd = leafStart + leaf.count
            }
            defer { index += 1 }
            return leaf[index - leafStart]
        }
    }

    public func makeIterator() -> Iterator { Iterator(self) }
}

extension SwishPersistentVector: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Expr...) { self.init(elements) }
}

extension SwishPersistentVector: Equatable {
    /// Walks both iterators in step, bailing on the first mismatch. Comparing
    /// `lhs.elements == rhs.elements` instead would build two full arrays before looking
    /// at a single element — so a pair differing at index 0 cost O(n) and two allocations.
    public static func == (lhs: SwishPersistentVector, rhs: SwishPersistentVector) -> Bool {
        guard lhs.count_ == rhs.count_ else { return false }
        var a = lhs.makeIterator()
        var b = rhs.makeIterator()
        while let x = a.next() {
            if x != b.next() { return false }
        }
        return true
    }
}

extension SwishPersistentVector: Hashable {
    public func hash(into hasher: inout Hasher) {
        // Must reproduce `Array<Expr>.hash(into:)` exactly — the count as a discriminator,
        // then each element in order. `Expr` treats `.vector`, `.sharedVector` (a real
        // `[Expr]`) and a 2-element `.mapEntry` (hashed as `[k, v]`) as cross-`==` and
        // hashes all three under one discriminator (`Expr+Hashable.swift`), so a vector
        // must hash identically to the equivalent array or map lookups break.
        //
        // `hasher.combine(elements)` got that for free by calling Array's implementation,
        // at the cost of materializing the whole trie on every hash. Iterating instead is
        // allocation-free but re-states the algorithm, so `ExprVectorParityTests` pins the
        // three representations' hashes together. `SwishPersistentList.hash` relies on the
        // same assumption.
        hasher.combine(count_)
        for e in self { hasher.combine(e) }
    }
}
