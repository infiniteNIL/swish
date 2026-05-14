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
}
