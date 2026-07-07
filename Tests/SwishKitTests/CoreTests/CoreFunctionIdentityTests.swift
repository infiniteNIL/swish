import Testing
@testable import SwishKit

@Suite("Core Function Identity Tests", .serialized)
struct CoreFunctionIdentityTests {
    let swish = Evaluator()

    @Test("two separately-created lambdas are not equal")
    func separateLambdasNotEqual() throws {
        #expect(try swish.eval("(= #(+ 2 %) #(+ 2 %))") == .boolean(false))
    }

    @Test("the same lambda binding is equal to itself")
    func sameLambdaEqualToItself() throws {
        #expect(try swish.eval("(let [f #(+ 2 %) f' f] (= f f'))") == .boolean(true))
    }

    @Test("two separately-created multi-arity fns are not equal")
    func separateMultiArityNotEqual() throws {
        #expect(try swish.eval("(= (fn ([] 0) ([x] x)) (fn ([] 0) ([x] x)))") == .boolean(false))
    }

    @Test("the same multi-arity fn binding is equal to itself")
    func sameMultiArityEqualToItself() throws {
        #expect(try swish.eval("(let [f (fn ([] 0) ([x] x)) f' f] (= f f'))") == .boolean(true))
    }

    @Test("with-meta preserves function identity")
    func withMetaPreservesIdentity() throws {
        #expect(try swish.eval("(let [f #(+ 2 %) g (with-meta f {:doc \"hi\"})] (= f g))") == .boolean(true))
    }
}
