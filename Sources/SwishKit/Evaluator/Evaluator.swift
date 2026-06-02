struct RecurSignal: Error {
    let args: [Expr]
}

/// Evaluator for Swish expressions
public class Evaluator {
    var namespaces: [String: Namespace] = [:]

    private var gensymCounter = 0
    var callDepth = 0
    let maxCallDepth = 1_000
    var interruptionCheck: (() -> Bool)? = nil

    public init() {
        // 1. Create clojure.core first — register() interns into it
        let coreNs = Namespace(name: "clojure.core")
        namespaces["clojure.core"] = coreNs

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
        gensymCounter += 1
        return "\(prefix)\(gensymCounter)"
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
        case .integer, .float, .ratio, .string, .character, .boolean, .nil, .keyword,
             .function, .macro, .multiArityFunction, .multiArityMacro,
             .nativeFunction, .varRef, .namespace, .atom, .transient, .lazySeq, .reduced:
            return expr

        case .vector(let elements, let vecMeta):
            return .vector(try elements.map { try eval($0, in: env) }, metadata: vecMeta)

        case .map(let dict, let mapMeta):
            return try transformMap(dict, metadata: mapMeta) { try eval($0, in: env) }

        case .set(let elements, let setMeta):
            var result: Set<Expr> = []
            for element in elements {
                let evaled = try eval(element, in: env)
                let (inserted, _) = result.insert(evaled)
                if !inserted {
                    throw EvaluatorError.duplicateSetElement(Printer().printString(evaled))
                }
            }
            return .set(result, metadata: setMeta)

        case .symbol(let name, _):
            if let v = try resolveQualifiedVar(name: name) {
                return try deref(v)
            }
            if let value = env.get(name) {
                return value
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

        case .symbol("throw", _):
            return try evalThrow(elements, in: env)

        case .symbol("try", _):
            return try evalTry(elements, in: env)

        default:
            let callee = try eval(head, in: env)
            return try callFunction(callee, args: elements.dropFirst(), in: env)
        }
    }

    private func deref(_ v: Var) throws -> Expr {
        guard let bound = v.value
        else {
            throw EvaluatorError.unboundVar("\(v.namespace.name)/\(v.name)")
        }
        return bound
    }

    func transformMap(_ dict: [Expr: Expr], metadata: [Expr: Expr]? = nil, _ transform: (Expr) throws -> Expr) rethrows -> Expr {
        var result: [Expr: Expr] = [:]
        for (k, v) in dict {
            result[try transform(k)] = try transform(v)
        }
        return .map(result, metadata: metadata)
    }
}

extension Evaluator: @unchecked Sendable {}
