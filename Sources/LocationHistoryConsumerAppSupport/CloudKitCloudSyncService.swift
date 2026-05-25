#if canImport(CloudKit)
import Foundation
import CloudKit

// MARK: - CloudKitCloudSyncService

/// CloudKit-aware `CloudSyncService` implementation. Capability-only —
/// queries `CKAccountStatus` against the configured private container
/// when the user opts in and surfaces the result via the standard
/// `CloudSyncStatus` snapshot. **No** record reads, writes,
/// subscriptions or assets in this implementation. Records and schema
/// land in Train F.2 (see `docs/ICLOUD_SYNC_ARCHITECTURE.md` §5).
///
/// Safety contract (matches the architecture note):
/// - Only the **private** database is referenced (`privateCloudDatabase`).
/// - No public or shared database access.
/// - No imported-history synchronisation. The class never touches
///   the LocalTimelineStore, `RecordedTrackFileStore`, or the
///   in-memory `AppExport`.
/// - The container identifier is supplied by the caller — defaults to
///   `iCloud.de.roeber.LH2GPXWrapper` to match the entitlement.
/// - When `isEnabled == false`, the service stays in `.disabled` and
///   makes no CloudKit calls.
@MainActor
public final class CloudKitCloudSyncService: CloudSyncService {
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

    private let container: CKContainer
    private let containerIdentifier: String

    public init(
        containerIdentifier: String = CloudKitCloudSyncService.defaultContainerIdentifier,
        isEnabled: Bool = false
    ) {
        self.containerIdentifier = containerIdentifier
        self.container = CloudKitContainerProvider.shared(identifier: containerIdentifier)
        self.isEnabled = isEnabled
        self.status = CloudSyncStatus(
            accountStatus: isEnabled ? .couldNotDetermine : .disabled
        )
    }

    /// Default container identifier. Matches the entry in
    /// `wrapper/LH2GPXWrapper/LH2GPXWrapper.entitlements` and the
    /// Apple Developer Portal container that Train F.1 registers.
    ///
    /// `nonisolated` so the value can be read from non-MainActor
    /// contexts (e.g. as the default argument for `init`, which itself
    /// must remain `@MainActor` because the class is). Reading a
    /// `let` constant is inherently safe; this annotation just tells
    /// the Swift 6 isolation checker so 138 build warnings disappear.
    public nonisolated static let defaultContainerIdentifier = "iCloud.de.roeber.LH2GPXWrapper"

    public func refresh() async {
        guard isEnabled else { return }
        status.isWorking = true
        do {
            let raw = try await container.accountStatus()
            status = CloudSyncStatus(
                accountStatus: Self.map(raw),
                lastSyncAt: status.lastSyncAt,
                lastErrorMessage: nil,
                isWorking: false
            )
        } catch {
            // Do not leak Apple-private error metadata into logs. The
            // localizedDescription is the only field surfaced to the UI.
            status = CloudSyncStatus(
                accountStatus: .error(localizedMessage: error.localizedDescription),
                lastSyncAt: status.lastSyncAt,
                lastErrorMessage: error.localizedDescription,
                isWorking: false
            )
        }
    }

    public func disable() {
        status = CloudSyncStatus(accountStatus: .disabled)
    }

    // MARK: - Helpers

    /// Reference to the private database. Exposed for future Train F.2
    /// work; this commit does not read or write any records. The class
    /// stays a *capability* adapter, not a *sync* adapter.
    internal var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }

    static func map(_ raw: CKAccountStatus) -> CloudSyncAccountStatus {
        switch raw {
        case .available:
            return .available
        case .noAccount:
            return .signedOut
        case .restricted:
            return .restricted
        case .couldNotDetermine:
            return .couldNotDetermine
        case .temporarilyUnavailable:
            return .temporarilyUnavailable
        @unknown default:
            return .couldNotDetermine
        }
    }
}

#endif
