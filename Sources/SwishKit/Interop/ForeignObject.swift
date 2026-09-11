import Foundation

/// An opaque host value carried through Swish.
///
/// Swish has no host class system, so a Swift value that has no Swish
/// representation crosses the boundary as one of these: the interpreter can
/// bind it, store it in collections, pass it around, and hand it back to a
/// registered Swift function, but it cannot look inside. Conform the Swift type
/// to `SwishOpaque` to opt in — that is the whole of the host-side work.
///
/// Two `ForeignObject`s are equal only when they are the same box, and the box
/// hashes by identity. That is deliberate: the wrapped value is `Any`, so there
/// is no general way to compare or hash it, and identity is the one answer that
/// is always correct. It also matches how `deftype` instances with mutable
/// fields behave.
public final class ForeignObject: @unchecked Sendable {
    /// The wrapped host value.
    public let value: Any

    /// The Swift type name of the wrapped value, used for printing and for
    /// protocol dispatch (`type`, `instance?`).
    public let typeName: String

    public init<T>(_ value: T) {
        self.value = value
        typeName = String(describing: T.self)
    }

    /// The wrapped value as `T`, or nil if it is some other type.
    public func unwrap<T>(as type: T.Type = T.self) -> T? {
        value as? T
    }
}
