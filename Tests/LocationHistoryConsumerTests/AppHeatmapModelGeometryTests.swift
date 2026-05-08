import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-8B — Doppelbug-Fix für Heatmap-Path-Aggregation. Tests laufen
/// Linux-only, der eigentliche `AppHeatmapModel`-Renderer hängt unter
/// `#if canImport(SwiftUI) && canImport(MapKit)`. Wir testen den
/// Foundation-only Sampler, den der Renderer ab Phase 8B nutzt.
final class AppHeatmapModelGeometryTests: XCTestCase {

    private func mkPoint(_ lat: Double, _ lon: Double) -> PathPoint {
        PathPoint(lat: lat, lon: lon, time: nil, accuracyM: nil)
    }

    private func makePath(points: [PathPoint], flat: [Double]?) -> Path {
        Path(startTime: nil, endTime: nil,
             activityType: nil, distanceM: nil, sourceType: nil,
             points: points, flatCoordinates: flat)
    }

    func testFlatCoordinatesOnlyCounted() {
        let p = makePath(points: [], flat: [48.0, 11.0, 48.1, 11.1, 48.2, 11.2])
        let s = AppHeatmapPathSampler.samples(forPath: p)
        XCTAssertEqual(s.count, 3)
        XCTAssertEqual(s.first?.lat ?? .nan, 48.0, accuracy: 1e-9)
        XCTAssertEqual(s.last?.lon ?? .nan, 11.2, accuracy: 1e-9)
    }

    func testPointsOnlyCounted() {
        let pts = [mkPoint(48.0, 11.0), mkPoint(48.1, 11.1)]
        let p = makePath(points: pts, flat: nil)
        let s = AppHeatmapPathSampler.samples(forPath: p)
        XCTAssertEqual(s.count, 2)
    }

    func testHybridShapeCountedExactlyOnceFlatPriority() {
        // Beides gefüllt — nach kanonischer Priorität gewinnt flatCoordinates.
        let pts = [mkPoint(0, 0)]
        let flat: [Double] = [48.0, 11.0, 48.1, 11.1]
        let p = makePath(points: pts, flat: flat)
        let s = AppHeatmapPathSampler.samples(forPath: p)
        XCTAssertEqual(s.count, 2, "Hybrid-Daten dürfen nicht doppelt gezählt werden")
        XCTAssertEqual(s.first?.lat ?? .nan, 48.0, accuracy: 1e-9)
    }

    func testMalformedOddFlatFallsBackToPoints() {
        // Ungerade flat-Länge → malformed → fallback auf points.
        let pts = [mkPoint(1.0, 2.0), mkPoint(3.0, 4.0)]
        let p = makePath(points: pts, flat: [48.0, 11.0, 48.1])
        let s = AppHeatmapPathSampler.samples(forPath: p)
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s.first?.lat ?? .nan, 1.0, accuracy: 1e-9)
    }

    func testEmptyFlatAndEmptyPointsReturnsEmpty() {
        let p = makePath(points: [], flat: [])
        XCTAssertTrue(AppHeatmapPathSampler.samples(forPath: p).isEmpty)
    }

    func testActivityMarkersAndGeometrySplit() {
        let act = Activity(
            startTime: nil, endTime: nil,
            startLat: 1.0, startLon: 2.0,
            endLat: 3.0, endLon: 4.0,
            activityType: nil, distanceM: nil,
            splitFromMidnight: nil, startAccuracyM: nil, endAccuracyM: nil,
            sourceType: nil,
            flatCoordinates: [10.0, 20.0, 11.0, 21.0]
        )
        let split = AppHeatmapPathSampler.samples(forActivity: act)
        XCTAssertEqual(split.markers.count, 2)
        XCTAssertEqual(split.geometry.count, 2)
    }

    func testActivityMalformedFlatYieldsEmptyGeometry() {
        let act = Activity(
            startTime: nil, endTime: nil,
            startLat: nil, startLon: nil, endLat: nil, endLon: nil,
            activityType: nil, distanceM: nil,
            splitFromMidnight: nil, startAccuracyM: nil, endAccuracyM: nil,
            sourceType: nil,
            flatCoordinates: [10.0, 20.0, 11.0]
        )
        let split = AppHeatmapPathSampler.samples(forActivity: act)
        XCTAssertTrue(split.markers.isEmpty)
        XCTAssertTrue(split.geometry.isEmpty)
    }
}
