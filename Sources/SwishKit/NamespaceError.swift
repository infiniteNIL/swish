/// Errors thrown by namespace operations
public enum NamespaceError: Error, Equatable, CustomStringConvertible {
    case referConflict(name: String, existing: String, new: String)
    case aliasConflict(name: String, existing: String, new: String)

    public var description: String {
        switch self {
        case .referConflict(let name, let existing, let new):
            return "'\(name)' already refers to \(existing), cannot refer \(new)"

        case .aliasConflict(let name, let existing, let new):
            return "Alias '\(name)' already refers to \(existing), cannot alias \(new)"
        }
    }
}
