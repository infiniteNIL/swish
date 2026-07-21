import Testing
@testable import SwishKit

@Suite("Multimethod and Hierarchy Tests", .serialized)
struct MultimethodTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - isa? / derive / underive (global hierarchy)

    @Test("isa? is reflexive")
    func isaReflexive() throws {
        #expect(try swish.eval("(isa? :mm/x :mm/x)") == .boolean(true))
    }

    @Test("derive establishes a direct isa? relationship, underive removes it")
    func deriveDirectAndUnderive() throws {
        #expect(try swish.eval("(derive ::mm-circle ::mm-shape)") == .nil)
        #expect(try swish.eval("(isa? ::mm-circle ::mm-shape)") == .boolean(true))
        #expect(try swish.eval("(underive ::mm-circle ::mm-shape)") == .nil)
        #expect(try swish.eval("(isa? ::mm-circle ::mm-shape)") == .boolean(false))
    }

    @Test("derive is transitive through ancestors")
    func deriveTransitive() throws {
        _ = try swish.eval("(derive ::mm-square ::mm-rect)")
        _ = try swish.eval("(derive ::mm-rect ::mm-shape)")
        #expect(try swish.eval("(isa? ::mm-square ::mm-shape)") == .boolean(true))
        #expect(try swish.eval("(parents ::mm-square)") == .set(SwishSet(elements: [.keyword("user/mm-rect")], metadata: nil)))
        #expect(try swish.eval("(ancestors ::mm-square)")
            == .set(SwishSet(elements: [.keyword("user/mm-rect"), .keyword("user/mm-shape")], metadata: nil)))
        #expect(try swish.eval("(descendants ::mm-shape)")
            == .set(SwishSet(elements: [.keyword("user/mm-rect"), .keyword("user/mm-square")], metadata: nil)))
        _ = try swish.eval("(underive ::mm-square ::mm-rect)")
        _ = try swish.eval("(underive ::mm-rect ::mm-shape)")
    }

    @Test("isa? matches vectors elementwise")
    func isaVectorElementwise() throws {
        _ = try swish.eval("(derive ::mm-v-circle ::mm-v-shape)")
        #expect(try swish.eval("(isa? [::mm-v-circle ::mm-v-circle] [::mm-v-shape ::mm-v-shape])") == .boolean(true))
        #expect(try swish.eval("(isa? [::mm-v-circle] [::mm-v-shape ::mm-v-shape])") == .boolean(false))
        _ = try swish.eval("(underive ::mm-v-circle ::mm-v-shape)")
    }

    @Test("derive throws for cyclic derivation")
    func deriveCyclicThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(derive ::mm-cyc ::mm-cyc)") }
        #expect(try swish.eval("""
            (let [h (-> (make-hierarchy) (derive ::mm-a ::mm-b) (derive ::mm-b ::mm-c))]
              (try (derive h ::mm-c ::mm-a) false (catch Exception e true)))
            """) == .boolean(true))
    }

    @Test("derive throws for non-namespaced tag or parent")
    func deriveNonNamespacedThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(derive :mm-plain ::mm-b)") }
        #expect(throws: (any Error).self) { try swish.eval("(derive ::mm-a :mm-plain)") }
    }

    // MARK: - custom hierarchy via make-hierarchy

    @Test("make-hierarchy returns an empty hierarchy map")
    func makeHierarchyEmpty() throws {
        #expect(try swish.eval("(make-hierarchy)")
            == .map(SwishMap(dict: [.keyword("parents"): .map(SwishMap(dict: [:], metadata: nil)),
                                     .keyword("descendants"): .map(SwishMap(dict: [:], metadata: nil)),
                                     .keyword("ancestors"): .map(SwishMap(dict: [:], metadata: nil))], metadata: nil)))
    }

    @Test("derive on a custom hierarchy does not affect the global hierarchy")
    func customHierarchyIsolated() throws {
        #expect(try swish.eval("""
            (let [h (derive (make-hierarchy) ::mm-custom-a ::mm-custom-b)]
              [(isa? h ::mm-custom-a ::mm-custom-b) (isa? ::mm-custom-a ::mm-custom-b)])
            """) == .vector([.boolean(true), .boolean(false)], metadata: nil))
    }

    @Test("derive on an invalid hierarchy shape throws")
    func deriveInvalidHierarchyThrows() throws {
        for h in ["nil", "{}", "42", "true", "::mm-not-a-hierarchy"] {
            #expect(throws: (any Error).self) { try swish.eval("(derive \(h) ::mm-a ::mm-b)") }
        }
    }

    // MARK: - defmulti / defmethod core dispatch

    @Test("exact dispatch value match calls the right method")
    func exactDispatchMatch() throws {
        #expect(try swish.eval("""
            (defmulti mm-area :type)
            (defmethod mm-area :circle [c] (:r c))
            (defmethod mm-area :square [c] (:side c))
            [(mm-area {:type :circle :r 5}) (mm-area {:type :square :side 3})]
            """) == .vector([.integer(5), .integer(3)], metadata: nil))
    }

    @Test("unmatched dispatch value falls back to the :default method")
    func defaultDispatchFallback() throws {
        #expect(try swish.eval("""
            (defmulti mm-fallback :type)
            (defmethod mm-fallback :known [x] :known!)
            (defmethod mm-fallback :default [x] :fell-back)
            (mm-fallback {:type :unknown})
            """) == .keyword("fell-back"))
    }

    @Test("no matching method and no default throws")
    func noMethodThrows() throws {
        #expect(try swish.eval("""
            (defmulti mm-strict :type)
            (defmethod mm-strict :known [x] :ok)
            (try (mm-strict {:type :nope}) false (catch Exception e true))
            """) == .boolean(true))
    }

    @Test("dispatch resolves through a hierarchy relationship")
    func hierarchyDispatch() throws {
        #expect(try swish.eval("""
            (derive ::mm-h-circle ::mm-h-shape)
            (defmulti mm-describe :type)
            (defmethod mm-describe ::mm-h-shape [x] :a-shape)
            (mm-describe {:type ::mm-h-circle})
            """) == .keyword("a-shape"))
    }

    @Test("ambiguous dispatch with no preference throws")
    func ambiguousDispatchThrows() throws {
        #expect(try swish.eval("""
            (defmulti mm-amb (fn [x] x))
            (derive ::mm-amb-child ::mm-amb-base1)
            (derive ::mm-amb-child ::mm-amb-base2)
            (defmethod mm-amb ::mm-amb-base1 [x] :base1)
            (defmethod mm-amb ::mm-amb-base2 [x] :base2)
            (try (mm-amb ::mm-amb-child) false (catch Exception e true))
            """) == .boolean(true))
    }

    @Test("prefer-method resolves an ambiguity")
    func preferMethodResolvesAmbiguity() throws {
        #expect(try swish.eval("""
            (defmulti mm-pref (fn [x] x))
            (derive ::mm-pref-child ::mm-pref-base1)
            (derive ::mm-pref-child ::mm-pref-base2)
            (defmethod mm-pref ::mm-pref-base1 [x] :base1)
            (defmethod mm-pref ::mm-pref-base2 [x] :base2)
            (prefer-method mm-pref ::mm-pref-base1 ::mm-pref-base2)
            (mm-pref ::mm-pref-child)
            """) == .keyword("base1"))
    }

    @Test("multi-arg dispatch function works")
    func multiArgDispatch() throws {
        #expect(try swish.eval("""
            (defmulti mm-combine (fn [a b] [(:type a) (:type b)]))
            (defmethod mm-combine [:x :y] [a b] :xy)
            (mm-combine {:type :x} {:type :y})
            """) == .keyword("xy"))
    }

    // MARK: - introspection / mutation

    @Test("methods returns the current dispatch-value -> fn table")
    func methodsIntrospection() throws {
        #expect(try swish.eval("""
            (defmulti mm-tbl :type)
            (defmethod mm-tbl :a [x] :a!)
            (defmethod mm-tbl :b [x] :b!)
            (set (keys (methods mm-tbl)))
            """) == .set(SwishSet(elements: [.keyword("a"), .keyword("b")], metadata: nil)))
    }

    @Test("get-method returns the resolved fn without invoking it, or nil")
    func getMethodIntrospection() throws {
        #expect(try swish.eval("""
            (defmulti mm-gm :type)
            (defmethod mm-gm :a [x] :a!)
            [(fn? (get-method mm-gm :a)) (nil? (get-method mm-gm :nope))]
            """) == .vector([.boolean(true), .boolean(true)], metadata: nil))
    }

    @Test("remove-method removes a single dispatch value")
    func removeMethod() throws {
        #expect(try swish.eval("""
            (defmulti mm-rm :type)
            (defmethod mm-rm :a [x] :a!)
            (defmethod mm-rm :b [x] :b!)
            (remove-method mm-rm :a)
            [(nil? (get-method mm-rm :a)) (fn? (get-method mm-rm :b))]
            """) == .vector([.boolean(true), .boolean(true)], metadata: nil))
    }

    @Test("remove-all-methods clears the whole table")
    func removeAllMethods() throws {
        #expect(try swish.eval("""
            (defmulti mm-rmall :type)
            (defmethod mm-rmall :a [x] :a!)
            (remove-all-methods mm-rmall)
            (methods mm-rmall)
            """) == .map(SwishMap(dict: [:], metadata: nil)))
    }

    @Test("prefers returns the current preference table")
    func prefersIntrospection() throws {
        #expect(try swish.eval("""
            (defmulti mm-prefs-test (fn [x] x))
            (prefer-method mm-prefs-test :x :y)
            (get (prefers mm-prefs-test) :x)
            """) == .set(SwishSet(elements: [.keyword("y")], metadata: nil)))
    }

    // MARK: - redefinition idempotency

    @Test("re-evaluating defmulti does not wipe already-registered methods")
    func redefiningDefmultiPreservesMethods() throws {
        #expect(try swish.eval("""
            (defmulti mm-stable :type)
            (defmethod mm-stable :x [m] :got-x)
            (defmulti mm-stable :type)
            (mm-stable {:type :x})
            """) == .keyword("got-x"))
    }
}
