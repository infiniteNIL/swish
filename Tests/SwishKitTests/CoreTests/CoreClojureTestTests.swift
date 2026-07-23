import Testing
@testable import SwishKit

@Suite("clojure.test Tests", .serialized)
struct CoreClojureTestTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - ns-interns / all-ns / ns-name

    @Test("ns-interns returns map of interned vars for a namespace")
    func nsInternsReturnsMap() throws {
        let result = try swish.eval("""
            (do
              (ns test-interns-ns)
              (def foo 1)
              (def bar 2)
              (ns user)
              (count (ns-interns 'test-interns-ns)))
            """)
        #expect(result == .integer(2))
    }

    @Test("ns-interns excludes referred vars")
    func nsInternsExcludesReferred() throws {
        let result = try swish.eval("""
            (do
              (ns test-interns-excl)
              (def my-var 99)
              (ns user)
              ;; ns-interns should not include clojure.core refers
              (get (ns-interns 'test-interns-excl) 'my-var))
            """)
        if case .varRef = result { } else {
            Issue.record("Expected varRef, got \(result)")
        }
    }

    @Test("all-ns returns a sequence containing clojure.core")
    func allNsContainsCore() throws {
        let result = try swish.eval("""
            (some #(= (ns-name %) 'clojure.core) (all-ns))
            """)
        #expect(result == .boolean(true))
    }

    @Test("ns-name returns symbol from namespace object")
    func nsNameReturnsSymbol() throws {
        let result = try swish.eval("(ns-name (find-ns 'clojure.core))")
        #expect(result == .symbol("clojure.core", metadata: nil))
    }

    // MARK: - clojure.test loading

    @Test("require clojure.test loads without error")
    func requireClojureTest() throws {
        #expect(throws: Never.self) {
            try swish.eval("(require '[clojure.test :refer [deftest is testing are run-tests]])")
        }
    }

    // MARK: - is macro

    @Test("is with passing assertion reports :pass")
    func isPassingAssertion() throws {
        let result = try swish.eval("""
            (do
              (require '[clojure.test :as t])
              (let [counters (ref {:test 0 :pass 0 :fail 0 :error 0})]
                (binding [t/*report-counters* counters]
                  (t/is (= 1 1)))
                (:pass @counters)))
            """)
        #expect(result == .integer(1))
    }

    @Test("is with failing assertion reports :fail")
    func isFailingAssertion() throws {
        let result = try swish.eval("""
            (do
              (require '[clojure.test :as t])
              (let [counters (ref {:test 0 :pass 0 :fail 0 :error 0})]
                (binding [t/*report-counters* counters
                          t/*test-out* *out*]
                  (t/is (= 1 2)))
                (:fail @counters)))
            """)
        #expect(result == .integer(1))
    }

    @Test("is with optional message still reports correctly")
    func isWithMessage() throws {
        let result = try swish.eval("""
            (do
              (require '[clojure.test :as t])
              (let [counters (ref {:test 0 :pass 0 :fail 0 :error 0})]
                (binding [t/*report-counters* counters]
                  (t/is (= 2 2) "two equals two"))
                (:pass @counters)))
            """)
        #expect(result == .integer(1))
    }

    @Test("is with exception in body reports :error")
    func isErrorOnException() throws {
        let result = try swish.eval("""
            (do
              (require '[clojure.test :as t])
              (let [counters (ref {:test 0 :pass 0 :fail 0 :error 0})]
                (binding [t/*report-counters* counters
                          t/*test-out* *out*]
                  (t/is (throw "boom")))
                (:error @counters)))
            """)
        #expect(result == .integer(1))
    }

    // MARK: - assert-expr / try-expr

    @Test("is default fallback (:default assert-expr) shows the quoted form, not a re-evaluated boolean")
    func isDefaultFallbackShowsQuotedForm() throws {
        let result = try swish.eval("""
            (do
              (require '[clojure.test :as t])
              (let [captured (atom nil)]
                (binding [t/report (fn [m] (reset! captured m))]
                  (t/is (odd? 4)))
                (= (:actual @captured) '(not (odd? 4)))))
            """)
        #expect(result == .boolean(true))
    }

    @Test("is = comparison (assert-expr '=) reports real evaluated values, not source symbols")
    func isEqualityShowsEvaluatedValues() throws {
        let result = try swish.eval("""
            (do
              (require '[clojure.test :as t])
              (let [captured (atom nil)
                    x 5
                    y 4]
                (binding [t/report (fn [m] (reset! captured m))]
                  (t/is (= x y)))
                [(= (:expected @captured) '(= x y))
                 (= (:actual @captured) '(not (= 5 4)))]))
            """)
        if case .vector(let elems, _) = result {
            #expect(elems[0] == .boolean(true))
            #expect(elems[1] == .boolean(true))
        } else {
            Issue.record("Expected vector result, got \(result)")
        }
    }

    @Test("is = comparison on pass reports evaluated values via cons, not the raw truthy result")
    func isEqualityPassReportsConsedValues() throws {
        let result = try swish.eval("""
            (do
              (require '[clojure.test :as t])
              (let [captured (atom nil)]
                (binding [t/report (fn [m] (reset! captured m))]
                  (t/is (= 5 5)))
                (= (:actual @captured) '(= 5 5))))
            """)
        #expect(result == .boolean(true))
    }

    @Test("is bare thrown? still passes after assert-expr refactor — untouched branch")
    func isThrownBareStillPasses() throws {
        let result = try swish.eval("""
            (do
              (require '[clojure.test :as t])
              (let [counters (ref {:test 0 :pass 0 :fail 0 :error 0})]
                (binding [t/*report-counters* counters
                          t/*test-out* *out*]
                  (t/is (thrown? Exception (throw "boom"))))
                (:pass @counters)))
            """)
        #expect(result == .integer(1))
    }

    @Test("are + let-wrapped p/thrown?-shaped form still passes after assert-expr refactor — untouched branch")
    func areWithLetWrappedThrownShapeStillPasses() throws {
        let result = try swish.eval("""
            (do
              (require '[clojure.test :as t])
              (let [counters (ref {:test 0 :pass 0 :fail 0 :error 0})]
                (binding [t/*report-counters* counters
                          t/*test-out* *out*]
                  (t/are [x] (p/thrown? (/ x 0)) 1 2 3))
                (:pass @counters)))
            """)
        #expect(result == .integer(3))
    }

    // MARK: - are macro

    @Test("are expands to multiple is assertions")
    func areExpandsToMultipleAssertions() throws {
        let result = try swish.eval("""
            (do
              (require '[clojure.test :as t])
              (let [counters (ref {:test 0 :pass 0 :fail 0 :error 0})]
                (binding [t/*report-counters* counters]
                  (t/are [x y] (= x y)
                    1 1
                    2 2
                    3 3))
                (:pass @counters)))
            """)
        #expect(result == .integer(3))
    }

    @Test("are reports fail for non-matching pairs")
    func areReportsFailsForNonMatches() throws {
        let result = try swish.eval("""
            (do
              (require '[clojure.test :as t])
              (let [counters (ref {:test 0 :pass 0 :fail 0 :error 0})]
                (binding [t/*report-counters* counters
                          t/*test-out* *out*]
                  (t/are [x y] (= x y)
                    1 1
                    2 99))
                [(:pass @counters) (:fail @counters)]))
            """)
        // 1 pass, 1 fail — check both are non-zero
        if case .list(let elems, _) = result {
            #expect(elems[0] == .integer(1))
            #expect(elems[1] == .integer(1))
        } else {
            // Vector form also acceptable
            if case .vector(let elems, _) = result {
                #expect(elems[0] == .integer(1))
                #expect(elems[1] == .integer(1))
            }
        }
    }

    // MARK: - testing macro

    @Test("testing adds context string to *testing-contexts*")
    func testingAddsContext() throws {
        let result = try swish.eval("""
            (do
              (require '[clojure.test :as t])
              (let [captured (atom nil)]
                (binding [t/*testing-contexts* (list)]
                  (t/testing "my context"
                    (reset! captured t/*testing-contexts*)))
                (first @captured)))
            """)
        #expect(result == .string("my context"))
    }

    // MARK: - deftest and run-tests

    @Test("deftest creates a function whose :test metadata is set")
    func deftestCreatesTestMetadata() throws {
        let result = try swish.eval("""
            (ns test-deftest-ns
              (:require [clojure.test :refer [deftest is]]))
            (deftest my-sample-test
              (is (= 1 1)))
            (some? (:test (meta #'my-sample-test)))
            """)
        #expect(result == .boolean(true))
    }

    @Test("run-tests returns summary map with correct counts")
    func runTestsReturnsSummary() throws {
        let result = try swish.eval("""
            (ns test-run-ns
              (:require [clojure.test :refer [deftest is run-tests]]))
            (deftest passing-test (is (= 1 1)) (is (= 2 2)))
            (deftest failing-test (is (= 1 2)))
            (let [summary (binding [clojure.test/*test-out* *out*]
                            (run-tests 'test-run-ns))]
              [(:test summary) (:pass summary) (:fail summary) (:error summary)])
            """)
        if case .vector(let elems, _) = result {
            #expect(elems[0] == .integer(2))  // 2 tests
            #expect(elems[1] == .integer(2))  // 2 passes
            #expect(elems[2] == .integer(1))  // 1 failure
            #expect(elems[3] == .integer(0))  // 0 errors
        } else {
            Issue.record("Expected vector result, got \(result)")
        }
    }

    @Test("successful? returns true when no failures or errors")
    func successfulReturnsTrueForCleanRun() throws {
        let result = try swish.eval("""
            (ns test-success-ns
              (:require [clojure.test :refer [deftest is run-tests successful?]]))
            (deftest all-pass (is (= 1 1)))
            (let [summary (binding [clojure.test/*test-out* *out*]
                            (run-tests 'test-success-ns))]
              (successful? summary))
            """)
        #expect(result == .boolean(true))
    }
}
