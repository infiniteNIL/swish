import Testing
@testable import SwishKit

@Suite("Evaluator Map Tests")
struct EvaluatorMapTests {
    let evaluator = Evaluator()
    let swish = Swish()

    @Test("Empty map evaluates to itself")
    func emptyMapSelfEvaluates() throws {
        let result = try evaluator.eval(.map([:], metadata: nil))
        #expect(result == .map([:], metadata: nil))
    }

    @Test("Map with literal values evaluates to itself")
    func mapWithLiteralsSelfEvaluates() throws {
        let result = try evaluator.eval(.map([.keyword("a"): .integer(1)], metadata: nil))
        #expect(result == .map([.keyword("a"): .integer(1)], metadata: nil))
    }

    @Test("Map evaluates key expressions")
    func mapEvaluatesKeys() throws {
        let expr = Expr.map([.list([.symbol("clojure.core/+", metadata: nil), .integer(1), .integer(2)], metadata: nil): .string("three")], metadata: nil)
        let result = try evaluator.eval(expr)
        #expect(result == .map([.integer(3): .string("three")], metadata: nil))
    }

    @Test("Map evaluates value expressions")
    func mapEvaluatesValues() throws {
        let expr = Expr.map([.keyword("sum"): .list([.symbol("clojure.core/+", metadata: nil), .integer(1), .integer(2)], metadata: nil)], metadata: nil)
        let result = try evaluator.eval(expr)
        #expect(result == .map([.keyword("sum"): .integer(3)], metadata: nil))
    }

    @Test("Map with nested map evaluates")
    func mapWithNestedMapEvaluates() throws {
        let inner = Expr.map([.keyword("b"): .integer(2)], metadata: nil)
        let outer = Expr.map([.keyword("a"): inner], metadata: nil)
        let result = try evaluator.eval(outer)
        #expect(result == .map([.keyword("a"): .map([.keyword("b"): .integer(2)], metadata: nil)], metadata: nil))
    }

    @Test("Map round-trips through reader")
    func mapRoundTripsFromSource() throws {
        let result = try swish.eval("{:x 10 :y 20}")
        #expect(result == .map([.keyword("x"): .integer(10), .keyword("y"): .integer(20)], metadata: nil))
    }
}
