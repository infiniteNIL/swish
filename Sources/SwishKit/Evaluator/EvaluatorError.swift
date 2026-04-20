/// Errors thrown during evaluation
public enum EvaluatorError: Error, Equatable, CustomStringConvertible {
    case undefinedSymbol(String)
    case arityMismatch(name: String, expected: Arity, got: Int)
    case invalidArgument(function: String, message: String)
    case notAFunction(Expr)
    case unboundVar(String)

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

        case .unboundVar(let fqn):
            return "Var '\(fqn)' is unbound."

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
