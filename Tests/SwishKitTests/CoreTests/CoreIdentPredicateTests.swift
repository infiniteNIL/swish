import Testing
@testable import SwishKit

@Suite("Core ident?/simple-*?/qualified-*? Tests", .serialized)
struct CoreIdentPredicateTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    static let scalarFalseCases = [
        "\"a string\"", "0", "0N", "0.0", "0.0M", "false", "true", "nil", "1/2",
    ]

    // MARK: - ident?

    @Test("ident? is true for keywords and symbols, namespaced or not")
    func identTrue() throws {
        #expect(try swish.eval("(ident? :a-keyword)") == .boolean(true))
        #expect(try swish.eval("(ident? 'a-symbol)") == .boolean(true))
        #expect(try swish.eval("(ident? :a-ns/a-keyword)") == .boolean(true))
        #expect(try swish.eval("(ident? 'a-ns/a-keyword)") == .boolean(true))
    }

    @Test("ident? is false for non-symbol/keyword scalars")
    func identFalse() throws {
        for c in Self.scalarFalseCases {
            #expect(try swish.eval("(ident? \(c))") == .boolean(false))
        }
    }

    // MARK: - simple-ident?

    @Test("simple-ident? is true for un-namespaced keywords and symbols")
    func simpleIdentTrue() throws {
        #expect(try swish.eval("(simple-ident? :a-keyword)") == .boolean(true))
        #expect(try swish.eval("(simple-ident? 'a-symbol)") == .boolean(true))
    }

    @Test("simple-ident? is false for namespaced forms and scalars")
    func simpleIdentFalse() throws {
        #expect(try swish.eval("(simple-ident? (keyword \"a/b/c\"))") == .boolean(false))
        #expect(try swish.eval("(simple-ident? (symbol \"a/b/c\"))") == .boolean(false))
        #expect(try swish.eval("(simple-ident? ::a-keyword)") == .boolean(false))
        #expect(try swish.eval("(simple-ident? :a-ns/a-keyword)") == .boolean(false))
        #expect(try swish.eval("(simple-ident? 'a-ns/a-keyword)") == .boolean(false))
        for c in Self.scalarFalseCases {
            #expect(try swish.eval("(simple-ident? \(c))") == .boolean(false))
        }
    }

    // MARK: - qualified-ident?

    @Test("qualified-ident? is true for namespaced keywords and symbols")
    func qualifiedIdentTrue() throws {
        #expect(try swish.eval("(qualified-ident? (keyword \"a/b/c\"))") == .boolean(true))
        #expect(try swish.eval("(qualified-ident? (symbol \"a/b/c\"))") == .boolean(true))
        #expect(try swish.eval("(qualified-ident? ::a-keyword)") == .boolean(true))
        #expect(try swish.eval("(qualified-ident? :a-ns/a-keyword)") == .boolean(true))
        #expect(try swish.eval("(qualified-ident? 'a-ns/a-keyword)") == .boolean(true))
    }

    @Test("qualified-ident? is false for un-namespaced forms and scalars")
    func qualifiedIdentFalse() throws {
        #expect(try swish.eval("(qualified-ident? :a-keyword)") == .boolean(false))
        #expect(try swish.eval("(qualified-ident? 'a-symbol)") == .boolean(false))
        for c in Self.scalarFalseCases {
            #expect(try swish.eval("(qualified-ident? \(c))") == .boolean(false))
        }
    }

    // MARK: - simple-symbol?

    @Test("simple-symbol? is true only for an un-namespaced symbol")
    func simpleSymbolTrue() throws {
        #expect(try swish.eval("(simple-symbol? 'a-symbol)") == .boolean(true))
    }

    @Test("simple-symbol? is false for namespaced symbols, keywords, and scalars")
    func simpleSymbolFalse() throws {
        #expect(try swish.eval("(simple-symbol? (symbol \"a/b/c\"))") == .boolean(false))
        #expect(try swish.eval("(simple-symbol? :a-keyword)") == .boolean(false))
        #expect(try swish.eval("(simple-symbol? :a-ns/a-keyword)") == .boolean(false))
        #expect(try swish.eval("(simple-symbol? 'a-ns/a-keyword)") == .boolean(false))
        for c in Self.scalarFalseCases {
            #expect(try swish.eval("(simple-symbol? \(c))") == .boolean(false))
        }
    }

    // MARK: - qualified-symbol?

    @Test("qualified-symbol? is true only for a namespaced symbol")
    func qualifiedSymbolTrue() throws {
        #expect(try swish.eval("(qualified-symbol? (symbol \"a/b/c\"))") == .boolean(true))
        #expect(try swish.eval("(qualified-symbol? 'a-ns/a-keyword)") == .boolean(true))
    }

    @Test("qualified-symbol? is false for un-namespaced symbols, keywords, and scalars")
    func qualifiedSymbolFalse() throws {
        #expect(try swish.eval("(qualified-symbol? :a-keyword)") == .boolean(false))
        #expect(try swish.eval("(qualified-symbol? 'a-symbol)") == .boolean(false))
        #expect(try swish.eval("(qualified-symbol? :a-ns/a-keyword)") == .boolean(false))
        for c in Self.scalarFalseCases {
            #expect(try swish.eval("(qualified-symbol? \(c))") == .boolean(false))
        }
    }

    // MARK: - simple-keyword?

    @Test("simple-keyword? is true only for an un-namespaced keyword")
    func simpleKeywordTrue() throws {
        #expect(try swish.eval("(simple-keyword? :a-keyword)") == .boolean(true))
    }

    @Test("simple-keyword? is false for namespaced keywords, symbols, and scalars")
    func simpleKeywordFalse() throws {
        #expect(try swish.eval("(simple-keyword? (keyword \"a/b/c\"))") == .boolean(false))
        #expect(try swish.eval("(simple-keyword? ::a-keyword)") == .boolean(false))
        #expect(try swish.eval("(simple-keyword? 'a-symbol)") == .boolean(false))
        #expect(try swish.eval("(simple-keyword? :a-ns/a-keyword)") == .boolean(false))
        #expect(try swish.eval("(simple-keyword? 'a-ns/a-keyword)") == .boolean(false))
        for c in Self.scalarFalseCases {
            #expect(try swish.eval("(simple-keyword? \(c))") == .boolean(false))
        }
    }

    // MARK: - qualified-keyword?

    @Test("qualified-keyword? is true only for a namespaced keyword")
    func qualifiedKeywordTrue() throws {
        #expect(try swish.eval("(qualified-keyword? (keyword \"a/b/c\"))") == .boolean(true))
        #expect(try swish.eval("(qualified-keyword? ::a-keyword)") == .boolean(true))
        #expect(try swish.eval("(qualified-keyword? :a-ns/a-keyword)") == .boolean(true))
    }

    @Test("qualified-keyword? is false for un-namespaced keywords, symbols, and scalars")
    func qualifiedKeywordFalse() throws {
        #expect(try swish.eval("(qualified-keyword? :a-keyword)") == .boolean(false))
        #expect(try swish.eval("(qualified-keyword? 'a-symbol)") == .boolean(false))
        #expect(try swish.eval("(qualified-keyword? 'a-ns/a-keyword)") == .boolean(false))
        for c in Self.scalarFalseCases {
            #expect(try swish.eval("(qualified-keyword? \(c))") == .boolean(false))
        }
    }
}
