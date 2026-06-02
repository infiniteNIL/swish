import Testing
@testable import SwishKit

@Suite("Core Atom Tests", .serialized)
struct CoreAtomTests {
    nonisolated(unsafe) static let _shared = Swish()
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
}
