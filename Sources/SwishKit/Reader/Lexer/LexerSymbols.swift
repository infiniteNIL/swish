extension Lexer {
    func scanCharacter(startLine: Int, startColumn: Int) throws -> Token {
        advance()  // consume backslash

        guard let char = peek() else {
            throw LexerError.invalidCharacterLiteral("unexpected end of input", line: startLine, column: startColumn)
        }

        if char.isWhitespace {
            throw LexerError.invalidCharacterLiteral(
                "whitespace after backslash (use \\space for space character)",
                line: startLine, column: startColumn)
        }

        // Unicode escape: \u{XXXX}
        if char == "u", let next = peekAt(1), next == "{" {
            return try scanUnicodeCharacter(startLine: startLine, startColumn: startColumn)
        }

        // Named character or single letter
        if char.isLetter {
            var name = ""
            while let c = peek(), c.isLetter {
                name.append(advance())
            }

            if name.count == 1 {
                return Token(type: .character, text: name, line: startLine, column: startColumn)
            }

            if let resolved = resolveNamedCharacter(name) {
                return Token(type: .character, text: String(resolved), line: startLine, column: startColumn)
            }
            throw LexerError.unknownNamedCharacter(name, line: startLine, column: startColumn)
        }

        // Any other single character
        return Token(type: .character, text: String(advance()), line: startLine, column: startColumn)
    }

    private func resolveNamedCharacter(_ name: String) -> Character? {
        switch name {
        case "newline":
            return "\n"

        case "tab":
            return "\t"

        case "space":
            return " "

        case "return":
            return "\r"

        case "backspace":
            return "\u{0008}"

        case "formfeed":
            return "\u{000C}"

        default:
            return nil
        }
    }

    private func scanUnicodeCharacter(startLine: Int, startColumn: Int) throws -> Token {
        advance()  // consume 'u'
        advance()  // consume '{'

        var hexDigits = ""
        while !isAtEnd && peek() != "}" {
            guard let char = peek(), char.isHexDigit else {
                throw LexerError.invalidUnicodeEscape("invalid hex digit", line: line, column: column)
            }
            hexDigits.append(advance())
        }

        guard !isAtEnd else {
            throw LexerError.invalidCharacterLiteral("unterminated unicode escape", line: startLine, column: startColumn)
        }
        guard !hexDigits.isEmpty && hexDigits.count <= 6 else {
            throw LexerError.invalidUnicodeEscape("expected 1-6 hex digits", line: line, column: column)
        }
        guard let codePoint = UInt32(hexDigits, radix: 16),
              let scalar = Unicode.Scalar(codePoint) else {
            throw LexerError.invalidUnicodeEscape("invalid code point", line: line, column: column)
        }

        advance()  // consume '}'
        return Token(type: .character, text: String(Character(scalar)), line: startLine, column: startColumn)
    }

    func scanSymbol(startLine: Int, startColumn: Int) -> Token {
        let text = scanQualifiedName()
        switch text {
        case "true", "false":
            return Token(type: .boolean, text: text, line: startLine, column: startColumn)

        case "nil":
            return Token(type: .nil, text: text, line: startLine, column: startColumn)

        default:
            return Token(type: .symbol, text: text, line: startLine, column: startColumn)
        }
    }

    func scanKeyword(startLine: Int, startColumn: Int) throws -> Token {
        advance() // consume leading ':'

        if let char = peek(), char == ":" {
            throw LexerError.unsupportedAutoResolvedKeyword(line: startLine, column: startColumn)
        }

        guard let char = peek() else {
            throw LexerError.invalidKeyword("expected name after ':'", line: startLine, column: startColumn)
        }

        if char.isWhitespace {
            throw LexerError.invalidKeyword("whitespace after ':'", line: startLine, column: startColumn)
        }
        if char.isNumber {
            throw LexerError.invalidKeyword("keyword cannot start with a number", line: startLine, column: startColumn)
        }
        if !isSymbolStart(char) {
            throw LexerError.invalidKeyword("invalid character '\(char)' after ':'", line: startLine, column: startColumn)
        }

        let text = scanQualifiedName()
        return Token(type: .keyword, text: text, line: startLine, column: startColumn)
    }

    private func scanQualifiedName() -> String {
        var text = ""
        var hasSlash = false
        while let char = peek() {
            if isSymbolContinuation(char) {
                text.append(advance())
            }
            else if char == "." {
                if text.isEmpty {
                    break
                }
                if let next = peekAt(1), isSymbolContinuation(next) {
                    text.append(advance())
                }
                else {
                    break
                }
            }
            else if char == "/" {
                if hasSlash || text.isEmpty {
                    break
                }
                if let next = peekAt(1), isSymbolContinuation(next) || next == "." {
                    text.append(advance())
                    hasSlash = true
                }
                else {
                    break
                }
            }
            else {
                break
            }
        }
        return text
    }
}
