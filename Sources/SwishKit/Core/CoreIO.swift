import Foundation

// MARK: - Registration

func registerIO(into evaluator: Evaluator) {
    let outVar = evaluator.findNs("clojure.core")!.intern(name: "*out*", value: .nil)
    outVar.isDynamic = true

    evaluator.register(name: "print", arity: .variadic,
        doc: "Prints the object(s) to the output stream that is the current value of *out*. print and println produce output for human consumption.",
        arglists: [["&", "more"]]) { [evaluator] args in
        try coreOutput(evaluator, args: args, terminator: "")
    }
    evaluator.register(name: "println", arity: .variadic,
        doc: "Same as print followed by (newline)",
        arglists: [["&", "more"]]) { [evaluator] args in
        try coreOutput(evaluator, args: args, terminator: "\n")
    }
    evaluator.register(name: "pr-str", arity: .variadic,
        doc: "pr to a string, returning it. Prints the object(s), separated by spaces, " +
             "in a form that the reader can read back.",
        arglists: [["&", "more"]]) { args in
        .string(args.map { corePrinter.printString($0) }.joined(separator: " "))
    }
    evaluator.register(name: "print-str", arity: .variadic,
        doc: "print to a string, returning it",
        arglists: [["&", "more"]]) { args in
        .string(args.map { strStringForPrint($0) }.joined(separator: " "))
    }
    evaluator.register(name: "println-str", arity: .variadic,
        doc: "println to a string, returning it",
        arglists: [["&", "more"]]) { args in
        .string(args.map { strStringForPrint($0) }.joined(separator: " ") + "\n")
    }
    evaluator.register(name: "prn-str", arity: .variadic,
        doc: "prn to a string, returning it",
        arglists: [["&", "more"]]) { args in
        .string(args.map { corePrinter.printString($0) }.joined(separator: " ") + "\n")
    }
    evaluator.register(name: "pr", arity: .variadic,
        doc: "Prints the object(s) to the output stream that is the current value of *out*. " +
             "Prints the object(s) in a form that the reader can read back.",
        arglists: [["&", "more"]]) { [evaluator] args in
        try corePrint(evaluator, args: args, terminator: "")
    }
    evaluator.register(name: "prn", arity: .variadic,
        doc: "Same as pr followed by (newline)",
        arglists: [["&", "more"]]) { [evaluator] args in
        try corePrint(evaluator, args: args, terminator: "\n")
    }
    evaluator.register(name: "print-doc", arity: .fixed(1),
        doc: "Prints formatted documentation for the var named by symbol to *out*.",
        arglists: [["sym"]]) { [evaluator] args in try corePrintDoc(evaluator, args) }

    evaluator.register(name: "read-string", arity: .fixed(1),
        doc: "Reads one object from the string s. Returns the first Swish data " +
             "structure read. Does not evaluate.",
        arglists: [["s"]],
        body: coreReadString)

    evaluator.register(name: "edn-read-string*", arity: .fixed(2),
        doc: "Low-level EDN reader used by clojure.edn/read-string. Accepts an opts map and source string; applies :default/:readers for unknown tagged literals and returns :eof sentinel for empty input.",
        arglists: [["opts", "s"]]) { [evaluator] args in try ednReadString(evaluator, args) }

    evaluator.register(name: "swish-read-line!", arity: .fixed(1),
        doc: "Reads the next line from a SwishReader. Returns the line as a string, or nil at EOF.",
        arglists: [["rdr"]]) { args in
        guard case .reader(let rdr) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "swish-read-line!",
                message: "argument must be a reader")
        }
        if let line = rdr.readLine() { return .string(line) }
        return .nil
    }
    evaluator.register(name: "swish-close-reader!", arity: .fixed(1),
        doc: "Closes a SwishReader.",
        arglists: [["rdr"]]) { args in
        guard case .reader(let rdr) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "swish-close-reader!",
                message: "argument must be a reader")
        }
        rdr.close()
        return .nil
    }
    evaluator.register(name: "swish-close-writer!", arity: .fixed(1),
        doc: "Closes a SwishWriter.",
        arglists: [["wtr"]]) { args in
        guard case .writer(let wtr) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "swish-close-writer!",
                message: "argument must be a writer")
        }
        wtr.close()
        return .nil
    }
    evaluator.register(name: "swish-string-writer", arity: .fixed(0),
        doc: "Internal. Returns a fresh in-memory writer whose accumulated content can be read back with swish-writer-string. Backs with-out-str.",
        arglists: [[]]) { _ in .writer(SwishWriter()) }
    evaluator.register(name: "swish-writer-string", arity: .fixed(1),
        doc: "Internal. Returns the content accumulated so far in an in-memory writer created by swish-string-writer. Backs with-out-str.",
        arglists: [["wtr"]]) { args in
        guard case .writer(let wtr) = args[0], wtr.path == nil else {
            throw EvaluatorError.invalidArgument(function: "swish-writer-string",
                message: "argument must be an in-memory writer created by swish-string-writer")
        }
        return .string(wtr.bufferedString)
    }

    evaluator.register(name: "slurp", arity: .variadic,
        doc: "Reads the file named by f and returns the contents as a string. " +
             "Supported options: :encoding (default \"UTF-8\").",
        arglists: [["f"], ["f", "&", "opts"]]) { args in
        guard !args.isEmpty, case .string(let path) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "slurp",
                message: "first argument must be a string path")
        }
        let encoding = parseEncodingOpt(args.dropFirst()) ?? .utf8
        do {
            return .string(try String(contentsOfFile: path, encoding: encoding))
        }
        catch {
            throw EvaluatorError.invalidArgument(function: "slurp",
                message: error.localizedDescription)
        }
    }

    evaluator.register(name: "spit", arity: .variadic,
        doc: "Opposite of slurp. Writes content to the file named by f. " +
             "Supported options: :append (default false).",
        arglists: [["f", "content"], ["f", "content", "&", "opts"]]) { args in
        guard args.count >= 2 else {
            throw EvaluatorError.invalidArgument(function: "spit",
                message: "requires at least 2 arguments")
        }
        guard case .string(let path) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "spit",
                message: "first argument must be a string path")
        }
        let content = corePrinter.strString(args[1])
        let append = parseAppendOpt(args.dropFirst(2))
        do {
            try spitImpl(path: path, content: content, append: append)
            return .nil
        }
        catch {
            throw EvaluatorError.invalidArgument(function: "spit",
                message: error.localizedDescription)
        }
    }
}

