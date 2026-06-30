import Foundation

/// Backing store for a `delay`. Holds either an unrealized thunk or its
/// memoized result. Thread-safe via NSLock.
public final class DelayBox: @unchecked Sendable {

    private enum State {
        case unrealized(@Sendable () throws -> Expr)
        case realized(Expr)
        case error(Error)
    }

    private var state: State
    private let lock = NSLock()

    public init(thunk: @escaping @Sendable () throws -> Expr) {
        self.state = .unrealized(thunk)
    }

    /// Returns true if the thunk has already been forced.
    public var isRealized: Bool {
        lock.lock()
        defer { lock.unlock() }
        if case .unrealized = state { return false }
        return true
    }

    /// Forces the thunk if not yet realized. Returns the memoized value.
    public func force() throws -> Expr {
        lock.lock()
        switch state {
        case .realized(let v):
            lock.unlock()
            return v

        case .error(let e):
            lock.unlock()
            throw e

        case .unrealized(let thunk):
            // Set a placeholder to break cycles, then release before evaluating.
            state = .realized(.nil)
            lock.unlock()
            do {
                let v = try thunk()
                lock.lock()
                state = .realized(v)
                lock.unlock()
                return v
            }
            catch {
                lock.lock()
                state = .error(error)
                lock.unlock()
                throw error
            }
        }
    }
}
