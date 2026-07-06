import Testing
@testable import SwishKit

@Suite("Core concat Tests", .serialized)
struct CoreConcatTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("(concat) returns an unrealized lazy seq")
    func concatZeroArityUnrealized() throws {
        #expect(try swish.eval("(realized? (concat))") == .boolean(false))
    }

    @Test("(seq (concat)) returns nil")
    func concatZeroAritySeqNil() throws {
        #expect(try swish.eval("(seq (concat))") == .nil)
    }

    // MARK: - vector == lazy-seq equality

    @Test("(= [1 2 3] (concat '(1 2 3))) is true (vector == lazy-seq)")
    func vectorEqualsLazySeq() throws {
        #expect(try swish.eval("(= [1 2 3] (concat '(1 2 3)))") == .boolean(true))
    }

    @Test("(= [0 1 2 3 4] (take 5 (concat (range)))) is true (infinite range)")
    func vectorEqualsInfiniteRangeSlice() throws {
        #expect(try swish.eval("(= [0 1 2 3 4] (take 5 (concat (range))))") == .boolean(true))
    }

    @Test("(= (concat '(1 2 3)) [1 2 3]) is true (lazy-seq == vector, reversed)")
    func lazySeqEqualsVector() throws {
        #expect(try swish.eval("(= (concat '(1 2 3)) [1 2 3])") == .boolean(true))
    }
}
