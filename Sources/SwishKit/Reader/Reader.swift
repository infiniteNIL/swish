/// The Reader converts source text into parsed expressions.
///
/// This encapsulates the lexing and parsing pipeline,
/// matching the standard Lisp concept of a "reader".
public class Reader {
    /// Reads a source string and returns parsed expressions.
    /// - Parameter source: A string containing Lisp expressions
    /// - Returns: An array of parsed `Expr` values
    /// - Throws: `LexerError` or `ParserError` if the input is invalid
    public static func readString(_ source: String) throws -> [Expr] {
        let lexer = Lexer(source)
        let parser = try Parser(lexer)
        return try parser.parse()
    }
}
