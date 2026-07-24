/// Swish - A Clojure-like Lisp for Swift
///
/// SwishKit provides the core Lisp interpreter functionality
/// for embedding in Swift applications.

import Foundation

/// The main entry point for the Swish Lisp interpreter.
public struct Swish: @unchecked Sendable {
    let evaluator: Evaluator

    public init(sourcePaths: [String] = []) {
        let envPaths = ProcessInfo.processInfo.environment["SWISH_SOURCEPATH"]
            .map { $0.split(separator: ":").map(String.init) } ?? []
        evaluator = Evaluator(sourcePaths: sourcePaths + envPaths)
    }

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
        evaluator.currentNamespaceName
    }

    public var interruptionCheck: (() -> Bool)? {
        get { evaluator.interruptionCheck }
        set { evaluator.interruptionCheck = newValue }
    }

    public func eval(_ source: String) throws -> Expr {
        let exprs = try Reader.readString(source)
        guard !exprs.isEmpty else { throw ParserError.unexpectedEOF }
        var result: Expr = .nil
        for expr in exprs {
            result = try evaluator.eval(expr)
        }
        return result
    }

    /// Returns a human-readable description of a caught evaluation error, for
    /// display at a top level (REPL, CLI). Routes the underlying thrown value
    /// through the printer instead of Swift's raw struct interpolation.
    public func describeError(_ error: Error) -> String {
        Printer().strString(evaluator.exprForError(error))
    }
}
