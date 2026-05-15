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
        try eval(expr, in: Environment())
    }

    private func eval(_ expr: Expr, in env: Environment) throws -> Expr {
        switch expr {
        case .integer, .float, .ratio, .string, .character, .boolean, .nil, .keyword, .function, .macro, .nativeFunction, .varRef, .namespace:
            return expr

        case .vector(let elements, let vecMeta):
            return .vector(try elements.map { try eval($0, in: env) }, metadata: vecMeta)

        case .map(let dict, let mapMeta):
            return try transformMap(dict, metadata: mapMeta) { try eval($0, in: env) }

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

    private func evalFn(_ elements: [Expr], in env: Environment) throws -> Expr {
        var offset = 1
        var name: String? = nil
        if elements.count > 1, case .symbol(let n, _) = elements[1],
           elements.count > 2, case .vector = elements[2] {
            name = n
            offset = 2
        }
        guard elements.count > offset, case .vector(let paramExprs, _) = elements[offset]
        else {
            throw EvaluatorError.invalidArgument(function: "fn", message: "requires a parameter vector")
        }
        let params = extractParamNames(paramExprs)
        let body = expandAliases(in: Array(elements.dropFirst(offset + 1)), locals: Set(params))
        return .function(name: name, params: params, body: body, metadata: nil)
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
        guard idx < elements.count, case .vector(let paramExprs, _) = elements[idx]
        else {
            throw EvaluatorError.invalidArgument(function: "defmacro", message: "invalid syntax")
        }
        let vectorIdx = idx
        var meta: [Expr: Expr] = symMeta ?? [:]
        if let attr = attrMap { for (k, v) in attr { meta[k] = v } }
        if let doc = docString { meta[.keyword("doc")] = .string(doc) }
        let macroMeta: [Expr: Expr]? = meta.isEmpty ? nil : meta
        let params = extractParamNames(paramExprs)
        let body = expandAliases(in: Array(elements.dropFirst(vectorIdx + 1)))
        let v = currentNs().intern(name: name, value: .macro(name: name, params: params, body: body, metadata: macroMeta))
        v.metadata = macroMeta
        return .symbol(name, metadata: nil)
    }

    // MARK: - Function call dispatch

    private func callFunction(_ callee: Expr, args: ArraySlice<Expr>, in env: Environment) throws -> Expr {
        switch callee {
        case .macro(let name, let params, let body, _):
            return try callMacro(name: name, params: params, body: body, args: args, in: env)

        case .nativeFunction(let name, let arity, let body):
            let evaluated = try args.map { try eval($0, in: env) }
            return try callNativeFunction(name: name, arity: arity, body: body, args: evaluated)

        case .function(let name, let params, let body, _):
            let evaluated = try args.map { try eval($0, in: env) }
            return try callUserFunction(name: name, params: params, body: body, args: evaluated, in: env)

        case .map(let dict, _):
            let evaluated = try args.map { try eval($0, in: env) }
            guard evaluated.count == 1 || evaluated.count == 2
            else {
                throw EvaluatorError.invalidArgument(
                    function: "map",
                    message: "requires 1 or 2 arguments, got \(evaluated.count)")
            }
            let notFound: Expr = evaluated.count == 2 ? evaluated[1] : .nil
            return dict[evaluated[0]] ?? notFound

        case .keyword(let name):
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

        default:
            throw EvaluatorError.notAFunction(callee)
        }
    }

    /// Calls an already-evaluated callee with already-evaluated args. Used by meta functions.
    func call(_ callee: Expr, args: [Expr]) throws -> Expr {
        try callFunction(callee, args: args[...], in: Environment())
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
        if interruptionCheck?() == true {
            throw EvaluatorError.interrupted
        }
        callDepth += 1
        defer { callDepth -= 1 }
        let fnEnv = Environment(parent: env)
        try bindParams(params, to: args, in: fnEnv, name: name ?? "fn")
        return try evalBody(body, in: fnEnv)
    }

    /// Expands a macro call one step. Returns nil if the form is not a macro call.
    func macroexpand1(_ expr: Expr) throws -> Expr? {
        guard case .list(let elements, _) = expr,
              !elements.isEmpty,
              case .symbol(let name, _) = elements[0]
        else {
            return nil
        }
        guard let value = resolveVar(name: name, in: currentNs())?.value,
              case .macro(_, let params, let body, _) = value
        else {
            return nil
        }
        return try expandMacro(name: name, params: params, body: body, args: Array(elements.dropFirst()))
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

        default:
            return expr
        }
    }

    private func expandFnForm(_ elements: [Expr], outerLocals: Set<String>, listMeta: [Expr: Expr]? = nil) -> Expr {
        var offset = 1
        if elements.count > 2, case .symbol = elements[1], case .vector = elements[2] {
            offset = 2
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
