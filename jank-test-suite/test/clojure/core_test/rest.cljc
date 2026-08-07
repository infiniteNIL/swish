(ns clojure.core-test.rest
  (:require [clojure.test :as t :refer [deftest is are testing]]
            [clojure.core-test.portability :as p #?(:cljs :refer-macros :default :refer) [when-var-exists]]))

(when-var-exists rest

  ;; Docstring:
  ;; ([coll])
  ;; Returns a possibly empty seq of the items after the first. Calls seq on its
  ;; argument.

  (deftest test-rest
    (testing "arity-1"
      (are [expected xs] (= expected (rest xs))
        [1 2 3 4 5 6 7 8 9] (range 0 10)
        [2 3 4 5 6 7 8 9] (rest (range 0 10)) ; do it twice
        [2 3] [1 2 3]
        [\e \l \l \o] "hello"
        [1 2 3 4] (int-array (range 5))
        ;; Sorted collections not currently implemented in Basilisp
        #?@(:lpy []
            :default [[[:b 2] [:c 3]] (sorted-map :a 1 :b 2 :c 3)
                      [:b :c] (sorted-set :a :b :c)])
        [] [1]
        [] '(1)
        [] {:a 1}
        [] #{:a}
        [] (rest "a")
        [] nil
        [] '()
        [] []
        [] "")

      ;; check unsorted maps and sets
      (is (= 2 (count (rest {:a 1 :b 2 :c 3}))))
      (is (= 2 (count (rest #{:a :b :c}))))

      ;; infinite lazy seq
      (is (= 1 (first (rest (range))))))

    (testing "exceptions"
      ;; non-seqable values throw
      (is (p/thrown? (rest 1)))
      (is (p/thrown? (rest :a))))))
