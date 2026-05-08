import Foundation
import LocationHistoryConsumer

/// Phase-10B (Weg 3) — Foundation-only Provider für den Store-backed
/// Punktelayer.
///
/// **Bounded-read-Garantien**:
///
/// 1. Visits + Activity-Endpunkte werden **ausschließlich** aus den
///    metadata-only Spalten gelesen (`latitude/longitude` bzw.
///    `start_lat/start_lon` / `end_lat/end_lon`) — kein `coord_blob`-Decoding.
/// 2. Route-Sample-Punkte werden lazy via `CoordBlobIterator` und
///    `LocalTimelineRouteDecimator` gezogen. Pro Pfad höchstens
///    `budget.maxRouteSamplePointsPerRoute` Punkte; insgesamt nie mehr als
///    `budget.maxPointLayerSamples` Punkte.
/// 3. Es entsteht **keine** vollständige Import-Geometrie, **kein**
///    `[Double]`-Buffer und **kein** `AppExport`.
/// 4. Ausgabe ist deterministisch sortiert (kind-asc, dann referenceID-asc,
///    dann sampleIndex-asc) — jede Wiederholung mit gleichem Input liefert
///    den gleichen Output.
public final class LocalTimelineMapPointLayerProvider {

    private let reader: LocalTimelineStoreReader

    public init(reader: LocalTimelineStoreReader) {
        self.reader = reader
    }

    // MARK: - Public API

    /// Bounded Punktelayer-Antwort für einen einzelnen Tag.
    public func dayPointCandidates(
        dayID: String,
        viewport: LocalTimelineMapViewport,
        budget: LocalTimelineMapPerformanceBudget
    ) throws -> LocalTimelineMapPointLayerResponse {
        try assertBudget(budget)
        guard let snapshot = try reader.dayDetail(dayId: dayID) else {
            throw LocalTimelineMapPointLayerError.unknownDay(dayID: dayID)
        }
        return try buildResponse(
            viewport: viewport,
            budget: budget,
            visitsAndActivities: [(snapshot.visits, snapshot.activities)],
            pathCandidates: snapshot.paths.filter { Self.intersects(path: $0, viewport: viewport) }
        )
    }

    /// Bounded Punktelayer-Antwort für einen ganzen Import.
    /// Iteriert über Tage des Imports und aggregiert Visits/Activities/Path-
    /// Samples bis `budget.maxPointLayerSamples` erreicht ist. Über
    /// `budget.maxRouteCandidates` werden ehrlich Pfad-Truncation-Signale
    /// gesetzt — der Provider stoppt das Decoding sobald das Sample-Budget
    /// ausgeschöpft ist.
    public func pointCandidates(
        importID: String,
        viewport: LocalTimelineMapViewport,
        budget: LocalTimelineMapPerformanceBudget
    ) throws -> LocalTimelineMapPointLayerResponse {
        try assertBudget(budget)
        let days = try reader.days(forImportId: importID)
        if days.isEmpty {
            // Kein Import gefunden → unknownImport, falls auch kein
            // ImportRecord vorhanden; sonst leere Antwort.
            if try reader.importRecord(id: importID) == nil {
                throw LocalTimelineMapPointLayerError.unknownImport(importID: importID)
            }
        }
        var visitsAndActivities: [([LocalTimelineVisitRecord], [LocalTimelineActivityRecord])] = []
        var allPaths: [LocalTimelinePathRecord] = []
        let candidatesCap = budget.maxRouteCandidates
        for day in days {
            guard let snapshot = try reader.dayDetail(dayId: day.id) else { continue }
            visitsAndActivities.append((snapshot.visits, snapshot.activities))
            for path in snapshot.paths where Self.intersects(path: path, viewport: viewport) {
                if allPaths.count >= candidatesCap { break }
                allPaths.append(path)
            }
            if allPaths.count >= candidatesCap { break }
        }
        return try buildResponse(
            viewport: viewport,
            budget: budget,
            visitsAndActivities: visitsAndActivities,
            pathCandidates: allPaths
        )
    }

    /// Cluster über die Punktelayer-Antwort eines Tages.
    public func dayClusteredPoints(
        dayID: String,
        viewport: LocalTimelineMapViewport,
        budget: LocalTimelineMapPerformanceBudget,
        cellSizeDegrees: Double? = nil
    ) throws -> LocalTimelineMapPointClusterResponse {
        let raw = try dayPointCandidates(dayID: dayID, viewport: viewport, budget: budget)
        return Self.cluster(response: raw, budget: budget, cellSizeDegrees: cellSizeDegrees)
    }

    /// Cluster über die Punktelayer-Antwort eines Imports.
    public func clusteredPoints(
        importID: String,
        viewport: LocalTimelineMapViewport,
        budget: LocalTimelineMapPerformanceBudget,
        cellSizeDegrees: Double? = nil
    ) throws -> LocalTimelineMapPointClusterResponse {
        let raw = try pointCandidates(importID: importID, viewport: viewport, budget: budget)
        return Self.cluster(response: raw, budget: budget, cellSizeDegrees: cellSizeDegrees)
    }

