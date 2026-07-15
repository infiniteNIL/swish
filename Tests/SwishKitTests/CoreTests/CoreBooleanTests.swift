import Testing
@testable import SwishKit

@Suite("Core boolean Tests", .serialized)
struct CoreBooleanTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("boolean is false only for nil and false")
    func booleanFalsyCases() throws {
        #expect(try swish.eval("(boolean nil)") == .boolean(false))
        #expect(try swish.eval("(boolean false)") == .boolean(false))
    }

    @Test("boolean is true for every numeric type, including NaN/Inf")
    func booleanTruthyNumeric() throws {
        #expect(try swish.eval("(boolean 0)") == .boolean(true))
        #expect(try swish.eval("(boolean 1)") == .boolean(true))
        #expect(try swish.eval("(boolean -1)") == .boolean(true))
        #expect(try swish.eval("(boolean 0.0)") == .boolean(true))
        #expect(try swish.eval("(boolean 1.0)") == .boolean(true))
        #expect(try swish.eval("(boolean (float 0.0))") == .boolean(true))
        #expect(try swish.eval("(boolean ##Inf)") == .boolean(true))
        #expect(try swish.eval("(boolean ##-Inf)") == .boolean(true))
        #expect(try swish.eval("(boolean ##NaN)") == .boolean(true))
        #expect(try swish.eval("(boolean 0N)") == .boolean(true))
        #expect(try swish.eval("(boolean 1N)") == .boolean(true))
        #expect(try swish.eval("(boolean 0.0M)") == .boolean(true))
        #expect(try swish.eval("(boolean 1/2)") == .boolean(true))
    }

    @Test("boolean is true for true, strings (including \"false\"/\"0\"), collections, chars, keywords, symbols")
    func booleanTruthyOther() throws {
        #expect(try swish.eval("(boolean true)") == .boolean(true))
        #expect(try swish.eval("(boolean \"a string\")") == .boolean(true))
        #expect(try swish.eval("(boolean \"false\")") == .boolean(true))
        #expect(try swish.eval("(boolean \"0\")") == .boolean(true))
        #expect(try swish.eval("(boolean {:a :map})") == .boolean(true))
        #expect(try swish.eval("(boolean #{:a-set})") == .boolean(true))
        #expect(try swish.eval("(boolean [:a :vector])") == .boolean(true))
        #expect(try swish.eval("(boolean '(:a :list))") == .boolean(true))
        #expect(try swish.eval("(boolean {})") == .boolean(true))
        #expect(try swish.eval("(boolean [])") == .boolean(true))
        #expect(try swish.eval("(boolean \\0)") == .boolean(true))
        #expect(try swish.eval("(boolean :a-keyword)") == .boolean(true))
        #expect(try swish.eval("(boolean :false)") == .boolean(true))
        #expect(try swish.eval("(boolean 'a-sym)") == .boolean(true))
    }

    @Test("boolean? is true only for the literals true/false")
    func booleanPredicate() throws {
        #expect(try swish.eval("(boolean? true)") == .boolean(true))
        #expect(try swish.eval("(boolean? false)") == .boolean(true))
    }

    @Test("boolean? is false for nil, numbers, char, keyword, string, and empty collections")
    func booleanPredicateFalseCases() throws {
        #expect(try swish.eval("(boolean? nil)") == .boolean(false))
        #expect(try swish.eval("(boolean? 0)") == .boolean(false))
        #expect(try swish.eval("(boolean? 1)") == .boolean(false))
        #expect(try swish.eval("(boolean? -1)") == .boolean(false))
        #expect(try swish.eval("(boolean? 0.0)") == .boolean(false))
        #expect(try swish.eval("(boolean? \\space)") == .boolean(false))
        #expect(try swish.eval("(boolean? :a-keyword)") == .boolean(false))
        #expect(try swish.eval("(boolean? \"str\")") == .boolean(false))
        #expect(try swish.eval("(boolean? [])") == .boolean(false))
        #expect(try swish.eval("(boolean? '())") == .boolean(false))
        #expect(try swish.eval("(boolean? {})") == .boolean(false))
        #expect(try swish.eval("(boolean? #{})") == .boolean(false))
    }

    @Test("parse-boolean matches \"true\"/\"false\" exactly")
    func parseBooleanValid() throws {
        #expect(try swish.eval("(parse-boolean \"true\")") == .boolean(true))
        #expect(try swish.eval("(parse-boolean \"false\")") == .boolean(false))
    }

    @Test("parse-boolean returns nil for any near-miss string, with no trimming or case-folding")
    func parseBooleanNilCases() throws {
        let nearMisses = ["0", "1", "", "foo", "False", "FALSE", "True", "TRUE",
                           "ttrue", "truee", "ffalse", "falsee", " true", "tr ue", "true "]
        for s in nearMisses {
            #expect(try swish.eval("(parse-boolean \"\(s)\")") == .nil, "parse-boolean of \"\(s)\" should be nil")
        }
    }

    @Test("parse-boolean throws for non-string arguments")
    func parseBooleanNonStringThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(parse-boolean nil)") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-boolean 0)") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-boolean 0.0)") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-boolean \\a)") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-boolean :key)") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-boolean {})") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-boolean '())") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-boolean #{})") }
        #expect(throws: (any Error).self) { try swish.eval("(parse-boolean [])") }
    }
}
