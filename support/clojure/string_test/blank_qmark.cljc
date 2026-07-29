(ns clojure.string-test.blank-qmark
  (:require [clojure.string :as str]
            [clojure.test :as t :refer [deftest testing is]]
            [clojure.core-test.portability
             #?(:cljs :refer-macros :default :refer) [when-var-exists] :as p]))

;; Swish-specific overlay for blank_qmark.cljc from the Jank Clojure Test Suite.
;; Swift treats U+2007 (Figure Space) as whitespace, so (str/blank? " ") is
;; true in Swish (like :cljr/:cljs/:lpy) rather than upstream's :default false —
;; the :swish branches below encode that. Kept as a support/ overlay rather than
;; an in-place subtree edit so `git subtree pull` stays conflict-free (the :swish
;; dialect tag is Swish-local, not recognized upstream).

(when-var-exists str/blank?
  (deftest test-blank?
    (is (true? (str/blank? "")))
    (is (true? (str/blank? nil)))
    (is (false? (str/blank? "֎")))
    (testing "U+2007"
      (is (#?(:cljr true? :lpy true? :cljs true? :swish true? :default false?) (str/blank? " ")))
      (is (#?(:cljr true? :lpy true? :cljs true? :swish true? :default false?) (str/blank? "\u2007"))))
    (is (true? (str/blank? "  ")))
    (is (true? (str/blank? " \t ")))
    #?(:cljs (do (is (true? (str/blank? (symbol ""))))
                 (is (false? (str/blank? 'a))))
       :default (is (p/thrown? (str/blank? (symbol "")))))
    #?(:cljs (do (is (false? (str/blank? (keyword ""))))
                 (is (false? (str/blank? :a))))
       :default (is (p/thrown? (str/blank? (keyword "")))))
    #?(:cljs (is (false? (str/blank? 1)))
       :default (is (p/thrown? (str/blank? 1))))
    #?(:lpy (is (true? (str/blank? \space)))
       :cljs (do (is (true? (str/blank? \space)))
                 (is (false? (str/blank? \a))))
       :default (is (p/thrown? (str/blank? \space))))
    (is (false? (str/blank? "nil")))
    (is (false? (str/blank? " as df ")))))
