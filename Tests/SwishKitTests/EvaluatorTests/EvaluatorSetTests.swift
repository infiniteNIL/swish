import Testing
@testable import SwishKit

@Suite("Evaluator Set Tests")
struct EvaluatorSetTests {
    let evaluator = Evaluator()
    let swish = Swish()

    @Test("Empty set evaluates to itself")
    func emptySetSelfEvaluates() throws {
        let result = try evaluator.eval(.set([], metadata: nil))
        #expect(result == .set([], metadata: nil))
    }

    @Test("Set with literal values evaluates to itself")
    func setWithLiteralsSelfEvaluates() throws {
        let result = try evaluator.eval(.set([.integer(1), .keyword("a")], metadata: nil))
        #expect(result == .set([.integer(1), .keyword("a")], metadata: nil))
    }

    @Test("Set evaluates expressions in elements")
    func setEvaluatesExpressions() throws {
        let expr = Expr.set(
            [.list([.symbol("clojure.core/+", metadata: nil), .integer(1), .integer(2)], metadata: nil),
             .integer(4)],
            metadata: nil)
        let result = try evaluator.eval(expr)
        #expect(result == .set([.integer(3), .integer(4)], metadata: nil))
    }

    @Test("Throws on computed duplicate elements")
    func throwsOnComputedDuplicates() throws {
        let expr = Expr.set(
            [.list([.symbol("clojure.core/+", metadata: nil), .integer(1), .integer(1)], metadata: nil),
             .integer(2)],
            metadata: nil)
        #expect(throws: EvaluatorError.self) {
            try evaluator.eval(expr)
        }
    }

    @Test("Set round-trips through reader")
    func setRoundTripsFromSource() throws {
        let result = try swish.eval("#{1 2 3}")
        #expect(result == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("Reader-time duplicate throws")
    func readerTimeDuplicateThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("#{1 1}")
        }
    }

    @Test("Set equality ignores element order")
    func setEqualityIgnoresOrder() throws {
        let a = try swish.eval("#{1 2 3}")
        let b = try swish.eval("#{3 1 2}")
        #expect(a == b)
    }

    @Test("Printer outputs set notation")
    func printerOutputsSetNotation() throws {
        let printer = Printer()
        let result = printer.printString(.set([.integer(1), .integer(2)], metadata: nil))
        #expect(result == "#{1 2}")
    }

    @Test("Printer outputs empty set")
    func printerOutputsEmptySet() throws {
        let printer = Printer()
        let result = printer.printString(.set([], metadata: nil))
        #expect(result == "#{}")
    }
}
