import Testing
@testable import SwishKit

@Suite("Core Atom Tests", .serialized)
struct CoreAtomTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - atom creation and deref

    @Test("(deref (atom 42)) returns initial value")
    func derefReturnsInitialValue() throws {
        #expect(try swish.eval("(deref (atom 42))") == .integer(42))
    }

    @Test("@a returns atom value via reader macro")
    func atReaderMacroDeref() throws {
        #expect(try swish.eval("(def a (atom 42)) @a") == .integer(42))
    }

    @Test("atom? returns true for atoms")
    func atomPredicateTrue() throws {
        #expect(try swish.eval("(atom? (atom 1))") == .boolean(true))
    }

    @Test("atom? returns false for non-atoms")
    func atomPredicateFalse() throws {
        #expect(try swish.eval("(atom? 42)") == .boolean(false))
    }

    // MARK: - reset!

    @Test("reset! changes the atom's value")
    func resetChangesValue() throws {
        #expect(try swish.eval("(def a (atom 1)) (reset! a 99) @a") == .integer(99))
    }

    @Test("reset! returns the new value")
    func resetReturnsNewValue() throws {
        #expect(try swish.eval("(def a (atom 0)) (reset! a 7)") == .integer(7))
    }

    // MARK: - swap!

    @Test("swap! applies f to current value")
    func swapAppliesF() throws {
        #expect(try swish.eval("(def a (atom 10)) (swap! a + 5) @a") == .integer(15))
    }

    @Test("swap! returns the new value")
    func swapReturnsNewValue() throws {
        #expect(try swish.eval("(def a (atom 10)) (swap! a * 2)") == .integer(20))
    }

    @Test("swap! with no extra args")
    func swapNoExtraArgs() throws {
        #expect(try swish.eval("(def a (atom 10)) (swap! a inc) @a") == .integer(11))
    }

    // MARK: - deref on var

    @Test("deref on a var returns its value")
    func derefVar() throws {
        #expect(try swish.eval("(def x 7) (deref (var x))") == .integer(7))
    }

    // MARK: - reference identity

    @Test("two bindings to the same atom share state")
    func referenceIdentity() throws {
        #expect(try swish.eval("(def a (atom 1)) (def b a) (reset! a 2) @b") == .integer(2))
    }

    // MARK: - atom variadic options

    @Test("atom accepts extra nil args (unknown options are ignored)")
    func atomExtraNilArgs() throws {
        #expect(try swish.eval("(deref (atom nil nil nil))") == .nil)
    }

    @Test("atom :meta sets metadata")
    func atomMetaOption() throws {
        #expect(try swish.eval("(meta (atom 1 :meta {:foo \"bar\"}))") == .map([.keyword("foo"): .string("bar")], metadata: nil))
    }

    @Test("meta on atom with no metadata returns nil")
    func atomNoMeta() throws {
        #expect(try swish.eval("(meta (atom 1))") == .nil)
    }

    @Test("atom :meta with non-map value throws")
    func atomMetaNonMapThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(atom 1 :meta 5)") }
    }

    @Test("get-validator returns nil when no validator set")
    func getValidatorNone() throws {
        #expect(try swish.eval("(get-validator (atom 1))") == .nil)
    }

    @Test("get-validator returns the validator function")
    func getValidatorSet() throws {
        #expect(try swish.eval("(nil? (get-validator (atom 1 :validator odd?)))") == .boolean(false))
    }

    @Test("atom :validator rejects invalid initial value")
    func atomValidatorRejectsInitial() throws {
        #expect(throws: (any Error).self) { try swish.eval("(atom 2 :validator odd?)") }
    }

    @Test("atom :validator accepts valid initial value")
    func atomValidatorAcceptsInitial() throws {
        #expect(try swish.eval("(deref (atom 1 :validator odd?))") == .integer(1))
    }

    @Test("reset! runs validator and accepts valid value")
    func resetValidatorAccepts() throws {
        #expect(try swish.eval("(reset! (atom 1 :validator odd?) 3)") == .integer(3))
    }

    @Test("reset! runs validator and throws on invalid value")
    func resetValidatorRejects() throws {
        #expect(throws: (any Error).self) { try swish.eval("(reset! (atom 1 :validator odd?) 2)") }
    }

    @Test("swap! runs validator and throws when result is invalid")
    func swapValidatorRejects() throws {
        #expect(throws: (any Error).self) { try swish.eval("(swap! (atom 1 :validator odd?) + 1)") }
    }

    @Test("swap! runs validator and accepts valid result")
    func swapValidatorAccepts() throws {
        #expect(try swish.eval("(swap! (atom 1 :validator odd?) + 2)") == .integer(3))
    }

    // MARK: - swap! reentrancy (thread-safety retrofit: swap! is a CAS-retry loop)

    @Test("swap! update fn that reentrantly swap!s the same atom retries instead of clobbering the inner write")
    func swapReentrantRetries() throws {
        // f reads x=1, reentrantly sets the atom to 100, then returns x+1=2.
        // A naive (non-CAS) swap! would overwrite the inner write with 2.
        // The CAS-retry loop instead detects the concurrent (well, reentrant)
        // change, retries with the now-current value (100), and converges to 101.
        #expect(try swish.eval("""
            (def a (atom 1))
            (def calls (atom 0))
            (swap! a (fn [x] (swap! calls inc) (swap! a (fn [_] 100)) (+ x 1)))
            @a
            """) == .integer(101))
        #expect(try swish.eval("@calls") == .integer(2))
    }
}
