//
//  Expr+Swift.swift
//  Swish
//
//  Created by Rod Schmidt on 9/2/26.
//

import Foundation

/// Convenience accessors for reading a Swish `Expr` as a Swift value.
///
/// These are the raw-`Expr` layer. For most host code the typed bridge is
/// preferable — `expr.decode(Int.self)`, `try swish.eval(source, as: [Int].self)`,
/// or `Int(swishValue: expr)` — which reports what it expected when it fails and
/// converts nested collections for you.
public extension Expr {
    /// Get a Swift array from a Swish Expr.
    ///
    /// Accepts arrays, lists, seqs, vectors, and lazy seqs.
    ///
    /// - Important: A lazy seq is realized in full. Never call this on a
    ///   possibly-infinite seq — use `prefix(_:of:)` or `forEach(of:_:)` instead.
    /// - Returns: the elements, or nil if this isn't a sequential value
    func asArray() -> Array<Expr>? {
        switch self {
        case let .array(a):
            a.elements

        case let .list(l, _):
            l.elements

        case let .seq(s):
            s

        case let .sharedVector(v, _):
            v.elements

        case let .vector(v, _):
            v.elements

        // Realizing a lazy seq can throw (the thunk runs user code); this
        // accessor can't, so a failure reads as "not convertible". Never call
        // this on a known-infinite seq.
        case .lazySeq:
            (try? SwishKit.asSequence(self)) ?? nil

        default:
            nil
        }
    }
    
    /// Get a Swift array from a Swish Expr, converting the elements.
    ///
    /// Fails rather than losing data: nil if any element can't be converted, so
    /// `[1 "x" 3]` mapped through `Expr.toInt` is nil, not `[1, 3]`.
    ///
    /// - Parameter mapElement: A function to convert each element to the Swift type you want
    /// - Returns: A Swift array of the type you converted to, or nil
    func asArray<T>(_ mapElement: (Expr) -> T?) -> Array<T>? {
        guard let a = asArray() else { return nil }
        var result: [T] = []
        result.reserveCapacity(a.count)
        for element in a {
            guard let converted = mapElement(element) else { return nil }
            result.append(converted)
        }
        return result
    }

    static func toBool(_ expr: Expr) -> Bool? {
        expr.asBool()
    }

    func asBool() -> Bool? {
        Bool(swishValue: self)
    }

    static func toCharacter(_ expr: Expr) -> Character? {
        expr.asCharacter()
    }

    func asCharacter() -> Character? {
        Character(swishValue: self)
    }

    static func toDate(_ expr: Expr) -> Date? {
        expr.asDate()
    }

    func asDate() -> Date? {
        Date(swishValue: self)
    }

    /// Get a Swift dictionary from a Swish map, record, or sortedMap
    /// - Returns: A dictionary or nil if can't convert the Swish Expr
    func asDictionary() -> Dictionary<Expr, Expr>? {
        switch self {
        case let .map(m):
            m.dict.swiftDictionary

        case let .record(_, _, data, _):
            data

        case let .sortedMap(m):
            m.asDictionary

        default:
            nil
        }
    }

    /// Get a Swift dictionary from a Swish map, record, or sortedMap, converting the entries.
    ///
    /// Fails rather than losing data: nil if any key or value can't be converted,
    /// and nil if two distinct Swish keys converge on the same Swift key (mapping
    /// `{:a 1 "a" 2}` through `Expr.toString` would otherwise keep one entry
    /// chosen by unspecified iteration order).
    ///
    /// - Parameter mapKey: A function to convert each key to the Swift type you want
    /// - Parameter mapValue: A function to convert each value to the Swift type you want.
    /// - Returns: A Swift dictionary of the types you converted to, or nil
    func asDictionary<K, V>(mapKey: (Expr) -> K?, mapValue: (Expr) -> V?) -> Dictionary<K, V>? {
        guard let d = asDictionary() else { return nil }
        var result: Dictionary<K, V> = [:]
        for (k, v) in d {
            guard let key = mapKey(k), let newValue = mapValue(v) else { return nil }
            guard result.updateValue(newValue, forKey: key) == nil else { return nil }
        }
        return result
    }

    static func toDouble(_ expr: Expr) -> Double? {
        expr.asDouble()
    }

    /// Also accepts integers and floats — Swish's numeric tower makes `5` a
    /// perfectly good `Double`. (It used to accept only `.double`/`.ratio`, so
    /// `asDouble()` on `5` was nil.)
    func asDouble() -> Double? {
        Double(swishValue: self)
    }

    static func toFloat(_ expr: Expr) -> Float? {
        expr.asFloat()
    }

    /// Also accepts integers and doubles — see `asDouble()`.
    func asFloat() -> Float? {
        Float(swishValue: self)
    }

    static func toInt(_ expr: Expr) -> Int? {
        expr.asInt()
    }

    /// Deliberately **not** `Int(swishValue:)`, which is strict: this truncates a
    /// ratio by integer division, so `(/ 5 2)` reads as `2`. Use `decode(Int.self)`
    /// or `Int(swishValue:)` when a ratio should be an error instead.
    func asInt() -> Int? {
        switch self {
        case let .integer(i):
            i

        case let .ratio(r):
            Int(r.numerator) / Int(r.denominator)

        default:
            nil
        }
    }


