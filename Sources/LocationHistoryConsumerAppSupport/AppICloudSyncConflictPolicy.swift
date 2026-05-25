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
    /// Full user-facing title for the menu-picker selection.
    public var titleKey: String {
        switch self {
        case .manual:      return "Manuell auflösen"
        case .preferLocal: return "Lokale Kopie bevorzugen"
        case .preferCloud: return "iCloud-Kopie bevorzugen"
        }
    }

    /// Short label for narrow UI surfaces (e.g. compact picker / chips).
    public var shortTitleKey: String {
        switch self {
        case .manual:      return "Manuell"
        case .preferLocal: return "Lokal"
        case .preferCloud: return "iCloud"
        }
    }

    /// Short description suitable for a settings row caption.
    public var captionKey: String {
        switch self {
        case .manual:
            return "Zeigt einen Vergleich, wenn lokale und iCloud-Metadaten voneinander abweichen."
        case .preferLocal:
            return "Behält bei einem Konflikt automatisch die lokale Kopie."
        case .preferCloud:
            return "Behält bei einem Konflikt automatisch die iCloud-Kopie."
        }
    }
}
