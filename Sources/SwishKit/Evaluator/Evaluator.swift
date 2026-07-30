import Foundation
import Synchronization

struct RecurSignal: Error {
    let args: [Expr]
}

/// Evaluator for Swish expressions
public class Evaluator {
    let namespacesState = Mutex<[String: Namespace]>([:])

    /// Snapshot of all registered namespaces. Dictionaries are value types
    /// (copy-on-write), so this is a safe, cheap point-in-time copy.
    var namespaces: [String: Namespace] { namespacesState.withLock { $0 } }

    /// Caches `"ns/name" -> Var` resolutions for `resolveQualifiedVar`. Safe with no
    /// invalidation logic: only populated for a *home*-var resolution reached via the
    /// literal-namespace-name branch (never an alias, which is caller-namespace-
    /// dependent), and there is no API anywhere to remove or replace a namespace's
    /// home mapping for a given name — see `resolveQualifiedVar`'s comment for the
    /// full argument.
    let qualifiedVarCache = Mutex<[String: Var]>([:])

    /// Generic `Thread.current.threadDictionary`-backed thread-local, retained only
    /// for the cold-path slots that still use it (`currentTransaction`,
    /// `currentCancellationCheck`, `currentAgentActionSends` — none per-call). The
    /// hot per-call state (`callDepth`/`bindingFrames`) moved off this onto
    /// `EvaluatorThreadState` below: the ObjC `NSMutableDictionary` lookup + `NSString`
    /// key bridge + dynamic cast was too costly to pay on every function call.
    final class ThreadLocalBox<T> {
        var value: T
        init(_ value: T) { self.value = value }
    }

    func threadLocalBox<T>(for key: String, default def: @autoclosure () -> T) -> ThreadLocalBox<T> {
        if let existing = Thread.current.threadDictionary[key] as? ThreadLocalBox<T> {
            return existing
        }
        let box = ThreadLocalBox(def())
        Thread.current.threadDictionary[key] = box
        return box
    }

    // MARK: - Per-thread evaluator state

    /// Per-thread mutable evaluator state: the recursion-depth guard and the
    /// dynamic-binding frame stack. Both must be per-OS-thread, not global — a
    /// future/agent body runs on its own GCD thread, and a shared counter or frame
    /// stack would let two independent logical call-stacks corrupt each other's
    /// depth tracking (falsely tripping, or masking real overflow) or dynamic
    /// bindings. Each instance is owned by exactly one thread and mutated only from
    /// that thread, so its fields need no lock — only the shared `threadStates`
    /// registry (lookup/insert) is synchronized.
    final class EvaluatorThreadState {
        var callDepth: Int = 0
        var bindingFrames: [[ObjectIdentifier: Expr]] = []
    }

    /// Registry of per-thread state, keyed by thread identity. Swift-native
    /// (`Dictionary` + `ObjectIdentifier`), replacing the previous
    /// `Thread.current.threadDictionary` string-keyed store whose ObjC
    /// dictionary lookup + `NSString` key bridge + dynamic cast was paid on every
    /// function call (see NOTES.md, Performance). Process-global, exactly like the
    /// fixed string keys it replaces — shared across `Evaluator` instances on one
    /// thread, which is harmless: `callDepth` is a conservative guard, and
    /// `bindingFrames` is keyed by `Var` identity so a frame from a different
    /// evaluator simply misses. A stale entry lingers for each dead GCD-pool thread;
    /// bounded (the pool is bounded) and harmless (`callDepth` returns to 0 after
    /// each top-level eval, `bindingFrames` empties).
    private let threadStates = Mutex<[ObjectIdentifier: EvaluatorThreadState]>([:])

    /// The calling thread's `EvaluatorThreadState`, creating it on first access.
    /// One `Mutex` acquisition to fetch (or insert) the state object; all further
    /// reads/writes of its fields are lock-free (the object is single-thread-owned).
    func currentThreadState() -> EvaluatorThreadState {
        let id = ObjectIdentifier(Thread.current)
        return threadStates.withLock { states in
            if let existing = states[id] {
                return existing
            }
            let state = EvaluatorThreadState()
            states[id] = state
            return state
        }
    }

