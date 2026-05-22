import Foundation

// MARK: - Public surface

/// User-facing state of the iCloud integration. Stays small on purpose:
/// each case maps to exactly one `LHXSyncStatusCard.StatusKind` so the
/// Settings UI can render without further translation. The service is
/// intentionally CloudKit-/SwiftUI-/UIKit-free so the package keeps
/// building on Linux.
public enum CloudSyncAccountStatus: Sendable, Equatable {
    /// User has not opted in. No iCloud calls are made.
    case disabled
    /// Opted in and the iCloud container is reachable.
    case available
    /// Opted in but the device is not currently signed into iCloud.
    case signedOut
    /// Opted in but iCloud is restricted (parental controls, MDM, etc.).
    case restricted
    /// Opted in but the system could not determine the status yet — UI
    /// should show a neutral "checking…" state and retry later.
    case couldNotDetermine
    /// Opted in but the system reports a temporary outage.
    case temporarilyUnavailable
    /// Opted in but the last call against iCloud returned a hard error.
    /// Caller can show the error message but must not assume the cache
    /// is stale; local-only operation remains the truth.
    case error(localizedMessage: String)
}

/// Lightweight snapshot of the current sync state. The service publishes
/// this struct whenever any field changes. UI binds against it via the
/// usual observation patterns (`@StateObject`, `Combine.Publisher`, etc.)
/// in the consuming view layer.
public struct CloudSyncStatus: Sendable, Equatable {
    public var accountStatus: CloudSyncAccountStatus
    public var lastSyncAt: Date?
    public var lastErrorMessage: String?
    public var isWorking: Bool

    public init(
        accountStatus: CloudSyncAccountStatus = .disabled,
        lastSyncAt: Date? = nil,
        lastErrorMessage: String? = nil,
        isWorking: Bool = false
    ) {
        self.accountStatus = accountStatus
        self.lastSyncAt = lastSyncAt
        self.lastErrorMessage = lastErrorMessage
        self.isWorking = isWorking
    }
}

/// Abstract iCloud-sync service. Implementations must be safe to call
/// even when the iCloud capability is not enabled in the Xcode project
/// (the default implementation in this package returns `.disabled`).
///
/// Concrete CloudKit-backed implementation lives in the Apple-Xcode
/// pass (`Train F` follow-up). The protocol stays Foundation-only so
/// unit tests on Linux do not pull `CloudKit`.
@MainActor
public protocol CloudSyncService: AnyObject {
    /// Current snapshot. UI reads this on render.
    var status: CloudSyncStatus { get }

    /// True iff the user has opted in. Backed by
    /// `AppPreferences.iCloudSyncEnabled` in production. Setting `false`
    /// must stop all in-flight sync work and reset `lastSyncAt`.
    var isEnabled: Bool { get set }

    /// Re-checks the iCloud account status and, if available, kicks off
    /// a best-effort refresh. Must remain a no-op when `isEnabled` is
    /// `false`. Errors are surfaced via `status.lastErrorMessage`, the
    /// method itself never throws.
    func refresh() async

    /// Performs a graceful shutdown of any pending work and clears
    /// transient state. Idempotent.
    func disable()
}

// MARK: - Default implementation

/// Foundation-only default implementation. Returns `.disabled` whenever
/// the user has not opted in and `.couldNotDetermine` while opted in but
/// the iCloud capability is not active in the Xcode project. Once the
/// Apple-side capability is enabled in Xcode (see
/// `docs/ICLOUD_SYNC_ARCHITECTURE.md`), this class will be replaced by
/// a CloudKit-aware version in a follow-up commit.
@MainActor
public final class DefaultCloudSyncService: CloudSyncService {
    public private(set) var status: CloudSyncStatus
    public var isEnabled: Bool {
        didSet {
            if isEnabled == oldValue { return }
            if isEnabled {
                status = CloudSyncStatus(
                    accountStatus: .couldNotDetermine,
                    lastSyncAt: status.lastSyncAt,
                    lastErrorMessage: nil,
                    isWorking: true
                )
            } else {
                disable()
            }
        }
    }

    public init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
        self.status = CloudSyncStatus(
            accountStatus: isEnabled ? .couldNotDetermine : .disabled
        )
    }

    public func refresh() async {
        guard isEnabled else { return }
        // No CloudKit call here on purpose — the Apple-side capability
        // is the gate. Once a CloudKit-aware subclass takes over, this
        // method becomes the place to call `CKContainer.accountStatus`
        // and a private-database fetch. Until then, the service stays
        // in `.couldNotDetermine` to signal honestly that no iCloud
        // round-trip happened.
        status.isWorking = false
    }

    public func disable() {
        status = CloudSyncStatus(accountStatus: .disabled)
    }
}

// MARK: - In-memory test double

/// Deterministic in-memory `CloudSyncService` for previews and Linux
/// unit tests. Lets callers script status transitions without bringing
/// in CloudKit.
@MainActor
public final class InMemoryCloudSyncService: CloudSyncService {
    public var status: CloudSyncStatus
    public var isEnabled: Bool

    public init(isEnabled: Bool = false, status: CloudSyncStatus = .init()) {
        self.isEnabled = isEnabled
        self.status = status
    }

    public func refresh() async { /* no-op */ }
    public func disable() {
        isEnabled = false
        status = CloudSyncStatus(accountStatus: .disabled)
    }
}
