import Foundation

/// Backing store for a lazy sequence. Holds either an unrealized thunk or its
/// memoized (head, tail) result. Thread-safe via NSLock.
///
/// Forcing a box produces either an empty signal or a cons cell (head + tail),
/// where tail is typically another `.lazySeq` or `.nil`.
public final class LazySeqBox: @unchecked Sendable {

    private enum State {
        case unrealized(@Sendable () throws -> Expr)
        case empty
        case cons(head: Expr, tail: Expr)
        case error(Error)
    }

    private var state: State
    private let lock = NSLock()

    /// Creates a box whose value is computed on first force.
    init(thunk: @escaping @Sendable () throws -> Expr) {
        state = .unrealized(thunk)
    }

    /// Creates a pre-realized cons cell. Used by `cons` when the tail is lazy.
    init(head: Expr, tail: Expr) {
        state = .cons(head: head, tail: tail)
    }

    /// Forces one step and returns the head element, or `nil` if the seq is empty.
    func forceHead() throws -> Expr? {
        try realizeIfNeeded()
        if case .cons(let h, _) = state { return h }
        return nil
    }

    /// Forces one step and returns the tail. Returns `.nil` when empty.
    func forceTail() throws -> Expr {
        try realizeIfNeeded()
        if case .cons(_, let t) = state { return t }
        return .nil
    }

    /// Returns true if the thunk has been forced (state is cons, empty, or error).
    /// A box created with init(head:tail:) is always considered realized.
    var isRealized: Bool {
        lock.lock()
        defer { lock.unlock() }
        if case .unrealized = state { return false }
        return true
    }

    // MARK: - Private

    private func realizeIfNeeded() throws {
        lock.lock()
        switch state {
        case .empty, .cons:
            lock.unlock()
            return

        case .error(let e):
            lock.unlock()
            throw e

        case .unrealized(let thunk):
            // Release before evaluating so the thunk can force other boxes without deadlock.
            lock.unlock()
            do {
                let result = try thunk()
                let (h, t) = try LazySeqBox.normalize(result)
                lock.lock()
                if case .unrealized = state {
                    state = h != nil ? .cons(head: h!, tail: t) : .empty
                }
                lock.unlock()
            }
            catch {
                lock.lock()
                if case .unrealized = state { state = .error(error) }
                lock.unlock()
                throw error
            }
        }
    }

    /// Normalizes the value returned by a thunk into (head?, tail) form.
    ///
    /// The thunk contract: return `nil` / empty seq for empty, or a seq whose
    /// first element is the head and whose rest is the tail.
    static func normalize(_ expr: Expr) throws -> (Expr?, Expr) {
        switch expr {
        case .nil:
            return (nil, .nil)

        case .list(let elems, _) where elems.isEmpty:
            return (nil, .nil)

        case .list(let elems, _):
            let tail: Expr = elems.count == 1
                ? .nil
                : .list(Array(elems.dropFirst()), metadata: nil)
            return (elems[0], tail)

        case .lazySeq(let inner):
            // Thunk returned another lazy seq — peel one step without recursing.
            let head = try inner.forceHead()
            let tail = try inner.forceTail()
            return (head, tail)

        default:
            guard let elems = asSequence(expr) else {
                throw EvaluatorError.invalidArgument(function: "lazy-seq",
                    message: "don't know how to create seq from \(corePrinter.printString(expr))")
            }
            if !elems.isEmpty {
                let tail: Expr = elems.count == 1
                    ? .nil
                    : .list(Array(elems.dropFirst()), metadata: nil)
                return (elems[0], tail)
            }
            return (nil, .nil)
        }
    }
}
