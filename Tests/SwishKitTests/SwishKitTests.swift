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

    @Test("Evaluates hexadecimal integer literals")
    func evaluatesHexInteger() throws {
        #expect(try swish.eval("0xFF") == .integer(255))
        #expect(try swish.eval("0x0a") == .integer(10))
        #expect(try swish.eval("-0xFF") == .integer(-255))
        #expect(try swish.eval("+0x10") == .integer(16))
        #expect(try swish.eval("0x1_000") == .integer(4096))
    }

    @Test("Evaluates binary integer literals")
    func evaluatesBinaryInteger() throws {
        #expect(try swish.eval("0b1010") == .integer(10))
        #expect(try swish.eval("0b0") == .integer(0))
        #expect(try swish.eval("0b1") == .integer(1))
        #expect(try swish.eval("-0b1010") == .integer(-10))
        #expect(try swish.eval("+0b100") == .integer(4))
        #expect(try swish.eval("0b1111_0000") == .integer(240))
    }

    @Test("Evaluates octal integer literals")
    func evaluatesOctalInteger() throws {
        #expect(try swish.eval("0o700") == .integer(448))
        #expect(try swish.eval("0o0") == .integer(0))
        #expect(try swish.eval("0o7") == .integer(7))
        #expect(try swish.eval("-0o700") == .integer(-448))
        #expect(try swish.eval("+0o755") == .integer(493))
        #expect(try swish.eval("0o7_55") == .integer(493))
    }

    @Test("Plain zero is still decimal zero")
    func plainZeroIsDecimal() throws {
        #expect(try swish.eval("0") == .integer(0))
    }

    @Test("Decimal integers can have leading zeros")
    func decimalWithLeadingZeros() throws {
        #expect(try swish.eval("0700") == .integer(700))
        #expect(try swish.eval("08") == .integer(8))
        #expect(try swish.eval("00") == .integer(0))
        #expect(try swish.eval("-09") == .integer(-9))
    }
}
