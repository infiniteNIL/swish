import Testing
@testable import SwishKit

@Suite("Core nthnext/nthrest Tests", .serialized)
struct CoreNthNextRestTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - nthnext

    @Test("nthnext with positive n on a range and a vector")
    func nthnextPositive() throws {
        #expect(try swish.eval("(nthnext (range 0 10) 3)") == .list([3, 4, 5, 6, 7, 8, 9].map { .integer($0) }, metadata: nil))
        #expect(try swish.eval("(nthnext [0 1 2 3 4 5] 3)") == .list([3, 4, 5].map { .integer($0) }, metadata: nil))
    }

    @Test("nthnext with n = 0 returns (seq coll)")
    func nthnextZero() throws {
        #expect(try swish.eval("(= (nthnext (range 0 10) 0) (range 0 10))") == .boolean(true))
    }

    @Test("nthnext exactly exhausting the collection returns the last element")
    func nthnextExact() throws {
        #expect(try swish.eval("(nthnext (range 0 10) 9)") == .list([.integer(9)], metadata: nil))
    }

    @Test("nthnext with n exceeding the collection's length returns nil")
    func nthnextExceeds() throws {
        #expect(try swish.eval("(nthnext (range 0 10) 10)") == .nil)
        #expect(try swish.eval("(nthnext (range 0 10) 100)") == .nil)
        #expect(try swish.eval("(nthnext [1 2 3] 100)") == .nil)
        #expect(try swish.eval("(nthnext nil 100)") == .nil)
        #expect(try swish.eval("(nthnext [] 100)") == .nil)
    }

    @Test("nthnext with negative n returns (seq coll) unchanged")
    func nthnextNegative() throws {
        #expect(try swish.eval("(= (nthnext (range 3) -1) (range 3))") == .boolean(true))
    }

    @Test("(nthnext nil nil) returns nil (xs checked before n, short-circuiting pos?)")
    func nthnextNilNil() throws {
        #expect(try swish.eval("(nthnext nil nil)") == .nil)
    }

    @Test("nthnext throws when n is nil and coll is non-empty")
    func nthnextNilNThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(nthnext (range 0 10) nil)") }
        #expect(throws: (any Error).self) { try swish.eval("(nthnext [0 1 2] nil)") }
    }

    // MARK: - nthrest

    @Test("nthrest with positive n on a range and a vector")
    func nthrestPositive() throws {
        #expect(try swish.eval("(nthrest (range 0 10) 3)") == .list([3, 4, 5, 6, 7, 8, 9].map { .integer($0) }, metadata: nil))
        #expect(try swish.eval("(nthrest [0 1 2 3 4 5] 3)") == .list([3, 4, 5].map { .integer($0) }, metadata: nil))
    }

    @Test("nthrest with n = 0 returns coll unchanged")
    func nthrestZero() throws {
        #expect(try swish.eval("(= (nthrest (range 0 10) 0) (range 0 10))") == .boolean(true))
    }

    @Test("nthrest exactly exhausting the collection returns the last element")
    func nthrestExact() throws {
        #expect(try swish.eval("(nthrest (range 0 10) 9)") == .list([.integer(9)], metadata: nil))
    }

    @Test("nthrest with n exceeding the collection's length returns an empty list, not nil")
    func nthrestExceeds() throws {
        #expect(try swish.eval("(nthrest (range 0 10) 10)") == .list([], metadata: nil))
        #expect(try swish.eval("(nthrest (range 0 10) 100)") == .list([], metadata: nil))
        #expect(try swish.eval("(nthrest [1 2 3] 100)") == .list([], metadata: nil))
        #expect(try swish.eval("(nthrest [] 100)") == .list([], metadata: nil))
        #expect(try swish.eval("(nthrest nil 100)") == .list([], metadata: nil))
    }

    @Test("nthrest with negative n returns coll unchanged")
    func nthrestNegative() throws {
        #expect(try swish.eval("(= (nthrest (range 3) -1) (range 3))") == .boolean(true))
    }

    @Test("(nthrest nil 0) returns nil (coll returned unchanged)")
    func nthrestNilZero() throws {
        #expect(try swish.eval("(nthrest nil 0)") == .nil)
    }

    @Test("nthrest throws when n is nil, including (nthrest nil nil) — unlike nthnext")
    func nthrestNilNThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(nthrest (range 0 10) nil)") }
        #expect(throws: (any Error).self) { try swish.eval("(nthrest [0 1 2] nil)") }
        #expect(throws: (any Error).self) { try swish.eval("(nthrest nil nil)") }
    }
}
