import Foundation
import LocationHistoryConsumer

/// Phase-8A — store-backed Map-Data-Provider.
///
/// `StoreBackedMapDataProvider` ist die Foundation-only Adapter-Schicht
/// zwischen `LocalTimelineStoreReader` und einem **renderer-unabhängigen**
/// Karten-Konsumenten. Der Provider verdrahtet **kein** SwiftUI-`Map`,
/// **kein** `MKMapView` und **keinen** Heatmap-Renderer; das bleibt
/// Phase 8B/9.
///
/// **Bounded-read-Garantien**:
/// 1. `routeCandidates(...)` und `dayRouteCandidates(...)` lesen ausschließlich
///    Path-Metadaten (kein `coord_blob`-Decoding, kein `[Double]`).
/// 2. `routeGeometry(...)` dekodiert **genau einen** Pfad, lazy via
///    `CoordBlobIterator`, mit hartem Punktbudget.
/// 3. `overviewRoutes(query:)` ist doppelt bounded: über `maxRoutes` und
///    `budget.maxTotalPoints`. Es wird nie eine vollständige Import-Geometrie
///    materialisiert.
/// 4. Kein Pfad in dieser Datei rekonstruiert ein `AppExport`.
public final class StoreBackedMapDataProvider {

    private let reader: LocalTimelineStoreReader

    public init(reader: LocalTimelineStoreReader) {
        self.reader = reader
    }

    // MARK: - Kandidaten (Metadata-only)

    /// Path-Kandidaten innerhalb des Viewports für einen ganzen Import.
    /// Sortiert newest-first per `start_time DESC` (NULL-Times zuletzt).
    public func routeCandidates(importID: String,
                                viewport: LocalTimelineMapViewport,
                                limit: Int) throws -> [LocalTimelineMapRouteCandidate] {
        guard limit >= 0 else { throw LocalTimelineMapProviderError.invalidLimit(limit) }
        if limit == 0 { return [] }
        let rows = try reader.pathMetadata(forImportId: importID,
                                           viewport: viewport,
                                           limit: limit)
        return rows.map(Self.toCandidate(_:))
    }

    /// Path-Kandidaten innerhalb des Viewports für einen einzelnen Tag.
    public func dayRouteCandidates(dayID: String,
                                   viewport: LocalTimelineMapViewport,
                                   limit: Int) throws -> [LocalTimelineMapRouteCandidate] {
        guard limit >= 0 else { throw LocalTimelineMapProviderError.invalidLimit(limit) }
        if limit == 0 { return [] }
        let rows = try reader.pathMetadata(forDayId: dayID,
                                           viewport: viewport,
                                           limit: limit)
        return rows.map(Self.toCandidate(_:))
    }

    // MARK: - Geometrie (genau ein Pfad)

    /// Lazy-decoded Geometrie eines einzelnen Pfads, bounded auf `maxPoints`.
    /// Sucht zuerst die Path-Metadata für `originalPointCount`, dekodiert dann
    /// genau diesen Blob via `CoordBlobIterator` und reicht den Stream an
    /// `LocalTimelineRouteDecimator` weiter.
    public func routeGeometry(pathID: String,
                              detailLevel: LocalTimelineMapDetailLevel,
                              maxPoints: Int) throws -> LocalTimelineMapRouteGeometry {
        guard maxPoints >= 1 else { throw LocalTimelineMapProviderError.invalidLimit(maxPoints) }
        guard let meta = try reader.pathRecord(id: pathID) else {
            throw LocalTimelineMapProviderError.unknownPath(pathID: pathID)
        }
        let iterator: CoordBlobIterator
        do {
            iterator = try reader.coordinateSequence(forPathId: pathID)
        } catch let err as LocalTimelineStoreReader.ReaderError {
            switch err {
            case .unknownPath(let id):
                throw LocalTimelineMapProviderError.unknownPath(pathID: id)
            case .malformedCoordBlob(let id, let n):
                throw LocalTimelineMapProviderError.malformedCoordBlob(pathID: id, byteCount: n)
            }
        }
        let points = LocalTimelineRouteDecimator.decimate(
            iterator,
            originalPointCount: meta.pointCount,
            maxPoints: maxPoints
        )
        return LocalTimelineMapRouteGeometry(
            pathID: pathID,
            detailLevel: detailLevel,
            originalPointCount: meta.pointCount,
            points: points
        )
    }