    /// Returns a Sequence over the elements of any sequential Swish value.
    ///
    /// A lazy seq is iterated lazily, one element realized at a time; every
    /// other supported shape (seq, list, vector, array) is already in memory and
    /// is handed back as-is.
    /// - Returns: a sequence, or nil if the Expr isn't sequential
    func asSequence() -> (any Sequence<Expr>)? {
        switch self {
        // Realized one element at a time, so an infinite seq stays usable.
        // Iteration stops on a realization error rather than reporting it — use
        // `forEach(of:_:)` or `prefix(_:of:)` when you need to know.
        case .lazySeq:
            lazySequence(of: Expr.self)

        case let .seq(s):
            s

        default:
            asArray()
        }
    }

    static func toRegex(_ expr: Expr) -> String? {
        expr.asRegex()
    }

    func asRegex() -> String? {
        switch self {
        case let .regex(r):
            r.pattern

        default:
            nil
        }
    }

    func asSet() -> Set<Expr>? {
        switch self {
        case let .set(s):
            Set(s.elements.map { $0 })

        case let .sortedSet(s):
            Set(s.elements)

        default:
            nil
        }
    }

    /// Get a Swift set from a Swish Expr, converting the elements.
    ///
    /// Fails rather than losing data: nil if any element can't be converted, and
    /// nil if two distinct Swish elements converge on the same Swift value.
    ///
    /// - Parameter mapElement: A function to convert each element to the Swift type you want
    /// - Returns: A Swift set of the type you converted to, or nil
    func asSet<T>(_ mapElement: (Expr) -> T?) -> Set<T>? {
        guard let s = asSet() else { return nil }
        var result: Set<T> = []
        for element in s {
            guard let converted = mapElement(element) else { return nil }
            guard result.insert(converted).inserted else { return nil }
        }
        return result
    }

    static func toString(_ expr: Expr) -> String? {
        expr.asString()
    }

    /// Get a Swift string from a Swish Expr.
    ///
    /// Accepts strings, symbols and keywords, flattening all three to the bare
    /// name — `String(swishValue:)` does the same.
    /// - Returns: a Swift String, or nil
    func asString() -> String? {
        String(swishValue: self)
    }
    
    static func toTuple(_ expr: Expr) -> (Expr, Expr)? {
        expr.asTuple()
    }

    /// Get a Swift tuple from a Swish Map Entry
    /// - Returns: Returns a tuple with the key and value of the map entry
    /// - Returns: nil if the Expr is not a mapEntry
    func asTuple() -> (Expr, Expr)? {
        switch self {
        case let .mapEntry(k, v):
            (k, v)

        default:
            nil
        }
    }

    /// Get the host value carried by a foreign (opaque Swift) value.
    ///
    /// The counterpart of `SwishOpaque` — useful when you're holding a raw
    /// `Expr` rather than letting the bridge convert it for you.
    /// - Returns: the wrapped value, or nil if this isn't a foreign value of
    ///   type `T`
    func asForeign<T>(_ type: T.Type = T.self) -> T? {
        guard case let .foreign(object) = self else { return nil }
        return object.unwrap(as: T.self)
    }

    static func toUUID(_ expr: Expr) -> UUID? {
        expr.asUUID()
    }

    func asUUID() -> UUID? {
        UUID(swishValue: self)
    }

    /* TODO
    case list(SwishPersistentList, metadata: [Expr: Expr]?)
    /// An eager, non-list seq — returned by `seq` on non-list collections (vector, map, set, etc.).
    /// Satisfies `seq?` but not `list?` or `lazy-seq?`, matching Clojure's ISeq-not-IPersistentList.
    case seq([Expr])
    /// A Java-style object array: seqable but not sequential or associative.
    /// Uses reference semantics so `aset` mutations are visible through all aliases.
    case array(SwishArray)
    case vector(SwishPersistentVector, metadata: [Expr: Expr]?)
    /// A persistent-vector view over a `SwishArray`. Produced by `(vec arr)`.
    /// Sequential and vector?=true; shares mutable storage with the source array.
    case sharedVector(SwishArray, metadata: [Expr: Expr]?)
    /// A key-value pair from map iteration. Semantically equivalent to a 2-element vector.
    case mapEntry(Expr, Expr)
    case map(SwishMap)
    case set(SwishSet)
    case sortedSet(SwishSortedSet)
    case sortedMap(SwishSortedMap)
    case function(SwishFunction)
    case multiArityFunction(SwishMultiArityFunction)
    case nativeFunction(name: String, arity: Arity, body: @Sendable ([Expr]) throws -> Expr)
    case transient(TransientCollection)
    /// A thunk-backed lazy sequence. Realizes elements on demand.
    case lazySeq(LazySeqBox)

    /// A compiled regular expression literal (`#"pattern"`).
    case regex(SwishRegex)

    /// A map-backed record created by `defrecord`.
    /// `typeName` is namespace-qualified (e.g. `"user/Point"`).
    /// `fields` lists the declared field names in order.
    /// `data` holds the current key→value pairs (always includes all declared fields).
    case record(typeName: String, fields: [String], data: [Expr: Expr], metadata: [Expr: Expr]?)
    */
}
