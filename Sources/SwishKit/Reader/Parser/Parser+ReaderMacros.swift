import Foundation
import BigInt
import BigDecimal

extension Parser {

    /// Reads and consumes the string-literal argument of a `#tag "..."` form
    /// (e.g. `#inst`/`#uuid`) — shared prefix before each tag's own parse/validate logic.
    private func readTaggedLiteralStringArg(tag: String, line: Int, col: Int) throws -> String {
        guard currentToken.type == .string else {
            throw ParserError.invalidTaggedLiteral(
                "#\(tag) expects a string literal",
                line: line, column: col)
        }
        let s = currentToken.text
        try advance()
        return s
    }

    func parseTaggedLiteral() throws -> Expr {
        let tag  = currentToken.text
        let line = currentToken.line
        let col  = currentToken.column
        try advance()  // consume the tag token

        while currentToken.type == .discard {
            try advance()        // consume '#_'
            _ = try parseExpr()  // read and discard the following form
        }

        switch tag {
        case "inst":
            let s = try readTaggedLiteralStringArg(tag: tag, line: line, col: col)
            if let resolver = tagResolver {
                return try resolver(tag, .string(s))
            }
            guard let date = Parser.parseInstString(s) else {
                throw ParserError.invalidTaggedLiteral(
                    "invalid #inst date string: \"\(s)\"",
                    line: line, column: col)
            }
            return .inst(date)

        case "uuid":
            let s = try readTaggedLiteralStringArg(tag: tag, line: line, col: col)
            if let resolver = tagResolver {
                return try resolver(tag, .string(s))
            }
            guard let uuid = UUID(uuidString: s) else {
                throw ParserError.invalidTaggedLiteral(
                    "invalid #uuid string: \"\(s)\"",
                    line: line, column: col)
            }
            return .uuid(uuid)

        default:
            let value = try parseExpr()
            if let resolver = tagResolver {
                return try resolver(tag, value)
            }
            throw ParserError.unknownTaggedLiteral(tag: tag, value: value, line: line, column: col)
        }
    }

    /// Parses a Clojure #inst string (RFC 3339 / ISO 8601).
    /// Tries with fractional seconds first, then without.
    static func parseInstString(_ s: String) -> Date? {
        let fmtFrac = ISO8601DateFormatter()
        fmtFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmtFrac.date(from: s) { return validatedInst(s, d) }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        if let d = fmt.date(from: s) { return validatedInst(s, d) }
        // Date-only: "2026-02-03" → midnight UTC
        let fmtDate = ISO8601DateFormatter()
        fmtDate.formatOptions = [.withFullDate]
        if let d = fmtDate.date(from: s) { return validatedInst(s, d) }
        return nil
    }

    private static func validatedInst(_ s: String, _ d: Date) -> Date? {
        let start = s.startIndex

        // Validate the date portion by re-constructing it from the string fields
        // and checking that Calendar accepts it unchanged. This catches invalid
        // dates like 2010-02-29 (non-leap year) regardless of timezone offset.
        if s.count >= 10,
           let year  = Int(s[s.index(start, offsetBy: 0) ..< s.index(start, offsetBy: 4)]),
           let month = Int(s[s.index(start, offsetBy: 5) ..< s.index(start, offsetBy: 7)]),
           let day   = Int(s[s.index(start, offsetBy: 8) ..< s.index(start, offsetBy: 10)]) {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(abbreviation: "UTC")!
            var comps = DateComponents()
            comps.year = year; comps.month = month; comps.day = day
            guard let check = cal.date(from: comps) else { return nil }
            let actual = cal.dateComponents([.year, .month, .day], from: check)
            if actual.year != year || actual.month != month || actual.day != day { return nil }
        }

        // Validate hour — T24:... is not valid (0–23 only); some formatters
        // accept it and roll to midnight of the next day
        if let tIdx = s.firstIndex(of: "T") {
            let h0 = s.index(after: tIdx)
            if let h1 = s.index(h0, offsetBy: 2, limitedBy: s.endIndex),
               let hour = Int(s[h0..<h1]), hour >= 24 { return nil }
        }

        return d
    }

    func parseReaderMacro(_ symbolName: String) throws -> Expr {
        try advance()
        guard let expr = try parseFormSkipDiscards() else { throw ParserError.unexpectedEOF }
        return .list([.symbol(symbolName, metadata: nil), expr], metadata: nil)
    }

