import Testing
@testable import SwishKit

@Suite("Core empty Tests", .serialized)
struct CoreEmptyTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - collection types

    @Test("(empty [1 2]) returns []")
    func emptyVector() throws {
        #expect(try swish.eval("(empty [1 2])") == .vector([], metadata: nil))
    }

    @Test("(empty {:a :map}) returns {}")
    func emptyMap() throws {
        #expect(try swish.eval("(empty {:a :map})") == .map([:], metadata: nil))
    }

    @Test("(empty '(1 2)) returns ()")
    func emptyList() throws {
        #expect(try swish.eval("(empty '(1 2))") == .list([], metadata: nil))
    }

    @Test("(empty #{1 2 3}) returns #{}")
    func emptySet() throws {
        #expect(try swish.eval("(empty #{1 2 3})") == .set(SwishSet(elements: [], metadata: nil)))
    }

    @Test("(empty (range)) returns ()")
    func emptyInfiniteRange() throws {
        #expect(try swish.eval("(empty (range))") == .list([], metadata: nil))
    }

    @Test("(empty (range 10)) returns ()")
    func emptyFiniteRange() throws {
        #expect(try swish.eval("(empty (range 10))") == .list([], metadata: nil))
    }

    @Test("(empty (sorted-map :a 1)) returns an empty sorted map")
    func emptySortedMap() throws {
        #expect(try swish.eval("(empty (sorted-map :a 1))") == .sortedMap([:], metadata: nil))
    }

    @Test("(empty (sorted-set 1 2)) returns an empty sorted set")
    func emptySortedSet() throws {
        #expect(try swish.eval("(empty (sorted-set 1 2))") == .sortedSet([], metadata: nil))
    }

    @Test("(empty (first {:a 1})) returns an empty vector")
    func emptyMapEntry() throws {
        #expect(try swish.eval("(empty (first {:a 1}))") == .vector([], metadata: nil))
    }

    // MARK: - non-collections return nil

    @Test("empty returns nil for non-collection values")
    func emptyNonCollectionReturnsNil() throws {
        #expect(try swish.eval(#"(empty "a string")"#) == .nil)
        #expect(try swish.eval(#"(empty \a)"#) == .nil)
        #expect(try swish.eval("(empty :a-keyword)") == .nil)
        #expect(try swish.eval("(empty 1)") == .nil)
        #expect(try swish.eval("(empty 1.0)") == .nil)
        #expect(try swish.eval("(empty nil)") == .nil)
        #expect(try swish.eval("(empty +)") == .nil)
    }

    @Test("(empty (deftype instance)) returns nil")
    func emptyDeftypeReturnsNil() throws {
        #expect(try swish.eval("(deftype EmptyType [x]) (empty (->EmptyType 1))") == .nil)
    }

    // MARK: - record throws

    @Test("(empty (defrecord instance)) throws")
    func emptyRecordThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(defrecord EmptyRec [x]) (empty (->EmptyRec 1))")
        }
    }

    // MARK: - metadata preservation

    @Test("empty preserves metadata on a vector")
    func emptyPreservesMetaOnVector() throws {
        #expect(try swish.eval("(meta (empty (with-meta [1 2] {:foo 42})))") == .map([.keyword("foo"): .integer(42)], metadata: nil))
    }

    @Test("empty preserves metadata on a map")
    func emptyPreservesMetaOnMap() throws {
        #expect(try swish.eval("(meta (empty (with-meta {} {:foo 42})))") == .map([.keyword("foo"): .integer(42)], metadata: nil))
    }

    @Test("empty preserves metadata on a set")
    func emptyPreservesMetaOnSet() throws {
        #expect(try swish.eval("(meta (empty (with-meta #{} {:foo 42})))") == .map([.keyword("foo"): .integer(42)], metadata: nil))
    }

    @Test("empty preserves metadata on a list")
    func emptyPreservesMetaOnList() throws {
        #expect(try swish.eval("(meta (empty (with-meta '() {:foo 42})))") == .map([.keyword("foo"): .integer(42)], metadata: nil))
    }
}
