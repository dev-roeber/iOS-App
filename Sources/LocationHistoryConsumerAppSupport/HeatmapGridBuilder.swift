#if canImport(MapKit) && canImport(SwiftUI)
import Foundation
import MapKit
import SwiftUI

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct GridKey: Hashable, Equatable {
    let lat: Int32
    let lon: Int32
}

struct WeightedPoint {
    let lat: Double
    let lon: Double
    let weight: Int
}

struct HeatCell: Identifiable {
    var id: GridKey { gridKey }
    let gridKey: GridKey
    let coordinate: CLLocationCoordinate2D
    let count: Int
    let normalizedIntensity: Double
    let cellSpan: Double
    let lod: HeatmapLOD
}

struct HeatmapViewportKey: Hashable {
    let lod: HeatmapLOD
    let minLatBin: Int32
    let maxLatBin: Int32
    let minLonBin: Int32
    let maxLonBin: Int32

    init(region: MKCoordinateRegion, lod: HeatmapLOD) {
        self.lod = lod

        let latPadding = region.span.latitudeDelta * lod.viewportPaddingFactor
        let lonPadding = region.span.longitudeDelta * lod.viewportPaddingFactor
        let minLat = region.center.latitude  - (region.span.latitudeDelta  / 2.0) - latPadding
        let maxLat = region.center.latitude  + (region.span.latitudeDelta  / 2.0) + latPadding
        let minLon = region.center.longitude - (region.span.longitudeDelta / 2.0) - lonPadding
        let maxLon = region.center.longitude + (region.span.longitudeDelta / 2.0) + lonPadding

        let step = lod.step
        let centerLonScale = HeatmapGridBuilder.lonScale(forLatitude: region.center.latitude)
        self.minLatBin = Int32(floor(minLat / step))
        self.maxLatBin = Int32(floor(maxLat / step))
        self.minLonBin = Int32(floor(minLon * centerLonScale / step))
        self.maxLonBin = Int32(floor(maxLon * centerLonScale / step))
    }
}

enum HeatmapGridBuilder {
    /// cos(lat) longitude correction, clamped 0.05–1.0 so polar bins stay sane.
    nonisolated static func lonScale(forLatitude latitude: Double) -> Double {
        let latRad = latitude * .pi / 180.0
        return max(min(cos(latRad), 1.0), 0.05)
    }

    /// Builds the LOD grid. `scale` controls how raw counts map to the
    /// normalized intensity: logarithmic flattens hotspot dominance so
    /// secondary regions stay visible at world/country zoom; linear is
    /// the classical density mapping.
    ///
    /// Map-Train 3 refactor: the binning and the smooth+normalise passes
    /// are factored into `binRaw(points:lod:)` and
    /// `smoothAndNormalize(raw:lod:scale:)` so that
    /// `computeMultiLODGrids` can reuse the smoothing phase. The
    /// per-LOD `computeGrid` keeps byte-identical output (golden-tested
    /// in `HeatmapGoldenOutputTests`).
    nonisolated static func computeGrid(
        for points: [WeightedPoint],
        lod: HeatmapLOD,
        scale: AppHeatmapScalePreference = .logarithmic
    ) -> [GridKey: HeatCell] {
        let raw = binRaw(points: points, lod: lod)
        return smoothAndNormalize(raw: raw, lod: lod, scale: scale)
    }

