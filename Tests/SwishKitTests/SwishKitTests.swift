import Testing
@testable import SwishKit

@Suite("SwishKit Tests")
struct SwishKitTests {
    @Test("Evaluates integer through full pipeline")
    func evaluatesInteger() throws {
        let swish = Swish()
        #expect(try swish.eval("42") == "42")
        #expect(try swish.eval("-17") == "-17")
        #expect(try swish.eval("0") == "0")
    }

    @Test("Throws error for invalid input")
    func throwsErrorForInvalidInput() {
        let swish = Swish()
        #expect(throws: LexerError.self) {
            _ = try swish.eval("hello")
        }
    }

    @Test("Uses Int for small numbers")
    func usesIntForSmall() throws {
        let swish = Swish()
        #expect(try swish.eval("42") == "42")
    }

    @Test("Handles Int.max")
    func handlesIntMax() throws {
        let swish = Swish()
        let intMax = "9223372036854775807"
        #expect(try swish.eval(intMax) == intMax)
    }

    @Test("Promotes to BigInt for large numbers")
    func promotesToBigInt() throws {
        let swish = Swish()
        let huge = "123456789012345678901234567890"
        #expect(try swish.eval(huge) == huge)
    }

    @Test("Handles number just above Int.max")
    func handlesJustAboveIntMax() throws {
        let swish = Swish()
        let justAboveMax = "9223372036854775808"
        #expect(try swish.eval(justAboveMax) == justAboveMax)
    }
}
