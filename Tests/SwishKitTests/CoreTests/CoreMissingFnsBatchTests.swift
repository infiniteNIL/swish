import Testing
@testable import SwishKit

/// The missing-function completeness batch: not-any?, printf, bounded-count,
/// partitionv, splitv-at, replace, indexed?, find-var, thread-bound?, biginteger,
/// find-keyword, and clojure.string/split-lines + replace-first + re-quote-replacement.
@Suite("Core missing-function batch Tests", .serialized)
struct CoreMissingFnsBatchTests {
    static let _shared = Evaluator()
    var evaluator: Evaluator { Self._shared }

    // MARK: - not-any?

    @Test("not-any? is true when no element satisfies the pred, false otherwise")
    func notAny() throws {
        #expect(try evaluator.eval("(not-any? odd? [2 4 6])") == .boolean(true))
        #expect(try evaluator.eval("(not-any? odd? [2 3 4])") == .boolean(false))
        #expect(try evaluator.eval("(not-any? odd? [])") == .boolean(true))
    }

    // MARK: - printf

    @Test("printf writes formatted output via *out*")
    func printf() throws {
        #expect(try evaluator.eval(#"(with-out-str (printf "%d-%s" 7 "x"))"#) == .string("7-x"))
    }

    // MARK: - bounded-count

    @Test("bounded-count returns count for counted colls, else counts up to n")
    func boundedCount() throws {
        #expect(try evaluator.eval("(bounded-count 10 [1 2 3])") == .integer(3))
        // Infinite lazy seq: must stop at n, not diverge.
        #expect(try evaluator.eval("(bounded-count 5 (range))") == .integer(5))
        #expect(try evaluator.eval("(bounded-count 5 (repeat 1))") == .integer(5))
    }

    // MARK: - partitionv

    @Test("partitionv returns vectors, honoring step and pad")
    func partitionv() throws {
        #expect(try evaluator.eval("(partitionv 2 [1 2 3 4])") == .list([.vector([.integer(1), .integer(2)], metadata: nil), .vector([.integer(3), .integer(4)], metadata: nil)], metadata: nil))
        #expect(try evaluator.eval("(vector? (first (partitionv 2 [1 2 3 4])))") == .boolean(true))
        // step
        #expect(try evaluator.eval("(partitionv 2 1 [1 2 3])") == .list([.vector([.integer(1), .integer(2)], metadata: nil), .vector([.integer(2), .integer(3)], metadata: nil)], metadata: nil))
        // incomplete final partition dropped without pad
        #expect(try evaluator.eval("(partitionv 2 [1 2 3])") == .list([.vector([.integer(1), .integer(2)], metadata: nil)], metadata: nil))
        // pad completes the final partition
        #expect(try evaluator.eval("(partitionv 3 3 [:a] [1 2 3 4])") == .list([.vector([.integer(1), .integer(2), .integer(3)], metadata: nil), .vector([.integer(4), .keyword("a")], metadata: nil)], metadata: nil))
    }

    // MARK: - splitv-at

    @Test("splitv-at returns [vector seq]")
    func splitvAt() throws {
        #expect(try evaluator.eval("(splitv-at 2 [1 2 3 4])") == .vector([.vector([.integer(1), .integer(2)], metadata: nil), .list([.integer(3), .integer(4)], metadata: nil)], metadata: nil))
        #expect(try evaluator.eval("(vector? (first (splitv-at 2 [1 2 3 4])))") == .boolean(true))
        #expect(try evaluator.eval("(vector? (second (splitv-at 2 [1 2 3 4])))") == .boolean(false))
    }

    // MARK: - replace

    @Test("replace maps keys of smap; vector in -> vector out, seq in -> seq out")
    func replace() throws {
        #expect(try evaluator.eval("(replace {2 :two} [1 2 3 2])") == .vector([.integer(1), .keyword("two"), .integer(3), .keyword("two")], metadata: nil))
        #expect(try evaluator.eval("(vector? (replace {2 :two} [1 2 3]))") == .boolean(true))
        #expect(try evaluator.eval("(replace {2 :two} '(1 2 3))") == .list([.integer(1), .keyword("two"), .integer(3)], metadata: nil))
    }

    @Test("replace has a 1-arity transducer form")
    func replaceTransducer() throws {
        #expect(try evaluator.eval("(into [] (replace {2 :two}) [1 2 3 2])") == .vector([.integer(1), .keyword("two"), .integer(3), .keyword("two")], metadata: nil))
    }

    // MARK: - indexed?

    @Test("indexed? is true for vectors, false for lists/seqs/strings")
    func indexed() throws {
        #expect(try evaluator.eval("(indexed? [1 2 3])") == .boolean(true))
        #expect(try evaluator.eval("(indexed? (first {:a 1}))") == .boolean(true))  // map entry
        #expect(try evaluator.eval("(indexed? '(1 2 3))") == .boolean(false))
        #expect(try evaluator.eval(#"(indexed? "abc")"#) == .boolean(false))
        #expect(try evaluator.eval("(indexed? (range 3))") == .boolean(false))
    }

