import Testing
@testable import SwishKit

@Suite("Core String Tests", .serialized)
struct CoreStringTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("str with no args returns empty string")
    func strNoArgs() throws {
        #expect(try swish.eval("(str)") == .string(""))
    }

    @Test("str of nil returns empty string")
    func strNil() throws {
        #expect(try swish.eval("(str nil)") == .string(""))
    }

    @Test("str of a string returns the string")
    func strString() throws {
        #expect(try swish.eval("(str \"hello\")") == .string("hello"))
    }

    @Test("str of an integer returns its decimal representation")
    func strInteger() throws {
        #expect(try swish.eval("(str 42)") == .string("42"))
    }

    @Test("str of a float returns its decimal representation")
    func strFloat() throws {
        #expect(try swish.eval("(str 3.14)") == .string("3.14"))
    }

    @Test("str of a ratio returns numerator/denominator")
    func strRatio() throws {
        #expect(try swish.eval("(str 1/3)") == .string("1/3"))
    }

    @Test("str of true returns \"true\"")
    func strTrue() throws {
        #expect(try swish.eval("(str true)") == .string("true"))
    }

    @Test("str of false returns \"false\"")
    func strFalse() throws {
        #expect(try swish.eval("(str false)") == .string("false"))
    }

    @Test("str of a keyword returns :name")
    func strKeyword() throws {
        #expect(try swish.eval("(str :foo)") == .string(":foo"))
    }

    @Test("str of a character returns the character itself")
    func strCharacter() throws {
        #expect(try swish.eval("(str \\a)") == .string("a"))
    }

    @Test("str of a newline character returns a newline")
    func strNewlineCharacter() throws {
        #expect(try swish.eval("(str \\newline)") == .string("\n"))
    }

    @Test("str concatenates multiple args with no separator")
    func strMultipleArgs() throws {
        #expect(try swish.eval("(str 1 2 3)") == .string("123"))
    }

    @Test("str concatenates strings")
    func strConcatenatesStrings() throws {
        #expect(try swish.eval("(str \"hello\" \" \" \"world\")") == .string("hello world"))
    }

    @Test("str treats nil as empty string in concatenation")
    func strNilInConcatenation() throws {
        #expect(try swish.eval("(str \"a\" nil \"b\")") == .string("ab"))
    }

    @Test("str mixes types")
    func strMixedTypes() throws {
        #expect(try swish.eval("(str \"x=\" 42)") == .string("x=42"))
    }
}
