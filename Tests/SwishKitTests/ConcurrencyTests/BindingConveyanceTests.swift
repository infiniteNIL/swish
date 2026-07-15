import Testing
@testable import SwishKit

/// Transliterates binding.cljc's and bound_fn.cljc's exact "Threaded/future
/// cases" assertions: a future captures the calling thread's dynamic bindings
/// at the moment it's created, not at deref time or from whatever's active on
/// the deref'ing thread, and nested futures each capture their own creation
/// instant independently.
@Suite("Binding Conveyance Tests")
struct BindingConveyanceTests {
    @Test("a future does not see bindings established after its own creation, on either thread")
    func futureIsolatedFromLaterBindings() throws {
        let swish = Swish()
        #expect(try swish.eval("""
            (def ^:dynamic *bc-x* :unset)
            (def f (future *bc-x*))
            (binding [*bc-x* :now-here] @f)
            """) == .keyword("unset"))
    }

    @Test("a future captures the binding active at its own creation instant")
    func futureCapturesCreationTimeBinding() throws {
        let swish = Swish()
        #expect(try swish.eval("""
            (def ^:dynamic *bc-y* :unset)
            (binding [*bc-y* :outer]
              (def f2 (future *bc-y*))
              (binding [*bc-y* :inner] @f2))
            """) == .keyword("outer"))
    }

    @Test("nested futures each capture their own creation-instant binding independently")
    func nestedFuturesCaptureIndependently() throws {
        let swish = Swish()
        #expect(try swish.eval("""
            (def ^:dynamic *bc-z* :unset)
            (binding [*bc-z* :caller]
              (let [f (future
                        (binding [*bc-z* :callee]
                          (future *bc-z*)))]
                (binding [*bc-z* :derefer]
                  (let [derefed-f @f]
                    @derefed-f))))
            """) == .keyword("callee"))
    }
}
