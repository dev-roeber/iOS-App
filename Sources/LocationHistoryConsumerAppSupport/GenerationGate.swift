import Foundation

/// Pure Foundation race-guard for cancellable workloads whose completion
/// lands back on a serial actor (e.g. `@MainActor`). Producers capture
/// `current` at task start, bump on every new request that invalidates
/// outstanding work, and check `isStillCurrent(_:)` before writing.
///
/// The type is a struct (`Sendable`, value semantics) so the *owning*
/// actor handles isolation — the gate itself is not thread-safe and
/// must be mutated only from one isolation domain (typically the
/// same `@MainActor` that consumes the results).
///
/// Train J, Phase 5: extracted as a Linux-testable replacement for the
/// inline `loadGeneration: UInt64` / `currentLoadToken: Int` pattern
/// used by `AppOverviewMapModel` and `AppHeatmapModel`.
public struct GenerationGate: Equatable, Sendable {
    private(set) public var current: UInt64

    public init(startingAt initial: UInt64 = 0) {
        self.current = initial
    }

    /// Invalidates all outstanding tokens and returns the new current
    /// token. Use this when a new request supersedes any in-flight work.
    @discardableResult
    public mutating func bump() -> UInt64 {
        current &+= 1
        return current
    }

    /// Returns `true` if `token` matches the most recently issued
    /// generation. Stale tokens — produced by superseded work — must
    /// be ignored by their producers.
    public func isStillCurrent(_ token: UInt64) -> Bool {
        token == current
    }
}
