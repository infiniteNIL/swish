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
}
