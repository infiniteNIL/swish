import Testing
@testable import SwishKit

@Suite("int coercion tests", .serialized)
struct CoreIntTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - integer input

    @Test("(int 42) returns 42")
    func fromInt() throws {
        #expect(try swish.eval("(int 42)") == .integer(42))
    }

    @Test("(int 0) returns 0")
    func fromZero() throws {
        #expect(try swish.eval("(int 0)") == .integer(0))
    }

    @Test("(int -7) returns -7")
    func fromNegativeInt() throws {
        #expect(try swish.eval("(int -7)") == .integer(-7))
    }

    // MARK: - float input (truncation toward zero)

    @Test("(int 3.9) truncates to 3")
    func fromFloatTruncates() throws {
        #expect(try swish.eval("(int 3.9)") == .integer(3))
    }

    @Test("(int -3.9) truncates toward zero to -3")
    func fromNegFloatTruncates() throws {
        #expect(try swish.eval("(int -3.9)") == .integer(-3))
    }

    @Test("(int 3.0) returns 3")
    func fromWholeFloat() throws {
        #expect(try swish.eval("(int 3.0)") == .integer(3))
    }

    // MARK: - biginteger input

    @Test("(int 100N) returns 100")
    func fromBigInt() throws {
        #expect(try swish.eval("(int 100N)") == .integer(100))
    }

    @Test("(int -5N) returns -5")
    func fromNegBigInt() throws {
        #expect(try swish.eval("(int -5N)") == .integer(-5))
    }

    // MARK: - bigdecimal input

    @Test("(int 7M) returns 7")
    func fromBigDecimalWhole() throws {
        #expect(try swish.eval("(int 7M)") == .integer(7))
    }

    @Test("(int 3.14M) truncates to 3")
    func fromBigDecimalFractional() throws {
        #expect(try swish.eval("(int 3.14M)") == .integer(3))
    }

    @Test("(int -2.9M) truncates toward zero to -2")
    func fromNegBigDecimalFractional() throws {
        #expect(try swish.eval("(int -2.9M)") == .integer(-2))
    }

    // MARK: - ratio input

    @Test("(int 7/2) truncates to 3")
    func fromRatio() throws {
        #expect(try swish.eval("(int 7/2)") == .integer(3))
    }

    @Test("(int -7/2) truncates toward zero to -3")
    func fromNegRatio() throws {
        #expect(try swish.eval("(int -7/2)") == .integer(-3))
    }

    @Test("(int 6/3) returns 2")
    func fromWholRatio() throws {
        #expect(try swish.eval("(int 6/3)") == .integer(2))
    }

    // MARK: - string input throws (ClojureJVM semantics)

    @Test("(int \"42\") throws")
    func fromStringPositive() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(int \"42\")")
        }
    }

    @Test("(int \"-7\") throws")
    func fromStringNegative() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(int \"-7\")")
        }
    }

    @Test("(int \"0\") throws")
    func fromStringZero() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(int \"0\")")
        }
    }

    // MARK: - error cases

    @Test("(int \"abc\") throws")
    func fromBadString() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(int \"abc\")")
        }
    }

    @Test("(int nil) throws")
    func fromNil() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(int nil)")
        }
    }

    @Test("(int true) throws")
    func fromBoolean() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(int true)")
        }
    }

    @Test("(int) throws — wrong arity")
    func noArgs() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(int)")
        }
    }

    @Test("(int 1 2) throws — wrong arity")
    func tooManyArgs() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(int 1 2)")
        }
    }

    // MARK: - Int32 range enforcement

    @Test("int accepts Int32.min boundary")
    func intMinBoundary() throws {
        #expect(try swish.eval("(int -2147483648)") == .integer(-2147483648))
    }

    @Test("int accepts Int32.max boundary")
    func intMaxBoundary() throws {
        #expect(try swish.eval("(int 2147483647)") == .integer(2147483647))
    }

    @Test("int throws for integer below Int32.min")
    func intThrowsBelowMin() {
        #expect(throws: (any Error).self) { try swish.eval("(int -2147483649)") }
    }

    @Test("int throws for integer above Int32.max")
    func intThrowsAboveMax() {
        #expect(throws: (any Error).self) { try swish.eval("(int 2147483648)") }
    }

    @Test("int throws for double below Int32.min")
    func intThrowsDoubleBelowMin() {
        #expect(throws: (any Error).self) { try swish.eval("(int -2147483648.000001)") }
    }

    @Test("int throws for double above Int32.max")
    func intThrowsDoubleAboveMax() {
        #expect(throws: (any Error).self) { try swish.eval("(int 2147483647.000001)") }
    }

    // MARK: - result is a fixed-precision integer

    @Test("(int? (int 5)) returns true")
    func resultIsInt() throws {
        #expect(try swish.eval("(int? (int 5))") == .boolean(true))
    }

    @Test("(int? (int 3.7)) returns true")
    func resultOfFloatIsInt() throws {
        #expect(try swish.eval("(int? (int 3.7))") == .boolean(true))
    }

    // MARK: - usable as a higher-order function

    @Test("map int over a sequence")
    func asHigherOrder() throws {
        #expect(try swish.eval("(map int [1.5 2.9 3.1])") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }
}
