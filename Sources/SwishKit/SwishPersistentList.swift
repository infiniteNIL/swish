/// A persistent, immutable singly-linked list matching `clojure.lang.PersistentList`'s
/// cons-cell design: O(1) `cons`/`first`/`rest`/`count` via structural sharing, no
/// copying. Value-semantic wrapper around a private class-based node chain — the class
/// is needed only so its `deinit` can safely unlink long chains iteratively (see below);
/// every call site otherwise sees ordinary array-like value semantics.
public struct SwishPersistentList: Sendable {

    fileprivate final class Node: @unchecked Sendable {
        let head: Expr
        var tail: Node?    // `var` only so deinit can unlink it; never mutated otherwise
        let count: Int     // 1 + (tail?.count ?? 0), cached at construction — O(1) count

        init(head: Expr, tail: Node?) {
            self.head = head
            self.tail = tail
            self.count = 1 + (tail?.count ?? 0)
        }

        // Modeled directly on LazySeqBox.deinit: Expr is an indirect enum, so a
        // compiler-generated deinit on a long chain recurses one stack frame per
        // link and overflows around ~20000 elements. Unlink iteratively, using
        // isKnownUniquelyReferenced to stop early if another list structurally
        // shares this node's tail (safe — that node's own eventual deinit repeats
        // this same walk).
        deinit {
            guard var tailNode = tail else { return }
            tail = nil
            while isKnownUniquelyReferenced(&tailNode) {
                guard let next = tailNode.tail else { break }
                tailNode.tail = nil
                tailNode = next
            }
        }
    }

    private var node: Node?

    public init() { node = nil }

    public init(_ elements: [Expr]) {
        var n: Node? = nil
        for e in elements.reversed() { n = Node(head: e, tail: n) }
        node = n
    }

    private init(node: Node?) { self.node = node }

    public var isEmpty: Bool { node == nil }
    public var count: Int { node?.count ?? 0 }
    public var first: Expr? { node?.head }

    public func cons(_ x: Expr) -> SwishPersistentList {
        SwishPersistentList(node: Node(head: x, tail: node))
    }

    /// Walks `n` tail pointers — O(n), no copying (unlike Array's O(n) copy-and-shift).
    public func dropFirst(_ n: Int = 1) -> SwishPersistentList {
        var cur = node
        for _ in 0..<n {
            guard let c = cur else { break }
            cur = c.tail
        }
        return SwishPersistentList(node: cur)
    }

    /// O(i) walk, traps on out-of-range like Array's subscript.
    public subscript(_ i: Int) -> Expr {
        var cur = node
        for _ in 0..<i { cur = cur?.tail }
        guard let c = cur else { preconditionFailure("SwishPersistentList index out of range") }
        return c.head
    }

    public var elements: [Expr] { Array(self) }
}

extension SwishPersistentList: Sequence {
    public struct Iterator: IteratorProtocol {
        fileprivate var current: Node?

        public mutating func next() -> Expr? {
            guard let c = current else { return nil }
            current = c.tail
            return c.head
        }
    }

    public func makeIterator() -> Iterator { Iterator(current: node) }
    public var underestimatedCount: Int { count }
}

extension SwishPersistentList: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Expr...) { self.init(elements) }
}

extension SwishPersistentList: Equatable {
    public static func == (lhs: SwishPersistentList, rhs: SwishPersistentList) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var a = lhs.makeIterator()
        var b = rhs.makeIterator()
        while let x = a.next() {
            if x != b.next() { return false }
        }
        return true
    }
}

extension SwishPersistentList: Hashable {
    public func hash(into hasher: inout Hasher) {
        // Matches Array<Expr>.hash(into:)'s own algorithm exactly, so a .list and
        // an equal .seq (still [Expr]-backed) produce the same hash sequence.
        hasher.combine(count)
        for e in self { hasher.combine(e) }
    }
}
