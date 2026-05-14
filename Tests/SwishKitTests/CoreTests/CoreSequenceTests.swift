import Testing
@testable import SwishKit

@Suite("Core Sequence Tests")
struct CoreSequenceTests {
    let swish = Swish()

    @Test("(list) returns empty list")
    func listNoArgs() throws {
        #expect(try swish.eval("(list)") == .list([]))
    }

    @Test("(list 1) returns single-element list")
    func listOneArg() throws {
        #expect(try swish.eval("(list 1)") == .list([.integer(1)]))
    }

    @Test("(list 1 2 3) returns list of ints")
    func listInts() throws {
        #expect(try swish.eval("(list 1 2 3)") == .list([.integer(1), .integer(2), .integer(3)]))
    }

    @Test("(list \"a\" :b) returns mixed list")
    func listMixed() throws {
        #expect(try swish.eval("(list \"a\" :b)") == .list([.string("a"), .keyword("b")]))
    }
}
