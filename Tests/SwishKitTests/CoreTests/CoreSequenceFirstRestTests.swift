import Testing
@testable import SwishKit

@Suite("Core first/rest/string? Tests", .serialized)
struct CoreSequenceFirstRestTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

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

    // MARK: - last

    @Test("(last '(1 2 3)) returns 3")
    func lastOnList() throws {
        #expect(try swish.eval("(last '(1 2 3))") == .integer(3))
    }

    @Test("(last [1 2 3]) returns 3")
    func lastOnVector() throws {
        #expect(try swish.eval("(last [1 2 3])") == .integer(3))
    }

    @Test("(last \"hello\") returns \\o")
    func lastOnString() throws {
        #expect(try swish.eval("(last \"hello\")") == .character("o"))
    }

    @Test("(last '()) returns nil")
    func lastOnEmptyList() throws {
        #expect(try swish.eval("(last '())") == .nil)
    }

    @Test("(last []) returns nil")
    func lastOnEmptyVector() throws {
        #expect(try swish.eval("(last [])") == .nil)
    }

    @Test("(last nil) returns nil")
    func lastOnNil() throws {
        #expect(try swish.eval("(last nil)") == .nil)
    }

    // MARK: - butlast

    @Test("(butlast '(1 2 3)) returns (1 2)")
    func butlastOnList() throws {
        #expect(try swish.eval("(butlast '(1 2 3))") == .list([.integer(1), .integer(2)], metadata: nil))
    }

    @Test("(butlast [1 2 3]) returns (1 2)")
    func butlastOnVector() throws {
        #expect(try swish.eval("(butlast [1 2 3])") == .list([.integer(1), .integer(2)], metadata: nil))
    }

    @Test("(butlast '(1)) returns nil")
    func butlastSingleElement() throws {
        #expect(try swish.eval("(butlast '(1))") == .nil)
    }

    @Test("(butlast '()) returns nil")
    func butlastOnEmptyList() throws {
        #expect(try swish.eval("(butlast '())") == .nil)
    }

    @Test("(butlast nil) returns nil")
    func butlastOnNil() throws {
        #expect(try swish.eval("(butlast nil)") == .nil)
    }

    // MARK: - reverse

    @Test("(reverse '(1 2 3)) returns (3 2 1)")
    func reverseOnList() throws {
        #expect(try swish.eval("(reverse '(1 2 3))") == .list([.integer(3), .integer(2), .integer(1)], metadata: nil))
    }

    @Test("(reverse [1 2 3]) returns (3 2 1)")
    func reverseOnVector() throws {
        #expect(try swish.eval("(reverse [1 2 3])") == .list([.integer(3), .integer(2), .integer(1)], metadata: nil))
    }

    @Test("(reverse '(1)) returns (1)")
    func reverseSingleElement() throws {
        #expect(try swish.eval("(reverse '(1))") == .list([.integer(1)], metadata: nil))
    }

    @Test("(reverse '()) returns empty list")
    func reverseOnEmptyList() throws {
        #expect(try swish.eval("(reverse '())") == .list([], metadata: nil))
    }

    @Test("(reverse nil) returns empty list")
    func reverseOnNil() throws {
        #expect(try swish.eval("(reverse nil)") == .list([], metadata: nil))
    }

    @Test("(reverse \\a) throws for char")
    func reverseCharThrows() {
        #expect(throws: (any Error).self) { try swish.eval("(reverse \\a)") }
    }

    @Test("(reverse 0) throws for integer")
    func reverseIntThrows() {
        #expect(throws: (any Error).self) { try swish.eval("(reverse 0)") }
    }

    @Test("(reverse 0.0) throws for float")
    func reverseFloatThrows() {
        #expect(throws: (any Error).self) { try swish.eval("(reverse 0.0)") }
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
}
