import Testing
@testable import SwishKit

@Suite("Core sorted-map Tests", .serialized)
struct CoreSortedMapTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("sorted-map equals a regular map with same entries")
    func sortedMapEqualsMap() throws {
        #expect(try swish.eval("(= (sorted-map :a 1 :b 2) {:a 1 :b 2})") == .boolean(true))
    }

    @Test("map? returns true for sorted-map")
    func sortedMapIsMap() throws {
        #expect(try swish.eval("(map? (sorted-map :a 1))") == .boolean(true))
    }

    @Test("sorted? returns true for sorted-map")
    func sortedMapIsSorted() throws {
        #expect(try swish.eval("(sorted? (sorted-map :a 1))") == .boolean(true))
    }

    @Test("sorted? returns false for regular map")
    func regularMapIsNotSorted() throws {
        #expect(try swish.eval("(sorted? {:a 1})") == .boolean(false))
    }

    @Test("get retrieves a value from sorted-map")
    func sortedMapGet() throws {
        #expect(try swish.eval("(get (sorted-map :a 1) :a)") == .integer(1))
    }

    @Test("count returns the number of entries in sorted-map")
    func sortedMapCount() throws {
        #expect(try swish.eval("(count (sorted-map :a 1 :b 2))") == .integer(2))
    }

    @Test("seq of sorted-map returns entries in key order")
    func sortedMapSeqOrder() throws {
        let result = try swish.eval("(vec (map first (seq (sorted-map :b 2 :a 1))))")
        #expect(result == .vector([.keyword("a"), .keyword("b")], metadata: nil))
    }

    @Test("sorted-map-by produces a map equal to sorted-map with same entries")
    func sortedMapByEquality() throws {
        #expect(try swish.eval("(= (sorted-map-by < 1 :a 2 :b) (sorted-map 1 :a 2 :b))") == .boolean(true))
    }

    @Test("sorted-set-by produces a set equal to sorted-set with same elements")
    func sortedSetByEquality() throws {
        #expect(try swish.eval("(= (sorted-set-by > 4 2 6) (sorted-set 4 2 6))") == .boolean(true))
    }

    // The `.map`/`.set` backing (TreeDictionary/TreeSet) and the `.sortedMap`/
    // `.sortedSet` backing (Swift Dictionary/Array) must hash equal for equal
    // contents, since a hash-map and an equal sorted-map are `=` and must collide
    // as the same key / dedup in a set. (TreeDictionary and Dictionary don't hash
    // equal by default — see hashMapContents/hashSetContents.)

    @Test("conj of an equal sorted-map onto a set holding the hash-map is a no-op (dedup)")
    func hashMapSortedMapDedupInSet() throws {
        #expect(try swish.eval("(count (conj #{{:a 1 :b 2}} (sorted-map :a 1 :b 2)))") == .integer(1))
    }

    @Test("hash-map key finds an equal sorted-map key (same hash bucket)")
    func hashMapSortedMapAsKey() throws {
        #expect(try swish.eval("(get {(sorted-map :a 1 :b 2) :found} {:a 1 :b 2})") == .keyword("found"))
    }

    @Test("conj of an equal sorted-set onto a set holding the hash-set is a no-op (dedup)")
    func hashSetSortedSetDedupInSet() throws {
        #expect(try swish.eval("(count (conj #{#{1 2 3}} (sorted-set 1 2 3)))") == .integer(1))
    }

    @Test("hash-set key finds an equal sorted-set key")
    func hashSetSortedSetAsKey() throws {
        #expect(try swish.eval("(get {(sorted-set 1 2 3) :found} #{1 2 3})") == .keyword("found"))
    }
}