    // MARK: - find-var

    @Test("find-var returns the var for a qualified symbol, nil for a missing var")
    func findVarBasics() throws {
        _ = try evaluator.eval("(def fv-target 42)")
        #expect(try evaluator.eval("(= (find-var 'user/fv-target) (var fv-target))") == .boolean(true))
        #expect(try evaluator.eval("(find-var 'user/no-such-var-here)") == .nil)
        #expect(try evaluator.eval("(var? (find-var 'clojure.core/map))") == .boolean(true))
    }

    @Test("find-var throws on an unqualified symbol and on a missing namespace")
    func findVarThrows() throws {
        #expect(throws: EvaluatorError.self) {
            try evaluator.eval("(find-var 'unqualified)")
        }
        #expect(throws: EvaluatorError.self) {
            try evaluator.eval("(find-var 'no.such.ns/foo)")
        }
    }

    // MARK: - thread-bound?

    @Test("thread-bound? is false at the root, true inside a binding")
    func threadBound() throws {
        _ = try evaluator.eval("(def ^:dynamic *tb* 0)")
        #expect(try evaluator.eval("(thread-bound? (var *tb*))") == .boolean(false))
        #expect(try evaluator.eval("(binding [*tb* 1] (thread-bound? (var *tb*)))") == .boolean(true))
        // vacuously true with no vars
        #expect(try evaluator.eval("(thread-bound?)") == .boolean(true))
    }

    // MARK: - biginteger

    @Test("biginteger coerces like bigint (Swish has no distinct BigInteger type)")
    func biginteger() throws {
        #expect(try evaluator.eval("(= (biginteger 5) (bigint 5))") == .boolean(true))
        #expect(try evaluator.eval("(bigint? (biginteger 5))") == .boolean(true))
        #expect(try evaluator.eval("(biginteger 3.9)") == (try evaluator.eval("(bigint 3.9)")))
    }

    // MARK: - find-keyword

    @Test("find-keyword returns the keyword for a valid name (Swish keywords are not interned)")
    func findKeyword() throws {
        #expect(try evaluator.eval(#"(find-keyword "foo")"#) == .keyword("foo"))
        #expect(try evaluator.eval(#"(find-keyword "ns" "nm")"#) == .keyword("ns/nm"))
    }

    // MARK: - clojure.string/split-lines

    @Test("split-lines splits on \\n and \\r\\n, dropping trailing empty lines")
    func splitLines() throws {
        _ = try evaluator.eval("(require '[clojure.string])")
        #expect(try evaluator.eval(#"(clojure.string/split-lines "a\nb\nc")"#) == .vector([.string("a"), .string("b"), .string("c")], metadata: nil))
        #expect(try evaluator.eval(#"(clojure.string/split-lines "a\r\nb\r\nc")"#) == .vector([.string("a"), .string("b"), .string("c")], metadata: nil))
        // trailing newline dropped; internal empty kept
        #expect(try evaluator.eval(#"(clojure.string/split-lines "a\n")"#) == .vector([.string("a")], metadata: nil))
        #expect(try evaluator.eval(#"(clojure.string/split-lines "a\n\nb")"#) == .vector([.string("a"), .string(""), .string("b")], metadata: nil))
        // a lone \r is not a boundary (matching #"\r?\n")
        #expect(try evaluator.eval(#"(clojure.string/split-lines "a\rb")"#) == .vector([.string("a\rb")], metadata: nil))
    }

    // MARK: - clojure.string/replace-first

    @Test("replace-first replaces only the first match (string, char, regex, fn)")
    func replaceFirst() throws {
        _ = try evaluator.eval("(require '[clojure.string])")
        #expect(try evaluator.eval(#"(clojure.string/replace-first "aXbXc" "X" "_")"#) == .string("a_bXc"))
        #expect(try evaluator.eval(#"(clojure.string/replace-first "a1b2" #"\d" "N")"#) == .string("aNb2"))
        #expect(try evaluator.eval(#"(clojure.string/replace-first "hello" \l \L)"#) == .string("heLlo"))
        #expect(try evaluator.eval(#"(clojure.string/replace-first "abc" #"." (fn [m] (clojure.string/upper-case m)))"#) == .string("Abc"))
    }

    // MARK: - clojure.string/re-quote-replacement

    @Test("re-quote-replacement escapes $ and backslash so replacement is literal")
    func reQuoteReplacement() throws {
        _ = try evaluator.eval("(require '[clojure.string])")
        #expect(try evaluator.eval(#"(clojure.string/re-quote-replacement "$1")"#) == .string("\\$1"))
        // used as a literal replacement, $1 is NOT treated as a group reference
        #expect(try evaluator.eval(#"(clojure.string/replace "a1b" #"(\d)" (clojure.string/re-quote-replacement "$1"))"#) == .string("a$1b"))
    }
}
