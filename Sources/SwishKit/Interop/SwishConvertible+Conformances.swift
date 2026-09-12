import Foundation
import BigInt
import BigDecimal

// The `SwishDecodable` conformances below are the *source of truth* for every
// conversion: `Expr`'s `as*` accessors delegate to them. They must therefore
// pattern-match `Expr` directly and never call an `as*` accessor back, or the
// two recurse until the stack runs out.

// MARK: - Identity

// `Expr` conforming to both halves is the escape hatch: a registered function
// can take or return a raw `Expr` for any parameter whose Swish shape has no
// Swift equivalent, while every other parameter still marshals normally.
extension Expr: SwishConvertible {
    public var swishValue: Expr { self }

    public init?(swishValue: Expr) { self = swishValue }
}

// MARK: - Strings and characters

extension String: SwishConvertible {
    public var swishValue: Expr { .string(self) }

    // Decodes a keyword's or symbol's name as well as a string, matching
    // `asString()`. Keyword-keyed maps are the Clojure norm, so a strict `String`
    // would mean `[String: Int]` could never read `{:a 1}` — or any `defrecord`,
    // whose fields are keyword-keyed.
    //
    // Two consequences, both deliberate:
    //   - A registered `(String) -> …` accepts `(f :oops)`. Take an `Expr`
    //     parameter when a function needs to reject that.
    //   - The round trip is lossy: a `String` always encodes back to `.string`,
    //     so a map read as `[String: Int]` and handed back has string keys and
    //     `(:a m)` misses. Use `Keyword` or a `SwishCodable` struct to preserve it.
    public init?(swishValue: Expr) {
        switch swishValue {
        case .string(let s):
            self = s

        case .keyword(let k):
            self = k

        case .symbol(let s, _):
            self = s

        default:
            return nil
        }
    }
}

extension Character: SwishConvertible {
    public var swishValue: Expr { .character(self) }

    public init?(swishValue: Expr) {
        guard case let .character(c) = swishValue else { return nil }
        self = c
    }
}

// MARK: - Booleans

extension Bool: SwishConvertible {
    public var swishValue: Expr { .boolean(self) }

    public init?(swishValue: Expr) {
        guard case let .boolean(b) = swishValue else { return nil }
        self = b
    }
}

// MARK: - Integers

extension Int: SwishConvertible {
    public var swishValue: Expr { .integer(self) }

    public init?(swishValue: Expr) {
        guard let n = exactInteger(swishValue, Int.self) else { return nil }
        self = n
    }
}

extension Int8: SwishConvertible {
    public var swishValue: Expr { .integer(Int(self)) }

    public init?(swishValue: Expr) {
        guard let n = exactInteger(swishValue, Int8.self) else { return nil }
        self = n
    }
}

extension Int16: SwishConvertible {
    public var swishValue: Expr { .integer(Int(self)) }

    public init?(swishValue: Expr) {
        guard let n = exactInteger(swishValue, Int16.self) else { return nil }
        self = n
    }
}

extension Int32: SwishConvertible {
    public var swishValue: Expr { .integer(Int(self)) }

    public init?(swishValue: Expr) {
        guard let n = exactInteger(swishValue, Int32.self) else { return nil }
        self = n
    }
}

extension Int64: SwishConvertible {
    public var swishValue: Expr { .integer(Int(self)) }

    public init?(swishValue: Expr) {
        guard let n = exactInteger(swishValue, Int64.self) else { return nil }
        self = n
    }
}

extension UInt8: SwishConvertible {
    public var swishValue: Expr { .integer(Int(self)) }

    public init?(swishValue: Expr) {
        guard let n = exactInteger(swishValue, UInt8.self) else { return nil }
        self = n
    }
}

extension UInt16: SwishConvertible {
    public var swishValue: Expr { .integer(Int(self)) }

    public init?(swishValue: Expr) {
        guard let n = exactInteger(swishValue, UInt16.self) else { return nil }
        self = n
    }
}

extension UInt32: SwishConvertible {
    public var swishValue: Expr { .integer(Int(self)) }

    public init?(swishValue: Expr) {
        guard let n = exactInteger(swishValue, UInt32.self) else { return nil }
        self = n
    }
}

extension UInt64: SwishConvertible {
    public var swishValue: Expr { .bigInteger(BigInt(self)) }

    public init?(swishValue: Expr) {
        guard let n = exactInteger(swishValue, UInt64.self) else { return nil }
        self = n
    }
}

extension UInt: SwishConvertible {
    public var swishValue: Expr { .bigInteger(BigInt(self)) }

    public init?(swishValue: Expr) {
        guard let n = exactInteger(swishValue, UInt.self) else { return nil }
        self = n
    }
}

extension BigInt: SwishConvertible {
    public var swishValue: Expr { .bigInteger(self) }

    public init?(swishValue: Expr) {
        switch swishValue {
        case .bigInteger(let n):
            self = n

        case .integer(let n):
            self = BigInt(n)

        default:
            return nil
        }
    }
}

// Shared by every fixed-width integer conformance. Deliberately stricter than
// `Expr.asInt()`, which truncates a `.ratio` by integer division — at the host
// boundary, handing `(/ 1 2)` to a Swift `Int` parameter should be a loud
// argument error, not a silent `0`. A `.bigInteger` converts when it fits.
private func exactInteger<T: BinaryInteger>(_ expr: Expr, _ type: T.Type) -> T? {
    switch expr {
    case .integer(let n):
        return T(exactly: n)

    case .bigInteger(let n):
        return T(exactly: n)

    default:
        return nil
    }
}

