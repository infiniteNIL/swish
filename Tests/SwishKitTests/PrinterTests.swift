import Testing
@testable import SwishKit

@Suite("Printer Tests")
struct PrinterTests {
    @Suite("Integers")
    struct Integers {
        @Test("prints positive integer")
        func printsPositiveInteger() {
            #expect(printString(.integer(.int(42))) == "42")
        }

        @Test("prints negative integer")
        func printsNegativeInteger() {
            #expect(printString(.integer(.int(-17))) == "-17")
        }

        @Test("prints zero")
        func printsZero() {
            #expect(printString(.integer(.int(0))) == "0")
        }
    }
}
