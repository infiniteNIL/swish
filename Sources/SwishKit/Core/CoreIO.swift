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
    evaluator.register(name: "print-doc", arity: .fixed(1),
        doc: "Prints formatted documentation for the var named by symbol to *out*.",
        arglists: [["sym"]]) { [evaluator] args in try corePrintDoc(evaluator, args) }

    evaluator.register(name: "read-string", arity: .fixed(1),
        doc: "Reads one object from the string s. Returns the first Swish data " +
             "structure read. Does not evaluate.",
        arglists: [["s"]],
        body: coreReadString)

    evaluator.register(name: "reader?", arity: .fixed(1),
        doc: "Returns true if x is a SwishReader.",
        arglists: [["x"]]) { args in
        if case .reader = args[0] { return .boolean(true) }
        return .boolean(false)
    }
    evaluator.register(name: "writer?", arity: .fixed(1),
        doc: "Returns true if x is a SwishWriter.",
        arglists: [["x"]]) { args in
        if case .writer = args[0] { return .boolean(true) }
        return .boolean(false)
    }
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
    do {
        let exprs = try Reader.readString(source)
        guard let first = exprs.first else {
            throw EvaluatorError.invalidArgument(function: "read-string",
                message: "no forms found in string")
        }
        return first
    }
    catch {
        throw EvaluatorError.invalidArgument(function: "read-string",
            message: error.localizedDescription)
    }
}

// MARK: - Print implementations

private func coreOutput(_ evaluator: Evaluator, args: [Expr], terminator: String) throws -> Expr {
    let s = args.map { corePrinter.strString($0) }.joined(separator: " ")
    switch evaluator.currentOut() {
    case .writer(let wtr):
        do { try wtr.write(s + terminator) }
        catch { throw EvaluatorError.invalidArgument(function: "print", message: error.localizedDescription) }
    default:
        Swift.print(s, terminator: terminator)
    }
    return .nil
}

private func corePrintDoc(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .symbol(let name, _) = args[0]
    else {
        throw EvaluatorError.invalidArgument(
            function: "print-doc",
            message: "argument must be a symbol")
    }
    if let ns = evaluator.findNs(name) {
        Swift.print(String(repeating: "-", count: 25))
        Swift.print(ns.name)
        if let meta = ns.metadata, case .string(let doc) = meta[.keyword("doc")] {
            for line in doc.components(separatedBy: "\n") {
                Swift.print("  \(line)")
            }
        }
        return .nil
    }
    let v = (try? evaluator.resolveQualifiedVar(name: name)) ?? nil
              ?? evaluator.resolveVar(name: name, in: evaluator.currentNs())
    guard let v else {
        Swift.print("No doc found for \(name)")
        return .nil
    }
    Swift.print(String(repeating: "-", count: 25))
    Swift.print("\(v.namespace.name)/\(v.name)")
    if let meta = v.metadata {
        if let arglists = meta[.keyword("arglists")] {
            Swift.print(corePrinter.printString(arglists))
        }
        if case .string(let doc) = meta[.keyword("doc")] {
            for line in doc.components(separatedBy: "\n") {
                Swift.print("  \(line)")
            }
        }
    }
    return .nil
}

// MARK: - File I/O implementations

private func parseEncodingOpt(_ opts: ArraySlice<Expr>) -> String.Encoding? {
    let opts = Array(opts)
    var i = 0
    while i + 1 < opts.count {
        if case .keyword(let k) = opts[i], k == "encoding",
           case .string(let enc) = opts[i + 1] {
            switch enc.uppercased() {
            case "UTF-8", "UTF8":
                return .utf8
            case "UTF-16", "UTF16":
                return .utf16
            case "ISO-8859-1", "ISO8859-1", "LATIN1":
                return .isoLatin1
            case "ASCII":
                return .ascii
            default:
                return .utf8
            }
        }
        i += 2
    }
    return nil
}

private func parseAppendOpt(_ opts: ArraySlice<Expr>) -> Bool {
    let opts = Array(opts)
    var i = 0
    while i + 1 < opts.count {
        if case .keyword(let k) = opts[i], k == "append",
           case .boolean(let b) = opts[i + 1] {
            return b
        }
        i += 2
    }
    return false
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
