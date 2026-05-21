import Testing
@testable import SwishKit

@Suite("Core Map Tests")
struct CoreMapTests {
    let swish = Swish()

    // MARK: - get on map

    @Test("(get {:a 1} :a) returns value for existing key")
    func getMapExistingKey() throws {
        #expect(try swish.eval("(get {:a 1} :a)") == .integer(1))
    }

    @Test("(get {:a 1} :b) returns nil for missing key")
    func getMapMissingKey() throws {
        #expect(try swish.eval("(get {:a 1} :b)") == .nil)
    }

    @Test("(get {:a 1} :b 99) returns default for missing key")
    func getMapMissingKeyWithDefault() throws {
        #expect(try swish.eval("(get {:a 1} :b 99)") == .integer(99))
    }

    // MARK: - get on vector

    @Test("(get [] 0) returns nil for empty vector")
    func getEmptyVector() throws {
        #expect(try swish.eval("(get [] 0)") == .nil)
    }

    @Test("(get [:a :b :c] 1) returns element at index")
    func getVectorValidIndex() throws {
        #expect(try swish.eval("(get [:a :b :c] 1)") == .keyword("b"))
    }

    @Test("(get [:a :b :c] 5) returns nil for out-of-bounds index")
    func getVectorOutOfBounds() throws {
        #expect(try swish.eval("(get [:a :b :c] 5)") == .nil)
    }

    @Test("(get [:a :b :c] 5 :default) returns default for out-of-bounds")
    func getVectorOutOfBoundsWithDefault() throws {
        #expect(try swish.eval("(get [:a :b :c] 5 :default)") == .keyword("default"))
    }

    @Test("(get [:a :b :c] -1) returns nil for negative index")
    func getVectorNegativeIndex() throws {
        #expect(try swish.eval("(get [:a :b :c] -1)") == .nil)
    }

    // MARK: - get on string

    @Test("(get \"hello\" 0) returns first character")
    func getStringValidIndex() throws {
        #expect(try swish.eval("(get \"hello\" 0)") == .character("h"))
    }

    @Test("(get \"hello\" 10) returns nil for out-of-bounds")
    func getStringOutOfBounds() throws {
        #expect(try swish.eval("(get \"hello\" 10)") == .nil)
    }

    @Test("(get \"hello\" 0 :x) returns character when found, ignores default")
    func getStringWithUnusedDefault() throws {
        #expect(try swish.eval("(get \"hello\" 0 :x)") == .character("h"))
    }

    // MARK: - get on nil

    @Test("(get nil :k) returns nil")
    func getNilNoDefault() throws {
        #expect(try swish.eval("(get nil :k)") == .nil)
    }

    @Test("(get nil :k 42) returns default")
    func getNilWithDefault() throws {
        #expect(try swish.eval("(get nil :k 42)") == .integer(42))
    }

    // MARK: - get on unsupported type

    @Test("(get 42 :k) returns nil for unsupported type")
    func getUnsupportedType() throws {
        #expect(try swish.eval("(get 42 :k)") == .nil)
    }

    // MARK: - arity errors

