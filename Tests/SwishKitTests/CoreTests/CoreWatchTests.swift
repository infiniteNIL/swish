import Testing
@testable import SwishKit

@Suite("Core Watch Tests", .serialized)
struct CoreWatchTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - add-watch / remove-watch on atoms

    @Test("add-watch returns the atom")
    func addWatchReturnsAtom() throws {
        #expect(try swish.eval("(def a (atom 1)) (= a (add-watch a :k identity))") == .boolean(true))
    }

    @Test("watch fires on reset!")
    func watchFiresOnReset() throws {
        #expect(try swish.eval("""
            (def log (atom nil))
            (def a (atom 1))
            (add-watch a :k (fn [k r o n] (reset! log [k o n])))
            (reset! a 9)
            @log
            """) == .vector([.keyword("k"), .integer(1), .integer(9)], metadata: nil))
    }

    @Test("watch fires on swap!")
    func watchFiresOnSwap() throws {
        #expect(try swish.eval("""
            (def log (atom nil))
            (def a (atom 1))
            (add-watch a :k (fn [k r o n] (reset! log [k o n])))
            (swap! a inc)
            @log
            """) == .vector([.keyword("k"), .integer(1), .integer(2)], metadata: nil))
    }

    @Test("watch fn receives (key ref old new) with ref identical to the atom")
    func watchReceivesCorrectArgs() throws {
        #expect(try swish.eval("""
            (def calls (atom []))
            (def a (atom 1))
            (add-watch a :k (fn [k r o n] (swap! calls conj [k (= r a) o n])))
            (swap! a inc)
            @calls
            """) == .vector([.vector([.keyword("k"), .boolean(true), .integer(1), .integer(2)], metadata: nil)], metadata: nil))
    }

    @Test("atom's value is already committed when the watch fires")
    func watchSeesCommittedValue() throws {
        #expect(try swish.eval("""
            (def log (atom nil))
            (def a (atom 1))
            (add-watch a :k (fn [k r o n] (reset! log @r)))
            (swap! a inc)
            @log
            """) == .integer(2))
    }

    @Test("re-adding a watch with the same key replaces it, not duplicates it")
    func rekeyingReplacesWatch() throws {
        #expect(try swish.eval("""
            (def calls (atom []))
            (def a (atom 1))
            (add-watch a :k (fn [k r o n] (swap! calls conj :first)))
            (add-watch a :k (fn [k r o n] (swap! calls conj :second)))
            (swap! a inc)
            @calls
            """) == .vector([.keyword("second")], metadata: nil))
    }

    @Test("two independently-keyed watches both fire")
    func independentWatchesBothFire() throws {
        #expect(try swish.eval("""
            (def calls (atom #{}))
            (def a (atom 1))
            (add-watch a :one (fn [k r o n] (swap! calls conj :one)))
            (add-watch a :two (fn [k r o n] (swap! calls conj :two)))
            (swap! a inc)
            (= @calls #{:one :two})
            """) == .boolean(true))
    }

    @Test("remove-watch returns the atom")
    func removeWatchReturnsAtom() throws {
        #expect(try swish.eval("(def a (atom 1)) (add-watch a :k identity) (= a (remove-watch a :k))") == .boolean(true))
    }

    @Test("remove-watch stops further notifications")
    func removeWatchStopsNotifications() throws {
        #expect(try swish.eval("""
            (def calls (atom 0))
            (def a (atom 1))
            (add-watch a :k (fn [k r o n] (swap! calls inc)))
            (swap! a inc)
            (remove-watch a :k)
            (swap! a inc)
            @calls
            """) == .integer(1))
    }

    @Test("remove-watch on an absent key is a no-op")
    func removeWatchAbsentKeyNoOp() throws {
        #expect(try swish.eval("(def a (atom 1)) (remove-watch a :nope) @a") == .integer(1))
    }

    @Test("a watch fn's exception propagates out of swap!")
    func watchExceptionPropagatesFromSwap() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(def a (atom 1)) (add-watch a :k (fn [k r o n] (throw \"boom\"))) (swap! a inc)")
        }
    }

    @Test("a watch fn's exception propagates out of reset!")
    func watchExceptionPropagatesFromReset() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(def a (atom 1)) (add-watch a :k (fn [k r o n] (throw \"boom\"))) (reset! a 2)")
        }
    }

    @Test("add-watch on a non-atom/non-var throws")
    func addWatchOnNonRefThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(add-watch 5 :k identity)")
        }
    }

    // MARK: - add-watch / remove-watch on vars

    // Each test below uses a uniquely-named var. Vars are interned once and
    // reused across `def`, so watches persist across redefinition within a
    // suite (matching real Clojure semantics) — reusing a var name across
    // tests would leak watches between them. See CoreDynamicVarTests.swift
    // for the same pattern applied to dynamic-var tests.

    @Test("add-watch on a var returns the var")
    func addWatchReturnsVar() throws {
        #expect(try swish.eval("(def watch-var-1 1) (= (var watch-var-1) (add-watch (var watch-var-1) :k identity))") == .boolean(true))
    }

    @Test("var watch fn receives (key ref old new) via alter-var-root")
    func varWatchReceivesCorrectArgs() throws {
        #expect(try swish.eval("""
            (def calls (atom []))
            (def watch-var-2 1)
            (add-watch (var watch-var-2) :k (fn [k r o n] (swap! calls conj [k (= r (var watch-var-2)) o n])))
            (alter-var-root (var watch-var-2) inc)
            @calls
            """) == .vector([.vector([.keyword("k"), .boolean(true), .integer(1), .integer(2)], metadata: nil)], metadata: nil))
    }

    @Test("remove-watch on a var stops further notifications")
    func varRemoveWatchStopsNotifications() throws {
        #expect(try swish.eval("""
            (def calls (atom 0))
            (def watch-var-3 1)
            (add-watch (var watch-var-3) :k (fn [k r o n] (swap! calls inc)))
            (alter-var-root (var watch-var-3) inc)
            (remove-watch (var watch-var-3) :k)
            (alter-var-root (var watch-var-3) inc)
            @calls
            """) == .integer(1))
    }

    @Test("a var watch fn's exception propagates out of alter-var-root")
    func varWatchExceptionPropagates() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(def watch-var-4 1) (add-watch (var watch-var-4) :k (fn [k r o n] (throw \"boom\"))) (alter-var-root (var watch-var-4) inc)")
        }
    }

    @Test("multiple watches on the same var all fire")
    func multipleVarWatchesAllFire() throws {
        #expect(try swish.eval("""
            (def calls (atom #{}))
            (def watch-var-5 1)
            (add-watch (var watch-var-5) :one (fn [k r o n] (swap! calls conj :one)))
            (add-watch (var watch-var-5) :two (fn [k r o n] (swap! calls conj :two)))
            (alter-var-root (var watch-var-5) inc)
            (= @calls #{:one :two})
            """) == .boolean(true))
    }
}
