;   Copyright (c) Rich Hickey. All rights reserved.
;   The use and distribution terms for this software are covered by the
;   Eclipse Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php)
;   which can be found in the file epl-v10.html at the root of this distribution.
;   By using this software in any fashion, you are agreeing to be bound by
;   the terms of this license.
;   You must not remove this notice, or any other, from this software.

;;; test.clj: test framework for Clojure

;; by Stuart Sierra
;; March 28, 2009

;; Thanks to Chas Emerick, Allen Rohner, and Stuart Halloway for
;; contributions and suggestions.

;; Remaining Swish adaptations (marked with [Swish]):
;;   - do-report does not add :file/:line — no Java stack trace access
;;   - testing-vars-str does not include file/line
;;   - is macro inlines try/catch (no try-expr/assert-expr multimethod yet)
;;   - are macro uses partition+interleave instead of clojure.template/do-template
;;   - run-tests uses doall+reduce instead of apply merge-with + (lazy-seq robustness)

(ns
  ^{:author "Stuart Sierra, with contributions and suggestions by
  Chas Emerick, Allen Rohner, and Stuart Halloway",
    :doc "A unit testing framework.

   ASSERTIONS

   The core of the library is the \"is\" macro, which lets you make
   assertions of any arbitrary expression:

   (is (= 4 (+ 2 2)))
   (is (.startsWith \"abcde\" \"ab\"))

   DOCUMENTING TESTS

   \"is\" takes an optional second argument, a string describing the
   assertion.  This message will be included in the error report.

   (is (= 5 (+ 2 2)) \"Crazy arithmetic\")

   In addition, you can document groups of assertions with the
   \"testing\" macro, which takes a string followed by any number of
   assertions.  The string will be included in failure reports.
   Calls to \"testing\" may be nested.

   DEFINING TESTS

   (deftest addition
     (is (= 4 (+ 2 2)))
     (is (= 7 (+ 3 4))))

   RUNNING TESTS

   (run-tests 'your.namespace)
   (run-all-tests)

   FIXTURES

   (use-fixtures :each fixture1 fixture2 ...)
   (use-fixtures :once fixture1 fixture2 ...)
   "}
  clojure.test
  (:require [clojure.string :as str]))


;;; USER-MODIFIABLE GLOBALS

(def ^:dynamic
  ^{:doc "True by default.  If set to false, no test functions will
   be created by deftest, set-test, or with-test.  Use this to omit
   tests when compiling or loading production code."
    :added "1.1"}
  *load-tests* true)

(def ^:dynamic
  ^{:doc "The maximum depth of stack traces to print when an Exception
  is thrown during a test.  Defaults to nil, which means print the
  complete stack trace."
    :added "1.1"}
  *stack-trace-depth* nil)


;;; GLOBALS USED BY THE REPORTING FUNCTIONS

(def ^:dynamic *report-counters* nil)       ; [Swish] ref of a map in test-ns

(def ^:dynamic *initial-report-counters*    ; used to initialize *report-counters*
  {:test 0, :pass 0, :fail 0, :error 0})

(def ^:dynamic *testing-vars* (list))       ; bound to hierarchy of vars being tested

(def ^:dynamic *testing-contexts* (list))   ; bound to hierarchy of "testing" strings

(def ^:dynamic *test-out* *out*)            ; output stream for test reporting

(defmacro with-test-out
  "Runs body with *out* bound to the value of *test-out*."
  {:added "1.1"}
  [& body]
  `(binding [*out* *test-out*]
     ~@body))


;;; UTILITIES FOR REPORTING FUNCTIONS

(defn testing-vars-str
  "Returns a string representation of the current test.  Renders names
  in *testing-vars* as a list."
  {:added "1.1"}
  [m]
  ;; [Swish] file/line not available; omit them
  (str (reverse (map #(:name (meta %)) *testing-vars*))))

(defn testing-contexts-str
  "Returns a string representation of the current test context. Joins
  strings in *testing-contexts* with spaces."
  {:added "1.1"}
  []
  (str/join " " (reverse *testing-contexts*)))

(defn inc-report-counter
  "Increments the named counter in *report-counters*, a ref holding a map.
  Does nothing if *report-counters* is nil."
  {:added "1.1"}
  [name]
  (when *report-counters*
    (dosync (commute *report-counters* (fn [m] (assoc m name (inc (get m name 0))))))))


;;; TEST RESULT REPORTING

(defmulti ^{:dynamic true
            :added "1.1"
            :doc "Generic reporting function, may be overridden to plug in
   different report formats (e.g., TAP, JUnit).  Assertions such as
   'is' call 'report' to indicate results.  The argument given to
   'report' will be a map with a :type key.  See the documentation at
   the top of test.clj for more information on the types of
   arguments for 'report'."}
  report :type)

(defmethod report :default [m]
  (with-test-out (prn m)))

(defmethod report :pass [m]
  (with-test-out (inc-report-counter :pass)))

(defmethod report :fail [m]
  (with-test-out
    (inc-report-counter :fail)
    (println "\nFAIL in" (testing-vars-str m))
    (when (seq *testing-contexts*) (println (testing-contexts-str)))
    (when-let [message (:message m)] (println message))
    (println "expected:" (pr-str (:expected m)))
    (println "  actual:" (pr-str (:actual m)))))

(defmethod report :error [m]
  (with-test-out
    (inc-report-counter :error)
    (println "\nERROR in" (testing-vars-str m))
    (when (seq *testing-contexts*) (println (testing-contexts-str)))
    (when-let [message (:message m)] (println message))
    (println "expected:" (pr-str (:expected m)))
    (println "  actual:" (pr-str (:actual m)))))

(defmethod report :summary [m]
  (with-test-out
    (println "\nRan" (:test m) "tests containing"
             (+ (:pass m) (:fail m) (:error m)) "assertions.")
    (println (:fail m) "failures," (:error m) "errors.")))

(defmethod report :begin-test-ns [m]
  (with-test-out
    (println "\nTesting" (ns-name (:ns m)))))

(defmethod report :end-test-ns [m])
(defmethod report :begin-test-var [m])
(defmethod report :end-test-var [m])

(defn do-report
  "Add file and line information to a test result and call report.
   If you are writing a custom assert-expr method, call this function
   to pass test results to report."
  {:added "1.2"}
  [m]
  ;; [Swish] no Java stack trace access; call report directly
  (report m))


;;; ASSERTION MACROS

(defmacro is
  "Generic assertion macro.  'form' is any predicate test.
  'msg' is an optional message to attach to the assertion.

  Example: (is (= 4 (+ 2 2)) \"Two plus two should be 4\")

  Special forms:

  (is (thrown? c body)) checks that an instance of c is thrown from
  body, fails if not; then returns the thing thrown."
  {:added "1.1"}
  ;; [Swish] real clojure.test delegates to try-expr/assert-expr for richer output;
  ;; we inline the try/catch and handle thrown? directly.
  ([form] `(is ~form nil))
  ([form msg]
   (let [p-thrown? (fn [f]
                     (and (seq? f)
                          (let [h (first f)]
                            (or (= h 'p/thrown?)
                                (= h 'clojure.core-test.portability/thrown?)))))]
     (cond
       (or (and (seq? form) (= (first form) 'thrown?)) (p-thrown? form))
       (let [body (if (and (seq? form) (= (first form) 'thrown?)) (drop 2 form) (rest form))]
         `(try ~@body
               (do-report {:type :fail, :message ~msg,
                           :expected '~form, :actual nil})
               (catch Exception e#
                 (do-report {:type :pass, :message ~msg,
                             :expected '~form, :actual e#})
                 e#)))

       (and (seq? form) (= (first form) 'let) (p-thrown? (last form)))
       (let [bindings (second form)
             p-body   (rest (last form))]
         `(try
            (let [~@bindings]
              (try ~@p-body
                (do-report {:type :fail, :message ~msg, :expected '~form, :actual nil})
                (catch Exception e#
                  (do-report {:type :pass, :message ~msg, :expected '~form, :actual e#})
                  e#)))
            (catch Exception outer-e#
              (do-report {:type :pass, :message ~msg, :expected '~form, :actual outer-e#})
              outer-e#)))

       :else
       `(try
          (let [result# ~form]
            (if result#
              (do-report {:type :pass, :message ~msg,
                          :expected '~form, :actual result#})
              (do-report {:type :fail, :message ~msg,
                          :expected '~form, :actual (list '~'not '~form)}))
            result#)
          (catch Exception e#
            (do-report {:type :error, :message ~msg,
                        :expected '~form, :actual e#})
            nil))))))

(defmacro are
  "Checks multiple assertions with a template expression.

  Example: (are [x y] (= x y)
                2 (+ 1 1)
                4 (* 2 2))
  Expands to:
           (do (is (= 2 (+ 1 1)))
               (is (= 4 (* 2 2))))"
  {:added "1.1"}
  [argv expr & args]
  ;; [Swish] real clojure.test uses clojure.template/do-template; we use partition+interleave.
  ;; Nested syntax-quote works in Swish after vector splicing was fixed.
  (if (or (and (empty? argv) (empty? args))
          (and (pos? (count argv))
               (pos? (count args))
               (zero? (mod (count args) (count argv)))))
    `(do ~@(map (fn [group]
                  `(is (let [~@(interleave argv group)] ~expr)))
                (partition (count argv) args)))
    (throw "The number of args doesn't match are's argv.")))

(defmacro testing
  "Adds a new string to the list of testing contexts.  May be nested,
  but must occur inside a test function (deftest)."
  {:added "1.1"}
  [string & body]
  `(binding [*testing-contexts* (conj *testing-contexts* ~string)]
     ~@body))


;;; DEFINING TESTS

(defmacro with-test
  "Takes any definition form (that returns a Var) as the first argument.
  Remaining body goes in the :test metadata function for that Var.

  When *load-tests* is false, only evaluates the definition, ignoring
  the tests."
  {:added "1.1"}
  [definition & body]
  (if *load-tests*
    `(doto ~definition (alter-meta! assoc :test (fn [] ~@body)))
    definition))

(defmacro deftest
  "Defines a test function with no arguments.  Test functions may call
  other tests, so tests may be composed.  If you compose tests, you
  should also define a function named test-ns-hook; run-tests will
  call test-ns-hook instead of testing all vars.

  Note: Actually, the test body goes in the :test metadata on the var,
  and the real function (the value of the var) calls test-var on
  itself.

  When *load-tests* is false, deftest is ignored."
  {:added "1.1"}
  [name & body]
  (when *load-tests*
    `(def ~(vary-meta name assoc :test `(fn [] ~@body))
          (fn [] (test-var (var ~name))))))

(defmacro deftest-
  "Like deftest but creates a private var."
  {:added "1.1"}
  [name & body]
  (when *load-tests*
    `(def ~(vary-meta name assoc :test `(fn [] ~@body) :private true)
          (fn [] (test-var (var ~name))))))

(defmacro set-test
  "Experimental.
  Sets :test metadata of the named var to a fn with the given body.
  The var must already exist.  Does not modify the value of the var.

  When *load-tests* is false, set-test is ignored."
  {:added "1.1"}
  [name & body]
  (when *load-tests*
    `(alter-meta! (var ~name) assoc :test (fn [] ~@body))))


;;; DEFINING FIXTURES

(defn- add-ns-meta
  "Adds elements in coll to the current namespace metadata as the
  value of key."
  {:added "1.1"}
  [key coll]
  (alter-meta! *ns* assoc key coll))

(defmulti use-fixtures
  "Wrap test runs in a fixture function to perform setup and
  teardown. Using a fixture-type of :each wraps every test
  individually, while :once wraps the whole run in a single function."
  {:added "1.1"}
  (fn [fixture-type & args] fixture-type))

(defmethod use-fixtures :each [fixture-type & args]
  (add-ns-meta ::each-fixtures args))

(defmethod use-fixtures :once [fixture-type & args]
  (add-ns-meta ::once-fixtures args))

(defn- default-fixture
  "The default, empty, fixture function.  Just calls its argument."
  {:added "1.1"}
  [f]
  (f))

(defn compose-fixtures
  "Composes two fixture functions, creating a new fixture function
  that combines their behavior."
  {:added "1.1"}
  [f1 f2]
  (fn [g] (f1 (fn [] (f2 g)))))

(defn join-fixtures
  "Composes a collection of fixtures, in order.  Always returns a valid
  fixture function, even if the collection is empty."
  {:added "1.1"}
  [fixtures]
  (reduce compose-fixtures default-fixture fixtures))


;;; RUNNING TESTS: LOW-LEVEL FUNCTIONS

(defn test-var
  "If v has a function in its :test metadata, calls that function,
  with *testing-vars* bound to (conj *testing-vars* v)."
  {:dynamic true, :added "1.1"}
  [v]
  (when-let [t (:test (meta v))]
    (binding [*testing-vars* (conj *testing-vars* v)]
      (do-report {:type :begin-test-var, :var v})
      (inc-report-counter :test)
      (try (t)
           (catch Exception e
             (do-report {:type :error,
                         :message "Uncaught exception, not in assertion."
                         :expected nil, :actual e})))
      (do-report {:type :end-test-var, :var v}))))

(defn test-all-vars
  "Calls test-var on every var with :test metadata interned in the namespace,
  with fixtures applied."
  {:added "1.1"}
  [ns]
  (let [once-fixture-fn (join-fixtures (::once-fixtures (meta ns)))
        each-fixture-fn (join-fixtures (::each-fixtures (meta ns)))]
    (once-fixture-fn
     (fn []
       (doseq [v (vals (ns-interns ns))]
         (when (:test (meta v))
           (each-fixture-fn (fn [] (test-var v)))))))))

(defn test-ns
  "If the namespace defines a function named test-ns-hook, calls that.
  Otherwise, calls test-all-vars on the namespace.  'ns' is a
  namespace object or a symbol.

  Internally binds *report-counters* to a ref initialized to
  *initial-report-counters*.  Returns the final, dereferenced state of
  *report-counters*."
  {:added "1.1"}
  [ns]
  (binding [*report-counters* (ref *initial-report-counters*)]
    (let [ns-obj (the-ns ns)
          hook-var (get (ns-interns ns-obj) (symbol "test-ns-hook"))]
      (do-report {:type :begin-test-ns, :ns ns-obj})
      (if (and hook-var (:test (meta hook-var)))
        ((deref hook-var))
        (test-all-vars ns-obj))
      (do-report {:type :end-test-ns, :ns ns-obj}))
    @*report-counters*))


;;; RUNNING TESTS: HIGH-LEVEL FUNCTIONS

(defn run-tests
  "Runs all tests in the given namespaces; prints results.
  Defaults to current namespace if none given.  Returns a map
  summarizing test results."
  {:added "1.1"}
  ([] (run-tests *ns*))
  ([& namespaces]
   ;; [Swish] use doall+reduce instead of (apply merge-with +) for lazy-seq robustness
   (let [results (doall (map test-ns namespaces))
         merged  (reduce #(merge-with + %1 %2) *initial-report-counters* results)
         summary (assoc merged :type :summary)]
     (do-report summary)
     summary)))

(defn run-all-tests
  "Runs all tests in all namespaces; prints results.
  Optional argument is a regular expression; only namespaces with
  names matching the regular expression (with re-matches) will be
  tested."
  {:added "1.1"}
  ([] (apply run-tests (all-ns)))
  ([re] (apply run-tests (filter #(re-find re (str (ns-name %))) (all-ns)))))

(defn successful?
  "Returns true if the given test summary indicates all tests
  were successful, false otherwise."
  {:added "1.1"}
  [summary]
  (and (zero? (:fail summary 0))
       (zero? (:error summary 0))))