// MARK: - clojure.swift.io namespace

func registerSwiftIONamespace(into evaluator: Evaluator) {
    let ns = evaluator.findOrCreateNs("clojure.swift.io")

    ns.register(
        name: "reader",
        value: .nativeFunction(name: "reader", arity: .variadic, body: { args in
            guard let first = args.first, case .string(let path) = first else {
                throw EvaluatorError.invalidArgument(function: "reader",
                    message: "first argument must be a string path")
            }
            do {
                return .reader(try SwishReader(path: path))
            }
            catch {
                throw EvaluatorError.invalidArgument(function: "reader",
                    message: error.localizedDescription)
            }
        }),
        doc: "Opens a buffered reader for the file at path. Close with with-open.",
        arglists: [["path"], ["path", "&", "opts"]]
    )

    ns.register(
        name: "writer",
        value: .nativeFunction(name: "writer", arity: .variadic, body: { args in
            guard let first = args.first, case .string(let path) = first else {
                throw EvaluatorError.invalidArgument(function: "writer",
                    message: "first argument must be a string path")
            }
            let append = parseAppendOpt(args.dropFirst())
            do {
                return .writer(try SwishWriter(path: path, append: append))
            }
            catch {
                throw EvaluatorError.invalidArgument(function: "writer",
                    message: error.localizedDescription)
            }
        }),
        doc: "Opens a buffered writer for the file at path. Supported options: :append (default false). Close with with-open.",
        arglists: [["path"], ["path", "&", "opts"]]
    )
}

// MARK: - Reader implementations

