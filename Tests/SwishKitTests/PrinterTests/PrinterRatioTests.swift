import Testing
@testable import SwishKit

@Suite("Printer Ratio Tests")
struct PrinterRatioTests {
    let printer = Printer()

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
        #expect(printer.printString(.ratio(Ratio(1000, 3))) == "1000/3")
    }

    @Test("prints ratio with large denominator")
    func printsRatioWithLargeDenominator() {
        #expect(printer.printString(.ratio(Ratio(1, 1000))) == "1/1000")
    }
}
