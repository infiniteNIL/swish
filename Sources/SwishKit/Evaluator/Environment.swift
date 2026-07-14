import Synchronization

/// Stores variable bindings for the evaluator
public class Environment: @unchecked Sendable {
    private let bindingsState = Mutex<[String: Expr]>([:])
    private let parent: Environment?

    public init(parent: Environment? = nil) {
        self.parent = parent
    }

    public func get(_ name: String) -> Expr? {
        bindingsState.withLock { $0[name] } ?? parent?.get(name)
    }

    public func set(_ name: String, _ value: Expr) {
        bindingsState.withLock { $0[name] = value }
    }

    /// Returns all names bound at any level of the environment chain.
    public func allNames() -> Set<String> {
        var names = bindingsState.withLock { Set($0.keys) }
        if let p = parent { names.formUnion(p.allNames()) }
        return names
    }
}
