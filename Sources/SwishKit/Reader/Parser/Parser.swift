import Foundation
import BigInt
import BigDecimal

/// Parser for Swish source code
public class Parser {
    let lexer: Lexer
    var currentToken: Token
    var syntaxQuoteDepth = 0
    var anonymousFnDepth = 0
    var tagResolver: ((String, Expr) throws -> Expr)? = nil

    static let readerFeatures: Set<String> = ["swish", "default"]

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

    func parseExpr() throws -> Expr {
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
        return .double(value)
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

    // MARK: - Discard

    func parseFormSkipDiscards() throws -> Expr? {
        while true {
            if currentToken.type == .discard {
                try advance()
                if currentToken.type == .eof { throw ParserError.unexpectedEOF }
                guard try parseFormSkipDiscards() != nil else { throw ParserError.unexpectedEOF }
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

    func advance() throws {
        currentToken = try lexer.nextToken()
    }
}
