import Testing
@testable import SwishKit

@Suite("Parser Special Forms Tests")
struct ParserSpecialFormsTests {
    // MARK: - let validation

    @Test("Parses let with empty bindings and no body")
    func parseLetEmptyBindings() throws {
        let exprs = try Reader.readString("(let [])")
        #expect(exprs == [.list([.symbol("let", metadata: nil), .vector([], metadata: nil)], metadata: nil)])
    }

    @Test("Parses let with bindings and body")
    func parseLetWithBindingsAndBody() throws {
        let exprs = try Reader.readString("(let [x 1] x)")
        #expect(exprs == [.list([.symbol("let", metadata: nil), .vector([.symbol("x", metadata: nil), .integer(1)], metadata: nil), .symbol("x", metadata: nil)], metadata: nil)])
    }

    @Test("Throws invalidLet when binding vector is missing")
    func letMissingVectorThrows() throws {
        #expect(throws: ParserError.invalidLet("requires a binding vector", line: 1, column: 1)) {
            try Reader.readString("(let)")
        }
    }

    @Test("Throws invalidLet when first argument is not a vector")
    func letFirstArgNotVectorThrows() throws {
        #expect(throws: ParserError.invalidLet("first argument must be a vector", line: 1, column: 1)) {
            try Reader.readString("(let x 1)")
        }
    }

    @Test("Throws invalidLet when binding vector has odd number of forms")
    func letOddBindingsThrows() throws {
        #expect(throws: ParserError.invalidLet("binding vector requires an even number of forms", line: 1, column: 1)) {
            try Reader.readString("(let [x])")
        }
    }

    @Test("Throws invalidLet when binding target is not a symbol")
    func letNonSymbolBindingTargetThrows() throws {
        #expect(throws: ParserError.invalidLet("binding targets must be symbols, vectors, or maps", line: 1, column: 1)) {
            try Reader.readString("(let [1 2])")
        }
    }

    // MARK: - fn special form

    @Test("Parses anonymous fn with params and body")
    func parsesAnonymousFn() throws {
        let result = try Reader.readString("(fn [x] x)")
        #expect(result == [.list([.symbol("fn", metadata: nil), .vector([.symbol("x", metadata: nil)], metadata: nil), .symbol("x", metadata: nil)], metadata: nil)])
    }

    @Test("Parses named fn")
    func parsesNamedFn() throws {
        let result = try Reader.readString("(fn square [x] (* x x))")
        #expect(result == [.list([
            .symbol("fn", metadata: nil), .symbol("square", metadata: nil),
            .vector([.symbol("x", metadata: nil)], metadata: nil),
            .list([.symbol("*", metadata: nil), .symbol("x", metadata: nil), .symbol("x", metadata: nil)], metadata: nil)
        ], metadata: nil)])
    }

    @Test("Parses fn with empty params")
    func parsesFnWithEmptyParams() throws {
        let result = try Reader.readString("(fn [] 42)")
        #expect(result == [.list([.symbol("fn", metadata: nil), .vector([], metadata: nil), .integer(42)], metadata: nil)])
    }

    @Test("Throws invalidFn when parameter vector is missing")
    func fnMissingParamVectorThrows() throws {
        #expect(throws: ParserError.invalidFn("fn requires a parameter vector", line: 1, column: 1)) {
            try Reader.readString("(fn)")
        }
    }

    @Test("Throws invalidFn when first argument is not a vector")
    func fnFirstArgNotVectorThrows() throws {
        #expect(throws: ParserError.invalidFn("fn requires a parameter vector", line: 1, column: 1)) {
            try Reader.readString("(fn 42)")
        }
    }

    @Test("Throws invalidFn when a parameter is not a symbol")
    func fnNonSymbolParamThrows() throws {
        #expect(throws: ParserError.invalidFn("fn parameters must be symbols, vectors, or maps", line: 1, column: 1)) {
            try Reader.readString("(fn [42] x)")
        }
    }

    // MARK: - Unquote / unquote-splicing reader macros

    @Test("~x expands to (unquote x)")
    func unquoteSymbolExpands() throws {
        let result = try Reader.readString("~x")
        #expect(result == [.list([.symbol("unquote", metadata: nil), .symbol("x", metadata: nil)], metadata: nil)])
    }

    @Test("~@xs expands to (unquote-splicing xs)")
    func unquoteSplicingSymbolExpands() throws {
        let result = try Reader.readString("~@xs")
        #expect(result == [.list([.symbol("unquote-splicing", metadata: nil), .symbol("xs", metadata: nil)], metadata: nil)])
    }

    @Test("~(+ 1 2) expands to (unquote (+ 1 2))")
    func unquoteListExpands() throws {
        let result = try Reader.readString("~(+ 1 2)")
        #expect(result == [.list([
            .symbol("unquote", metadata: nil),
            .list([.symbol("+", metadata: nil), .integer(1), .integer(2)], metadata: nil)
        ], metadata: nil)])
    }

    @Test("`~x expands to (syntax-quote (unquote x))")
    func backtickUnquoteExpands() throws {
        let result = try Reader.readString("`~x")
        #expect(result == [.list([
            .symbol("syntax-quote", metadata: nil),
            .list([.symbol("unquote", metadata: nil), .symbol("x", metadata: nil)], metadata: nil)
        ], metadata: nil)])
    }

    @Test("`(1 ~x 3) expands to (syntax-quote (1 (unquote x) 3))")
    func backtickListWithUnquoteExpands() throws {
        let result = try Reader.readString("`(1 ~x 3)")
        #expect(result == [.list([
            .symbol("syntax-quote", metadata: nil),
            .list([
                .integer(1),
                .list([.symbol("unquote", metadata: nil), .symbol("x", metadata: nil)], metadata: nil),
                .integer(3)
            ], metadata: nil)
        ], metadata: nil)])
    }

    @Test("`(1 ~@xs 3) expands to (syntax-quote (1 (unquote-splicing xs) 3))")
    func backtickListWithUnquoteSplicingExpands() throws {
        let result = try Reader.readString("`(1 ~@xs 3)")
        #expect(result == [.list([
            .symbol("syntax-quote", metadata: nil),
            .list([
                .integer(1),
                .list([.symbol("unquote-splicing", metadata: nil), .symbol("xs", metadata: nil)], metadata: nil),
                .integer(3)
            ], metadata: nil)
        ], metadata: nil)])
    }

    @Test("`(~x ~@xs) expands correctly")
    func backtickMixedUnquoteExpands() throws {
        let result = try Reader.readString("`(~x ~@xs)")
        #expect(result == [.list([
            .symbol("syntax-quote", metadata: nil),
            .list([
                .list([.symbol("unquote", metadata: nil), .symbol("x", metadata: nil)], metadata: nil),
                .list([.symbol("unquote-splicing", metadata: nil), .symbol("xs", metadata: nil)], metadata: nil)
            ], metadata: nil)
        ], metadata: nil)])
    }

    // MARK: - defmacro parsing

    @Test("defmacro parses correctly")
    func defmacroParses() throws {
        let result = try Reader.readString("(defmacro m [x] x)")
        #expect(result == [.list([
            .symbol("defmacro", metadata: nil),
            .symbol("m", metadata: nil),
            .vector([.symbol("x", metadata: nil)], metadata: nil),
            .symbol("x", metadata: nil)
        ], metadata: nil)])
    }

    @Test("defmacro with multiple body forms parses correctly")
    func defmacroMultipleBodyForms() throws {
        let result = try Reader.readString("(defmacro m [x y] x y)")
        #expect(result == [.list([
            .symbol("defmacro", metadata: nil),
            .symbol("m", metadata: nil),
            .vector([.symbol("x", metadata: nil), .symbol("y", metadata: nil)], metadata: nil),
            .symbol("x", metadata: nil),
            .symbol("y", metadata: nil)
        ], metadata: nil)])
    }

    @Test("defmacro requires a symbol name")
    func defmacroRequiresSymbolName() throws {
        #expect(throws: ParserError.invalidDefmacro("first argument to defmacro must be a symbol", line: 1, column: 1)) {
            try Reader.readString("(defmacro 42 [x] x)")
        }
    }

    @Test("defmacro requires a parameter vector")
    func defmacroRequiresParamVector() throws {
        #expect(throws: ParserError.invalidDefmacro("second argument to defmacro must be a parameter vector", line: 1, column: 1)) {
            try Reader.readString("(defmacro m x x)")
        }
    }

    @Test("defmacro with empty body parses successfully")
    func defmacroEmptyBodyParses() throws {
        let result = try Reader.readString("(defmacro m [x])")
        #expect(result == [.list([.symbol("defmacro", metadata: nil), .symbol("m", metadata: nil), .vector([.symbol("x", metadata: nil)], metadata: nil)], metadata: nil)])
    }

    @Test("defmacro with docstring parses successfully")
    func defmacroWithDocstringParses() throws {
        let result = try Reader.readString("(defmacro m \"doc\" [x] x)")
        #expect(result == [.list([
            .symbol("defmacro", metadata: nil), .symbol("m", metadata: nil),
            .string("doc"),
            .vector([.symbol("x", metadata: nil)], metadata: nil),
            .symbol("x", metadata: nil)
        ], metadata: nil)])
    }

    @Test("defmacro with docstring and empty body parses successfully")
    func defmacroWithDocstringEmptyBodyParses() throws {
        let result = try Reader.readString("(defmacro m \"doc\" [x])")
        #expect(result == [.list([
            .symbol("defmacro", metadata: nil), .symbol("m", metadata: nil),
            .string("doc"),
            .vector([.symbol("x", metadata: nil)], metadata: nil)
        ], metadata: nil)])
    }

    @Test("defmacro parameters must be symbols")
    func defmacroParamsMustBeSymbols() throws {
        #expect(throws: ParserError.invalidDefmacro("defmacro parameters must be symbols, vectors, or maps", line: 1, column: 1)) {
            try Reader.readString("(defmacro m [42] 42)")
        }
    }

    @Test("defmacro with variadic & rest param parses correctly")
    func defmacroVariadicParses() throws {
        let result = try Reader.readString("(defmacro m [x & rest] rest)")
        #expect(result == [.list([
            .symbol("defmacro", metadata: nil),
            .symbol("m", metadata: nil),
            .vector([.symbol("x", metadata: nil), .symbol("&", metadata: nil), .symbol("rest", metadata: nil)], metadata: nil),
            .symbol("rest", metadata: nil)
        ], metadata: nil)])
    }

    @Test("fn with & rest param parses correctly")
    func fnVariadicParses() throws {
        let result = try Reader.readString("(fn [x & rest] rest)")
        #expect(result == [.list([
            .symbol("fn", metadata: nil),
            .vector([.symbol("x", metadata: nil), .symbol("&", metadata: nil), .symbol("rest", metadata: nil)], metadata: nil),
            .symbol("rest", metadata: nil)
        ], metadata: nil)])
    }

    @Test("fn & with nothing after it throws invalidFn")
    func fnAmpersandAloneThrows() throws {
        #expect(throws: ParserError.invalidFn("fn & must be followed by exactly one binding form", line: 1, column: 1)) {
            try Reader.readString("(fn [x &] x)")
        }
    }

    @Test("fn & with more than one symbol after it throws invalidFn")
    func fnAmpersandTooManyThrows() throws {
        #expect(throws: ParserError.invalidFn("fn & must be followed by exactly one binding form", line: 1, column: 1)) {
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
        #expect(result == [.list([.symbol("+", metadata: nil), .integer(1), .integer(3)], metadata: nil)])
    }

    @Test("#_ discards form inside a vector")
    func discardInsideVector() throws {
        let result = try Reader.readString("[a #_b c]")
        #expect(result == [.vector([.symbol("a", metadata: nil), .symbol("c", metadata: nil)], metadata: nil)])
    }

    @Test("#_ before closing paren discards last element")
    func discardBeforeClosingParen() throws {
        let result = try Reader.readString("(a #_b)")
        #expect(result == [.list([.symbol("a", metadata: nil)], metadata: nil)])
    }

    @Test("#_ with no following form throws unexpectedEOF")
    func discardWithNoFormThrows() throws {
        #expect(throws: ParserError.unexpectedEOF) {
            try Reader.readString("#_")
        }
    }

    // MARK: - fn multi-arity validation

    @Test("Parses fn with single arity in list syntax")
    func fnSingleArityListSyntax() throws {
        let exprs = try Reader.readString("(fn ([x] x))")
        #expect(exprs.count == 1)
    }

    @Test("Parses fn with multiple arities")
    func fnMultipleArities() throws {
        let exprs = try Reader.readString("(fn ([x] x) ([x y] y))")
        #expect(exprs.count == 1)
    }

    @Test("Parses named fn with multiple arities")
    func fnNamedMultipleArities() throws {
        let exprs = try Reader.readString("(fn add ([x] x) ([x y] y))")
        #expect(exprs.count == 1)
    }

    @Test("Parses fn with variadic arity")
    func fnVariadicArity() throws {
        let exprs = try Reader.readString("(fn ([x] x) ([x & rest] rest))")
        #expect(exprs.count == 1)
    }

    @Test("fn throws when two arities have the same fixed count")
    func fnDuplicateFixedArityThrows() throws {
        #expect(throws: ParserError.invalidFn("fn can't have 2 overloads with same arity", line: 1, column: 1)) {
            try Reader.readString("(fn ([x] x) ([x] y))")
        }
    }

    @Test("fn throws when two variadic arities are specified")
    func fnDuplicateVariadicArityThrows() throws {
        #expect(throws: ParserError.invalidFn("fn can only have 1 variadic overload", line: 1, column: 1)) {
            try Reader.readString("(fn ([x & a] x) ([y & b] y))")
        }
    }

    @Test("fn throws when a non-list appears in multi-arity position")
    func fnArityClauseNotListThrows() throws {
        #expect(throws: ParserError.invalidFn("fn arity clause must be a list", line: 1, column: 1)) {
            try Reader.readString("(fn ([x] x) 42)")
        }
    }

    @Test("fn throws when arity clause doesn't start with a vector")
    func fnArityClauseNoVectorThrows() throws {
        #expect(throws: ParserError.invalidFn("fn arity clause must begin with a parameter vector", line: 1, column: 1)) {
            try Reader.readString("(fn (x x))")
        }
    }

    // MARK: - defmacro multi-arity validation

    @Test("Parses defmacro with multiple arities")
    func defmacroMultipleArities() throws {
        let exprs = try Reader.readString("(defmacro m ([] true) ([x] x))")
        #expect(exprs.count == 1)
    }

    @Test("defmacro throws when two arities have same fixed count")
    func defmacroDuplicateFixedArityThrows() throws {
        #expect(throws: ParserError.invalidDefmacro("defmacro can't have 2 overloads with same arity", line: 1, column: 1)) {
            try Reader.readString("(defmacro m ([] true) ([] false))")
        }
    }
}
