extension Parser {

    // MARK: - Special-form validation

    func validateDef(_ elements: [Expr], line: Int, column: Int) throws {
        guard elements.count >= 2 && elements.count <= 4 else {
            throw ParserError.invalidDef("def requires 1 to 3 arguments", line: line, column: column)
        }

        guard case .symbol = elements[1] else {
            throw ParserError.invalidDef("first argument to def must be a symbol", line: line, column: column)
        }
    }

    func validateThrow(_ elements: [Expr], line: Int, column: Int) throws {
        guard elements.count == 2
        else {
            throw ParserError.invalidThrow("throw requires exactly 1 argument", line: line, column: column)
        }
    }

    func validateBindingVector(_ elements: [Expr], makeError: (String) -> ParserError) throws {
        guard elements.count >= 2 else {
            throw makeError("requires a binding vector")
        }
        guard case .vector(let bindings, _) = elements[1] else {
            throw makeError("first argument must be a vector")
        }
        guard bindings.count % 2 == 0 else {
            throw makeError("binding vector requires an even number of forms")
        }
        for i in stride(from: 0, to: bindings.count, by: 2) {
            switch bindings[i] {
            case .symbol, .vector, .map: break
            default: throw makeError("binding targets must be symbols, vectors, or maps")
            }
        }
    }

    func validateFn(_ elements: [Expr], line: Int, column: Int) throws {
        var offset = 1
        if elements.count > 2, case .symbol = elements[1] {
            offset = 2
        }
        guard offset < elements.count else {
            throw ParserError.invalidFn("fn requires a parameter vector", line: line, column: column)
        }
        switch elements[offset] {
        case .list:
            try validateArityForms(Array(elements.dropFirst(offset)),
                                   makeError: { ParserError.invalidFn("fn \($0)", line: line, column: column) })
        case .vector(let params, _):
            try validateParamVector(params) { ParserError.invalidFn("fn \($0)", line: line, column: column) }
        default:
            throw ParserError.invalidFn("fn requires a parameter vector", line: line, column: column)
        }
    }

    func validateDefmacro(_ elements: [Expr], line: Int, column: Int) throws {
        guard elements.count >= 3, case .symbol = elements[1] else {
            throw ParserError.invalidDefmacro("first argument to defmacro must be a symbol", line: line, column: column)
        }
        var idx = 2
        if idx < elements.count, case .string = elements[idx] { idx += 1 }
        if idx < elements.count, case .map = elements[idx] { idx += 1 }
        guard idx < elements.count else {
            throw ParserError.invalidDefmacro("defmacro requires a parameter vector or arity clauses", line: line, column: column)
        }
        switch elements[idx] {
        case .vector(let params, _):
            try validateParamVector(params) { ParserError.invalidDefmacro("defmacro \($0)", line: line, column: column) }
        case .list:
            try validateArityForms(Array(elements.dropFirst(idx)),
                                   makeError: { ParserError.invalidDefmacro("defmacro \($0)", line: line, column: column) })
        default:
            throw ParserError.invalidDefmacro("second argument to defmacro must be a parameter vector", line: line, column: column)
        }
    }

    func validateArityForms(_ forms: [Expr], makeError: (String) -> ParserError) throws {
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

    func validateParamVector(_ params: [Expr], makeError: (String) -> ParserError) throws {
        for param in params where param != .symbol("&", metadata: nil) {
            switch param {
            case .symbol, .vector, .map: break
            default: throw makeError("parameters must be symbols, vectors, or maps")
            }
        }
        if let ampIdx = params.firstIndex(of: .symbol("&", metadata: nil)) {
            guard ampIdx == params.count - 2 else {
                throw makeError("& must be followed by exactly one binding form")
            }
            switch params[ampIdx + 1] {
            case .symbol, .vector, .map: break
            default: throw makeError("& must be followed by a symbol, vector, or map")
            }
        }
    }
}
