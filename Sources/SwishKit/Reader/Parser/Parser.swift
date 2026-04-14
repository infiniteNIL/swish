
/// Parser for Swish source code
public class Parser {
    private let lexer: Lexer
    private var currentToken: Token
    private var syntaxQuoteDepth = 0

    public init(_ lexer: Lexer) throws {
        self.lexer = lexer
        self.currentToken = try lexer.nextToken()
    }

    public func parse() throws -> [Expr] {
        var exprs: [Expr] = []
        while currentToken.type != .eof {
            exprs.append(try parseExpr())
        }
        return exprs
    }

    private func parseExpr() throws -> Expr {
        switch currentToken.type {
        case .integer:
            let text = currentToken.text
            let value: Int

            if let binaryValue = parseBinaryInteger(text) {
                value = binaryValue
            }
            else if let hexValue = parseHexInteger(text) {
                value = hexValue
            }
            else if let octalValue = parseOctalInteger(text) {
                value = octalValue
            }
            else if let decValue = Int(text) {
                value = decValue
            }
            else {
                throw ParserError.integerOverflow(text)
            }

            let expr = Expr.integer(value)
            try advance()
            return expr

        case .float:
            let text = currentToken.text
            guard let value = Double(text) else {
                throw ParserError.invalidFloat(text)
            }
            let expr = Expr.float(value)
            try advance()
            return expr

        case .ratio:
            let text = currentToken.text
            let parts = text.split(separator: "/", maxSplits: 1)
            guard parts.count == 2,
                  let numerator = Int(parts[0]),
                  let denominator = Int(parts[1]) else {
                throw ParserError.integerOverflow(text)
            }

            // Zero numerator returns integer 0
            if numerator == 0 {
                try advance()
                return .integer(0)
            }

            let ratio = Ratio(numerator, denominator)

            // If reduced denominator is 1, return integer
            if ratio.denominator == 1 {
                try advance()
                return .integer(ratio.numerator)
            }

            try advance()
            return .ratio(ratio)

        case .string:
            let value = currentToken.text
            try advance()
            return .string(value)

        case .character:
            let char = currentToken.text.first!
            try advance()
            return .character(char)

        case .boolean:
            let value = currentToken.text == "true"
            try advance()
            return .boolean(value)

        case .nil:
            try advance()
            return .nil

        case .symbol:
            let name = currentToken.text
            try advance()
            return .symbol(name)

        case .keyword:
            let name = currentToken.text
            try advance()
            return .keyword(name)

        case .quote:
            try advance() // consume quote token
            if currentToken.type == .eof {
                throw ParserError.unexpectedEOF
            }
            let expr = try parseExpr()
            return .list([.symbol("quote"), expr])

        case .backtick:
            try advance() // consume backtick token
            if currentToken.type == .eof {
                throw ParserError.unexpectedEOF
            }
            syntaxQuoteDepth += 1
            let expr = try parseExpr()
            syntaxQuoteDepth -= 1
            return .list([.symbol("syntax-quote"), expr])

        case .unquote:
            try advance() // consume unquote token
            if currentToken.type == .eof {
                throw ParserError.unexpectedEOF
            }
            let expr = try parseExpr()
            return .list([.symbol("unquote"), expr])

        case .unquoteSplicing:
            try advance() // consume unquote-splicing token
            if currentToken.type == .eof {
                throw ParserError.unexpectedEOF
            }
            let expr = try parseExpr()
            return .list([.symbol("unquote-splicing"), expr])

        case .leftParen:
            return try parseList()

        case .rightParen:
            throw ParserError.unexpectedToken(currentToken)

        case .leftBracket:
            return try parseVector()

        case .rightBracket:
            throw ParserError.unexpectedToken(currentToken)

        case .eof:
            throw ParserError.unexpectedEOF
        }
    }

