import Foundation
import BigInt
import BigDecimal

// MARK: - Murmur3 (a verbatim port of clojure.lang.Murmur3)

// Clojure's `hash` is `Util.hasheq`, a deterministic 32-bit MurmurHash3-based
// algorithm. It CANNOT reuse Swish's `Expr.hash(into:)` (Swift's `Hasher` is seeded
// randomly per process, so those values are unstable across runs and don't match
// Clojure). This is a standalone port so `(hash x)` returns Clojure-matching,
// run-stable ints. All arithmetic is 32-bit with Java's wrapping/`>>>` semantics.
private enum Murmur3 {
    static let seed: Int32 = 0
    static let c1 = Int32(bitPattern: 0xcc9e2d51)
    static let c2 = Int32(bitPattern: 0x1b873593)

    /// Java `Integer.rotateLeft` — a logical (unsigned) rotate.
    static func rotl(_ x: Int32, _ n: UInt32) -> Int32 {
        let u = UInt32(bitPattern: x)
        return Int32(bitPattern: (u << n) | (u >> (32 - n)))
    }

    /// Java `>>>` — logical (zero-filling) right shift.
    static func ushr(_ x: Int32, _ n: UInt32) -> Int32 {
        Int32(bitPattern: UInt32(bitPattern: x) >> n)
    }

    static func mixK1(_ k1In: Int32) -> Int32 {
        var k1 = k1In
        k1 = k1 &* c1
        k1 = rotl(k1, 15)
        k1 = k1 &* c2
        return k1
    }

    static func mixH1(_ h1In: Int32, _ k1: Int32) -> Int32 {
        var h1 = h1In
        h1 ^= k1
        h1 = rotl(h1, 13)
        h1 = h1 &* 5 &+ Int32(bitPattern: 0xe6546b64)
        return h1
    }

    static func fmix(_ h1In: Int32, _ length: Int32) -> Int32 {
        var h1 = h1In
        h1 ^= length
        h1 ^= ushr(h1, 16)
        h1 = h1 &* Int32(bitPattern: 0x85ebca6b)
        h1 ^= ushr(h1, 13)
        h1 = h1 &* Int32(bitPattern: 0xc2b2ae35)
        h1 ^= ushr(h1, 16)
        return h1
    }

    static func hashInt(_ input: Int32) -> Int32 {
        if input == 0 {
            return 0
        }
        let k1 = mixK1(input)
        let h1 = mixH1(seed, k1)
        return fmix(h1, 4)
    }

    static func hashLong(_ input: Int64) -> Int32 {
        if input == 0 {
            return 0
        }
        let low = Int32(truncatingIfNeeded: input)
        let high = Int32(truncatingIfNeeded: input >> 32)
        var k1 = mixK1(low)
        var h1 = mixH1(seed, k1)
        k1 = mixK1(high)
        h1 = mixH1(h1, k1)
        return fmix(h1, 8)
    }

    static func mixCollHash(_ hash: Int32, _ count: Int32) -> Int32 {
        var h1 = seed
        let k1 = mixK1(hash)
        h1 = mixH1(h1, k1)
        return fmix(h1, count)
    }

    static func hashOrdered<S: Sequence>(_ xs: S) -> Int32 where S.Element == Expr {
        var n: Int32 = 0
        var hash: Int32 = 1
        for x in xs {
            hash = 31 &* hash &+ swishHasheq(x)
            n &+= 1
        }
        return mixCollHash(hash, n)
    }

    static func hashUnordered<S: Sequence>(_ xs: S) -> Int32 where S.Element == Expr {
        var hash: Int32 = 0
        var n: Int32 = 0
        for x in xs {
            hash = hash &+ swishHasheq(x)
            n &+= 1
        }
        return mixCollHash(hash, n)
    }

    /// Java `Murmur3.hashUnencodedChars` — hashes a string's UTF-16 units two at a
    /// time. Backs symbol/keyword hashing.
    static func hashUnencodedChars(_ s: String) -> Int32 {
        var h1 = seed
        let units = Array(s.utf16)
        let len = units.count
        var i = 1
        while i < len {
            let k1 = Int32(bitPattern: UInt32(units[i - 1]) | (UInt32(units[i]) << 16))
            h1 = mixH1(h1, mixK1(k1))
            i += 2
        }
        if len & 1 == 1 {
            let k1 = mixK1(Int32(bitPattern: UInt32(units[len - 1])))
            h1 ^= k1
        }
        return fmix(h1, Int32(truncatingIfNeeded: 2 * len))
    }
}

// MARK: - Java primitive hashCodes

/// Java `String.hashCode`: `s[0]*31^(n-1) + … + s[n-1]` over UTF-16 code units
/// (matching Java `char`s), in 32-bit wrapping arithmetic. Empty → 0.
private func javaStringHashCode(_ s: String) -> Int32 {
    var h: Int32 = 0
    for u in s.utf16 {
        h = 31 &* h &+ Int32(u)
    }
    return h
}

