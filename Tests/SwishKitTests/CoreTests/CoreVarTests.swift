import Testing
@testable import SwishKit

@Suite("Core Var (alter-var-root) Tests", .serialized)
struct CoreVarTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // Each test uses a uniquely-named var: vars are interned once and reused
    // across `def` within the shared instance, and `(def foo)` with no value
    // leaves an already-bound var's value intact rather than unbinding it
    // (see VarTests.swift), so sharing a name across tests risks
    // order-dependent leakage.

    @Test("alter-var-root sets the var's root value")
    func alterVarRootSetsValue() throws {
        #expect(try swish.eval("(def avr-1 1) (alter-var-root (var avr-1) inc) avr-1") == .integer(2))
    }

    @Test("alter-var-root returns the new value")
    func alterVarRootReturnsNewValue() throws {
        #expect(try swish.eval("(def avr-2 1) (alter-var-root (var avr-2) inc)") == .integer(2))
    }

    @Test("alter-var-root applies f with trailing args")
    func alterVarRootWithTrailingArgs() throws {
        #expect(try swish.eval("(def avr-3 1) (alter-var-root (var avr-3) + 10 100)") == .integer(111))
    }

    @Test("alter-var-root throws on an unbound var")
    func alterVarRootUnboundVarThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(def avr-4) (alter-var-root (var avr-4) inc)")
        }
    }

    @Test("alter-var-root throws when first argument isn't a var")
    func alterVarRootNonVarThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(alter-var-root 5 inc)")
        }
    }

    @Test("alter-var-root mutates the root, independent of a thread binding override")
    func alterVarRootIndependentOfBinding() throws {
        #expect(try swish.eval("""
            (def ^:dynamic *avr-5* 1)
            (binding [*avr-5* 99]
              (alter-var-root (var *avr-5*) inc))
            *avr-5*
            """) == .integer(2))
    }
}
