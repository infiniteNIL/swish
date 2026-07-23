import Testing
@testable import SwishKit

@Suite("Core Cons And Equality Tests", .serialized)
struct CoreConsAndEqualityTests {
    static let _shared = Swish()
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

    @Test("(cons 1 {:2 2 :3 3}) yields entries in sorted key order")
    func consMapSortedOrder() throws {
        #expect(try swish.eval("(= [1 [:2 2] [:3 3]] (cons 1 {:2 2 :3 3}))") == .boolean(true))
    }

    // MARK: - vector / list cross-type equality

    @Test("(= [1 2 3] (cons 1 [2 3])) is true")
    func vectorEqualsConsList() throws {
        #expect(try swish.eval("(= [1 2 3] (cons 1 [2 3]))") == .boolean(true))
    }

    @Test("(= [1 2 3] (cons 1 '(2 3))) is true")
    func vectorEqualsConsFromList() throws {
        #expect(try swish.eval("(= [1 2 3] (cons 1 '(2 3)))") == .boolean(true))
    }

    @Test("(= (cons 1 '(2 3)) [1 2 3]) is true (reversed)")
    func consListEqualsVector() throws {
        #expect(try swish.eval("(= (cons 1 '(2 3)) [1 2 3])") == .boolean(true))
    }

    @Test("(= [1 2] '(1 2)) is true")
    func vectorEqualsListLiteral() throws {
        #expect(try swish.eval("(= [1 2] '(1 2))") == .boolean(true))
    }

    @Test("(= [1 2] '(1 3)) is false")
    func vectorNotEqualsDifferentList() throws {
        #expect(try swish.eval("(= [1 2] '(1 3))") == .boolean(false))
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

}