    // MARK: - Overview (doppelt bounded)

    /// Bounded Overview: liefert höchstens `query.maxRoutes` Geometrien und
    /// insgesamt höchstens `query.budget.maxTotalPoints`. Pro Pfad wird
    /// `query.budget.maxPointsPerRoute` strikt eingehalten.
    public func overviewRoutes(query: LocalTimelineMapQuery) throws
        -> LocalTimelineMapOverviewResponse
    {
        guard query.maxRoutes >= 0 else {
            throw LocalTimelineMapProviderError.invalidLimit(query.maxRoutes)
        }
        if query.maxRoutes == 0 {
            return LocalTimelineMapOverviewResponse(
                importID: query.importID,
                detailLevel: query.viewport.detailLevel,
                routes: [],
                truncatedRoutes: false,
                truncatedPoints: false
            )
        }

        // Über-Fetch um 1 Eintrag, um `truncatedRoutes` ehrlich zu signalisieren.
        let overFetch = query.maxRoutes &+ 1
        let candidates = try reader.pathMetadata(forImportId: query.importID,
                                                 viewport: query.viewport,
                                                 limit: overFetch)
        let truncatedRoutes = candidates.count > query.maxRoutes
        let selected = truncatedRoutes ? Array(candidates.prefix(query.maxRoutes)) : candidates

        var routes: [LocalTimelineMapRouteGeometry] = []
        routes.reserveCapacity(selected.count)
        var remainingTotal = query.budget.maxTotalPoints
        var truncatedPoints = false

        for candidate in selected {
            if remainingTotal <= 0 {
                truncatedPoints = true
                break
            }
            let perRouteCap = min(query.budget.maxPointsPerRoute, remainingTotal)
            let geometry = try routeGeometry(pathID: candidate.id,
                                             detailLevel: query.viewport.detailLevel,
                                             maxPoints: perRouteCap)
            // Wenn der Originalpfad mehr Punkte hatte als wir liefern konnten
            // **und** die Caps schon gegriffen haben, dann ist das ein
            // truncatedPoints-Signal — aber nur, wenn der Verlust ursächlich
            // durch das Total-Budget entstand, nicht durch den Per-Route-Cap.
            if perRouteCap < query.budget.maxPointsPerRoute
                && geometry.originalPointCount > geometry.points.count
            {
                truncatedPoints = true
            }
            remainingTotal -= geometry.points.count
            routes.append(geometry)
        }

        return LocalTimelineMapOverviewResponse(
            importID: query.importID,
            detailLevel: query.viewport.detailLevel,
            routes: routes,
            truncatedRoutes: truncatedRoutes,
            truncatedPoints: truncatedPoints
        )
    }

    // MARK: - Bounds-Aggregate

    /// Aggregierte Bbox über alle Pfade eines Imports. Nutzt die
    /// `min/max_lat/lon`-Spalten von `paths`. **Liest keine Geometrie.**
    public func mapBounds(forImportID importID: String) throws -> LocalTimelineMapBounds? {
        guard let bbox = try reader.pathBoundingBox(forImportId: importID) else { return nil }
        return LocalTimelineMapBounds(minLat: bbox.minLat, minLon: bbox.minLon,
                                      maxLat: bbox.maxLat, maxLon: bbox.maxLon)
    }

    public func mapBounds(forDayID dayID: String) throws -> LocalTimelineMapBounds? {
        guard let bbox = try reader.pathBoundingBox(forDayId: dayID) else { return nil }
        return LocalTimelineMapBounds(minLat: bbox.minLat, minLon: bbox.minLon,
                                      maxLat: bbox.maxLat, maxLon: bbox.maxLon)
    }

    // MARK: - Mapping

    private static func toCandidate(_ row: LocalTimelinePathRecord) -> LocalTimelineMapRouteCandidate {
        LocalTimelineMapRouteCandidate(
            pathID: row.id, dayID: row.dayId,
            startTime: row.startTime, endTime: row.endTime,
            mode: row.mode, distanceM: row.distanceM, pointCount: row.pointCount,
            minLat: row.minLat, minLon: row.minLon,
            maxLat: row.maxLat, maxLon: row.maxLon
        )
    }
}
