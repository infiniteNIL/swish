extension Lexer {
    func scanDecimalNumber(startLine: Int, startColumn: Int, prefix: String = "") throws -> Token {
        var text = prefix
        var isFloat = false

        try scanDigitSequence(into: &text, isDigit: { $0.isNumber }, startLine: startLine, startColumn: startColumn)

        // Clojure radix notation: NrDIGITS (e.g., 2r1111, 16rFF, 36rZ)
        if peek() == "r" {
            let noSign = text.hasPrefix("-") || text.hasPrefix("+") ? String(text.dropFirst()) : text
            if !noSign.isEmpty && noSign.allSatisfy({ $0.isNumber }) {
                advance() // consume 'r'
                var digitText = ""
                while let c = peek(), c.isLetter || c.isNumber {
                    digitText.append(advance())
                }
                guard !digitText.isEmpty else {
                    throw LexerError.invalidNumberFormat(text + "r", line: startLine, column: startColumn)
                }
                // N and M at the end of radix digits are BigInt/BigDecimal suffixes,
                // not part of the number — strip them before calling validateNumberEnd.
                var tokenType: TokenType = .integer
                if digitText.last == "N", isNumberTerminator(peek()) {
                    digitText.removeLast()
                    tokenType = .bigInteger
                } else if digitText.last == "M", isNumberTerminator(peek()) {
                    digitText.removeLast()
                    tokenType = .bigDecimal
                }
                let fullText = text + "r" + digitText
                try validateNumberEnd(text: fullText, startLine: startLine, startColumn: startColumn)
                return Token(type: tokenType, text: fullText, line: startLine, column: startColumn)
            }
        }

        // Check for ratio: / followed by digit
        if peek() == "/", let afterSlash = peekAt(1), afterSlash.isNumber {
            text.append(advance()) // consume '/'
            try scanDigitSequence(into: &text, isDigit: { $0.isNumber }, startLine: startLine, startColumn: startColumn)
            try validateNumberEnd(text: text, startLine: startLine, startColumn: startColumn)
            let cleanText = text.filter { $0 != "_" }
            let parts = cleanText.split(separator: "/", maxSplits: 1)
            if parts.count == 2, let denom = Int(String(parts[1])), denom == 0 {
                throw LexerError.invalidRatio(cleanText, line: startLine, column: startColumn)
            }
            return Token(type: .ratio, text: cleanText, line: startLine, column: startColumn)
        }

        // Check for fractional part: . followed by digit
        if peek() == ".", let afterDot = peekAt(1), afterDot.isNumber {
            isFloat = true
            text.append(advance()) // consume '.'
            try scanDigitSequence(into: &text, isDigit: { $0.isNumber }, startLine: startLine, startColumn: startColumn)
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
                try scanDigitSequence(into: &text, isDigit: { $0.isNumber }, startLine: startLine, startColumn: startColumn)
            }
        }

        let cleanText = text.filter { $0 != "_" }

        // Clojure BigDecimal (M) and BigInteger (N) suffixes
        if let suffix = peek(), suffix == "M" {
            advance()
            try validateNumberEnd(text: text, startLine: startLine, startColumn: startColumn)
            return Token(type: .bigDecimal, text: cleanText, line: startLine, column: startColumn)
        } else if let suffix = peek(), suffix == "N" {
            advance()
            try validateNumberEnd(text: text, startLine: startLine, startColumn: startColumn)
            return Token(type: .bigInteger, text: cleanText, line: startLine, column: startColumn)
        }

        try validateNumberEnd(text: text, startLine: startLine, startColumn: startColumn)
        return Token(type: isFloat ? .float : .integer, text: cleanText, line: startLine, column: startColumn)
    }

    func scanHexInteger(startLine: Int, startColumn: Int, prefix: String) throws -> Token {
        try scanPrefixedInteger(startLine: startLine, startColumn: startColumn, prefix: prefix, isDigit: isHexDigit)
    }

    func scanBinaryInteger(startLine: Int, startColumn: Int, prefix: String) throws -> Token {
        try scanPrefixedInteger(startLine: startLine, startColumn: startColumn, prefix: prefix, isDigit: isBinaryDigit)
    }

    func scanOctalInteger(startLine: Int, startColumn: Int, prefix: String) throws -> Token {
        try scanPrefixedInteger(startLine: startLine, startColumn: startColumn, prefix: prefix, isDigit: isOctalDigit)
    }

    private func scanPrefixedInteger(
        startLine: Int, startColumn: Int,
        prefix: String,
        isDigit: (Character) -> Bool
    ) throws -> Token {
        var text = prefix
        text.append(advance()) // '0'
        text.append(advance()) // base prefix char (x / b / o)
        try scanDigitSequence(into: &text, isDigit: isDigit, requiresLeadingDigit: true,
                              startLine: startLine, startColumn: startColumn)
        try validateNumberEnd(text: text, startLine: startLine, startColumn: startColumn)
        let cleanText = text.filter { $0 != "_" }
        return Token(type: .integer, text: cleanText, line: startLine, column: startColumn)
    }

    /// Scans a sequence of digits (determined by `isDigit`) and underscores into `text`.
    /// Rejects consecutive underscores and a trailing underscore.
    /// When `requiresLeadingDigit` is true, also rejects an empty sequence (e.g. `0x_`).
    private func scanDigitSequence(
        into text: inout String,
        isDigit: (Character) -> Bool,
        requiresLeadingDigit: Bool = false,
        startLine: Int,
        startColumn: Int
    ) throws {
        var hasDigits = false
        var lastWasUnderscore = false

        while let char = peek() {
            if isDigit(char) {
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

        if (requiresLeadingDigit && !hasDigits) || lastWasUnderscore {
            throw LexerError.invalidNumberFormat(text, line: startLine, column: startColumn)
        }
    }
}
