import Foundation
import Testing
@testable import SwishKit

@Suite("Core parse-uuid Tests", .serialized)
struct CoreParseUUIDTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - malformed / wrong-length strings return nil

    @Test("parse-uuid returns nil for malformed or wrong-length strings")
    func parseUUIDMalformed() throws {
        let cases = [
            "",
            "0",
            "df0993",
            "b6883c0a-0342-4007-9966-bc2dfa6b109eb",
            "ab6883c0a-0342-4007-9966-bc2dfa6b109e",
        ]
        for c in cases {
            #expect(try swish.eval("(parse-uuid \"\(c)\")") == .nil)
        }
    }

    // MARK: - valid UUID string parses

    @Test("parse-uuid parses a valid canonical UUID string")
    func parseUUIDValid() throws {
        let result = try swish.eval(#"(parse-uuid "b6883c0a-0342-4007-9966-bc2dfa6b109e")"#)
        #expect(result == .uuid(UUID(uuidString: "b6883c0a-0342-4007-9966-bc2dfa6b109e")!))
    }

    // MARK: - case-insensitivity

    @Test("parse-uuid is case-insensitive")
    func parseUUIDCaseInsensitive() throws {
        #expect(try swish.eval(#"(= (parse-uuid "b6883c0a-0342-4007-9966-bc2dfa6b109e") (parse-uuid "B6883C0A-0342-4007-9966-BC2dfa6b109E"))"#) == .boolean(true))
    }

    // MARK: - JVM-permissive, Swish-strict non-canonical forms return nil

    @Test("parse-uuid rejects non-canonical forms the JVM permissively accepts")
    func parseUUIDStrictRejection() throws {
        #expect(try swish.eval(#"(parse-uuid "0-0-0-0-0")"#) == .nil)
        #expect(try swish.eval(#"(parse-uuid "12-34-56-78-9")"#) == .nil)
        #expect(try swish.eval(#"(parse-uuid "5-4-3-DEADBEEF0002-9000000001")"#) == .nil)
    }

    // MARK: - throws for non-string types

    @Test("parse-uuid throws for non-string types")
    func parseUUIDThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(parse-uuid {})") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-uuid '())") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-uuid [])") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-uuid #{})") }
        #expect(throws: (any Error).self) { try swish.eval(#"(parse-uuid \a)"#) }
        #expect(throws: (any Error).self) { try swish.eval("(parse-uuid :key)") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-uuid 0.0)") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-uuid 1000)") }
    }

    // MARK: - str renders the bare UUID string, not reader syntax

    @Test("(str uuid) returns the bare UUID string, not the #uuid reader form")
    func strOnUUIDReturnsBareString() throws {
        #expect(try swish.eval(#"(str (parse-uuid "b6883c0a-0342-4007-9966-bc2dfa6b109e"))"#) ==
            .string("b6883c0a-0342-4007-9966-bc2dfa6b109e"))
    }

    @Test("(pr-str uuid) still returns the #uuid reader form")
    func prStrOnUUIDReturnsReaderForm() throws {
        #expect(try swish.eval(#"(pr-str (parse-uuid "b6883c0a-0342-4007-9966-bc2dfa6b109e"))"#) ==
            .string(#"#uuid "b6883c0a-0342-4007-9966-bc2dfa6b109e""#))
    }
}
