import Testing
@testable import SwishKit

@Suite("Core Sequence Tests")
struct CoreSequenceTests {
    let swish = Swish()

    @Test("(list) returns empty list")
    func listNoArgs() throws {
        #expect(try swish.eval("(list)") == .list([]))
    }

    @Test("(list 1) returns single-element list")
    func listOneArg() throws {
        #expect(try swish.eval("(list 1)") == .list([.integer(1)]))
    }

    @Test("(list 1 2 3) returns list of ints")
    func listInts() throws {
        #expect(try swish.eval("(list 1 2 3)") == .list([.integer(1), .integer(2), .integer(3)]))
    }

    @Test("(list \"a\" :b) returns mixed list")
    func listMixed() throws {
        #expect(try swish.eval("(list \"a\" :b)") == .list([.string("a"), .keyword("b")]))
    }

    // MARK: - cons

    @Test("(cons 1 '(2 3)) prepends to list")
    func consOntoList() throws {
        #expect(try swish.eval("(cons 1 '(2 3))") == .list([.integer(1), .integer(2), .integer(3)]))
    }

    @Test("(cons 1 [2 3]) prepends to vector, returns list")
    func consOntoVector() throws {
        #expect(try swish.eval("(cons 1 [2 3])") == .list([.integer(1), .integer(2), .integer(3)]))
    }

    @Test("(cons 1 nil) returns single-element list")
    func consOntoNil() throws {
        #expect(try swish.eval("(cons 1 nil)") == .list([.integer(1)]))
    }

    @Test("(cons \\a \"bc\") prepends char onto string as char seq")
    func consOntoString() throws {
        #expect(try swish.eval("(cons \\a \"bc\")") == .list([.character("a"), .character("b"), .character("c")]))
    }

    @Test("(cons 0 '()) returns single-element list from empty list")
    func consOntoEmptyList() throws {
        #expect(try swish.eval("(cons 0 '())") == .list([.integer(0)]))
    }

    @Test("(cons 1 2) throws invalidArgument")
    func consOntoNonCollectionThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "cons", message: "cannot cons onto 2")) {
            try swish.eval("(cons 1 2)")
        }
    }
}
