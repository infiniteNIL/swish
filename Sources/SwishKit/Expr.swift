/// Specifies how many arguments a function accepts
public enum Arity: Equatable, Hashable, Sendable {
    case fixed(Int)    // exactly N arguments
    case atLeastOne    // 1 or more arguments
    case variadic      // zero or more arguments
}

/// AST node types for Swish expressions
public indirect enum Expr: Sendable {
    case integer(Int)
    case float(Double)
    case ratio(Ratio)
    case string(String)
    case character(Character)
    case boolean(Bool)
    case `nil`
    case symbol(String, metadata: [Expr: Expr]?)
    case keyword(String)
    case list([Expr], metadata: [Expr: Expr]?)
    case vector([Expr], metadata: [Expr: Expr]?)
    case map([Expr: Expr], metadata: [Expr: Expr]?)
    case function(name: String?, params: [String], body: [Expr], metadata: [Expr: Expr]?)
    case macro(name: String?, params: [String], body: [Expr], metadata: [Expr: Expr]?)
    case nativeFunction(name: String, arity: Arity, body: @Sendable ([Expr]) throws -> Expr)
    case varRef(Var)
    case namespace(Namespace)
}

extension Expr: Equatable {
    public static func == (lhs: Expr, rhs: Expr) -> Bool {
        switch (lhs, rhs) {
        case (.integer(let a), .integer(let b)):
            return a == b

        case (.float(let a), .float(let b)):
            return a == b

        case (.ratio(let a), .ratio(let b)):
            return a == b

        case (.string(let a), .string(let b)):
            return a == b

        case (.character(let a), .character(let b)):
            return a == b

        case (.boolean(let a), .boolean(let b)):
            return a == b

        case (.nil, .nil):
            return true

        case (.symbol(let a, _), .symbol(let b, _)):
            return a == b

        case (.keyword(let a), .keyword(let b)):
            return a == b

        case (.list(let a, _), .list(let b, _)):
            return a == b

        case (.vector(let a, _), .vector(let b, _)):
            return a == b

        case (.map(let a, _), .map(let b, _)):
            return a == b

        case (.function(let n1, let p1, let b1, _), .function(let n2, let p2, let b2, _)):
            return n1 == n2 && p1 == p2 && b1 == b2

        case (.macro(let n1, let p1, let b1, _), .macro(let n2, let p2, let b2, _)):
            return n1 == n2 && p1 == p2 && b1 == b2

        case (.nativeFunction(let n1, let a1, _), .nativeFunction(let n2, let a2, _)):
            return n1 == n2 && a1 == a2

        case (.varRef(let a), .varRef(let b)):
            return a === b

        case (.namespace(let a), .namespace(let b)):
            return a === b

        default:
            return false
        }
    }
}

extension Expr: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .integer(let v):
            hasher.combine(0);  hasher.combine(v)

        case .float(let v):
            hasher.combine(1);  hasher.combine(v)

        case .ratio(let v):
            hasher.combine(2);  hasher.combine(v)

        case .string(let v):
            hasher.combine(3);  hasher.combine(v)

        case .character(let v):
            hasher.combine(4);  hasher.combine(v)

        case .boolean(let v):
            hasher.combine(5);  hasher.combine(v)

        case .nil:
            hasher.combine(6)

        case .symbol(let v, _):
            hasher.combine(7);  hasher.combine(v)

        case .keyword(let v):
            hasher.combine(8);  hasher.combine(v)

        case .list(let v, _):
            hasher.combine(9);  hasher.combine(v)

        case .vector(let v, _):
            hasher.combine(10); hasher.combine(v)

        case .map(let v, _):
            hasher.combine(11); hasher.combine(v)

        case .function(let n, let p, let b, _):
            hasher.combine(12); hasher.combine(n); hasher.combine(p); hasher.combine(b)

        case .macro(let n, let p, let b, _):
            hasher.combine(13); hasher.combine(n); hasher.combine(p); hasher.combine(b)

        case .nativeFunction(let n, let a, _):
            hasher.combine(14); hasher.combine(n); hasher.combine(a)

        case .varRef(let v):
            hasher.combine(15); hasher.combine(ObjectIdentifier(v))

        case .namespace(let v):
            hasher.combine(16); hasher.combine(ObjectIdentifier(v))
        }
    }
}
