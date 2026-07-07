public final class SwishMap: @unchecked Sendable {
    public let dict: [Expr: Expr]
    public var metadata: [Expr: Expr]?

    init(dict: [Expr: Expr], metadata: [Expr: Expr]?) {
        self.dict = dict
        self.metadata = metadata
    }
}

extension SwishMap: Equatable {
    public static func == (lhs: SwishMap, rhs: SwishMap) -> Bool {
        lhs.dict == rhs.dict
    }
}

extension SwishMap: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(dict)
    }
}
