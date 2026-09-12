import Foundation

/// A lazily-realized sequence of decoded Swish values.
///
/// Named rather than an opaque `some Sequence<T>` so the iterator can expose
/// `failure`: `IteratorProtocol.next()` can't throw, so an element that fails to
/// realize or decode has to stop iteration — and stopping *silently* is the exact
/// bug this API exists to avoid. Check `failure` when the loop ends, or use
/// `Expr.forEach(of:_:)`, which throws and can't be ignored.
///
/// - Important: Each `next()` runs Swish code. Consume the sequence on the thread
///   that produced it.
public struct SwishLazySequence<T: SwishDecodable>: Sequence {
    public struct Iterator: IteratorProtocol {
        /// The cursor for a lazy seq, realized one element at a time.
        private var current: Expr?

        /// The already-realized elements of an eager collection. A vector, list
        /// or seq has nothing to realize, and yielding nothing for one would be
        /// the silent emptiness this type exists to avoid.
        private var eager: Array<Expr>.Iterator?

        /// Why iteration stopped early, or nil if the sequence ran to its end.
        ///
        /// A `SwishConversionError` when an element wasn't a `T` or the value
        /// wasn't sequential at all, or whatever realizing an element threw.
        public private(set) var failure: (any Error)?

        init(start: Expr) {
            if case .lazySeq = start {
                current = start
                return
            }
            do {
                guard let elements = try SwishKit.asSequence(start) else {
                    failure = SwishConversionError(expected: "a sequence", value: start)
                    return
                }
                eager = elements.makeIterator()
            }
            catch {
                failure = error
            }
        }

        public mutating func next() -> T? {
            if var elements = eager {
                let element = elements.next()
                eager = elements
                guard let element else { return nil }
                return decoded(element)
            }
            guard let box = nextBox() else { return nil }
            do {
                guard let head = try box.forceHead() else {
                    current = nil
                    return nil
                }
                current = try box.forceTail()
                return decoded(head)
            }
            catch {
                failure = error
                current = nil
                return nil
            }
        }

        /// Converts an element, ending iteration and recording why if it can't.
        private mutating func decoded(_ expr: Expr) -> T? {
            guard let value = T(swishValue: expr) else {
                failure = SwishConversionError(expected: "\(T.self)", value: expr)
                current = nil
                eager = nil
                return nil
            }
            return value
        }

        private mutating func nextBox() -> LazySeqBox? {
            guard case let .lazySeq(box)? = current else {
                current = nil
                return nil
            }
            return box
        }
    }

    let start: Expr

    public func makeIterator() -> Iterator {
        Iterator(start: start)
    }
}

public extension Expr {
    /// Iterates this value, decoding each element.
    ///
    /// A lazy seq is realized one element at a time, so this is safe on an
    /// infinite one as long as the loop stops; eager collections (vector, list,
    /// seq, …) are iterated directly. Check the iterator's `failure` afterwards,
    /// or prefer `forEach(of:_:)`, which throws instead.
    func lazySequence<T: SwishDecodable>(of type: T.Type = T.self) -> SwishLazySequence<T> {
        SwishLazySequence(start: self)
    }

    /// Calls `body` with each element, decoded.
    ///
    /// The streaming form that can't hide a failure: a realization error or an
    /// element that isn't a `T` throws. `body` can stop early by throwing.
    ///
    /// ```swift
    /// try naturals.forEach(of: Int.self) { n in
    ///     if n > 10 { throw StopIterating() }
    ///     print(n)
    /// }
    /// ```
    func forEach<T: SwishDecodable>(of type: T.Type = T.self, _ body: (T) throws -> Void) throws {
        // A lazy seq is walked one element at a time so an infinite source stays
        // usable; everything else is already realized.
        guard case .lazySeq = self else {
            guard let elements = try SwishKit.asSequence(self) else {
                throw SwishConversionError(expected: "a sequence", value: self)
            }
            for element in elements {
                try body(element.decode(T.self))
            }
            return
        }

        var current = self
        while case let .lazySeq(box) = current {
            guard let head = try box.forceHead() else { return }
            try body(head.decode(T.self))
            current = try box.forceTail()
        }
        // A realized tail can be an ordinary list — finish it eagerly.
        if case .lazySeq = current {
            return
        }
        guard let rest = try SwishKit.asSequence(current) else { return }
        for element in rest {
            try body(element.decode(T.self))
        }
    }

    /// The first `maxLength` elements, decoded.
    ///
    /// The safe way to read a possibly-infinite seq: bounded, strict, and it says
    /// what went wrong. Prefer this to `asArray()` or `[T](swishValue:)`, both of
    /// which realize a lazy seq in full and so never return on an infinite one.
    func prefix<T: SwishDecodable>(_ maxLength: Int, of type: T.Type = T.self) throws -> [T] {
        guard maxLength > 0 else { return [] }
        var result: [T] = []
        result.reserveCapacity(maxLength)

        do {
            try forEach(of: T.self) { element in
                result.append(element)
                if result.count == maxLength {
                    throw PrefixReached()
                }
            }
        }
        catch is PrefixReached {
            // Hit the bound, which is a normal ending here.
        }
        return result
    }
}

/// Thrown by `Expr.prefix(_:of:)` to stop the walk once it has enough elements.
/// A sentinel, never surfaced to callers.
private struct PrefixReached: Error {}
