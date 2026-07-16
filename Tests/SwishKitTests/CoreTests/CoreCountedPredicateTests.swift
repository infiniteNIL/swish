import Testing
@testable import SwishKit

@Suite("Core counted? Tests", .serialized)
struct CoreCountedPredicateTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("counted? returns true for a vector")
    func countedVector() throws {
        #expect(try swish.eval("(counted? [1 2 3])") == .boolean(true))
    }

    @Test("counted? returns true for a list")
    func countedList() throws {
        #expect(try swish.eval("(counted? '(1 2 3))") == .boolean(true))
    }

    @Test("counted? returns true for a map")
    func countedMap() throws {
        #expect(try swish.eval("(counted? (hash-map :a 1 :b 2 :c 3))") == .boolean(true))
        #expect(try swish.eval("(counted? (array-map :a 1 :b 2 :c 3))") == .boolean(true))
    }

    @Test("counted? returns true for a sorted map")
    func countedSortedMap() throws {
        #expect(try swish.eval("(counted? (sorted-map :a 1 :b 2 :c 3))") == .boolean(true))
    }

    @Test("counted? returns true for a set")
    func countedSet() throws {
        #expect(try swish.eval("(counted? #{1 2 3})") == .boolean(true))
    }

    @Test("counted? returns true for a sorted set")
    func countedSortedSet() throws {
        #expect(try swish.eval("(counted? (sorted-set 1 2 3))") == .boolean(true))
    }

    @Test("counted? returns true for a seq")
    func countedSeq() throws {
        #expect(try swish.eval("(counted? (seq [1 2 3]))") == .boolean(true))
    }

    @Test("counted? returns true for a map entry")
    func countedMapEntry() throws {
        #expect(try swish.eval("(counted? (first {:a 1}))") == .boolean(true))
    }

    @Test("counted? returns true for a record")
    func countedRecord() throws {
        #expect(try swish.eval("(defrecord CtdRec [x]) (counted? (->CtdRec 1))") == .boolean(true))
    }

    @Test("counted? returns false for nil, scalars, strings, and arrays")
    func countedFalseCases() throws {
        #expect(try swish.eval("(counted? 1)") == .boolean(false))
        #expect(try swish.eval("(counted? 1N)") == .boolean(false))
        #expect(try swish.eval("(counted? 1.0)") == .boolean(false))
        #expect(try swish.eval("(counted? 1.0M)") == .boolean(false))
        #expect(try swish.eval("(counted? :a-keyword)") == .boolean(false))
        #expect(try swish.eval("(counted? 'a-sym)") == .boolean(false))
        #expect(try swish.eval("(counted? nil)") == .boolean(false))
        #expect(try swish.eval("(counted? \"a string\")") == .boolean(false))
        #expect(try swish.eval("(counted? (object-array 3))") == .boolean(false))
    }

    @Test("counted? returns false for a lazy seq / range")
    func countedLazySeqFalse() throws {
        #expect(try swish.eval("(counted? (range 0 10))") == .boolean(false))
        #expect(try swish.eval("(counted? (range))") == .boolean(false))
    }

    @Test("counted? returns false for a deftype instance")
    func countedDeftypeFalse() throws {
        #expect(try swish.eval("(deftype CtdType [x]) (counted? (->CtdType 1))") == .boolean(false))
    }
}
