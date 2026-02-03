/// Token types for the Swish lexer
public enum TokenType: Equatable, Sendable {
    case integer
    case float
    case ratio
    case string
    case character
    case boolean
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
    case invalidRatio(String, line: Int, column: Int)
    case unterminatedString(line: Int, column: Int)
    case invalidEscapeSequence(char: Character, line: Int, column: Int)
    case invalidUnicodeEscape(String, line: Int, column: Int)
    case multilineStringContentOnOpeningLine(line: Int, column: Int)
    case multilineStringInsufficientIndentation(line: Int, column: Int)
    case unterminatedMultilineString(line: Int, column: Int)
    case invalidCharacterLiteral(String, line: Int, column: Int)
    case unknownNamedCharacter(String, line: Int, column: Int)

    public var description: String {
        switch self {
        case .illegalCharacter(let char, let line, let column):
            "Illegal character '\(char)' (line \(line), column \(column))."

        case .invalidNumberFormat(let text, let line, let column):
            "Invalid number format '\(text)' (line \(line), column \(column))."

        case .invalidRatio(let text, let line, let column):
            "Invalid ratio '\(text)': division by zero (line \(line), column \(column))."

        case .unterminatedString(let line, let column):
            "Unterminated string (line \(line), column \(column))."

        case .invalidEscapeSequence(let char, let line, let column):
            "Invalid escape sequence '\\(\(char))' (line \(line), column \(column))."

        case .invalidUnicodeEscape(let reason, let line, let column):
            "Invalid Unicode escape: \(reason) (line \(line), column \(column))."

        case .multilineStringContentOnOpeningLine(let line, let column):
            "Multiline string literal must begin with a newline after opening delimiter (line \(line), column \(column))."

        case .multilineStringInsufficientIndentation(let line, let column):
            "Insufficient indentation in multiline string literal (line \(line), column \(column))."

        case .unterminatedMultilineString(let line, let column):
            "Unterminated multiline string literal (line \(line), column \(column))."

        case .invalidCharacterLiteral(let reason, let line, let column):
            "Invalid character literal: \(reason) (line \(line), column \(column))."

        case .unknownNamedCharacter(let name, let line, let column):
            "Unknown named character '\\(\(name))' (line \(line), column \(column))."
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

        // Unsigned binary: 0b...
        if char == "0", let next = peekAt(1), next == "b" {
            return try scanBinaryInteger(startLine: startLine, startColumn: startColumn, prefix: "")
        }

        // Unsigned octal: 0o...
        if char == "0", let next = peekAt(1), next == "o" {
            return try scanOctalInteger(startLine: startLine, startColumn: startColumn, prefix: "")
        }

        // Unsigned hex: 0x...
        if char == "0", let next = peekAt(1), next == "x" {
            return try scanHexInteger(startLine: startLine, startColumn: startColumn, prefix: "")
        }

        if char.isNumber {
            return try scanDecimalNumber(startLine: startLine, startColumn: startColumn)
        }

        if char == "+" || char == "-" {
            let signChar = advance()

            // Check for binary: sign followed by 0b
            if let next = peek(), next == "0",
               let afterZero = peekAt(1), afterZero == "b" {
                return try scanBinaryInteger(startLine: startLine, startColumn: startColumn, prefix: String(signChar))
            }

            // Check for octal: sign followed by 0o
            if let next = peek(), next == "0",
               let afterZero = peekAt(1), afterZero == "o" {
                return try scanOctalInteger(startLine: startLine, startColumn: startColumn, prefix: String(signChar))
            }

            // Check for hex: sign followed by 0x
            if let next = peek(), next == "0",
               let afterZero = peekAt(1), afterZero == "x" {
                return try scanHexInteger(startLine: startLine, startColumn: startColumn, prefix: String(signChar))
            }

            if let next = peek(), next.isNumber {
                return try scanDecimalNumber(startLine: startLine, startColumn: startColumn, prefix: String(signChar))
            }
            else {
                throw LexerError.illegalCharacter(signChar, line: startLine, column: startColumn)
            }
        }

        if char == "\"" {
            return try scanString(startLine: startLine, startColumn: startColumn)
        }

        if char == "\\" {
            return try scanCharacter(startLine: startLine, startColumn: startColumn)
        }

        if char.isLetter {
            return try scanIdentifier(startLine: startLine, startColumn: startColumn)
        }

        throw LexerError.illegalCharacter(char, line: startLine, column: startColumn)
    }

    private func skipWhitespace() {
        while let char = peek(), char.isWhitespace {
            _ = advance()
        }
    }

    private func scanDecimalNumber(startLine: Int, startColumn: Int, prefix: String = "") throws -> Token {
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

        // Check for ratio: / followed by digit
        if let slash = peek(), slash == "/", let afterSlash = peekAt(1), afterSlash.isNumber {
            text.append(advance()) // consume '/'
            lastWasUnderscore = false

            // Scan denominator digits
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

            // Check for division by zero
            let parts = cleanText.split(separator: "/", maxSplits: 1)
            if parts.count == 2 {
                let denomStr = String(parts[1])
                if let denom = Int(denomStr), denom == 0 {
                    throw LexerError.invalidRatio(cleanText, line: startLine, column: startColumn)
                }
            }

            return Token(type: .ratio, text: cleanText, line: startLine, column: startColumn)
        }

        // Check for fractional part: . followed by digit
        if let dot = peek(), dot == ".", let afterDot = peekAt(1), afterDot.isNumber {
            isFloat = true
            text.append(advance()) // consume '.'
            lastWasUnderscore = false

            // Scan fractional digits
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
        }

        // Check for exponent: e or E
        if let e = peek(), e == "e" || e == "E" {
            // Need at least one digit after exponent (with optional sign)
            var offset = 1
            if let sign = peekAt(offset), sign == "+" || sign == "-" {
                offset += 1
            }
            if let digitAfter = peekAt(offset), digitAfter.isNumber {
                isFloat = true
                text.append(advance()) // consume 'e' or 'E'

                // Consume optional sign
                if let sign = peek(), sign == "+" || sign == "-" {
                    text.append(advance())
                }

                lastWasUnderscore = false
                var hasExponentDigits = false

                // Scan exponent digits
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
            }
        }

        let cleanText = text.filter { $0 != "_" }
        let tokenType: TokenType = isFloat ? .float : .integer
        return Token(type: tokenType, text: cleanText, line: startLine, column: startColumn)
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

    private func scanBinaryInteger(startLine: Int, startColumn: Int, prefix: String) throws -> Token {
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

    private func isBinaryDigit(_ char: Character) -> Bool {
        char == "0" || char == "1"
    }

    private func scanOctalInteger(startLine: Int, startColumn: Int, prefix: String) throws -> Token {
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

    private func isOctalDigit(_ char: Character) -> Bool {
        char >= "0" && char <= "7"
    }

    private var isAtEnd: Bool {
        index >= source.endIndex
    }

    private func scanString(startLine: Int, startColumn: Int) throws -> Token {
        _ = advance()  // consume opening quote

        // Check for multiline string: """
        if peek() == "\"" && peekAt(1) == "\"" {
            _ = advance()  // consume second quote
            _ = advance()  // consume third quote
            return try scanMultilineString(startLine: startLine, startColumn: startColumn)
        }

        var value = ""

        while !isAtEnd && peek() != "\"" {
            if peek() == "\\" {
                _ = advance()  // consume backslash
                if isAtEnd {
                    throw LexerError.unterminatedString(line: startLine, column: startColumn)
                }
                switch peek()! {
                case "\"": value.append("\"")
                case "\\": value.append("\\")
                case "n": value.append("\n")
                case "t": value.append("\t")
                case "r": value.append("\r")
                case "0": value.append("\0")
                case "u":
                    guard let next = peekAt(1), next == "{" else {
                        throw LexerError.invalidUnicodeEscape("expected '{'", line: line, column: column)
                    }
                    _ = advance()  // consume 'u'
                    _ = advance()  // consume '{'

                    var hexDigits = ""
                    while !isAtEnd && peek() != "}" {
                        guard let char = peek(), char.isHexDigit else {
                            throw LexerError.invalidUnicodeEscape("invalid hex digit", line: line, column: column)
                        }
                        hexDigits.append(advance())
                    }

                    guard !isAtEnd else {
                        throw LexerError.unterminatedString(line: startLine, column: startColumn)
                    }
                    guard !hexDigits.isEmpty && hexDigits.count <= 6 else {
                        throw LexerError.invalidUnicodeEscape("expected 1-6 hex digits", line: line, column: column)
                    }
                    guard let codePoint = UInt32(hexDigits, radix: 16),
                          let scalar = Unicode.Scalar(codePoint) else {
                        throw LexerError.invalidUnicodeEscape("invalid code point", line: line, column: column)
                    }

                    value.append(Character(scalar))
                    // The shared advance() after the switch will consume '}'
                default:
                    throw LexerError.invalidEscapeSequence(char: peek()!, line: line, column: column)
                }
                _ = advance()
            }
            else if peek() == "\n" {
                // Allow multiline strings - track line/column
                value.append(peek()!)
                _ = advance()
            }
            else {
                value.append(peek()!)
                _ = advance()
            }
        }

        if isAtEnd {
            throw LexerError.unterminatedString(line: startLine, column: startColumn)
        }

        _ = advance()  // consume closing quote
        return Token(type: .string, text: value, line: startLine, column: startColumn)
    }

    private func scanMultilineString(startLine: Int, startColumn: Int) throws -> Token {
        // After opening """, only whitespace is allowed before the newline
        while !isAtEnd && peek() != "\n" {
            if let char = peek(), !char.isWhitespace {
                throw LexerError.multilineStringContentOnOpeningLine(line: line, column: column)
            }
            _ = advance()
        }

        // Must have a newline after opening """
        if isAtEnd {
            throw LexerError.unterminatedMultilineString(line: startLine, column: startColumn)
        }
        _ = advance()  // consume the newline after opening """

        // Collect raw lines until we find closing """
        var rawLines: [String] = []
        var currentLine = ""

        while !isAtEnd {
            // Check for closing """
            if peek() == "\"" && peekAt(1) == "\"" && peekAt(2) == "\"" {
                // Found closing delimiter - don't include the current line content
                // (it should be the indentation before closing """)
                break
            }

            if peek() == "\n" {
                rawLines.append(currentLine)
                currentLine = ""
                _ = advance()
            }
            else {
                currentLine.append(advance())
            }
        }

        if isAtEnd {
            throw LexerError.unterminatedMultilineString(line: startLine, column: startColumn)
        }

        // currentLine now contains the whitespace before closing """
        // This determines the baseline indentation
        let closingIndentation = currentLine

        // Verify closing indentation is all whitespace
        for char in closingIndentation {
            if !char.isWhitespace {
                throw LexerError.multilineStringInsufficientIndentation(line: line, column: column)
            }
        }

        // Consume the closing """
        _ = advance()  // first "
        _ = advance()  // second "
        _ = advance()  // third "

        // Process each line: strip baseline indentation
        var strippedLines: [String] = []

        for (lineIndex, rawLine) in rawLines.enumerated() {
            // Empty lines don't need indentation stripping
            if rawLine.isEmpty {
                strippedLines.append("")
                continue
            }

            // Whitespace-only lines: strip up to the baseline, keep the rest
            let isWhitespaceOnly = rawLine.allSatisfy { $0.isWhitespace }

            // Check if line has sufficient indentation
            if !rawLine.hasPrefix(closingIndentation) {
                // For whitespace-only lines, if they have less indentation than baseline,
                // they become empty lines
                if isWhitespaceOnly {
                    strippedLines.append("")
                    continue
                }
                // Content line with insufficient indentation
                throw LexerError.multilineStringInsufficientIndentation(
                    line: startLine + 1 + lineIndex,
                    column: 1
                )
            }

            // Strip the baseline indentation
            let strippedLine = String(rawLine.dropFirst(closingIndentation.count))
            strippedLines.append(strippedLine)
        }

        // Join lines, handling line continuations
        var joinedContent = ""
        var i = 0
        while i < strippedLines.count {
            let line = strippedLines[i]

            // Check for line continuation (backslash at end that isn't escaped)
            if line.hasSuffix("\\") && !line.hasSuffix("\\\\") {
                // Line continuation - append without the trailing backslash and without newline
                joinedContent.append(String(line.dropLast()))
            }
            else if line.hasSuffix("\\\\") {
                // Escaped backslash at end - will be processed as escape later
                joinedContent.append(line)
                if i < strippedLines.count - 1 {
                    joinedContent.append("\n")
                }
            }
            else {
                joinedContent.append(line)
                if i < strippedLines.count - 1 {
                    joinedContent.append("\n")
                }
            }
            i += 1
        }

        // Now process escape sequences
        var result = ""
        var charIndex = joinedContent.startIndex

        while charIndex < joinedContent.endIndex {
            let char = joinedContent[charIndex]

            if char == "\\" {
                let nextIndex = joinedContent.index(after: charIndex)
                guard nextIndex < joinedContent.endIndex else {
                    throw LexerError.unterminatedMultilineString(line: startLine, column: startColumn)
                }

                let nextChar = joinedContent[nextIndex]
                switch nextChar {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "r": result.append("\r")
                case "0": result.append("\0")
                case "u":
                    // Unicode escape - need to look ahead for {
                    let afterU = joinedContent.index(nextIndex, offsetBy: 1, limitedBy: joinedContent.endIndex) ?? joinedContent.endIndex
                    if afterU >= joinedContent.endIndex || joinedContent[afterU] != "{" {
                        throw LexerError.invalidUnicodeEscape("expected '{'", line: startLine, column: startColumn)
                    }

                    var hexDigits = ""
                    var hexIndex = joinedContent.index(after: afterU)
                    while hexIndex < joinedContent.endIndex && joinedContent[hexIndex] != "}" {
                        let hexChar = joinedContent[hexIndex]
                        guard hexChar.isHexDigit else {
                            throw LexerError.invalidUnicodeEscape("invalid hex digit", line: startLine, column: startColumn)
                        }
                        hexDigits.append(hexChar)
                        hexIndex = joinedContent.index(after: hexIndex)
                    }

                    guard hexIndex < joinedContent.endIndex else {
                        throw LexerError.unterminatedMultilineString(line: startLine, column: startColumn)
                    }
                    guard !hexDigits.isEmpty && hexDigits.count <= 6 else {
                        throw LexerError.invalidUnicodeEscape("expected 1-6 hex digits", line: startLine, column: startColumn)
                    }
                    guard let codePoint = UInt32(hexDigits, radix: 16),
                          let scalar = Unicode.Scalar(codePoint) else {
                        throw LexerError.invalidUnicodeEscape("invalid code point", line: startLine, column: startColumn)
                    }

                    result.append(Character(scalar))
                    charIndex = hexIndex  // point to }, will be advanced below
                    charIndex = joinedContent.index(after: charIndex)
                    continue
                default:
                    throw LexerError.invalidEscapeSequence(char: nextChar, line: startLine, column: startColumn)
                }
                charIndex = joinedContent.index(after: nextIndex)
            }
            else {
                result.append(char)
                charIndex = joinedContent.index(after: charIndex)
            }
        }

        return Token(type: .string, text: result, line: startLine, column: startColumn)
    }

    private func scanCharacter(startLine: Int, startColumn: Int) throws -> Token {
        _ = advance()  // consume backslash

        guard let char = peek() else {
            throw LexerError.invalidCharacterLiteral("unexpected end of input", line: startLine, column: startColumn)
        }

        // Whitespace after backslash is invalid
        if char.isWhitespace {
            throw LexerError.invalidCharacterLiteral("whitespace after backslash (use \\space for space character)", line: startLine, column: startColumn)
        }

        // Unicode escape: \u{XXXX}
        if char == "u", let next = peekAt(1), next == "{" {
            return try scanUnicodeCharacter(startLine: startLine, startColumn: startColumn)
        }

        // Check for named character or single letter
        if char.isLetter {
            var name = ""
            while let c = peek(), c.isLetter {
                name.append(advance())
            }

            // Single letter is just that character
            if name.count == 1 {
                return Token(type: .character, text: name, line: startLine, column: startColumn)
            }

            // Multi-letter must be a named character
            if let resolved = resolveNamedCharacter(name) {
                return Token(type: .character, text: String(resolved), line: startLine, column: startColumn)
            }
            else {
                throw LexerError.unknownNamedCharacter(name, line: startLine, column: startColumn)
            }
        }

        // Any other single character
        let singleChar = advance()
        return Token(type: .character, text: String(singleChar), line: startLine, column: startColumn)
    }

    private func resolveNamedCharacter(_ name: String) -> Character? {
        switch name {
        case "newline": return "\n"
        case "tab": return "\t"
        case "space": return " "
        case "return": return "\r"
        case "backspace": return "\u{0008}"
        case "formfeed": return "\u{000C}"
        default: return nil
        }
    }

    private func scanUnicodeCharacter(startLine: Int, startColumn: Int) throws -> Token {
        _ = advance()  // consume 'u'
        _ = advance()  // consume '{'

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

        _ = advance()  // consume '}'

        return Token(type: .character, text: String(Character(scalar)), line: startLine, column: startColumn)
    }

    private func scanIdentifier(startLine: Int, startColumn: Int) throws -> Token {
        var text = ""
        while let char = peek(), char.isLetter || char.isNumber {
            text.append(advance())
        }

        switch text {
        case "true", "false":
            return Token(type: .boolean, text: text, line: startLine, column: startColumn)
        default:
            throw LexerError.illegalCharacter(text.first!, line: startLine, column: startColumn)
        }
    }
}
