/// Errors thrown during evaluation
public enum EvaluatorError: Error, Equatable, CustomStringConvertible {
    case undefinedSymbol(String)
    case arityMismatch(name: String, expected: Arity, got: Int)
    case invalidArgument(function: String, message: String)
    case notAFunction(Expr)

    public var description: String {
        switch self {
        case .undefinedSymbol(let name):
            return "Undefined symbol '\(name)'."
        case .arityMismatch(let name, let expected, let got):
            switch expected {
            case .fixed(let n):
                return "Wrong number of arguments to '\(name)': expected \(n), got \(got)."
            case .atLeastOne:
                return "Wrong number of arguments to '\(name)': expected at least 1, got \(got)."
            case .variadic:
                return "Wrong number of arguments to '\(name)': got \(got)."
            }
        case .invalidArgument(let function, let message):
            return "Invalid argument to '\(function)': \(message)."
        case .notAFunction(let expr):
            let rep: String
            switch expr {
            case .integer(let n):  rep = String(n)
            case .float(let n):    rep = String(n)
            case .ratio(let r):    rep = "\(r.numerator)/\(r.denominator)"
            case .boolean(let b):  rep = b ? "true" : "false"
            case .nil:             rep = "nil"
            case .string(let s):   rep = "\"\(s)\""
            case .keyword(let k):  rep = ":\(k)"
            case .vector:          rep = "a vector"
            case .list:            rep = "a list"
            default:               rep = "a value"
            }
            return "'\(rep)' is not a function."
        }
    }
}

/// Stores variable bindings for the evaluator
public class Environment {
    private var bindings: [String: Expr] = [:]
    private let parent: Environment?

    public init(parent: Environment? = nil) {
        self.parent = parent
    }

    public func get(_ name: String) -> Expr? {
        bindings[name] ?? parent?.get(name)
    }

    public func set(_ name: String, _ value: Expr) {
        bindings[name] = value
    }
}

/// Evaluator for Swish expressions
public class Evaluator {
    /// Holds built-in symbols and functions (the core library)
    public let coreEnvironment = Environment()
    /// Holds user-defined bindings; falls through to coreEnvironment on lookup
    public let environment: Environment

    public init() {
        environment = Environment(parent: coreEnvironment)
        registerCoreFunctions(into: self)
    }

    /// Evaluates a Swish expression
    public func eval(_ expr: Expr) throws -> Expr {
        try eval(expr, in: environment)
    }

