import Testing
@testable import SwishKit

@Suite("key and val tests", .serialized)
struct CoreKeyValTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - key on map entries

    @Test("key returns the key of a map entry")
    func keyFromMapEntry() throws {
        #expect(try swish.eval("(key (first {:k :v}))") == .keyword("k"))
    }

    @Test("val returns the value of a map entry")
    func valFromMapEntry() throws {
        #expect(try swish.eval("(val (first {:k :v}))") == .keyword("v"))
    }

    @Test("key works when the key is nil")
    func keyNilKey() throws {
        #expect(try swish.eval("(key (first {nil :v}))") == .nil)
    }

    @Test("val works when the value is nil")
    func valNilValue() throws {
        #expect(try swish.eval("(val (first {:k nil}))") == .nil)
    }

    // MARK: - MapEntry semantics

    @Test("vector? returns true for a map entry")
    func mapEntryIsVector() throws {
        #expect(try swish.eval("(vector? (first {:k :v}))") == .boolean(true))
    }

    @Test("count of a map entry is 2")
    func mapEntryCount() throws {
        #expect(try swish.eval("(count (first {:k :v}))") == .integer(2))
    }

    @Test("map entry equals a 2-element vector with same contents")
    func mapEntryEqualToVector() throws {
        #expect(try swish.eval("(= (first {:k :v}) [:k :v])") == .boolean(true))
    }

    @Test("2-element vector equals a map entry with same contents")
    func vectorEqualToMapEntry() throws {
        #expect(try swish.eval("(= [:k :v] (first {:k :v}))") == .boolean(true))
    }

    @Test("nth 0 on map entry returns key")
    func mapEntryNth0() throws {
        #expect(try swish.eval("(nth (first {:k :v}) 0)") == .keyword("k"))
    }

    @Test("nth 1 on map entry returns value")
    func mapEntryNth1() throws {
        #expect(try swish.eval("(nth (first {:k :v}) 1)") == .keyword("v"))
    }

    // MARK: - key throws on non-map-entry arguments

    @Test("key throws on nil")
    func keyThrowsNil() throws {
        #expect(throws: (any Error).self) { try swish.eval("(key nil)") }
    }

    @Test("key throws on empty list")
    func keyThrowsEmptyList() throws {
        #expect(throws: (any Error).self) { try swish.eval("(key '())") }
    }

    @Test("key throws on a non-empty list")
    func keyThrowsList() throws {
        #expect(throws: (any Error).self) { try swish.eval("(key '(1 2))") }
    }

    @Test("key throws on an empty map")
    func keyThrowsEmptyMap() throws {
        #expect(throws: (any Error).self) { try swish.eval("(key {})") }
    }

    @Test("key throws on a non-empty map")
    func keyThrowsMap() throws {
        #expect(throws: (any Error).self) { try swish.eval("(key {1 2})") }
    }

    @Test("key throws on a plain 2-element vector")
    func keyThrowsVector() throws {
        #expect(throws: (any Error).self) { try swish.eval("(key [1 2])") }
    }

    // MARK: - val throws on non-map-entry arguments

    @Test("val throws on nil")
    func valThrowsNil() throws {
        #expect(throws: (any Error).self) { try swish.eval("(val nil)") }
    }

    @Test("val throws on an empty map")
    func valThrowsEmptyMap() throws {
        #expect(throws: (any Error).self) { try swish.eval("(val {})") }
    }

    @Test("val throws on a plain 2-element vector")
    func valThrowsVector() throws {
        #expect(throws: (any Error).self) { try swish.eval("(val [1 2])") }
    }
}
