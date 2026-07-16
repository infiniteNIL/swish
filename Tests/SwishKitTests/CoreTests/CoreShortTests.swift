import Testing
@testable import SwishKit

@Suite("Core short Tests", .serialized)
struct CoreShortTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - boundary identity

    @Test("(short Int16.min) returns Int16.min unchanged")
    func shortMinBoundary() throws {
        #expect(try swish.eval("(short -32768)") == .integer(-32768))
    }

    @Test("(short Int16.max) returns Int16.max unchanged")
    func shortMaxBoundary() throws {
        #expect(try swish.eval("(short 32767)") == .integer(32767))
    }

    // MARK: - boundary-plus-epsilon throws

    @Test("(short a double just below Int16.min) throws")
    func shortBelowMinThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(short -32768.000001)")
        }
    }

    @Test("(short a double just above Int16.max) throws")
    func shortAboveMaxThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(short 32767.000001)")
        }
    }

    // MARK: - truncation toward zero

    @Test("short truncates bigint, bigdecimal, double, and ratio toward zero")
    func shortTruncatesTowardZero() throws {
        #expect(try swish.eval("(short 1N)") == .integer(1))
        #expect(try swish.eval("(short 0N)") == .integer(0))
        #expect(try swish.eval("(short -1N)") == .integer(-1))
        #expect(try swish.eval("(short 1.0M)") == .integer(1))
        #expect(try swish.eval("(short 0.0M)") == .integer(0))
        #expect(try swish.eval("(short -1.0M)") == .integer(-1))
        #expect(try swish.eval("(short 1.1)") == .integer(1))
        #expect(try swish.eval("(short -1.1)") == .integer(-1))
        #expect(try swish.eval("(short 1.9)") == .integer(1))
        #expect(try swish.eval("(short 1.1M)") == .integer(1))
        #expect(try swish.eval("(short -1.1M)") == .integer(-1))
        #expect(try swish.eval("(short 3/2)") == .integer(1))
        #expect(try swish.eval("(short -3/2)") == .integer(-1))
        #expect(try swish.eval("(short 1/10)") == .integer(0))
        #expect(try swish.eval("(short -1/10)") == .integer(0))
    }

    // MARK: - overflow throws

    @Test("(short bigint one past Int16.min) throws")
    func shortBelowMinBigIntThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(short -32769)")
        }
    }

    @Test("(short bigint one past Int16.max) throws")
    func shortAboveMaxBigIntThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(short 32768)")
        }
    }

    // MARK: - non-numeric types throw

    @Test("short throws for non-numeric types")
    func shortNonNumericThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval(#"(short "0")"#) }
        #expect(throws: (any Error).self) { try swish.eval("(short :0)") }
        #expect(throws: (any Error).self) { try swish.eval("(short [0])") }
        #expect(throws: (any Error).self) { try swish.eval("(short nil)") }
    }
}
