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
        let depthBox = callDepthBox()
        let savedFrames = bindingFrames
        let savedDepth = depthBox.value
        bindingFrames = frames
        depthBox.value = depth
        defer {
            bindingFrames = savedFrames
            depthBox.value = savedDepth
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

    private static let agentActionSendsKey = "swish.evaluator.agentActionSends"

    /// Nested `send`/`send-off` calls issued while an agent action is running on
    /// this thread, held rather than dispatched immediately. `nil` means "not
    /// inside an action" (dispatch immediately). Released on the action's
    /// successful completion, discarded if it throws — matching Clojure's
    /// `Agent.nested`. Thread-local for the same reason `currentTransaction` is:
    /// `SwishAgent.runAction` runs synchronously on the agent's own serial queue.
    var currentAgentActionSends: [() -> Void]? {
        get { threadLocalBox(for: Self.agentActionSendsKey, default: [() -> Void]?.none).value }
        set { threadLocalBox(for: Self.agentActionSendsKey, default: [() -> Void]?.none).value = newValue }
    }

    /// Buffers a nested send. Only called when `currentAgentActionSends != nil`
    /// (i.e. an action is running); a get-append-set since the buffer is a value
    /// type behind the thread-local.
    func holdAgentActionSend(_ action: @escaping () -> Void) {
        var buffer = currentAgentActionSends ?? []
        buffer.append(action)
        currentAgentActionSends = buffer
    }

    /// Dispatches the currently-held nested sends and clears the buffer to empty
    /// (still "in an action", so more can accumulate after) — matching Clojure's
    /// `releasePendingSends`. A no-op returning 0 when not inside an action. Backs
    /// both the end-of-action release in `runAction` and `release-pending-sends`.
    @discardableResult
    func releaseAgentActionSends() -> Int {
        guard let buffer = currentAgentActionSends else { return 0 }
        currentAgentActionSends = []
        for action in buffer {
            action()
        }
        return buffer.count
    }
}
