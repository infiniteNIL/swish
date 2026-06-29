import Testing
@testable import SwishKit

@Suite("Core sorted-set Tests", .serialized)
struct CoreSortedSetTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("(sorted-set 3 1 2) seqs to (1 2 3)")
    func sortedSetOrders() throws {
        #expect(try swish.eval("(seq (sorted-set 3 1 2))") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(sorted-set 1 1 2 3) deduplicates")
    func sortedSetDeduplicates() throws {
        #expect(try swish.eval("(count (sorted-set 1 1 2 3))") == .integer(3))
    }

    @Test("(set? (sorted-set 1 2)) returns true")
    func sortedSetIsSet() throws {
        #expect(try swish.eval("(set? (sorted-set 1 2))") == .boolean(true))
    }

    @Test("(contains? (sorted-set 1 2 3) 2) returns true")
    func sortedSetContains() throws {
        #expect(try swish.eval("(contains? (sorted-set 1 2 3) 2)") == .boolean(true))
    }

    @Test("(contains? (sorted-set 1 2 3) 4) returns false")
    func sortedSetNotContains() throws {
        #expect(try swish.eval("(contains? (sorted-set 1 2 3) 4)") == .boolean(false))
    }

    @Test("(count (sorted-set 1 2 3)) returns 3")
    func sortedSetCount() throws {
        #expect(try swish.eval("(count (sorted-set 1 2 3))") == .integer(3))
    }

    @Test("(= (sorted-set 1 2) #{1 2}) returns true")
    func sortedSetEqualsHashSet() throws {
        #expect(try swish.eval("(= (sorted-set 1 2) #{1 2})") == .boolean(true))
    }

    @Test("(seq (conj (sorted-set 1 3) 2)) returns (1 2 3)")
    func sortedSetConj() throws {
        #expect(try swish.eval("(seq (conj (sorted-set 1 3) 2))") == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("(seq (disj (sorted-set 1 2 3) 2)) returns (1 3)")
    func sortedSetDisj() throws {
        #expect(try swish.eval("(seq (disj (sorted-set 1 2 3) 2))") == .list([.integer(1), .integer(3)], metadata: nil))
    }
}
