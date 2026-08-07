import Testing
@testable import SwishKit

/// What `nth` accepts and rejects.
///
/// Clojure's `nth` takes Indexed or sequential things — vectors, lists, strings, arrays,
/// seqs, `nil`, and a regex Matcher — but *not* an unordered collection. Swish previously
/// got both ends of that wrong: a Matcher threw ("don't know how to create seq from
/// #<Matcher>") because `.matcher` isn't seqable, and a map or set quietly returned an
/// element because `asSequence` handles them. Both were caught by the jank suite's
/// rewritten `nth` test.
@Suite("Core nth Indexed Sources Tests", .serialized)
struct CoreNthIndexedSourcesTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - Matcher

    /// `(nth m i)` indexes the matcher's *current* match: 0 is the whole match, 1…n are
    /// the capture groups — the same shape `re-groups` returns.
    @Test("nth on a matcher with capture groups returns the whole match then each group")
    func matcherWithGroups() throws {
        let setup = #"(def m1 (re-matcher #"(\d+),(\d+),(\d+)" "123,456,789")) (re-find m1)"#
        _ = try swish.eval(setup)
        #expect(try swish.eval("(nth m1 0)") == .string("123,456,789"))
        #expect(try swish.eval("(nth m1 1)") == .string("123"))
        #expect(try swish.eval("(nth m1 2)") == .string("456"))
        #expect(try swish.eval("(nth m1 3)") == .string("789"))
    }

    @Test("Past the last group: nth throws, or returns the not-found value")
    func matcherOutOfRange() throws {
        _ = try swish.eval(#"(def m2 (re-matcher #"(\d+),(\d+),(\d+)" "123,456,789")) (re-find m2)"#)
        #expect(try swish.eval("(nth m2 10 :default)") == .keyword("default"))
        #expect(try swish.eval("(nth m2 -1 :default)") == .keyword("default"))
        #expect(throws: (any Error).self) { try swish.eval("(nth m2 10)") }
    }

    /// With no capture groups the current match is a bare string, so index 0 is the only
    /// addressable slot.
    @Test("nth on a matcher without capture groups addresses only index 0")
    func matcherWithoutGroups() throws {
        _ = try swish.eval(#"(def m3 (re-matcher #"\d+" "abc 123")) (re-find m3)"#)
        #expect(try swish.eval("(nth m3 0)") == .string("123"))
        #expect(try swish.eval("(nth m3 1 :nf)") == .keyword("nf"))
        #expect(throws: (any Error).self) { try swish.eval("(nth m3 1)") }
    }

    @Test("A matcher with no current match — before any re-find, or once exhausted")
    func matcherNoCurrentMatch() throws {
        _ = try swish.eval(#"(def m4 (re-matcher #"\d+" "abc 123"))"#)
        #expect(try swish.eval("(nth m4 0 :nf)") == .keyword("nf"))
        #expect(throws: (any Error).self) { try swish.eval("(nth m4 0)") }

        // Walk past the only match; `last` clears, so nth reports not-found again.
        _ = try swish.eval(#"(def m5 (re-matcher #"\d+" "abc 123")) (re-find m5) (re-find m5)"#)
        #expect(try swish.eval("(nth m5 0 :nf)") == .keyword("nf"))
    }

    /// Matcher support is confined to `nth`. A `java.util.regex.Matcher` isn't seqable in
    /// Clojure either, so the seq protocol must keep rejecting it — widening `asSequence`
    /// would silently make `seq`/`first`/`map` start working on matchers.
    @Test("A matcher is still not seqable")
    func matcherIsNotSeqable() throws {
        _ = try swish.eval(#"(def m6 (re-matcher #"\d+" "abc 123")) (re-find m6)"#)
        #expect(throws: (any Error).self) { try swish.eval("(seq m6)") }
        #expect(throws: (any Error).self) { try swish.eval("(first m6)") }
        #expect(throws: (any Error).self) { try swish.eval("(count m6)") }
    }

    // MARK: - Unordered collections are rejected

    @Test("nth throws on a map, sorted-map, set, sorted-set and record")
    func rejectsUnorderedCollections() throws {
        _ = try swish.eval("(defrecord NthRec [a b])")
        for form in ["(nth {:a 1 :b 2} 0)",
                     "(nth (sorted-map :a 1 :b 2) 0)",
                     "(nth #{:a :b :c :d} 0)",
                     "(nth (sorted-set :a :b) 0)",
                     "(nth (->NthRec 1 2) 0)"] {
            #expect(throws: (any Error).self, "\(form) should throw") { try swish.eval(form) }
        }
    }

    /// It is the *collection* that is rejected, never the seq you get from `seq`-ing it.
    @Test("nth still works on the seq of an unordered collection")
    func acceptsTheSeqOfThem() throws {
        #expect(try swish.eval("(nth (seq (sorted-map :a 1 :b 2)) 0)")
                == .vector([.keyword("a"), .integer(1)], metadata: nil))
        #expect(try swish.eval("(nth (seq (sorted-set :a :b :c :d)) 0)") == .keyword("a"))
        #expect(try swish.eval("(nth (seq {:a 1}) 0)")
                == .vector([.keyword("a"), .integer(1)], metadata: nil))
        #expect(try swish.eval("(nth (vec {:a 1}) 0)")
                == .vector([.keyword("a"), .integer(1)], metadata: nil))
    }

    /// The rejection is unconditional — supplying a not-found value doesn't turn the
    /// unsupported type into a miss, matching Clojure.
    @Test("The 3-arity form throws on an unordered collection too")
    func rejectionIgnoresNotFound() throws {
        #expect(throws: (any Error).self) { try swish.eval("(nth {:a 1} 0 :default)") }
        #expect(throws: (any Error).self) { try swish.eval("(nth #{:a} 0 :default)") }
    }

    // MARK: - The sources that must keep working

    @Test("Indexed and sequential sources are unaffected")
    func indexedSourcesStillWork() throws {
        #expect(try swish.eval("(nth [0 1 2] 1)") == .integer(1))
        #expect(try swish.eval("(nth (list 0 1 2) 1)") == .integer(1))
        #expect(try swish.eval("(nth (range 0 10) 5)") == .integer(5))
        #expect(try swish.eval("(nth (range) 10)") == .integer(10))
        #expect(try swish.eval(#"(nth "hello" 2)"#) == .character("l"))
        #expect(try swish.eval("(nth (int-array [0 1 2]) 2)") == .integer(2))
        #expect(try swish.eval("(nth (vec (object-array [0 1 2])) 2)") == .integer(2))
        #expect(try swish.eval("(nth nil 0)") == .nil)
        #expect(try swish.eval("(nth nil 10 :default)") == .keyword("default"))
    }

    @Test("A non-integer index throws regardless of the collection")
    func nonIntegerIndex() throws {
        #expect(throws: (any Error).self) { try swish.eval("(nth [0 1 2] nil)") }
        #expect(throws: (any Error).self) { try swish.eval("(nth nil nil)") }
        #expect(throws: (any Error).self) { try swish.eval(#"(nth [0 1 2] "x")"#) }
    }
}
