import Foundation

/// Phase-10B (Weg 3) — Foundation-only Modelle für den Store-backed
/// **Punktelayer**.
///
/// Der Punktelayer ist **kein** unbounded "alle Rohpunkte aller Pfade"-Layer.
/// Er aggregiert vier Punkt-Typen, die zusammen ein Visit/Activity/Route
/// Sample-Bild ergeben:
///
/// 1. `visit` — Visit-Punkt aus `visits` (representative coordinate, direkt
///    aus Spalten `latitude/longitude` ohne `coord_blob`-Decoding).
/// 2. `activityStart` — Start-Koordinate einer Activity (`start_lat/start_lon`).
/// 3. `activityEnd` — End-Koordinate einer Activity (`end_lat/end_lon`).
/// 4. `routeSample` — wenige, deterministische Sample-Punkte aus dem
///    `coord_blob` eines selektierten Pfades — lazy via `CoordBlobIterator`,
///    nie vollständige Geometrie.
///
/// Alle Antworten sind viewport-, detail-level- und budget-bounded. Es gibt
/// keine Pfade, die die volle Import-Punktwolke materialisieren.

// MARK: - Punkttypen

/// Klassifikation eines Punktelayer-Punkts. UI/Renderer entscheidet
/// anhand dieses Wertes über Symbol/Marker/Cluster-Logik.
public enum LocalTimelineMapPointKind: String, Equatable, CaseIterable, Sendable {
    case visit
    case activityStart
    case activityEnd
    case routeSample
}

/// Ein einzelner Punktelayer-Punkt.
///
/// `referenceID` zeigt auf die Quell-Entität:
/// - bei `visit` auf die Visit-Row-ID
/// - bei `activityStart`/`activityEnd` auf die Activity-Row-ID
/// - bei `routeSample` auf die Path-Row-ID
///
/// `sampleIndex` ist nur bei `routeSample` relevant und gibt den 0-basierten
/// Index innerhalb der gezogenen Sample-Sequenz an (deterministisch).
public struct LocalTimelineMapPointLayerEntry: Equatable, Sendable {
    public let kind: LocalTimelineMapPointKind
    public let referenceID: String
    public let dayID: String?
    public let latitude: Double
    public let longitude: Double
    public let sampleIndex: Int?

    public init(kind: LocalTimelineMapPointKind,
                referenceID: String,
                dayID: String?,
                latitude: Double,
                longitude: Double,
                sampleIndex: Int? = nil) {
        self.kind = kind
        self.referenceID = referenceID
        self.dayID = dayID
        self.latitude = latitude
        self.longitude = longitude
        self.sampleIndex = sampleIndex
    }
}

/// Antwort eines `pointCandidates(...)`-Aufrufs. Trägt höchstens
/// `budget.maxPointLayerSamples` Einträge.
public struct LocalTimelineMapPointLayerResponse: Equatable, Sendable {
    public let detailLevel: LocalTimelineMapDetailLevel
    public let entries: [LocalTimelineMapPointLayerEntry]
    public let truncatedVisits: Bool
    public let truncatedActivities: Bool
    public let truncatedRouteSamples: Bool
    public let totalRouteCandidatesScanned: Int

    public init(detailLevel: LocalTimelineMapDetailLevel,
                entries: [LocalTimelineMapPointLayerEntry],
                truncatedVisits: Bool,
                truncatedActivities: Bool,
                truncatedRouteSamples: Bool,
                totalRouteCandidatesScanned: Int) {
        self.detailLevel = detailLevel
        self.entries = entries
        self.truncatedVisits = truncatedVisits
        self.truncatedActivities = truncatedActivities
        self.truncatedRouteSamples = truncatedRouteSamples
        self.totalRouteCandidatesScanned = totalRouteCandidatesScanned
    }

    public var pointCount: Int { entries.count }
    public var isTruncated: Bool {
        truncatedVisits || truncatedActivities || truncatedRouteSamples
    }
}

// MARK: - Cluster

/// Aggregat-Bucket für Punkte. Ein Cluster speichert seinen geographischen
/// Mittelpunkt (Cell-Center, identisch zu `LocalTimelineHeatmapGridCell`)
/// und die Anzahl Punkte pro Kind.
public struct LocalTimelineMapPointCluster: Equatable, Sendable {
    public let centerLat: Double
    public let centerLon: Double
    public let count: Int
    public let visitCount: Int
    public let activityStartCount: Int
    public let activityEndCount: Int
    public let routeSampleCount: Int

    public init(centerLat: Double, centerLon: Double,
                count: Int,
                visitCount: Int,
                activityStartCount: Int,
                activityEndCount: Int,
                routeSampleCount: Int) {
        self.centerLat = centerLat
        self.centerLon = centerLon
        self.count = count
        self.visitCount = visitCount
        self.activityStartCount = activityStartCount
        self.activityEndCount = activityEndCount
        self.routeSampleCount = routeSampleCount
    }

    /// Dominanter Punkttyp im Cluster (für Marker-Symbol). Tie-Break
    /// in `CaseIterable`-Reihenfolge: `visit > activityStart > activityEnd
    /// > routeSample`.
    public var dominantKind: LocalTimelineMapPointKind {
        let pairs: [(LocalTimelineMapPointKind, Int)] = [
            (.visit, visitCount),
            (.activityStart, activityStartCount),
            (.activityEnd, activityEndCount),
            (.routeSample, routeSampleCount)
        ]
        return pairs.max { $0.1 < $1.1 }?.0 ?? .visit
    }
}

/// Antwort eines `clusteredPoints(...)`-Aufrufs. Trägt höchstens
/// `budget.maxClusters` Cluster.
public struct LocalTimelineMapPointClusterResponse: Equatable, Sendable {
    public let detailLevel: LocalTimelineMapDetailLevel
    public let cellSizeDegrees: Double
    public let clusters: [LocalTimelineMapPointCluster]
    public let totalEntriesAggregated: Int
    public let truncatedClusters: Bool
    public let sourceTruncated: Bool

    public init(detailLevel: LocalTimelineMapDetailLevel,
                cellSizeDegrees: Double,
                clusters: [LocalTimelineMapPointCluster],
                totalEntriesAggregated: Int,
                truncatedClusters: Bool,
                sourceTruncated: Bool) {
        self.detailLevel = detailLevel
        self.cellSizeDegrees = cellSizeDegrees
        self.clusters = clusters
        self.totalEntriesAggregated = totalEntriesAggregated
        self.truncatedClusters = truncatedClusters
        self.sourceTruncated = sourceTruncated
    }

    public var isTruncated: Bool { truncatedClusters || sourceTruncated }
}

// MARK: - Fehler

public enum LocalTimelineMapPointLayerError: Error, Equatable, CustomStringConvertible {
    case unknownImport(importID: String)
    case unknownDay(dayID: String)
    case malformedCoordBlob(pathID: String, byteCount: Int)
    case invalidViewport
    case invalidBudget(reason: String)

    public var description: String {
        switch self {
        case .unknownImport(let id): return "unknownImport(\(id))"
        case .unknownDay(let id):    return "unknownDay(\(id))"
        case .malformedCoordBlob(let id, let n):
            return "malformedCoordBlob(\(id), bytes=\(n))"
        case .invalidViewport:       return "invalidViewport"
        case .invalidBudget(let r):  return "invalidBudget(\(r))"
        }
    }
}
