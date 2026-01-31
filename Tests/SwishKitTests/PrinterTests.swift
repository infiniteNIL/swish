import Foundation
import Testing
@testable import SwishKit

@Suite("Printer Tests")
struct PrinterTests {
    let printer = Printer(locale: Locale(identifier: "en_US"))

    @Suite("Integers")
    struct Integers {
        let printer = Printer(locale: Locale(identifier: "en_US"))

        @Test("prints positive integer")
        func printsPositiveInteger() {
            #expect(printer.printString(.integer(42)) == "42")
        }

        @Test("prints negative integer")
        func printsNegativeInteger() {
            #expect(printer.printString(.integer(-17)) == "-17")
        }

        @Test("prints zero")
        func printsZero() {
            #expect(printer.printString(.integer(0)) == "0")
        }

        @Test("prints large number with thousand separators")
        func printsLargeNumber() {
            #expect(printer.printString(.integer(1_000_000)) == "1,000,000")
        }

        @Test("prints negative large number with thousand separators")
        func printsNegativeLargeNumber() {
            #expect(printer.printString(.integer(-1_000_000)) == "-1,000,000")
        }
    }
}
