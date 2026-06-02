import Testing
@testable import SwishKit

@Suite("Core Interpose Tests", .serialized)
struct CoreInterposeTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("(interpose \", \" [\"a\" \"b\" \"c\"]) inserts separator between strings")
    func interposeStrings() throws {
        #expect(try swish.eval("(interpose \", \" [\"a\" \"b\" \"c\"])") == .list([.string("a"), .string(", "), .string("b"), .string(", "), .string("c")], metadata: nil))
    }

    @Test("(interpose 0 [1 2 3]) inserts separator between ints")
    func interposeInts() throws {
        #expect(try swish.eval("(interpose 0 [1 2 3])") == .list([.integer(1), .integer(0), .integer(2), .integer(0), .integer(3)], metadata: nil))
    }

    @Test("(interpose :sep [:a :b]) inserts separator between two elements")
    func interposeTwoElements() throws {
        #expect(try swish.eval("(interpose :sep [:a :b])") == .list([.keyword("a"), .keyword("sep"), .keyword("b")], metadata: nil))
    }

    @Test("(interpose :sep [:a]) returns single-element list")
    func interposeSingleElement() throws {
        #expect(try swish.eval("(interpose :sep [:a])") == .list([.keyword("a")], metadata: nil))
    }

    @Test("(interpose :sep []) returns empty list")
    func interposeEmpty() throws {
        #expect(try swish.eval("(interpose :sep [])") == .list([], metadata: nil))
    }

    @Test("(interpose :sep nil) returns empty list")
    func interposeNil() throws {
        #expect(try swish.eval("(interpose :sep nil)") == .list([], metadata: nil))
    }
}
