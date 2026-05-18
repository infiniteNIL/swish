import Testing
@testable import SwishKit

@Suite("Core nil? Tests")
struct CoreNilPredicateTests {
    let swish = Swish()

    @Test("nil? returns true for nil")
    func nilPredicateNil() throws {
        #expect(try swish.eval("(nil? nil)") == .boolean(true))
    }

    @Test("nil? returns false for false")
    func nilPredicateFalse() throws {
        #expect(try swish.eval("(nil? false)") == .boolean(false))
    }

    @Test("nil? returns false for 0")
    func nilPredicateZero() throws {
        #expect(try swish.eval("(nil? 0)") == .boolean(false))
    }

    @Test("nil? returns false for empty string")
    func nilPredicateEmptyString() throws {
        #expect(try swish.eval("(nil? \"\")") == .boolean(false))
    }

    @Test("nil? returns false for empty vector")
    func nilPredicateEmptyVector() throws {
        #expect(try swish.eval("(nil? [])") == .boolean(false))
    }
}
