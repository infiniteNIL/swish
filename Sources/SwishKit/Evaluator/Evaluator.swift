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

    final class ThreadLocalBox<T> {
        var value: T
        init(_ value: T) { self.value = value }
    }
    private static let bindingFramesKey = "swish.evaluator.bindingFrames"
    private static let callDepthKey = "swish.evaluator.callDepth"

    func threadLocalBox<T>(for key: String, default def: @autoclosure () -> T) -> ThreadLocalBox<T> {
        if let existing = Thread.current.threadDictionary[key] as? ThreadLocalBox<T> {
            return existing
        }
        let box = ThreadLocalBox(def())
        Thread.current.threadDictionary[key] = box
        return box
    }

    /// Stack of dynamic-binding frames. Each frame maps var identity → current value.
    /// Pushed/popped by the `binding` special form. Thread-local (via
    /// `Thread.current.threadDictionary`): each real OS thread gets its own stack, so
    /// independent logical call-stacks (e.g. separate agent/future executions once a
    /// later step adds real background execution) can't corrupt each other's dynamic
    /// bindings. A lock alone wouldn't be correct here — it would prevent memory
    /// corruption but not the logical-correctness problem of two unrelated call
    /// stacks sharing one frame stack. Today, with only one thread ever running,
    /// this always resolves to the same bucket it always did — no behavior change.
    var bindingFrames: [[ObjectIdentifier: Expr]] {
        get { threadLocalBox(for: Self.bindingFramesKey, default: [[ObjectIdentifier: Expr]]()).value }
        set { threadLocalBox(for: Self.bindingFramesKey, default: [[ObjectIdentifier: Expr]]()).value = newValue }
    }

    let sourcePaths: [String]

    /// Global uniqueness counter for `gensym`. Stays global (not thread-local,
    /// unlike `bindingFrames`/`callDepth`) since gensym uniqueness must hold even
    /// across concurrent macro-expansion on different threads.
    private let gensymCounterState = Mutex<Int>(0)

    /// Recursion-depth guard, thread-local for the same reason as `bindingFrames`:
    /// a shared counter would let two threads' independent call-stacks corrupt each
    /// other's depth tracking (falsely tripping, or masking real overflow).
    var callDepth: Int {
        get { threadLocalBox(for: Self.callDepthKey, default: 0).value }
        set { threadLocalBox(for: Self.callDepthKey, default: 0).value = newValue }
    }
    let maxCallDepth = 1_000
    var interruptionCheck: (() -> Bool)? = nil

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
             .reader, .writer, .record, .inst, .uuid, .mapEntry, .array, .sharedVector,
             .agent, .future, .promise:
            return expr

        case .seq(let elements):
            return try evalList(elements, in: env)

        case .vector(let elements, let vecMeta):
            return .vector(try elements.map { try eval($0, in: env) }, metadata: vecMeta)

        case .map(let sm):
            var result: [Expr: Expr] = [:]
            for (k, v) in sm.dict {
                result[try eval(k, in: env)] = try eval(v, in: env)
            }
            return .map(result, metadata: sm.metadata)

        case .sortedMap(let dict, let mapMeta):
            var result: [Expr: Expr] = [:]
            for (k, v) in dict {
                result[try eval(k, in: env)] = try eval(v, in: env)
            }
            return .sortedMap(result, metadata: mapMeta)

        case .set(let ss):
            var result: Set<Expr> = []
            for element in ss.elements {
                let evaled = try eval(element, in: env)
                let (inserted, _) = result.insert(evaled)
                if !inserted {
                    throw EvaluatorError.duplicateSetElement(Printer().printString(evaled))
                }
            }
            return .set(SwishSet(elements: result, metadata: ss.metadata))

        case .sortedSet(let elements, let setMeta):
            var result: [Expr] = []
            for element in elements {
                result = try sortedSetInsert(result, eval(element, in: env))
            }
            return .sortedSet(result, metadata: setMeta)

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
            return try evalList(elements, in: env)
        }
    }

    // MARK: - List dispatch

    private func evalList(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard let head = elements.first
        else { return .list([], metadata: nil) }
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

        case .symbol("throw", _):
            return try evalThrow(elements, in: env)

        case .symbol("try", _):
            return try evalTry(elements, in: env)

        case .symbol("defrecord", _):
            return try evalDefrecord(elements, in: env)

        default:
            let callee = try eval(head, in: env)
            return try callFunction(callee, args: elements.dropFirst(), in: env)
        }
    }

    /// Returns the current value of a var, checking the binding stack for dynamic vars.
    func dynamicValue(of v: Var) -> Expr? {
        if v.isDynamic {
            let id = ObjectIdentifier(v)
            for frame in bindingFrames.reversed() {
                if let val = frame[id] { return val }
            }
        }
        return v.value
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

    func transformSortedMap(_ dict: [Expr: Expr], metadata: [Expr: Expr]? = nil, _ transform: (Expr) throws -> Expr) rethrows -> Expr {
        var result: [Expr: Expr] = [:]
        for (k, v) in dict {
            result[try transform(k)] = try transform(v)
        }
        return .sortedMap(result, metadata: metadata)
    }
}

extension Evaluator: @unchecked Sendable {}
