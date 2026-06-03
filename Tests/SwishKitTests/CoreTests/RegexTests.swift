import Testing
@testable import SwishKit

@Suite("Regex Literal Tests", .serialized)
struct RegexTests {
    nonisolated(unsafe) static let _shared = Swish()
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

    @Test("two regexes with the same pattern are equal")
    func regexEqualitySamePattern() throws {
        let a = try swish.eval(#"#"\d+""#)
        let b = try swish.eval(#"#"\d+""#)
        #expect(a == b)
    }

    @Test("two regexes with different patterns are not equal")
    func regexEqualityDifferentPattern() throws {
        let a = try swish.eval(#"#"\d+""#)
        let b = try swish.eval(#"#"\w+""#)
        #expect(a != b)
    }

    @Test("regex can be used as a map key")
    func regexAsMapKey() throws {
        let result = try swish.eval(#"{#"\d+" :digits}"#)
        guard case .map(let m, _) = result else {
            Issue.record("expected .map, got \(result)")
            return
        }
        let key = Expr.regex(try SwishRegex(pattern: #"\d+"#))
        #expect(m[key] == .keyword("digits"))
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
