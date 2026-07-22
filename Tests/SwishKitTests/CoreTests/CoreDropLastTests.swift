import Testing
@testable import SwishKit

@Suite("Core drop-last Tests", .serialized)
struct CoreDropLastTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - 1-arity (default n = 1)

    @Test("(drop-last (range 10)) drops the last item")
    func dropLastDefaultN() throws {
        #expect(try swish.eval("(drop-last (range 10))") == .list(SwishPersistentList([0, 1, 2, 3, 4, 5, 6, 7, 8].map { .integer($0) }), metadata: nil))
    }

    @Test("(drop-last nil) returns an empty seq")
    func dropLastNilColl() throws {
        #expect(try swish.eval("(drop-last nil)") == .list([], metadata: nil))
    }

    // MARK: - 2-arity

    @Test("(drop-last 5 (range 10)) drops the last 5 items")
    func dropLastExplicitN() throws {
        #expect(try swish.eval("(drop-last 5 (range 10))") == .list(SwishPersistentList([0, 1, 2, 3, 4].map { .integer($0) }), metadata: nil))
    }

    @Test("(drop-last 5 nil) returns an empty seq")
    func dropLastExplicitNNilColl() throws {
        #expect(try swish.eval("(drop-last 5 nil)") == .list([], metadata: nil))
    }

    @Test("(drop-last 0 (range 5)) returns all items")
    func dropLastZero() throws {
        #expect(try swish.eval("(drop-last 0 (range 5))") == .list(SwishPersistentList([0, 1, 2, 3, 4].map { .integer($0) }), metadata: nil))
    }

    @Test("(drop-last 10 (range 5)) returns an empty seq when n exceeds count")
    func dropLastNExceedsCount() throws {
        #expect(try swish.eval("(drop-last 10 (range 5))") == .list([], metadata: nil))
    }

    // MARK: - error case

    @Test("(doall (drop-last nil (range 5))) throws")
    func dropLastNilNThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(doall (drop-last nil (range 5)))")
        }
    }

    // MARK: - laziness

    @Test("drop-last is lazy on an infinite seq")
    func dropLastLazyOnInfinite() throws {
        #expect(try swish.eval("(take 3 (drop-last 2 (range)))") == .list(SwishPersistentList([0, 1, 2].map { .integer($0) }), metadata: nil))
    }

    @Test("drop-last returns a lazy seq")
    func dropLastReturnsLazySeq() throws {
        #expect(try swish.eval("(seq? (drop-last 1 (range)))") == .boolean(true))
    }
}
