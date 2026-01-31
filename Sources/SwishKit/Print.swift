import Foundation

/// Printer for Swish expressions
public class Printer {
    private let numberFormatter: NumberFormatter

    public init(locale: Locale = .current) {
        numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.locale = locale
    }

    /// Returns a human-readable string representation of a Swish expression
    public func printString(_ expr: Expr) -> String {
        switch expr {
        case .integer(let value):
            return numberFormatter.string(from: NSNumber(value: value)) ?? String(value)
        }
    }
}
