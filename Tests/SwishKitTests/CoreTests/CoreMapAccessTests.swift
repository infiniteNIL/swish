import Testing
@testable import SwishKit

@Suite("Core Map Access Tests", .serialized)
struct CoreMapAccessTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - keys

    @Test("(keys {:a 1}) returns list of keys")
    func keysReturnsKeys() throws {
        #expect(try swish.eval("(keys {:a 1})") == .list([.keyword("a")], metadata: nil))
    }

    @Test("(keys {}) returns nil for empty map")
    func keysEmptyMapReturnsNil() throws {
        #expect(try swish.eval("(keys {})") == .nil)
    }

    @Test("(keys nil) returns nil")
    func keysNilReturnsNil() throws {
        #expect(try swish.eval("(keys nil)") == .nil)
    }

    @Test("(keys 42) throws for non-map")
    func keysNonMapThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(keys 42)") }
    }

    // MARK: - vals

    @Test("(vals {:a 1}) returns list of values")
    func valsReturnsVals() throws {
        #expect(try swish.eval("(vals {:a 1})") == .list([.integer(1)], metadata: nil))
    }

    @Test("(vals {}) returns nil for empty map")
    func valsEmptyMapReturnsNil() throws {
        #expect(try swish.eval("(vals {})") == .nil)
    }

    @Test("(vals nil) returns nil")
    func valsNilReturnsNil() throws {
        #expect(try swish.eval("(vals nil)") == .nil)
    }

    @Test("(vals 42) throws for non-map")
    func valsNonMapThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(vals 42)") }
    }

    // MARK: - find

    @Test("(find {:a 1} :a) returns entry vector")
    func findExistingKey() throws {
        #expect(try swish.eval("(find {:a 1} :a)") == .vector([.keyword("a"), .integer(1)], metadata: nil))
    }

    @Test("(find {:a 1} :b) returns nil for missing key")
    func findMissingKey() throws {
        #expect(try swish.eval("(find {:a 1} :b)") == .nil)
    }

    @Test("(find {} :a) returns nil for empty map")
    func findEmptyMap() throws {
        #expect(try swish.eval("(find {} :a)") == .nil)
    }

    @Test("(find nil :a) returns nil")
    func findNilMap() throws {
        #expect(try swish.eval("(find nil :a)") == .nil)
    }

    @Test("(find 42 :a) throws on non-map")
    func findNonMapThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "find", message: "first argument must be a map, vector, or nil, got 42")) {
            try swish.eval("(find 42 :a)")
        }
    }

    // MARK: - key / val

    @Test("key returns key of a map entry")
    func keyReturnsKey() throws {
        #expect(try swish.eval("(key (first {:a 1}))") == .keyword("a"))
    }

    @Test("val returns value of a map entry")
    func valReturnsVal() throws {
        #expect(try swish.eval("(val (first {:a 1}))") == .integer(1))
    }

    @Test("key throws for a plain vector")
    func keyThrowsForVector() throws {
        #expect(throws: (any Error).self) { try swish.eval("(key [:a 1])") }
    }

    @Test("val throws for a plain vector")
    func valThrowsForVector() throws {
        #expect(throws: (any Error).self) { try swish.eval("(val [:a 1])") }
    }

    // MARK: - select-keys

    @Test("(select-keys {:a 1 :b 2 :c 3} [:a :c]) returns subset map")
    func selectKeysSubset() throws {
        #expect(try swish.eval("(select-keys {:a 1 :b 2 :c 3} [:a :c])") == .map([.keyword("a"): .integer(1), .keyword("c"): .integer(3)], metadata: nil))
    }

    @Test("(select-keys {:a 1} [:b]) returns empty map for no matches")
    func selectKeysNoMatch() throws {
        #expect(try swish.eval("(select-keys {:a 1} [:b])") == .map([:], metadata: nil))
    }

    @Test("(select-keys {:a 1} []) returns empty map for empty keys")
    func selectKeysEmptyKeys() throws {
        #expect(try swish.eval("(select-keys {:a 1} [])") == .map([:], metadata: nil))
    }

    @Test("(select-keys nil [:a]) returns empty map for nil map")
    func selectKeysNilMap() throws {
        #expect(try swish.eval("(select-keys nil [:a])") == .map([:], metadata: nil))
    }

    // MARK: - merge-with

    @Test("(merge-with + {:a 1} {:a 2}) merges with combining fn")
    func mergeWithCombines() throws {
        #expect(try swish.eval("(merge-with + {:a 1} {:a 2})") == .map([.keyword("a"): .integer(3)], metadata: nil))
    }

    @Test("(merge-with + {:a 1 :b 2} {:a 3}) combines only overlapping keys")
    func mergeWithPartialOverlap() throws {
        #expect(try swish.eval("(merge-with + {:a 1 :b 2} {:a 3})") == .map([.keyword("a"): .integer(4), .keyword("b"): .integer(2)], metadata: nil))
    }

    @Test("(merge-with + {:a 1} {:b 2}) passes through non-overlapping keys")
    func mergeWithNoOverlap() throws {
        #expect(try swish.eval("(merge-with + {:a 1} {:b 2})") == .map([.keyword("a"): .integer(1), .keyword("b"): .integer(2)], metadata: nil))
    }

    @Test("(merge-with + {:a 1} nil) treats nil map as absent")
    func mergeWithNilSecond() throws {
        #expect(try swish.eval("(merge-with + {:a 1} nil)") == .map([.keyword("a"): .integer(1)], metadata: nil))
    }

    @Test("(merge-with + nil {:a 1}) treats nil first map as empty")
    func mergeWithNilFirst() throws {
        #expect(try swish.eval("(merge-with + nil {:a 1})") == .map([.keyword("a"): .integer(1)], metadata: nil))
    }

    @Test("(merge-with + nil nil) returns nil")
    func mergeWithAllNil() throws {
        #expect(try swish.eval("(merge-with + nil nil)") == .nil)
    }

    @Test("(find [] nil) returns nil")
    func findEmptyVectorNilKey() throws {
        #expect(try swish.eval("(find [] nil)") == .nil)
    }

    @Test("(find [10 20 30] 1) returns [1 20]")
    func findVectorValidIndex() throws {
        #expect(try swish.eval("(find [10 20 30] 1)") == .vector([.integer(1), .integer(20)], metadata: nil))
    }

    @Test("(find [1 2 3] 5) returns nil for out-of-bounds index")
    func findVectorOutOfBounds() throws {
        #expect(try swish.eval("(find [1 2 3] 5)") == .nil)
    }

    @Test("(find [1 2 3] -1) returns nil for negative index")
    func findVectorNegativeIndex() throws {
        #expect(try swish.eval("(find [1 2 3] -1)") == .nil)
    }

    @Test("(find [1 2 3] :a) returns nil for non-integer key")
    func findVectorNonIntegerKey() throws {
        #expect(try swish.eval("(find [1 2 3] :a)") == .nil)
    }

    @Test("(keys []) returns nil for empty vector")
    func keysVector() throws {
        #expect(try swish.eval("(keys [])") == .nil)
    }

    @Test("(keys '()) returns nil for empty list")
    func keysList() throws {
        #expect(try swish.eval("(keys '())") == .nil)
    }

    @Test("(keys #{}) returns nil for empty set")
    func keysSet() throws {
        #expect(try swish.eval("(keys #{})") == .nil)
    }

    @Test("(keys \"\") returns nil for empty string")
    func keysString() throws {
        #expect(try swish.eval("(keys \"\")") == .nil)
    }
}
