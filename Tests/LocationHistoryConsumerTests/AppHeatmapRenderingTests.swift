import XCTest

#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class AppHeatmapRenderingTests: XCTestCase {
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

    func testDisplayIntensityLiftsMidAndHighDensity() {
        let low = HeatmapVisualStyle.displayIntensity(for: 0.12)
        let mid = HeatmapVisualStyle.displayIntensity(for: 0.5)
        let high = HeatmapVisualStyle.displayIntensity(for: 0.9)

        XCTAssertGreaterThan(low, 0.26)
        XCTAssertGreaterThan(mid, 0.68)
        XCTAssertGreaterThan(high, 0.95)
        XCTAssertLessThan(low, mid)
        XCTAssertLessThan(mid, high)
    }

    func testFullOpacityControlUsesStrongerHighEndMapping() {
        let full = HeatmapVisualStyle.effectiveOpacity(
            cellOpacity: 0.88,
            normalizedIntensity: 0.95,
            overlayOpacity: 1.0,
            lod: .high
        )
        let reduced = HeatmapVisualStyle.effectiveOpacity(
            cellOpacity: 0.88,
            normalizedIntensity: 0.95,
            overlayOpacity: 0.55,
            lod: .high
        )

        XCTAssertGreaterThan(full, 0.85)
        XCTAssertGreaterThan(full, reduced)
    }

    func testHighDetailOpacityKeepsSparseCellsVisible() {
        let sparse = HeatmapVisualStyle.effectiveOpacity(
            cellOpacity: 0.30,
            normalizedIntensity: 0.05,
            overlayOpacity: 0.84,
            lod: .high
        )

        XCTAssertGreaterThan(sparse, 0.14)
    }

    func testHighDetailColorPositionAdvancesSparseCellsFurtherThanLowDetail() {
        let sparseHigh = HeatmapVisualStyle.colorPosition(for: 0.08, lod: .high)
        let sparseLow = HeatmapVisualStyle.colorPosition(for: 0.08, lod: .low)
        let mid = HeatmapVisualStyle.colorPosition(for: 0.45, lod: .high)

        XCTAssertGreaterThan(sparseHigh, sparseLow)
        XCTAssertGreaterThan(sparseHigh, 0.24)
        XCTAssertGreaterThan(mid, sparseHigh)
    }

    func testHighDetailLodUsesLowerVisibilityThresholdThanLowLod() {
        XCTAssertLessThan(HeatmapLOD.high.minimumNormalizedIntensity, HeatmapLOD.low.minimumNormalizedIntensity)
        XCTAssertLessThan(HeatmapLOD.high.precomputationVisibilityFactor, HeatmapLOD.low.precomputationVisibilityFactor)
    }

    func testPaletteWarmsAsDensityIncreases() {
        let low = HeatmapPalette.rgb(for: 0.12)
        let mid = HeatmapPalette.rgb(for: 0.55)
        let high = HeatmapPalette.rgb(for: 0.9)

        XCTAssertGreaterThan(mid.green, low.green)
        XCTAssertGreaterThan(high.red, mid.red)
        XCTAssertLessThan(high.blue, mid.blue)
        XCTAssertGreaterThan(low.blue, 0.80)
        XCTAssertGreaterThan(mid.green, 0.80)
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
        XCTAssertEqual(firstCoord.latitude, lastCoord.latitude, accuracy: 1e-9, "Polygon must be closed")
        XCTAssertEqual(firstCoord.longitude, lastCoord.longitude, accuracy: 1e-9, "Polygon must be closed")

        XCTAssertEqual(coords[0].longitude, 8.214, accuracy: 1e-9, "Top vertex must be on centre longitude")
        XCTAssertEqual(coords[0].latitude, 53.144 + 0.01, accuracy: 1e-9, "Top vertex Y must be centre + step/2")

        XCTAssertEqual(coords[3].longitude, 8.214, accuracy: 1e-9, "Bottom vertex must be on centre longitude")
        XCTAssertEqual(coords[3].latitude, 53.144 - 0.01, accuracy: 1e-9, "Bottom vertex Y must be centre - step/2")

        let expectedHalfWidth = 0.02 * 0.4330127018922193
        XCTAssertEqual(coords[1].longitude - 8.214, expectedHalfWidth, accuracy: 1e-9, "Right side vertex X")
        XCTAssertEqual(8.214 - coords[5].longitude, expectedHalfWidth, accuracy: 1e-9, "Left side vertex X")

        XCTAssertEqual(coords[1].latitude - 53.144, 0.005, accuracy: 1e-9, "Upper-right vertex Y")
        XCTAssertEqual(53.144 - coords[2].latitude, 0.005, accuracy: 1e-9, "Lower-right vertex Y")
    }

    func testDensityBinsCosineCorrectLongitudeAtHighLatitude() {
        let pointA = WeightedPoint(lat: 53.144, lon: 8.214, weight: 1)
        let pointB = WeightedPoint(lat: 53.144, lon: 8.300, weight: 1)
        let grid = HeatmapGridBuilder.computeGrid(for: [pointA, pointB], lod: .medium)
        let lonCentres = Set(grid.values.map { Double(round($0.coordinate.longitude * 1000)) })
        XCTAssertGreaterThanOrEqual(lonCentres.count, 2,
            "Two points 0.086° lon apart at 53° N must occupy at least two distinct lon bins under medium LOD")

        let cellLons = grid.values.map(\.coordinate.longitude)
        XCTAssertTrue(cellLons.contains { abs($0 - 8.214) < 0.025 },
            "A cell should be close to point A's longitude")
        XCTAssertTrue(cellLons.contains { abs($0 - 8.300) < 0.025 },
            "A cell should be close to point B's longitude")
    }

    func testLonScaleClampsAtPoles() {
        XCTAssertEqual(HeatmapGridBuilder.lonScale(forLatitude: 0.0),  1.0,  accuracy: 1e-9)
        XCTAssertEqual(HeatmapGridBuilder.lonScale(forLatitude: 53.0), cos(53.0 * .pi / 180), accuracy: 1e-9)
        XCTAssertEqual(HeatmapGridBuilder.lonScale(forLatitude: 89.0), 0.05, accuracy: 1e-9, "Clamps near the poles")
        XCTAssertEqual(HeatmapGridBuilder.lonScale(forLatitude: 90.0), 0.05, accuracy: 1e-9, "Hard clamp at pole")
        XCTAssertEqual(HeatmapGridBuilder.lonScale(forLatitude: -90.0), 0.05, accuracy: 1e-9, "Hard clamp at south pole")
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
        XCTAssertEqual(actualHorizontalExtent, stepLon, accuracy: 1e-12,
                       "Side-vertex span must equal the supplied stepLon")
    }
}
#endif
