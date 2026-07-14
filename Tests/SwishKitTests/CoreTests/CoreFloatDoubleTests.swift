import Testing
@testable import SwishKit

@Suite("Core Float/Double Predicate Tests", .serialized)
struct CoreFloatDoubleTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - double?

    @Test("double? returns false for (float ...) values")
    func doubleQmarkFloat() throws {
        #expect(try swish.eval("(double? (float 0.0))") == .boolean(false))
        #expect(try swish.eval("(double? (float 1.0))") == .boolean(false))
        #expect(try swish.eval("(double? (float -1.0))") == .boolean(false))
    }

    @Test("double? returns true for double literals and (double ...)")
    func doubleQmarkDouble() throws {
        #expect(try swish.eval("(double? 0.0)") == .boolean(true))
        #expect(try swish.eval("(double? (double 0.0))") == .boolean(true))
    }

    // MARK: - float?

    @Test("float? returns true for (float ...) values")
    func floatQmarkFloat() throws {
        #expect(try swish.eval("(float? (float 0.0))") == .boolean(true))
        #expect(try swish.eval("(float? (float 1.0))") == .boolean(true))
        #expect(try swish.eval("(float? (float -1.0))") == .boolean(true))
    }

    @Test("float? returns true for double literals and (double ...)")
    func floatQmarkDouble() throws {
        #expect(try swish.eval("(float? 0.0)") == .boolean(true))
        #expect(try swish.eval("(float? (double 0.0))") == .boolean(true))
    }
}
