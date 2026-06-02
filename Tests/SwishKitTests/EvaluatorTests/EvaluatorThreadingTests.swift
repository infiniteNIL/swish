import Testing
@testable import SwishKit

@Suite("Evaluator threading macro Tests", .serialized)
struct EvaluatorThreadingTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - ->

    @Test("(-> x) with no forms returns x")
    func threadFirstNoForms() throws {
        #expect(try swish.eval("(-> 42)") == .integer(42))
    }

    @Test("(-> x f) threads through a bare symbol")
    func threadFirstSymbol() throws {
        #expect(try swish.eval("(-> 1 inc)") == .integer(2))
    }

    @Test("(-> x f g) chains multiple forms")
    func threadFirstChained() throws {
        #expect(try swish.eval("(-> 1 inc inc)") == .integer(3))
    }

    @Test("(-> x (f a)) inserts x as second item in list form")
    func threadFirstListForm() throws {
        #expect(try swish.eval("(-> 5 (+ 3))") == .integer(8))
    }

    @Test("(-> x (f a) (g b)) chains list forms")
    func threadFirstChainedListForms() throws {
        #expect(try swish.eval("(-> 10 (- 3) (+ 2))") == .integer(9))
    }

    @Test("(-> m :k) threads through keyword lookup")
    func threadFirstKeyword() throws {
        #expect(try swish.eval("(-> {:a 1} :a)") == .integer(1))
    }

    @Test("(-> v first) threads into first")
    func threadFirstIntoFirst() throws {
        #expect(try swish.eval("(-> [1 2 3] first)") == .integer(1))
    }

    @Test("(-> v (conj x)) inserts v as first arg to conj")
    func threadFirstConj() throws {
        #expect(try swish.eval("(-> [1 2 3] (conj 4))") == .vector([.integer(1), .integer(2), .integer(3), .integer(4)], metadata: nil))
    }

    @Test("(-> s (str suffix)) threads string through str")
    func threadFirstStr() throws {
        #expect(try swish.eval("(-> \"hello\" (str \" world\"))") == .string("hello world"))
    }

    // MARK: - ->>

    @Test("(->> x) with no forms returns x")
    func threadLastNoForms() throws {
        #expect(try swish.eval("(->> 42)") == .integer(42))
    }

    @Test("(->> coll (map f)) threads coll as last arg")
    func threadLastMap() throws {
        #expect(try swish.eval("(->> [1 2 3] (map inc))") == .list([.integer(2), .integer(3), .integer(4)], metadata: nil))
    }

    @Test("(->> coll (filter pred)) threads coll as last arg")
    func threadLastFilter() throws {
        #expect(try swish.eval("(->> [1 2 3] (filter odd?))") == .list([.integer(1), .integer(3)], metadata: nil))
    }

    @Test("(->> x (map f) (filter p)) chains list forms")
    func threadLastChained() throws {
        #expect(try swish.eval("(->> [1 2 3] (map inc) (filter odd?))") == .list([.integer(3)], metadata: nil))
    }

    @Test("(->> x (- n)) inserts x as last arg — different from ->")
    func threadLastSubtract() throws {
        // (->> 5 (- 10)) = (- 10 5) = 5
        #expect(try swish.eval("(->> 5 (- 10))") == .integer(5))
        // (-> 5 (- 10)) = (- 5 10) = -5
        #expect(try swish.eval("(-> 5 (- 10))") == .integer(-5))
    }

    @Test("(->> coll f) threads through a bare symbol")
    func threadLastSymbol() throws {
        #expect(try swish.eval("(->> [1 2 3] count)") == .integer(3))
    }

    // MARK: - seq?

    @Test("(seq? '(1 2)) returns true")
    func seqPredList() throws {
        #expect(try swish.eval("(seq? '(1 2))") == .boolean(true))
    }

    @Test("(seq? [1 2]) returns false")
    func seqPredVector() throws {
        #expect(try swish.eval("(seq? [1 2])") == .boolean(false))
    }

    @Test("(seq? nil) returns false")
    func seqPredNil() throws {
        #expect(try swish.eval("(seq? nil)") == .boolean(false))
    }
}
