import Testing
import BigInt
import BigDecimal
@testable import SwishKit

@Suite("Printer BigInt / BigDecimal Tests")
struct PrinterBigNumberTests {
    let printer = Printer()

    @Test("Prints BigInt with N suffix")
    func printBigInteger() {
        #expect(printer.printString(.bigInteger(BigInt(42))) == "42N")
    }

    @Test("Prints negative BigInt with N suffix")
    func printNegativeBigInteger() {
        #expect(printer.printString(.bigInteger(BigInt(-99))) == "-99N")
    }

    @Test("Prints large BigInt with N suffix")
    func printLargeBigInteger() {
        let big: BigInt = "179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368"
        #expect(printer.printString(.bigInteger(big)).hasSuffix("N"))
    }

    @Test("Prints BigDecimal with M suffix")
    func printBigDecimal() {
        #expect(printer.printString(.bigDecimal(BigDecimal("1.5")!)) == "1.5M")
    }

    @Test("Prints negative BigDecimal with M suffix")
    func printNegativeBigDecimal() {
        #expect(printer.printString(.bigDecimal(BigDecimal("-3.14")!)) == "-3.14M")
    }

    @Test("Prints BigDecimal zero with M suffix")
    func printBigDecimalZero() {
        let result = printer.printString(.bigDecimal(BigDecimal("0.0")!))
        #expect(result.hasSuffix("M"))
    }
}
