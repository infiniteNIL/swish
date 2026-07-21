// MARK: - Registration

// The JVM Clojure compiler's fixed table of special-form names (Compiler.java's
// `specials` map), reproduced verbatim for special-symbol?. import* is the one
// namespace-qualified entry (Symbol.intern("clojure.core", "import*")) — a bare
// 'import* does not match it, matching real Clojure exactly.
private let specialSymbolNames: Set<String> = [
    "def", "loop*", "recur", "if", "case*", "let*", "letfn*", "do", "fn*",
    "quote", "var", "clojure.core/import*", ".", "set!", "deftype*", "reify*",
    "try", "throw", "monitor-enter", "monitor-exit", "catch", "finally", "new", "&",
]

func registerPredicates(into evaluator: Evaluator) {
    evaluator.register(name: "nil?",     arity: .fixed(1), doc: "Returns true if x is nil, false otherwise.",       arglists: [["x"]]) { args in if case .nil     = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "true?",    arity: .fixed(1), doc: "Returns true if x is the value true, false otherwise.",  arglists: [["x"]]) { args in if case .boolean(true)  = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "false?",   arity: .fixed(1), doc: "Returns true if x is the value false, false otherwise.", arglists: [["x"]]) { args in if case .boolean(false) = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "boolean?", arity: .fixed(1), doc: "Return true if x is a Boolean",                       arglists: [["x"]]) { args in if case .boolean = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "var?",     arity: .fixed(1), doc: "Returns true if v is of type clojure.lang.Var.",     arglists: [["v"]]) { args in if case .varRef = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "special-symbol?", arity: .fixed(1),
        doc: "Returns true if s names a special form",
        arglists: [["s"]]) { args in
        guard case .symbol(let name, _) = args[0] else { return .boolean(false) }
        return .boolean(specialSymbolNames.contains(name))
    }
    evaluator.register(name: "uuid?",    arity: .fixed(1), doc: "Return true if x is a java.util.UUID",              arglists: [["x"]]) { args in if case .uuid   = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "keyword?", arity: .fixed(1), doc: "Returns true if x is a keyword, false otherwise.",  arglists: [["x"]]) { args in if case .keyword = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "keyword", arity: .variadic,
        doc: "Returns a Keyword with the given namespace and name. Do not use : in the keyword strings, it will be added automatically. If the name is already a keyword, returns it. Returns nil if the name is nil.",
        arglists: [["name"], ["ns", "name"]]) { args in try coreKeyword(args) }
    evaluator.register(name: "symbol?",  arity: .fixed(1), doc: "Return true if x is a Symbol",                      arglists: [["x"]]) { args in if case .symbol  = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "string?",  arity: .fixed(1), doc: "Return true if x is a String",                      arglists: [["x"]]) { args in if case .string    = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "char?",    arity: .fixed(1), doc: "Returns true if x is a Character.",                  arglists: [["x"]]) { args in if case .character = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "reader?",  arity: .fixed(1), doc: "Returns true if x is a SwishReader.",               arglists: [["x"]]) { args in if case .reader  = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "writer?",  arity: .fixed(1), doc: "Returns true if x is a SwishWriter.",               arglists: [["x"]]) { args in if case .writer  = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "fn?",      arity: .fixed(1), doc: "Returns true if x is a fn.",                        arglists: [["x"]]) { args in
        switch args[0] {
        case .function, .multiArityFunction, .nativeFunction:
            return .boolean(true)

        default:
            return .boolean(false)
        }
    }
    evaluator.register(name: "ifn?", arity: .fixed(1), doc: "Returns true if x implements IFn.", arglists: [["x"]]) { args in
        switch args[0] {
        case .function, .multiArityFunction, .nativeFunction,
             .macro, .multiArityMacro,
             .keyword, .map, .sortedMap, .set, .sortedSet, .vector, .mapEntry,
             .symbol, .varRef, .promise:
            return .boolean(true)

        default:
            return .boolean(false)
        }
    }
    evaluator.register(name: "associative?", arity: .fixed(1), doc: "Returns true if coll implements Associative.", arglists: [["coll"]]) { args in
        switch args[0] {
        case .map, .sortedMap, .record, .vector, .sharedVector, .mapEntry:
            return .boolean(true)

        default:
            return .boolean(false)
        }
    }
    evaluator.register(name: "reversible?", arity: .fixed(1), doc: "Returns true if coll implements Reversible", arglists: [["coll"]]) { args in
        switch args[0] {
        case .vector, .sharedVector, .sortedMap, .sortedSet:
            return .boolean(true)

        default:
            return .boolean(false)
        }
    }
    evaluator.register(name: "coll?", arity: .fixed(1), doc: "Returns true if x implements IPersistentCollection", arglists: [["x"]]) { args in
        switch args[0] {
        case .list, .seq, .lazySeq, .vector, .sharedVector, .mapEntry, .map, .sortedMap, .set, .sortedSet, .record:
            return .boolean(true)

        default:
            return .boolean(false)
        }
    }
    evaluator.register(name: "counted?", arity: .fixed(1), doc: "Returns true if coll implements count in constant time", arglists: [["coll"]]) { args in
        switch args[0] {
        case .list, .seq, .vector, .sharedVector, .mapEntry, .map, .sortedMap, .set, .sortedSet, .record:
            return .boolean(true)

        default:
            return .boolean(false)
        }
    }
    evaluator.register(name: "name", arity: .fixed(1),
        doc: "Returns the name String of a string, symbol or keyword.",
        arglists: [["x"]]) { args in
        switch args[0] {
        case .string(let s):
            return .string(s)

        case .keyword(let k):
            return .string(k.contains("/") ? String(k.split(separator: "/", maxSplits: 1).last!) : k)

        case .symbol(let s, _):
            return .string(s.contains("/") ? String(s.split(separator: "/", maxSplits: 1).last!) : s)

        default:
            throw EvaluatorError.invalidArgument(function: "name",
                message: "don't know how to get name of \(corePrinter.printString(args[0]))")
        }
    }
    evaluator.register(name: "namespace", arity: .fixed(1),
        doc: "Returns the namespace String of a symbol or keyword, or nil if not present.",
        arglists: [["x"]]) { args in
        switch args[0] {
        case .keyword(let k):
            guard k.contains("/") else { return .nil }
            return .string(String(k.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).first!))

        case .symbol(let s, _):
            guard s.contains("/") else { return .nil }
            return .string(String(s.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).first!))

        case .string:
            return .nil

        default:
            throw EvaluatorError.invalidArgument(function: "namespace",
                message: "don't know how to get namespace of \(corePrinter.printString(args[0]))")
        }
    }
    evaluator.register(name: "type", arity: .fixed(1),
        doc: "Returns a keyword naming the runtime type of x, or nil for nil.",
        arglists: [["x"]]) { args in
        if case .nil = args[0] { return .nil }
        return .keyword(args[0].description)
    }
}

// MARK: - Helpers

private func coreKeyword(_ args: [Expr]) throws -> Expr {
    switch args.count {
    case 1:
        switch args[0] {
        case .nil:
            return .nil
        case .keyword:
            return args[0]
        case .string(let s):
            return .keyword(s)
        case .symbol(let s, _):
            return .keyword(s)
        default:
            throw EvaluatorError.invalidArgument(function: "keyword",
                message: "don't know how to make a keyword from \(corePrinter.printString(args[0]))")
        }

    case 2:
        guard case .string(let name) = args[1] else {
            throw EvaluatorError.invalidArgument(function: "keyword", message: "name must be a string")
        }
        switch args[0] {
        case .nil:
            return .keyword(name)
        case .string(let ns):
            return .keyword("\(ns)/\(name)")
        default:
            throw EvaluatorError.invalidArgument(function: "keyword", message: "ns must be a string or nil")
        }

    default:
        throw EvaluatorError.arityMismatch(name: "keyword", expected: .variadic, got: args.count)
    }
}
