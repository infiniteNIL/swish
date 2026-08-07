import Testing
@testable import SwishKit

/// Indexed access agreement across every entry point into a vector.
///
/// `nth`/`get`/`get-in`/`contains?`/`find` used to reach an element by materializing the
/// whole `SwishPersistentVector` into an array (O(n) plus an allocation) while calling the
/// vector as a function went through the O(log₃₂ n) trie subscript. They now share
/// `vectorElement(_:at:)`, so these assert all five agree — including on the boundaries,
/// where an off-by-one in the new bounds check would show up.
///
/// Every case uses a **>32-element** vector on purpose: `SwishPersistentVector` keeps the
/// last ≤32 elements in a flat tail and only builds trie levels beyond that, so a smaller
/// vector would never exercise the indexed path this covers.
@Suite("Core Vector Indexed Access Tests", .serialized)
struct CoreVectorIndexedAccessTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    /// 100 elements — three tail-fulls plus trie levels.
    private static let bigVec = "(vec (range 100))"

    @Test("nth, get, and calling the vector agree at the head, an interior index, and the last index")
    func agreementAcrossEntryPoints() throws {
        for i in [0, 1, 31, 32, 33, 63, 64, 98, 99] {
            let expected = Expr.integer(i)
            #expect(try swish.eval("(nth \(Self.bigVec) \(i))") == expected, "nth at \(i)")
            #expect(try swish.eval("(get \(Self.bigVec) \(i))") == expected, "get at \(i)")
            #expect(try swish.eval("(\(Self.bigVec) \(i))") == expected, "call at \(i)")
            #expect(try swish.eval("(get-in [\(Self.bigVec)] [0 \(i)])") == expected, "get-in at \(i)")
        }
    }

    @Test("find returns the [index value] entry, and nil past the end")
    func findEntry() throws {
        #expect(try swish.eval("(find \(Self.bigVec) 64)") == .vector([.integer(64), .integer(64)], metadata: nil))
        #expect(try swish.eval("(find \(Self.bigVec) 100)") == .nil)
        #expect(try swish.eval("(find \(Self.bigVec) -1)") == .nil)
    }

    @Test("contains? tests the index range, not membership — true only for 0..<count")
    func containsIsIndexRange() throws {
        #expect(try swish.eval("(contains? \(Self.bigVec) 0)") == .boolean(true))
        #expect(try swish.eval("(contains? \(Self.bigVec) 99)") == .boolean(true))
        #expect(try swish.eval("(contains? \(Self.bigVec) 100)") == .boolean(false))
        #expect(try swish.eval("(contains? \(Self.bigVec) -1)") == .boolean(false))
    }

    @Test("Out of range: get returns nil, nth throws, nth with not-found returns it")
    func outOfRange() throws {
        #expect(try swish.eval("(get \(Self.bigVec) 100)") == .nil)
        #expect(try swish.eval("(get \(Self.bigVec) -1)") == .nil)
        #expect(try swish.eval("(nth \(Self.bigVec) 100 :missing)") == .keyword("missing"))
        #expect(try swish.eval("(nth \(Self.bigVec) -1 :missing)") == .keyword("missing"))
        #expect(throws: (any Error).self) { try swish.eval("(nth \(Self.bigVec) 100)") }
        #expect(throws: (any Error).self) { try swish.eval("(nth \(Self.bigVec) -1)") }
    }

    @Test("A non-integer key is nil for get/find, false for contains?, and throws for nth")
    func nonIntegerKey() throws {
        #expect(try swish.eval("(get \(Self.bigVec) :k)") == .nil)
        #expect(try swish.eval("(find \(Self.bigVec) :k)") == .nil)
        #expect(try swish.eval("(contains? \(Self.bigVec) :k)") == .boolean(false))
        #expect(throws: (any Error).self) { try swish.eval("(nth \(Self.bigVec) :k)") }
    }

    // MARK: - The sharedVector representation must behave identically

    /// `(vec some-array)` produces `.sharedVector`, the other vector case — it shares the
    /// array's storage rather than using the trie, and every accessor must treat it the same.
    private static let sharedVec = "(vec (object-array 100))"

    @Test("A sharedVector answers the same nth/get/contains?/call as a trie-backed vector")
    func sharedVectorAgreement() throws {
        #expect(try swish.eval("(count \(Self.sharedVec))") == .integer(100))
        #expect(try swish.eval("(nth \(Self.sharedVec) 64)") == .nil)
        #expect(try swish.eval("(get \(Self.sharedVec) 64)") == .nil)
        #expect(try swish.eval("(contains? \(Self.sharedVec) 99)") == .boolean(true))
        #expect(try swish.eval("(contains? \(Self.sharedVec) 100)") == .boolean(false))
        #expect(try swish.eval("(nth \(Self.sharedVec) 100 :missing)") == .keyword("missing"))
    }

    @Test("subvec still slices correctly across a trie boundary")
    func subvecAcrossTrieBoundary() throws {
        #expect(try swish.eval("(subvec \(Self.bigVec) 30 35)")
                == .vector([.integer(30), .integer(31), .integer(32), .integer(33), .integer(34)], metadata: nil))
        #expect(try swish.eval("(count (subvec \(Self.bigVec) 0 100))") == .integer(100))
        #expect(try swish.eval("(count (subvec \(Self.bigVec) 99))") == .integer(1))
    }
}