    private func eval(_ expr: Expr, in env: Environment) throws -> Expr {
        switch expr {
        case .integer, .float, .ratio, .string, .character, .boolean, .nil, .keyword, .function, .nativeFunction:
            return expr

        case .vector(let elements):
            return .vector(try elements.map { try eval($0, in: env) })

        case .symbol(let name):
            guard let value = env.get(name) else {
                throw EvaluatorError.undefinedSymbol(name)
            }
            return value

        case .list(let elements):
            if case .symbol("quote") = elements.first {
                return elements[1]
            }
            if case .symbol("syntax-quote") = elements.first {
                return try syntaxQuoteExpand(elements[1], in: env)
            }
            if case .symbol("def") = elements.first {
                let name: String
                if case .symbol(let n) = elements[1] {
                    name = n
                } else {
                    // Parser validates this, but be safe
                    throw EvaluatorError.undefinedSymbol("def")
                }
                let value = try eval(elements[2], in: env)
                environment.set(name, value)
                return .symbol(name)
            }

            if case .symbol("if") = elements.first {
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

            if case .symbol("let") = elements.first {
                guard elements.count >= 2, case .vector(let bindingVec) = elements[1] else {
                    throw EvaluatorError.invalidArgument(function: "let",
                        message: "first argument must be a vector of bindings")
                }
                let letEnv = Environment(parent: env)
                for i in stride(from: 0, to: bindingVec.count, by: 2) {
                    guard case .symbol(let name) = bindingVec[i] else { continue }
                    letEnv.set(name, try eval(bindingVec[i + 1], in: letEnv))
                }
                let body = elements.dropFirst(2)
                var result: Expr = .nil
                for bodyExpr in body {
                    result = try eval(bodyExpr, in: letEnv)
                }
                return result
            }

            if case .symbol("fn") = elements.first {
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
                let params = paramExprs.compactMap { if case .symbol(let s) = $0 { return s } else { return nil } }
                let body = Array(elements.dropFirst(offset + 1))
                try checkUndefinedSymbols(in: body, localBindings: Set(params), env: env)
                return .function(name: name, params: params, body: body)
            }

            // Function call: evaluate head, dispatch to native or user-defined function
            if let head = elements.first {
                let callee = try eval(head, in: env)
                if case .nativeFunction(let name, let arity, let body) = callee {
                    let args = try elements.dropFirst().map { try eval($0, in: env) }
                    if case .fixed(let n) = arity, args.count != n {
                        throw EvaluatorError.arityMismatch(name: name, expected: arity, got: args.count)
                    }
                    if case .atLeastOne = arity, args.isEmpty {
                        throw EvaluatorError.arityMismatch(name: name, expected: arity, got: 0)
                    }
                    return try body(args)
                }
                if case .function(let name, let params, let body) = callee {
                    let args = try elements.dropFirst().map { try eval($0, in: env) }
                    guard args.count == params.count else {
                        throw EvaluatorError.arityMismatch(name: name ?? "fn", expected: .fixed(params.count), got: args.count)
                    }
                    let fnEnv = Environment(parent: env)
                    for (param, arg) in zip(params, args) {
                        fnEnv.set(param, arg)
                    }
                    var result: Expr = .nil
                    for bodyExpr in body {
                        result = try eval(bodyExpr, in: fnEnv)
                    }
                    return result
                }
                throw EvaluatorError.notAFunction(callee)
            }

            return .list([])  // empty list () evaluates to itself
        }
    }

    /// Registers a native Swift function in the core environment.
    public func register(name: String, arity: Arity, body: @escaping @Sendable ([Expr]) throws -> Expr) {
        coreEnvironment.set(name, .nativeFunction(name: name, arity: arity, body: body))
    }

    /// Recursively expands a syntax-quote template, substituting (unquote ...) and
    /// splicing (unquote-splicing ...) sub-forms.
    private func syntaxQuoteExpand(_ expr: Expr, in env: Environment) throws -> Expr {
        guard case .list(let elements) = expr else {
            return expr // atoms are returned as-is
        }

        // (unquote x) → evaluate x
        if case .symbol("unquote") = elements.first {
            return try eval(elements[1], in: env)
        }

        // General list: process each element, splicing unquote-splicing sub-forms
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
            } else {
                result.append(try syntaxQuoteExpand(element, in: env))
            }
        }
        return .list(result)
    }

    /// Recursively checks that every symbol referenced in `exprs` is either in
    /// `localBindings` or resolvable in `env`. Understands special forms so that
    /// binding targets (fn params, let names, def name) are not treated as lookups.
    private func checkUndefinedSymbols(in exprs: [Expr], localBindings: Set<String>, env: Environment) throws {
        for expr in exprs {
            try checkUndefinedSymbols(in: expr, localBindings: localBindings, env: env)
        }
    }

    private func checkUndefinedSymbols(in expr: Expr, localBindings: Set<String>, env: Environment) throws {
        switch expr {
        case .symbol(let name):
            guard localBindings.contains(name) || env.get(name) != nil else {
                throw EvaluatorError.undefinedSymbol(name)
            }

        case .list(let elements) where !elements.isEmpty:
            switch elements[0] {
            case .symbol("quote"):
                return

            case .symbol("syntax-quote"):
                if elements.count > 1 {
                    try checkSyntaxQuoteSymbols(in: elements[1], localBindings: localBindings, env: env)
                }

            case .symbol("unquote"), .symbol("unquote-splicing"):
                if elements.count > 1 {
                    try checkUndefinedSymbols(in: elements[1], localBindings: localBindings, env: env)
                }

            case .symbol("fn"):
                var offset = 1
                if elements.count > 1, case .symbol = elements[1],
                   elements.count > 2, case .vector = elements[2] {
                    offset = 2
                }
                if elements.count > offset, case .vector(let paramExprs) = elements[offset] {
                    let innerParams = Set(paramExprs.compactMap { if case .symbol(let s) = $0 { return s } else { return nil } })
                    try checkUndefinedSymbols(in: Array(elements.dropFirst(offset + 1)),
                                              localBindings: localBindings.union(innerParams), env: env)
                }

            case .symbol("let"):
                if elements.count > 1, case .vector(let bindingVec) = elements[1] {
                    var letBindings = localBindings
                    var i = 0
                    while i + 1 < bindingVec.count {
                        try checkUndefinedSymbols(in: bindingVec[i + 1], localBindings: letBindings, env: env)
                        if case .symbol(let s) = bindingVec[i] { letBindings.insert(s) }
                        i += 2
                    }
                    try checkUndefinedSymbols(in: Array(elements.dropFirst(2)), localBindings: letBindings, env: env)
                }

            case .symbol("def"):
                // elements[1] is the binding target (not a lookup); check the value expression
                if elements.count > 2 {
                    try checkUndefinedSymbols(in: elements[2], localBindings: localBindings, env: env)
                }

            case .symbol("if"):
                for element in elements.dropFirst() {
                    try checkUndefinedSymbols(in: element, localBindings: localBindings, env: env)
                }

            default:
                for element in elements {
                    try checkUndefinedSymbols(in: element, localBindings: localBindings, env: env)
                }
            }

        case .vector(let elements):
            for element in elements {
                try checkUndefinedSymbols(in: element, localBindings: localBindings, env: env)
            }

        default:
            break
        }
    }

    /// Walks a syntax-quote template and checks symbols only inside (unquote ...)
    /// and (unquote-splicing ...) sub-forms, since only those get evaluated.
    private func checkSyntaxQuoteSymbols(
        in expr: Expr, localBindings: Set<String>, env: Environment
    ) throws {
        guard case .list(let elements) = expr else { return }

        if case .symbol("unquote") = elements.first {
            if elements.count > 1 {
                try checkUndefinedSymbols(in: elements[1], localBindings: localBindings, env: env)
            }
            return
        }

        for element in elements {
            if case .list(let sub) = element, case .symbol("unquote-splicing") = sub.first {
                if sub.count > 1 {
                    try checkUndefinedSymbols(in: sub[1], localBindings: localBindings, env: env)
                }
            } else {
                try checkSyntaxQuoteSymbols(in: element, localBindings: localBindings, env: env)
            }
        }
    }
}
