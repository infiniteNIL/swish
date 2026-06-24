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
        namedCharacters.first(where: { $0.key == name })?.value
    }

    private func scanUnicodeCharacter(startLine: Int, startColumn: Int) throws -> Token {
        advance()  // consume 'u'
        advance()  // consume '{'
        let char = try parseUnicodeHexContent(
            unterminated: .invalidCharacterLiteral("unterminated unicode escape", line: startLine, column: startColumn),
            startLine: startLine, startColumn: startColumn)
        return Token(type: .character, text: String(char), line: startLine, column: startColumn)
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
            _ = advance()  // consume second ':'
            let localName = scanQualifiedName()
            guard !localName.isEmpty else {
                throw LexerError.invalidKeyword("expected name after '::'", line: startLine, column: startColumn)
            }
            let qualified = "\(currentNsName)/\(localName)"
            return Token(type: .keyword, text: qualified, line: startLine, column: startColumn)
        }

        guard let char = peek() else {
            throw LexerError.invalidKeyword("expected name after ':'", line: startLine, column: startColumn)
        }

        if char.isWhitespace {
            throw LexerError.invalidKeyword("whitespace after ':'", line: startLine, column: startColumn)
        }
        if !isSymbolStart(char) && !char.isNumber {
            throw LexerError.invalidKeyword("invalid character '\(char)' after ':'", line: startLine, column: startColumn)
        }

        // For digit-starting keywords (e.g. :0, :1, :-1), scan manually since
        // scanQualifiedName expects at least one symbol-start char first.
        var text = ""
        if char.isNumber {
            while let c = peek(), isSymbolContinuation(c) {
                text.append(advance())
            }
        } else {
            text = scanQualifiedName()
        }
        return Token(type: .keyword, text: text, line: startLine, column: startColumn)
    }

    func scanQualifiedName() -> String {
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
