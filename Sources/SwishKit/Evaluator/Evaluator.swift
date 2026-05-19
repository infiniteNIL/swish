private struct RecurSignal: Error {
    let args: [Expr]
}

/// Evaluator for Swish expressions
public class Evaluator {
    var namespaces: [String: Namespace] = [:]

    private var gensymCounter = 0
    private var callDepth = 0
    private let maxCallDepth = 1_000
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

    private func eval(_ expr: Expr, in env: Environment) throws -> Expr {
        switch expr {
        case .integer, .float, .ratio, .string, .character, .boolean, .nil, .keyword,
             .function, .macro, .multiArityFunction, .multiArityMacro,
             .nativeFunction, .varRef, .namespace:
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
                if case .varRef(let v) = value {
                    return try deref(v)
                }
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

    // MARK: - Special forms

    private func evalVar(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard elements.count == 2, case .symbol(let name, _) = elements[1]
        else {
            throw EvaluatorError.invalidArgument(function: "var",
                message: "requires exactly one symbol argument")
        }
        if let v = try resolveQualifiedVar(name: name) {
            return .varRef(v)
        }
        if let stored = env.get(name), case .varRef = stored {
            return stored
        }
        if let v = resolveVar(name: name, in: currentNs()) {
            return .varRef(v)
        }
        throw EvaluatorError.undefinedSymbol(name)
    }

    private func evalNs(_ elements: [Expr]) throws -> Expr {
        guard elements.count >= 2, case .symbol(let name, _) = elements[1]
        else {
            throw EvaluatorError.invalidArgument(function: "ns",
                message: "requires at least one symbol argument")
        }
        let ns = findOrCreateNs(name)
        setCurrentNs(ns)
        for directive in elements.dropFirst(2) {
            guard case .list(let parts, _) = directive,
                  !parts.isEmpty,
                  case .keyword(let kind) = parts[0]
            else {
                throw EvaluatorError.invalidArgument(function: "ns",
                    message: "expected a directive list like (:require ...)")
            }
            switch kind {
            case "require":
                try processRequireDirective(Array(parts.dropFirst()), caller: "ns")

            default:
                throw EvaluatorError.invalidArgument(function: "ns",
                    message: "unknown directive ':\(kind)'")
            }
        }
        return .nil
    }

    func processRequireDirective(_ specs: [Expr], caller: String = "require") throws {
        for spec in specs {
            switch spec {
            case .symbol(let nsName, _):
                _ = try requireNs(nsName)

            case .vector(let parts, _):
                guard !parts.isEmpty, case .symbol(let nsName, _) = parts[0]
                else {
                    throw EvaluatorError.invalidArgument(function: caller,
                        message: ":require spec must start with a namespace symbol")
                }
                let loadedNs = try requireNs(nsName)
                var i = 1
                while i + 1 < parts.count {
                    guard case .keyword(let key) = parts[i]
                    else {
                        i += 1
                        continue
                    }
                    switch key {
                    case "as":
                        guard case .symbol(let aliasName, _) = parts[i + 1]
                        else {
                            throw EvaluatorError.invalidArgument(function: caller,
                                message: ":as requires a symbol")
                        }
                        try currentNs().alias(name: aliasName, ns: loadedNs)

                    case "refer":
                        switch parts[i + 1] {
                        case .keyword("all"):
                            for (_, v) in loadedNs.mappings where v.namespace === loadedNs {
                                try currentNs().refer(v)
                            }

                        case .vector(let syms, _):
                            let names = syms.compactMap { if case .symbol(let s, _) = $0 { s } else { nil } }
                            for symName in names {
                                guard let v = loadedNs.findVar(name: symName)
                                else {
                                    throw EvaluatorError.undefinedSymbol("\(nsName)/\(symName)")
                                }
                                try currentNs().refer(v)
                            }

                        default:
                            throw EvaluatorError.invalidArgument(function: caller,
                                message: ":refer requires a vector of symbols or :all")
                        }

                    default:
                        break
                    }
                    i += 2
                }

            default:
                throw EvaluatorError.invalidArgument(function: caller,
                    message: ":require spec must be a symbol or vector")
            }
        }
    }

    private func evalSyntaxQuote(_ elements: [Expr], in env: Environment) throws -> Expr {
        var gensyms: [String: String] = [:]
        return try syntaxQuoteExpand(elements[1], in: env, gensyms: &gensyms)
    }

    private func evalDef(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard case .symbol(let name, let symMeta) = elements[1]
        else {
            throw EvaluatorError.undefinedSymbol("def")
        }
        let ns = currentNs()
        if let existing = resolveVar(name: name, in: ns), existing.isSystem {
            throw EvaluatorError.cannotRedefineSystemVar(name)
        }
        let v = ns.intern(name: name)
        if elements.count == 3 {
            v.value = try eval(elements[2], in: env)
        }
        if let m = symMeta {
            v.metadata = m
        }
        return .varRef(v)
    }

    private func evalIf(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard elements.count >= 3
        else {
            throw EvaluatorError.invalidArgument(function: "if",
                message: "requires a condition and a then-branch")
        }
        let condition = try eval(elements[1], in: env)
        let isFalsy = condition == .nil || condition == .boolean(false)
        if !isFalsy {
            return try eval(elements[2], in: env)
        }
        else if elements.count > 3 {
            return try eval(elements[3], in: env)
        }
        else {
            return .nil
        }
    }

    private func evalLet(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard elements.count >= 2, case .vector(let bindingVec, _) = elements[1]
        else {
            throw EvaluatorError.invalidArgument(function: "let",
                message: "first argument must be a vector of bindings")
        }
        let letEnv = Environment(parent: env)
        for i in stride(from: 0, to: bindingVec.count, by: 2) {
            guard case .symbol(let name, _) = bindingVec[i]
            else { continue }
            letEnv.set(name, try eval(bindingVec[i + 1], in: letEnv))
        }
        return try evalBody(Array(elements.dropFirst(2)), in: letEnv)
    }

    private func evalLoop(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard elements.count >= 2, case .vector(let bindingVec, _) = elements[1]
        else {
            throw EvaluatorError.invalidArgument(function: "loop",
                message: "first argument must be a vector of bindings")
        }
        let loopEnv = Environment(parent: env)
        var names: [String] = []
        for i in stride(from: 0, to: bindingVec.count, by: 2) {
            guard case .symbol(let name, _) = bindingVec[i] else { continue }
            names.append(name)
            loopEnv.set(name, try eval(bindingVec[i + 1], in: loopEnv))
        }
        let body = Array(elements.dropFirst(2))
        try validateRecurTailPosition(in: body)
        while true {
            if interruptionCheck?() == true { throw EvaluatorError.interrupted }
            do {
                return try evalBody(body, in: loopEnv)
            } catch let signal as RecurSignal {
                guard signal.args.count == names.count else {
                    throw EvaluatorError.arityMismatch(
                        name: "loop", expected: .fixed(names.count), got: signal.args.count)
                }
                for (name, value) in zip(names, signal.args) {
                    loopEnv.set(name, value)
                }
            }
        }
    }

    private func evalRecur(_ elements: [Expr], in env: Environment) throws -> Expr {
        let args = try elements.dropFirst().map { try eval($0, in: env) }
        throw RecurSignal(args: args)
    }

    private func buildFnArity(from clause: Expr, functionName: String, validateRecur: Bool) throws -> FnArity {
        guard case .list(let elems, _) = clause, !elems.isEmpty,
              case .vector(let paramExprs, _) = elems[0]
        else {
            throw EvaluatorError.invalidArgument(function: functionName, message: "invalid arity clause")
        }
        let params = extractParamNames(paramExprs)
        let rawBody = Array(elems.dropFirst())
        if validateRecur { try validateRecurTailPosition(in: rawBody) }
        return FnArity(params: params, body: expandAliases(in: rawBody, locals: Set(params)))
    }

    // MARK: - Recur tail-position validation

    /// Validates that every `recur` in `body` is in tail position.
    /// Must be called before evalBody so errors surface at definition time.
    private func validateRecurTailPosition(in body: [Expr]) throws {
        try validateTailForms(body)
    }

    private func validateTailForms(_ forms: [Expr]) throws {
        for form in forms.dropLast() {
            if recurAppears(in: form) { throw EvaluatorError.recurNotInTailPosition }
        }
        if let last = forms.last { try validateTailExpr(last) }
    }

    private func validateTailExpr(_ expr: Expr) throws {
        guard case .list(let elements, _) = expr, !elements.isEmpty else {
            if recurAppears(in: expr) { throw EvaluatorError.recurNotInTailPosition }
            return
        }
        switch elements[0] {
        case .symbol("recur", _):
            return  // ✓ recur is the tail call

        case .symbol("if", _):
            // test is not in tail position; both branches are
            if elements.count > 1, recurAppears(in: elements[1]) {
                throw EvaluatorError.recurNotInTailPosition
            }
            if elements.count > 2 { try validateTailExpr(elements[2]) }
            if elements.count > 3 { try validateTailExpr(elements[3]) }

        case .symbol("do", _):
            try validateTailForms(Array(elements.dropFirst()))

        case .symbol("let", _):
            // Binding values are not in tail position
            if elements.count > 1, case .vector(let bindings, _) = elements[1] {
                for i in stride(from: 1, to: bindings.count, by: 2) {
                    if recurAppears(in: bindings[i]) { throw EvaluatorError.recurNotInTailPosition }
                }
            }
            try validateTailForms(Array(elements.dropFirst(2)))

        case .symbol("fn", _), .symbol("loop", _):
            return  // New recur target — stop descending

        case .symbol(let name, _):
            // If this is a known macro, we can't validate post-expansion — allow it
            if let v = resolveVar(name: name, in: currentNs())?.value {
                switch v {
                case .macro, .multiArityMacro: return
                default: break
                }
            }
            // Known function or unresolved symbol — recur in any arg is non-tail
            for element in elements where recurAppears(in: element) {
                throw EvaluatorError.recurNotInTailPosition
            }

        default:
            for element in elements where recurAppears(in: element) {
                throw EvaluatorError.recurNotInTailPosition
            }
        }
    }

    /// Returns true if a `recur` form appears anywhere in `expr`,
    /// not descending into nested `fn` or `loop` forms (they have their own target).
    private func recurAppears(in expr: Expr) -> Bool {
        switch expr {
        case .list(let elements, _):
            guard !elements.isEmpty else { return false }
            if case .symbol("fn", _)    = elements[0] { return false }
            if case .symbol("loop", _)  = elements[0] { return false }
            if case .symbol("recur", _) = elements[0] { return true }
            return elements.contains { recurAppears(in: $0) }
        case .vector(let elements, _):
            return elements.contains { recurAppears(in: $0) }
        case .map(let dict, _):
            return dict.keys.contains { recurAppears(in: $0) }
                || dict.values.contains { recurAppears(in: $0) }
        default:
            return false
        }
    }

    private func evalFn(_ elements: [Expr], in env: Environment) throws -> Expr {
        var offset = 1
        var name: String? = nil
        if elements.count > 2, case .symbol(let n, _) = elements[1] {
            let next = elements[2]
            if case .vector = next { name = n; offset = 2 }
            else if case .list = next { name = n; offset = 2 }
        }
        let remaining = Array(elements.dropFirst(offset))
        if let first = remaining.first, case .list = first {
            let arities = try remaining.map { try buildFnArity(from: $0, functionName: "fn", validateRecur: true) }
            return .multiArityFunction(name: name, arities: arities, capturedEnv: env, metadata: nil)
        }
        guard !remaining.isEmpty, case .vector(let paramExprs, _) = remaining[0] else {
            throw EvaluatorError.invalidArgument(function: "fn", message: "requires a parameter vector")
        }
        let params = extractParamNames(paramExprs)
        let rawBody = Array(remaining.dropFirst())
        try validateRecurTailPosition(in: rawBody)
        let body = expandAliases(in: rawBody, locals: Set(params))
        return .function(name: name, params: params, body: body, capturedEnv: env, metadata: nil)
    }

    private func evalDefmacro(_ elements: [Expr]) throws -> Expr {
        guard elements.count >= 3, case .symbol(let name, let symMeta) = elements[1]
        else {
            throw EvaluatorError.invalidArgument(function: "defmacro", message: "invalid syntax")
        }
        var idx = 2
        var docString: String? = nil
        var attrMap: [Expr: Expr]? = nil
        if idx < elements.count, case .string(let s) = elements[idx] { docString = s; idx += 1 }
        if idx < elements.count, case .map(let m, _) = elements[idx] { attrMap = m; idx += 1 }
        guard idx < elements.count else {
            throw EvaluatorError.invalidArgument(function: "defmacro", message: "invalid syntax")
        }
        var meta: [Expr: Expr] = symMeta ?? [:]
        if let attr = attrMap { for (k, v) in attr { meta[k] = v } }
        if let doc = docString { meta[.keyword("doc")] = .string(doc) }
        let macroMeta: [Expr: Expr]? = meta.isEmpty ? nil : meta
        let macroValue: Expr
        switch elements[idx] {
        case .vector(let paramExprs, _):
            let params = extractParamNames(paramExprs)
            let rawBody = Array(elements.dropFirst(idx + 1))
            macroValue = .macro(name: name, params: params,
                                body: expandAliases(in: rawBody, locals: Set(params)),
                                metadata: macroMeta)
        case .list:
            let arities = try Array(elements.dropFirst(idx)).map {
                try buildFnArity(from: $0, functionName: "defmacro", validateRecur: false)
            }
            macroValue = .multiArityMacro(name: name, arities: arities, metadata: macroMeta)
        default:
            throw EvaluatorError.invalidArgument(function: "defmacro", message: "invalid syntax")
        }
        let v = currentNs().intern(name: name, value: macroValue)
        v.metadata = macroMeta
        return .symbol(name, metadata: nil)
    }

    // MARK: - Function call dispatch

    private func evalArgs(_ args: ArraySlice<Expr>, in env: Environment) throws -> [Expr] {
        try args.map { try eval($0, in: env) }
    }

    private func selectArity(from arities: [FnArity], argCount: Int, name: String) throws -> FnArity {
        for arity in arities where !arity.params.contains("&") {
            if arity.params.count == argCount { return arity }
        }
        for arity in arities {
            if let ampIdx = arity.params.firstIndex(of: "&"), argCount >= ampIdx {
                return arity
            }
        }
        throw EvaluatorError.noMatchingArity(name: name, got: argCount)
    }

    private func callFunction(_ callee: Expr, args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        switch callee {
        case .macro(let name, let params, let body, _):
            return try callMacro(name: name, params: params, body: body, args: args, in: env)

        case .multiArityMacro(let name, let arities, _):
            let chosen = try selectArity(from: arities, argCount: args.count, name: name ?? "macro")
            return try callMacro(name: name, params: chosen.params, body: chosen.body, args: args, in: env)

        case .nativeFunction(let name, let arity, let body):
            return try callNativeFunction(name: name, arity: arity, body: body, args: evalArgs(args, in: env))

        case .function(let name, let params, let body, let capturedEnv, _):
            return try callUserFunction(name: name, params: params, body: body, args: evalArgs(args, in: env), in: capturedEnv ?? env)

        case .multiArityFunction(let name, let arities, let capturedEnv, _):
            let evaluated = try evalArgs(args, in: env)
            let chosen = try selectArity(from: arities, argCount: evaluated.count, name: name ?? "fn")
            return try callUserFunction(name: name, params: chosen.params, body: chosen.body, args: evaluated, in: capturedEnv ?? env)

        case .map(let dict, _):
            return try callMap(dict, args: args, in: env)

        case .keyword(let name):
            return try callKeyword(name, args: args, in: env)

        case .vector(let elements, _):
            return try callVector(elements, args: args, in: env)

        case .set(let elements, _):
            return try callSet(elements, args: args, in: env)

        default:
            throw EvaluatorError.notAFunction(callee)
        }
    }

    private func callMap(_ dict: [Expr: Expr], args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        let evaluated = try args.map { try eval($0, in: env) }
        guard evaluated.count == 1 || evaluated.count == 2
        else {
            throw EvaluatorError.invalidArgument(
                function: "map",
                message: "requires 1 or 2 arguments, got \(evaluated.count)")
        }
        let notFound: Expr = evaluated.count == 2 ? evaluated[1] : .nil
        return dict[evaluated[0]] ?? notFound
    }

    private func callKeyword(_ name: String, args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        let evaluated = try args.map { try eval($0, in: env) }
        guard evaluated.count == 1 || evaluated.count == 2
        else {
            throw EvaluatorError.invalidArgument(
                function: "keyword",
                message: "requires 1 or 2 arguments, got \(evaluated.count)")
        }
        let notFound: Expr = evaluated.count == 2 ? evaluated[1] : .nil
        switch evaluated[0] {
        case .map(let dict, _):
            return dict[.keyword(name)] ?? notFound

        case .nil:
            return notFound

        default:
            return notFound
        }
    }

    private func callVector(_ elements: [Expr], args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        let evaluated = try args.map { try eval($0, in: env) }
        guard evaluated.count == 1
        else {
            throw EvaluatorError.invalidArgument(
                function: "vector",
                message: "requires 1 argument, got \(evaluated.count)")
        }
        guard case .integer(let idx) = evaluated[0]
        else {
            throw EvaluatorError.invalidArgument(
                function: "vector",
                message: "index must be an integer")
        }
        guard idx >= 0, idx < elements.count
        else {
            throw EvaluatorError.invalidArgument(
                function: "vector",
                message: "index \(idx) out of bounds for vector of size \(elements.count)")
        }
        return elements[idx]
    }

    private func callSet(_ set: Set<Expr>, args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        let evaluated = try args.map { try eval($0, in: env) }
        guard evaluated.count == 1
        else {
            throw EvaluatorError.invalidArgument(
                function: "set",
                message: "requires 1 argument, got \(evaluated.count)")
        }
        return set.contains(evaluated[0]) ? evaluated[0] : .nil
    }

    /// Calls an already-evaluated callee with already-evaluated args. Used by HOFs and meta functions.
    /// Does NOT re-evaluate args — use callFunction for unevaluated args.
    func call(_ callee: Expr, args: [Expr]) throws -> Expr {
        switch callee {
        case .nativeFunction(let name, let arity, let body):
            return try callNativeFunction(name: name, arity: arity, body: body, args: args)
        case .function(let name, let params, let body, let capturedEnv, _):
            return try callUserFunction(name: name, params: params, body: body, args: args, in: capturedEnv ?? Environment())
        case .multiArityFunction(let name, let arities, let capturedEnv, _):
            let chosen = try selectArity(from: arities, argCount: args.count, name: name ?? "fn")
            return try callUserFunction(name: name, params: chosen.params, body: chosen.body, args: args, in: capturedEnv ?? Environment())
        case .macro(let name, let params, let body, _):
            return try callMacro(name: name, params: params, body: body, args: args[...], in: Environment())
        case .multiArityMacro(let name, let arities, _):
            let chosen = try selectArity(from: arities, argCount: args.count, name: name ?? "macro")
            return try callMacro(name: name, params: chosen.params, body: chosen.body, args: args[...], in: Environment())
        default:
            throw EvaluatorError.notAFunction(callee)
        }
    }

    private func callMacro(name: String?, params: [String], body: [Expr], args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        guard callDepth < maxCallDepth else {
            throw EvaluatorError.stackOverflow(maxDepth: maxCallDepth)
        }
        callDepth += 1
        defer { callDepth -= 1 }
        let expanded = try expandMacro(name: name ?? "macro", params: params, body: body, args: Array(args))
        return try eval(expanded, in: env)
    }

    private func callNativeFunction(name: String, arity: Arity, body: @Sendable ([Expr]) throws -> Expr, args: [Expr]) throws -> Expr {
        if case .fixed(let n) = arity, args.count != n {
            throw EvaluatorError.arityMismatch(name: name, expected: arity, got: args.count)
        }
        if case .atLeastOne = arity, args.isEmpty {
            throw EvaluatorError.arityMismatch(name: name, expected: arity, got: 0)
        }
        return try body(args)
    }

    private func callUserFunction(name: String?, params: [String], body: [Expr], args: [Expr], in env: Environment) throws -> Expr {
        guard callDepth < maxCallDepth else {
            throw EvaluatorError.stackOverflow(maxDepth: maxCallDepth)
        }
        callDepth += 1
        defer { callDepth -= 1 }
        var currentArgs = args
        while true {
            if interruptionCheck?() == true { throw EvaluatorError.interrupted }
            let fnEnv = Environment(parent: env)
            try bindParams(params, to: currentArgs, in: fnEnv, name: name ?? "fn")
            do {
                return try evalBody(body, in: fnEnv)
            } catch let signal as RecurSignal {
                currentArgs = signal.args
            }
        }
    }

    /// Expands a macro call one step. Returns nil if the form is not a macro call.
    func macroexpand1(_ expr: Expr) throws -> Expr? {
        guard case .list(let elements, _) = expr,
              !elements.isEmpty,
              case .symbol(let name, _) = elements[0]
        else {
            return nil
        }
        guard let value = resolveVar(name: name, in: currentNs())?.value else {
            return nil
        }
        let args = Array(elements.dropFirst())
        switch value {
        case .macro(_, let params, let body, _):
            return try expandMacro(name: name, params: params, body: body, args: args)
        case .multiArityMacro(_, let arities, _):
            let chosen = try selectArity(from: arities, argCount: args.count, name: name)
            return try expandMacro(name: name, params: chosen.params, body: chosen.body, args: args)
        default:
            return nil
        }
    }

    private func expandMacro(name: String, params: [String], body: [Expr], args: [Expr]) throws -> Expr {
        let macroEnv = Environment()
        try bindParams(params, to: args, in: macroEnv, name: name)
        return try evalBody(body, in: macroEnv)
    }

    private func evalBody(_ forms: [Expr], in env: Environment) throws -> Expr {
        var result: Expr = .nil
        for form in forms {
            result = try eval(form, in: env)
        }
        return result
    }

    /// Binds params to args in the given environment, supporting variadic & rest params.
    private func bindParams(_ params: [String], to args: [Expr], in env: Environment, name: String) throws {
        if let ampIdx = params.firstIndex(of: "&") {
            let fixedParams = Array(params[..<ampIdx])
            let restParam = params[ampIdx + 1]
            guard args.count >= fixedParams.count
            else {
                throw EvaluatorError.arityMismatch(
                    name: name, expected: .fixed(fixedParams.count), got: args.count)
            }
            for (param, arg) in zip(fixedParams, args) {
                env.set(param, arg)
            }
            env.set(restParam, .list(Array(args.dropFirst(fixedParams.count)), metadata: nil))
        }
        else {
            guard args.count == params.count
            else {
                throw EvaluatorError.arityMismatch(
                    name: name, expected: .fixed(params.count), got: args.count)
            }
            for (param, arg) in zip(params, args) {
                env.set(param, arg)
            }
        }
    }

    /// Recursively expands a syntax-quote template, substituting (unquote ...) and
    /// splicing (unquote-splicing ...) sub-forms. Auto-gensyms symbols ending in #.
    private func syntaxQuoteExpand(_ expr: Expr, in env: Environment, gensyms: inout [String: String]) throws -> Expr {
        switch expr {
        case .symbol(let name, _) where name.hasSuffix("#"):
            let base = String(name.dropLast()) + "__"
            let generated = gensyms[name] ?? gensym(prefix: base)
            gensyms[name] = generated
            return .symbol(generated, metadata: nil)

        case .list(let elements, let listMeta):
            if case .symbol("unquote", _) = elements.first {
                return try eval(elements[1], in: env)
            }
            var result: [Expr] = []
            for element in elements {
                if case .list(let sub, _) = element,
                   case .symbol("unquote-splicing", _) = sub.first {
                    let spliced = try eval(sub[1], in: env)
                    guard case .list(let splicedElements, _) = spliced
                    else {
                        throw EvaluatorError.invalidArgument(
                            function: "unquote-splicing",
                            message: "value must be a list")
                    }
                    result.append(contentsOf: splicedElements)
                }
                else {
                    result.append(try syntaxQuoteExpand(element, in: env, gensyms: &gensyms))
                }
            }
            return .list(result, metadata: listMeta)

        case .vector(let elements, let vecMeta):
            return .vector(try elements.map { try syntaxQuoteExpand($0, in: env, gensyms: &gensyms) }, metadata: vecMeta)

        case .map(let dict, let mapMeta):
            return try transformMap(dict, metadata: mapMeta) { try syntaxQuoteExpand($0, in: env, gensyms: &gensyms) }

        case .set(let elements, let setMeta):
            var result: Set<Expr> = []
            for element in elements {
                result.insert(try syntaxQuoteExpand(element, in: env, gensyms: &gensyms))
            }
            return .set(result, metadata: setMeta)

        default:
            return expr
        }
    }

    private func transformMap(_ dict: [Expr: Expr], metadata: [Expr: Expr]? = nil, _ transform: (Expr) throws -> Expr) rethrows -> Expr {
        var result: [Expr: Expr] = [:]
        for (k, v) in dict {
            result[try transform(k)] = try transform(v)
        }
        return .map(result, metadata: metadata)
    }

    private func extractParamNames(_ exprs: [Expr]) -> [String] {
        exprs.compactMap {
            if case .symbol(let s, _) = $0 {
                return s
            }
            else {
                return nil
            }
        }
    }

    // MARK: - Alias expansion

    private func expandAliases(in forms: [Expr], locals: Set<String> = []) -> [Expr] {
        forms.map { expandAliasesInExpr($0, locals: locals) }
    }

    private func expandAliasesInExpr(_ expr: Expr, locals: Set<String> = []) -> Expr {
        switch expr {
        case .symbol(let name, let symMeta):
            if locals.contains(name) { return expr }
            if let (nsAlias, varName) = splitQualified(name),
               let ns = currentNs().findAlias(nsAlias) {
                return .symbol("\(ns.name)/\(varName)", metadata: symMeta)
            }
            if !name.contains("/"), let v = resolveVar(name: name, in: currentNs()) {
                return .symbol("\(v.namespace.name)/\(v.name)", metadata: symMeta)
            }
            return expr

        case .list(let elements, let listMeta):
            guard let head = elements.first
            else { return expr }
            if case .symbol("quote", _) = head { return expr }
            if case .symbol("syntax-quote", _) = head { return expr }
            if case .symbol("fn", _) = head { return expandFnForm(elements, outerLocals: locals, listMeta: listMeta) }
            if case .symbol("let", _) = head { return expandLetForm(elements, outerLocals: locals, listMeta: listMeta) }
            return .list(elements.map { expandAliasesInExpr($0, locals: locals) }, metadata: listMeta)

        case .vector(let elements, let vecMeta):
            return .vector(elements.map { expandAliasesInExpr($0, locals: locals) }, metadata: vecMeta)

        case .map(let dict, let mapMeta):
            return transformMap(dict, metadata: mapMeta) { expandAliasesInExpr($0, locals: locals) }

        case .set(let elements, let setMeta):
            var result: Set<Expr> = []
            for element in elements {
                result.insert(expandAliasesInExpr(element, locals: locals))
            }
            return .set(result, metadata: setMeta)

        default:
            return expr
        }
    }

    private func expandFnForm(_ elements: [Expr], outerLocals: Set<String>, listMeta: [Expr: Expr]? = nil) -> Expr {
        var offset = 1
        if elements.count > 2, case .symbol = elements[1] {
            let next = elements[2]
            if case .vector = next { offset = 2 }
            else if case .list = next { offset = 2 }
        }
        if offset < elements.count, case .list = elements[offset] {
            var result = Array(elements.prefix(offset))
            for clause in elements.dropFirst(offset) {
                guard case .list(let clauseElems, let clauseMeta) = clause,
                      !clauseElems.isEmpty,
                      case .vector(let paramExprs, _) = clauseElems[0]
                else { result.append(clause); continue }
                var clauseLocals = outerLocals
                clauseLocals.formUnion(extractParamNames(paramExprs))
                let expandedBody = Array(clauseElems.dropFirst()).map { expandAliasesInExpr($0, locals: clauseLocals) }
                result.append(.list([clauseElems[0]] + expandedBody, metadata: clauseMeta))
            }
            return .list(result, metadata: listMeta)
        }
        var newLocals = outerLocals
        if offset < elements.count, case .vector(let paramExprs, _) = elements[offset] {
            newLocals.formUnion(extractParamNames(paramExprs))
        }
        var result = Array(elements.prefix(offset + 1))
        result += Array(elements.dropFirst(offset + 1)).map { expandAliasesInExpr($0, locals: newLocals) }
        return .list(result, metadata: listMeta)
    }

    private func expandLetForm(_ elements: [Expr], outerLocals: Set<String>, listMeta: [Expr: Expr]? = nil) -> Expr {
        guard elements.count >= 2, case .vector(let bindings, let bindVecMeta) = elements[1]
        else {
            return .list(elements.map { expandAliasesInExpr($0, locals: outerLocals) }, metadata: listMeta)
        }
        var newLocals = outerLocals
        var newBindings: [Expr] = []
        var i = 0
        while i + 1 < bindings.count {
            newBindings.append(bindings[i])
            newBindings.append(expandAliasesInExpr(bindings[i + 1], locals: newLocals))
            if case .symbol(let n, _) = bindings[i] { newLocals.insert(n) }
            i += 2
        }
        let body = Array(elements.dropFirst(2)).map { expandAliasesInExpr($0, locals: newLocals) }
        return .list([elements[0], .vector(newBindings, metadata: bindVecMeta)] + body, metadata: listMeta)
    }
}

extension Evaluator: @unchecked Sendable {}