/// Java `hashCombine` (boost-style). `>> 2` is arithmetic (signed), matching Java `>>`.
private func hashCombine(_ seedIn: Int32, _ hash: Int32) -> Int32 {
    var seed = seedIn
    seed ^= hash &+ Int32(bitPattern: 0x9e3779b9) &+ (seed << 6) &+ (seed >> 2)
    return seed
}

/// Splits a Swish `"ns/name"` string into `(ns, name)`; `ns` is nil when unqualified.
private func splitNamed(_ s: String) -> (ns: String?, name: String) {
    guard let slash = s.firstIndex(of: "/"), slash != s.startIndex else {
        return (nil, s)
    }
    return (String(s[..<slash]), String(s[s.index(after: slash)...]))
}

/// `clojure.lang.Symbol.hasheq` = `hashCombine(Murmur3.hashUnencodedChars(name), Util.hash(ns))`,
/// where `Util.hash(ns)` is `0` for a nil ns else Java `String.hashCode`.
private func symbolHasheq(_ qualified: String) -> Int32 {
    let (ns, name) = splitNamed(qualified)
    let nameHash = Murmur3.hashUnencodedChars(name)
    let nsHash = ns.map(javaStringHashCode) ?? 0
    return hashCombine(nameHash, nsHash)
}

/// `clojure.lang.Keyword.hasheq` = `sym.hasheq() + 0x9e3779b9`.
private func keywordHasheq(_ qualified: String) -> Int32 {
    symbolHasheq(qualified) &+ Int32(bitPattern: 0x9e3779b9)
}

/// Java `BigInteger.hashCode`: fold `h = 31*h + word` over the magnitude's 32-bit
/// big-endian words, then multiply by signum. Exact — so ratios of int-range
/// numerator/denominator hash exactly too (e.g. `(hash 1/3)` = `1 ^ 3` = `2`).
private func bigIntegerHashCode(_ v: BigInt) -> Int32 {
    if v == 0 {
        return 0
    }
    let bytes = [UInt8](v.magnitude.serialize())
    var padded = bytes
    while padded.count % 4 != 0 {
        padded.insert(0, at: 0)
    }
    var h: Int32 = 0
    var i = 0
    while i < padded.count {
        let word = (UInt32(padded[i]) << 24) | (UInt32(padded[i + 1]) << 16)
            | (UInt32(padded[i + 2]) << 8) | UInt32(padded[i + 3])
        h = 31 &* h &+ Int32(bitPattern: word)
        i += 4
    }
    return v.sign == .minus ? (0 &- h) : h
}

/// `Numbers.hasheq` for a Double: `-0.0` → `0`; else Java `Double.hashCode`
/// (`(int)(bits ^ (bits >>> 32))`). NaN uses Swift's raw bit pattern (Java canonicalizes
/// NaN in `doubleToLongBits`) — a negligible edge for a value that isn't `=` to itself.
private func doubleHasheq(_ d: Double) -> Int32 {
    if d == 0.0 {
        return 0
    }
    let bits = d.bitPattern
    return Int32(truncatingIfNeeded: bits ^ (bits >> 32))
}

/// `Numbers.hasheq` for a Float: `-0.0f` → `0`; else Java `Float.hashCode` (`floatToIntBits`).
private func floatHasheq(_ f: Float) -> Int32 {
    if f == 0.0 {
        return 0
    }
    return Int32(bitPattern: f.bitPattern)
}

// MARK: - hasheq dispatch (clojure.lang.Util.hasheq)

/// Deterministic Clojure `hasheq` for a Swish value. Faithful for the types programs
/// actually hash (numbers, strings, chars, keywords/symbols, ordered/unordered
/// collections). Records/deftypes/BigDecimal/opaque-reference values are documented
/// approximations (several are non-deterministic identity hashes in Clojure itself).
func swishHasheq(_ expr: Expr) -> Int32 {
    switch expr {
    case .nil:
        return 0

    case .boolean(let b):
        return b ? 1231 : 1237

    case .integer(let n):
        return Murmur3.hashLong(Int64(n))

    case .double(let d):
        return doubleHasheq(d)

    case .float(let f):
        return floatHasheq(f)

    case .ratio(let r):
        return bigIntegerHashCode(r.numerator) ^ bigIntegerHashCode(r.denominator)

    case .bigInteger(let v):
        if let i = Int64(exactly: v) {
            return Murmur3.hashLong(i)
        }
        return bigIntegerHashCode(v)

    case .bigDecimal(let v):
        return bigDecimalHasheq(v)

    case .string(let s):
        return Murmur3.hashInt(javaStringHashCode(s))

    case .character(let c):
        return Int32(c.unicodeScalars.first?.value ?? 0)

    case .keyword(let k):
        return keywordHasheq(k)

    case .symbol(let s, _):
        return symbolHasheq(s)

    case .list(let l, _):
        return Murmur3.hashOrdered(l)

    case .seq(let elements):
        return Murmur3.hashOrdered(elements)

    case .vector(let v, _):
        return Murmur3.hashOrdered(v.elements)

    case .sharedVector(let sa, _):
        return Murmur3.hashOrdered(sa.elements)

    case .mapEntry(let k, let v):
        return Murmur3.hashOrdered([k, v])

    case .lazySeq:
        // Clojure realizes lazy seqs when hashing (so a lazy seq hashes the same as
        // an =-equal concrete list). Infinite seqs hang here, exactly as in Clojure.
        return Murmur3.hashOrdered((try? asSequence(expr)) ?? [])

    case .map(let sm):
        return mapHasheq(sm.dict.map { ($0.key, $0.value) })

    case .sortedMap(let ssm):
        return mapHasheq(ssm.asDictionary.map { ($0.key, $0.value) })

    case .set(let s):
        return Murmur3.hashUnordered(s.elements)

    case .sortedSet(let sss):
        return Murmur3.hashUnordered(sss.elements)

    case .record(let typeName, _, let data, _):
        // Approximation of defrecord's generated hasheq: combine the field map's hash
        // with the type name (Clojure mixes the type in; the exact bit layout isn't
        // replicated). Deterministic and =-consistent for records of the same type.
        return hashCombine(mapHasheq(data.map { ($0.key, $0.value) }), javaStringHashCode(typeName))

    default:
        // Opaque / reference values (functions, atoms, refs, vars, namespaces, regex,
        // reader/writer, delay/agent/future/promise, transient, matcher, reduced,
        // array, deftype). Clojure hashes these by non-deterministic identity, so no
        // deterministic value can match; return a stable per-kind constant so `hash`
        // never crashes. Documented in CLAUDE.md.
        return opaqueHasheq(expr)
    }
}

