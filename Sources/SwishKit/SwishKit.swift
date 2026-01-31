import Foundation

/// Swish - A Clojure-like Lisp for Swift
///
/// SwishKit provides the core Lisp interpreter functionality
/// for embedding in Swift applications.

/// The main entry point for the Swish Lisp interpreter.
public struct Swish {
    private let locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    /// Evaluates a Lisp expression string and returns the result.
    /// - Parameter source: A string containing a Lisp expression
    /// - Returns: The string representation of the evaluated result
    /// - Throws: `LexerError` or `ParserError` if the input is invalid
    public func eval(_ source: String) throws -> String {
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
        let printer = Printer(locale: locale)
        return printer.printString(result)
    }
}
