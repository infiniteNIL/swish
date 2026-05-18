import Testing
@testable import SwishKit

@Suite("Core Set Tests")
struct CoreSetTests {
    let swish = Swish()

    @Test("set? returns true for a non-empty set")
    func setPredicateNonEmpty() throws {
        #expect(try swish.eval("(set? #{1 2 3})") == .boolean(true))
    }

    @Test("set? returns true for an empty set")
    func setPredicateEmpty() throws {
        #expect(try swish.eval("(set? #{})") == .boolean(true))
    }

    @Test("set? returns false for a vector")
    func setPredicateVector() throws {
        #expect(try swish.eval("(set? [1 2 3])") == .boolean(false))
    }

    @Test("set? returns false for a map")
    func setPredicateMap() throws {
        #expect(try swish.eval("(set? {:a 1})") == .boolean(false))
    }

    @Test("set? returns false for nil")
    func setPredicateNil() throws {
        #expect(try swish.eval("(set? nil)") == .boolean(false))
    }

    @Test("set? returns false for an integer")
    func setPredicateInteger() throws {
        #expect(try swish.eval("(set? 42)") == .boolean(false))
    }

    @Test("set? returns false for a string")
    func setPredicateString() throws {
        #expect(try swish.eval("(set? \"hello\")") == .boolean(false))
    }

    @Test("set? returns false for a list")
    func setPredicateList() throws {
        #expect(try swish.eval("(set? '(1 2 3))") == .boolean(false))
    }
}
