import Foundation
import LocationHistoryConsumer

/// Phase-7B — Coarse-grained Presentation-Auswahl für die App-Session.
///
/// Macht für die UI-Schicht explizit, **welcher** Pfad gerade aktiv ist
/// (Legacy In-Memory `AppSessionContent` vs. Store-backed
/// `LocalTimelineSession`), ohne daß die UI selbst `nil`-Logik gegen
/// `AppSessionState.content` und `AppSessionState.localTimelineSession`
/// schreiben muß. Ein direkter SwiftUI-Hook gehört in Phase 8 — diese
/// Schicht ist absichtlich Foundation-only und liefert keine Map/Heatmap/
/// Overview-Projektionen.
public enum AppSessionActiveContent: Equatable {
    case none
    case legacy(AppSessionContent)
    case localTimeline(LocalTimelineSession)

    public static func == (lhs: AppSessionActiveContent, rhs: AppSessionActiveContent) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none): return true
        case let (.legacy(a), .legacy(b)): return a === b
        case let (.localTimeline(a), .localTimeline(b)): return a == b
        default: return false
        }
    }

    public var isLocalTimeline: Bool {
        if case .localTimeline = self { return true }
        return false
    }

    public var isLegacy: Bool {
        if case .legacy = self { return true }
        return false
    }
}

extension AppSessionState {

    /// Welcher Inhalts-Pfad ist im aktuellen State aktiv? Invariante:
    /// `legacy` und `localTimeline` schließen sich gegenseitig aus —
    /// `show(content:)` und `show(localTimeline:)` setzen jeweils die
    /// andere Quelle auf `nil`, `clearContent()` räumt beide.
    public var activeContent: AppSessionActiveContent {
        if let session = localTimelineSession { return .localTimeline(session) }
        if let content = content { return .legacy(content) }
        return .none
    }

    /// True, wenn der Store-Pfad aktiv ist (Phase-7A/7B). UI-Schichten
    /// können hierüber entscheiden, ob sie den Store-backed DayList/Detail-
    /// Adapter statt der Legacy-`AppSessionContent`-Projektionen
    /// konsumieren.
    public var isLocalTimelineActive: Bool {
        localTimelineSession != nil
    }
}
