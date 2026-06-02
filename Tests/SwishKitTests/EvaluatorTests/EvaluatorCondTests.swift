import Testing
@testable import SwishKit

@Suite("Evaluator cond Tests", .serialized)
struct EvaluatorCondTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - second

    @Test("(second [1 2 3]) returns 2")
    func secondOfVector() throws {
        #expect(try swish.eval("(second [1 2 3])") == .integer(2))
    }

    @Test("(second [1]) returns nil")
    func secondOfSingletonReturnsNil() throws {
        #expect(try swish.eval("(second [1])") == .nil)
    }

    @Test("(second nil) returns nil")
    func secondOfNilReturnsNil() throws {
        #expect(try swish.eval("(second nil)") == .nil)
    }

    @Test("(second '(a b c)) returns b")
    func secondOfList() throws {
        #expect(try swish.eval("(second '(1 2 3))") == .integer(2))
    }

    // MARK: - cond basics

    @Test("(cond) returns nil")
    func condNoClausesReturnsNil() throws {
        #expect(try swish.eval("(cond)") == .nil)
    }

    @Test("(cond true 1) returns 1")
    func condSingleTrueClause() throws {
        #expect(try swish.eval("(cond true 1)") == .integer(1))
    }

    @Test("(cond false 1 true 2) returns 2")
    func condSkipsFalseClause() throws {
        #expect(try swish.eval("(cond false 1 true 2)") == .integer(2))
    }

    @Test("(cond false 1 false 2 true 3) returns 3")
    func condMultipleFalseThenTrue() throws {
        #expect(try swish.eval("(cond false 1 false 2 true 3)") == .integer(3))
    }

    @Test("(cond false 1 false 2) returns nil when no clause matches")
    func condNoMatchReturnsNil() throws {
        #expect(try swish.eval("(cond false 1 false 2)") == .nil)
    }

    @Test("(cond true 42 true 99) stops at first matching clause")
    func condStopsAtFirstMatch() throws {
        #expect(try swish.eval("(cond true 42 true 99)") == .integer(42))
    }

    // MARK: - expression tests and values

    @Test("test expression is evaluated")
    func condTestExprEvaluated() throws {
        #expect(try swish.eval("(cond (= 1 1) \"yes\")") == .string("yes"))
    }

    @Test("value expression is evaluated")
    func condValueExprEvaluated() throws {
        #expect(try swish.eval("(cond true (+ 1 2))") == .integer(3))
    }

    @Test("nil test is falsy")
    func condNilTestIsFalsy() throws {
        #expect(try swish.eval("(cond nil 1 true 2)") == .integer(2))
    }

    @Test(":else keyword as test is truthy")
    func condElseKeyword() throws {
        #expect(try swish.eval("(cond false 1 :else 99)") == .integer(99))
    }

    // MARK: - error case

    @Test("odd number of forms throws")
    func condOddFormsThrows() throws {
        #expect(throws: SwishException.self) {
            try swish.eval("(cond true)")
        }
    }
}
