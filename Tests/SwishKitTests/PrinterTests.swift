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

    @Suite("Floats")
    struct Floats {
        let printer = Printer(locale: Locale(identifier: "en_US"))

        @Test("prints positive float")
        func printsPositiveFloat() {
            #expect(printer.printString(.float(3.14)) == "3.14")
        }

        @Test("prints negative float")
        func printsNegativeFloat() {
            #expect(printer.printString(.float(-2.5)) == "-2.5")
        }

        @Test("prints float zero with decimal")
        func printsFloatZero() {
            #expect(printer.printString(.float(0.0)) == "0.0")
        }

        @Test("prints whole number float with decimal")
        func printsWholeNumberFloat() {
            #expect(printer.printString(.float(42.0)) == "42.0")
        }

        @Test("prints large float with thousand separators")
        func printsLargeFloat() {
            #expect(printer.printString(.float(1_000_000.5)) == "1,000,000.5")
        }

        @Test("prints small float")
        func printsSmallFloat() {
            #expect(printer.printString(.float(0.01)) == "0.01")
        }

        @Test("prints very small float")
        func printsVerySmallFloat() {
            #expect(printer.printString(.float(0.00001)) == "0.00001")
        }
    }

    @Suite("Ratios")
    struct Ratios {
        let printer = Printer(locale: Locale(identifier: "en_US"))

        @Test("prints basic ratio")
        func printsBasicRatio() {
            #expect(printer.printString(.ratio(Ratio(3, 4))) == "3/4")
        }

        @Test("prints negative ratio")
        func printsNegativeRatio() {
            #expect(printer.printString(.ratio(Ratio(-3, 4))) == "-3/4")
        }

        @Test("prints ratio with large numbers")
        func printsRatioWithLargeNumbers() {
            #expect(printer.printString(.ratio(Ratio(1000, 3))) == "1,000/3")
        }

        @Test("prints ratio with large denominator")
        func printsRatioWithLargeDenominator() {
            #expect(printer.printString(.ratio(Ratio(1, 1000))) == "1/1,000")
        }
    }
}
