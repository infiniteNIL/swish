extension Expr: CustomStringConvertible {
    public var description: String {
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

        case .deftype(let typeName, _, _, _):
            return typeName

        case .regex:
            return "regex"

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
        }
    }
}
