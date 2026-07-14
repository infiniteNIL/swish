import Testing
@testable import SwishKit

@Suite("clojure.set Tests", .serialized)
struct ClojureSetTests {
    static let _shared: Swish = {
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

    @Test("difference of one set returns that set")
    func differenceOneArg() throws {
        #expect(try swish.eval("(s/difference #{1 2 3})") == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("difference removes elements present in s2")
    func differenceOverlapping() throws {
        #expect(try swish.eval("(s/difference #{1 2 3} #{2 3})") == .set([.integer(1)], metadata: nil))
    }

    @Test("difference with disjoint s2 returns s1 unchanged")
    func differenceDisjoint() throws {
        #expect(try swish.eval("(s/difference #{1 2 3} #{4 5})") == .set([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("difference where s2 covers all of s1 returns empty set")
    func differenceAllRemoved() throws {
        #expect(try swish.eval("(s/difference #{1 2} #{1 2 3})") == .set([], metadata: nil))
    }

    @Test("difference of three sets removes from multiple")
    func differenceThreeSets() throws {
        #expect(try swish.eval("(s/difference #{1 2 3 4} #{2} #{3})") == .set([.integer(1), .integer(4)], metadata: nil))
    }

    @Test("subset? empty set is subset of any set")
    func subsetEmpty() throws {
        #expect(try swish.eval("(s/subset? #{} #{1 2 3})") == .boolean(true))
    }

    @Test("subset? proper subset returns true")
    func subsetProper() throws {
        #expect(try swish.eval("(s/subset? #{1 2} #{1 2 3})") == .boolean(true))
    }

    @Test("subset? identical sets returns true")
    func subsetIdentical() throws {
        #expect(try swish.eval("(s/subset? #{1 2} #{1 2})") == .boolean(true))
    }

    @Test("subset? set with extra element returns false")
    func subsetFalse() throws {
        #expect(try swish.eval("(s/subset? #{1 2 4} #{1 2 3})") == .boolean(false))
    }

    @Test("superset? any set is superset of empty set")
    func supersetEmpty() throws {
        #expect(try swish.eval("(s/superset? #{1 2 3} #{})") == .boolean(true))
    }

    @Test("superset? proper superset returns true")
    func supersetProper() throws {
        #expect(try swish.eval("(s/superset? #{1 2 3} #{1 2})") == .boolean(true))
    }

    @Test("superset? identical sets returns true")
    func supersetIdentical() throws {
        #expect(try swish.eval("(s/superset? #{1 2} #{1 2})") == .boolean(true))
    }

    @Test("superset? set missing element returns false")
    func supersetFalse() throws {
        #expect(try swish.eval("(s/superset? #{1 2} #{1 2 3})") == .boolean(false))
    }
}
