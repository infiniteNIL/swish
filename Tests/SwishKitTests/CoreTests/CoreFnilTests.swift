import Testing
@testable import SwishKit

@Suite("Core fnil Tests", .serialized)
struct CoreFnilTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    static let setup = "(defn fnil-test-fn [& x] (into [] x)) (def fnil-arg 'not-nil)"

    // MARK: - arity 1

    @Test("fnil arity 1: nil argument is patched")
    func fnilArity1Nil() throws {
        #expect(try swish.eval("\(Self.setup) ((fnil fnil-test-fn 100) nil)") == .vector([.integer(100)], metadata: nil))
    }

    @Test("fnil arity 1: non-nil argument passes through")
    func fnilArity1NonNil() throws {
        #expect(try swish.eval("\(Self.setup) ((fnil fnil-test-fn 100) fnil-arg)") == .vector([.symbol("not-nil", metadata: nil)], metadata: nil))
    }

    // MARK: - arity 2

    @Test("fnil arity 2: all nil/non-nil combinations")
    func fnilArity2Combinations() throws {
        #expect(try swish.eval("\(Self.setup) ((fnil fnil-test-fn 100 200) nil nil)") == .vector([.integer(100), .integer(200)], metadata: nil))
        #expect(try swish.eval("\(Self.setup) ((fnil fnil-test-fn 100 200) fnil-arg nil)") == .vector([.symbol("not-nil", metadata: nil), .integer(200)], metadata: nil))
        #expect(try swish.eval("\(Self.setup) ((fnil fnil-test-fn 100 200) nil fnil-arg)") == .vector([.integer(100), .symbol("not-nil", metadata: nil)], metadata: nil))
        #expect(try swish.eval("\(Self.setup) ((fnil fnil-test-fn 100 200) fnil-arg fnil-arg)") == .vector([.symbol("not-nil", metadata: nil), .symbol("not-nil", metadata: nil)], metadata: nil))
    }

    // MARK: - arity 3

    @Test("fnil arity 3: all nil/non-nil combinations")
    func fnilArity3Combinations() throws {
        let a = "fnil-arg"
        let n = "nil"
        let cases: [(String, String, String, [Expr])] = [
            (n, n, n, [.integer(100), .integer(200), .integer(300)]),
            (a, n, n, [.symbol("not-nil", metadata: nil), .integer(200), .integer(300)]),
            (n, a, n, [.integer(100), .symbol("not-nil", metadata: nil), .integer(300)]),
            (n, n, a, [.integer(100), .integer(200), .symbol("not-nil", metadata: nil)]),
            (a, a, n, [.symbol("not-nil", metadata: nil), .symbol("not-nil", metadata: nil), .integer(300)]),
            (n, a, a, [.integer(100), .symbol("not-nil", metadata: nil), .symbol("not-nil", metadata: nil)]),
            (a, n, a, [.symbol("not-nil", metadata: nil), .integer(200), .symbol("not-nil", metadata: nil)]),
            (a, a, a, [.symbol("not-nil", metadata: nil), .symbol("not-nil", metadata: nil), .symbol("not-nil", metadata: nil)]),
        ]
        for (x, y, z, expected) in cases {
            let form = "\(Self.setup) ((fnil fnil-test-fn 100 200 300) \(x) \(y) \(z))"
            #expect(try swish.eval(form) == .vector(expected, metadata: nil))
        }
    }

    // MARK: - variadic tail (& ds) passes through unpatched

    @Test("fnil arity 3 called with 4 args: trailing arg passes through apply unpatched")
    func fnilArity3Variadic() throws {
        #expect(try swish.eval("\(Self.setup) ((fnil fnil-test-fn 100 200 300) nil nil nil fnil-arg)") == .vector([.integer(100), .integer(200), .integer(300), .symbol("not-nil", metadata: nil)], metadata: nil))
        #expect(try swish.eval("\(Self.setup) ((fnil fnil-test-fn 100 200 300) fnil-arg nil nil fnil-arg)") == .vector([.symbol("not-nil", metadata: nil), .integer(200), .integer(300), .symbol("not-nil", metadata: nil)], metadata: nil))
        #expect(try swish.eval("\(Self.setup) ((fnil fnil-test-fn 100 200 300) nil fnil-arg nil fnil-arg)") == .vector([.integer(100), .symbol("not-nil", metadata: nil), .integer(300), .symbol("not-nil", metadata: nil)], metadata: nil))
        #expect(try swish.eval("\(Self.setup) ((fnil fnil-test-fn 100 200 300) nil nil fnil-arg fnil-arg)") == .vector([.integer(100), .integer(200), .symbol("not-nil", metadata: nil), .symbol("not-nil", metadata: nil)], metadata: nil))
    }

    @Test("fnil arity 1 called with 4 args: only first position is patched")
    func fnilArity1Variadic() throws {
        #expect(try swish.eval("\(Self.setup) ((fnil fnil-test-fn 100) nil 2 3 4)") == .vector([.integer(100), .integer(2), .integer(3), .integer(4)], metadata: nil))
    }

    @Test("fnil arity 2 called with 4 args: only first two positions are patched")
    func fnilArity2Variadic() throws {
        #expect(try swish.eval("\(Self.setup) ((fnil fnil-test-fn 100 200) nil nil 3 4)") == .vector([.integer(100), .integer(200), .integer(3), .integer(4)], metadata: nil))
    }
}
