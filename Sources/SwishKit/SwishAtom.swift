/// A Swish atom — an unsynchronized mutable reference to a value.
public final class SwishAtom: @unchecked Sendable {
    var value: Expr

    init(_ value: Expr) { self.value = value }
}
