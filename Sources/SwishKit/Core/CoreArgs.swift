import Foundation
import BigDecimal

/// Shared argument extraction and arity checking for native (`Expr.nativeFunction`)
/// bodies, replacing the ~160 hand-written
/// `guard case .X(let y) = args[i] else { throw .invalidArgument(…) }` blocks that
/// were spread across `Core/` and the evaluator extensions (along with three
/// mutually-invisible `private` copies of the same idea).
///
/// Every helper follows one shape: unwrap the expected `Expr` payload, or throw
/// `EvaluatorError.invalidArgument` naming `function`.
///
/// **`message` is an `@autoclosure`** so a call site that interpolates the offending
/// value — `"… got \(corePrinter.printString(x))"`, by far the most common form — pays
/// the string formatting only on the throwing path, never on the successful one. These
/// sit on the native-call hot path, so that matters.
///
/// **Message text stays per-call-site.** The defaults below cover only the dominant
/// wording; anything else is passed explicitly rather than unified. Several Swift tests
/// assert on exact message text, and two call sites wording the same failure differently
/// is not worth a behavior change to fix.

// MARK: - Arity

/// `"requires <lo> or <hi> arguments, got <n>"` for an adjacent pair (the shape every
/// current call site uses), `"requires <lo> to <hi> arguments, got <n>"` for a wider range.
func requireArgCount(_ args: [Expr], in range: ClosedRange<Int>, function: String) throws {
    guard !range.contains(args.count) else { return }
    let bounds = range.count == 2
        ? "\(range.lowerBound) or \(range.upperBound)"
        : "\(range.lowerBound) to \(range.upperBound)"
    throw EvaluatorError.invalidArgument(
        function: function,
        message: "requires \(bounds) arguments, got \(args.count)")
}

/// `"requires at least <n> argument(s)"` — singular for `n == 1`, matching the existing
/// `-` / `/` wording that tests assert on.
func requireArgCount(_ args: [Expr], atLeast n: Int, function: String) throws {
    guard args.count < n else { return }
    let noun = n == 1 ? "argument" : "arguments"
    throw EvaluatorError.invalidArgument(
        function: function,
        message: "requires at least \(n) \(noun)")
}

/// `"requires exactly <n> argument(s)"`.
func requireArgCount(_ args: [Expr], exactly n: Int, function: String) throws {
    guard args.count != n else { return }
    let noun = n == 1 ? "argument" : "arguments"
    throw EvaluatorError.invalidArgument(
        function: function,
        message: "requires exactly \(n) \(noun)")
}

// MARK: - Scalars

func requireString(_ arg: Expr, function: String,
                   message: @autoclosure () -> String = "argument must be a string") throws -> String {
    guard case .string(let s) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return s
}

/// `str`-coerces any non-nil value to its printed form. Distinct from `requireString`:
/// the `clojure.string` fns that accept "anything but nil" (`upper-case`, `replace`,
/// `starts-with?`, …) go through this, matching Clojure's `^CharSequence` coercion.
func requireNonNilStr(_ arg: Expr, function: String,
                      message: @autoclosure () -> String = "argument must not be nil") throws -> String {
    guard case .nil = arg else {
        return corePrinter.strString(arg)
    }
    throw EvaluatorError.invalidArgument(function: function, message: message())
}

func requireInteger(_ arg: Expr, function: String,
                    message: @autoclosure () -> String = "argument must be an integer") throws -> Int {
    guard case .integer(let n) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return n
}

func requireBigDecimal(_ arg: Expr, function: String,
                       message: @autoclosure () -> String = "argument must be a BigDecimal") throws -> BigDecimal {
    guard case .bigDecimal(let bd) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return bd
}

func requireCharacter(_ arg: Expr, function: String,
                      message: @autoclosure () -> String = "argument must be a character") throws -> Character {
    guard case .character(let c) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return c
}