private func mapHasheq<S: Sequence>(_ entries: S) -> Int32 where S.Element == (Expr, Expr) {
    var hash: Int32 = 0
    var count: Int32 = 0
    for (k, v) in entries {
        hash = hash &+ (swishHasheq(k) ^ swishHasheq(v))
        count &+= 1
    }
    return Murmur3.mixCollHash(hash, count)
}

/// Swish's BigDecimal package has no Java-`BigDecimal.hashCode` equivalent, so this is a
/// documented approximation: `31 * hasheq(unscaled) + scale` (the shape of Java's
/// inflated-form hashCode). Deterministic and `=`-consistent within Swish; not
/// guaranteed to equal Clojure's value (BigDecimal is very rarely hashed).
private func bigDecimalHasheq(_ v: BigDecimal) -> Int32 {
    31 &* bigIntegerHashCode(v.integerValue) &+ Int32(truncatingIfNeeded: v.scale)
}

/// A stable per-kind constant for opaque/reference values (see the `default` note).
private func opaqueHasheq(_ expr: Expr) -> Int32 {
    switch expr {
    case .deftype(let t, _, let d, let box, _):
        // Mutable-bearing deftypes are identity in Swish's `=`; without a stable
        // identity int, fall back to the type-name hash. Immutable deftypes get a
        // value hash consistent with their `=`.
        if box != nil {
            return javaStringHashCode(t)
        }
        return hashCombine(mapHasheq(d.map { ($0.key, $0.value) }), javaStringHashCode(t))

    default:
        return javaStringHashCode(expr.description)
    }
}

// MARK: - Registration

func registerHash(into evaluator: Evaluator) {
    evaluator.register(name: "hash", arity: .fixed(1),
        doc: "Returns the hash code of its argument. Consistent with =, matching Clojure's hasheq.",
        arglists: [["x"]]) { args in
        .integer(Int(swishHasheq(args[0])))
    }
    evaluator.register(name: "hash-ordered-coll", arity: .fixed(1),
        doc: "Returns the hash code, consistent with =, for an external ordered collection implementing Iterable. See http://clojure.org/data_structures#hash for full algorithms.",
        arglists: [["coll"]]) { args in
        let elements = (try? asSequence(args[0])) ?? []
        return .integer(Int(Murmur3.hashOrdered(elements)))
    }
    evaluator.register(name: "hash-unordered-coll", arity: .fixed(1),
        doc: "Returns the hash code, consistent with =, for an external unordered collection implementing Iterable. For maps, the iterator should return map entries whose hash is computed as (hash-ordered-coll [k v]). See http://clojure.org/data_structures#hash for full algorithms.",
        arglists: [["coll"]]) { args in
        let elements = (try? asSequence(args[0])) ?? []
        return .integer(Int(Murmur3.hashUnordered(elements)))
    }
    evaluator.register(name: "mix-collection-hash", arity: .fixed(2),
        doc: "Mix final collection hash for ordered or unordered collections. hash-basis is the accumulated hash code, count is the number of elements included in the basis. Note this is the hash code consistent with =, different from .hashCode. See http://clojure.org/data_structures#hash for full algorithms.",
        arglists: [["hash-basis", "count"]]) { args in
        guard case .integer(let basis) = args[0], case .integer(let count) = args[1] else {
            throw EvaluatorError.invalidArgument(function: "mix-collection-hash", message: "both arguments must be integers")
        }
        return .integer(Int(Murmur3.mixCollHash(Int32(truncatingIfNeeded: basis), Int32(truncatingIfNeeded: count))))
    }
}
