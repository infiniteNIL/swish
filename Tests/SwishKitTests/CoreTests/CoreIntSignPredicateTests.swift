import Testing
@testable import SwishKit

@Suite("Core neg-int?/pos-int?/nat-int? Tests", .serialized)
struct CoreIntSignPredicateTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // 0/2 is deliberately excluded here: it reduces to the plain integer 0
    // (matching real Clojure's ratio auto-reduction), so it's not "false for
    // all three" the way every other case in this list is — nat-int? (0)
    // correctly returns true for it. Tested explicitly per-function below.
    static let nonIntCases = [
        "0.0", "1.0", "-1.0", "1.7976931348623157e+308", "4.9e-324",
        "##Inf", "##-Inf", "##NaN",
        "0N", "1N", "-1N", "0.0M", "1.0M", "-1.0M",
        "1/2", "-1/2",
        "nil", "true", "false",
        "\"a string\"", "\"0\"", "\"1\"", "\"-1\"",
        "{:a :map}", "#{:a-set}", "[:a :vector]", "'(:a :list)",
        "\\0", "\\1",
        ":a-keyword", ":0", ":1", ":-1", "'a-sym",
    ]

    // MARK: - neg-int?

    @Test("neg-int? is true for negative integers, including Int64.min")
    func negIntTrue() throws {
        #expect(try swish.eval("(neg-int? -1)") == .boolean(true))
        #expect(try swish.eval("(neg-int? -9223372036854775808)") == .boolean(true))
    }

    @Test("neg-int? is false for zero, positive integers, and Int64.max")
    func negIntFalseForNonNegative() throws {
        #expect(try swish.eval("(neg-int? 0)") == .boolean(false))
        #expect(try swish.eval("(neg-int? 1)") == .boolean(false))
        #expect(try swish.eval("(neg-int? 9223372036854775807)") == .boolean(false))
    }

    @Test("neg-int? is false for non-fixed-precision-integer and non-numeric types")
    func negIntFalseCases() throws {
        for c in Self.nonIntCases {
            #expect(try swish.eval("(neg-int? \(c))") == .boolean(false))
        }
        #expect(try swish.eval("(neg-int? 0/2)") == .boolean(false))
    }

    // MARK: - pos-int?

    @Test("pos-int? is true for positive integers, including Int64.max")
    func posIntTrue() throws {
        #expect(try swish.eval("(pos-int? 1)") == .boolean(true))
        #expect(try swish.eval("(pos-int? 9223372036854775807)") == .boolean(true))
    }

    @Test("pos-int? is false for zero, negative integers, and Int64.min")
    func posIntFalseForNonPositive() throws {
        #expect(try swish.eval("(pos-int? 0)") == .boolean(false))
        #expect(try swish.eval("(pos-int? -1)") == .boolean(false))
        #expect(try swish.eval("(pos-int? -9223372036854775808)") == .boolean(false))
    }

    @Test("pos-int? is false for non-fixed-precision-integer and non-numeric types")
    func posIntFalseCases() throws {
        for c in Self.nonIntCases {
            #expect(try swish.eval("(pos-int? \(c))") == .boolean(false))
        }
        #expect(try swish.eval("(pos-int? 0/2)") == .boolean(false))
    }

    // MARK: - nat-int?

    @Test("nat-int? is true for zero and positive integers, including Int64.max")
    func natIntTrue() throws {
        #expect(try swish.eval("(nat-int? 0)") == .boolean(true))
        #expect(try swish.eval("(nat-int? 1)") == .boolean(true))
        #expect(try swish.eval("(nat-int? 9223372036854775807)") == .boolean(true))
    }

    @Test("nat-int? is true for 0/2, which reduces to the plain integer 0")
    func natIntTrueForReducedZeroRatio() throws {
        #expect(try swish.eval("(nat-int? 0/2)") == .boolean(true))
    }

    @Test("nat-int? is false for negative integers, including Int64.min")
    func natIntFalseForNegative() throws {
        #expect(try swish.eval("(nat-int? -1)") == .boolean(false))
        #expect(try swish.eval("(nat-int? -9223372036854775808)") == .boolean(false))
    }

    @Test("nat-int? is false for non-fixed-precision-integer and non-numeric types")
    func natIntFalseCases() throws {
        for c in Self.nonIntCases {
            #expect(try swish.eval("(nat-int? \(c))") == .boolean(false))
        }
    }
}
