import Testing
@testable import SwishKit

@Suite("Evaluator when-let Tests", .serialized)
struct EvaluatorWhenLetTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - when-let basics

    @Test("truthy binding — body evaluates and returns last form")
    func whenLetTruthy() throws {
        #expect(try swish.eval("(when-let [x 42] x)") == .integer(42))
    }

    @Test("nil binding — body skipped, returns nil")
    func whenLetNilBinding() throws {
        #expect(try swish.eval("(when-let [x nil] x)") == .nil)
    }

    @Test("false binding — body skipped, returns nil")
    func whenLetFalseBinding() throws {
        #expect(try swish.eval("(when-let [x false] x)") == .nil)
    }

    @Test("expression binding — evaluated and bound")
    func whenLetExpressionBinding() throws {
        #expect(try swish.eval("(when-let [x (+ 1 2)] (* x 2))") == .integer(6))
    }

    @Test("multi-form body — returns last form")
    func whenLetMultiFormBody() throws {
        #expect(try swish.eval("(when-let [x 5] (+ x 1) (* x 2))") == .integer(10))
    }

    @Test("binding is visible inside body")
    func whenLetBindingVisibleInBody() throws {
        #expect(try swish.eval("(when-let [x 7] (+ x x))") == .integer(14))
    }

    @Test("zero is truthy — body runs")
    func whenLetZeroIsTruthy() throws {
        #expect(try swish.eval("(when-let [x 0] x)") == .integer(0))
    }

    @Test("empty string is truthy — body runs")
    func whenLetEmptyStringIsTruthy() throws {
        #expect(try swish.eval("(when-let [x \"\"] x)") == .string(""))
    }

    // MARK: - destructuring binding

    @Test("vector destructuring in binding")
    func whenLetVectorDestructuring() throws {
        #expect(try swish.eval("(when-let [[a b] [1 2]] (+ a b))") == .integer(3))
    }

    @Test("map destructuring in binding")
    func whenLetMapDestructuring() throws {
        #expect(try swish.eval("(when-let [{:keys [x]} {:x 5}] x)") == .integer(5))
    }

    // MARK: - assert-args validation

    @Test("non-vector binding throws")
    func whenLetNonVectorThrows() throws {
        #expect(throws: SwishException.self) {
            try swish.eval("(when-let 42 nil)")
        }
    }

    @Test("binding vector with one form throws")
    func whenLetOneFormBindingThrows() throws {
        #expect(throws: SwishException.self) {
            try swish.eval("(when-let [x] x)")
        }
    }

    @Test("binding vector with four forms throws")
    func whenLetFourFormsBindingThrows() throws {
        #expect(throws: SwishException.self) {
            try swish.eval("(when-let [x 1 y 2] x)")
        }
    }
}
