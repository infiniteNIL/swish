/// AST node types for Swish expressions
public enum Expr: Equatable {
    case integer(Int)
}

/// Errors thrown during parsing
public enum ParserError: Error, Equatable {
    case unexpectedToken(Token)
    case unexpectedEOF
}

/// Parser for Swish source code
public class Parser {
    private let lexer: Lexer
    private var currentToken: Token

    public init(_ lexer: Lexer) throws {
        self.lexer = lexer
        self.currentToken = try lexer.nextToken()
    }

    public func parse() throws -> Expr {
        switch currentToken.type {
        case .integer:
            guard let value = Int(currentToken.text) else {
                throw ParserError.unexpectedToken(currentToken)
            }
            return .integer(value)
        case .eof:
            throw ParserError.unexpectedEOF
        }
    }
}