    /// Stack of dynamic-binding frames (var identity → current value), pushed/popped
    /// by the `binding` special form. Per-thread — see `EvaluatorThreadState`.
    var bindingFrames: [[ObjectIdentifier: Expr]] {
        get { currentThreadState().bindingFrames }
        set { currentThreadState().bindingFrames = newValue }
    }

    let sourcePaths: [String]

    /// Global uniqueness counter for `gensym`. Stays global (not thread-local,
    /// unlike `bindingFrames`/`callDepth`) since gensym uniqueness must hold even
    /// across concurrent macro-expansion on different threads.
    private let gensymCounterState = Mutex<Int>(0)

    /// Recursion-depth guard, per-thread — see `EvaluatorThreadState`. Hot callers
    /// (`callUserFunction`/`callMacro`) fetch the state once via `currentThreadState()`
    /// and mutate `callDepth` in place, so guarding a call costs a single registry
    /// lookup rather than one per read and one per write.
    var callDepth: Int {
        get { currentThreadState().callDepth }
        set { currentThreadState().callDepth = newValue }
    }
    let maxCallDepth = 1_000
    var interruptionCheck: (() -> Bool)? = nil

    /// The interned `*ns*` Var, cached at init so `currentNs()`/`setCurrentNs(_:)`
    /// reach the current namespace with a single Var-lock access instead of a
    /// namespace-registry lookup + a var-table lookup + the value read — three lock
    /// acquisitions and two string-keyed dictionary hashes — on every call, which
    /// bare-symbol resolution hits for every self-/forward-referenced fn in a hot
    /// loop. Safe to cache: `*ns*` is interned exactly once here at init and its Var
    /// object is never replaced (only its value changes, via `in-ns`/`setCurrentNs`)
    /// — the same immutability that lets `qualifiedVarCache` skip invalidation.
    private(set) var starNsVar: Var!

    public init(sourcePaths: [String] = []) {
        self.sourcePaths = sourcePaths
        // 1. Create clojure.core first — register() interns into it
        let coreNs = Namespace(name: "clojure.core")
        namespacesState.withLock { $0["clojure.core"] = coreNs }

        // 2. Populate clojure.core with all native built-ins
        registerCoreFunctions(into: self)

        // 3. *ns* must exist before loading core.clj (evalNs and evalDefmacro use currentNs())
        let nsVar = coreNs.intern(name: "*ns*", value: .namespace(coreNs))
        nsVar.isSystem = true
        starNsVar = nsVar

        // 4. *print-meta* controls whether metadata is printed with values
        let pmVar = coreNs.intern(name: "*print-meta*", value: .boolean(false))
        pmVar.isSystem = true

        // *print-length* caps how many lazy-seq elements the printer realizes.
        _ = coreNs.intern(name: "*print-length*", value: .integer(1000))

        // 5. Load clojure/core.clj — defines Clojure-level macros (defn, etc.) into clojure.core
        loadCoreLibrary()

        // 6. Create user after core.clj so auto-refer picks up all new definitions
        let userNs = findOrCreateNs("user")
        setCurrentNs(userNs)
    }

    /// Generates a unique symbol with the given prefix
    func gensym(prefix: String = "G__") -> String {
        let n = gensymCounterState.withLock { c -> Int in
            c += 1
            return c
        }
        return "\(prefix)\(n)"
    }

    /// Evaluates a Swish expression
    public func eval(_ expr: Expr) throws -> Expr {
        do {
            return try eval(expr, in: Environment())
        } catch is RecurSignal {
            throw EvaluatorError.recurOutsideLoop
        }
    }

