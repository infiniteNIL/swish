import Testing
@testable import SwishKit

/// `opaqueHasheq`'s fallback hashes `Expr.typeName`, deliberately — a constant per
/// *kind*. These pin the three ways rendering the value instead would break, since
/// `Expr.description` prints the value and the two are one word apart in the source.
@Suite("Core Hash — opaque values")
struct CoreHashOpaqueTests {
    @Test("An atom's hash does not move when the atom does")
    func atomHashIsStableAcrossMutation() throws {
        let evaluator = Evaluator()
        let before = try evaluator.eval("(def a (atom 1)) (hash a)")
        let after = try evaluator.eval("(swap! a inc) (hash a)")

        #expect(before == after)
    }

    @Test("An atom used as a map key stays findable after it mutates")
    func atomAsMapKeySurvivesMutation() throws {
        let evaluator = Evaluator()
        _ = try evaluator.eval("(def a (atom 1)) (def m {a :found})")
        _ = try evaluator.eval("(swap! a inc)")

        #expect(try evaluator.eval("(get m a)") == .keyword("found"))
    }

    @Test("Hashing an unrealized promise returns instead of blocking")
    func hashingAPromiseDoesNotBlock() throws {
        let evaluator = Evaluator()
        // Would deadlock if hashing rendered the value: the printer derefs a promise.
        #expect(try evaluator.eval("(integer? (hash (promise)))") == .boolean(true))
    }

    @Test("Hashing a delay does not force it")
    func hashingADelayDoesNotForceIt() throws {
        let evaluator = Evaluator()
        _ = try evaluator.eval("(def forced (atom false)) (def d (delay (reset! forced true)))")
        _ = try evaluator.eval("(hash d)")

        #expect(try evaluator.eval("@forced") == .boolean(false))
        #expect(try evaluator.eval("(realized? d)") == .boolean(false))
    }

    @Test("Hashing a ref does not move when the ref does")
    func refHashIsStableAcrossMutation() throws {
        let evaluator = Evaluator()
        let before = try evaluator.eval("(def r (ref 1)) (hash r)")
        let after = try evaluator.eval("(dosync (ref-set r 99)) (hash r)")

        #expect(before == after)
    }

    @Test("Functions and other opaque values hash without crashing")
    func opaqueValuesHash() throws {
        let evaluator = Evaluator()
        for source in ["(hash inc)", "(hash (fn [x] x))", "(hash #\"a.*b\")", "(hash (atom 1))"] {
            #expect(throws: Never.self) { try evaluator.eval(source) }
        }
    }
}
