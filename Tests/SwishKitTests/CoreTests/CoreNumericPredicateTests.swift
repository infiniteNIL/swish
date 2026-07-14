import Testing
@testable import SwishKit

@Suite("Core Numeric Predicate Tests", .serialized)
struct CoreNumericPredicateTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - int?

    @Test("(int? 42) returns true")
    func intPredicateTrue() throws {
        #expect(try swish.eval("(int? 42)") == .boolean(true))
    }

    @Test("(int? 1.5) returns false")
    func intPredicateFalseFloat() throws {
        #expect(try swish.eval("(int? 1.5)") == .boolean(false))
    }

    @Test("(int? \"x\") returns false")
    func intPredicateFalseString() throws {
        #expect(try swish.eval("(int? \"x\")") == .boolean(false))
    }

    // MARK: - even?

    @Test("(even? 2) returns true")
    func evenTwo() throws {
        #expect(try swish.eval("(even? 2)") == .boolean(true))
    }

    @Test("(even? 3) returns false")
    func evenThree() throws {
        #expect(try swish.eval("(even? 3)") == .boolean(false))
    }

    @Test("(even? 0) returns true")
    func evenZero() throws {
        #expect(try swish.eval("(even? 0)") == .boolean(true))
    }

    @Test("(even? -2) returns true")
    func evenNegTwo() throws {
        #expect(try swish.eval("(even? -2)") == .boolean(true))
    }

    @Test("(even? -3) returns false")
    func evenNegThree() throws {
        #expect(try swish.eval("(even? -3)") == .boolean(false))
    }

    // MARK: - odd?

    @Test("(odd? 3) returns true")
    func oddThree() throws {
        #expect(try swish.eval("(odd? 3)") == .boolean(true))
    }

    @Test("(odd? 2) returns false")
    func oddTwo() throws {
        #expect(try swish.eval("(odd? 2)") == .boolean(false))
    }

    @Test("(odd? -1) returns true")
    func oddNegOne() throws {
        #expect(try swish.eval("(odd? -1)") == .boolean(true))
    }

    // MARK: - pos?

    @Test("(pos? 1) returns true")
    func posOne() throws {
        #expect(try swish.eval("(pos? 1)") == .boolean(true))
    }

    @Test("(pos? 0) returns false")
    func posZero() throws {
        #expect(try swish.eval("(pos? 0)") == .boolean(false))
    }

    @Test("(pos? -1) returns false")
    func posNegOne() throws {
        #expect(try swish.eval("(pos? -1)") == .boolean(false))
    }

    @Test("(pos? 0.1) returns true")
    func posFloat() throws {
        #expect(try swish.eval("(pos? 0.1)") == .boolean(true))
    }

    // MARK: - neg?

    @Test("(neg? -1) returns true")
    func negNegOne() throws {
        #expect(try swish.eval("(neg? -1)") == .boolean(true))
    }

    @Test("(neg? 0) returns false")
    func negZero() throws {
        #expect(try swish.eval("(neg? 0)") == .boolean(false))
    }

    @Test("(neg? 1) returns false")
    func negOne() throws {
        #expect(try swish.eval("(neg? 1)") == .boolean(false))
    }

    @Test("(neg? -0.1) returns true")
    func negFloat() throws {
        #expect(try swish.eval("(neg? -0.1)") == .boolean(true))
    }

    // MARK: - zero?

    @Test("(zero? 0) returns true")
    func zeroInt() throws {
        #expect(try swish.eval("(zero? 0)") == .boolean(true))
    }

    @Test("(zero? 1) returns false")
    func zeroOne() throws {
        #expect(try swish.eval("(zero? 1)") == .boolean(false))
    }

    @Test("(zero? -1) returns false")
    func zeroNegOne() throws {
        #expect(try swish.eval("(zero? -1)") == .boolean(false))
    }

    @Test("(zero? 0.0) returns true")
    func zeroFloat() throws {
        #expect(try swish.eval("(zero? 0.0)") == .boolean(true))
    }

    @Test("(zero? 0.5) returns false")
    func zeroNonZeroFloat() throws {
        #expect(try swish.eval("(zero? 0.5)") == .boolean(false))
    }
}
