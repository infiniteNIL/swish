import Foundation
import BigInt
import BigDecimal
import Synchronization

// `NumberFormatter`/`ISO8601DateFormatter` are expensive to construct and unsafe for
// concurrent use, so they're process-wide shared instances (built once) guarded by this
// lock — NOT per-`Printer` fields. That keeps `Printer` a *cheap* value type: the print
// fns build a per-call `Printer` configured from the `*print-*` dynamic vars, and that
// costs only a struct copy, never a formatter allocation.
private let formatterLock = Mutex<Void>(())

private let sharedFloatFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.usesGroupingSeparator = false
    f.minimumFractionDigits = 1
    f.maximumFractionDigits = 15
    return f
}()

// `nonisolated(unsafe)`: `ISO8601DateFormatter` isn't `Sendable`; it's mutated only via
// the `formatterLock`-guarded `.string(from:)` call site, so it's manually serialized.
nonisolated(unsafe) private let sharedInstFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

/// Printer for Swish expressions. A cheap-to-construct value type holding only config;
/// the expensive formatters are shared module-level (see above).
public struct Printer {
    public var printMeta: Bool = false
    /// Maximum number of lazy-seq elements to realize when printing (`*print-length*`).
    /// `nil` means no limit (only safe for finite seqs).
    public var printLengthCap: Int? = 1000
    /// Maximum nesting depth before a collection prints as `#` (`*print-level*`). `nil` = no limit.
    public var printLevelCap: Int? = nil
    /// When true, a map whose keys all share one namespace prints compactly as `#:ns{…}`
    /// (`*print-namespace-maps*`). Defaults true, matching Clojure.
    public var printNamespaceMaps: Bool = true
    /// When false, `pr`-style printing renders strings/chars unquoted (`*print-readably*`).
    public var printReadably: Bool = true
    /// Optional hook consulted when printing a `deftype`/`defrecord` instance — backs
    /// `print-method`. Returns a custom rendering, or nil to fall through to the native form.
    /// Non-`Sendable` closure held safely: `Printer` is `@unchecked Sendable` and is used
    /// synchronously within one print call.
    public var userTypePrinter: ((Expr) -> String?)?

    public init() {}

    // MARK: - Public entry points (depth 0)
    //
    // Three renderings, each matching a distinct Clojure concept. The difference is not
    // just "quoted vs unquoted" — it is *how far down* the unquoting reaches:
    //
    //   pr      readable everywhere.                        (pr-str {:a "x"}) => {:a "x"}
    //   str     top-level scalar plain, elements readable.  (str    {:a "x"}) => {:a "x"}
    //                                                       (str    "x")      => x
    //   print   plain everywhere.                           (print-str {:a "x"}) => {:a x}
    //
    // `str` looks like the odd one out but isn't: in Clojure it is the value's `toString`,
    // and a collection's `toString` is pr-based. `print` is the one that reaches all the
    // way down, because it binds `*print-readably*` to nil around an ordinary `pr` — which
    // is why it is built here from `printString` with `printReadably` false (see
    // `CoreIO.outputPrinter`) rather than from `strString`.

    /// Machine-readable representation (quoted/escaped strings, named chars). Round-trips
    /// through the reader. Backs `pr`/`pr-str` — and, with `printReadably` false, the whole
    /// `print` family.
    public func printString(_ expr: Expr) -> String { printString(expr, depth: 0) }

    /// `str`'s representation: a scalar renders plainly (a string is itself, a char is
    /// itself, `nil` is ""), but a **collection** renders readably, so its nested strings
    /// keep their quotes. Backs `str` — and, through it, `join`, `format`'s `%s`, `spit`'s
    /// content, and `clojure.string`'s non-nil coercion.
    public func strString(_ expr: Expr) -> String { strString(expr, depth: 0) }

    /// Like `printString` but floats use `String(value)` for exact round-trip — REPL result form.
    public func sourceForm(_ expr: Expr) -> String { sourceForm(expr, depth: 0) }

