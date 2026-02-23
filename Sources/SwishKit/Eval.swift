/// Errors thrown during evaluation
public enum EvaluatorError: Error, Equatable, CustomStringConvertible {
    case undefinedSymbol(String)

    public var description: String {
        switch self {
        case .undefinedSymbol(let name):
            "Undefined symbol '\(name)'."
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
    }

    /// Evaluates a Swish expression
    public func eval(_ expr: Expr) throws -> Expr {
        switch expr {
        case .integer, .float, .ratio, .string, .character, .boolean, .nil, .keyword:
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
            return .list(try elements.map { try eval($0) })
        }
    }
}
