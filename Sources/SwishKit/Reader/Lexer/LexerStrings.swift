extension Lexer {
    func scanString(startLine: Int, startColumn: Int) throws -> Token {
        advance()  // consume opening quote

        // Check for multiline string: """
        if peek() == "\"" && peekAt(1) == "\"" {
            advance()  // consume second quote
            advance()  // consume third quote
            return try scanMultilineString(startLine: startLine, startColumn: startColumn)
        }

        var value = ""
        while !isAtEnd && peek() != "\"" {
            if peek() == "\\" {
                advance()  // consume backslash
                if isAtEnd { throw LexerError.unterminatedString(line: startLine, column: startColumn) }
                switch peek()! {
                case "\"": value.append("\""); advance()
                case "\\": value.append("\\"); advance()
                case "n":  value.append("\n"); advance()
                case "t":  value.append("\t"); advance()
                case "r":  value.append("\r"); advance()
                case "0":  value.append("\0"); advance()
                case "u":  value.append(try scanUnicodeEscapeFromStream(startLine: startLine, startColumn: startColumn))
                default:   throw LexerError.invalidEscapeSequence(char: peek()!, line: line, column: column)
                }
            } else {
                value.append(advance())
            }
        }

        if isAtEnd { throw LexerError.unterminatedString(line: startLine, column: startColumn) }
        advance()  // consume closing quote
        return Token(type: .string, text: value, line: startLine, column: startColumn)
    }

    func scanMultilineString(startLine: Int, startColumn: Int) throws -> Token {
        let (rawLines, indent) = try collectMultilineRawLines(startLine: startLine, startColumn: startColumn)
        let strippedLines = try stripIndentation(rawLines, indent: indent, startLine: startLine)
        let joinedContent = joinWithContinuations(strippedLines)
        let result = try processEscapeSequences(joinedContent, startLine: startLine, startColumn: startColumn)
        return Token(type: .string, text: result, line: startLine, column: startColumn)
    }

    // MARK: - Single-line string helpers

    private func scanUnicodeEscapeFromStream(startLine: Int, startColumn: Int) throws -> Character {
        guard peekAt(1) == "{" else {
            throw LexerError.invalidUnicodeEscape("expected '{'", line: line, column: column)
        }
        advance()  // consume 'u'
        advance()  // consume '{'

        var hexDigits = ""
        while !isAtEnd && peek() != "}" {
            guard let char = peek(), char.isHexDigit else {
                throw LexerError.invalidUnicodeEscape("invalid hex digit", line: line, column: column)
            }
            hexDigits.append(advance())
        }

        guard !isAtEnd else { throw LexerError.unterminatedString(line: startLine, column: startColumn) }
        guard !hexDigits.isEmpty && hexDigits.count <= 6 else {
            throw LexerError.invalidUnicodeEscape("expected 1-6 hex digits", line: line, column: column)
        }
        guard let codePoint = UInt32(hexDigits, radix: 16),
              let scalar = Unicode.Scalar(codePoint) else {
            throw LexerError.invalidUnicodeEscape("invalid code point", line: line, column: column)
        }

        advance()  // consume '}'
        return Character(scalar)
    }

    // MARK: - Multiline string helpers

    private func collectMultilineRawLines(startLine: Int, startColumn: Int) throws -> (lines: [String], closingIndentation: String) {
        // After opening """, only whitespace is allowed before the newline
        while !isAtEnd && peek() != "\n" {
            if let char = peek(), !char.isWhitespace {
                throw LexerError.multilineStringContentOnOpeningLine(line: line, column: column)
            }
            advance()
        }
        if isAtEnd { throw LexerError.unterminatedMultilineString(line: startLine, column: startColumn) }
        advance()  // consume the newline after opening """

        var rawLines: [String] = []
        var currentLine = ""

        while !isAtEnd {
            if peek() == "\"" && peekAt(1) == "\"" && peekAt(2) == "\"" { break }
            if peek() == "\n" {
                rawLines.append(currentLine)
                currentLine = ""
                advance()
            } else {
                currentLine.append(advance())
            }
        }

        if isAtEnd { throw LexerError.unterminatedMultilineString(line: startLine, column: startColumn) }

        let closingIndentation = currentLine
        for char in closingIndentation {
            if !char.isWhitespace {
                throw LexerError.multilineStringInsufficientIndentation(line: line, column: column)
            }
        }

        advance(); advance(); advance()  // consume closing """
        return (rawLines, closingIndentation)
    }

    private func stripIndentation(_ lines: [String], indent: String, startLine: Int) throws -> [String] {
        try lines.enumerated().map { (lineIndex, rawLine) in
            if rawLine.isEmpty { return "" }
            if rawLine.allSatisfy({ $0.isWhitespace }) { return "" }
            guard rawLine.hasPrefix(indent) else {
                throw LexerError.multilineStringInsufficientIndentation(
                    line: startLine + 1 + lineIndex, column: 1)
            }
            return String(rawLine.dropFirst(indent.count))
        }
    }

    private func joinWithContinuations(_ lines: [String]) -> String {
        var result = ""
        for (i, line) in lines.enumerated() {
            if line.hasSuffix("\\") && !line.hasSuffix("\\\\") {
                result.append(String(line.dropLast()))
            } else {
                result.append(line)
                if i < lines.count - 1 { result.append("\n") }
            }
        }
        return result
    }

    // MARK: - Escape sequence processing

    private func processEscapeSequences(_ input: String, startLine: Int, startColumn: Int) throws -> String {
        var result = ""
        var i = input.startIndex

        while i < input.endIndex {
            let char = input[i]

            guard char == "\\" else {
                result.append(char)
                i = input.index(after: i)
                continue
            }

            let nextIndex = input.index(after: i)
            guard nextIndex < input.endIndex else {
                throw LexerError.unterminatedString(line: startLine, column: startColumn)
            }

            let nextChar = input[nextIndex]
            switch nextChar {
            case "\"": result.append("\"")
            case "\\": result.append("\\")
            case "n":  result.append("\n")
            case "t":  result.append("\t")
            case "r":  result.append("\r")
            case "0":  result.append("\0")
            case "u":
                let afterU = input.index(after: nextIndex)
                guard afterU < input.endIndex, input[afterU] == "{" else {
                    throw LexerError.invalidUnicodeEscape("expected '{'", line: startLine, column: startColumn)
                }
                var hexDigits = ""
                var hexIndex = input.index(after: afterU)
                while hexIndex < input.endIndex && input[hexIndex] != "}" {
                    let hexChar = input[hexIndex]
                    guard hexChar.isHexDigit else {
                        throw LexerError.invalidUnicodeEscape("invalid hex digit", line: startLine, column: startColumn)
                    }
                    hexDigits.append(hexChar)
                    hexIndex = input.index(after: hexIndex)
                }
                guard hexIndex < input.endIndex else {
                    throw LexerError.unterminatedString(line: startLine, column: startColumn)
                }
                guard !hexDigits.isEmpty && hexDigits.count <= 6 else {
                    throw LexerError.invalidUnicodeEscape("expected 1-6 hex digits", line: startLine, column: startColumn)
                }
                guard let codePoint = UInt32(hexDigits, radix: 16),
                      let scalar = Unicode.Scalar(codePoint) else {
                    throw LexerError.invalidUnicodeEscape("invalid code point", line: startLine, column: startColumn)
                }
                result.append(Character(scalar))
                i = input.index(after: hexIndex)  // advance past '}'
                continue
            default:
                throw LexerError.invalidEscapeSequence(char: nextChar, line: startLine, column: startColumn)
            }

            i = input.index(after: nextIndex)
        }

        return result
    }
}
