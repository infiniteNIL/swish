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
    /// Search order: Bundle.module, then each source path, then CWD.
    /// Throws `namespaceNotFound` if the namespace cannot be located.
    func requireNs(_ name: String) throws -> Namespace {
        if let existing = findNs(name) {
            return existing
        }

        let filePath = name
            .replacingOccurrences(of: ".", with: "/")
            .replacingOccurrences(of: "-", with: "_")

        if let lastSlash = filePath.lastIndex(of: "/") {
            let resourceName = String(filePath[filePath.index(after: lastSlash)...])
            let subdirectory = String(filePath[..<lastSlash])
            if let url = Bundle.module.url(forResource: resourceName,
                                           withExtension: "clj",
                                           subdirectory: subdirectory) {
                return try loadNs(name: name, url: url)
            }
        } else if let url = Bundle.module.url(forResource: filePath,
                                               withExtension: "clj") {
            return try loadNs(name: name, url: url)
        }

        let extensions = ["swish"]
        for basePath in sourcePaths + [FileManager.default.currentDirectoryPath] {
            let base = URL(fileURLWithPath: basePath).appendingPathComponent(filePath)
            for ext in extensions {
                let url = base.appendingPathExtension(ext)
                if FileManager.default.fileExists(atPath: url.path) {
                    return try loadNs(name: name, url: url)
                }
            }
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
