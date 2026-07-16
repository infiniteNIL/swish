(ns clojure.core-test.format
  (:require [clojure.test :as t :refer [deftest is]]
            [clojure.core-test.portability #?(:cljs :refer-macros :default :refer) [when-var-exists]]))

;; Swish-specific overlay for format.cljc from the Jank Clojure Test Suite.
;; The upstream fixture is deliberately conservative (per its own comment,
;; preserved below) since format compatibility varies across Clojure
;; implementations. Swish's format delegates to Foundation's
;; String(format:) rather than Java's java.util.Formatter (there's no JVM
;; to delegate to) — see CLAUDE.md's Known Limitations for the specific
;; divergences. This :swish branch exercises Swish's actual,
;; empirically-verified behavior for %s and %d rather than assuming Java
;; compatibility.
;;
;;; Note that `format` presents a bit of a conundrum for
;;; testing. Clojure JVM delegates the formatting task to
;;; Java. ClojureScript doesn't implement `format`. Other Clojure
;;; implementations may take different paths. Even when `format` is
;;; implemented, the full scope of Java's `java.util.Formatter`
;;; functionality may not be there. Thus, we take a very conservative
;;; approach here for the default case of just testing to verify that
;;; the function exists and that a simple format string with no escape
;;; characters passes through `format` unharmed.
;;; See: https://clojurians.slack.com/archives/C03SRH97FDK/p1733853098700809

(when-var-exists format
 (deftest test-format
   #?@(:swish
       [(is (= "test" (format "test")))
        (is (= "hello" (format "%s" "hello")))
        (is (= "42" (format "%s" 42)))
        (is (= "42" (format "%d" 42)))
        (is (= "foo and 7" (format "%s and %d" "foo" 7)))]

       :lpy
       [(is (= "test" (format "test")))
        (is (= "1" (format "%s" 1)))]

       :cljs ; CLJS doesn't have `format`
       []

       :default
       [(is (= "test" (format "test")))])))
