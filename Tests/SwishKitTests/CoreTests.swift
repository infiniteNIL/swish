import Testing
@testable import SwishKit

@Suite("Core Builtin Tests")
struct CoreTests {
    let swish = Swish()

    // MARK: - +

    @Test("(+) returns 0")
    func addNoArgs() throws {
        #expect(try swish.eval("(+)") == .integer(0))
    }

    @Test("(+ 5) returns 5")
    func addOneInt() throws {
        #expect(try swish.eval("(+ 5)") == .integer(5))
    }

    @Test("(+ 1 2 3) returns 6")
    func addIntegers() throws {
        #expect(try swish.eval("(+ 1 2 3)") == .integer(6))
    }

    @Test("(+ 1.0 2.0) returns 3.0")
    func addFloats() throws {
        #expect(try swish.eval("(+ 1.0 2.0)") == .float(3.0))
    }

    @Test("(+ 1 2.0) returns 3.0 (int + float promotes to float)")
    func addIntAndFloat() throws {
        #expect(try swish.eval("(+ 1 2.0)") == .float(3.0))
    }

    @Test("(+ 1/2 1/3) returns 5/6")
    func addRatios() throws {
        #expect(try swish.eval("(+ 1/2 1/3)") == .ratio(Ratio(5, 6)))
    }

    @Test("(+ 1/2 1/2) returns 1 (ratio reduces to integer)")
    func addRatiosReducesToInt() throws {
        #expect(try swish.eval("(+ 1/2 1/2)") == .integer(1))
    }

    @Test("(+ 1 1/3) returns 4/3 (int + ratio)")
    func addIntAndRatio() throws {
        #expect(try swish.eval("(+ 1 1/3)") == .ratio(Ratio(4, 3)))
    }

    @Test("(+ 1/2 0.5) returns 1.0 (ratio + float promotes to float)")
    func addRatioAndFloat() throws {
        #expect(try swish.eval("(+ 1/2 0.5)") == .float(1.0))
    }

    @Test("(+ 1.5) returns 1.5 (single float)")
    func addOneFloat() throws {
        #expect(try swish.eval("(+ 1.5)") == .float(1.5))
    }

    @Test("(+ 1/3) returns 1/3 (single ratio)")
    func addOneRatio() throws {
        #expect(try swish.eval("(+ 1/3)") == .ratio(Ratio(1, 3)))
    }

    @Test("(+ \"a\") throws invalidArgument")
    func addNonNumericThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "+", message: "expected a number, got \"a\"")) {
            try swish.eval("(+ \"a\")")
        }
    }

    // MARK: - -

    @Test("(-) throws invalidArgument")
    func subtractNoArgs() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "-", message: "requires at least 1 argument")) {
            try swish.eval("(-)")
        }
    }

    @Test("(- 5) negates integer")
    func negateInt() throws {
        #expect(try swish.eval("(- 5)") == .integer(-5))
    }

    @Test("(- 3.0) negates float")
    func negateFloat() throws {
        #expect(try swish.eval("(- 3.0)") == .float(-3.0))
    }

    @Test("(- 1/3) negates ratio")
    func negateRatio() throws {
        #expect(try swish.eval("(- 1/3)") == .ratio(Ratio(-1, 3)))
    }

    @Test("(- 10 3 2) subtracts left to right")
    func subtractIntegers() throws {
        #expect(try swish.eval("(- 10 3 2)") == .integer(5))
    }

    @Test("(- 1.0 0.5) subtracts floats")
    func subtractFloats() throws {
        #expect(try swish.eval("(- 1.0 0.5)") == .float(0.5))
    }

    @Test("(- 1 1/2) subtracts int and ratio")
    func subtractIntAndRatio() throws {
        #expect(try swish.eval("(- 1 1/2)") == .ratio(Ratio(1, 2)))
    }

    // MARK: - *

    @Test("(*) returns 1")
    func multiplyNoArgs() throws {
        #expect(try swish.eval("(*)") == .integer(1))
    }

    @Test("(* 7) returns 7")
    func multiplyOneArg() throws {
        #expect(try swish.eval("(* 7)") == .integer(7))
    }

    @Test("(* 2 3 4) returns 24")
    func multiplyIntegers() throws {
        #expect(try swish.eval("(* 2 3 4)") == .integer(24))
    }

    @Test("(* 2.0 3.0) returns 6.0")
    func multiplyFloats() throws {
        #expect(try swish.eval("(* 2.0 3.0)") == .float(6.0))
    }

    @Test("(* 2 3.0) returns 6.0 (int * float promotes to float)")
    func multiplyIntAndFloat() throws {
        #expect(try swish.eval("(* 2 3.0)") == .float(6.0))
    }

    @Test("(* 2/3 3/4) returns 1/2")
    func multiplyRatios() throws {
        #expect(try swish.eval("(* 2/3 3/4)") == .ratio(Ratio(1, 2)))
    }

    @Test("(* 2/3 3) returns 2 (ratio * int reduces to integer)")
    func multiplyRatioAndInt() throws {
        #expect(try swish.eval("(* 2/3 3)") == .integer(2))
    }

    @Test("(* 1/2 2.0) returns 1.0 (ratio * float promotes to float)")
    func multiplyRatioAndFloat() throws {
        #expect(try swish.eval("(* 1/2 2.0)") == .float(1.0))
    }

    // MARK: - /

    @Test("(/) throws invalidArgument")
    func divideNoArgs() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "/", message: "requires at least 1 argument")) {
            try swish.eval("(/)")
        }
    }

    @Test("(/ 4) returns reciprocal as ratio")
    func reciprocalInt() throws {
        #expect(try swish.eval("(/ 4)") == .ratio(Ratio(1, 4)))
    }

    @Test("(/ 1) returns 1 (reciprocal of 1 reduces to integer)")
    func reciprocalOneReducesToInt() throws {
        #expect(try swish.eval("(/ 1)") == .integer(1))
    }

    @Test("(/ 2.0) returns 0.5 (reciprocal of float)")
    func reciprocalFloat() throws {
        #expect(try swish.eval("(/ 2.0)") == .float(0.5))
    }

    @Test("(/ 1/3) returns 3 (reciprocal of ratio reduces to integer)")
    func reciprocalRatioReducesToInt() throws {
        #expect(try swish.eval("(/ 1/3)") == .integer(3))
    }

    @Test("(/ 2/3) returns 3/2")
    func reciprocalRatio() throws {
        #expect(try swish.eval("(/ 2/3)") == .ratio(Ratio(3, 2)))
    }

    @Test("(/ 10 4) returns 5/2 (int/int → ratio)")
    func divideIntByInt() throws {
        #expect(try swish.eval("(/ 10 4)") == .ratio(Ratio(5, 2)))
    }

    @Test("(/ 10 2) returns 5 (int/int reduces to integer)")
    func divideIntByIntReducesToInt() throws {
        #expect(try swish.eval("(/ 10 2)") == .integer(5))
    }

    @Test("(/ 12 3 2) divides left to right")
    func divideIntegers() throws {
        #expect(try swish.eval("(/ 12 3 2)") == .integer(2))
    }

    @Test("(/ 1.0 4.0) returns 0.25")
    func divideFloats() throws {
        #expect(try swish.eval("(/ 1.0 4.0)") == .float(0.25))
    }

    @Test("(/ 1/2 1/4) returns 2")
    func divideRatios() throws {
        #expect(try swish.eval("(/ 1/2 1/4)") == .integer(2))
    }

    @Test("(/ 1 0) throws division by zero")
    func divideByZeroThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "/", message: "division by zero")) {
            try swish.eval("(/ 1 0)")
        }
    }
}
