import Testing
@testable import SwishKit

@Suite("Future Concurrency Tests")
struct FutureConcurrencyTests {
    /// GCD reuses OS threads across unrelated work items (confirmed against
    /// Apple's own dispatch/queue.h docs during Step 1's design). Running many
    /// sequential future round-trips against one shared Evaluator, each with a
    /// distinct binding, is likely to reuse the same pooled thread across
    /// several of them — proving the capture/install/restore wrapper actually
    /// neutralizes any stale leftover state rather than merely working by
    /// accident on a fresh thread each time.
    @Test("many sequential futures with distinct bindings show zero cross-contamination")
    func noCrossContaminationAcrossReusedThreads() throws {
        let swish = Swish()
        _ = try swish.eval("(def ^:dynamic *fc-x* :unset)")
        for i in 0..<50 {
            let result = try swish.eval("(binding [*fc-x* \(i)] @(future *fc-x*))")
            #expect(result == .integer(i), "iteration \(i) saw contaminated binding state")
        }
    }
}
