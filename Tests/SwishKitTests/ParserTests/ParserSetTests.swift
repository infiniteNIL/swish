import Testing
@testable import SwishKit

@Suite("Parser Set Tests")
struct ParserSetTests {
    @Test("Parses empty set")
    func parsesEmptySet() throws {
        let exprs = try Reader.readString("#{}")
        #expect(exprs.count == 1)
        #expect(exprs[0] == .set([], metadata: nil))
    }

    @Test("Parses set with integer literals")
    func parsesSetWithIntegers() throws {
        let exprs = try Reader.readString("#{1 2 3}")
        #expect(exprs.count == 1)
        guard case .set(let elements, _, _) = exprs[0] else {
            Issue.record("Expected .set")
            return
        }
        #expect(elements == [.integer(1), .integer(2), .integer(3)])
    }

    @Test("Parses set with keyword literals")
    func parsesSetWithKeywords() throws {
        let exprs = try Reader.readString("#{:a :b :c}")
        guard case .set(let elements, _, _) = exprs[0] else {
            Issue.record("Expected .set")
            return
        }
        #expect(elements == [.keyword("a"), .keyword("b"), .keyword("c")])
    }

    @Test("Parses set with mixed types")
    func parsesSetWithMixedTypes() throws {
        let exprs = try Reader.readString("#{1 :key \"hello\"}")
        guard case .set(let elements, _, _) = exprs[0] else {
            Issue.record("Expected .set")
            return
        }
        #expect(elements.contains(.integer(1)))
        #expect(elements.contains(.keyword("key")))
        #expect(elements.contains(.string("hello")))
    }

    @Test("Throws on duplicate literal element")
    func throwsOnDuplicateLiteralElement() throws {
        #expect(throws: ParserError.self) {
            try Reader.readString("#{1 1}")
        }
    }

    @Test("Throws on duplicate keyword element")
    func throwsOnDuplicateKeyword() throws {
        #expect(throws: ParserError.self) {
            try Reader.readString("#{:a :a}")
        }
    }

    @Test("Throws on unterminated set")
    func throwsOnUnterminatedSet() throws {
        #expect(throws: ParserError.self) {
            try Reader.readString("#{1 2")
        }
    }

    @Test("Parses nested set")
    func parsesNestedSet() throws {
        let exprs = try Reader.readString("#{#{1 2} 3}")
        guard case .set(let outer, _, _) = exprs[0] else {
            Issue.record("Expected .set")
            return
        }
        #expect(outer.contains(.set([.integer(1), .integer(2)], metadata: nil)))
        #expect(outer.contains(.integer(3)))
    }

    @Test("Parses set alongside other forms")
    func parsesSetAlongsideOtherForms() throws {
        let exprs = try Reader.readString("#{1 2} #{3 4}")
        #expect(exprs.count == 2)
        #expect(exprs[0] == .set([.integer(1), .integer(2)], metadata: nil))
        #expect(exprs[1] == .set([.integer(3), .integer(4)], metadata: nil))
    }
}
