import Foundation
import LocationHistoryConsumer

/// Phase-7B — UI-nahe Day-List-Projektion auf Basis des
/// `LocalTimelineAppSessionAdapter`.
///
/// Liest ausschließlich `days(forImportId:)` aus dem Store-Reader, ohne
/// `coord_blob`, ohne Path-Koordinaten und ohne `AppExport`-Materialisierung.
/// Dient als Foundation-only Presentation-Layer, der später von einem
/// SwiftUI-DayList-View konsumiert werden kann (UI-Hook ist Phase 8).
public struct LocalTimelineDayListViewState: Equatable {

    /// UI-nahe Day-Zeile. Mirroring der relevanten Felder von `DaySummary`,
    /// damit der Konsument bei einem späteren UI-Hook keine Felder ergänzen
    /// muss. Bewusst Foundation-Only — kein SwiftUI-Symbol.
    public struct Row: Equatable {
        public let dayId: String
        public let date: String
        public let routeCount: Int
        public let visitCount: Int
        public let distanceM: Double
        public var hasContent: Bool { routeCount > 0 || visitCount > 0 }

        public init(dayId: String, date: String,
                    routeCount: Int, visitCount: Int, distanceM: Double) {
            self.dayId = dayId
            self.date = date
            self.routeCount = routeCount
            self.visitCount = visitCount
            self.distanceM = distanceM
        }
    }

    public let rows: [Row]
    public let importID: String
    public let sourceFilename: String

    public init(rows: [Row], importID: String, sourceFilename: String) {
        self.rows = rows
        self.importID = importID
        self.sourceFilename = sourceFilename
    }

    /// Erzeugt die Day-List aus dem Store. Sortierung newest-first, konsistent
    /// mit `DaySummaryDisplayOrdering.newestFirst` für den Legacy-Pfad
    /// (lexikographisch absteigend nach ISO-Datum entspricht numerisch
    /// newest-first für `YYYY-MM-DD`).
    public static func make(adapter: LocalTimelineAppSessionAdapter) throws
        -> LocalTimelineDayListViewState
    {
        let summaries = try adapter.daySummaries()
        let rows = summaries
            .map { Row(dayId: $0.dayId, date: $0.date,
                       routeCount: $0.routeCount, visitCount: $0.visitCount,
                       distanceM: $0.distanceM) }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date > rhs.date }
                if lhs.hasContent != rhs.hasContent {
                    return lhs.hasContent && !rhs.hasContent
                }
                return lhs.distanceM > rhs.distanceM
            }
        return LocalTimelineDayListViewState(
            rows: rows,
            importID: adapter.session.importID,
            sourceFilename: adapter.session.sourceFilename
        )
    }

    /// Convenience: direkter Aufruf, wenn nur Reader + Session vorliegen.
    public static func make(reader: LocalTimelineStoreReader,
                            session: LocalTimelineSession) throws
        -> LocalTimelineDayListViewState
    {
        try make(adapter: LocalTimelineAppSessionAdapter(reader: reader, session: session))
    }

    public var isEmpty: Bool { rows.isEmpty }
    public var rowCount: Int { rows.count }
}
