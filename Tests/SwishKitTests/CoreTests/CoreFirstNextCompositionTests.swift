import Testing
@testable import SwishKit

@Suite("Core ffirst/nfirst/fnext Tests", .serialized)
struct CoreFirstNextCompositionTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - ffirst

    @Test("ffirst on empty collections returns nil")
    func ffirstEmptyCollections() throws {
        #expect(try swish.eval("(ffirst '())") == .nil)
        #expect(try swish.eval("(ffirst [])") == .nil)
        #expect(try swish.eval("(ffirst {})") == .nil)
        #expect(try swish.eval("(ffirst #{})") == .nil)
        #expect(try swish.eval("(ffirst nil)") == .nil)
    }

    @Test("ffirst on a map returns the first key")
    func ffirstMap() throws {
        #expect(try swish.eval("(ffirst {:a :b})") == .keyword("a"))
    }

    @Test("ffirst on nested vectors/lists returns the first of the first")
    func ffirstNested() throws {
        #expect(try swish.eval("(ffirst [[0 1] [2 3]])") == .integer(0))
        #expect(try swish.eval("(ffirst '([0 1] [2 3]))") == .integer(0))
    }

    @Test("ffirst stays lazy on infinite sequences")
    func ffirstLazy() throws {
        #expect(try swish.eval("(ffirst (repeat (range)))") == .integer(0))
        #expect(try swish.eval("(ffirst [(range)])") == .integer(0))
    }

    @Test("ffirst on strings returns the first character")
    func ffirstStrings() throws {
        #expect(try swish.eval(#"(ffirst ["ab" "cd"])"#) == .character("a"))
        #expect(try swish.eval(#"(ffirst ["abcd"])"#) == .character("a"))
        #expect(try swish.eval(#"(ffirst #{"abcd"})"#) == .character("a"))
    }

    @Test("ffirst throws when the inner first isn't seqable")
    func ffirstThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(ffirst (range 0 10))") }
        #expect(throws: (any Error).self) { try swish.eval("(ffirst (range))") }
        #expect(throws: (any Error).self) { try swish.eval("(ffirst [:a :b :c])") }
        #expect(throws: (any Error).self) { try swish.eval("(ffirst '(:a :b :c))") }
    }

    // MARK: - nfirst

    @Test("nfirst on empty collections returns nil")
    func nfirstEmptyCollections() throws {
        #expect(try swish.eval("(nfirst '())") == .nil)
        #expect(try swish.eval("(nfirst [])") == .nil)
        #expect(try swish.eval("(nfirst {})") == .nil)
        #expect(try swish.eval("(nfirst #{})") == .nil)
        #expect(try swish.eval("(nfirst nil)") == .nil)
        #expect(try swish.eval(#"(nfirst "")"#) == .nil)
    }

    @Test("nfirst on a map returns the rest of the first entry")
    func nfirstMap() throws {
        #expect(try swish.eval("(nfirst {:a :b})") == .list([.keyword("b")], metadata: nil))
    }

    @Test("nfirst on nested vectors/lists returns the rest of the first")
    func nfirstNested() throws {
        #expect(try swish.eval("(nfirst [[0 1] [2 3]])") == .list([.integer(1)], metadata: nil))
        #expect(try swish.eval("(nfirst '([0 1] [2 3]))") == .list([.integer(1)], metadata: nil))
    }

    @Test("nfirst stays lazy on infinite sequences")
    func nfirstLazy() throws {
        #expect(try swish.eval("(nfirst (repeat (range 0 5)))") == .list([1, 2, 3, 4].map { .integer($0) }, metadata: nil))
    }

    @Test("nfirst on strings returns the rest characters as a seq")
    func nfirstStrings() throws {
        #expect(try swish.eval(#"(nfirst ["ab" "cd"])"#) == .list([.character("b")], metadata: nil))
        #expect(try swish.eval(#"(nfirst ["abcd"])"#) == .list([.character("b"), .character("c"), .character("d")], metadata: nil))
        #expect(try swish.eval(#"(nfirst #{"abcd"})"#) == .list([.character("b"), .character("c"), .character("d")], metadata: nil))
    }

    @Test("nfirst throws when the inner first isn't seqable")
    func nfirstThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(nfirst (range 0 10))") }
        #expect(throws: (any Error).self) { try swish.eval("(nfirst (range))") }
        #expect(throws: (any Error).self) { try swish.eval("(nfirst [:a :b :c])") }
        #expect(throws: (any Error).self) { try swish.eval("(nfirst '(:a :b :c))") }
    }

    // MARK: - fnext

    @Test("fnext on empty/short collections returns nil")
    func fnextEmptyCollections() throws {
        #expect(try swish.eval("(fnext '())") == .nil)
        #expect(try swish.eval("(fnext [])") == .nil)
        #expect(try swish.eval("(fnext {})") == .nil)
        #expect(try swish.eval("(fnext #{})") == .nil)
        #expect(try swish.eval("(fnext nil)") == .nil)
        #expect(try swish.eval(#"(fnext "")"#) == .nil)
        #expect(try swish.eval(#"(fnext "a")"#) == .nil)
        #expect(try swish.eval("(fnext {:a :b})") == .nil)
    }

    @Test("fnext on a vector returns the second element")
    func fnextVector() throws {
        #expect(try swish.eval("(fnext [:a :b])") == .keyword("b"))
    }

    @Test("fnext stays lazy on infinite sequences")
    func fnextLazy() throws {
        #expect(try swish.eval("(fnext (range 0 10))") == .integer(1))
        #expect(try swish.eval("(fnext (range))") == .integer(1))
    }

    @Test("fnext on nested vectors/lists returns the second element of the seq")
    func fnextNested() throws {
        #expect(try swish.eval("(fnext [[0 1] [2 3]])") == .vector([.integer(2), .integer(3)], metadata: nil))
        #expect(try swish.eval("(fnext '([0 1] [2 3]))") == .vector([.integer(2), .integer(3)], metadata: nil))
    }

    @Test("fnext on strings/string-collections")
    func fnextStrings() throws {
        #expect(try swish.eval(#"(fnext "abcd")"#) == .character("b"))
        #expect(try swish.eval(#"(fnext ["ab" "cd"])"#) == .string("cd"))
        #expect(try swish.eval(#"(fnext ["abcd"])"#) == .nil)
        #expect(try swish.eval(#"(fnext #{"abcd"})"#) == .nil)
    }

    @Test("fnext throws when the argument isn't seqable")
    func fnextThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(fnext 0)") }
        #expect(throws: (any Error).self) { try swish.eval(#"(fnext \a)"#) }
    }
}
