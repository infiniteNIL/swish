import Testing
@testable import SwishKit

@Suite("Evaluator Macros Tests")
struct EvaluatorMacrosTests {
    let evaluator = Evaluator()

    @Test("defmacro defines a macro and returns its name")
    func defmacroReturnsName() throws {
        // (defmacro my-macro [x] x) => my-macro
        let swish = Swish()
        let result = try swish.eval("(defmacro my-macro [x] x)")
        #expect(result == .symbol("my-macro"))
    }

    @Test("macro value self-evaluates")
    func macroSelfEvaluates() throws {
        let m = Expr.macro(name: "test", params: ["x"], body: [.symbol("x")])
        let result = try evaluator.eval(m)
        #expect(result == m)
    }

    @Test("Simple macro expands and evaluates")
    func simpleMacroExpansion() throws {
        // (defmacro unless [cond then] `(if ~cond nil ~then))
        // (unless false 42) => 42
        let swish = Swish()
        let result = try swish.eval("""
            (defmacro unless [cond then] `(if ~cond nil ~then))
            (unless false 42)
            """)
        #expect(result == .integer(42))
    }

    @Test("Macro receives unevaluated arguments")
    func macroReceivesUnevaluatedArgs() throws {
        // (defmacro get-code [x] `(quote ~x))
        // (get-code (+ 1 2)) => (+ 1 2)   not 3
        let swish = Swish()
        let result = try swish.eval("""
            (defmacro get-code [x] `(quote ~x))
            (get-code (+ 1 2))
            """)
        #expect(result == .list([.symbol("+"), .integer(1), .integer(2)]))
    }

    @Test("Macro with multiple body forms returns last expansion")
    func macroMultipleBodyForms() throws {
        // The last body form becomes the expansion
        // (defmacro double-if [c a b] (quote nil) `(if ~c ~a ~b))
        // (double-if true 10 20) => 10
        let swish = Swish()
        let result = try swish.eval("""
            (defmacro double-if [c a b]
              (quote nil)
              `(if ~c ~a ~b))
            (double-if true 10 20)
            """)
        #expect(result == .integer(10))
    }

    @Test("Macro expansion result is evaluated in caller's environment")
    func macroEvalsInCallerEnv() throws {
        // (def y 10)
        // (defmacro use-y [] 'y)
        // (use-y) => 10
        let swish = Swish()
        let result = try swish.eval("""
            (def y 10)
            (defmacro use-y [] 'y)
            (use-y)
            """)
        #expect(result == .integer(10))
    }

