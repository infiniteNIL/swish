/// Token types for the Swish lexer
public enum TokenType: Equatable, Sendable {
    case integer
    case float
    case ratio
    case string
    case character
    case boolean
    case `nil`
    case symbol
    case keyword
    case leftParen
    case rightParen
    case leftBracket
    case rightBracket
    case quote
    case backtick
    case unquote
    case unquoteSplicing
    case varRef
    case eof
}

/// Represents a lexical token with position information
public struct Token: Equatable, Sendable {
    public let type: TokenType
    public let text: String
    public let line: Int
    public let column: Int
}
