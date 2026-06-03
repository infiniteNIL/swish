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
    case leftBrace
    case rightBrace
    case quote
    case backtick
    case unquote
    case unquoteSplicing
    case varRef
    case deref
    case discard
    case leftSet     // #{
    case anonymousFn // #(
    case regex       // #"..."
    case metadata
    case eof
}

/// Represents a lexical token with position information
public struct Token: Equatable, Sendable {
    public let type: TokenType
    public let text: String
    public let line: Int
    public let column: Int
}
