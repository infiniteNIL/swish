/// Evaluator for Swish expressions
public class Evaluator {
    /// Holds built-in symbols and functions (the core library)
    public let coreEnvironment = Environment()
    /// Holds user-defined bindings; falls through to coreEnvironment on lookup
    public let environment: Environment

    private var gensymCounter = 0

    public init() {
        environment = Environment(parent: coreEnvironment)
        registerCoreFunctions(into: self)
    }

    /// Generates a unique symbol with the given prefix
    func gensym(prefix: String = "G__") -> String {
        gensymCounter += 1
        return "\(prefix)\(gensymCounter)"
    }

    /// Evaluates a Swish expression
    public func eval(_ expr: Expr) throws -> Expr {
        try eval(expr, in: environment)
    }

    private func eval(_ expr: Expr, in env: Environment) throws -> Expr {
        switch expr {
        case .integer, .float, .ratio, .string, .character, .boolean, .nil, .keyword, .function, .macro, .nativeFunction:
            return expr
        case .vector(let elements):
            return .vector(try elements.map { try eval($0, in: env) })
        case .symbol(let name):
            guard let value = env.get(name) else {
                throw EvaluatorError.undefinedSymbol(name)
            }
            return value
        case .list(let elements):
            return try evalList(elements, in: env)
        }
    }

    // MARK: - List dispatch

    private func evalList(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard let head = elements.first else { return .list([]) }
        switch head {
        case .symbol("quote"):        return elements[1]
        case .symbol("syntax-quote"): return try evalSyntaxQuote(elements, in: env)
        case .symbol("def"):          return try evalDef(elements, in: env)
        case .symbol("if"):           return try evalIf(elements, in: env)
        case .symbol("let"):          return try evalLet(elements, in: env)
        case .symbol("fn"):           return try evalFn(elements, in: env)
        case .symbol("defmacro"):     return try evalDefmacro(elements)
        default:
            let callee = try eval(head, in: env)
            return try callFunction(callee, args: elements.dropFirst(), in: env)
        }
    }

    // MARK: - Special forms

    private func evalSyntaxQuote(_ elements: [Expr], in env: Environment) throws -> Expr {
        var gensyms: [String: String] = [:]
        return try syntaxQuoteExpand(elements[1], in: env, gensyms: &gensyms)
    }

    private func evalDef(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard case .symbol(let name) = elements[1] else {
            throw EvaluatorError.undefinedSymbol("def")
        }
        let value = try eval(elements[2], in: env)
        environment.set(name, value)
        return .symbol(name)
    }

    private func evalIf(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard elements.count >= 3 else {
            throw EvaluatorError.invalidArgument(function: "if",
                message: "requires a condition and a then-branch")
        }
        let condition = try eval(elements[1], in: env)
        let isFalsy = condition == .nil || condition == .boolean(false)
        if !isFalsy {
            return try eval(elements[2], in: env)
        } else if elements.count > 3 {
            return try eval(elements[3], in: env)
        } else {
            return .nil
        }
    }

    private func evalLet(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard elements.count >= 2, case .vector(let bindingVec) = elements[1] else {
            throw EvaluatorError.invalidArgument(function: "let",
                message: "first argument must be a vector of bindings")
        }
        let letEnv = Environment(parent: env)
        for i in stride(from: 0, to: bindingVec.count, by: 2) {
            guard case .symbol(let name) = bindingVec[i] else { continue }
            letEnv.set(name, try eval(bindingVec[i + 1], in: letEnv))
        }
        var result: Expr = .nil
        for bodyExpr in elements.dropFirst(2) {
            result = try eval(bodyExpr, in: letEnv)
        }
        return result
    }

    private func evalFn(_ elements: [Expr], in env: Environment) throws -> Expr {
        var offset = 1
        var name: String? = nil
        if elements.count > 1, case .symbol(let n) = elements[1],
           elements.count > 2, case .vector = elements[2] {
            name = n
            offset = 2
        }
        guard elements.count > offset, case .vector(let paramExprs) = elements[offset] else {
            throw EvaluatorError.invalidArgument(function: "fn", message: "requires a parameter vector")
        }
        let params = extractParamNames(paramExprs)
        let body = Array(elements.dropFirst(offset + 1))
        return .function(name: name, params: params, body: body)
    }

    private func evalDefmacro(_ elements: [Expr]) throws -> Expr {
        guard case .symbol(let name) = elements[1],
              case .vector(let paramExprs) = elements[2] else {
            throw EvaluatorError.invalidArgument(function: "defmacro", message: "invalid syntax")
        }
        let params = extractParamNames(paramExprs)
        let body = Array(elements.dropFirst(3))
        environment.set(name, .macro(name: name, params: params, body: body))
        return .symbol(name)
    }

    // MARK: - Function call dispatch

