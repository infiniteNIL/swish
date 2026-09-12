import Foundation

/// Lets `SwishOpaqueCodable` hand a raw Swish value to the encoder.
public protocol ExprEncodingContainer {
    func record(_ value: Expr)
}

/// Encodes a `Codable` Swift value into a Swish value.
///
/// Structs become maps with **keyword** keys, which is the idiomatic Clojure shape
/// and what `(:field m)` expects. Arrays become vectors, scalars convert via their
/// `SwishRepresentable` conformance.
///
/// ```swift
/// let expr = try ExprEncoder().encode(point)     // => {:x 1 :y 2}
/// ```
///
/// - Note: Never emits a `defrecord` — a record needs a type registered by a
///   `defrecord` form in Swish. Call `map->TypeName` with the encoded map when you
///   need an actual record instance.
public struct ExprEncoder: Sendable {
    /// How a Swift property name becomes a Swish map key. Mirrors
    /// `ExprDecoder.KeyStrategy`.
    public typealias KeyStrategy = ExprDecoder.KeyStrategy

    public var keyStrategy: KeyStrategy

    public init(keyStrategy: KeyStrategy = .keyword) {
        self.keyStrategy = keyStrategy
    }

    public func encode(_ value: some Encodable) throws -> Expr {
        let encoder = _ExprEncoder(codingPath: [], strategy: keyStrategy)
        try encodeValue(value, into: encoder)
        return encoder.result
    }
}

/// Converts `value` to a Swish value into `encoder`.
///
/// **The order mirrors `decodeExpr`'s, and is load-bearing for the same reason.**
/// Every `SwishCodable` is also `SwishRepresentable`, and its `swishValue` default
/// calls `ExprEncoder().encode`. Checking `SwishRepresentable` first would bounce a
/// `SwishCodable` value between the two until the stack ran out.
func encodeValue(_ value: some Encodable, into encoder: _ExprEncoder) throws {
    // (a) A Codable Swish type takes itself apart, keeping its coding path.
    if value is any SwishCodable {
        try value.encode(to: encoder)
        return
    }
    // (b) A leaf converts directly — what keeps a `Date` a `#inst` rather than
    //     Codable's bare Double.
    if let leaf = value as? any SwishLeafConvertible {
        encoder.record(leaf.swishValue)
        return
    }
    // (c) Everything else goes through real containers.
    try value.encode(to: encoder)
}

// MARK: - Encoder

final class _ExprEncoder: Encoder, ExprEncodingContainer {
    let codingPath: [any CodingKey]
    let strategy: ExprEncoder.KeyStrategy
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    private var storage: Expr = .nil
    private var keyed: [Expr: Expr] = [:]
    private var unkeyed: [Expr] = []
    private var kind: Kind = .single

    private enum Kind {
        case single
        case keyed
        case unkeyed
    }

    init(codingPath: [any CodingKey], strategy: ExprEncoder.KeyStrategy) {
        self.codingPath = codingPath
        self.strategy = strategy
    }

    var result: Expr {
        switch kind {
        case .single:
            return storage

        case .keyed:
            return .map(keyed, metadata: nil)

        case .unkeyed:
            return .vector(SwishPersistentVector(unkeyed), metadata: nil)
        }
    }

    func record(_ value: Expr) {
        kind = .single
        storage = value
    }

    func setEntry(_ key: Expr, _ value: Expr) {
        kind = .keyed
        keyed[key] = value
    }

    func append(_ value: Expr) {
        kind = .unkeyed
        unkeyed.append(value)
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        kind = .keyed
        return KeyedEncodingContainer(ExprKeyedEncodingContainer(encoder: self, codingPath: codingPath))
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        kind = .unkeyed
        return ExprUnkeyedEncodingContainer(encoder: self, codingPath: codingPath)
    }

    func singleValueContainer() -> any SingleValueEncodingContainer {
        ExprSingleValueEncodingContainer(encoder: self, codingPath: codingPath)
    }

    /// The Swish key a property name is written under — always a keyword, the
    /// idiomatic Clojure map key.
    func mapKey(for name: String) -> Expr {
        .keyword(strategy == .kebabCaseKeyword ? kebabCased(name) : name)
    }

    func child(for key: any CodingKey) -> _ExprEncoder {
        _ExprEncoder(codingPath: codingPath + [key], strategy: strategy)
    }
}

// MARK: - Keyed container

private struct ExprKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: _ExprEncoder
    let codingPath: [any CodingKey]

    mutating func encodeNil(forKey key: Key) throws {
        encoder.setEntry(encoder.mapKey(for: key.stringValue), .nil)
    }

    mutating func encode(_ value: some Encodable, forKey key: Key) throws {
        let child = encoder.child(for: key)
        try encodeValue(value, into: child)
        encoder.setEntry(encoder.mapKey(for: key.stringValue), child.result)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type, forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> {
        // A nested container writes into its own encoder, which is only folded back
        // in when it is finished — so record a placeholder now and overwrite on
        // completion via the shared reference.
        let child = encoder.child(for: key)
        encoder.setEntry(encoder.mapKey(for: key.stringValue), child.result)
        return child.container(keyedBy: NestedKey.self)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
        let child = encoder.child(for: key)
        encoder.setEntry(encoder.mapKey(for: key.stringValue), child.result)
        return child.unkeyedContainer()
    }

    mutating func superEncoder() -> any Encoder {
        encoder
    }

    mutating func superEncoder(forKey key: Key) -> any Encoder {
        encoder.child(for: key)
    }
}

// MARK: - Unkeyed container

private struct ExprUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let encoder: _ExprEncoder
    let codingPath: [any CodingKey]
    var count = 0

    mutating func encodeNil() throws {
        encoder.append(.nil)
        count += 1
    }

    mutating func encode(_ value: some Encodable) throws {
        let child = _ExprEncoder(codingPath: codingPath + [IndexKey(intValue: count)],
                                 strategy: encoder.strategy)
        try encodeValue(value, into: child)
        encoder.append(child.result)
        count += 1
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> {
        let child = _ExprEncoder(codingPath: codingPath + [IndexKey(intValue: count)],
                                 strategy: encoder.strategy)
        count += 1
        return child.container(keyedBy: NestedKey.self)
    }

    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        let child = _ExprEncoder(codingPath: codingPath + [IndexKey(intValue: count)],
                                 strategy: encoder.strategy)
        count += 1
        return child.unkeyedContainer()
    }

    mutating func superEncoder() -> any Encoder {
        encoder
    }
}

// MARK: - Single value container

private struct ExprSingleValueEncodingContainer: SingleValueEncodingContainer {
    let encoder: _ExprEncoder
    let codingPath: [any CodingKey]

    mutating func encodeNil() throws {
        encoder.record(.nil)
    }

    mutating func encode(_ value: some Encodable) throws {
        try encodeValue(value, into: encoder)
    }
}