func requireKeyword(_ arg: Expr, function: String,
                    message: @autoclosure () -> String = "argument must be a keyword") throws -> String {
    guard case .keyword(let k) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return k
}

/// The symbol's name. Use `requireSymbolWithMeta` when the caller also needs the
/// symbol's reader metadata (`intern`, `deftype` field annotations).
func requireSymbol(_ arg: Expr, function: String,
                   message: @autoclosure () -> String = "argument must be a symbol") throws -> String {
    guard case .symbol(let name, _) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return name
}

func requireSymbolWithMeta(_ arg: Expr, function: String,
                           message: @autoclosure () -> String = "argument must be a symbol") throws -> (name: String, metadata: [Expr: Expr]?) {
    guard case .symbol(let name, let meta) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return (name, meta)
}

// MARK: - Collections

func requireMap(_ arg: Expr, function: String,
                message: @autoclosure () -> String = "argument must be a map") throws -> SwishMap {
    guard case .map(let sm) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return sm
}

func requireVector(_ arg: Expr, function: String,
                   message: @autoclosure () -> String = "argument must be a vector") throws -> SwishPersistentVector {
    guard case .vector(let v, _) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return v
}

func requireSet(_ arg: Expr, function: String,
                message: @autoclosure () -> String = "argument must be a set") throws -> SwishSet {
    guard case .set(let ss) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return ss
}

/// The Java-style `.array` backing (`aset`/`aget`/`alength`/`aclone`). Note this is
/// *not* satisfied by `.sharedVector`, which shares the same `SwishArray` storage but
/// is a vector to Clojure code.
func requireArray(_ arg: Expr, function: String,
                  message: @autoclosure () -> String = "argument must be an array") throws -> SwishArray {
    guard case .array(let sa) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return sa
}

// MARK: - Reference types

func requireAtom(_ arg: Expr, function: String,
                 message: @autoclosure () -> String = "argument must be an atom") throws -> SwishAtom {
    guard case .atom(let a) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return a
}

func requireAgent(_ arg: Expr, function: String,
                  message: @autoclosure () -> String = "argument must be an agent") throws -> SwishAgent {
    guard case .agent(let a) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return a
}

func requireFuture(_ arg: Expr, function: String,
                   message: @autoclosure () -> String = "argument must be a future") throws -> FutureBox {
    guard case .future(let box) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return box
}

func requirePromise(_ arg: Expr, function: String,
                    message: @autoclosure () -> String = "argument must be a promise") throws -> PromiseBox {
    guard case .promise(let box) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return box
}

func requireRef(_ arg: Expr, function: String,
                message: @autoclosure () -> String = "argument must be a ref") throws -> SwishRef {
    guard case .ref(let r) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return r
}

func requireVarRef(_ arg: Expr, function: String,
                   message: @autoclosure () -> String = "argument must be a var") throws -> Var {
    guard case .varRef(let v) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return v
}

func requireNamespaceValue(_ arg: Expr, function: String,
                           message: @autoclosure () -> String = "argument must be a namespace") throws -> Namespace {
    guard case .namespace(let ns) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return ns
}

func requireRegex(_ arg: Expr, function: String,
                  message: @autoclosure () -> String = "argument must be a regex") throws -> SwishRegex {
    guard case .regex(let re) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return re
}

func requireMatcher(_ arg: Expr, function: String,
                    message: @autoclosure () -> String = "argument must be a matcher") throws -> SwishMatcher {
    guard case .matcher(let m) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return m
}

// MARK: - I/O handles

func requireReader(_ arg: Expr, function: String,
                   message: @autoclosure () -> String = "argument must be a reader") throws -> SwishReader {
    guard case .reader(let rdr) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return rdr
}

func requireWriter(_ arg: Expr, function: String,
                   message: @autoclosure () -> String = "argument must be a writer") throws -> SwishWriter {
    guard case .writer(let wtr) = arg else {
        throw EvaluatorError.invalidArgument(function: function, message: message())
    }
    return wtr
}
