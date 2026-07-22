import Foundation

// MARK: - Registration

func registerString(into evaluator: Evaluator) {
    evaluator.register(name: "str", arity: .variadic,
        doc: "With no args, returns the empty string. With one arg x, returns x.toString(). (str nil) returns the empty string. With more than one arg, returns the concatenation of the str values of the args.",
        arglists: [[], ["x"], ["x", "&", "ys"]],
        body: coreStr)
    evaluator.register(name: "subs", arity: .variadic,
        doc: "Returns the substring of s beginning at start inclusive, and ending at end (defaults to length of string), exclusive.",
        arglists: [["s", "start"], ["s", "start", "end"]],
        body: coreSubs)
    evaluator.register(name: "format", arity: .atLeastOne,
        doc: "Formats a string using Foundation's String(format:) directive syntax. Note: this follows Swift/Foundation's printf dialect, not Java's java.util.Formatter that real Clojure delegates to — see Known Limitations in CLAUDE.md.",
        arglists: [["fmt"], ["fmt", "&", "args"]],
        body: coreFormat)
}

// MARK: - Implementations

private func coreStr(_ args: [Expr]) throws -> Expr {
    .string(args.map { corePrinter.strString($0) }.joined())
}

// String(format:) marshals each vararg per its own Swift type, but C varargs
// have no type safety: a directive dictates what shape of value it expects
// regardless of what an Expr's natural Swift type would otherwise suggest.
// %s given a raw Int, or a numeric directive given a C string pointer, is
// undefined behavior — confirmed to crash the process, not just misformat.
// So arguments are marshaled per their *directive's* expected shape (scanned
// from the format string below), not per the Expr's own type.
private enum FormatArgShape {
    case string
    case numeric
    case none  // consumes no argument (%%, %n)
}

private func formatDirectiveShapes(_ fmt: String) -> [FormatArgShape] {
    var shapes: [FormatArgShape] = []
    let chars = Array(fmt)
    var i = 0
    while i < chars.count {
        guard chars[i] == "%" else { i += 1; continue }
        i += 1
        guard i < chars.count else { break }
        if chars[i] == "%" { i += 1; continue }  // %% is a literal percent, consumes no arg
        while i < chars.count, "0123456789.-+ #,$".contains(chars[i]) { i += 1 }
        guard i < chars.count else { break }
        let conversion = chars[i]
        i += 1
        switch conversion {
        case "n":
            shapes.append(.none)

        case "d", "i", "u", "o", "x", "X", "f", "e", "E", "g", "G", "a", "A", "c", "C":
            shapes.append(.numeric)

        default:
            shapes.append(.string)
        }
    }
    return shapes
}

private func coreFormat(_ args: [Expr]) throws -> Expr {
    guard case .string(let fmt) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "format",
            message: "format string must be a string, got \(corePrinter.printString(args[0]))")
    }
    let formatArgs = Array(args.dropFirst())
    // keepAlive holds each %s argument's backing NSString for the duration
    // of this call, so its .utf8String pointer stays valid through the
    // String(format:) call below.
    var keepAlive: [NSString] = []
    var cArgs: [CVarArg] = []
    var argIndex = 0
    for shape in formatDirectiveShapes(fmt) {
        if case .none = shape { continue }
        guard argIndex < formatArgs.count else { break }
        let expr = formatArgs[argIndex]
        argIndex += 1
        cArgs.append(try formatCVarArg(expr, shape: shape, keepAlive: &keepAlive))
    }
    return .string(String(format: fmt, arguments: cArgs))
}

private func formatCVarArg(_ expr: Expr, shape: FormatArgShape, keepAlive: inout [NSString]) throws -> CVarArg {
    switch shape {
    case .string, .none:
        let ns = corePrinter.strString(expr) as NSString
        keepAlive.append(ns)
        return ns.utf8String!

    case .numeric:
        switch expr {
        case .integer(let i):
            return i

        case .double(let d):
            return d

        case .float(let f):
            return f

        case .character(let c):
            return Int(c.unicodeScalars.first?.value ?? 0)

        default:
            throw EvaluatorError.invalidArgument(function: "format",
                message: "cannot format \(corePrinter.printString(expr)) with a numeric directive")
        }
    }
}

private func coreSubs(_ args: [Expr]) throws -> Expr {
    guard args.count == 2 || args.count == 3 else {
        throw EvaluatorError.invalidArgument(
            function: "subs",
            message: "requires 2 or 3 arguments, got \(args.count)")
    }
    guard case .string(let s) = args[0] else {
        throw EvaluatorError.invalidArgument(
            function: "subs",
            message: "first argument must be a string")
    }
    guard case .integer(let start) = args[1] else {
        throw EvaluatorError.invalidArgument(
            function: "subs",
            message: "start must be an integer")
    }
    let len = s.count
    let end: Int
    if args.count == 3 {
        guard case .integer(let e) = args[2] else {
            throw EvaluatorError.invalidArgument(
                function: "subs",
                message: "end must be an integer")
        }
        end = e
    }
    else {
        end = len
    }
    guard start >= 0, end >= start, end <= len,
          let startIdx = s.index(s.startIndex, offsetBy: start, limitedBy: s.endIndex),
          let endIdx = s.index(s.startIndex, offsetBy: end, limitedBy: s.endIndex)
    else {
        throw EvaluatorError.invalidArgument(
            function: "subs",
            message: "index out of range (start=\(start), end=\(end), length=\(len))")
    }
    return .string(String(s[startIdx..<endIdx]))
}
