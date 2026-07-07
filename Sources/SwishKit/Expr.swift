import Foundation
import BigInt
import BigDecimal

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
    public var isInvalidated: Bool = false
    public init(_ value: Expr) { self.value = value }
}


/// AST node types for Swish expressions
public indirect enum Expr: Sendable {
    case integer(Int)
    case float(Float)
    case double(Double)
    case ratio(Ratio)
    case bigInteger(BigInt)
    case bigDecimal(BigDecimal)
    case string(String)
    case character(Character)
    case boolean(Bool)
    case `nil`
    case symbol(String, metadata: [Expr: Expr]?)
    case keyword(String)
    case list([Expr], metadata: [Expr: Expr]?)
    /// An eager, non-list seq — returned by `seq` on non-list collections (vector, map, set, etc.).
    /// Satisfies `seq?` but not `list?` or `lazy-seq?`, matching Clojure's ISeq-not-IPersistentList.
    case seq([Expr])
    case vector([Expr], metadata: [Expr: Expr]?)
    /// A key-value pair from map iteration. Semantically equivalent to a 2-element vector.
    case mapEntry(Expr, Expr)
    case map(SwishMap)
    case set(SwishSet)
    case sortedSet([Expr], metadata: [Expr: Expr]?)
    case sortedMap([Expr: Expr], metadata: [Expr: Expr]?)
    case function(SwishFunction)
    case macro(name: String?, params: [String], body: [Expr], metadata: [Expr: Expr]?)
    case multiArityFunction(SwishMultiArityFunction)
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

    /// A memoized thunk created by `delay`. Forces on first `deref`/`force`.
    case delay(DelayBox)

    /// A compiled regular expression literal (`#"pattern"`).
    case regex(SwishRegex)

    /// A buffered file reader, usable with `line-seq` and `with-open`.
    case reader(SwishReader)

    /// A buffered file writer, usable with `swish-write!` and `with-open`.
    case writer(SwishWriter)

    /// A date value from a `#inst` tagged literal.
    case inst(Date)

    /// A UUID value from a `#uuid` tagged literal.
    case uuid(UUID)

    /// A map-backed record created by `defrecord`.
    /// `typeName` is namespace-qualified (e.g. `"user/Point"`).
    /// `fields` lists the declared field names in order.
    /// `data` holds the current key→value pairs (always includes all declared fields).
    case record(typeName: String, fields: [String], data: [Expr: Expr], metadata: [Expr: Expr]?)
}

