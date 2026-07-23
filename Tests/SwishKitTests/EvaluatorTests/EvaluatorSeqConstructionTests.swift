import Testing
@testable import SwishKit

@Suite("Evaluator Seq Construction Tests", .serialized)
struct EvaluatorSeqConstructionTests {
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

    @Test("seq of map returns entries as map entries")
    func seqOfMap() throws {
        let result = try evaluator.eval("(seq {:a 1})")
        guard case .seq(let entries) = result, entries.count == 1,
              case .mapEntry(let k, let v) = entries[0]
        else { Issue.record("Expected seq of one map entry"); return }
        #expect(k == .keyword("a"))
        #expect(v == .integer(1))
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

    @Test("conj onto map adds entry")
    func conjOntoMap() throws {
        let result = try evaluator.eval("(conj {:a 1} [:b 2])")
        guard case .map(let sm) = result else { Issue.record("Expected map"); return }
        #expect(sm.dict[.keyword("a")] == .integer(1))
        #expect(sm.dict[.keyword("b")] == .integer(2))
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
        guard case .map(let sm) = result else { Issue.record("Expected map"); return }
        #expect(sm.dict[.keyword("a")] == .integer(1))
        #expect(sm.dict[.keyword("b")] == .integer(2))
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

    // MARK: - first on non-list collection types

    @Test("first on map returns a map entry")
    func firstOnMap() throws {
        let result = try evaluator.eval("(first {:a 1})")
        guard case .mapEntry(let k, let v) = result else {
            Issue.record("Expected map entry"); return
        }
        #expect(k == .keyword("a"))
        #expect(v == .integer(1))
    }

    @Test("first on set returns an element")
    func firstOnSet() throws {
        let result = try evaluator.eval("(first #{42})")
        #expect(result == .integer(42))
    }

}
