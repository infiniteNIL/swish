/// Errors thrown during evaluation
public enum EvaluatorError: Error, Equatable, CustomStringConvertible {
    case undefinedSymbol(String)
    case arityMismatch(name: String, expected: Arity, got: Int)
    case invalidArgument(function: String, message: String)

    public var description: String {
        switch self {
        case .undefinedSymbol(let name):
            "Undefined symbol '\(name)'."
        case .arityMismatch(let name, let expected, let got):
            switch expected {
            case .fixed(let n):
                "Wrong number of arguments to '\(name)': expected \(n), got \(got)."
            case .variadic:
                "Wrong number of arguments to '\(name)': got \(got)."
            }
        case .invalidArgument(let function, let message):
            "Invalid argument to '\(function)': \(message)."
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

            // Function call: evaluate head, dispatch if it's a native function
            if let head = elements.first {
                let callee = try eval(head)
                if case .nativeFunction(let name, let arity, let body) = callee {
                    let args = try elements.dropFirst().map { try eval($0) }
                    if case .fixed(let n) = arity, args.count != n {
                        throw EvaluatorError.arityMismatch(name: name, expected: arity, got: args.count)
                    }
                    return try body(args)
                }
            }

            return .list(try elements.map { try eval($0) })
        }
    }

    /// Registers a native Swift function in the core environment.
    public func register(name: String, arity: Arity, body: @escaping ([Expr]) throws -> Expr) {
        coreEnvironment.set(name, .nativeFunction(name: name, arity: arity, body: body))
    }
}
