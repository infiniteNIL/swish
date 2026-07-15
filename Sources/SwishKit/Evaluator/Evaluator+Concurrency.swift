import Foundation

extension Evaluator {

    /// Reads `bindingFrames` NOW, on the calling thread, before dispatching
    /// anywhere. The result is a value-type snapshot (Array/Dictionary are
    /// copy-on-write), safe to hand to another thread.
    func captureCurrentBindings() -> [[ObjectIdentifier: Expr]] {
        bindingFrames
    }

    /// Runs `body` with `frames`/`depth` installed as this thread's
    /// `bindingFrames`/`callDepth`, restoring whatever was there before on exit.
    ///
    /// Safe to call from ANY thread, including a GCD pool thread reused from an
    /// earlier, unrelated work item: this unconditionally overwrites (rather than
    /// merges with) whatever stale state might be sitting in that thread's
    /// `threadDictionary`, which is what makes `Thread.current.threadDictionary`-backed
    /// thread-local storage safe to use under thread-pool reuse (see `Evaluator.swift`'s
    /// `bindingFrames` doc comment).
    func withInstalledBindings<T>(
        _ frames: [[ObjectIdentifier: Expr]],
        callDepth depth: Int,
        _ body: () throws -> T
    ) rethrows -> T {
        let savedFrames = bindingFrames
        let savedDepth = callDepth
        bindingFrames = frames
        callDepth = depth
        defer {
            bindingFrames = savedFrames
            callDepth = savedDepth
        }
        return try body()
    }

    private static let cancellationCheckKey = "swish.evaluator.currentCancellationCheck"

    /// Thread-local, installed only around a `future`'s body execution — read by
    /// `sleep!` so a cancelled future's sleep can exit early. `nil` outside
    /// a future body (e.g. plain top-level `(sleep ...)`), in which case sleep
    /// just runs to completion normally.
    var currentCancellationCheck: (() -> Bool)? {
        get { threadLocalBox(for: Self.cancellationCheckKey, default: nil).value }
        set { threadLocalBox(for: Self.cancellationCheckKey, default: nil).value = newValue }
    }
}
