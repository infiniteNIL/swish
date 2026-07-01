extension Lexer {
    func scanCharacter(startLine: Int, startColumn: Int) throws -> Token {
        advance()  // consume backslash

        guard let char = peek() else {
            throw LexerError.invalidCharacterLiteral("unexpected end of input", line: startLine, column: startColumn)
        }

        // Octal character literal: \oXXX (1-3 octal digits, value 0-377 octal = 0-255 decimal)
        if char == "o", let next = peekAt(1), next.isNumber {
            return try scanOctalChar(startLine: startLine, startColumn: startColumn)
        }

        // Clojure Unicode character literal: \uXXXX (exactly 4 hex digits, no braces)
        if char == "u",
           let d1 = peekAt(1), d1.isHexDigit,
           let d2 = peekAt(2), d2.isHexDigit,
           let d3 = peekAt(3), d3.isHexDigit,
           let d4 = peekAt(4), d4.isHexDigit {
            return try scanHex4UnicodeChar(startLine: startLine, startColumn: startColumn)
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

    private func scanOctalChar(startLine: Int, startColumn: Int) throws -> Token {
        advance()  // consume 'o'
        var digits = ""
        while let c = peek(), c.isNumber {
            guard c >= "0" && c <= "7" else {
                throw LexerError.invalidCharacterLiteral(
                    "invalid octal digit '\(c)' in character literal",
                    line: line, column: column)
            }
            digits.append(advance())
            if digits.count == 3 { break }
        }
        if let c = peek(), c.isNumber {
            throw LexerError.invalidCharacterLiteral(
                "too many octal digits in character literal",
                line: startLine, column: startColumn)
        }
        guard let value = UInt32(digits, radix: 8), value <= 0xFF,
              let scalar = Unicode.Scalar(value) else {
            throw LexerError.invalidCharacterLiteral(
                "octal character literal \\o\(digits) out of range (must be 0-377 octal)",
                line: startLine, column: startColumn)
        }
        return Token(type: .character, text: String(Character(scalar)), line: startLine, column: startColumn)
    }

    private func scanHex4UnicodeChar(startLine: Int, startColumn: Int) throws -> Token {
        advance()  // consume 'u'
        var hexDigits = ""
        for _ in 0..<4 { hexDigits.append(advance()) }
        guard let codePoint = UInt32(hexDigits, radix: 16),
              let scalar = Unicode.Scalar(codePoint) else {
            throw LexerError.invalidCharacterLiteral(
                "invalid Unicode code point \\u\(hexDigits)",
                line: startLine, column: startColumn)
        }
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

        // Special single-char keywords: :/ and :. (with possible continuation)
        if char == "/" {
            _ = advance()
            return Token(type: .keyword, text: "/", line: startLine, column: startColumn)
        }
        if char == "." {
            _ = advance()
            var text = "."
            while let c = peek(), isSymbolContinuation(c) || c == "." {
                text.append(advance())
            }
            return Token(type: .keyword, text: text, line: startLine, column: startColumn)
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
                // Always include the dot — trailing dot is Clojure constructor call
                // syntax (ClassName.), interior dot is namespace separator (foo.bar).
                text.append(advance())
            }
            else if char == "/" {
                if hasSlash || text.isEmpty {
                    break
                }
                // foo// → namespace "foo", name "/" (Clojure allows "/" as a symbol name)
                if peekAt(1) == "/" {
                    text.append(advance())  // consume '/' (namespace separator)
                    hasSlash = true
                    text.append(advance())  // consume '/' (the name is "/")
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
