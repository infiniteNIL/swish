import Testing
@testable import SwishKit

@Suite("Core take-last Tests", .serialized)
struct CoreTakeLastTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - jank fixture cases

    @Test("take-last on a lazy range returns the last n items")
    func takeLastRange() throws {
        #expect(try swish.eval("(= (range 8 10) (take-last 2 (range 0 10)))") == .boolean(true))
    }

    @Test("(take-last 2 nil) returns nil, not an empty list")
    func takeLastNilColl() throws {
        #expect(try swish.eval("(take-last 2 nil)") == .nil)
    }

    @Test("take-last with a nil n throws")
    func takeLastNilN() throws {
        #expect(throws: (any Error).self) { try swish.eval("(doall (take-last nil (range 0 10)))") }
    }

    // MARK: - other collection types and edge cases

    @Test("take-last on a vector and a list returns the last n items")
    func takeLastVectorAndList() throws {
        #expect(try swish.eval("(take-last 3 [1 2 3 4 5])") == .list([3, 4, 5].map { .integer($0) }, metadata: nil))
        #expect(try swish.eval("(take-last 3 '(1 2 3 4 5))") == .list([3, 4, 5].map { .integer($0) }, metadata: nil))
    }

    @Test("(take-last 0 coll) returns nil")
    func takeLastZero() throws {
        #expect(try swish.eval("(take-last 0 [1 2 3])") == .nil)
    }

    @Test("take-last with n greater than the collection's count returns the whole collection")
    func takeLastNGreaterThanCount() throws {
        #expect(try swish.eval("(take-last 10 [1 2 3])") == .list([1, 2, 3].map { .integer($0) }, metadata: nil))
    }

    @Test("take-last on an empty vector returns nil")
    func takeLastEmptyVector() throws {
        #expect(try swish.eval("(take-last 2 [])") == .nil)
    }

    // MARK: - lazy-seq stack-safety regression

    @Test("take-last on a moderately large lazy range does not overflow the stack")
    func takeLastLargeLazyRange() throws {
        // Regression guard for the specific concern this task was asked about:
        // take-last's loop/recur walks next once per element of the whole
        // collection, structurally similar to the (dorun (range n)) pattern
        // that used to segfault via recursive LazySeqBox deinit (see
        // CLAUDE.md). take-last's loop/recur compiles through evalLoop
        // (shared-environment rebinding per iteration), not
        // callUserFunction's recur trampoline, so it shouldn't hit that
        // failure mode. Stack-safety at extreme scale is already proven
        // cheaply by LazySeqTests' white-box LazySeqBox chain tests — this
        // just needs to prove take-last's own code path is genuinely
        // exercised end to end, so it stays a moderate size rather than
        // approaching the historical ~20000 crash threshold directly
        // (which, at Swish's interpreter cost, would make this one test
        // take upwards of ten seconds for no extra confidence).
        #expect(try swish.eval("(take-last 3 (range 5000))") ==
            .list([4997, 4998, 4999].map { .integer($0) }, metadata: nil))
    }
}
