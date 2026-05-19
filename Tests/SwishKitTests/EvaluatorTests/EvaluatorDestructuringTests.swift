import Testing
@testable import SwishKit

@Suite("Evaluator Destructuring Tests")
struct EvaluatorDestructuringTests {
    let evaluator = Evaluator()

    // MARK: - Sequential destructuring in let

    @Test("sequential: basic positional binding")
    func seqBasic() throws {
        #expect(try evaluator.eval("(let [[a b c] [1 2 3]] [a b c])") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("sequential: bind fewer than available")
    func seqPartial() throws {
        #expect(try evaluator.eval("(let [[a b] [1 2 3]] [a b])") == .vector([.integer(1), .integer(2)], metadata: nil))
    }

    @Test("sequential: out-of-bounds yields nil")
    func seqOutOfBounds() throws {
        #expect(try evaluator.eval("(let [[a b c] [1 2]] c)") == .nil)
    }

    @Test("sequential: _ discards")
    func seqDiscard() throws {
        #expect(try evaluator.eval("(let [[_ b _] [1 2 3]] b)") == .integer(2))
    }

    @Test("sequential: & rest binding")
    func seqRest() throws {
        #expect(try evaluator.eval("(let [[a & r] [1 2 3]] r)") == .list([.integer(2), .integer(3)], metadata: nil))
    }

    @Test("sequential: & rest on single-element gives nil")
    func seqRestSingle() throws {
        #expect(try evaluator.eval("(let [[a & r] [1]] r)") == .nil)
    }

    @Test("sequential: on a list")
    func seqFromList() throws {
        #expect(try evaluator.eval("(let [[a b] '(10 20)] [a b])") == .vector([.integer(10), .integer(20)], metadata: nil))
    }

    @Test("sequential: nested sequential")
    func seqNested() throws {
        #expect(try evaluator.eval("(let [[[a b] c] [[1 2] 3]] [a b c])") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    // MARK: - Associative destructuring in let

    @Test("associative: :keys shorthand")
    func mapKeys() throws {
        #expect(try evaluator.eval("(let [{:keys [a b]} {:a 1 :b 2}] [a b])") == .vector([.integer(1), .integer(2)], metadata: nil))
    }

    @Test("associative: :keys missing key yields nil")
    func mapKeysMissing() throws {
        #expect(try evaluator.eval("(let [{:keys [a b]} {:a 1}] b)") == .nil)
    }

    @Test("associative: explicit key→binding")
    func mapExplicit() throws {
        #expect(try evaluator.eval("(let [{x :a y :b} {:a 1 :b 2}] [x y])") == .vector([.integer(1), .integer(2)], metadata: nil))
    }

    @Test("associative: :as binds the whole map")
    func mapAs() throws {
        let result = try evaluator.eval("(let [{:as m :keys [a]} {:a 1 :b 2}] [a m])")
        guard case .vector(let elems, _) = result, elems.count == 2 else {
            Issue.record("Expected [a m] vector"); return
        }
        #expect(elems[0] == .integer(1))
        if case .map(let dict, _) = elems[1] {
            #expect(dict[.keyword("b")] == .integer(2))
        } else {
            Issue.record("Expected map for :as binding")
        }
    }

    @Test("associative: :or provides defaults for missing keys")
    func mapOr() throws {
        #expect(try evaluator.eval("(let [{:keys [a b] :or {b 99}} {:a 1}] b)") == .integer(99))
    }

    @Test("associative: :or does not override present key")
    func mapOrPresent() throws {
        #expect(try evaluator.eval("(let [{:keys [a] :or {a 99}} {:a 42}] a)") == .integer(42))
    }

    @Test("associative: :strs shorthand")
    func mapStrs() throws {
        #expect(try evaluator.eval("(let [{:strs [name]} {\"name\" \"Alice\"}] name)") == .string("Alice"))
    }

    @Test("associative: nested sequential in map value")
    func mapNestedSeq() throws {
        #expect(try evaluator.eval("(let [{[b c] :pair} {:pair [2 3]}] [b c])") == .vector([.integer(2), .integer(3)], metadata: nil))
    }

    // MARK: - Destructuring in fn params

    @Test("fn: sequential param destructuring")
    func fnSeqParam() throws {
        #expect(try evaluator.eval("((fn [[a b]] (+ a b)) [3 4])") == .integer(7))
    }

    @Test("fn: map param destructuring with :keys")
    func fnMapParam() throws {
        #expect(try evaluator.eval("((fn [{:keys [x y]}] (+ x y)) {:x 10 :y 20})") == .integer(30))
    }

    @Test("fn: mixed normal and destructuring params")
    func fnMixed() throws {
        #expect(try evaluator.eval("((fn [n {:keys [x]}] (+ n x)) 5 {:x 3})") == .integer(8))
    }

    @Test("fn: & rest with destructuring")
    func fnRestDestructured() throws {
        #expect(try evaluator.eval("((fn [a & [b c]] [a b c]) 1 2 3)") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    // MARK: - Destructuring in defn

    @Test("defn: sequential param destructuring")
    func defnSeqParam() throws {
        _ = try evaluator.eval("(defn sum-pair [[a b]] (+ a b))")
        #expect(try evaluator.eval("(sum-pair [3 7])") == .integer(10))
    }

    @Test("defn: :keys destructuring")
    func defnMapParam() throws {
        _ = try evaluator.eval("(defn greet [{:keys [name]}] (str \"Hello \" name))")
        #expect(try evaluator.eval("(greet {:name \"Alice\"})") == .string("Hello Alice"))
    }

    // MARK: - Destructuring in loop

    @Test("loop: sequential destructuring")
    func loopSeq() throws {
        let result = try evaluator.eval("""
            (loop [[a & r] [1 2 3] acc 0]
              (if (nil? a)
                acc
                (recur r (+ acc a))))
            """)
        #expect(result == .integer(6))
    }

    @Test("loop: map destructuring")
    func loopMap() throws {
        let result = try evaluator.eval("""
            (loop [{:keys [n acc]} {:n 3 :acc 0}]
              (if (= n 0)
                acc
                (recur {:n (- n 1) :acc (+ acc n)})))
            """)
        #expect(result == .integer(6))
    }

    // MARK: - Multiple destructuring bindings in one let

    @Test("multiple destructuring bindings in one let")
    func multipleBindings() throws {
        #expect(try evaluator.eval("(let [[a b] [1 2] {:keys [c]} {:c 3}] [a b c])") == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("sequential bindings can reference earlier binds")
    func seqReferenceEarlier() throws {
        #expect(try evaluator.eval("(let [[a b] [1 2] c (+ a b)] c)") == .integer(3))
    }
}

// MARK: - Helper

private extension Evaluator {
    func eval(_ source: String) throws -> Expr {
        let exprs = try Reader.readString(source)
        var result: Expr = .nil
        for expr in exprs { result = try eval(expr) }
        return result
    }
}
