import Foundation

/// Printer for Swish expressions
public class Printer {
    private let floatFormatter: NumberFormatter

    public init() {
        floatFormatter = NumberFormatter()
        floatFormatter.numberStyle = .decimal
        floatFormatter.usesGroupingSeparator = false
        floatFormatter.minimumFractionDigits = 1
        floatFormatter.maximumFractionDigits = 15
    }

    /// Returns a human-readable string representation of a Swish expression
    public func printString(_ expr: Expr) -> String {
        switch expr {
        case .integer(let value):
            return String(value)
        case .float(let value):
            return floatFormatter.string(from: NSNumber(value: value)) ?? String(value)
        case .ratio(let ratio):
            return "\(ratio.numerator)/\(ratio.denominator)"
        }
    }
}
