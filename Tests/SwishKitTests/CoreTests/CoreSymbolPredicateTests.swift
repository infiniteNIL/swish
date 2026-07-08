import Testing
@testable import SwishKit

@Suite("symbol? Tests", .serialized)
struct CoreSymbolPredicateTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("symbol? returns true for a symbol")
    func symbolPredicateSymbol() throws {
        #expect(try swish.eval("(symbol? 'foo)") == .boolean(true))
    }

    @Test("symbol? returns false for a keyword")
    func symbolPredicateKeyword() throws {
        #expect(try swish.eval("(symbol? :foo)") == .boolean(false))
    }

    @Test("symbol? returns false for a string")
    func symbolPredicateString() throws {
        #expect(try swish.eval(#"(symbol? "foo")"#) == .boolean(false))
    }

    @Test("symbol? returns false for an integer")
    func symbolPredicateInteger() throws {
        #expect(try swish.eval("(symbol? 42)") == .boolean(false))
    }

    @Test("symbol? returns false for nil")
    func symbolPredicateNil() throws {
        #expect(try swish.eval("(symbol? nil)") == .boolean(false))
    }

    @Test("(symbol #'+) returns fully qualified symbol clojure.core/+")
    func symbolFromVarRef() throws {
        #expect(try swish.eval("(symbol #'+)") == .symbol("clojure.core/+", metadata: nil))
    }

    @Test("(namespace (symbol \"\" \"hi\")) returns empty string")
    func namespaceOfSymbolWithEmptyNs() throws {
        #expect(try swish.eval(#"(namespace (symbol "" "hi"))"#) == .string(""))
    }
}
