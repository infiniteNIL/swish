import Testing
@testable import SwishKit

@Suite("Core intern Tests", .serialized)
struct CoreInternTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("3-arg intern creates a var with the given value")
    func internWithValue() throws {
        #expect(try swish.eval("(var-get (intern 'user 'intern-test-a 42))") == .integer(42))
    }

    @Test("2-arg intern on an already-interned name preserves the existing value")
    func internWithoutValuePreservesExisting() throws {
        #expect(try swish.eval("(intern 'user 'intern-test-b 42) (var-get (intern 'user 'intern-test-b))") == .integer(42))
    }

    @Test("intern accepts ns as an actual namespace value")
    func internWithNamespaceValue() throws {
        #expect(try swish.eval("(var-get (intern (create-ns 'intern-test-ns-c) 'y 7))") == .integer(7))
    }

    @Test("intern accepts ns as a symbol naming an existing namespace")
    func internWithNamespaceSymbol() throws {
        #expect(try swish.eval("(create-ns 'intern-test-ns-d) (var-get (intern 'intern-test-ns-d 'z 9))") == .integer(9))
    }

    @Test("intern throws for a nonexistent namespace, both arities")
    func internNonexistentNamespaceThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(intern 'intern-test-unknown-ns 'x)")
        }
        #expect(throws: (any Error).self) {
            try swish.eval("(intern 'intern-test-unknown-ns 'x 42)")
        }
    }

    @Test("intern adopts metadata from the name symbol")
    func internAdoptsMetadata() throws {
        #expect(try swish.eval("(meta (intern 'user (with-meta 'intern-test-e {:foo 42})))") == .map([.keyword("foo"): .integer(42)], metadata: nil))
    }

    @Test("intern returns a var")
    func internReturnsVar() throws {
        #expect(try swish.eval("(var? (intern 'user 'intern-test-f 1))") == .boolean(true))
    }
}
