/// Specifies how many arguments a function accepts
public enum Arity: Equatable, Hashable, Sendable {
    case fixed(Int)    // exactly N arguments
    case atLeastOne    // 1 or more arguments
    case variadic      // zero or more arguments
}

/// A single arity clause for a multi-arity function or macro.
public struct FnArity: Sendable, Equatable, Hashable {
    public let params: [String]
    public let body: [Expr]
}

public final class TransientCollection: @unchecked Sendable {
    public var value: Expr
    public init(_ value: Expr) { self.value = value }
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
    case set(Set<Expr>, metadata: [Expr: Expr]?)
    case function(name: String?, params: [String], body: [Expr], capturedEnv: Environment?, metadata: [Expr: Expr]?)
    case macro(name: String?, params: [String], body: [Expr], metadata: [Expr: Expr]?)
    case multiArityFunction(name: String?, arities: [FnArity], capturedEnv: Environment?, metadata: [Expr: Expr]?)
    case multiArityMacro(name: String?, arities: [FnArity], metadata: [Expr: Expr]?)
    case nativeFunction(name: String, arity: Arity, body: @Sendable ([Expr]) throws -> Expr)
    case varRef(Var)
    case namespace(Namespace)
    case atom(SwishAtom)
    case transient(TransientCollection)
    /// A thunk-backed lazy sequence. Realizes elements on demand.
    case lazySeq(LazySeqBox)

    /// A sentinel wrapping a value to signal early termination of `reduce`.
    case reduced(Expr)
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

        case (.set(let a, _), .set(let b, _)):
            return a == b

        case (.function(let n1, let p1, let b1, _, _), .function(let n2, let p2, let b2, _, _)):
            return n1 == n2 && p1 == p2 && b1 == b2

        case (.macro(let n1, let p1, let b1, _), .macro(let n2, let p2, let b2, _)):
            return n1 == n2 && p1 == p2 && b1 == b2

        case (.multiArityFunction(let n1, let a1, _, _), .multiArityFunction(let n2, let a2, _, _)):
            return n1 == n2 && a1 == a2

        case (.multiArityMacro(let n1, let a1, _), .multiArityMacro(let n2, let a2, _)):
            return n1 == n2 && a1 == a2

        case (.nativeFunction(let n1, let a1, _), .nativeFunction(let n2, let a2, _)):
            return n1 == n2 && a1 == a2

        case (.varRef(let a), .varRef(let b)):
            return a === b

        case (.namespace(let a), .namespace(let b)):
            return a === b

        case (.atom(let a), .atom(let b)):
            return a === b

        case (.transient(let a), .transient(let b)):
            return a === b

        // Lazy seqs with the same identity are trivially equal.
        // Cross-type: a lazy seq and a list (or two different lazy seqs) compare
        // element-by-element up to 1 000 elements for safety on infinite seqs.
        case (.lazySeq(let a), .lazySeq(let b)):
            if a === b { return true }
            return seqEqual(lhs, rhs)

        case (.lazySeq, .list), (.list, .lazySeq):
            return seqEqual(lhs, rhs)

        case (.reduced(let a), .reduced(let b)):
            return a == b

        default:
            return false
        }
    }

    // MARK: - Seq equality helpers

    private static func seqEqual(_ lhs: Expr, _ rhs: Expr) -> Bool {
        var l = lhs
        var r = rhs
        for _ in 0..<1_000 {
            let lh = advanceSeq(&l)
            let rh = advanceSeq(&r)
            switch (lh, rh) {
            case (.some(let le), .some(let re)):
                if le != re { return false }

            case (nil, nil):
                return true

            default:
                return false
            }
        }
        return false  // cap exceeded — conservative: not equal
    }

    /// Advances `expr` one step through a seq, returning the head (or `nil` for empty).
    private static func advanceSeq(_ expr: inout Expr) -> Expr? {
        switch expr {
        case .nil:
            return nil

        case .list(let elems, _):
            if elems.isEmpty { return nil }
            expr = elems.count == 1 ? .nil : .list(Array(elems.dropFirst()), metadata: nil)
            return elems[0]

        case .lazySeq(let box):
            guard let head = try? box.forceHead() else {
                expr = .nil
                return nil
            }
            expr = (try? box.forceTail()) ?? .nil
            return head

        default:
            return nil
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

        case .set(let v, _):
            hasher.combine(12); hasher.combine(v)

        case .function(let n, let p, let b, _, _):
            hasher.combine(13); hasher.combine(n); hasher.combine(p); hasher.combine(b)

        case .macro(let n, let p, let b, _):
            hasher.combine(14); hasher.combine(n); hasher.combine(p); hasher.combine(b)

        case .multiArityFunction(let n, let a, _, _):
            hasher.combine(15); hasher.combine(n); hasher.combine(a)

        case .multiArityMacro(let n, let a, _):
            hasher.combine(16); hasher.combine(n); hasher.combine(a)

        case .nativeFunction(let n, let a, _):
            hasher.combine(17); hasher.combine(n); hasher.combine(a)

        case .varRef(let v):
            hasher.combine(18); hasher.combine(ObjectIdentifier(v))

        case .namespace(let v):
            hasher.combine(19); hasher.combine(ObjectIdentifier(v))

        case .atom(let v):
            hasher.combine(20); hasher.combine(ObjectIdentifier(v))

        case .transient(let v):
            hasher.combine(21); hasher.combine(ObjectIdentifier(v))

        // Identity hash. Lazy seqs can be == to lists via element comparison but
        // the hash contract is maintained within the lazy-seq type (same box → same hash).
        case .lazySeq(let box):
            hasher.combine(22); hasher.combine(ObjectIdentifier(box))

        case .reduced(let v):
            hasher.combine(23); hasher.combine(v)
        }
    }
}
