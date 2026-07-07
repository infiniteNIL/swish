public final class SwishSet: @unchecked Sendable {
    public let elements: Set<Expr>
    public var metadata: [Expr: Expr]?

    init(elements: Set<Expr>, metadata: [Expr: Expr]?) {
        self.elements = elements
        self.metadata = metadata
    }
}

extension SwishSet: Equatable {
    public static func == (lhs: SwishSet, rhs: SwishSet) -> Bool {
        lhs.elements == rhs.elements
    }
}

extension SwishSet: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(elements)
    }
}
