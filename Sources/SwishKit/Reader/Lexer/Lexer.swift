
/// Lexical analyzer for Swish source code
public class Lexer {
    private let source: String
    private(set) var index: String.Index
    private(set) var line: Int = 1
    private(set) var column: Int = 1
    /// The current namespace name, used to resolve auto-qualified keywords (::foo → :ns/foo).
    let currentNsName: String

    public init(_ source: String, currentNsName: String = "user") {
        self.source = source
        self.index = source.startIndex
        self.currentNsName = currentNsName
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

        // Handle . as a symbol (Clojure method-call special form or .method name).
        // Only extend past the dot if the next char is a non-digit symbol start
        // (so .5 lexes as "." + 5, not ".5").
        if char == "." {
            _ = advance()
            if let c = peek(), isSymbolStart(c) {
                var text = "."
                text.append(advance())
                while let c = peek(), isSymbolContinuation(c) || c == "." {
                    text.append(advance())
                }
                return Token(type: .symbol, text: text, line: startLine, column: startColumn)
            }
            return Token(type: .symbol, text: ".", line: startLine, column: startColumn)
        }

        if char == "\"" {
            return try scanString(startLine: startLine, startColumn: startColumn)
        }
        if char == "\\" {
            return try scanCharacter(startLine: startLine, startColumn: startColumn)
        }
        if char == ":" {
            return try scanKeyword(startLine: startLine, startColumn: startColumn)
        }

        switch char {
        case "(":
            _ = advance()
            return Token(type: .leftParen, text: "(", line: startLine, column: startColumn)

        case ")":
            _ = advance()
            return Token(type: .rightParen, text: ")", line: startLine, column: startColumn)

        case "[":
            _ = advance()
            return Token(type: .leftBracket, text: "[", line: startLine, column: startColumn)

        case "]":
            _ = advance()
            return Token(type: .rightBracket, text: "]", line: startLine, column: startColumn)

        case "{":
            _ = advance()
            return Token(type: .leftBrace, text: "{", line: startLine, column: startColumn)

        case "}":
            _ = advance()
            return Token(type: .rightBrace, text: "}", line: startLine, column: startColumn)

        case "'":
            _ = advance()
            return Token(type: .quote, text: "'", line: startLine, column: startColumn)

        case "`":
            _ = advance()
            return Token(type: .backtick, text: "`", line: startLine, column: startColumn)

        case "~":
            _ = advance()
            if peek() == "@" {
                _ = advance()
                return Token(type: .unquoteSplicing, text: "~@", line: startLine, column: startColumn)
            }
            return Token(type: .unquote, text: "~", line: startLine, column: startColumn)

        case "@":
            _ = advance()
            return Token(type: .deref, text: "@", line: startLine, column: startColumn)

        case "^":
            _ = advance()
            return Token(type: .metadata, text: "^", line: startLine, column: startColumn)

        case "#":
            _ = advance()
            if peek() == "'" {
                _ = advance()
                return Token(type: .varRef, text: "#'", line: startLine, column: startColumn)
            }
            if peek() == "_" {
                _ = advance()
                return Token(type: .discard, text: "#_", line: startLine, column: startColumn)
            }
            if peek() == "{" {
                _ = advance()
                return Token(type: .leftSet, text: "#{", line: startLine, column: startColumn)
            }
            if peek() == "(" {
                _ = advance()
                return Token(type: .anonymousFn, text: "#(", line: startLine, column: startColumn)
            }
            if peek() == "\"" {
                return try scanRegex(startLine: startLine, startColumn: startColumn)
            }
            if peek() == "?" {
                _ = advance()
                if peek() == "@" {
                    _ = advance()
                    return Token(type: .readerConditionalSplicing, text: "#?@", line: startLine, column: startColumn)
                }
                return Token(type: .readerConditional, text: "#?", line: startLine, column: startColumn)
            }
            if peek() == "#" {
                _ = advance()
                let name = scanQualifiedName()
                return Token(type: .float, text: "##\(name)", line: startLine, column: startColumn)
            }
            if let c = peek(), isSymbolStart(c) {
                let tag = scanQualifiedName()
                return Token(type: .taggedLiteral, text: tag, line: startLine, column: startColumn)
            }
            throw LexerError.illegalCharacter("#", line: startLine, column: startColumn)

        default:
            break
        }

        if isSymbolStart(char) {
            return scanSymbol(startLine: startLine, startColumn: startColumn)
        }

        throw LexerError.illegalCharacter(char, line: startLine, column: startColumn)
    }

    private func scanNumber(startLine: Int, startColumn: Int, prefix: String = "") throws -> Token {
        if peek() == "0", let next = peekAt(1) {
            switch next {
            case "b":
                return try scanBinaryInteger(startLine: startLine, startColumn: startColumn, prefix: prefix)

            case "o":
                return try scanOctalInteger(startLine: startLine, startColumn: startColumn, prefix: prefix)

            case "x":
                return try scanHexInteger(startLine: startLine, startColumn: startColumn, prefix: prefix)

            default:
                break
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

    func skipWhitespace() {
        while true {
            while let char = peek(), char.isWhitespace || char == "," {
                advance()
            }
            guard peek() == ";" else { break }
            while let char = peek(), char != "\n" {
                advance()
            }
        }
    }

    // MARK: - Number helpers

    func isNumberTerminator(_ char: Character?) -> Bool {
        guard let char = char else { return true }
        if char.isWhitespace || char == "," {
            return true
        }
        switch char {
        case "(", ")", "[", "]", "{", "}", "\"", ":", "\\", ";":
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
        if char.isLetter {
            return true
        }
        switch char {
        case "*", "+", "!", "-", "_", "?", "<", ">", "=", "&", "%", "$":
            return true

        default:
            return false
        }
    }

    func isSymbolContinuation(_ char: Character) -> Bool {
        isSymbolStart(char) || char.isNumber || char == "'" || char == "#" || char == ":"
    }
}
