import Testing
@testable import SwishKit

@Suite("Evaluator try/catch/finally/throw Tests", .serialized)
struct EvaluatorTryCatchTests {
    static let _shared = Evaluator()
    var evaluator: Evaluator { Self._shared }

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

    // MARK: - typed catch (catch-on-type dispatch)

    @Test("catch ExceptionInfo catches an ex-info")
    func catchExceptionInfo() throws {
        #expect(try evaluator.eval(#"(try (throw (ex-info "boom" {})) (catch ExceptionInfo e (ex-message e)))"#) == .string("boom"))
    }

    @Test("catch String catches a thrown string")
    func catchString() throws {
        #expect(try evaluator.eval(#"(try (throw "raw") (catch String e e))"#) == .string("raw"))
    }

    @Test("a non-matching typed catch lets the exception reach a later catch")
    func typedCatchPropagatesWrongType() throws {
        #expect(try evaluator.eval(#"(try (throw (ex-info "x" {})) (catch String e :string) (catch Exception e :exc))"#) == .keyword("exc"))
    }

    @Test("catch clauses are tried in order, first match wins")
    func typedCatchOrderedFirstMatch() throws {
        #expect(try evaluator.eval(#"(try (throw (ex-info "x" {})) (catch ExceptionInfo e :exinfo) (catch Exception e :exc))"#) == .keyword("exinfo"))
    }

    @Test("Throwable and Error are catch-alls like Exception")
    func throwableAndErrorAreCatchAlls() throws {
        #expect(try evaluator.eval(#"(try (throw "x") (catch Throwable e :thr))"#) == .keyword("thr"))
        #expect(try evaluator.eval(#"(try (throw "x") (catch Error e :err))"#) == .keyword("err"))
    }

    @Test("catch dispatches on a defrecord type")
    func catchOnRecordType() throws {
        _ = try evaluator.eval("(defrecord CatchBoom [x])")
        #expect(try evaluator.eval("(try (throw (->CatchBoom 7)) (catch CatchBoom e (:x e)) (catch Exception e :wrong))") == .integer(7))
    }

    @Test("an unresolvable catch type never matches, so the throw propagates")
    func unresolvableCatchTypePropagates() throws {
        #expect(throws: SwishException.self) {
            try evaluator.eval(#"(try (throw (ex-info "x" {})) (catch NoSuchType e :nope))"#)
        }
    }
}
