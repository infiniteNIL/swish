import Testing
@testable import SwishKit

@Suite("Var Tests")
struct VarTests {
    private func eval(_ source: String) throws -> Expr {
        let lexer = Lexer(source)
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        let evaluator = Evaluator()
        var result: Expr = .nil
        for expr in exprs {
            result = try evaluator.eval(expr)
        }
        return result
    }

    private func evaluator(with source: String) throws -> Evaluator {
        let lexer = Lexer(source)
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        let evaluator = Evaluator()
        for expr in exprs {
            _ = try evaluator.eval(expr)
        }
        return evaluator
    }

    @Test("def interns a Var with correct name, namespace, and value")
    func defInternsVar() throws {
        let result = try eval("(def foo 42)")
        guard case .varRef(let v) = result else {
            Issue.record("Expected .varRef, got \(result)")
            return
        }
        #expect(v.name == "foo")
        #expect(v.namespace.name == "user")
        #expect(v.value == .integer(42))
    }

    @Test("Symbol lookup auto-dereferences a var")
    func symbolAutoDeref() throws {
        let result = try eval("(def foo 42) foo")
        #expect(result == .integer(42))
    }

    @Test("Re-def updates the existing Var object (same identity)")
    func redefUpdatesSameVar() throws {
        let e = Evaluator()
        let parse = { (src: String) throws -> Expr in
            let parser = try Parser(Lexer(src))
            return try parser.parse()[0]
        }
        let first = try e.eval(try parse("(def foo 1)"))
        let second = try e.eval(try parse("(def foo 2)"))

        guard case .varRef(let v1) = first, case .varRef(let v2) = second else {
            Issue.record("Expected .varRef results")
            return
        }

        #expect(v1 === v2)
        #expect(v2.value == .integer(2))
    }

    @Test("(var foo) returns the varRef itself, not the value")
    func varFormReturnsVarRef() throws {
        let result = try eval("(def foo 42) (var foo)")
        guard case .varRef(let v) = result else {
            Issue.record("Expected .varRef, got \(result)")
            return
        }
        #expect(v.name == "foo")
        #expect(v.value == .integer(42))
    }

    @Test("#'foo reader syntax expands to (var foo) and evaluates to the varRef")
    func hashQuoteReaderSyntax() throws {
        let result = try eval("(def foo 42) #'foo")
        guard case .varRef(let v) = result else {
            Issue.record("Expected .varRef, got \(result)")
            return
        }
        #expect(v.name == "foo")
        #expect(v.value == .integer(42))
    }

    @Test("Printer renders a var as #'namespace/name")
    func printerRendersVar() throws {
        let result = try eval("(def foo 42) (var foo)")
        let printer = Printer()
        #expect(printer.printString(result) == "#'user/foo")
    }

    @Test("(def foo) with no value creates an unbound var")
    func defWithNoValueCreatesUnboundVar() throws {
        let result = try eval("(def foo)")
        guard case .varRef(let v) = result else {
            Issue.record("Expected .varRef, got \(result)")
            return
        }
        #expect(v.isBound == false)
        #expect(v.value == nil)
    }

    @Test("Evaluating an unbound var's symbol throws unboundVar error")
    func unboundVarThrows() throws {
        let e = Evaluator()
        _ = try e.eval(try Parser(Lexer("(def foo)")).parse()[0])
        #expect(throws: EvaluatorError.unboundVar("user/foo")) {
            _ = try e.eval(try Parser(Lexer("foo")).parse()[0])
        }
    }

    @Test("Re-def with a value binds a previously unbound var (same object)")
    func redefBindsUnboundVar() throws {
        let e = Evaluator()
        let firstResult = try e.eval(try Parser(Lexer("(def foo)")).parse()[0])
        let secondResult = try e.eval(try Parser(Lexer("(def foo 99)")).parse()[0])
        guard case .varRef(let v1) = firstResult, case .varRef(let v2) = secondResult else {
            Issue.record("Expected .varRef results")
            return
        }
        #expect(v1 === v2)
        #expect(v2.isBound == true)
        #expect(v2.value == .integer(99))
    }

    @Test("Re-declaring a bound var with (def foo) leaves existing value intact")
    func redefWithNoValuePreservesValue() throws {
        let e = Evaluator()
        _ = try e.eval(try Parser(Lexer("(def foo 42)")).parse()[0])
        let result = try e.eval(try Parser(Lexer("(def foo)")).parse()[0])
        guard case .varRef(let v) = result else {
            Issue.record("Expected .varRef, got \(result)")
            return
        }
        #expect(v.value == .integer(42))
    }
}
