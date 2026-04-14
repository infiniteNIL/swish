/// Specifies how many arguments a function accepts
public enum Arity: Equatable, Sendable {
    case fixed(Int)    // exactly N arguments
    case atLeastOne    // 1 or more arguments
    case variadic      // zero or more arguments
}

/// AST node types for Swish expressions
public enum Expr: Sendable {
    case integer(Int)
    case float(Double)
    case ratio(Ratio)
    case string(String)
    case character(Character)
    case boolean(Bool)
    case `nil`
    case symbol(String)
    case keyword(String)
    case list([Expr])
    case vector([Expr])
    indirect case function(name: String?, params: [String], body: [Expr])
    indirect case macro(name: String?, params: [String], body: [Expr])
    case nativeFunction(name: String, arity: Arity, body: @Sendable ([Expr]) throws -> Expr)
}

extension Expr: Equatable {
    public static func == (lhs: Expr, rhs: Expr) -> Bool {
        switch (lhs, rhs) {
        case (.integer(let a), .integer(let b)):           return a == b
        case (.float(let a), .float(let b)):               return a == b
        case (.ratio(let a), .ratio(let b)):               return a == b
        case (.string(let a), .string(let b)):             return a == b
        case (.character(let a), .character(let b)):       return a == b
        case (.boolean(let a), .boolean(let b)):           return a == b
        case (.nil, .nil):                                 return true
        case (.symbol(let a), .symbol(let b)):             return a == b
        case (.keyword(let a), .keyword(let b)):           return a == b
        case (.list(let a), .list(let b)):                 return a == b
        case (.vector(let a), .vector(let b)):             return a == b
        case (.function(let n1, let p1, let b1),
              .function(let n2, let p2, let b2)):          return n1 == n2 && p1 == p2 && b1 == b2
        case (.macro(let n1, let p1, let b1),
              .macro(let n2, let p2, let b2)):             return n1 == n2 && p1 == p2 && b1 == b2
        case (.nativeFunction(let n1, let a1, _),
              .nativeFunction(let n2, let a2, _)):         return n1 == n2 && a1 == a2
        default:                                           return false
        }
    }
}
