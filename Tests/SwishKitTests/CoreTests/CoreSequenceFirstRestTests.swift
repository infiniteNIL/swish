import Testing
@testable import SwishKit

@Suite("Core first/rest/string? Tests")
struct CoreSequenceFirstRestTests {
    let swish = Swish()

    // MARK: - first

    @Test("(first '(1 2 3)) returns 1")
    func firstOnList() throws {
        #expect(try swish.eval("(first '(1 2 3))") == .integer(1))
    }

    @Test("(first [1 2 3]) returns 1")
    func firstOnVector() throws {
        #expect(try swish.eval("(first [1 2 3])") == .integer(1))
    }

    @Test("(first \"hello\") returns \\h")
    func firstOnString() throws {
        #expect(try swish.eval("(first \"hello\")") == .character("h"))
    }

    @Test("(first '()) returns nil")
    func firstOnEmptyList() throws {
        #expect(try swish.eval("(first '())") == .nil)
    }

    @Test("(first []) returns nil")
    func firstOnEmptyVector() throws {
        #expect(try swish.eval("(first [])") == .nil)
    }

    @Test("(first nil) returns nil")
    func firstOnNil() throws {
        #expect(try swish.eval("(first nil)") == .nil)
    }

    // MARK: - rest

    @Test("(rest '(1 2 3)) returns (2 3)")
    func restOnList() throws {
        #expect(try swish.eval("(rest '(1 2 3))") == .list([.integer(2), .integer(3)], metadata: nil))
    }

    @Test("(rest [1 2 3]) returns (2 3)")
    func restOnVector() throws {
        #expect(try swish.eval("(rest [1 2 3])") == .list([.integer(2), .integer(3)], metadata: nil))
    }

    @Test("(rest \"hello\") returns character list")
    func restOnString() throws {
        #expect(try swish.eval("(rest \"hello\")") == .list(
            [.character("e"), .character("l"), .character("l"), .character("o")],
            metadata: nil))
    }

    @Test("(rest '()) returns empty list")
    func restOnEmptyList() throws {
        #expect(try swish.eval("(rest '())") == .list([], metadata: nil))
    }

    @Test("(rest nil) returns empty list")
    func restOnNil() throws {
        #expect(try swish.eval("(rest nil)") == .list([], metadata: nil))
    }

    // MARK: - string?

    @Test("(string? \"foo\") returns true")
    func stringPredicateTrue() throws {
        #expect(try swish.eval("(string? \"foo\")") == .boolean(true))
    }

    @Test("(string? :foo) returns false")
    func stringPredicateFalseKeyword() throws {
        #expect(try swish.eval("(string? :foo)") == .boolean(false))
    }

    @Test("(string? 42) returns false")
    func stringPredicateFalseInteger() throws {
        #expect(try swish.eval("(string? 42)") == .boolean(false))
    }

    @Test("(string? nil) returns false")
    func stringPredicateFalseNil() throws {
        #expect(try swish.eval("(string? nil)") == .boolean(false))
    }

    // MARK: - defn doc string

    @Test("defn with doc string stores :doc in var metadata")
    func defnDocString() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(defn greet \"Says hi\" [name] (str \"hi \" name))")
        let result = try swish2.eval("(meta #'user/greet)")
        #expect(result == .map([.keyword("doc"): .string("Says hi")], metadata: nil))
    }

    @Test("defn without doc string has no :doc in var metadata")
    func defnNoDocString() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(defn greet [name] name)")
        let result = try swish2.eval("(meta #'user/greet)")
        #expect(result == .nil)
    }

    @Test("defn with doc string still works correctly")
    func defnWithDocStringEvaluates() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(defn double \"Doubles x\" [x] (* x 2))")
        #expect(try swish2.eval("(double 21)") == .integer(42))
    }
}
