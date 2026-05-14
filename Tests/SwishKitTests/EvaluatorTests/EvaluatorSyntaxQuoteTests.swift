import Testing
@testable import SwishKit

@Suite("Evaluator Syntax Quote Tests")
struct EvaluatorSyntaxQuoteTests {
    let evaluator = Evaluator()

    @Test("syntax-quote returns atom as-is")
    func syntaxQuoteAtomReturnsItself() throws {
        let result = try evaluator.eval(.list([.symbol("syntax-quote", metadata: nil), .symbol("a", metadata: nil)], metadata: nil))
        #expect(result == .symbol("a", metadata: nil))
    }

    @Test("syntax-quote returns integer as-is")
    func syntaxQuoteIntegerReturnsItself() throws {
        let result = try evaluator.eval(.list([.symbol("syntax-quote", metadata: nil), .integer(42)], metadata: nil))
        #expect(result == .integer(42))
    }

    @Test("syntax-quote returns plain list unevaluated")
    func syntaxQuotePlainListUnevaluated() throws {
        let result = try evaluator.eval(.list([
            .symbol("syntax-quote", metadata: nil),
            .list([.integer(1), .integer(2), .integer(3)], metadata: nil)
        ], metadata: nil))
        #expect(result == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("syntax-quote with top-level unquote evaluates the inner expr")
    func syntaxQuoteTopLevelUnquoteEvaluates() throws {
        // bind x = 5
        _ = try evaluator.eval(.list([.symbol("def", metadata: nil), .symbol("x", metadata: nil), .integer(5)], metadata: nil))
        // (syntax-quote (unquote x)) => 5
        let result = try evaluator.eval(.list([
            .symbol("syntax-quote", metadata: nil),
            .list([.symbol("unquote", metadata: nil), .symbol("x", metadata: nil)], metadata: nil)
        ], metadata: nil))
        #expect(result == .integer(5))
    }

    @Test("syntax-quote substitutes unquote in a list element")
    func syntaxQuoteUnquoteSubstitution() throws {
        _ = try evaluator.eval(.list([.symbol("def", metadata: nil), .symbol("x", metadata: nil), .integer(2)], metadata: nil))
        // (syntax-quote (1 (unquote x) 3)) => (1 2 3)
        let result = try evaluator.eval(.list([
            .symbol("syntax-quote", metadata: nil),
            .list([
                .integer(1),
                .list([.symbol("unquote", metadata: nil), .symbol("x", metadata: nil)], metadata: nil),
                .integer(3)
            ], metadata: nil)
        ], metadata: nil))
        #expect(result == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("syntax-quote unquote substitution is recursive")
    func syntaxQuoteUnquoteRecursive() throws {
        _ = try evaluator.eval(.list([.symbol("def", metadata: nil), .symbol("x", metadata: nil), .integer(5)], metadata: nil))
        // (syntax-quote (1 (2 (unquote x)) 3)) => (1 (2 5) 3)
        let result = try evaluator.eval(.list([
            .symbol("syntax-quote", metadata: nil),
            .list([
                .integer(1),
                .list([.integer(2), .list([.symbol("unquote", metadata: nil), .symbol("x", metadata: nil)], metadata: nil)], metadata: nil),
                .integer(3)
            ], metadata: nil)
        ], metadata: nil))
        #expect(result == .list([
            .integer(1),
            .list([.integer(2), .integer(5)], metadata: nil),
            .integer(3)
        ], metadata: nil))
    }

    @Test("syntax-quote splices unquote-splicing into the surrounding list")
    func syntaxQuoteUnquoteSplicing() throws {
        _ = try evaluator.eval(.list([
            .symbol("def", metadata: nil), .symbol("xs", metadata: nil),
            .list([.symbol("quote", metadata: nil), .list([.integer(4), .integer(5)], metadata: nil)], metadata: nil)
        ], metadata: nil))
        // (syntax-quote (1 (unquote-splicing xs) 3)) => (1 4 5 3)
        let result = try evaluator.eval(.list([
            .symbol("syntax-quote", metadata: nil),
            .list([
                .integer(1),
                .list([.symbol("unquote-splicing", metadata: nil), .symbol("xs", metadata: nil)], metadata: nil),
                .integer(3)
            ], metadata: nil)
        ], metadata: nil))
        #expect(result == .list([.integer(1), .integer(4), .integer(5), .integer(3)], metadata: nil))
    }

    @Test("syntax-quote handles mixed unquote and unquote-splicing")
    func syntaxQuoteMixedUnquoteAndSplicing() throws {
        _ = try evaluator.eval(.list([.symbol("def", metadata: nil), .symbol("x", metadata: nil), .integer(2)], metadata: nil))
        _ = try evaluator.eval(.list([
            .symbol("def", metadata: nil), .symbol("xs", metadata: nil),
            .list([.symbol("quote", metadata: nil), .list([.integer(4), .integer(5)], metadata: nil)], metadata: nil)
        ], metadata: nil))
        // (syntax-quote ((unquote x) (unquote-splicing xs) (unquote x))) => (2 4 5 2)
        let result = try evaluator.eval(.list([
            .symbol("syntax-quote", metadata: nil),
            .list([
                .list([.symbol("unquote", metadata: nil), .symbol("x", metadata: nil)], metadata: nil),
                .list([.symbol("unquote-splicing", metadata: nil), .symbol("xs", metadata: nil)], metadata: nil),
                .list([.symbol("unquote", metadata: nil), .symbol("x", metadata: nil)], metadata: nil)
            ], metadata: nil)
        ], metadata: nil))
        #expect(result == .list([.integer(2), .integer(4), .integer(5), .integer(2)], metadata: nil))
    }

    @Test("unquote of undefined symbol throws undefinedSymbol")
    func unquoteUndefinedSymbolThrows() throws {
        #expect(throws: EvaluatorError.undefinedSymbol("y")) {
            try evaluator.eval(.list([
                .symbol("syntax-quote", metadata: nil),
                .list([.symbol("unquote", metadata: nil), .symbol("y", metadata: nil)], metadata: nil)
            ], metadata: nil))
        }
    }

    @Test("unquote-splicing a non-list throws invalidArgument")
    func unquoteSplicingNonListThrows() throws {
        _ = try evaluator.eval(.list([.symbol("def", metadata: nil), .symbol("v", metadata: nil), .integer(99)], metadata: nil))
        #expect(throws: EvaluatorError.invalidArgument(
            function: "unquote-splicing", message: "value must be a list"
        )) {
            try evaluator.eval(.list([
                .symbol("syntax-quote", metadata: nil),
                .list([
                    .integer(1),
                    .list([.symbol("unquote-splicing", metadata: nil), .symbol("v", metadata: nil)], metadata: nil),
                    .integer(3)
                ], metadata: nil)
            ], metadata: nil))
        }
    }

    @Test("fn body with syntax-quote and unquote checks param symbols")
    func fnBodySyntaxQuoteUnquoteChecksParams() throws {
        // (fn [x] (syntax-quote (1 (unquote x) 3))) — x is a param, should succeed
        #expect(throws: Never.self) {
            try evaluator.eval(.list([
                .symbol("fn", metadata: nil),
                .vector([.symbol("x", metadata: nil)], metadata: nil),
                .list([
                    .symbol("syntax-quote", metadata: nil),
                    .list([
                        .integer(1),
                        .list([.symbol("unquote", metadata: nil), .symbol("x", metadata: nil)], metadata: nil),
                        .integer(3)
                    ], metadata: nil)
                ], metadata: nil)
            ], metadata: nil))
        }
    }

    @Test("fn body with syntax-quote and unquote succeeds at definition time")
    func fnBodySyntaxQuoteUnquoteDefinitionSucceeds() throws {
        // (fn [] (syntax-quote (1 (unquote y) 3))) — y is not defined, but that's ok at definition time
        #expect(throws: Never.self) {
            try evaluator.eval(.list([
                .symbol("fn", metadata: nil),
                .vector([], metadata: nil),
                .list([
                    .symbol("syntax-quote", metadata: nil),
                    .list([
                        .integer(1),
                        .list([.symbol("unquote", metadata: nil), .symbol("y", metadata: nil)], metadata: nil),
                        .integer(3)
                    ], metadata: nil)
                ], metadata: nil)
            ], metadata: nil))
        }
    }

    @Test("fn body with syntax-quote and unquote throws undefinedSymbol at call time")
    func fnBodySyntaxQuoteUnquoteCallTimeThrows() throws {
        let fn = try evaluator.eval(.list([
            .symbol("fn", metadata: nil),
            .vector([], metadata: nil),
            .list([
                .symbol("syntax-quote", metadata: nil),
                .list([
                    .integer(1),
                    .list([.symbol("unquote", metadata: nil), .symbol("y", metadata: nil)], metadata: nil),
                    .integer(3)
                ], metadata: nil)
            ], metadata: nil)
        ], metadata: nil))
        #expect(throws: EvaluatorError.undefinedSymbol("y")) {
            try evaluator.eval(.list([fn], metadata: nil))
        }
    }

    @Test("fn body with syntax-quote and unquote-splicing checks param symbols")
    func fnBodySyntaxQuoteUnquoteSplicingChecksParams() throws {
        // (fn [xs] (syntax-quote (1 (unquote-splicing xs) 3))) — xs is a param
        #expect(throws: Never.self) {
            try evaluator.eval(.list([
                .symbol("fn", metadata: nil),
                .vector([.symbol("xs", metadata: nil)], metadata: nil),
                .list([
                    .symbol("syntax-quote", metadata: nil),
                    .list([
                        .integer(1),
                        .list([.symbol("unquote-splicing", metadata: nil), .symbol("xs", metadata: nil)], metadata: nil),
                        .integer(3)
                    ], metadata: nil)
                ], metadata: nil)
            ], metadata: nil))
        }
    }

    @Test("fn body with syntax-quote and unquote-splicing succeeds at definition time")
    func fnBodySyntaxQuoteUnquoteSplicingDefinitionSucceeds() throws {
        // (fn [] (syntax-quote (1 (unquote-splicing zs) 3))) — zs is not defined, but that's ok at definition time
        #expect(throws: Never.self) {
            try evaluator.eval(.list([
                .symbol("fn", metadata: nil),
                .vector([], metadata: nil),
                .list([
                    .symbol("syntax-quote", metadata: nil),
                    .list([
                        .integer(1),
                        .list([.symbol("unquote-splicing", metadata: nil), .symbol("zs", metadata: nil)], metadata: nil),
                        .integer(3)
                    ], metadata: nil)
                ], metadata: nil)
            ], metadata: nil))
        }
    }

    @Test("fn body with syntax-quote and unquote-splicing throws undefinedSymbol at call time")
    func fnBodySyntaxQuoteUnquoteSplicingCallTimeThrows() throws {
        let fn = try evaluator.eval(.list([
            .symbol("fn", metadata: nil),
            .vector([], metadata: nil),
            .list([
                .symbol("syntax-quote", metadata: nil),
                .list([
                    .integer(1),
                    .list([.symbol("unquote-splicing", metadata: nil), .symbol("zs", metadata: nil)], metadata: nil),
                    .integer(3)
                ], metadata: nil)
            ], metadata: nil)
        ], metadata: nil))
        #expect(throws: EvaluatorError.undefinedSymbol("zs")) {
            try evaluator.eval(.list([fn], metadata: nil))
        }
    }

    @Test("fn body with plain syntax-quote does not check symbols inside it")
    func fnBodyPlainSyntaxQuoteDoesNotCheckSymbols() throws {
        // (fn [] (syntax-quote (1 undefined-sym 3))) — undefined-sym is not evaluated
        #expect(throws: Never.self) {
            try evaluator.eval(.list([
                .symbol("fn", metadata: nil),
                .vector([], metadata: nil),
                .list([
                    .symbol("syntax-quote", metadata: nil),
                    .list([.integer(1), .symbol("undefined-sym", metadata: nil), .integer(3)], metadata: nil)
                ], metadata: nil)
            ], metadata: nil))
        }
    }
}
