extension Evaluator {

    // MARK: - Special forms

    func buildMeta(from symMeta: [Expr: Expr]?, attrMap: [Expr: Expr]?, docString: String?) -> [Expr: Expr] {
        var meta: [Expr: Expr] = symMeta ?? [:]
        if let attr = attrMap { for (k, v) in attr { meta[k] = v } }
        if let doc = docString { meta[.keyword("doc")] = .string(doc) }
        return meta
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
}
