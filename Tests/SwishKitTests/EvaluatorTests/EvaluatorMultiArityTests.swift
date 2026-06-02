import Testing
@testable import SwishKit

@Suite("Evaluator Multi-Arity Tests", .serialized)
struct EvaluatorMultiArityTests {
    static let _shared = Evaluator()
    var evaluator: Evaluator { Self._shared }

    // MARK: - fn multi-arity construction

    @Test("fn with multi-arity syntax produces multiArityFunction")
    func fnMultiArityProducesMultiArityFunction() throws {
        let result = try evaluator.eval(
            "(fn ([x] x) ([x y] y))"
        )
        if case .multiArityFunction(let name, let arities, _, _) = result {
            #expect(name == nil)
            #expect(arities.count == 2)
            #expect(arities[0].params == ["x"])
            #expect(arities[1].params == ["x", "y"])
        } else {
            Issue.record("Expected .multiArityFunction, got \(result)")
        }
    }

    @Test("named fn with multi-arity syntax captures name")
    func namedFnMultiArity() throws {
        let result = try evaluator.eval(
            "(fn add ([x] x) ([x y] (+ x y)))"
        )
        if case .multiArityFunction(let name, let arities, _, _) = result {
            #expect(name == "add")
            #expect(arities.count == 2)
        } else {
            Issue.record("Expected .multiArityFunction, got \(result)")
        }
    }

    @Test("fn with single arity in list syntax produces multiArityFunction")
    func fnSingleArityListSyntax() throws {
        let result = try evaluator.eval("(fn ([x] x))")
        if case .multiArityFunction(_, let arities, _, _) = result {
            #expect(arities.count == 1)
        } else {
            Issue.record("Expected .multiArityFunction, got \(result)")
        }
    }

    // MARK: - Dispatch

    @Test("multi-arity fn dispatches by arg count")
    func multiArityDispatch() throws {
        let result1 = try evaluator.eval("((fn ([x] :one) ([x y] :two)) 1)")
        #expect(result1 == .keyword("one"))

        let result2 = try evaluator.eval("((fn ([x] :one) ([x y] :two)) 1 2)")
        #expect(result2 == .keyword("two"))
    }

    @Test("multi-arity fn with zero-arg arity dispatches correctly")
    func multiArityZeroArg() throws {
        let result0 = try evaluator.eval("((fn ([] :zero) ([x] :one)) )")
        #expect(result0 == .keyword("zero"))

        let result1 = try evaluator.eval("((fn ([] :zero) ([x] :one)) 42)")
        #expect(result1 == .keyword("one"))
    }

    @Test("multi-arity fn evaluates the correct body")
    func multiArityBodyEval() throws {
        let result = try evaluator.eval("((fn ([x] (+ x 1)) ([x y] (+ x y))) 10)")
        #expect(result == .integer(11))

        let result2 = try evaluator.eval("((fn ([x] (+ x 1)) ([x y] (+ x y))) 3 4)")
        #expect(result2 == .integer(7))
    }

    @Test("multi-arity fn with three arities dispatches all correctly")
    func threeArityDispatch() throws {
        let result1 = try evaluator.eval("((fn ([x] 1) ([x y] 2) ([x y z] 3)) :a)")
        #expect(result1 == .integer(1))

        let result2 = try evaluator.eval("((fn ([x] 1) ([x y] 2) ([x y z] 3)) :a :b)")
        #expect(result2 == .integer(2))

        let result3 = try evaluator.eval("((fn ([x] 1) ([x y] 2) ([x y z] 3)) :a :b :c)")
        #expect(result3 == .integer(3))
    }

    // MARK: - Variadic arity

    @Test("fixed arity wins over variadic when arg count matches exactly")
    func fixedWinsOverVariadic() throws {
        let result = try evaluator.eval("((fn ([x] :fixed) ([x & rest] :variadic)) 42)")
        #expect(result == .keyword("fixed"))
    }

    @Test("variadic arity dispatches when no fixed arity matches")
    func variadicDispatch() throws {
        let result = try evaluator.eval("((fn ([x] :one) ([x & rest] rest)) 1 2 3)")
        #expect(result == .list([.integer(2), .integer(3)], metadata: nil))
    }

    @Test("variadic arity with zero fixed params accepts any count")
    func variadicZeroFixed() throws {
        let result0 = try evaluator.eval("((fn ([& args] (count args))))")
        #expect(result0 == .integer(0))

        let result3 = try evaluator.eval("((fn ([& args] (count args))) 1 2 3)")
        #expect(result3 == .integer(3))
    }