extension Expr: Equatable {
    public static func == (lhs: Expr, rhs: Expr) -> Bool {
        switch (lhs, rhs) {
        case (.integer(let a), .integer(let b)):
            return a == b

        case (.double(let a), .double(let b)):
            return a == b

        case (.float(let a), .float(let b)):
            return a == b

        case (.float(let a), .double(let b)):
            return Double(a) == b

        case (.double(let a), .float(let b)):
            return a == Double(b)

        case (.ratio(let a), .ratio(let b)):
            return a == b

        case (.bigInteger(let a), .bigInteger(let b)):
            return a == b

        case (.integer(let a), .bigInteger(let b)):
            return BigInt(a) == b

        case (.bigInteger(let a), .integer(let b)):
            return a == BigInt(b)

        case (.bigDecimal(let a), .bigDecimal(let b)):
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

        case (.seq(let a), .seq(let b)):
            return a == b

        case (.vector(let a, _), .vector(let b, _)):
            return a == b

        case (.mapEntry(let k1, let v1), .mapEntry(let k2, let v2)):
            return k1 == k2 && v1 == v2

        case (.mapEntry(let k, let v), .vector(let elems, _)):
            return elems.count == 2 && k == elems[0] && v == elems[1]

        case (.vector(let elems, _), .mapEntry(let k, let v)):
            return elems.count == 2 && elems[0] == k && elems[1] == v

        case (.map(let a), .map(let b)):
            return a == b

        case (.set(let a), .set(let b)):
            return a == b

        case (.sortedSet(let a, _), .sortedSet(let b, _)):
            return Set(a) == Set(b)

        case (.sortedSet(let a, _), .set(let b)):
            return Set(a) == b.elements

        case (.set(let a), .sortedSet(let b, _)):
            return a.elements == Set(b)

        case (.sortedMap(let a, _), .sortedMap(let b, _)):
            return a == b

        case (.sortedMap(let a, _), .map(let b)):
            return a == b.dict

        case (.map(let a), .sortedMap(let b, _)):
            return a.dict == b

        case (.function(let a), .function(let b)):
            return a === b

        case (.macro(let n1, let p1, let b1, _), .macro(let n2, let p2, let b2, _)):
            return n1 == n2 && p1 == p2 && b1 == b2

        case (.multiArityFunction(let a), .multiArityFunction(let b)):
            return a === b

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

        case (.vector, .lazySeq), (.lazySeq, .vector):
            return seqEqual(lhs, rhs)

        case (.vector, .list), (.list, .vector):
            return seqEqual(lhs, rhs)

        case (.seq, .list), (.list, .seq):
            return seqEqual(lhs, rhs)

        case (.seq, .vector), (.vector, .seq):
            return seqEqual(lhs, rhs)

        case (.seq, .lazySeq), (.lazySeq, .seq):
            return seqEqual(lhs, rhs)

        case (.reduced(let a), .reduced(let b)):
            return a == b

        case (.delay(let a), .delay(let b)):
            return a === b

        case (.regex(let a), .regex(let b)):
            return a == b

        case (.reader(let a), .reader(let b)):
            return a === b

        case (.writer(let a), .writer(let b)):
            return a === b

        case (.inst(let a), .inst(let b)):
            return a == b

        case (.uuid(let a), .uuid(let b)):
            return a == b

        case (.record(let t1, _, let d1, _), .record(let t2, _, let d2, _)):
            return t1 == t2 && d1 == d2

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

        case .seq(let elems):
            if elems.isEmpty { return nil }
            expr = elems.count == 1 ? .nil : .seq(Array(elems.dropFirst()))
            return elems[0]

        case .vector(let elems, _):
            if elems.isEmpty { return nil }
            expr = elems.count == 1 ? .nil : .vector(Array(elems.dropFirst()), metadata: nil)
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

// MARK: - Convenience constructors

extension Expr {
    public static func set(_ elements: Set<Expr>, metadata: [Expr: Expr]?) -> Expr {
        .set(SwishSet(elements: elements, metadata: metadata))
    }

    public static func map(_ dict: [Expr: Expr], metadata: [Expr: Expr]?) -> Expr {
        .map(SwishMap(dict: dict, metadata: metadata))
    }
}

// MARK: - Hash discriminants

/// Named type discriminants for Expr.hash(into:).
/// Sorted/unsorted variants that are value-equal share the same discriminant
/// so their hashes are compatible (required by Swift's Hashable contract).
private enum ExprHash {
    static let integer            = 0
    static let float              = 1
    static let ratio              = 2
    static let string             = 3
    static let character          = 4
    static let boolean            = 5
    static let `nil`              = 6
    static let symbol             = 7
    static let keyword            = 8
    static let list               = 9  // .seq shares this discriminant for cross-type equality
    static let vector             = 10  // mapEntry shares this for cross-type equality
    static let map                = 11  // sortedMap shares this for cross-type equality
    static let set                = 12  // sortedSet shares this for cross-type equality
    static let function           = 13
    static let macro              = 14
    static let multiArityFunction = 15
    static let multiArityMacro    = 16
    static let nativeFunction     = 17
    static let varRef             = 18
    static let namespace          = 19
    static let atom               = 20
    static let transient          = 21
    static let lazySeq            = 22
    static let reduced            = 23
    static let regex              = 24
    static let reader             = 25
    static let writer             = 26
    static let bigInteger         = 27
    static let bigDecimal         = 28
    static let record             = 29
    static let inst               = 30
    static let uuid               = 31
    static let delay              = 32
}

extension Expr: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .integer(let v):
            hasher.combine(ExprHash.integer);   hasher.combine(BigInt(v))

        case .double(let v):
            hasher.combine(ExprHash.float);     hasher.combine(v)

        case .float(let v):
            hasher.combine(ExprHash.float);     hasher.combine(Double(v))

        case .ratio(let v):
            hasher.combine(ExprHash.ratio);     hasher.combine(v)

        case .string(let v):
            hasher.combine(ExprHash.string);    hasher.combine(v)

        case .character(let v):
            hasher.combine(ExprHash.character); hasher.combine(v)

        case .boolean(let v):
            hasher.combine(ExprHash.boolean);   hasher.combine(v)

        case .nil:
            hasher.combine(ExprHash.nil)

        case .symbol(let v, _):
            hasher.combine(ExprHash.symbol);    hasher.combine(v)

        case .keyword(let v):
            hasher.combine(ExprHash.keyword);   hasher.combine(v)

        case .list(let v, _):
            hasher.combine(ExprHash.list);      hasher.combine(v)

        case .seq(let v):
            hasher.combine(ExprHash.list);      hasher.combine(v)

        case .vector(let v, _):
            hasher.combine(ExprHash.vector);    hasher.combine(v)

        case .mapEntry(let k, let v):
            hasher.combine(ExprHash.vector);    hasher.combine([k, v])

        case .map(let sm):
            hasher.combine(ExprHash.map);       hasher.combine(sm)

        case .sortedMap(let v, _):
            hasher.combine(ExprHash.map);       hasher.combine(v)

        case .set(let s):
            hasher.combine(ExprHash.set);       hasher.combine(s)

        case .sortedSet(let v, _):
            hasher.combine(ExprHash.set);       hasher.combine(Set(v))

        case .function(let f):
            hasher.combine(ExprHash.function);          hasher.combine(ObjectIdentifier(f))

        case .macro(let n, let p, let b, _):
            hasher.combine(ExprHash.macro);             hasher.combine(n); hasher.combine(p); hasher.combine(b)

        case .multiArityFunction(let maf):
            hasher.combine(ExprHash.multiArityFunction); hasher.combine(ObjectIdentifier(maf))

        case .multiArityMacro(let n, let a, _):
            hasher.combine(ExprHash.multiArityMacro);    hasher.combine(n); hasher.combine(a)

        case .nativeFunction(let n, let a, _):
            hasher.combine(ExprHash.nativeFunction);     hasher.combine(n); hasher.combine(a)

        case .varRef(let v):
            hasher.combine(ExprHash.varRef);    hasher.combine(ObjectIdentifier(v))

        case .namespace(let v):
            hasher.combine(ExprHash.namespace); hasher.combine(ObjectIdentifier(v))

        case .atom(let v):
            hasher.combine(ExprHash.atom);      hasher.combine(ObjectIdentifier(v))

        case .transient(let v):
            hasher.combine(ExprHash.transient); hasher.combine(ObjectIdentifier(v))

        // Identity hash. Lazy seqs can be == to lists via element comparison but
        // the hash contract is maintained within the lazy-seq type (same box → same hash).
        case .lazySeq(let box):
            hasher.combine(ExprHash.lazySeq);   hasher.combine(ObjectIdentifier(box))

        case .reduced(let v):
            hasher.combine(ExprHash.reduced);   hasher.combine(v)

        case .delay(let v):
            hasher.combine(ExprHash.delay);     hasher.combine(ObjectIdentifier(v))

        case .regex(let v):
            hasher.combine(ExprHash.regex);     hasher.combine(v)

        case .reader(let v):
            hasher.combine(ExprHash.reader);    hasher.combine(ObjectIdentifier(v))

        case .writer(let v):
            hasher.combine(ExprHash.writer);    hasher.combine(ObjectIdentifier(v))

        case .bigInteger(let v):
            if let i = Int(exactly: v) {
                hasher.combine(ExprHash.integer); hasher.combine(BigInt(i))
            } else {
                hasher.combine(ExprHash.bigInteger); hasher.combine(v)
            }

        case .bigDecimal(let v):
            hasher.combine(ExprHash.bigDecimal); hasher.combine(v)

        case .inst(let v):
            hasher.combine(ExprHash.inst);      hasher.combine(v)

        case .uuid(let v):
            hasher.combine(ExprHash.uuid);      hasher.combine(v)

        case .record(let t, _, let d, _):
            hasher.combine(ExprHash.record);    hasher.combine(t); hasher.combine(d)
        }
    }
}

