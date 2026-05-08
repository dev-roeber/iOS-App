import Foundation
import LocationHistoryConsumer

/// Phase-9B — Foundation-only Quelle für Store-DayList/DayDetail-UI.
///
/// Kapselt den Zugriff auf den Store hinter Closures, damit die
/// SwiftUI-Views (`LocalTimelineDayListView`, `LocalTimelineDayDetailView`)
/// vollständig auf Linux gegen In-Memory-Daten testbar bleiben und der
/// produktive Pfad keine Disk-I/O in der View-Schicht hält. Die Source
/// hält selbst keinen Reader/Store offen — der Owner (Production-Factory
/// oder Test-Stub) verwaltet die Lebensdauer.
///
/// Bounded-Read-Pflichten:
/// - `loadList` darf **keine** `coord_blob`-Daten lesen.
/// - `loadDetail` darf **keine** Pfad-Koordinaten dekodieren.
/// - Path-Geometrie ist explizit und Phase-9B-fern (kein Map-/Polyline-UI).
public struct LocalTimelineDayBrowserSource {
    public let session: LocalTimelineSession
    public let loadList: () throws -> LocalTimelineDayListViewState
    public let loadDetail: (String) throws -> LocalTimelineDayDetailViewStateAdapter.ViewState?

    public init(session: LocalTimelineSession,
                loadList: @escaping () throws -> LocalTimelineDayListViewState,
                loadDetail: @escaping (String) throws
                    -> LocalTimelineDayDetailViewStateAdapter.ViewState?) {
        self.session = session
        self.loadList = loadList
        self.loadDetail = loadDetail
    }

    /// Convenience: bindet die Source an einen bereits geöffneten Reader.
    /// Der Reader/Store muss vom Aufrufer am Leben gehalten werden, solange
    /// die Source benutzt wird.
    public static func bind(session: LocalTimelineSession,
                            reader: LocalTimelineStoreReader)
        -> LocalTimelineDayBrowserSource
    {
        let listAdapter = LocalTimelineAppSessionAdapter(reader: reader, session: session)
        let detailAdapter = LocalTimelineDayDetailViewStateAdapter(adapter: listAdapter)
        return LocalTimelineDayBrowserSource(
            session: session,
            loadList: { try LocalTimelineDayListViewState.make(adapter: listAdapter) },
            loadDetail: { dayId in try detailAdapter.viewState(forDayId: dayId) }
        )
    }
}
