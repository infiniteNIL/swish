import Foundation
import BigInt
import BigDecimal
import Synchronization

/// Specifies how many arguments a function accepts
public enum Arity: Equatable, Hashable, Sendable {
    case fixed(Int)    // exactly N arguments
    case atLeastOne    // 1 or more arguments
    case variadic      // zero or more arguments
}

/// A single arity clause for a multi-arity function or macro.
public struct FnArity: Sendable, Equatable, Hashable {
    public let params: [String]
    public let body: [Expr]
}

// Deliberately left unsynchronized (thread-safety retrofit non-goal, not an
// oversight): transients mirror real Clojure's, which are documented as
// explicitly not thread-safe — single-owner-by-convention, scoped to one
// `transient`/`assoc!`/`dissoc!`/`conj!`/`persistent!` chain.
public final class TransientCollection: @unchecked Sendable {
    public var value: Expr
    public var isInvalidated: Bool = false
    public init(_ value: Expr) { self.value = value }
}

/// Mutable reference-type backing for Java-style arrays.
/// Shared between a `.array` and any `.sharedVector` produced by `(vec arr)`.
public final class SwishArray: @unchecked Sendable {
    private let state: Mutex<[Expr]>

    public var elements: [Expr] {
        get { state.withLock { $0 } }
        set { state.withLock { $0 = newValue } }
    }

    public init(_ elements: [Expr]) { state = Mutex(elements) }

    /// Atomically sets the element at `index`. Use instead of `elements[index] = value`,
    /// which would race under concurrent index-writes (locked read-copy-mutate-locked write).
    func set(at index: Int, to value: Expr) {
        state.withLock { $0[index] = value }
    }
}


/// AST node types for Swish expressions
public indirect enum Expr: Sendable {
    case integer(Int)
    case float(Float)
    case double(Double)
    case ratio(Ratio)
    case bigInteger(BigInt)
    case bigDecimal(BigDecimal)
    case string(String)
    case character(Character)
    case boolean(Bool)
    case `nil`
    case symbol(String, metadata: [Expr: Expr]?)
    case keyword(String)
    case list(SwishPersistentList, metadata: [Expr: Expr]?)
    /// An eager, non-list seq — returned by `seq` on non-list collections (vector, map, set, etc.).
    /// Satisfies `seq?` but not `list?` or `lazy-seq?`, matching Clojure's ISeq-not-IPersistentList.
    case seq([Expr])
    /// A Java-style object array: seqable but not sequential or associative.
    /// Uses reference semantics so `aset` mutations are visible through all aliases.
    case array(SwishArray)
    case vector([Expr], metadata: [Expr: Expr]?)
    /// A persistent-vector view over a `SwishArray`. Produced by `(vec arr)`.
    /// Sequential and vector?=true; shares mutable storage with the source array.
    case sharedVector(SwishArray, metadata: [Expr: Expr]?)
    /// A key-value pair from map iteration. Semantically equivalent to a 2-element vector.
    case mapEntry(Expr, Expr)
    case map(SwishMap)
    case set(SwishSet)
    case sortedSet([Expr], metadata: [Expr: Expr]?)
    case sortedMap([Expr: Expr], metadata: [Expr: Expr]?)
    case function(SwishFunction)
    case macro(name: String?, params: [String], body: [Expr], metadata: [Expr: Expr]?)
    case multiArityFunction(SwishMultiArityFunction)
    case multiArityMacro(name: String?, arities: [FnArity], metadata: [Expr: Expr]?)
    case nativeFunction(name: String, arity: Arity, body: @Sendable ([Expr]) throws -> Expr)
    case varRef(Var)
    case namespace(Namespace)
    case atom(SwishAtom)
    case transient(TransientCollection)
    /// A thunk-backed lazy sequence. Realizes elements on demand.
    case lazySeq(LazySeqBox)

    /// A sentinel wrapping a value to signal early termination of `reduce`.
    case reduced(Expr)

    /// A memoized thunk created by `delay`. Forces on first `deref`/`force`.
    case delay(DelayBox)

    /// A thread-safe mutable reference to a value, updated asynchronously by
    /// serially-dispatched actions submitted via `send`/`await`.
    case agent(SwishAgent)

    /// A background computation created by `future`/`future-call`. `deref` blocks
    /// until realized.
    case future(FutureBox)

    /// A single-slot, deliver-once synchronization primitive created by `promise`.
    /// `deref` blocks until `deliver`ed. Calling it as a function is equivalent to
    /// `deliver`.
    case promise(PromiseBox)

    /// A transactional mutable reference created by `ref`. Mutated only within a
    /// `dosync` transaction via `ref-set`/`alter`/`commute`.
    case ref(SwishRef)

    /// A compiled regular expression literal (`#"pattern"`).
    case regex(SwishRegex)

    /// A buffered file reader, usable with `line-seq` and `with-open`.
    case reader(SwishReader)

    /// A buffered file writer, usable with `swish-write!` and `with-open`.
    case writer(SwishWriter)

    /// A date value from a `#inst` tagged literal.
    case inst(Date)

    /// A UUID value from a `#uuid` tagged literal.
    case uuid(UUID)

    /// A map-backed record created by `defrecord`.
    /// `typeName` is namespace-qualified (e.g. `"user/Point"`).
    /// `fields` lists the declared field names in order.
    /// `data` holds the current key→value pairs (always includes all declared fields).
    case record(typeName: String, fields: [String], data: [Expr: Expr], metadata: [Expr: Expr]?)

    /// A minimal instance created by `deftype`. Structurally parallel to `.record`,
    /// but deliberately given none of `.record`'s map-like integration (no `get`/
    /// `assoc`/`seq`/callable-as-fn) — matching real Clojure's "deftype provides no
    /// functionality not specified by the user, other than a constructor."
    /// `typeName` is namespace-qualified (e.g. `"user/Point"`).
    case deftype(typeName: String, fields: [String], data: [Expr: Expr], metadata: [Expr: Expr]?)
}

// MARK: - Convenience constructors

extension Expr {
    public static func set(_ elements: Set<Expr>, metadata: [Expr: Expr]?) -> Expr {
        .set(SwishSet(elements: elements, metadata: metadata))
    }

    public static func map(_ dict: [Expr: Expr], metadata: [Expr: Expr]?) -> Expr {
        .map(SwishMap(dict: dict, metadata: metadata))
    }
}

