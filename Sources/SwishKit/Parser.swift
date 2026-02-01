/// AST node types for Swish expressions
public enum Expr: Equatable {
    case integer(Int)
    case float(Double)
}

/// Errors thrown during parsing
public enum ParserError: Error, Equatable, CustomStringConvertible {
    case unexpectedToken(Token)
    case unexpectedEOF
    case integerOverflow(String)
    case invalidFloat(String)

    public var description: String {
        switch self {
        case .unexpectedToken(let token):
            return "Unexpected token '\(token.text)' (line \(token.line), column \(token.column))."
        case .unexpectedEOF:
            return "Unexpected end of input."
        case .integerOverflow(let text):
            return "Integer overflow: '\(text)' is too large."
        case .invalidFloat(let text):
            return "Invalid float: '\(text)'."
        }
    }
}

/// Parser for Swish source code
public class Parser {
    private let lexer: Lexer
    private var currentToken: Token

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
        case .eof:
            throw ParserError.unexpectedEOF
        }
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
