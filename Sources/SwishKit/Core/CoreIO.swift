private let printer = Printer()

// MARK: - Registration

func registerIO(into evaluator: Evaluator) {
    evaluator.register(name: "print",   arity: .variadic, body: corePrint)
    evaluator.register(name: "println", arity: .variadic, body: corePrintln)
}

// MARK: - Implementations

private func corePrint(_ args: [Expr]) throws -> Expr {
    Swift.print(args.map { printer.strString($0) }.joined(separator: " "), terminator: "")
    return .nil
}

private func corePrintln(_ args: [Expr]) throws -> Expr {
    Swift.print(args.map { printer.strString($0) }.joined(separator: " "))
    return .nil
}
