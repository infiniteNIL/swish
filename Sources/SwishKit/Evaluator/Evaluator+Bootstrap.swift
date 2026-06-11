import Foundation

extension Evaluator {
    func loadCoreLibrary() {
        guard let url = Bundle.module.url(
            forResource: "core", withExtension: "clj", subdirectory: "clojure"
        ) else {
            fatalError("SwishKit: clojure/core.clj not found in bundle")
        }
        do {
            _ = try loadNs(name: "clojure.core", url: url)
        } catch {
            fatalError("SwishKit: failed to load clojure/core.clj: \(error)")
        }
    }

    /// Returns the namespace named `name`, loading it if needed.
    /// Search order: bundle resources (.clj), then current working directory (.swish).
    /// Throws `namespaceNotFound` if the namespace cannot be located.
    func requireNs(_ name: String) throws -> Namespace {
        if let existing = findNs(name) {
            return existing
        }
        if name.hasPrefix("clojure"), let lastDot = name.lastIndex(of: ".") {
            let resourceName = String(name[name.index(after: lastDot)...])
            let subdirectory = String(name[..<lastDot]).replacingOccurrences(of: ".", with: "/")
            if let url = Bundle.module.url(forResource: resourceName,
                                           withExtension: "clj",
                                           subdirectory: subdirectory) {
                return try loadNs(name: name, url: url)
            }
        }

        let cwdURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(name.replacingOccurrences(of: ".", with: "/"))
            .appendingPathExtension("swish")
        if FileManager.default.fileExists(atPath: cwdURL.path) {
            return try loadNs(name: name, url: cwdURL)
        }

        throw EvaluatorError.namespaceNotFound(name)
    }

    private func loadNs(name: String, url: URL) throws -> Namespace {
        let savedNs = currentNs()
        defer { setCurrentNs(savedNs) }
        let source = try String(contentsOf: url, encoding: .utf8)
        for expr in try Reader.readString(source, currentNsName: name) {
            _ = try eval(expr)
        }
        guard let ns = findNs(name) else {
            throw EvaluatorError.namespaceNotFound(name)
        }
        postLoadNatives(for: name)
        return ns
    }

    private func postLoadNatives(for name: String) {
        switch name {
        case "clojure.string":
            registerClojureStringNatives(into: self)

        default:
            break
        }
    }
}
