import Foundation

/// Phase-7B — Presentation/ViewModel-Schicht für „Importierte lokale
/// Timeline-Daten löschen".
///
/// Wrapper um `LocalTimelineDeletionService`, die der Settings-/Technical-UI
/// (Phase 8) eine stabile, testbare API liefert, ohne daß der View den
/// Lifecycle-Manager direkt halten oder Filesystem-Pfade kennen muss.
///
/// **Sichtbarkeit:** Der Konsument soll die UI-Aktion nur dann anbieten,
/// wenn `isAvailable == true` (Store existiert oder Debug/Technical-Kontext).
///
/// **Bookmark/Preferences-Cleanup:** Der aktuelle Store-Pfad schreibt **keine**
/// neuen Bookmarks oder Preferences-Keys (vgl. `LocalTimelineDeletionService`-
/// Doku). Sollte sich das in einer späteren Phase ändern, gehört der Cleanup
/// in genau diesen Presenter.
public final class LocalTimelineDeletionPresentation {

    public enum Result: Equatable {
        case deleted(LocalTimelineStoreLifecycle.Report)
        case failed(String)
    }

    public let service: LocalTimelineDeletionService
    public private(set) var lastResult: Result?

    /// Liefert eine offene Store-Referenz, falls die UI eine bereits geöffnete
    /// Session beim Löschen mit angeben muss (damit der Lifecycle die Datei
    /// schließen kann, bevor sie entfernt wird).
    public var openStoreProvider: (() -> LocalTimelineStore?)?

    /// Sichtbarkeitsregel — UI darf den Button nur anzeigen, wenn dies `true`
    /// ist. Per Default an, weil der Service idempotent ist; spezielle
    /// Technical-Surfaces können die Bedingung verschärfen.
    public var isAvailable: Bool

    public init(service: LocalTimelineDeletionService,
                isAvailable: Bool = true,
                openStoreProvider: (() -> LocalTimelineStore?)? = nil) {
        self.service = service
        self.isAvailable = isAvailable
        self.openStoreProvider = openStoreProvider
    }

    /// Idempotente Lösch-Aktion. Mehrfaches Aufrufen ist erlaubt; die zweite
    /// Ausführung gegen einen leeren Store liefert einen Report ohne
    /// `rowWipeError` und mit leeren `removedDBFiles`/`removedDirectories`.
    @discardableResult
    public func performDelete() -> Result {
        do {
            let report = try service.deleteAll(openStore: openStoreProvider?())
            let result = Result.deleted(report)
            lastResult = result
            return result
        } catch {
            let result = Result.failed(String(describing: error))
            lastResult = result
            return result
        }
    }
}
