import Foundation

/// A Swish keyword, as a Swift value.
///
/// `String` decodes from a keyword too (a keyword's name reads as a `String`), so
/// this type is for the cases where the distinction matters:
///
/// - **Producing one.** `try swish.call("assoc", m, Keyword("status"), "ok")` puts a
///   real `:status` in the map, where `"status"` would put a Swish string.
/// - **Round-tripping.** `[String: Int]` read from `{:a 1}` and handed back is
///   `{"a" 1}`, and Clojure's `(:a m)` then misses. `[Keyword: Int]` survives the
///   trip intact.
public struct Keyword: Hashable, Sendable, Comparable, CustomStringConvertible {
    /// The namespace part of a qualified keyword (`:user/name` → `"user"`), or nil.
    public let namespace: String?

    /// The name part, never including the namespace.
    public let name: String

    /// Creates a keyword from a name, which may be qualified (`"user/name"`).
    public init(_ name: String) {
        // `Expr.keyword` carries the whole thing in one String, so split it here
        // rather than making every host do it. A lone "/" is the name, not a
        // separator — `:/` is a legal keyword.
        if let slash = name.firstIndex(of: "/"), name.count > 1 {
            self.namespace = String(name[name.startIndex ..< slash])
            self.name = String(name[name.index(after: slash)...])
        }
        else {
            self.namespace = nil
            self.name = name
        }
    }

    public init(namespace: String?, name: String) {
        self.namespace = namespace
        self.name = name
    }

    /// The keyword's full name, including the namespace when it has one.
    public var qualifiedName: String {
        guard let namespace else { return name }
        return "\(namespace)/\(name)"
    }

    /// Renders as Swish would — `:status` — so a keyword is never mistaken for a
    /// string in debug output. Matches Clojure's `(str :a)`.
    public var description: String { ":\(qualifiedName)" }

    public static func < (lhs: Keyword, rhs: Keyword) -> Bool {
        lhs.qualifiedName < rhs.qualifiedName
    }
}

extension Keyword: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension Keyword: SwishConvertible {
    public var swishValue: Expr { .keyword(qualifiedName) }

    public init?(swishValue: Expr) {
        guard case let .keyword(name) = swishValue else { return nil }
        self.init(name)
    }
}

/// A Swish symbol, as a Swift value.
///
/// The counterpart of `Keyword` for the unquoted-name case — building a form to
/// `eval`, or naming a var to look up.
///
/// - Note: A Swish symbol can carry metadata (`^:private foo`). This type does
///   not, so metadata is dropped in both directions. Use a raw `Expr` when it
///   matters.
public struct Symbol: Hashable, Sendable, Comparable, CustomStringConvertible {
    /// The namespace part of a qualified symbol (`clojure.core/map` → `"clojure.core"`), or nil.
    public let namespace: String?

    /// The name part, never including the namespace.
    public let name: String

    public init(_ name: String) {
        let keyword = Keyword(name)
        self.namespace = keyword.namespace
        self.name = keyword.name
    }

    public init(namespace: String?, name: String) {
        self.namespace = namespace
        self.name = name
    }

    /// The symbol's full name, including the namespace when it has one.
    public var qualifiedName: String {
        guard let namespace else { return name }
        return "\(namespace)/\(name)"
    }

    /// The bare name, matching Clojure's `(str 'foo)` — unlike `Keyword`, a symbol
    /// has no leading marker to render.
    public var description: String { qualifiedName }

    public static func < (lhs: Symbol, rhs: Symbol) -> Bool {
        lhs.qualifiedName < rhs.qualifiedName
    }
}

extension Symbol: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension Symbol: SwishConvertible {
    public var swishValue: Expr { .symbol(qualifiedName, metadata: nil) }

    public init?(swishValue: Expr) {
        guard case let .symbol(name, _) = swishValue else { return nil }
        self.init(name)
    }
}
