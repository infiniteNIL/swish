extension Lexer {
    /// Skips exactly one complete form at the character level, without tokenizing.
    /// Used by the parser to discard non-matching reader conditional branches,
    /// so dialect-specific syntax (e.g. `.get_type`, `#cpp`) causes no errors.
    func skipForm() throws {
        skipWhitespace()
        guard let char = peek() else { return }

        switch char {
        case "\"":
            skipString()

        case "(":
            advance()
            try skipUntilClose(")")

        case "[":
            advance()
            try skipUntilClose("]")

        case "{":
            advance()
            try skipUntilClose("}")

        case "#":
            advance()
            guard let next = peek() else { return }
            switch next {
            case "{":
                advance()
                try skipUntilClose("}")
            case "(":
                advance()
                try skipUntilClose(")")
            case "'", "^", "_", "@":
                advance()
                try skipForm()
            case "?":
                advance()
                if peek() == "@" { advance() }
                try skipForm()
            default:
                // Tagged literal or unknown dispatch (e.g. #cpp, #inst):
                // skip the dispatch tag, then the data form.
                skipAtom()
                try skipForm()
            }

        case "\\":
            // Character literal: \ followed by the char name/sequence.
            advance()
            skipAtom()

        case "'", "`", "@", "^":
            advance()
            try skipForm()

        case "~":
            advance()
            if peek() == "@" { advance() }
            try skipForm()

        default:
            skipAtom()
        }
    }

    func skipUntilClose(_ close: Character) throws {
        skipWhitespace()
        while let c = peek(), c != close {
            try skipForm()
            skipWhitespace()
        }
        if peek() == close { advance() }
    }

    private func skipString() {
        advance()  // consume opening "
        while let c = peek(), c != "\"" {
            if c == "\\" { advance() }  // consume backslash, fall through to consume next char
            advance()
        }
        if peek() == "\"" { advance() }  // consume closing "
    }

    private func skipAtom() {
        while let c = peek() {
            if c.isWhitespace || c == "," { break }
            if "()[]{};\"".contains(c) { break }
            advance()
        }
    }
}
