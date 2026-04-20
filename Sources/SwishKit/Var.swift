/// A Swish var — an interned, named reference to a value
public final class Var: @unchecked Sendable {
    public let name: String
    public let namespace: String
    public var value: Expr?

    public init(name: String, namespace: String, value: Expr? = nil) {
        self.name = name
        self.namespace = namespace
        self.value = value
    }

    public var isBound: Bool { value != nil }
}
