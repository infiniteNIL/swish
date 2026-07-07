private struct CatchClause {
    let typeName: String
    let bindingName: String
    let body: [Expr]
}

extension Evaluator {

    // MARK: - Special forms

    private func buildMeta(from symMeta: [Expr: Expr]?, attrMap: [Expr: Expr]?, docString: String?) -> [Expr: Expr] {
        var meta: [Expr: Expr] = symMeta ?? [:]
        if let attr = attrMap { for (k, v) in attr { meta[k] = v } }
        if let doc = docString { meta[.keyword("doc")] = .string(doc) }
        return meta
    }

    private func requireBindingVector(_ elements: [Expr], function: String, message: String) throws -> [Expr] {
        guard elements.count >= 2, case .vector(let vec, _) = elements[1] else {
            throw EvaluatorError.invalidArgument(function: function, message: message)
        }
        return vec
    }

    private func extractDocAndAttr(_ elements: [Expr], startingAt idx: Int) -> (doc: String?, attrs: [Expr: Expr]?, nextIdx: Int) {
        var i = idx
        var doc: String? = nil
        var attrs: [Expr: Expr]? = nil
        if i < elements.count, case .string(let s) = elements[i] { doc = s; i += 1 }
        if i < elements.count, case .map(let sm) = elements[i] { attrs = sm.dict; i += 1 }
        return (doc, attrs, i)
    }

    /// `(delay body...)` — special form.
    ///
    /// Captures the body and current lexical environment. Returns a `.delay`
    /// immediately without evaluating the body. The body is evaluated at most
    /// once on first `deref`/`force`, and the result is memoized.
    func evalDelay(_ elements: [Expr], in env: Environment) throws -> Expr {
        let body = Array(elements.dropFirst())
        let capturedEnv = env
        let box = DelayBox { [self] in
            try self.evalBody(body, in: capturedEnv)
        }
        return .delay(box)
    }

    /// `(lazy-seq body...)` — special form.
    ///
    /// Captures the body and the current lexical environment inside a thunk.
    /// Returns a `.lazySeq` immediately without evaluating the body. The body
    /// is evaluated at most once, on first demand, and must return a seq or nil.
    func evalLazySeq(_ elements: [Expr], in env: Environment) throws -> Expr {
        let body = Array(elements.dropFirst())
        let capturedEnv = env
        let box = LazySeqBox { [self] in
            let result = try self.evalBody(body, in: capturedEnv)
            switch result {
            case .nil:
                return .nil

            case .list(let e, _) where e.isEmpty:
                return .nil

            default:
                return result
            }
        }
        return .lazySeq(box)
    }

