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
}