    @Test("(get) throws on zero args")
    func getZeroArgs() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "get", message: "requires 2 or 3 arguments, got 0")) {
            try swish.eval("(get)")
        }
    }

    @Test("(get {:a 1}) throws on one arg")
    func getOneArg() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "get", message: "requires 2 or 3 arguments, got 1")) {
            try swish.eval("(get {:a 1})")
        }
    }

    @Test("(get {:a 1} :a :b :c) throws on four args")
    func getFourArgs() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "get", message: "requires 2 or 3 arguments, got 4")) {
            try swish.eval("(get {:a 1} :a :b :c)")
        }
    }

    // MARK: - map as function

    @Test("({:a 1 :b 2} :a) returns value for existing key")
    func mapAsFunctionExistingKey() throws {
        #expect(try swish.eval("({:a 1 :b 2} :a)") == .integer(1))
    }

    @Test("({:a 1 :b 2} :c) returns nil for missing key")
    func mapAsFunctionMissingKey() throws {
        #expect(try swish.eval("({:a 1 :b 2} :c)") == .nil)
    }

    @Test("({:a 1 :b 2} :c 99) returns default for missing key")
    func mapAsFunctionMissingKeyWithDefault() throws {
        #expect(try swish.eval("({:a 1 :b 2} :c 99)") == .integer(99))
    }

    @Test("({} :k) returns nil for empty map")
    func mapAsFunctionEmptyMap() throws {
        #expect(try swish.eval("({} :k)") == .nil)
    }

    @Test("({0 \"zero\"} 0) key is evaluated before lookup")
    func mapAsFunctionEvaluatedKey() throws {
        #expect(try swish.eval("({0 \"zero\"} (+ 0 0))") == .string("zero"))
    }

    @Test("({:a 1}) throws on zero args")
    func mapAsFunctionZeroArgs() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "map", message: "requires 1 or 2 arguments, got 0")) {
            try swish.eval("({:a 1})")
        }
    }

    @Test("({:a 1} :a :b :c) throws on three args")
    func mapAsFunctionThreeArgs() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "map", message: "requires 1 or 2 arguments, got 3")) {
            try swish.eval("({:a 1} :a :b :c)")
        }
    }

    // MARK: - keyword as function

    @Test("(:a {:a 1 :b 2}) returns value for existing key")
    func keywordAsFunctionExistingKey() throws {
        #expect(try swish.eval("(:a {:a 1 :b 2})") == .integer(1))
    }

    @Test("(:c {:a 1 :b 2}) returns nil for missing key")
    func keywordAsFunctionMissingKey() throws {
        #expect(try swish.eval("(:c {:a 1 :b 2})") == .nil)
    }

    @Test("(:c {:a 1 :b 2} 99) returns default for missing key")
    func keywordAsFunctionMissingKeyWithDefault() throws {
        #expect(try swish.eval("(:c {:a 1 :b 2} 99)") == .integer(99))
    }

    @Test("(:a nil) returns nil")
    func keywordAsFunctionNil() throws {
        #expect(try swish.eval("(:a nil)") == .nil)
    }

    @Test("(:a nil 42) returns default for nil map")
    func keywordAsFunctionNilWithDefault() throws {
        #expect(try swish.eval("(:a nil 42)") == .integer(42))
    }

    @Test("(:a \"foo\") returns nil for unsupported type")
    func keywordAsFunctionUnsupportedType() throws {
        #expect(try swish.eval("(:a \"foo\")") == .nil)
    }

    // MARK: - vector as function

    @Test("([1 2 3] 0) returns first element")
    func vectorAsFunctionFirst() throws {
        #expect(try swish.eval("([1 2 3] 0)") == .integer(1))
    }

    @Test("([1 2 3] 2) returns last element")
    func vectorAsFunctionLast() throws {
        #expect(try swish.eval("([1 2 3] 2)") == .integer(3))
    }

    @Test("([:a :b :c] 1) returns middle keyword")
    func vectorAsFunctionKeyword() throws {
        #expect(try swish.eval("([:a :b :c] 1)") == .keyword("b"))
    }

    @Test("([1 2 3]) throws on zero args")
    func vectorAsFunctionZeroArgs() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "vector", message: "requires 1 argument, got 0")) {
            try swish.eval("([1 2 3])")
        }
    }

    @Test("([1 2 3] 0 99) throws on two args")
    func vectorAsFunctionTwoArgs() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "vector", message: "requires 1 argument, got 2")) {
            try swish.eval("([1 2 3] 0 99)")
        }
    }

    @Test("([1 2 3] :k) throws on non-integer index")
    func vectorAsFunctionNonIntegerIndex() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "vector", message: "index must be an integer")) {
            try swish.eval("([1 2 3] :k)")
        }
    }

    @Test("([1 2 3] -1) throws on negative index")
    func vectorAsFunctionNegativeIndex() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "vector", message: "index -1 out of bounds for vector of size 3")) {
            try swish.eval("([1 2 3] -1)")
        }
    }

    @Test("([1 2 3] 3) throws on index equal to count")
    func vectorAsFunctionIndexAtCount() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "vector", message: "index 3 out of bounds for vector of size 3")) {
            try swish.eval("([1 2 3] 3)")
        }
    }

    @Test("([] 0) throws on empty vector")
    func vectorAsFunctionEmptyVector() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "vector", message: "index 0 out of bounds for vector of size 0")) {
            try swish.eval("([] 0)")
        }
    }

    // MARK: - assoc on vector

    @Test("(assoc [1 2 3] 1 :b) replaces element at index")
    func assocVectorReplace() throws {
        #expect(try swish.eval("(assoc [1 2 3] 1 :b)") == .vector([.integer(1), .keyword("b"), .integer(3)], metadata: nil))
    }

    @Test("(assoc [1 2 3] 0 :a 2 :c) applies multiple pairs")
    func assocVectorMultiplePairs() throws {
        #expect(try swish.eval("(assoc [1 2 3] 0 :a 2 :c)") == .vector([.keyword("a"), .integer(2), .keyword("c")], metadata: nil))
    }

    @Test("(assoc [1 2 3] 3 :d) appends at end")
    func assocVectorAppend() throws {
        #expect(try swish.eval("(assoc [1 2 3] 3 :d)") == .vector([.integer(1), .integer(2), .integer(3), .keyword("d")], metadata: nil))
    }

    @Test("(assoc [] 0 :x) appends to empty vector")
    func assocVectorAppendToEmpty() throws {
        #expect(try swish.eval("(assoc [] 0 :x)") == .vector([.keyword("x")], metadata: nil))
    }

    @Test("(assoc [1 2 3] -1 :x) throws on negative index")
    func assocVectorNegativeIndex() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "assoc", message: "index -1 out of bounds for vector of size 3")) {
            try swish.eval("(assoc [1 2 3] -1 :x)")
        }
    }

    @Test("(assoc [1 2 3] 4 :x) throws when index skips past end")
    func assocVectorIndexTooLarge() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "assoc", message: "index 4 out of bounds for vector of size 3")) {
            try swish.eval("(assoc [1 2 3] 4 :x)")
        }
    }

    @Test("(assoc [1 2 3] :k :v) throws on non-integer key")
    func assocVectorNonIntegerKey() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "assoc", message: "vector index must be an integer, got :k")) {
            try swish.eval("(assoc [1 2 3] :k :v)")
        }
    }

    // MARK: - keyword as function (zero/three args)

    @Test("(:a) throws on zero args")
    func keywordAsFunctionZeroArgs() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "keyword", message: "requires 1 or 2 arguments, got 0")) {
            try swish.eval("(:a)")
        }
    }

    @Test("(:a {:a 1} :b :c) throws on three args")
    func keywordAsFunctionThreeArgs() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "keyword", message: "requires 1 or 2 arguments, got 3")) {
            try swish.eval("(:a {:a 1} :b :c)")
        }
    }

    // MARK: - merge

    @Test("(merge) returns nil")
    func mergeNoArgs() throws {
        #expect(try swish.eval("(merge)") == .nil)
    }

    @Test("(merge nil) returns nil")
    func mergeNilReturnsNil() throws {
        #expect(try swish.eval("(merge nil)") == .nil)
    }

    @Test("(merge nil nil) returns nil")
    func mergeAllNilReturnsNil() throws {
        #expect(try swish.eval("(merge nil nil)") == .nil)
    }

    @Test("(merge {} {}) returns empty map, not nil")
    func mergeTwoEmptyMapsReturnsEmptyMap() throws {
        #expect(try swish.eval("(merge {} {})") == .map([:], metadata: nil))
    }

    @Test("(merge nil {}) returns empty map")
    func mergeNilAndEmptyMapReturnsEmptyMap() throws {
        #expect(try swish.eval("(merge nil {})") == .map([:], metadata: nil))
    }

    @Test("(merge {:a 1} {:b 2}) merges both maps")
    func mergeTwoMaps() throws {
        let result = try swish.eval("(merge {:a 1} {:b 2})")
        #expect(result == .map([.keyword("a"): .integer(1), .keyword("b"): .integer(2)], metadata: nil))
    }

    @Test("(merge {:a 1} {:a 2}) later value wins")
    func mergeLaterValueWins() throws {
        #expect(try swish.eval("(merge {:a 1} {:a 2})") == .map([.keyword("a"): .integer(2)], metadata: nil))
    }

    // MARK: - dissoc

    @Test("(dissoc {:a 1 :b 2} :a) removes one key")
    func dissocOneKey() throws {
        #expect(try swish.eval("(dissoc {:a 1 :b 2} :a)") == .map([.keyword("b"): .integer(2)], metadata: nil))
    }

    @Test("(dissoc {:a 1 :b 2} :a :b) removes multiple keys")
    func dissocMultipleKeys() throws {
        #expect(try swish.eval("(dissoc {:a 1 :b 2} :a :b)") == .map([:], metadata: nil))
    }

    @Test("(dissoc {:a 1} :missing) returns map unchanged for absent key")
    func dissocMissingKey() throws {
        #expect(try swish.eval("(dissoc {:a 1} :missing)") == .map([.keyword("a"): .integer(1)], metadata: nil))
    }

    @Test("(dissoc {:a 1}) returns map unchanged when no keys given")
    func dissocNoKeys() throws {
        #expect(try swish.eval("(dissoc {:a 1})") == .map([.keyword("a"): .integer(1)], metadata: nil))
    }

    @Test("(dissoc nil :a) returns nil")
    func dissocNilReturnsNil() throws {
        #expect(try swish.eval("(dissoc nil :a)") == .nil)
    }

    @Test("(dissoc nil) returns nil")
    func dissocNilNoKeysReturnsNil() throws {
        #expect(try swish.eval("(dissoc nil)") == .nil)
    }

    @Test("(dissoc 42 :a) throws on non-map first arg")
    func dissocNonMapThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "dissoc", message: "first argument must be a map or nil, got 42")) {
            try swish.eval("(dissoc 42 :a)")
        }
    }

    // MARK: - get-in

    @Test("(get-in {:a {:b 1}} [:a :b]) returns nested value")
    func getInBasic() throws {
        #expect(try swish.eval("(get-in {:a {:b 1}} [:a :b])") == .integer(1))
    }

    @Test("(get-in {:a {:b 1}} [:a :c]) returns nil for missing key")
    func getInMissingKey() throws {
        #expect(try swish.eval("(get-in {:a {:b 1}} [:a :c])") == .nil)
    }

    @Test("(get-in {:a {:b 1}} [:a :c] 42) returns not-found for missing key")
    func getInNotFound() throws {
        #expect(try swish.eval("(get-in {:a {:b 1}} [:a :c] 42)") == .integer(42))
    }

    @Test("(get-in {:a nil} [:a :b] :nf) returns not-found when intermediate is nil")
    func getInFoundNilIntermediate() throws {
        #expect(try swish.eval("(get-in {:a nil} [:a :b] :nf)") == .keyword("nf"))
    }

    @Test("(get-in {:a 1} []) returns m for empty path")
    func getInEmptyPath() throws {
        #expect(try swish.eval("(get-in {:a 1} [])") == .map([.keyword("a"): .integer(1)], metadata: nil))
    }

    @Test("(get-in nil [:a]) returns nil")
    func getInNilRoot() throws {
        #expect(try swish.eval("(get-in nil [:a])") == .nil)
    }

    @Test("(get-in nil [:a] 99) returns not-found for nil root")
    func getInNilRootNotFound() throws {
        #expect(try swish.eval("(get-in nil [:a] 99)") == .integer(99))
    }

    @Test("(get-in [[1 2] [3 4]] [1 0]) traverses vectors by index")
    func getInVectorPath() throws {
        #expect(try swish.eval("(get-in [[1 2] [3 4]] [1 0])") == .integer(3))
    }

    // MARK: - assoc-in

    @Test("(assoc-in {:a 1} [:a] 99) single key — same as assoc")
    func assocInSingleKey() throws {
        #expect(try swish.eval("(assoc-in {:a 1} [:a] 99)") == .map([.keyword("a"): .integer(99)], metadata: nil))
    }

    @Test("(assoc-in {:a {:b 1}} [:a :b] 99) updates nested key")
    func assocInNestedKey() throws {
        #expect(try swish.eval("(assoc-in {:a {:b 1}} [:a :b] 99)") == .map([.keyword("a"): .map([.keyword("b"): .integer(99)], metadata: nil)], metadata: nil))
    }

    @Test("(assoc-in {} [:a :b] 42) creates intermediate maps")
    func assocInCreatesIntermediates() throws {
        #expect(try swish.eval("(assoc-in {} [:a :b] 42)") == .map([.keyword("a"): .map([.keyword("b"): .integer(42)], metadata: nil)], metadata: nil))
    }

    @Test("(assoc-in nil [:a :b] 1) treats nil root as empty map")
    func assocInNilRoot() throws {
        #expect(try swish.eval("(assoc-in nil [:a :b] 1)") == .map([.keyword("a"): .map([.keyword("b"): .integer(1)], metadata: nil)], metadata: nil))
    }

    // MARK: - update

    @Test("(update {:a 1} :a inc) applies f to existing value")
    func updateInc() throws {
        #expect(try swish.eval("(update {:a 1} :a inc)") == .map([.keyword("a"): .integer(2)], metadata: nil))
    }

    @Test("(update {:a 1} :a + 10) passes extra arg to f")
    func updateExtraArg() throws {
        #expect(try swish.eval("(update {:a 1} :a + 10)") == .map([.keyword("a"): .integer(11)], metadata: nil))
    }

    @Test("(update {:a 1} :b str) passes nil to f for missing key")
    func updateMissingKey() throws {
        #expect(try swish.eval("(update {:a 1} :b str)") == .map([.keyword("a"): .integer(1), .keyword("b"): .string("")], metadata: nil))
    }

    @Test("(update {:a 0} :a + 1 2 3) uses apply arity for many extra args")
    func updateManyExtraArgs() throws {
        #expect(try swish.eval("(update {:a 0} :a + 1 2 3)") == .map([.keyword("a"): .integer(6)], metadata: nil))
    }

    // MARK: - update-in

    @Test("(update-in {:a {:b 1}} [:a :b] inc) updates nested value")
    func updateInNested() throws {
        #expect(try swish.eval("(update-in {:a {:b 1}} [:a :b] inc)") == .map([.keyword("a"): .map([.keyword("b"): .integer(2)], metadata: nil)], metadata: nil))
    }

    @Test("(update-in {:a {:b 1}} [:a :b] + 10) passes extra arg to f")
    func updateInExtraArg() throws {
        #expect(try swish.eval("(update-in {:a {:b 1}} [:a :b] + 10)") == .map([.keyword("a"): .map([.keyword("b"): .integer(11)], metadata: nil)], metadata: nil))
    }

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

    @Test("(keys 42) throws on non-map")
    func keysNonMapThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "keys", message: "argument must be a map or nil, got 42")) {
            try swish.eval("(keys 42)")
        }
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

    @Test("(vals 42) throws on non-map")
    func valsNonMapThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "vals", message: "argument must be a map or nil, got 42")) {
            try swish.eval("(vals 42)")
        }
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
        #expect(throws: EvaluatorError.invalidArgument(function: "find", message: "first argument must be a map or nil, got 42")) {
            try swish.eval("(find 42 :a)")
        }
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
}
