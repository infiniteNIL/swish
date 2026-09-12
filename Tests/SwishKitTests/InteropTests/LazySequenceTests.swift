import Testing
@testable import SwishKit

@Suite("Interop: lazy sequences")
struct LazySequenceTests {
    @Test("prefix reads a bounded slice of an infinite seq")
    func prefixOfInfiniteSeq() throws {
        let swish = Swish()
        let naturals = try swish.eval("(range)")

        #expect(try naturals.prefix(5, of: Int.self) == [0, 1, 2, 3, 4])
        #expect(try naturals.prefix(0, of: Int.self) == [])
        // A fresh evaluation of the same infinite source, to prove nothing was
        // consumed destructively.
        #expect(try swish.eval("(map inc (range))").prefix(3, of: Int.self) == [1, 2, 3])
    }

    @Test("prefix past the end returns what there is")
    func prefixBeyondEnd() throws {
        let swish = Swish()

        #expect(try swish.eval("(range 3)").prefix(10, of: Int.self) == [0, 1, 2])
        #expect(try swish.eval("[1 2]").prefix(10, of: Int.self) == [1, 2])
        #expect(try swish.eval("'()").prefix(10, of: Int.self) == [])
    }

    @Test("forEach streams an infinite seq and stops when the body throws")
    func forEachStopsOnThrow() throws {
        let swish = Swish()
        struct Enough: Error {}

        var seen: [Int] = []
        do {
            try swish.eval("(range)").forEach(of: Int.self) { n in
                seen.append(n)
                if n == 4 {
                    throw Enough()
                }
            }
            Issue.record("Expected the body's throw to propagate")
        }
        catch is Enough {
            #expect(seen == [0, 1, 2, 3, 4])
        }
    }

    @Test("forEach reports an element that isn't the requested type")
    func forEachReportsBadElement() throws {
        let swish = Swish()

        #expect(throws: SwishConversionError.self) {
            try swish.eval(#"[1 2 "three"]"#).forEach(of: Int.self) { _ in }
        }
        #expect(throws: SwishConversionError.self) {
            try swish.eval(#"(list 1 "two")"#).prefix(5, of: Int.self)
        }
    }

    @Test("forEach covers eager collections too")
    func forEachOnEagerCollections() throws {
        let swish = Swish()

        for source in ["[1 2 3]", "'(1 2 3)", "(range 1 4)", "(seq [1 2 3])"] {
            var seen: [Int] = []
            try swish.eval(source).forEach(of: Int.self) { seen.append($0) }
            #expect(seen == [1, 2, 3], "failed for \(source)")
        }
    }

    @Test("lazySequence covers eager collections, not just lazy seqs")
    func lazySequenceCoversEagerCollections() throws {
        let swish = Swish()

        // A vector, list or seq has nothing to realize; yielding nothing for one
        // would be exactly the silent emptiness this type exists to avoid.
        for source in ["[1 2 3]", "'(1 2 3)", "(seq [1 2 3])", "(range 1 4)", "(map inc [0 1 2])"] {
            let elements = Array(try swish.eval(source).lazySequence(of: Int.self))
            #expect(elements == [1, 2, 3], "failed for \(source)")
        }
    }

    @Test("A non-sequential value reports a failure rather than looking empty")
    func nonSequentialReportsFailure() throws {
        let swish = Swish()

        var iterator = try swish.eval("42").lazySequence(of: Int.self).makeIterator()
        #expect(iterator.next() == nil)
        #expect(iterator.failure is SwishConversionError)
    }

    @Test("An undecodable element in an eager collection stops and records why")
    func eagerBadElementRecordsFailure() throws {
        let swish = Swish()

        var iterator = try swish.eval(#"[1 "two" 3]"#).lazySequence(of: Int.self).makeIterator()
        #expect(iterator.next() == 1)
        #expect(iterator.next() == nil)
        #expect(iterator.failure is SwishConversionError)
    }

    @Test("lazySequence supports for-in and reports why it stopped")
    func lazySequenceReportsFailure() throws {
        let swish = Swish()

        var iterator = try swish.eval("(range)").lazySequence(of: Int.self).makeIterator()
        var taken: [Int] = []
        while taken.count < 3, let n = iterator.next() {
            taken.append(n)
        }
        #expect(taken == [0, 1, 2])
        #expect(iterator.failure == nil)

        // A bad element stops iteration and records why, instead of looking like
        // the end of the sequence.
        var bad = try swish.eval(#"(map identity [1 "two" 3])"#).lazySequence(of: Int.self).makeIterator()
        #expect(bad.next() == 1)
        #expect(bad.next() == nil)
        #expect(bad.failure is SwishConversionError)
    }

    @Test("A lazy seq that ends normally leaves no failure")
    func cleanTermination() throws {
        let swish = Swish()

        var iterator = try swish.eval("(map inc [1 2 3])").lazySequence(of: Int.self).makeIterator()
        var seen: [Int] = []
        while let n = iterator.next() {
            seen.append(n)
        }
        #expect(seen == [2, 3, 4])
        #expect(iterator.failure == nil)
    }

    @Test("asSequence stays lazy on a lazy seq")
    func asSequenceStaysLazy() throws {
        let swish = Swish()
        guard let seq = try swish.eval("(range)").asSequence() else {
            Issue.record("Expected a sequence")
            return
        }
        var taken: [Expr] = []
        for element in seq {
            taken.append(element)
            if taken.count == 4 {
                break
            }
        }
        #expect(taken == [.integer(0), .integer(1), .integer(2), .integer(3)])
    }
}
