/// Swish - A Clojure-like Lisp for Swift
///
/// SwishKit provides the core Lisp interpreter functionality
/// for embedding in Swift applications.

/// The main entry point for the Swish Lisp interpreter.
public struct Swish {
    public init() {}

    /// Evaluates a Lisp expression string and returns the result.
    /// - Parameter source: A string containing a Lisp expression
    /// - Returns: The evaluated `Expr` value
    /// - Throws: `LexerError` or `ParserError` if the input is invalid
    public func eval(_ source: String) throws -> Expr {
        let lexer = Lexer(source)
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        guard let lastExpr = exprs.last else {
            throw ParserError.unexpectedEOF
        }
        let evaluator = Evaluator()
        var result = lastExpr
        for expr in exprs {
            result = evaluator.eval(expr)
        }
        return result
    }
}
