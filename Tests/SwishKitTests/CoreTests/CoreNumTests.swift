import Testing
@testable import SwishKit

@Suite("Core num Tests", .serialized)
struct CoreNumTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("num passes through every numeric type unchanged")
    func numIdentityForNumericTypes() throws {
        #expect(try swish.eval("(num 0)") == .integer(0))
        #expect(try swish.eval("(num 0.1)") == .double(0.1))
        #expect(try swish.eval("(num 1/2)") == .ratio(Ratio(1, 2)))
        #expect(try swish.eval("(num 1N)") == .bigInteger(1))
        #expect(try swish.eval("(num 1.0M)") == .bigDecimal(1.0))
        #expect(try swish.eval("(num (float 1.0))") == .float(1.0))
        #expect(try swish.eval("(num (double 1.0))") == .double(1.0))
        #expect(try swish.eval("(num (short 1))") == .integer(1))
        #expect(try swish.eval("(num (byte 1))") == .integer(1))
        #expect(try swish.eval("(num (int 1))") == .integer(1))
        #expect(try swish.eval("(num (long 1))") == .integer(1))
    }

    @Test("num passes through Inf unchanged and NaN? holds for num of NaN")
    func numInfAndNaN() throws {
        #expect(try swish.eval("(num ##Inf)") == .double(.infinity))
        #expect(try swish.eval("(NaN? (num ##NaN))") == .boolean(true))
    }

    @Test("(num nil) returns nil, not a throw")
    func numNil() throws {
        #expect(try swish.eval("(num nil)") == .nil)
    }

    @Test("num throws for non-numeric types")
    func numThrowsForNonNumeric() throws {
        #expect(throws: (any Error).self) { try swish.eval("(num (fn []))") }
        #expect(throws: (any Error).self) { try swish.eval("(num {})") }
        #expect(throws: (any Error).self) { try swish.eval("(num #{})") }
        #expect(throws: (any Error).self) { try swish.eval("(num [])") }
        #expect(throws: (any Error).self) { try swish.eval("(num '())") }
        #expect(throws: (any Error).self) { try swish.eval(#"(num \a)"#) }
        #expect(throws: (any Error).self) { try swish.eval(#"(num "")"#) }
        #expect(throws: (any Error).self) { try swish.eval("(num 'a)") }
        #expect(throws: (any Error).self) { try swish.eval(#"(num #"")"#) }
    }
}
