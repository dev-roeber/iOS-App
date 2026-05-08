import Foundation

/// Phase-8B — Foundation-only Heatmap-Domain-Modelle für den
/// store-backed Heatmap-Provider. Renderer-/Plattform-frei (kein
/// MapKit, kein SwiftUI, kein CoreLocation).
///
/// Die Modelle hier liefern **bounded** Eingaben für eine künftige
/// Heatmap-Render-Schicht. Sie materialisieren nie eine vollständige
/// Import-Geometrie.

/// Ein gewichteter Punkt im Heatmap-Sample-Strom.
public struct LocalTimelineHeatmapSample: Equatable {
    public let latitude: Double
    public let longitude: Double
    public let weight: Int
    public init(latitude: Double, longitude: Double, weight: Int = 1) {
        self.latitude = latitude
        self.longitude = longitude
        self.weight = weight
    }
}

/// Antwort auf `heatmapSamples(...)`.
public struct LocalTimelineHeatmapSampleResponse: Equatable {
    public let importID: String
    public let samples: [LocalTimelineHeatmapSample]
    public let truncatedRoutes: Bool
    public let truncatedPoints: Bool
    public init(importID: String,
                samples: [LocalTimelineHeatmapSample],
                truncatedRoutes: Bool,
                truncatedPoints: Bool) {
        self.importID = importID
        self.samples = samples
        self.truncatedRoutes = truncatedRoutes
        self.truncatedPoints = truncatedPoints
    }
}

/// Deterministische Zellen-Einteilung über die Bbox.
public struct LocalTimelineHeatmapGridCell: Equatable {
    public let centerLat: Double
    public let centerLon: Double
    public let count: Int
    public init(centerLat: Double, centerLon: Double, count: Int) {
        self.centerLat = centerLat
        self.centerLon = centerLon
        self.count = count
    }
}

/// Antwort auf `heatmapLOD(...)`.
public struct LocalTimelineHeatmapLODResponse: Equatable {
    public let importID: String
    public let detailLevel: LocalTimelineMapDetailLevel
    public let cellSizeDegrees: Double
    public let cells: [LocalTimelineHeatmapGridCell]
    public let totalSamples: Int
    public let truncatedCells: Bool
    public let cacheHit: Bool
    public init(importID: String,
                detailLevel: LocalTimelineMapDetailLevel,
                cellSizeDegrees: Double,
                cells: [LocalTimelineHeatmapGridCell],
                totalSamples: Int,
                truncatedCells: Bool,
                cacheHit: Bool) {
        self.importID = importID
        self.detailLevel = detailLevel
        self.cellSizeDegrees = cellSizeDegrees
        self.cells = cells
        self.totalSamples = totalSamples
        self.truncatedCells = truncatedCells
        self.cacheHit = cacheHit
    }
}

/// Encoding-Marker für Cache-Payloads (`derived_cache.payload_encoding`).
public enum LocalTimelineHeatmapCacheEncoding {
    public static let lodV1 = "heatmap-lod-v1"
}

/// Cache-Schlüssel-Builder. Deterministisch aus Eingaben.
public enum LocalTimelineHeatmapCacheKey {
    /// Quantisierter Viewport-Bucket auf 1e-3°-Raster, damit kleine
    /// Pan-Bewegungen denselben Cache-Treffer erzeugen.
    public static func make(viewport: LocalTimelineMapViewport,
                            detailLevel: LocalTimelineMapDetailLevel,
                            maxSamples: Int,
                            cellSizeDegrees: Double,
                            version: Int) -> String {
        let q = { (v: Double) -> Int in Int((v * 1000.0).rounded()) }
        return [
            "v\(version)",
            detailLevel.rawValue,
            "vp", "\(q(viewport.minLat))", "\(q(viewport.minLon))",
                  "\(q(viewport.maxLat))", "\(q(viewport.maxLon))",
            "ms\(maxSamples)",
            "cs\(q(cellSizeDegrees))",
        ].joined(separator: ":")
    }
}
