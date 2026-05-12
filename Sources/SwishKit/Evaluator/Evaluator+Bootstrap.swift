import Foundation

extension Evaluator {
    func loadCoreLibrary() {
        guard let url = Bundle.module.url(
            forResource: "core", withExtension: "clj", subdirectory: "clojure"
        ) else {
            fatalError("SwishKit: clojure/core.clj not found in bundle")
        }
        do {
            let source = try String(contentsOf: url, encoding: .utf8)
            for expr in try Reader.readString(source) {
                _ = try eval(expr)
            }
        } catch {
            fatalError("SwishKit: failed to load clojure/core.clj: \(error)")
        }
    }

    /// Returns the namespace named `name`, loading its `.clj` resource file if needed.
    /// Throws `namespaceNotFound` if the namespace doesn't exist and no resource file matches.
    func requireNs(_ name: String) throws -> Namespace {
        if let existing = findNs(name) {
            return existing
        }
        let resourcePath = name.replacingOccurrences(of: ".", with: "/")
        guard let url = Bundle.module.url(forResource: resourcePath, withExtension: "clj") else {
            throw EvaluatorError.namespaceNotFound(name)
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        for expr in try Reader.readString(source) {
            _ = try eval(expr)
        }
        guard let ns = findNs(name) else {
            throw EvaluatorError.namespaceNotFound(name)
        }
        return ns
    }
}
