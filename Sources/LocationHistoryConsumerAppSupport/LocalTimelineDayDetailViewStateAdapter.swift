import Foundation
import LocationHistoryConsumer

/// Phase-7B — UI-nahe Day-Detail-Projektion auf Basis des
/// `LocalTimelineAppSessionAdapter`.
///
/// **Bounded-Read-Pflichten:**
/// 1. Liest `days` + `visits` + `activities` + Path-**Metadaten**.
/// 2. Decodiert **keine** `coord_blob`-Daten beim Detail-Aufbau.
/// 3. `coordinates(forPathId:)` ist die einzige Stelle, an der eine *einzelne*
///    Path-Geometrie explizit angefordert werden darf.
/// 4. Es entsteht **kein** `AppExport`, **kein** Tag-/Import-weites
///    `[Double]`-Array.
public struct LocalTimelineDayDetailViewStateAdapter {

    public struct ViewState: Equatable {
        public let dayId: String
        public let date: String
        public let routeCount: Int
        public let visitCount: Int
        public let distanceM: Double
        public let visits: [LocalTimelineAppSessionAdapter.VisitView]
        public let activities: [LocalTimelineAppSessionAdapter.ActivityView]
        public let paths: [LocalTimelineAppSessionAdapter.PathMetadataView]

        public var hasContent: Bool {
            !visits.isEmpty || !activities.isEmpty || !paths.isEmpty
        }

        public var totalPathPointCount: Int {
            paths.reduce(0) { $0 + $1.pointCount }
        }
    }

    public let adapter: LocalTimelineAppSessionAdapter

    public init(adapter: LocalTimelineAppSessionAdapter) {
        self.adapter = adapter
    }

    public init(reader: LocalTimelineStoreReader, session: LocalTimelineSession) {
        self.adapter = LocalTimelineAppSessionAdapter(reader: reader, session: session)
    }

    /// Bounded Detail-Aufbau. Liest **keine** Path-Koordinaten.
    public func viewState(forDayId dayId: String) throws -> ViewState? {
        guard let detail = try adapter.dayDetail(dayId: dayId) else { return nil }
        return ViewState(
            dayId: detail.day.dayId,
            date: detail.day.date,
            routeCount: detail.day.routeCount,
            visitCount: detail.day.visitCount,
            distanceM: detail.day.distanceM,
            visits: detail.visits,
            activities: detail.activities,
            paths: detail.paths
        )
    }

    /// Explizite Geometrie-Abfrage für **einen** Pfad. Decodiert den
    /// `coord_blob` lazy via `CoordBlobIterator` und liefert die Punkte als
    /// Tuple-Array. Niemals von `viewState(forDayId:)` aus aufgerufen.
    public func coordinates(forPathId pathId: String) throws
        -> [(lat: Double, lon: Double)]
    {
        try adapter.coordinates(forPathId: pathId)
    }
}
