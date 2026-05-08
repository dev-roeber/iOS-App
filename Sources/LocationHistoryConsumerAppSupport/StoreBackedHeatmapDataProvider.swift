import Foundation
import LocationHistoryConsumer

/// Phase-8B — store-backed Heatmap/LOD-Provider.
///
/// Foundation-only Adapter über `LocalTimelineStoreReader` + optionalem
/// `LocalTimelineStore` für Cache-Schreibvorgänge in `derived_cache`.
/// **Kein** SwiftUI/MapKit-Hook. Bounded-Read-Garantien:
/// 1. `heatmapSamples(...)` lädt nur viewport-gefilterte Path-Kandidaten,
///    dekodiert dann je Pfad einen lazy `CoordBlobIterator` mit hartem
///    `maxPointsPerRoute`-Cap. Globaler `maxSamples`-Cap stoppt früh.
/// 2. `heatmapLOD(...)` aggregiert die bounded Samples in ein Grid und
///    cached optional via `derived_cache`.
/// 3. Kein Pfad rekonstruiert ein vollständiges `AppExport`.
/// 4. Kein `[Double]`-Buffer für den ganzen Import.
public final class StoreBackedHeatmapDataProvider {

    private let reader: LocalTimelineStoreReader
    private let cacheStore: LocalTimelineStore?
    /// Erlaubt deterministische Cache-Timestamps in Tests.
    private let now: () -> String

    public init(reader: LocalTimelineStoreReader,
                cacheStore: LocalTimelineStore? = nil,
                now: @escaping () -> String = StoreBackedHeatmapDataProvider.defaultNow) {
        self.reader = reader
        self.cacheStore = cacheStore
        self.now = now
    }

