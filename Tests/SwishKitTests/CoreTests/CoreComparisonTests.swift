import Testing
@testable import SwishKit

@Suite("Core Comparison Tests")
struct CoreComparisonTests {
    let swish = Swish()

    // MARK: - <

    @Test("(<) throws arityMismatch")
    func ltNoArgs() throws {
        #expect(throws: EvaluatorError.arityMismatch(name: "<", expected: .atLeastOne, got: 0)) {
            try swish.eval("(<)")
        }
    }

    @Test("(< 1) returns true")
    func ltOneArg() throws {
        #expect(try swish.eval("(< 1)") == .boolean(true))
    }

    @Test("(< 1 2) returns true")
    func ltTrue() throws {
        #expect(try swish.eval("(< 1 2)") == .boolean(true))
    }

    @Test("(< 2 1) returns false")
    func ltFalse() throws {
        #expect(try swish.eval("(< 2 1)") == .boolean(false))
    }

    @Test("(< 1 1) returns false")
    func ltEqual() throws {
        #expect(try swish.eval("(< 1 1)") == .boolean(false))
    }

    @Test("(< 1 2 3) returns true (chained)")
    func ltChainedTrue() throws {
        #expect(try swish.eval("(< 1 2 3)") == .boolean(true))
    }

    @Test("(< 1 3 2) returns false (chained)")
    func ltChainedFalse() throws {
        #expect(try swish.eval("(< 1 3 2)") == .boolean(false))
    }

    @Test("(< 1 2.0) returns true (int vs float)")
    func ltIntFloat() throws {
        #expect(try swish.eval("(< 1 2.0)") == .boolean(true))
    }

    @Test("(< 1/2 1) returns true (ratio vs int)")
    func ltRatioInt() throws {
        #expect(try swish.eval("(< 1/2 1)") == .boolean(true))
    }

    @Test("(< 1/3 1/2) returns true (ratio vs ratio)")
    func ltRatioRatio() throws {
        #expect(try swish.eval("(< 1/3 1/2)") == .boolean(true))
    }

    // MARK: - >

    @Test("(>) throws arityMismatch")
    func gtNoArgs() throws {
        #expect(throws: EvaluatorError.arityMismatch(name: ">", expected: .atLeastOne, got: 0)) {
            try swish.eval("(>)")
        }
    }

    @Test("(> 1) returns true")
    func gtOneArg() throws {
        #expect(try swish.eval("(> 1)") == .boolean(true))
    }

    @Test("(> 2 1) returns true")
    func gtTrue() throws {
        #expect(try swish.eval("(> 2 1)") == .boolean(true))
    }

    @Test("(> 1 2) returns false")
    func gtFalse() throws {
        #expect(try swish.eval("(> 1 2)") == .boolean(false))
    }

    @Test("(> 3 2 1) returns true (chained)")
    func gtChainedTrue() throws {
        #expect(try swish.eval("(> 3 2 1)") == .boolean(true))
    }

    @Test("(> 3 1 2) returns false (chained)")
    func gtChainedFalse() throws {
        #expect(try swish.eval("(> 3 1 2)") == .boolean(false))
    }

    // MARK: - <=

    @Test("(<=) throws arityMismatch")
    func lteNoArgs() throws {
        #expect(throws: EvaluatorError.arityMismatch(name: "<=", expected: .atLeastOne, got: 0)) {
            try swish.eval("(<=)")
        }
    }

    @Test("(<= 1) returns true")
    func lteOneArg() throws {
        #expect(try swish.eval("(<= 1)") == .boolean(true))
    }

    @Test("(<= 1 2) returns true")
    func lteTrue() throws {
        #expect(try swish.eval("(<= 1 2)") == .boolean(true))
    }

    @Test("(<= 1 1) returns true (equal)")
    func lteEqual() throws {
        #expect(try swish.eval("(<= 1 1)") == .boolean(true))
    }

    @Test("(<= 2 1) returns false")
    func lteFalse() throws {
        #expect(try swish.eval("(<= 2 1)") == .boolean(false))
    }

    @Test("(<= 1 2 2) returns true (chained with equal)")
    func lteChainedWithEqual() throws {
        #expect(try swish.eval("(<= 1 2 2)") == .boolean(true))
    }

    // MARK: - >=

    @Test("(>=) throws arityMismatch")
    func gteNoArgs() throws {
        #expect(throws: EvaluatorError.arityMismatch(name: ">=", expected: .atLeastOne, got: 0)) {
            try swish.eval("(>=)")
        }
    }

    @Test("(>= 1) returns true")
    func gteOneArg() throws {
        #expect(try swish.eval("(>= 1)") == .boolean(true))
    }

    @Test("(>= 2 1) returns true")
    func gteTrue() throws {
        #expect(try swish.eval("(>= 2 1)") == .boolean(true))
    }

    @Test("(>= 1 1) returns true (equal)")
    func gteEqual() throws {
        #expect(try swish.eval("(>= 1 1)") == .boolean(true))
    }

    @Test("(>= 1 2) returns false")
    func gteFalse() throws {
        #expect(try swish.eval("(>= 1 2)") == .boolean(false))
    }

    @Test("(>= 2 2 1) returns true (chained with equal)")
    func gteChainedWithEqual() throws {
        #expect(try swish.eval("(>= 2 2 1)") == .boolean(true))
    }

    // MARK: - =

    @Test("(=) throws arityMismatch")
    func eqNoArgs() throws {
        #expect(throws: EvaluatorError.arityMismatch(name: "=", expected: .atLeastOne, got: 0)) {
            try swish.eval("(=)")
        }
    }

    @Test("(= 1) returns true")
    func eqOneArg() throws {
        #expect(try swish.eval("(= 1)") == .boolean(true))
    }

    @Test("(= 1 1) returns true")
    func eqTrue() throws {
        #expect(try swish.eval("(= 1 1)") == .boolean(true))
    }

    @Test("(= 1 2) returns false")
    func eqFalse() throws {
        #expect(try swish.eval("(= 1 2)") == .boolean(false))
    }

    @Test("(= 1 1 1) returns true (chained)")
    func eqChainedTrue() throws {
        #expect(try swish.eval("(= 1 1 1)") == .boolean(true))
    }

    @Test("(= 1 1 2) returns false (chained)")
    func eqChainedFalse() throws {
        #expect(try swish.eval("(= 1 1 2)") == .boolean(false))
    }

    @Test("(= 1 1.0) returns false (no cross-type coercion)")
    func eqIntFloatFalse() throws {
        #expect(try swish.eval("(= 1 1.0)") == .boolean(false))
    }

    @Test("(= \"a\" \"a\") returns true")
    func eqStrings() throws {
        #expect(try swish.eval("(= \"a\" \"a\")") == .boolean(true))
    }

    @Test("(= true true) returns true")
    func eqBooleans() throws {
        #expect(try swish.eval("(= true true)") == .boolean(true))
    }

    @Test("(= nil nil) returns true")
    func eqNil() throws {
        #expect(try swish.eval("(= nil nil)") == .boolean(true))
    }

    // MARK: - not=

    @Test("(not=) throws arityMismatch")
    func notEqNoArgs() throws {
        #expect(throws: EvaluatorError.arityMismatch(name: "not=", expected: .atLeastOne, got: 0)) {
            try swish.eval("(not=)")
        }
    }

    @Test("(not= 1) returns false")
    func notEqOneArg() throws {
        #expect(try swish.eval("(not= 1)") == .boolean(false))
    }

    @Test("(not= 1 2) returns true")
    func notEqTrue() throws {
        #expect(try swish.eval("(not= 1 2)") == .boolean(true))
    }

    @Test("(not= 1 1) returns false")
    func notEqFalse() throws {
        #expect(try swish.eval("(not= 1 1)") == .boolean(false))
    }

    @Test("(not= 1 1 2) returns true (not all equal)")
    func notEqChained() throws {
        #expect(try swish.eval("(not= 1 1 2)") == .boolean(true))
    }

    @Test("(not= 1 1 1) returns false (all equal)")
    func notEqChainedFalse() throws {
        #expect(try swish.eval("(not= 1 1 1)") == .boolean(false))
    }
}
