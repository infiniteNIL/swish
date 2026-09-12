import Foundation
import BigInt
import BigDecimal

/// A Swift type that converts to and from a Swish value *without* being taken
/// apart into a keyed or unkeyed container.
///
/// The `Codable` bridge needs this to be a **closed** set. "Is it `SwishDecodable`?"
/// would be wrong: `Array`, `Set`, `Dictionary` and `Optional` all conform
/// conditionally, so `[Int]` would bypass `unkeyedContainer` — losing element-level
/// `codingPath` in errors, and inheriting `Array.init?(swishValue:)`'s eager
/// realization, which hangs on an infinite seq.
///
/// It also carries real weight for the Foundation types: `Date: Codable` encodes as
/// a bare `Double` and `UUID: Codable` as a `String`, so without routing them here a
/// `#inst` would silently degrade to a number.
public protocol SwishLeafConvertible: SwishConvertible {}

extension Expr: SwishLeafConvertible {}
extension String: SwishLeafConvertible {}
extension Character: SwishLeafConvertible {}
extension Bool: SwishLeafConvertible {}
extension Int: SwishLeafConvertible {}
extension Int8: SwishLeafConvertible {}
extension Int16: SwishLeafConvertible {}
extension Int32: SwishLeafConvertible {}
extension Int64: SwishLeafConvertible {}
extension UInt: SwishLeafConvertible {}
extension UInt8: SwishLeafConvertible {}
extension UInt16: SwishLeafConvertible {}
extension UInt32: SwishLeafConvertible {}
extension UInt64: SwishLeafConvertible {}
extension Double: SwishLeafConvertible {}
extension Float: SwishLeafConvertible {}
extension BigInt: SwishLeafConvertible {}
extension BigDecimal: SwishLeafConvertible {}
extension Ratio: SwishLeafConvertible {}
extension Date: SwishLeafConvertible {}
extension UUID: SwishLeafConvertible {}
extension Keyword: SwishLeafConvertible {}
extension Symbol: SwishLeafConvertible {}

// MARK: - Codable bridging

/// Opts a `Codable` Swift type into converting to and from a Swish map.
///
/// One line of host code, mirroring `SwishOpaque`:
///
/// ```swift
/// struct Point: Codable { var x: Int; var y: Int }
/// extension Point: SwishCodable {}
///
/// let p: Point = try swish.eval("{:x 1 :y 2}")      // also reads a defrecord
/// try swish.call("move", p, 3)
/// ```
///
/// Where `SwishOpaque` hands a type through untouched, this one takes it apart:
/// properties become keyword-keyed map entries, and a Swish map, sorted map or
/// `defrecord` reads back into the struct.
///
/// - Note: A field's own type must be `Codable` too, which a `SwishOpaque` handle
///   isn't — Swift's `Codable` synthesis rejects that at compile time and no
///   runtime bridging can rescue it. Conform such a type to `SwishOpaqueCodable`
///   instead, or pass opaque values as whole arguments rather than as fields.
public protocol SwishCodable: Codable, SwishConvertible {}

public extension SwishCodable {
    var swishValue: Expr {
        // Encoding a value whose `encode(to:)` throws has no non-throwing answer
        // here. `.nil` would be indistinguishable from a legitimately nil value —
        // exactly the silent-loss failure this codebase refuses elsewhere — so the
        // throwing path in `swishEncodedValue()` is what `register` and `call`
        // actually use, and this is only the last-resort fallback.
        (try? ExprEncoder().encode(self)) ?? .nil
    }

    func swishEncodedValue() throws -> Expr {
        try ExprEncoder().encode(self)
    }

    init?(swishValue: Expr) {
        guard let value = try? ExprDecoder().decode(Self.self, from: swishValue) else { return nil }
        self = value
    }

    /// Decodes without collapsing the error, for callers holding the type as an
    /// existential metatype — the throwing path `Expr.decode` uses so a
    /// `DecodingError` reaches the host intact.
    static func decodedFromSwish(_ expr: Expr) throws -> Self {
        try ExprDecoder().decode(Self.self, from: expr)
    }
}

/// A value's Swish form, preferring the throwing path when it has one.
///
/// `SwishRepresentable.swishValue` can't throw, so a `SwishCodable` whose
/// `encode(to:)` fails would otherwise become `.nil` — indistinguishable from a
/// legitimately nil value, silently, including through every registered
/// function's return. Every boundary that *can* throw routes through here so the
/// failure reaches the host instead.
func swishValue(of value: any SwishRepresentable) throws -> Expr {
    if let codable = value as? any SwishCodable {
        return try codable.swishEncodedValue()
    }
    return value.swishValue
}

/// Lets a `SwishOpaque` type also satisfy `Codable`, so it can be a field of a
/// `SwishCodable` struct.
///
/// Codable synthesis is a whole-struct compile-time requirement: a field whose type
/// isn't `Decodable` fails to build, and the host has no way to fix that from the
/// outside. Conforming the opaque type here supplies the conformance, and encoding
/// it through anything other than `ExprEncoder`/`ExprDecoder` — a `JSONEncoder`,
/// say — throws a clear error instead of failing to compile.
public protocol SwishOpaqueCodable: SwishOpaque, Codable {}

public extension SwishOpaqueCodable {
    func encode(to encoder: any Encoder) throws {
        guard let exprEncoder = encoder as? ExprEncodingContainer else {
            throw EncodingError.invalidValue(self, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "\(Self.self) is an opaque Swish value and can only be encoded by ExprEncoder."))
        }
        exprEncoder.record(.foreign(ForeignObject(self)))
    }

    init(from decoder: any Decoder) throws {
        guard let exprDecoder = decoder as? ExprDecodingContainer else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "\(Self.self) is an opaque Swish value and can only be decoded by ExprDecoder."))
        }
        guard let value = Self(swishValue: exprDecoder.currentValue) else {
            throw DecodingError.typeMismatch(Self.self, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected an opaque \(Self.self)."))
        }
        self = value
    }
}
