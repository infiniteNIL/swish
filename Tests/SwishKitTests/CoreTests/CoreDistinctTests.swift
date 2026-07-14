import Testing
@testable import SwishKit

@Suite("Core Distinct Tests", .serialized)
struct CoreDistinctTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("(distinct [1 2 3]) returns unchanged when no duplicates")
    func distinctNoDuplicates() throws {
        #expect(try swish.eval("(distinct [1 2 3])") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(distinct [1 2 1 3 2]) removes duplicates preserving order")
    func distinctRemovesDuplicates() throws {
        #expect(try swish.eval("(distinct [1 2 1 3 2])") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(distinct []) returns empty list")
    func distinctEmpty() throws {
        #expect(try swish.eval("(distinct [])") == .list([], metadata: nil))
    }

    @Test("(distinct nil) returns empty list")
    func distinctNil() throws {
        #expect(try swish.eval("(distinct nil)") == .list([], metadata: nil))
    }

    @Test("(distinct [:a :b :a :c]) works on keywords")
    func distinctKeywords() throws {
        #expect(try swish.eval("(distinct [:a :b :a :c])") == .list([.keyword("a"), .keyword("b"), .keyword("c")], metadata: nil))
    }

    @Test("(distinct '(1 1 1)) returns single element")
    func distinctAllSame() throws {
        #expect(try swish.eval("(distinct '(1 1 1))") == .list([.integer(1)], metadata: nil))
    }
}
