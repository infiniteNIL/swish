import Testing
@testable import SwishKit

@Suite("ifn? and symbol/varRef callability", .serialized)
struct CoreIfnTests {
    static let _shared = Evaluator()
    var evaluator: Evaluator { Self._shared }

    @Test("ifn? returns true for a symbol")
    func ifnSymbol() throws {
        #expect(try evaluator.eval("(ifn? 'foo)") == .boolean(true))
    }

    @Test("ifn? returns true for a varRef")
    func ifnVarRef() throws {
        #expect(try evaluator.eval("(ifn? #'ifn?)") == .boolean(true))
    }

    @Test("symbol looks up itself in a map with symbol keys")
    func symbolCallInMap() throws {
        #expect(try evaluator.eval("('foo {'foo 42})") == .integer(42))
    }

    @Test("symbol with default returns value when found")
    func symbolCallInMapWithDefault() throws {
        #expect(try evaluator.eval("('foo {'foo 42} :not-found)") == .integer(42))
    }

    @Test("symbol with default returns default when not found")
    func symbolCallInMapMissing() throws {
        #expect(try evaluator.eval("('bar {'foo 42} :not-found)") == .keyword("not-found"))
    }

    @Test("varRef is callable and delegates to its value")
    func varRefCallable() throws {
        #expect(try evaluator.eval("(#'inc 1)") == .integer(2))
    }
}
