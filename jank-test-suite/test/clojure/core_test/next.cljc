(ns clojure.core-test.next
  (:require [clojure.test :as t :refer [deftest is are testing]]
            [clojure.core-test.portability #?(:cljs :refer-macros :default :refer) [when-var-exists]]))

(when-var-exists next

  ;; Docstring:
  ;; ([coll])
  ;; Returns a seq of the items after the first. Calls seq on its
  ;; argument.  If there are no more items, returns nil.

  (deftest test-next
    (testing "arity-1"
      (are [expected xs] (= expected (next xs))
        [1 2 3 4 5 6 7 8 9] (range 0 10)
        [2 3 4 5 6 7 8 9] (rest (range 0 10)) ; do it twice
        [2 3] [1 2 3]
        [\e \l \l \o] "hello"
        [1 2 3 4] (int-array (range 5))
        ;; Sorted collections not currently implemented in Basilisp
        #?@(:lpy []
            :default ['([:b 2] [:c 3]) (sorted-map :a 1 :b 2 :c 3)
                      '(:b :c) (sorted-set :a :b :c)])
        nil [1]
        nil '(1)
        nil {:a 1}
        nil #{:a}
        nil (rest "a")
        nil nil
        nil []
        nil '()
        nil {}
        nil #{}
        nil "")

      ;; check unsorted maps and sets
      (is (= 3 (count (next #{1 2 3 4}))))
      (is (= 3 (count (next {:a 1 :b 2 :c 3 :d 4}))))

      ;; infinite lazy seq isn't fully realized
      (is (= 1 (first (next (range))))))

    (testing "exceptions"
      (is (p/thrown? (next 17)))
      (is (p/thrown? (next :a))))))
