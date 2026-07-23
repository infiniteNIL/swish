import Testing
@testable import SwishKit

@Suite("Core Sequence Partition Tests", .serialized)
struct CoreSequencePartitionTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

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

}
