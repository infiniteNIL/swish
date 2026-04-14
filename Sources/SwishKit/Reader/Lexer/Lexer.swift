
/// Lexical analyzer for Swish source code
public class Lexer {
    private let source: String
    private(set) var index: String.Index
    private(set) var line: Int = 1
    private(set) var column: Int = 1

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
            return try scanNumber(startLine: startLine, startColumn: startColumn)
        }

        if char == "+" || char == "-" {
            if let next = peekAt(1), next.isNumber {
                let sign = String(advance())
                return try scanNumber(startLine: startLine, startColumn: startColumn, prefix: sign)
            }
            return scanSymbol(startLine: startLine, startColumn: startColumn)
        }

        // Handle / as division symbol (standalone)
        if char == "/" {
            _ = advance()
            return Token(type: .symbol, text: "/", line: startLine, column: startColumn)
        }

        if char == "\"" { return try scanString(startLine: startLine, startColumn: startColumn) }
        if char == "\\" { return try scanCharacter(startLine: startLine, startColumn: startColumn) }
        if char == ":"  { return try scanKeyword(startLine: startLine, startColumn: startColumn) }

        switch char {
        case "(": _ = advance(); return Token(type: .leftParen,        text: "(",  line: startLine, column: startColumn)
        case ")": _ = advance(); return Token(type: .rightParen,       text: ")",  line: startLine, column: startColumn)
        case "[": _ = advance(); return Token(type: .leftBracket,      text: "[",  line: startLine, column: startColumn)
        case "]": _ = advance(); return Token(type: .rightBracket,     text: "]",  line: startLine, column: startColumn)
        case "'": _ = advance(); return Token(type: .quote,            text: "'",  line: startLine, column: startColumn)
        case "`": _ = advance(); return Token(type: .backtick,         text: "`",  line: startLine, column: startColumn)
        case "~":
            _ = advance()
            if peek() == "@" { _ = advance(); return Token(type: .unquoteSplicing, text: "~@", line: startLine, column: startColumn) }
            return Token(type: .unquote, text: "~", line: startLine, column: startColumn)
        default: break
        }

        if isSymbolStart(char) {
            return scanSymbol(startLine: startLine, startColumn: startColumn)
        }

        throw LexerError.illegalCharacter(char, line: startLine, column: startColumn)
    }

    private func scanNumber(startLine: Int, startColumn: Int, prefix: String = "") throws -> Token {
        if peek() == "0", let next = peekAt(1) {
            switch next {
            case "b": return try scanBinaryInteger(startLine: startLine, startColumn: startColumn, prefix: prefix)
            case "o": return try scanOctalInteger(startLine: startLine, startColumn: startColumn, prefix: prefix)
            case "x": return try scanHexInteger(startLine: startLine, startColumn: startColumn, prefix: prefix)
            default: break
            }
        }
        return try scanDecimalNumber(startLine: startLine, startColumn: startColumn, prefix: prefix)
    }

    // MARK: - Cursor helpers

    func peek() -> Character? {
        guard index < source.endIndex else { return nil }
        return source[index]
    }

    @discardableResult
    func advance() -> Character {
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

    func peekAt(_ offset: Int) -> Character? {
        var i = index
        for _ in 0..<offset {
            guard i < source.endIndex else { return nil }
            i = source.index(after: i)
        }
        guard i < source.endIndex else { return nil }
        return source[i]
    }

    var isAtEnd: Bool {
        index >= source.endIndex
    }

    // MARK: - Whitespace

    private func skipWhitespace() {
        while let char = peek(), char.isWhitespace || char == "," {
            advance()
        }
    }

    // MARK: - Number helpers

    func isNumberTerminator(_ char: Character?) -> Bool {
        guard let char = char else { return true }
        if char.isWhitespace || char == "," { return true }
        switch char {
        case "(", ")", "[", "]", "\"", ":", "\\", ";":
            return true
        default:
            return false
        }
    }

    func validateNumberEnd(text: String, startLine: Int, startColumn: Int) throws {
        if !isNumberTerminator(peek()) {
            var fullText = text
            while let char = peek(), !isNumberTerminator(char) {
                fullText.append(advance())
            }
            throw LexerError.invalidNumberFormat(fullText, line: startLine, column: startColumn)
        }
    }

    func isHexDigit(_ char: Character) -> Bool { char.isHexDigit }
    func isBinaryDigit(_ char: Character) -> Bool { char == "0" || char == "1" }
    func isOctalDigit(_ char: Character) -> Bool { char >= "0" && char <= "7" }

    // MARK: - Symbol helpers

    func isSymbolStart(_ char: Character) -> Bool {
        if char.isLetter { return true }
        switch char {
        case "*", "+", "!", "-", "_", "?", "<", ">", "=", "&":
            return true
        default:
            return false
        }
    }

    func isSymbolContinuation(_ char: Character) -> Bool {
        isSymbolStart(char) || char.isNumber || char == "'" || char == "#"
    }
}
