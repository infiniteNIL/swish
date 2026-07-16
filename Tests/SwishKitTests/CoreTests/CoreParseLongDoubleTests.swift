import Testing
@testable import SwishKit

@Suite("Core parse-long/parse-double Tests", .serialized)
struct CoreParseLongDoubleTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - parse-long: malformed strings return nil

    @Test("parse-long returns nil for malformed strings")
    func parseLongMalformed() throws {
        let cases = [
            "", "1L", "foo", "f00", "7oo", "four", "0.0", "+-5", "-+5",
            "##Inf", "-##Inf", "Infinity", "Infinity7", "-Infinity", "-50Infinity",
            "NaN", "1e3",
        ]
        for c in cases {
            #expect(try swish.eval("(parse-long \"\(c)\")") == .nil)
        }
    }

    // MARK: - parse-long: valid strings

    @Test("parse-long parses valid decimal integer strings")
    func parseLongValid() throws {
        #expect(try swish.eval(#"(parse-long "0")"#) == .integer(0))
        #expect(try swish.eval(#"(parse-long "42")"#) == .integer(42))
        #expect(try swish.eval(#"(parse-long "+12")"#) == .integer(12))
        #expect(try swish.eval(#"(parse-long "-1000")"#) == .integer(-1000))
        #expect(try swish.eval(#"(parse-long "-100000000000")"#) == .integer(-100000000000))
        #expect(try swish.eval(#"(parse-long "999999999999999999")"#) == .integer(999999999999999999))
    }

    // MARK: - parse-long: throws for non-string types

    @Test("parse-long throws for non-string types")
    func parseLongThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(parse-long {})") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-long '())") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-long [])") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-long #{})") }
        #expect(throws: (any Error).self) { try swish.eval(#"(parse-long \a)"#) }
        #expect(throws: (any Error).self) { try swish.eval("(parse-long :key)") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-long 0.0)") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-long 1000)") }
    }

    // MARK: - parse-double: malformed strings return nil

    @Test("parse-double returns nil for malformed strings")
    func parseDoubleMalformed() throws {
        let cases = [
            "", "foo", "f00", "7oo", "four", "##Inf", "-##Inf", "+-5.6", "-+5.6",
            "7.9+6.4", "7.9-6.4", "Infinity7", "-50Infinity7", "8-Infinity7",
            "InfinityE100", "Infinitye5", "2.6e8E5",
        ]
        for c in cases {
            #expect(try swish.eval("(parse-double \"\(c)\")") == .nil)
        }
    }

    // MARK: - parse-double: valid strings

    @Test("parse-double parses valid floating point strings")
    func parseDoubleValid() throws {
        #expect(try swish.eval(#"(parse-double "1")"#) == .double(1.0))
        #expect(try swish.eval(#"(parse-double "1.0")"#) == .double(1.0))
        #expect(try swish.eval(#"(parse-double "1.000")"#) == .double(1.0))
        #expect(try swish.eval(#"(parse-double "+5.6")"#) == .double(5.6))
        #expect(try swish.eval(#"(parse-double "-8.7")"#) == .double(-8.7))
        #expect(try swish.eval(#"(parse-double "9.0006e4")"#) == .double(90006.0))
        #expect(try swish.eval(#"(parse-double "-1.058e2")"#) == .double(-105.8))
        #expect(try swish.eval(#"(parse-double "56851e-2")"#) == .double(568.51))
        #expect(try swish.eval(#"(parse-double "56851E-2")"#) == .double(568.51))
        #expect(try swish.eval(#"(parse-double "Infinity")"#) == .double(.infinity))
        #expect(try swish.eval(#"(parse-double "-Infinity")"#) == .double(-.infinity))
    }

    // MARK: - parse-double: throws for non-string types

    @Test("parse-double throws for non-string types")
    func parseDoubleThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(parse-double {})") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-double '())") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-double [])") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-double #{})") }
        #expect(throws: (any Error).self) { try swish.eval(#"(parse-double \a)"#) }
        #expect(throws: (any Error).self) { try swish.eval("(parse-double :key)") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-double 0.0)") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-double 1000)") }
    }
}
