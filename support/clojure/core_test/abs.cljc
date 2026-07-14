(ns clojure.core-test.abs
  (:require [clojure.test :as t :refer [are deftest is testing]]
            [clojure.core-test.number-range :as r]
            [clojure.core-test.portability :refer [when-var-exists] :as p]))

;; Swish-specific overlay for abs.cljc from the Jank Clojure Test Suite.
;; The upstream :default branch for min-int uses (* -1 r/min-int), which
;; assumes arbitrary-precision integers. Swish uses 64-bit integers (same
;; as JVM Clojure), so abs(Long/MIN_VALUE) == Long/MIN_VALUE.

(when-var-exists abs
  (deftest test-abs
    (testing "common"
     (are [in ex] (= ex (abs in))
       -1              1
       1               1
       -1.0            1.0
       -0.0            0.0
       ##-Inf          ##Inf
       ##Inf           ##Inf
       -123.456M       123.456M
       -123N           123N

       (inc r/min-int) (- (inc r/min-int))

       ;; Swish uses 64-bit integers: abs(Long/MIN_VALUE) == Long/MIN_VALUE
       r/min-int r/min-int
       -1/5 1/5)
     (is (NaN? (abs ##NaN)))
     (is (p/thrown? (abs nil))))

    (testing "unboxed"
      (let [a  42
            b  -42
            a' (abs a)
            b' (abs b)]
        (is (= 42 a'))
        (is (= 42 b'))))))
