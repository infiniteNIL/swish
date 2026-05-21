// MARK: - Registration

func registerIO(into evaluator: Evaluator) {
    evaluator.register(name: "print", arity: .variadic,
        doc: "Prints the object(s) to the output stream that is the current value of *out*. print and println produce output for human consumption.",
        arglists: [["&", "more"]],
        body: corePrint)
    evaluator.register(name: "println", arity: .variadic,
        doc: "Same as print followed by (newline)",
        arglists: [["&", "more"]],
        body: corePrintln)
    evaluator.register(name: "print-doc", arity: .fixed(1),
        doc: "Prints formatted documentation for the var named by symbol to *out*.",
        arglists: [["sym"]]) { [evaluator] args in try corePrintDoc(evaluator, args) }
}

// MARK: - Implementations

private func printArgs(_ args: [Expr], terminator: String) {
    Swift.print(args.map { corePrinter.strString($0) }.joined(separator: " "), terminator: terminator)
}

private func corePrint(_ args: [Expr]) throws -> Expr {
    printArgs(args, terminator: "")
    return .nil
}

private func corePrintln(_ args: [Expr]) throws -> Expr {
    printArgs(args, terminator: "\n")
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
