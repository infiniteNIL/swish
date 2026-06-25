import Testing
import Foundation
@testable import SwishKit

@Suite("Parser Tagged Literal Tests")
struct ParserTaggedLiteralTests {

    // MARK: - #inst

    @Test("Parses #inst with UTC Z timestamp")
    func parsesInstUtc() throws {
        let exprs = try Reader.readString(#"#inst "2024-01-01T00:00:00Z""#)
        #expect(exprs.count == 1)
        guard case .inst(let date) = exprs[0] else {
            Issue.record("Expected .inst, got \(exprs[0])")
            return
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        #expect(comps.year == 2024)
        #expect(comps.month == 1)
        #expect(comps.day == 1)
    }

    @Test("Parses #inst with fractional seconds and timezone offset")
    func parsesInstFractionalWithOffset() throws {
        let exprs = try Reader.readString(#"#inst "2013-06-18T17:47:02.766-07:00""#)
        #expect(exprs.count == 1)
        if case .inst = exprs[0] { } else {
            Issue.record("Expected .inst, got \(exprs[0])")
        }
    }

    @Test("Parses #inst without fractional seconds")
    func parsesInstNoFractional() throws {
        let exprs = try Reader.readString(#"#inst "2020-03-15T12:30:00Z""#)
        #expect(exprs.count == 1)
        if case .inst = exprs[0] { } else {
            Issue.record("Expected .inst, got \(exprs[0])")
        }
    }

    @Test("Two #inst with same timestamp are equal")
    func instEquality() throws {
        let a = try Reader.readString(#"#inst "2024-01-01T00:00:00Z""#)[0]
        let b = try Reader.readString(#"#inst "2024-01-01T00:00:00Z""#)[0]
        #expect(a == b)
    }

    @Test("Two #inst with different timestamps are not equal")
    func instInequality() throws {
        let a = try Reader.readString(#"#inst "2024-01-01T00:00:00Z""#)[0]
        let b = try Reader.readString(#"#inst "2025-01-01T00:00:00Z""#)[0]
        #expect(a != b)
    }

    @Test("Malformed #inst string throws invalidTaggedLiteral")
    func malformedInstThrows() throws {
        #expect(throws: ParserError.self) {
            _ = try Reader.readString(#"#inst "not-a-date""#)
        }
    }

    @Test("#inst with non-string data throws invalidTaggedLiteral")
    func instNonStringThrows() throws {
        #expect(throws: ParserError.self) {
            _ = try Reader.readString("#inst 42")
        }
    }

    // MARK: - #uuid

    @Test("Parses #uuid lowercase")
    func parsesUuidLowercase() throws {
        let exprs = try Reader.readString(#"#uuid "f81d4fae-7dec-11d0-a765-00a0c91e6bf6""#)
        #expect(exprs.count == 1)
        guard case .uuid(let uuid) = exprs[0] else {
            Issue.record("Expected .uuid, got \(exprs[0])")
            return
        }
        #expect(uuid.uuidString.lowercased() == "f81d4fae-7dec-11d0-a765-00a0c91e6bf6")
    }

    @Test("Parses #uuid uppercase")
    func parsesUuidUppercase() throws {
        let exprs = try Reader.readString(#"#uuid "F81D4FAE-7DEC-11D0-A765-00A0C91E6BF6""#)
        #expect(exprs.count == 1)
        if case .uuid = exprs[0] { } else {
            Issue.record("Expected .uuid, got \(exprs[0])")
        }
    }

    @Test("UUID parsed from lowercase and uppercase are equal")
    func uuidCaseInsensitive() throws {
        let a = try Reader.readString(#"#uuid "f81d4fae-7dec-11d0-a765-00a0c91e6bf6""#)[0]
        let b = try Reader.readString(#"#uuid "F81D4FAE-7DEC-11D0-A765-00A0C91E6BF6""#)[0]
        #expect(a == b)
    }

    @Test("Two identical #uuid are equal")
    func uuidEquality() throws {
        let a = try Reader.readString(#"#uuid "f81d4fae-7dec-11d0-a765-00a0c91e6bf6""#)[0]
        let b = try Reader.readString(#"#uuid "f81d4fae-7dec-11d0-a765-00a0c91e6bf6""#)[0]
        #expect(a == b)
    }

    @Test("Two different #uuid are not equal")
    func uuidInequality() throws {
        let a = try Reader.readString(#"#uuid "f81d4fae-7dec-11d0-a765-00a0c91e6bf6""#)[0]
        let b = try Reader.readString(#"#uuid "00000000-0000-0000-0000-000000000000""#)[0]
        #expect(a != b)
    }

    @Test("Malformed #uuid string throws invalidTaggedLiteral")
    func malformedUuidThrows() throws {
        #expect(throws: ParserError.self) {
            _ = try Reader.readString(#"#uuid "not-a-uuid""#)
        }
    }

    @Test("#uuid with non-string data throws invalidTaggedLiteral")
    func uuidNonStringThrows() throws {
        #expect(throws: ParserError.self) {
            _ = try Reader.readString("#uuid 42")
        }
    }

    // MARK: - Unknown tags

    @Test("Unknown tag throws invalidTaggedLiteral")
    func unknownTagThrows() throws {
        #expect(throws: ParserError.self) {
            _ = try Reader.readString(#"#foo "bar""#)
        }
    }
}
