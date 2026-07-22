import Testing
@testable import SwishKit

@Suite("SwishPersistentList Tests")
struct SwishPersistentListTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - Basic construction / accessors

    @Test("Empty list has count 0, isEmpty true, first nil")
    func emptyList() {
        let list = SwishPersistentList()
        #expect(list.isEmpty)
        #expect(list.count == 0)
        #expect(list.first == nil)
        #expect(Array(list) == [])
    }

    @Test("Constructing from an array preserves order")
    func fromArray() {
        let list = SwishPersistentList([.integer(1), .integer(2), .integer(3)])
        #expect(!list.isEmpty)
        #expect(list.count == 3)
        #expect(list.first == .integer(1))
        #expect(Array(list) == [.integer(1), .integer(2), .integer(3)])
    }

    @Test("Array literal construction works")
    func arrayLiteral() {
        let list: SwishPersistentList = [.integer(1), .integer(2)]
        #expect(list.count == 2)
        #expect(Array(list) == [.integer(1), .integer(2)])
    }

    @Test("cons prepends and preserves the original")
    func consPrepends() {
        let tail = SwishPersistentList([.integer(2), .integer(3)])
        let consed = tail.cons(.integer(1))
        #expect(Array(consed) == [.integer(1), .integer(2), .integer(3)])
        #expect(Array(tail) == [.integer(2), .integer(3)])
        #expect(consed.count == 3)
        #expect(tail.count == 2)
    }

    @Test("cons onto an empty list produces a single-element list")
    func consOntoEmpty() {
        let list = SwishPersistentList().cons(.integer(1))
        #expect(Array(list) == [.integer(1)])
        #expect(list.count == 1)
    }

    @Test("dropFirst walks tail pointers without copying")
    func dropFirst() {
        let list = SwishPersistentList([.integer(1), .integer(2), .integer(3), .integer(4)])
        #expect(Array(list.dropFirst()) == [.integer(2), .integer(3), .integer(4)])
        #expect(Array(list.dropFirst(2)) == [.integer(3), .integer(4)])
        #expect(list.dropFirst(4).isEmpty)
        #expect(list.dropFirst(10).isEmpty)
    }

    @Test("subscript walks n steps to fetch an element")
    func subscriptAccess() {
        let list = SwishPersistentList([.integer(10), .integer(20), .integer(30)])
        #expect(list[0] == .integer(10))
        #expect(list[1] == .integer(20))
        #expect(list[2] == .integer(30))
    }

    @Test("elements materializes back to a plain array")
    func elementsMaterializes() {
        let list = SwishPersistentList([.integer(1), .integer(2)])
        #expect(list.elements == [.integer(1), .integer(2)])
    }

    @Test("Sequence conformance supports for-in and map")
    func sequenceConformance() {
        let list = SwishPersistentList([.integer(1), .integer(2), .integer(3)])
        var collected: [Expr] = []
        for e in list { collected.append(e) }
        #expect(collected == [.integer(1), .integer(2), .integer(3)])
        #expect(list.map { $0 } == [.integer(1), .integer(2), .integer(3)])
    }

    // MARK: - Equatable / Hashable

    @Test("Equal-content lists compare equal")
    func equalContentListsAreEqual() {
        let a = SwishPersistentList([.integer(1), .integer(2), .integer(3)])
        let b = SwishPersistentList([.integer(1), .integer(2), .integer(3)])
        #expect(a == b)
    }

    @Test("Different-content lists compare unequal")
    func differentContentListsAreUnequal() {
        let a = SwishPersistentList([.integer(1), .integer(2)])
        let b = SwishPersistentList([.integer(1), .integer(3)])
        let c = SwishPersistentList([.integer(1), .integer(2), .integer(3)])
        #expect(a != b)
        #expect(a != c)
    }

    @Test("Equal-content lists hash equal and are usable as Set/Dictionary keys")
    func equalListsHashEqual() {
        let a = SwishPersistentList([.integer(1), .integer(2), .integer(3)])
        let b = SwishPersistentList([.integer(1), .integer(2), .integer(3)])
        #expect(a.hashValue == b.hashValue)

        var set: Set<SwishPersistentList> = []
        set.insert(a)
        #expect(set.contains(b))

        var dict: [SwishPersistentList: String] = [:]
        dict[a] = "found"
        #expect(dict[b] == "found")
    }

    @Test("A .list and an equal .seq (still [Expr]-backed) hash equal")
    func listAndSeqCrossTypeHashConsistency() {
        let list = Expr.list(SwishPersistentList([.integer(1), .integer(2), .integer(3)]), metadata: nil)
        let seq = Expr.seq([.integer(1), .integer(2), .integer(3)])
        #expect(list == seq)
        #expect(list.hashValue == seq.hashValue)
    }

    // MARK: - Structural sharing / aliased-tail correctness

    @Test("Forking two lists off a shared tail leaves the tail and both forks intact")
    func aliasedTailStaysIntact() {
        let sharedTail = SwishPersistentList([.integer(3), .integer(4), .integer(5)])
        var forkA: SwishPersistentList? = sharedTail.cons(.integer(1))
        let forkB = sharedTail.cons(.integer(2))

        // Drop one fork entirely — this must not corrupt the shared tail or forkB,
        // which is exactly what a broken deinit (one that unlinks nodes still
        // referenced elsewhere) would get wrong.
        forkA = nil
        _ = forkA

        #expect(Array(sharedTail) == [.integer(3), .integer(4), .integer(5)])
        #expect(Array(forkB) == [.integer(2), .integer(3), .integer(4), .integer(5)])
    }

    // MARK: - Deinit safety

    @Test("Releasing a very long list does not overflow the stack")
    func longListDeinitDoesNotOverflow() {
        var list = SwishPersistentList()
        for i in stride(from: 999_999, through: 0, by: -1) {
            list = list.cons(.integer(i))
        }
        #expect(list.count == 1_000_000)
        // `list` is released when the function returns, triggering the deinit
        // chain — if that overflows the stack, this test (and likely others)
        // crash the whole process rather than reporting a normal failure.
    }

    @Test("conj/list construction end to end does not crash at meaningful scale")
    func conjListIntegration() throws {
        // Stack-safety on very long chains is already covered by the pure-Swift
        // longListDeinitDoesNotOverflow test above (1,000,000 elements, no
        // interpreter overhead). This just confirms the real conj/reduce path is
        // wired correctly end to end — kept small since consuming a lazy range
        // through reduce pays the interpreter's documented high per-element cost
        // (CLAUDE.md: "Interpreter has a high per-element constant cost for
        // lazy-seq-driven code"), especially in debug builds.
        #expect(try swish.eval("(count (reduce conj '() (range 2000)))") == .integer(2000))
    }
}
