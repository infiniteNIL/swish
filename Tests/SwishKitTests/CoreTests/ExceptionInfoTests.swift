import Testing
@testable import SwishKit

@Suite("ex-info/ex-message/ex-data/ex-cause Tests", .serialized)
struct ExceptionInfoTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - ex-info

    @Test("ex-info 2-arity constructs an ExceptionInfo with nil cause")
    func exInfoTwoArity() throws {
        #expect(try swish.eval(#"(:message (ex-info "boom" {:code 1}))"#) == .string("boom"))
        #expect(try swish.eval(#"(:data (ex-info "boom" {:code 1}))"#) == .map([.keyword("code"): .integer(1)], metadata: nil))
        #expect(try swish.eval(#"(:cause (ex-info "boom" {:code 1}))"#) == .nil)
    }

    @Test("ex-info 3-arity attaches a cause")
    func exInfoThreeArity() throws {
        #expect(try swish.eval(#"(:cause (ex-info "boom" {} :inner))"#) == .keyword("inner"))
    }

    @Test("ex-info returns an ExceptionInfo instance")
    func exInfoIsExceptionInfoInstance() throws {
        #expect(try swish.eval(#"(instance? ExceptionInfo (ex-info "boom" {}))"#) == .boolean(true))
    }

    // MARK: - ex-message

    @Test("ex-message on an ex-info value returns its message")
    func exMessageOnExInfo() throws {
        #expect(try swish.eval(#"(ex-message (ex-info "boom" {}))"#) == .string("boom"))
    }

    @Test("ex-message on a caught plain thrown string returns the string itself")
    func exMessageOnPlainString() throws {
        #expect(
            try swish.eval(#"(try (throw "boom") (catch Exception e (ex-message e)))"#)
                == .string("boom"))
    }

    @Test("ex-message on a caught native runtime error returns its description")
    func exMessageOnNativeError() throws {
        let result = try swish.eval("(try (/ 1 0) (catch Exception e (ex-message e)))")
        guard case .string(let s) = result else {
            Issue.record("expected .string, got \(result)")
            return
        }
        #expect(!s.isEmpty)
    }

    @Test("ex-message on a value with no message returns nil")
    func exMessageOnNonMessageValue() throws {
        #expect(try swish.eval("(ex-message :not-an-exception)") == .nil)
    }

    // MARK: - ex-data

    @Test("ex-data on an ex-info value returns its data map")
    func exDataOnExInfo() throws {
        #expect(
            try swish.eval(#"(ex-data (ex-info "boom" {:code 42}))"#)
                == .map([.keyword("code"): .integer(42)], metadata: nil))
    }

    @Test("ex-data on a non-ex-info value returns nil")
    func exDataOnNonExInfo() throws {
        #expect(try swish.eval(#"(ex-data "boom")"#) == .nil)
    }

    // MARK: - ex-cause

    @Test("ex-cause on an ex-info value returns its cause")
    func exCauseOnExInfo() throws {
        #expect(try swish.eval(#"(ex-cause (ex-info "boom" {} :inner))"#) == .keyword("inner"))
    }

    @Test("ex-cause on an ex-info value with no cause returns nil")
    func exCauseNoCause() throws {
        #expect(try swish.eval(#"(ex-cause (ex-info "boom" {}))"#) == .nil)
    }

    @Test("ex-cause on a non-ex-info value returns nil")
    func exCauseOnNonExInfo() throws {
        #expect(try swish.eval(#"(ex-cause "boom")"#) == .nil)
    }

    // MARK: - throw/catch round trip

    @Test("throwing an ex-info value round-trips through catch as the same record")
    func exInfoRoundTripsThroughCatch() throws {
        #expect(
            try swish.eval(#"""
                (try
                  (throw (ex-info "boom" {:code 1}))
                  (catch Exception e
                    [(instance? ExceptionInfo e) (ex-message e) (ex-data e)]))
                """#)
                == .vector(
                    [.boolean(true), .string("boom"), .map([.keyword("code"): .integer(1)], metadata: nil)],
                    metadata: nil))
    }
}
