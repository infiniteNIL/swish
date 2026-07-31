import Testing
@testable import SwishKit

@Suite("Core namespace introspection Tests", .serialized)
struct CoreNamespaceTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - ns-publics / ns-map

    @Test("ns-publics includes public defs and excludes :private; ns-map includes both")
    func nsPublicsAndMap() throws {
        _ = try swish.eval("(ns nspub-test)")
        _ = try swish.eval("(def ^:private secret 1)")
        _ = try swish.eval("(def visible 2)")
        #expect(try swish.eval("(contains? (ns-publics 'nspub-test) 'visible)") == .boolean(true))
        #expect(try swish.eval("(contains? (ns-publics 'nspub-test) 'secret)") == .boolean(false))
        // ns-map holds every mapping, private and referred included
        #expect(try swish.eval("(contains? (ns-map 'nspub-test) 'secret)") == .boolean(true))
        #expect(try swish.eval("(contains? (ns-map 'nspub-test) 'map)") == .boolean(true))
    }

    // MARK: - ns-refers

    @Test("ns-refers holds the auto-referred core mappings, not the namespace's own vars")
    func nsRefers() throws {
        _ = try swish.eval("(ns nsref-test)")
        _ = try swish.eval("(def home-var 1)")
        // clojure.core is auto-referred, so `map` shows up as a refer
        #expect(try swish.eval("(contains? (ns-refers 'nsref-test) 'map)") == .boolean(true))
        // a home var is not a refer
        #expect(try swish.eval("(contains? (ns-refers 'nsref-test) 'home-var)") == .boolean(false))
    }

    // MARK: - ns-aliases / ns-unalias

    @Test("ns-aliases reflects an alias, ns-unalias removes it")
    func nsAliasesAndUnalias() throws {
        _ = try swish.eval("(require 'clojure.string)")
        _ = try swish.eval("(ns nsalias-test)")
        _ = try swish.eval("(alias 'mystr 'clojure.string)")
        #expect(try swish.eval("(contains? (ns-aliases 'nsalias-test) 'mystr)") == .boolean(true))
        _ = try swish.eval("(ns-unalias 'nsalias-test 'mystr)")
        #expect(try swish.eval("(contains? (ns-aliases 'nsalias-test) 'mystr)") == .boolean(false))
    }

    // MARK: - ns-imports

    @Test("ns-imports returns an empty map (no host classes)")
    func nsImports() throws {
        #expect(try swish.eval("(= {} (ns-imports 'clojure.core))") == .boolean(true))
    }

    // MARK: - loaded-libs

    @Test("loaded-libs holds file-loaded libs, not create-ns/in-ns namespaces")
    func loadedLibs() throws {
        _ = try swish.eval("(require 'clojure.walk)")
        _ = try swish.eval("(create-ns 'adhoc.only)")
        #expect(try swish.eval("(contains? (loaded-libs) 'clojure.core)") == .boolean(true))
        #expect(try swish.eval("(contains? (loaded-libs) 'clojure.walk)") == .boolean(true))
        #expect(try swish.eval("(contains? (loaded-libs) 'adhoc.only)") == .boolean(false))
        // returns a sorted set
        #expect(try swish.eval("(sorted? (loaded-libs))") == .boolean(true))
    }

    // MARK: - requiring-resolve

    @Test("requiring-resolve resolves a qualified symbol, loading its lib if needed")
    func requiringResolve() throws {
        #expect(try swish.eval("(var? (requiring-resolve 'clojure.core/map))") == .boolean(true))
        // forces a lib to load then resolves within it
        #expect(try swish.eval("(var? (requiring-resolve 'clojure.set/union))") == .boolean(true))
    }

    @Test("requiring-resolve throws on a non-qualified symbol")
    func requiringResolveThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(requiring-resolve 'map)")
        }
    }

    // MARK: - use

    @Test("use requires and refers a lib's publics (non-clashing lib)")
    func useFull() throws {
        _ = try swish.eval("(in-ns 'use-full-test)")
        _ = try swish.eval("(clojure.core/refer 'clojure.core)")
        _ = try swish.eval("(use 'clojure.set)")
        #expect(try swish.eval("(union #{1} #{2})") == .set([.integer(1), .integer(2)], metadata: nil))
    }

    @Test("use forwards an :only filter to refer")
    func useOnly() throws {
        _ = try swish.eval("(in-ns 'use-only-test)")
        _ = try swish.eval("(clojure.core/refer 'clojure.core)")
        _ = try swish.eval("(use '[clojure.string :only [join]])")
        #expect(try swish.eval(#"(join "-" ["x" "y"])"#) == .string("x-y"))
    }

    // MARK: - refer-clojure / *err*

    @Test("(ns … (:refer-clojure :exclude [inc])) leaves inc unreferred")
    func nsReferClojureExclude() throws {
        _ = try swish.eval("(ns rc-test (:refer-clojure :exclude [inc]))")
        #expect(try swish.eval("(dec 5)") == .integer(4))
        #expect(throws: EvaluatorError.undefinedSymbol("inc")) {
            try swish.eval("(inc 5)")
        }
    }

    @Test("with-err-str captures a refer clash warning routed through *err*")
    func withErrStrCapturesReferWarning() throws {
        _ = try swish.eval("(ns errcap)")
        let captured = try swish.eval(#"(with-err-str (use 'clojure.string))"#)
        guard case .string(let s) = captured else {
            Issue.record("expected a string from with-err-str"); return
        }
        #expect(s.contains("WARNING"))
    }
}
