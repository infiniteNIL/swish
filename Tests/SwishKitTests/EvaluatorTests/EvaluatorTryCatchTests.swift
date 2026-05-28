import Testing
@testable import SwishKit

@Suite("Evaluator try/catch/finally/throw Tests")
struct EvaluatorTryCatchTests {
    let evaluator = Evaluator()

    // MARK: - try

    @Test("(try) returns nil")
    func tryNoBodyReturnsNil() throws {
        #expect(try evaluator.eval("(try)") == .nil)
    }

    @Test("(try expr) returns expr")
    func tryWithBodyReturnsValue() throws {
        #expect(try evaluator.eval("(try 42)") == .integer(42))
    }

    @Test("try returns last body expression")
    func tryReturnsLastBodyExpr() throws {
        #expect(try evaluator.eval("(try 1 2 3)") == .integer(3))
    }

    // MARK: - throw / catch

    @Test("caught throw value is bound in catch")
    func caughtThrowValueBound() throws {
        #expect(try evaluator.eval("(try (throw \"oops\") (catch Exception e e))") == .string("oops"))
    }

    @Test("throw a map and extract a key in catch")
    func throwMapExtractKey() throws {
        #expect(try evaluator.eval("(try (throw {:code 42}) (catch Exception e (:code e)))") == .integer(42))
    }

    @Test("uncaught throw propagates as SwishException")
    func uncaughtThrowPropagates() throws {
        #expect(throws: SwishException.self) {
            try evaluator.eval("(try (throw \"boom\"))")
        }
    }

    @Test("uncaught throw carries the thrown value")
    func uncaughtThrowCarriesValue() throws {
        do {
            _ = try evaluator.eval("(try (throw \"boom\"))")
        }
        catch let e as SwishException {
            #expect(e.value == .string("boom"))
        }
    }

    @Test("evaluator error is catchable")
    func evaluatorErrorIsCatchable() throws {
        #expect(try evaluator.eval("(try (/ 1 0) (catch Exception e \"got-it\"))") == .string("got-it"))
    }

    @Test("catch body result is returned")
    func catchBodyResultReturned() throws {
        #expect(try evaluator.eval("(try (throw 1) (catch Exception e (+ e 10)))") == .integer(11))
    }

    @Test("first matching catch wins")
    func firstMatchingCatchWins() throws {
        #expect(try evaluator.eval("(try (throw \"x\") (catch Exception e \"first\") (catch Exception e \"second\"))") == .string("first"))
    }

    @Test("nested try rethrow reaches outer catch")
    func nestedTryRethrowReachesOuter() throws {
        let result = try evaluator.eval("""
            (try
              (try (throw "inner") (catch Exception e (throw "outer")))
              (catch Exception e e))
            """)
        #expect(result == .string("outer"))
    }

    // MARK: - finally

    @Test("finally runs, result is from try body")
    func finallyRunsResultIsFromTryBody() throws {
        #expect(try evaluator.eval("(try 1 (finally 99))") == .integer(1))
    }

    @Test("finally runs after catch, result is from catch")
    func finallyRunsAfterCatch() throws {
        #expect(try evaluator.eval("(try (throw \"x\") (catch Exception e \"caught\") (finally \"fin\"))") == .string("caught"))
    }

    @Test("finally exception masks uncaught try exception")
    func finallyExceptionMasksTryException() throws {
        do {
            _ = try evaluator.eval("(try (throw \"try-err\") (finally (throw \"finally-err\")))")
            Issue.record("Expected exception")
        }
        catch let e as SwishException {
            #expect(e.value == .string("finally-err"))
        }
    }

    @Test("finally exception masks successful try result")
    func finallyExceptionMasksTryResult() throws {
        #expect(throws: SwishException.self) {
            try evaluator.eval("(try 1 (finally (throw \"oops\")))")
        }
    }

    // MARK: - parse-time errors

    @Test("(throw) with no argument fails at parse time")
    func throwNoArgFailsAtParseTime() throws {
        #expect(throws: ParserError.self) {
            try Reader.readString("(throw)")
        }
    }

    @Test("(throw 1 2) with extra argument fails at parse time")
    func throwExtraArgFailsAtParseTime() throws {
        #expect(throws: ParserError.self) {
            try Reader.readString("(throw 1 2)")
        }
    }

    // MARK: - structural errors

    @Test("catch after finally is an error")
    func catchAfterFinallyIsError() throws {
        #expect(throws: EvaluatorError.self) {
            try evaluator.eval("(try 1 (finally 2) (catch Exception e e))")
        }
    }

    @Test("body form after catch is an error")
    func bodyAfterCatchIsError() throws {
        #expect(throws: EvaluatorError.self) {
            try evaluator.eval("(try 1 (catch Exception e e) 2)")
        }
    }
}
