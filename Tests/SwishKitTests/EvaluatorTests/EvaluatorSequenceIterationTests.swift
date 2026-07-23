import Testing
@testable import SwishKit

@Suite("Evaluator Sequence Iteration Tests", .serialized)
struct EvaluatorSequenceIterationTests {
    static let _shared = Evaluator()
    var evaluator: Evaluator { Self._shared }

    // MARK: - mapcat

    @Test("mapcat maps and concatenates")
    func mapcatBasic() throws {
        #expect(try evaluator.eval("(mapcat (fn [x] [x x]) [1 2 3])") == .list([.integer(1), .integer(1), .integer(2), .integer(2), .integer(3), .integer(3)], metadata: nil))
    }

    // MARK: - keep

    @Test("keep returns non-nil results")
    func keepBasic() throws {
        #expect(try evaluator.eval("(keep (fn [x] (when (odd? x) x)) [1 2 3 4 5])") == .list([.integer(1), .integer(3), .integer(5)], metadata: nil))
    }

    @Test("keep includes false results")
    func keepIncludesFalse() throws {
        #expect(try evaluator.eval("(keep (fn [x] (odd? x)) [1 2 3])") == .list([.boolean(true), .boolean(false), .boolean(true)], metadata: nil))
    }

    @Test("keep excludes nil results")
    func keepExcludesNil() throws {
        #expect(try evaluator.eval("(keep (fn [x] (when (> x 3) x)) [1 2 3 4 5])") == .list([.integer(4), .integer(5)], metadata: nil))
    }

    @Test("keep on empty collection returns empty list")
    func keepEmpty() throws {
        #expect(try evaluator.eval("(keep identity [])") == .list([], metadata: nil))
    }

    @Test("keep works on a list")
    func keepOnList() throws {
        #expect(try evaluator.eval("(keep (fn [x] (when (even? x) x)) '(1 2 3 4))") == .list([.integer(2), .integer(4)], metadata: nil))
    }

    // MARK: - keep-indexed

    @Test("keep-indexed passes index and item to f")
    func keepIndexedBasic() throws {
        #expect(try evaluator.eval("(keep-indexed (fn [i x] (when (even? i) x)) [:a :b :c :d :e])") == .list([.keyword("a"), .keyword("c"), .keyword("e")], metadata: nil))
    }

    @Test("keep-indexed includes false results")
    func keepIndexedIncludesFalse() throws {
        #expect(try evaluator.eval("(keep-indexed (fn [i x] (even? i)) [10 20 30])") == .list([.boolean(true), .boolean(false), .boolean(true)], metadata: nil))
    }

    @Test("keep-indexed excludes nil results")
    func keepIndexedExcludesNil() throws {
        #expect(try evaluator.eval("(keep-indexed (fn [i x] (when (odd? i) x)) [:a :b :c :d])") == .list([.keyword("b"), .keyword("d")], metadata: nil))
    }

    @Test("keep-indexed on empty collection returns empty list")
    func keepIndexedEmpty() throws {
        #expect(try evaluator.eval("(keep-indexed (fn [i x] x) [])") == .list([], metadata: nil))
    }

    @Test("keep-indexed index starts at 0")
    func keepIndexedIndexStartsAt0() throws {
        #expect(try evaluator.eval("(keep-indexed (fn [i x] i) [:a :b :c])") == .list([.integer(0), .integer(1), .integer(2)], metadata: nil))
    }

    // MARK: - map-indexed

    @Test("map-indexed applies f with index and item")
    func mapIndexedBasic() throws {
        #expect(try evaluator.eval("(map-indexed (fn [i x] (* i x)) [1 2 3])") == .list([.integer(0), .integer(2), .integer(6)], metadata: nil))
    }

    @Test("map-indexed index starts at 0")
    func mapIndexedIndexStartsAt0() throws {
        #expect(try evaluator.eval("(map-indexed (fn [i x] i) [:a :b :c])") == .list([.integer(0), .integer(1), .integer(2)], metadata: nil))
    }

