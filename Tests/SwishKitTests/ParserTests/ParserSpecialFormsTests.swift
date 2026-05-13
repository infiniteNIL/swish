import Testing
@testable import SwishKit

@Suite("Parser Special Forms Tests")
struct ParserSpecialFormsTests {
    // MARK: - let validation

    @Test("Parses let with empty bindings and no body")
    func parseLetEmptyBindings() throws {
        let exprs = try Reader.readString("(let [])")
        #expect(exprs == [.list([.symbol("let"), .vector([])])])
    }

    @Test("Parses let with bindings and body")
    func parseLetWithBindingsAndBody() throws {
        let exprs = try Reader.readString("(let [x 1] x)")
        #expect(exprs == [.list([.symbol("let"), .vector([.symbol("x"), .integer(1)]), .symbol("x")])])
    }

    @Test("Throws invalidLet when binding vector is missing")
    func letMissingVectorThrows() throws {
        #expect(throws: ParserError.invalidLet("let requires a binding vector")) {
            try Reader.readString("(let)")
        }
    }

    @Test("Throws invalidLet when first argument is not a vector")
    func letFirstArgNotVectorThrows() throws {
        #expect(throws: ParserError.invalidLet("first argument to let must be a vector")) {
            try Reader.readString("(let x 1)")
        }
    }

    @Test("Throws invalidLet when binding vector has odd number of forms")
    func letOddBindingsThrows() throws {
        #expect(throws: ParserError.invalidLet("let binding vector requires an even number of forms")) {
            try Reader.readString("(let [x])")
        }
    }

    @Test("Throws invalidLet when binding target is not a symbol")
    func letNonSymbolBindingTargetThrows() throws {
        #expect(throws: ParserError.invalidLet("binding targets in let must be symbols")) {
            try Reader.readString("(let [1 2])")
        }
    }

    // MARK: - fn special form

    @Test("Parses anonymous fn with params and body")
    func parsesAnonymousFn() throws {
        let result = try Reader.readString("(fn [x] x)")
        #expect(result == [.list([.symbol("fn"), .vector([.symbol("x")]), .symbol("x")])])
    }

    @Test("Parses named fn")
    func parsesNamedFn() throws {
        let result = try Reader.readString("(fn square [x] (* x x))")
        #expect(result == [.list([
            .symbol("fn"), .symbol("square"),
            .vector([.symbol("x")]),
            .list([.symbol("*"), .symbol("x"), .symbol("x")])
        ])])
    }

    @Test("Parses fn with empty params")
    func parsesFnWithEmptyParams() throws {
        let result = try Reader.readString("(fn [] 42)")
        #expect(result == [.list([.symbol("fn"), .vector([]), .integer(42)])])
    }

    @Test("Throws invalidFn when parameter vector is missing")
    func fnMissingParamVectorThrows() throws {
        #expect(throws: ParserError.invalidFn("fn requires a parameter vector")) {
            try Reader.readString("(fn)")
        }
    }

    @Test("Throws invalidFn when first argument is not a vector")
    func fnFirstArgNotVectorThrows() throws {
        #expect(throws: ParserError.invalidFn("fn requires a parameter vector")) {
            try Reader.readString("(fn 42)")
        }
    }

    @Test("Throws invalidFn when a parameter is not a symbol")
    func fnNonSymbolParamThrows() throws {
        #expect(throws: ParserError.invalidFn("fn parameters must be symbols")) {
            try Reader.readString("(fn [42] x)")
        }
    }

    // MARK: - Unquote / unquote-splicing reader macros

    @Test("~x expands to (unquote x)")
    func unquoteSymbolExpands() throws {
        let result = try Reader.readString("~x")
        #expect(result == [.list([.symbol("unquote"), .symbol("x")])])
    }

    @Test("~@xs expands to (unquote-splicing xs)")
    func unquoteSplicingSymbolExpands() throws {
        let result = try Reader.readString("~@xs")
        #expect(result == [.list([.symbol("unquote-splicing"), .symbol("xs")])])
    }

    @Test("~(+ 1 2) expands to (unquote (+ 1 2))")
    func unquoteListExpands() throws {
        let result = try Reader.readString("~(+ 1 2)")
        #expect(result == [.list([
            .symbol("unquote"),
            .list([.symbol("+"), .integer(1), .integer(2)])
        ])])
    }

    @Test("`~x expands to (syntax-quote (unquote x))")
    func backtickUnquoteExpands() throws {
        let result = try Reader.readString("`~x")
        #expect(result == [.list([
            .symbol("syntax-quote"),
            .list([.symbol("unquote"), .symbol("x")])
        ])])
    }

    @Test("`(1 ~x 3) expands to (syntax-quote (1 (unquote x) 3))")
    func backtickListWithUnquoteExpands() throws {
        let result = try Reader.readString("`(1 ~x 3)")
        #expect(result == [.list([
            .symbol("syntax-quote"),
            .list([
                .integer(1),
                .list([.symbol("unquote"), .symbol("x")]),
                .integer(3)
            ])
        ])])
    }

    @Test("`(1 ~@xs 3) expands to (syntax-quote (1 (unquote-splicing xs) 3))")
    func backtickListWithUnquoteSplicingExpands() throws {
        let result = try Reader.readString("`(1 ~@xs 3)")
        #expect(result == [.list([
            .symbol("syntax-quote"),
            .list([
                .integer(1),
                .list([.symbol("unquote-splicing"), .symbol("xs")]),
                .integer(3)
            ])
        ])])
    }

    @Test("`(~x ~@xs) expands correctly")
    func backtickMixedUnquoteExpands() throws {
        let result = try Reader.readString("`(~x ~@xs)")
        #expect(result == [.list([
            .symbol("syntax-quote"),
            .list([
                .list([.symbol("unquote"), .symbol("x")]),
                .list([.symbol("unquote-splicing"), .symbol("xs")])
            ])
        ])])
    }

    // MARK: - defmacro parsing

    @Test("defmacro parses correctly")
    func defmacroParses() throws {
        let result = try Reader.readString("(defmacro m [x] x)")
        #expect(result == [.list([
            .symbol("defmacro"),
            .symbol("m"),
            .vector([.symbol("x")]),
            .symbol("x")
        ])])
    }

    @Test("defmacro with multiple body forms parses correctly")
    func defmacroMultipleBodyForms() throws {
        let result = try Reader.readString("(defmacro m [x y] x y)")
        #expect(result == [.list([
            .symbol("defmacro"),
            .symbol("m"),
            .vector([.symbol("x"), .symbol("y")]),
            .symbol("x"),
            .symbol("y")
        ])])
    }

    @Test("defmacro requires a symbol name")
    func defmacroRequiresSymbolName() throws {
        #expect(throws: ParserError.invalidDefmacro("first argument to defmacro must be a symbol")) {
            try Reader.readString("(defmacro 42 [x] x)")
        }
    }

    @Test("defmacro requires a parameter vector")
    func defmacroRequiresParamVector() throws {
        #expect(throws: ParserError.invalidDefmacro("second argument to defmacro must be a parameter vector")) {
            try Reader.readString("(defmacro m x x)")
        }
    }

    @Test("defmacro with empty body parses successfully")
    func defmacroEmptyBodyParses() throws {
        let result = try Reader.readString("(defmacro m [x])")
        #expect(result == [.list([.symbol("defmacro"), .symbol("m"), .vector([.symbol("x")])])])
    }

    @Test("defmacro with docstring parses successfully")
    func defmacroWithDocstringParses() throws {
        let result = try Reader.readString("(defmacro m \"doc\" [x] x)")
        #expect(result == [.list([
            .symbol("defmacro"), .symbol("m"),
            .string("doc"),
            .vector([.symbol("x")]),
            .symbol("x")
        ])])
    }

    @Test("defmacro with docstring and empty body parses successfully")
    func defmacroWithDocstringEmptyBodyParses() throws {
        let result = try Reader.readString("(defmacro m \"doc\" [x])")
        #expect(result == [.list([
            .symbol("defmacro"), .symbol("m"),
            .string("doc"),
            .vector([.symbol("x")])
        ])])
    }

    @Test("defmacro parameters must be symbols")
    func defmacroParamsMustBeSymbols() throws {
        #expect(throws: ParserError.invalidDefmacro("defmacro parameters must be symbols")) {
            try Reader.readString("(defmacro m [42] 42)")
        }
    }

    @Test("defmacro with variadic & rest param parses correctly")
    func defmacroVariadicParses() throws {
        let result = try Reader.readString("(defmacro m [x & rest] rest)")
        #expect(result == [.list([
            .symbol("defmacro"),
            .symbol("m"),
            .vector([.symbol("x"), .symbol("&"), .symbol("rest")]),
            .symbol("rest")
        ])])
    }

    @Test("fn with & rest param parses correctly")
    func fnVariadicParses() throws {
        let result = try Reader.readString("(fn [x & rest] rest)")
        #expect(result == [.list([
            .symbol("fn"),
            .vector([.symbol("x"), .symbol("&"), .symbol("rest")]),
            .symbol("rest")
        ])])
    }

    @Test("fn & with nothing after it throws invalidFn")
    func fnAmpersandAloneThrows() throws {
        #expect(throws: ParserError.invalidFn("fn & must be followed by exactly one symbol")) {
            try Reader.readString("(fn [x &] x)")
        }
    }

    @Test("fn & with more than one symbol after it throws invalidFn")
    func fnAmpersandTooManyThrows() throws {
        #expect(throws: ParserError.invalidFn("fn & must be followed by exactly one symbol")) {
            try Reader.readString("(fn [x & a b] x)")
        }
    }

    // MARK: - Discard macro

    @Test("#_42 at top level discards the form")
    func discardAtTopLevel() throws {
        let result = try Reader.readString("#_42")
        #expect(result == [])
    }

    @Test("#_ discards form inside a list")
    func discardInsideList() throws {
        let result = try Reader.readString("(+ 1 #_2 3)")
        #expect(result == [.list([.symbol("+"), .integer(1), .integer(3)])])
    }

    @Test("#_ discards form inside a vector")
    func discardInsideVector() throws {
        let result = try Reader.readString("[a #_b c]")
        #expect(result == [.vector([.symbol("a"), .symbol("c")])])
    }

    @Test("#_ before closing paren discards last element")
    func discardBeforeClosingParen() throws {
        let result = try Reader.readString("(a #_b)")
        #expect(result == [.list([.symbol("a")])])
    }

    @Test("#_ with no following form throws unexpectedEOF")
    func discardWithNoFormThrows() throws {
        #expect(throws: ParserError.unexpectedEOF) {
            try Reader.readString("#_")
        }
    }
}
