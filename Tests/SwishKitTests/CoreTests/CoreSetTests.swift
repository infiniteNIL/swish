import Testing
@testable import SwishKit

@Suite("Core Set Tests", .serialized)
struct CoreSetTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - set?

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

    // MARK: - set constructor

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

    // MARK: - disj

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

    // MARK: - conj

    @Test("conj adds a new element to a set")
    func conjAddsToSet() throws {
        #expect(try swish.eval("(conj #{1 2} 3)") == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("conj with an existing element leaves the set unchanged")
    func conjExistingElementNoDuplicates() throws {
        #expect(try swish.eval("(conj #{1 2} 2)") == .set([.integer(1), .integer(2)], metadata: nil))
    }

    // MARK: - contains?

    @Test("contains? returns true for a member of the set")
    func containsMember() throws {
        #expect(try swish.eval("(contains? #{1 2 3} 2)") == .boolean(true))
    }

    @Test("contains? returns false for a non-member")
    func containsNonMember() throws {
        #expect(try swish.eval("(contains? #{1 2 3} 99)") == .boolean(false))
    }

    @Test("(contains? \"abc\" 0) returns true (index in range)")
    func containsStringIntKeyInRange() throws {
        #expect(try swish.eval("(contains? \"abc\" 0)") == .boolean(true))
    }

    @Test("(contains? \"abc\" 3) returns false (index out of range)")
    func containsStringIntKeyOutOfRange() throws {
        #expect(try swish.eval("(contains? \"abc\" 3)") == .boolean(false))
    }

    @Test("(contains? \"abc\" \"a\") throws for non-integer key on string")
    func containsStringNonIntKeyThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(contains? \"abc\" \"a\")")
        }
    }

    // MARK: - get

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
