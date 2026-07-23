import Testing
@testable import SwishKit

@Suite("Core Map Mutation Tests", .serialized)
struct CoreMapMutationTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - assoc on vector

    @Test("(assoc [1 2 3] 1 :b) replaces element at index")
    func assocVectorReplace() throws {
        #expect(try swish.eval("(assoc [1 2 3] 1 :b)") == .vector([.integer(1), .keyword("b"), .integer(3)], metadata: nil))
    }

    @Test("(assoc [1 2 3] 0 :a 2 :c) applies multiple pairs")
    func assocVectorMultiplePairs() throws {
        #expect(try swish.eval("(assoc [1 2 3] 0 :a 2 :c)") == .vector([.keyword("a"), .integer(2), .keyword("c")], metadata: nil))
    }

    @Test("(assoc [1 2 3] 3 :d) appends at end")
    func assocVectorAppend() throws {
        #expect(try swish.eval("(assoc [1 2 3] 3 :d)") == .vector([.integer(1), .integer(2), .integer(3), .keyword("d")], metadata: nil))
    }

    @Test("(assoc [] 0 :x) appends to empty vector")
    func assocVectorAppendToEmpty() throws {
        #expect(try swish.eval("(assoc [] 0 :x)") == .vector([.keyword("x")], metadata: nil))
    }

    @Test("(assoc [1 2 3] -1 :x) throws on negative index")
    func assocVectorNegativeIndex() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "assoc", message: "index -1 out of bounds for vector of size 3")) {
            try swish.eval("(assoc [1 2 3] -1 :x)")
        }
    }

    @Test("(assoc [1 2 3] 4 :x) throws when index skips past end")
    func assocVectorIndexTooLarge() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "assoc", message: "index 4 out of bounds for vector of size 3")) {
            try swish.eval("(assoc [1 2 3] 4 :x)")
        }
    }

    @Test("(assoc [1 2 3] :k :v) throws on non-integer key")
    func assocVectorNonIntegerKey() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "assoc", message: "vector index must be an integer, got :k")) {
            try swish.eval("(assoc [1 2 3] :k :v)")
        }
    }

    // MARK: - keyword as function (zero/three args)

    @Test("(:a) throws on zero args")
    func keywordAsFunctionZeroArgs() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "keyword", message: "requires 1 or 2 arguments, got 0")) {
            try swish.eval("(:a)")
        }
    }

    @Test("(:a {:a 1} :b :c) throws on three args")
    func keywordAsFunctionThreeArgs() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "keyword", message: "requires 1 or 2 arguments, got 3")) {
            try swish.eval("(:a {:a 1} :b :c)")
        }
    }

    // MARK: - merge

    @Test("(merge) returns nil")
    func mergeNoArgs() throws {
        #expect(try swish.eval("(merge)") == .nil)
    }

    @Test("(merge nil) returns nil")
    func mergeNilReturnsNil() throws {
        #expect(try swish.eval("(merge nil)") == .nil)
    }

    @Test("(merge nil nil) returns nil")
    func mergeAllNilReturnsNil() throws {
        #expect(try swish.eval("(merge nil nil)") == .nil)
    }

    @Test("(merge {} {}) returns empty map, not nil")
    func mergeTwoEmptyMapsReturnsEmptyMap() throws {
        #expect(try swish.eval("(merge {} {})") == .map([:], metadata: nil))
    }

    @Test("(merge nil {}) returns empty map")
    func mergeNilAndEmptyMapReturnsEmptyMap() throws {
        #expect(try swish.eval("(merge nil {})") == .map([:], metadata: nil))
    }

    @Test("(merge {:a 1} {:b 2}) merges both maps")
    func mergeTwoMaps() throws {
        let result = try swish.eval("(merge {:a 1} {:b 2})")
        #expect(result == .map([.keyword("a"): .integer(1), .keyword("b"): .integer(2)], metadata: nil))
    }

    @Test("(merge {:a 1} {:a 2}) later value wins")
    func mergeLaterValueWins() throws {
        #expect(try swish.eval("(merge {:a 1} {:a 2})") == .map([.keyword("a"): .integer(2)], metadata: nil))
    }

    @Test("merge accepts a 2-element vector as a map entry")
    func mergeVectorEntry() throws {
        #expect(try swish.eval("(merge {} [:foo \"foo\"])") ==
            .map([.keyword("foo"): .string("foo")], metadata: nil))
    }

    @Test("merge accepts multiple vector entries")
    func mergeMultipleVectorEntries() throws {
        #expect(try swish.eval("(merge {} [:foo \"foo\"] [:bar \"bar\"])") ==
            .map([.keyword("foo"): .string("foo"), .keyword("bar"): .string("bar")], metadata: nil))
    }

    // MARK: - dissoc

    @Test("(dissoc {:a 1 :b 2} :a) removes one key")
    func dissocOneKey() throws {
        #expect(try swish.eval("(dissoc {:a 1 :b 2} :a)") == .map([.keyword("b"): .integer(2)], metadata: nil))
    }

    @Test("(dissoc {:a 1 :b 2} :a :b) removes multiple keys")
    func dissocMultipleKeys() throws {
        #expect(try swish.eval("(dissoc {:a 1 :b 2} :a :b)") == .map([:], metadata: nil))
    }

    @Test("(dissoc {:a 1} :missing) returns map unchanged for absent key")
    func dissocMissingKey() throws {
        #expect(try swish.eval("(dissoc {:a 1} :missing)") == .map([.keyword("a"): .integer(1)], metadata: nil))
    }

    @Test("(dissoc {:a 1}) returns map unchanged when no keys given")
    func dissocNoKeys() throws {
        #expect(try swish.eval("(dissoc {:a 1})") == .map([.keyword("a"): .integer(1)], metadata: nil))
    }

    @Test("(dissoc nil :a) returns nil")
    func dissocNilReturnsNil() throws {
        #expect(try swish.eval("(dissoc nil :a)") == .nil)
    }

    @Test("(dissoc nil) returns nil")
    func dissocNilNoKeysReturnsNil() throws {
        #expect(try swish.eval("(dissoc nil)") == .nil)
    }

    @Test("(dissoc 42 :a) throws on non-map first arg")
    func dissocNonMapThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "dissoc", message: "first argument must be a map or nil, got 42")) {
            try swish.eval("(dissoc 42 :a)")
        }
    }

    @Test("dissoc preserves map metadata")
    func dissocPreservesMeta() throws {
        let result = try swish.eval(
            "(let [m (with-meta {:a 1 :b 2} {:tag :test})] (meta (dissoc m :a)))")
        #expect(result == .map([.keyword("tag"): .keyword("test")], metadata: nil))
    }

    // MARK: - get-in

    @Test("(get-in {:a {:b 1}} [:a :b]) returns nested value")
    func getInBasic() throws {
        #expect(try swish.eval("(get-in {:a {:b 1}} [:a :b])") == .integer(1))
    }

    @Test("(get-in {:a {:b 1}} [:a :c]) returns nil for missing key")
    func getInMissingKey() throws {
        #expect(try swish.eval("(get-in {:a {:b 1}} [:a :c])") == .nil)
    }

    @Test("(get-in {:a {:b 1}} [:a :c] 42) returns not-found for missing key")
    func getInNotFound() throws {
        #expect(try swish.eval("(get-in {:a {:b 1}} [:a :c] 42)") == .integer(42))
    }

    @Test("(get-in {:a nil} [:a :b] :nf) returns not-found when intermediate is nil")
    func getInFoundNilIntermediate() throws {
        #expect(try swish.eval("(get-in {:a nil} [:a :b] :nf)") == .keyword("nf"))
    }

    @Test("(get-in {:a 1} []) returns m for empty path")
    func getInEmptyPath() throws {
        #expect(try swish.eval("(get-in {:a 1} [])") == .map([.keyword("a"): .integer(1)], metadata: nil))
    }

    @Test("(get-in nil [:a]) returns nil")
    func getInNilRoot() throws {
        #expect(try swish.eval("(get-in nil [:a])") == .nil)
    }

    @Test("(get-in nil [:a] 99) returns not-found for nil root")
    func getInNilRootNotFound() throws {
        #expect(try swish.eval("(get-in nil [:a] 99)") == .integer(99))
    }

    @Test("(get-in [[1 2] [3 4]] [1 0]) traverses vectors by index")
    func getInVectorPath() throws {
        #expect(try swish.eval("(get-in [[1 2] [3 4]] [1 0])") == .integer(3))
    }

    // get-in delegates to the same lookupOptional dispatch as get, so every
    // type get supports should now work through get-in too.

    @Test("(get-in {:a \"hello\"} [:a 1]) indexes into a string")
    func getInStringPath() throws {
        #expect(try swish.eval(#"(get-in {:a "hello"} [:a 1])"#) == .character("e"))
    }

    @Test("(get-in [#{:x :y}] [0 :x]) tests set membership, nil if absent")
    func getInSetPath() throws {
        #expect(try swish.eval("(get-in [#{:x :y}] [0 :x])") == .keyword("x"))
        #expect(try swish.eval("(get-in [#{:x :y}] [0 :z])") == .nil)
    }

    @Test("(get-in [(sorted-set 1 2 3)] [0 2]) tests sorted-set membership, nil if absent")
    func getInSortedSetPath() throws {
        #expect(try swish.eval("(get-in [(sorted-set 1 2 3)] [0 2])") == .integer(2))
        #expect(try swish.eval("(get-in [(sorted-set 1 2 3)] [0 99])") == .nil)
    }

    @Test("(get-in [(to-array [10 20 30])] [0 1]) indexes into an array")
    func getInArrayPath() throws {
        #expect(try swish.eval("(get-in [(to-array [10 20 30])] [0 1])") == .integer(20))
    }

    @Test("(get-in [(transient {:a 1})] [0 :a]) looks up in a transient map")
    func getInTransientPath() throws {
        #expect(try swish.eval("(get-in [(transient {:a 1})] [0 :a])") == .integer(1))
    }

    @Test("(get-in [record] [0 :field]) looks up a defrecord field")
    func getInRecordPath() throws {
        #expect(try swish.eval("""
            (defrecord GetInPoint [x y])
            (get-in [(->GetInPoint 1 2)] [0 :x])
            """) == .integer(1))
    }

    // MARK: - assoc metadata preservation

    @Test("assoc preserves metadata on map")
    func assocPreservesMapMeta() throws {
        let result = try swish.eval("(meta (assoc (with-meta {:a 1} {:tag :x}) :b 2))")
        #expect(result == .map([.keyword("tag"): .keyword("x")], metadata: nil))
    }

    @Test("assoc preserves metadata on vector")
    func assocPreservesVectorMeta() throws {
        let result = try swish.eval("(meta (assoc (with-meta [1 2] {:tag :x}) 0 9))")
        #expect(result == .map([.keyword("tag"): .keyword("x")], metadata: nil))
    }

    // MARK: - assoc-in

    @Test("(assoc-in {:a 1} [:a] 99) single key — same as assoc")
    func assocInSingleKey() throws {
        #expect(try swish.eval("(assoc-in {:a 1} [:a] 99)") == .map([.keyword("a"): .integer(99)], metadata: nil))
    }

    @Test("(assoc-in {:a {:b 1}} [:a :b] 99) updates nested key")
    func assocInNestedKey() throws {
        #expect(try swish.eval("(assoc-in {:a {:b 1}} [:a :b] 99)") == .map([.keyword("a"): .map([.keyword("b"): .integer(99)], metadata: nil)], metadata: nil))
    }

    @Test("(assoc-in {} [:a :b] 42) creates intermediate maps")
    func assocInCreatesIntermediates() throws {
        #expect(try swish.eval("(assoc-in {} [:a :b] 42)") == .map([.keyword("a"): .map([.keyword("b"): .integer(42)], metadata: nil)], metadata: nil))
    }

    @Test("(assoc-in nil [:a :b] 1) treats nil root as empty map")
    func assocInNilRoot() throws {
        #expect(try swish.eval("(assoc-in nil [:a :b] 1)") == .map([.keyword("a"): .map([.keyword("b"): .integer(1)], metadata: nil)], metadata: nil))
    }

    // MARK: - update

    @Test("(update {:a 1} :a inc) applies f to existing value")
    func updateInc() throws {
        #expect(try swish.eval("(update {:a 1} :a inc)") == .map([.keyword("a"): .integer(2)], metadata: nil))
    }

    @Test("(update {:a 1} :a + 10) passes extra arg to f")
    func updateExtraArg() throws {
        #expect(try swish.eval("(update {:a 1} :a + 10)") == .map([.keyword("a"): .integer(11)], metadata: nil))
    }

    @Test("(update {:a 1} :b str) passes nil to f for missing key")
    func updateMissingKey() throws {
        #expect(try swish.eval("(update {:a 1} :b str)") == .map([.keyword("a"): .integer(1), .keyword("b"): .string("")], metadata: nil))
    }

    @Test("(update {:a 0} :a + 1 2 3) uses apply arity for many extra args")
    func updateManyExtraArgs() throws {
        #expect(try swish.eval("(update {:a 0} :a + 1 2 3)") == .map([.keyword("a"): .integer(6)], metadata: nil))
    }

    // MARK: - update-in

    @Test("(update-in {:a {:b 1}} [:a :b] inc) updates nested value")
    func updateInNested() throws {
        #expect(try swish.eval("(update-in {:a {:b 1}} [:a :b] inc)") == .map([.keyword("a"): .map([.keyword("b"): .integer(2)], metadata: nil)], metadata: nil))
    }

    @Test("(update-in {:a {:b 1}} [:a :b] + 10) passes extra arg to f")
    func updateInExtraArg() throws {
        #expect(try swish.eval("(update-in {:a {:b 1}} [:a :b] + 10)") == .map([.keyword("a"): .map([.keyword("b"): .integer(11)], metadata: nil)], metadata: nil))
    }

}
