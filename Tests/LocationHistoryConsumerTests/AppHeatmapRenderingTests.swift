import XCTest
import MapKit
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
