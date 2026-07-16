import Testing
@testable import SwishKit

@Suite("Evaluator case Tests", .serialized)
struct EvaluatorCaseTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - single test-constant clauses, across every type

    @Test("case dispatches on a symbol")
    func caseSymbol() throws {
        #expect(try swish.eval("(case 'sym sym :sym-result :default)") == .keyword("sym-result"))
    }

    @Test("case dispatches on a keyword")
    func caseKeyword() throws {
        #expect(try swish.eval("(case :kw :kw :kw-result :default)") == .keyword("kw-result"))
    }

    @Test("case dispatches on a string")
    func caseString() throws {
        #expect(try swish.eval("(case \"string\" \"string\" :string-result :default)") == .keyword("string-result"))
    }

    @Test("case dispatches on an integer")
    func caseInteger() throws {
        #expect(try swish.eval("(case 1 1 :integer-result :default)") == .keyword("integer-result"))
    }

    @Test("case dispatches on a bigint")
    func caseBigInt() throws {
        #expect(try swish.eval("(case 2N 2N :big-integer-result :default)") == .keyword("big-integer-result"))
    }

    @Test("case dispatches on a double")
    func caseDouble() throws {
        #expect(try swish.eval("(case 3.0 3.0 :double-result :default)") == .keyword("double-result"))
    }

    @Test("case dispatches on a bigdecimal")
    func caseBigDecimal() throws {
        #expect(try swish.eval("(case 4.0M 4.0M :big-decimal-result :default)") == .keyword("big-decimal-result"))
    }

    @Test("case dispatches on a ratio")
    func caseRatio() throws {
        #expect(try swish.eval("(case 1/2 1/2 :ratio-result :default)") == .keyword("ratio-result"))
    }

    @Test("case dispatches on a character")
    func caseCharacter() throws {
        #expect(try swish.eval("(case \\a \\a :character-result :default)") == .keyword("character-result"))
    }

    @Test("case dispatches on true/false/nil")
    func caseBooleanAndNil() throws {
        #expect(try swish.eval("(case true true :true-result false :false-result nil :nil-result :default)") == .keyword("true-result"))
        #expect(try swish.eval("(case false true :true-result false :false-result nil :nil-result :default)") == .keyword("false-result"))
        #expect(try swish.eval("(case nil true :true-result false :false-result nil :nil-result :default)") == .keyword("nil-result"))
    }

    @Test("case dispatches on ##Inf/##-Inf")
    func caseInfinities() throws {
        #expect(try swish.eval("(case ##Inf ##Inf :inf-result ##-Inf :neg-inf-result :default)") == .keyword("inf-result"))
        #expect(try swish.eval("(case ##-Inf ##Inf :inf-result ##-Inf :neg-inf-result :default)") == .keyword("neg-inf-result"))
    }

    @Test("case dispatches on a vector, map, and set")
    func caseCollections() throws {
        #expect(try swish.eval("(case [:vec :of :kws] [:vec :of :kws] :vec-result :default)") == .keyword("vec-result"))
        #expect(try swish.eval("(case {:a :map} {:a :map} :map-result :default)") == .keyword("map-result"))
        #expect(try swish.eval("(case #{:a :set} #{:a :set} :set-result :default)") == .keyword("set-result"))
    }

    // MARK: - multi-constant list clause

    @Test("multi-constant clause matches any of its alternatives")
    func multiConstantClause() throws {
        let form = "(case x (:either :this :or :that) :one-of-multiple :default)"
        #expect(try swish.eval("(let [x :either] \(form))") == .keyword("one-of-multiple"))
        #expect(try swish.eval("(let [x :this] \(form))") == .keyword("one-of-multiple"))
        #expect(try swish.eval("(let [x :or] \(form))") == .keyword("one-of-multiple"))
        #expect(try swish.eval("(let [x :that] \(form))") == .keyword("one-of-multiple"))
        #expect(try swish.eval("(let [x :match-nuthin] \(form))") == .keyword("default"))
    }

    // MARK: - vector/list cross-equality

    @Test("a vector clause matches an equal list value")
    func vectorClauseMatchesList() throws {
        #expect(try swish.eval("(case '(:vec :of :kws) [:vec :of :kws] :vec-result :default)") == .keyword("vec-result"))
    }

    // MARK: - numeric-tower discrimination

    @Test("1 and 1N match a 1 clause, but 1.0 and 1.0M do not")
    func integralCategoryMatchesAcrossIntAndBigInt() throws {
        let form = "(case x 1 :integer-result :default)"
        #expect(try swish.eval("(let [x 1] \(form))") == .keyword("integer-result"))
        #expect(try swish.eval("(let [x 1N] \(form))") == .keyword("integer-result"))
        #expect(try swish.eval("(let [x 1.0] \(form))") == .keyword("default"))
        #expect(try swish.eval("(let [x 1.0M] \(form))") == .keyword("default"))
    }

    @Test("3.0 matches only 3.0, not 3, 3N, or 3.0M")
    func floatingCategoryIsIsolated() throws {
        let form = "(case x 3.0 :double-result :default)"
        #expect(try swish.eval("(let [x 3.0] \(form))") == .keyword("double-result"))
        #expect(try swish.eval("(let [x 3] \(form))") == .keyword("default"))
        #expect(try swish.eval("(let [x 3N] \(form))") == .keyword("default"))
        #expect(try swish.eval("(let [x 3.0M] \(form))") == .keyword("default"))
    }

    @Test("4.0M matches only 4.0M, not 4, 4N, or 4.0")
    func decimalCategoryIsIsolated() throws {
        let form = "(case x 4.0M :big-decimal-result :default)"
        #expect(try swish.eval("(let [x 4.0M] \(form))") == .keyword("big-decimal-result"))
        #expect(try swish.eval("(let [x 4] \(form))") == .keyword("default"))
        #expect(try swish.eval("(let [x 4N] \(form))") == .keyword("default"))
        #expect(try swish.eval("(let [x 4.0] \(form))") == .keyword("default"))
    }

    // MARK: - ##NaN never matches, even its own clause

    @Test("##NaN never matches its own literal clause")
    func nanNeverMatches() throws {
        #expect(throws: SwishException.self) {
            try swish.eval("(case ##NaN ##NaN :nan-result)")
        }
    }

    // MARK: - test constants are never evaluated

    @Test("test constants are not evaluated")
    func testConstantsNotEvaluated() throws {
        #expect(try swish.eval("(case 'range (range 0 5) :bad-range-result (1 2 3 4) :real-range-result :other)") == .keyword("bad-range-result"))
        #expect(try swish.eval("(case 0 (range 0 5) :bad-range-result (1 2 3 4) :real-range-result :other)") == .keyword("bad-range-result"))
        #expect(try swish.eval("(case 5 (range 0 5) :bad-range-result (1 2 3 4) :real-range-result :other)") == .keyword("bad-range-result"))
        #expect(try swish.eval("(case 1 (range 0 5) :bad-range-result (1 2 3 4) :real-range-result :other)") == .keyword("real-range-result"))
    }

    // MARK: - '(quote foo) clause: reader-expands to a 2-constant list clause

    @Test("'foo as a clause reader-expands to (quote foo), matching both 'quote and 'foo")
    func quotedSymbolClauseExpandsToTwoConstants() throws {
        #expect(try swish.eval("(case 'quote 'foo :quote-foo-result :other)") == .keyword("quote-foo-result"))
        #expect(try swish.eval("(case 'foo 'foo :quote-foo-result :other)") == .keyword("quote-foo-result"))
    }

    // MARK: - default clause present vs. absent

    @Test("default clause is returned when nothing matches")
    func defaultClauseReturnedOnNoMatch() throws {
        #expect(try swish.eval("(case 999 1 :one 2 :two :default)") == .keyword("default"))
    }

    @Test("no default clause and no match throws")
    func noDefaultAndNoMatchThrows() throws {
        #expect(throws: SwishException.self) {
            try swish.eval("(case 999 1 :one 2 :two)")
        }
    }

    // MARK: - degenerate form: only a default, no test clauses

    @Test("(case x default) always returns default, evaluating x for side effects")
    func degenerateDefaultOnlyForm() throws {
        #expect(try swish.eval("(case 999 :always-this)") == .keyword("always-this"))
        #expect(try swish.eval("(case (+ 1 2) :always-this)") == .keyword("always-this"))
    }

    // MARK: - duplicate test constant detection

    @Test("duplicate test constant across two clauses throws")
    func duplicateTestConstantAcrossClausesThrows() throws {
        #expect(throws: SwishException.self) {
            try swish.eval("(case 1 1 :a 1N :b)")
        }
    }

    @Test("duplicate test constant within one multi-constant clause throws")
    func duplicateTestConstantWithinClauseThrows() throws {
        #expect(throws: SwishException.self) {
            try swish.eval("(case :a (:a :b :a) :result)")
        }
    }
}
