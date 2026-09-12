import Foundation

// MARK: - Registering Swift functions

public extension Swish {
    /// Makes a Swift function callable from Swish.
    ///
    /// The function is used as-is — no wrapper, no `Expr` handling. Arguments are
    /// converted from Swish values to the parameter types and the result is
    /// converted back, so any type conforming to `SwishDecodable` /
    /// `SwishRepresentable` just works:
    ///
    /// ```swift
    /// swish.register(getVowels, as: "get-vowels")   // (String) -> [Character]
    /// ```
    /// ```clojure
    /// (get-vowels "hello")   ;=> [\e \o]
    /// ```
    ///
    /// A trailing run of `Optional` parameters may be omitted at the call site;
    /// everything before the first optional is required. Use an `Expr` parameter
    /// to receive a Swish value the bridge has no Swift equivalent for, and
    /// `SwishOpaque` to pass your own types through untouched.
    ///
    /// Errors thrown by `fn` surface in Swish as an `ExceptionInfo`, catchable
    /// with `(catch ExceptionInfo e …)`; `ex-data` carries the Swift error.
    ///
    /// - Important: `fn` is invoked synchronously on whatever thread evaluates
    ///   the calling form. Swish runs agents, futures, and STM commits on
    ///   background queues, so a function isolated to an actor (a `@MainActor`
    ///   view-model method, say) is only safe if you confine evaluation to that
    ///   actor's thread.
    ///
    /// - Parameters:
    ///   - fn: The Swift function to expose.
    ///   - name: The Swish name to bind it to.
    ///   - namespace: The namespace to intern it in, created if absent. Defaults
    ///     to `clojure.core`, which makes the name available unqualified.
    ///   - doc: Docstring, readable from Swish with `(doc name)`.
    ///   - parameters: Parameter names for `(doc name)`'s arglists. Swift can't
    ///     reflect them, so they default to `arg1`, `arg2`, … .
    @discardableResult
    func register<each A: SwishDecodable & SendableMetatype, R: SwishRepresentable & SendableMetatype>(
        _ fn: @escaping (repeat each A) throws -> R,
        as name: String,
        in namespace: String? = nil,
        doc: String? = nil,
        parameters: [String]? = nil
    ) -> Self {
        // `fn` is not `Sendable`, but the native-function body must be. The host
        // owns thread-safety here (see the threading note above), so vouch for
        // the capture rather than forcing every call site to prove it.
        //
        // This has to be a direct local capture: a pack-typed function cannot be
        // stored in a generic box ("cannot fully abstract a value of variadic
        // function type"), which rules out the usual @unchecked Sendable wrapper.
        nonisolated(unsafe) let fn = fn
        let shape = parameterShape(repeat (each A).self, named: parameters)
        evaluator.register(name: name, arity: shape.arity, in: namespace, doc: doc,
                           arglists: shape.arglists) { [evaluator] args in
            let cursor = ArgumentCursor(args: args, function: name)
            do {
                return try swishValue(of: fn(repeat cursor.next((each A).self)))
            }
            catch {
                throw evaluator.hostException(error, function: name)
            }
        }
        return self
    }

    /// Makes a Swift function that returns nothing callable from Swish; it
    /// evaluates to `nil` there. Otherwise identical to
    /// ``register(_:as:in:doc:)``.
    @discardableResult
    func register<each A: SwishDecodable & SendableMetatype>(
        _ fn: @escaping (repeat each A) throws -> Void,
        as name: String,
        in namespace: String? = nil,
        doc: String? = nil,
        parameters: [String]? = nil
    ) -> Self {
        nonisolated(unsafe) let fn = fn
        let shape = parameterShape(repeat (each A).self, named: parameters)
        evaluator.register(name: name, arity: shape.arity, in: namespace, doc: doc,
                           arglists: shape.arglists) { [evaluator] args in
            let cursor = ArgumentCursor(args: args, function: name)
            do {
                try fn(repeat cursor.next((each A).self))
                return .nil
            }
            catch {
                throw evaluator.hostException(error, function: name)
            }
        }
        return self
    }

    /// Registers a function that receives its arguments as raw Swish values.
    ///
    /// The escape hatch for shapes the typed form can't express — a genuinely
    /// variadic function (`& rest`), or one that inspects its arguments before
    /// deciding how to interpret them.
    @discardableResult
    func register(
        as name: String,
        arity: Arity,
        in namespace: String? = nil,
        doc: String? = nil,
        body: @escaping @Sendable ([Expr]) throws -> Expr
    ) -> Self {
        evaluator.register(name: name, arity: arity, in: namespace, doc: doc) { [evaluator] args in
            do {
                return try body(args)
            }
            catch {
                throw evaluator.hostException(error, function: name)
            }
        }
        return self
    }

    /// Binds a constant, readable from Swish as `name`.
    @discardableResult
    func define(_ value: some SwishRepresentable, as name: String, in namespace: String? = nil) throws -> Self {
        evaluator.define(try swishValue(of: value), as: name, in: namespace)
        return self
    }
}

// MARK: - Parameter pack inspection

/// The registered shape of a parameter pack: how many arguments the Swish
/// function takes, and the `:arglists` metadata describing them.
struct ParameterShape {
    var arity: Arity
    var arglists: [[String]]
}

/// Walks a parameter-pack's types to derive the registered arity.
///
/// A trailing run of `Optional` parameters is optional at the call site, so the
/// arity is a range from "everything up to the last non-optional" to "all of
/// them". Uses pack *iteration*: pack expansion into an array literal is
/// rejected by the compiler ("value pack expansion can only appear inside a
/// function argument list, tuple element, or as the expression of a for-in
/// loop").
func parameterShape<each A>(_ types: repeat (each A).Type, named supplied: [String]?) -> ParameterShape {
    var names: [String] = []
    var required = 0
    for type in repeat each types {
        let position = names.count
        names.append(supplied?.indices.contains(position) == true ? supplied![position] : "arg\(position + 1)")
        if !(type is any SwishOptionalParameter.Type) {
            required = names.count
        }
    }
    let arity: Arity = required == names.count ? .fixed(names.count) : .range(required...names.count)
    // One arglist per legal call shape, so `(doc f)` shows the optional tail.
    let arglists = (required...names.count).map { Array(names.prefix($0)) }
    return ParameterShape(arity: arity, arglists: arglists)
}

// MARK: - Argument marshalling

/// Hands out successive arguments from a native call, converted to the Swift
/// type each parameter wants.
///
/// A class rather than an `inout` index because it is advanced from inside a
/// parameter-pack expansion, where `inout` is not usable; Swift evaluates call
/// arguments left to right, so the cursor tracks parameter order.
final class ArgumentCursor {
    private let args: [Expr]
    private let function: String
    private var index = 0

    init(args: [Expr], function: String) {
        self.args = args
        self.function = function
    }

    /// The next argument as `T`. Past the end of the argument list this yields
    /// `.nil`, which is what lets an omitted trailing `Optional` parameter decode
    /// as `nil` rather than failing.
    func next<T: SwishDecodable>(_ type: T.Type) throws -> T {
        let position = index
        index += 1
        let raw = position < args.count ? args[position] : Expr.nil
        guard let value = T(swishValue: raw) else {
            throw EvaluatorError.invalidArgument(
                function: function,
                message: "argument \(position + 1) must be a \(T.self), got \(corePrinter.printString(raw))")
        }
        return value
    }
}
