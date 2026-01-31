import Testing
@testable import SwishKit

@Suite("SwishKit Tests")
struct SwishKitTests {
    let swish = Swish()

    @Test("Evaluates integer through full pipeline")
    func evaluatesInteger() throws {
        #expect(try swish.eval("42") == .integer(42))
        #expect(try swish.eval("-17") == .integer(-17))
        #expect(try swish.eval("0") == .integer(0))
    }

    @Test("Throws error for invalid input")
    func throwsErrorForInvalidInput() {
        #expect(throws: LexerError.self) {
            _ = try swish.eval("hello")
        }
    }

    @Test("Uses Int for small numbers")
    func usesIntForSmall() throws {
        #expect(try swish.eval("42") == .integer(42))
    }

    @Test("Handles Int.max")
    func handlesIntMax() throws {
        #expect(try swish.eval("9223372036854775807") == .integer(Int.max))
    }

    @Test("Throws error for integer overflow")
    func throwsErrorForIntegerOverflow() {
        #expect(throws: ParserError.self) {
            _ = try swish.eval("9223372036854775808")
        }
    }

    @Test("Evaluates integer with underscore separators")
    func evaluatesIntegerWithUnderscores() throws {
        #expect(try swish.eval("1_000") == .integer(1000))
        #expect(try swish.eval("1_000_000") == .integer(1_000_000))
        #expect(try swish.eval("-1_000") == .integer(-1000))
    }
}
