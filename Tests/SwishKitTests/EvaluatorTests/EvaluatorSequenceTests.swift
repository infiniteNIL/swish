import Testing
@testable import SwishKit

@Suite("Evaluator Sequence Tests", .serialized)
struct EvaluatorSequenceTests {
    static let _shared = Evaluator()
    var evaluator: Evaluator { Self._shared }

    // MARK: - seq

    @Test("seq of nil returns nil")
    func seqOfNil() throws {
        #expect(try evaluator.eval("(seq nil)") == .nil)
    }

    @Test("seq of empty list returns nil")
    func seqOfEmptyList() throws {
        #expect(try evaluator.eval("(seq '())") == .nil)
    }

    @Test("seq of empty vector returns nil")
    func seqOfEmptyVector() throws {
        #expect(try evaluator.eval("(seq [])") == .nil)
    }

    @Test("seq of non-empty list returns a list")
    func seqOfList() throws {
        #expect(try evaluator.eval("(seq '(1 2 3))") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("seq of vector returns a list")
    func seqOfVector() throws {
        #expect(try evaluator.eval("(seq [1 2 3])") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("seq of string returns character list")
    func seqOfString() throws {
        #expect(try evaluator.eval("(seq \"ab\")") == .list([.character("a"), .character("b")], metadata: nil))
    }

    @Test("seq of map returns entries as vectors")
    func seqOfMap() throws {
        let result = try evaluator.eval("(seq {:a 1})")
        guard case .list(let entries, _) = result, entries.count == 1,
              case .vector(let pair, _) = entries[0], pair.count == 2
        else { Issue.record("Expected list of one vector pair"); return }
        #expect(pair[0] == .keyword("a"))
        #expect(pair[1] == .integer(1))
    }

    @Test("seq of set returns elements")
    func seqOfSet() throws {
        let result = try evaluator.eval("(count (seq #{1 2 3}))")
        #expect(result == .integer(3))
    }

    // MARK: - next

    @Test("next of single-element list returns nil")
    func nextSingleElement() throws {
        #expect(try evaluator.eval("(next '(1))") == .nil)
    }

    @Test("next of two-element list returns one-element list")
    func nextTwoElements() throws {
        #expect(try evaluator.eval("(next '(1 2))") == .list([.integer(2)], metadata: nil))
    }

    @Test("next of nil returns nil")
    func nextOfNil() throws {
        #expect(try evaluator.eval("(next nil)") == .nil)
    }

    @Test("next differs from rest on empty result")
    func nextVsRest() throws {
        // rest returns () but next returns nil
        #expect(try evaluator.eval("(rest '(1))") == .list([], metadata: nil))
        #expect(try evaluator.eval("(next '(1))") == .nil)
    }

    // MARK: - conj

    @Test("conj onto nil creates a list")
    func conjOntoNil() throws {
        #expect(try evaluator.eval("(conj nil 1)") == .list([.integer(1)], metadata: nil))
    }

    @Test("conj onto list prepends")
    func conjOntoList() throws {
        #expect(try evaluator.eval("(conj '(1 2) 0)") == .list([.integer(0), .integer(1), .integer(2)], metadata: nil))
    }

    @Test("conj onto vector appends")
    func conjOntoVector() throws {
        #expect(try evaluator.eval("(conj [1 2] 3)") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("conj onto map adds entry")
    func conjOntoMap() throws {
        let result = try evaluator.eval("(conj {:a 1} [:b 2])")
        guard case .map(let dict, _) = result else { Issue.record("Expected map"); return }
        #expect(dict[.keyword("a")] == .integer(1))
        #expect(dict[.keyword("b")] == .integer(2))
    }

    @Test("conj onto set adds element")
    func conjOntoSet() throws {
        let result = try evaluator.eval("(count (conj #{1 2} 3))")
        #expect(result == .integer(3))
    }

    @Test("conj with multiple items applies in order")
    func conjMultipleItems() throws {
        #expect(try evaluator.eval("(conj [1] 2 3)") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    // MARK: - Collection constructors

    @Test("vector creates a vector from args")
    func vectorConstructor() throws {
        #expect(try evaluator.eval("(vector 1 2 3)") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("vector with no args creates empty vector")
    func vectorEmpty() throws {
        #expect(try evaluator.eval("(vector)") == .vector([], metadata: nil))
    }

    @Test("hash-map creates a map from pairs")
    func hashMapConstructor() throws {
        let result = try evaluator.eval("(hash-map :a 1 :b 2)")
        guard case .map(let dict, _) = result else { Issue.record("Expected map"); return }
        #expect(dict[.keyword("a")] == .integer(1))
        #expect(dict[.keyword("b")] == .integer(2))
    }

    @Test("hash-map with no args creates empty map")
    func hashMapEmpty() throws {
        #expect(try evaluator.eval("(hash-map)") == .map([:], metadata: nil))
    }

    @Test("hash-set creates a set from args")
    func hashSetConstructor() throws {
        let result = try evaluator.eval("(hash-set 1 2 3)")
        #expect(result == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    // MARK: - concat

    @Test("concat with no args returns empty list")
    func concatNone() throws {
        #expect(try evaluator.eval("(concat)") == .list([], metadata: nil))
    }

    @Test("concat two lists")
    func concatLists() throws {
        #expect(try evaluator.eval("(concat '(1 2) '(3 4))") == .list([.integer(1), .integer(2), .integer(3), .integer(4)], metadata: nil))
    }

    @Test("concat list and vector")
    func concatListVector() throws {
        #expect(try evaluator.eval("(concat '(1 2) [3 4])") == .list([.integer(1), .integer(2), .integer(3), .integer(4)], metadata: nil))
    }

    @Test("concat with nil is harmless")
    func concatWithNil() throws {
        #expect(try evaluator.eval("(concat '(1) nil '(2))") == .list([.integer(1), .integer(2)], metadata: nil))
    }

    // MARK: - first/rest on all collection types

    @Test("first on vector works")
    func firstOnVector() throws {
        #expect(try evaluator.eval("(first [1 2 3])") == .integer(1))
    }

    @Test("rest on vector returns a list")
    func restOnVector() throws {
        #expect(try evaluator.eval("(rest [1 2 3])") == .list([.integer(2), .integer(3)], metadata: nil))
    }

    @Test("first on map returns a key-value vector")
    func firstOnMap() throws {
        let result = try evaluator.eval("(first {:a 1})")
        guard case .vector(let pair, _) = result, pair.count == 2 else {
            Issue.record("Expected [k v] vector"); return
        }
        #expect(pair[0] == .keyword("a"))
        #expect(pair[1] == .integer(1))
    }

    @Test("first on set returns an element")
    func firstOnSet() throws {
        let result = try evaluator.eval("(first #{42})")
        #expect(result == .integer(42))
    }

    // MARK: - apply

    @Test("apply calls function with sequence as args")
    func applyBasic() throws {
        #expect(try evaluator.eval("(apply + [1 2 3])") == .integer(6))
    }

    @Test("apply with prefix args")
    func applyWithPrefix() throws {
        #expect(try evaluator.eval("(apply + 1 2 [3 4])") == .integer(10))
    }

    @Test("apply with empty sequence")
    func applyEmptySeq() throws {
        #expect(try evaluator.eval("(apply + [])") == .integer(0))
    }

    @Test("apply works with user-defined functions")
    func applyUserFn() throws {
        #expect(try evaluator.eval("(apply (fn [x y] (+ x y)) [3 4])") == .integer(7))
    }

    // MARK: - map

    @Test("map transforms each element")
    func mapBasic() throws {
        #expect(try evaluator.eval("(map inc [1 2 3])") == .list([.integer(2), .integer(3), .integer(4)], metadata: nil))
    }

    @Test("map on empty collection returns empty list")
    func mapEmpty() throws {
        #expect(try evaluator.eval("(map inc [])") == .list([], metadata: nil))
    }

    @Test("map with two collections zips to shortest")
    func mapTwoCollections() throws {
        #expect(try evaluator.eval("(map + [1 2 3] [4 5 6])") == .list([.integer(5), .integer(7), .integer(9)], metadata: nil))
    }

    @Test("map with user-defined function")
    func mapUserFn() throws {
        #expect(try evaluator.eval("(map (fn [x] (* x x)) [1 2 3])") == .list([.integer(1), .integer(4), .integer(9)], metadata: nil))
    }

    // MARK: - filter

    @Test("filter keeps matching elements")
    func filterBasic() throws {
        _ = try evaluator.eval("(defn odd? [x] (not (= 0 (mod x 2))))")
        #expect(try evaluator.eval("(filter odd? [1 2 3 4 5])") == .list([.integer(1), .integer(3), .integer(5)], metadata: nil))
    }

    @Test("filter on empty collection returns empty list")
    func filterEmpty() throws {
        #expect(try evaluator.eval("(filter nil? [])") == .list([], metadata: nil))
    }

    @Test("filter with anonymous function")
    func filterAnon() throws {
        #expect(try evaluator.eval("(filter (fn [x] (> x 2)) [1 2 3 4])") == .list([.integer(3), .integer(4)], metadata: nil))
    }

    // MARK: - reduce

    @Test("reduce with initial value")
    func reduceWithInit() throws {
        #expect(try evaluator.eval("(reduce + 0 [1 2 3])") == .integer(6))
    }

    @Test("reduce without initial value")
    func reduceNoInit() throws {
        #expect(try evaluator.eval("(reduce + [1 2 3])") == .integer(6))
    }

    @Test("reduce single element without init returns element")
    func reduceSingleNoInit() throws {
        #expect(try evaluator.eval("(reduce + [42])") == .integer(42))
    }

    @Test("reduce empty with init returns init")
    func reduceEmptyWithInit() throws {
        #expect(try evaluator.eval("(reduce + 99 [])") == .integer(99))
    }

    @Test("reduce empty without init calls f with no args")
    func reduceEmptyNoInit() throws {
        #expect(try evaluator.eval("(reduce + [])") == .integer(0))
    }

    @Test("reduce builds a result with a function")
    func reduceBuilds() throws {
        #expect(try evaluator.eval("(reduce (fn [acc x] (conj acc x)) [] '(1 2 3))") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    // MARK: - into

    @Test("into pours list into vector")
    func intoListToVector() throws {
        #expect(try evaluator.eval("(into [] '(1 2 3))") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("into pours vector into list")
    func intoVectorToList() throws {
        #expect(try evaluator.eval("(into '() [1 2 3])") == .list([.integer(3), .integer(2), .integer(1)], metadata: nil))
    }

    @Test("into pours pairs into map")
    func intoPairsToMap() throws {
        let result = try evaluator.eval("(into {} [[:a 1] [:b 2]])")
        guard case .map(let dict, _) = result else { Issue.record("Expected map"); return }
        #expect(dict[.keyword("a")] == .integer(1))
        #expect(dict[.keyword("b")] == .integer(2))
    }

    // MARK: - empty? / not-empty

    @Test("empty? true for empty collections")
    func emptyTrue() throws {
        #expect(try evaluator.eval("(empty? [])") == .boolean(true))
        #expect(try evaluator.eval("(empty? '())") == .boolean(true))
        #expect(try evaluator.eval("(empty? nil)") == .boolean(true))
    }

    @Test("empty? false for non-empty collections")
    func emptyFalse() throws {
        #expect(try evaluator.eval("(empty? [1])") == .boolean(false))
        #expect(try evaluator.eval("(empty? '(1))") == .boolean(false))
    }

    @Test("not-empty returns nil for empty, coll for non-empty")
    func notEmpty() throws {
        #expect(try evaluator.eval("(not-empty [])") == .nil)
        #expect(try evaluator.eval("(not-empty [1 2])") == .vector([.integer(1), .integer(2)], metadata: nil))
    }

    // MARK: - contains?

    @Test("contains? true for existing map key")
    func containsMapKeyExists() throws {
        #expect(try evaluator.eval("(contains? {:a 1 :b 2} :a)") == .boolean(true))
    }

    @Test("contains? false for missing map key")
    func containsMapKeyMissing() throws {
        #expect(try evaluator.eval("(contains? {:a 1} :b)") == .boolean(false))
    }

    @Test("contains? true for map key whose value is nil")
    func containsMapNilValue() throws {
        #expect(try evaluator.eval("(contains? {:a nil} :a)") == .boolean(true))
    }

    @Test("contains? true for set member")
    func containsSetMember() throws {
        #expect(try evaluator.eval("(contains? #{1 2 3} 2)") == .boolean(true))
    }

    @Test("contains? false for non-member set")
    func containsSetNonMember() throws {
        #expect(try evaluator.eval("(contains? #{1 2 3} 5)") == .boolean(false))
    }

    @Test("contains? true for valid vector index")
    func containsVectorIndex() throws {
        #expect(try evaluator.eval("(contains? [10 20 30] 0)") == .boolean(true))
        #expect(try evaluator.eval("(contains? [10 20 30] 2)") == .boolean(true))
    }

    @Test("contains? false for out-of-bounds vector index")
    func containsVectorOutOfBounds() throws {
        #expect(try evaluator.eval("(contains? [10 20 30] 3)") == .boolean(false))
        #expect(try evaluator.eval("(contains? [10 20 30] -1)") == .boolean(false))
    }

    @Test("contains? false for nil collection")
    func containsNil() throws {
        #expect(try evaluator.eval("(contains? nil :a)") == .boolean(false))
    }

    @Test("contains? throws for lists")
    func containsListThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "contains?", message: "(1 2 3) is not supported")) {
            try evaluator.eval("(contains? '(1 2 3) 1)")
        }
    }

    // MARK: - mapcat

    @Test("mapcat maps and concatenates")
    func mapcatBasic() throws {
        #expect(try evaluator.eval("(mapcat (fn [x] [x x]) [1 2 3])") == .list([.integer(1), .integer(1), .integer(2), .integer(2), .integer(3), .integer(3)], metadata: nil))
    }

    // MARK: - keep

    @Test("keep returns non-nil results")
    func keepBasic() throws {
        #expect(try evaluator.eval("(keep (fn [x] (when (odd? x) x)) [1 2 3 4 5])") == .list([.integer(1), .integer(3), .integer(5)], metadata: nil))
    }

    @Test("keep includes false results")
    func keepIncludesFalse() throws {
        #expect(try evaluator.eval("(keep (fn [x] (odd? x)) [1 2 3])") == .list([.boolean(true), .boolean(false), .boolean(true)], metadata: nil))
    }

    @Test("keep excludes nil results")
    func keepExcludesNil() throws {
        #expect(try evaluator.eval("(keep (fn [x] (when (> x 3) x)) [1 2 3 4 5])") == .list([.integer(4), .integer(5)], metadata: nil))
    }

    @Test("keep on empty collection returns empty list")
    func keepEmpty() throws {
        #expect(try evaluator.eval("(keep identity [])") == .list([], metadata: nil))
    }

    @Test("keep works on a list")
    func keepOnList() throws {
        #expect(try evaluator.eval("(keep (fn [x] (when (even? x) x)) '(1 2 3 4))") == .list([.integer(2), .integer(4)], metadata: nil))
    }

    // MARK: - keep-indexed

    @Test("keep-indexed passes index and item to f")
    func keepIndexedBasic() throws {
        #expect(try evaluator.eval("(keep-indexed (fn [i x] (when (even? i) x)) [:a :b :c :d :e])") == .list([.keyword("a"), .keyword("c"), .keyword("e")], metadata: nil))
    }

    @Test("keep-indexed includes false results")
    func keepIndexedIncludesFalse() throws {
        #expect(try evaluator.eval("(keep-indexed (fn [i x] (even? i)) [10 20 30])") == .list([.boolean(true), .boolean(false), .boolean(true)], metadata: nil))
    }

    @Test("keep-indexed excludes nil results")
    func keepIndexedExcludesNil() throws {
        #expect(try evaluator.eval("(keep-indexed (fn [i x] (when (odd? i) x)) [:a :b :c :d])") == .list([.keyword("b"), .keyword("d")], metadata: nil))
    }

    @Test("keep-indexed on empty collection returns empty list")
    func keepIndexedEmpty() throws {
        #expect(try evaluator.eval("(keep-indexed (fn [i x] x) [])") == .list([], metadata: nil))
    }

    @Test("keep-indexed index starts at 0")
    func keepIndexedIndexStartsAt0() throws {
        #expect(try evaluator.eval("(keep-indexed (fn [i x] i) [:a :b :c])") == .list([.integer(0), .integer(1), .integer(2)], metadata: nil))
    }

    // MARK: - map-indexed

    @Test("map-indexed applies f with index and item")
    func mapIndexedBasic() throws {
        #expect(try evaluator.eval("(map-indexed (fn [i x] (* i x)) [1 2 3])") == .list([.integer(0), .integer(2), .integer(6)], metadata: nil))
    }

    @Test("map-indexed index starts at 0")
    func mapIndexedIndexStartsAt0() throws {
        #expect(try evaluator.eval("(map-indexed (fn [i x] i) [:a :b :c])") == .list([.integer(0), .integer(1), .integer(2)], metadata: nil))
    }

    @Test("map-indexed on empty collection returns empty list")
    func mapIndexedEmpty() throws {
        #expect(try evaluator.eval("(map-indexed (fn [i x] x) [])") == .list([], metadata: nil))
    }

    @Test("map-indexed works on a list")
    func mapIndexedOnList() throws {
        #expect(try evaluator.eval("(map-indexed (fn [i x] (+ i x)) '(10 20 30))") == .list([.integer(10), .integer(21), .integer(32)], metadata: nil))
    }

    // MARK: - dorun

    @Test("dorun on empty collection returns nil")
    func dorunEmpty() throws {
        #expect(try evaluator.eval("(dorun [])") == .nil)
    }

    @Test("dorun returns nil, not the seq")
    func dorunReturnsNil() throws {
        #expect(try evaluator.eval("(dorun [1 2 3])") == .nil)
    }

    @Test("dorun with count returns nil")
    func dorunWithCount() throws {
        #expect(try evaluator.eval("(dorun 2 [1 2 3 4 5])") == .nil)
    }

    // MARK: - doall

    @Test("doall on empty collection returns empty vector")
    func doallEmpty() throws {
        #expect(try evaluator.eval("(doall [])") == .vector([], metadata: nil))
    }

    @Test("doall returns the collection itself")
    func doallVector() throws {
        #expect(try evaluator.eval("(doall [1 2 3])") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("doall works on a list")
    func doallList() throws {
        #expect(try evaluator.eval("(doall '(1 2 3))") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("doall with count returns full collection")
    func doallWithCount() throws {
        #expect(try evaluator.eval("(doall 2 [1 2 3])") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    // MARK: - doseq

    @Test("doseq returns nil")
    func doseqReturnsNil() throws {
        #expect(try evaluator.eval("(doseq [x [1 2 3]] x)") == .nil)
    }

    @Test("doseq iterates over a collection")
    func doseqBasic() throws {
        #expect(try evaluator.eval("""
            (let [result (atom [])]
              (doseq [x [1 2 3]]
                (swap! result conj x))
              @result)
            """) == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("doseq with multiple bindings is nested")
    func doseqMultipleBindings() throws {
        #expect(try evaluator.eval("""
            (let [result (atom [])]
              (doseq [x [1 2]
                      y [:a :b]]
                (swap! result conj [x y]))
              @result)
            """) == .vector([
                .vector([.integer(1), .keyword("a")], metadata: nil),
                .vector([.integer(1), .keyword("b")], metadata: nil),
                .vector([.integer(2), .keyword("a")], metadata: nil),
                .vector([.integer(2), .keyword("b")], metadata: nil)
            ], metadata: nil))
    }

    @Test("doseq :when skips non-matching elements")
    func doseqWhen() throws {
        #expect(try evaluator.eval("""
            (let [result (atom [])]
              (doseq [x [1 2 3 4 5]
                      :when (odd? x)]
                (swap! result conj x))
              @result)
            """) == .vector([.integer(1), .integer(3), .integer(5)], metadata: nil))
    }

    @Test("doseq :while stops at first false")
    func doseqWhile() throws {
        #expect(try evaluator.eval("""
            (let [result (atom [])]
              (doseq [x [1 2 3 4 5]
                      :while (< x 4)]
                (swap! result conj x))
              @result)
            """) == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("doseq :let binds in scope")
    func doseqLet() throws {
        #expect(try evaluator.eval("""
            (let [result (atom [])]
              (doseq [x [1 2 3]
                      :let [doubled (* x 2)]]
                (swap! result conj doubled))
              @result)
            """) == .vector([.integer(2), .integer(4), .integer(6)], metadata: nil))
    }

    @Test("doseq on empty collection runs body zero times")
    func doseqEmpty() throws {
        #expect(try evaluator.eval("""
            (let [result (atom [])]
              (doseq [x []]
                (swap! result conj x))
              @result)
            """) == .vector([], metadata: nil))
    }
}
