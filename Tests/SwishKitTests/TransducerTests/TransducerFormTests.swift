import Testing
@testable import SwishKit

@Suite("Transducer: 1-arity HOF forms", .serialized)
struct TransducerFormTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - Stateless transducers

    @Test("(into [] (map inc) [1 2 3])")
    func mapInc() throws {
        #expect(try swish.eval("(into [] (map inc) [1 2 3])")
            == .vector([2, 3, 4].map { .integer($0) }, metadata: nil))
    }

    @Test("(into [] (filter even?) [1 2 3 4])")
    func filterEven() throws {
        #expect(try swish.eval("(into [] (filter even?) [1 2 3 4])")
            == .vector([2, 4].map { .integer($0) }, metadata: nil))
    }

    @Test("(into [] (remove odd?) [1 2 3 4])")
    func removeOdd() throws {
        #expect(try swish.eval("(into [] (remove odd?) [1 2 3 4])")
            == .vector([2, 4].map { .integer($0) }, metadata: nil))
    }

    @Test("(into [] (keep #(when (even? %) (* % 2))) [1 2 3 4])")
    func keepEven() throws {
        #expect(try swish.eval("(into [] (keep #(when (even? %) (* % 2))) [1 2 3 4])")
            == .vector([4, 8].map { .integer($0) }, metadata: nil))
    }

    @Test("(into [] cat [[1 2] [3 4]])")
    func catFlattens() throws {
        #expect(try swish.eval("(into [] cat [[1 2] [3 4]])")
            == .vector([1, 2, 3, 4].map { .integer($0) }, metadata: nil))
    }

    @Test("(into [] (mapcat #(list % (* % 10))) [1 2 3])")
    func mapcatTransducer() throws {
        #expect(try swish.eval("(into [] (mapcat #(list % (* % 10))) [1 2 3])")
            == .vector([1, 10, 2, 20, 3, 30].map { .integer($0) }, metadata: nil))
    }

    // MARK: - Stateful transducers

    @Test("(into [] (take 3) [1 2 3 4 5])")
    func takeForms() throws {
        #expect(try swish.eval("(into [] (take 3) [1 2 3 4 5])")
            == .vector([1, 2, 3].map { .integer($0) }, metadata: nil))
    }

    @Test("(into [] (drop 2) [1 2 3 4 5])")
    func dropForms() throws {
        #expect(try swish.eval("(into [] (drop 2) [1 2 3 4 5])")
            == .vector([3, 4, 5].map { .integer($0) }, metadata: nil))
    }

    @Test("(into [] (take-while #(< % 4)) [1 2 3 4 5])")
    func takeWhileForms() throws {
        #expect(try swish.eval("(into [] (take-while #(< % 4)) [1 2 3 4 5])")
            == .vector([1, 2, 3].map { .integer($0) }, metadata: nil))
    }

    @Test("(into [] (drop-while #(< % 3)) [1 2 3 4 5])")
    func dropWhileForms() throws {
        #expect(try swish.eval("(into [] (drop-while #(< % 3)) [1 2 3 4 5])")
            == .vector([3, 4, 5].map { .integer($0) }, metadata: nil))
    }

    @Test("(into [] (take-nth 2) [0 1 2 3 4])")
    func takeNth() throws {
        #expect(try swish.eval("(into [] (take-nth 2) [0 1 2 3 4])")
            == .vector([0, 2, 4].map { .integer($0) }, metadata: nil))
    }

    @Test("(into [] (partition-all 2) [1 2 3 4 5]) flushes trailing partition")
    func partitionAll() throws {
        let result = try swish.eval("(into [] (partition-all 2) [1 2 3 4 5])")
        #expect(result == .vector([
            .vector([.integer(1), .integer(2)], metadata: nil),
            .vector([.integer(3), .integer(4)], metadata: nil),
            .vector([.integer(5)], metadata: nil),
        ], metadata: nil))
    }

    @Test("(into [] (distinct) [1 1 2 2 3])")
    func distinctTransducer() throws {
        #expect(try swish.eval("(into [] (distinct) [1 1 2 2 3])")
            == .vector([1, 2, 3].map { .integer($0) }, metadata: nil))
    }

    @Test("(into [] (dedupe) [1 1 2 1 1 3])")
    func dedupeTransducer() throws {
        #expect(try swish.eval("(into [] (dedupe) [1 1 2 1 1 3])")
            == .vector([1, 2, 1, 3].map { .integer($0) }, metadata: nil))
    }

    @Test("(into [] (interpose :x) [1 2 3])")
    func interposeTransducer() throws {
        #expect(try swish.eval("(into [] (interpose :x) [1 2 3])")
            == .vector([.integer(1), .keyword("x"), .integer(2), .keyword("x"), .integer(3)], metadata: nil))
    }

    @Test("(into [] (map-indexed vector) [:a :b :c])")
    func mapIndexed() throws {
        #expect(try swish.eval("(into [] (map-indexed vector) [:a :b :c])")
            == .vector([
                .vector([.integer(0), .keyword("a")], metadata: nil),
                .vector([.integer(1), .keyword("b")], metadata: nil),
                .vector([.integer(2), .keyword("c")], metadata: nil),
            ], metadata: nil))
    }

    @Test("(into [] (keep-indexed #(when (even? %1) %2)) [:a :b :c :d])")
    func keepIndexed() throws {
        #expect(try swish.eval("(into [] (keep-indexed #(when (even? %1) %2)) [:a :b :c :d])")
            == .vector([.keyword("a"), .keyword("c")], metadata: nil))
    }

    // MARK: - Composition

    @Test("(into [] (comp (filter odd?) (map inc)) (range 10))")
    func compFilterMap() throws {
        #expect(try swish.eval("(into [] (comp (filter odd?) (map inc)) (range 10))")
            == .vector([2, 4, 6, 8, 10].map { .integer($0) }, metadata: nil))
    }

    @Test("(into [] (comp (take 5) (filter even?)) (range))")
    func compTakeFilter() throws {
        #expect(try swish.eval("(into [] (comp (take 5) (filter even?)) (range))")
            == .vector([0, 2, 4].map { .integer($0) }, metadata: nil))
    }

    @Test("take 3 from infinite input")
    func takeInfinite() throws {
        #expect(try swish.eval("(into [] (take 3) (range))")
            == .vector([0, 1, 2].map { .integer($0) }, metadata: nil))
    }

    // MARK: - transduce with 1-arity forms

    @Test("(transduce (map inc) + 0 [1 2 3])")
    func transduceMapInc() throws {
        #expect(try swish.eval("(transduce (map inc) + 0 [1 2 3])") == .integer(9))
    }

    @Test("(transduce (filter even?) conj [] (range 10))")
    func transduceFilterEven() throws {
        #expect(try swish.eval("(transduce (filter even?) conj [] (range 10))")
            == .vector([0, 2, 4, 6, 8].map { .integer($0) }, metadata: nil))
    }

    // MARK: - Stateful transducer fresh state per call

    @Test("stateful transducer reused creates fresh state each time")
    func freshStatePerCall() throws {
        let result = try swish.eval("""
            (let [xf (take 2)]
              [(into [] xf [1 2 3]) (into [] xf [4 5 6])])
            """)
        #expect(result == .vector([
            .vector([.integer(1), .integer(2)], metadata: nil),
            .vector([.integer(4), .integer(5)], metadata: nil),
        ], metadata: nil))
    }

    // MARK: - Seq forms still work

    @Test("take still works as lazy seq")
    func takeSeq() throws {
        #expect(try swish.eval("(take 3 (range))") == .list([0, 1, 2].map { .integer($0) }, metadata: nil))
    }

    @Test("drop still works as lazy seq")
    func dropSeq() throws {
        #expect(try swish.eval("(take 3 (drop 2 (range)))") == .list([2, 3, 4].map { .integer($0) }, metadata: nil))
    }

    @Test("filter still works as lazy seq")
    func filterSeq() throws {
        #expect(try swish.eval("(take 3 (filter even? (range)))") == .list([0, 2, 4].map { .integer($0) }, metadata: nil))
    }

    @Test("map still works as lazy seq")
    func mapSeq() throws {
        #expect(try swish.eval("(take 3 (map inc (range)))") == .list([1, 2, 3].map { .integer($0) }, metadata: nil))
    }

    @Test("remove works as lazy seq")
    func removeSeq() throws {
        #expect(try swish.eval("(remove odd? [1 2 3 4 5])") == .list([2, 4].map { .integer($0) }, metadata: nil))
    }

    @Test("take-nth lazy seq form")
    func takeNthSeq() throws {
        #expect(try swish.eval("(take 4 (take-nth 2 (range)))") == .list([0, 2, 4, 6].map { .integer($0) }, metadata: nil))
    }

    @Test("dedupe lazy seq form")
    func dedupeSeq() throws {
        #expect(try swish.eval("(dedupe [1 1 2 3 3])") == .list([1, 2, 3].map { .integer($0) }, metadata: nil))
    }
}
