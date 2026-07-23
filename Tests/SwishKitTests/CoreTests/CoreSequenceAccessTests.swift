import Testing
@testable import SwishKit

@Suite("Core Sequence Access Tests", .serialized)
struct CoreSequenceAccessTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - second

    @Test("(second [1 2 3]) returns 2")
    func secondOfVector() throws {
        #expect(try swish.eval("(second [1 2 3])") == .integer(2))
    }

    @Test("(second '(10 20)) returns 20")
    func secondOfList() throws {
        #expect(try swish.eval("(second '(10 20))") == .integer(20))
    }

    @Test("(second '(1)) returns nil")
    func secondOfSingleton() throws {
        #expect(try swish.eval("(second '(1))") == .nil)
    }

    @Test("(second nil) returns nil")
    func secondOfNil() throws {
        #expect(try swish.eval("(second nil)") == .nil)
    }

    // MARK: - nnext

    @Test("(nnext [1 2 3]) returns (3)")
    func nnextThreeElems() throws {
        #expect(try swish.eval("(nnext [1 2 3])") == .list([.integer(3)], metadata: nil))
    }

    @Test("(nnext [1 2]) returns nil")
    func nnextTwoElems() throws {
        #expect(try swish.eval("(nnext [1 2])") == .nil)
    }

    @Test("(nnext [1]) returns nil")
    func nnextOneElem() throws {
        #expect(try swish.eval("(nnext [1])") == .nil)
    }

    // MARK: - empty?

    @Test("(empty? []) returns true")
    func emptyVector() throws {
        #expect(try swish.eval("(empty? [])") == .boolean(true))
    }

    @Test("(empty? [1]) returns false")
    func emptyNonEmptyVector() throws {
        #expect(try swish.eval("(empty? [1])") == .boolean(false))
    }

    @Test("(empty? '(1)) returns false")
    func emptyNonEmptyList() throws {
        #expect(try swish.eval("(empty? '(1))") == .boolean(false))
    }

    @Test("(empty? nil) returns true")
    func emptyNil() throws {
        #expect(try swish.eval("(empty? nil)") == .boolean(true))
    }

    @Test("(empty? '()) returns true")
    func emptyList() throws {
        #expect(try swish.eval("(empty? '())") == .boolean(true))
    }

    // MARK: - not-empty

    @Test("(not-empty [1 2]) returns [1 2]")
    func notEmptyVector() throws {
        #expect(try swish.eval("(not-empty [1 2])") == .vector([.integer(1), .integer(2)], metadata: nil))
    }

    @Test("(not-empty []) returns nil")
    func notEmptyEmptyVector() throws {
        #expect(try swish.eval("(not-empty [])") == .nil)
    }

    @Test("(not-empty nil) returns nil")
    func notEmptyNil() throws {
        #expect(try swish.eval("(not-empty nil)") == .nil)
    }

    @Test("(to-array [1 2 3]) returns an array")
    func toArrayReturnsArray() throws {
        let result = try swish.eval("(to-array [1 2 3])")
        guard case .array(let sa) = result else {
            Issue.record("Expected .array, got \(result)")
            return
        }
        #expect(sa.elements == [.integer(1), .integer(2), .integer(3)])
    }

    @Test("(get (to-array [1 2]) 0) returns first element")
    func toArrayGetFirst() throws {
        #expect(try swish.eval("(get (to-array [1 2]) 0)") == .integer(1))
    }

    @Test("(get (to-array [1 2]) 10) returns nil for out-of-bounds")
    func toArrayGetOutOfBounds() throws {
        #expect(try swish.eval("(get (to-array [1 2]) 10)") == .nil)
    }

    @Test("(object-array 3) is not a list")
    func objectArrayNotList() throws {
        #expect(try swish.eval("(list? (object-array 3))") == .boolean(false))
    }

    @Test("(array-map :a 1) is not a list")
    func arrayMapNotList() throws {
        #expect(try swish.eval("(list? (array-map :a 1))") == .boolean(false))
    }

    // MARK: - conj

    @Test("(conj) returns empty vector")
    func conjNoArgs() throws {
        #expect(try swish.eval("(conj)") == .vector([], metadata: nil))
    }

    @Test("(conj [1 2] 3) appends to vector")
    func conjVectorAppend() throws {
        #expect(try swish.eval("(conj [1 2] 3)") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    // MARK: - rseq

    @Test("(rseq [1 2 3]) returns reversed seq")
    func rseqVector() throws {
        #expect(try swish.eval("(rseq [1 2 3])") == .list([.integer(3), .integer(2), .integer(1)], metadata: nil))
    }

    @Test("(rseq []) returns nil")
    func rseqEmptyVector() throws {
        #expect(try swish.eval("(rseq [])") == .nil)
    }

    @Test("(rseq nil) throws")
    func rseqNilThrows() {
        #expect(throws: (any Error).self) { try swish.eval("(rseq nil)") }
    }

    @Test("(rseq (sorted-map :a 0 :b 1 :c 2)) returns reversed entries")
    func rseqSortedMap() throws {
        let result = try swish.eval("(rseq (sorted-map :a 0 :b 1 :c 2))")
        let expected = Expr.list([
            .vector([.keyword("c"), .integer(2)], metadata: nil),
            .vector([.keyword("b"), .integer(1)], metadata: nil),
            .vector([.keyword("a"), .integer(0)], metadata: nil),
        ], metadata: nil)
        #expect(result == expected)
    }

    @Test("(rseq (sorted-map)) returns nil")
    func rseqEmptySortedMap() throws {
        #expect(try swish.eval("(rseq (sorted-map))") == .nil)
    }

    @Test("(rseq (sorted-set 1 2 3)) returns reversed elements")
    func rseqSortedSet() throws {
        #expect(try swish.eval("(rseq (sorted-set 1 2 3))") == .list([.integer(3), .integer(2), .integer(1)], metadata: nil))
    }

    @Test("(rseq (sorted-set)) returns nil")
    func rseqEmptySortedSet() throws {
        #expect(try swish.eval("(rseq (sorted-set))") == .nil)
    }
}
