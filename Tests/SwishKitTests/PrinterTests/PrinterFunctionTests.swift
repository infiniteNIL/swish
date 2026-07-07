import Testing
@testable import SwishKit

@Suite("Printer Function Tests")
struct PrinterFunctionTests {
    let printer = Printer()

    @Test("prints anonymous function")
    func printsAnonymousFunction() {
        #expect(printer.printString(.function(SwishFunction(name: nil, params: ["x"], body: [.symbol("x", metadata: nil)], capturedEnv: nil, metadata: nil))) == "#<fn>")
    }

    @Test("prints named function")
    func printsNamedFunction() {
        #expect(printer.printString(.function(SwishFunction(name: "add", params: ["x", "y"], body: [.symbol("x", metadata: nil)], capturedEnv: nil, metadata: nil))) == "#<fn add>")
    }
}
