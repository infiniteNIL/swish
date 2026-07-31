/// Errors thrown by namespace operations
public enum NamespaceError: Error, Equatable, CustomStringConvertible {
    // `refer` no longer throws on clash — it warns/replaces (referred var) or keeps
    // + returns a REJECTED message (home var), matching Clojure's checkReplacement.
    case aliasConflict(name: String, existing: String, new: String)

    public var description: String {
        switch self {
        case .aliasConflict(let name, let existing, let new):
            return "Alias '\(name)' already refers to \(existing), cannot alias \(new)"
        }
    }
}
