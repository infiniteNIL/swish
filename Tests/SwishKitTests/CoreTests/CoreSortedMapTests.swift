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

    // MARK: - comparators honored, sorted keys/vals, subseq/rsubseq

    @Test("sorted-map-by honors the comparator (descending order)")
    func sortedMapByComparator() throws {
        #expect(try swish.eval("(vec (seq (sorted-map-by > 1 :a 3 :b 2 :c)))")
            == .vector([.vector([.integer(3), .keyword("b")], metadata: nil),
                        .vector([.integer(2), .keyword("c")], metadata: nil),
                        .vector([.integer(1), .keyword("a")], metadata: nil)], metadata: nil))
    }

    @Test("sorted-set-by honors the comparator (descending order)")
    func sortedSetByComparator() throws {
        #expect(try swish.eval("(vec (sorted-set-by > 5 1 3 2 4))")
            == .vector(SwishPersistentVector([5, 4, 3, 2, 1].map { .integer($0) }), metadata: nil))
    }

    @Test("keys and vals of a sorted-map are in sorted (not hash) order")
    func sortedMapKeysValsSorted() throws {
        #expect(try swish.eval("(vec (keys (sorted-map :z 1 :a 2 :m 3)))")
            == .vector([.keyword("a"), .keyword("m"), .keyword("z")], metadata: nil))
        #expect(try swish.eval("(vec (vals (sorted-map :z 1 :a 2 :m 3)))")
            == .vector([.integer(2), .integer(3), .integer(1)], metadata: nil))
    }

    @Test("assoc into a sorted-map keeps sorted order")
    func sortedMapAssocKeepsOrder() throws {
        #expect(try swish.eval("(vec (keys (assoc (sorted-map 1 :a 3 :c) 2 :b)))")
            == .vector(SwishPersistentVector([1, 2, 3].map { .integer($0) }), metadata: nil))
    }

    @Test("get / contains? on a sorted collection use the comparator")
    func sortedGetContainsUseComparator() throws {
        #expect(try swish.eval("(get (sorted-map-by > 1 :a 2 :b) 2)") == .keyword("b"))
        #expect(try swish.eval("(contains? (sorted-set-by > 5 1 3) 3)") == .boolean(true))
        #expect(try swish.eval("(get (sorted-set-by > 5 1 3) 3)") == .integer(3))
    }

    @Test("comparator-defined equality dedups (compare 0 = same element)")
    func sortedComparatorEqualityDedup() throws {
        #expect(try swish.eval("(count (sorted-set-by (fn [a b] 0) 1 2 3))") == .integer(1))
    }

    @Test("subseq single-test forms")
    func subseqSingle() throws {
        #expect(try swish.eval("(vec (subseq (sorted-set 1 2 3 4 5) > 2))") == .vector(SwishPersistentVector([3, 4, 5].map { .integer($0) }), metadata: nil))
        #expect(try swish.eval("(vec (subseq (sorted-set 1 2 3 4 5) <= 3))") == .vector(SwishPersistentVector([1, 2, 3].map { .integer($0) }), metadata: nil))
    }

    @Test("subseq range form and rsubseq")
    func subseqRangeAndRsubseq() throws {
        #expect(try swish.eval("(vec (subseq (sorted-set 1 2 3 4 5) > 1 < 5))") == .vector(SwishPersistentVector([2, 3, 4].map { .integer($0) }), metadata: nil))
        #expect(try swish.eval("(vec (rsubseq (sorted-set 1 2 3 4 5) < 4))") == .vector(SwishPersistentVector([3, 2, 1].map { .integer($0) }), metadata: nil))
    }

    @Test("subseq over a sorted-map yields entries")
    func subseqSortedMap() throws {
        #expect(try swish.eval("(vec (subseq (sorted-map 1 :a 2 :b 3 :c) >= 2))")
            == .vector([.vector([.integer(2), .keyword("b")], metadata: nil),
                        .vector([.integer(3), .keyword("c")], metadata: nil)], metadata: nil))
    }
}
