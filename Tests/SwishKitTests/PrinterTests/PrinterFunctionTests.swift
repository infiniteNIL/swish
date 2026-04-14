import Testing
@testable import SwishKit

@Suite("Printer Function Tests")
struct PrinterFunctionTests {
    let printer = Printer()

    @Test("prints anonymous function")
    func printsAnonymousFunction() {
        #expect(printer.printString(.function(name: nil, params: ["x"], body: [.symbol("x")])) == "#<fn>")
    }

    @Test("prints named function")
    func printsNamedFunction() {
        #expect(printer.printString(.function(name: "add", params: ["x", "y"], body: [.symbol("x")])) == "#<fn add>")
    }
}
