import Foundation

/// Lets `SwishOpaqueCodable` reach the value being decoded.
public protocol ExprDecodingContainer {
    var currentValue: Expr { get }
}

/// Decodes a Swish value into a `Codable` Swift type.
///
/// Reads a Swish map, sorted map, or `defrecord` into a struct; a vector, list or
/// seq into an array; and scalars via their `SwishDecodable` conformance.
///
/// ```swift
/// let point = try ExprDecoder().decode(Point.self, from: expr)
/// ```
///
/// Errors are `DecodingError`s carrying a `codingPath`, so a bad field says which
/// one — the diagnosis that `T(swishValue:)`'s failable init can't give.
///
/// - Note: A `deftype` is not read, matching Clojure, where `defrecord` instances
///   are associative and `deftype` instances are not.
public struct ExprDecoder: Sendable {
    /// How a Swift property name is matched against Swish map keys.
    public enum KeyStrategy: Sendable {
        /// Use the property name verbatim: `firstName` matches `:firstName`.
        case keyword

        /// Convert camelCase to kebab-case: `firstName` matches `:first-name`,
        /// the idiomatic Clojure spelling.
        case kebabCaseKeyword
    }

    public var keyStrategy: KeyStrategy

    public init(keyStrategy: KeyStrategy = .keyword) {
        self.keyStrategy = keyStrategy
    }

    public func decode<T: Decodable>(_ type: T.Type, from expr: Expr) throws -> T {
        // Through the same dispatch every nested value uses, so a top-level leaf
        // (`Date`, `UUID`, `Int`) converts via its Swish conformance rather than
        // Codable's own representation — `Date(from:)` alone would demand a
        // Double and reject a `#inst`.
        //
        // Safe against the recursion `decodeExpr` guards: for a `SwishCodable` T
        // step (a) calls the *synthesized* `T(from:)`, never `init?(swishValue:)`,
        // so it can't come back here.
        try decodeExpr(expr, as: T.self, codingPath: [], strategy: keyStrategy)
    }
}

// MARK: - Decoder

final class _ExprDecoder: Decoder, ExprDecodingContainer {
    let value: Expr
    let codingPath: [any CodingKey]
    let strategy: ExprDecoder.KeyStrategy
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    var currentValue: Expr { value }

    init(value: Expr, codingPath: [any CodingKey], strategy: ExprDecoder.KeyStrategy) {
        self.value = value
        self.codingPath = codingPath
        self.strategy = strategy
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard let entries = value.asDictionary() else {
            throw DecodingError.typeMismatch([Expr: Expr].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected a Swish map or record, found \(value.typeName)."))
        }
        return KeyedDecodingContainer(
            ExprKeyedContainer(entries: entries, codingPath: codingPath, strategy: strategy))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        // The eager coercion: an unkeyed container has a `count`, so the sequence
        // has to be finite anyway. `prefix(_:of:)` is the bounded alternative.
        guard let elements = try? asSequence(value) else {
            throw DecodingError.typeMismatch([Expr].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected a Swish sequence, found \(value.typeName)."))
        }
        return ExprUnkeyedContainer(elements: elements, codingPath: codingPath, strategy: strategy)
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        ExprSingleValueContainer(value: value, codingPath: codingPath, strategy: strategy)
    }
}

/// Converts `expr` to `T`.
///
/// **The order of these three branches is load-bearing — reversing the first two
/// recurses infinitely.** Every `SwishCodable` is also `SwishDecodable` (the
/// protocol refines `SwishConvertible`), and its `init?(swishValue:)` default calls
/// `ExprDecoder().decode`. So if the `SwishLeafConvertible` branch were widened to
/// all of `SwishDecodable` and ran first, a `SwishCodable` value would bounce
/// between the two until the stack ran out.
func decodeExpr<T: Decodable>(
    _ expr: Expr,
    as type: T.Type,
    codingPath: [any CodingKey],
    strategy: ExprDecoder.KeyStrategy
) throws -> T {
    // (a) A Codable Swish type takes itself apart, keeping its coding path.
    if T.self is any SwishCodable.Type {
        return try T(from: _ExprDecoder(value: expr, codingPath: codingPath, strategy: strategy))
    }
    // (b) A leaf converts directly — this is what makes `Date` read a `#inst`
    //     rather than Codable's bare Double, and `UUID` a `#uuid`.
    if let leaf = T.self as? any SwishLeafConvertible.Type {
        guard let value = leaf.init(swishValue: expr) as? T else {
            throw DecodingError.typeMismatch(T.self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected \(T.self), found \(expr.typeName)."))
        }
        return value
    }
    // (c) Anything else — arrays, dictionaries, optionals, plain Codable structs —
    //     goes through real containers so element errors carry a coding path.
    return try T(from: _ExprDecoder(value: expr, codingPath: codingPath, strategy: strategy))
}

/// The Swish keys a property name may appear under, in first-match order.
///
/// Ordered rather than merged: a Swish map can legitimately hold both `:a` and
/// `"a"`, and the keyword is the idiomatic one.
func candidateKeys(for name: String, strategy: ExprDecoder.KeyStrategy) -> [Expr] {
    let key = strategy == .kebabCaseKeyword ? kebabCased(name) : name
    return [.keyword(key), .string(key), .symbol(key, metadata: nil)]
}

func kebabCased(_ name: String) -> String {
    var result = ""
    for character in name {
        if character.isUppercase {
            result.append("-")
            result.append(Character(character.lowercased()))
        }
        else {
            result.append(character)
        }
    }
    return result
}

// MARK: - Keyed container

private struct ExprKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let entries: [Expr: Expr]
    let codingPath: [any CodingKey]
    let strategy: ExprDecoder.KeyStrategy

    var allKeys: [Key] {
        entries.keys.compactMap { key in
            guard let name = key.asString() else { return nil }
            return Key(stringValue: name)
        }
    }

    func contains(_ key: Key) -> Bool {
        value(for: key) != nil
    }

    // A `defrecord` always carries every declared field, usually as `.nil`, so
    // `contains` is nearly always true for records and it is `decodeNil` that
    // actually drives optionality.
    func decodeNil(forKey key: Key) throws -> Bool {
        guard let found = value(for: key) else { return true }
        // Only `.nil` counts. Swish's own truthiness treats `false` as falsey too,
        // and letting that leak here would turn `false` into a missing value.
        if case .nil = found {
            return true
        }
        return false
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        guard let found = value(for: key) else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "No value for \(key.stringValue)."))
        }
        if case .nil = found, !(T.self is ExpressibleByNilLiteral.Type) {
            throw DecodingError.valueNotFound(T.self, DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Found nil for non-optional \(key.stringValue)."))
        }
        return try decodeExpr(found, as: T.self, codingPath: codingPath + [key], strategy: strategy)
    }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type, forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> {
        try decoder(for: key).container(keyedBy: NestedKey.self)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
        try decoder(for: key).unkeyedContainer()
    }

