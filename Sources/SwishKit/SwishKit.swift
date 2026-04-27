/// Swish - A Clojure-like Lisp for Swift
///
/// SwishKit provides the core Lisp interpreter functionality
/// for embedding in Swift applications.

/// The main entry point for the Swish Lisp interpreter.
public struct Swish {
    let evaluator = Evaluator()

    public init() {}

    /// Reads and evaluates a Swish source file.
    /// - Parameter filename: Path to the file to run
    /// - Throws: File read errors, `LexerError`, `ParserError`, or `EvaluatorError`
    public func run(filename: String) throws {
        let source = try String(contentsOfFile: filename, encoding: .utf8)
        _ = try eval(source)
    }

    /// Evaluates a Lisp expression string and returns the result.
    /// - Parameter source: A string containing a Lisp expression
    /// - Returns: The evaluated `Expr` value
    /// - Throws: `LexerError`, `ParserError`, or `EvaluatorError` if the input is invalid
    public var currentNamespaceName: String {
        evaluator.currentNs().name
    }

    public func eval(_ source: String) throws -> Expr {
        let exprs = try Reader.readString(source)
        guard let lastExpr = exprs.last else {
            throw ParserError.unexpectedEOF
        }
        var result = lastExpr
        for expr in exprs {
            result = try evaluator.eval(expr)
        }
        return result
    }
}
