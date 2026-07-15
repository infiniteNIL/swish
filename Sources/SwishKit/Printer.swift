import Foundation
import BigInt
import BigDecimal
import Synchronization

/// `Printer` is a struct (value type), so it can't hold a `Mutex` field directly.
/// `NumberFormatter`/`ISO8601DateFormatter` are not safe for concurrent use on one
/// instance, and `corePrinter` (`Core.swift`) is a single process-wide shared
/// `Printer` used from error-message-building code across every native function —
/// exactly the kind of code path that will run on background threads once
/// agents/futures exist. This module-level lock serializes just the two
/// formatter-touching call sites, without changing `Printer`'s value semantics.
private let formatterLock = Mutex<Void>(())

/// Printer for Swish expressions
public struct Printer {
    private let floatFormatter: NumberFormatter
    private let instFormatter: ISO8601DateFormatter
    public var printMeta: Bool = false
    /// Maximum number of lazy-seq elements to realize when printing.
    /// `nil` means no limit (only safe for finite seqs).
    public var printLengthCap: Int? = 1000

    public init() {
        floatFormatter = NumberFormatter()
        floatFormatter.numberStyle = .decimal
        floatFormatter.usesGroupingSeparator = false
        floatFormatter.minimumFractionDigits = 1
        floatFormatter.maximumFractionDigits = 15

        instFormatter = ISO8601DateFormatter()
        instFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    /// Returns a machine-readable string representation of a Swish expression.
    /// Strings are quoted and escaped; characters use named forms (e.g. \newline).
    /// Output round-trips through the reader. Backs the planned `pr-str` native function.
    public func printString(_ expr: Expr) -> String {
        switch expr {
        case .integer(let value):
            String(value)

        case .double(let value):
            formatterLock.withLock { _ in floatFormatter.string(from: NSNumber(value: value)) } ?? String(value)

        case .float(let value):
            formatterLock.withLock { _ in floatFormatter.string(from: NSNumber(value: Double(value))) } ?? String(value)

        case .ratio(let ratio):
            "\(ratio.numerator)/\(ratio.denominator)"

        case .bigInteger(let v):
            "\(v)N"

        case .bigDecimal(let v):
            "\(v)M"

        case .string(let value):
            "\"\(escapeString(value))\""

        case .character(let char):
            printCharacter(char)

        case .boolean(let value):
            value ? "true" : "false"

        case .nil:
            "nil"

        case .symbol(let name, let meta):
            metaPrefix(meta) + (name.hasPrefix("clojure.core/")
                ? String(name.dropFirst("clojure.core/".count))
                : name)

        case .keyword(let name):
            ":\(name)"

        case .list, .seq, .array, .sharedVector, .vector, .mapEntry, .map, .sortedMap, .set, .sortedSet:
            formatCollection(expr, transform: printString, includeMeta: true) ?? ""

        case .function(let f):
            if let name = f.name {
                metaPrefix(f.metadata) + "#<fn \(name)>"
            }
            else {
                metaPrefix(f.metadata) + "#<fn>"
            }

        case .macro(let name, _, _, let meta):
            if let name {
                metaPrefix(meta) + "#<macro \(name)>"
            }
            else {
                metaPrefix(meta) + "#<macro>"
            }

        case .multiArityFunction(let maf):
            metaPrefix(maf.metadata) + (maf.name.map { "#<fn \($0)>" } ?? "#<fn>")

        case .multiArityMacro(let name, _, let meta):
            metaPrefix(meta) + (name.map { "#<macro \($0)>" } ?? "#<macro>")

        case .nativeFunction(let name, _, _):
            "#<native-fn \(name)>"

        case .varRef(let v):
            "#'\(v.namespace.name)/\(v.name)"

        case .namespace(let ns):
            "#<Namespace \(ns.name)>"

        case .atom(let a):
            "#<Atom: \(printString(a.value))>"

        case .transient(let tc):
            "#<transient \(printString(tc.value))>"

        case .lazySeq(let box):
            formatLazySeq(box, transform: printString)

        case .reduced(let v):
            "#<reduced \(printString(v))>"

        case .delay(let box):
            box.isRealized
                ? "#<Delay@\((try? box.force()).map { printString($0) } ?? "error")>"
                : "#<Delay@pending>"

        case .agent(let a):
            "#<Agent: \(printString(a.value))>"

        case .future(let box):
            box.isCancelled
                ? "#<Future@cancelled>"
                : box.isRealized
                    ? "#<Future@\((try? box.deref()).map { printString($0) } ?? "error")>"
                    : "#<Future@pending>"

        case .promise(let box):
            box.isRealized
                ? "#<Promise@\(printString(box.deref()))>"
                : "#<Promise@pending>"

        case .regex(let r):
            "#\"\(r.pattern)\""

        case .reader(let r):
            "#<Reader \(r.path)>"

        case .writer(let w):
            "#<Writer \(w.path)>"

        case .inst(let date):
            "#inst \"\(formatterLock.withLock { _ in instFormatter.string(from: date) })\""

        case .uuid(let uuid):
            "#uuid \"\(uuid.uuidString.lowercased())\""

        case .record(let typeName, _, let data, _):
            "#\(typeName.contains("/") ? String(typeName.split(separator: "/").last!) : typeName)\(printMapString(data, transform: printString))"
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

        case .list, .seq, .array, .sharedVector, .vector, .mapEntry, .map, .sortedMap, .set, .sortedSet:
            formatCollection(expr, transform: strString, includeMeta: true) ?? ""

        case .lazySeq(let box):
            formatLazySeq(box, transform: strString)

        case .double(let value):
            value.isInfinite ? (value > 0 ? "Infinity" : "-Infinity") : printString(.double(value))

        case .bigInteger(let v):
            "\(v)"

        case .bigDecimal(let v):
            "\(v)"

        case .reduced:
            printString(expr)

        case .transient:
            printString(expr)

        default:
            printString(expr)
        }
    }

    /// Returns the source-code form of a Swish expression for use in result substitution.
    /// Like `printString` but floats use `String(value)` for exact round-trip fidelity.
    public func sourceForm(_ expr: Expr) -> String {
        switch expr {
        case .double(let value):
            String(value)

        case .float(let value):
            String(value)

        case .list, .seq, .array, .sharedVector, .vector, .mapEntry, .map, .sortedMap, .set, .sortedSet:
            formatCollection(expr, transform: sourceForm, includeMeta: false) ?? ""

        case .lazySeq(let box):
            formatLazySeq(box, transform: sourceForm)

        case .reduced:
            printString(expr)

        case .transient:
            printString(expr)

        default:
            printString(expr)
        }
    }

    private func formatSeq(open: String, close: String, elements: [Expr], meta: [Expr: Expr]?, includeMeta: Bool, transform: (Expr) -> String) -> String {
        (includeMeta ? metaPrefix(meta) : "") + open + elements.map(transform).joined(separator: " ") + close
    }

    private func formatCollection(_ expr: Expr, transform: (Expr) -> String, includeMeta: Bool) -> String? {
        switch expr {
        case .list(let elements, let meta):
            return formatSeq(open: "(", close: ")", elements: elements, meta: meta, includeMeta: includeMeta, transform: transform)

        case .seq(let elements):
            return formatSeq(open: "(", close: ")", elements: elements, meta: nil, includeMeta: false, transform: transform)

        case .vector(let elements, let meta):
            return formatSeq(open: "[", close: "]", elements: elements, meta: meta, includeMeta: includeMeta, transform: transform)

        case .array(let sa):
            return formatSeq(open: "[", close: "]", elements: sa.elements, meta: nil, includeMeta: false, transform: transform)

        case .sharedVector(let sa, let meta):
            return formatSeq(open: "[", close: "]", elements: sa.elements, meta: meta, includeMeta: includeMeta, transform: transform)

        case .mapEntry(let k, let v):
            return "[" + transform(k) + " " + transform(v) + "]"

        case .map(let sm):
            return (includeMeta ? metaPrefix(sm.metadata) : "") + printMapString(sm.dict, transform: transform)

        case .set(let ss):
            return (includeMeta ? metaPrefix(ss.metadata) : "") + printSetString(ss.elements, transform: transform)

        case .sortedSet(let elements, let meta):
            let body = elements.map(transform).joined(separator: " ")
            return (includeMeta ? metaPrefix(meta) : "") + (elements.isEmpty ? "#{}" : "#{\(body)}")

        case .sortedMap(let dict, let meta):
            let sortedKeys = dict.keys.sorted { (try? compareExprValue($0, $1)).map { $0 < 0 } ?? false }
            let pairs = sortedKeys.flatMap { [transform($0), transform(dict[$0]!)] }.joined(separator: " ")
            return (includeMeta ? metaPrefix(meta) : "") + (dict.isEmpty ? "{}" : "{\(pairs)}")

        default:
            return nil
        }
    }

    /// Prints a lazy seq, realizing at most `printLengthCap` elements.
    /// Appends `...` when the seq extends past the cap.
    private func formatLazySeq(_ box: LazySeqBox, transform: (Expr) -> String) -> String {
        var parts: [String] = []
        var current: Expr = .lazySeq(box)
        let cap = printLengthCap ?? Int.max

        // Advance through the chain one element at a time.
        stepLoop: while true {
            switch current {
            case .nil:
                break stepLoop

            case .lazySeq(let b):
                guard let head = try? b.forceHead() else {
                    break stepLoop
                }
                if parts.count >= cap {
                    // Have head but already at cap — truncated.
                    return "(\(parts.joined(separator: " ")) ...)"
                }
                parts.append(transform(head))
                current = (try? b.forceTail()) ?? .nil

            case .list(let elems, _):
                let remaining = cap - parts.count
                for e in elems.prefix(remaining) { parts.append(transform(e)) }
                if elems.count > remaining {
                    return "(\(parts.joined(separator: " ")) ...)"
                }
                break stepLoop

            default:
                break stepLoop
            }
        }

        return "(\(parts.joined(separator: " ")))"
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
        if let pair = namedCharacters.first(where: { $0.value == char }) {
            return "\\\(pair.key)"
        }
        return "\\\(char)"
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

            case "\u{0008}":
                result.append("\\u{0008}")

            case "\u{000C}":
                result.append("\\u{000C}")

            default:
                result.append(char)
            }
        }
        return result
    }
}

extension Printer: @unchecked Sendable {}
