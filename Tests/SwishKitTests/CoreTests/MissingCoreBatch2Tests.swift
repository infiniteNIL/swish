import Testing
@testable import SwishKit

@Suite("Missing Core Forms Batch 2 Tests", .serialized)
struct MissingCoreBatch2Tests {
    static let _shared: Swish = {
        let swish = Swish()
        _ = try? swish.eval("(require '[clojure.string] '[clojure.set] '[clojure.walk])")
        return swish
    }()
    var swish: Swish { Self._shared }

    // MARK: - mapv / filterv

    @Test("mapv returns a real vector")
    func mapvReturnsVector() throws {
        #expect(try swish.eval("(mapv inc [1 2 3])") == .vector([.integer(2), .integer(3), .integer(4)], metadata: nil))
        #expect(try swish.eval("(vector? (mapv inc [1 2 3]))") == .boolean(true))
    }

    @Test("mapv over multiple colls")
    func mapvMultiColl() throws {
        #expect(try swish.eval("(mapv + [1 2 3] [10 20 30])") == .vector([.integer(11), .integer(22), .integer(33)], metadata: nil))
    }

    @Test("filterv returns a real vector of matching items")
    func filtervReturnsVector() throws {
        #expect(try swish.eval("(filterv even? [1 2 3 4])") == .vector([.integer(2), .integer(4)], metadata: nil))
        #expect(try swish.eval("(vector? (filterv even? [1 2]))") == .boolean(true))
    }

    // MARK: - reduce-kv

