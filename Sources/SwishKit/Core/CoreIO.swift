import Foundation

// Shared verbatim by slurp/spit and the clojure.swift.io reader/writer openers.
private let pathMustBeAString = "first argument must be a string path"

// MARK: - Registration

func registerIO(into evaluator: Evaluator) {
    let outVar = evaluator.findNs("clojure.core")!.intern(name: "*out*", value: .nil)
    outVar.isDynamic = true

    // *err* mirrors *out*: a redirectable dynamic var whose value is a writer, or
    // nil meaning stderr. Backs warnings (e.g. refer clashes) and `with-err-str`.
    let errVar = evaluator.findNs("clojure.core")!.intern(name: "*err*", value: .nil)
    errVar.isDynamic = true

    // Hand both to the evaluator so `currentOut()`/`currentErr()` read them directly
    // instead of resolving by name on every write — see `Evaluator.outVar`.
    evaluator.cacheIOVars(out: outVar, err: errVar)

    // print/println and pr/prn are the same operation; `readable` is the only difference.
    evaluator.register(name: "print", arity: .variadic,
        doc: "Prints the object(s) to the output stream that is the current value of *out*. print and println produce output for human consumption.",
        arglists: [["&", "more"]]) { [evaluator] args in
        try writeRendered(evaluator, args: args, readable: false, terminator: "")
    }
    evaluator.register(name: "println", arity: .variadic,
        doc: "Same as print followed by (newline)",
        arglists: [["&", "more"]]) { [evaluator] args in
        try writeRendered(evaluator, args: args, readable: false, terminator: "\n")
    }
    evaluator.register(name: "newline", arity: .fixed(0),
        doc: "Writes a platform-specific newline to *out*.",
        arglists: [[]]) { [evaluator] _ in
        try writeToOut(evaluator, "\n")
        return .nil
    }
    // The four `*-str` fns differ only in renderer (readable `pr` vs human `print`) and
    // whether they append a newline.
    evaluator.register(name: "pr-str", arity: .variadic,
        doc: "pr to a string, returning it. Prints the object(s), separated by spaces, " +
             "in a form that the reader can read back.",
        arglists: [["&", "more"]],
        body: printToStringFn(evaluator, readable: true, terminator: ""))
    evaluator.register(name: "print-str", arity: .variadic,
        doc: "print to a string, returning it",
        arglists: [["&", "more"]],
        body: printToStringFn(evaluator, readable: false, terminator: ""))
    evaluator.register(name: "println-str", arity: .variadic,
        doc: "println to a string, returning it",
        arglists: [["&", "more"]],
        body: printToStringFn(evaluator, readable: false, terminator: "\n"))
    evaluator.register(name: "prn-str", arity: .variadic,
        doc: "prn to a string, returning it",
        arglists: [["&", "more"]],
        body: printToStringFn(evaluator, readable: true, terminator: "\n"))
    evaluator.register(name: "pr", arity: .variadic,
        doc: "Prints the object(s) to the output stream that is the current value of *out*. " +
             "Prints the object(s) in a form that the reader can read back.",
        arglists: [["&", "more"]]) { [evaluator] args in
        try writeRendered(evaluator, args: args, readable: true, terminator: "")
    }
    evaluator.register(name: "prn", arity: .variadic,
        doc: "Same as pr followed by (newline)",
        arglists: [["&", "more"]]) { [evaluator] args in
        try writeRendered(evaluator, args: args, readable: true, terminator: "\n")
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
        let rdr = try requireReader(args[0], function: "swish-read-line!")
        if let line = rdr.readLine() { return .string(line) }
        return .nil
    }
    evaluator.register(name: "swish-close-reader!", arity: .fixed(1),
        doc: "Closes a SwishReader.",
        arglists: [["rdr"]]) { args in
        try requireReader(args[0], function: "swish-close-reader!").close()
        return .nil
    }
    evaluator.register(name: "swish-close-writer!", arity: .fixed(1),
        doc: "Closes a SwishWriter.",
        arglists: [["wtr"]]) { args in
        try requireWriter(args[0], function: "swish-close-writer!").close()
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
    evaluator.register(name: "swish-write-default", arity: .fixed(2),
        doc: "Internal. Writes the default (pr) representation of x to writer w — backs print-method's :default method. Uses the hook-free shared printer, so it never recurses back into print-method.",
        arglists: [["x", "w"]]) { args in
        let wtr = try requireWriter(args[1], function: "swish-write-default",
            message: "second argument must be a writer")
        try wtr.write(corePrinter.printString(args[0]))
        return .nil
    }
    evaluator.register(name: "flush", arity: .fixed(0),
        doc: "Flushes the output stream that is the current value of *out*.",
        arglists: [[]]) { [evaluator] _ in
        // A SwishWriter writes eagerly (nothing buffered to flush); only stdout needs it.
        if case .writer = evaluator.currentOut() {
            // no-op
        }
        else {
            fflush(stdout)
        }
        return .nil
    }

    evaluator.register(name: "slurp", arity: .variadic,
        doc: "Reads the file named by f and returns the contents as a string. " +
             "Supported options: :encoding (default \"UTF-8\").",
        arglists: [["f"], ["f", "&", "opts"]]) { args in
        // `args.first ?? .nil` keeps the no-args case throwing the same "must be a
        // string path" message it always did (`.nil` is not a string), rather than
        // an arity message.
        let path = try requireString(args.first ?? .nil, function: "slurp", message: pathMustBeAString)
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
        try requireArgCount(args, atLeast: 2, function: "spit")
        let path = try requireString(args[0], function: "spit", message: pathMustBeAString)
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
            let path = try requireString(args.first ?? .nil, function: "reader", message: pathMustBeAString)
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
            let path = try requireString(args.first ?? .nil, function: "writer", message: pathMustBeAString)
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
    let source = try requireString(args[0], function: "read-string")
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
    let opts = try requireMap(args[0], function: "edn-read-string*",
        message: "first argument must be a map").dict
    let source = try requireString(args[1], function: "edn-read-string*",
        message: "second argument must be a string")

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

/// The printer for one output call. `pr`/`prn` honor whatever `*print-readably*` is
/// currently bound to; `print`/`println` **force it off**, mirroring Clojure's
/// `(binding [*print-readably* nil] (apply pr more))`.
///
/// Note what that binding does and does not do: it suppresses string and char quoting at
/// *every* depth, but leaves everything else readable — `nil` still prints as "nil", a
/// bigint keeps its `N`, a `#uuid` keeps its tag. That is why the print family is built
/// from `printString` and not from `strString`, whose plain rendering of those is specific
/// to `str`. See the entry-point comment in `Printer.swift`.
private func outputPrinter(_ evaluator: Evaluator, readable: Bool) -> Printer {
    var printer = evaluator.makePrinter()
    if !readable {
        printer.printReadably = false
    }
    return printer
}

/// Renders `args` space-separated, appends `terminator`. Shared by all four `*-str` fns
/// and by `writeRendered`.
private func renderArgs(_ evaluator: Evaluator, _ args: [Expr], readable: Bool, terminator: String) -> String {
    let printer = outputPrinter(evaluator, readable: readable)
    return args.map { printer.printString($0) }.joined(separator: " ") + terminator
}

/// Backs `print`/`println`/`pr`/`prn` — the four differ only in `readable` and `terminator`.
private func writeRendered(_ evaluator: Evaluator, args: [Expr], readable: Bool, terminator: String) throws -> Expr {
    try writeToOut(evaluator, renderArgs(evaluator, args, readable: readable, terminator: terminator))
    return .nil
}

/// Backs the four `*-str` fns — the same rendering, returned instead of written.
private func printToStringFn(_ evaluator: Evaluator, readable: Bool, terminator: String) -> @Sendable ([Expr]) throws -> Expr {
    { [evaluator] args in
        .string(renderArgs(evaluator, args, readable: readable, terminator: terminator))
    }
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
    let name = try requireSymbol(args[0], function: "print-doc")
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
