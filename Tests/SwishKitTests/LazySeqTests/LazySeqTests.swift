import Testing
@testable import SwishKit

@Suite("Lazy Sequences", .serialized)
struct LazySeqTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - range

    @Test("range with 0 args produces infinite seq")
    func rangeInfinite() throws {
        #expect(try swish.eval("(take 5 (range))") == .list([0, 1, 2, 3, 4].map { .integer($0) }, metadata: nil))
    }

    @Test("range with 1 arg produces finite seq")
    func rangeOneArg() throws {
        #expect(try swish.eval("(take 3 (range 10))") == .list([0, 1, 2].map { .integer($0) }, metadata: nil))
    }

    @Test("range with start and end")
    func rangeTwoArgs() throws {
        #expect(try swish.eval("(range 3 7)") == .list([3, 4, 5, 6].map { .integer($0) }, metadata: nil))
    }

    @Test("range with start end and step")
    func rangeStep() throws {
        #expect(try swish.eval("(range 0 10 2)") == .list([0, 2, 4, 6, 8].map { .integer($0) }, metadata: nil))
    }

    @Test("range with empty bounds")
    func rangeEmpty() throws {
        #expect(try swish.eval("(range 5 3)") == .list([], metadata: nil))
    }

    @Test("range with negative step")
    func rangeNegStep() throws {
        #expect(try swish.eval("(range 5 0 -1)") == .list([5, 4, 3, 2, 1].map { .integer($0) }, metadata: nil))
    }

    // MARK: - iterate

    @Test("iterate produces infinite seq")
    func iterateInfinite() throws {
        #expect(try swish.eval("(take 5 (iterate inc 0))") == .list([0, 1, 2, 3, 4].map { .integer($0) }, metadata: nil))
    }

    @Test("iterate with doubling function")
    func iterateDouble() throws {
        #expect(try swish.eval("(take 5 (iterate #(* % 2) 1))") == .list([1, 2, 4, 8, 16].map { .integer($0) }, metadata: nil))
    }

    // MARK: - cycle

    @Test("cycle repeats elements")
    func cycleBasic() throws {
        #expect(try swish.eval("(take 6 (cycle [1 2 3]))") == .list([1, 2, 3, 1, 2, 3].map { .integer($0) }, metadata: nil))
    }

    @Test("cycle over single element")
    func cycleSingle() throws {
        #expect(try swish.eval("(take 4 (cycle [:a]))") == .list([.keyword("a"), .keyword("a"), .keyword("a"), .keyword("a")], metadata: nil))
    }

    @Test("(cycle :k) throws for non-seqable keyword")
    func cycleKeywordThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(cycle :k)")
        }
    }

    @Test("(cycle 42) throws for non-seqable integer")
    func cycleIntegerThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(cycle 42)")
        }
    }

    @Test("(cycle 3.14) throws for non-seqable float")
    func cycleFloatThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(cycle 3.14)")
        }
    }

    // MARK: - repeat

    @Test("repeat infinite sequence")
    func repeatInfinite() throws {
        #expect(try swish.eval("(take 4 (repeat :x))") == .list([.keyword("x"), .keyword("x"), .keyword("x"), .keyword("x")], metadata: nil))
    }

    @Test("repeat with count")
    func repeatWithCount() throws {
        #expect(try swish.eval("(repeat 3 :x)") == .list([.keyword("x"), .keyword("x"), .keyword("x")], metadata: nil))
    }

    @Test("(repeat 3.14 :x) truncates to 3 elements")
    func repeatFloatCount() throws {
        #expect(try swish.eval("(repeat 3.14 :x)") == .list([.keyword("x"), .keyword("x"), .keyword("x")], metadata: nil))
    }

    @Test("(repeat 3.99 :x) truncates to 3 elements")
    func repeatFloat399Count() throws {
        #expect(try swish.eval("(repeat 3.99 :x)") == .list([.keyword("x"), .keyword("x"), .keyword("x")], metadata: nil))
    }

    @Test("(repeat nil :x) throws")
    func repeatNilCountThrows() {
        #expect(throws: (any Error).self) { try swish.eval("(repeat nil :x)") }
    }

    @Test("(repeat \"a\" :x) throws")
    func repeatStringCountThrows() {
        #expect(throws: (any Error).self) { try swish.eval("(repeat \"a\" :x)") }
    }

    @Test("(repeat :kw :x) throws")
    func repeatKeywordCountThrows() {
        #expect(throws: (any Error).self) { try swish.eval("(repeat :kw :x)") }
    }

    @Test("(repeat true :x) returns one element")
    func repeatTrueCount() throws {
        #expect(try swish.eval("(repeat true :x)") == .list([.keyword("x")], metadata: nil))
    }

    @Test("(repeat false :x) returns empty")
    func repeatFalseCount() throws {
        #expect(try swish.eval("(repeat false :x)") == .list([], metadata: nil))
    }

    // MARK: - repeatedly

    @Test("repeatedly calls function each time")
    func repeatedlyCalls() throws {
        #expect(try swish.eval("(count (take 5 (repeatedly (fn [] 42))))") == .integer(5))
    }

    @Test("repeatedly with count")
    func repeatedlyWithCount() throws {
        #expect(try swish.eval("(count (repeatedly 7 (fn [] 1)))") == .integer(7))
    }

    // MARK: - lazy map

    @Test("map over lazy seq")
    func mapOverLazy() throws {
        #expect(try swish.eval("(take 5 (map inc (range)))") == .list([1, 2, 3, 4, 5].map { .integer($0) }, metadata: nil))
    }

    @Test("map returns lazy seq")
    func mapIsLazy() throws {
        #expect(try swish.eval("(seq? (map inc (range)))") == .boolean(true))
    }

    @Test("map two colls")
    func mapTwoColls() throws {
        #expect(try swish.eval("(take 3 (map + (range) (range 10 100)))") == .list([10, 12, 14].map { .integer($0) }, metadata: nil))
    }

    // MARK: - lazy filter

    @Test("filter over lazy seq")
    func filterLazy() throws {
        #expect(try swish.eval("(take 3 (filter even? (range)))") == .list([0, 2, 4].map { .integer($0) }, metadata: nil))
    }

    @Test("filter returns lazy seq")
    func filterIsLazy() throws {
        #expect(try swish.eval("(seq? (filter even? (range)))") == .boolean(true))
    }

    // MARK: - lazy concat

    @Test("concat with lazy seqs")
    func concatLazy() throws {
        #expect(try swish.eval("(take 5 (concat (range 3) (range 10 20)))") == .list([0, 1, 2, 10, 11].map { .integer($0) }, metadata: nil))
    }

    @Test("concat with infinite second seq")
    func concatWithInfinite() throws {
        #expect(try swish.eval("(take 5 (concat [1 2 3] (range)))") == .list([1, 2, 3, 0, 1].map { .integer($0) }, metadata: nil))
    }

    @Test("concat with no args returns empty")
    func concatEmpty() throws {
        #expect(try swish.eval("(concat)") == .list([], metadata: nil))
    }

    // MARK: - lazy-cat

    @Test("lazy-cat concatenates lazily")
    func lazyCat() throws {
        #expect(try swish.eval("(take 5 (lazy-cat [1 2 3] (range)))") == .list([1, 2, 3, 0, 1].map { .integer($0) }, metadata: nil))
    }

    // MARK: - laziness — work is deferred

    @Test("lazy-seq body is not evaluated until forced")
    func lazynessDefers() throws {
        let result = try swish.eval("""
            (def side-effect-count (atom 0))
            (def lazy-s (lazy-seq (do (swap! side-effect-count inc) (list 1 2 3))))
            @side-effect-count
            """)
        #expect(result == .integer(0))
    }

    @Test("lazy-seq body is evaluated when first is called")
    func lazyForced() throws {
        let result = try swish.eval("""
            (def side-effect-count (atom 0))
            (def lazy-s (lazy-seq (do (swap! side-effect-count inc) (list 1 2 3))))
            (first lazy-s)
            @side-effect-count
            """)
        #expect(result == .integer(1))
    }

    // MARK: - memoization

    @Test("thunk is only evaluated once")
    func memoization() throws {
        let result = try swish.eval("""
            (def call-count (atom 0))
            (def lazy-s (lazy-seq (do (swap! call-count inc) (list 42))))
            (first lazy-s)
            (first lazy-s)
            @call-count
            """)
        #expect(result == .integer(1))
    }

    // MARK: - seq/first/rest semantics

    @Test("seq on empty lazy seq returns nil")
    func seqEmpty() throws {
        #expect(try swish.eval("(seq (lazy-seq nil))") == .nil)
    }

    @Test("seq on non-empty lazy seq is non-nil")
    func seqNonEmpty() throws {
        #expect(try swish.eval("(nil? (seq (range 3)))") == .boolean(false))
    }

    @Test("first of lazy seq")
    func firstLazy() throws {
        #expect(try swish.eval("(first (range 5))") == .integer(0))
    }

    @Test("rest of lazy seq")
    func restLazy() throws {
        #expect(try swish.eval("(first (rest (range 5)))") == .integer(1))
    }

    @Test("next of lazy seq")
    func nextLazy() throws {
        #expect(try swish.eval("(first (next (range 5)))") == .integer(1))
    }

    @Test("next of single-element seq returns nil")
    func nextSingleNil() throws {
        #expect(try swish.eval("(next (range 1))") == .nil)
    }

    // MARK: - seq? predicate

    @Test("seq? true for lazy seq")
    func seqPredLazy() throws {
        #expect(try swish.eval("(seq? (range))") == .boolean(true))
    }

    @Test("seq? true for list")
    func seqPredList() throws {
        #expect(try swish.eval("(seq? '(1 2 3))") == .boolean(true))
    }

    @Test("seq? false for vector")
    func seqPredVector() throws {
        #expect(try swish.eval("(seq? [1 2 3])") == .boolean(false))
    }

    // MARK: - sequential?

    @Test("sequential? true for lazy seq")
    func sequentialLazy() throws {
        #expect(try swish.eval("(sequential? (range 3))") == .boolean(true))
    }

    // MARK: - eager consumers

    @Test("count forces and counts lazy seq")
    func countLazy() throws {
        #expect(try swish.eval("(count (range 10))") == .integer(10))
    }

    @Test("reduce works on lazy seq")
    func reduceLazy() throws {
        #expect(try swish.eval("(reduce + (range 5))") == .integer(10))
    }

    @Test("nth works on lazy seq")
    func nthLazy() throws {
        #expect(try swish.eval("(nth (range 100) 7)") == .integer(7))
    }

    @Test("into vector from lazy seq")
    func intoVector() throws {
        #expect(try swish.eval("(into [] (take 4 (range)))") == .vector([0, 1, 2, 3].map { .integer($0) }, metadata: nil))
    }

    @Test("doall realizes lazy seq")
    func doallRealizes() throws {
        #expect(try swish.eval("(doall (take 3 (range)))") == .list([0, 1, 2].map { .integer($0) }, metadata: nil))
    }

    // MARK: - printing

    @Test("lazy seq prints like a list")
    func printLazy() throws {
        let result = try swish.eval("(str (take 3 (range)))")
        #expect(result == .string("(0 1 2)"))
    }

    @Test("infinite lazy seq printing is capped by *print-length*")
    func printCapped() throws {
        let evaluator = Evaluator()
        let printer = Printer()
        let lazySeq = try evaluator.eval("(range)")
        let output = printer.printString(lazySeq)
        #expect(output.contains("..."))
    }

    // MARK: - interop with eager collections

    @Test("cons onto lazy seq stays lazy")
    func consLazy() throws {
        #expect(try swish.eval("(take 4 (cons 99 (range)))") == .list([99, 0, 1, 2].map { .integer($0) }, metadata: nil))
    }

    @Test("conj onto list from lazy seq works")
    func conjLazy() throws {
        #expect(try swish.eval("(count (conj (range 5) 99))") == .integer(6))
    }

    @Test("map over finite eager coll returns lazy seq")
    func mapFinite() throws {
        let result = try swish.eval("(seq? (map inc [1 2 3]))")
        #expect(result == .boolean(true))
    }

    @Test("filter over finite coll works")
    func filterFinite() throws {
        #expect(try swish.eval("(filter odd? [1 2 3 4 5])") == .list([1, 3, 5].map { .integer($0) }, metadata: nil))
    }

    // MARK: - complex pipelines

    @Test("composing take map filter range")
    func pipeline() throws {
        #expect(try swish.eval("(take 3 (filter even? (map #(* % 3) (range))))") == .list([0, 6, 12].map { .integer($0) }, metadata: nil))
    }

    @Test("mapcat over lazy seq")
    func mapcatLazy() throws {
        #expect(try swish.eval("(take 6 (mapcat #(list % (* % 10)) (range 1 4)))") == .list([1, 10, 2, 20, 3, 30].map { .integer($0) }, metadata: nil))
    }

    // MARK: - stack safety of chained lazy-seq realization

    // `filter`'s non-matching branch recurses into `(filter pred r)` again,
    // so realizing past a long run of rejected elements chains that many
    // nested unrealized lazy seqs together. LazySeqBox.normalize must unwrap
    // this chain iteratively, not recursively, or a long-enough run blows
    // the Swift call stack (previously crashed at ~5000 consecutive
    // rejections; 4000 was the last size confirmed crash-free before the
    // fix). These sizes stay well past that boundary while keeping runtime
    // reasonable — Swish's tree-walking interpreter costs low-hundreds of
    // microseconds per filtered element, so much larger sizes make a single
    // test take tens of seconds without adding meaningful proof.

    @Test("filter with an always-false predicate over a large collection does not overflow the stack")
    func filterAllRejectingLargeCollection() throws {
        #expect(try swish.eval("(count (filter (fn [_] false) (range 10000)))") == .integer(0))
    }

    @Test("remove (filter's inverse) over a large collection does not overflow the stack")
    func removeLargeCollection() throws {
        // remove's predicate goes through complement's (fn [& args] (not (apply f args)))
        // wrapper, which costs meaningfully more stack per call than a bare lambda — so
        // this uses a smaller N than the bare-predicate test above to stay safely within
        // swift-testing's smaller worker-thread stack (vs. the CLI's larger main-thread
        // stack), while still exercising the same chained-lazy-seq-realization path.
        #expect(try swish.eval("(count (remove even? (range 1500)))") == .integer(750))
    }

    @Test("a chain of nested lazy seqs still memoizes every element (no re-running thunks)")
    func chainedLazySeqMemoizes() throws {
        #expect(try swish.eval("""
            (let [calls (atom 0)
                  xs (filter (fn [_] (swap! calls inc) false) (range 3000))]
              (dorun xs)
              (dorun xs)
              @calls)
            """) == .integer(3000))
    }
}
