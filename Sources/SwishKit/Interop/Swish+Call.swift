import Foundation

public extension Swish {
    /// Calls a Swish function from Swift, converting the arguments on the way in
    /// and the result on the way out.
    ///
    /// ```swift
    /// let greeting: String = try swish.call("hello", "Swish")
    /// ```
    ///
    /// Preferable to building a source string for `eval` — no quoting or
    /// escaping, and a value that is not a valid literal (a `Date`, or one of
    /// your own `SwishOpaque` types) can be passed directly.
    ///
    /// - Parameters:
    ///   - name: The function's name, either namespace-qualified
    ///     (`"clojure.string/upper-case"`) or resolved in the current namespace.
    ///   - args: Arguments, converted with their `SwishRepresentable` conformance.
    /// - Returns: The result, converted to `R`.
    /// - Throws: `SwishConversionError` if the result is not an `R`, and
    ///   whatever the Swish function itself throws.
    func call<R: SwishDecodable>(_ name: String, _ args: (any SwishRepresentable)...) throws -> R {
        let result = try callReturningExpr(name, args)
        guard let value = R(swishValue: result) else {
            throw SwishConversionError(expected: "\(R.self)", value: result)
        }
        return value
    }

    /// Calls a Swish function and returns its result as a raw Swish value.
    @discardableResult
    func call(_ name: String, _ args: (any SwishRepresentable)...) throws -> Expr {
        try callReturningExpr(name, args)
    }

    private func callReturningExpr(_ name: String, _ args: [any SwishRepresentable]) throws -> Expr {
        let callee = try evaluator.function(named: name)
        return try evaluator.call(callee, args: args.map(\.swishValue))
    }
}
