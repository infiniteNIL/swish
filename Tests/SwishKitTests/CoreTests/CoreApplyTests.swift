import Testing
@testable import SwishKit

@Suite("Core Apply Tests", .serialized)
struct CoreApplyTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("(apply str [\"a\" \"b\" \"c\"]) concatenates strings")
    func applyStr() throws {
        #expect(try swish.eval("(apply str [\"a\" \"b\" \"c\"])") == .string("abc"))
    }

    @Test("local binding named after a built-in shadows it in apply")
    func localShadowsBuiltinUnqualified() throws {
        // 'keys' resolves to clojure.core/keys but the let binding must win
        #expect(try swish.eval("(let [keys [1 2 3]] (apply + keys))") == .integer(6))
    }

    @Test("qualified local binding shadows the same namespace var")
    func localShadowsBuiltinQualified() throws {
        // expandAliases can produce clojure.core/keys as a binding name;
        // the local value must still take priority over the namespace var
        #expect(try swish.eval("(let [clojure.core/keys [1 2 3]] (apply + clojure.core/keys))") == .integer(6))
    }

    @Test("(apply map {:a 1 :b 2}) uses map as spread arg")
    func applyMapSpread() throws {
        let result = try swish.eval("(count (apply list {:a 1 :b 2}))")
        #expect(result == .integer(2))
    }

    @Test("(apply + {}) returns 0 — empty map as spread arg")
    func applyEmptyMapSpread() throws {
        #expect(try swish.eval("(apply + {})") == .integer(0))
    }

    @Test("(apply + #{1 2 3}) returns 6 — set as spread arg")
    func applySetSpread() throws {
        #expect(try swish.eval("(apply + #{1 2 3})") == .integer(6))
    }

    @Test("map as spread arg produces pairs: (count (apply list {:a 1 :b 2})) → 2")
    func applyMapSpreadPairCount() throws {
        #expect(try swish.eval("(count (apply list {:a 1 :b 2}))") == .integer(2))
    }
}
