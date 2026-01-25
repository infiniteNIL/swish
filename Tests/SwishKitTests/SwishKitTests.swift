import Testing
@testable import SwishKit

@Suite("SwishKit Tests")
struct SwishKitTests {
    @Test("Evaluates integer through full pipeline")
    func evaluatesInteger() {
        let swish = Swish()
        #expect(swish.eval("42") == "42")
        #expect(swish.eval("-17") == "-17")
        #expect(swish.eval("0") == "0")
    }

    @Test("Returns error for invalid input")
    func returnsErrorForInvalidInput() {
        let swish = Swish()
        let result = swish.eval("hello")
        #expect(result.contains("Lexer error"))
    }
}
