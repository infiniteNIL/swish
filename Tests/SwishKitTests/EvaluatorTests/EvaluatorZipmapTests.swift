import Testing
@testable import SwishKit

@Suite("Evaluator zipmap Tests")
struct EvaluatorZipmapTests {
    let evaluator = Evaluator()

    @Test("zipmap with matching keys and vals")
    func zipmapBasic() throws {
        let result = try evaluator.eval("(zipmap [:a :b :c] [1 2 3])")
        #expect(result == .map([.keyword("a"): .integer(1), .keyword("b"): .integer(2), .keyword("c"): .integer(3)], metadata: nil))
    }

    @Test("zipmap with more keys than vals stops at shortest")
    func zipmapMoreKeys() throws {
        let result = try evaluator.eval("(zipmap [:a :b :c] [1 2])")
        #expect(result == .map([.keyword("a"): .integer(1), .keyword("b"): .integer(2)], metadata: nil))
    }

    @Test("zipmap with more vals than keys stops at shortest")
    func zipmapMoreVals() throws {
        let result = try evaluator.eval("(zipmap [:a :b] [1 2 3])")
        #expect(result == .map([.keyword("a"): .integer(1), .keyword("b"): .integer(2)], metadata: nil))
    }

    @Test("zipmap with empty keys returns empty map")
    func zipmapEmptyKeys() throws {
        let result = try evaluator.eval("(zipmap [] [1 2 3])")
        #expect(result == .map([:], metadata: nil))
    }

    @Test("zipmap with empty vals returns empty map")
    func zipmapEmptyVals() throws {
        let result = try evaluator.eval("(zipmap [:a :b] [])")
        #expect(result == .map([:], metadata: nil))
    }

    @Test("zipmap with string keys")
    func zipmapStringKeys() throws {
        let result = try evaluator.eval("(zipmap [\"x\" \"y\"] [10 20])")
        #expect(result == .map([.string("x"): .integer(10), .string("y"): .integer(20)], metadata: nil))
    }

    @Test("zipmap with list colls")
    func zipmapListColls() throws {
        let result = try evaluator.eval("(zipmap '(:a :b) '(1 2))")
        #expect(result == .map([.keyword("a"): .integer(1), .keyword("b"): .integer(2)], metadata: nil))
    }
}

// MARK: - Helper

private extension Evaluator {
    func eval(_ source: String) throws -> Expr {
        let exprs = try Reader.readString(source)
        var result: Expr = .nil
        for expr in exprs { result = try eval(expr) }
        return result
    }
}
