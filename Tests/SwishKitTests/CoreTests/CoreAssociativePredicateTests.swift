import Testing
@testable import SwishKit

@Suite("Core associative? Tests", .serialized)
struct CoreAssociativePredicateTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("associative? returns true for a vector")
    func associativeVector() throws {
        #expect(try swish.eval("(associative? [])") == .boolean(true))
        #expect(try swish.eval("(associative? [1 2 3])") == .boolean(true))
    }

    @Test("associative? returns true for a map")
    func associativeMap() throws {
        #expect(try swish.eval("(associative? {})") == .boolean(true))
        #expect(try swish.eval("(associative? {:a 1 :b 2})") == .boolean(true))
    }

    @Test("associative? returns true for a record")
    func associativeRecord() throws {
        #expect(try swish.eval("(defrecord APRec [x]) (associative? (->APRec 1))") == .boolean(true))
    }

    @Test("associative? returns true for a map entry")
    func associativeMapEntry() throws {
        #expect(try swish.eval("(associative? (first {:a 1}))") == .boolean(true))
    }

    @Test("associative? returns false for nil, lists, seqs, sets, strings, arrays, and scalars")
    func associativeFalseCases() throws {
        #expect(try swish.eval("(associative? nil)") == .boolean(false))
        #expect(try swish.eval("(associative? '())") == .boolean(false))
        #expect(try swish.eval("(associative? (range 10))") == .boolean(false))
        #expect(try swish.eval("(associative? (range))") == .boolean(false))
        #expect(try swish.eval("(associative? #{})") == .boolean(false))
        #expect(try swish.eval("(associative? #{:a :b})") == .boolean(false))
        #expect(try swish.eval("(associative? \"ab\")") == .boolean(false))
        #expect(try swish.eval("(associative? (seq \"ab\"))") == .boolean(false))
        #expect(try swish.eval("(associative? (to-array [1 2 3]))") == .boolean(false))
        #expect(try swish.eval("(associative? :a)") == .boolean(false))
        #expect(try swish.eval("(associative? 'a)") == .boolean(false))
        #expect(try swish.eval("(associative? 1)") == .boolean(false))
        #expect(try swish.eval("(associative? \\a)") == .boolean(false))
    }

    @Test("associative? returns false for a deftype instance")
    func associativeDeftypeFalse() throws {
        #expect(try swish.eval("(deftype APType [x]) (associative? (->APType 1))") == .boolean(false))
    }
}