    private func callFunction(_ callee: Expr, args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        switch callee {
        case .macro(let name, let params, let body):
            return try callMacro(name: name, params: params, body: body, args: args, in: env)
        case .nativeFunction(let name, let arity, let body):
            let evaluated = try args.map { try eval($0, in: env) }
            return try callNativeFunction(name: name, arity: arity, body: body, args: evaluated)
        case .function(let name, let params, let body):
            let evaluated = try args.map { try eval($0, in: env) }
            return try callUserFunction(name: name, params: params, body: body, args: evaluated, in: env)
        default:
            throw EvaluatorError.notAFunction(callee)
        }
    }

    private func callMacro(name: String?, params: [String], body: [Expr], args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        let macroEnv = Environment(parent: environment)
        try bindParams(params, to: Array(args), in: macroEnv, name: name ?? "macro")
        var expanded: Expr = .nil
        for bodyExpr in body {
            expanded = try eval(bodyExpr, in: macroEnv)
        }
        return try eval(expanded, in: env)
    }

    private func callNativeFunction(name: String, arity: Arity, body: @Sendable ([Expr]) throws -> Expr, args: [Expr]) throws -> Expr {
        if case .fixed(let n) = arity, args.count != n {
            throw EvaluatorError.arityMismatch(name: name, expected: arity, got: args.count)
        }
        if case .atLeastOne = arity, args.isEmpty {
            throw EvaluatorError.arityMismatch(name: name, expected: arity, got: 0)
        }
        return try body(args)
    }

    private func callUserFunction(name: String?, params: [String], body: [Expr], args: [Expr], in env: Environment) throws -> Expr {
        let fnEnv = Environment(parent: env)
        try bindParams(params, to: args, in: fnEnv, name: name ?? "fn")
        var result: Expr = .nil
        for bodyExpr in body {
            result = try eval(bodyExpr, in: fnEnv)
        }
        return result
    }

    /// Registers a native Swift function in the core environment.
    public func register(name: String, arity: Arity, body: @escaping @Sendable ([Expr]) throws -> Expr) {
        coreEnvironment.set(name, .nativeFunction(name: name, arity: arity, body: body))
    }

    /// Expands a macro call one step. Returns nil if the form is not a macro call.
    func macroexpand1(_ expr: Expr) throws -> Expr? {
        guard case .list(let elements) = expr,
              !elements.isEmpty,
              case .symbol(let name) = elements[0],
              let value = environment.get(name),
              case .macro(_, let params, let body) = value else {
            return nil
        }
        let macroArgs = Array(elements.dropFirst())
        let macroEnv = Environment(parent: environment)
        try bindParams(params, to: macroArgs, in: macroEnv, name: name)
        var result: Expr = .nil
        for bodyExpr in body {
            result = try eval(bodyExpr, in: macroEnv)
        }
        return result
    }

    /// Binds params to args in the given environment, supporting variadic & rest params.
    private func bindParams(_ params: [String], to args: [Expr], in env: Environment, name: String) throws {
        if let ampIdx = params.firstIndex(of: "&") {
            let fixedParams = Array(params[..<ampIdx])
            let restParam = params[ampIdx + 1]
            guard args.count >= fixedParams.count else {
                throw EvaluatorError.arityMismatch(
                    name: name, expected: .fixed(fixedParams.count), got: args.count)
            }
            for (param, arg) in zip(fixedParams, args) {
                env.set(param, arg)
            }
            env.set(restParam, .list(Array(args.dropFirst(fixedParams.count))))
        }
        else {
            guard args.count == params.count else {
                throw EvaluatorError.arityMismatch(
                    name: name, expected: .fixed(params.count), got: args.count)
            }
            for (param, arg) in zip(params, args) {
                env.set(param, arg)
            }
        }
    }

    /// Recursively expands a syntax-quote template, substituting (unquote ...) and
    /// splicing (unquote-splicing ...) sub-forms. Auto-gensyms symbols ending in #.
    private func syntaxQuoteExpand(_ expr: Expr, in env: Environment, gensyms: inout [String: String]) throws -> Expr {
        switch expr {
        case .symbol(let name) where name.hasSuffix("#"):
            let base = String(name.dropLast()) + "__"
            let generated = gensyms[name] ?? gensym(prefix: base)
            gensyms[name] = generated
            return .symbol(generated)

        case .list(let elements):
            if case .symbol("unquote") = elements.first {
                return try eval(elements[1], in: env)
            }
            var result: [Expr] = []
            for element in elements {
                if case .list(let sub) = element,
                   case .symbol("unquote-splicing") = sub.first {
                    let spliced = try eval(sub[1], in: env)
                    guard case .list(let splicedElements) = spliced else {
                        throw EvaluatorError.invalidArgument(
                            function: "unquote-splicing",
                            message: "value must be a list")
                    }
                    result.append(contentsOf: splicedElements)
                }
                else {
                    result.append(try syntaxQuoteExpand(element, in: env, gensyms: &gensyms))
                }
            }
            return .list(result)

        case .vector(let elements):
            return .vector(try elements.map { try syntaxQuoteExpand($0, in: env, gensyms: &gensyms) })

        default:
            return expr
        }
    }

    private func extractParamNames(_ exprs: [Expr]) -> [String] {
        exprs.compactMap { if case .symbol(let s) = $0 { return s } else { return nil } }
    }
}

extension Evaluator: @unchecked Sendable {}
