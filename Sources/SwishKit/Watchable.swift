/// Shared add/remove-watch mechanism for the four mutable reference types that
/// support `add-watch`/`remove-watch`. Each stores `watches` inside its own
/// private, Mutex-protected state struct, so conforming only needs a small
/// per-type `mutateWatches` bridge into that lock.
protocol Watchable: AnyObject {
    func mutateWatches(_ body: (inout [Expr: Expr]) -> Void)
}

extension Watchable {
    func addWatch(key: Expr, fn: Expr) {
        mutateWatches { $0[key] = fn }
    }

    func removeWatch(key: Expr) {
        mutateWatches { _ = $0.removeValue(forKey: key) }
    }
}
