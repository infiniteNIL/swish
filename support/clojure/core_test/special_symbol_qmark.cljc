(ns clojure.core-test.special-symbol-qmark
  (:require [clojure.test :refer [deftest testing are]]
            [clojure.core-test.portability #?(:cljs :refer-macros :default :refer) [when-var-exists]]))

;; Swish-specific overlay for special_symbol_qmark.cljc from the Jank Clojure
;; Test Suite. The upstream "special symbols" block is
;;   (are [arg] (special-symbol? 'arg) & case* new ...)
;; Real Clojure's `are` (via clojure.template/do-template) does textual
;; substitution: it replaces `arg` with each template value everywhere in the
;; expression, including inside `quote`, so `'arg` becomes `'&`, `'case*`,
;; etc. before evaluation. Swish's `are` is not do-template-based (see
;; CLAUDE.md's "clojure.test/are uses a partition+interleave expansion
;; instead" note) — it expands to `(let [arg <value>] (special-symbol? 'arg))`,
;; and `let` cannot reach inside a `quote`: `'arg` always evaluates to the
;; literal symbol `arg` regardless of what `arg` is bound to, so every
;; substituted bare symbol (&, case*, new, ...) is evaluated as a variable
;; reference instead, throwing "Undefined symbol". Rewritten to quote each
;; value in the template arguments instead of quoting inside the template
;; expression — an identical set of assertions, just restructured to work
;; with let-based expansion instead of relying on substitution-inside-quote.
;; The "not special symbols" block below is unaffected (its template already
;; quotes the values, not a bare template variable) and is copied unchanged.

(when-var-exists special-symbol?
  (deftest test-special-symbol?

    (testing "special symbols"
      (are [arg] (special-symbol? arg)
                 '&
                 'case*
                 'new
                 '.
                 'deftype*
                 'fn*
                 'let*
                 'letfn*
                 'loop*
                 'set!
                 'catch
                 'def
                 'do
                 'finally
                 'if
                 'quote
                 'recur
                 'throw
                 'try
                 'var))

    (testing "not special symbols"
      (are [arg] (not (special-symbol? arg))
                 'a-symbol
                 'a-ns/a-qualified-symbol
                 'defn
                 'import
                 "not a symbol"
                 :k
                 0
                 0.0
                 true
                 false
                 nil))))
