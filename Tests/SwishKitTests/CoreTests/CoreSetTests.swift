import Testing
@testable import SwishKit

@Suite("Core Set Tests", .serialized)
struct CoreSetTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

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

    // MARK: - conj on sets

    @Test("conj adds a new element to a set")
    func conjAddsToSet() throws {
        #expect(try swish.eval("(conj #{1 2} 3)") == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("conj with an existing element leaves the set unchanged")
    func conjExistingElementNoDuplicates() throws {
        #expect(try swish.eval("(conj #{1 2} 2)") == .set([.integer(1), .integer(2)], metadata: nil))
    }

    // MARK: - contains? on sets

    @Test("contains? returns true for a member of the set")
    func containsMember() throws {
        #expect(try swish.eval("(contains? #{1 2 3} 2)") == .boolean(true))
    }

    @Test("contains? returns false for a non-member")
    func containsNonMember() throws {
        #expect(try swish.eval("(contains? #{1 2 3} 99)") == .boolean(false))
    }

    // MARK: - get on sets

    @Test("get on a set returns the element when it exists")
    func getSetMember() throws {
        #expect(try swish.eval("(get #{1 2 3} 2)") == .integer(2))
    }

    @Test("get on a set returns nil when element is absent")
    func getSetNonMember() throws {
        #expect(try swish.eval("(get #{1 2 3} 99)") == .nil)
    }

    @Test("get on a set returns the default when element is absent")
    func getSetNonMemberWithDefault() throws {
        #expect(try swish.eval("(get #{1 2 3} 99 :miss)") == .keyword("miss"))
    }
}
