import Testing
@testable import SwishKit

@Suite("Core long Tests", .serialized)
struct CoreLongTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - boundary identity

    @Test("(long Int64.min) returns Int64.min unchanged")
    func longMinBoundary() throws {
        #expect(try swish.eval("(long -9223372036854775808)") == .integer(Int.min))
    }

    @Test("(long Int64.max) returns Int64.max unchanged")
    func longMaxBoundary() throws {
        #expect(try swish.eval("(long 9223372036854775807)") == .integer(Int.max))
    }

    // MARK: - truncation toward zero

    @Test("long truncates bigint, bigdecimal, double, and ratio toward zero")
    func longTruncatesTowardZero() throws {
        #expect(try swish.eval("(long 1N)") == .integer(1))
        #expect(try swish.eval("(long 0N)") == .integer(0))
        #expect(try swish.eval("(long -1N)") == .integer(-1))
        #expect(try swish.eval("(long 1.0M)") == .integer(1))
        #expect(try swish.eval("(long 0.0M)") == .integer(0))
        #expect(try swish.eval("(long -1.0M)") == .integer(-1))
        #expect(try swish.eval("(long 1.1)") == .integer(1))
        #expect(try swish.eval("(long -1.1)") == .integer(-1))
        #expect(try swish.eval("(long 1.9)") == .integer(1))
        #expect(try swish.eval("(long 1.1M)") == .integer(1))
        #expect(try swish.eval("(long -1.1M)") == .integer(-1))
        #expect(try swish.eval("(long 3/2)") == .integer(1))
        #expect(try swish.eval("(long -3/2)") == .integer(-1))
        #expect(try swish.eval("(long 1/10)") == .integer(0))
        #expect(try swish.eval("(long -1/10)") == .integer(0))
    }

    // MARK: - overflow throws

    @Test("(long bigint one past Int64.min) throws")
    func longBelowMinThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(long -9223372036854775809)")
        }
    }

    @Test("(long bigint one past Int64.max) throws")
    func longAboveMaxThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(long 9223372036854775808)")
        }
    }

    // MARK: - double precision boundary (crash-risk regression coverage)

    @Test("(long a double exactly at 2^63) throws cleanly, not a crash")
    func longDoubleAtTwoToThe63Throws() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(long 9223372036854775808.0)")
        }
    }

    // MARK: - non-numeric types throw

    @Test("long throws for non-numeric types")
    func longNonNumericThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval(#"(long "0")"#) }
        #expect(throws: (any Error).self) { try swish.eval("(long :0)") }
        #expect(throws: (any Error).self) { try swish.eval("(long [0])") }
        #expect(throws: (any Error).self) { try swish.eval("(long nil)") }
    }
}
