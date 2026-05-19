/// Errors thrown during evaluation
public enum EvaluatorError: Error, Equatable, CustomStringConvertible {
    case undefinedSymbol(String)
    case arityMismatch(name: String, expected: Arity, got: Int)
    case invalidArgument(function: String, message: String)
    case notAFunction(Expr)
    case unboundVar(String)
    case cannotRedefineSystemVar(String)
    case namespaceNotFound(String)
    case integerOverflow(operation: String, lhs: Int, rhs: Int)
    case stackOverflow(maxDepth: Int)
    case interrupted
    case duplicateSetElement(String)
    case noMatchingArity(name: String, got: Int)
    case recurOutsideLoop
    case recurNotInTailPosition

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

        case .cannotRedefineSystemVar(let name):
            return "Cannot redefine system var '\(name)'."

        case .namespaceNotFound(let name):
            return "No namespace named '\(name)' found."

        case .integerOverflow(let op, let lhs, let rhs):
            return "Integer overflow in '\(op)': \(lhs) \(op) \(rhs)."

        case .stackOverflow(let max):
            return "Stack overflow: maximum call depth of \(max) exceeded."

        case .interrupted:
            return "Evaluation interrupted."

        case .duplicateSetElement(let key):
            return "Duplicate key: \(key)."

        case .noMatchingArity(let name, let got):
            return "Wrong number of args (\(got)) passed to: \(name)"

        case .recurOutsideLoop:
            return "recur used outside of loop or fn"

        case .recurNotInTailPosition:
            return "Can only recur from tail position"

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
            case .set:             rep = "a set"
            case .function(let name, _, _, _), .macro(let name, _, _, _):
                rep = name.map { "#<fn \($0)>" } ?? "#<fn>"
            case .multiArityFunction(let name, _, _), .multiArityMacro(let name, _, _):
                rep = name.map { "#<fn \($0)>" } ?? "#<fn>"
            case .nativeFunction(let name, _, _):
                rep = "#<native-fn \(name)>"
            default:               rep = "a value"
            }
            return "'\(rep)' is not a function."
        }
    }
}
