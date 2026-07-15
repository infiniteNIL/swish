import Testing
@testable import SwishKit

@Suite("Core Future Tests", .serialized)
struct CoreFutureTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("future returns a future object")
    func futureReturnsFuture() throws {
        let result = try swish.eval("(future 42)")
        if case .future = result { }
        else { Issue.record("Expected .future, got \(result)") }
    }

    @Test("future? recognizes a future")
    func futurePredicate() throws {
        #expect(try swish.eval("(future? (future 42))") == .boolean(true))
        #expect(try swish.eval("(future? 42)") == .boolean(false))
    }

    @Test("deref blocks and returns the future's result")
    func derefReturnsResult() throws {
        #expect(try swish.eval("@(future (+ 1 2))") == .integer(3))
    }

    @Test("realized? becomes true after deref")
    func realizedAfterDeref() throws {
        #expect(try swish.eval("(def f (future 42)) (deref f) (realized? f)") == .boolean(true))
    }

    @Test("future-done? becomes true after deref")
    func futureDoneAfterDeref() throws {
        #expect(try swish.eval("(def f (future 42)) (deref f) (future-done? f)") == .boolean(true))
    }

    @Test("deref rethrows an exception raised in the future's body")
    func derefRethrowsBodyException() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("@(future (throw \"boom\"))")
        }
    }

    @Test("future-cancel synchronously marks a still-running future realized and cancelled")
    func futureCancelIsSynchronous() throws {
        #expect(try swish.eval("""
            (def f (future (swish-sleep! 10000)))
            (realized? f)
            """) == .boolean(false))
        #expect(try swish.eval("(future-cancel f)") == .boolean(true))
        #expect(try swish.eval("(realized? f)") == .boolean(true))
        #expect(try swish.eval("(future-cancelled? f)") == .boolean(true))
    }

    @Test("future-cancel on an already-realized future returns false")
    func futureCancelOnRealizedReturnsFalse() throws {
        #expect(try swish.eval("(def f (future 1)) (deref f) (future-cancel f)") == .boolean(false))
    }

    @Test("deref on a cancelled future throws")
    func derefOnCancelledThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(def f (future (swish-sleep! 10000))) (future-cancel f) (deref f)")
        }
    }
}
