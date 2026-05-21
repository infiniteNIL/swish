import Testing
@testable import SwishKit

@Suite("Core Sequence Tests")
struct CoreSequenceTests {
    let swish = Swish()

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

    @Test("(take 0 [1 2 3]) returns nil")
    func takeZeroReturnsNil() throws {
        #expect(try swish.eval("(take 0 [1 2 3])") == .nil)
    }

    @Test("(take 10 [1 2]) returns all when n exceeds length")
    func takeBeyondLength() throws {
        #expect(try swish.eval("(take 10 [1 2])") == .list([.integer(1), .integer(2)], metadata: nil))
    }

    @Test("(take 3 nil) returns nil")
    func takeFromNil() throws {
        #expect(try swish.eval("(take 3 nil)") == .nil)
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

    @Test("(take-while odd? [2 4 6]) returns nil when pred fails immediately")
    func takeWhileFailsImmediately() throws {
        #expect(try swish.eval("(take-while odd? [2 4 6])") == .nil)
    }

    @Test("(take-while even? nil) returns nil")
    func takeWhileOnNil() throws {
        #expect(try swish.eval("(take-while even? nil)") == .nil)
    }

    @Test("(take-while pos? [-1 2 3]) returns nil when first fails")
    func takeWhileFirstFails() throws {
        #expect(try swish.eval("(take-while pos? [-1 2 3])") == .nil)
    }
}
