//
//  File.swift
//  Swish
//
//  Created by Rod Schmidt on 9/2/26.
//

import Foundation

/// Extensions to extract Swift types for Swish Exprs
public extension Expr {
    /// Get a Swift array from an Swish Expr.
    /// Arrays can be made from Swish arrays, lists, vectors, ???
    /// - Returns: a Swift String
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

        default:
            nil
        }
    }
    
    /// Get a Swift array from a Swish Expr, converting the elements.
    /// - Parameter mapElement: A function to convert each element to the Swift type you want
    /// - Returns: A Swift array of the type you converted to.
    func asArray<T>(_ mapElement: (Expr) -> T?) -> Array<T>? {
        guard let a = asArray() else { return nil }
        return a.compactMap { mapElement($0) }
    }

    static func toBool(_ expr: Expr) -> Bool? {
        expr.asBool()
    }

    func asBool() -> Bool? {
        if case let .boolean(b) = self {
            b
        }
        else {
            nil
        }
    }

    static func toCharacter(_ expr: Expr) -> Character? {
        expr.asCharacter()
    }

    func asCharacter() -> Character? {
        if case let .character(ch) = self {
            ch
        }
        else {
            nil
        }
    }

    static func toDate(_ expr: Expr) -> Date? {
        expr.asDate()
    }

    func asDate() -> Date? {
        if case let .inst(d) = self {
            d
        }
        else {
            nil
        }
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

    /// Get a Swift dictionary from a Swish map, record, or sortedMap, converting the elements.
    /// - Parameter mapKey: A function to convert each key to the Swift type you want
    /// - Parameter mapValue: A function to convert each value to the Swift type you want.
    /// - Returns: A Swift dictionary of the types you converted to.
    func asDictionary<K, V>(mapKey: (Expr) -> K?, mapValue: (Expr) -> V?) -> Dictionary<K, V>? {
        guard let d = asDictionary() else { return nil }
        var result: Dictionary<K, V> = [:]
        for (k, v) in d {
            if let key = mapKey(k), let newValue = mapValue(v) {
                result[key] = newValue
            }
        }
        return result
    }

    static func toDouble(_ expr: Expr) -> Double? {
        expr.asDouble()
    }

    func asDouble() -> Double? {
        switch self {
        case let .double(d):
            d

        case let .ratio(r):
            Double(r.numerator) / Double(r.denominator)

        default:
            nil
        }
    }

    static func toFloat(_ expr: Expr) -> Float? {
        expr.asFloat()
    }

    func asFloat() -> Float? {
        switch self {
        case let .float(f):
            f

        case let .ratio(r):
            Float(r.numerator) / Float(r.denominator)

        default:
            nil
        }
    }

    static func toInt(_ expr: Expr) -> Int? {
        expr.asInt()
    }

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

    private struct SwiftLazySequence: Sequence {
        public struct Iterator: IteratorProtocol {
            typealias Element = Expr
            private var current: Expr?

            init(box: LazySeqBox) {
                self.current = .lazySeq(box)
            }

            public mutating func next() -> Expr? {
                guard case let .lazySeq(box) = current else {
                    return nil
                }
                let value = try? box.forceHead()
                current = try? box.forceTail()
                return value
            }
        }

        let box: LazySeqBox

        public func makeIterator() -> Iterator {
            Iterator(box: box)
        }
    }
    
    /// Returns a Sequence for a Clojure seq or lazy seq
    /// - Returns: a sequence or nil if the Expr is not a seq or lazy seq
    func asSequence() -> (any Sequence<Expr>)? {
        switch self {
        case let .lazySeq(seq):
            SwiftLazySequence(box: seq)

        case let .seq(s):
            s

        default:
            nil
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
    /// - Parameter mapElement: A function to convert each element to the Swift type you want
    /// - Returns: A Swift set of the type you converted to.
    func asSet<T>(_ mapElement: (Expr) -> T?) -> Set<T>? {
        guard let s = asSet() else { return nil }
        return Set(s.compactMap(mapElement))
    }

    static func toString(_ expr: Expr) -> String? {
        expr.asString()
    }

    /// Get a Swift string from an Swish Expr.
    /// Strings can be made from Swish strings, symbols, and keywords
    /// - Returns: a Swift String
    func asString() -> String? {
        switch self {
        case let .string(s):    s
        case let .symbol(s, _): s
        case let .keyword(s):   s
        default:                nil
        }
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

    static func toUUID(_ expr: Expr) -> UUID? {
        expr.asUUID()
    }

    func asUUID() -> UUID? {
        if case let .uuid(u) = self {
            u
        }
        else {
            nil
        }
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
