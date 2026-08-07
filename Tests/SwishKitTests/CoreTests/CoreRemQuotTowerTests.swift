import Testing
@testable import SwishKit
import BigInt

/// `rem`/`quot` over the full numeric tower.
///
/// These back the rewrite that replaced both functions' hand-rolled ~15-case pairwise
/// dispatch with the shared `coerceNumericPair`. Most cases below assert *unchanged*
/// behavior; the `bigInteger`×`double` and `bigInteger`×`bigDecimal` pairs are new —
/// they had no explicit case before and fell through to an integers-only extractor that
/// threw "arguments must be integers", where Clojure returns a value.
@Suite("Core rem/quot Numeric Tower Tests", .serialized)
struct CoreRemQuotTowerTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - Newly-supported pairs (the closed fidelity gap)

    @Test("(rem 10N 3.0) => 1.0 — bigInteger x double now coerces through the float branch")
    func remBigIntegerDouble() throws {
        #expect(try swish.eval("(rem 10N 3.0)") == .double(1.0))
    }

    @Test("(rem 10.0 3N) => 1.0 — and in the other operand order")
    func remDoubleBigInteger() throws {
        #expect(try swish.eval("(rem 10.0 3N)") == .double(1.0))
    }

    @Test("(quot 10N 3.0) => 3.0")
    func quotBigIntegerDouble() throws {
        #expect(try swish.eval("(quot 10N 3.0)") == .double(3.0))
    }

    @Test("(quot 10N 3.0M) => 3M — bigInteger x bigDecimal coerces to the BigDecimal branch")
    func quotBigIntegerBigDecimal() throws {
        #expect(try swish.eval("(= 3M (quot 10N 3.0M))") == .boolean(true))
    }

    @Test("(rem 10N 3.0M) => 1M")
    func remBigIntegerBigDecimal() throws {
        #expect(try swish.eval("(= 1M (rem 10N 3.0M))") == .boolean(true))
    }

    // MARK: - Integer branch

    @Test("(rem 10 3) => 1 and (quot 10 3) => 3, both staying integers")
    func intBranch() throws {
        #expect(try swish.eval("(rem 10 3)") == .integer(1))
        #expect(try swish.eval("(quot 10 3)") == .integer(3))
    }

    @Test("rem/quot truncate toward zero for negative operands, matching Clojure")
    func intBranchNegative() throws {
        #expect(try swish.eval("(rem -10 3)") == .integer(-1))
        #expect(try swish.eval("(quot -10 3)") == .integer(-3))
        #expect(try swish.eval("(rem 10 -3)") == .integer(1))
        #expect(try swish.eval("(quot 10 -3)") == .integer(-3))
    }

    // MARK: - BigInt branch

    @Test("(rem 10N 3N) => 1N and (quot 10N 3N) => 3N, staying bigInteger")
    func bigIntBranch() throws {
        #expect(try swish.eval("(rem 10N 3N)") == .bigInteger(BigInt(1)))
        #expect(try swish.eval("(quot 10N 3N)") == .bigInteger(BigInt(3)))
    }

    @Test("A bigInteger mixed with a plain integer promotes the result to bigInteger")
    func bigIntMixedWithInt() throws {
        #expect(try swish.eval("(rem 10N 3)") == .bigInteger(BigInt(1)))
        #expect(try swish.eval("(quot 10 3N)") == .bigInteger(BigInt(3)))
    }

    // MARK: - Float branch

    @Test("(rem 10.0 3.0) => 1.0 and (quot 10.0 3.0) => 3.0")
    func floatBranch() throws {
        #expect(try swish.eval("(rem 10.0 3.0)") == .double(1.0))
        #expect(try swish.eval("(quot 10.0 3.0)") == .double(3.0))
    }

    @Test("A double mixed with an integer yields a double")
    func floatMixedWithInt() throws {
        #expect(try swish.eval("(rem 10.0 3)") == .double(1.0))
        #expect(try swish.eval("(quot 10 3.0)") == .double(3.0))
    }

    // MARK: - Ratio branch

    @Test("Ratio operands go through ratioRem/ratioQuot and yield bigInteger when whole")
    func ratioBranch() throws {
        #expect(try swish.eval("(quot 7/2 1/2)") == .bigInteger(BigInt(7)))
        #expect(try swish.eval("(rem 7/2 1/2)") == .bigInteger(BigInt(0)))
        #expect(try swish.eval("(quot 7/2 1)") == .bigInteger(BigInt(3)))
    }

    // MARK: - BigDecimal branch

    @Test("BigDecimal operands stay BigDecimal")
    func bigDecimalBranch() throws {
        #expect(try swish.eval("(= 1M (rem 10M 3M))") == .boolean(true))
        #expect(try swish.eval("(= 3M (quot 10M 3M))") == .boolean(true))
        #expect(try swish.eval("(= 1M (rem 10M 3))") == .boolean(true))
    }

    // MARK: - Non-finite operands

    @Test("An infinite divisor gives NaN for rem but 0.0 for quot — they genuinely disagree")
    func infiniteDivisor() throws {
        guard case .double(let r) = try swish.eval("(rem 5 ##Inf)") else {
            Issue.record("expected a double from (rem 5 ##Inf)")
            return
        }
        #expect(r.isNaN)
        #expect(try swish.eval("(quot 5 ##Inf)") == .double(0.0))
    }

    @Test("A non-finite dividend or a NaN divisor throws for both rem and quot")
    func nonFiniteRejected() throws {
        for form in ["(rem ##Inf 3)", "(quot ##Inf 3)", "(rem ##NaN 3)", "(quot ##NaN 3)",
                     "(rem 3 ##NaN)", "(quot 3 ##NaN)"] {
            #expect(throws: (any Error).self, "\(form) should throw") {
                try swish.eval(form)
            }
        }
    }

    // MARK: - Division by zero, on every coerced branch

    @Test("A zero divisor throws on the int, bigInt, float, ratio, and bigDecimal branches alike")
    func divisionByZero() throws {
        for form in ["(rem 10 0)", "(quot 10 0)",
                     "(rem 10N 0N)", "(quot 10N 0N)",
                     "(rem 10.0 0.0)", "(quot 10.0 0.0)",
                     "(rem 7/2 0)", "(quot 7/2 0)",
                     "(rem 10M 0M)", "(quot 10M 0M)"] {
            #expect(throws: (any Error).self, "\(form) should throw") {
                try swish.eval(form)
            }
        }
    }

    // MARK: - Non-numeric operands

    @Test("A non-numeric operand still throws")
    func nonNumeric() throws {
        #expect(throws: (any Error).self) { try swish.eval("(rem \"x\" 3)") }
        #expect(throws: (any Error).self) { try swish.eval("(quot 3 :k)") }
    }
}
