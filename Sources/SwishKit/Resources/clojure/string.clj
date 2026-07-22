(ns clojure.string)

;; join is implemented natively in CoreStringNS.swift (registerClojureStringNatives,
;; called after this namespace loads) — a pure-Clojure version built on interpose/apply
;; was measured to be *slower* than the O(n^2) loop it replaced, because interposing
;; ~2n elements through Swish's lazy-seq/transducer machinery costs far more per
;; element than the string concatenation it avoided (see CLAUDE.md's "Interpreter has
;; a high per-element constant cost for lazy-seq-driven code").
