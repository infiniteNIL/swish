import Foundation

// Evaluator-side support for the host embedding API. Everything here is
// internal: hosts reach it only through the `Swish` façade.
extension Evaluator {
    /// Interns `value` under `name`, by default in clojure.core.
    func define(_ value: Expr, as name: String, in namespace: String? = nil) {
        let target = namespace.map { findOrCreateNs($0) } ?? findNs("clojure.core")!
        let v = target.intern(name: name, value: value)
        if target.name == "clojure.core" {
            backFillReferral(of: v, named: name)
        }
    }

    /// Looks up a callable bound to `name`, which may be namespace-qualified
    /// (`"clojure.string/upper-case"`) or resolved in the current namespace.
    func function(named name: String) throws -> Expr {
        let v: Var?
        if name.contains("/") {
            v = try resolveQualifiedVar(name: name)
        }
        else {
            v = currentNs().findVar(name: name)
        }
        guard let v else {
            throw EvaluatorError.undefinedSymbol(name)
        }
        guard let value = v.value else {
            throw EvaluatorError.unboundVar(name)
        }
        return value
    }

    /// Converts an error thrown out of a registered Swift function into
    /// something Swish code can catch meaningfully.
    ///
    /// Without this, `exprForError` stringifies any non-`SwishException` error,
    /// so a host error could only be caught as a bare `String`. Wrapping it in
    /// core's own `ExceptionInfo` means `(catch ExceptionInfo e …)`,
    /// `(ex-message e)` and `(ex-data e)` all behave. Built by *calling*
    /// `ex-info` rather than constructing the record here, so the record's type
    /// name stays whatever `core.clj` defines it as.
    ///
    /// Errors that are already Swish-level pass through untouched: a Swish
    /// `throw` (`SwishException`), and interpreter errors such as the argument
    /// conversion failure raised by `ArgumentCursor`.
    func hostException(_ error: Error, function: String) -> Error {
        if error is SwishException || error is EvaluatorError {
            return error
        }
        let data = Expr.map([
            .keyword("swift-error"): .string("\(error)"),
            .keyword("swift-error-type"): .string("\(type(of: error))"),
            .keyword("function"): .string(function),
        ], metadata: nil)
        guard let exInfo = findNs("clojure.core")?.findVar(name: "ex-info")?.value,
              let value = try? call(exInfo, args: [.string("\(error)"), data])
        else {
            return error
        }
        return SwishException(value: value)
    }
}
