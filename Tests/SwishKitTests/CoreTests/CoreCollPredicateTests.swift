import Testing
@testable import SwishKit

@Suite("Core coll? Tests", .serialized)
struct CoreCollPredicateTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("coll? returns true for a vector")
    func collVector() throws {
        #expect(try swish.eval("(coll? [])") == .boolean(true))
        #expect(try swish.eval("(coll? [1 2 3])") == .boolean(true))
    }

    @Test("coll? returns true for a list")
    func collList() throws {
        #expect(try swish.eval("(coll? '())") == .boolean(true))
        #expect(try swish.eval("(coll? '(1 2 3))") == .boolean(true))
    }

    @Test("coll? returns true for a map")
    func collMap() throws {
        #expect(try swish.eval("(coll? {})") == .boolean(true))
        #expect(try swish.eval("(coll? (hash-map :a 1))") == .boolean(true))
        #expect(try swish.eval("(coll? (array-map :a 1))") == .boolean(true))
    }

    @Test("coll? returns true for a sorted map")
    func collSortedMap() throws {
        #expect(try swish.eval("(coll? (sorted-map :a 1))") == .boolean(true))
    }

    @Test("coll? returns true for a set")
    func collSet() throws {
        #expect(try swish.eval("(coll? (hash-set :a))") == .boolean(true))
    }

    @Test("coll? returns true for a sorted set")
    func collSortedSet() throws {
        #expect(try swish.eval("(coll? (sorted-set :a))") == .boolean(true))
    }

    @Test("coll? returns true for a seq")
    func collSeq() throws {
        #expect(try swish.eval("(coll? (seq [1 2 3]))") == .boolean(true))
        #expect(try swish.eval("(coll? (seq (sorted-map :a 1)))") == .boolean(true))
        #expect(try swish.eval("(coll? (seq (sorted-set :a)))") == .boolean(true))
    }

    @Test("coll? returns true for a lazy seq / range")
    func collLazySeq() throws {
        #expect(try swish.eval("(coll? (range 0 10))") == .boolean(true))
        #expect(try swish.eval("(coll? (range))") == .boolean(true))
    }

    @Test("coll? returns true for a record")
    func collRecord() throws {
        #expect(try swish.eval("(defrecord CPRec [x]) (coll? (->CPRec 1))") == .boolean(true))
    }

    @Test("coll? returns true for a map entry")
    func collMapEntry() throws {
        #expect(try swish.eval("(coll? (first {:a 1}))") == .boolean(true))
    }

    @Test("coll? returns false for nil, scalars, strings, and arrays")
    func collFalseCases() throws {
        #expect(try swish.eval("(coll? nil)") == .boolean(false))
        #expect(try swish.eval("(coll? 1)") == .boolean(false))
        #expect(try swish.eval("(coll? 1N)") == .boolean(false))
        #expect(try swish.eval("(coll? 1.0)") == .boolean(false))
        #expect(try swish.eval("(coll? 1.0M)") == .boolean(false))
        #expect(try swish.eval("(coll? :a-keyword)") == .boolean(false))
        #expect(try swish.eval("(coll? 'a-sym)") == .boolean(false))
        #expect(try swish.eval("(coll? \"a string\")") == .boolean(false))
        #expect(try swish.eval("(coll? \\a)") == .boolean(false))
        #expect(try swish.eval("(coll? (object-array 3))") == .boolean(false))
    }

    @Test("coll? returns false for a deftype instance")
    func collDeftypeFalse() throws {
        #expect(try swish.eval("(deftype CPType [x]) (coll? (->CPType 1))") == .boolean(false))
    }
}
