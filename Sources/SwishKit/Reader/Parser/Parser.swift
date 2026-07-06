import Foundation
import BigInt
import BigDecimal

/// Parser for Swish source code
public class Parser {
    private let lexer: Lexer
    private var currentToken: Token
    private var syntaxQuoteDepth = 0
    private var anonymousFnDepth = 0
    var tagResolver: ((String, Expr) throws -> Expr)? = nil

    private static let readerFeatures: Set<String> = ["swish", "default"]

    public init(_ lexer: Lexer) throws {
        self.lexer = lexer
        self.currentToken = try lexer.nextToken()
    }

    public func parse() throws -> [Expr] {
        var exprs: [Expr] = []
        while currentToken.type != .eof {
            if let expr = try parseFormSkipDiscards() {
                exprs.append(expr)
            } else if currentToken.type != .eof {
                throw ParserError.unexpectedToken(currentToken)
            }
        }
        return exprs
    }

    private func parseExpr() throws -> Expr {
        switch currentToken.type {
        case .integer:
            return try parseInteger()

        case .float:
            return try parseFloat()

        case .ratio:
            return try parseRatio()

        case .bigInteger:
            return try parseBigInteger()

        case .bigDecimal:
            return try parseBigDecimal()

        case .string:
            return try parseString()

        case .regex:
            return try parseRegex()

        case .character:
            return try parseCharacter()

        case .boolean:
            return try parseBoolean()

        case .nil:
            return try parseNil()

        case .symbol:
            return try parseSymbol()

        case .keyword:
            return try parseKeyword()

        case .quote:
            return try parseReaderMacro("quote")

        case .backtick:
            return try parseBacktick()

        case .unquote:
            return try parseReaderMacro("unquote")

        case .unquoteSplicing:
            return try parseReaderMacro("unquote-splicing")

        case .varRef:
            return try parseReaderMacro("var")

        case .deref:
            return try parseReaderMacro("deref")

        case .metadata:
            return try parseMetadataForm()

        case .discard:
            throw ParserError.unexpectedToken(currentToken)

        case .readerConditional:
            let startToken = currentToken
            try advance()
            guard let exprs = try parseReaderConditionalBody(splicing: false, startToken: startToken) else {
                throw ParserError.unexpectedToken(startToken)
            }
            return exprs[0]

        case .readerConditionalSplicing:
            throw ParserError.splicingOutsideCollection(line: currentToken.line, column: currentToken.column)

        case .leftParen:
            return try parseList()

        case .leftBracket:
            return try parseVector()

        case .leftBrace:
            return try parseMap()

        case .leftSet:
            return try parseSet()

        case .anonymousFn:
            return try parseAnonymousFn()

        case .rightParen, .rightBracket, .rightBrace:
            throw ParserError.unexpectedToken(currentToken)

        case .taggedLiteral:
            return try parseTaggedLiteral()

        case .namespacedMapPrefix:
            return try parseNamespacedMap()

        case .eof:
            throw ParserError.unexpectedEOF
        }
    }

    private func parseInteger() throws -> Expr {
        let text = currentToken.text
        let value: Int
        if let v = parseBinaryInteger(text) {
            value = v
        }
        else if let v = parseHexInteger(text) {
            value = v
        }
        else if let v = parseOctalInteger(text) {
            value = v
        }
        else if let v = parseClojureRadixInteger(text) {
            value = v
        }
        else if let v = Int(text) {
            value = v
        }
        else {
            // Overflow: fall back to BigInt
            guard let big = parseClojureRadixBigInteger(text) ?? BigInt(text) else {
                throw ParserError.integerOverflow(text)
            }
            try advance()
            return .bigInteger(big)
        }
        try advance()
        return .integer(value)
    }

    private func parseFloat() throws -> Expr {
        let text = currentToken.text
        let value: Double
        switch text {
        case "##Inf":  value = Double.infinity
        case "##-Inf": value = -Double.infinity
        case "##NaN":  value = Double.nan
        default:
            guard let v = Double(text) else { throw ParserError.invalidFloat(text) }
            value = v
        }
        try advance()
        return .float(value)
    }

    private func parseRatio() throws -> Expr {
        let text = currentToken.text
        let parts = text.split(separator: "/", maxSplits: 1)
        guard parts.count == 2,
              let numerator = BigInt(String(parts[0])),
              let denominator = BigInt(String(parts[1])) else {
            throw ParserError.integerOverflow(text)
        }
        try advance()
        if numerator == 0 {
            return .integer(0)
        }
        let ratio = Ratio(numerator, denominator)
        if ratio.denominator == 1 {
            if let i = Int(exactly: ratio.numerator) { return .integer(i) }
            return .bigInteger(ratio.numerator)
        }
        return .ratio(ratio)
    }

