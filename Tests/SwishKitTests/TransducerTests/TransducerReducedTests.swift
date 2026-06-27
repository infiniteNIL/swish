import Testing
@testable import SwishKit

@Suite("Transducer: reduced", .serialized)
struct TransducerReducedTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - reduced?

    @Test("reduced? returns true for reduced value")
    func reducedPredicateTrue() throws {
        #expect(try swish.eval("(reduced? (reduced 42))") == .boolean(true))
    }

    @Test("reduced? returns false for plain value")
    func reducedPredicateFalse() throws {
        #expect(try swish.eval("(reduced? 42)") == .boolean(false))
    }

    @Test("reduced? returns false for nil")
    func reducedPredicateNil() throws {
        #expect(try swish.eval("(reduced? nil)") == .boolean(false))
    }

    // MARK: - unreduced

    @Test("unreduced unwraps a reduced value")
    func unreducedUnwraps() throws {
        #expect(try swish.eval("(unreduced (reduced 42))") == .integer(42))
    }

    @Test("unreduced returns non-reduced value unchanged")
    func unreducedPassthrough() throws {
        #expect(try swish.eval("(unreduced 42)") == .integer(42))
    }

    @Test("unreduced on nil returns nil unchanged")
    func unreducedNil() throws {
        #expect(try swish.eval("(unreduced nil)") == .nil)
    }

    // MARK: - ensure-reduced

    @Test("ensure-reduced wraps plain value")
    func ensureReducedWraps() throws {
        #expect(try swish.eval("(reduced? (ensure-reduced 42))") == .boolean(true))
    }

    @Test("ensure-reduced on already-reduced value is a no-op")
    func ensureReducedIdempotent() throws {
        #expect(try swish.eval("(let [r (reduced 42)] (= r (ensure-reduced r)))") == .boolean(true))
    }

    // MARK: - deref on reduced

    @Test("deref unwraps a reduced value")
    func derefReduced() throws {
        #expect(try swish.eval("@(reduced :x)") == .keyword("x"))
    }

    @Test("deref on nested reduced unwraps one level")
    func derefReducedOnce() throws {
        #expect(try swish.eval("(reduced? @(reduced (reduced 1)))") == .boolean(true))
    }

    // MARK: - reduce early exit

    @Test("reduce short-circuits on reduced")
    func reduceShortCircuits() throws {
        let result = try swish.eval("""
            (reduce (fn [acc x]
                      (if (= x 3) (reduced acc) (+ acc x)))
                    0 [1 2 3 4 5])
            """)
        #expect(result == .integer(3))
    }

    @Test("reduce over lazy seq with early exit")
    func reduceLazyEarlyExit() throws {
        let result = try swish.eval("""
            (reduce (fn [acc x]
                      (if (= x 3) (reduced acc) (conj acc x)))
                    [] (range 100))
            """)
        #expect(result == .vector([.integer(0), .integer(1), .integer(2)], metadata: nil))
    }

    @Test("reduce over infinite seq terminates with reduced")
    func reduceInfiniteTerminates() throws {
        let result = try swish.eval("""
            (reduce (fn [acc x]
                      (if (= (count acc) 4) (reduced acc) (conj acc x)))
                    [] (range))
            """)
        #expect(result == .vector([0, 1, 2, 3].map { .integer($0) }, metadata: nil))
    }

    // MARK: - comp

    @Test("comp with no args returns identity")
    func compNoArgs() throws {
        #expect(try swish.eval("((comp) 42)") == .integer(42))
    }

    @Test("comp with single fn returns that fn")
    func compOneFn() throws {
        #expect(try swish.eval("((comp inc) 5)") == .integer(6))
    }

    @Test("comp of two fns")
    func compTwoFns() throws {
        #expect(try swish.eval("((comp inc #(* % 2)) 3)") == .integer(7))
    }

    @Test("comp of three fns")
    func compThreeFns() throws {
        #expect(try swish.eval("((comp str inc #(* % 2)) 3)") == .string("7"))
    }

    @Test("comp applies rightmost first")
    func compOrder() throws {
        #expect(try swish.eval("((comp #(- % 1) #(* % 2)) 5)") == .integer(9))
    }

    // MARK: - volatile! / vswap! / vreset!

    @Test("volatile! creates an atom-like container")
    func volatileCreate() throws {
        #expect(try swish.eval("@(volatile! 42)") == .integer(42))
    }

    @Test("vswap! updates volatile value")
    func vswapUpdates() throws {
        let result = try swish.eval("""
            (let [v (volatile! 0)]
              (vswap! v inc)
              @v)
            """)
        #expect(result == .integer(1))
    }

    @Test("vreset! sets volatile value")
    func vresetSets() throws {
        let result = try swish.eval("""
            (let [v (volatile! 0)]
              (vreset! v 99)
              @v)
            """)
        #expect(result == .integer(99))
    }
}
