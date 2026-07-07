import Testing
@testable import SwishKit

@Suite("Evaluator >= and <= NaN Tests", .serialized)
struct EvaluatorGtEqLtEqNaNTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - >= NaN cases

    @Test(">= 1 NaN is false")
    func gtEqOneNaN() throws {
        #expect(try swish.eval("(>= 1 ##NaN)") == .boolean(false))
    }

    @Test(">= NaN 1 is false")
    func gtEqNaNOne() throws {
        #expect(try swish.eval("(>= ##NaN 1)") == .boolean(false))
    }

    @Test(">= NaN NaN is false")
    func gtEqNaNNaN() throws {
        #expect(try swish.eval("(>= ##NaN ##NaN)") == .boolean(false))
    }

    // MARK: - >= regression guards

    @Test(">= 1 0 is true")
    func gtEqOneZero() throws {
        #expect(try swish.eval("(>= 1 0)") == .boolean(true))
    }

    @Test(">= 0 1 is false")
    func gtEqZeroOne() throws {
        #expect(try swish.eval("(>= 0 1)") == .boolean(false))
    }

    @Test(">= 1 1 is true")
    func gtEqOneOne() throws {
        #expect(try swish.eval("(>= 1 1)") == .boolean(true))
    }

    @Test(">= ##Inf ##Inf is true")
    func gtEqInfInf() throws {
        #expect(try swish.eval("(>= ##Inf ##Inf)") == .boolean(true))
    }

    @Test(">= ##-Inf -1 is false")
    func gtEqNegInfNegOne() throws {
        #expect(try swish.eval("(>= ##-Inf -1)") == .boolean(false))
    }

    // MARK: - <= NaN cases

    @Test("<= 1 NaN is false")
    func ltEqOneNaN() throws {
        #expect(try swish.eval("(<= 1 ##NaN)") == .boolean(false))
    }

    @Test("<= NaN 1 is false")
    func ltEqNaNOne() throws {
        #expect(try swish.eval("(<= ##NaN 1)") == .boolean(false))
    }

    @Test("<= NaN NaN is false")
    func ltEqNaNNaN() throws {
        #expect(try swish.eval("(<= ##NaN ##NaN)") == .boolean(false))
    }

    // MARK: - <= regression guards

    @Test("<= 0 1 is true")
    func ltEqZeroOne() throws {
        #expect(try swish.eval("(<= 0 1)") == .boolean(true))
    }

    @Test("<= 1 0 is false")
    func ltEqOneZero() throws {
        #expect(try swish.eval("(<= 1 0)") == .boolean(false))
    }

    @Test("<= 1 1 is true")
    func ltEqOneOne() throws {
        #expect(try swish.eval("(<= 1 1)") == .boolean(true))
    }

    @Test("<= ##-Inf ##-Inf is true")
    func ltEqNegInfNegInf() throws {
        #expect(try swish.eval("(<= ##-Inf ##-Inf)") == .boolean(true))
    }

    @Test("<= 1 ##Inf is true")
    func ltEqOneInf() throws {
        #expect(try swish.eval("(<= 1 ##Inf)") == .boolean(true))
    }
}
