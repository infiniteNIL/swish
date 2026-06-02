import Testing
@testable import SwishKit

@Suite("Transducer: completing / transduce / into", .serialized)
struct TransducerCoreTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - completing

    @Test("completing wraps a 2-arity fn with identity completion")
    func completingDefault() throws {
        let result = try swish.eval("""
            (let [rf (completing +)]
              (rf (rf (rf) 1) 2))
            """)
        #expect(result == .integer(3))
    }

    @Test("completing uses supplied completion fn")
    func completingCustom() throws {
        let result = try swish.eval("""
            (let [rf (completing + str)]
              (rf 42))
            """)
        #expect(result == .string("42"))
    }

    @Test("completing 0-arity delegates to f")
    func completingInit() throws {
        #expect(try swish.eval("((completing +))") == .integer(0))
    }

    @Test("completing step delegates to f")
    func completingStep() throws {
        #expect(try swish.eval("((completing +) 10 5)") == .integer(15))
    }

    // MARK: - transduce with identity transducer

    @Test("transduce identity passthrough")
    func transduceIdentity() throws {
        #expect(try swish.eval("(transduce identity (completing +) 0 [1 2 3])") == .integer(6))
    }

    @Test("transduce identity with conj")
    func transduceIdentityConj() throws {
        #expect(try swish.eval("(transduce identity conj [] [1 2 3])")
            == .vector([1, 2, 3].map { .integer($0) }, metadata: nil))
    }

    @Test("transduce identity over empty coll")
    func transduceIdentityEmpty() throws {
        #expect(try swish.eval("(transduce identity (completing +) 0 [])") == .integer(0))
    }

    @Test("transduce no-init arity uses (f)")
    func transduceNoInit() throws {
        #expect(try swish.eval("(transduce identity (completing +) [1 2 3])") == .integer(6))
    }

    // MARK: - transduce with manually constructed transducer

    @Test("transduce with a custom stateless transducer")
    func transduceCustomStateless() throws {
        let result = try swish.eval("""
            (let [doubling-xf (fn [rf]
                                (fn
                                  ([] (rf))
                                  ([result] (rf result))
                                  ([result input] (rf result (* input 2)))))]
              (transduce doubling-xf + 0 [1 2 3]))
            """)
        #expect(result == .integer(12))
    }

    @Test("transduce with early-exit transducer")
    func transduceEarlyExit() throws {
        let result = try swish.eval("""
            (let [take2 (fn [rf]
                          (let [n (atom 2)]
                            (fn
                              ([] (rf))
                              ([result] (rf result))
                              ([result input]
                               (let [remaining (swap! n dec)]
                                 (let [result (rf result input)]
                                   (if (pos? remaining)
                                     result
                                     (reduced result))))))))]
              (transduce take2 conj [] [1 2 3 4 5]))
            """)
        #expect(result == .vector([1, 2].map { .integer($0) }, metadata: nil))
    }

    // MARK: - into 2-arity (unchanged)

    @Test("into 2-arity with vector")
    func intoTwoArityVector() throws {
        #expect(try swish.eval("(into [] [1 2 3])")
            == .vector([1, 2, 3].map { .integer($0) }, metadata: nil))
    }

    @Test("into 2-arity with map")
    func intoTwoArityMap() throws {
        #expect(try swish.eval("(into {} [[:a 1] [:b 2]])")
            == .map([.keyword("a"): .integer(1), .keyword("b"): .integer(2)], metadata: nil))
    }

    // MARK: - into 3-arity with manually constructed transducer

    @Test("into 3-arity with custom transducer")
    func intoThreeArity() throws {
        let result = try swish.eval("""
            (let [inc-xf (fn [rf]
                           (fn
                             ([] (rf))
                             ([result] (rf result))
                             ([result input] (rf result (inc input)))))]
              (into [] inc-xf [1 2 3]))
            """)
        #expect(result == .vector([2, 3, 4].map { .integer($0) }, metadata: nil))
    }
}
