import Testing
@testable import SwishKit

@Suite("Core vector? Tests")
struct CoreVectorPredicateTests {
    let swish = Swish()

    @Test("vector? returns true for a non-empty vector")
    func vectorPredicateNonEmpty() throws {
        #expect(try swish.eval("(vector? [1 2 3])") == .boolean(true))
    }

    @Test("vector? returns true for an empty vector")
    func vectorPredicateEmpty() throws {
        #expect(try swish.eval("(vector? [])") == .boolean(true))
    }

    @Test("vector? returns false for a list")
    func vectorPredicateList() throws {
        #expect(try swish.eval("(vector? '(1 2 3))") == .boolean(false))
    }

    @Test("vector? returns false for a set")
    func vectorPredicateSet() throws {
        #expect(try swish.eval("(vector? #{1 2})") == .boolean(false))
    }

    @Test("vector? returns false for a map")
    func vectorPredicateMap() throws {
        #expect(try swish.eval("(vector? {:a 1})") == .boolean(false))
    }

    @Test("vector? returns false for nil")
    func vectorPredicateNil() throws {
        #expect(try swish.eval("(vector? nil)") == .boolean(false))
    }

    @Test("vector? returns false for an integer")
    func vectorPredicateInteger() throws {
        #expect(try swish.eval("(vector? 42)") == .boolean(false))
    }
}