// MARK: - Floating point

// Unlike the integer conformances, these widen: Swish's numeric tower makes
// `(area 5)` the natural way to call a Swift `(Double) -> Double`, so an
// integral argument is accepted for a floating-point parameter.
extension Double: SwishConvertible {
    public var swishValue: Expr { .double(self) }

    public init?(swishValue: Expr) {
        switch swishValue {
        case .double(let d):
            self = d

        case .float(let f):
            self = Double(f)

        case .integer(let n):
            self = Double(n)

        case .ratio(let r):
            self = Double(r.numerator) / Double(r.denominator)

        default:
            return nil
        }
    }
}

extension Float: SwishConvertible {
    public var swishValue: Expr { .float(self) }

    public init?(swishValue: Expr) {
        switch swishValue {
        case .float(let f):
            self = f

        case .double(let d):
            self = Float(d)

        case .integer(let n):
            self = Float(n)

        case .ratio(let r):
            self = Float(r.numerator) / Float(r.denominator)

        default:
            return nil
        }
    }
}

extension BigDecimal: SwishConvertible {
    public var swishValue: Expr { .bigDecimal(self) }

    public init?(swishValue: Expr) {
        guard case let .bigDecimal(d) = swishValue else { return nil }
        self = d
    }
}

extension Ratio: SwishConvertible {
    public var swishValue: Expr { .ratio(self) }

    public init?(swishValue: Expr) {
        guard case let .ratio(r) = swishValue else { return nil }
        self = r
    }
}

// MARK: - Foundation values

extension Date: SwishConvertible {
    public var swishValue: Expr { .inst(self) }

    public init?(swishValue: Expr) {
        guard case let .inst(d) = swishValue else { return nil }
        self = d
    }
}

extension UUID: SwishConvertible {
    public var swishValue: Expr { .uuid(self) }

    public init?(swishValue: Expr) {
        guard case let .uuid(u) = swishValue else { return nil }
        self = u
    }
}

// MARK: - Optionals

extension Optional: SwishRepresentable where Wrapped: SwishRepresentable {
    public var swishValue: Expr {
        switch self {
        case .none:
            return .nil

        case .some(let wrapped):
            return wrapped.swishValue
        }
    }
}

// Decoding `nil` from `.nil` is also what lets a trailing optional parameter be
// omitted entirely: `ArgumentCursor` hands out `.nil` past the end of the
// argument list, and it lands here.
extension Optional: SwishDecodable where Wrapped: SwishDecodable {
    public init?(swishValue: Expr) {
        if case .nil = swishValue {
            self = .none
            return
        }
        guard let wrapped = Wrapped(swishValue: swishValue) else { return nil }
        self = .some(wrapped)
    }
}

// MARK: - Collections

extension Array: SwishRepresentable where Element: SwishRepresentable {
    public var swishValue: Expr {
        .vector(SwishPersistentVector(map(\.swishValue)), metadata: nil)
    }
}

// Accepts anything Swish considers seqable — vector, list, seq, lazy seq, array,
// string, set, map, or nil — not just the vector this encodes to, so a Swift
// `[Int]` parameter can receive `(range 5)` or `'(1 2 3)`.
extension Array: SwishDecodable where Element: SwishDecodable {
    public init?(swishValue: Expr) {
        // `try?` flattens the throwing `[Expr]?` result to a single optional.
        guard let elements = try? asSequence(swishValue) else { return nil }
        var result: [Element] = []
        result.reserveCapacity(elements.count)
        for element in elements {
            guard let converted = Element(swishValue: element) else { return nil }
            result.append(converted)
        }
        self = result
    }
}

extension Set: SwishRepresentable where Element: SwishRepresentable {
    public var swishValue: Expr {
        .set(Set<Expr>(map(\.swishValue)), metadata: nil)
    }
}

extension Set: SwishDecodable where Element: SwishDecodable {
    public init?(swishValue: Expr) {
        guard let array = [Element](swishValue: swishValue) else { return nil }
        self = Set(array)
    }
}

extension Dictionary: SwishRepresentable where Key: SwishRepresentable, Value: SwishRepresentable {
    public var swishValue: Expr {
        var pairs: [Expr: Expr] = [:]
        pairs.reserveCapacity(count)
        for (key, value) in self {
            pairs[key.swishValue] = value.swishValue
        }
        return .map(pairs, metadata: nil)
    }
}

extension Dictionary: SwishDecodable where Key: SwishDecodable, Value: SwishDecodable {
    public init?(swishValue: Expr) {
        guard let pairs = swishValue.asDictionary() else { return nil }
        var result: [Key: Value] = [:]
        result.reserveCapacity(pairs.count)
        for (key, value) in pairs {
            guard let k = Key(swishValue: key), let v = Value(swishValue: value) else { return nil }
            // Two distinct Swish keys can converge on one Swift key — `{:a 1 "a" 2}`
            // decoded as [String: Int], say. Silently keeping whichever came last
            // would make the result depend on unspecified iteration order.
            guard result.updateValue(v, forKey: k) == nil else { return nil }
        }
        self = result
    }
}
