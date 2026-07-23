import Testing
@testable import SwishKit

@Suite("Evaluator Higher Order Sequence Tests", .serialized)
struct EvaluatorHigherOrderSequenceTests {
    static let _shared = Evaluator()
    var evaluator: Evaluator { Self._shared }

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

    @Test("reduce throws for a non-seqable collection instead of silently treating it as empty")
    func reduceNonSeqableThrows() throws {
        #expect(throws: (any Error).self) { try evaluator.eval("(reduce + 0 true)") }
        #expect(throws: (any Error).self) { try evaluator.eval("(reduce (fn [_ x] x) nil 42)") }
    }

    @Test("reduce still works on every legitimately seqable type after the non-seqable fix")
    func reduceSeqableStillWorks() throws {
        #expect(try evaluator.eval("(reduce + 0 [1 2 3])") == .integer(6))
        #expect(try evaluator.eval("(reduce + 0 #{1 2 3})") == .integer(6))
        #expect(try evaluator.eval(#"(reduce str "" "abc")"#) == .string("abc"))
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
        guard case .map(let sm) = result else { Issue.record("Expected map"); return }
        #expect(sm.dict[.keyword("a")] == .integer(1))
        #expect(sm.dict[.keyword("b")] == .integer(2))
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

    @Test("contains? true for valid array index")
    func containsArrayIndex() throws {
        #expect(try evaluator.eval("(contains? (int-array [1 2 3]) 0)") == .boolean(true))
        #expect(try evaluator.eval("(contains? (int-array [1 2 3]) 2)") == .boolean(true))
    }

    @Test("contains? false for out-of-bounds array index")
    func containsArrayOutOfBounds() throws {
        #expect(try evaluator.eval("(contains? (int-array [1 2 3]) 3)") == .boolean(false))
        #expect(try evaluator.eval("(contains? (int-array [1 2 3]) -1)") == .boolean(false))
    }

    @Test("contains? throws for non-integer key on array (unlike vectors, which return false)")
    func containsArrayNonIntegerKeyThrows() throws {
        #expect(throws: (any Error).self) { try evaluator.eval("(contains? (int-array [1 2 3]) :a)") }
        #expect(throws: (any Error).self) { try evaluator.eval("(contains? (int-array [1 2 3]) nil)") }
    }

    @Test("contains? true for valid map entry index")
    func containsMapEntryIndex() throws {
        #expect(try evaluator.eval("(contains? (first {:a 1}) 0)") == .boolean(true))
        #expect(try evaluator.eval("(contains? (first {:a 1}) 1)") == .boolean(true))
    }

    @Test("contains? false for out-of-bounds map entry index")
    func containsMapEntryOutOfBounds() throws {
        #expect(try evaluator.eval("(contains? (first {:a 1}) 2)") == .boolean(false))
    }

    @Test("contains? false for non-integer key on map entry (vector-like, not array-like)")
    func containsMapEntryNonIntegerKey() throws {
        #expect(try evaluator.eval("(contains? (first {:a 1}) :a)") == .boolean(false))
    }

}
