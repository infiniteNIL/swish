import Testing
@testable import SwishKit

@Suite("Core seqable? Tests", .serialized)
struct CoreSeqableTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - true for everything seq supports

    @Test("seqable? is true for lists, vectors, maps, and sets")
    func seqableTrueForCoreCollections() throws {
        #expect(try swish.eval("(seqable? [1 2 3])") == .boolean(true))
        #expect(try swish.eval("(seqable? '(1 2 3))") == .boolean(true))
        #expect(try swish.eval("(seqable? (hash-map :a 1))") == .boolean(true))
        #expect(try swish.eval("(seqable? (hash-set :a))") == .boolean(true))
    }

    @Test("seqable? is true for nil, a seq, a string, and an array")
    func seqableTrueForMisc() throws {
        #expect(try swish.eval("(seqable? nil)") == .boolean(true))
        #expect(try swish.eval("(seqable? (seq [1 2 3]))") == .boolean(true))
        #expect(try swish.eval(#"(seqable? "a string")"#) == .boolean(true))
        #expect(try swish.eval("(seqable? (object-array 3))") == .boolean(true))
    }

    @Test("seqable? is true for sorted collections and array-map")
    func seqableTrueForSortedCollections() throws {
        #expect(try swish.eval("(seqable? (sorted-map :a 1))") == .boolean(true))
        #expect(try swish.eval("(seqable? (sorted-set :a))") == .boolean(true))
        #expect(try swish.eval("(seqable? (array-map :a 1))") == .boolean(true))
        #expect(try swish.eval("(seqable? (seq (sorted-map :a 1)))") == .boolean(true))
        #expect(try swish.eval("(seqable? (seq (sorted-set :a)))") == .boolean(true))
    }

    // MARK: - true for lazy seqs, without forcing them

    @Test("seqable? is true for a finite lazy seq")
    func seqableTrueForFiniteLazySeq() throws {
        #expect(try swish.eval("(seqable? (range 0 10))") == .boolean(true))
    }

    @Test("seqable? is true for an infinite lazy seq, and returns promptly rather than hanging")
    func seqableTrueForInfiniteLazySeqDoesNotHang() throws {
        // The regression this guards: asSequence's .lazySeq case fully
        // realizes the seq into an array, so naively implementing seqable?
        // as (asSequence(x) != nil) would hang forever here. seqable? must
        // special-case .lazySeq as an unconditional true without forcing.
        #expect(try swish.eval("(seqable? (range))") == .boolean(true))
    }

    // MARK: - false for everything else

    @Test("seqable? is false for numbers")
    func seqableFalseForNumbers() throws {
        #expect(try swish.eval("(seqable? 1)") == .boolean(false))
        #expect(try swish.eval("(seqable? 1N)") == .boolean(false))
        #expect(try swish.eval("(seqable? 1.0)") == .boolean(false))
        #expect(try swish.eval("(seqable? 1.0M)") == .boolean(false))
    }

    @Test("seqable? is false for keywords, symbols, and characters")
    func seqableFalseForScalars() throws {
        #expect(try swish.eval("(seqable? :a-keyword)") == .boolean(false))
        #expect(try swish.eval("(seqable? 'a-sym)") == .boolean(false))
        #expect(try swish.eval(#"(seqable? \a)"#) == .boolean(false))
    }
}
