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
}
