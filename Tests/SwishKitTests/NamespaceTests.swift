import Testing
@testable import SwishKit

@Suite("Namespace Tests")
struct NamespaceTests {

    @Test("intern creates a home Var with correct name and namespace")
    func internCreatesHomeVar() {
        let ns = Namespace(name: "test")
        let v = ns.intern(name: "foo")
        #expect(v.name == "foo")
        #expect(v.namespace === ns)
        #expect(v.value == nil)
    }

    @Test("intern returns the same Var object on redef")
    func internReturnsSameVar() {
        let ns = Namespace(name: "test")
        let v1 = ns.intern(name: "foo", value: .integer(1))
        let v2 = ns.intern(name: "foo", value: .integer(2))
        #expect(v1 === v2)
        #expect(v2.value == .integer(2))
    }

    @Test("intern with no value preserves existing value")
    func internNoValuePreservesValue() {
        let ns = Namespace(name: "test")
        _ = ns.intern(name: "foo", value: .integer(42))
        let v = ns.intern(name: "foo")
        #expect(v.value == .integer(42))
    }

    @Test("intern shadows a referred Var with a new home Var")
    func internShadowsReferredVar() throws {
        let homeNs = Namespace(name: "other")
        let homeVar = homeNs.intern(name: "bar", value: .integer(99))
        let ns = Namespace(name: "test")
        ns.refer(homeVar)
        let newVar = ns.intern(name: "bar", value: .integer(1))
        #expect(newVar !== homeVar)
        #expect(newVar.namespace === ns)
        #expect(ns.findVar(name: "bar") === newVar)
    }

    @Test("refer adds a Var under its short name")
    func referAddsVar() throws {
        let homeNs = Namespace(name: "other")
        let v = homeNs.intern(name: "bar", value: .integer(99))
        let ns = Namespace(name: "test")
        ns.refer(v)
        #expect(ns.findVar(name: "bar") === v)
    }

    @Test("refer is idempotent for the same Var")
    func referIdempotent() throws {
        let homeNs = Namespace(name: "other")
        let v = homeNs.intern(name: "bar")
        let ns = Namespace(name: "test")
        #expect(ns.refer(v) == nil)
        #expect(ns.refer(v) == nil)
        #expect(ns.findVar(name: "bar") === v)
    }

    @Test("refer warns and replaces a referred Var (Clojure checkReplacement)")
    func referReplacesReferredVar() throws {
        let ns1 = Namespace(name: "a")
        let ns2 = Namespace(name: "b")
        let ns3 = Namespace(name: "c")
        let v1 = ns1.intern(name: "foo")
        let v2 = ns2.intern(name: "foo")
        #expect(ns3.refer(v1) == nil)
        let msg = ns3.refer(v2)
        #expect(msg?.hasPrefix("WARNING:") == true)
        #expect(ns3.findVar(name: "foo") === v2)
    }

    @Test("refer keeps a home Var and returns REJECTED (Clojure checkReplacement)")
    func referRejectsOverHomeVar() throws {
        let ns = Namespace(name: "h")
        let home = ns.intern(name: "foo")
        let otherNs = Namespace(name: "o")
        let other = otherNs.intern(name: "foo")
        let msg = ns.refer(other)
        #expect(msg?.hasPrefix("REJECTED:") == true)
        #expect(ns.findVar(name: "foo") === home)
    }

    @Test("findVar returns nil for an unknown name")
    func findVarMissing() {
        let ns = Namespace(name: "test")
        #expect(ns.findVar(name: "missing") == nil)
    }

    @Test("findVar returns the Var after it is interned")
    func findVarAfterIntern() {
        let ns = Namespace(name: "test")
        let v = ns.intern(name: "x", value: .integer(5))
        #expect(ns.findVar(name: "x") === v)
    }
}
