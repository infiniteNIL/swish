extension Lexer {
    func scanDecimalNumber(startLine: Int, startColumn: Int, prefix: String = "") throws -> Token {
        var text = prefix
        var lastWasUnderscore = false
        var isFloat = false

        // Scan integer part
        while let char = peek() {
            if char.isNumber {
                text.append(advance())
                lastWasUnderscore = false
            }
            else if char == "_" {
                if lastWasUnderscore {
                    throw LexerError.invalidNumberFormat(text + "_", line: startLine, column: startColumn)
                }
                advance()
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

        // Check for ratio: / followed by digit
        if let slash = peek(), slash == "/", let afterSlash = peekAt(1), afterSlash.isNumber {
            text.append(advance()) // consume '/'
            lastWasUnderscore = false

            while let char = peek() {
                if char.isNumber {
                    text.append(advance())
                    lastWasUnderscore = false
                }
                else if char == "_" {
                    if lastWasUnderscore {
                        throw LexerError.invalidNumberFormat(text + "_", line: startLine, column: startColumn)
                    }
                    advance()
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

            try validateNumberEnd(text: text, startLine: startLine, startColumn: startColumn)
            let cleanText = text.filter { $0 != "_" }

            let parts = cleanText.split(separator: "/", maxSplits: 1)
            if parts.count == 2, let denom = Int(String(parts[1])), denom == 0 {
                throw LexerError.invalidRatio(cleanText, line: startLine, column: startColumn)
            }

            return Token(type: .ratio, text: cleanText, line: startLine, column: startColumn)
        }

        // Check for fractional part: . followed by digit
        if let dot = peek(), dot == ".", let afterDot = peekAt(1), afterDot.isNumber {
            isFloat = true
            text.append(advance()) // consume '.'
            lastWasUnderscore = false

            while let char = peek() {
                if char.isNumber {
                    text.append(advance())
                    lastWasUnderscore = false
                }
                else if char == "_" {
                    if lastWasUnderscore {
                        throw LexerError.invalidNumberFormat(text + "_", line: startLine, column: startColumn)
                    }
                    advance()
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
        }

        // Check for exponent: e or E
        if let e = peek(), e == "e" || e == "E" {
            var offset = 1
            if let sign = peekAt(offset), sign == "+" || sign == "-" {
                offset += 1
            }
            if let digitAfter = peekAt(offset), digitAfter.isNumber {
                isFloat = true
                text.append(advance()) // consume 'e' or 'E'

                if let sign = peek(), sign == "+" || sign == "-" {
                    text.append(advance())
                }

                lastWasUnderscore = false
                var hasExponentDigits = false

                while let char = peek() {
                    if char.isNumber {
                        text.append(advance())
                        hasExponentDigits = true
                        lastWasUnderscore = false
                    }
                    else if char == "_" {
                        if !hasExponentDigits || lastWasUnderscore {
                            throw LexerError.invalidNumberFormat(text + "_", line: startLine, column: startColumn)
                        }
                        advance()
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
            }
        }

        try validateNumberEnd(text: text, startLine: startLine, startColumn: startColumn)
        let cleanText = text.filter { $0 != "_" }
        return Token(type: isFloat ? .float : .integer, text: cleanText, line: startLine, column: startColumn)
    }

    func scanHexInteger(startLine: Int, startColumn: Int, prefix: String) throws -> Token {
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
                advance()
                text.append("_")
                lastWasUnderscore = true
            }
            else {
                break
            }
        }

        if !hasDigits || lastWasUnderscore {
            throw LexerError.invalidNumberFormat(text, line: startLine, column: startColumn)
        }

        try validateNumberEnd(text: text, startLine: startLine, startColumn: startColumn)
        let cleanText = text.filter { $0 != "_" }
        return Token(type: .integer, text: cleanText, line: startLine, column: startColumn)
    }

    func scanBinaryInteger(startLine: Int, startColumn: Int, prefix: String) throws -> Token {
        var text = prefix
        text.append(advance()) // '0'
        text.append(advance()) // 'b'

        var hasDigits = false
        var lastWasUnderscore = false

        while let char = peek() {
            if isBinaryDigit(char) {
                text.append(advance())
                hasDigits = true
                lastWasUnderscore = false
            }
            else if char == "_" {
                if !hasDigits || lastWasUnderscore {
                    throw LexerError.invalidNumberFormat(text + "_", line: startLine, column: startColumn)
                }
                advance()
                text.append("_")
                lastWasUnderscore = true
            }
            else {
                break
            }
        }

        if !hasDigits || lastWasUnderscore {
            throw LexerError.invalidNumberFormat(text, line: startLine, column: startColumn)
        }

        try validateNumberEnd(text: text, startLine: startLine, startColumn: startColumn)
        let cleanText = text.filter { $0 != "_" }
        return Token(type: .integer, text: cleanText, line: startLine, column: startColumn)
    }

    func scanOctalInteger(startLine: Int, startColumn: Int, prefix: String) throws -> Token {
        var text = prefix
        text.append(advance()) // '0'
        text.append(advance()) // 'o'

        var hasDigits = false
        var lastWasUnderscore = false

        while let char = peek() {
            if isOctalDigit(char) {
                text.append(advance())
                hasDigits = true
                lastWasUnderscore = false
            }
            else if char == "_" {
                if !hasDigits || lastWasUnderscore {
                    throw LexerError.invalidNumberFormat(text + "_", line: startLine, column: startColumn)
                }
                advance()
                text.append("_")
                lastWasUnderscore = true
            }
            else {
                break
            }
        }

        if !hasDigits || lastWasUnderscore {
            throw LexerError.invalidNumberFormat(text, line: startLine, column: startColumn)
        }

        try validateNumberEnd(text: text, startLine: startLine, startColumn: startColumn)
        let cleanText = text.filter { $0 != "_" }
        return Token(type: .integer, text: cleanText, line: startLine, column: startColumn)
    }
}