    @Test("reduce-kv over a map passes key and value")
    func reduceKvMap() throws {
        #expect(
            try swish.eval("(reduce-kv (fn [a k v] (assoc a v k)) {} {:a 1 :b 2})")
                == .map([.integer(1): .keyword("a"), .integer(2): .keyword("b")], metadata: nil))
    }

    @Test("reduce-kv over a vector passes index and element")
    func reduceKvVector() throws {
        #expect(
            try swish.eval("(reduce-kv (fn [a i x] (conj a [i x])) [] [:x :y])")
                == .vector(
                    [.vector([.integer(0), .keyword("x")], metadata: nil),
                     .vector([.integer(1), .keyword("y")], metadata: nil)], metadata: nil))
    }

    @Test("reduce-kv honors reduced early termination")
    func reduceKvReduced() throws {
        #expect(
            try swish.eval("(reduce-kv (fn [a k v] (if (= k 1) (reduced :stop) a)) :init [:zero :one :two])")
                == .keyword("stop"))
    }

    // MARK: - distinct?

    @Test("distinct? arities")
    func distinctPred() throws {
        #expect(try swish.eval("(distinct? 1)") == .boolean(true))
        #expect(try swish.eval("(distinct? 1 2)") == .boolean(true))
        #expect(try swish.eval("(distinct? 1 1)") == .boolean(false))
        #expect(try swish.eval("(distinct? 1 2 3)") == .boolean(true))
        #expect(try swish.eval("(distinct? 1 2 3 2)") == .boolean(false))
    }

    // MARK: - every-pred

    @Test("every-pred all/one/no-args")
    func everyPred() throws {
        #expect(try swish.eval("((every-pred pos? even?) 2 4)") == .boolean(true))
        #expect(try swish.eval("((every-pred pos? even?) 2 3)") == .boolean(false))
        #expect(try swish.eval("((every-pred pos?))") == .boolean(true))
    }

    // MARK: - when-some / if-some

    @Test("when-some binds on a false value, not on nil")
    func whenSome() throws {
        #expect(try swish.eval("(when-some [x false] :bound)") == .keyword("bound"))
        #expect(try swish.eval("(when-some [x nil] :bound)") == .nil)
    }

    @Test("if-some binds on 0, takes else on nil")
    func ifSome() throws {
        #expect(try swish.eval("(if-some [x 0] x :else)") == .integer(0))
        #expect(try swish.eval("(if-some [x nil] x :else)") == .keyword("else"))
    }

    // MARK: - doto

    @Test("doto runs forms in order and returns the original object")
    func doto() throws {
        #expect(try swish.eval("(deref (doto (atom 0) (reset! 5) (swap! inc)))") == .integer(6))
    }

    // MARK: - bound?

    @Test("bound? is true for a bound var, false for a declared-unbound var")
    func boundPred() throws {
        #expect(try swish.eval("(bound? #'+)") == .boolean(true))
        #expect(
            try swish.eval("(do (declare mcb2-unbound) (bound? #'mcb2-unbound))")
                == .boolean(false))
    }

    // MARK: - ns-resolve

    @Test("ns-resolve resolves a symbol in a named namespace different from current")
    func nsResolve() throws {
        #expect(try swish.eval("(= (ns-resolve 'clojure.core 'inc) (resolve 'inc))") == .boolean(true))
        #expect(try swish.eval("(ns-resolve 'clojure.core 'no-such-sym-xyz)") == .nil)
    }

    // MARK: - partition-by

    @Test("partition-by groups consecutive equal-f runs")
    func partitionBy() throws {
        #expect(
            try swish.eval("(partition-by even? [1 1 2 2 3])")
                == .list(
                    [.list([.integer(1), .integer(1)], metadata: nil),
                     .list([.integer(2), .integer(2)], metadata: nil),
                     .list([.integer(3)], metadata: nil)], metadata: nil))
    }

    @Test("partition-by works as a transducer")
    func partitionByTransducer() throws {
        #expect(
            try swish.eval("(into [] (partition-by odd?) [1 3 2 4 5])")
                == .vector(
                    [.vector([.integer(1), .integer(3)], metadata: nil),
                     .vector([.integer(2), .integer(4)], metadata: nil),
                     .vector([.integer(5)], metadata: nil)], metadata: nil))
    }

    // MARK: - reductions

    @Test("reductions returns the running reduction values")
    func reductions() throws {
        #expect(
            try swish.eval("(reductions + [1 2 3 4])")
                == .list([.integer(1), .integer(3), .integer(6), .integer(10)], metadata: nil))
        #expect(
            try swish.eval("(reductions + 100 [1 2 3])")
                == .list([.integer(100), .integer(101), .integer(103), .integer(106)], metadata: nil))
    }

    // MARK: - Large-input stack-safety (must be a Swift test — the smaller-stack runner)

    @Test("partition-by over a large input does not overflow the stack")
    func partitionByLargeInput() throws {
        // Each element is its own partition here, so this realizes 2000 lazy
        // partition-by steps. That's well past where a broken (eager-recursive)
        // implementation would overflow the interpreter's own eval stack, so it
        // catches a stack-accumulation regression — while keeping partition-by's
        // high per-element interpreter cost (composed take-while/drop/count lazy
        // layers) from dominating the suite.
        #expect(try swish.eval("(count (partition-by even? (range 2000)))") == .integer(2000))
    }

    @Test("reductions over a large input does not overflow the stack")
    func reductionsLargeInput() throws {
        #expect(try swish.eval("(count (reductions + (range 3000)))") == .integer(3000))
    }

    // MARK: - clojure.string/index-of / last-index-of

    @Test("index-of: found, from-index, not-found, char value")
    func indexOf() throws {
        #expect(try swish.eval(#"(clojure.string/index-of "abcabc" "b")"#) == .integer(1))
        #expect(try swish.eval(#"(clojure.string/index-of "abcabc" "b" 2)"#) == .integer(4))
        #expect(try swish.eval(#"(clojure.string/index-of "abc" "z")"#) == .nil)
        #expect(try swish.eval(#"(clojure.string/index-of "abc" \c)"#) == .integer(2))
    }

    @Test("last-index-of: found, from-index")
    func lastIndexOf() throws {
        #expect(try swish.eval(#"(clojure.string/last-index-of "abcabc" "b")"#) == .integer(4))
        #expect(try swish.eval(#"(clojure.string/last-index-of "abcabc" "b" 3)"#) == .integer(1))
        #expect(try swish.eval(#"(clojure.string/last-index-of "abc" "z")"#) == .nil)
    }

    // MARK: - clojure.set/rename-keys

    @Test("rename-keys: basic, absent source key skipped")
    func renameKeys() throws {
        #expect(
            try swish.eval("(clojure.set/rename-keys {:a 1 :b 2} {:a :x})")
                == .map([.keyword("x"): .integer(1), .keyword("b"): .integer(2)], metadata: nil))
        #expect(
            try swish.eval("(clojure.set/rename-keys {:a 1} {:z :y})")
                == .map([.keyword("a"): .integer(1)], metadata: nil))
    }

    // MARK: - clojure.walk/keywordize-keys / stringify-keys

    @Test("keywordize-keys/stringify-keys handle nested maps and round-trip")
    func walkKeys() throws {
        #expect(
            try swish.eval(#"(clojure.walk/keywordize-keys {"a" 1 "b" {"c" 2}})"#)
                == .map([.keyword("a"): .integer(1),
                         .keyword("b"): .map([.keyword("c"): .integer(2)], metadata: nil)], metadata: nil))
        #expect(
            try swish.eval(#"(clojure.walk/stringify-keys {:a 1 :b {:c 2}})"#)
                == .map([.string("a"): .integer(1),
                         .string("b"): .map([.string("c"): .integer(2)], metadata: nil)], metadata: nil))
        #expect(
            try swish.eval(#"(= {:a {:b 1}} (clojure.walk/keywordize-keys (clojure.walk/stringify-keys {:a {:b 1}})))"#)
                == .boolean(true))
    }
}
