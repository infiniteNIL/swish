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
            String(value)

        case .float(let value):
            floatFormatter.string(from: NSNumber(value: value)) ?? String(value)

        case .ratio(let ratio):
            "\(ratio.numerator)/\(ratio.denominator)"

        case .string(let value):
            "\"\(escapeString(value))\""
        }
    }

    private func escapeString(_ s: String) -> String {
        var result = ""
        for char in s {
            switch char {
            case "\"": result.append("\\\"")
            case "\\": result.append("\\\\")
            case "\n": result.append("\\n")
            case "\t": result.append("\\t")
            case "\r": result.append("\\r")
            case "\0": result.append("\\0")
            default: result.append(char)
            }
        }
        return result
    }
}