    // MARK: - Special doubles
    //
    // ±Infinity and NaN have two correct spellings, and which one applies is the whole
    // difference between the readable and the `str` rendering:
    //
    //   - `##Inf`/`##-Inf`/`##NaN` — the reader literals (`Parser.swift` accepts exactly
    //     these), so `pr` must emit them or its output stops round-tripping. Handing the
    //     values to `sharedFloatFormatter` instead produced `+∞`/`-∞`, which no reader
    //     accepts.
    //   - `Infinity`/`-Infinity`/`NaN` — Java's `Double.toString` names, which is what
    //     `str` produces in Clojure (its `str` *is* `toString`). Pinned by the jank suite.

    /// The reader-round-trippable literal for a special double, or nil if `value` is ordinary.
    private func readableSpecialDouble(_ value: Double) -> String? {
        if value.isNaN {
            return "##NaN"
        }
        if value.isInfinite {
            return value > 0 ? "##Inf" : "##-Inf"
        }
        return nil
    }

    /// Java `Double.toString`'s name for a special double, or nil if `value` is ordinary.
    private func javaSpecialDouble(_ value: Double) -> String? {
        if value.isNaN {
            return "NaN"
        }
        if value.isInfinite {
            return value > 0 ? "Infinity" : "-Infinity"
        }
        return nil
    }

    /// The ordinary (finite) rendering. Callers must rule out the special values first —
    /// `NumberFormatter` renders those with typographic symbols.
    private func formattedDouble(_ value: Double) -> String {
        formatterLock.withLock { _ in sharedFloatFormatter.string(from: NSNumber(value: value)) } ?? String(value)
    }

    // MARK: - Depth-threaded implementations

    func printString(_ expr: Expr, depth: Int) -> String {
        if let cap = printLevelCap, depth >= cap, isCollectionForLevel(expr) {
            return "#"
        }
        let recur: (Expr) -> String = { self.printString($0, depth: depth + 1) }
        if let collection = formatCollection(expr, transform: recur, includeMeta: true) {
            return collection
        }
        if case .lazySeq(let box) = expr {
            return formatLazySeq(box, transform: recur)
        }
        return switch expr {
        case .integer(let value):
            String(value)

        case .double(let value):
            readableSpecialDouble(value) ?? formattedDouble(value)

        case .float(let value):
            readableSpecialDouble(Double(value)) ?? formattedDouble(Double(value))

        case .ratio(let ratio):
            "\(ratio.numerator)/\(ratio.denominator)"

        case .bigInteger(let v):
            "\(v)N"

        case .bigDecimal(let v):
            "\(v)M"

        case .string(let value):
            printReadably ? "\"\(escapeString(value))\"" : value

        case .character(let char):
            printReadably ? printCharacter(char) : String(char)

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
            "#<Atom: \(printString(a.value, depth: depth + 1))>"

        case .transient(let tc):
            "#<transient \(printString(tc.value, depth: depth + 1))>"

        case .reduced(let v):
            "#<reduced \(printString(v, depth: depth + 1))>"

        case .delay(let box):
            box.isRealized
                ? "#<Delay@\((try? box.force()).map { printString($0, depth: depth + 1) } ?? "error")>"
                : "#<Delay@pending>"

        case .agent(let a):
            "#<Agent: \(printString(a.value, depth: depth + 1))>"

        case .future(let box):
            box.isCancelled
                ? "#<Future@cancelled>"
                : box.isRealized
                    ? "#<Future@\((try? box.deref()).map { printString($0, depth: depth + 1) } ?? "error")>"
                    : "#<Future@pending>"

        case .promise(let box):
            box.isRealized
                ? "#<Promise@\(printString(box.deref(), depth: depth + 1))>"
                : "#<Promise@pending>"

        case .ref(let r):
            "#<Ref: \(printString(r.value, depth: depth + 1))>"

        case .regex(let r):
            "#\"\(r.pattern)\""

        case .matcher:
            "#<Matcher>"

        case .reader(let r):
            "#<Reader \(r.path)>"

        case .writer(let w):
            w.path.map { "#<Writer \($0)>" } ?? "#<Writer>"

        case .inst(let date):
            "#inst \"\(formatterLock.withLock { _ in sharedInstFormatter.string(from: date) })\""

        case .uuid(let uuid):
            "#uuid \"\(uuid.uuidString.lowercased())\""

        case .record(let typeName, _, let data, _):
            userTypePrinter?(expr) ?? "#\(shortTypeName(typeName))\(printMapString(data, transform: recur))"

        case .deftype(let typeName, let fields, let data, let box, _):
            userTypePrinter?(expr) ?? printDeftype(typeName: typeName, fields: fields, data: data, mutableStorage: box, depth: depth)

        default:
            fatalError("unreachable: collection and lazySeq cases are handled by formatCollection/formatLazySeq above")
        }
    }

