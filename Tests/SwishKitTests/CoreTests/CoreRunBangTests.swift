import Testing
@testable import SwishKit

@Suite("Core run! Tests", .serialized)
struct CoreRunBangTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - always returns nil

    @Test("run! always returns nil")
    func runBangAlwaysNil() throws {
        #expect(try swish.eval("(nil? (run! identity []))") == .boolean(true))
        #expect(try swish.eval("(nil? (run! identity [1]))") == .boolean(true))
        #expect(try swish.eval("(nil? (run! identity [1 2 3]))") == .boolean(true))
        #expect(try swish.eval(#"(nil? (run! identity ["foo" "bar"]))"#) == .boolean(true))
    }

    // MARK: - causes side effects proportional to collection size

    @Test("run! causes one side effect per element, none for nil or empty")
    func runBangSideEffects() throws {
        #expect(try swish.eval("""
            (let [calls (volatile! 0)
                  inc-calls (fn [_] (vswap! calls inc))]
              (run! inc-calls nil)
              (run! inc-calls [])
              (run! inc-calls [0])
              (run! inc-calls [0 0])
              @calls)
            """) == .integer(3))
    }

    // MARK: - seqable is required

    @Test("run! throws for a non-seqable collection and attempts no side effects")
    func runBangNonSeqableThrows() throws {
        #expect(try swish.eval("""
            (let [sum (volatile! 0)
                  add! (fn [n] (vswap! sum + n))
                  threw (try (run! add! true) false (catch Exception e true))]
              [threw @sum])
            """) == .vector([.boolean(true), .integer(0)], metadata: nil))
    }

    @Test("run! works over a set")
    func runBangSet() throws {
        #expect(try swish.eval("""
            (let [sum (volatile! 0)
                  add! (fn [n] (vswap! sum + n))]
              (run! add! #{1 2 3})
              @sum)
            """) == .integer(6))
    }

    // MARK: - passes collection sequentially

    @Test("run! passes elements to proc in order")
    func runBangSequentialOrder() throws {
        #expect(try swish.eval("""
            (let [result (volatile! [])
                  coll [:foo "bar" 'baz]]
              (run! (fn [v] (vswap! result conj v)) coll)
              (= coll @result))
            """) == .boolean(true))
    }

    // MARK: - terminates on exception

    @Test("run! propagates an exception thrown by proc, stopping after the first call")
    func runBangTerminatesOnException() throws {
        #expect(try swish.eval("""
            (let [calls (volatile! 0)
                  boom! (fn [_] (vswap! calls inc) (throw (ex-info "Boom!" {})))
                  threw (try (run! boom! (range 2)) false (catch Exception e true))]
              [threw @calls])
            """) == .vector([.boolean(true), .integer(1)], metadata: nil))
    }

    // MARK: - terminates on reduced

    @Test("run! stops early when proc returns reduced, calling proc only once")
    func runBangTerminatesOnReduced() throws {
        #expect(try swish.eval("""
            (let [calls (volatile! 0)
                  done! (fn [_] (vswap! calls inc) (reduced :done))
                  result (run! done! (range 2))]
              [(nil? result) @calls])
            """) == .vector([.boolean(true), .integer(1)], metadata: nil))
    }
}
