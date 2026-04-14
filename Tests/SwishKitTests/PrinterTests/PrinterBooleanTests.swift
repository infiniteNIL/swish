import Testing
@testable import SwishKit

@Suite("Printer Boolean Tests")
struct PrinterBooleanTests {
    let printer = Printer()

    @Test("prints true")
    func printsTrue() {
        #expect(printer.printString(.boolean(true)) == "true")
    }

    @Test("prints false")
    func printsFalse() {
        #expect(printer.printString(.boolean(false)) == "false")
    }
}
