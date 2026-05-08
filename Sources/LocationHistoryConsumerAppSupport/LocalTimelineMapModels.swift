import Foundation

/// Phase-8A — Foundation-only Map-Domain-Modelle.
///
/// Diese Typen sind die UI-/Renderer-unabhängige Schnittstelle, mit der
/// `StoreBackedMapDataProvider` Karten-Konsumenten bedient. Keine
/// Abhängigkeit auf SwiftUI, MapKit, CoreLocation. Alle Koordinaten sind
/// reine WGS84-`Double`-Paare.
///
/// **Bounded-read-Invariante**: kein Typ in dieser Datei trägt einen
/// vollständigen `[Double]` über mehrere Pfade hinweg. Nur
/// `LocalTimelineMapRouteGeometry` materialisiert eine bounded
/// Punkt-Sequenz für **genau einen** Pfad, und nur nachdem ein
/// Decimator das Punktbudget durchgesetzt hat.

// MARK: - Viewport

/// Achsenparallele Bounding-Box in WGS84.
///
/// Anti-Meridian-Fälle (`maxLon < minLon`) werden in dieser Phase
/// **kontrolliert abgelehnt** — `init` liefert `nil` und der Provider
/// signalisiert `LocalTimelineMapProviderError.unsupportedAntimeridianViewport`.
/// Eine echte Anti-Meridian-Splitting-Strategie ist Phase 8B/9.
public struct LocalTimelineMapViewport: Equatable {
    public let minLat: Double
    public let minLon: Double
    public let maxLat: Double
    public let maxLon: Double
    public let detailLevel: LocalTimelineMapDetailLevel

    public init?(minLat: Double,
                 minLon: Double,
                 maxLat: Double,
                 maxLon: Double,
                 detailLevel: LocalTimelineMapDetailLevel = .medium) {
        guard minLat.isFinite, minLon.isFinite, maxLat.isFinite, maxLon.isFinite else { return nil }
        guard (-90.0...90.0).contains(minLat), (-90.0...90.0).contains(maxLat) else { return nil }
        guard (-180.0...180.0).contains(minLon), (-180.0...180.0).contains(maxLon) else { return nil }
        guard minLat <= maxLat else { return nil }
        // Anti-Meridian (Wrap) explizit abgelehnt — siehe Doc-Block oben.
        guard minLon <= maxLon else { return nil }
        self.minLat = minLat
        self.minLon = minLon
        self.maxLat = maxLat
        self.maxLon = maxLon
        self.detailLevel = detailLevel
    }

    /// `true`, wenn die übergebene Path-BBox die Viewport-BBox schneidet.
    /// `nil`-Bounds (Pfad ohne Bbox) gelten als „nicht filterbar" und
    /// werden konservativ als überlappend gewertet.
    public func intersects(minLat pMinLat: Double?,
                           minLon pMinLon: Double?,
                           maxLat pMaxLat: Double?,
                           maxLon pMaxLon: Double?) -> Bool {
        guard let pMinLat, let pMinLon, let pMaxLat, let pMaxLon else { return true }
        if pMaxLat < minLat || pMinLat > maxLat { return false }
        if pMaxLon < minLon || pMinLon > maxLon { return false }
        return true
    }

    /// Der gesamte WGS84-Datenbereich (ohne Antimeridian-Wrap).
    public static let world = LocalTimelineMapViewport(
        minLat: -90, minLon: -180, maxLat: 90, maxLon: 180, detailLevel: .overview
    )!
}

// MARK: - Detail-Level / Punktbudget

/// Grobe Detail-Stufe, an der `LocalTimelineMapPointBudget` und der
/// Decimator orientiert werden. Bewusst plattform-/zoomstufenfrei.
public enum LocalTimelineMapDetailLevel: String, Equatable, CaseIterable {
    case overview
    case low
    case medium
    case high
}

/// Punkt-Budget pro **einzelnem** Pfad und für die **Gesamtantwort** einer
/// Overview-Query. Beide Werte werden vom Decimator und Provider hart
/// eingehalten.
public struct LocalTimelineMapPointBudget: Equatable {
    public let maxPointsPerRoute: Int
    public let maxTotalPoints: Int

    public init(maxPointsPerRoute: Int, maxTotalPoints: Int) {
        precondition(maxPointsPerRoute >= 2, "maxPointsPerRoute must be >= 2")
        precondition(maxTotalPoints >= maxPointsPerRoute,
                     "maxTotalPoints must be >= maxPointsPerRoute")
        self.maxPointsPerRoute = maxPointsPerRoute
        self.maxTotalPoints = maxTotalPoints
    }

    /// Default-Budgets je Detail-Stufe. Werte sind konservativ und
    /// orientieren sich an `OverviewMapPreparation.candidateStorageCap`
    /// (Legacy = 512). Phase-8A-Provider hält das gegen einen Hard-Cap.
    public static func `default`(for level: LocalTimelineMapDetailLevel) -> LocalTimelineMapPointBudget {
        switch level {
        case .overview: return .init(maxPointsPerRoute: 64,  maxTotalPoints: 8_000)
        case .low:      return .init(maxPointsPerRoute: 128, maxTotalPoints: 16_000)
        case .medium:   return .init(maxPointsPerRoute: 256, maxTotalPoints: 32_000)
        case .high:     return .init(maxPointsPerRoute: 512, maxTotalPoints: 64_000)
        }
    }
}

