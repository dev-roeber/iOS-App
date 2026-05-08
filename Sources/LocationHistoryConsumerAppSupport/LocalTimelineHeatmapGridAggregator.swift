import Foundation

/// Phase-8B — deterministische Grid-Aggregation für Heatmap-LOD.
///
/// Punkte werden in achsenparallele Zellen einsortiert. Zellgröße in Grad
/// ist explizit oder ergibt sich aus der `LocalTimelineMapDetailLevel`.
/// Das Ergebnis ist deterministisch sortiert, damit die Cache-Hashing-Lage
/// stabil bleibt.
///
/// Die Aggregation hat **harte Caps**:
/// - `maxCells` begrenzt die Anzahl Zellen in der Antwort.
/// - `maxSamplesConsumed` begrenzt, wie viele Eingangs-Samples eingelesen
///   werden, bevor der Iterator vorzeitig abgebrochen wird (Schutz vor
///   pathologischen Quellen).
private struct GridKey: Hashable { let lat: Int; let lon: Int }

public enum LocalTimelineHeatmapGridAggregator {

    /// Default-Zellgröße je Detail-Stufe (Grad). Werte konservativ, an
    /// `AppHeatmapModel`-LODs angelehnt; für die Phase-8B-Vorbereitung
    /// reicht eine grobe, dokumentierte Tabelle.
    public static func defaultCellSizeDegrees(for level: LocalTimelineMapDetailLevel) -> Double {
        switch level {
        case .overview: return 0.5
        case .low:      return 0.1
        case .medium:   return 0.02
        case .high:     return 0.005
        }
    }

    public struct Result: Equatable {
        public let cells: [LocalTimelineHeatmapGridCell]
        public let totalSamples: Int
        public let truncatedCells: Bool
        public init(cells: [LocalTimelineHeatmapGridCell], totalSamples: Int, truncatedCells: Bool) {
            self.cells = cells
            self.totalSamples = totalSamples
            self.truncatedCells = truncatedCells
        }
    }

    /// Aggregiert eine bounded Sample-Sequenz auf ein Grid.
    ///
    /// - Parameters:
    ///   - samples: Foundation-only Sample-Strom (kein CoreLocation).
    ///   - viewport: optionaler Viewport. Samples außerhalb werden ignoriert
    ///     (siehe Test "viewport outside ergibt leer"). Mit `nil` zählen alle.
    ///   - cellSizeDegrees: positive Kantenlänge der Quadratzellen.
    ///   - maxCells: hartes Limit für die Anzahl ausgegebener Zellen.
    ///   - maxSamplesConsumed: hartes Limit für die Anzahl konsumierter Eingaben.
    public static func aggregate<S: Sequence>(
        samples: S,
        viewport: LocalTimelineMapViewport? = nil,
        cellSizeDegrees: Double,
        maxCells: Int,
        maxSamplesConsumed: Int
    ) -> Result where S.Element == LocalTimelineHeatmapSample {
        precondition(cellSizeDegrees > 0, "cellSizeDegrees must be > 0")
        precondition(maxCells >= 0, "maxCells must be >= 0")
        precondition(maxSamplesConsumed >= 0, "maxSamplesConsumed must be >= 0")

        if maxCells == 0 || maxSamplesConsumed == 0 {
            return Result(cells: [], totalSamples: 0, truncatedCells: false)
        }

        var bucket: [GridKey: Int] = [:]
        var consumed = 0

        for sample in samples {
            if consumed >= maxSamplesConsumed { break }
            consumed += 1
            if let vp = viewport,
               !vp.intersects(minLat: sample.latitude, minLon: sample.longitude,
                              maxLat: sample.latitude, maxLon: sample.longitude) {
                continue
            }
            let latBucket = Int((sample.latitude / cellSizeDegrees).rounded(.down))
            let lonBucket = Int((sample.longitude / cellSizeDegrees).rounded(.down))
            bucket[GridKey(lat: latBucket, lon: lonBucket), default: 0] += max(1, sample.weight)
        }

        // Deterministische Sortierung (lat asc, lon asc) für stabile
        // Cache-Hashes und Tests.
        let sortedKeys = bucket.keys.sorted { (a, b) in
            if a.lat != b.lat { return a.lat < b.lat }
            return a.lon < b.lon
        }
        let truncated = sortedKeys.count > maxCells
        let kept = truncated ? Array(sortedKeys.prefix(maxCells)) : sortedKeys

        var cells: [LocalTimelineHeatmapGridCell] = []
        cells.reserveCapacity(kept.count)
        var total = 0
        for key in kept {
            let count = bucket[key] ?? 0
            total += count
            let centerLat = (Double(key.lat) + 0.5) * cellSizeDegrees
            let centerLon = (Double(key.lon) + 0.5) * cellSizeDegrees
            cells.append(LocalTimelineHeatmapGridCell(
                centerLat: centerLat,
                centerLon: centerLon,
                count: count
            ))
        }
        return Result(cells: cells, totalSamples: total, truncatedCells: truncated)
    }
}
