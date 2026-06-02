import Testing
@testable import SwishKit

@Suite("Core list? Tests", .serialized)
struct CoreListPredicateTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("list? returns true for a non-empty list")
    func listPredicateNonEmpty() throws {
        #expect(try swish.eval("(list? '(1 2 3))") == .boolean(true))
    }

    @Test("list? returns true for an empty list")
    func listPredicateEmpty() throws {
        #expect(try swish.eval("(list? '())") == .boolean(true))
    }

    @Test("list? returns false for a vector")
    func listPredicateVector() throws {
        #expect(try swish.eval("(list? [1 2 3])") == .boolean(false))
    }

    @Test("list? returns false for a set")
    func listPredicateSet() throws {
        #expect(try swish.eval("(list? #{1 2})") == .boolean(false))
    }

    @Test("list? returns false for a map")
    func listPredicateMap() throws {
        #expect(try swish.eval("(list? {:a 1})") == .boolean(false))
    }

    @Test("list? returns false for nil")
    func listPredicateNil() throws {
        #expect(try swish.eval("(list? nil)") == .boolean(false))
    }

    @Test("list? returns false for an integer")
    func listPredicateInteger() throws {
        #expect(try swish.eval("(list? 42)") == .boolean(false))
    }
}
