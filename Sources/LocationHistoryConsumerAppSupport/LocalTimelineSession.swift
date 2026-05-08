import Foundation

/// Phase-6 — Session-Modell für den Store-backed AppSession-Pfad.
///
/// Eine `LocalTimelineSession` bündelt Identifikation, Quelle und
/// aggregierte Counter für einen bereits in den lokalen SQLite-Store
/// importierten Datensatz. Die Session **enthält keine geometrischen
/// Daten** — Koordinaten werden ausschließlich on-demand über den
/// `LocalTimelineStoreReader` (lazy via `CoordBlobIterator`) geladen.
///
/// **Lifetime / Ownership:**
/// - Der zugrundeliegende `LocalTimelineStore` wird vom *Aufrufer* geöffnet
///   und freigegeben (typischerweise `LocalTimelineStoreFactory.openStore()`
///   + `LocalTimelineStoreLifecycle`). Die Session hält nur eine
///   schwache Referenz auf den `Reader`; sie verlängert die Lebensdauer
///   nicht künstlich. Wer die Session erzeugt, ist verpflichtet, den
///   Store nach Gebrauch zu schließen, bevor die Datei entfernt wird
///   (siehe Phase-4 WAL-Lifecycle).
/// - Es wird **kein `AppExport`** materialisiert.
/// - Es wird **keine vollständige `[Double]`-Importgeometrie** gehalten.
public struct LocalTimelineSession: Equatable {

    public struct Summary: Equatable {
        public let dayCount: Int
        public let pathCount: Int
        public let visitCount: Int
        public let activityCount: Int
        public let totalDistanceM: Double
        public let dateRange: ClosedRange<String>?

        public init(dayCount: Int,
                    pathCount: Int,
                    visitCount: Int,
                    activityCount: Int,
                    totalDistanceM: Double,
                    dateRange: ClosedRange<String>?) {
            self.dayCount = dayCount
            self.pathCount = pathCount
            self.visitCount = visitCount
            self.activityCount = activityCount
            self.totalDistanceM = totalDistanceM
            self.dateRange = dateRange
        }
    }

    public let importID: String
    public let sourceFilename: String
    public let storeURL: URL
    public let createdAt: String
    public let importedAt: String
    public let summary: Summary

    public init(importID: String,
                sourceFilename: String,
                storeURL: URL,
                createdAt: String,
                importedAt: String,
                summary: Summary) {
        self.importID = importID
        self.sourceFilename = sourceFilename
        self.storeURL = storeURL
        self.createdAt = createdAt
        self.importedAt = importedAt
        self.summary = summary
    }
}

extension LocalTimelineSession {

    /// Baut eine Session aus einem bereits geöffneten Reader, indem alle
    /// nötigen Aggregat-Counter bounded gezählt werden. Geometrie wird
    /// **nicht** geladen.
    public static func make(reader: LocalTimelineStoreReader,
                            importID: String,
                            storeURL: URL) throws -> LocalTimelineSession {
        guard let record = try reader.importRecord(id: importID) else {
            throw LocalTimelineSessionError.unknownImport(importID: importID)
        }

        let dayCount = try reader.days(forImportId: importID).count
        let routeCount = try reader.totalRouteCount(forImportId: importID)
        let visitCount = try reader.totalVisitCount(forImportId: importID)
        let totalDistance = try reader.totalDistance(forImportId: importID)
        let dateRange = try reader.dayDateRange(forImportId: importID)

        // Activity-Counter via Day-Detail-Aggregation (bounded; pro Tag).
        var activityCount = 0
        for day in try reader.days(forImportId: importID) {
            if let detail = try reader.dayDetail(dayId: day.id) {
                activityCount += detail.activities.count
            }
        }

        let summary = Summary(
            dayCount: dayCount,
            pathCount: routeCount,
            visitCount: visitCount,
            activityCount: activityCount,
            totalDistanceM: totalDistance,
            dateRange: dateRange)

        return LocalTimelineSession(
            importID: record.id,
            sourceFilename: record.sourceFilename,
            storeURL: storeURL,
            createdAt: record.createdAt,
            importedAt: record.createdAt,
            summary: summary)
    }
}

public enum LocalTimelineSessionError: Error, Equatable, CustomStringConvertible {
    case unknownImport(importID: String)

    public var description: String {
        switch self {
        case let .unknownImport(id):
            return "unknownImport(importID: \(id))"
        }
    }
}
