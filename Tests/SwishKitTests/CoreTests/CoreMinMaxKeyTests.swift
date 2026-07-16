import Testing
@testable import SwishKit

@Suite("Core min-key/max-key Tests", .serialized)
struct CoreMinMaxKeyTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - min-key numeric ordering

    @Test("min-key numeric ordering across int/bigint/double/ratio")
    func minKeyNumericOrdering() throws {
        #expect(try swish.eval("(apply min-key identity [1 2])") == .integer(1))
        #expect(try swish.eval("(apply min-key identity [1 3 2])") == .integer(1))
        #expect(try swish.eval("(apply min-key identity [1N 2N])") == .bigInteger(1))
        #expect(try swish.eval("(apply min-key identity [2N 1N 3N])") == .bigInteger(1))
        #expect(try swish.eval("(apply min-key identity [1N 2])") == .bigInteger(1))
        #expect(try swish.eval("(apply min-key identity [1 2N])") == .integer(1))
        #expect(try swish.eval("(apply min-key identity [1.0 2.0])") == .double(1.0))
        #expect(try swish.eval("(apply min-key identity [1 2.0])") == .integer(1))
        #expect(try swish.eval("(apply min-key identity [1.0 2])") == .double(1.0))
        #expect(try swish.eval("(apply min-key identity [1/2 2/2])") == .ratio(Ratio(1, 2)))
        #expect(try swish.eval("(apply min-key identity [1/2 1])") == .ratio(Ratio(1, 2)))
    }

    // MARK: - min-key IEEE-754 special cases

    @Test("min-key handles Inf/-Inf")
    func minKeyInfinities() throws {
        #expect(try swish.eval("(apply min-key identity [##-Inf ##Inf])") == .double(-Double.infinity))
        #expect(try swish.eval("(apply min-key identity [1 ##Inf])") == .integer(1))
        #expect(try swish.eval("(apply min-key identity [1 ##-Inf])") == .double(-Double.infinity))
    }

    @Test("min-key NaN weirdness matches IEEE-754 comparison semantics")
    func minKeyNaN() throws {
        // (< NaN 1) and (< 1 NaN) are both false, so NaN never "wins" as a strict minimum
        #expect(try swish.eval("(apply min-key identity [##NaN 1])") == .integer(1))
        #expect(try swish.eval("(NaN? (apply min-key identity [1 ##NaN]))") == .boolean(true))
        #expect(try swish.eval("(apply min-key identity [##NaN ##-Inf 1])") == .double(-Double.infinity))
        #expect(try swish.eval("(apply min-key identity [##NaN 1 ##-Inf])") == .double(-Double.infinity))
    }

    // MARK: - min-key single argument

    @Test("min-key with a single argument returns it without calling k")
    func minKeySingleArgument() throws {
        #expect(try swish.eval("(min-key identity 1)") == .integer(1))
        #expect(try swish.eval("(min-key identity 2)") == .integer(2))
        #expect(try swish.eval(#"(min-key identity "x")"#) == .string("x"))
        #expect(try swish.eval("(min-key nil 1)") == .integer(1))
    }

    // MARK: - min-key multi-argument, including tie-breaking

    @Test("min-key multi-argument")
    func minKeyMultiArgument() throws {
        #expect(try swish.eval("(apply min-key inc [-3 -1 2])") == .integer(-3))
        #expect(try swish.eval("(apply min-key identity [1 2 3 4 5])") == .integer(1))
        #expect(try swish.eval("(apply min-key identity [5 4 3 2 1])") == .integer(1))
    }

    @Test("min-key breaks ties by returning the last matching element")
    func minKeyTieBreaking() throws {
        #expect(try swish.eval("(apply min-key (constantly 5) [nil 1 {:k 2} [3] '(4) #{5} \"a\"])") == .string("a"))
    }

    // MARK: - min-key with non-trivial key functions

    @Test("min-key with count and keyword key functions")
    func minKeyKeyFunctions() throws {
        #expect(try swish.eval(#"(apply min-key count ["a" "bb" "ccc"])"#) == .string("a"))
        #expect(try swish.eval(#"(apply min-key count ["a" "bb" "c"])"#) == .string("c"))
        #expect(try swish.eval("(apply min-key :val [{:val 2} {:val 3} {:val 4}])") == .map([.keyword("val"): .integer(2)], metadata: nil))
    }

    // MARK: - min-key negative cases

    @Test("min-key throws when k is nil but is actually called (2+ args)")
    func minKeyNilKeyThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(apply min-key nil [1 2])") }
        #expect(throws: (any Error).self) { try swish.eval("(apply min-key nil [2 1 3])") }
    }

    @Test("min-key throws for non-numeric key results")
    func minKeyNonNumericKeyThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval(#"(apply min-key identity ["x" "y"])"#) }
        #expect(throws: (any Error).self) { try swish.eval("(apply min-key identity [[1] [2]])") }
        #expect(throws: (any Error).self) { try swish.eval("(apply min-key identity [{:val 1} {:val 2}])") }
        #expect(throws: (any Error).self) { try swish.eval("(apply min-key identity [#{1} #{2}])") }
    }

    // MARK: - max-key (mirrors min-key with flipped expectations; no dedicated jank fixture)

    @Test("max-key numeric ordering across int/bigint/double/ratio")
    func maxKeyNumericOrdering() throws {
        #expect(try swish.eval("(apply max-key identity [1 2])") == .integer(2))
        #expect(try swish.eval("(apply max-key identity [1 3 2])") == .integer(3))
        #expect(try swish.eval("(apply max-key identity [1N 2N])") == .bigInteger(2))
        #expect(try swish.eval("(apply max-key identity [1 2N])") == .bigInteger(2))
        #expect(try swish.eval("(apply max-key identity [1.0 2])") == .integer(2))
    }

    @Test("max-key handles Inf/-Inf")
    func maxKeyInfinities() throws {
        #expect(try swish.eval("(apply max-key identity [##-Inf ##Inf])") == .double(Double.infinity))
        #expect(try swish.eval("(apply max-key identity [1 ##Inf])") == .double(Double.infinity))
        #expect(try swish.eval("(apply max-key identity [1 ##-Inf])") == .integer(1))
    }

    @Test("max-key with a single argument returns it without calling k")
    func maxKeySingleArgument() throws {
        #expect(try swish.eval("(max-key identity 1)") == .integer(1))
        #expect(try swish.eval("(max-key nil 1)") == .integer(1))
    }

    @Test("max-key multi-argument")
    func maxKeyMultiArgument() throws {
        #expect(try swish.eval("(apply max-key inc [-3 -1 2])") == .integer(2))
        #expect(try swish.eval("(apply max-key identity [1 2 3 4 5])") == .integer(5))
        #expect(try swish.eval("(apply max-key identity [5 4 3 2 1])") == .integer(5))
    }

    @Test("max-key breaks ties by returning the last matching element")
    func maxKeyTieBreaking() throws {
        #expect(try swish.eval("(apply max-key (constantly 5) [nil 1 {:k 2} [3] '(4) #{5} \"a\"])") == .string("a"))
    }

    @Test("max-key with count and keyword key functions")
    func maxKeyKeyFunctions() throws {
        #expect(try swish.eval(#"(apply max-key count ["a" "bb" "ccc"])"#) == .string("ccc"))
        #expect(try swish.eval("(apply max-key :val [{:val 2} {:val 3} {:val 4}])") == .map([.keyword("val"): .integer(4)], metadata: nil))
    }

    @Test("max-key throws when k is nil but is actually called (2+ args)")
    func maxKeyNilKeyThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(apply max-key nil [1 2])") }
    }

    @Test("max-key throws for non-numeric key results")
    func maxKeyNonNumericKeyThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval(#"(apply max-key identity ["x" "y"])"#) }
        #expect(throws: (any Error).self) { try swish.eval("(apply max-key identity [{:val 1} {:val 2}])") }
    }
}
