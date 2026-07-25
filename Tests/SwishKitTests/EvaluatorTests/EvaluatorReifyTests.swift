import Testing
@testable import SwishKit

@Suite("Evaluator reify Tests", .serialized)
struct EvaluatorReifyTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("reify implements a protocol method that can be called")
    func reifyBasicCall() throws {
        _ = try swish.eval("(defprotocol RP1 (rm1 [this]))")
        #expect(try swish.eval("(rm1 (reify RP1 (rm1 [this] 42)))") == .integer(42))
    }

    @Test("reify method closes over a surrounding let-local")
    func reifyClosesOverLetLocal() throws {
        _ = try swish.eval("(defprotocol RP2 (rm2 [this]))")
        #expect(try swish.eval("(let [x 10] (rm2 (reify RP2 (rm2 [this] x))))") == .integer(10))
    }

    @Test("reify method closes over a surrounding fn parameter")
    func reifyClosesOverFnParam() throws {
        _ = try swish.eval("(defprotocol RP3 (rm3 [this]))")
        _ = try swish.eval("(defn rp3-make [n] (reify RP3 (rm3 [this] n)))")
        #expect(try swish.eval("(rm3 (rp3-make 5))") == .integer(5))
    }

    @Test("reify method uses both a captured local and its own argument")
    func reifyMethodWithArgs() throws {
        _ = try swish.eval("(defprotocol RP4 (rm4 [this a]))")
        #expect(
            try swish.eval("(let [base 100] (rm4 (reify RP4 (rm4 [this a] (+ base a))) 7))")
                == .integer(107))
    }

    @Test("one reify can implement multiple protocols")
    func reifyMultipleProtocols() throws {
        _ = try swish.eval("(defprotocol RP5a (rm5a [this]))")
        _ = try swish.eval("(defprotocol RP5b (rm5b [this]))")
        _ = try swish.eval("(def rp5-obj (reify RP5a (rm5a [this] :a) RP5b (rm5b [this] :b)))")
        #expect(try swish.eval("(rm5a rp5-obj)") == .keyword("a"))
        #expect(try swish.eval("(rm5b rp5-obj)") == .keyword("b"))
    }

    @Test("satisfies? is true for an implemented protocol, false for a non-implemented one")
    func reifySatisfies() throws {
        _ = try swish.eval("(defprotocol RP6a (rm6a [this]))")
        _ = try swish.eval("(defprotocol RP6b (rm6b [this]))")
        _ = try swish.eval("(def rp6-obj (reify RP6a (rm6a [this] 1)))")
        #expect(try swish.eval("(satisfies? RP6a rp6-obj)") == .boolean(true))
        #expect(try swish.eval("(satisfies? RP6b rp6-obj)") == .boolean(false))
    }

    @Test("a reify method can reference this, and satisfies? still holds for the returned instance")
    func reifyThisBinding() throws {
        _ = try swish.eval("(defprotocol RP7 (rm7 [this]))")
        _ = try swish.eval("(def rp7-obj (reify RP7 (rm7 [this] this)))")
        // rm7 returns `this` — the same instance — which still satisfies RP7.
        #expect(try swish.eval("(satisfies? RP7 (rm7 rp7-obj))") == .boolean(true))
    }

    @Test("calling a protocol method the reify does not implement throws")
    func reifyUnimplementedMethodThrows() throws {
        _ = try swish.eval("(defprotocol RP8a (rm8a [this]))")
        _ = try swish.eval("(defprotocol RP8b (rm8b [this]))")
        _ = try swish.eval("(def rp8-obj (reify RP8a (rm8a [this] 1)))")
        #expect(throws: (any Error).self) {
            try swish.eval("(rm8b rp8-obj)")
        }
    }

    @Test("reify produces a distinct anonymous type per instance")
    func reifyDistinctAnonymousType() throws {
        _ = try swish.eval("(defprotocol RP9 (rm9 [this]))")
        let t = try swish.eval("(type (reify RP9 (rm9 [this] 1)))")
        guard case .keyword(let name) = t else {
            Issue.record("expected a keyword type, got \(t)")
            return
        }
        #expect(name.hasPrefix("reify__"))
        // Two separate reify evaluations get different anonymous type names.
        #expect(
            try swish.eval("""
                (= (type (reify RP9 (rm9 [this] 1)))
                   (type (reify RP9 (rm9 [this] 1))))
                """) == .boolean(false))
    }

    @Test("reify method supports multiple arities")
    func reifyMultiArity() throws {
        _ = try swish.eval("(defprotocol RP10 (rm10 [this] [this a]))")
        _ = try swish.eval("(def rp10-obj (reify RP10 (rm10 [this] :zero) (rm10 [this a] a)))")
        #expect(try swish.eval("(rm10 rp10-obj)") == .keyword("zero"))
        #expect(try swish.eval("(rm10 rp10-obj 99)") == .integer(99))
    }
}
