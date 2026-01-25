/// Token types for the Swish lexer
public enum TokenType: Equatable, Sendable {
    case integer
    case eof
}

/// Represents a lexical token with position information
public struct Token: Equatable, Sendable {
    public let type: TokenType
    public let text: String
    public let line: Int
    public let column: Int
}

/// Errors thrown during lexical analysis
public enum LexerError: Error, Equatable, CustomStringConvertible {
    case illegalCharacter(Character, line: Int, column: Int)

    public var description: String {
        switch self {
        case .illegalCharacter(let char, let line, let column):
            return "Illegal character '\(char)' (line \(line), column \(column))."
        }
    }
}

/// Lexical analyzer for Swish source code
public class Lexer {
    private let source: String
    private var index: String.Index
    private var line: Int = 1
    private var column: Int = 1

    public init(_ source: String) {
        self.source = source
        self.index = source.startIndex
    }

    public func nextToken() throws -> Token {
        skipWhitespace()

        let startLine = line
        let startColumn = column

        guard let char = peek() else {
            return Token(type: .eof, text: "", line: startLine, column: startColumn)
        }

        if char.isNumber {
            return scanInteger(startLine: startLine, startColumn: startColumn)
        }

        if char == "+" || char == "-" {
            let signChar = advance()

            if let next = peek(), next.isNumber {
                return scanInteger(startLine: startLine, startColumn: startColumn, prefix: String(signChar))
            }
            else {
                throw LexerError.illegalCharacter(signChar, line: startLine, column: startColumn)
            }
        }

        throw LexerError.illegalCharacter(char, line: startLine, column: startColumn)
    }

    private func skipWhitespace() {
        while let char = peek(), char.isWhitespace {
            _ = advance()
        }
    }

    private func scanInteger(startLine: Int, startColumn: Int, prefix: String = "") -> Token {
        var text = prefix
        while let char = peek(), char.isNumber {
            text.append(advance())
        }
        return Token(type: .integer, text: text, line: startLine, column: startColumn)
    }

    private func peek() -> Character? {
        guard index < source.endIndex else { return nil }
        return source[index]
    }

    private func advance() -> Character {
        let char = source[index]
        index = source.index(after: index)
        if char == "\n" {
            line += 1
            column = 1
        }
        else {
            column += 1
        }
        return char
    }
}
