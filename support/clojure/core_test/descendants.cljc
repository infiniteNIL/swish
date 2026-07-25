(ns clojure.core-test.descendants
  (:require [clojure.test :refer [are deftest is testing use-fixtures]]
            [clojure.core-test.portability #?(:cljs :refer-macros :default :refer) [when-var-exists] :as p]))

;; Swish-specific overlay for descendants.cljc from the Jank Clojure Test Suite.
;; Upstream's two "cannot get descendants by type inheritance" blocks assert that
;; `(descendants Object)` throws — real Clojure's descendants throws
;; UnsupportedOperationException ("Can't get descendants of classes") when the tag
;; is a Java class. Swish has no Java class objects at all (same root limitation
;; documented for protocols/ancestors/parents in CLAUDE.md), and now binds `Object`
;; as an ordinary keyword tag (`:Object`, the built-in protocol-dispatch hierarchy
;; root — see CLAUDE.md's Protocols section), so `(descendants Object)` is just
;; `(descendants :Object)`, which returns nil rather than throwing. The class-
;; throwing assertions are therefore dropped here (mirroring the ancestors/parents
;; overlays); the valid `(descendants TestDescendantsProtocol)` => nil check and
;; every derive-relationship test are kept unchanged.

(when-var-exists descendants

  ; Some types for testing descendants by type
  (defprotocol TestDescendantsProtocol)
  (defrecord TestDescendantsRecord [] TestDescendantsProtocol)
  (deftype TestDescendantsType [] TestDescendantsProtocol)

  ; A global hierarchy for testing `descendants tag` and `descendants h tag`
  (def global-hierarchy [[TestDescendantsRecord ::record]
                         [::t ::p-1]
                         [::t ::p-2]
                         [::p-1 'ns/p-0]
                         [::p-2 ::root]
                         ['ns/p-0 ::root]])

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

  ; A hierarchy for testing `descendants h tag`
  (def datatypes
    (-> (make-hierarchy)
        (derive TestDescendantsRecord ::datatype)
        (derive TestDescendantsType ::datatype)
        (derive TestDescendantsType ::mutable)))

  ; Another hierarchy for testing `descendants h tag`
  (def diamond
    (-> (make-hierarchy)
        (derive ::a ::root)
        (derive ::b ::a)
        (derive ::c ::a)
        (derive ::d ::b)
        (derive ::d ::c)))

  (deftest test-descendants

    (testing "descendants tag"

      (testing "returns descendants by relationship globally defined with derive"
        (are [expected tag] (= expected (descendants tag))
                            nil ::t
                            #{::t ::p-1} 'ns/p-0
                            #{::t ::p-1 ::p-2 'ns/p-0} ::root
                            #{::t} ::p-2
                            #{TestDescendantsRecord} ::record))

      ;; Class-throwing assertion dropped (see header); the protocol check stays.
      (testing "cannot get descendants by type inheritance"
        (is (nil? (descendants TestDescendantsProtocol))))

      (testing "does not throw on invalid tag"
        (are [tag] (nil? (descendants tag))
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

    (testing "descendants h tag"

      (testing "returns only descendants declared in h, whether the tag is in global hierarchy or not"
        (are [expected h tag] (= expected (descendants h tag))

                              ; tag in h and not in global hierarchy
                              nil diamond ::d
                              #{::d} diamond ::b
                              #{::b ::c ::d} diamond ::a
                              #{TestDescendantsRecord TestDescendantsType} datatypes ::datatype
                              #{TestDescendantsType} datatypes ::mutable

                              ; tag in both h and global hierarchy, only descendants in h are returned
                              #{::a ::b ::c ::d} diamond ::root

                              ; tag not in h but in global hierarchy
                              nil datatypes ::root
                              nil datatypes ::p-1
                              nil datatypes ::p-2

                              ; tag neither in h nor in global hierarchy
                              nil datatypes ::d
                              nil datatypes ::b
                              nil datatypes ::a))

      ;; Upstream's "cannot get descendants by type inheritance, whether the tag
      ;; is in h or not" block is dropped entirely — it exclusively asserts that
      ;; `(descendants h Object)` throws, which is the class-hierarchy behavior
      ;; Swish has no equivalent of (see header).

      (testing "does not throw on invalid tag or hierarchy"
        (are [invalid] (nil? (descendants invalid invalid))
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
