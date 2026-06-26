(ns clojure.core-test.reduce
  (:require [clojure.test :as t :refer [deftest is testing]]
            [clojure.core-test.portability :refer [when-var-exists] :as p]))

;; Swish-specific overlay for reduce.cljc from the Jank Clojure Test Suite.
;; The upstream file has no :swish or :default branches in its interop map,
;; which produces a malformed map literal when no platform key matches.

(def interop
  {:int-new int
   :Integer nil
   :Long    nil
   :Float   nil
   :Double  nil
   :Boolean nil})

(when-var-exists reduce
  (deftest test-reduce
    (testing "common"
      (is (nil? (reduce nil nil nil)))
      (is (p/thrown? (reduce nil nil)))
      (is (= 6 (reduce + 0 [1 2 3]))))

    (testing "val is not supplied"
      (is (= 3 (reduce (fn [a b]
                         (+ a b))
                       [1 2])))

      (testing "empty coll"
        (is (= 1 (reduce (fn [] 1) []))))

      (testing "coll with 1 item"
        (is (= 1 (reduce (fn []
                           (is false)
                           (throw (ex-info "should not get here" {})))
                         [1])))))

    (testing "val is supplied, empty coll"
      (is (= 1 (reduce (fn []
                           (is false)
                         (throw (ex-info "should not get here" {})))
                       1
                       []))))

    (when-var-exists into-array
      (testing "reduction by type"
        (let [int-new (interop :int-new)
              arange (range 1 100)
              avec (into [] arange)
              alist (into () arange)
              obj-array (into-array arange)
              int-array (into-array (:Integer interop) (map #(int-new (int %)) arange))
              long-array (into-array (:Long interop) arange)
              float-array (into-array (:Float interop) arange)
              double-array (into-array (:Double interop) arange)
              all-true (into-array (:Boolean interop) (repeat 10 true))]

          (testing "val is not supplied"
            (is (== 4950
                    (reduce + arange)
                    (reduce + avec)
                    (reduce + alist)
                    (reduce + obj-array)
                    (reduce + int-array)
                    (reduce + long-array)
                    (reduce + float-array)
                    (reduce + double-array))))

          (testing "val is supplied"
            (is (== 4951
                    (reduce + 1 arange)
                    (reduce + 1 avec)
                    (reduce + 1 alist)
                    (reduce + 1 obj-array)
                    (reduce + 1 int-array)
                    (reduce + 1 long-array)
                    (reduce + 1 float-array)
                    (reduce + 1 double-array))))

          (is (= true
                 (reduce #(and %1 %2) all-true)
                 (reduce #(and %1 %2) true all-true))))))))
