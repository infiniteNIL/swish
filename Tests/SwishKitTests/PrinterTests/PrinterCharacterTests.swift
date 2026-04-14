import Testing
@testable import SwishKit

@Suite("Printer Character Tests")
struct PrinterCharacterTests {
    let printer = Printer()

    @Test("prints simple letter character")
    func printsSimpleLetterCharacter() {
        #expect(printer.printString(.character("a")) == "\\a")
    }

    @Test("prints digit character")
    func printsDigitCharacter() {
        #expect(printer.printString(.character("5")) == "\\5")
    }

    @Test("prints punctuation character")
    func printsPunctuationCharacter() {
        #expect(printer.printString(.character("!")) == "\\!")
    }

    @Test("prints newline as named character")
    func printsNewlineAsNamed() {
        #expect(printer.printString(.character("\n")) == "\\newline")
    }

    @Test("prints tab as named character")
    func printsTabAsNamed() {
        #expect(printer.printString(.character("\t")) == "\\tab")
    }

    @Test("prints space as named character")
    func printsSpaceAsNamed() {
        #expect(printer.printString(.character(" ")) == "\\space")
    }

    @Test("prints return as named character")
    func printsReturnAsNamed() {
        #expect(printer.printString(.character("\r")) == "\\return")
    }

    @Test("prints backspace as named character")
    func printsBackspaceAsNamed() {
        #expect(printer.printString(.character("\u{0008}")) == "\\backspace")
    }

    @Test("prints formfeed as named character")
    func printsFormfeedAsNamed() {
        #expect(printer.printString(.character("\u{000C}")) == "\\formfeed")
    }

    @Test("prints euro sign")
    func printsEuroSign() {
        #expect(printer.printString(.character("€")) == "\\€")
    }

    @Test("prints emoji")
    func printsEmoji() {
        #expect(printer.printString(.character("😀")) == "\\😀")
    }
}
