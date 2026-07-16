import Testing
@testable import SwishKit

@Suite("Core format Tests", .serialized)
struct CoreFormatTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("(format \"test\") passes through directive-free strings unchanged")
    func formatPassthrough() throws {
        #expect(try swish.eval(#"(format "test")"#) == .string("test"))
    }

    @Test("%s formats a string argument")
    func formatStringDirectiveWithString() throws {
        #expect(try swish.eval(#"(format "%s" "hello")"#) == .string("hello"))
    }

    @Test("%s formats a non-string argument via str-style conversion")
    func formatStringDirectiveWithNonString() throws {
        #expect(try swish.eval(#"(format "%s" :a-keyword)"#) == .string(":a-keyword"))
        #expect(try swish.eval(#"(format "%s" 42)"#) == .string("42"))
    }

    @Test("%d formats an integer argument")
    func formatIntegerDirective() throws {
        #expect(try swish.eval(#"(format "%d" 42)"#) == .string("42"))
    }

    @Test("%f formats a double argument")
    func formatDoubleDirective() throws {
        #expect(try swish.eval(#"(format "%f" 3.14)"#) == .string("3.140000"))
    }

    @Test("%.2f respects precision")
    func formatDoublePrecision() throws {
        #expect(try swish.eval(#"(format "%.2f" 3.14159)"#) == .string("3.14"))
    }

    @Test("%% formats a literal percent")
    func formatLiteralPercent() throws {
        #expect(try swish.eval(#"(format "%%")"#) == .string("%"))
    }

    @Test("%c formats a character argument")
    func formatCharDirective() throws {
        #expect(try swish.eval(#"(format "%c" \a)"#) == .string("a"))
    }

    @Test("multiple directives in one format string")
    func formatMultipleDirectives() throws {
        #expect(try swish.eval(#"(format "%s and %d" "foo" 7)"#) == .string("foo and 7"))
    }

    @Test("a numeric directive given a non-numeric argument throws instead of crashing")
    func formatNumericDirectiveTypeMismatchThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval(#"(format "%d" "not-a-number")"#)
        }
    }

    @Test("format throws when the format string argument isn't a string")
    func formatNonStringFmtThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(format 42)")
        }
    }
}
