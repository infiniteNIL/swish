import Foundation

/// Printer for Swish expressions
public struct Printer {
    private let floatFormatter: NumberFormatter
    public var printMeta: Bool = false

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

        case .symbol(let name, let meta):
            metaPrefix(meta) + name

        case .keyword(let name):
            ":\(name)"

        case .list(let elements, let meta):
            metaPrefix(meta) + "(" + elements.map { printString($0) }.joined(separator: " ") + ")"

        case .vector(let elements, let meta):
            metaPrefix(meta) + "[" + elements.map { printString($0) }.joined(separator: " ") + "]"

        case .map(let dict, let meta):
            metaPrefix(meta) + printMapString(dict, transform: printString)

        case .set(let elements, let meta):
            metaPrefix(meta) + printSetString(elements, transform: printString)

        case .function(let name, _, _, let meta):
            if let name {
                metaPrefix(meta) + "#<fn \(name)>"
            }
            else {
                metaPrefix(meta) + "#<fn>"
            }

        case .macro(let name, _, _, let meta):
            if let name {
                metaPrefix(meta) + "#<macro \(name)>"
            }
            else {
                metaPrefix(meta) + "#<macro>"
            }

        case .nativeFunction(let name, _, _):
            "#<native-fn \(name)>"

        case .varRef(let v):
            "#'\(v.namespace.name)/\(v.name)"

        case .namespace(let ns):
            "#<Namespace \(ns.name)>"
        }
    }

    /// Returns a human-readable string representation of a Swish expression.
    /// Strings print without quotes; characters print as the raw character.
    /// Backs the `str` native function. Named `strString` to mirror `printString` → `pr-str`.
    public func strString(_ expr: Expr) -> String {
        switch expr {
        case .nil:
            ""

        case .string(let value):
            value

        case .character(let char):
            String(char)

        case .list(let elements, let meta):
            metaPrefix(meta) + "(" + elements.map { strString($0) }.joined(separator: " ") + ")"

        case .vector(let elements, let meta):
            metaPrefix(meta) + "[" + elements.map { strString($0) }.joined(separator: " ") + "]"

        case .map(let dict, let meta):
            metaPrefix(meta) + printMapString(dict, transform: strString)

        case .set(let elements, let meta):
            metaPrefix(meta) + printSetString(elements, transform: strString)

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

        case .list(let elements, _):
            "(" + elements.map { sourceForm($0) }.joined(separator: " ") + ")"

        case .vector(let elements, _):
            "[" + elements.map { sourceForm($0) }.joined(separator: " ") + "]"

        case .map(let dict, _):
            printMapString(dict, transform: sourceForm)

        case .set(let elements, _):
            printSetString(elements, transform: sourceForm)

        default:
            printString(expr)
        }
    }

    private func metaPrefix(_ meta: [Expr: Expr]?) -> String {
        guard printMeta, let meta, !meta.isEmpty else { return "" }
        return "^\(printMapString(meta, transform: printString)) "
    }

    private func printMapString(_ dict: [Expr: Expr], transform: (Expr) -> String) -> String {
        let pairs = dict
            .map { (transform($0.key), transform($0.value)) }
            .sorted { $0.0 < $1.0 }
            .flatMap { [$0.0, $0.1] }
            .joined(separator: " ")
        return pairs.isEmpty ? "{}" : "{\(pairs)}"
    }

    private func printSetString(_ set: Set<Expr>, transform: (Expr) -> String) -> String {
        let elements = set
            .map { transform($0) }
            .sorted()
            .joined(separator: " ")
        return elements.isEmpty ? "#{}" : "#{\(elements)}"
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
