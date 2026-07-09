import Testing
@testable import SwishKit

@Suite("Core Transient Tests", .serialized)
struct CoreTransientTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - assoc! on transient vectors

    @Test("assoc! on transient vector sets single index-value pair")
    func assocBangVectorSinglePair() throws {
        #expect(try swish.eval("(persistent! (assoc! (transient [0 0 0]) 1 42))") == .vector([.integer(0), .integer(42), .integer(0)], metadata: nil))
    }

    @Test("assoc! on transient vector sets multiple index-value pairs")
    func assocBangVectorMultiplePairs() throws {
        #expect(try swish.eval("(persistent! (assoc! (transient [1 2]) 1 3 2 5 3 7))") == .vector([.integer(1), .integer(3), .integer(5), .integer(7)], metadata: nil))
    }

    @Test("assoc! on transient vector with odd args treats trailing index as nil")
    func assocBangVectorOddArgs() throws {
        #expect(try swish.eval("(persistent! (assoc! (transient []) 0 1 1))") == .vector([.integer(1), .nil], metadata: nil))
    }

    @Test("assoc! on transient vector with even args [0 1 1 2]")
    func assocBangVectorEvenArgs() throws {
        #expect(try swish.eval("(persistent! (assoc! (transient []) 0 1 1 2))") == .vector([.integer(1), .integer(2)], metadata: nil))
    }

    @Test("assoc! on transient map with odd args treats trailing key as nil")
    func assocBangMapOddArgs() throws {
        #expect(try swish.eval("(persistent! (assoc! (transient {:a 1}) :b 2 :c))") == .map([.keyword("a"): .integer(1), .keyword("b"): .integer(2), .keyword("c"): .nil], metadata: nil))
    }

    // MARK: - conj! multi-arity

    @Test("(persistent! (conj!)) returns empty vector")
    func conjBangZeroArity() throws {
        #expect(try swish.eval("(persistent! (conj!))") == .vector([], metadata: nil))
    }

    @Test("(persistent! (conj! (transient []))) returns empty vector")
    func conjBangOneArity() throws {
        #expect(try swish.eval("(persistent! (conj! (transient [])))") == .vector([], metadata: nil))
    }

    @Test("(persistent! (conj! (transient []) 1 2 3)) returns [1 2 3]")
    func conjBangMultipleArgs() throws {
        #expect(try swish.eval("(persistent! (conj! (transient []) 1 2 3))") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(conj! nil) returns nil unchanged")
    func conjBangNilPassthrough() throws {
        #expect(try swish.eval("(conj! nil)") == .nil)
    }

    // MARK: - conj! map with nil/map items

    @Test("(conj! transient-map nil) returns map unchanged")
    func conjBangMapNil() throws {
        #expect(try swish.eval("(persistent! (conj! (transient {}) nil))") == .map([:], metadata: nil))
    }

    @Test("(conj! transient-map {}) returns map unchanged")
    func conjBangMapEmptyMap() throws {
        #expect(try swish.eval("(persistent! (conj! (transient {}) {}))") == .map([:], metadata: nil))
    }

    @Test("(conj! transient-map {:a 1}) merges entries")
    func conjBangMapMerge() throws {
        #expect(try swish.eval("(persistent! (conj! (transient {}) {:a 1}))") == .map([.keyword("a"): .integer(1)], metadata: nil))
    }

    // MARK: - post-persistent! invalidation

    @Test("conj! throws after persistent! call on vector")
    func conjBangAfterPersistentVector() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(let [t (transient [1 2]), _ (persistent! t)] (conj! t 3))")
        }
    }

    @Test("assoc! throws after persistent! call on map")
    func assocBangAfterPersistentMap() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(let [t (transient {:a 1}), _ (persistent! t)] (assoc! t :b 2))")
        }
    }

    @Test("assoc! throws after persistent! call on vector")
    func assocBangAfterPersistentVector() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(let [t (transient [1]), _ (persistent! t)] (assoc! t 0 2))")
        }
    }

    @Test("dissoc! throws after persistent! call on map")
    func dissocBangAfterPersistentMap() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(let [t (transient {:a 1}), _ (persistent! t)] (dissoc! t :a))")
        }
    }

    // MARK: - keyword lookup on transient map

    @Test("keyword lookup on transient map returns value")
    func keywordLookupTransientMap() throws {
        #expect(try swish.eval("(:x (transient {:x 42}))") == .integer(42))
    }

    @Test("keyword lookup on transient map returns nil for missing key")
    func keywordLookupTransientMapMissing() throws {
        #expect(try swish.eval("(:y (transient {:x 42}))") == .nil)
    }

    @Test("keyword lookup on transient map uses notFound argument")
    func keywordLookupTransientMapNotFound() throws {
        #expect(try swish.eval("(:y (transient {:x 42}) :default)") == .keyword("default"))
    }
}
