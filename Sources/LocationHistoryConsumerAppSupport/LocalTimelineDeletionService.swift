import Foundation

/// Phase-6 — Service-API für „Importierte Daten löschen".
///
/// Dünner, idempotenter Wrapper um `LocalTimelineStoreLifecycle.deleteAllLocalTimelineData`.
/// **Kein UI-Hook** — der Settings-Eintrag ist Phase-7. Der Service existiert
/// vor allem, damit eine spätere UI-Schicht eine stabile, testbare Schnittstelle
/// vorfindet, ohne den Lifecycle-Manager direkt anzufassen.
///
/// **Kein UserDefaults-Cleanup**, solange keine produktiven Store-Keys in den
/// Preferences existieren. Bookmark-/Preferences-Cleanup bleibt offene
/// Phase-7-Pflicht (siehe NEXT_STEPS).
public struct LocalTimelineDeletionService {

    public let lifecycle: LocalTimelineStoreLifecycle

    public init(lifecycle: LocalTimelineStoreLifecycle) {
        self.lifecycle = lifecycle
    }

    /// Idempotent: Aufruf gegen einen bereits geleerten Store schlägt nicht
    /// fehl, sondern liefert einen Report mit leerem `removedDBFiles`/
    /// `removedDirectories`-Set.
    @discardableResult
    public func deleteAll(openStore: LocalTimelineStore? = nil) throws -> LocalTimelineStoreLifecycle.Report {
        try lifecycle.deleteAllLocalTimelineData(store: openStore)
    }
}