    private func parseBigInteger() throws -> Expr {
        let text = currentToken.text
        let value: BigInt
        if let v = parseClojureRadixBigInteger(text) {
            value = v
        }
        else if let v = BigInt(text) {
            value = v
        }
        else {
            throw ParserError.integerOverflow(text)
        }
        try advance()
        return .bigInteger(value)
    }

    private func parseBigDecimal() throws -> Expr {
        let text = currentToken.text
        guard let value = BigDecimal(text) else { throw ParserError.invalidFloat(text) }
        try advance()
        return .bigDecimal(value)
    }

    private func parseString() throws -> Expr {
        let value = currentToken.text
        try advance()
        return .string(value)
    }

    private func parseRegex() throws -> Expr {
        let pattern = currentToken.text
        try advance()
        return .regex(try SwishRegex(pattern: pattern))
    }

    private func parseTaggedLiteral() throws -> Expr {
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
            guard currentToken.type == .string else {
                throw ParserError.invalidTaggedLiteral(
                    "#inst expects a string literal",
                    line: line, column: col)
            }
            let s = currentToken.text
            try advance()
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
            guard currentToken.type == .string else {
                throw ParserError.invalidTaggedLiteral(
                    "#uuid expects a string literal",
                    line: line, column: col)
            }
            let s = currentToken.text
            try advance()
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
        if let d = fmtFrac.date(from: s) { return d }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        if let d = fmt.date(from: s) { return d }
        // Date-only: "2026-02-03" → midnight UTC
        let fmtDate = ISO8601DateFormatter()
        fmtDate.formatOptions = [.withFullDate]
        return fmtDate.date(from: s)
    }

    private func parseCharacter() throws -> Expr {
        let char = currentToken.text.first!
        try advance()
        return .character(char)
    }

    private func parseBoolean() throws -> Expr {
        let value = currentToken.text == "true"
        try advance()
        return .boolean(value)
    }

    private func parseNil() throws -> Expr {
        try advance()
        return .nil
    }

    private func parseSymbol() throws -> Expr {
        let name = currentToken.text
        try advance()
        return .symbol(name, metadata: nil)
    }

    private func parseKeyword() throws -> Expr {
        let name = currentToken.text
        try advance()
        return .keyword(name)
    }

    private func parseReaderMacro(_ symbolName: String) throws -> Expr {
        try advance()
        guard let expr = try parseFormSkipDiscards() else { throw ParserError.unexpectedEOF }
        return .list([.symbol(symbolName, metadata: nil), expr], metadata: nil)
    }

