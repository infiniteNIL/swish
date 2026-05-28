// Ordered pairs shared by Lexer (name→char) and Printer (char→name).
let namedCharacters: KeyValuePairs<String, Character> = [
    "newline":   "\n",
    "tab":       "\t",
    "space":     " ",
    "return":    "\r",
    "backspace": "\u{0008}",
    "formfeed":  "\u{000C}",
]

extension Lexer {
    // Call after 'u' and '{' have been consumed from the stream.
    func parseUnicodeHexContent(unterminated: LexerError, startLine: Int, startColumn: Int) throws -> Character {
        var hexDigits = ""
        while !isAtEnd && peek() != "}" {
            guard let char = peek(), char.isHexDigit else {
                throw LexerError.invalidUnicodeEscape("invalid hex digit", line: line, column: column)
            }
            hexDigits.append(advance())
        }
        guard !isAtEnd else { throw unterminated }
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
}
