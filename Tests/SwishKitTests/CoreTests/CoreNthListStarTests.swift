import Testing
@testable import SwishKit

@Suite("Core nth and list* Tests")
struct CoreNthListStarTests {
    let swish = Swish()

    // MARK: - nth

    @Test("(nth [1 2 3] 0) returns first element")
    func nthFirstElement() throws {
        #expect(try swish.eval("(nth [1 2 3] 0)") == .integer(1))
    }

    @Test("(nth [1 2 3] 2) returns last element")
    func nthLastElement() throws {
        #expect(try swish.eval("(nth [1 2 3] 2)") == .integer(3))
    }

    @Test("(nth [1 2 3] 5) returns nil when out of bounds")
    func nthOutOfBoundsReturnsNil() throws {
        #expect(try swish.eval("(nth [1 2 3] 5)") == .nil)
    }

    @Test("(nth [1 2 3] 5 :missing) returns default when out of bounds")
    func nthOutOfBoundsWithDefault() throws {
        #expect(try swish.eval("(nth [1 2 3] 5 :missing)") == .keyword("missing"))
    }

    @Test("(nth '(a b c) 1) works on lists")
    func nthOnList() throws {
        #expect(try swish.eval("(nth '(1 2 3) 1)") == .integer(2))
    }

    @Test("(nth nil 0) returns nil")
    func nthOnNilReturnsNil() throws {
        #expect(try swish.eval("(nth nil 0)") == .nil)
    }

    @Test("(nth coll) with no index throws arity error")
    func nthNoIndexThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "nth",
                                                       message: "requires at least 2 arguments")) {
            try swish.eval("(nth [1 2 3])")
        }
    }

    @Test("(nth coll non-integer) throws type error")
    func nthNonIntegerIndexThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "nth",
                                                       message: "index must be an integer")) {
            try swish.eval("(nth [1 2 3] \"a\")")
        }
    }

    // MARK: - list*

    @Test("(list* '(1 2 3)) with just a tail returns the tail as a list")
    func listStarTailOnly() throws {
        #expect(try swish.eval("(list* '(1 2 3))") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(list* 1 '(2 3)) prepends to tail")
    func listStarPrependOne() throws {
        #expect(try swish.eval("(list* 1 '(2 3))") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(list* 1 2 '(3 4)) prepends multiple elements")
    func listStarPrependMultiple() throws {
        #expect(try swish.eval("(list* 1 2 '(3 4))") == .list([.integer(1), .integer(2), .integer(3), .integer(4)], metadata: nil))
    }

    @Test("(list* 1 nil) treats nil tail as empty")
    func listStarNilTail() throws {
        #expect(try swish.eval("(list* 1 nil)") == .list([.integer(1)], metadata: nil))
    }

    @Test("(list* 1 [2 3]) accepts vector tail")
    func listStarVectorTail() throws {
        #expect(try swish.eval("(list* 1 [2 3])") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }
}
