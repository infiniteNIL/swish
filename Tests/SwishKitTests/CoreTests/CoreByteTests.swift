import Testing
@testable import SwishKit

@Suite("byte coercion tests", .serialized)
struct CoreByteTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - integer input

    @Test("(byte -128) returns -128")
    func fromMinInt() throws {
        #expect(try swish.eval("(byte -128)") == .integer(-128))
    }

    @Test("(byte 0) returns 0")
    func fromZero() throws {
        #expect(try swish.eval("(byte 0)") == .integer(0))
    }

    @Test("(byte 127) returns 127")
    func fromMaxInt() throws {
        #expect(try swish.eval("(byte 127)") == .integer(127))
    }

    // MARK: - biginteger input

    @Test("(byte 1N) returns 1")
    func fromBigInt() throws {
        #expect(try swish.eval("(byte 1N)") == .integer(1))
    }

    @Test("(byte 0N) returns 0")
    func fromZeroBigInt() throws {
        #expect(try swish.eval("(byte 0N)") == .integer(0))
    }

    @Test("(byte -1N) returns -1")
    func fromNegBigInt() throws {
        #expect(try swish.eval("(byte -1N)") == .integer(-1))
    }

    // MARK: - bigdecimal input

    @Test("(byte 1.0M) returns 1")
    func fromBigDecimal() throws {
        #expect(try swish.eval("(byte 1.0M)") == .integer(1))
    }

    @Test("(byte 0.0M) returns 0")
    func fromZeroBigDecimal() throws {
        #expect(try swish.eval("(byte 0.0M)") == .integer(0))
    }

    @Test("(byte -1.0M) returns -1")
    func fromNegBigDecimal() throws {
        #expect(try swish.eval("(byte -1.0M)") == .integer(-1))
    }

    @Test("(byte 1.1M) truncates to 1")
    func fromFractionalBigDecimal() throws {
        #expect(try swish.eval("(byte 1.1M)") == .integer(1))
    }

    @Test("(byte -1.1M) truncates toward zero to -1")
    func fromNegFractionalBigDecimal() throws {
        #expect(try swish.eval("(byte -1.1M)") == .integer(-1))
    }

    // MARK: - float/double input (truncation toward zero)

    @Test("(byte 1.1) truncates to 1")
    func fromDoubleTruncates() throws {
        #expect(try swish.eval("(byte 1.1)") == .integer(1))
    }

    @Test("(byte -1.1) truncates toward zero to -1")
    func fromNegDoubleTruncates() throws {
        #expect(try swish.eval("(byte -1.1)") == .integer(-1))
    }

    @Test("(byte 1.9) truncates to 1")
    func fromDoubleTruncatesNotRounds() throws {
        #expect(try swish.eval("(byte 1.9)") == .integer(1))
    }

    // MARK: - ratio input (truncation toward zero)

    @Test("(byte 3/2) truncates to 1")
    func fromRatio() throws {
        #expect(try swish.eval("(byte 3/2)") == .integer(1))
    }

    @Test("(byte -3/2) truncates toward zero to -1")
    func fromNegRatio() throws {
        #expect(try swish.eval("(byte -3/2)") == .integer(-1))
    }

    @Test("(byte 1/10) truncates to 0")
    func fromSmallRatio() throws {
        #expect(try swish.eval("(byte 1/10)") == .integer(0))
    }

    @Test("(byte -1/10) truncates to 0")
    func fromNegSmallRatio() throws {
        #expect(try swish.eval("(byte -1/10)") == .integer(0))
    }

    // MARK: - byte range enforcement (throws, does not wrap)

    @Test("byte accepts -128 boundary")
    func minBoundary() throws {
        #expect(try swish.eval("(byte -128)") == .integer(-128))
    }

    @Test("byte accepts 127 boundary")
    func maxBoundary() throws {
        #expect(try swish.eval("(byte 127)") == .integer(127))
    }

    @Test("byte throws for integer below -128")
    func throwsBelowMin() {
        #expect(throws: (any Error).self) { try swish.eval("(byte -129)") }
    }

    @Test("byte throws for integer above 127")
    func throwsAboveMax() {
        #expect(throws: (any Error).self) { try swish.eval("(byte 128)") }
    }

    @Test("byte throws for double below -128")
    func throwsDoubleBelowMin() {
        #expect(throws: (any Error).self) { try swish.eval("(byte -128.000001)") }
    }

    @Test("byte throws for double above 127")
    func throwsDoubleAboveMax() {
        #expect(throws: (any Error).self) { try swish.eval("(byte 127.000001)") }
    }

    // MARK: - non-numeric types throw

    @Test("(byte \"0\") throws")
    func fromStringThrows() {
        #expect(throws: (any Error).self) { try swish.eval("(byte \"0\")") }
    }

    @Test("(byte :0) throws")
    func fromKeywordThrows() {
        #expect(throws: (any Error).self) { try swish.eval("(byte :0)") }
    }

    @Test("(byte [0]) throws")
    func fromVectorThrows() {
        #expect(throws: (any Error).self) { try swish.eval("(byte [0])") }
    }

    @Test("(byte nil) throws")
    func fromNilThrows() {
        #expect(throws: (any Error).self) { try swish.eval("(byte nil)") }
    }

    @Test("(byte) throws — wrong arity")
    func noArgs() {
        #expect(throws: (any Error).self) { try swish.eval("(byte)") }
    }

    @Test("(byte 1 2) throws — wrong arity")
    func tooManyArgs() {
        #expect(throws: (any Error).self) { try swish.eval("(byte 1 2)") }
    }

    // MARK: - result is a fixed-precision integer

    @Test("(int? (byte 0)) returns true")
    func resultIsInt() throws {
        #expect(try swish.eval("(int? (byte 0))") == .boolean(true))
    }

    // MARK: - usable as a higher-order function

    @Test("map byte over a sequence")
    func asHigherOrder() throws {
        #expect(try swish.eval("(map byte [1 2 3])") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }
}
