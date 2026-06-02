import Testing
@testable import SwishKit

@Suite("Transducer: sequence / eduction", .serialized)
struct TransducerSequenceTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - sequence 1-arity (coerce to seq)

    @Test("(sequence [1 2 3]) returns a seq")
    func sequenceCoerceVector() throws {
        #expect(try swish.eval("(sequence [1 2 3])")
            == .list([1, 2, 3].map { .integer($0) }, metadata: nil))
    }

    @Test("(sequence nil) returns empty list")
    func sequenceNil() throws {
        #expect(try swish.eval("(sequence nil)") == .list([], metadata: nil))
    }

    @Test("(sequence '(1 2)) returns the list unchanged")
    func sequenceAlreadySeq() throws {
        #expect(try swish.eval("(sequence '(1 2))")
            == .list([.integer(1), .integer(2)], metadata: nil))
    }

    // MARK: - sequence 2-arity (transducer)

    @Test("(sequence (map inc) [1 2 3])")
    func sequenceMapInc() throws {
        #expect(try swish.eval("(into [] (sequence (map inc) [1 2 3]))")
            == .vector([2, 3, 4].map { .integer($0) }, metadata: nil))
    }

    @Test("(sequence (filter even?) [1 2 3 4])")
    func sequenceFilterEven() throws {
        #expect(try swish.eval("(into [] (sequence (filter even?) [1 2 3 4]))")
            == .vector([2, 4].map { .integer($0) }, metadata: nil))
    }

    @Test("sequence over infinite range terminates with take")
    func sequenceInfiniteRange() throws {
        #expect(try swish.eval("(take 3 (sequence (map inc) (range)))")
            == .list([1, 2, 3].map { .integer($0) }, metadata: nil))
    }

    @Test("(sequence (take 3) (range))")
    func sequenceTakeInfinite() throws {
        #expect(try swish.eval("(into [] (sequence (take 3) (range)))")
            == .vector([0, 1, 2].map { .integer($0) }, metadata: nil))
    }

    @Test("sequence with filter over infinite seq")
    func sequenceFilterInfinite() throws {
        #expect(try swish.eval("(take 4 (sequence (filter even?) (range)))")
            == .list([0, 2, 4, 6].map { .integer($0) }, metadata: nil))
    }

    @Test("(sequence (partition-all 2) (range 5)) flushes trailing partition")
    func sequencePartitionAllFlush() throws {
        let result = try swish.eval("(into [] (sequence (partition-all 2) (range 5)))")
        #expect(result == .vector([
            .vector([.integer(0), .integer(1)], metadata: nil),
            .vector([.integer(2), .integer(3)], metadata: nil),
            .vector([.integer(4)], metadata: nil),
        ], metadata: nil))
    }

    // MARK: - eduction

    @Test("eduction applies transducers lazily")
    func eductionBasic() throws {
        #expect(try swish.eval("(into [] (eduction (filter odd?) (map inc) [1 2 3 4 5]))")
            == .vector([2, 4, 6].map { .integer($0) }, metadata: nil))
    }

    @Test("eduction over infinite seq")
    func eductionInfinite() throws {
        #expect(try swish.eval("(into [] (eduction (take 4) (filter even?) (range)))")
            == .vector([0, 2].map { .integer($0) }, metadata: nil))
    }

    @Test("eduction creates fresh transducer state per call")
    func eductionFreshState() throws {
        let result = try swish.eval("""
            (let [e (eduction (take 2) [1 2 3 4])]
              [(into [] e) (into [] e)])
            """)
        #expect(result == .vector([
            .vector([.integer(1), .integer(2)], metadata: nil),
            .vector([.integer(1), .integer(2)], metadata: nil),
        ], metadata: nil))
    }
}
