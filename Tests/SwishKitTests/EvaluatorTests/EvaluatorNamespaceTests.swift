import Testing
@testable import SwishKit

@Suite("Evaluator Namespace Tests")
struct EvaluatorNamespaceTests {

    @Test("*ns* initial value is the user namespace")
    func nsStarInitialValue() throws {
        let swish = Swish()
        let result = try swish.eval("*ns*")
        guard case .namespace(let ns) = result else {
            Issue.record("Expected .namespace, got \(result)")
            return
        }
        #expect(ns.name == "user")
    }

    @Test("(in-ns 'foo) switches the current namespace")
    func inNsSwitches() throws {
        let swish = Swish()
        _ = try swish.eval("(in-ns 'foo)")
        #expect(swish.currentNamespaceName == "foo")
    }

    @Test("(def x 1) after (in-ns 'foo) interns x into foo")
    func defAfterInNsInternsIntoNewNs() throws {
        let swish = Swish()
        _ = try swish.eval("(in-ns 'foo)")
        _ = try swish.eval("(def x 1)")
        let result = try swish.eval("x")
        #expect(result == .integer(1))
        #expect(swish.evaluator.findNs("foo")?.findVar(name: "x")?.namespace.name == "foo")
    }

    @Test("(create-ns 'bar) creates namespace without switching")
    func createNsDoesNotSwitch() throws {
        let swish = Swish()
        _ = try swish.eval("(create-ns 'bar)")
        #expect(swish.currentNamespaceName == "user")
        #expect(swish.evaluator.findNs("bar") != nil)
    }

    @Test("clojure.core/+ resolves from another namespace")
    func qualifiedLookupFromOtherNs() throws {
        let swish = Swish()
        _ = try swish.eval("(in-ns 'other)")
        let result = try swish.eval("(clojure.core/+ 1 2)")
        #expect(result == .integer(3))
    }

    @Test("new namespace auto-refers clojure.core so bare + works")
    func autoReferMakesCoreFnsAvailable() throws {
        let swish = Swish()
        _ = try swish.eval("(in-ns 'myns)")
        let result = try swish.eval("(+ 1 2)")
        #expect(result == .integer(3))
    }

    @Test("(def *ns* 1) throws cannotRedefineSystemVar")
    func defSystemVarThrows() throws {
        let swish = Swish()
        #expect(throws: EvaluatorError.cannotRedefineSystemVar("*ns*")) {
            _ = try swish.eval("(def *ns* 1)")
        }
    }

    @Test("Var identity is preserved across redef in the same namespace")
    func varIdentityPreservedOnRedef() throws {
        let swish = Swish()
        let first = try swish.eval("(def x 1)")
        let second = try swish.eval("(def x 2)")
        guard case .varRef(let v1) = first, case .varRef(let v2) = second else {
            Issue.record("Expected .varRef results")
            return
        }
        #expect(v1 === v2)
        #expect(v2.value == .integer(2))
    }

    @Test("let binding shadows ns mapping")
    func letShadowsNsMapping() throws {
        let swish = Swish()
        _ = try swish.eval("(def x 1)")
        let result = try swish.eval("(let [x 99] x)")
        #expect(result == .integer(99))
        #expect(try swish.eval("x") == .integer(1))
    }

    @Test("Unqualified symbol lookup falls through to clojure.core")
    func unqualifiedFallsThroughToCore() throws {
        let swish = Swish()
        _ = try swish.eval("(in-ns 'newns)")
        let result = try swish.eval("(+ 10 20)")
        #expect(result == .integer(30))
    }

    @Test("Undefined unqualified symbol throws undefinedSymbol")
    func undefinedSymbolThrows() throws {
        let swish = Swish()
        #expect(throws: EvaluatorError.undefinedSymbol("__no_such_var__")) {
            _ = try swish.eval("__no_such_var__")
        }
    }
}
