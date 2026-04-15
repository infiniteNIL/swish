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

    /// Returns a machine-readable string representation of a Swish expression.
    /// Strings are quoted and escaped; characters use named forms (e.g. \newline).
    /// Output round-trips through the reader. Backs the planned `pr-str` native function.
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

        case .keyword(let name):
            ":\(name)"

        case .list(let elements):
            "(" + elements.map { printString($0) }.joined(separator: " ") + ")"

        case .vector(let elements):
            "[" + elements.map { printString($0) }.joined(separator: " ") + "]"

        case .function(let name, _, _):
            if let name {
                "#<fn \(name)>"
            }
            else {
                "#<fn>"
            }

        case .macro(let name, _, _):
            if let name {
                "#<macro \(name)>"
            }
            else {
                "#<macro>"
            }

        case .nativeFunction(let name, _, _):
            "#<native-fn \(name)>"
        }
    }

    /// Returns a human-readable string representation of a Swish expression.
    /// Strings print without quotes; characters print as the raw character.
    /// Backs the planned `str` native function. Named `strString` to mirror `printString` → `pr-str`.
    public func strString(_ expr: Expr) -> String {
        switch expr {
        case .string(let value):
            value

        case .character(let char):
            String(char)

        case .list(let elements):
            "(" + elements.map { strString($0) }.joined(separator: " ") + ")"

        case .vector(let elements):
            "[" + elements.map { strString($0) }.joined(separator: " ") + "]"

        default:
            printString(expr)
        }
    }

    /// Returns the source-code form of a Swish expression for use in result substitution.
    /// Like `printString` but floats use `String(value)` for exact round-trip fidelity.
    public func sourceForm(_ expr: Expr) -> String {
        switch expr {
        case .float(let value):
            String(value)

        case .list(let elements):
            "(" + elements.map { sourceForm($0) }.joined(separator: " ") + ")"

        case .vector(let elements):
            "[" + elements.map { sourceForm($0) }.joined(separator: " ") + "]"

        default:
            printString(expr)
        }
    }

    private func printCharacter(_ char: Character) -> String {
        switch char {
        case "\n":
            return "\\newline"

        case "\t":
            return "\\tab"

        case " ":
            return "\\space"

        case "\r":
            return "\\return"

        case "\u{0008}":
            return "\\backspace"

        case "\u{000C}":
            return "\\formfeed"

        default:
            return "\\\(char)"
        }
    }

    private func escapeString(_ s: String) -> String {
        var result = ""
        for char in s {
            switch char {
            case "\"":
                result.append("\\\"")

            case "\\":
                result.append("\\\\")

            case "\n":
                result.append("\\n")

            case "\t":
                result.append("\\t")

            case "\r":
                result.append("\\r")

            case "\0":
                result.append("\\0")

            default:
                result.append(char)
            }
        }
        return result
    }
}

extension Printer: @unchecked Sendable {}