    private func parseBacktick() throws -> Expr {
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

    private func parseMetadataForm() throws -> Expr {
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

        case .map(let dict, _):
            return dict

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

    // MARK: - Collections

    private func parseList() throws -> Expr {
        let startToken = currentToken
        try advance() // consume '('

        var elements: [Expr] = []

        while currentToken.type != .rightParen {
            if currentToken.type == .eof {
                throw ParserError.unterminatedList(line: startToken.line, column: startToken.column)
            }
            if !(try appendNextElement(to: &elements)) && currentToken.type != .rightParen {
                throw ParserError.unexpectedToken(currentToken)
            }
        }

        try advance() // consume ')'

        // Skip special-form validation inside syntax-quote templates — those lists
        // are data, not code to be immediately evaluated.
        guard syntaxQuoteDepth == 0 else {
            return .list(elements, metadata: nil)
        }

        if case .symbol(let name, _) = elements.first {
            switch name {
            case "def":      try validateDef(elements)
            case "let":      try validateBindingVector(elements, makeError: { ParserError.invalidLet($0) })
            case "fn":       try validateFn(elements)
            case "defmacro": try validateDefmacro(elements)
            case "loop":     try validateBindingVector(elements, makeError: { ParserError.invalidLoop($0) })
            case "throw":    try validateThrow(elements)
            default: break
            }
        }

        return .list(elements, metadata: nil)
    }

    private func parseVector() throws -> Expr {
        let startToken = currentToken
        try advance() // consume '['

        var elements: [Expr] = []

        while currentToken.type != .rightBracket {
            if currentToken.type == .eof {
                throw ParserError.unterminatedVector(line: startToken.line, column: startToken.column)
            }
            if !(try appendNextElement(to: &elements)) && currentToken.type != .rightBracket {
                throw ParserError.unexpectedToken(currentToken)
            }
        }

        try advance() // consume ']'
        return .vector(elements, metadata: nil)
    }

    private func parseMap() throws -> Expr {
        let startToken = currentToken
        try advance() // consume '{'

        var forms: [Expr] = []

        while currentToken.type != .rightBrace {
            if currentToken.type == .eof {
                throw ParserError.unterminatedMap(line: startToken.line, column: startToken.column)
            }
            if !(try appendNextElement(to: &forms)) && currentToken.type != .rightBrace {
                throw ParserError.unexpectedToken(currentToken)
            }
        }

        try advance() // consume '}'

        guard forms.count % 2 == 0 else {
            throw ParserError.oddNumberOfMapForms(line: startToken.line, column: startToken.column)
        }

        var dict: [Expr: Expr] = [:]
        for i in stride(from: 0, to: forms.count, by: 2) {
            dict[forms[i]] = forms[i + 1]
        }
        return .map(dict, metadata: nil)
    }

    private func parseNamespacedMap() throws -> Expr {
        let ns = currentToken.text
        try advance()  // consume namespacedMapPrefix
        guard currentToken.type == .leftBrace else {
            throw ParserError.unexpectedToken(currentToken)
        }
        let mapExpr = try parseMap()
        guard case .map(let dict, let meta) = mapExpr else {
            return mapExpr
        }
        var qualified: [Expr: Expr] = [:]
        for (key, val) in dict {
            qualified[qualifyMapKey(key, ns: ns)] = val
        }
        return .map(qualified, metadata: meta)
    }

    private func qualifyMapKey(_ key: Expr, ns: String) -> Expr {
        switch key {
        case .keyword(let text):
            if text.hasPrefix("_/") {
                return .keyword("\(ns)/\(text.dropFirst(2))")
            }
            if !text.contains("/") {
                return .keyword("\(ns)/\(text)")
            }
            return key
        case .symbol(let text, let meta):
            if text.hasPrefix("_/") {
                return .symbol("\(ns)/\(text.dropFirst(2))", metadata: meta)
            }
            if !text.contains("/") {
                return .symbol("\(ns)/\(text)", metadata: meta)
            }
            return key
        default:
            return key
        }
    }

    private func parseSet() throws -> Expr {
        let startToken = currentToken
        try advance() // consume '#{'

        var forms: [Expr] = []

        while currentToken.type != .rightBrace {
            if currentToken.type == .eof {
                throw ParserError.unterminatedSet(line: startToken.line, column: startToken.column)
            }
            if !(try appendNextElement(to: &forms)) && currentToken.type != .rightBrace {
                throw ParserError.unexpectedToken(currentToken)
            }
        }

        try advance() // consume '}'

        var set: Set<Expr> = []
        for elem in forms {
            let (inserted, _) = set.insert(elem)
            if !inserted {
                let key = Printer().printString(elem)
                throw ParserError.duplicateSetElement(key, line: startToken.line, column: startToken.column)
            }
        }
        return .set(set, _id: CollectionID(), metadata: nil)
    }

    // MARK: - Anonymous function literal

    private func parseAnonymousFn() throws -> Expr {
        let startToken = currentToken
        guard anonymousFnDepth == 0 else {
            throw ParserError.nestedAnonymousFunction(line: startToken.line, column: startToken.column)
        }
        anonymousFnDepth += 1
        defer { anonymousFnDepth -= 1 }

        try advance()  // consume '#('

        var bodyForms: [Expr] = []
        while currentToken.type != .rightParen {
            if currentToken.type == .eof {
                throw ParserError.unterminatedList(line: startToken.line, column: startToken.column)
            }
            if !(try appendNextElement(to: &bodyForms)) && currentToken.type != .rightParen {
                throw ParserError.unexpectedToken(currentToken)
            }
        }
        try advance()  // consume ')'

        let paramVector = buildAnonFnParamVector(from: bodyForms)
        let normalizedBody = normalizeAnonFnArgRefs(bodyForms)
        let bodyExpr: Expr = normalizedBody.isEmpty ? .nil : .list(normalizedBody, metadata: nil)

        return .list([.symbol("fn", metadata: nil), paramVector, bodyExpr], metadata: nil)
    }

    private func buildAnonFnParamVector(from bodyForms: [Expr]) -> Expr {
        var refs = Set<String>()
        collectAnonFnRefs(bodyForms, into: &refs)
        let hasRest = refs.contains("%&")
        var maxIndex = 0
        for ref in refs {
            let name = ref == "%" ? "%1" : ref
            if name.hasPrefix("%"), name != "%&", let n = Int(name.dropFirst()), n > maxIndex {
                maxIndex = n
            }
        }
        var params: [Expr] = []
        if maxIndex >= 1 {
            params = (1...maxIndex).map { .symbol("%\($0)", metadata: nil) }
        }
        if hasRest {
            params.append(.symbol("&", metadata: nil))
            params.append(.symbol("%&", metadata: nil))
        }
        return .vector(params, metadata: nil)
    }

    private func collectAnonFnRefs(_ exprs: [Expr], into refs: inout Set<String>) {
        for expr in exprs { collectAnonFnRefsInExpr(expr, into: &refs) }
    }

    private func collectAnonFnRefsInExpr(_ expr: Expr, into refs: inout Set<String>) {
        switch expr {
        case .symbol(let name, _) where name == "%" || name.hasPrefix("%"):
            refs.insert(name)
        case .list(let elems, _):
            collectAnonFnRefs(elems, into: &refs)
        case .vector(let elems, _):
            collectAnonFnRefs(elems, into: &refs)
        case .map(let dict, _), .sortedMap(let dict, _):
            for (k, v) in dict {
                collectAnonFnRefsInExpr(k, into: &refs)
                collectAnonFnRefsInExpr(v, into: &refs)
            }
        case .set(let elems, _, _):
            collectAnonFnRefs(Array(elems), into: &refs)
        case .sortedSet(let elems, _):
            collectAnonFnRefs(elems, into: &refs)
        default:
            break
        }
    }

    private func normalizeAnonFnArgRefs(_ exprs: [Expr]) -> [Expr] {
        exprs.map { normalizeAnonFnArgRef($0) }
    }

    private func normalizeAnonFnArgRef(_ expr: Expr) -> Expr {
        switch expr {
        case .symbol("%", let meta):
            return .symbol("%1", metadata: meta)

        case .list(let elems, let meta):
            return .list(normalizeAnonFnArgRefs(elems), metadata: meta)

        case .vector(let elems, let meta):
            return .vector(normalizeAnonFnArgRefs(elems), metadata: meta)

        case .map(let dict, let meta):
            var result: [Expr: Expr] = [:]
            for (k, v) in dict { result[normalizeAnonFnArgRef(k)] = normalizeAnonFnArgRef(v) }
            return .map(result, metadata: meta)

        case .sortedMap(let dict, let meta):
            var result: [Expr: Expr] = [:]
            for (k, v) in dict { result[normalizeAnonFnArgRef(k)] = normalizeAnonFnArgRef(v) }
            return .sortedMap(result, metadata: meta)

        case .set(let elems, _, let meta):
            return .set(Set(elems.map { normalizeAnonFnArgRef($0) }), _id: CollectionID(), metadata: meta)

        case .sortedSet(let elems, let meta):
            return .sortedSet(elems.map { normalizeAnonFnArgRef($0) }, metadata: meta)
            
        default:
            return expr
        }
    }

    // MARK: - Discard

    private func parseFormSkipDiscards() throws -> Expr? {
        while true {
            if currentToken.type == .discard {
                try advance()
                if currentToken.type == .eof { throw ParserError.unexpectedEOF }
                _ = try parseFormSkipDiscards()
                continue
            }
            if currentToken.type == .readerConditional {
                let startToken = currentToken
                try advance()
                if let exprs = try parseReaderConditionalBody(splicing: false, startToken: startToken) {
                    return exprs[0]
                }
                continue  // no matching platform — skip and try next form
            }
            break
        }
        if currentToken.type == .eof
            || currentToken.type == .rightParen
            || currentToken.type == .rightBracket
            || currentToken.type == .rightBrace { return nil }
        return try parseExpr()
    }

    // MARK: - Collection element helper

    @discardableResult
    private func appendNextElement(to elements: inout [Expr]) throws -> Bool {
        while true {
            switch currentToken.type {
            case .eof, .rightParen, .rightBracket, .rightBrace:
                return false

            case .discard:
                try advance()
                guard currentToken.type != .eof else { throw ParserError.unexpectedEOF }
                _ = try parseFormSkipDiscards()

            case .readerConditional:
                let startToken = currentToken
                try advance()
                if let exprs = try parseReaderConditionalBody(splicing: false, startToken: startToken) {
                    elements.append(exprs[0])
                    return true
                }
                // non-matching branch — loop to process the next element in the collection

            case .readerConditionalSplicing:
                let condToken = currentToken
                try advance()
                if let spliced = try parseReaderConditionalBody(splicing: true, startToken: condToken) {
                    elements.append(contentsOf: spliced)
                }
                return true

            default:
                elements.append(try parseExpr())
                return true
            }
        }
    }

    // MARK: - Reader Conditionals

    private func parseReaderConditionalBody(splicing: Bool, startToken: Token) throws -> [Expr]? {
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

    private func advance() throws {
        currentToken = try lexer.nextToken()
    }
}
