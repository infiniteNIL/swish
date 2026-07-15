import Testing
@testable import SwishKit

@Suite("Core Promise Tests", .serialized)
struct CorePromiseTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("promise returns a promise object")
    func promiseReturnsPromise() throws {
        let result = try swish.eval("(promise)")
        if case .promise = result { }
        else { Issue.record("Expected .promise, got \(result)") }
    }

    @Test("promise is not realized before delivery")
    func promiseNotRealizedBeforeDeliver() throws {
        #expect(try swish.eval("(realized? (promise))") == .boolean(false))
    }

    @Test("deliver sets the value and realized? becomes true")
    func deliverSetsValue() throws {
        #expect(try swish.eval("(def p (promise)) (deliver p 42) (realized? p)") == .boolean(true))
    }

    @Test("deref returns the delivered value")
    func derefReturnsDeliveredValue() throws {
        #expect(try swish.eval("(def p (promise)) (deliver p 42) @p") == .integer(42))
    }

    @Test("delivering an already-delivered promise is a no-op and returns nil")
    func doubleDeliverIsNoOp() throws {
        #expect(try swish.eval("(def p (promise)) (deliver p 1) (deliver p 2) @p") == .integer(1))
        #expect(try swish.eval("(def p2 (promise)) (deliver p2 1) (deliver p2 2)") == .nil)
    }

    @Test("a promise is callable — calling it delivers")
    func promiseIsCallable() throws {
        #expect(try swish.eval("(def p (promise)) (ifn? p)") == .boolean(true))
        #expect(try swish.eval("(def p2 (promise)) (p2 99) @p2") == .integer(99))
    }
}
