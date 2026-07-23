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

    // MARK: - alias

    @Test("(alias 'c 'clojure.core) lets c/+ resolve to clojure.core/+")
    func aliasEnablesQualifiedLookup() throws {
        let swish = Swish()
        _ = try swish.eval("(alias 'c 'clojure.core)")
        let result = try swish.eval("(c/+ 1 2)")
        #expect(result == .integer(3))
    }

    @Test("qualified-var-cache: same alias name resolving to different namespaces is never poisoned across callers")
    func aliasedResolutionNotCachedAcrossNamespaces() throws {
        let swish = Swish()
        _ = try swish.eval("(ns ns-a)")
        _ = try swish.eval("(def helper 1)")
        _ = try swish.eval("(ns ns-b)")
        _ = try swish.eval("(def helper 2)")
        _ = try swish.eval("(ns caller-a)")
        _ = try swish.eval("(alias 'u 'ns-a)")
        #expect(try swish.eval("u/helper") == .integer(1))
        _ = try swish.eval("(ns caller-b)")
        _ = try swish.eval("(alias 'u 'ns-b)")
        // Same qualified-string cache key ("u/helper") as above, resolved from a
        // different calling namespace whose `u` alias points elsewhere — must not
        // be served the previous caller's cached (and wrong, for this caller) result.
        #expect(try swish.eval("u/helper") == .integer(2))
    }

    @Test("qualified-var-cache: a referred var later shadowed by a local def is never served stale")
    func referredVarShadowedByLocalDefNotCached() throws {
        let swish = Swish()
        _ = try swish.eval("(ns home-ns)")
        _ = try swish.eval("(def shared 100)")
        _ = try swish.eval("(ns consumer-ns)")
        _ = try swish.eval("(refer 'home-ns)")
        #expect(try swish.eval("consumer-ns/shared") == .integer(100))
        _ = try swish.eval("(ns consumer-ns)")
        _ = try swish.eval("(def shared 200)")
        // intern creates a genuinely new home Var here, since the existing mapping's
        // home was home-ns, not consumer-ns — the earlier referred-var resolution
        // must not have been cached, or this would incorrectly still read 100.
        #expect(try swish.eval("consumer-ns/shared") == .integer(200))
    }

    @Test("alias is per-namespace — alias in user does not affect other ns")
    func aliasIsPerNamespace() throws {
        let swish = Swish()
        _ = try swish.eval("(alias 'c 'clojure.core)")
        _ = try swish.eval("(in-ns 'other)")
        #expect(throws: EvaluatorError.undefinedSymbol("c/+")) {
            _ = try swish.eval("(c/+ 1 2)")
        }
    }

    @Test("alias conflict throws aliasConflict")
    func aliasConflictThrows() throws {
        let swish = Swish()
        _ = try swish.eval("(create-ns 'foo)")
        _ = try swish.eval("(alias 'f 'clojure.core)")
        #expect(throws: NamespaceError.aliasConflict(name: "f", existing: "clojure.core", new: "foo")) {
            _ = try swish.eval("(alias 'f 'foo)")
        }
    }

    @Test("alias to same namespace is idempotent")
    func aliasSameNsIdempotent() throws {
        let swish = Swish()
        _ = try swish.eval("(alias 'c 'clojure.core)")
        _ = try swish.eval("(alias 'c 'clojure.core)")
        let result = try swish.eval("(c/+ 1 2)")
        #expect(result == .integer(3))
    }

    @Test("alias to unknown namespace throws namespaceNotFound")
    func aliasUnknownNsThrows() throws {
        let swish = Swish()
        #expect(throws: EvaluatorError.namespaceNotFound("no.such.ns")) {
            _ = try swish.eval("(alias 'x 'no.such.ns)")
        }
    }

    // MARK: - refer

    @Test("(refer ...) with :only refers only the named vars from a user namespace")
    func referOnly() throws {
        let swish = Swish()
        _ = try swish.eval("(in-ns 'src)")
        _ = try swish.eval("(def a 1)")
        _ = try swish.eval("(def b 2)")
        _ = try swish.eval("(in-ns 'consumer)")
        _ = try swish.eval("(refer 'src :only '[a])")
        #expect(try swish.eval("a") == .integer(1))
        #expect(throws: EvaluatorError.undefinedSymbol("b")) {
            _ = try swish.eval("b")
        }
    }

    @Test("(refer ...) with :exclude skips the listed vars from a user namespace")
    func referExclude() throws {
        let swish = Swish()
        _ = try swish.eval("(in-ns 'src2)")
        _ = try swish.eval("(def x 10)")
        _ = try swish.eval("(def y 20)")
        _ = try swish.eval("(in-ns 'consumer2)")
        _ = try swish.eval("(refer 'src2 :exclude '[x])")
        #expect(try swish.eval("y") == .integer(20))
        #expect(throws: EvaluatorError.undefinedSymbol("x")) {
            _ = try swish.eval("x")
        }
    }

    @Test("refer to unknown namespace throws namespaceNotFound")
    func referUnknownNsThrows() throws {
        let swish = Swish()
        #expect(throws: EvaluatorError.namespaceNotFound("no.such.ns")) {
            _ = try swish.eval("(refer 'no.such.ns)")
        }
    }

    @Test("refer does not re-export auto-referred clojure.core vars")
    func referDoesNotReExportAutoRefers() throws {
        let swish = Swish()
        _ = try swish.eval("(in-ns 'myns)")
        _ = try swish.eval("(def my-fn (fn [] 42))")
        _ = try swish.eval("(in-ns 'consumer)")
        _ = try swish.eval("(refer 'myns)")
        #expect(try swish.eval("(my-fn)") == .integer(42))
        // clojure.core/+ should NOT have been re-exported through myns
        let myns = swish.evaluator.findNs("myns")!
        let plusInMyns = myns.mappings["+"]
        #expect(plusInMyns?.namespace.name == "clojure.core")
        let consumerNs = swish.evaluator.findNs("consumer")!
        let plusInConsumer = consumerNs.mappings["+"]
        #expect(plusInConsumer?.namespace.name == "clojure.core")
    }

    // MARK: - require

    @Test("(require 'clojure.core) is a no-op when already loaded")
    func requireAlreadyLoadedIsNoop() throws {
        let swish = Swish()
        _ = try swish.eval("(require 'clojure.core)")
        let result = try swish.eval("(+ 1 2)")
        #expect(result == .integer(3))
    }

    @Test("(require 'unknown.ns) throws namespaceNotFound")
    func requireUnknownNsThrows() throws {
        let swish = Swish()
        #expect(throws: EvaluatorError.namespaceNotFound("unknown.ns")) {
            _ = try swish.eval("(require 'unknown.ns)")
        }
    }

    // MARK: - ns with :require directives

    @Test("(ns foo (:require [clojure.core :as cc])) enables cc/+ alias")
    func nsRequireAs() throws {
        let swish = Swish()
        _ = try swish.eval("(ns foo (:require [clojure.core :as cc]))")
        let result = try swish.eval("(cc/+ 1 2)")
        #expect(result == .integer(3))
    }

    @Test("(ns foo (:require [clojure.core :refer [+]])) makes + available unqualified")
    func nsRequireRefer() throws {
        let swish = Swish()
        _ = try swish.eval("(in-ns 'bare)")
        _ = try swish.eval("(ns bare2 (:require [clojure.core :refer [+]]))")
        let result = try swish.eval("(+ 10 20)")
        #expect(result == .integer(30))
    }

    @Test("(ns foo (:require [clojure.core :as cc :refer [+]])) supports both")
    func nsRequireAsAndRefer() throws {
        let swish = Swish()
        _ = try swish.eval("(ns combo (:require [clojure.core :as cc :refer [+]]))")
        #expect(try swish.eval("(+ 1 2)") == .integer(3))
        #expect(try swish.eval("(cc/+ 1 2)") == .integer(3))
    }

    @Test("ns with unknown directive throws invalidArgument")
    func nsUnknownDirectiveThrows() throws {
        let swish = Swish()
        #expect(throws: EvaluatorError.invalidArgument(
            function: "ns", message: "unknown directive ':import'")) {
            _ = try swish.eval("(ns bad (:import java.util.Date))")
        }
    }

    @Test("unqualified recursive call resolves in defining namespace")
    func recursiveCallResolvesInDefiningNamespace() throws {
        let swish = Swish()
        _ = try swish.eval("(ns math)")
        _ = try swish.eval("(defn fact [n] (if (= n 0) 1 (* n (fact (- n 1)))))")
        _ = try swish.eval("(ns user)")
        let result = try swish.eval("(math/fact 5)")
        #expect(result == .integer(120))
    }

    @Test("alias in function body resolves when called from a different namespace")
    func aliasFunctionBodyResolvesAcrossNamespaces() throws {
        let swish = Swish()
        _ = try swish.eval("(ns ns-b)")
        _ = try swish.eval("(defn greeting [] \"hello\")")
        _ = try swish.eval("(ns ns-a (:require [ns-b :as b]))")
        _ = try swish.eval("(defn call-b [] (b/greeting))")
        _ = try swish.eval("(ns user)")
        let result = try swish.eval("(ns-a/call-b)")
        #expect(result == .string("hello"))
    }

    // MARK: - ns metadata

    @Test("ns with doc string stores :doc in metadata")
    func nsDocString() throws {
        let swish = Swish()
        _ = try swish.eval("(ns meta-doc-ns \"a doc string\")")
        let result = try swish.eval("(meta *ns*)")
        #expect(result == .map([.keyword("doc"): .string("a doc string")], metadata: nil))
    }

    @Test("ns with attr map stores metadata")
    func nsAttrMap() throws {
        let swish = Swish()
        _ = try swish.eval("(ns meta-attr-ns {:author \"Rod\"})")
        let result = try swish.eval("(meta *ns*)")
        #expect(result == .map([.keyword("author"): .string("Rod")], metadata: nil))
    }

    @Test("ns with doc string and attr map merges both")
    func nsDocAndAttrMap() throws {
        let swish = Swish()
        _ = try swish.eval("(ns meta-both-ns \"the doc\" {:author \"Rod\"})")
        let result = try swish.eval("(meta *ns*)")
        #expect(result == .map([
            .keyword("doc"): .string("the doc"),
            .keyword("author"): .string("Rod")
        ], metadata: nil))
    }

    @Test("doc string wins over :doc key in attr map")
    func nsDocStringWinsOverAttrDoc() throws {
        let swish = Swish()
        _ = try swish.eval("(ns meta-doc-win-ns \"real doc\" {:doc \"ignored\"})")
        let result = try swish.eval("(meta *ns*)")
        #expect(result == .map([.keyword("doc"): .string("real doc")], metadata: nil))
    }

    @Test("ns with no doc or attr has nil metadata")
    func nsNoMetaIsNil() throws {
        let swish = Swish()
        _ = try swish.eval("(ns plain-meta-ns)")
        let result = try swish.eval("(meta *ns*)")
        #expect(result == .nil)
    }

    // MARK: - find-ns

    @Test("find-ns returns nil for unknown namespace")
    func findNsUnknownReturnsNil() throws {
        let swish = Swish()
        #expect(try swish.eval("(find-ns 'no.such.namespace.xyz)") == .nil)
    }

    @Test("find-ns returns the namespace for a known namespace")
    func findNsKnownReturnsNamespace() throws {
        let swish = Swish()
        _ = try swish.eval("(ns find-ns-test)")
        let result = try swish.eval("(find-ns 'find-ns-test)")
        guard case .namespace(let ns) = result else {
            Issue.record("Expected .namespace, got \(result)")
            return
        }
        #expect(ns.name == "find-ns-test")
    }

    @Test("meta via find-ns returns namespace metadata")
    func metaViaFindNs() throws {
        let swish = Swish()
        _ = try swish.eval("(ns find-ns-meta-test \"hello from find-ns\")")
        _ = try swish.eval("(ns user)")
        let result = try swish.eval("(meta (find-ns 'find-ns-meta-test))")
        #expect(result == .map([.keyword("doc"): .string("hello from find-ns")], metadata: nil))
    }
}
