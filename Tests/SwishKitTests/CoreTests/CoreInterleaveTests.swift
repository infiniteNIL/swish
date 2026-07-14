import Testing
@testable import SwishKit

@Suite("Core Interleave Tests", .serialized)
struct CoreInterleaveTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("(interleave) returns empty list")
    func interleaveNoArgs() throws {
        #expect(try swish.eval("(interleave)") == .list([], metadata: nil))
    }

    @Test("(interleave [1 2 3]) returns seq of single coll")
    func interleaveOneArg() throws {
        #expect(try swish.eval("(interleave [1 2 3])") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(interleave [1 2] [:a :b]) interleaves two equal-length colls")
    func interleaveTwoEqual() throws {
        #expect(try swish.eval("(interleave [1 2] [:a :b])") == .list([.integer(1), .keyword("a"), .integer(2), .keyword("b")], metadata: nil))
    }

    @Test("(interleave [1 2 3] [:a :b]) stops at shortest")
    func interleaveTwoUnequal() throws {
        #expect(try swish.eval("(interleave [1 2 3] [:a :b])") == .list([.integer(1), .keyword("a"), .integer(2), .keyword("b")], metadata: nil))
    }

    @Test("(interleave [1 2] [:a :b] [\"x\" \"y\"]) interleaves three colls")
    func interleaveThree() throws {
        #expect(try swish.eval("(interleave [1 2] [:a :b] [\"x\" \"y\"])") == .list([.integer(1), .keyword("a"), .string("x"), .integer(2), .keyword("b"), .string("y")], metadata: nil))
    }

    @Test("(interleave [] [1 2]) returns empty list when first coll empty")
    func interleaveFirstEmpty() throws {
        #expect(try swish.eval("(interleave [] [1 2])") == .list([], metadata: nil))
    }

    @Test("(interleave [1 2] []) returns empty list when second coll empty")
    func interleaveSecondEmpty() throws {
        #expect(try swish.eval("(interleave [1 2] [])") == .list([], metadata: nil))
    }

    @Test("(interleave nil [1 2]) returns empty list for nil input")
    func interleaveNil() throws {
        #expect(try swish.eval("(interleave nil [1 2])") == .list([], metadata: nil))
    }
}
