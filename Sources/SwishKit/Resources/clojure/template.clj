;   Copyright (c) Rich Hickey. All rights reserved.
;   The use and distribution terms for this software are covered by the
;   Eclipse Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php)
;   which can be found in the file epl-v10.html at the root of this distribution.
;   By using this software in any fashion, you are agreeing to be bound by
;   the terms of this license.
;   You must not remove this notice, or any other, from this software.

;; template.clj: Macros that expand to repeated copies of a template
;; expression.

;; [Swish] apply-template/do-template reference clojure.walk/postwalk-replace
;; and clojure.template/apply-template fully qualified rather than via the
;; :as walk require alias or bare — a cross-function reference that appears
;; either inside an ordinary (non-defmacro) function body or inside an
;; unquoted ~/~@ sub-expression nested in a defmacro's own syntax-quote
;; template isn't pre-qualified to its defining namespace the way a literal
;; symbol embedded directly in a defmacro's template is (preExpandSyntaxQuote
;; only handles the latter). See CLAUDE.md's note on this for the full
;; explanation — this is the second time this exact shape has come up
;; (clojure.test/assert-expr's defmethod bodies were the first).

(ns clojure.template
  (:require [clojure.walk :as walk]))

(defn apply-template
  "For use in macros. argv is an argument list, as in defn. expr is
  a quoted expression using the symbols in argv. values is a sequence
  of values to be used for the arguments.

  apply-template will recursively replace argument symbols in expr
  with their corresponding values, returning a modified expr.

  Example: (apply-template '[x] '(+ x x) '[2])
           ;=> (+ 2 2)"
  {:added "1.1"}
  [argv expr values]
  (assert (vector? argv))
  (assert (every? symbol? argv))
  (clojure.walk/postwalk-replace (zipmap argv values) expr))

(defmacro do-template
  "Repeatedly copies expr (in a do block) for each group of arguments
  in values. values are automatically partitioned by the number of
  arguments in argv, an argument vector as in defn.

  Example: (macroexpand '(do-template [x y] (+ y x) 2 4 3 5))
           ;=> (do (+ 4 2) (+ 5 3))"
  {:added "1.1"}
  [argv expr & values]
  (let [c (count argv)]
    `(do ~@(map (fn [a] (clojure.template/apply-template argv expr a))
                (partition c values)))))
