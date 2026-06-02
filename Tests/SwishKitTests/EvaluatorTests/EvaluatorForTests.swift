import Testing
@testable import SwishKit

@Suite("Evaluator for Tests")
struct EvaluatorForTests {
    let swish = Swish()

    @Test("for over single collection returns transformed sequence")
    func forSingleCollection() throws {
        let result = try swish.eval("(for [x [1 2 3]] (* x 2))")
        #expect(result == .list([.integer(2), .integer(4), .integer(6)], metadata: nil))
    }

    @Test("for returns a list not nil")
    func forReturnsList() throws {
        let result = try swish.eval("(seq? (for [x [1 2 3]] x))")
        #expect(result == .boolean(true))
    }

    @Test("for on empty collection returns empty list")
    func forEmptyCollection() throws {
        let result = try swish.eval("(for [x []] x)")
        #expect(result == .list([], metadata: nil))
    }

    @Test("for with multiple bindings nests rightmost fastest")
    func forMultipleBindings() throws {
        let result = try swish.eval("(for [x [1 2] y [:a :b]] [x y])")
        #expect(result == .list([
            .vector([.integer(1), .keyword("a")], metadata: nil),
            .vector([.integer(1), .keyword("b")], metadata: nil),
            .vector([.integer(2), .keyword("a")], metadata: nil),
            .vector([.integer(2), .keyword("b")], metadata: nil),
        ], metadata: nil))
    }

    @Test("for :when filters elements")
    func forWhen() throws {
        let result = try swish.eval("(for [x [1 2 3 4 5] :when (odd? x)] x)")
        #expect(result == .list([.integer(1), .integer(3), .integer(5)], metadata: nil))
    }

    @Test("for :while stops at first false")
    func forWhile() throws {
        let result = try swish.eval("(for [x [1 2 3 4 5] :while (< x 4)] x)")
        #expect(result == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("for :let binds in scope")
    func forLet() throws {
        let result = try swish.eval("(for [x [1 2 3] :let [doubled (* x 2)]] doubled)")
        #expect(result == .list([.integer(2), .integer(4), .integer(6)], metadata: nil))
    }

    @Test("for inner binding can reference outer binding")
    func forInnerReferencesOuter() throws {
        let result = try swish.eval("(for [x [[1 2] [3 4]] y x] y)")
        #expect(result == .list([.integer(1), .integer(2), .integer(3), .integer(4)], metadata: nil))
    }
}
