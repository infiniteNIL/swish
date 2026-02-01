import Foundation

/// Printer for Swish expressions
public class Printer {
    private let integerFormatter: NumberFormatter
    private let floatFormatter: NumberFormatter

    public init(locale: Locale = .current) {
        integerFormatter = NumberFormatter()
        integerFormatter.numberStyle = .decimal
        integerFormatter.locale = locale

        floatFormatter = NumberFormatter()
        floatFormatter.numberStyle = .decimal
        floatFormatter.locale = locale
        floatFormatter.minimumFractionDigits = 1
        floatFormatter.maximumFractionDigits = 15
    }

    /// Returns a human-readable string representation of a Swish expression
    public func printString(_ expr: Expr) -> String {
        switch expr {
        case .integer(let value):
            return integerFormatter.string(from: NSNumber(value: value)) ?? String(value)
        case .float(let value):
            return floatFormatter.string(from: NSNumber(value: value)) ?? String(value)
        }
    }
}
