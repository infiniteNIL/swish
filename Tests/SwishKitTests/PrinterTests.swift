import Testing
@testable import SwishKit

@Suite("Printer Tests")
struct PrinterTests {
    @Suite("Integers")
    struct Integers {
        @Test("prints positive integer")
        func printsPositiveInteger() {
            #expect(printString(.integer(42)) == "42")
        }

        @Test("prints negative integer")
        func printsNegativeInteger() {
            #expect(printString(.integer(-17)) == "-17")
        }

        @Test("prints zero")
        func printsZero() {
            #expect(printString(.integer(0)) == "0")
        }
    }
}
