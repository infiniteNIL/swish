import Foundation

/// The umbrella for everything Swish throws.
///
/// The interpreter raises several unrelated error types — reader errors,
/// evaluation errors, namespace errors, and values thrown by Swish code itself.
/// Rather than wrap them (which would hide which one you actually got), they all
/// conform to this, so a host can catch the lot in one clause and still switch
/// on the specific type when it wants to:
///
/// ```swift
/// do {
///     try swish.load(filename: "app.swish")
/// }
/// catch let error as any SwishError {
///     print("Swish: \(error)")
/// }
/// ```
///
/// Every conformer is `CustomStringConvertible`, so interpolating the error
/// gives the same message the REPL would print.
public protocol SwishError: Error, CustomStringConvertible {}

extension LexerError: SwishError {}

extension ParserError: SwishError {}

extension EvaluatorError: SwishError {}

extension NamespaceError: SwishError {}

extension SwishException: SwishError {
    public var description: String {
        corePrinter.strString(value)
    }
}

/// A Swish value could not be converted to the Swift type that was asked for.
/// Thrown by `Swish.call(_:_:)` when the result doesn't fit.
public struct SwishConversionError: SwishError {
    /// The Swift type that was expected, as a name.
    public let expected: String

    /// The value that could not be converted.
    public let value: Expr

    public init(expected: String, value: Expr) {
        self.expected = expected
        self.value = value
    }

    public var description: String {
        "Cannot convert \(corePrinter.printString(value)) to \(expected)."
    }
}

/// A Swish source file could not be loaded.
public enum SwishLoadError: SwishError {
    /// No file by that name was found on any of the configured source paths.
    case fileNotFound(String, searched: [String])

    public var description: String {
        switch self {
        case .fileNotFound(let filename, let searched):
            return "Swish file '\(filename)' not found. Searched: \(searched.joined(separator: ", "))."
        }
    }
}
