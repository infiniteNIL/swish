import Testing
@testable import SwishKit

// Transliterates the jank Clojure Test Suite's bound_fn.cljc / bound_fn_star.cljc
// "base case" / "Common cases" / "Nested cases" assertions directly, since those
// exact semantics (captured bindings override; ones absent from the capture fall
// through to whatever's active on the calling thread at call time) are the crux
// of a real bug this task fixed in evalLet's environment handling.
@Suite("Core bound-fn Tests", .serialized)
struct CoreBoundFnTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("base case: picks up dynamic vars, and reflects a var not present in its own capture")
    func baseCase() throws {
        #expect(try swish.eval("""
            (def ^:dynamic *bf-a* :unset)
            (defn bf-a-fn [] *bf-a*)
            (def f (bound-fn* bf-a-fn))
            (f)
            """) == .keyword("unset"))
        #expect(try swish.eval("""
            (binding [*bf-a* :set] (f))
            """) == .keyword("set"))
    }

    @Test("Common cases: a captured binding overrides a later rebinding at call time")
    func commonCases() throws {
        #expect(try swish.eval("""
            (def ^:dynamic *bf-b* :unset)
            (defn bf-b-fn [] *bf-b*)
            (binding [*bf-b* :set]
              (let [f (bound-fn* bf-b-fn)]
                (binding [*bf-b* :set-again]
                  (f))))
            """) == .keyword("set"))
    }

    @Test("Nested cases: an outer bound-fn resolves to its own capture, not the inner scope")
    func nestedCases() throws {
        #expect(try swish.eval("""
            (def ^:dynamic *bf-c* :unset)
            (defn bf-c-fn [] *bf-c*)
            (binding [*bf-c* :first]
              (let [f (bound-fn* bf-c-fn)]
                (binding [*bf-c* :second]
                  (let [f (fn [] [(f) ((bound-fn* bf-c-fn))])]
                    (f)))))
            """) == .vector([.keyword("first"), .keyword("second")], metadata: nil))
    }

    @Test("Nested cases: a bound-fn returned from a function preserves its own creation-time binding")
    func nestedCasesPreservesCreationBinding() throws {
        #expect(try swish.eval("""
            (def ^:dynamic *bf-d* :unset)
            (defn bf-d-fn [] *bf-d*)
            (let [f (fn [] (binding [*bf-d* :inside-f] (bound-fn* bf-d-fn)))]
              (binding [*bf-d* :outside-f]
                ((f))))
            """) == .keyword("inside-f"))
    }

    @Test("Threaded case: bound-fn stays bound to its capture even when called from a future")
    func threadedCase() throws {
        #expect(try swish.eval("""
            (def ^:dynamic *bf-e* :unset)
            (defn bf-e-fn [] *bf-e*)
            (def f (bound-fn* bf-e-fn))
            (def fut (future (f)))
            (binding [*bf-e* :here]
              @fut)
            """) == .keyword("unset"))
    }

    @Test("bound-fn macro form works the same as bound-fn*")
    func boundFnMacro() throws {
        #expect(try swish.eval("""
            (def ^:dynamic *bf-f* :unset)
            (def f (bound-fn [] *bf-f*))
            (binding [*bf-f* :set] (f))
            """) == .keyword("set"))
    }
}
