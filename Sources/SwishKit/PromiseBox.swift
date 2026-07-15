import Foundation

/// Backing store for a `promise` — a single-slot, deliver-once synchronization
/// primitive. `deref` blocks until a value is delivered.
public final class PromiseBox: @unchecked Sendable {
    private var value: Expr?
    private let cond = NSCondition()

    /// Delivers `v` if not already delivered. Returns whether this call delivered
    /// the value (false if the promise was already delivered).
    @discardableResult
    func deliver(_ v: Expr) -> Bool {
        cond.lock()
        defer { cond.unlock() }
        guard value == nil else { return false }
        value = v
        cond.broadcast()
        return true
    }

    var isRealized: Bool {
        cond.lock()
        defer { cond.unlock() }
        return value != nil
    }

    /// Blocks until delivered.
    func deref() -> Expr {
        cond.lock()
        defer { cond.unlock() }
        while value == nil {
            cond.wait()
        }
        return value!
    }
}
