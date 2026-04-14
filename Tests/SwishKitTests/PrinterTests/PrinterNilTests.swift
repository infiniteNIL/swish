import Testing
@testable import SwishKit

@Suite("Printer Nil Tests")
struct PrinterNilTests {
    let printer = Printer()

    @Test("prints nil")
    func printsNil() {
        #expect(printer.printString(.nil) == "nil")
    }
}
