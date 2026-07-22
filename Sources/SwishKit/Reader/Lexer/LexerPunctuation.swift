extension Lexer {

    /// Scans a single/double-char punctuation or reader-macro-prefix token
    /// starting at `char`. Returns `nil` (instead of the caller falling through
    /// its own switch's `default:`) for anything that isn't punctuation, so
    /// `nextToken` can fall through to its symbol-start check exactly as before.
    func scanPunctuation(_ char: Character, startLine: Int, startColumn: Int) throws -> Token? {
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
            return try scanDispatchMacro(startLine: startLine, startColumn: startColumn)

        default:
            return nil
        }
    }

    /// Scans everything after a leading `#` — reader macros and tagged literals.
    /// Always returns a `Token` or throws; unlike `scanPunctuation`, there's no
    /// fallthrough once `#` has been consumed.
    func scanDispatchMacro(startLine: Int, startColumn: Int) throws -> Token {
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
        if peek() == ":" {
            _ = advance()  // consume ':'
            let ns = scanQualifiedName()
            return Token(type: .namespacedMapPrefix, text: ns, line: startLine, column: startColumn)
        }
        if let c = peek(), isSymbolStart(c) {
            let tag = scanQualifiedName()
            return Token(type: .taggedLiteral, text: tag, line: startLine, column: startColumn)
        }
        throw LexerError.illegalCharacter("#", line: startLine, column: startColumn)
    }
}
