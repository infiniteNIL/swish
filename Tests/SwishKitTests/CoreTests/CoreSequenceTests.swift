import Testing
@testable import SwishKit

@Suite("Core Sequence Tests", .serialized)
struct CoreSequenceTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("(list) returns empty list")
    func listNoArgs() throws {
        #expect(try swish.eval("(list)") == .list([], metadata: nil))
    }

    @Test("(list 1) returns single-element list")
    func listOneArg() throws {
        #expect(try swish.eval("(list 1)") == .list([.integer(1)], metadata: nil))
    }

    @Test("(list 1 2 3) returns list of ints")
    func listInts() throws {
        #expect(try swish.eval("(list 1 2 3)") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(list \"a\" :b) returns mixed list")
    func listMixed() throws {
        #expect(try swish.eval("(list \"a\" :b)") == .list([.string("a"), .keyword("b")], metadata: nil))
    }

    // MARK: - cons

    @Test("(cons 1 '(2 3)) prepends to list")
    func consOntoList() throws {
        #expect(try swish.eval("(cons 1 '(2 3))") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(cons 1 [2 3]) prepends to vector, returns list")
    func consOntoVector() throws {
        #expect(try swish.eval("(cons 1 [2 3])") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(cons 1 nil) returns single-element list")
    func consOntoNil() throws {
        #expect(try swish.eval("(cons 1 nil)") == .list([.integer(1)], metadata: nil))
    }

    @Test("(cons \\a \"bc\") prepends char onto string as char seq")
    func consOntoString() throws {
        #expect(try swish.eval("(cons \\a \"bc\")") == .list([.character("a"), .character("b"), .character("c")], metadata: nil))
    }

    @Test("(cons 0 '()) returns single-element list from empty list")
    func consOntoEmptyList() throws {
        #expect(try swish.eval("(cons 0 '())") == .list([.integer(0)], metadata: nil))
    }

    @Test("(cons 1 2) throws invalidArgument")
    func consOntoNonCollectionThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "cons", message: "cannot cons onto 2")) {
            try swish.eval("(cons 1 2)")
        }
    }

    // MARK: - take

    @Test("(take 3 [1 2 3 4 5]) returns first 3 elements")
    func takeFromVector() throws {
        #expect(try swish.eval("(take 3 [1 2 3 4 5])") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(take 0 [1 2 3]) returns empty list")
    func takeZeroReturnsNil() throws {
        #expect(try swish.eval("(take 0 [1 2 3])") == .list([], metadata: nil))
    }

    @Test("(take 10 [1 2]) returns all when n exceeds length")
    func takeBeyondLength() throws {
        #expect(try swish.eval("(take 10 [1 2])") == .list([.integer(1), .integer(2)], metadata: nil))
    }

    @Test("(take 3 nil) returns empty list")
    func takeFromNil() throws {
        #expect(try swish.eval("(take 3 nil)") == .list([], metadata: nil))
    }

    @Test("(take 3 '(1 2 3 4)) works on lists")
    func takeFromList() throws {
        #expect(try swish.eval("(take 3 '(1 2 3 4))") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    // MARK: - take-while

    @Test("(take-while even? [2 4 6 1 2]) takes while pred is true")
    func takeWhileEven() throws {
        #expect(try swish.eval("(take-while even? [2 4 6 1 2])") == .list([.integer(2), .integer(4), .integer(6)], metadata: nil))
    }

    @Test("(take-while odd? [2 4 6]) returns empty list when pred fails immediately")
    func takeWhileFailsImmediately() throws {
        #expect(try swish.eval("(take-while odd? [2 4 6])") == .list([], metadata: nil))
    }

    @Test("(take-while even? nil) returns empty list")
    func takeWhileOnNil() throws {
        #expect(try swish.eval("(take-while even? nil)") == .list([], metadata: nil))
    }

    @Test("(take-while pos? [-1 2 3]) returns empty list when first fails")
    func takeWhileFirstFails() throws {
        #expect(try swish.eval("(take-while pos? [-1 2 3])") == .list([], metadata: nil))
    }

    // MARK: - drop-while

    @Test("(drop-while even? [2 4 6 1 2]) drops while pred is true")
    func dropWhileEven() throws {
        #expect(try swish.eval("(drop-while even? [2 4 6 1 2])") == .list([.integer(1), .integer(2)], metadata: nil))
    }

    @Test("(drop-while odd? [2 4 6]) returns full sequence when pred fails immediately")
    func dropWhileFailsImmediately() throws {
        #expect(try swish.eval("(drop-while odd? [2 4 6])") == .list([.integer(2), .integer(4), .integer(6)], metadata: nil))
    }

    @Test("(drop-while even? [2 4 6]) returns empty list when pred always true")
    func dropWhileAlwaysTrue() throws {
        #expect(try swish.eval("(drop-while even? [2 4 6])") == .list([], metadata: nil))
    }

    @Test("(drop-while even? nil) returns empty list")
    func dropWhileOnNil() throws {
        #expect(try swish.eval("(drop-while even? nil)") == .list([], metadata: nil))
    }

    @Test("(drop-while pos? [1 2 -1 3]) drops leading positives")
    func dropWhilePos() throws {
        #expect(try swish.eval("(drop-while pos? [1 2 -1 3])") == .list([.integer(-1), .integer(3)], metadata: nil))
    }

    @Test("(drop-while even? '(2 4 1 3)) works on lists")
    func dropWhileOnList() throws {
        #expect(try swish.eval("(drop-while even? '(2 4 1 3))") == .list([.integer(1), .integer(3)], metadata: nil))
    }

    // MARK: - sequential?

    @Test("(sequential? '(1 2)) returns true for list")
    func sequentialList() throws {
        #expect(try swish.eval("(sequential? '(1 2))") == .boolean(true))
    }

    @Test("(sequential? [1 2]) returns true for vector")
    func sequentialVector() throws {
        #expect(try swish.eval("(sequential? [1 2])") == .boolean(true))
    }

    @Test("(sequential? {:a 1}) returns false for map")
    func sequentialMap() throws {
        #expect(try swish.eval("(sequential? {:a 1})") == .boolean(false))
    }

    @Test("(sequential? nil) returns false")
    func sequentialNil() throws {
        #expect(try swish.eval("(sequential? nil)") == .boolean(false))
    }

    // MARK: - flatten

    @Test("(flatten '(1 2 3)) returns flat list unchanged")
    func flattenFlat() throws {
        #expect(try swish.eval("(flatten '(1 2 3))") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(flatten '(1 (2 3) 4)) flattens one level")
    func flattenOneLevel() throws {
        #expect(try swish.eval("(flatten '(1 (2 3) 4))") == .list([.integer(1), .integer(2), .integer(3), .integer(4)], metadata: nil))
    }

    @Test("(flatten '(1 (2 (3 4)) 5)) flattens deeply nested")
    func flattenDeep() throws {
        #expect(try swish.eval("(flatten '(1 (2 (3 4)) 5))") == .list([.integer(1), .integer(2), .integer(3), .integer(4), .integer(5)], metadata: nil))
    }

    @Test("(flatten [[1 2] [3 4]]) flattens vectors")
    func flattenVectors() throws {
        #expect(try swish.eval("(flatten [[1 2] [3 4]])") == .list([.integer(1), .integer(2), .integer(3), .integer(4)], metadata: nil))
    }

    @Test("(flatten nil) returns empty list")
    func flattenNil() throws {
        #expect(try swish.eval("(flatten nil)") == .list([], metadata: nil))
    }

    @Test("(flatten '()) returns empty list")
    func flattenEmpty() throws {
        #expect(try swish.eval("(flatten '())") == .list([], metadata: nil))
    }

    // MARK: - partition

    @Test("(partition 2 [1 2 3 4]) returns non-overlapping pairs")
    func partitionBasic() throws {
        let expected = Expr.list([
            .list([.integer(1), .integer(2)], metadata: nil),
            .list([.integer(3), .integer(4)], metadata: nil)
        ], metadata: nil)
        #expect(try swish.eval("(partition 2 [1 2 3 4])") == expected)
    }

    @Test("(partition 2 [1 2 3]) drops incomplete last chunk")
    func partitionDropsIncomplete() throws {
        let expected = Expr.list([
            .list([.integer(1), .integer(2)], metadata: nil)
        ], metadata: nil)
        #expect(try swish.eval("(partition 2 [1 2 3])") == expected)
    }

    @Test("(partition 2 1 [1 2 3]) returns overlapping partitions")
    func partitionWithStep() throws {
        let expected = Expr.list([
            .list([.integer(1), .integer(2)], metadata: nil),
            .list([.integer(2), .integer(3)], metadata: nil)
        ], metadata: nil)
        #expect(try swish.eval("(partition 2 1 [1 2 3])") == expected)
    }

    @Test("(partition 3 3 [0 0] [1 2 3 4]) pads last chunk")
    func partitionWithPad() throws {
        let expected = Expr.list([
            .list([.integer(1), .integer(2), .integer(3)], metadata: nil),
            .list([.integer(4), .integer(0), .integer(0)], metadata: nil)
        ], metadata: nil)
        #expect(try swish.eval("(partition 3 3 [0 0] [1 2 3 4])") == expected)
    }

    @Test("(partition 2 []) returns empty list")
    func partitionEmpty() throws {
        #expect(try swish.eval("(partition 2 [])") == .list([], metadata: nil))
    }

    @Test("(partition 2 nil) returns empty list")
    func partitionNil() throws {
        #expect(try swish.eval("(partition 2 nil)") == .list([], metadata: nil))
    }

    // MARK: - partition-all

    @Test("(partition-all 2 [1 2 3 4]) returns even partitions")
    func partitionAllEven() throws {
        let expected = Expr.list([
            .list([.integer(1), .integer(2)], metadata: nil),
            .list([.integer(3), .integer(4)], metadata: nil)
        ], metadata: nil)
        #expect(try swish.eval("(partition-all 2 [1 2 3 4])") == expected)
    }

    @Test("(partition-all 2 [1 2 3]) keeps incomplete last chunk")
    func partitionAllKeepsIncomplete() throws {
        let expected = Expr.list([
            .list([.integer(1), .integer(2)], metadata: nil),
            .list([.integer(3)], metadata: nil)
        ], metadata: nil)
        #expect(try swish.eval("(partition-all 2 [1 2 3])") == expected)
    }

    @Test("(partition-all 2 1 [1 2 3]) returns overlapping partitions including tail")
    func partitionAllWithStep() throws {
        let expected = Expr.list([
            .list([.integer(1), .integer(2)], metadata: nil),
            .list([.integer(2), .integer(3)], metadata: nil),
            .list([.integer(3)], metadata: nil)
        ], metadata: nil)
        #expect(try swish.eval("(partition-all 2 1 [1 2 3])") == expected)
    }

    @Test("(partition-all 2 []) returns empty list")
    func partitionAllEmpty() throws {
        #expect(try swish.eval("(partition-all 2 [])") == .list([], metadata: nil))
    }

    @Test("(partition-all 2 nil) returns empty list")
    func partitionAllNil() throws {
        #expect(try swish.eval("(partition-all 2 nil)") == .list([], metadata: nil))
    }

    // MARK: - group-by

    @Test("(group-by even? [1 2 3 4]) groups by predicate")
    func groupByEven() throws {
        let expected = Expr.map([
            .boolean(false): .vector([.integer(1), .integer(3)], metadata: nil),
            .boolean(true): .vector([.integer(2), .integer(4)], metadata: nil)
        ], metadata: nil)
        #expect(try swish.eval("(group-by even? [1 2 3 4])") == expected)
    }

    @Test("(group-by count [\"a\" \"bb\" \"cc\"]) groups by string length")
    func groupByCount() throws {
        let expected = Expr.map([
            .integer(1): .vector([.string("a")], metadata: nil),
            .integer(2): .vector([.string("bb"), .string("cc")], metadata: nil)
        ], metadata: nil)
        #expect(try swish.eval("(group-by count [\"a\" \"bb\" \"cc\"])") == expected)
    }

    @Test("(group-by identity [:a :b :a]) groups duplicate keys into same vector")
    func groupByIdentity() throws {
        let expected = Expr.map([
            .keyword("a"): .vector([.keyword("a"), .keyword("a")], metadata: nil),
            .keyword("b"): .vector([.keyword("b")], metadata: nil)
        ], metadata: nil)
        #expect(try swish.eval("(group-by identity [:a :b :a])") == expected)
    }

    @Test("(group-by even? []) returns empty map")
    func groupByEmpty() throws {
        #expect(try swish.eval("(group-by even? [])") == .map([:], metadata: nil))
    }

    @Test("(group-by even? nil) returns empty map")
    func groupByNil() throws {
        #expect(try swish.eval("(group-by even? nil)") == .map([:], metadata: nil))
    }

    // MARK: - frequencies

    @Test("(frequencies [1 2 2 3 3 3]) counts occurrences")
    func frequenciesBasic() throws {
        let expected = Expr.map([
            .integer(1): .integer(1),
            .integer(2): .integer(2),
            .integer(3): .integer(3)
        ], metadata: nil)
        #expect(try swish.eval("(frequencies [1 2 2 3 3 3])") == expected)
    }

    @Test("(frequencies [:a :b :a]) counts keywords")
    func frequenciesKeywords() throws {
        let expected = Expr.map([
            .keyword("a"): .integer(2),
            .keyword("b"): .integer(1)
        ], metadata: nil)
        #expect(try swish.eval("(frequencies [:a :b :a])") == expected)
    }

    @Test("(frequencies []) returns empty map")
    func frequenciesEmpty() throws {
        #expect(try swish.eval("(frequencies [])") == .map([:], metadata: nil))
    }

    @Test("(frequencies nil) returns empty map")
    func frequenciesNil() throws {
        #expect(try swish.eval("(frequencies nil)") == .map([:], metadata: nil))
    }

    // MARK: - second

    @Test("(second [1 2 3]) returns 2")
    func secondOfVector() throws {
        #expect(try swish.eval("(second [1 2 3])") == .integer(2))
    }

    @Test("(second '(10 20)) returns 20")
    func secondOfList() throws {
        #expect(try swish.eval("(second '(10 20))") == .integer(20))
    }

    @Test("(second '(1)) returns nil")
    func secondOfSingleton() throws {
        #expect(try swish.eval("(second '(1))") == .nil)
    }

    @Test("(second nil) returns nil")
    func secondOfNil() throws {
        #expect(try swish.eval("(second nil)") == .nil)
    }

    // MARK: - nnext

    @Test("(nnext [1 2 3]) returns (3)")
    func nnextThreeElems() throws {
        #expect(try swish.eval("(nnext [1 2 3])") == .list([.integer(3)], metadata: nil))
    }

    @Test("(nnext [1 2]) returns nil")
    func nnextTwoElems() throws {
        #expect(try swish.eval("(nnext [1 2])") == .nil)
    }

    @Test("(nnext [1]) returns nil")
    func nnextOneElem() throws {
        #expect(try swish.eval("(nnext [1])") == .nil)
    }

    // MARK: - empty?

    @Test("(empty? []) returns true")
    func emptyVector() throws {
        #expect(try swish.eval("(empty? [])") == .boolean(true))
    }

    @Test("(empty? [1]) returns false")
    func emptyNonEmptyVector() throws {
        #expect(try swish.eval("(empty? [1])") == .boolean(false))
    }

    @Test("(empty? nil) returns true")
    func emptyNil() throws {
        #expect(try swish.eval("(empty? nil)") == .boolean(true))
    }

    @Test("(empty? '()) returns true")
    func emptyList() throws {
        #expect(try swish.eval("(empty? '())") == .boolean(true))
    }

    // MARK: - not-empty

    @Test("(not-empty [1 2]) returns [1 2]")
    func notEmptyVector() throws {
        #expect(try swish.eval("(not-empty [1 2])") == .vector([.integer(1), .integer(2)], metadata: nil))
    }

    @Test("(not-empty []) returns nil")
    func notEmptyEmptyVector() throws {
        #expect(try swish.eval("(not-empty [])") == .nil)
    }

    @Test("(not-empty nil) returns nil")
    func notEmptyNil() throws {
        #expect(try swish.eval("(not-empty nil)") == .nil)
    }

    @Test("(to-array [1 2 3]) returns a vector")
    func toArrayReturnsVector() throws {
        #expect(try swish.eval("(to-array [1 2 3])") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(get (to-array [1 2]) 0) returns first element")
    func toArrayGetFirst() throws {
        #expect(try swish.eval("(get (to-array [1 2]) 0)") == .integer(1))
    }

    @Test("(get (to-array [1 2]) 10) returns nil for out-of-bounds")
    func toArrayGetOutOfBounds() throws {
        #expect(try swish.eval("(get (to-array [1 2]) 10)") == .nil)
    }

    @Test("(object-array 3) is not a list")
    func objectArrayNotList() throws {
        #expect(try swish.eval("(list? (object-array 3))") == .boolean(false))
    }

    @Test("(array-map :a 1) is not a list")
    func arrayMapNotList() throws {
        #expect(try swish.eval("(list? (array-map :a 1))") == .boolean(false))
    }

    // MARK: - conj

    @Test("(conj) returns empty vector")
    func conjNoArgs() throws {
        #expect(try swish.eval("(conj)") == .vector([], metadata: nil))
    }

    @Test("(conj [1 2] 3) appends to vector")
    func conjVectorAppend() throws {
        #expect(try swish.eval("(conj [1 2] 3)") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }
}
