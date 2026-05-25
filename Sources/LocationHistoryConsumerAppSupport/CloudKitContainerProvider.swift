#if canImport(CloudKit)
import Foundation
import CloudKit

// MARK: - CloudKitContainerProvider

/// Central cache for `CKContainer` instances keyed by container identifier.
///
/// `CKContainer(identifier:)` returns a new façade object on every call, but the
/// underlying CloudKit container is process-global. Repeatedly instantiating
/// the wrapper across the code base obscures call sites and makes it harder to
/// guarantee a single source of truth for container-scoped state (caches,
/// subscriptions, account status). This provider hands out a single, cached
/// `CKContainer` per identifier so all CloudKit call sites in the consumer app
/// share the same instance.
///
/// Safety contract:
/// - Private database only — this provider never references
///   `publicCloudDatabase` or `sharedCloudDatabase`.
/// - The cache only stores containers requested by the caller; no implicit
///   default-container lookup happens.
/// - The cache is process-lifetime — entries are not evicted, matching the
///   lifetime of the underlying CloudKit container objects.
public enum CloudKitContainerProvider {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: CKContainer] = [:]
    nonisolated(unsafe) internal static var factoryOverride: ((String) -> CKContainer)?

    /// Returns a cached `CKContainer` for the given identifier, creating it
    /// lazily on first access. Subsequent calls with the same identifier
    /// return the identical instance.
    public static func shared(identifier: String) -> CKContainer {
        lock.lock()
        defer { lock.unlock() }
        if let existing = cache[identifier] {
            return existing
        }
        let container = (factoryOverride ?? { CKContainer(identifier: $0) })(identifier)
        cache[identifier] = container
        return container
    }

    /// Test-only seam: clears the cache and installs an optional factory
    /// override so tests can verify caching semantics without instantiating
    /// a real CloudKit container (which traps in non-entitled unit-test
    /// hosts on macOS).
    internal static func _resetForTesting(factory: ((String) -> CKContainer)? = nil) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
        factoryOverride = factory
    }
}
#endif
