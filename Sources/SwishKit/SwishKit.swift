/// Swish - A Clojure-like Lisp for Swift
///
/// SwishKit provides the core Lisp interpreter functionality
/// for embedding in Swift applications.

/// The main entry point for the Swish Lisp interpreter.
public struct Swish {
    public init() {}

    /// Evaluates a Lisp expression string and returns the result.
    /// - Parameter source: A string containing a Lisp expression
    /// - Returns: The string representation of the evaluated result
    public func eval(_ source: String) -> String {
        do {
            let lexer = Lexer(source)
            let parser = try Parser(lexer)
            let ast = try parser.parse()
            let result = SwishKit.eval(ast)
            return printString(result)
        }
        catch let error as LexerError {
            return error.description
        }
        catch let error as ParserError {
            return error.description
        }
        catch {
            return "Error: \(error)"
        }
    }
}