    func parseBacktick() throws -> Expr {
        try advance()
        syntaxQuoteDepth += 1
        guard let expr = try parseFormSkipDiscards() else {
            syntaxQuoteDepth -= 1
            throw ParserError.unexpectedEOF
        }
        syntaxQuoteDepth -= 1
        return .list([.symbol("syntax-quote", metadata: nil), expr], metadata: nil)
    }

    // MARK: - Metadata reader macro

    func parseMetadataForm() throws -> Expr {
        let startToken = currentToken
        try advance()  // consume '^'
        guard let spec = try parseFormSkipDiscards() else { throw ParserError.unexpectedEOF }
        guard let target = try parseFormSkipDiscards() else { throw ParserError.unexpectedEOF }
        let metaMap = try specToMetaMap(spec, at: startToken)
        return try applyMetadata(metaMap, to: target, at: startToken)
    }

    private func specToMetaMap(_ spec: Expr, at token: Token) throws -> [Expr: Expr] {
        switch spec {
        case .keyword(let k):
            return [.keyword(k): .boolean(true)]

        case .symbol(let s, _):
            return [.keyword("tag"): .symbol(s, metadata: nil)]

        case .string(let s):
            return [.keyword("tag"): .string(s)]

        case .map(let sm):
            return sm.dict

        default:
            throw ParserError.invalidMetadataSpec(line: token.line, column: token.column)
        }
    }

    private func applyMetadata(_ new: [Expr: Expr], to target: Expr, at token: Token) throws -> Expr {
        guard let result = target.mergingMetadata(new) else {
            throw ParserError.metadataOnUnsupportedForm(line: token.line, column: token.column)
        }
        return result
    }

    // MARK: - Reader Conditionals

    func parseReaderConditionalBody(splicing: Bool, startToken: Token) throws -> [Expr]? {
        guard currentToken.type == .leftParen else {
            throw ParserError.invalidReaderConditional(
                "expected '(' after #?", line: startToken.line, column: startToken.column)
        }
        try advance()  // consume '('

        var matched: [Expr]? = nil

        while currentToken.type != .rightParen {
            if currentToken.type == .eof {
                throw ParserError.unterminatedList(line: startToken.line, column: startToken.column)
            }
            guard currentToken.type == .keyword else {
                throw ParserError.invalidReaderConditional(
                    "reader conditional requires keyword/form pairs",
                    line: currentToken.line, column: currentToken.column)
            }
            let feature = currentToken.text
            try advance()

            if matched == nil && Self.readerFeatures.contains(feature) {
                guard let branchExpr = try parseFormSkipDiscards() else {
                    throw ParserError.invalidReaderConditional(
                        "missing form after feature key :\(feature)",
                        line: startToken.line, column: startToken.column)
                }
                if splicing {
                    switch branchExpr {
                    case .list(let elems, _):
                        matched = elems
                    case .vector(let elems, _):
                        matched = elems
                    default:
                        throw ParserError.invalidReaderConditional(
                            "splicing reader conditional requires a sequential",
                            line: startToken.line, column: startToken.column)
                    }
                } else {
                    matched = [branchExpr]
                }
            } else {
                try skipBranchForm()
            }
        }

        try advance()  // consume ')'
        return matched
    }

    /// Skips the form that `currentToken` has already started consuming,
    /// then calls `advance()` to load the next token.
    /// Used for non-matching reader conditional branches where the first
    /// token is already in `currentToken` but we don't want to parse the form.
    private func skipBranchForm() throws {
        switch currentToken.type {
        case .leftParen, .anonymousFn:
            try lexer.skipUntilClose(")")
        case .leftBracket:
            try lexer.skipUntilClose("]")
        case .leftBrace, .leftSet:
            try lexer.skipUntilClose("}")
        case .quote, .backtick, .unquote, .unquoteSplicing, .deref, .metadata, .varRef, .discard:
            try lexer.skipForm()
        case .readerConditional, .readerConditionalSplicing:
            try lexer.skipForm()
        case .taggedLiteral:
            try lexer.skipForm()  // skip the data form that follows the tag
        default:
            break  // atom (symbol, keyword, number, string, bool, nil, char): already consumed
        }
        try advance()
    }
}