    @Test("map-indexed on empty collection returns empty list")
    func mapIndexedEmpty() throws {
        #expect(try evaluator.eval("(map-indexed (fn [i x] x) [])") == .list([], metadata: nil))
    }

    @Test("map-indexed works on a list")
    func mapIndexedOnList() throws {
        #expect(try evaluator.eval("(map-indexed (fn [i x] (+ i x)) '(10 20 30))") == .list([.integer(10), .integer(21), .integer(32)], metadata: nil))
    }

    // MARK: - dorun

    @Test("dorun on empty collection returns nil")
    func dorunEmpty() throws {
        #expect(try evaluator.eval("(dorun [])") == .nil)
    }

    @Test("dorun returns nil, not the seq")
    func dorunReturnsNil() throws {
        #expect(try evaluator.eval("(dorun [1 2 3])") == .nil)
    }

    @Test("dorun with count returns nil")
    func dorunWithCount() throws {
        #expect(try evaluator.eval("(dorun 2 [1 2 3 4 5])") == .nil)
    }

    // MARK: - doall

    @Test("doall on empty collection returns empty vector")
    func doallEmpty() throws {
        #expect(try evaluator.eval("(doall [])") == .vector([], metadata: nil))
    }

    @Test("doall returns the collection itself")
    func doallVector() throws {
        #expect(try evaluator.eval("(doall [1 2 3])") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("doall works on a list")
    func doallList() throws {
        #expect(try evaluator.eval("(doall '(1 2 3))") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("doall with count returns full collection")
    func doallWithCount() throws {
        #expect(try evaluator.eval("(doall 2 [1 2 3])") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    // MARK: - doseq

    @Test("doseq returns nil")
    func doseqReturnsNil() throws {
        #expect(try evaluator.eval("(doseq [x [1 2 3]] x)") == .nil)
    }

    @Test("doseq iterates over a collection")
    func doseqBasic() throws {
        #expect(try evaluator.eval("""
            (let [result (atom [])]
              (doseq [x [1 2 3]]
                (swap! result conj x))
              @result)
            """) == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("doseq with multiple bindings is nested")
    func doseqMultipleBindings() throws {
        #expect(try evaluator.eval("""
            (let [result (atom [])]
              (doseq [x [1 2]
                      y [:a :b]]
                (swap! result conj [x y]))
              @result)
            """) == .vector([
                .vector([.integer(1), .keyword("a")], metadata: nil),
                .vector([.integer(1), .keyword("b")], metadata: nil),
                .vector([.integer(2), .keyword("a")], metadata: nil),
                .vector([.integer(2), .keyword("b")], metadata: nil)
            ], metadata: nil))
    }

    @Test("doseq :when skips non-matching elements")
    func doseqWhen() throws {
        #expect(try evaluator.eval("""
            (let [result (atom [])]
              (doseq [x [1 2 3 4 5]
                      :when (odd? x)]
                (swap! result conj x))
              @result)
            """) == .vector([.integer(1), .integer(3), .integer(5)], metadata: nil))
    }

    @Test("doseq :while stops at first false")
    func doseqWhile() throws {
        #expect(try evaluator.eval("""
            (let [result (atom [])]
              (doseq [x [1 2 3 4 5]
                      :while (< x 4)]
                (swap! result conj x))
              @result)
            """) == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("doseq :let binds in scope")
    func doseqLet() throws {
        #expect(try evaluator.eval("""
            (let [result (atom [])]
              (doseq [x [1 2 3]
                      :let [doubled (* x 2)]]
                (swap! result conj doubled))
              @result)
            """) == .vector([.integer(2), .integer(4), .integer(6)], metadata: nil))
    }

    @Test("doseq on empty collection runs body zero times")
    func doseqEmpty() throws {
        #expect(try evaluator.eval("""
            (let [result (atom [])]
              (doseq [x []]
                (swap! result conj x))
              @result)
            """) == .vector([], metadata: nil))
    }
}