    func strString(_ expr: Expr, depth: Int) -> String {
        // A collection is handed to `printString` outright rather than recursed here.
        // Clojure's `str` on a collection is that collection's `toString`, which is
        // pr-based — so the *elements* print readably (`(str {:a "x"})` => `{:a "x"}`,
        // `(str [nil])` => `[nil]`, `(str [1N])` => `[1N]`) even though a *top-level*
        // string does not. Only scalars get str's own rendering below.
        //
        // `isCollectionForLevel` already enumerates exactly the set that needs this, and
        // `printString` re-applies the `*print-level*` cap at this same depth, so handing
        // off before checking it here loses nothing.
        if isCollectionForLevel(expr) {
            return printString(expr, depth: depth)
        }
        return switch expr {
        case .nil:
            ""

        case .string(let value):
            value

        case .character(let char):
            String(char)

        // Java's `toString` names, not `printString`'s reader literals — `(str ##Inf)` is
        // "Infinity", where `(pr-str ##Inf)` is "##Inf". Falling through to `printString`
        // for NaN (as this used to) would now yield "##NaN".
        case .double(let value):
            javaSpecialDouble(value) ?? formattedDouble(value)

        case .float(let value):
            javaSpecialDouble(Double(value)) ?? formattedDouble(Double(value))

        case .bigInteger(let v):
            "\(v)"

        case .bigDecimal(let v):
            "\(v)"

        case .uuid(let uuid):
            uuid.uuidString.lowercased()

        default:
            printString(expr, depth: depth)
        }
    }

    func sourceForm(_ expr: Expr, depth: Int) -> String {
        if let cap = printLevelCap, depth >= cap, isCollectionForLevel(expr) {
            return "#"
        }
        let recur: (Expr) -> String = { self.sourceForm($0, depth: depth + 1) }
        if let collection = formatCollection(expr, transform: recur, includeMeta: false) {
            return collection
        }
        if case .lazySeq(let box) = expr {
            return formatLazySeq(box, transform: recur)
        }
        return switch expr {
        // `String(value)` round-trips a finite double exactly, but spells the special
        // values "inf"/"-inf"/"nan", which the reader doesn't accept.
        case .double(let value):
            readableSpecialDouble(value) ?? String(value)

        case .float(let value):
            readableSpecialDouble(Double(value)) ?? String(value)

        default:
            printString(expr, depth: depth)
        }
    }

    // MARK: - Collection formatting

    private func isCollectionForLevel(_ expr: Expr) -> Bool {
        switch expr {
        case .list, .seq, .vector, .sharedVector, .array, .mapEntry,
             .map, .sortedMap, .set, .sortedSet, .lazySeq, .record, .deftype:
            return true

        default:
            return false
        }
    }

