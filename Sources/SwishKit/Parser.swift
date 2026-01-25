/// AST node types for Swish expressions
public enum Expr: Equatable {
    case integer(Int)
}

/// Errors thrown during parsing
public enum ParserError: Error, Equatable, CustomStringConvertible {
    case unexpectedToken(Token)
    case unexpectedEOF

    public var description: String {
        switch self {
        case .unexpectedToken(let token):
            return "Unexpected token '\(token.text)' (line \(token.line), column \(token.column))."
        case .unexpectedEOF:
            return "Unexpected end of input."
        }
    }
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
