import Testing
@testable import SwishKit

@Suite("Missing Core Forms Tests", .serialized)
struct MissingCoreFormsTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - split-at

    @Test("split-at returns a 2-vector of take/drop")
    func splitAtBasic() throws {
        #expect(
            try swish.eval("(split-at 2 [1 2 3 4 5])")
                == .vector([.list([.integer(1), .integer(2)], metadata: nil), .list([.integer(3), .integer(4), .integer(5)], metadata: nil)], metadata: nil))
    }

    @Test("split-at n=0 returns empty first half")
    func splitAtZero() throws {
        #expect(try swish.eval("(first (split-at 0 [1 2 3]))") == .list([], metadata: nil))
    }

    @Test("split-at n>=count returns empty second half")
    func splitAtBeyondCount() throws {
        #expect(try swish.eval("(second (split-at 10 [1 2 3]))") == .list([], metadata: nil))
    }

    // MARK: - dotimes

    @Test("dotimes runs body n times with indices 0..<n")
    func dotimesRunsWithIndices() throws {
        #expect(
            try swish.eval("(let [a (atom [])] (dotimes [i 3] (swap! a conj i)) @a)")
                == .vector([.integer(0), .integer(1), .integer(2)], metadata: nil))
    }

    @Test("dotimes with n=0 runs zero times")
    func dotimesZero() throws {
        #expect(try swish.eval("(let [a (atom 0)] (dotimes [i 0] (swap! a inc)) @a)") == .integer(0))
    }

    // MARK: - while

    @Test("while runs until test goes false")
    func whileRunsUntilFalse() throws {
        #expect(try swish.eval("(let [a (atom 0)] (while (< @a 5) (swap! a inc)) @a)") == .integer(5))
    }

    @Test("while with initially-false test runs zero times")
    func whileInitiallyFalse() throws {
        #expect(try swish.eval("(let [a (atom 0)] (while false (swap! a inc)) @a)") == .integer(0))
    }

    // MARK: - condp

    @Test("condp binary clause matches and returns result-expr")
    func condpBinaryMatch() throws {
        #expect(try swish.eval("(condp = 2 1 :one 2 :two 3 :three)") == .keyword("two"))
    }

    @Test("condp :>> ternary clause calls result-fn with predicate's result")
    func condpArrowMatch() throws {
        #expect(
            try swish.eval("(condp #(re-find %1 %2) \"abc123\" #\"\\d+\" :>> (fn [m] (str \"matched:\" m)) :none)")
                == .string("matched:123"))
    }

    @Test("condp falls through to a trailing default expression")
    func condpDefault() throws {
        #expect(try swish.eval("(condp = 9 1 :one 2 :two :other)") == .keyword("other"))
    }

    @Test("condp with no match and no default throws")
    func condpNoMatchThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(condp = 9 1 :one 2 :two)") }
    }

    // MARK: - declare

    @Test("declare creates a var referenceable before its later def")
    func declareForwardReference() throws {
        #expect(
            try swish.eval("""
                (do
                  (declare mcf-fwd-var)
                  (defn mcf-uses-fwd [] mcf-fwd-var)
                  (def mcf-fwd-var 42)
                  (mcf-uses-fwd))
                """) == .integer(42))
    }

    // MARK: - cond-> / cond->>

    @Test("cond-> threads only true-tested steps, no short-circuit")
    func condArrowThreadsTrueSteps() throws {
        #expect(try swish.eval("(cond-> 1 true inc false (* 42) true inc)") == .integer(3))
    }

    @Test("cond-> with no true tests returns expr unchanged")
    func condArrowAllFalse() throws {
        #expect(try swish.eval("(cond-> 1 false inc false (* 42))") == .integer(1))
    }

    @Test("cond->> threads via ->> (form last, not first)")
    func condArrowArrowThreadsViaAppend() throws {
        #expect(try swish.eval("(cond->> [2 3] true (cons 1))") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    // MARK: - as->

    @Test("as-> threads through forms using the bound name at arbitrary positions")
    func asArrowArbitraryPosition() throws {
        #expect(try swish.eval("(as-> [1 2 3] v (map inc v) (reduce + v) (- v 1))") == .integer(8))
    }

    // MARK: - some-> / some->>

    @Test("some-> short-circuits to nil on the first nil step")
    func someArrowShortCircuits() throws {
        #expect(try swish.eval("(some-> {:a 1} :b :c)") == .nil)
    }

    @Test("some-> threads through non-nil steps")
    func someArrowThreadsNonNil() throws {
        #expect(try swish.eval("(some-> {:a {:b 2}} :a :b inc)") == .integer(3))
    }

    @Test("some->> short-circuits to nil on the first nil step")
    func someArrowArrowShortCircuits() throws {
        #expect(try swish.eval("(some->> [1 2 3] (map inc) (drop 5) first)") == .nil)
    }

    @Test("some->> threads through non-nil steps")
    func someArrowArrowThreadsNonNil() throws {
        #expect(try swish.eval("(some->> [1 2 3] (map inc) reverse first)") == .integer(4))
    }

    // MARK: - memoize

    @Test("memoize only invokes the underlying fn once per distinct args")
    func memoizeCachesPerArgs() throws {
        #expect(
            try swish.eval("""
                (let [calls (atom 0)
                      f (memoize (fn [x] (swap! calls inc) (* x x)))]
                  (f 5) (f 5) (f 5) (f 6)
                  @calls)
                """) == .integer(2))
    }

    @Test("memoize correctly caches an actual nil return, not just re-invoking every time")
    func memoizeCachesNilReturn() throws {
        #expect(
            try swish.eval("""
                (let [calls (atom 0)
                      f (memoize (fn [x] (swap! calls inc) nil))]
                  (f 5) (f 5)
                  @calls)
                """) == .integer(1))
    }

    // MARK: - trampoline

    @Test("trampoline resolves mutual recursion at a depth that would stack-overflow directly")
    func trampolineAvoidsStackOverflow() throws {
        #expect(
            try swish.eval("""
                (letfn [(mcf-even? [n] (if (zero? n) true (fn [] (mcf-odd? (dec n)))))
                        (mcf-odd? [n] (if (zero? n) false (fn [] (mcf-even? (dec n)))))]
                  (trampoline mcf-even? 20000))
                """) == .boolean(true))
    }

    @Test("trampoline with extra args form")
    func trampolineWithArgs() throws {
        #expect(try swish.eval("(trampoline (fn [x y] (+ x y)) 3 4)") == .integer(7))
    }
}