private func coreReadString(_ args: [Expr]) throws -> Expr {
    guard case .string(let source) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "read-string",
            message: "argument must be a string")
    }
    let exprs: [Expr]
    do {
        exprs = try Reader.readString(source)
    } catch let e as ParserError {
        if case .unknownTaggedLiteral(let tag, _, _, _) = e {
            throw EvaluatorError.invalidArgument(function: "read-string",
                message: "No reader function for tag #\(tag)")
        }
        throw EvaluatorError.invalidArgument(function: "read-string",
            message: e.description)
    } catch {
        throw EvaluatorError.invalidArgument(function: "read-string",
            message: error.localizedDescription)
    }
    guard let first = exprs.first else {
        throw EvaluatorError.invalidArgument(function: "read-string",
            message: "no forms found in string")
    }
    return first
}

private func ednReadString(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .map(let optsMap) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "edn-read-string*",
            message: "first argument must be a map")
    }
    let opts = optsMap.dict
    guard case .string(let source) = args[1] else {
        throw EvaluatorError.invalidArgument(function: "edn-read-string*",
            message: "second argument must be a string")
    }

    let tagResolver: (String, Expr) throws -> Expr = { tag, value in
        let tagSym = Expr.symbol(tag, metadata: nil)
        // :readers override takes precedence (even over uuid/inst built-ins)
        if let readersExpr = opts[.keyword("readers")],
           case .map(let readersMap) = readersExpr,
           let fn = readersMap.dict[tagSym] {
            return try evaluator.call(fn, args: [value])
        }
        // Built-in handling for uuid and inst
        if tag == "inst", case .string(let s) = value {
            guard let date = Parser.parseInstString(s) else {
                throw EvaluatorError.invalidArgument(function: "edn/read-string",
                    message: "invalid #inst date string: \"\(s)\"")
            }
            return .inst(date)
        }
        if tag == "uuid", case .string(let s) = value {
            guard let uuid = UUID(uuidString: s) else {
                throw EvaluatorError.invalidArgument(function: "edn/read-string",
                    message: "invalid #uuid string: \"\(s)\"")
            }
            return .uuid(uuid)
        }
        // :default for unknown tags
        if let defaultFn = opts[.keyword("default")] {
            return try evaluator.call(defaultFn, args: [tagSym, value])
        }
        throw EvaluatorError.invalidArgument(function: "edn/read-string",
            message: "No reader function for tag #\(tag)")
    }

    // Pre-validate: reject auto-qualified keywords (::), which are Clojure-specific
    if sourceContainsAutoQualifiedKeyword(source) {
        throw EvaluatorError.invalidArgument(function: "edn/read-string",
            message: "Invalid token: auto-qualified keywords (::) are not valid EDN")
    }

    let exprs: [Expr]
    do {
        exprs = try Reader.readEDN(source, tagResolver: tagResolver)
    } catch let e as EvaluatorError {
        throw e
    } catch {
        throw EvaluatorError.invalidArgument(function: "edn/read-string",
            message: error.localizedDescription)
    }
    guard let first = exprs.first else {
        guard let eofVal = opts[.keyword("eof")] else {
            throw EvaluatorError.invalidArgument(function: "edn/read-string",
                message: "EOF while reading")
        }
        return eofVal
    }
    return first
}

// MARK: - EDN helpers

private func sourceContainsAutoQualifiedKeyword(_ source: String) -> Bool {
    var i = source.startIndex
    while i < source.endIndex {
        let c = source[i]
        let next = source.index(after: i)
        if c == ";" {
            while i < source.endIndex && source[i] != "\n" {
                i = source.index(after: i)
            }
        }
        else if c == "\"" {
            i = next
            while i < source.endIndex {
                if source[i] == "\\" {
                    i = source.index(after: i)
                    if i < source.endIndex { i = source.index(after: i) }
                }
                else if source[i] == "\"" {
                    i = source.index(after: i)
                    break
                }
                else {
                    i = source.index(after: i)
                }
            }
        }
        else if c == ":" && next < source.endIndex && source[next] == ":" {
            return true
        }
        else {
            i = next
        }
    }
    return false
}

// MARK: - Print implementations

