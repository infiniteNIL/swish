import Testing
@testable import SwishKit

@Suite("Evaluator Loop/Recur Tests")
struct EvaluatorLoopTests {
    let evaluator = Evaluator()

    // MARK: - Basic loop

    @Test("loop with zero bindings returns body result")
    func loopZeroBindings() throws {
        #expect(try evaluator.eval("(loop [] 42)") == .integer(42))
    }

    @Test("loop with bindings makes them available in body")
    func loopBindingsAvailable() throws {
        #expect(try evaluator.eval("(loop [x 10] x)") == .integer(10))
    }

    @Test("loop bindings are sequential like let")
    func loopSequentialBindings() throws {
        #expect(try evaluator.eval("(loop [x 2 y (* x 3)] y)") == .integer(6))
    }

    @Test("loop body is an implicit do")
    func loopImplicitDo() throws {
        #expect(try evaluator.eval("(loop [x 1] x x (+ x 9))") == .integer(10))
    }

    // MARK: - recur in loop

    @Test("recur rebinds loop vars and repeats")
    func loopRecurCount() throws {
        let result = try evaluator.eval("""
            (loop [i 0 sum 0]
              (if (> i 5)
                sum
                (recur (+ i 1) (+ sum i))))
            """)
        #expect(result == .integer(15))
    }

    @Test("recur with zero bindings loop terminates")
    func loopRecurZeroBindings() throws {
        #expect(try evaluator.eval("(loop [] 99)") == .integer(99))
    }

    @Test("loop computes factorial via recur")
    func loopFactorial() throws {
        let result = try evaluator.eval("""
            (loop [n 5 acc 1]
              (if (= n 0) acc (recur (- n 1) (* n acc))))
            """)
        #expect(result == .integer(120))
    }

    @Test("recur rebinding is parallel not sequential")
    func loopRecurParallelRebind() throws {
        // swap x and y — if sequential, both would become the old x value
        let result = try evaluator.eval("""
            (loop [x 1 y 2 steps 0]
              (if (= steps 1)
                [x y]
                (recur y x (+ steps 1))))
            """)
        #expect(result == .vector([.integer(2), .integer(1)], metadata: nil))
    }

    // MARK: - recur in fn (TCO)

    @Test("recur in fn performs self tail-call")
    func fnRecurCountDown() throws {
        _ = try evaluator.eval("(defn count-down [n] (if (= n 0) :done (recur (- n 1))))")
        #expect(try evaluator.eval("(count-down 5)") == .keyword("done"))
    }

    @Test("recur in fn accumulates result")
    func fnRecurFactorial() throws {
        _ = try evaluator.eval("(defn fact [n acc] (if (= n 0) acc (recur (- n 1) (* n acc))))")
        #expect(try evaluator.eval("(fact 5 1)") == .integer(120))
    }

    @Test("recur in fn with multiple params")
    func fnRecurMultiParam() throws {
        _ = try evaluator.eval("(defn sum-to [n acc] (if (= n 0) acc (recur (- n 1) (+ acc n))))")
        #expect(try evaluator.eval("(sum-to 10 0)") == .integer(55))
    }

    @Test("recur does not blow the stack for large iterations")
    func fnRecurLargeIteration() throws {
        _ = try evaluator.eval("(defn loop-n [n] (if (= n 0) :done (recur (- n 1))))")
        #expect(try evaluator.eval("(loop-n 10000)") == .keyword("done"))
    }

    // MARK: - Nested loops

    @Test("recur targets nearest enclosing loop")
    func nestedLoopRecur() throws {
        let result = try evaluator.eval("""
            (loop [i 0]
              (let [inner (loop [j 0]
                            (if (= j 3) j (recur (+ j 1))))]
                (if (= i 2) [i inner] (recur (+ i 1)))))
            """)
        #expect(result == .vector([.integer(2), .integer(3)], metadata: nil))
    }

    // MARK: - recur in conditional branches

    @Test("recur works inside if branches")
    func recurInIfBranch() throws {
        let result = try evaluator.eval("""
            (loop [n 5 acc 1]
              (if (= n 0) acc (recur (- n 1) (* acc n))))
            """)
        #expect(result == .integer(120))
    }

    @Test("recur works inside let body")
    func recurInLetBody() throws {
        let result = try evaluator.eval("""
            (loop [x 0]
              (let [next (+ x 1)]
                (if (= next 5) next (recur next))))
            """)
        #expect(result == .integer(5))
    }

    // MARK: - Error cases

    @Test("recur outside loop throws recurOutsideLoop")
    func recurOutsideLoopThrows() throws {
        #expect(throws: EvaluatorError.recurOutsideLoop) {
            try evaluator.eval("(recur 1)")
        }
    }

    @Test("recur with wrong arg count in loop throws arityMismatch")
    func recurArityMismatchInLoop() throws {
        #expect(throws: EvaluatorError.arityMismatch(name: "loop", expected: .fixed(1), got: 2)) {
            try evaluator.eval("(loop [x 0] (recur 1 2))")
        }
    }

    // MARK: - Tail position validation

    @Test("recur as argument to a function throws recurNotInTailPosition")
    func recurNotTailInFunctionArg() throws {
        #expect(throws: EvaluatorError.recurNotInTailPosition) {
            try evaluator.eval("(defn fact [n] (* n (recur (- n 1))))")
        }
    }

    @Test("recur in non-last body position throws recurNotInTailPosition")
    func recurNotTailNonLastBody() throws {
        #expect(throws: EvaluatorError.recurNotInTailPosition) {
            try evaluator.eval("(fn [n] (recur n) 42)")
        }
    }

    @Test("recur in if test position throws recurNotInTailPosition")
    func recurNotTailInIfTest() throws {
        #expect(throws: EvaluatorError.recurNotInTailPosition) {
            try evaluator.eval("(fn [n] (if (recur n) 1 2))")
        }
    }

    @Test("recur in let binding value throws recurNotInTailPosition")
    func recurNotTailInLetBinding() throws {
        #expect(throws: EvaluatorError.recurNotInTailPosition) {
            try evaluator.eval("(fn [n] (let [x (recur n)] x))")
        }
    }

    @Test("recur in if then-branch is valid")
    func recurInIfThenIsValid() throws {
        _ = try evaluator.eval("(fn [n] (if (= n 0) :done (recur (- n 1))))")
    }

    @Test("recur in if else-branch is valid")
    func recurInIfElseIsValid() throws {
        _ = try evaluator.eval("(fn [n] (if (= n 0) nil (recur (dec n))))")
    }

    @Test("recur in let body is valid")
    func recurInLetBodyIsValid() throws {
        _ = try evaluator.eval("(fn [n] (let [m (- n 1)] (recur m)))")
    }

    @Test("recur in do last position is valid")
    func recurInDoLastIsValid() throws {
        _ = try evaluator.eval("(fn [n] (do (+ 1 2) (recur n)))")
    }

    @Test("recur inside nested fn is valid (targets that fn, not outer)")
    func recurInNestedFnIsValid() throws {
        _ = try evaluator.eval("(fn [n] (fn [x] (recur x)))")
    }

    @Test("recur inside when (a macro) is allowed at definition time")
    func recurInsideWhenAllowed() throws {
        _ = try evaluator.eval("(defn f [n] (when (> n 0) (recur (- n 1))))")
    }
}
