public final class SwishFunction: @unchecked Sendable {
    public let name: String?
    public let params: [String]
    public let body: [Expr]
    public let capturedEnv: Environment?
    public var metadata: [Expr: Expr]?

    init(name: String?, params: [String], body: [Expr], capturedEnv: Environment?, metadata: [Expr: Expr]?) {
        self.name = name
        self.params = params
        self.body = body
        self.capturedEnv = capturedEnv
        self.metadata = metadata
    }
}

extension SwishFunction: Equatable {
    public static func == (lhs: SwishFunction, rhs: SwishFunction) -> Bool {
        lhs === rhs
    }
}

extension SwishFunction: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

public final class SwishMultiArityFunction: @unchecked Sendable {
    public let name: String?
    public let arities: [FnArity]
    public let capturedEnv: Environment?
    public var metadata: [Expr: Expr]?

    init(name: String?, arities: [FnArity], capturedEnv: Environment?, metadata: [Expr: Expr]?) {
        self.name = name
        self.arities = arities
        self.capturedEnv = capturedEnv
        self.metadata = metadata
    }
}

extension SwishMultiArityFunction: Equatable {
    public static func == (lhs: SwishMultiArityFunction, rhs: SwishMultiArityFunction) -> Bool {
        lhs === rhs
    }
}

extension SwishMultiArityFunction: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
