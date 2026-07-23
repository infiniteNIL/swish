import Testing
@testable import SwishKit

@Suite("Core Collection As Function Tests", .serialized)
struct CoreCollectionAsFunctionTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

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

}
