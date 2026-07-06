import Testing
@testable import SwishKit

@Suite("Printer Float Tests")
struct PrinterFloatTests {
    let printer = Printer()

    @Test("prints positive float")
    func printsPositiveFloat() {
        #expect(printer.printString(.double(3.14)) == "3.14")
    }

    @Test("prints negative float")
    func printsNegativeFloat() {
        #expect(printer.printString(.double(-2.5)) == "-2.5")
    }

    @Test("prints float zero with decimal")
    func printsFloatZero() {
        #expect(printer.printString(.double(0.0)) == "0.0")
    }

    @Test("prints whole number float with decimal")
    func printsWholeNumberFloat() {
        #expect(printer.printString(.double(42.0)) == "42.0")
    }

    @Test("prints large float")
    func printsLargeFloat() {
        #expect(printer.printString(.double(1_000_000.5)) == "1000000.5")
    }

    @Test("prints small float")
    func printsSmallFloat() {
        #expect(printer.printString(.double(0.01)) == "0.01")
    }

    @Test("prints very small float")
    func printsVerySmallFloat() {
        #expect(printer.printString(.double(0.00001)) == "0.00001")
    }
}