    func evalVar(_ elements: [Expr], in env: Environment) throws -> Expr {
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

    func evalNs(_ elements: [Expr]) throws -> Expr {
        guard elements.count >= 2, case .symbol(let name, let symMeta) = elements[1]
        else {
            throw EvaluatorError.invalidArgument(function: "ns",
                message: "requires at least one symbol argument")
        }
        let (docString, attrMap, idx) = extractDocAndAttr(elements, startingAt: 2)
        let meta = buildMeta(from: symMeta, attrMap: attrMap, docString: docString)

        let ns = findOrCreateNs(name)
        setCurrentNs(ns)
        ns.metadata = meta.isEmpty ? nil : meta

        for directive in elements.dropFirst(idx) {
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
            if caller == "ns" {
                do {
                    try processOneRequireSpec(spec, caller: caller)
                }
                catch {
                    print("Warning: require spec failed: \(error)")
                }
            }
            else {
                try processOneRequireSpec(spec, caller: caller)
            }
        }
    }

    private func processOneRequireSpec(_ spec: Expr, caller: String) throws {
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

    func evalSyntaxQuote(_ elements: [Expr], in env: Environment) throws -> Expr {
        var gensyms: [String: String] = [:]
        return try syntaxQuoteExpand(elements[1], in: env, gensyms: &gensyms)
    }

    func evalDef(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard elements.count >= 2, case .symbol(let name, let symMeta) = elements[1]
        else {
            throw EvaluatorError.undefinedSymbol("def")
        }
        let ns = currentNs()
        if let existing = resolveVar(name: name, in: ns), existing.isSystem {
            throw EvaluatorError.cannotRedefineSystemVar(name)
        }
        var idx = 2
        var docString: String? = nil
        if idx < elements.count, case .string(let s) = elements[idx] {
            docString = s
            idx += 1
        }
        guard idx >= elements.count - 1 else {
            throw EvaluatorError.invalidArgument(function: "def", message: "too many arguments")
        }
        let v = ns.intern(name: name)
        if idx < elements.count {
            v.value = try eval(elements[idx], in: env)
        }
        if case .boolean(true) = symMeta?[.keyword("dynamic")] {
            v.isDynamic = true
        }
        if symMeta != nil || docString != nil {
            // Evaluate metadata values that are (fn ...) forms (e.g. :test metadata in deftest).
            // All other metadata values — keywords, strings, booleans, arglists vectors — are left as-is.
            var evaluatedMeta = symMeta
            if var m = symMeta {
                for (k, val) in m {
                    if case .list(let elems, _) = val,
                       case .symbol(let head, _) = elems.first,
                       head == "fn" || head == "fn*" {
                        m[k] = try eval(val, in: env)
                    }
                }
                evaluatedMeta = m
            }
            v.metadata = buildMeta(from: evaluatedMeta, attrMap: nil, docString: docString)
        }
        return .varRef(v)
    }

    func evalIf(_ elements: [Expr], in env: Environment) throws -> Expr {
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

    func evalBinding(_ elements: [Expr], in env: Environment) throws -> Expr {
        let bindingVec = try requireBindingVector(elements, function: "binding",
            message: "requires a vector of var/value pairs")
        guard bindingVec.count % 2 == 0
        else {
            throw EvaluatorError.invalidArgument(function: "binding",
                message: "requires an even number of forms in binding vector")
        }
        var frame: [ObjectIdentifier: Expr] = [:]
        var i = 0
        while i < bindingVec.count {
            guard case .symbol(let name, _) = bindingVec[i]
            else {
                throw EvaluatorError.invalidArgument(function: "binding",
                    message: "binding target must be a symbol")
            }
            let v: Var
            if let qualified = try resolveQualifiedVar(name: name) {
                v = qualified
            }
            else if let local = resolveVar(name: name, in: currentNs()) {
                v = local
            }
            else {
                throw EvaluatorError.undefinedSymbol(name)
            }
            guard v.isDynamic
            else {
                throw EvaluatorError.invalidArgument(function: "binding",
                    message: "\(name) is not a dynamic var")
            }
            frame[ObjectIdentifier(v)] = try eval(bindingVec[i + 1], in: env)
            i += 2
        }
        bindingFrames.append(frame)
        defer { bindingFrames.removeLast() }
        return try evalBody(Array(elements.dropFirst(2)), in: env)
    }

    func evalLet(_ elements: [Expr], in env: Environment) throws -> Expr {
        let bindingVec = try requireBindingVector(elements, function: "let",
            message: "first argument must be a vector of bindings")
        let letEnv = Environment(parent: env)
        for i in stride(from: 0, to: bindingVec.count, by: 2) {
            let bindings = try destructureBindings(bindingVec[i], bindingVec[i + 1])
            if bindings.isEmpty {
                _ = try eval(bindingVec[i + 1], in: letEnv)
            }
            else {
                for (name, expr) in bindings {
                    letEnv.set(name, try eval(expr, in: letEnv))
                }
            }
        }
        return try evalBody(Array(elements.dropFirst(2)), in: letEnv)
    }

    func evalLetfn(_ elements: [Expr], in env: Environment) throws -> Expr {
        let specs = try requireBindingVector(elements, function: "letfn",
            message: "first argument must be a vector of function specs")
        let letfnEnv = Environment(parent: env)
        var bindings: [(String, Expr)] = []
        for spec in specs {
            guard case .list(let specElems, _) = spec,
                  !specElems.isEmpty,
                  case .symbol(let fnName, _) = specElems[0]
            else {
                throw EvaluatorError.invalidArgument(function: "letfn",
                    message: "each spec must be a list starting with a name symbol")
            }
            // Transform (fname params body...) → (fn fname params body...)
            let fnElements = [Expr.symbol("fn", metadata: nil),
                              Expr.symbol(fnName, metadata: nil)]
                             + Array(specElems.dropFirst())
            bindings.append((fnName, try evalFn(fnElements, in: letfnEnv)))
        }
        // Second pass: bind all fns into the shared env so they see each other
        for (name, fnValue) in bindings {
            letfnEnv.set(name, fnValue)
        }
        return try evalBody(Array(elements.dropFirst(2)), in: letfnEnv)
    }

    func evalLoop(_ elements: [Expr], in env: Environment) throws -> Expr {
        let bindingVec = try requireBindingVector(elements, function: "loop",
            message: "first argument must be a vector of bindings")
        let loopEnv = Environment(parent: env)
        var names: [String] = []
        var patternBindings: [(Expr, String)] = []
        for i in stride(from: 0, to: bindingVec.count, by: 2) {
            let pattern = bindingVec[i]
            let valueExpr = bindingVec[i + 1]
            if case .symbol(let name, _) = pattern {
                names.append(name)
                loopEnv.set(name, try eval(valueExpr, in: loopEnv))
            } else {
                let tmp = gensym(prefix: "lp__")
                names.append(tmp)
                loopEnv.set(tmp, try eval(valueExpr, in: loopEnv))
                patternBindings.append((pattern, tmp))
            }
        }
        var body = Array(elements.dropFirst(2))
        if !patternBindings.isEmpty {
            var letVec: [Expr] = []
            for (pat, tmpName) in patternBindings {
                letVec.append(pat)
                letVec.append(.symbol(tmpName, metadata: nil))
            }
            body = [.list([.symbol("let", metadata: nil), .vector(letVec, metadata: nil)] + body, metadata: nil)]
        }
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

    func evalRecur(_ elements: [Expr], in env: Environment) throws -> Expr {
        let args = try elements.dropFirst().map { try eval($0, in: env) }
        throw RecurSignal(args: args)
    }

    func evalThrow(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard elements.count == 2
        else {
            throw EvaluatorError.invalidArgument(function: "throw",
                                                 message: "requires exactly 1 argument")
        }
        throw SwishException(value: try eval(elements[1], in: env))
    }

    private func parseTryForm(
        _ elements: [Expr]
    ) throws -> (body: [Expr], catches: [CatchClause], finally: [Expr]) {
        var body: [Expr] = []
        var catches: [CatchClause] = []
        var finallyExprs: [Expr] = []
        var seenFinally = false

        for elem in elements.dropFirst() {
            if case .list(let inner, _) = elem, let head = inner.first {
                if case .symbol("catch", _) = head {
                    guard !seenFinally
                    else {
                        throw EvaluatorError.invalidArgument(function: "try",
                                                             message: "catch clause after finally")
                    }
                    guard inner.count >= 3,
                          case .symbol(let typeName, _) = inner[1],
                          case .symbol(let bindingName, _) = inner[2]
                    else {
                        throw EvaluatorError.invalidArgument(function: "catch",
                                                             message: "requires a type and binding name")
                    }
                    catches.append(CatchClause(typeName: typeName,
                                               bindingName: bindingName,
                                               body: Array(inner.dropFirst(3))))
                    continue
                }

                if case .symbol("finally", _) = head {
                    guard !seenFinally
                    else {
                        throw EvaluatorError.invalidArgument(function: "try",
                                                             message: "multiple finally clauses")
                    }
                    seenFinally = true
                    finallyExprs = Array(inner.dropFirst())
                    continue
                }
            }

            guard catches.isEmpty && !seenFinally
            else {
                throw EvaluatorError.invalidArgument(function: "try",
                                                     message: "body forms must appear before catch/finally")
            }
            body.append(elem)
        }

        return (body, catches, finallyExprs)
    }

    func evalTry(_ elements: [Expr], in env: Environment) throws -> Expr {
        let (body, catches, finallyExprs) = try parseTryForm(elements)
        var result: Expr = .nil
        var thrownError: Error? = nil

        do {
            result = try evalBody(body, in: env)
        }
        catch let signal as RecurSignal {
            throw signal
        }
        catch let e as EvaluatorError where e == .interrupted {
            throw e
        }
        catch {
            if let clause = catches.first(where: { $0.typeName == "Exception" }) {
                do {
                    let catchEnv = Environment(parent: env)
                    catchEnv.set(clause.bindingName, exprForError(error))
                    result = try evalBody(clause.body, in: catchEnv)
                }
                catch let catchBodyError {
                    thrownError = catchBodyError
                }
            }
            else {
                thrownError = error
            }
        }

        if !finallyExprs.isEmpty {
            _ = try evalBody(finallyExprs, in: env)
        }

        if let err = thrownError {
            throw err
        }
        return result
    }

    func exprForError(_ error: Error) -> Expr {
        if let e = error as? SwishException {
            return e.value
        }
        return .string("\(error)")
    }

    func buildFnArity(from clause: Expr, functionName: String, validateRecur: Bool, outerLocals: Set<String> = []) throws -> FnArity {
        guard case .list(let elems, _) = clause, !elems.isEmpty,
              case .vector(let paramExprs, _) = elems[0]
        else {
            throw EvaluatorError.invalidArgument(function: functionName, message: "invalid arity clause")
        }
        let (params, rawBody) = expandDestructuredParams(paramExprs, body: Array(elems.dropFirst()))
        if validateRecur { try validateRecurTailPosition(in: rawBody) }
        let allLocals = collectAllParamLocals(paramExprs).union(outerLocals)
        return FnArity(params: params, body: expandAliases(in: rawBody, locals: allLocals))
    }

    func evalFn(_ elements: [Expr], in env: Environment) throws -> Expr {
        var offset = 1
        var name: String? = nil
        if elements.count > 2, case .symbol(let n, _) = elements[1] {
            let next = elements[2]
            if case .vector = next { name = n; offset = 2 }
            else if case .list = next { name = n; offset = 2 }
        }
        let remaining = Array(elements.dropFirst(offset))
        if let first = remaining.first, case .list = first {
            let outerLocals = env.allNames()
            let arities = try remaining.map { try buildFnArity(from: $0, functionName: "fn", validateRecur: true, outerLocals: outerLocals) }
            return .multiArityFunction(SwishMultiArityFunction(name: name, arities: arities, capturedEnv: env, metadata: nil))
        }
        guard !remaining.isEmpty, case .vector(let paramExprs, _) = remaining[0] else {
            throw EvaluatorError.invalidArgument(function: "fn", message: "requires a parameter vector")
        }
        let (params, rawBody) = expandDestructuredParams(paramExprs, body: Array(remaining.dropFirst()))
        try validateRecurTailPosition(in: rawBody)
        let ownLocals = collectAllParamLocals(paramExprs)
        let allLocals = ownLocals.union(env.allNames())
        let body = expandAliases(in: rawBody, locals: allLocals)
        return .function(SwishFunction(name: name, params: params, body: body, capturedEnv: env, metadata: nil))
    }

    func evalDefmacro(_ elements: [Expr]) throws -> Expr {
        guard elements.count >= 3, case .symbol(let name, let symMeta) = elements[1]
        else {
            throw EvaluatorError.invalidArgument(function: "defmacro", message: "invalid syntax")
        }
        let (docString, attrMap, idx) = extractDocAndAttr(elements, startingAt: 2)
        guard idx < elements.count else {
            throw EvaluatorError.invalidArgument(function: "defmacro", message: "invalid syntax")
        }
        var meta = buildMeta(from: symMeta, attrMap: attrMap, docString: docString)
        let restElems = Array(elements.dropFirst(idx))
        if meta[.keyword("arglists")] == nil {
            if case .vector(let paramExprs, _) = restElems.first {
                meta[.keyword("arglists")] = .list([.vector(paramExprs, metadata: nil)], metadata: nil)
            }
            else {
                let vecs = restElems.compactMap { form -> Expr? in
                    guard case .list(let parts, _) = form, case .vector(let p, _) = parts.first else { return nil }
                    return .vector(p, metadata: nil)
                }
                if !vecs.isEmpty { meta[.keyword("arglists")] = .list(vecs, metadata: nil) }
            }
        }
        let macroMeta: [Expr: Expr]? = meta.isEmpty ? nil : meta
        // Pre-qualify syntax-quote templates using the current (defining) namespace.
        // This matches Clojure's compile-time syntax-quote behavior.
        let expandedRestElems = preExpandSyntaxQuotesInBody(restElems)
        let macroValue: Expr
        switch expandedRestElems.first {
        case .vector(let paramExprs, _):
            let params = extractParamNames(paramExprs)
            let rawBody = Array(expandedRestElems.dropFirst())
            macroValue = .macro(name: name, params: params,
                                body: expandAliases(in: rawBody, locals: Set(params)),
                                metadata: macroMeta)
        case .list:
            let arities = try expandedRestElems.map {
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

    // MARK: - Recur tail-position validation

    func validateRecurTailPosition(in body: [Expr]) throws {
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
            return

        case .symbol("if", _):
            if elements.count > 1, recurAppears(in: elements[1]) {
                throw EvaluatorError.recurNotInTailPosition
            }
            if elements.count > 2 { try validateTailExpr(elements[2]) }
            if elements.count > 3 { try validateTailExpr(elements[3]) }

        case .symbol("do", _):
            try validateTailForms(Array(elements.dropFirst()))

        case .symbol("let", _):
            if elements.count > 1, case .vector(let bindings, _) = elements[1] {
                for i in stride(from: 1, to: bindings.count, by: 2) {
                    if recurAppears(in: bindings[i]) { throw EvaluatorError.recurNotInTailPosition }
                }
            }
            try validateTailForms(Array(elements.dropFirst(2)))

        case .symbol("fn", _), .symbol("loop", _):
            return

        case .symbol(let name, _):
            let resolved = (try? resolveQualifiedVar(name: name)) ?? resolveVar(name: name, in: currentNs())
            if let v = resolved?.value {
                switch v {
                case .macro, .multiArityMacro: return
                default: break
                }
            }
            for element in elements where recurAppears(in: element) {
                throw EvaluatorError.recurNotInTailPosition
            }

        default:
            for element in elements where recurAppears(in: element) {
                throw EvaluatorError.recurNotInTailPosition
            }
        }
    }

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

        case .map(let sm):
            return sm.dict.keys.contains { recurAppears(in: $0) }
                || sm.dict.values.contains { recurAppears(in: $0) }

        default:
            return false
        }
    }
}
