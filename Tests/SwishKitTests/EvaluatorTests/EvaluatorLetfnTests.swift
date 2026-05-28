import Testing
@testable import SwishKit

@Suite("Evaluator letfn Tests")
struct EvaluatorLetfnTests {
    let evaluator = Evaluator()

    @Test("letfn binds a single function usable in body")
    func letfnBasic() throws {
        #expect(try evaluator.eval("(letfn [(double [x] (* x 2))] (double 5))") == .integer(10))
    }

    @Test("letfn function can call itself recursively")
    func letfnSelfRecursion() throws {
        #expect(try evaluator.eval("""
            (letfn [(fact [n]
                      (if (= n 0)
                        1
                        (* n (fact (dec n)))))]
              (fact 5))
            """) == .integer(120))
    }

    @Test("letfn supports mutual recursion")
    func letfnMutualRecursion() throws {
        #expect(try evaluator.eval("""
            (letfn [(my-even? [n]
                      (if (= n 0) true (my-odd? (dec n))))
                    (my-odd? [n]
                      (if (= n 0) false (my-even? (dec n))))]
              (my-even? 10))
            """) == .boolean(true))
    }

    @Test("letfn mutual recursion odd case")
    func letfnMutualRecursionOdd() throws {
        #expect(try evaluator.eval("""
            (letfn [(my-even? [n]
                      (if (= n 0) true (my-odd? (dec n))))
                    (my-odd? [n]
                      (if (= n 0) false (my-even? (dec n))))]
              (my-odd? 7))
            """) == .boolean(true))
    }

    @Test("letfn body sees all bound names")
    func letfnBodySeesAllNames() throws {
        #expect(try evaluator.eval("""
            (letfn [(a [] 1)
                    (b [] 2)]
              (+ (a) (b)))
            """) == .integer(3))
    }

    @Test("letfn body has access to outer scope")
    func letfnOuterScope() throws {
        #expect(try evaluator.eval("""
            (let [x 10]
              (letfn [(add-x [n] (+ n x))]
                (add-x 5)))
            """) == .integer(15))
    }
}
