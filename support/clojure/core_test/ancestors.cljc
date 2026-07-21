(ns clojure.core-test.ancestors
  (:require [clojure.test :refer [are deftest is testing use-fixtures]]
            [clojure.core-test.portability #?(:cljs :refer-macros :default :refer) [when-var-exists]]))

;; Swish-specific overlay for ancestors.cljc from the Jank Clojure Test Suite.
;; Upstream defines top-level vars pointing at raw JVM classes (Object,
;; clojure.lang.PersistentHashSet) to test ancestors' automatic Java-class-
;; inheritance fallback, and separately expects a deftype/defrecord's ancestors
;; to automatically include its protocols via JVM reflection over the
;; generated interface. Swish has no Java class objects and no JVM reflection
;; at all (same root limitation already documented for protocols in
;; CLAUDE.md's Protocols section: "no ancestor-chain fallback"), so those bare
;; class symbols fail to resolve at namespace-load time, before any test even
;; runs. Dropped the AncestorT/ChildT class-reference defs and every testing
;; block that depends on automatic class/protocol-based ancestor discovery.
;; Everything based on explicit `derive` relationships — including using a
;; defrecord's type identity as a plain derive tag, which works fine since
;; Swish represents deftype/defrecord types as keywords — is unchanged.

(when-var-exists ancestors

  ; Some custom types for testing ancestors by derive relationship
  (defprotocol TestAncestorsProtocol)
  (defrecord TestAncestorsRecord [] TestAncestorsProtocol)
  (deftype TestAncestorsType [] TestAncestorsProtocol)

  ; A global hierarchy for testing `ancestors tag` and `ancestors h tag`
  (def global-hierarchy [[TestAncestorsRecord ::record]
                         [::record ::object]
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

  ; A hierarchy for testing `ancestors h tag`
  (def datatypes
    (-> (make-hierarchy)
        (derive TestAncestorsRecord ::datatype)
        (derive TestAncestorsType ::datatype)
        (derive TestAncestorsType ::mutable)
        (derive ::datatype ::type)))

  ; Another hierarchy for testing `ancestors h tag`
  (def diamond
    (-> (make-hierarchy)
        (derive ::b ::a)
        (derive ::c ::a)
        (derive ::d ::b)
        (derive ::d ::c)
        (derive ::leaf ::d)))

  (deftest test-ancestors

    (testing "ancestors tag"

      (testing "returns ancestors by relationship globally defined with derive"
        (are [expected tag] (= expected (ancestors tag))
                            #{::t ::p-1 ::p-2 'ns/p-0} ::leaf
                            #{::p-1 ::p-2 'ns/p-0} ::t
                            #{'ns/p-0} ::p-1
                            nil ::p-2)
        (is (= #{::record ::object} (->> (ancestors TestAncestorsRecord)
                                        (filter keyword?) ; filter out parents by type, tested in next sections
                                        set))))

      (testing "does not throw on invalid tag"
        (are [tag] (nil? (ancestors tag))
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

      (testing "returns only ancestors declared in h, whether the tag is in global hierarchy or not"
        (are [expected h tag] (= expected (->> (ancestors h tag)
                                               (filter keyword?) ; filter out ancestors by type, tested in next sections
                                               set))

                              ; tag in h and not in global hierarchy
                              #{::a ::b ::c} diamond ::d
                              #{::a} diamond ::b
                              #{} diamond ::a
                              #{::datatype ::mutable ::type} datatypes TestAncestorsType

                              ; tag in both h and global hierarchy, only ancestors in h are returned
                              #{::a ::b ::c ::d} diamond ::leaf
                              #{::datatype ::type} datatypes TestAncestorsRecord

                              ; tag not in h but in global hierarchy
                              #{} datatypes ::t
                              #{} datatypes ::p-1
                              #{} datatypes ::p-2

                              ; tag neither in h nor in global hierarchy
                              #{} datatypes ::d
                              #{} datatypes ::b
                              #{} datatypes ::a))

      (testing "does not throw on invalid tag or hierarchy"
        (are [invalid] (nil? (ancestors invalid invalid))
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
