import Testing
@testable import SwishKit

@Suite("Core lazy-seq? Tests", .serialized)
struct CoreLazySeqPredicateTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("lazy-seq? returns true for a lazy sequence")
    func lazySeqPredicateTrue() throws {
        #expect(try swish.eval("(lazy-seq? (map inc [1 2 3]))") == .boolean(true))
    }

    @Test("lazy-seq? returns false for an eager list")
    func lazySeqPredicateFalseList() throws {
        #expect(try swish.eval("(lazy-seq? '(1 2 3))") == .boolean(false))
    }

    @Test("lazy-seq? returns false for a vector")
    func lazySeqPredicateFalseVector() throws {
        #expect(try swish.eval("(lazy-seq? [1 2 3])") == .boolean(false))
    }

    @Test("lazy-seq? returns false for nil")
    func lazySeqPredicateFalseNil() throws {
        #expect(try swish.eval("(lazy-seq? nil)") == .boolean(false))
    }

    @Test("lazy-seq? returns false for an integer")
    func lazySeqPredicateFalseInteger() throws {
        #expect(try swish.eval("(lazy-seq? 42)") == .boolean(false))
    }
}
