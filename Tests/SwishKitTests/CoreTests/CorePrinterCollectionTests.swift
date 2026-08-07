import Testing
@testable import SwishKit

/// Collection printing after the printer stopped materializing its input.
///
/// `.map` used to be rendered from a freshly-built `[Expr: Expr]` copy of its
/// `TreeDictionary` and `.set` from a Swift `Set` rebuilt out of its `TreeSet`. Both now
/// print straight off the persistent backing, so these pin the observable output that
/// depends on it: key sorting, the `#:ns{}` compaction rule, and the `*print-length*` /
/// `*print-level*` interaction with nesting.
@Suite("Core Printer Collection Tests", .serialized)
struct CorePrinterCollectionTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - Ordering

    @Test("Map keys print in sorted order regardless of insertion order")
    func mapKeysSorted() throws {
        #expect(try swish.eval(#"(pr-str {:c 3 :a 1 :b 2})"#) == .string("{:a 1 :b 2 :c 3}"))
        #expect(try swish.eval(#"(pr-str (into {} [[:z 1] [:y 2] [:x 3]]))"#) == .string("{:x 3 :y 2 :z 1}"))
    }

    @Test("Set elements print in sorted order regardless of insertion order")
    func setElementsSorted() throws {
        #expect(try swish.eval(#"(pr-str #{3 1 2})"#) == .string("#{1 2 3}"))
        #expect(try swish.eval(#"(pr-str (into #{} [:c :a :b]))"#) == .string("#{:a :b :c}"))
    }

    @Test("Empty map and set print as {} and #{}")
    func emptyCollections() throws {
        #expect(try swish.eval(#"(pr-str {})"#) == .string("{}"))
        #expect(try swish.eval(#"(pr-str #{})"#) == .string("#{}"))
    }

    // MARK: - #:ns{} compaction

    @Test("A map whose keys all share one namespace compacts to #:ns{…}")
    func namespacedMapCompacts() throws {
        #expect(try swish.eval(#"(pr-str {:a/x 1 :a/y 2})"#) == .string("#:a{:x 1 :y 2}"))
    }

    @Test("Mixed namespaces, a bare key, or a non-keyword key all suppress compaction")
    func compactionSuppressed() throws {
        #expect(try swish.eval(#"(pr-str {:a/x 1 :b/y 2})"#) == .string("{:a/x 1 :b/y 2}"))
        #expect(try swish.eval(#"(pr-str {:a/x 1 :y 2})"#) == .string("{:a/x 1 :y 2}"))
        #expect(try swish.eval(#"(pr-str {"a/x" 1 "a/y" 2})"#) == .string(#"{"a/x" 1 "a/y" 2}"#))
    }

    @Test("*print-namespace-maps* false suppresses compaction")
    func compactionDisabled() throws {
        #expect(try swish.eval(#"(binding [*print-namespace-maps* false] (pr-str {:a/x 1 :a/y 2}))"#)
                == .string("{:a/x 1 :a/y 2}"))
    }

    // MARK: - Print-control vars over nested collections

    @Test("*print-level* renders a collection at or past the cap as #")
    func printLevelCapsNesting() throws {
        #expect(try swish.eval(#"(binding [*print-level* 1] (pr-str {:a {:b 1}}))"#) == .string("{:a #}"))
        #expect(try swish.eval(#"(binding [*print-level* 2] (pr-str {:a {:b 1}}))"#) == .string("{:a {:b 1}}"))
        #expect(try swish.eval(#"(binding [*print-level* 1] (pr-str #{[1]}))"#) == .string("#{#}"))
    }

    @Test("*print-length* truncates a lazy seq with … while leaving map/set printing intact")
    func printLengthTruncatesLazySeq() throws {
        #expect(try swish.eval(#"(binding [*print-length* 3] (pr-str (range 10)))"#) == .string("(0 1 2 ...)"))
        #expect(try swish.eval(#"(binding [*print-length* 3] (pr-str {:a 1 :b 2 :c 3 :d 4}))"#)
                == .string("{:a 1 :b 2 :c 3 :d 4}"))
    }

    @Test("A map nested in a set and a set nested in a map both round-trip through the printer")
    func nestedCollections() throws {
        #expect(try swish.eval(#"(pr-str {:s #{1 2}})"#) == .string("{:s #{1 2}}"))
        #expect(try swish.eval(#"(pr-str #{{:a 1}})"#) == .string("#{{:a 1}}"))
    }

    // MARK: - str vs pr-str vs print-str

    /// The three renderings differ in *how far down* the unquoting reaches: `pr` quotes
    /// everywhere, `str` quotes the elements but not a top-level string (it is the value's
    /// `toString`, and a collection's `toString` is pr-based), and `print` quotes nothing
    /// at any depth (it binds `*print-readably*` to nil over an ordinary `pr`).
    @Test("pr-str, str and print-str differ in how deep the unquoting reaches")
    func threeRenderings() throws {
        #expect(try swish.eval(#"(pr-str {:a "x"})"#) == .string(#"{:a "x"}"#))
        #expect(try swish.eval(#"(str {:a "x"})"#) == .string(#"{:a "x"}"#))
        #expect(try swish.eval(#"(print-str {:a "x"})"#) == .string("{:a x}"))

        // Only `str` unquotes a *top-level* string; only `print` unquotes a nested one.
        #expect(try swish.eval(#"(pr-str "x")"#) == .string(#""x""#))
        #expect(try swish.eval(#"(str "x")"#) == .string("x"))
        #expect(try swish.eval(#"(print-str "x")"#) == .string("x"))
    }

    @Test("*print-readably* false makes pr-str match print-str")
    func printReadablyFalse() throws {
        #expect(try swish.eval(#"(binding [*print-readably* false] (pr-str {:a "x"}))"#) == .string("{:a x}"))
    }
}
