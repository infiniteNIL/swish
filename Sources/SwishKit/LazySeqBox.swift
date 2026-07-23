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

    private enum Outcome {
        case value(Expr?, Expr)
        case failure(Error)
    }

    private var state: State
    private let lock = NSLock()

    /// Creates a box whose value is computed on first force.
    init(thunk: @escaping @Sendable () throws -> Expr) {
        state = .unrealized(thunk)
    }

    deinit {
        // Unlink the tail chain iteratively instead of letting ARC recurse into
        // it: next/seq memoize each realized step as .cons(head, tail: .lazySeq(next)),
        // so a long-realized chain (e.g. from (dorun (range n)), whose recur
        // trampoline in callUserFunction keeps the chain's head reachable for
        // the whole call) is a genuine singly linked list of LazySeqBox. Since
        // Expr is an indirect enum (heap-boxed), Swift's compiler-generated
        // deinit for a long reference chain like this is not tail-call-optimized
        // — releasing the head would otherwise trigger one recursive deinit per
        // link, overflowing the stack for large n. isKnownUniquelyReferenced
        // guards correctness: only detach a link's tail if this walk is the
        // only thing keeping it alive — if something else aliases into the
        // middle of the chain, the walk stops there and normal (safe, since
        // that box's own eventual deinit runs this same logic) ARC teardown
        // proceeds from that point.
        guard case .cons(_, var tailExpr) = state else { return }
        state = .empty
        while case .lazySeq(var box) = tailExpr {
            // tailExpr must release its own hold on the box before the
            // uniqueness check below, or it counts as a second reference and
            // isKnownUniquelyReferenced always (incorrectly) reports false.
            tailExpr = .nil
            guard isKnownUniquelyReferenced(&box) else { break }
            guard case .cons(_, let nextTail) = box.state else { break }
            box.state = .empty
            tailExpr = nextTail
        }
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

        case .unrealized:
            // Release before evaluating so the thunk can force other boxes without deadlock.
            lock.unlock()
            switch LazySeqBox.resolveChain(startingAt: self) {
            case .value(let h, let t):
                lock.lock()
                if case .unrealized = state {
                    state = h != nil ? .cons(head: h!, tail: t) : .empty
                }
                lock.unlock()

            case .failure(let error):
                throw error
            }
        }
    }

    /// Resolves `start`'s thunk, following a chain of "thunk returned another
    /// unrealized lazy seq" links (e.g. filter's non-matching branch calling
    /// itself, which happens once per rejected element) iteratively rather
    /// than recursively — so a run of any length costs O(1) Swift stack
    /// depth instead of one frame per link. Mirrors real Clojure's
    /// `LazySeq.seq()` trampolining loop, including memoizing every box
    /// along the chain (not just `start`) once the final result — or
    /// failure — is known, in case anything else independently holds a
    /// reference to one of the intermediate boxes.
    private static func resolveChain(startingAt start: LazySeqBox) -> Outcome {
        var chain: [LazySeqBox] = []
        var box = start
        while true {
            box.lock.lock()
            let currentState = box.state
            box.lock.unlock()

            switch currentState {
            case .cons(let h, let t):
                backfill(chain, head: h, tail: t)
                return .value(h, t)

            case .empty:
                backfill(chain, head: nil, tail: .nil)
                return .value(nil, .nil)

            case .error(let e):
                backfillError(chain, e)
                return .failure(e)

            case .unrealized(let thunk):
                do {
                    let result = try thunk()
                    if case .lazySeq(let next) = result {
                        chain.append(box)
                        box = next
                        continue
                    }
                    let (h, t) = try normalizeConcrete(result)
                    box.lock.lock()
                    if case .unrealized = box.state {
                        box.state = h != nil ? .cons(head: h!, tail: t) : .empty
                    }
                    box.lock.unlock()
                    backfill(chain, head: h, tail: t)
                    return .value(h, t)
                }
                catch {
                    box.lock.lock()
                    if case .unrealized = box.state { box.state = .error(error) }
                    box.lock.unlock()
                    backfillError(chain, error)
                    return .failure(error)
                }
            }
        }
    }

    private static func backfill(_ chain: [LazySeqBox], head: Expr?, tail: Expr) {
        for box in chain {
            box.lock.lock()
            if case .unrealized = box.state {
                box.state = head != nil ? .cons(head: head!, tail: tail) : .empty
            }
            box.lock.unlock()
        }
    }

    private static func backfillError(_ chain: [LazySeqBox], _ error: Error) {
        for box in chain {
            box.lock.lock()
            if case .unrealized = box.state { box.state = .error(error) }
            box.lock.unlock()
        }
    }

    /// Normalizes the value returned by a thunk into (head?, tail) form.
    ///
    /// The thunk contract: return `nil` / empty seq for empty, or a seq whose
    /// first element is the head and whose rest is the tail. Callers that may
    /// receive a `.lazySeq` result should use `normalize` instead, which
    /// unwraps chains of nested lazy seqs iteratively; this handles only the
    /// concrete (non-lazySeq) cases.
    static func normalizeConcrete(_ expr: Expr) throws -> (Expr?, Expr) {
        switch expr {
        case .nil:
            return (nil, .nil)

        case .list(let elems, _) where elems.isEmpty:
            return (nil, .nil)

        case .list(let elems, _):
            let tail: Expr = elems.count == 1
                ? .nil
                : .list(elems.dropFirst(1), metadata: nil)
            return (elems[0], tail)

        case .lazySeq(let inner):
            return try normalize(.lazySeq(inner))

        default:
            guard let elems = try asSequence(expr) else {
                throw EvaluatorError.invalidArgument(function: "lazy-seq",
                    message: "don't know how to create seq from \(corePrinter.printString(expr))")
            }
            if !elems.isEmpty {
                let tail: Expr = elems.count == 1
                    ? .nil
                    : .list(SwishPersistentList(Array(elems.dropFirst())), metadata: nil)
                return (elems[0], tail)
            }
            return (nil, .nil)
        }
    }

    /// Normalizes the value returned by a thunk into (head?, tail) form.
    /// Dispatches `.lazySeq` results to the iterative chain resolver so long
    /// runs of nested lazy seqs (e.g. `filter` skipping thousands of
    /// non-matching elements in a row) stay stack-safe.
    static func normalize(_ expr: Expr) throws -> (Expr?, Expr) {
        guard case .lazySeq(let inner) = expr else {
            return try normalizeConcrete(expr)
        }
        switch resolveChain(startingAt: inner) {
        case .value(let h, let t):
            return (h, t)
        case .failure(let error):
            throw error
        }
    }
}
