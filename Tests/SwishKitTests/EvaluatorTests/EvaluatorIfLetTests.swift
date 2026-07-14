import Testing
@testable import SwishKit

@Suite("Evaluator if-let Tests", .serialized)
struct EvaluatorIfLetTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - truthy binding

    @Test("truthy binding evaluates then branch with binding")
    func ifLetTruthy() throws {
        #expect(try swish.eval("(if-let [x 42] x :no)") == .integer(42))
    }

    @Test("zero is truthy — then branch runs")
    func ifLetZeroIsTruthy() throws {
        #expect(try swish.eval("(if-let [x 0] x :no)") == .integer(0))
    }

    @Test("empty string is truthy — then branch runs")
    func ifLetEmptyStringIsTruthy() throws {
        #expect(try swish.eval("(if-let [x \"\"] x :no)") == .string(""))
    }

    // MARK: - falsy binding

    @Test("nil binding evaluates else branch")
    func ifLetNilBinding() throws {
        #expect(try swish.eval("(if-let [x nil] x :no)") == .keyword("no"))
    }

    @Test("false binding evaluates else branch")
    func ifLetFalseBinding() throws {
        #expect(try swish.eval("(if-let [x false] x :no)") == .keyword("no"))
    }

    // MARK: - two-arg form (no else)

    @Test("no else form returns nil when binding is falsy")
    func ifLetNoElseReturnNil() throws {
        #expect(try swish.eval("(if-let [x nil] x)") == .nil)
    }

    @Test("no else form runs then when binding is truthy")
    func ifLetNoElseTruthy() throws {
        #expect(try swish.eval("(if-let [x 5] (* x 2))") == .integer(10))
    }

    // MARK: - expressions

    @Test("expression binding evaluated and used")
    func ifLetExpressionBinding() throws {
        #expect(try swish.eval("(if-let [x (+ 1 2)] (* x 2) 0)") == .integer(6))
    }

    @Test("else branch is an expression")
    func ifLetElseExpression() throws {
        #expect(try swish.eval("(if-let [x nil] x (+ 1 2))") == .integer(3))
    }

    // MARK: - destructuring

    @Test("vector destructuring in binding")
    func ifLetVectorDestructuring() throws {
        #expect(try swish.eval("(if-let [[a b] [1 2]] (+ a b) 0)") == .integer(3))
    }

    // MARK: - assert-args validation

    @Test("non-vector binding throws")
    func ifLetNonVectorThrows() throws {
        #expect(throws: SwishException.self) {
            try swish.eval("(if-let 42 x :no)")
        }
    }

    @Test("binding vector with one form throws")
    func ifLetOneFormBindingThrows() throws {
        #expect(throws: SwishException.self) {
            try swish.eval("(if-let [x] x :no)")
        }
    }

    @Test("binding vector with four forms throws")
    func ifLetFourFormsBindingThrows() throws {
        #expect(throws: SwishException.self) {
            try swish.eval("(if-let [x 1 y 2] x :no)")
        }
    }
}
