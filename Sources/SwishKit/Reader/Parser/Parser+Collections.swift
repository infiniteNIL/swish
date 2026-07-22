extension Parser {

    // MARK: - Collections

    /// Parses a `(...)`/`[...]`/`{...}`-shaped element list up to (and consuming)
    /// `close` — shared by every collection-literal parser, which otherwise only
    /// differ in the close token and which `ParserError` case to throw on EOF.
    private func parseDelimited(close: TokenType, unterminated: (Token) -> ParserError) throws -> [Expr] {
        let startToken = currentToken
        try advance() // consume the opening delimiter

        var elements: [Expr] = []

        while currentToken.type != close {
            if currentToken.type == .eof {
                throw unterminated(startToken)
            }
            if !(try appendNextElement(to: &elements)) && currentToken.type != close {
                throw ParserError.unexpectedToken(currentToken)
            }
        }

        try advance() // consume the closing delimiter
        return elements
    }

    func parseList() throws -> Expr {
        let startToken = currentToken
        let elements = try parseDelimited(close: .rightParen) {
            ParserError.unterminatedList(line: $0.line, column: $0.column)
        }

        // Skip special-form validation inside syntax-quote templates — those lists
        // are data, not code to be immediately evaluated.
        guard syntaxQuoteDepth == 0 else {
            return .list(elements, metadata: nil)
        }

        if case .symbol(let name, _) = elements.first {
            switch name {
            case "def":      try validateDef(elements, line: startToken.line, column: startToken.column)
            case "let":      try validateBindingVector(elements, makeError: { ParserError.invalidLet($0, line: startToken.line, column: startToken.column) })
            case "fn":       try validateFn(elements, line: startToken.line, column: startToken.column)
            case "defmacro": try validateDefmacro(elements, line: startToken.line, column: startToken.column)
            case "loop":     try validateBindingVector(elements, makeError: { ParserError.invalidLoop($0, line: startToken.line, column: startToken.column) })
            case "throw":    try validateThrow(elements, line: startToken.line, column: startToken.column)
            default: break
            }
        }

        return .list(elements, metadata: nil)
    }

    func parseVector() throws -> Expr {
        let elements = try parseDelimited(close: .rightBracket) {
            ParserError.unterminatedVector(line: $0.line, column: $0.column)
        }
        return .vector(elements, metadata: nil)
    }

    func parseMap() throws -> Expr {
        let startToken = currentToken
        let forms = try parseDelimited(close: .rightBrace) {
            ParserError.unterminatedMap(line: $0.line, column: $0.column)
        }

        guard forms.count % 2 == 0 else {
            throw ParserError.oddNumberOfMapForms(line: startToken.line, column: startToken.column)
        }

        var dict: [Expr: Expr] = [:]
        for i in stride(from: 0, to: forms.count, by: 2) {
            let key = forms[i]
            if dict[key] != nil {
                throw ParserError.duplicateMapKey(Printer().printString(key),
                    line: startToken.line, column: startToken.column)
            }
            dict[key] = forms[i + 1]
        }
        return .map(dict, metadata: nil)
    }

    func parseNamespacedMap() throws -> Expr {
        let ns = currentToken.text
        try advance()  // consume namespacedMapPrefix
        guard currentToken.type == .leftBrace else {
            throw ParserError.unexpectedToken(currentToken)
        }
        let mapExpr = try parseMap()
        guard case .map(let sm) = mapExpr else {
            return mapExpr
        }
        var qualified: [Expr: Expr] = [:]
        for (key, val) in sm.dict {
            qualified[qualifyMapKey(key, ns: ns)] = val
        }
        return .map(qualified, metadata: sm.metadata)
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

    func parseSet() throws -> Expr {
        let startToken = currentToken
        let forms = try parseDelimited(close: .rightBrace) {
            ParserError.unterminatedSet(line: $0.line, column: $0.column)
        }

        var set: Set<Expr> = []
        for elem in forms {
            let (inserted, _) = set.insert(elem)
            if !inserted {
                let key = Printer().printString(elem)
                throw ParserError.duplicateSetElement(key, line: startToken.line, column: startToken.column)
            }
        }
        return .set(SwishSet(elements: set, metadata: nil))
    }

    // MARK: - Anonymous function literal

    func parseAnonymousFn() throws -> Expr {
        let startToken = currentToken
        guard anonymousFnDepth == 0 else {
            throw ParserError.nestedAnonymousFunction(line: startToken.line, column: startToken.column)
        }
        anonymousFnDepth += 1
        defer { anonymousFnDepth -= 1 }

        let bodyForms = try parseDelimited(close: .rightParen) {
            ParserError.unterminatedList(line: $0.line, column: $0.column)
        }

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
        case .map(let sm):
            for (k, v) in sm.dict {
                collectAnonFnRefsInExpr(k, into: &refs)
                collectAnonFnRefsInExpr(v, into: &refs)
            }
        case .sortedMap(let dict, _):
            for (k, v) in dict {
                collectAnonFnRefsInExpr(k, into: &refs)
                collectAnonFnRefsInExpr(v, into: &refs)
            }
        case .set(let ss):
            collectAnonFnRefs(Array(ss.elements), into: &refs)
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

        case .map(let sm):
            var result: [Expr: Expr] = [:]
            for (k, v) in sm.dict { result[normalizeAnonFnArgRef(k)] = normalizeAnonFnArgRef(v) }
            return .map(result, metadata: sm.metadata)

        case .sortedMap(let dict, let meta):
            var result: [Expr: Expr] = [:]
            for (k, v) in dict { result[normalizeAnonFnArgRef(k)] = normalizeAnonFnArgRef(v) }
            return .sortedMap(result, metadata: meta)

        case .set(let ss):
            return .set(SwishSet(elements: Set(ss.elements.map { normalizeAnonFnArgRef($0) }), metadata: ss.metadata))

        case .sortedSet(let elems, let meta):
            return .sortedSet(elems.map { normalizeAnonFnArgRef($0) }, metadata: meta)

        default:
            return expr
        }
    }

    // MARK: - Collection element helper

    @discardableResult
    func appendNextElement(to elements: inout [Expr]) throws -> Bool {
        while true {
            switch currentToken.type {
            case .eof, .rightParen, .rightBracket, .rightBrace:
                return false

            case .discard:
                try advance()
                guard currentToken.type != .eof else { throw ParserError.unexpectedEOF }
                guard try parseFormSkipDiscards() != nil else { throw ParserError.unexpectedEOF }

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
}
