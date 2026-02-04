import Testing
@testable import SwishKit

@Suite("Printer Tests")
struct PrinterTests {
    let printer = Printer()

    @Suite("Integers")
    struct Integers {
        let printer = Printer()

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

        @Test("prints large number")
        func printsLargeNumber() {
            #expect(printer.printString(.integer(1_000_000)) == "1000000")
        }

        @Test("prints negative large number")
        func printsNegativeLargeNumber() {
            #expect(printer.printString(.integer(-1_000_000)) == "-1000000")
        }
    }

    @Suite("Floats")
    struct Floats {
        let printer = Printer()

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

        @Test("prints large float")
        func printsLargeFloat() {
            #expect(printer.printString(.float(1_000_000.5)) == "1000000.5")
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

    @Suite("Strings")
    struct Strings {
        let printer = Printer()

        @Test("prints basic string with quotes")
        func printsBasicString() {
            #expect(printer.printString(.string("hello")) == "\"hello\"")
        }

        @Test("prints empty string")
        func printsEmptyString() {
            #expect(printer.printString(.string("")) == "\"\"")
        }

        @Test("prints string with escaped quote")
        func printsStringWithEscapedQuote() {
            #expect(printer.printString(.string("say \"hi\"")) == "\"say \\\"hi\\\"\"")
        }

        @Test("prints string with escaped backslash")
        func printsStringWithEscapedBackslash() {
            #expect(printer.printString(.string("a\\b")) == "\"a\\\\b\"")
        }

        @Test("prints string with escaped newline")
        func printsStringWithEscapedNewline() {
            #expect(printer.printString(.string("line1\nline2")) == "\"line1\\nline2\"")
        }

        @Test("prints string with escaped tab")
        func printsStringWithEscapedTab() {
            #expect(printer.printString(.string("col1\tcol2")) == "\"col1\\tcol2\"")
        }

        @Test("prints string with escaped carriage return")
        func printsStringWithEscapedCarriageReturn() {
            #expect(printer.printString(.string("line1\rline2")) == "\"line1\\rline2\"")
        }

        @Test("prints string with escaped null")
        func printsStringWithEscapedNull() {
            #expect(printer.printString(.string("a\0b")) == "\"a\\0b\"")
        }

        @Test("prints string with multiple special characters")
        func printsStringWithMultipleSpecialChars() {
            #expect(printer.printString(.string("\"\\\n\t")) == "\"\\\"\\\\\\n\\t\"")
        }
    }

    @Suite("Characters")
    struct Characters {
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

    @Suite("Booleans")
    struct Booleans {
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

    @Suite("Nil")
    struct Nil {
        let printer = Printer()

        @Test("prints nil")
        func printsNil() {
            #expect(printer.printString(.nil) == "nil")
        }
    }

    @Suite("Symbols")
    struct Symbols {
        let printer = Printer()

        @Test("prints simple symbol")
        func printsSimpleSymbol() {
            #expect(printer.printString(.symbol("foo")) == "foo")
        }

        @Test("prints hyphenated symbol")
        func printsHyphenatedSymbol() {
            #expect(printer.printString(.symbol("foo-bar")) == "foo-bar")
        }

        @Test("prints special char symbol")
        func printsSpecialCharSymbol() {
            #expect(printer.printString(.symbol("*foo*")) == "*foo*")
        }

        @Test("prints + symbol")
        func printsPlusSymbol() {
            #expect(printer.printString(.symbol("+")) == "+")
        }

        @Test("prints - symbol")
        func printsMinusSymbol() {
            #expect(printer.printString(.symbol("-")) == "-")
        }

        @Test("prints / symbol")
        func printsSlashSymbol() {
            #expect(printer.printString(.symbol("/")) == "/")
        }

        @Test("prints namespaced symbol")
        func printsNamespacedSymbol() {
            #expect(printer.printString(.symbol("clojure.core/map")) == "clojure.core/map")
        }
    }

    @Suite("Keywords")
    struct Keywords {
        let printer = Printer()

        @Test("prints simple keyword with colon prefix")
        func printsSimpleKeyword() {
            #expect(printer.printString(.keyword("foo")) == ":foo")
        }

        @Test("prints hyphenated keyword")
        func printsHyphenatedKeyword() {
            #expect(printer.printString(.keyword("foo-bar")) == ":foo-bar")
        }

        @Test("prints namespaced keyword")
        func printsNamespacedKeyword() {
            #expect(printer.printString(.keyword("user/name")) == ":user/name")
        }

        @Test("prints :true keyword")
        func printsTrueKeyword() {
            #expect(printer.printString(.keyword("true")) == ":true")
        }

        @Test("prints :false keyword")
        func printsFalseKeyword() {
            #expect(printer.printString(.keyword("false")) == ":false")
        }

        @Test("prints :nil keyword")
        func printsNilKeyword() {
            #expect(printer.printString(.keyword("nil")) == ":nil")
        }
    }

    @Suite("Lists")
    struct Lists {
        let printer = Printer()

        @Test("prints empty list")
        func printsEmptyList() {
            #expect(printer.printString(.list([])) == "()")
        }

        @Test("prints list with single element")
        func printsListWithSingleElement() {
            #expect(printer.printString(.list([.integer(42)])) == "(42)")
        }

        @Test("prints list with multiple elements")
        func printsListWithMultipleElements() {
            #expect(printer.printString(.list([.integer(1), .integer(2), .integer(3)])) == "(1 2 3)")
        }

        @Test("prints list with mixed types")
        func printsListWithMixedTypes() {
            #expect(printer.printString(.list([.keyword("foo"), .string("bar"), .integer(42)])) == "(:foo \"bar\" 42)")
        }

        @Test("prints nested list")
        func printsNestedList() {
            #expect(printer.printString(.list([.integer(1), .list([.integer(2), .integer(3)]), .integer(4)])) == "(1 (2 3) 4)")
        }

        @Test("prints deeply nested list")
        func printsDeeplyNestedList() {
            #expect(printer.printString(.list([.list([.list([.integer(1)])])])) == "(((1)))")
        }

        @Test("prints list with symbols")
        func printsListWithSymbols() {
            #expect(printer.printString(.list([.symbol("+"), .integer(1), .integer(2)])) == "(+ 1 2)")
        }
    }
}