    @Test("Macro arity mismatch throws arityMismatch error")
    func macroArityMismatch() throws {
        // (defmacro m [x] x) then (m 1 2) should throw
        let swish = Swish()
        _ = try swish.eval("(defmacro m [x] x)")
        #expect(throws: EvaluatorError.arityMismatch(name: "m", expected: .fixed(1), got: 2)) {
            try swish.eval("(m 1 2)")
        }
    }

    @Test("Variadic macro with & rest")
    func variadicMacro() throws {
        // (defmacro my-list [& items] `(quote ~items))
        // (my-list 1 2 3) => (1 2 3)
        let swish = Swish()
        let result = try swish.eval("""
            (defmacro my-list [& items] `(quote ~items))
            (my-list 1 2 3)
            """)
        #expect(result == .list([.integer(1), .integer(2), .integer(3)]))
    }

    @Test("gensym produces unique symbols")
    func gensymUnique() throws {
        // Two calls to gensym produce different symbols
        let swish = Swish()
        let a = try swish.eval("(gensym)")
        let b = try swish.eval("(gensym)")
        #expect(a != b)
        if case .symbol = a { } else { Issue.record("expected symbol, got \(a)") }
    }

    @Test("gensym accepts a custom prefix")
    func gensymCustomPrefix() throws {
        // (gensym "tmp__") => a symbol starting with "tmp__"
        let swish = Swish()
        let result = try swish.eval(#"(gensym "tmp__")"#)
        guard case .symbol(let name) = result else {
            Issue.record("expected symbol, got \(result)")
            return
        }
        #expect(name.hasPrefix("tmp__"))
    }

    @Test("Auto-gensym replaces foo# with unique symbol in syntax-quote")
    func autoGensymInSyntaxQuote() throws {
        // `x# should produce a unique symbol (not the literal x#)
        let swish = Swish()
        let result = try swish.eval("`x#")
        guard case .symbol(let name) = result else {
            Issue.record("expected symbol, got \(result)")
            return
        }
        #expect(name != "x#")
        #expect(name.hasPrefix("x__"))
    }

    @Test("Auto-gensym produces the same symbol for repeated foo# in one template")
    func autoGensymConsistentInTemplate() throws {
        // `(x# x#) should produce (G1 G1) — both x# become the same symbol
        let swish = Swish()
        let result = try swish.eval("`(x# x#)")
        guard case .list(let elems) = result, elems.count == 2 else {
            Issue.record("expected 2-element list, got \(result)")
            return
        }
        #expect(elems[0] == elems[1])
    }

    @Test("Auto-gensym produces different symbols across separate syntax-quote expansions")
    func autoGensymFreshAcrossExpansions() throws {
        // Two separate backtick evaluations get different gensyms for x#
        let swish = Swish()
        let first = try swish.eval("`x#")
        let second = try swish.eval("`x#")
        #expect(first != second)
    }

    @Test("Auto-gensym works inside vectors in syntax-quote")
    func autoGensymInVector() throws {
        // `[x# x#] => [G1 G1]
        let swish = Swish()
        let result = try swish.eval("`[x# x#]")
        guard case .vector(let elems) = result, elems.count == 2 else {
            Issue.record("expected 2-element vector, got \(result)")
            return
        }
        #expect(elems[0] == elems[1])
    }

    @Test("macroexpand-1 expands one step")
    func macroexpand1OneStep() throws {
        // (defmacro unless [cond then] `(if ~cond nil ~then))
        // (macroexpand-1 '(unless false 42)) => (if false nil 42)
        let swish = Swish()
        let result = try swish.eval("""
            (defmacro unless [cond then] `(if ~cond nil ~then))
            (macroexpand-1 '(unless false 42))
            """)
        #expect(result == .list([.symbol("if"), .boolean(false), .nil, .integer(42)]))
    }

    @Test("macroexpand-1 returns non-macro form unchanged")
    func macroexpand1NonMacro() throws {
        // (macroexpand-1 '(+ 1 2)) => (+ 1 2)
        let swish = Swish()
        let result = try swish.eval("(macroexpand-1 '(+ 1 2))")
        #expect(result == .list([.symbol("+"), .integer(1), .integer(2)]))
    }

    @Test("macroexpand fully expands nested macros")
    func macroexpandFull() throws {
        // (defmacro a [x] `(b ~x))
        // (defmacro b [x] x)
        // (macroexpand '(a 42)) => 42
        let swish = Swish()
        let result = try swish.eval("""
            (defmacro b [x] x)
            (defmacro a [x] `(b ~x))
            (macroexpand '(a 42))
            """)
        #expect(result == .integer(42))
    }

    @Test("macroexpand-1 returns non-list form unchanged")
    func macroexpand1Atom() throws {
        let swish = Swish()
        let result = try swish.eval("(macroexpand-1 42)")
        #expect(result == .integer(42))
    }

    @Test("defmacro with def template does not throw at parse time")
    func defmacroDefTemplateParses() throws {
        // `(def ~name ~value) inside a macro body must not be validated as a real def
        let swish = Swish()
        #expect(throws: Never.self) {
            try swish.eval("(defmacro defn [name value] `(def ~name ~value))")
        }
    }

    @Test("defmacro with fn template does not throw at parse time")
    func defmacroFnTemplateParses() throws {
        // `(def ~name (fn ~args ~body)) inside a macro body must not be validated as real fn
        let swish = Swish()
        #expect(throws: Never.self) {
            try swish.eval("(defmacro defn [name args body] `(def ~name (fn ~args ~body)))")
        }
    }

    @Test("defn macro defined via defmacro works end-to-end")
    func defnMacroEndToEnd() throws {
        let swish = Swish()
        let result = try swish.eval("""
            (defmacro defn [name args body] `(def ~name (fn ~args ~body)))
            (defn square [x] (* x x))
            (square 5)
            """)
        #expect(result == .integer(25))
    }
}
