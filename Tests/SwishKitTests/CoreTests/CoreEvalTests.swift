import Testing
@testable import SwishKit

@Suite("Core eval Tests", .serialized)
struct CoreEvalTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - self-evaluating literals

    @Test("eval on self-evaluating literals returns them unchanged")
    func evalSelfEvaluating() throws {
        #expect(try swish.eval("(eval 1)") == .integer(1))
        #expect(try swish.eval("(eval -1)") == .integer(-1))
        #expect(try swish.eval("(eval 1.0)") == .double(1.0))
        #expect(try swish.eval("(eval 1N)") == .bigInteger(1))
        #expect(try swish.eval("(eval 1.0M)") == .bigDecimal(1.0))
        #expect(try swish.eval("(eval 1/2)") == .ratio(Ratio(1, 2)))
        #expect(try swish.eval(#"(eval "a string")"#) == .string("a string"))
        #expect(try swish.eval(#"(eval "(+ 1 2)")"#) == .string("(+ 1 2)"))
        #expect(try swish.eval(#"(eval \x)"#) == .character("x"))
        #expect(try swish.eval("(eval true)") == .boolean(true))
        #expect(try swish.eval("(eval false)") == .boolean(false))
        #expect(try swish.eval("(eval nil)") == .nil)
        #expect(try swish.eval("(eval :a-keyword)") == .keyword("a-keyword"))
    }

    // MARK: - functions

    @Test("eval on functions returns a fn")
    func evalFunctions() throws {
        #expect(try swish.eval("(fn? (eval (fn [x] x)))") == .boolean(true))
        #expect(try swish.eval("(fn? (eval '(fn [x] x)))") == .boolean(true))
        #expect(try swish.eval("(fn? (eval +))") == .boolean(true))
        #expect(try swish.eval("(fn? (eval '+))") == .boolean(true))
    }

    // MARK: - vars

    @Test("eval on (var +) returns a Var")
    func evalVar() throws {
        #expect(try swish.eval("(var? (eval '(var +)))") == .boolean(true))
    }

    // MARK: - namespace-qualified symbol resolution

    @Test("eval resolves a namespace-qualified symbol to its def'd value")
    func evalQualifiedSymbol() throws {
        #expect(try swish.eval("(def eval-test-x 42) (eval 'user/eval-test-x)") == .integer(42))
    }

    // MARK: - vectors, maps, sets

    @Test("eval on literal collections returns them, resolving contained symbols")
    func evalCollections() throws {
        #expect(try swish.eval("(eval [:a :b])") == .vector([.keyword("a"), .keyword("b")], metadata: nil))
        #expect(try swish.eval("(eval {:a :b})") == .map([.keyword("a"): .keyword("b")], metadata: nil))
        #expect(try swish.eval("(eval #{:a :b})") == .set(SwishSet(elements: [.keyword("a"), .keyword("b")], metadata: nil)))
        #expect(try swish.eval("(def eval-test-y 42) (eval [:a :b 'user/eval-test-y])") == .vector([.keyword("a"), .keyword("b"), .integer(42)], metadata: nil))
    }

    // MARK: - lists, function application, macros, special forms

    @Test("eval on an empty list returns an empty list")
    func evalEmptyList() throws {
        #expect(try swish.eval("(eval '())") == .list([], metadata: nil))
    }

    @Test("eval on a function-call form applies it")
    func evalFunctionCall() throws {
        #expect(try swish.eval("(eval '(+ 2 3))") == .integer(5))
        #expect(try swish.eval("(eval '(* 2 3))") == .integer(6))
    }

    @Test("eval on macro forms expands and evaluates them")
    func evalMacroForms() throws {
        #expect(try swish.eval("(def eval-test-z 42) (eval '(or false user/eval-test-z))") == .integer(42))
        #expect(try swish.eval("(def eval-test-w 42) (eval '(and (+ 2 3) user/eval-test-w))") == .integer(42))
    }

    @Test("eval on let and loop/recur forms")
    func evalLetAndLoop() throws {
        #expect(try swish.eval("(eval '(let [y 43] (or false y)))") == .integer(43))
        #expect(try swish.eval("(eval '(loop [y 0] (if (= y 43) y (recur (inc y)))))") == .integer(43))
    }

    // MARK: - infinite sequence stays lazy

    @Test("eval on an infinite lazy seq is truthy without hanging")
    func evalInfiniteSeq() throws {
        let result = try swish.eval("(eval '(range))")
        #expect(result != .nil && result != .boolean(false))
    }

    // MARK: - recursive eval

    @Test("eval called recursively")
    func evalRecursive() throws {
        #expect(try swish.eval("(eval '(eval 1))") == .integer(1))
        #expect(try swish.eval("(eval '(eval (eval 1)))") == .integer(1))
    }

    // MARK: - eval does not close over lexical scope

    @Test("eval does not see let-local bindings from the call site")
    func evalDoesNotCloseOverLexicalScope() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(let [eval-test-unbound 1] (eval '(+ eval-test-unbound 1)))")
        }
    }
}
