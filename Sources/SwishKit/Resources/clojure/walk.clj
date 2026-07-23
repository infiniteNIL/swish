;   Copyright (c) Rich Hickey. All rights reserved.
;   The use and distribution terms for this software are covered by the
;   Eclipse Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php)
;   which can be found in the file epl-v10.html at the root of this distribution.
;   By using this software in any fashion, you are agreeing to be bound by
;   the terms of this license.
;   You must not remove this notice, or any other, from this software.

;; walk.clj
;;
;; Utilities for recursively walking a data structure.
;;
;; [Swish] Partial port: only walk/postwalk/postwalk-replace, the three
;; functions clojure.template/do-template actually needs. walk's dispatch
;; is narrowed to list?/vector?/map?/set? — real Clojure's walk also
;; special-cases IMapEntry and IRecord, which only matter when walking
;; *runtime data* (e.g. a defrecord instance or a realized map's entries);
;; a macro template (the only thing this port is used for) is unevaluated
;; reader syntax and is never shaped like either. No prewalk/stringify-keys/
;; keywordize-keys/macroexpand-all — not needed by do-template, not built.
;;
;; [Swish] walk uses reduce, not map, to rebuild each collection, and
;; postwalk recurses directly rather than through partial. map/filter are
;; lazy core.clj defns composing multiple independently-recursing layers
;; (see CLAUDE.md's "high per-element constant cost" note) — for a form as
;; small as a single test assertion this cost is negligible in wall-clock
;; terms, but the *native Swift call-stack depth* it adds per logical
;; recursion level is not: an early version of this file, built the
;; idiomatic-upstream way with map/partial, segfaulted with a stack
;; overflow under Swift Testing's runner thread (which has a smaller
;; default stack than a plain `swift run` process) on nothing deeper than
;; `(p/thrown? (/ x 0))` — reduce (a native, non-lazy Swift function) and
;; direct recursion avoid stacking that extra layered overhead on top of
;; walk's own (unavoidable, but shallow) nesting-depth recursion.

(ns clojure.walk)

(defn walk
  "Traverses form, an arbitrary data structure. inner and outer are
  functions. Applies inner to each element of form, building up a
  data structure of the same type, then applies outer to the result.
  Recognizes list/vector/map/set; everything else is passed to outer
  unchanged."
  {:added "1.1"}
  [inner outer form]
  (cond
    (list? form) (outer (apply list (reduce (fn [acc x] (conj acc (inner x))) [] form)))
    (vector? form) (outer (reduce (fn [acc x] (conj acc (inner x))) [] form))
    (set? form) (outer (reduce (fn [acc x] (conj acc (inner x))) #{} form))
    (map? form) (outer (reduce (fn [acc entry] (assoc acc (inner (key entry)) (inner (val entry)))) {} form))
    :else (outer form)))

(defn postwalk
  "Performs a depth-first, post-order traversal of form. Calls f on
  each sub-form, uses f's return value in place of the original."
  {:added "1.1"}
  [f form]
  (clojure.walk/walk (fn [x] (clojure.walk/postwalk f x)) f form))

(defn postwalk-replace
  "Recursively transforms form by replacing keys in smap with their
  values. Does replacement at the leaves of the tree first."
  {:added "1.1"}
  [smap form]
  (clojure.walk/postwalk (fn [x] (if (contains? smap x) (get smap x) x)) form))
