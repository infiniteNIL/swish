(ns clojure.core-test.parents
  (:require [clojure.test :refer [are deftest is testing use-fixtures]]
            [clojure.core-test.portability #?(:cljs :refer-macros :default :refer) [when-var-exists]]))

;; Swish-specific overlay for parents.cljc from the Jank Clojure Test Suite.
;; Same reason as the ancestors.cljc overlay: upstream expects parents to
;; automatically include a class's Java superclass/interfaces and a
;; deftype/defrecord's implemented protocols via JVM reflection. Swish has
;; neither JVM classes nor reflection (same limitation already documented for
;; protocols in CLAUDE.md), so those blocks are dropped. Everything based on
;; explicit `derive` relationships is unchanged.

(when-var-exists parents

  ; Some custom types for testing parents by derive relationship
  (defprotocol TestParentsProtocol)
  (defrecord TestParentsRecord [] TestParentsProtocol)
  (deftype TestParentsType [] TestParentsProtocol)

  ; A global hierarchy for testing `parents tag` and `parents h tag`
  (def global-hierarchy [[TestParentsRecord ::record]
                         [::leaf ::t]
                         [::t ::p-1]
                         [::t ::p-2]
                         [::p-1 'ns/p-0]])

  (defn register-global-hierarchy []
    (doseq [[tag parent] global-hierarchy]
      (derive tag parent)))

  (defn unregister-global-hierarchy []
    (doseq [[tag parent] global-hierarchy]
      (underive tag parent)))

  (defn with-global-hierarchy [tests]
    (register-global-hierarchy)
    (tests)
    (unregister-global-hierarchy))

  (use-fixtures :once with-global-hierarchy)

  ; A hierarchy for testing `parents h tag`
  (def datatypes
    (-> (make-hierarchy)
        (derive TestParentsRecord ::datatype)
        (derive TestParentsType ::datatype)
        (derive TestParentsType ::mutable)))

  ; Another hierarchy for testing `parents h tag`
  (def diamond
    (-> (make-hierarchy)
        (derive ::b ::a)
        (derive ::c ::a)
        (derive ::d ::b)
        (derive ::d ::c)
        (derive ::leaf ::d)))

  (deftest test-parents

    (testing "parents tag"

      (testing "returns parents by relationship globally defined with derive"
        (are [expected tag] (= expected (parents tag))
                            #{::t} ::leaf
                            #{::p-1 ::p-2} ::t
                            #{'ns/p-0} ::p-1
                            nil ::p-2)
        (is (contains? (parents TestParentsRecord) ::record)))

      (testing "does not throw on invalid tag"
        (are [tag] (nil? (parents tag))
                   nil
                   "anything"
                   42
                   3.14
                   true
                   false
                   []
                   {}
                   #{}
                   '())))

    (testing "parents h tag"

      (testing "returns only parents declared in h, whether the tag is in global hierarchy or not"
        (are [expected h tag] (= expected (->> (parents h tag)
                                               (filter keyword?) ; filter out parents by type, tested in next sections
                                               set))

                              ; tag in h and not in global hierarchy
                              #{::b ::c} diamond ::d
                              #{::a} diamond ::b
                              #{} diamond ::a
                              #{::datatype ::mutable} datatypes TestParentsType

                              ; tag in both h and global hierarchy, only parents in h are returned
                              #{::d} diamond ::leaf
                              #{::datatype} datatypes TestParentsRecord

                              ; tag not in h but in global hierarchy
                              #{} datatypes ::t
                              #{} datatypes ::p-1
                              #{} datatypes ::p-2

                              ; tag neither in h nor in global hierarchy
                              #{} datatypes ::d
                              #{} datatypes ::b
                              #{} datatypes ::a))

      (testing "does not throw on invalid tag or hierarchy"
        (are [invalid] (nil? (parents invalid invalid))
                       nil
                       "anything"
                       42
                       3.14
                       true
                       false
                       []
                       {}
                       #{}
                       '())))))
