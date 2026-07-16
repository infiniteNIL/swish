import Testing
@testable import SwishKit

@Suite("Core var? Tests", .serialized)
struct CoreVarPredicateTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("var? returns true for a Var")
    func varTrue() throws {
        #expect(try swish.eval("(var? (var +))") == .boolean(true))
    }

    @Test("var? returns false for non-Var values")
    func varFalseCases() throws {
        #expect(try swish.eval("(var? nil)") == .boolean(false))
        #expect(try swish.eval("(var? 1)") == .boolean(false))
        #expect(try swish.eval("(var? :a)") == .boolean(false))
        #expect(try swish.eval("(var? +)") == .boolean(false))
    }
}
