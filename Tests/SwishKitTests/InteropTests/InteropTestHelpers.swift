import Testing
@testable import SwishKit

/// Asserts that `body` throws one of the `SwishError` types.
///
/// `#expect(throws:)` needs a concrete error type, so it can't express "any
/// conformer of this protocol" — which is exactly what a host catching Swish
/// errors writes.
func expectSwishError<T>(
    _ body: () throws -> T,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    do {
        _ = try body()
        Issue.record("Expected a SwishError, but nothing was thrown", sourceLocation: sourceLocation)
    }
    catch is any SwishError {
        // Expected.
    }
    catch {
        Issue.record("Expected a SwishError, got \(type(of: error)): \(error)",
                     sourceLocation: sourceLocation)
    }
}

/// Runs `body` and returns the resulting error's rendered text, or "" if it
/// unexpectedly succeeded.
func errorText(from body: () throws -> Expr) -> String {
    do {
        _ = try body()
        return ""
    }
    catch {
        return "\(error)"
    }
}