    public static func defaultNow() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: Date())
    }

    /// Cache-Kind, unter dem LOD-Antworten in `derived_cache` abgelegt werden.
    public static let lodCacheKind = "heatmap-lod"
    /// Schema-Version der serialisierten Cache-Payload.
    public static let lodCacheVersion = 1

    // MARK: - Bounded samples

    /// Liest viewport-gebundene Path-Kandidaten und dekodiert pro Pfad
    /// höchstens `maxPointsPerRoute` Punkte. Stoppt früh bei `maxSamples`.
    public func heatmapSamples(importID: String,
                               viewport: LocalTimelineMapViewport,
                               maxRoutes: Int,
                               maxPointsPerRoute: Int,
                               maxSamples: Int) throws -> LocalTimelineHeatmapSampleResponse {
        guard maxRoutes >= 0, maxPointsPerRoute >= 1, maxSamples >= 0 else {
            throw LocalTimelineMapProviderError.invalidLimit(min(maxRoutes, maxPointsPerRoute, maxSamples))
        }
        if maxRoutes == 0 || maxSamples == 0 {
            return LocalTimelineHeatmapSampleResponse(importID: importID,
                                                     samples: [],
                                                     truncatedRoutes: false,
                                                     truncatedPoints: false)
        }

        let overFetch = maxRoutes &+ 1
        let candidates = try reader.pathMetadata(forImportId: importID,
                                                 viewport: viewport,
                                                 limit: overFetch)
        let truncatedRoutes = candidates.count > maxRoutes
        let selected = truncatedRoutes ? Array(candidates.prefix(maxRoutes)) : candidates

        var samples: [LocalTimelineHeatmapSample] = []
        samples.reserveCapacity(min(maxSamples, 1024))
        var truncatedPoints = false
        var remaining = maxSamples

        outer: for cand in selected {
            if remaining <= 0 { truncatedPoints = true; break }
            let perRouteCap = min(maxPointsPerRoute, remaining)
            let iterator: CoordBlobIterator
            do {
                iterator = try reader.coordinateSequence(forPathId: cand.id)
            } catch let err as LocalTimelineStoreReader.ReaderError {
                switch err {
                case .unknownPath: continue
                case .malformedCoordBlob: continue
                }
            }
            var consumedThisPath = 0
            for encoded in iterator {
                if consumedThisPath >= perRouteCap {
                    if cand.pointCount > consumedThisPath {
                        truncatedPoints = true
                    }
                    break
                }
                samples.append(LocalTimelineHeatmapSample(
                    latitude: encoded.latitude,
                    longitude: encoded.longitude,
                    weight: 1
                ))
                consumedThisPath += 1
                remaining -= 1
                if remaining <= 0 {
                    truncatedPoints = true
                    break outer
                }
            }
        }

        return LocalTimelineHeatmapSampleResponse(
            importID: importID,
            samples: samples,
            truncatedRoutes: truncatedRoutes,
            truncatedPoints: truncatedPoints
        )
    }

    // MARK: - LOD with optional derived_cache

    public struct LODOptions {
        public let maxRoutes: Int
        public let maxPointsPerRoute: Int
        public let maxSamples: Int
        public let maxCells: Int
        public let cellSizeDegrees: Double?
        public let useCache: Bool
        public init(maxRoutes: Int,
                    maxPointsPerRoute: Int,
                    maxSamples: Int,
                    maxCells: Int,
                    cellSizeDegrees: Double? = nil,
                    useCache: Bool = true) {
            self.maxRoutes = maxRoutes
            self.maxPointsPerRoute = maxPointsPerRoute
            self.maxSamples = maxSamples
            self.maxCells = maxCells
            self.cellSizeDegrees = cellSizeDegrees
            self.useCache = useCache
        }

        public static func `default`(for level: LocalTimelineMapDetailLevel) -> LODOptions {
            let budget = LocalTimelineMapPointBudget.default(for: level)
            return LODOptions(maxRoutes: 1024,
                              maxPointsPerRoute: budget.maxPointsPerRoute,
                              maxSamples: budget.maxTotalPoints,
                              maxCells: 4096,
                              cellSizeDegrees: nil,
                              useCache: true)
        }
    }

    public func heatmapLOD(importID: String,
                           viewport: LocalTimelineMapViewport,
                           options: LODOptions) throws -> LocalTimelineHeatmapLODResponse {
        let level = viewport.detailLevel
        let cellSize = options.cellSizeDegrees
            ?? LocalTimelineHeatmapGridAggregator.defaultCellSizeDegrees(for: level)
        let cacheKey = LocalTimelineHeatmapCacheKey.make(
            viewport: viewport,
            detailLevel: level,
            maxSamples: options.maxSamples,
            cellSizeDegrees: cellSize,
            version: Self.lodCacheVersion
        )

        if options.useCache, let store = cacheStore,
           let row = try store.derivedCache(importId: importID,
                                            cacheKind: Self.lodCacheKind,
                                            cacheKey: cacheKey),
           row.payloadEncoding == LocalTimelineHeatmapCacheEncoding.lodV1,
           let cached = try? Self.decodeLODPayload(row.payloadBlob)
        {
            return LocalTimelineHeatmapLODResponse(
                importID: importID,
                detailLevel: level,
                cellSizeDegrees: cellSize,
                cells: cached.cells,
                totalSamples: cached.totalSamples,
                truncatedCells: cached.truncatedCells,
                cacheHit: true
            )
        }

        let samples = try heatmapSamples(importID: importID,
                                         viewport: viewport,
                                         maxRoutes: options.maxRoutes,
                                         maxPointsPerRoute: options.maxPointsPerRoute,
                                         maxSamples: options.maxSamples)
        let aggregated = LocalTimelineHeatmapGridAggregator.aggregate(
            samples: samples.samples,
            viewport: viewport,
            cellSizeDegrees: cellSize,
            maxCells: options.maxCells,
            maxSamplesConsumed: options.maxSamples
        )

        if options.useCache, let store = cacheStore {
            let payload = Self.encodeLODPayload(cells: aggregated.cells,
                                                totalSamples: aggregated.totalSamples,
                                                truncatedCells: aggregated.truncatedCells)
            try store.putDerivedCache(.init(
                id: "\(importID):\(Self.lodCacheKind):\(cacheKey)",
                importId: importID,
                cacheKind: Self.lodCacheKind,
                cacheKey: cacheKey,
                createdAt: now(),
                version: Self.lodCacheVersion,
                payloadEncoding: LocalTimelineHeatmapCacheEncoding.lodV1,
                payloadBlob: payload
            ))
        }

        return LocalTimelineHeatmapLODResponse(
            importID: importID,
            detailLevel: level,
            cellSizeDegrees: cellSize,
            cells: aggregated.cells,
            totalSamples: aggregated.totalSamples,
            truncatedCells: aggregated.truncatedCells,
            cacheHit: false
        )
    }

    /// Cache-Invalidierung für einen Import (alle LOD-Einträge).
    public func clearHeatmapCache(importID: String) throws {
        try cacheStore?.deleteDerivedCache(importId: importID, cacheKind: Self.lodCacheKind)
    }

    // MARK: - Payload codec (Foundation-only, deterministic)

    /// Layout: u32 magic 'L8B1' | u32 cellCount | u32 totalSamples | u8 truncatedCells |
    /// cellCount × (f64 lat | f64 lon | u32 count)
    static func encodeLODPayload(cells: [LocalTimelineHeatmapGridCell],
                                 totalSamples: Int,
                                 truncatedCells: Bool) -> Data {
        var data = Data()
        data.reserveCapacity(13 + cells.count * 20)
        appendU32(&data, 0x4C384231) // 'L8B1'
        appendU32(&data, UInt32(cells.count))
        appendU32(&data, UInt32(clamping: totalSamples))
        data.append(truncatedCells ? 1 : 0)
        for c in cells {
            appendF64(&data, c.centerLat)
            appendF64(&data, c.centerLon)
            appendU32(&data, UInt32(clamping: c.count))
        }
        return data
    }

    struct DecodedLODPayload {
        let cells: [LocalTimelineHeatmapGridCell]
        let totalSamples: Int
        let truncatedCells: Bool
    }

    enum LODPayloadError: Error { case malformed }

    static func decodeLODPayload(_ data: Data) throws -> DecodedLODPayload {
        guard data.count >= 13 else { throw LODPayloadError.malformed }
        var offset = 0
        let magic = readU32(data, &offset)
        guard magic == 0x4C384231 else { throw LODPayloadError.malformed }
        let cellCount = Int(readU32(data, &offset))
        let totalSamples = Int(readU32(data, &offset))
        let truncated = data[data.startIndex + offset] != 0
        offset += 1
        guard data.count >= offset + cellCount * 20 else { throw LODPayloadError.malformed }
        var cells: [LocalTimelineHeatmapGridCell] = []
        cells.reserveCapacity(cellCount)
        for _ in 0..<cellCount {
            let lat = readF64(data, &offset)
            let lon = readF64(data, &offset)
            let count = Int(readU32(data, &offset))
            cells.append(.init(centerLat: lat, centerLon: lon, count: count))
        }
        return DecodedLODPayload(cells: cells, totalSamples: totalSamples, truncatedCells: truncated)
    }

    private static func appendU32(_ d: inout Data, _ v: UInt32) {
        var le = v.littleEndian
        withUnsafeBytes(of: &le) { d.append(contentsOf: $0) }
    }
    private static func appendF64(_ d: inout Data, _ v: Double) {
        var le = v.bitPattern.littleEndian
        withUnsafeBytes(of: &le) { d.append(contentsOf: $0) }
    }
    private static func readU32(_ d: Data, _ off: inout Int) -> UInt32 {
        var v: UInt32 = 0
        let s = d.startIndex + off
        withUnsafeMutableBytes(of: &v) { dst in
            d.copyBytes(to: dst, from: s..<s+4)
        }
        off += 4
        return UInt32(littleEndian: v)
    }
    private static func readF64(_ d: Data, _ off: inout Int) -> Double {
        var bits: UInt64 = 0
        let s = d.startIndex + off
        withUnsafeMutableBytes(of: &bits) { dst in
            d.copyBytes(to: dst, from: s..<s+8)
        }
        off += 8
        return Double(bitPattern: UInt64(littleEndian: bits))
    }
}
