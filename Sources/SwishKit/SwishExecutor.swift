import Foundation

/// Shared executor backing `future`. Independent, unordered work — unlike
/// agent actions, futures don't need per-item ordering, so a global
/// concurrent queue is sufficient.
enum SwishExecutor {
    static let shared = DispatchQueue.global(qos: .userInitiated)
}
