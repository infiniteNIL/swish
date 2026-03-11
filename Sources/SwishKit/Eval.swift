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
        switch expr {
        case .integer, .float, .ratio, .string, .character, .boolean, .nil, .keyword, .function, .nativeFunction:
            return expr

        case .vector(let elements):
            return .vector(try elements.map { try eval($0) })

        case .symbol(let name):
            guard let value = environment.get(name) else {
                throw EvaluatorError.undefinedSymbol(name)
            }
            return value

        case .list(let elements):
            if case .symbol("quote") = elements.first {
                return elements[1]
            }
            if case .symbol("def") = elements.first {
                let name: String
                if case .symbol(let n) = elements[1] {
                    name = n
                } else {
                    // Parser validates this, but be safe
                    throw EvaluatorError.undefinedSymbol("def")
                }
                let value = try eval(elements[2])
                environment.set(name, value)
                return .symbol(name)
            }

            if case .symbol("if") = elements.first {
                guard elements.count >= 3 else {
                    throw EvaluatorError.invalidArgument(function: "if",
                        message: "requires a condition and a then-branch")
                }
                let condition = try eval(elements[1])
                let isFalsy = condition == .nil || condition == .boolean(false)
                if !isFalsy {
                    return try eval(elements[2])
                } else if elements.count > 3 {
                    return try eval(elements[3])
                } else {
                    return .nil
                }
            }

            // Function call: evaluate head, dispatch to native or user-defined function
            if let head = elements.first {
                let callee = try eval(head)
                if case .nativeFunction(let name, let arity, let body) = callee {
                    let args = try elements.dropFirst().map { try eval($0) }
                    if case .fixed(let n) = arity, args.count != n {
                        throw EvaluatorError.arityMismatch(name: name, expected: arity, got: args.count)
                    }
                    if case .atLeastOne = arity, args.isEmpty {
                        throw EvaluatorError.arityMismatch(name: name, expected: arity, got: 0)
                    }
                    return try body(args)
                }
                if case .function = callee {
                    // TODO: implement user-defined function calls when `fn` is added
                    fatalError("user-defined function calls not yet implemented")
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
}
