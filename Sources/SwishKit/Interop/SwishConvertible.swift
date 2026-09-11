import Foundation

/// A Swift value that can be handed to Swish.
///
/// Conformance is what lets a type be returned from a function registered with
/// `Swish.register(_:as:)`, passed to `Swish.call(_:_:)`, or installed as a
/// constant with `Swish.define(_:as:)`.
public protocol SwishRepresentable {
    /// This value as a Swish expression.
    var swishValue: Expr { get }
}

/// A Swift value that can be reconstructed from a Swish value.
///
/// Conformance is what lets a type be used as a parameter of a function
/// registered with `Swish.register(_:as:)`, or as the result of
/// `Swish.call(_:_:)`.
public protocol SwishDecodable {
    /// Creates a value from `swishValue`, or returns nil when the Swish value
    /// is not a compatible shape. Returning nil produces a Swish-level argument
    /// error naming the parameter position and the expected Swift type.
    init?(swishValue: Expr)
}

/// A Swift type that crosses the Swish boundary in both directions.
public typealias SwishConvertible = SwishRepresentable & SwishDecodable

/// Opts a Swift type into passing through Swish as an opaque handle.
///
/// Conforming is the entire host-side cost — the default implementations box the
/// value into a `ForeignObject` on the way in and unbox it on the way out:
///
/// ```swift
/// extension User: SwishOpaque {}
///
/// swish.register(loadUser,  as: "load-user")    // (String) -> User
/// swish.register(userName,  as: "user-name")    // (User) -> String
/// ```
///
/// Swish code can then thread `User` values between those two functions without
/// Swish ever knowing what a `User` is.
public protocol SwishOpaque: SwishConvertible {}

public extension SwishOpaque {
    var swishValue: Expr {
        .foreign(ForeignObject(self))
    }

    init?(swishValue: Expr) {
        guard case let .foreign(object) = swishValue,
              let value = object.value as? Self
        else {
            return nil
        }
        self = value
    }
}

/// Marks the parameter types that may be omitted at a Swish call site.
///
/// Only `Optional` conforms. `Swish.register` walks its parameter pack looking
/// for a trailing run of these to compute the registered `Arity` — see
/// `parameterShape(_:)`.
protocol SwishOptionalParameter {}

extension Optional: SwishOptionalParameter {}