    // MARK: - Pipeline

    private func buildResponse(
        viewport: LocalTimelineMapViewport,
        budget: LocalTimelineMapPerformanceBudget,
        visitsAndActivities: [([LocalTimelineVisitRecord], [LocalTimelineActivityRecord])],
        pathCandidates: [LocalTimelinePathRecord]
    ) throws -> LocalTimelineMapPointLayerResponse {

        var entries: [LocalTimelineMapPointLayerEntry] = []
        let cap = budget.maxPointLayerSamples
        entries.reserveCapacity(min(cap, 1024))

        var truncatedVisits = false
        var truncatedActivities = false
        var truncatedRouteSamples = false

        // 1) Visits — direkt aus Spalten, keine Geometrie. Sortiert per `id`.
        let visits = visitsAndActivities.flatMap { $0.0 }.sorted { $0.id < $1.id }
        for v in visits {
            guard let lat = v.latitude, let lon = v.longitude,
                  Self.contains(viewport: viewport, lat: lat, lon: lon) else { continue }
            if entries.count >= cap { truncatedVisits = true; break }
            entries.append(LocalTimelineMapPointLayerEntry(
                kind: .visit, referenceID: v.id, dayID: v.dayId,
                latitude: lat, longitude: lon
            ))
        }

        // 2) Activities — Start- und End-Koordinaten getrennt.
        let activities = visitsAndActivities.flatMap { $0.1 }.sorted { $0.id < $1.id }
        for a in activities {
            if let sLat = a.startLat, let sLon = a.startLon,
               Self.contains(viewport: viewport, lat: sLat, lon: sLon) {
                if entries.count >= cap { truncatedActivities = true; break }
                entries.append(LocalTimelineMapPointLayerEntry(
                    kind: .activityStart, referenceID: a.id, dayID: a.dayId,
                    latitude: sLat, longitude: sLon
                ))
            }
            if let eLat = a.endLat, let eLon = a.endLon,
               Self.contains(viewport: viewport, lat: eLat, lon: eLon) {
                if entries.count >= cap { truncatedActivities = true; break }
                entries.append(LocalTimelineMapPointLayerEntry(
                    kind: .activityEnd, referenceID: a.id, dayID: a.dayId,
                    latitude: eLat, longitude: eLon
                ))
            }
        }

        // 3) Route-Samples — lazy via Decimator. Pro Pfad höchstens
        //    `maxRouteSamplePointsPerRoute`; insgesamt höchstens `cap`.
        let perRouteCap = budget.maxRouteSamplePointsPerRoute
        var totalScanned = 0
        if perRouteCap > 0 {
            let sortedPaths = pathCandidates.sorted { $0.id < $1.id }
            outer: for path in sortedPaths {
                if entries.count >= cap { truncatedRouteSamples = true; break }
                totalScanned += 1
                let remaining = cap - entries.count
                let take = Swift.min(perRouteCap, remaining)
                if take < 2 {
                    truncatedRouteSamples = true
                    break
                }
                let iterator: CoordBlobIterator
                do {
                    iterator = try reader.coordinateSequence(forPathId: path.id)
                } catch let err as LocalTimelineStoreReader.ReaderError {
                    switch err {
                    case .malformedCoordBlob(let id, let n):
                        throw LocalTimelineMapPointLayerError.malformedCoordBlob(
                            pathID: id, byteCount: n
                        )
                    case .unknownPath:
                        // Pfad zwischenzeitlich entfernt — überspringen, nicht crashen.
                        continue outer
                    }
                }
                let samples = LocalTimelineRouteDecimator.decimate(
                    iterator,
                    originalPointCount: path.pointCount,
                    maxPoints: take
                )
                for (idx, p) in samples.enumerated() {
                    if !Self.contains(viewport: viewport, lat: p.latitude, lon: p.longitude) {
                        continue
                    }
                    entries.append(LocalTimelineMapPointLayerEntry(
                        kind: .routeSample,
                        referenceID: path.id,
                        dayID: path.dayId,
                        latitude: p.latitude,
                        longitude: p.longitude,
                        sampleIndex: idx
                    ))
                    if entries.count >= cap { truncatedRouteSamples = true; break outer }
                }
            }
            if totalScanned < pathCandidates.count {
                truncatedRouteSamples = truncatedRouteSamples || (entries.count >= cap)
            }
        } else if !pathCandidates.isEmpty {
            truncatedRouteSamples = true
        }

        // Deterministische Endsortierung: kind-rang asc, refID asc, sampleIndex asc.
        entries.sort { lhs, rhs in
            let lk = Self.rank(of: lhs.kind), rk = Self.rank(of: rhs.kind)
            if lk != rk { return lk < rk }
            if lhs.referenceID != rhs.referenceID { return lhs.referenceID < rhs.referenceID }
            return (lhs.sampleIndex ?? -1) < (rhs.sampleIndex ?? -1)
        }

        return LocalTimelineMapPointLayerResponse(
            detailLevel: budget.detailLevel,
            entries: entries,
            truncatedVisits: truncatedVisits,
            truncatedActivities: truncatedActivities,
            truncatedRouteSamples: truncatedRouteSamples,
            totalRouteCandidatesScanned: totalScanned
        )
    }

