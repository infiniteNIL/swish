import Synchronization

/// Backing store for a `delay`. Holds either an unrealized thunk or its
/// memoized result. Thread-safe via `Mutex`.
public final class DelayBox: @unchecked Sendable {

    private enum State {
        case unrealized(@Sendable () throws -> Expr)
        case realized(Expr)
        case error(Error)
    }

    private enum ClaimResult {
        case value(Expr)
        case error(Error)
        case run(@Sendable () throws -> Expr)
    }

    private let state: Mutex<State>

    public init(thunk: @escaping @Sendable () throws -> Expr) {
        state = Mutex(.unrealized(thunk))
    }

    /// Returns true if the thunk has already been forced.
    public var isRealized: Bool {
        state.withLock {
            if case .unrealized = $0 { return false }
            return true
        }
    }

    /// Forces the thunk if not yet realized. Returns the memoized value.
    public func force() throws -> Expr {
        // Read-or-claim happens under a single lock acquisition: an unrealized
        // box is immediately marked with a placeholder so a second caller
        // racing in sees `.realized` rather than re-running the thunk. The
        // claimed thunk is then run with the lock released, since it's
        // arbitrary user code that could take a long time or (for a
        // self-referential delay) call back into `force()` itself.
        let claim: ClaimResult = state.withLock {
            switch $0 {
            case .realized(let v):
                return .value(v)

            case .error(let e):
                return .error(e)

            case .unrealized(let thunk):
                $0 = .realized(.nil)
                return .run(thunk)
            }
        }

        switch claim {
        case .value(let v):
            return v

        case .error(let e):
            throw e

        case .run(let thunk):
            do {
                let v = try thunk()
                state.withLock { $0 = .realized(v) }
                return v
            }
            catch {
                state.withLock { $0 = .error(error) }
                throw error
            }
        }
    }
}