extension Expr: CustomStringConvertible {
    public var description: String {
        switch self {
        case .nil:
            return "nil"

        case .boolean:
            return "boolean"

        case .integer:
            return "integer"

        case .bigInteger:
            return "bigInteger"

        case .float:
            return "float"

        case .double:
            return "double"

        case .bigDecimal:
            return "bigDecimal"

        case .ratio:
            return "ratio"

        case .string:
            return "string"

        case .character:
            return "character"

        case .keyword:
            return "keyword"

        case .symbol:
            return "symbol"

        case .list:
            return "list"

        case .seq:
            return "seq"

        case .vector:
            return "vector"

        case .mapEntry:
            return "map-entry"

        case .map:
            return "map"

        case .sortedMap:
            return "sorted-map"

        case .set:
            return "set"

        case .sortedSet:
            return "sorted-set"

        case .function, .multiArityFunction, .nativeFunction:
            return "function"

        case .macro, .multiArityMacro:
            return "macro"

        case .atom:
            return "atom"

        case .lazySeq:
            return "lazy-seq"

        case .delay:
            return "delay"

        case .reduced:
            return "reduced"

        case .transient:
            return "transient"

        case .varRef:
            return "var"

        case .namespace:
            return "namespace"

        case .record(let typeName, _, _, _):
            return typeName

        case .regex:
            return "regex"

        case .reader:
            return "reader"

        case .writer:
            return "writer"

        case .inst:
            return "inst"

        case .uuid:
            return "uuid"
        }
    }
}

