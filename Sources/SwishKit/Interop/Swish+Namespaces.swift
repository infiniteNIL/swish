import Foundation

// Namespace access for hosts, addressed by name. Deliberately string-based: no
// `Namespace` object escapes the façade, so there is no way to reach into the
// interpreter's var tables from outside.
public extension Swish {
    /// The names of every namespace that currently exists, sorted.
    var namespaceNames: [String] {
        evaluator.namespaces.keys.sorted()
    }

    /// Whether a namespace named `name` exists.
    func namespaceExists(_ name: String) -> Bool {
        evaluator.findNs(name) != nil
    }

    /// Switches the current namespace, the one unqualified names in `eval` and
    /// `call` resolve against.
    ///
    /// - Throws: `EvaluatorError.namespaceNotFound` if no such namespace exists.
    ///   Loading a file containing an `(ns …)` form already switches to it, so
    ///   this is for moving back and forth afterwards.
    func inNamespace(_ name: String) throws {
        guard let ns = evaluator.findNs(name) else {
            throw EvaluatorError.namespaceNotFound(name)
        }
        evaluator.setCurrentNs(ns)
    }

    /// The names bound in `namespace`, sorted — what `(ns-map …)` would show.
    /// Empty if no such namespace exists.
    func names(in namespace: String) -> [String] {
        guard let ns = evaluator.findNs(namespace) else { return [] }
        return ns.mappings.keys.sorted()
    }
}
