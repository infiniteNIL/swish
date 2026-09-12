import Foundation

// MARK: - Typed evaluation

public extension Swish {
    /// Evaluates Swish source and converts the result to a Swift value.
    ///
    /// ```swift
    /// let numbers: [Int] = try swish.eval("(range 1 4)")
    /// let tally = try swish.eval("{:a 1 :b 2}", as: [String: Int].self)
    /// ```
    ///
    /// The `as:` argument is usually inferred from context; pass it explicitly
    /// where there is nothing to infer from, such as inside an interpolation.
    ///
    /// - Throws: `SwishConversionError` if the result isn't a `T`, plus whatever
    ///   reading and evaluating the source throws.
    func eval<T: SwishDecodable>(_ source: String, as type: T.Type = T.self) throws -> T {
        try eval(source).decode(T.self)
    }
}

// MARK: - Typed conversion

public extension Expr {
    /// This value as `T`.
    ///
    /// The throwing counterpart of `T(swishValue:)` — use this when you want to
    /// know *what* failed, and `T(swishValue:)` when an optional is enough.
    ///
    /// - Throws: `SwishConversionError` naming the expected type and the value —
    ///   or, for a `SwishCodable` type, the underlying `DecodingError` naming the
    ///   field that failed.
    func decode<T: SwishDecodable>(_ type: T.Type = T.self) throws -> T {
        // A `SwishCodable`'s `init?(swishValue:)` default swallows the
        // `DecodingError` to satisfy the failable initializer, which would throw
        // away the field-level diagnosis that is the whole point of the bridge.
        // Go straight to the decoder so the error survives.
        if let codableType = T.self as? any SwishCodable.Type {
            guard let value = try codableType.decodedFromSwish(self) as? T else {
                throw SwishConversionError(expected: "\(T.self)", value: self)
            }
            return value
        }
        guard let value = T(swishValue: self) else {
            throw SwishConversionError(expected: "\(T.self)", value: self)
        }
        return value
    }
}

// MARK: - Calling function values

public extension Swish {
    /// Looks up a Swish function by name without calling it.
    ///
    /// Worth doing when the same function is called repeatedly —
    /// `call(_ name:_:)` re-resolves the var every time.
    ///
    /// - Parameter name: Either namespace-qualified (`"clojure.string/upper-case"`)
    ///   or resolved in the current namespace.
    func function(named name: String) throws -> Expr {
        try evaluator.function(named: name)
    }

    /// Calls a Swish function *value* — one obtained from `eval`, `function(named:)`,
    /// or handed back by Swish code — converting the result.
    ///
    /// ```swift
    /// let double = try swish.eval("(fn [x] (* x 2))")
    /// let six: Int = try swish.call(double, 3)
    /// ```
    ///
    /// - Note: Swish callables include more than functions — a keyword, map, vector
    ///   or set is callable too, exactly as in Clojure, so `swish.call(.keyword("a"), map)`
    ///   works. A *macro* value is expanded but not evaluated, so calling one
    ///   returns the expansion form rather than a result.
    func call<R: SwishDecodable>(_ function: Expr, _ args: (any SwishRepresentable)...) throws -> R {
        try call(function, arguments: args)
    }

    /// Calls a Swish function value and returns its result as a raw Swish value.
    @discardableResult
    func call(_ function: Expr, _ args: (any SwishRepresentable)...) throws -> Expr {
        try evaluator.call(function, args: try args.map(swishValue(of:)))
    }

    /// Calls a Swish function value with a pre-built argument list.
    ///
    /// The variadic forms can't be used when the arguments are assembled at
    /// runtime; this can.
    func call<R: SwishDecodable>(_ function: Expr, arguments: [any SwishRepresentable]) throws -> R {
        try evaluator.call(function, args: try arguments.map(swishValue(of:))).decode(R.self)
    }

    /// Calls a Swish function value with a pre-built argument list, returning a
    /// raw Swish value.
    @discardableResult
    func call(_ function: Expr, arguments: [any SwishRepresentable]) throws -> Expr {
        try evaluator.call(function, args: try arguments.map(swishValue(of:)))
    }

    /// Calls a named Swish function with a pre-built argument list.
    func call<R: SwishDecodable>(_ name: String, arguments: [any SwishRepresentable]) throws -> R {
        try call(function(named: name), arguments: arguments)
    }

    /// Calls a named Swish function with a pre-built argument list, returning a
    /// raw Swish value.
    @discardableResult
    func call(_ name: String, arguments: [any SwishRepresentable]) throws -> Expr {
        try call(function(named: name), arguments: arguments)
    }
}
