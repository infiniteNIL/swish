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

        case .character(let char):
            printCharacter(char)

        case .boolean(let value):
            value ? "true" : "false"

        case .nil:
            "nil"

        case .symbol(let name):
            name
        }
    }

    private func printCharacter(_ char: Character) -> String {
        switch char {
        case "\n": return "\\newline"
        case "\t": return "\\tab"
        case " ": return "\\space"
        case "\r": return "\\return"
        case "\u{0008}": return "\\backspace"
        case "\u{000C}": return "\\formfeed"
        default: return "\\\(char)"
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
