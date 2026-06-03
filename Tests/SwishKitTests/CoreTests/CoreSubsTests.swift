import Testing
@testable import SwishKit

@Suite("subs Tests")
struct CoreSubsTests {
    let swish = Swish()

    @Test("subs 2-arity returns suffix from start")
    func subsFromStart() throws {
        #expect(try swish.eval(#"(subs "hello" 2)"#) == .string("llo"))
    }

    @Test("subs 2-arity with start 0 returns full string")
    func subsFromZero() throws {
        #expect(try swish.eval(#"(subs "hello" 0)"#) == .string("hello"))
    }

    @Test("subs 3-arity returns substring")
    func subsRange() throws {
        #expect(try swish.eval(#"(subs "hello" 1 3)"#) == .string("el"))
    }

    @Test("subs 3-arity with equal start and end returns empty string")
    func subsEmptyRange() throws {
        #expect(try swish.eval(#"(subs "hello" 2 2)"#) == .string(""))
    }

    @Test("subs 3-arity full range returns full string")
    func subsFullRange() throws {
        #expect(try swish.eval(#"(subs "hello" 0 5)"#) == .string("hello"))
    }

    @Test("subs on empty string with 0 0 returns empty string")
    func subsEmptyString() throws {
        #expect(try swish.eval(#"(subs "" 0)"#) == .string(""))
    }

    @Test("subs throws on negative start")
    func subsNegativeStart() throws {
        #expect(throws: (any Error).self) {
            try swish.eval(#"(subs "hello" -1)"#)
        }
    }

    @Test("subs throws when end exceeds length")
    func subsEndPastLength() throws {
        #expect(throws: (any Error).self) {
            try swish.eval(#"(subs "hello" 0 6)"#)
        }
    }

    @Test("subs throws when start exceeds end")
    func subsStartExceedsEnd() throws {
        #expect(throws: (any Error).self) {
            try swish.eval(#"(subs "hello" 3 1)"#)
        }
    }
}
