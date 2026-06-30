import Testing
@testable import SwishKit

@Suite("Core nil? Tests", .serialized)
struct CoreNilPredicateTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

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

    @Test("(true? true) returns true")
    func truePredTrue() throws {
        #expect(try swish.eval("(true? true)") == .boolean(true))
    }

    @Test("(true? false) returns false")
    func truePredFalse() throws {
        #expect(try swish.eval("(true? false)") == .boolean(false))
    }

    @Test("(true? 1) returns false")
    func truePredInt() throws {
        #expect(try swish.eval("(true? 1)") == .boolean(false))
    }

    @Test("(false? false) returns true")
    func falsePredFalse() throws {
        #expect(try swish.eval("(false? false)") == .boolean(true))
    }

    @Test("(false? true) returns false")
    func falsePredTrue() throws {
        #expect(try swish.eval("(false? true)") == .boolean(false))
    }

    @Test("(false? nil) returns false")
    func falsePredNil() throws {
        #expect(try swish.eval("(false? nil)") == .boolean(false))
    }

    @Test("(ifn? inc) returns true for a function")
    func ifnPredFunction() throws {
        #expect(try swish.eval("(ifn? inc)") == .boolean(true))
    }

    @Test("(ifn? :foo) returns true for a keyword")
    func ifnPredKeyword() throws {
        #expect(try swish.eval("(ifn? :foo)") == .boolean(true))
    }

    @Test("(ifn? {}) returns true for a map")
    func ifnPredMap() throws {
        #expect(try swish.eval("(ifn? {})") == .boolean(true))
    }

    @Test("(ifn? #{}) returns true for a set")
    func ifnPredSet() throws {
        #expect(try swish.eval("(ifn? #{})") == .boolean(true))
    }

    @Test("(ifn? []) returns true for a vector")
    func ifnPredVector() throws {
        #expect(try swish.eval("(ifn? [])") == .boolean(true))
    }

    @Test("(ifn? 42) returns false")
    func ifnPredInt() throws {
        #expect(try swish.eval("(ifn? 42)") == .boolean(false))
    }

    @Test("(any? nil) returns true")
    func anyPredNil() throws {
        #expect(try swish.eval("(any? nil)") == .boolean(true))
    }

    @Test("(any? 42) returns true")
    func anyPredInt() throws {
        #expect(try swish.eval("(any? 42)") == .boolean(true))
    }

    @Test("(any? false) returns true")
    func anyPredFalse() throws {
        #expect(try swish.eval("(any? false)") == .boolean(true))
    }

    @Test("(double? 1.0) returns true")
    func doublePredFloat() throws {
        #expect(try swish.eval("(double? 1.0)") == .boolean(true))
    }

    @Test("(double? 1) returns false")
    func doublePredInt() throws {
        #expect(try swish.eval("(double? 1)") == .boolean(false))
    }
}
