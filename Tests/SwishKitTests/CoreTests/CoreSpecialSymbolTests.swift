import Testing
@testable import SwishKit

@Suite("Core special-symbol? Tests", .serialized)
struct CoreSpecialSymbolTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - fixture-tested positive cases (the star-suffixed compiler primitives)

    @Test("special-symbol? is true for every symbol the jank fixture tests")
    func specialSymbolTrueForFixtureCases() throws {
        let names = [
            "&", "case*", "new", ".", "deftype*", "fn*", "let*", "letfn*", "loop*", "set!",
            "catch", "def", "do", "finally", "if", "quote", "recur", "throw", "try", "var",
        ]
        for n in names {
            #expect(try swish.eval("(special-symbol? '\(n))") == .boolean(true), "expected \(n) to be a special symbol")
        }
    }

    // MARK: - real, but not fixture-tested, positive cases

    @Test("special-symbol? is true for monitor-enter, monitor-exit, and reify*")
    func specialSymbolTrueForUntestedRealCases() throws {
        #expect(try swish.eval("(special-symbol? 'monitor-enter)") == .boolean(true))
        #expect(try swish.eval("(special-symbol? 'monitor-exit)") == .boolean(true))
        #expect(try swish.eval("(special-symbol? 'reify*)") == .boolean(true))
    }

    @Test("special-symbol? distinguishes bare import* (false) from clojure.core/import* (true)")
    func specialSymbolImportStarQualification() throws {
        #expect(try swish.eval("(special-symbol? 'import*)") == .boolean(false))
        #expect(try swish.eval("(special-symbol? 'clojure.core/import*)") == .boolean(true))
    }

    // MARK: - negative cases

    @Test("special-symbol? is false for an arbitrary or qualified symbol")
    func specialSymbolFalseForArbitrarySymbols() throws {
        #expect(try swish.eval("(special-symbol? 'a-symbol)") == .boolean(false))
        #expect(try swish.eval("(special-symbol? 'a-ns/a-qualified-symbol)") == .boolean(false))
    }

    @Test("special-symbol? is false for macros that expand to special forms, not the forms themselves")
    func specialSymbolFalseForMacros() throws {
        #expect(try swish.eval("(special-symbol? 'defn)") == .boolean(false))
        #expect(try swish.eval("(special-symbol? 'import)") == .boolean(false))
    }

    @Test("special-symbol? is false for non-symbol types")
    func specialSymbolFalseForNonSymbols() throws {
        #expect(try swish.eval(#"(special-symbol? "not a symbol")"#) == .boolean(false))
        #expect(try swish.eval("(special-symbol? :k)") == .boolean(false))
        #expect(try swish.eval("(special-symbol? 0)") == .boolean(false))
        #expect(try swish.eval("(special-symbol? 0.0)") == .boolean(false))
        #expect(try swish.eval("(special-symbol? true)") == .boolean(false))
        #expect(try swish.eval("(special-symbol? false)") == .boolean(false))
        #expect(try swish.eval("(special-symbol? nil)") == .boolean(false))
    }
}
