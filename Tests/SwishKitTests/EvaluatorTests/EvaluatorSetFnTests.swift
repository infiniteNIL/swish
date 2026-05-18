import Testing
@testable import SwishKit

@Suite("Evaluator Set-as-Function Tests")
struct EvaluatorSetFnTests {
    let swish = Swish()

    @Test("Member element returns itself")
    func memberReturnsItself() throws {
        let result = try swish.eval("(#{1 2 3} 2)")
        #expect(result == .integer(2))
    }

    @Test("Non-member returns nil")
    func nonMemberReturnsNil() throws {
        let result = try swish.eval("(#{1 2 3} 4)")
        #expect(result == .nil)
    }

    @Test("Keyword member returns itself")
    func keywordMemberReturnsItself() throws {
        let result = try swish.eval("(#{:a :b} :a)")
        #expect(result == .keyword("a"))
    }

    @Test("Keyword non-member returns nil")
    func keywordNonMemberReturnsNil() throws {
        let result = try swish.eval("(#{:a :b} :c)")
        #expect(result == .nil)
    }

    @Test("Empty set always returns nil")
    func emptySetReturnsNil() throws {
        let result = try swish.eval("(#{} 1)")
        #expect(result == .nil)
    }

    @Test("Too many arguments throws")
    func tooManyArgsThrows() throws {
        #expect(throws: EvaluatorError.self) {
            try swish.eval("(#{1 2} 1 2)")
        }
    }

    @Test("Zero arguments throws")
    func zeroArgsThrows() throws {
        #expect(throws: EvaluatorError.self) {
            try swish.eval("(#{1 2})")
        }
    }

    @Test("Set lookup with expression argument")
    func lookupWithExpressionArg() throws {
        let result = try swish.eval("(#{1 2 3} (+ 1 1))")
        #expect(result == .integer(2))
    }
}
