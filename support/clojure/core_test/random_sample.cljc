(ns clojure.core-test.random-sample
  (:require [clojure.test :as t :refer [are deftest is testing]]
            [clojure.core-test.portability #?(:cljs :refer-macros :default :refer) [when-var-exists] :as p]))

;; Swish-specific overlay for random_sample.cljc from the Jank Clojure Test
;; Suite. The only change from upstream is nitems: 10000 -> 1000. Swish's
;; tree-walking interpreter costs roughly 300-475us per lazy-seq element
;; (see CLAUDE.md's "Interpreter has a high per-element constant cost"
;; section) — at the upstream nitems, this single fixture (10 draws across
;; ~8 prob/coll/transducer-form combinations, each walking up to 10000
;; elements) took ~148 seconds on its own, dominating the entire jank suite
;; run. Every prob/coll/nil/empty/transducer-form code path below is
;; otherwise identical to upstream — this only shrinks the collection size,
;; not the coverage.

(when-var-exists random-sample

  (defn check
    [nitems xs]
    ;; check that subsets are not constant
    (is (> (count (set xs)) 1))
    ;; check that every subset has a size between 0 and the size of
    ;; the original collection (nitems)
    (is (every? #(and (>= (count %) 0)
                      (< (count %) nitems))
                xs))
    ;; check that every item of every subset is an item in the
    ;; original collection
    (is (every? (fn [sub]
                  (every? (fn [item]
                            (and (>= item 0)
                                 (< item nitems)))
                          sub))
                xs)))

  (deftest test-random-sample
    ;; Multiple calls to random-sample should return non-constant
    ;; subsets If all the items in the collection are unique, every
    ;; item in the subset should be unique and be one of the items in
    ;; the collection. Length of each subset should be between 0 and
    ;; the length of the original collection.
    (let [draws 10
          nitems 1000
          coll (doall (range nitems))
          prob 0.5]
      (testing "positive tests"
        (check nitems (repeatedly draws #(random-sample prob coll)))
        (check nitems (repeatedly draws #(transduce (random-sample prob) conj [] coll)))
        ;; if probability is 0, then the result is always an empty seq
        (is (every? (comp nil? seq) (repeatedly draws #(random-sample 0 coll))))
        (is (every? (comp nil? seq) (repeatedly draws #(transduce (random-sample 0) conj [] coll))))
        ;; if probability is 1, then the result is always the input collection
        (is (every? #(= % coll) (repeatedly draws #(random-sample 1 coll))))
        (is (every? #(= % coll) (repeatedly draws #(transduce (random-sample 1) conj [] coll))))
        ;; if input collection is empty, then the result is always empty
        (is (every? (comp nil? seq) (repeatedly draws #(random-sample 1 []))))
        (is (every? (comp nil? seq) (repeatedly draws #(transduce (random-sample 1) conj [] [])))))

      (testing "negative tests"
        ;; if probablity is < 0, always empty
        (is (every? (comp nil? seq) (repeatedly draws #(random-sample -1 coll))))
        (is (every? (comp nil? seq) (repeatedly draws #(transduce (random-sample -1) conj [] coll))))
        ;; if probability is > 1, then the result is always the input collection
        (is (every? #(= % coll) (repeatedly draws #(random-sample 10 coll))))
        (is (every? #(= % coll) (repeatedly draws #(transduce (random-sample 10) conj [] coll))))
        ;; if nil as input collection, then the result is always empty
        (is (every? (comp nil? seq) (repeatedly draws #(random-sample -1 nil))))
        (is (every? (comp nil? seq) (repeatedly draws #(transduce (random-sample -1) conj [] nil))))

        #?(:cljs (is (nil? (seq (random-sample nil coll))))
           :default (is (p/thrown? (seq (random-sample nil coll)))))
        (is (p/thrown? (seq (random-sample 0.5 42))))
        (is (p/thrown? (seq (random-sample 0.5 :foo))))))))
