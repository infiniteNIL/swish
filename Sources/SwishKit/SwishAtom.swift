/// A Swish atom — an unsynchronized mutable reference to a value.
public final class SwishAtom: @unchecked Sendable {
    var value: Expr
    var metadata: [Expr: Expr]?
    var validator: Expr?

    init(_ value: Expr, metadata: [Expr: Expr]? = nil, validator: Expr? = nil) {
        self.value = value
        self.metadata = metadata
        self.validator = validator
    }
}
