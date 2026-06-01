import Testing
@testable import SwishKit

@Suite("Core Sort Tests")
struct CoreSortTests {
    let swish = Swish()

    // MARK: - compare

    @Test("(compare 1 2) returns -1")
    func compareLess() throws {
        #expect(try swish.eval("(compare 1 2)") == .integer(-1))
    }

    @Test("(compare 2 1) returns 1")
    func compareGreater() throws {
        #expect(try swish.eval("(compare 2 1)") == .integer(1))
    }

    @Test("(compare 1 1) returns 0")
    func compareEqual() throws {
        #expect(try swish.eval("(compare 1 1)") == .integer(0))
    }

    @Test("(compare nil nil) returns 0")
    func compareNilNil() throws {
        #expect(try swish.eval("(compare nil nil)") == .integer(0))
    }

    @Test("(compare nil 1) returns -1")
    func compareNilLess() throws {
        #expect(try swish.eval("(compare nil 1)") == .integer(-1))
    }

    @Test("(compare 1 nil) returns 1")
    func compareNilGreater() throws {
        #expect(try swish.eval("(compare 1 nil)") == .integer(1))
    }

    @Test("(compare \"a\" \"b\") returns -1")
    func compareStrings() throws {
        #expect(try swish.eval("(compare \"a\" \"b\")") == .integer(-1))
    }

    @Test("(compare :a :b) returns -1")
    func compareKeywords() throws {
        #expect(try swish.eval("(compare :a :b)") == .integer(-1))
    }

    // MARK: - sort

    @Test("(sort [3 1 2]) returns sorted list")
    func sortInts() throws {
        #expect(try swish.eval("(sort [3 1 2])") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(sort []) returns empty list")
    func sortEmpty() throws {
        #expect(try swish.eval("(sort [])") == .list([], metadata: nil))
    }

    @Test("(sort nil) returns empty list")
    func sortNil() throws {
        #expect(try swish.eval("(sort nil)") == .list([], metadata: nil))
    }

    @Test("(sort > [3 1 2]) sorts descending")
    func sortDescending() throws {
        #expect(try swish.eval("(sort > [3 1 2])") == .list([.integer(3), .integer(2), .integer(1)], metadata: nil))
    }

    @Test("(sort [\"banana\" \"apple\" \"cherry\"]) sorts strings")
    func sortStrings() throws {
        #expect(try swish.eval("(sort [\"banana\" \"apple\" \"cherry\"])") == .list(
            [.string("apple"), .string("banana"), .string("cherry")], metadata: nil))
    }

    // MARK: - sort-by

    @Test("(sort-by count [\"bb\" \"a\" \"ccc\"]) sorts by length")
    func sortByCount() throws {
        #expect(try swish.eval("(sort-by count [\"bb\" \"a\" \"ccc\"])") == .list(
            [.string("a"), .string("bb"), .string("ccc")], metadata: nil))
    }

    @Test("(sort-by count > [\"bb\" \"a\" \"ccc\"]) sorts by length descending")
    func sortByCountDesc() throws {
        #expect(try swish.eval("(sort-by count > [\"bb\" \"a\" \"ccc\"])") == .list(
            [.string("ccc"), .string("bb"), .string("a")], metadata: nil))
    }

    @Test("(sort-by first [[3 :c] [1 :a] [2 :b]]) sorts by first element")
    func sortByFirst() throws {
        #expect(try swish.eval("(sort-by first [[3 :c] [1 :a] [2 :b]])") == .list([
            .vector([.integer(1), .keyword("a")], metadata: nil),
            .vector([.integer(2), .keyword("b")], metadata: nil),
            .vector([.integer(3), .keyword("c")], metadata: nil)
        ], metadata: nil))
    }

    @Test("(sort-by (fn [x] x) [3 1 2]) sorts by identity")
    func sortByIdentity() throws {
        #expect(try swish.eval("(sort-by (fn [x] x) [3 1 2])") == .list(
            [.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(sort-by #(%1) [1 2 3 4]) errors naming the first element")
    func sortByAnonFnErrors() throws {
        let error = #expect(throws: EvaluatorError.self) {
            try swish.eval("(sort-by #(%1) [1 2 3 4])")
        }
        #expect(error?.description.contains("'1'") == true)
    }
}
