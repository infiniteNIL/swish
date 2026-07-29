(ns clojure.core-test.with-precision
  (:require [clojure.test :as t :refer [deftest is]]
            [clojure.core-test.portability #?(:cljs :refer-macros :default :refer) [when-var-exists] :as p]))

;; Swish-specific overlay for with_precision.cljc from the Jank Clojure Test
;; Suite. Swish only implements HALF_UP-style rounding (its underlying BigDecimal
;; package has no other mode) and rounds only with-precision's body's final
;; result, so every other :rounding mode throws — the :swish branches below
;; assert that. Kept as a support/ overlay rather than an in-place subtree edit
;; so `git subtree pull` stays conflict-free (the :swish dialect tag is
;; Swish-local, not recognized upstream).

(when-var-exists with-precision
  (deftest test-with-precision
    ;; tests copied from https://clojuredocs.org/clojure.core/with-precision
    ;; Swish only implements HALF_UP-style rounding (its underlying BigDecimal
    ;; package has no other rounding mode) and rounds with-precision's body's
    ;; final result only, not every intermediate BigDecimal operation within it
    ;; (see CLAUDE.md) — any other requested :rounding mode throws. HALF_UP
    ;; itself (including the negative-number case, which exercises a sign-
    ;; related rounding bug found and worked around in the underlying package)
    ;; behaves identically to real Clojure and needs no :swish branch.
    #?(:swish   (is (p/thrown? (with-precision 1 :rounding UP (* 1.1M 1M))))
       :default (is (= 2M (with-precision 1 :rounding UP (* 1.1M 1M)))))
    #?(:swish   (is (p/thrown? (with-precision 1 :rounding CEILING (* 1.1M 1M))))
       :default (is (= 2M (with-precision 1 :rounding CEILING (* 1.1M 1M)))))
    #?(:swish   (is (p/thrown? (with-precision 1 :rounding UP (* -1.1M 1M))))
       :default (is (= -2M (with-precision 1 :rounding UP (* -1.1M 1M)))))
    #?(:swish   (is (p/thrown? (with-precision 1 :rounding CEILING (* -1.1M 1M))))
       :default (is (= -1M (with-precision 1 :rounding CEILING (* -1.1M 1M)))))

    #?(:swish   (is (p/thrown? (with-precision 1 :rounding DOWN (* 1.9M 1M))))
       :default (is (= 1M (with-precision 1 :rounding DOWN (* 1.9M 1M)))))
    #?(:swish   (is (p/thrown? (with-precision 1 :rounding FLOOR (* 1.9M 1M))))
       :default (is (= 1M (with-precision 1 :rounding FLOOR (* 1.9M 1M)))))
    #?(:swish   (is (p/thrown? (with-precision 1 :rounding DOWN (* -1.9M 1M))))
       :default (is (= -1M (with-precision 1 :rounding DOWN (* -1.9M 1M)))))
    #?(:swish   (is (p/thrown? (with-precision 1 :rounding FLOOR (* -1.9M 1M))))
       :default (is (= -2M (with-precision 1 :rounding FLOOR (* -1.9M 1M)))))

    #?(:swish   (is (p/thrown? (with-precision 1 :rounding HALF_EVEN (* 1.5M 1M))))
       :default (is (= 2M (with-precision 1 :rounding HALF_EVEN (* 1.5M 1M)))))
    #?(:swish   (is (p/thrown? (with-precision 1 :rounding HALF_EVEN (* 2.5M 1M))))
       :default (is (= 2M (with-precision 1 :rounding HALF_EVEN (* 2.5M 1M)))))
    #?(:swish   (is (p/thrown? (with-precision 1 :rounding HALF_EVEN (* -1.5M 1M))))
       :default (is (= -2M (with-precision 1 :rounding HALF_EVEN (* -1.5M 1M)))))
    #?(:swish   (is (p/thrown? (with-precision 1 :rounding HALF_EVEN (* -2.5M 1M))))
       :default (is (= -2M (with-precision 1 :rounding HALF_EVEN (* -2.5M 1M)))))

    (is (= 2M (with-precision 1 :rounding HALF_UP (* 1.5M 1M))))
    #?(:swish   (is (p/thrown? (with-precision 1 :rounding HALF_DOWN (* 1.5M 1M))))
       :default (is (= 1M (with-precision 1 :rounding HALF_DOWN (* 1.5M 1M)))))
    (is (= -2M (with-precision 1 :rounding HALF_UP (* -1.5M 1M))))
    #?(:swish   (is (p/thrown? (with-precision 1 :rounding HALF_DOWN (* -1.5M 1M))))
       :default (is (= -1M (with-precision 1 :rounding HALF_DOWN (* -1.5M 1M)))))

    (is (p/thrown? (with-precision 1 :rounding UNNECESSARY (* 1.5M 1M)))) ;; => Execution error (ArithmeticException) at... Rounding necessary
    ;; Swish treats UNNECESSARY as just another unsupported mode and throws
    ;; unconditionally, rather than implementing its real semantics (only throw
    ;; if rounding would actually change the value) — so unlike real Clojure,
    ;; this throws even though 2M already has exactly 1 significant digit.
    #?(:swish   (is (p/thrown? (with-precision 1 :rounding UNNECESSARY (* 2M 1M))))
       :default (is (= 2M (with-precision 1 :rounding UNNECESSARY (* 2M 1M)))))))
