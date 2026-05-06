import XCTest

#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class AppHeatmapRenderingTests: XCTestCase {

    // MARK: - LOD aggregation

    func testCoarserLODProducesFewerAggregatedCellsThanFineLOD() {
        let points = clusteredPoints()

        let macroGrid = HeatmapGridBuilder.computeGrid(for: points, lod: .macro)
        let highGrid = HeatmapGridBuilder.computeGrid(for: points, lod: .high)

        XCTAssertFalse(macroGrid.isEmpty)
        XCTAssertFalse(highGrid.isEmpty)
        XCTAssertLessThan(macroGrid.count, highGrid.count)
    }

    func testVisibleCellsRespectViewportAndSelectionLimit() {
        let points = clusteredPoints()
        let grid = HeatmapGridBuilder.computeGrid(for: points, lod: .medium)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )

        let visible = HeatmapGridBuilder.visibleCells(
            in: grid,
            viewportKey: HeatmapViewportKey(region: region, lod: .medium)
        )

        XCTAssertFalse(visible.isEmpty)
        XCTAssertLessThanOrEqual(visible.count, HeatmapLOD.medium.selectionLimit)
        XCTAssertTrue(visible.allSatisfy { abs($0.coordinate.latitude - 52.52) < 0.2 })
        XCTAssertTrue(visible.allSatisfy { abs($0.coordinate.longitude - 13.405) < 0.2 })
    }

    func testHighDetailLodUsesLowerVisibilityThresholdThanLowLod() {
        XCTAssertLessThan(HeatmapLOD.high.minimumNormalizedIntensity, HeatmapLOD.low.minimumNormalizedIntensity)
        XCTAssertLessThan(HeatmapLOD.high.precomputationVisibilityFactor, HeatmapLOD.low.precomputationVisibilityFactor)
    }

    // MARK: - Visual style

    func testDisplayIntensityLiftsMidAndHighDensity() {
        let low = HeatmapVisualStyle.displayIntensity(for: 0.12)
        let mid = HeatmapVisualStyle.displayIntensity(for: 0.5)
        let high = HeatmapVisualStyle.displayIntensity(for: 0.9)

        XCTAssertLessThan(low, mid)
        XCTAssertLessThan(mid, high)
        XCTAssertGreaterThan(high, 0.85)
    }

    func testFullOpacityControlIsStrongerThanReduced() {
        let full = HeatmapVisualStyle.effectiveOpacity(
            normalizedIntensity: 0.95,
            overlayOpacity: 1.0,
            lod: .high
        )
        let reduced = HeatmapVisualStyle.effectiveOpacity(
            normalizedIntensity: 0.95,
            overlayOpacity: 0.55,
            lod: .high
        )

        XCTAssertGreaterThan(full, reduced)
        XCTAssertGreaterThan(full, 0.20)
    }

    func testEffectiveOpacityIsBoundedSoftRange() {
        // The new soft palette intentionally caps cell alpha to allow
        // overlapping cells to glow without saturating into a solid block.
        let max = HeatmapVisualStyle.effectiveOpacity(
            normalizedIntensity: 1.0,
            overlayOpacity: 1.0,
            lod: .high
        )
        XCTAssertLessThanOrEqual(max, 0.90,
            "Per-cell alpha must stay below 0.90 to avoid the bullseye target effect")
    }

    // MARK: - Perceptual palettes

    func testMagmaPaletteWarmsAsIntensityIncreases() {
        // Magma: dark purple → magenta → cream. Hot end has high red AND
        // green; low end has near-zero of every channel. Cool→hot reads as
        // brightness in addition to hue, which is what makes it perceptual.
        let low = HeatmapPalette.rgb(for: 0.05, palette: .magma)
        let mid = HeatmapPalette.rgb(for: 0.55, palette: .magma)
        let high = HeatmapPalette.rgb(for: 0.95, palette: .magma)

        // Brightness (channel sum) must monotonically increase.
        let lowSum = low.red + low.green + low.blue
        let midSum = mid.red + mid.green + mid.blue
        let highSum = high.red + high.green + high.blue
        XCTAssertLessThan(lowSum, midSum)
        XCTAssertLessThan(midSum, highSum)

        // Magma's high end is cream/yellow — green channel rises sharply.
        XCTAssertGreaterThan(high.green, mid.green)
        XCTAssertGreaterThan(high.red, 0.95)
    }

    func testInfernoPaletteHasBrighterHotEndThanCividis() {
        let infernoHot = HeatmapPalette.rgb(for: 1.0, palette: .inferno)
        let cividisHot = HeatmapPalette.rgb(for: 1.0, palette: .cividis)
        // Inferno top stop is very bright cream; cividis caps at saturated yellow.
        let infernoSum = infernoHot.red + infernoHot.green + infernoHot.blue
        let cividisSum = cividisHot.red + cividisHot.green + cividisHot.blue
        XCTAssertGreaterThan(infernoSum, cividisSum)
    }

    func testCividisLowEndIsBlueDominant() {
        let cividisLow = HeatmapPalette.rgb(for: 0.0, palette: .cividis)
        XCTAssertGreaterThan(cividisLow.blue, cividisLow.red,
            "Cividis low end must be blue-dominant for colorblind accessibility")
    }

    // MARK: - Log scale

    func testLogarithmicScaleFlattensHotspotDominance() {
        // One extreme hotspot and three small clusters far away.
        // Under linear scale, the small clusters fall below the macro
        // visibility threshold; under log scale they survive.
        var points: [WeightedPoint] = []
        // Single dominant hotspot
        for _ in 0..<2000 {
            points.append(WeightedPoint(lat: 53.144, lon: 8.214, weight: 1))
        }
        // Three secondary clusters
        for offset in [(40.0, -3.0), (48.0, 11.5), (51.5, -0.1)] {
            for _ in 0..<8 {
                points.append(WeightedPoint(lat: offset.0, lon: offset.1, weight: 1))
            }
        }

        let logGrid = HeatmapGridBuilder.computeGrid(for: points, lod: .macro, scale: .logarithmic)
        let linearGrid = HeatmapGridBuilder.computeGrid(for: points, lod: .macro, scale: .linear)

        // Log scale should retain more cells (hotspot doesn't crush the long tail).
        XCTAssertGreaterThanOrEqual(logGrid.count, linearGrid.count,
            "Logarithmic normalization must retain at least as many cells as linear when one hotspot dominates")
    }

    // MARK: - Density polygon shape

    func testDensityPolygonIsRegularPointyTopHexagon() {
        let coords = HeatmapGridBuilder.polygonCoordinates(
            centerLat: 53.144,
            centerLon: 8.214,
            step: 0.02
        )
        XCTAssertEqual(coords.count, 7, "Hex polygon has 6 vertices + closing copy")
        guard let firstCoord = coords.first, let lastCoord = coords.last else {
            return XCTFail("Polygon coordinates must not be empty")
        }
        XCTAssertEqual(firstCoord.latitude, lastCoord.latitude, accuracy: 1e-9)
        XCTAssertEqual(firstCoord.longitude, lastCoord.longitude, accuracy: 1e-9)

        XCTAssertEqual(coords[0].longitude, 8.214, accuracy: 1e-9)
        XCTAssertEqual(coords[0].latitude, 53.144 + 0.01, accuracy: 1e-9)

        XCTAssertEqual(coords[3].longitude, 8.214, accuracy: 1e-9)
        XCTAssertEqual(coords[3].latitude, 53.144 - 0.01, accuracy: 1e-9)

        let expectedHalfWidth = 0.02 * 0.4330127018922193
        XCTAssertEqual(coords[1].longitude - 8.214, expectedHalfWidth, accuracy: 1e-9)
        XCTAssertEqual(8.214 - coords[5].longitude, expectedHalfWidth, accuracy: 1e-9)

        XCTAssertEqual(coords[1].latitude - 53.144, 0.005, accuracy: 1e-9)
        XCTAssertEqual(53.144 - coords[2].latitude, 0.005, accuracy: 1e-9)
    }

    func testDensityBinsCosineCorrectLongitudeAtHighLatitude() {
        let pointA = WeightedPoint(lat: 53.144, lon: 8.214, weight: 1)
        let pointB = WeightedPoint(lat: 53.144, lon: 8.300, weight: 1)
        let grid = HeatmapGridBuilder.computeGrid(for: [pointA, pointB], lod: .medium)
        let lonCentres = Set(grid.values.map { Double(round($0.coordinate.longitude * 1000)) })
        XCTAssertGreaterThanOrEqual(lonCentres.count, 2,
            "Two points 0.086° lon apart at 53° N must occupy at least two distinct lon bins")

        let cellLons = grid.values.map(\.coordinate.longitude)
        XCTAssertTrue(cellLons.contains { abs($0 - 8.214) < 0.025 })
        XCTAssertTrue(cellLons.contains { abs($0 - 8.300) < 0.025 })
    }

    func testLonScaleClampsAtPoles() {
        XCTAssertEqual(HeatmapGridBuilder.lonScale(forLatitude: 0.0),  1.0,  accuracy: 1e-9)
        XCTAssertEqual(HeatmapGridBuilder.lonScale(forLatitude: 53.0), cos(53.0 * .pi / 180), accuracy: 1e-9)
        XCTAssertEqual(HeatmapGridBuilder.lonScale(forLatitude: 89.0), 0.05, accuracy: 1e-9)
        XCTAssertEqual(HeatmapGridBuilder.lonScale(forLatitude: 90.0), 0.05, accuracy: 1e-9)
        XCTAssertEqual(HeatmapGridBuilder.lonScale(forLatitude: -90.0), 0.05, accuracy: 1e-9)
    }

    func testHexPolygonAcceptsAsymmetricStepForMercatorCorrection() {
        let stepLat = 0.012
        let lonScale = cos(53.144 * .pi / 180.0)
        let stepLon = stepLat / lonScale

        let coords = HeatmapGridBuilder.polygonCoordinates(
            centerLat: 53.144,
            centerLon: 8.214,
            stepLat: stepLat,
            stepLon: stepLon
        )

        XCTAssertEqual(coords.count, 7)
        XCTAssertEqual(coords[0].longitude, 8.214, accuracy: 1e-12)
        XCTAssertEqual(coords[3].longitude, 8.214, accuracy: 1e-12)
        XCTAssertEqual(coords[0].latitude - coords[3].latitude, stepLat, accuracy: 1e-12)
        let actualHorizontalExtent = coords[1].longitude - coords[5].longitude
        XCTAssertEqual(actualHorizontalExtent, stepLon, accuracy: 1e-12)
    }

    // MARK: - Preferences round-trip

    func testHeatmapPreferencesPersistAcrossInstances() {
        let suite = "test.heatmap.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return XCTFail("Could not create test UserDefaults")
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        Task { @MainActor in
            let prefs1 = AppPreferences(userDefaults: defaults)
            prefs1.heatmapOpacity = 0.42
            prefs1.heatmapRadius = .wide
            prefs1.heatmapPalette = .inferno
            prefs1.heatmapScale = .linear

            let prefs2 = AppPreferences(userDefaults: defaults)
            XCTAssertEqual(prefs2.heatmapOpacity, 0.42, accuracy: 0.001)
            XCTAssertEqual(prefs2.heatmapRadius, .wide)
            XCTAssertEqual(prefs2.heatmapPalette, .inferno)
            XCTAssertEqual(prefs2.heatmapScale, .linear)
        }
    }

    // MARK: - Helpers

    private func clusteredPoints() -> [WeightedPoint] {
        var points: [WeightedPoint] = []

        for latOffset in stride(from: -0.03, through: 0.03, by: 0.003) {
            for lonOffset in stride(from: -0.03, through: 0.03, by: 0.003) {
                points.append(WeightedPoint(lat: 52.52 + latOffset, lon: 13.405 + lonOffset, weight: 3))
            }
        }

        for latOffset in stride(from: -0.02, through: 0.02, by: 0.004) {
            for lonOffset in stride(from: -0.02, through: 0.02, by: 0.004) {
                points.append(WeightedPoint(lat: 48.137 + latOffset, lon: 11.575 + lonOffset, weight: 1))
            }
        }

        return points
    }
}
#endif