    /// Map-Train 3: fused multi-LOD binning. Iterates `points` exactly
    /// **once** and produces raw bin counts for every requested LOD in
    /// the same pass. `lonScale(forLatitude:)` is evaluated once per
    /// point and reused across LODs (was: 4× per point in the
    /// per-LOD loop). Smoothing + normalisation still run per-LOD so
    /// the produced grids are **byte-identical** to four separate
    /// `computeGrid` calls (locked by `HeatmapGoldenOutputTests`).
    ///
    /// Returns one grid per requested LOD. Duplicate or empty `lods`
    /// inputs are tolerated (duplicate LOD produces the same grid;
    /// empty `lods` returns `[:]`).
    nonisolated static func computeMultiLODGrids(
        for points: [WeightedPoint],
        lods: [HeatmapLOD],
        scale: AppHeatmapScalePreference = .logarithmic
    ) -> [HeatmapLOD: [GridKey: HeatCell]] {
        guard !lods.isEmpty else { return [:] }
        // Deduplicate while preserving insertion order so callers can
        // pass `HeatmapLOD.allCases` directly without worrying about
        // accidental repeats.
        var seen = Set<HeatmapLOD>()
        var orderedLODs: [HeatmapLOD] = []
        orderedLODs.reserveCapacity(lods.count)
        for lod in lods where seen.insert(lod).inserted { orderedLODs.append(lod) }

        guard !points.isEmpty else {
            // Empty input → empty grids; preserve the requested-LOD set
            // so callers can read all keys back unconditionally.
            return Dictionary(uniqueKeysWithValues: orderedLODs.map { ($0, [:]) })
        }

        // Pre-extract per-LOD step so the inner loop stays branch-free.
        let steps: [Double] = orderedLODs.map { $0.step }

        var rawByLOD: [[GridKey: Double]] = Array(
            repeating: [:],
            count: orderedLODs.count
        )

        // Fused pass: one cos() per point, then per-LOD bin insertion.
        for point in points {
            // Compute lonScale exactly once per point. The product
            // `point.lon * lonScale` is divided by each LOD's step
            // identically to the per-LOD `computeGrid` operation order
            // (`floor(point.lon * lonScale / step)`).
            let scaledLon = point.lon * lonScale(forLatitude: point.lat)
            let lat = point.lat
            let weight = Double(point.weight)
            for i in 0..<orderedLODs.count {
                let step = steps[i]
                let key = GridKey(
                    lat: Int32(floor(lat / step)),
                    lon: Int32(floor(scaledLon / step))
                )
                rawByLOD[i][key, default: 0] += weight
            }
        }

        var output: [HeatmapLOD: [GridKey: HeatCell]] = [:]
        output.reserveCapacity(orderedLODs.count)
        for i in 0..<orderedLODs.count {
            let lod = orderedLODs[i]
            output[lod] = smoothAndNormalize(raw: rawByLOD[i], lod: lod, scale: scale)
        }
        return output
    }

    /// Extracted binning pass. Per-point work: 1 cos() + 1 floor/lat +
    /// 1 floor/lon + 1 dict insert. Used by `computeGrid` for the
    /// single-LOD path; `computeMultiLODGrids` inlines the equivalent
    /// computation but shares `lonScale(forLatitude:)` across LODs.
    nonisolated static func binRaw(
        points: [WeightedPoint],
        lod: HeatmapLOD
    ) -> [GridKey: Double] {
        var raw: [GridKey: Double] = [:]
        let step = lod.step
        for point in points {
            let lonScale = lonScale(forLatitude: point.lat)
            let latBin = Int32(floor(point.lat / step))
            let lonBin = Int32(floor(point.lon * lonScale / step))
            let key = GridKey(lat: latBin, lon: lonBin)
            raw[key, default: 0] += Double(point.weight)
        }
        return raw
    }

    /// Extracted smoothing + normalisation pass. Byte-identical to the
    /// inline pre-refactor implementation; golden-tested.
    nonisolated static func smoothAndNormalize(
        raw: [GridKey: Double],
        lod: HeatmapLOD,
        scale: AppHeatmapScalePreference
    ) -> [GridKey: HeatCell] {
        guard !raw.isEmpty else { return [:] }

        var smoothed: [GridKey: Double] = [:]
        smoothed.reserveCapacity(raw.count * 2)
        for (key, count) in raw {
            for offset in lod.smoothingKernel {
                let neighbor = GridKey(lat: key.lat + offset.lat, lon: key.lon + offset.lon)
                smoothed[neighbor, default: 0] += count * offset.weight
            }
        }

        guard let maxCount = smoothed.values.max(), maxCount > 0 else { return [:] }

        // Logarithmic normalization (default) flattens the long tail so a
        // single dominant home/office cell doesn't push every other region
        // below the visibility threshold. log1p keeps the curve continuous
        // through count = 0 (smoothed neighbors) and avoids a hard step.
        let logDenominator = log1p(maxCount)
        let useLog = scale == .logarithmic && logDenominator > 0

        var result: [GridKey: HeatCell] = [:]
        result.reserveCapacity(smoothed.count)

        for (key, count) in smoothed {
            let normalized = useLog
                ? log1p(count) / logDenominator
                : count / maxCount
            guard normalized >= lod.minimumNormalizedIntensity * lod.precomputationVisibilityFactor else { continue }

            let cell = makeCell(for: key, count: count, normalized: normalized, lod: lod)
            result[key] = cell
        }

        return result
    }

