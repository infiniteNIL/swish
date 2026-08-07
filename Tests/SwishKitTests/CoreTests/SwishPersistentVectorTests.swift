import Testing
@testable import SwishKit

@Suite("SwishPersistentVector Tests")
struct SwishPersistentVectorTests {

    private func build(_ n: Int) -> SwishPersistentVector {
        var v = SwishPersistentVector()
        for i in 0..<n { v = v.conj(.integer(i)) }
        return v
    }

    @Test("conj + subscript + count round-trip across level boundaries",
          arguments: [0, 1, 31, 32, 33, 63, 64, 1023, 1024, 1025, 2048, 32768, 32800])
    func conjSubscriptCount(_ n: Int) throws {
        let v = build(n)
        #expect(v.count == n)
        for i in 0..<n {
            #expect(v[i] == .integer(i))
        }
        #expect(v.elements == (0..<n).map { .integer($0) })
        #expect(v.first == (n == 0 ? nil : .integer(0)))
        #expect(v.last == (n == 0 ? nil : .integer(n - 1)))
        #expect(v.isEmpty == (n == 0))
    }

    @Test("assoc updates one index and shares the rest, across boundaries",
          arguments: [1, 32, 33, 1024, 1025, 2000])
    func assoc(_ n: Int) throws {
        var v = build(n)
        // Update a spread of indices to values (i * 10).
        let targets = Set([0, n / 2, n - 1, min(31, n - 1), min(32, n - 1), min(1024, n - 1)].filter { $0 >= 0 && $0 < n })
        for i in targets { v = v.with(index: i, .integer(i * 10)) }
        for i in 0..<n {
            #expect(v[i] == .integer(targets.contains(i) ? i * 10 : i))
        }
        #expect(v.count == n)
    }

    @Test("pop back down to empty keeps count/last/elements correct",
          arguments: [1, 32, 33, 1024, 1025, 2050])
    func popToEmpty(_ n: Int) throws {
        var v = build(n)
        for k in stride(from: n, to: 0, by: -1) {
            #expect(v.count == k)
            #expect(v.last == .integer(k - 1))
            #expect(v[k - 1] == .integer(k - 1))
            v = v.popLast()
        }
        #expect(v.isEmpty)
        #expect(v.count == 0)
    }

    @Test("conj is non-destructive (structural sharing preserves the original)")
    func conjNonDestructive() throws {
        let a = build(100)
        let b = a.conj(.integer(999))
        #expect(a.count == 100)
        #expect(b.count == 101)
        #expect(a[99] == .integer(99))
        #expect(b[100] == .integer(999))
        #expect(a.elements == (0..<100).map { .integer($0) })
    }

    @Test("equality and hashing are element-wise")
    func equalityHashing() throws {
        let a = build(1025)
        let b = build(1025)
        let c = a.conj(.integer(-1))
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
        // built from array literal / [Expr] matches conj-built
        #expect(SwishPersistentVector([.integer(0), .integer(1), .integer(2)]) == build(3))
    }

    @Test("Collection conformance: map / for-in / Array(...) / reversed")
    func collectionConformance() throws {
        let v = build(100)
        #expect(Array(v) == (0..<100).map { .integer($0) })
        #expect(v.map { $0 } == (0..<100).map { .integer($0) })
        var seen = [Expr]()
        for e in v { seen.append(e) }
        #expect(seen == (0..<100).map { .integer($0) })
        #expect(Array(v.reversed()) == (0..<100).reversed().map { .integer($0) })
    }

    // MARK: - The leaf-walking iterator
    //
    // `makeIterator` walks stored leaves rather than materializing `elements`, refilling a
    // cached leaf whenever the index crosses its boundary. The sizes below straddle every
    // boundary that matters: the 32-element tail, the first full trie leaf, and the level
    // growth at 1024.

    @Test("Iteration yields every element in order, across all leaf/level boundaries",
          arguments: [0, 1, 31, 32, 33, 63, 64, 65, 1023, 1024, 1025, 2048])
    func iteratorAcrossBoundaries(_ n: Int) throws {
        let v = build(n)
        var seen = [Expr]()
        var it = v.makeIterator()
        while let e = it.next() { seen.append(e) }
        #expect(seen == (0..<n).map { .integer($0) })
        // And it agrees with the materializing path and with per-index subscripting.
        #expect(seen == v.elements)
        #expect(seen == (0..<n).map { v[$0] })
    }

    @Test("A fresh iterator restarts from the beginning; an exhausted one keeps returning nil")
    func iteratorRestartAndExhaustion() throws {
        let v = build(40)
        #expect(Array(v) == Array(v))
        var it = v.makeIterator()
        while it.next() != nil {}
        #expect(it.next() == nil)
        #expect(it.next() == nil)
    }

    @Test("A partially-consumed iterator has taken exactly the prefix it reported")
    func iteratorPartialConsumption() throws {
        let v = build(1025)
        var it = v.makeIterator()
        var prefix = [Expr]()
        for _ in 0..<40 {
            guard let e = it.next() else { break }
            prefix.append(e)
        }
        #expect(prefix == (0..<40).map { .integer($0) })
        #expect(it.next() == .integer(40))
    }

    @Test("== bails on the first mismatch and still answers correctly wherever it is",
          arguments: [0, 500, 1024])
    func equalityEarlyExit(_ differingIndex: Int) throws {
        let n = 1025
        let a = build(n)
        let b = a.with(index: differingIndex, .integer(-1))
        #expect(a != b)
        #expect(b != a)
        #expect(a == build(n))
    }

    @Test("Vectors of different lengths are unequal without comparing elements")
    func equalityDifferentLengths() throws {
        #expect(build(1024) != build(1025))
        #expect(build(0) != build(1))
        #expect(build(0) == SwishPersistentVector())
    }
}