    // MARK: - Clustering

    private static func cluster(
        response: LocalTimelineMapPointLayerResponse,
        budget: LocalTimelineMapPerformanceBudget,
        cellSizeDegrees: Double?
    ) -> LocalTimelineMapPointClusterResponse {
        let cell = cellSizeDegrees
            ?? LocalTimelineHeatmapGridAggregator.defaultCellSizeDegrees(for: budget.detailLevel)
        precondition(cell > 0, "cellSizeDegrees must be > 0")

        struct Bucket {
            var visit = 0, activityStart = 0, activityEnd = 0, routeSample = 0
            var firstLat: Double = 0
            var firstLon: Double = 0
        }
        var buckets: [String: Bucket] = [:]
        for e in response.entries {
            let latIdx = Int((e.latitude / cell).rounded(.down))
            let lonIdx = Int((e.longitude / cell).rounded(.down))
            let key = "\(latIdx)#\(lonIdx)"
            var b = buckets[key] ?? Bucket(
                visit: 0, activityStart: 0, activityEnd: 0, routeSample: 0,
                firstLat: (Double(latIdx) + 0.5) * cell,
                firstLon: (Double(lonIdx) + 0.5) * cell
            )
            switch e.kind {
            case .visit:         b.visit += 1
            case .activityStart: b.activityStart += 1
            case .activityEnd:   b.activityEnd += 1
            case .routeSample:   b.routeSample += 1
            }
            buckets[key] = b
        }

        var clusters: [LocalTimelineMapPointCluster] = buckets.values.map { b in
            LocalTimelineMapPointCluster(
                centerLat: b.firstLat, centerLon: b.firstLon,
                count: b.visit + b.activityStart + b.activityEnd + b.routeSample,
                visitCount: b.visit,
                activityStartCount: b.activityStart,
                activityEndCount: b.activityEnd,
                routeSampleCount: b.routeSample
            )
        }
        clusters.sort {
            if $0.centerLat != $1.centerLat { return $0.centerLat < $1.centerLat }
            return $0.centerLon < $1.centerLon
        }
        let truncatedClusters = clusters.count > budget.maxClusters
        if truncatedClusters {
            clusters = Array(clusters.prefix(budget.maxClusters))
        }

        return LocalTimelineMapPointClusterResponse(
            detailLevel: budget.detailLevel,
            cellSizeDegrees: cell,
            clusters: clusters,
            totalEntriesAggregated: response.entries.count,
            truncatedClusters: truncatedClusters,
            sourceTruncated: response.isTruncated
        )
    }

    // MARK: - Helfer

    private func assertBudget(_ budget: LocalTimelineMapPerformanceBudget) throws {
        if budget.maxPointLayerSamples < 0 {
            throw LocalTimelineMapPointLayerError.invalidBudget(reason: "maxPointLayerSamples<0")
        }
        if budget.maxRouteCandidates < 0 {
            throw LocalTimelineMapPointLayerError.invalidBudget(reason: "maxRouteCandidates<0")
        }
        if budget.maxRouteSamplePointsPerRoute < 0 {
            throw LocalTimelineMapPointLayerError.invalidBudget(
                reason: "maxRouteSamplePointsPerRoute<0"
            )
        }
        if budget.maxClusters < 0 {
            throw LocalTimelineMapPointLayerError.invalidBudget(reason: "maxClusters<0")
        }
    }

    private static func intersects(path: LocalTimelinePathRecord,
                                   viewport: LocalTimelineMapViewport) -> Bool {
        viewport.intersects(minLat: path.minLat, minLon: path.minLon,
                            maxLat: path.maxLat, maxLon: path.maxLon)
    }

    private static func contains(viewport: LocalTimelineMapViewport,
                                 lat: Double, lon: Double) -> Bool {
        guard lat.isFinite, lon.isFinite else { return false }
        return lat >= viewport.minLat && lat <= viewport.maxLat
            && lon >= viewport.minLon && lon <= viewport.maxLon
    }

    private static func rank(of kind: LocalTimelineMapPointKind) -> Int {
        switch kind {
        case .visit:         return 0
        case .activityStart: return 1
        case .activityEnd:   return 2
        case .routeSample:   return 3
        }
    }
}
