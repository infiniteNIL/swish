import Testing
@testable import SwishKit

@Suite("set function Tests")
struct CoreSetFnTests {
    let swish = Swish()

    @Test("set converts a vector to a set, removing duplicates")
    func setFromVector() throws {
        #expect(try swish.eval("(set [1 2 2 3])") == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("set converts a list to a set")
    func setFromList() throws {
        #expect(try swish.eval("(set '(1 2 3))") == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("set of nil returns empty set")
    func setFromNil() throws {
        #expect(try swish.eval("(set nil)") == .set([], metadata: nil))
    }

    @Test("set of empty vector returns empty set")
    func setFromEmpty() throws {
        #expect(try swish.eval("(set [])") == .set([], metadata: nil))
    }

    @Test("set of a map returns a set of key-value pairs")
    func setFromMap() throws {
        let result = try swish.eval("(set {:a 1})")
        #expect(result == .set([.vector([.keyword("a"), .integer(1)], metadata: nil)], metadata: nil))
    }

    @Test("set of a string returns a set of characters")
    func setFromString() throws {
        let result = try swish.eval(#"(set "ab")"#)
        #expect(result == .set([.character("a"), .character("b")], metadata: nil))
    }

    @Test("set of a set is idempotent")
    func setFromSet() throws {
        #expect(try swish.eval("(set #{1 2 3})") == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("disj removes one element from a set")
    func disjOneElement() throws {
        #expect(try swish.eval("(disj #{1 2 3} 2)") == .set([.integer(1), .integer(3)], metadata: nil))
    }

    @Test("disj removes multiple elements from a set")
    func disjMultipleElements() throws {
        #expect(try swish.eval("(disj #{1 2 3} 1 3)") == .set([.integer(2)], metadata: nil))
    }

    @Test("disj with non-existent element returns the original set")
    func disjNonExistent() throws {
        #expect(try swish.eval("(disj #{1 2 3} 99)") == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("disj with one arg returns the set unchanged")
    func disjOneArg() throws {
        #expect(try swish.eval("(disj #{1 2 3})") == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }
}
