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
    case invalidNumberFormat(String, line: Int, column: Int)

    public var description: String {
        switch self {
        case .illegalCharacter(let char, let line, let column):
            return "Illegal character '\(char)' (line \(line), column \(column))."
        case .invalidNumberFormat(let text, let line, let column):
            return "Invalid number format '\(text)' (line \(line), column \(column))."
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

        // Unsigned hex: 0x...
        if char == "0", let next = peekAt(1), next == "x" {
            return try scanHexInteger(startLine: startLine, startColumn: startColumn, prefix: "")
        }

        if char.isNumber {
            return try scanInteger(startLine: startLine, startColumn: startColumn)
        }

        if char == "+" || char == "-" {
            let signChar = advance()

            // Check for hex: sign followed by 0x
            if let next = peek(), next == "0",
               let afterZero = peekAt(1), afterZero == "x" {
                return try scanHexInteger(startLine: startLine, startColumn: startColumn, prefix: String(signChar))
            }

            if let next = peek(), next.isNumber {
                return try scanInteger(startLine: startLine, startColumn: startColumn, prefix: String(signChar))
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

    private func scanInteger(startLine: Int, startColumn: Int, prefix: String = "") throws -> Token {
        var text = prefix
        var lastWasUnderscore = false

        while let char = peek() {
            if char.isNumber {
                text.append(advance())
                lastWasUnderscore = false
            }
            else if char == "_" {
                if lastWasUnderscore {
                    throw LexerError.invalidNumberFormat(text + "_", line: startLine, column: startColumn)
                }
                _ = advance()
                text.append("_")
                lastWasUnderscore = true
            }
            else {
                break
            }
        }

        if lastWasUnderscore {
            throw LexerError.invalidNumberFormat(text, line: startLine, column: startColumn)
        }

        let cleanText = text.filter { $0 != "_" }
        return Token(type: .integer, text: cleanText, line: startLine, column: startColumn)
    }

    private func scanHexInteger(startLine: Int, startColumn: Int, prefix: String) throws -> Token {
        var text = prefix
        text.append(advance()) // '0'
        text.append(advance()) // 'x'

        var hasDigits = false
        var lastWasUnderscore = false

        while let char = peek() {
            if isHexDigit(char) {
                text.append(advance())
                hasDigits = true
                lastWasUnderscore = false
            }
            else if char == "_" {
                if !hasDigits || lastWasUnderscore {
                    throw LexerError.invalidNumberFormat(text + "_", line: startLine, column: startColumn)
                }
                _ = advance()
                text.append("_")
                lastWasUnderscore = true
            }
            else {
                break
            }
        }

        if !hasDigits {
            throw LexerError.invalidNumberFormat(text, line: startLine, column: startColumn)
        }
        if lastWasUnderscore {
            throw LexerError.invalidNumberFormat(text, line: startLine, column: startColumn)
        }

        let cleanText = text.filter { $0 != "_" }
        return Token(type: .integer, text: cleanText, line: startLine, column: startColumn)
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

    private func peekAt(_ offset: Int) -> Character? {
        var i = index
        for _ in 0..<offset {
            guard i < source.endIndex else { return nil }
            i = source.index(after: i)
        }
        guard i < source.endIndex else { return nil }
        return source[i]
    }

    private func isHexDigit(_ char: Character) -> Bool {
        char.isHexDigit
    }
}