    private func parseList() throws -> Expr {
        let startToken = currentToken
        try advance() // consume '('

        var elements: [Expr] = []

        while currentToken.type != .rightParen {
            if currentToken.type == .eof {
                throw ParserError.unterminatedList(line: startToken.line, column: startToken.column)
            }
            elements.append(try parseExpr())
        }

        try advance() // consume ')'

        // Skip special-form validation inside syntax-quote templates — those lists
        // are data, not code to be immediately evaluated.
        guard syntaxQuoteDepth == 0 else {
            return .list(elements)
        }

        // Validate def syntax
        if case .symbol("def") = elements.first {
            guard elements.count == 3 else {
                throw ParserError.invalidDef("def requires exactly 2 arguments")
            }
            guard case .symbol = elements[1] else {
                throw ParserError.invalidDef("first argument to def must be a symbol")
            }
        }

        // Validate let syntax
        if case .symbol("let") = elements.first {
            guard elements.count >= 2 else {
                throw ParserError.invalidLet("let requires a binding vector")
            }
            guard case .vector(let bindings) = elements[1] else {
                throw ParserError.invalidLet("first argument to let must be a vector")
            }
            guard bindings.count % 2 == 0 else {
                throw ParserError.invalidLet("let binding vector requires an even number of forms")
            }
            for i in stride(from: 0, to: bindings.count, by: 2) {
                guard case .symbol = bindings[i] else {
                    throw ParserError.invalidLet("binding targets in let must be symbols")
                }
            }
        }

        // Validate fn syntax
        if case .symbol("fn") = elements.first {
            var offset = 1
            if elements.count > 1, case .symbol = elements[1] {
                offset = 2
            }
            guard elements.count > offset, case .vector(let params) = elements[offset] else {
                throw ParserError.invalidFn("fn requires a parameter vector")
            }
            try validateParamVector(params) { ParserError.invalidFn("fn \($0)") }
        }

        // Validate defmacro syntax
        if case .symbol("defmacro") = elements.first {
            guard elements.count >= 4 else {
                throw ParserError.invalidDefmacro(
                    "defmacro requires a name, parameter vector, and at least one body form")
            }
            guard case .symbol = elements[1] else {
                throw ParserError.invalidDefmacro("first argument to defmacro must be a symbol")
            }
            guard case .vector(let params) = elements[2] else {
                throw ParserError.invalidDefmacro("second argument to defmacro must be a parameter vector")
            }
            try validateParamVector(params) { ParserError.invalidDefmacro("defmacro \($0)") }
        }

        return .list(elements)
    }

    private func validateParamVector(_ params: [Expr], makeError: (String) -> ParserError) throws {
        for param in params {
            guard case .symbol = param else {
                throw makeError("parameters must be symbols")
            }
        }
        if let ampIdx = params.firstIndex(of: .symbol("&")) {
            guard ampIdx == params.count - 2 else {
                throw makeError("& must be followed by exactly one symbol")
            }
        }
    }

    private func parseVector() throws -> Expr {
        let startToken = currentToken
        try advance() // consume '['

        var elements: [Expr] = []

        while currentToken.type != .rightBracket {
            if currentToken.type == .eof {
                throw ParserError.unterminatedVector(line: startToken.line, column: startToken.column)
            }
            elements.append(try parseExpr())
        }

        try advance() // consume ']'
        return .vector(elements)
    }

    private func parseHexInteger(_ text: String) -> Int? {
        var str = text
        var negative = false

        if str.hasPrefix("-") {
            negative = true
            str = String(str.dropFirst())
        }
        else if str.hasPrefix("+") {
            str = String(str.dropFirst())
        }

        guard str.hasPrefix("0x") else { return nil }

        let hexPart = String(str.dropFirst(2))
        guard let magnitude = Int(hexPart, radix: 16) else { return nil }

        return negative ? -magnitude : magnitude
    }

    private func parseBinaryInteger(_ text: String) -> Int? {
        var str = text
        var negative = false

        if str.hasPrefix("-") {
            negative = true
            str = String(str.dropFirst())
        }
        else if str.hasPrefix("+") {
            str = String(str.dropFirst())
        }

        guard str.hasPrefix("0b") else { return nil }

        let binaryPart = String(str.dropFirst(2))
        guard let magnitude = Int(binaryPart, radix: 2) else { return nil }

        return negative ? -magnitude : magnitude
    }

    private func parseOctalInteger(_ text: String) -> Int? {
        var str = text
        var negative = false

        if str.hasPrefix("-") {
            negative = true
            str = String(str.dropFirst())
        }
        else if str.hasPrefix("+") {
            str = String(str.dropFirst())
        }

        guard str.hasPrefix("0o") else { return nil }

        let octalPart = String(str.dropFirst(2)) // drop "0o"
        guard let magnitude = Int(octalPart, radix: 8) else { return nil }

        return negative ? -magnitude : magnitude
    }

    private func advance() throws {
        currentToken = try lexer.nextToken()
    }
}