extension Expr {
    /// Returns `self` with `additional` merged into its existing metadata.
    /// Returns `nil` for types that do not support metadata.
    func mergingMetadata(_ additional: [Expr: Expr]) -> Expr? {
        func merged(_ existing: [Expr: Expr]?) -> [Expr: Expr] {
            var result = existing ?? [:]
            for (k, v) in additional { result[k] = v }
            return result
        }
        switch self {
        case .symbol(let n, let m):                    return .symbol(n, metadata: merged(m))
        case .list(let e, let m):                      return .list(e, metadata: merged(m))
        case .vector(let e, let m):                    return .vector(e, metadata: merged(m))
        case .map(let sm):                             return .map(SwishMap(dict: sm.dict, metadata: merged(sm.metadata)))
        case .sortedMap(let d, let m):                 return .sortedMap(d, metadata: merged(m))
        case .set(let s):                              return .set(SwishSet(elements: s.elements, metadata: merged(s.metadata)))
        case .sortedSet(let s, let m):                 return .sortedSet(s, metadata: merged(m))
        case .function(let f):
            f.metadata = merged(f.metadata)
            return .function(f)
        case .macro(let n, let p, let b, let m):       return .macro(name: n, params: p, body: b, metadata: merged(m))
        case .multiArityFunction(let maf):
            maf.metadata = merged(maf.metadata)
            return .multiArityFunction(maf)
        case .multiArityMacro(let n, let a, let m):    return .multiArityMacro(name: n, arities: a, metadata: merged(m))
        default: return nil
        }
    }
}
