(ns clojure.core-test.portability
  (:require [clojure.test :as t]))

;; Swish-specific portability shim for the Jank Clojure Test Suite.
;; This file shadows portability.cljc from the test suite itself.
;; Loaded first because support/ comes first on the sourcepath.

(defmacro when-var-exists [var-sym & body]
  (if (resolve var-sym)
    `(do ~@body)
    `(println "SKIP -" '~var-sym)))

(defn big-int? [n] (bigint? n))

(defn lazy-seq? [x]
  (clojure.core/lazy-seq? x))

(defn sleep [_ms] nil)

;; p/thrown? must be a macro so (is (p/thrown? expr)) works:
;; Swish's `is` evaluates the inner form, which expands this macro
;; into a try/catch that returns true on any exception.
(defmacro thrown? [& body]
  `(try (do ~@body) false
     (catch Exception ~'_ true)))