private func coreOutput(_ evaluator: Evaluator, args: [Expr], terminator: String) throws -> Expr {
    let s = args.map { strStringForPrint($0) }.joined(separator: " ")
    try writeToOut(evaluator, s + terminator)
    return .nil
}

/// str-style rendering for print/println/print-str/println-str: like `strString`,
/// but nil renders as the literal text "nil" rather than "". strString's empty-string
/// nil is specific to `str`'s own concatenation semantics ((str nil) => ""); print's
/// per-argument rendering always shows "nil", matching real Clojure.
private func strStringForPrint(_ expr: Expr) -> String {
    if case .nil = expr {
        return "nil"
    }
    return corePrinter.strString(expr)
}

private func corePrint(_ evaluator: Evaluator, args: [Expr], terminator: String) throws -> Expr {
    let s = args.map { corePrinter.printString($0) }.joined(separator: " ")
    try writeToOut(evaluator, s + terminator)
    return .nil
}

private func writeToOut(_ evaluator: Evaluator, _ s: String) throws {
    switch evaluator.currentOut() {
    case .writer(let wtr):
        do { try wtr.write(s) }
        catch { throw EvaluatorError.invalidArgument(function: "print", message: error.localizedDescription) }
    default:
        Swift.print(s, terminator: "")
    }
}

private func corePrintDoc(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .symbol(let name, _) = args[0]
    else {
        throw EvaluatorError.invalidArgument(
            function: "print-doc",
            message: "argument must be a symbol")
    }
    if let ns = evaluator.findNs(name) {
        var lines = [String(repeating: "-", count: 25), ns.name]
        if let meta = ns.metadata, case .string(let doc) = meta[.keyword("doc")] {
            for line in doc.components(separatedBy: "\n") {
                lines.append("  \(line)")
            }
        }
        try writeToOut(evaluator, lines.joined(separator: "\n") + "\n")
        return .nil
    }
    let v = (try? evaluator.resolveQualifiedVar(name: name)) ?? nil
              ?? evaluator.resolveVar(name: name, in: evaluator.currentNs())
    guard let v else {
        try writeToOut(evaluator, "No doc found for \(name)\n")
        return .nil
    }
    var lines = [String(repeating: "-", count: 25), "\(v.namespace.name)/\(v.name)"]
    if let meta = v.metadata {
        if let arglists = meta[.keyword("arglists")] {
            lines.append(corePrinter.printString(arglists))
        }
        if case .string(let doc) = meta[.keyword("doc")] {
            for line in doc.components(separatedBy: "\n") {
                lines.append("  \(line)")
            }
        }
    }
    try writeToOut(evaluator, lines.joined(separator: "\n") + "\n")
    return .nil
}

// MARK: - File I/O implementations

private func parseKVOpt(_ opts: ArraySlice<Expr>, key: String) -> Expr? {
    var i = opts.startIndex
    while i + 1 < opts.endIndex {
        if case .keyword(let k) = opts[i], k == key {
            return opts[i + 1]
        }
        i += 2
    }
    return nil
}

private func parseEncodingOpt(_ opts: ArraySlice<Expr>) -> String.Encoding? {
    guard case .string(let enc) = parseKVOpt(opts, key: "encoding") else { return nil }
    switch enc.uppercased() {
    case "UTF-8", "UTF8":   return .utf8
    case "UTF-16", "UTF16": return .utf16
    case "ISO-8859-1", "ISO8859-1", "LATIN1": return .isoLatin1
    case "ASCII":           return .ascii
    default:                return .utf8
    }
}

private func parseAppendOpt(_ opts: ArraySlice<Expr>) -> Bool {
    guard case .boolean(let b) = parseKVOpt(opts, key: "append") else { return false }
    return b
}

private func spitImpl(path: String, content: String, append: Bool) throws {
    let data = Data(content.utf8)
    let url = URL(fileURLWithPath: path)
    if append && FileManager.default.fileExists(atPath: path) {
        let handle = try FileHandle(forWritingTo: url)
        defer { handle.closeFile() }
        handle.seekToEndOfFile()
        handle.write(data)
    }
    else {
        try data.write(to: url, options: .atomic)
    }
}
