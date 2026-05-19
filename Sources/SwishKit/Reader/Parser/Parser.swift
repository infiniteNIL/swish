
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

        case .string:
            return try parseString()

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

        case .metadata:
            return try parseMetadataForm()

        case .discard:
            throw ParserError.unexpectedToken(currentToken)

        case .leftParen:
            return try parseList()

        case .leftBracket:
            return try parseVector()

        case .leftBrace:
            return try parseMap()

        case .leftSet:
            return try parseSet()

        case .rightParen, .rightBracket, .rightBrace:
            throw ParserError.unexpectedToken(currentToken)

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
        else if let v = Int(text) {
            value = v
        }
        else {
            throw ParserError.integerOverflow(text)
        }
        try advance()
        return .integer(value)
    }

    private func parseFloat() throws -> Expr {
        let text = currentToken.text
        guard let value = Double(text) else { throw ParserError.invalidFloat(text) }
        try advance()
        return .float(value)
    }

    private func parseRatio() throws -> Expr {
        let text = currentToken.text
        let parts = text.split(separator: "/", maxSplits: 1)
        guard parts.count == 2,
              let numerator = Int(parts[0]),
              let denominator = Int(parts[1]) else {
            throw ParserError.integerOverflow(text)
        }
        try advance()
        if numerator == 0 {
            return .integer(0)
        }
        let ratio = Ratio(numerator, denominator)
        return ratio.denominator == 1 ? .integer(ratio.numerator) : .ratio(ratio)
    }

    private func parseString() throws -> Expr {
        let value = currentToken.text
        try advance()
        return .string(value)
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
        if currentToken.type == .eof { throw ParserError.unexpectedEOF }
        return .list([.symbol(symbolName, metadata: nil), try parseExpr()], metadata: nil)
    }

    private func parseBacktick() throws -> Expr {
        try advance()
        if currentToken.type == .eof { throw ParserError.unexpectedEOF }
        syntaxQuoteDepth += 1
        let expr = try parseExpr()
        syntaxQuoteDepth -= 1
        return .list([.symbol("syntax-quote", metadata: nil), expr], metadata: nil)
    }

    // MARK: - Metadata reader macro

    private func parseMetadataForm() throws -> Expr {
        let startToken = currentToken
        try advance()  // consume '^'
        if currentToken.type == .eof { throw ParserError.unexpectedEOF }
        let spec = try parseExpr()
        if currentToken.type == .eof { throw ParserError.unexpectedEOF }
        let target = try parseExpr()
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
        func merge(_ existing: [Expr: Expr]?, _ new: [Expr: Expr]) -> [Expr: Expr] {
            var result = existing ?? [:]
            for (k, v) in new { result[k] = v }
            return result
        }

        switch target {
        case .symbol(let n, let m):
            return .symbol(n, metadata: merge(m, new))

        case .list(let e, let m):
            return .list(e, metadata: merge(m, new))

        case .vector(let e, let m):
            return .vector(e, metadata: merge(m, new))

        case .map(let d, let m):
            return .map(d, metadata: merge(m, new))

        case .set(let e, let m):
            return .set(e, metadata: merge(m, new))

        case .function(let n, let p, let b, let m):
            return .function(name: n, params: p, body: b, metadata: merge(m, new))

        case .macro(let n, let p, let b, let m):
            return .macro(name: n, params: p, body: b, metadata: merge(m, new))

        case .multiArityFunction(let n, let a, let m):
            return .multiArityFunction(name: n, arities: a, metadata: merge(m, new))

        case .multiArityMacro(let n, let a, let m):
            return .multiArityMacro(name: n, arities: a, metadata: merge(m, new))

        default:
            throw ParserError.metadataOnUnsupportedForm(line: token.line, column: token.column)
        }
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
            if let expr = try parseFormSkipDiscards() {
                elements.append(expr)
            } else if currentToken.type != .rightParen {
                throw ParserError.unexpectedToken(currentToken)
            }
        }

        try advance() // consume ')'

        // Skip special-form validation inside syntax-quote templates — those lists
        // are data, not code to be immediately evaluated.
        guard syntaxQuoteDepth == 0 else {
            return .list(elements, metadata: nil)
        }

        if case .symbol("def", _) = elements.first {
            try validateDef(elements)
        }
        if case .symbol("let", _) = elements.first {
            try validateLet(elements)
        }
        if case .symbol("fn", _) = elements.first {
            try validateFn(elements)
        }
        if case .symbol("defmacro", _) = elements.first {
            try validateDefmacro(elements)
        }
        if case .symbol("loop", _) = elements.first {
            try validateLoop(elements)
        }

        return .list(elements, metadata: nil)
    }

    private func validateDef(_ elements: [Expr]) throws {
        guard elements.count == 2 || elements.count == 3 else {
            throw ParserError.invalidDef("def requires 1 or 2 arguments")
        }

        guard case .symbol = elements[1] else {
            throw ParserError.invalidDef("first argument to def must be a symbol")
        }
    }

    private func validateLet(_ elements: [Expr]) throws {
        guard elements.count >= 2 else {
            throw ParserError.invalidLet("let requires a binding vector")
        }
        guard case .vector(let bindings, _) = elements[1] else {
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

    private func validateLoop(_ elements: [Expr]) throws {
        guard elements.count >= 2 else {
            throw ParserError.invalidLoop("loop requires a binding vector")
        }
        guard case .vector(let bindings, _) = elements[1] else {
            throw ParserError.invalidLoop("first argument to loop must be a vector")
        }
        guard bindings.count % 2 == 0 else {
            throw ParserError.invalidLoop("loop binding vector requires an even number of forms")
        }
        for i in stride(from: 0, to: bindings.count, by: 2) {
            guard case .symbol = bindings[i] else {
                throw ParserError.invalidLoop("binding targets in loop must be symbols")
            }
        }
    }

    private func validateFn(_ elements: [Expr]) throws {
        var offset = 1
        if elements.count > 2, case .symbol = elements[1] {
            offset = 2
        }
        guard offset < elements.count else {
            throw ParserError.invalidFn("fn requires a parameter vector")
        }
        switch elements[offset] {
        case .list:
            try validateArityForms(Array(elements.dropFirst(offset)),
                                   makeError: { ParserError.invalidFn("fn \($0)") })
        case .vector(let params, _):
            try validateParamVector(params) { ParserError.invalidFn("fn \($0)") }
        default:
            throw ParserError.invalidFn("fn requires a parameter vector")
        }
    }

    private func validateDefmacro(_ elements: [Expr]) throws {
        guard elements.count >= 3, case .symbol = elements[1] else {
            throw ParserError.invalidDefmacro("first argument to defmacro must be a symbol")
        }
        var idx = 2
        if idx < elements.count, case .string = elements[idx] { idx += 1 }
        if idx < elements.count, case .map = elements[idx] { idx += 1 }
        guard idx < elements.count else {
            throw ParserError.invalidDefmacro("defmacro requires a parameter vector or arity clauses")
        }
        switch elements[idx] {
        case .vector(let params, _):
            try validateParamVector(params) { ParserError.invalidDefmacro("defmacro \($0)") }
        case .list:
            try validateArityForms(Array(elements.dropFirst(idx)),
                                   makeError: { ParserError.invalidDefmacro("defmacro \($0)") })
        default:
            throw ParserError.invalidDefmacro("second argument to defmacro must be a parameter vector")
        }
    }

    private func validateArityForms(_ forms: [Expr], makeError: (String) -> ParserError) throws {
        guard !forms.isEmpty else {
            throw makeError("multi-arity form requires at least one arity clause")
        }
        var fixedArities: Set<Int> = []
        var variadicCount = 0
        for form in forms {
            guard case .list(let clause, _) = form else {
                throw makeError("arity clause must be a list")
            }
            guard !clause.isEmpty, case .vector(let params, _) = clause[0] else {
                throw makeError("arity clause must begin with a parameter vector")
            }
            try validateParamVector(params, makeError: makeError)
            let isVariadic = params.contains(.symbol("&", metadata: nil))
            if isVariadic {
                variadicCount += 1
                if variadicCount > 1 { throw makeError("can only have 1 variadic overload") }
            } else {
                let count = params.count
                if fixedArities.contains(count) { throw makeError("can't have 2 overloads with same arity") }
                fixedArities.insert(count)
            }
        }
    }

    private func validateParamVector(_ params: [Expr], makeError: (String) -> ParserError) throws {
        for param in params {
            guard case .symbol = param else {
                throw makeError("parameters must be symbols")
            }
        }
        if let ampIdx = params.firstIndex(of: .symbol("&", metadata: nil)) {
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
            if let expr = try parseFormSkipDiscards() {
                elements.append(expr)
            } else if currentToken.type != .rightBracket {
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
            if let expr = try parseFormSkipDiscards() {
                forms.append(expr)
            } else if currentToken.type != .rightBrace {
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

    private func parseSet() throws -> Expr {
        let startToken = currentToken
        try advance() // consume '#{'

        var forms: [Expr] = []

        while currentToken.type != .rightBrace {
            if currentToken.type == .eof {
                throw ParserError.unterminatedSet(line: startToken.line, column: startToken.column)
            }
            if let expr = try parseFormSkipDiscards() {
                forms.append(expr)
            }
            else if currentToken.type != .rightBrace {
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
        return .set(set, metadata: nil)
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

    // MARK: - Discard

    private func parseFormSkipDiscards() throws -> Expr? {
        while currentToken.type == .discard {
            try advance()
            if currentToken.type == .eof { throw ParserError.unexpectedEOF }
            _ = try parseFormSkipDiscards()
        }
        if currentToken.type == .eof
            || currentToken.type == .rightParen
            || currentToken.type == .rightBracket
            || currentToken.type == .rightBrace { return nil }
        return try parseExpr()
    }

    private func advance() throws {
        currentToken = try lexer.nextToken()
    }
}
