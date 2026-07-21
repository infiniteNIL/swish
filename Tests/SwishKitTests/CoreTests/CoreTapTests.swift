import Testing
@testable import SwishKit

@Suite("Core add-tap/tap>/remove-tap Tests", .serialized)
struct CoreTapTests {
    // tap-tester/await-tap mirror the jank suite's own taps.cljc fixture:
    // sending a promise through tap> and blocking on it is a synchronization
    // barrier — by the time it's delivered, every tap registered at that
    // point has already processed everything sent before it (tap dispatch
    // is a strictly ordered, single serial queue).
    static let _shared: Swish = {
        let swish = Swish()
        _ = try? swish.eval("""
            (defn tap-tester [atom-ref]
              (fn [x]
                (if (= (type x) :promise)
                  (deliver x nil)
                  (swap! atom-ref conj x))))
            (defn await-tap []
              (let [p (promise)]
                (tap> p)
                @p))
            """)
        return swish
    }()
    var swish: Swish { Self._shared }

    @Test("add-tap and remove-tap both return nil")
    func addRemoveTapReturnNil() throws {
        #expect(try swish.eval("""
            (let [tap (tap-tester (atom []))]
              [(nil? (add-tap tap)) (nil? (remove-tap tap))])
            """) == .vector([.boolean(true), .boolean(true)], metadata: nil))
    }

    @Test("tap> returns true")
    func tapSendReturnsTrue() throws {
        #expect(try swish.eval("""
            (let [tap (tap-tester (atom []))]
              (add-tap tap)
              (let [result (tap> :x)]
                (remove-tap tap)
                result))
            """) == .boolean(true))
    }

    @Test("a tapped value reaches a registered tap")
    func tapReachesRegisteredTap() throws {
        #expect(try swish.eval("""
            (let [results (atom [])
                  tap (tap-tester results)]
              (add-tap tap)
              (tap> :hello)
              (await-tap)
              (remove-tap tap)
              @results)
            """) == .vector([.keyword("hello")], metadata: nil))
    }

    @Test("a tapped value does not reach an unregistered tap")
    func tapDoesNotReachUnregisteredTap() throws {
        // await-tap needs at least one registered tap to deliver its sync
        // promise, or it blocks forever — register a harmless sentinel tap
        // just to keep it functional, while the tap under test (`tap`) is
        // deliberately never registered.
        #expect(try swish.eval("""
            (let [results (atom [])
                  tap (tap-tester results)
                  sentinel (tap-tester (atom []))]
              (add-tap sentinel)
              (tap> :should-not-appear)
              (await-tap)
              (remove-tap sentinel)
              @results)
            """) == .vector([], metadata: nil))
    }

    @Test("remove-tap stops future delivery but doesn't undo values already received")
    func removeTapStopsFutureDelivery() throws {
        // Same sentinel-tap need as tapDoesNotReachUnregisteredTap above: the
        // second await-tap runs after `tap` is removed, so something else
        // must stay registered to deliver its sync promise.
        #expect(try swish.eval("""
            (let [results (atom [])
                  tap (tap-tester results)
                  sentinel (tap-tester (atom []))]
              (add-tap sentinel)
              (add-tap tap)
              (tap> :before)
              (await-tap)
              (remove-tap tap)
              (tap> :after)
              (await-tap)
              (remove-tap sentinel)
              @results)
            """) == .vector([.keyword("before")], metadata: nil))
    }

    @Test("multiple taps all receive the same value")
    func multipleTapsAllReceiveValue() throws {
        #expect(try swish.eval("""
            (let [results-1 (atom [])
                  results-2 (atom [])
                  tap-1 (tap-tester results-1)
                  tap-2 (tap-tester results-2)]
              (add-tap tap-1)
              (add-tap tap-2)
              (tap> :both)
              (await-tap)
              (remove-tap tap-1)
              (remove-tap tap-2)
              [@results-1 @results-2])
            """) == .vector([
                .vector([.keyword("both")], metadata: nil),
                .vector([.keyword("both")], metadata: nil),
            ], metadata: nil))
    }

    @Test("a throwing tap does not prevent other taps from receiving the value or crash the process")
    func throwingTapDoesNotAffectOthers() throws {
        #expect(try swish.eval("""
            (let [results (atom [])
                  boom (fn [x] (throw (ex-info "boom" {})))
                  tap (tap-tester results)]
              (add-tap boom)
              (add-tap tap)
              (tap> :survives)
              (await-tap)
              (remove-tap boom)
              (remove-tap tap)
              @results)
            """) == .vector([.keyword("survives")], metadata: nil))
    }
}
