import Testing
@testable import SwishKit

@Suite("Core char Tests", .serialized)
struct CoreCharTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("(char 65) returns character 'A'")
    func charFromCodePoint() throws {
        #expect(try swish.eval("(char 65)") == .character("A"))
    }

    @Test("(char 0) returns NUL character")
    func charFromZero() throws {
        #expect(try swish.eval("(char 0)") == .character("\0"))
    }

    @Test("(char \\A) returns \\A unchanged")
    func charFromCharacter() throws {
        #expect(try swish.eval("(char \\A)") == .character("A"))
    }

    @Test("(char -1) throws")
    func charNegativeThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(char -1)")
        }
    }

    @Test("(char 0101) with leading-zero octal (65) returns 'A'")
    func charFromLeadingZeroOctal() throws {
        #expect(try swish.eval("(char 0101)") == .character("A"))
    }

    @Test("Leading-zero octal integer 0377 equals 255")
    func leadingZeroOctal() throws {
        #expect(try swish.eval("(= 0377 255)") == .boolean(true))
    }

    @Test("Leading-zero octal integer 0101 equals 65")
    func leadingZeroOctal2() throws {
        #expect(try swish.eval("(= 0101 65)") == .boolean(true))
    }

    @Test("(int \\a) returns the character's code point")
    func intFromCharacter() throws {
        #expect(try swish.eval(#"(int \a)"#) == .integer(97))
        #expect(try swish.eval(#"(int \A)"#) == .integer(65))
    }

    @Test("(int (char n)) round-trips back to n")
    func intCharRoundTrip() throws {
        #expect(try swish.eval("(int (char 65))") == .integer(65))
    }
}
