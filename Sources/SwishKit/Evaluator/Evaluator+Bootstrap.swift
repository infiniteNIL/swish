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
}
