import Testing
@testable import SwishKit

@Suite("Regex Literal Tests", .serialized)
struct RegexTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("regex literal evaluates to itself")
    func regexSelfEvaluating() throws {
        let result = try swish.eval(#"#"\d+""#)
        guard case .regex(let r) = result else {
            Issue.record("expected .regex, got \(result)")
            return
        }
        #expect(r.pattern == #"\d+"#)
    }

    @Test("regex literal prints as #\"pattern\"")
    func regexPrints() throws {
        let result = try swish.eval(#"#"\d+""#)
        #expect(Printer().printString(result) == #"#"\d+""#)
    }

    @Test("two separately-created regexes with the same pattern are not equal")
    func regexEqualitySamePattern() throws {
        let a = try swish.eval(#"#"\d+""#)
        let b = try swish.eval(#"#"\d+""#)
        #expect(a != b)
    }

    @Test("the same regex binding is equal to itself")
    func regexIdentity() throws {
        #expect(try swish.eval(#"(let [r #"\d+"] (= r r))"#) == .boolean(true))
    }

    @Test("two regexes with different patterns are not equal")
    func regexEqualityDifferentPattern() throws {
        let a = try swish.eval(#"#"\d+""#)
        let b = try swish.eval(#"#"\w+""#)
        #expect(a != b)
    }

    @Test("regex can be used as a map key when looked up by the same instance")
    func regexAsMapKey() throws {
        #expect(try swish.eval(#"(let [r #"\d+"] (get {r :digits} r))"#) == .keyword("digits"))
    }

    @Test("escaped quote inside regex pattern")
    func regexEscapedQuote() throws {
        let result = try swish.eval(#"#"say \"hi\"""#)
        guard case .regex(let r) = result else {
            Issue.record("expected .regex, got \(result)")
            return
        }
        #expect(r.pattern == #"say \"hi\""#)
    }

    @Test("backslash sequences pass through intact for the regex engine")
    func regexBackslashPassthrough() throws {
        let result = try swish.eval(#"#"\d+\.\d+""#)
        guard case .regex(let r) = result else {
            Issue.record("expected .regex, got \(result)")
            return
        }
        #expect(r.pattern == #"\d+\.\d+"#)
    }

    @Test("invalid regex pattern throws at read time")
    func regexInvalidPattern() throws {
        #expect(throws: (any Error).self) {
            try swish.eval(#"#"[invalid""#)
        }
    }
}
