import Foundation
import LocationHistoryConsumer

/// Phase-6 — Adapter, der Store-Daten in bounded, UI-nahe ViewState-Modelle
/// projiziert, **ohne** den vollständigen Import in `[Double]` oder
/// `AppExport` zu materialisieren.
///
/// Die hier exponierten Modelle sind bewusst eigenständig (nicht die alten
/// `AppExport`-View-Modelle), damit der Store-Pfad isoliert testbar bleibt.
/// Der Hook in die produktive UI (DayList/DayDetail/Map) erfolgt explizit
/// in Phase 7.
public struct LocalTimelineAppSessionAdapter {

    public let reader: LocalTimelineStoreReader
    public let session: LocalTimelineSession

    public init(reader: LocalTimelineStoreReader, session: LocalTimelineSession) {
        self.reader = reader
        self.session = session
    }

    // MARK: - ViewState-Modelle (Store-spezifisch, bounded)

    public struct DaySummaryView: Equatable {
        public let dayId: String
        public let date: String
        public let routeCount: Int
        public let visitCount: Int
        public let distanceM: Double

        public init(dayId: String, date: String,
                    routeCount: Int, visitCount: Int, distanceM: Double) {
            self.dayId = dayId
            self.date = date
            self.routeCount = routeCount
            self.visitCount = visitCount
            self.distanceM = distanceM
        }
    }

    public struct VisitView: Equatable {
        public let id: String
        public let startTime: String?
        public let endTime: String?
        public let latitude: Double?
        public let longitude: Double?
        public let name: String?

        public init(id: String, startTime: String?, endTime: String?,
                    latitude: Double?, longitude: Double?, name: String?) {
            self.id = id
            self.startTime = startTime
            self.endTime = endTime
            self.latitude = latitude
            self.longitude = longitude
            self.name = name
        }
    }

    public struct ActivityView: Equatable {
        public let id: String
        public let startTime: String?
        public let endTime: String?
        public let mode: String?
        public let distanceM: Double?

        public init(id: String, startTime: String?, endTime: String?,
                    mode: String?, distanceM: Double?) {
            self.id = id
            self.startTime = startTime
            self.endTime = endTime
            self.mode = mode
            self.distanceM = distanceM
        }
    }

    public struct PathMetadataView: Equatable {
        public let id: String
        public let mode: String?
        public let distanceM: Double
        public let pointCount: Int
        public let startTime: String?
        public let endTime: String?

        public init(id: String, mode: String?, distanceM: Double,
                    pointCount: Int, startTime: String?, endTime: String?) {
            self.id = id
            self.mode = mode
            self.distanceM = distanceM
            self.pointCount = pointCount
            self.startTime = startTime
            self.endTime = endTime
        }
    }

    public struct DayDetailView: Equatable {
        public let day: DaySummaryView
        public let visits: [VisitView]
        public let activities: [ActivityView]
        public let paths: [PathMetadataView]

        public init(day: DaySummaryView,
                    visits: [VisitView],
                    activities: [ActivityView],
                    paths: [PathMetadataView]) {
            self.day = day
            self.visits = visits
            self.activities = activities
            self.paths = paths
        }
    }

    // MARK: - Bounded Reads

    /// Day-Listen-Projektion. Liest nur Day-Metadaten, keine Geometrie.
    public func daySummaries() throws -> [DaySummaryView] {
        try reader.days(forImportId: session.importID).map { record in
            DaySummaryView(dayId: record.id,
                           date: record.date,
                           routeCount: record.routeCount,
                           visitCount: record.visitCount,
                           distanceM: record.distanceM)
        }
    }

    /// Day-Detail-Projektion. Liest Visits/Activities/Path-Metadaten, aber
    /// **nicht** die Koordinaten der Pfade.
    public func dayDetail(dayId: String) throws -> DayDetailView? {
        guard let snap = try reader.dayDetail(dayId: dayId) else { return nil }
        let day = DaySummaryView(dayId: snap.day.id,
                                 date: snap.day.date,
                                 routeCount: snap.day.routeCount,
                                 visitCount: snap.day.visitCount,
                                 distanceM: snap.day.distanceM)
        let visits = snap.visits.map {
            VisitView(id: $0.id,
                      startTime: $0.startTime,
                      endTime: $0.endTime,
                      latitude: $0.latitude,
                      longitude: $0.longitude,
                      name: $0.name)
        }
        let activities = snap.activities.map {
            ActivityView(id: $0.id,
                         startTime: $0.startTime,
                         endTime: $0.endTime,
                         mode: $0.mode,
                         distanceM: $0.distanceM)
        }
        let paths = snap.paths.map {
            PathMetadataView(id: $0.id,
                             mode: $0.mode,
                             distanceM: $0.distanceM,
                             pointCount: $0.pointCount,
                             startTime: $0.startTime,
                             endTime: $0.endTime)
        }
        return DayDetailView(day: day, visits: visits,
                             activities: activities, paths: paths)
    }

    /// **Explizite** Koordinaten-Decodierung für *einen* Pfad. Wird nur
    /// aufgerufen, wenn der UI-Konsument Geometrie tatsächlich braucht
    /// (z. B. Detail-Karte für einen einzelnen Tag).
    public func coordinates(forPathId pathId: String) throws -> [(lat: Double, lon: Double)] {
        var iterator = try reader.coordinateSequence(forPathId: pathId)
        var out: [(lat: Double, lon: Double)] = []
        while let point = iterator.next() {
            out.append((lat: point.latitude, lon: point.longitude))
        }
        return out
    }
}