    private func formatSeq(open: String, close: String, elements: some Sequence<Expr>, meta: [Expr: Expr]?, includeMeta: Bool, transform: (Expr) -> String) -> String {
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
            // Printed straight off the `TreeDictionary`; `swiftDictionary` here would
            // materialize an entire second map on every print just to iterate it.
            return (includeMeta ? metaPrefix(sm.metadata) : "") + printMapString(sm.dict, transform: transform)

        case .set(let ss):
            // Likewise the `TreeSet` — the elements are only mapped and sorted, so
            // rebuilding a Swift `Set` from them first bought nothing.
            return (includeMeta ? metaPrefix(ss.metadata) : "") + printSetString(ss.elements, transform: transform)

        case .sortedSet(let sss):
            let body = sss.elements.map(transform).joined(separator: " ")
            return (includeMeta ? metaPrefix(sss.metadata) : "") + (sss.isEmpty ? "#{}" : "#{\(body)}")

        case .sortedMap(let ssm):
            let pairs = zip(ssm.keys, ssm.values).flatMap { [transform($0), transform($1)] }.joined(separator: " ")
            return (includeMeta ? metaPrefix(ssm.metadata) : "") + (ssm.isEmpty ? "{}" : "{\(pairs)}")

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
        return "^\(printMapString(meta, transform: { self.printString($0, depth: 0) })) "
    }

    private func shortTypeName(_ typeName: String) -> String {
        typeName.contains("/") ? String(typeName.split(separator: "/").last!) : typeName
    }

    private func printDeftype(typeName: String, fields: [String], data: [Expr: Expr], mutableStorage: MutableFieldStore?, depth: Int) -> String {
        // Immutable fields live in `data`; mutable ones (if any) live in the box —
        // read each field's *current* value from wherever it's stored.
        let mutableFields = mutableStorage?.snapshot ?? [:]
        let values = fields.map { field -> String in
            let value = data[.keyword(field)] ?? mutableFields[field] ?? .nil
            return printString(value, depth: depth + 1)
        }.joined(separator: " ")
        return "#\(shortTypeName(typeName))[\(values)]"
    }

    /// Generic over the key/value sequence so a `.map` prints directly from its
    /// `TreeDictionary` and `metaPrefix` still passes a plain `[Expr: Expr]`, without
    /// either having to materialize into the other's representation.
    private func printMapString(_ dict: some Sequence<(key: Expr, value: Expr)>, transform: (Expr) -> String) -> String {
        let entries = Array(dict)
        // `#:ns{…}`: when every key is a keyword/symbol sharing one namespace, print the
        // compact namespaced-map form with the shared namespace stripped from each key.
        if printNamespaceMaps, !entries.isEmpty, let ns = sharedKeyNamespace(entries) {
            let pairs = entries
                .map { (transform(stripKeyNamespace($0.key)), transform($0.value)) }
                .sorted { $0.0 < $1.0 }
                .flatMap { [$0.0, $0.1] }
                .joined(separator: " ")
            return "#:\(ns){\(pairs)}"
        }
        let pairs = entries
            .map { (transform($0.key), transform($0.value)) }
            .sorted { $0.0 < $1.0 }
            .flatMap { [$0.0, $0.1] }
            .joined(separator: " ")
        return pairs.isEmpty ? "{}" : "{\(pairs)}"
    }

    /// The common namespace shared by *all* keys, or nil if any key is unqualified or not a
    /// keyword/symbol (in which case no `#:ns{}` compaction applies).
    private func sharedKeyNamespace(_ entries: [(key: Expr, value: Expr)]) -> String? {
        var shared: String?
        for entry in entries {
            let name: String
            switch entry.key {
            case .keyword(let k):     name = k
            case .symbol(let s, _):   name = s
            default:                  return nil
            }
            guard let slash = name.firstIndex(of: "/"), slash != name.startIndex else {
                return nil
            }
            let ns = String(name[..<slash])
            if shared == nil {
                shared = ns
            }
            else if shared != ns {
                return nil
            }
        }
        return shared
    }

    private func stripKeyNamespace(_ key: Expr) -> Expr {
        switch key {
        case .keyword(let k):
            guard let slash = k.firstIndex(of: "/") else { return key }
            return .keyword(String(k[k.index(after: slash)...]))

        case .symbol(let s, let meta):
            guard let slash = s.firstIndex(of: "/") else { return key }
            return .symbol(String(s[s.index(after: slash)...]), metadata: meta)

        default:
            return key
        }
    }

    private func printSetString(_ set: some Sequence<Expr>, transform: (Expr) -> String) -> String {
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