    func eval(_ expr: Expr, in env: Environment) throws -> Expr {
        switch expr {
        case .integer, .float, .double, .ratio, .bigInteger, .bigDecimal,
             .string, .character, .boolean, .nil, .keyword,
             .function, .macro, .multiArityFunction, .multiArityMacro,
             .nativeFunction, .varRef, .namespace, .atom, .transient, .lazySeq, .reduced, .delay, .regex,
             .matcher, .reader, .writer, .record, .deftype, .inst, .uuid, .mapEntry, .array, .sharedVector,
             .agent, .future, .promise, .ref:
            return expr

        case .seq(let elements):
            return try evalList(elements, in: env)

        case .vector(let elements, let vecMeta):
            return .vector(SwishPersistentVector(try elements.map { try eval($0, in: env) }), metadata: vecMeta)

        case .map(let sm):
            var result: [Expr: Expr] = [:]
            for (k, v) in sm.dict {
                result[try eval(k, in: env)] = try eval(v, in: env)
            }
            return .map(result, metadata: sm.metadata)

        case .sortedMap(let ssm):
            let compare = makeComparator(ssm.comparator)
            var result = SwishSortedMap(keys: [], values: [], comparator: ssm.comparator, metadata: ssm.metadata)
            for (k, v) in zip(ssm.keys, ssm.values) {
                result = try result.assoc(eval(k, in: env), eval(v, in: env), compare)
            }
            return .sortedMap(result)

        case .set(let ss):
            var result: Set<Expr> = []
            for element in ss.elements {
                let evaled = try eval(element, in: env)
                let (inserted, _) = result.insert(evaled)
                if !inserted {
                    throw EvaluatorError.duplicateSetElement(Printer().printString(evaled))
                }
            }
            return .set(result, metadata: ss.metadata)

        case .sortedSet(let sss):
            let compare = makeComparator(sss.comparator)
            var result = SwishSortedSet(elements: [], comparator: sss.comparator, metadata: sss.metadata)
            for element in sss.elements {
                result = try result.inserting(eval(element, in: env), compare)
            }
            return .sortedSet(result)

        case .symbol(let name, _):
            if let value = env.get(name) {
                return value
            }
            if let v = try resolveQualifiedVar(name: name) {
                return try deref(v)
            }
            if let v = resolveVar(name: name, in: currentNs()) {
                return try deref(v)
            }
            throw EvaluatorError.undefinedSymbol(name)

        case .list(let elements, _):
            return try evalList(elements.elements, in: env)
        }
    }

    // MARK: - List dispatch

    /// Every symbol handled directly by `evalList`'s switch below, kept in sync
    /// with it by hand. These are never interned as vars (they're intercepted
    /// before any normal symbol lookup when they're the head of a list), so
    /// `resolve`/`when-var-exists` would otherwise incorrectly report them as
    /// absent even though they work correctly — `coreResolve` (`CoreNamespace.swift`)
    /// falls back to this set rather than Swish interning a placeholder var for
    /// each, which would incorrectly make bare-symbol references to these names
    /// (e.g. `(println let)`) silently succeed instead of throwing, and would
    /// pollute namespace introspection with fake "vars" for pure syntax keywords.
    static let specialFormNames: Set<String> = [
        "quote", "syntax-quote", "def", "if", "do", "let", "letfn", "loop", "recur",
        "fn", "defmacro", "var", "ns", "lazy-seq", "delay", "binding", "set!", "throw", "try",
        "defrecord", "deftype", "reify", "extend-type", "extend-protocol",
    ]

    private func evalList(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard let head = elements.first
        else { return .list([], metadata: nil) }

        // Fast path: the overwhelming majority of calls are ordinary function
        // calls, not one of the ~20 special forms below. Reject non-special-form
        // heads with a single Set lookup instead of paying up to 20 sequential
        // string-equality comparisons (Swift doesn't compile a switch over an
        // enum's associated String value to a jump table) before falling through
        // to this exact same path anyway.
        guard case .symbol(let headName, _) = head, Evaluator.specialFormNames.contains(headName) else {
            let callee = try eval(head, in: env)
            return try callFunction(callee, args: elements.dropFirst(), in: env)
        }

        return try evalSpecialForm(head, elements, in: env)
    }

