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
}
