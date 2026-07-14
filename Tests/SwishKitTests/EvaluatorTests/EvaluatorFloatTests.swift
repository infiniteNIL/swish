import Testing
@testable import SwishKit

@Suite("Evaluator float Tests", .serialized)
struct EvaluatorFloatTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - Valid inputs

    @Test("float of integer 1")
    func floatFromInt() throws {
        #expect(try swish.eval("(float 1)") == .float(1.0))
    }

    @Test("float of integer 0")
    func floatFromZero() throws {
        #expect(try swish.eval("(float 0)") == .float(0.0))
    }

    @Test("float of integer -1")
    func floatFromNegInt() throws {
        #expect(try swish.eval("(float -1)") == .float(-1.0))
    }

    @Test("float of double 1.0")
    func floatFromDouble() throws {
        #expect(try swish.eval("(float 1.0)") == .float(1.0))
    }

    @Test("float of ratio 1/1")
    func floatFromRatio() throws {
        #expect(try swish.eval("(float 1/1)") == .float(1.0))
    }

    @Test("float of ##NaN returns NaN")
    func floatFromNaN() throws {
        let result = try swish.eval("(NaN? (float ##NaN))")
        #expect(result == .boolean(true))
    }

    // MARK: - Out-of-range inputs that must throw

    @Test("float of ##Inf throws")
    func floatInfThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(float ##Inf)") }
    }

    @Test("float of ##-Inf throws")
    func floatNegInfThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(float ##-Inf)") }
    }

    @Test("float of max-double throws")
    func floatMaxDoubleThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(float 1.7976931348623157e308)") }
    }
}
