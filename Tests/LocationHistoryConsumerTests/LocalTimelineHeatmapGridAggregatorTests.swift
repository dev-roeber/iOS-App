import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-8B — deterministische Grid-Aggregation.
final class LocalTimelineHeatmapGridAggregatorTests: XCTestCase {

    private func sample(_ lat: Double, _ lon: Double, _ w: Int = 1) -> LocalTimelineHeatmapSample {
        .init(latitude: lat, longitude: lon, weight: w)
    }

    func testEmptyInputStable() {
        let r = LocalTimelineHeatmapGridAggregator.aggregate(
            samples: [LocalTimelineHeatmapSample](),
            cellSizeDegrees: 0.1, maxCells: 100, maxSamplesConsumed: 100)
        XCTAssertEqual(r.cells.count, 0)
        XCTAssertEqual(r.totalSamples, 0)
        XCTAssertFalse(r.truncatedCells)
    }

    func testPointsInSameCellAggregate() {
        // Drei Punkte alle innerhalb 0.05° um (48.05, 11.05) → eine Zelle bei 0.1° Grid.
        let pts = [sample(48.05, 11.05), sample(48.06, 11.04), sample(48.04, 11.06)]
        let r = LocalTimelineHeatmapGridAggregator.aggregate(
            samples: pts, cellSizeDegrees: 0.1, maxCells: 10, maxSamplesConsumed: 100)
        XCTAssertEqual(r.cells.count, 1)
        XCTAssertEqual(r.cells[0].count, 3)
        XCTAssertEqual(r.totalSamples, 3)
    }

    func testMaxCellsBudgetEnforced() {
        var pts: [LocalTimelineHeatmapSample] = []
        for i in 0..<20 {
            pts.append(sample(Double(i), Double(i)))
        }
        let r = LocalTimelineHeatmapGridAggregator.aggregate(
            samples: pts, cellSizeDegrees: 1.0, maxCells: 5, maxSamplesConsumed: 100)
        XCTAssertEqual(r.cells.count, 5)
        XCTAssertTrue(r.truncatedCells)
    }

    func testViewportOutsideYieldsEmpty() {
        let pts = [sample(48.0, 11.0), sample(48.5, 11.5)]
        let vp = LocalTimelineMapViewport(minLat: 0, minLon: 0, maxLat: 1, maxLon: 1)!
        let r = LocalTimelineHeatmapGridAggregator.aggregate(
            samples: pts, viewport: vp,
            cellSizeDegrees: 0.1, maxCells: 100, maxSamplesConsumed: 100)
        XCTAssertEqual(r.cells.count, 0)
        XCTAssertEqual(r.totalSamples, 0)
    }

    func testDeterministicOrderingByLatThenLon() {
        let pts = [sample(2.0, 1.0), sample(1.0, 2.0), sample(1.0, 1.0)]
        let r = LocalTimelineHeatmapGridAggregator.aggregate(
            samples: pts, cellSizeDegrees: 1.0, maxCells: 10, maxSamplesConsumed: 100)
        XCTAssertEqual(r.cells.count, 3)
        // Sortierung: lat asc, lon asc → (1,1) (1,2) (2,1)
        XCTAssertLessThan(r.cells[0].centerLat, r.cells[2].centerLat)
        XCTAssertLessThan(r.cells[0].centerLon, r.cells[1].centerLon)
    }

    func testMaxSamplesConsumedHonored() {
        var pts: [LocalTimelineHeatmapSample] = []
        for i in 0..<1000 {
            pts.append(sample(Double(i) * 0.001, Double(i) * 0.001))
        }
        let r = LocalTimelineHeatmapGridAggregator.aggregate(
            samples: pts, cellSizeDegrees: 1.0, maxCells: 100, maxSamplesConsumed: 50)
        XCTAssertLessThanOrEqual(r.totalSamples, 50)
    }

    func testWeightAccumulates() {
        let pts = [sample(48.0, 11.0, 5), sample(48.001, 11.001, 3)]
        let r = LocalTimelineHeatmapGridAggregator.aggregate(
            samples: pts, cellSizeDegrees: 1.0, maxCells: 10, maxSamplesConsumed: 100)
        XCTAssertEqual(r.cells.count, 1)
        XCTAssertEqual(r.cells[0].count, 8)
    }
}
