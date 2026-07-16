import Testing
@testable import SwishKit

@Suite("Core var-get/var-set Tests", .serialized)
struct CoreVarGetSetTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("var-get returns a plain var's root value")
    func varGetRootValue() throws {
        #expect(try swish.eval("(def var-get-test-a 1) (var-get (var var-get-test-a))") == .integer(1))
    }

    @Test("var-get returns the dynamic binding's value inside binding")
    func varGetDynamicInsideBinding() throws {
        #expect(try swish.eval("(def ^:dynamic var-get-test-b 1) (binding [var-get-test-b 2] (var-get (var var-get-test-b)))") == .integer(2))
    }

    @Test("var-get returns the root value outside any binding")
    func varGetDynamicOutsideBinding() throws {
        #expect(try swish.eval("(def ^:dynamic var-get-test-c 1) (var-get (var var-get-test-c))") == .integer(1))
    }

    @Test("var-get throws for a non-Var argument")
    func varGetNonVarThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(var-get 1)")
        }
    }

    @Test("var-get throws for a genuinely unbound var")
    func varGetUnboundThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(def var-get-test-unbound) (var-get (var var-get-test-unbound))")
        }
    }

    @Test("var-set inside binding changes the value for the duration of that binding")
    func varSetInsideBinding() throws {
        #expect(try swish.eval("(def ^:dynamic var-set-test-a 1) (binding [var-set-test-a 2] (var-set (var var-set-test-a) 3) (var-get (var var-set-test-a)))") == .integer(3))
    }

    @Test("var-set does not affect the root value after the binding ends")
    func varSetDoesNotAffectRoot() throws {
        #expect(try swish.eval("(def ^:dynamic var-set-test-b 1) (binding [var-set-test-b 2] (var-set (var var-set-test-b) 3)) (var-get (var var-set-test-b))") == .integer(1))
    }

    @Test("var-set throws when the var has no active thread-local binding")
    func varSetNotBoundThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(def ^:dynamic var-set-test-c 1) (var-set (var var-set-test-c) 2)")
        }
    }

    @Test("var-set throws for a non-Var argument")
    func varSetNonVarThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(var-set 1 2)")
        }
    }
}
