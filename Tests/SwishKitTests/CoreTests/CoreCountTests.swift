import Testing
@testable import SwishKit

@Suite("Core Count Tests", .serialized)
struct CoreCountTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("(count nil) returns 0")
    func countNil() throws {
        #expect(try swish.eval("(count nil)") == .integer(0))
    }

    @Test("(count list) returns element count")
    func countList() throws {
        #expect(try swish.eval("(count '(1 2 3))") == .integer(3))
    }

    @Test("(count empty list) returns 0")
    func countEmptyList() throws {
        #expect(try swish.eval("(count '())") == .integer(0))
    }

    @Test("(count vector) returns element count")
    func countVector() throws {
        #expect(try swish.eval("(count [1 2 3])") == .integer(3))
    }

    @Test("(count empty vector) returns 0")
    func countEmptyVector() throws {
        #expect(try swish.eval("(count [])") == .integer(0))
    }

    @Test("(count map) returns key-value pair count")
    func countMap() throws {
        #expect(try swish.eval("(count {:a 1 :b 2})") == .integer(2))
    }

    @Test("(count empty map) returns 0")
    func countEmptyMap() throws {
        #expect(try swish.eval("(count {})") == .integer(0))
    }

    @Test("(count set) returns element count")
    func countSet() throws {
        #expect(try swish.eval("(count #{1 2 3})") == .integer(3))
    }

    @Test("(count empty set) returns 0")
    func countEmptySet() throws {
        #expect(try swish.eval("(count #{})") == .integer(0))
    }

    @Test("(count string) returns grapheme cluster count")
    func countString() throws {
        #expect(try swish.eval("(count \"hello\")") == .integer(5))
    }

    @Test("(count empty string) returns 0")
    func countEmptyString() throws {
        #expect(try swish.eval("(count \"\")") == .integer(0))
    }

    @Test("(count integer) throws")
    func countIntegerThrows() throws {
        #expect(throws: EvaluatorError.self) {
            try swish.eval("(count 42)")
        }
    }
}
