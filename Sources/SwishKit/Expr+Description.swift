public extension Expr {
    /// The name of this value's Swish type — `"integer"`, `"vector"`, `"lazy-seq"`,
    /// a `defrecord`/`deftype`'s qualified type name, or a foreign value's Swift
    /// type name.
    ///
    /// This is the dispatch key, not a rendering: `type`, `instance?`, `satisfies?`,
    /// `catch` clause matching, and `hash`'s opaque-value fallback all compare
    /// against it, so it must stay stable per *kind* and never depend on contents.
    /// To render a value, use `Swish.printString(_:)` / `toString(_:)`, or just
    /// interpolate it — `description` prints the value.
    var typeName: String {
        switch self {
        case .nil:
            return "nil"

        case .boolean:
            return "boolean"

        case .integer:
            return "integer"

        case .bigInteger:
            return "bigInteger"

        case .float:
            return "float"

        case .double:
            return "double"

        case .bigDecimal:
            return "bigDecimal"

        case .ratio:
            return "ratio"

        case .string:
            return "string"

        case .character:
            return "character"

        case .keyword:
            return "keyword"

        case .symbol:
            return "symbol"

        case .list:
            return "list"

        case .seq:
            return "seq"

        case .vector, .sharedVector:
            return "vector"

        case .mapEntry:
            return "map-entry"

        case .map:
            return "map"

        case .sortedMap:
            return "sorted-map"

        case .set:
            return "set"

        case .sortedSet:
            return "sorted-set"

        case .function, .multiArityFunction, .nativeFunction:
            return "function"

        case .macro, .multiArityMacro:
            return "macro"

        case .atom:
            return "atom"

        case .lazySeq:
            return "lazy-seq"

        case .delay:
            return "delay"

        case .agent:
            return "agent"

        case .future:
            return "future"

        case .promise:
            return "promise"

        case .ref:
            return "ref"

        case .reduced:
            return "reduced"

        case .transient:
            return "transient"

        case .varRef:
            return "var"

        case .namespace:
            return "namespace"

        case .record(let typeName, _, _, _):
            return typeName

        case .deftype(let typeName, _, _, _, _):
            return typeName

        case .regex:
            return "regex"

        case .matcher:
            return "matcher"

        case .reader:
            return "reader"

        case .writer:
            return "writer"

        case .inst:
            return "inst"

        case .uuid:
            return "uuid"

        case .array:
            return "array"

        case .foreign(let object):
            return object.typeName
        }
    }
}

extension Expr: CustomStringConvertible {
    /// The value, rendered the way `pr-str` would — so interpolating an `Expr`
    /// does the obvious thing and test failures read as values rather than as
    /// type names.
    ///
    /// `printString` rather than `strString`: a top-level string stays quoted,
    /// which is what keeps `"a"` distinguishable from `'a` in debug output.
    /// The printer's `*print-length*` cap is what makes this terminate on an
    /// infinite lazy seq (it realizes up to that many elements as a side effect).
    ///
    /// For the dispatch key — `type`, `instance?`, `catch` matching, `hash`'s
    /// opaque fallback — use `typeName`.
    public var description: String { corePrinter.printString(self) }
}
