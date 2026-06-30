import Testing
@testable import SwishKit

@Suite("Core Higher Order Tests", .serialized)
struct CoreHigherOrderTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - identity

    @Test("(identity 42) returns 42")
    func identityInt() throws {
        #expect(try swish.eval("(identity 42)") == .integer(42))
    }

    @Test("(identity :foo) returns :foo")
    func identityKeyword() throws {
        #expect(try swish.eval("(identity :foo)") == .keyword("foo"))
    }

    @Test("(identity nil) returns nil")
    func identityNil() throws {
        #expect(try swish.eval("(identity nil)") == .nil)
    }

    @Test("(identity [1 2]) returns [1 2]")
    func identityVector() throws {
        #expect(try swish.eval("(identity [1 2])") == .vector([.integer(1), .integer(2)], metadata: nil))
    }

    // MARK: - complement

    @Test("((complement odd?) 2) returns true")
    func complementOddEven() throws {
        #expect(try swish.eval("((complement odd?) 2)") == .boolean(true))
    }

    @Test("((complement odd?) 3) returns false")
    func complementOddOdd() throws {
        #expect(try swish.eval("((complement odd?) 3)") == .boolean(false))
    }

    @Test("((complement nil?) 1) returns true")
    func complementNilNonNil() throws {
        #expect(try swish.eval("((complement nil?) 1)") == .boolean(true))
    }

    @Test("((complement nil?) nil) returns false")
    func complementNilNil() throws {
        #expect(try swish.eval("((complement nil?) nil)") == .boolean(false))
    }

    // MARK: - every?

    @Test("(every? odd? [1 3 5]) returns true")
    func everyAllOdd() throws {
        #expect(try swish.eval("(every? odd? [1 3 5])") == .boolean(true))
    }

    @Test("(every? odd? [1 2 3]) returns false")
    func everySomeEven() throws {
        #expect(try swish.eval("(every? odd? [1 2 3])") == .boolean(false))
    }

    @Test("(every? odd? []) returns true")
    func everyEmpty() throws {
        #expect(try swish.eval("(every? odd? [])") == .boolean(true))
    }

    @Test("(every? number? [1 2 3]) returns true")
    func everyNumbers() throws {
        #expect(try swish.eval("(every? number? [1 2 3])") == .boolean(true))
    }

    // MARK: - some

    @Test("(some odd? [2 3 4]) returns truthy value")
    func someFindsOdd() throws {
        let result = try swish.eval("(some odd? [2 3 4])")
        #expect(result == .boolean(true))
    }

    @Test("(some odd? [2 4 6]) returns nil")
    func someNoMatch() throws {
        #expect(try swish.eval("(some odd? [2 4 6])") == .nil)
    }

    @Test("(some odd? []) returns nil")
    func someEmpty() throws {
        #expect(try swish.eval("(some odd? [])") == .nil)
    }

    @Test("(some identity [nil false 3]) returns 3")
    func someIdentity() throws {
        #expect(try swish.eval("(some identity [nil false 3])") == .integer(3))
    }

    // MARK: - constantly

    @Test("constantly returns a fn that always returns x regardless of args")
    func constantlyMultiArgs() throws {
        #expect(try swish.eval("((constantly 42) 1 2 3)") == .integer(42))
    }

    @Test("constantly with no args call returns x")
    func constantlyNoArgs() throws {
        #expect(try swish.eval("((constantly nil))") == .nil)
    }

    @Test("juxt is a function")
    func juxtIsFunction() throws {
        #expect(try swish.eval("(fn? juxt)") == .boolean(true))
    }

    @Test("(juxt inc dec) returns a function")
    func juxtReturnsFunction() throws {
        #expect(try swish.eval("(fn? (juxt inc dec))") == .boolean(true))
    }

    @Test("((juxt inc dec) 5) returns [6 4]")
    func juxtApplied() throws {
        #expect(try swish.eval("((juxt inc dec) 5)") == .vector([.integer(6), .integer(4)], metadata: nil))
    }

    @Test("((juxt + - *) 2 3) returns [5 -1 6]")
    func juxtMultipleArgs() throws {
        #expect(try swish.eval("((juxt + - *) 2 3)") == .vector([.integer(5), .integer(-1), .integer(6)], metadata: nil))
    }
}
