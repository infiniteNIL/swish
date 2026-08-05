import Testing
@testable import SwishKit

/// `hash` + family — a deterministic port of Clojure's Murmur3-based `hasheq`.
///
/// The exact-value pins below are the output of the source-verified algorithm
/// (ported verbatim from Clojure's `Murmur3.java`/`Util.java`/`Numbers.java`), and
/// were cross-checked against independently-known Clojure values — including the
/// non-trivial `(hash []) = -2017569654` and `(hash [1 2 3]) = 736442005`, which
/// transitively validate the number/collection hashing.
@Suite("Core hash Tests", .serialized)
struct CoreHashTests {
    static let _shared = Evaluator()
    var evaluator: Evaluator { Self._shared }

    // MARK: - Exact-value pins

    @Test("scalars hash to their exact Clojure values")
    func scalarPins() throws {
        #expect(try evaluator.eval("(hash nil)") == .integer(0))
        #expect(try evaluator.eval("(hash false)") == .integer(1237))
        #expect(try evaluator.eval("(hash true)") == .integer(1231))
        #expect(try evaluator.eval(#"(hash \a)"#) == .integer(97))
        #expect(try evaluator.eval(#"(hash \A)"#) == .integer(65))
        #expect(try evaluator.eval("(hash 0)") == .integer(0))
        #expect(try evaluator.eval("(hash 1)") == .integer(1392991556))
        #expect(try evaluator.eval("(hash 2)") == .integer(-971005196))
        #expect(try evaluator.eval("(hash 42)") == .integer(1871679806))
        #expect(try evaluator.eval("(hash -1)") == .integer(1651860712))
        #expect(try evaluator.eval("(hash 100)") == .integer(-970256272))
        #expect(try evaluator.eval("(hash 1.5)") == .integer(1073217536))
    }

    @Test("strings, keywords, and symbols hash to their exact Clojure values")
    func namedPins() throws {
        #expect(try evaluator.eval(#"(hash "")"#) == .integer(0))
        #expect(try evaluator.eval(#"(hash "foo")"#) == .integer(493551392))
        #expect(try evaluator.eval("(hash :a)") == .integer(-2123407586))
        #expect(try evaluator.eval("(hash :foo/bar)") == .integer(-1386151538))
        #expect(try evaluator.eval("(hash 'sym)") == .integer(195671222))
    }

    @Test("collections hash to their exact Clojure values")
    func collectionPins() throws {
        #expect(try evaluator.eval("(hash [])") == .integer(-2017569654))
        #expect(try evaluator.eval("(hash [1 2 3])") == .integer(736442005))
        #expect(try evaluator.eval("(hash {})") == .integer(-15128758))
        #expect(try evaluator.eval("(hash {:a 1})") == .integer(2001360408))
        #expect(try evaluator.eval("(hash #{})") == .integer(-15128758))
        #expect(try evaluator.eval("(hash #{1 2 3})") == .integer(439094965))
    }

    @Test("a ratio hashes as numerator.hashCode ^ denominator.hashCode")
    func ratioPin() throws {
        #expect(try evaluator.eval("(hash 1/3)") == .integer(2))                  // 1 ^ 3
        // a ratio that reduces to an integer hashes like that integer
        #expect(try evaluator.eval("(= (hash (/ 6 3)) (hash 2))") == .boolean(true))
    }

    // MARK: - Contracts (consistent with =)

    @Test("=-equal values of different concrete types hash equal")
    func equalValuesHashEqual() throws {
        #expect(try evaluator.eval("(= (hash [1 2 3]) (hash '(1 2 3)))") == .boolean(true))
        #expect(try evaluator.eval("(= (hash (map inc [1 2 3])) (hash [2 3 4]))") == .boolean(true))
        #expect(try evaluator.eval("(= (hash (seq [1 2])) (hash '(1 2)))") == .boolean(true))
    }

    @Test("unordered collections hash independent of iteration order")
    func unorderedOrderIndependent() throws {
        #expect(try evaluator.eval("(= (hash {:a 1 :b 2}) (hash {:b 2 :a 1}))") == .boolean(true))
        #expect(try evaluator.eval("(= (hash #{1 2 3}) (hash #{3 2 1}))") == .boolean(true))
    }

    @Test("hash is deterministic across calls")
    func deterministic() throws {
        #expect(try evaluator.eval(#"(= (hash "foobar") (hash "foobar"))"#) == .boolean(true))
        #expect(try evaluator.eval("(= (hash [1 [2 3] {:a 1}]) (hash [1 [2 3] {:a 1}]))") == .boolean(true))
    }

    @Test("distinct values hash distinctly (sanity)")
    func distinctValues() throws {
        #expect(try evaluator.eval(#"(not= (hash "foo") (hash "bar"))"#) == .boolean(true))
        #expect(try evaluator.eval("(not= (hash :a) (hash :b))") == .boolean(true))
    }

    // MARK: - hash family

    @Test("hash-ordered-coll / hash-unordered-coll match hash on the collection")
    func hashFamily() throws {
        #expect(try evaluator.eval("(hash-ordered-coll [1 2 3])") == .integer(736442005))
        #expect(try evaluator.eval("(= (hash-ordered-coll [1 2 3]) (hash [1 2 3]))") == .boolean(true))
        #expect(try evaluator.eval("(= (hash-unordered-coll #{1 2 3}) (hash #{1 2 3}))") == .boolean(true))
    }

    @Test("mix-collection-hash mixes a basis and count")
    func mixCollectionHash() throws {
        // (hash #{}) and (hash {}) are both mix-collection-hash of (0, 0)
        #expect(try evaluator.eval("(mix-collection-hash 0 0)") == .integer(-15128758))
        #expect(try evaluator.eval("(= (mix-collection-hash 0 0) (hash #{}))") == .boolean(true))
    }
}
