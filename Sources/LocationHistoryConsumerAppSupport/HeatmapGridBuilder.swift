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
    nonisolated static func computeGrid(
        for points: [WeightedPoint],
        lod: HeatmapLOD,
        scale: AppHeatmapScalePreference = .logarithmic
    ) -> [GridKey: HeatCell] {
        var raw: [GridKey: Double] = [:]
        let step = lod.step

        for point in points {
            let lonScale = lonScale(forLatitude: point.lat)
            let latBin = Int32(floor(point.lat / step))
            let lonBin = Int32(floor(point.lon * lonScale / step))
            let key = GridKey(lat: latBin, lon: lonBin)
            raw[key, default: 0] += Double(point.weight)
        }

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

        visible.sort {
            if $0.normalizedIntensity == $1.normalizedIntensity {
                return $0.count > $1.count
            }
            return $0.normalizedIntensity > $1.normalizedIntensity
        }

        if visible.count > viewportKey.lod.selectionLimit {
            visible = Array(visible.prefix(viewportKey.lod.selectionLimit))
        }

        // Render cold→hot so brightest cells composite on top of dim ones.
        visible.sort { $0.normalizedIntensity < $1.normalizedIntensity }
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