    @Test("variadic rest param is a list")
    func variadicRestIsList() throws {
        let result = try evaluator.eval("((fn ([] nil) ([x & rest] rest)) 1 2 3)")
        #expect(result == .list([.integer(2), .integer(3)], metadata: nil))
    }

    // MARK: - Error cases

    @Test("calling with wrong arg count throws noMatchingArity")
    func wrongArgCountThrows() throws {
        #expect(throws: EvaluatorError.noMatchingArity(name: "fn", got: 3)) {
            try evaluator.eval("((fn ([x] x) ([x y] y)) 1 2 3)")
        }
    }

    // MARK: - defn multi-arity

    @Test("defn with multi-arity syntax defines function correctly")
    func defnMultiArity() throws {
        _ = try evaluator.eval("(defn greet ([name] (str \"Hi \" name)) ([greeting name] (str greeting \" \" name)))")
        #expect(try evaluator.eval("(greet \"Alice\")") == .string("Hi Alice"))
        #expect(try evaluator.eval("(greet \"Hello\" \"Bob\")") == .string("Hello Bob"))
    }

    @Test("defn single-arity still works after the change")
    func defnSingleArityStillWorks() throws {
        _ = try evaluator.eval("(defn inc1 [x] (+ x 1))")
        #expect(try evaluator.eval("(inc1 5)") == .integer(6))
    }

    @Test("defn with docstring and multi-arity preserves metadata")
    func defnDocstringMultiArity() throws {
        _ = try evaluator.eval("(defn greet2 \"Greets\" ([name] name) ([a b] b))")
        let m = try evaluator.eval("(meta #'user/greet2)")
        if case .map(let dict, _) = m {
            #expect(dict[.keyword("doc")] == .string("Greets"))
        } else {
            Issue.record("Expected map metadata")
        }
    }

    @Test("defn- multi-arity works via delegation to defn")
    func defnMinusMultiArity() throws {
        _ = try evaluator.eval("(defn- secret ([x] x) ([x y] y))")
        #expect(try evaluator.eval("(secret 1)") == .integer(1))
        #expect(try evaluator.eval("(secret 1 2)") == .integer(2))
    }

    // MARK: - defmacro multi-arity

    @Test("defmacro with multi-arity produces multiArityMacro")
    func defmacroMultiArity() throws {
        _ = try evaluator.eval("(defmacro my-and ([] true) ([x] x))")
        #expect(try evaluator.eval("(my-and)") == .boolean(true))
        #expect(try evaluator.eval("(my-and 42)") == .integer(42))
        #expect(try evaluator.eval("(my-and nil)") == .nil)
    }

    @Test("macroexpand-1 works on multi-arity macro")
    func macroexpand1MultiArity() throws {
        _ = try evaluator.eval("(defmacro my-or ([] nil) ([x] x))")
        let expanded = try evaluator.macroexpand1(
            .list([.symbol("my-or", metadata: nil)], metadata: nil)
        )
        #expect(expanded == .nil)
    }

    // MARK: - Closures

    @Test("multi-arity fn closes over its defining environment")
    func multiArityClosure() throws {
        let result = try evaluator.eval("""
            (let [x 10]
              ((fn ([y] (+ x y)) ([y z] (+ x y z))) 5))
            """)
        #expect(result == .integer(15))
    }

    // MARK: - Printer

    @Test("anonymous multi-arity fn prints as #<fn>")
    func printMultiArityFn() {
        let printer = Printer()
        let expr = Expr.multiArityFunction(name: nil, arities: [], capturedEnv: nil, metadata: nil)
        #expect(printer.printString(expr) == "#<fn>")
    }

    @Test("named multi-arity fn prints name")
    func printNamedMultiArityFn() {
        let printer = Printer()
        let expr = Expr.multiArityFunction(name: "add", arities: [], capturedEnv: nil, metadata: nil)
        #expect(printer.printString(expr) == "#<fn add>")
    }

    @Test("multi-arity macro prints as #<macro name>")
    func printMultiArityMacro() {
        let printer = Printer()
        let expr = Expr.multiArityMacro(name: "my-and", arities: [], metadata: nil)
        #expect(printer.printString(expr) == "#<macro my-and>")
    }
}
