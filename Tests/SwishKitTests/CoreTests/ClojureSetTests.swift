import Testing
@testable import SwishKit

@Suite("clojure.set Tests", .serialized)
struct ClojureSetTests {
    nonisolated(unsafe) static let _shared: Swish = {
        let swish = Swish()
        _ = try? swish.eval("(require '[clojure.set :as s])")
        return swish
    }()
    var swish: Swish { Self._shared }

    @Test("union with no args returns empty set")
    func unionNoArgs() throws {
        #expect(try swish.eval("(s/union)") == .set([], metadata: nil))
    }

    @Test("union with one arg returns that set")
    func unionOneArg() throws {
        #expect(try swish.eval("(s/union #{1 2 3})") == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("union of two disjoint sets contains all elements")
    func unionDisjoint() throws {
        #expect(try swish.eval("(s/union #{1 2} #{3 4})") == .set([.integer(1), .integer(2), .integer(3), .integer(4)], metadata: nil))
    }

    @Test("union of overlapping sets removes duplicates")
    func unionOverlapping() throws {
        #expect(try swish.eval("(s/union #{1 2} #{2 3})") == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("union of identical sets returns the same set")
    func unionIdentical() throws {
        #expect(try swish.eval("(s/union #{1 2} #{1 2})") == .set([.integer(1), .integer(2)], metadata: nil))
    }

    @Test("union of three sets combines all elements")
    func unionThreeSets() throws {
        #expect(try swish.eval("(s/union #{1} #{2} #{3})") == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("union with an empty set returns the other set")
    func unionWithEmpty() throws {
        #expect(try swish.eval("(s/union #{1 2} #{})") == .set([.integer(1), .integer(2)], metadata: nil))
    }

    @Test("disj removes one element from a set")
    func disjOneElement() throws {
        #expect(try swish.eval("(disj #{1 2 3} 2)") == .set([.integer(1), .integer(3)], metadata: nil))
    }

    @Test("disj removes multiple elements from a set")
    func disjMultipleElements() throws {
        #expect(try swish.eval("(disj #{1 2 3} 1 3)") == .set([.integer(2)], metadata: nil))
    }

    @Test("disj with non-existent element returns the original set")
    func disjNonExistent() throws {
        #expect(try swish.eval("(disj #{1 2 3} 99)") == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("disj with one arg returns the set unchanged")
    func disjOneArg() throws {
        #expect(try swish.eval("(disj #{1 2 3})") == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("intersection of one set returns that set")
    func intersectionOneArg() throws {
        #expect(try swish.eval("(s/intersection #{1 2 3})") == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("intersection of two disjoint sets returns empty set")
    func intersectionDisjoint() throws {
        #expect(try swish.eval("(s/intersection #{1 2} #{3 4})") == .set([], metadata: nil))
    }

    @Test("intersection of overlapping sets returns shared elements")
    func intersectionOverlapping() throws {
        #expect(try swish.eval("(s/intersection #{1 2 3} #{2 3 4})") == .set([.integer(2), .integer(3)], metadata: nil))
    }

    @Test("intersection of three sets returns elements in all")
    func intersectionThreeSets() throws {
        #expect(try swish.eval("(s/intersection #{1 2 3} #{2 3 4} #{3 4 5})") == .set([.integer(3)], metadata: nil))
    }
}
