import Synchronization

/// Reference-identity Equatable/Hashable — matches Clojure's fn/multimethod
/// identity semantics (functions are never structurally equal, even with
/// identical bodies).
protocol ReferenceEquatable: AnyObject, Hashable {}
extension ReferenceEquatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs === rhs }
    public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

/// A class whose `metadata` is a plain Mutex-protected optional dict. Distinct
/// from CoreMeta.swift's private MetadataHolder, which type-erases *existing*
/// metadata properties for with-meta/meta dispatch rather than providing one.
protocol LockedMetadata: AnyObject {
    var metadataState: Mutex<[Expr: Expr]?> { get }
}
extension LockedMetadata {
    public var metadata: [Expr: Expr]? {
        get { metadataState.withLock { $0 } }
        set { metadataState.withLock { $0 = newValue } }
    }
}

public final class SwishFunction: @unchecked Sendable, ReferenceEquatable, LockedMetadata {
    public let name: String?
    public let params: [String]
    public let body: [Expr]
    public let capturedEnv: Environment?
    let metadataState: Mutex<[Expr: Expr]?>

    init(name: String?, params: [String], body: [Expr], capturedEnv: Environment?, metadata: [Expr: Expr]?) {
        self.name = name
        self.params = params
        self.body = body
        self.capturedEnv = capturedEnv
        self.metadataState = Mutex(metadata)
    }
}

public final class SwishMultiArityFunction: @unchecked Sendable, ReferenceEquatable, LockedMetadata {
    public let name: String?
    public let arities: [FnArity]
    public let capturedEnv: Environment?
    let metadataState: Mutex<[Expr: Expr]?>

    init(name: String?, arities: [FnArity], capturedEnv: Environment?, metadata: [Expr: Expr]?) {
        self.name = name
        self.arities = arities
        self.capturedEnv = capturedEnv
        self.metadataState = Mutex(metadata)
    }
}