// MARK: - Query

/// Eingabe für `StoreBackedMapDataProvider.overviewRoutes(query:)`.
public struct LocalTimelineMapQuery: Equatable {
    public let importID: String
    public let viewport: LocalTimelineMapViewport
    public let budget: LocalTimelineMapPointBudget
    public let maxRoutes: Int

    public init(importID: String,
                viewport: LocalTimelineMapViewport,
                budget: LocalTimelineMapPointBudget,
                maxRoutes: Int) {
        precondition(maxRoutes >= 0, "maxRoutes must be >= 0")
        self.importID = importID
        self.viewport = viewport
        self.budget = budget
        self.maxRoutes = maxRoutes
    }
}

// MARK: - Antworten

/// Kandidat aus einer Bounded-Bbox-Query. Trägt **nur Metadaten**, nie eine
/// dekodierte Geometrie.
public struct LocalTimelineMapRouteCandidate: Equatable {
    public let pathID: String
    public let dayID: String
    public let startTime: String?
    public let endTime: String?
    public let mode: String?
    public let distanceM: Double
    public let pointCount: Int
    public let minLat: Double?
    public let minLon: Double?
    public let maxLat: Double?
    public let maxLon: Double?

    public init(pathID: String, dayID: String,
                startTime: String?, endTime: String?,
                mode: String?, distanceM: Double, pointCount: Int,
                minLat: Double?, minLon: Double?,
                maxLat: Double?, maxLon: Double?) {
        self.pathID = pathID
        self.dayID = dayID
        self.startTime = startTime
        self.endTime = endTime
        self.mode = mode
        self.distanceM = distanceM
        self.pointCount = pointCount
        self.minLat = minLat
        self.minLon = minLon
        self.maxLat = maxLat
        self.maxLon = maxLon
    }
}

/// Ein einzelner Punkt einer Route-Geometrie. Plattform-/Renderer-frei.
public struct LocalTimelineMapPoint: Equatable {
    public let latitude: Double
    public let longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Bounded Geometrie für **genau einen** Pfad. `points.count <= maxPointsPerRoute`
/// und `points.first` / `points.last` entsprechen dem ersten/letzten
/// dekodierten Quell-Punkt, wenn der Pfad nicht leer ist.
public struct LocalTimelineMapRouteGeometry: Equatable {
    public let pathID: String
    public let detailLevel: LocalTimelineMapDetailLevel
    public let originalPointCount: Int
    public let points: [LocalTimelineMapPoint]

    public init(pathID: String,
                detailLevel: LocalTimelineMapDetailLevel,
                originalPointCount: Int,
                points: [LocalTimelineMapPoint]) {
        self.pathID = pathID
        self.detailLevel = detailLevel
        self.originalPointCount = originalPointCount
        self.points = points
    }
}

/// Antwort auf `overviewRoutes(query:)`. Trägt höchstens `maxRoutes`
/// Geometrien und insgesamt höchstens `budget.maxTotalPoints`.
public struct LocalTimelineMapOverviewResponse: Equatable {
    public let importID: String
    public let detailLevel: LocalTimelineMapDetailLevel
    public let routes: [LocalTimelineMapRouteGeometry]
    public let truncatedRoutes: Bool
    public let truncatedPoints: Bool

    public init(importID: String,
                detailLevel: LocalTimelineMapDetailLevel,
                routes: [LocalTimelineMapRouteGeometry],
                truncatedRoutes: Bool,
                truncatedPoints: Bool) {
        self.importID = importID
        self.detailLevel = detailLevel
        self.routes = routes
        self.truncatedRoutes = truncatedRoutes
        self.truncatedPoints = truncatedPoints
    }

    public var totalPoints: Int { routes.reduce(0) { $0 + $1.points.count } }
}

/// Bounding-Box, gerechnet aus `paths.min/max_lat/lon`. `nil`, wenn der
/// Import/Tag keine Pfade mit gesetzter Bbox enthält.
public struct LocalTimelineMapBounds: Equatable {
    public let minLat: Double
    public let minLon: Double
    public let maxLat: Double
    public let maxLon: Double
    public init(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) {
        self.minLat = minLat
        self.minLon = minLon
        self.maxLat = maxLat
        self.maxLon = maxLon
    }
}

// MARK: - Fehler

public enum LocalTimelineMapProviderError: Error, Equatable, CustomStringConvertible {
    case unknownImport(importID: String)
    case unknownDay(dayID: String)
    case unknownPath(pathID: String)
    case malformedCoordBlob(pathID: String, byteCount: Int)
    case unsupportedAntimeridianViewport
    case invalidViewport
    case invalidLimit(Int)

    public var description: String {
        switch self {
        case .unknownImport(let id):       return "unknownImport(\(id))"
        case .unknownDay(let id):          return "unknownDay(\(id))"
        case .unknownPath(let id):         return "unknownPath(\(id))"
        case .malformedCoordBlob(let id, let n):
            return "malformedCoordBlob(\(id), bytes=\(n))"
        case .unsupportedAntimeridianViewport:
            return "unsupportedAntimeridianViewport"
        case .invalidViewport:             return "invalidViewport"
        case .invalidLimit(let n):         return "invalidLimit(\(n))"
        }
    }
}
