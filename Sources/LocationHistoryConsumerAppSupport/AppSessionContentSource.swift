import Foundation

/// Phase-7A — Envelope, das eine geladene Session entweder als klassischen
/// In-Memory-`AppSessionContent` oder als feature-flagged
/// `LocalTimelineSession` (disk-first Store-Spike) trägt.
///
/// Die bestehende `AppSessionContent`-Klasse bleibt unverändert. Der
/// Store-Pfad wird ausschließlich über den `.localTimeline`-Case
/// transportiert; es wird **kein** `AppExport` rekonstruiert und es werden
/// **keine** Koordinaten eager dekodiert.
///
/// Default-Rollout ist `.inMemory`. Der `.localTimeline`-Case existiert nur,
/// wenn `LocalTimelineFeatureFlags.isLocalTimelineStoreEnabled == true` ist.
public enum AppSessionContentSource {

    /// Klassischer In-Memory-Pfad (Legacy-AppExport, Default).
    case inMemory(AppSessionContent)

    /// Feature-flagged Store-Pfad (Phase-7A Spike, nicht UI-aktiv).
    case localTimeline(LocalTimelineSession)

    public var inMemoryContent: AppSessionContent? {
        if case let .inMemory(content) = self { return content }
        return nil
    }

    public var localTimelineSession: LocalTimelineSession? {
        if case let .localTimeline(session) = self { return session }
        return nil
    }

    public var sourceFilename: String {
        switch self {
        case let .inMemory(content):
            return content.source.displayName
        case let .localTimeline(session):
            return session.sourceFilename
        }
    }
}
