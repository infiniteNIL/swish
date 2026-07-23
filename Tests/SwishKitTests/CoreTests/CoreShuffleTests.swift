import Testing
@testable import SwishKit

@Suite("Core shuffle Tests", .serialized)
struct CoreShuffleTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - accepted collection types produce a vector with the same elements

    @Test("shuffle on a vector returns a vector with the same elements")
    func shuffleVector() throws {
        #expect(try swish.eval("""
            (let [x [1 2 3] actual (shuffle x)]
              [(vector? actual) (= (count x) (count actual)) (= (set x) (set actual))])
            """) == .vector([.boolean(true), .boolean(true), .boolean(true)], metadata: nil))
    }

    @Test("shuffle on a set returns a vector with the same elements")
    func shuffleSet() throws {
        #expect(try swish.eval("""
            (let [x #{1 2 3} actual (shuffle x)]
              [(vector? actual) (= (count x) (count actual)) (= (set x) (set actual))])
            """) == .vector([.boolean(true), .boolean(true), .boolean(true)], metadata: nil))
    }

    @Test("shuffle on a list returns a vector with the same elements")
    func shuffleList() throws {
        #expect(try swish.eval("""
            (let [x '(1 2 3) actual (shuffle x)]
              [(vector? actual) (= (count x) (count actual)) (= (set x) (set actual))])
            """) == .vector([.boolean(true), .boolean(true), .boolean(true)], metadata: nil))
    }

    @Test("shuffle on a lazy seq returns a vector with the same elements")
    func shuffleLazySeq() throws {
        #expect(try swish.eval("""
            (let [x (range 5) actual (shuffle x)]
              [(vector? actual) (= (count x) (count actual)) (= (set x) (set actual))])
            """) == .vector([.boolean(true), .boolean(true), .boolean(true)], metadata: nil))
    }

    @Test("shuffle on a sorted-set returns a vector with the same elements")
    func shuffleSortedSet() throws {
        #expect(try swish.eval("""
            (let [x (sorted-set 1 2 3) actual (shuffle x)]
              [(vector? actual) (= (count x) (count actual)) (= (set x) (set actual))])
            """) == .vector([.boolean(true), .boolean(true), .boolean(true)], metadata: nil))
    }

    // MARK: - produces varied orderings

    @Test("shuffle produces more than one distinct ordering across repeated calls")
    func shuffleProducesVariedOrderings() throws {
        #expect(try swish.eval("""
            (> (count (set (repeatedly 20 #(shuffle (range 10))))) 1)
            """) == .boolean(true))
    }

    // MARK: - throws for types that don't implement java.util.Collection

    @Test("shuffle throws for nil, a string, a map, and a scalar")
    func shuffleThrowsForUnsupportedTypes() throws {
        #expect(throws: (any Error).self) { try swish.eval("(shuffle nil)") }
        #expect(throws: (any Error).self) { try swish.eval(#"(shuffle "abc")"#) }
        #expect(throws: (any Error).self) { try swish.eval("(shuffle {})") }
        #expect(throws: (any Error).self) { try swish.eval("(shuffle 1)") }
    }

    @Test("shuffle throws for an array")
    func shuffleThrowsForArray() throws {
        #expect(throws: (any Error).self) { try swish.eval("(shuffle (object-array 3))") }
    }

    // MARK: - lazy-seq thunk errors propagate instead of silently truncating

    @Test("shuffle propagates a lazy-seq thunk's error instead of silently shuffling a partial result")
    func shufflePropagatesThunkError() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(shuffle (map (fn [x] (if (= x 3) (throw \"boom\") x)) [1 2 3 4 5]))")
        }
    }
}
