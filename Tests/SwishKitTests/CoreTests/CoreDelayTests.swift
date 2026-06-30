import Testing
@testable import SwishKit

@Suite("Core Delay Tests", .serialized)
struct CoreDelayTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("delay returns a delay object")
    func delayReturnsDelay() throws {
        let result = try swish.eval("(delay 42)")
        if case .delay = result { }
        else { Issue.record("Expected .delay, got \(result)") }
    }

    @Test("delay is not realized before forcing")
    func delayNotRealizedBeforeForce() throws {
        #expect(try swish.eval("(realized? (delay 42))") == .boolean(false))
    }

    @Test("deref forces a delay")
    func derefForcesDelay() throws {
        #expect(try swish.eval("(deref (delay 42))") == .integer(42))
    }

    @Test("@ forces a delay")
    func atForcesDelay() throws {
        #expect(try swish.eval("(let [d (delay 42)] @d)") == .integer(42))
    }

    @Test("delay is realized after forcing")
    func delayRealizedAfterForce() throws {
        #expect(try swish.eval("(let [d (delay 42)] (deref d) (realized? d))") == .boolean(true))
    }

    @Test("force forces a delay")
    func forceForcesDelay() throws {
        #expect(try swish.eval("(force (delay 42))") == .integer(42))
    }

    @Test("force returns non-delay unchanged")
    func forceNonDelayIsIdentity() throws {
        #expect(try swish.eval("(force 99)") == .integer(99))
    }

    @Test("delay? returns true for delay")
    func delayPredTrue() throws {
        #expect(try swish.eval("(delay? (delay 1))") == .boolean(true))
    }

    @Test("delay? returns false for non-delay")
    func delayPredFalse() throws {
        #expect(try swish.eval("(delay? 42)") == .boolean(false))
    }

    @Test("delay body is evaluated at most once")
    func delayEvaluatedOnce() throws {
        #expect(try swish.eval("""
            (let [n (atom 0)
                  d (delay (swap! n inc))]
              (deref d)
              (deref d)
              @n)
            """) == .integer(1))
    }

    @Test("realized? returns true for realized lazy-seq")
    func realizedLazySeq() throws {
        #expect(try swish.eval("(let [s (map inc [1 2 3])] (doall s) (realized? s))") == .boolean(true))
    }
}