    func superDecoder() throws -> any Decoder {
        _ExprDecoder(value: .map(entries, metadata: nil), codingPath: codingPath, strategy: strategy)
    }

    func superDecoder(forKey key: Key) throws -> any Decoder {
        try decoder(for: key)
    }

    private func value(for key: Key) -> Expr? {
        for candidate in candidateKeys(for: key.stringValue, strategy: strategy) {
            if let found = entries[candidate] {
                return found
            }
        }
        return nil
    }

    private func decoder(for key: Key) throws -> _ExprDecoder {
        guard let found = value(for: key) else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "No value for \(key.stringValue)."))
        }
        return _ExprDecoder(value: found, codingPath: codingPath + [key], strategy: strategy)
    }
}

// MARK: - Unkeyed container

private struct ExprUnkeyedContainer: UnkeyedDecodingContainer {
    let elements: [Expr]
    let codingPath: [any CodingKey]
    let strategy: ExprDecoder.KeyStrategy
    var currentIndex = 0

    var count: Int? { elements.count }
    var isAtEnd: Bool { currentIndex >= elements.count }

    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else { return true }
        if case .nil = elements[currentIndex] {
            currentIndex += 1
            return true
        }
        return false
    }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let element = try nextElement(for: T.self)
        return try decodeExpr(element, as: T.self,
                              codingPath: codingPath + [IndexKey(intValue: currentIndex - 1)],
                              strategy: strategy)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey> {
        try nextDecoder().container(keyedBy: NestedKey.self)
    }

    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
        try nextDecoder().unkeyedContainer()
    }

    mutating func superDecoder() throws -> any Decoder {
        try nextDecoder()
    }

    private mutating func nextDecoder() throws -> _ExprDecoder {
        let element = try nextElement(for: Expr.self)
        return _ExprDecoder(value: element,
                            codingPath: codingPath + [IndexKey(intValue: currentIndex - 1)],
                            strategy: strategy)
    }

    private mutating func nextElement(for type: Any.Type) throws -> Expr {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Ran out of elements decoding \(type)."))
        }
        let element = elements[currentIndex]
        currentIndex += 1
        return element
    }
}

// MARK: - Single value container

private struct ExprSingleValueContainer: SingleValueDecodingContainer {
    let value: Expr
    let codingPath: [any CodingKey]
    let strategy: ExprDecoder.KeyStrategy

    func decodeNil() -> Bool {
        if case .nil = value {
            return true
        }
        return false
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try decodeExpr(value, as: T.self, codingPath: codingPath, strategy: strategy)
    }
}

/// A `CodingKey` for an array position, so element errors carry an index.
struct IndexKey: CodingKey {
    let intValue: Int?
    var stringValue: String { "Index \(intValue ?? -1)" }

    init(intValue: Int) {
        self.intValue = intValue
    }

    init?(stringValue: String) {
        return nil
    }
}
