import Foundation

/// Conflict-resolution policy gate for the (deferred) iCloud sync engine.
///
/// **Today** this is purely a stored user preference — the app does not write
/// or read CloudKit records (see `CloudKitLiveTrackMetadataSchema.swift` and
/// `docs/ICLOUD_SYNC_ARCHITECTURE.md`). The preference is surfaced in the
/// iCloud settings screen so the user can pick a policy in advance of the
/// sync-engine train; until that train ships, toggling has no runtime effect.
public enum AppICloudSyncConflictPolicy: String, CaseIterable, Codable, Hashable, Sendable {
    case manual
    case preferLocal
    case preferCloud

    /// User-facing title key. Pass through `AppLanguagePreference.localized`
    /// at the call site to localize.
    public var titleKey: String {
        switch self {
        case .manual:      return "Resolve manually"
        case .preferLocal: return "Prefer local copy"
        case .preferCloud: return "Prefer iCloud copy"
        }
    }

    /// Short description suitable for a settings row caption.
    public var captionKey: String {
        switch self {
        case .manual:
            return "Show a side-by-side comparison whenever local and iCloud metadata disagree."
        case .preferLocal:
            return "Silently keep the local copy when there is a conflict."
        case .preferCloud:
            return "Silently keep the iCloud copy when there is a conflict."
        }
    }
}
