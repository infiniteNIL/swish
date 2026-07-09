import Foundation
import Testing
@testable import SwishKit

@Suite("clojure.edn Tests", .serialized)
struct CoreClojureEDNTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - clojure.edn/read-string 1-arity

    @Test("edn/read-string returns nil for empty string")
    func readStringEmptyReturnsNil() throws {
        let result = try swish.eval("""
            (do (require '[clojure.edn :as edn])
                (edn/read-string ""))
            """)
        #expect(result == .nil)
    }

    @Test("edn/read-string returns nil for whitespace-only string")
    func readStringWhitespaceReturnsNil() throws {
        let result = try swish.eval("""
            (do (require '[clojure.edn :as edn])
                (edn/read-string "   \\t \\r \\n"))
            """)
        #expect(result == .nil)
    }

    @Test("edn/read-string returns nil for comma+whitespace string (EDN whitespace)")
    func readStringCommaWhitespaceReturnsNil() throws {
        let result = try swish.eval("""
            (do (require '[clojure.edn :as edn])
                (edn/read-string "  , ,, \\t \\r \\n"))
            """)
        #expect(result == .nil)
    }

    @Test("edn/read-string returns nil for comment-only string")
    func readStringCommentOnlyReturnsNil() throws {
        let result = try swish.eval("""
            (do (require '[clojure.edn :as edn])
                (edn/read-string ";just a comment\\n"))
            """)
        #expect(result == .nil)
    }

    @Test("edn/read-string parses valid EDN")
    func readStringParsesValidEDN() throws {
        let r = try swish.eval("""
            (do (require '[clojure.edn :as edn])
                [(edn/read-string "42")
                 (edn/read-string ":foo")
                 (edn/read-string "nil")
                 (edn/read-string "true")])
            """)
        guard case .vector(let elems, _) = r else {
            Issue.record("Expected vector, got \(r)")
            return
        }
        #expect(elems[0] == .integer(42))
        #expect(elems[1] == .keyword("foo"))
        #expect(elems[2] == .nil)
        #expect(elems[3] == .boolean(true))
    }

    @Test("edn/read-string throws on eval reader form")
    func readStringThrowsOnEvalReader() throws {
        #expect(throws: (any Error).self) {
            try swish.eval(##"""
                (do (require '[clojure.edn :as edn])
                    (edn/read-string "#=(+ 1 2)"))
                """##)
        }
    }

    @Test("edn/read-string throws on malformed input")
    func readStringThrowsOnMalformed() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("""
                (do (require '[clojure.edn :as edn])
                    (edn/read-string "(unclosed"))
                """)
        }
    }

    @Test("edn/read-string throws on ::foo (auto-qualified keyword)")
    func readStringThrowsOnAutoQualifiedKeyword() {
        #expect(throws: (any Error).self) {
            try swish.eval("""
                (do (require '[clojure.edn :as edn])
                    (edn/read-string "::foo"))
                """)
        }
    }

    @Test("edn/read-string throws on :/foo (slash after colon)")
    func readStringThrowsOnColonSlashKeyword() {
        #expect(throws: (any Error).self) {
            try swish.eval("""
                (do (require '[clojure.edn :as edn])
                    (edn/read-string ":/foo"))
                """)
        }
    }

    @Test("edn/read-string throws on foo/ (trailing slash)")
    func readStringThrowsOnTrailingSlashSymbol() {
        #expect(throws: (any Error).self) {
            try swish.eval("""
                (do (require '[clojure.edn :as edn])
                    (edn/read-string "foo/"))
                """)
        }
    }

    @Test("edn/read-string throws on /foo (leading slash)")
    func readStringThrowsOnLeadingSlashSymbol() {
        #expect(throws: (any Error).self) {
            try swish.eval("""
                (do (require '[clojure.edn :as edn])
                    (edn/read-string "/foo"))
                """)
        }
    }

    @Test("edn/read-string throws on foo/bar/baz (multiple slashes)")
    func readStringThrowsOnMultipleSlashSymbol() {
        #expect(throws: (any Error).self) {
            try swish.eval("""
                (do (require '[clojure.edn :as edn])
                    (edn/read-string "foo/bar/baz"))
                """)
        }
    }

    @Test("edn/read-string throws on :foo/bar/baz (multiple slashes in keyword)")
    func readStringThrowsOnMultipleSlashKeyword() {
        #expect(throws: (any Error).self) {
            try swish.eval("""
                (do (require '[clojure.edn :as edn])
                    (edn/read-string ":foo/bar/baz"))
                """)
        }
    }

    @Test("edn/read-string throws on map with duplicate keyword keys")
    func readStringThrowsOnDuplicateKeywordKeys() {
        #expect(throws: (any Error).self) {
            try swish.eval("""
                (do (require '[clojure.edn :as edn])
                    (edn/read-string "{:a 1 :a 2}"))
                """)
        }
    }

    @Test("edn/read-string throws on map with duplicate uuid keys")
    func readStringThrowsOnDuplicateUUIDKeys() {
        #expect(throws: (any Error).self) {
            try swish.eval(##"""
                (do (require '[clojure.edn :as edn])
                    (edn/read-string "{#uuid \"550e8400-e29b-41d4-a716-446655440000\" 1 #uuid \"550e8400-e29b-41d4-a716-446655440000\" 2}"))
                """##)
        }
    }

    // MARK: - clojure.edn/read-string 2-arity

    @Test("edn/read-string with opts returns :eof value for blank string")
    func readStringOptsReturnsEOFForBlank() throws {
        let result = try swish.eval("""
            (do (require '[clojure.edn :as edn])
                (edn/read-string {:eof :END} ""))
            """)
        #expect(result == .keyword("END"))
    }

    @Test("edn/read-string with opts returns :eof for comment-only string")
    func readStringOptsReturnsEOFForCommentOnly() throws {
        let result = try swish.eval("""
            (do (require '[clojure.edn :as edn])
                (edn/read-string {:eof :END} ";just a comment\\n"))
            """)
        #expect(result == .keyword("END"))
    }

    @Test("edn/read-string with opts returns nil eof default for blank string")
    func readStringOptsReturnsNilEOFDefault() throws {
        let result = try swish.eval("""
            (do (require '[clojure.edn :as edn])
                (edn/read-string {} " "))
            """)
        #expect(result == .nil)
    }

    @Test("edn/read-string with opts parses valid EDN")
    func readStringOptsParsesValidEDN() throws {
        let result = try swish.eval("""
            (do (require '[clojure.edn :as edn])
                (edn/read-string {:eof :END} "42"))
            """)
        #expect(result == .integer(42))
    }

    // MARK: - Namespace map literals

    @Test("edn/read-string parses namespace map literal with unqualified keyword keys")
    func readStringNamespacedMapQualifiesKeys() throws {
        let result = try swish.eval(##"""
            (do (require '[clojure.edn :as edn])
                (edn/read-string "#:foo{:bar 1 :baz 2}"))
            """##)
        guard case .map(let sm) = result else {
            Issue.record("Expected map, got \(result)")
            return
        }
        #expect(sm.dict[.keyword("foo/bar")] == .integer(1))
        #expect(sm.dict[.keyword("foo/baz")] == .integer(2))
    }

    @Test("edn/read-string namespace map leaves already-qualified keys unchanged")
    func readStringNamespacedMapPreservesQualifiedKeys() throws {
        let result = try swish.eval(##"""
            (do (require '[clojure.edn :as edn])
                (edn/read-string "#:foo{:other/bar 1}"))
            """##)
        guard case .map(let sm) = result else {
            Issue.record("Expected map, got \(result)")
            return
        }
        #expect(sm.dict[.keyword("other/bar")] == .integer(1))
    }

    @Test("edn/read-string namespace map does not prefix nested map value keys")
    func readStringNamespacedMapDoesNotPrefixNestedKeys() throws {
        let result = try swish.eval(##"""
            (do (require '[clojure.edn :as edn])
                (edn/read-string "#:foo{:bar {:buzz 2}}"))
            """##)
        guard case .map(let sm) = result else {
            Issue.record("Expected map, got \(result)")
            return
        }
        guard case .map(let innerSm) = sm.dict[.keyword("foo/bar")] else {
            Issue.record("Expected inner map at :foo/bar")
            return
        }
        #expect(innerSm.dict[.keyword("buzz")] == .integer(2))
    }

    // MARK: - inst-ms

    @Test("inst-ms returns epoch milliseconds for a known instant")
    func instMsKnownInstant() throws {
        let result = try swish.eval(##"""
            (do (require '[clojure.edn :as edn])
                (inst-ms (edn/read-string "#inst \"2010-01-01T01:01:01.001-01:01\"")))
            """##)
        #expect(result == .integer(1262311321001))
    }

    @Test("inst-ms returns epoch milliseconds for a second known instant")
    func instMsSecondKnownInstant() throws {
        let result = try swish.eval(##"""
            (do (require '[clojure.edn :as edn])
                (inst-ms (edn/read-string "#inst \"2010-09-09T09:09:09.009-09:09\"")))
            """##)
        #expect(result == .integer(1284056289009))
    }

    @Test("inst-ms returns midnight UTC for date-only #inst string")
    func instMsDateOnly() throws {
        let result = try swish.eval(##"""
            (do (require '[clojure.edn :as edn])
                (inst-ms (edn/read-string "#inst \"2026-02-03\"")))
            """##)
        #expect(result == .integer(1770076800000))
    }

    @Test("edn/read-string skips #_ discard forms between tagged literal tag and data")
    func readStringTaggedLiteralSkipsDiscards() throws {
        let result = try swish.eval(##"""
            (do (require '[clojure.edn :as edn])
                (edn/read-string "#uuid #_ignored \"550e8400-e29b-41d4-a716-446655440000\""))
            """##)
        #expect(result == .uuid(UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!))
    }

    @Test("edn/read-string with :readers handler invokes it with value only")
    func readStringReadersHandlerForNamespacedTag() throws {
        let result = try swish.eval(##"""
            (do (require '[clojure.edn :as edn])
                (edn/read-string {:readers {'my/foo (fn [x] [:foo x])}} "#my/foo 42"))
            """##)
        guard case .vector(let elems, _) = result else {
            Issue.record("Expected vector, got \(result)")
            return
        }
        #expect(elems[0] == .keyword("foo"))
        #expect(elems[1] == .integer(42))
    }

    @Test("edn/read-string with :default handler invokes it for unknown tagged literal")
    func readStringDefaultHandlerForUnknownTag() throws {
        let result = try swish.eval(##"""
            (do (require '[clojure.edn :as edn])
                (edn/read-string {:default (fn [_tag v] [:unknown v])} "#foo 42"))
            """##)
        guard case .vector(let elems, _) = result else {
            Issue.record("Expected vector, got \(result)")
            return
        }
        #expect(elems[0] == .keyword("unknown"))
        #expect(elems[1] == .integer(42))
    }

    @Test("identical? returns true for two equal UUID values (value-type semantics)")
    func identicalUUIDsReturnTrue() throws {
        let result = try swish.eval(##"""
            (do (require '[clojure.edn :as edn])
                (let [a (edn/read-string "#uuid \"550e8400-e29b-41d4-a716-446655440000\"")
                      b (edn/read-string "#uuid \"550e8400-e29b-41d4-a716-446655440000\"")]
                  (identical? a b)))
            """##)
        #expect(result == .boolean(true))
    }

    @Test("= returns true for equal UUID values")
    func equalUUIDsReturnTrue() throws {
        let result = try swish.eval(##"""
            (do (require '[clojure.edn :as edn])
                (= (edn/read-string "#uuid \"550e8400-e29b-41d4-a716-446655440000\"")
                   (edn/read-string "#uuid \"550e8400-e29b-41d4-a716-446655440000\"")))
            """##)
        #expect(result == .boolean(true))
    }

    @Test("edn/read-string handles CRLF line ending in comment between tagged literal tag and data")
    func readStringTaggedLiteralCRLFComment() throws {
        // The jank test uses ";comment\r\n\t,#_foo" between the tag and the UUID string.
        // Swift's \r\n forms a single grapheme cluster; the comment scanner must stop at it.
        let result = try swish.eval("""
            (do (require '[clojure.edn :as edn])
                (edn/read-string (str "#uuid  ;comment\\r\\n\\t,#_foo\\"550e8400-e29b-41d4-a716-446655440000\\"")))
            """)
        #expect(result == .uuid(UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!))
    }
}
