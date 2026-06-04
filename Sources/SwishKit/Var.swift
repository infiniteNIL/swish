/// A Swish var — an interned, named reference to a value
public final class Var: @unchecked Sendable {
    public let name: String
    public unowned let namespace: Namespace
    public var value: Expr?
    public var metadata: [Expr: Expr]? = nil
    public var isSystem: Bool = false
    public var isDynamic: Bool = false

    public init(name: String, namespace: Namespace, value: Expr? = nil) {
        self.name = name
        self.namespace = namespace
        self.value = value
    }

    public var isBound: Bool { value != nil }
}
