import Testing
@testable import SwishKit

@Suite("Parser Reader Conditional Tests")
struct ParserReaderConditionalTests {

    private func parse(_ source: String) throws -> [Expr] {
        let lexer = Lexer(source)
        let parser = try Parser(lexer)
        return try parser.parse()
    }

    private func eval(_ source: String) throws -> Expr {
        let exprs = try Reader.readString(source)
        var result: Expr = .nil
        for expr in exprs { result = try Evaluator().eval(expr) }
        return result
    }

    // MARK: - #? matching

    @Test("Selects :swish branch")
    func selectsSwishBranch() throws {
        let exprs = try parse(#"#?(:swish "matched" :clj "nope")"#)
        #expect(exprs == [.string("matched")])
    }

    @Test("Selects :default branch when no :swish")
    func selectsDefaultBranch() throws {
        let exprs = try parse(#"#?(:jank "nope" :default "fallback")"#)
        #expect(exprs == [.string("fallback")])
    }

    @Test("Prefers :swish over :default when both present")
    func prefersSwishOverDefault() throws {
        let exprs = try parse(#"#?(:swish "swish" :default "default")"#)
        #expect(exprs == [.string("swish")])
    }

    @Test("Prefers :swish over :clj")
    func prefersSwishOverClj() throws {
        let exprs = try parse(#"#?(:swish "swish" :clj "clj")"#)
        #expect(exprs == [.string("swish")])
    }

    @Test("Discards non-matching conditional at top level")
    func discardsNonMatchingTopLevel() throws {
        let exprs = try parse(#"#?(:jank "nope") 42"#)
        #expect(exprs == [.integer(42)])
    }

    @Test("Non-matching conditional with no default yields empty top-level")
    func nonMatchingNoDefault() throws {
        let exprs = try parse("#?(:jank 1)")
        #expect(exprs == [])
    }

    @Test("Multiple top-level forms with non-matching conditional")
    func multipleTopLevelFormsWithNonMatch() throws {
        let exprs = try parse("#?(:jank 1) 2 #?(:swish 3)")
        #expect(exprs == [.integer(2), .integer(3)])
    }

    // MARK: - #? inside collections

    @Test("Reader conditional inside a list")
    func inList() throws {
        let exprs = try parse("(+ 1 #?(:swish 10 :clj 20))")
        #expect(exprs == [.list([.symbol("+", metadata: nil), .integer(1), .integer(10)], metadata: nil)])
    }

    @Test("Non-matching conditional inside a list is skipped")
    func nonMatchingInList() throws {
        let exprs = try parse("(+ 1 #?(:jank 99) 2)")
        #expect(exprs == [.list([.symbol("+", metadata: nil), .integer(1), .integer(2)], metadata: nil)])
    }

    @Test("Reader conditional inside a vector")
    func inVector() throws {
        let exprs = try parse("[1 #?(:swish 2) 3]")
        #expect(exprs == [.vector([.integer(1), .integer(2), .integer(3)], metadata: nil)])
    }

    @Test("Non-matching conditional inside a vector is skipped")
    func nonMatchingInVector() throws {
        let exprs = try parse("[1 #?(:jank 99) 2]")
        #expect(exprs == [.vector([.integer(1), .integer(2)], metadata: nil)])
    }

    @Test("Reader conditional inside a map value")
    func inMapValue() throws {
        let exprs = try parse("{:a #?(:swish 1 :clj 2)}")
        #expect(exprs == [.map([.keyword("a"): .integer(1)], metadata: nil)])
    }

    // MARK: - #?@ splicing

    @Test("Splicing into a vector")
    func spliceIntoVector() throws {
        let exprs = try parse("[1 #?@(:swish [2 3]) 4]")
        #expect(exprs == [.vector([.integer(1), .integer(2), .integer(3), .integer(4)], metadata: nil)])
    }

    @Test("Non-matching splice into a vector")
    func nonMatchingSpliceIntoVector() throws {
        let exprs = try parse("[1 #?@(:jank [2 3]) 4]")
        #expect(exprs == [.vector([.integer(1), .integer(4)], metadata: nil)])
    }

    @Test("Splicing into a list")
    func spliceIntoList() throws {
        let exprs = try parse("(f #?@(:swish [a b]) c)")
        #expect(exprs == [.list([
            .symbol("f", metadata: nil),
            .symbol("a", metadata: nil),
            .symbol("b", metadata: nil),
            .symbol("c", metadata: nil)
        ], metadata: nil)])
    }

    @Test("Splice with :default branch")
    func spliceWithDefault() throws {
        let exprs = try parse("[#?@(:jank [1 2] :default [3 4])]")
        #expect(exprs == [.vector([.integer(3), .integer(4)], metadata: nil)])
    }

    @Test("Splicing empty list produces no elements")
    func spliceEmptyList() throws {
        let exprs = try parse("[1 #?@(:swish []) 2]")
        #expect(exprs == [.vector([.integer(1), .integer(2)], metadata: nil)])
    }

    // MARK: - Nesting

    @Test("Nested reader conditionals")
    func nestedConditionals() throws {
        let exprs = try parse("#?(:swish #?(:swish :inner :default :outer))")
        #expect(exprs == [.keyword("inner")])
    }

    @Test("Reader conditional in function argument position (evaluated)")
    func inFunctionArgument() throws {
        let result = try eval("(+ 1 #?(:swish 2 :clj 99))")
        #expect(result == .integer(3))
    }

    // MARK: - #? with #_ discard

    @Test("Discard form can precede reader conditional")
    func discardBeforeConditional() throws {
        let exprs = try parse("#_ :ignored #?(:swish :kept)")
        #expect(exprs == [.keyword("kept")])
    }

    @Test("Discard inside a quoted form: '#_ x y quotes y")
    func discardInsideQuote() throws {
        // '  #_ :ignored  :kept  →  (quote :kept)
        let exprs = try parse("'#_ :ignored :kept")
        #expect(exprs == [.list([.symbol("quote", metadata: nil), .keyword("kept")], metadata: nil)])
    }

    @Test("Discard inside a syntax-quoted form")
    func discardInsideSyntaxQuote() throws {
        let exprs = try parse("`#_ :ignored :kept")
        #expect(exprs == [.list([.symbol("syntax-quote", metadata: nil), .keyword("kept")], metadata: nil)])
    }

    // MARK: - Error cases

    @Test("Splicing outside collection throws")
    func splicingOutsideCollection() throws {
        #expect(throws: (any Error).self) {
            try parse("#?@(:swish [1 2])")
        }
    }

    @Test("Reader conditional without list throws")
    func conditionalWithoutList() throws {
        #expect(throws: (any Error).self) {
            try parse("#?:swish")
        }
    }
}