    /// The special-form dispatch switch, deliberately kept in its own function
    /// rather than inlined into `evalList`. This is a stack-depth measure, not
    /// cosmetics: `evalList` recurses deeply in this tree-walking interpreter, and
    /// folding a ~two-dozen-case switch back into it inflates *every* recursive
    /// `evalList` frame — including the ordinary-call frames (the overwhelming
    /// majority) that skip the switch entirely and return in the guard above.
    /// That inflation is enough to overflow the smaller stack of Swift Testing's
    /// runner thread on the most recursion-heavy tests (e.g. multi-namespace
    /// `run-tests`). With the switch here, only actual special forms pay the one
    /// extra frame; ordinary calls never reach it. `headName` was already checked
    /// against `specialFormNames`, so `default` is effectively unreachable for a
    /// symbol head — kept only as the safe ordinary-call fallback.
    private func evalSpecialForm(_ head: Expr, _ elements: [Expr], in env: Environment) throws -> Expr {
        switch head {
        case .symbol("quote", _):
            guard elements.count == 2
            else {
                throw EvaluatorError.invalidArgument(function: "quote",
                                                     message: "requires exactly 1 argument")
            }
            return elements[1]

        case .symbol("syntax-quote", _):
            return try evalSyntaxQuote(elements, in: env)

        case .symbol("def", _):
            return try evalDef(elements, in: env)

        case .symbol("if", _):
            return try evalIf(elements, in: env)

        case .symbol("do", _):
            return try evalBody(Array(elements.dropFirst()), in: env)

        case .symbol("let", _):
            return try evalLet(elements, in: env)

        case .symbol("letfn", _):
            return try evalLetfn(elements, in: env)

        case .symbol("loop", _):
            return try evalLoop(elements, in: env)

        case .symbol("recur", _):
            return try evalRecur(elements, in: env)

        case .symbol("fn", _):
            return try evalFn(elements, in: env)

        case .symbol("defmacro", _):
            return try evalDefmacro(elements)

        case .symbol("var", _):
            return try evalVar(elements, in: env)

        case .symbol("ns", _):
            return try evalNs(elements)

        case .symbol("lazy-seq", _):
            return try evalLazySeq(elements, in: env)

        case .symbol("delay", _):
            return try evalDelay(elements, in: env)

        case .symbol("binding", _):
            return try evalBinding(elements, in: env)

        case .symbol("set!", _):
            return try evalSet(elements, in: env)

        case .symbol("throw", _):
            return try evalThrow(elements, in: env)

        case .symbol("try", _):
            return try evalTry(elements, in: env)

        case .symbol("defrecord", _):
            return try evalDefrecord(elements, in: env)

        case .symbol("deftype", _):
            return try evalDeftype(elements, in: env)

        case .symbol("reify", _):
            return try evalReify(elements, in: env)

        case .symbol("extend-type", _):
            return try evalExtendType(elements, in: env)

        case .symbol("extend-protocol", _):
            return try evalExtendProtocol(elements, in: env)

        default:
            let callee = try eval(head, in: env)
            return try callFunction(callee, args: elements.dropFirst(), in: env)
        }
    }

    /// Returns the current value of a var, checking the binding stack for dynamic vars.
    func dynamicValue(of v: Var) -> Expr? {
        let (isDynamic, value) = v.snapshotIsDynamicAndValue()
        if isDynamic {
            let id = ObjectIdentifier(v)
            for frame in bindingFrames.reversed() {
                if let val = frame[id] { return val }
            }
        }
        return value
    }

    private func deref(_ v: Var) throws -> Expr {
        if let val = dynamicValue(of: v) { return val }
        throw EvaluatorError.unboundVar("\(v.namespace.name)/\(v.name)")
    }

    /// Returns the current value of `*out*`, or `.nil` if unbound (meaning stdout).
    func currentOut() -> Expr {
        guard let v = findNs("clojure.core")?.findVar(name: "*out*") else { return .nil }
        return dynamicValue(of: v) ?? .nil
    }

    func transformMap(_ dict: [Expr: Expr], metadata: [Expr: Expr]? = nil, _ transform: (Expr) throws -> Expr) rethrows -> Expr {
        var result: [Expr: Expr] = [:]
        for (k, v) in dict {
            result[try transform(k)] = try transform(v)
        }
        return .map(result, metadata: metadata)
    }

    func transformSortedMap(_ ssm: SwishSortedMap, _ transform: (Expr) throws -> Expr) rethrows -> Expr {
        // Positional transform: preserves the comparator, metadata, and (assumed
        // order-preserving) sorted layout — used only by structural template
        // transforms (syntax-quote), never on runtime-reordering input.
        let keys = try ssm.keys.map(transform)
        let values = try ssm.values.map(transform)
        return .sortedMap(sortedKeys: keys, sortedValues: values, comparator: ssm.comparator, metadata: ssm.metadata)
    }
}

extension Evaluator: @unchecked Sendable {}
