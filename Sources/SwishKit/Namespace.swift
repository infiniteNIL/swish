/// A Swish namespace — a named container of interned Vars and refers
public final class Namespace: @unchecked Sendable {
    public let name: String
    public private(set) var mappings: [String: Var] = [:]

    public init(name: String) {
        self.name = name
    }

    /// Returns the home Var for `name`, creating it if it doesn't exist.
    /// If a home Var already exists, updates its value (if provided) and returns it.
    /// A home Var is one whose namespace is this namespace.
    @discardableResult
    public func intern(name: String, value: Expr? = nil) -> Var {
        if let existing = mappings[name], existing.namespace === self {
            if let v = value {
                existing.value = v
            }
            return existing
        }
        let v = Var(name: name, namespace: self, value: value)
        mappings[name] = v
        return v
    }

    /// Adds a reference to a Var from another namespace under its short name.
    /// Idempotent for the same Var. Throws if a different Var already occupies that name.
    public func refer(_ v: Var) throws {
        if let existing = mappings[v.name], existing !== v {
            throw NamespaceError.referConflict(
                name: v.name,
                existing: "\(existing.namespace.name)/\(existing.name)",
                new: "\(v.namespace.name)/\(v.name)")
        }
        mappings[v.name] = v
    }

    public func findVar(name: String) -> Var? {
        mappings[name]
    }
}