    nonisolated static func visibleCells(
        in grid: [GridKey: HeatCell],
        viewportKey: HeatmapViewportKey
    ) -> [HeatCell] {
        var visible: [HeatCell] = []
        visible.reserveCapacity(min(viewportKey.lod.selectionLimit * 2, 256))

        for lat in viewportKey.minLatBin...viewportKey.maxLatBin {
            for lon in viewportKey.minLonBin...viewportKey.maxLonBin {
                if let cell = grid[GridKey(lat: lat, lon: lon)],
                   cell.normalizedIntensity >= viewportKey.lod.minimumNormalizedIntensity {
                    visible.append(cell)
                }
            }
        }

        if visible.isEmpty { return [] }

        // Single sort + reverse: previously we sorted descending, trimmed,
        // then sorted ascending — two O(n log n) passes on the same array.
        // Sort ascending once and keep the *tail* (highest-intensity cells)
        // when we're past the LOD limit; the array is already in render
        // order (cold→hot) so brightest cells composite on top.
        visible.sort {
            if $0.normalizedIntensity == $1.normalizedIntensity {
                return $0.count < $1.count
            }
            return $0.normalizedIntensity < $1.normalizedIntensity
        }

        if visible.count > viewportKey.lod.selectionLimit {
            visible = Array(visible.suffix(viewportKey.lod.selectionLimit))
        }

        return visible
    }

    nonisolated private static func makeCell(
        for key: GridKey,
        count: Double,
        normalized: Double,
        lod: HeatmapLOD
    ) -> HeatCell {
        let step = lod.step
        let centerLat = (Double(key.lat) * step) + (step / 2.0)
        let centerLonScale = lonScale(forLatitude: centerLat)
        let centerLonCorrected = (Double(key.lon) * step) + (step / 2.0)
        let centerLon = centerLonCorrected / centerLonScale
        let cellSpan = step * lod.tileSpanMultiplier

        return HeatCell(
            gridKey: key,
            coordinate: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            count: max(Int(count.rounded()), 1),
            normalizedIntensity: normalized,
            cellSpan: cellSpan,
            lod: lod
        )
    }

    /// Pointy-top regular hexagon centred at (centerLat, centerLon).
    nonisolated static func polygonCoordinates(
        centerLat: Double,
        centerLon: Double,
        stepLat: Double,
        stepLon: Double
    ) -> [CLLocationCoordinate2D] {
        let halfHeightLat = stepLat / 2.0
        let quarterHeightLat = stepLat / 4.0
        let halfWidthLon = stepLon / 2.0
        return [
            CLLocationCoordinate2D(latitude: centerLat + halfHeightLat,    longitude: centerLon),
            CLLocationCoordinate2D(latitude: centerLat + quarterHeightLat, longitude: centerLon + halfWidthLon),
            CLLocationCoordinate2D(latitude: centerLat - quarterHeightLat, longitude: centerLon + halfWidthLon),
            CLLocationCoordinate2D(latitude: centerLat - halfHeightLat,    longitude: centerLon),
            CLLocationCoordinate2D(latitude: centerLat - quarterHeightLat, longitude: centerLon - halfWidthLon),
            CLLocationCoordinate2D(latitude: centerLat + quarterHeightLat, longitude: centerLon - halfWidthLon),
            CLLocationCoordinate2D(latitude: centerLat + halfHeightLat,    longitude: centerLon),
        ]
    }

    /// Convenience: equilateral hexagon (sin30°/cos30° aspect) for tests.
    nonisolated static func polygonCoordinates(
        centerLat: Double,
        centerLon: Double,
        step: Double
    ) -> [CLLocationCoordinate2D] {
        polygonCoordinates(
            centerLat: centerLat,
            centerLon: centerLon,
            stepLat: step,
            stepLon: step * 0.8660254037844387
        )
    }
}
#endif
