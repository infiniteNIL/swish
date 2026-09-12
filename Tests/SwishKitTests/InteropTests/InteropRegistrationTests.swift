import Foundation
import Testing
@testable import SwishKit

/// A non-Sendable, non-isolated class holding the functions under test — the
/// shape a host view model actually has. Registering `instance.method` has to
/// compile without the host making the type Sendable.
final class HostFunctions {
    var lastRecorded = ""

    func getVowels(_ name: String) -> [Character] {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        return name.filter { vowels.contains($0) }
    }

    func greet(_ name: String, _ times: Int) -> String {
        String(repeating: "Hi \(name)! ", count: times).trimmingCharacters(in: .whitespaces)
    }

    func record(_ value: String) {
        lastRecorded = value
    }
}

struct HostFailure: Error, CustomStringConvertible {
    let description: String
}

@Suite("Interop: registering Swift functions")
struct InteropRegistrationTests {
    @Test("A plain Swift function is callable from Swish with no wrapper")
    func registersPlainFunction() throws {
        let swish = Swish()
        let host = HostFunctions()
        swish.register(host.getVowels, as: "get-vowels")

        #expect(try swish.eval(#"(get-vowels "hello world")"#)
            == .vector(SwishPersistentVector([.character("e"), .character("o"), .character("o")]), metadata: nil))
    }

    @Test("Arity zero, one, and three all marshal")
    func variousArities() throws {
        let swish = Swish()
        swish.register({ 42 }, as: "answer")
        swish.register({ (n: Int) in n * 2 }, as: "double-it")
        swish.register({ (a: Int, b: String, c: Double) in "\(a)\(b)\(c)" }, as: "three")

        #expect(try swish.eval("(answer)") == .integer(42))
        #expect(try swish.eval("(double-it 21)") == .integer(42))
        #expect(try swish.eval(#"(three 1 "x" 2.5)"#) == .string("1x2.5"))
    }

    @Test("A Void-returning function evaluates to nil and still runs")
    func voidReturn() throws {
        let swish = Swish()
        let host = HostFunctions()
        swish.register(host.record, as: "record!")

        #expect(try swish.eval(#"(record! "written")"#) == .nil)
        #expect(host.lastRecorded == "written")
    }

    @Test("A trailing optional parameter may be omitted")
    func trailingOptional() throws {
        let swish = Swish()
        swish.register({ (a: Int, b: Int?) in a + (b ?? 100) }, as: "plus")

        #expect(try swish.eval("(plus 1 2)") == .integer(3))
        #expect(try swish.eval("(plus 1)") == .integer(101))
        #expect(try swish.eval("(plus 1 nil)") == .integer(101))
    }

    @Test("Too many or too few arguments is an arity error naming the range")
    func arityErrors() throws {
        let swish = Swish()
        swish.register({ (a: Int, b: Int?) in a + (b ?? 0) }, as: "plus")
        swish.register({ (a: Int) in a }, as: "identity!")

        expectSwishError { try swish.eval("(plus)") }
        expectSwishError { try swish.eval("(plus 1 2 3)") }
        expectSwishError { try swish.eval("(identity! 1 2)") }

        let message = errorText(from: { try swish.eval("(plus 1 2 3)") })
        #expect(message.contains("expected 1 to 2, got 3"))
    }

    @Test("A wrong-typed argument names the position and the expected Swift type")
    func wrongArgumentType() throws {
        let swish = Swish()
        swish.register({ (a: Int, b: String) in "\(a)\(b)" }, as: "pair")

        let message = errorText(from: { try swish.eval(#"(pair "nope" "x")"#) })
        #expect(message.contains("argument 1"))
        #expect(message.contains("Int"))
    }

    @Test("Integer parameters reject a ratio rather than truncating it")
    func integerIsStrict() throws {
        let swish = Swish()
        swish.register({ (n: Int) in n }, as: "int-only")
        swish.register({ (d: Double) in d }, as: "double-ok")

        expectSwishError { try swish.eval("(int-only (/ 1 2))") }
        // Floating-point parameters widen, so an integer literal is accepted.
        #expect(try swish.eval("(double-ok 5)") == .double(5))
    }

    @Test("A raw [Expr] registration handles a genuinely variadic function")
    func variadicRawRegistration() throws {
        let swish = Swish()
        swish.register(as: "count-args", arity: .variadic) { args in .integer(args.count) }

        #expect(try swish.eval("(count-args)") == .integer(0))
        #expect(try swish.eval("(count-args 1 2 3)") == .integer(3))
    }

    @Test("A Swift error becomes a catchable ExceptionInfo carrying ex-data")
    func hostErrorsAreCatchable() throws {
        let swish = Swish()
        swish.register({ (n: Int) throws -> Int in throw HostFailure(description: "boom \(n)") },
                       as: "explode")

        #expect(try swish.eval("(try (explode 7) (catch ExceptionInfo e (ex-message e)))")
            == .string("boom 7"))
        #expect(try swish.eval("(try (explode 7) (catch ExceptionInfo e (:swift-error-type (ex-data e))))")
            == .string("HostFailure"))
    }

    @Test("Collections and dictionaries round-trip through a registered function")
    func collectionMarshalling() throws {
        let swish = Swish()
        swish.register({ (xs: [Int]) in xs.reduce(0, +) }, as: "sum")
        swish.register({ (m: [String: Int]) in m.values.reduce(0, +) }, as: "sum-vals")
        swish.register({ (n: Int) in Array(1...n) }, as: "up-to")

        // Any seqable argument works, not just the vector the bridge encodes to.
        #expect(try swish.eval("(sum [1 2 3])") == .integer(6))
        #expect(try swish.eval("(sum '(1 2 3))") == .integer(6))
        #expect(try swish.eval("(sum (range 4))") == .integer(6))
        #expect(try swish.eval(#"(sum-vals {"a" 1 "b" 2})"#) == .integer(3))
        #expect(try swish.eval("(up-to 3)")
            == .vector(SwishPersistentVector([.integer(1), .integer(2), .integer(3)]), metadata: nil))
    }

    @Test("An Expr parameter receives the raw Swish value untouched")
    func rawExprParameter() throws {
        let swish = Swish()
        swish.register({ (e: Expr) in e.typeName }, as: "type-name")

        #expect(try swish.eval("(type-name :kw)") == .string("keyword"))
        #expect(try swish.eval("(type-name 'sym)") == .string("symbol"))
    }

    @Test("define binds a constant")
    func definesConstant() throws {
        let swish = Swish()
        try swish.define("1.2.3", as: "app-version")

        #expect(try swish.eval("app-version") == .string("1.2.3"))
    }

    @Test("Registering into a namespace makes the name available qualified")
    func registersIntoNamespace() throws {
        let swish = Swish()
        swish.register({ 7 }, as: "lucky", in: "app")

        #expect(try swish.eval("(app/lucky)") == .integer(7))
        #expect(swish.namespaceExists("app"))
    }

    @Test("doc metadata reaches Swish")
    func docMetadata() throws {
        let swish = Swish()
        swish.register({ (n: Int) in n }, as: "documented", doc: "Returns its argument.")

        let doc = try swish.eval("(:doc (meta #'documented))")
        #expect(doc == .string("Returns its argument."))
    }

    @Test("Parameter names reach arglists; otherwise they are positional")
    func arglistsMetadata() throws {
        let swish = Swish()
        swish.register({ (a: Int, b: Int?) in a + (b ?? 0) }, as: "named",
                       parameters: ["x", "y"])
        swish.register({ (a: Int) in a }, as: "unnamed")

        // One arglist per legal call shape, so the optional tail is visible.
        #expect(try swish.eval("(pr-str (:arglists (meta #'named)))") == .string("([x] [x y])"))
        #expect(try swish.eval("(pr-str (:arglists (meta #'unnamed)))") == .string("([arg1])"))
    }
}
