import Testing
@testable import SwishKit

@Suite("SwishKit Tests")
struct SwishKitTests {
    @Test("Evaluates integer through full pipeline")
    func evaluatesInteger() throws {
        let swish = Swish()
        #expect(try swish.eval("42") == "42")
        #expect(try swish.eval("-17") == "-17")
        #expect(try swish.eval("0") == "0")
    }

    @Test("Throws error for invalid input")
    func throwsErrorForInvalidInput() {
        let swish = Swish()
        #expect(throws: LexerError.self) {
            _ = try swish.eval("hello")
        }
    }

    @Test("Uses Int for small numbers")
    func usesIntForSmall() throws {
        let swish = Swish()
        #expect(try swish.eval("42") == "42")
    }

    @Test("Handles Int.max")
    func handlesIntMax() throws {
        let swish = Swish()
        let intMax = "9223372036854775807"
        #expect(try swish.eval(intMax) == intMax)
    }

    @Test("Throws error for integer overflow")
    func throwsErrorForIntegerOverflow() {
        let swish = Swish()
        #expect(throws: ParserError.self) {
            _ = try swish.eval("9223372036854775808")
        }
    }

    @Test("Evaluates integer with underscore separators")
    func evaluatesIntegerWithUnderscores() throws {
        let swish = Swish()
        #expect(try swish.eval("1_000") == "1000")
        #expect(try swish.eval("1_000_000") == "1000000")
        #expect(try swish.eval("-1_000") == "-1000")
    }
}
