import Testing
@testable import SwishKit

@Suite("Core subvec Tests", .serialized)
struct CoreSubvecTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - 2-arity (start only, end defaults to count)

    @Test("subvec with 2 args slices from start to the end of the vector")
    func subvecTwoArity() throws {
        #expect(try swish.eval("(subvec [0 1 2 3 4] 2)") == .vector([2, 3, 4].map { .integer($0) }, metadata: nil))
        #expect(try swish.eval("(subvec [0 1 2 3 4] 1)") == .vector([1, 2, 3, 4].map { .integer($0) }, metadata: nil))
        #expect(try swish.eval("(subvec [1 2 3 4 5] 5)") == .vector([], metadata: nil))
        #expect(try swish.eval("(subvec [] 0)") == .vector([], metadata: nil))
    }

    // MARK: - 3-arity (start and end)

    @Test("subvec with 3 args slices from start to end")
    func subvecThreeArity() throws {
        #expect(try swish.eval("(subvec [0 1 2 3 4] 2 4)") == .vector([2, 3].map { .integer($0) }, metadata: nil))
        #expect(try swish.eval("(subvec [0 1 2 3 4] 1 5)") == .vector([1, 2, 3, 4].map { .integer($0) }, metadata: nil))
        #expect(try swish.eval("(subvec [1 2 3 4 5] 2 2)") == .vector([], metadata: nil))
        #expect(try swish.eval("(subvec [] 0 0)") == .vector([], metadata: nil))
    }

    // MARK: - borderline indices: NaN, negative zero, floats, ratios

    @Test("subvec casts NaN indices to 0, matching Java's Number.intValue()")
    func subvecNaNIndices() throws {
        #expect(try swish.eval("(subvec [0 1 2] ##NaN ##NaN)") == .vector([], metadata: nil))
        #expect(try swish.eval("(subvec [0 1 2] ##NaN 3)") == .vector([0, 1, 2].map { .integer($0) }, metadata: nil))
        #expect(try swish.eval("(subvec [0 1 2] 0 ##NaN)") == .vector([], metadata: nil))
    }

    @Test("subvec accepts negative zero as a plain zero index")
    func subvecNegativeZero() throws {
        #expect(try swish.eval("(subvec [0 1 2] -0 3)") == .vector([0, 1, 2].map { .integer($0) }, metadata: nil))
    }

    @Test("subvec truncates float indices toward zero")
    func subvecFloatIndices() throws {
        #expect(try swish.eval("(subvec [0 1 2] 2.72 3.14)") == .vector([.integer(2)], metadata: nil))
    }

    @Test("subvec truncates ratio indices via integer division")
    func subvecRatioIndices() throws {
        #expect(try swish.eval("(subvec [0 1 2] 1/2 4/3)") == .vector([.integer(0)], metadata: nil))
    }

    // MARK: - out of bounds

    @Test("subvec throws for out-of-bounds indices")
    func subvecOutOfBounds() throws {
        #expect(throws: (any Error).self) { try swish.eval("(subvec [0 1 2 3] -1 3)") }
        #expect(throws: (any Error).self) { try swish.eval("(subvec [0 1 2 3] 1 5)") }
        #expect(throws: (any Error).self) { try swish.eval("(subvec [0 1 2 3] 3 2)") }
        #expect(throws: (any Error).self) { try swish.eval("(subvec [] 0 1)") }
    }

    @Test("subvec throws when ±Infinity indices cast out of bounds")
    func subvecInfiniteIndices() throws {
        #expect(throws: (any Error).self) { try swish.eval("(subvec [0 1 2 3] ##-Inf 4)") }
        #expect(throws: (any Error).self) { try swish.eval("(subvec [0 1 2 3] 0 ##Inf)") }
    }

    // MARK: - nil args

    @Test("subvec throws for nil v, start, or end")
    func subvecNilArgs() throws {
        #expect(throws: (any Error).self) { try swish.eval("(subvec nil 0 0)") }
        #expect(throws: (any Error).self) { try swish.eval("(subvec [] nil 0)") }
        #expect(throws: (any Error).self) { try swish.eval("(subvec [0 1 2] 1 nil)") }
    }

    // MARK: - not a vector

    @Test("subvec throws for a list, set, map, lazy seq, string, or transient vector")
    func subvecNotAVector() throws {
        #expect(throws: (any Error).self) { try swish.eval("(subvec '(0 1 2) 0 2)") }
        #expect(throws: (any Error).self) { try swish.eval("(subvec #{0 1 2} 0 2)") }
        #expect(throws: (any Error).self) { try swish.eval("(subvec {:a 0 :b 1} 0 2)") }
        #expect(throws: (any Error).self) { try swish.eval("(subvec (range 3) 0 2)") }
        #expect(throws: (any Error).self) { try swish.eval(#"(subvec "012" 0 2)"#) }
        #expect(throws: (any Error).self) { try swish.eval("(subvec (transient [0 1 2]) 0 2)") }
    }

    // MARK: - indices that cannot be cast to numbers

    @Test("subvec throws for non-numeric index types")
    func subvecNonNumericIndices() throws {
        #expect(throws: (any Error).self) { try swish.eval("(subvec [0 1 2] :a 2)") }
        #expect(throws: (any Error).self) { try swish.eval("(subvec [0 1 2] 1 :b)") }
        #expect(throws: (any Error).self) { try swish.eval("(subvec [0 1 2] 'c 'd)") }
        #expect(throws: (any Error).self) { try swish.eval(#"(subvec [0 1 2] "a" "b")"#) }
        #expect(throws: (any Error).self) { try swish.eval("(subvec [0 1 2] [] {})") }
    }
}
