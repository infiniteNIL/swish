import Testing
@testable import SwishKit

/// The `(ns …)` form copies clojure.core's mappings at load time and `resolveVar`
/// has no core fallback, so a host function registered *after* its Swish source
/// loaded would be invisible without the back-fill in `Evaluator.register`.
/// The demo app registers after `load`, so this is the ordering that matters.
@Suite("Interop: registration order")
struct RegistrationOrderTests {
    @Test("Registering after the namespace was loaded still resolves unqualified")
    func registerAfterLoad() throws {
        let swish = Swish()
        _ = try swish.eval("(ns receive-calls) (defn vowels [name] (get-vowels name))")
        swish.register({ (s: String) in s.filter { "aeiou".contains($0) } }, as: "get-vowels")

        #expect(try swish.eval(#"(vowels "hello")"#) == .string("eo"))
    }

    @Test("Registering before the namespace was loaded also resolves")
    func registerBeforeLoad() throws {
        let swish = Swish()
        swish.register({ (s: String) in s.filter { "aeiou".contains($0) } }, as: "get-vowels")
        _ = try swish.eval("(ns receive-calls) (defn vowels [name] (get-vowels name))")

        #expect(try swish.eval(#"(vowels "hello")"#) == .string("eo"))
    }

    @Test("A namespace that excluded the name does not get it back-filled")
    func excludedNameIsNotBackFilled() throws {
        let swish = Swish()
        _ = try swish.eval("(ns picky (:refer-clojure :exclude [get-vowels]))")
        swish.register({ (s: String) in s } , as: "get-vowels")

        expectSwishError { try swish.eval(#"(get-vowels "hello")"#) }
    }

    @Test("A namespace's own definition wins over a back-filled core var")
    func ownDefinitionWins() throws {
        let swish = Swish()
        _ = try swish.eval(#"(ns mine) (defn get-vowels [s] "mine")"#)
        swish.register({ (s: String) in "host" }, as: "get-vowels")

        #expect(try swish.eval(#"(get-vowels "hello")"#) == .string("mine"))
        // The host's version is still reachable where it actually lives.
        #expect(try swish.eval(#"(clojure.core/get-vowels "hello")"#) == .string("host"))
    }

    @Test("A bare namespace made with in-ns is unaffected, matching Clojure")
    func bareNamespaceStaysBare() throws {
        let swish = Swish()
        _ = try swish.eval("(in-ns 'bare)")
        swish.register({ 1 }, as: "host-fn")

        // in-ns never refers clojure.core, so nothing is back-filled there either.
        expectSwishError { try swish.eval("(host-fn)") }
    }

    @Test("Registering into a namespace does not disturb clojure.core")
    func namespacedRegistrationIsIsolated() throws {
        let swish = Swish()
        swish.register({ 7 }, as: "lucky", in: "app")

        #expect(try swish.eval("(app/lucky)") == .integer(7))
        expectSwishError { try swish.eval("(lucky)") }
    }
}
