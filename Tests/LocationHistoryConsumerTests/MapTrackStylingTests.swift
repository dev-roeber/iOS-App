import XCTest

#if canImport(SwiftUI) && canImport(MapKit)
import MapKit
@testable import LocationHistoryConsumerAppSupport

final class MapTrackStylingTests: XCTestCase {

    // MARK: - SpeedTrackBuilder

    func testSegmentsEmptyWhenLessThanTwoSamples() {
        XCTAssertTrue(SpeedTrackBuilder.segments(from: []).isEmpty)
        let single = [TrackSample(coordinate: .init(latitude: 53.0, longitude: 8.0), timestamp: Date())]
        XCTAssertTrue(SpeedTrackBuilder.segments(from: single).isEmpty)
    }

    func testSegmentsAssignHigherNormalizedSpeedToFasterMovement() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        // Build a long track with two regimes so the rolling-mean smoothing
        // doesn't collapse the differentiation: 20 slow points (~1 m/s)
        // followed by 20 fast points (~10 m/s).
        var samples: [TrackSample] = []
        var t = 0.0
        var lat = 53.000
        for _ in 0..<20 {
            samples.append(sample(lat, 8.0, base.addingTimeInterval(t)))
            t += 5.0
            lat += 0.00005    // ≈ 5.5 m → ~1.1 m/s
        }
        for _ in 0..<20 {
            samples.append(sample(lat, 8.0, base.addingTimeInterval(t)))
            t += 5.0
            lat += 0.00045    // ≈ 50 m → ~10 m/s
        }
        let segments = SpeedTrackBuilder.segments(from: samples)
        XCTAssertGreaterThan(segments.count, 30)

        let firstQuarter = segments.prefix(8)
        let lastQuarter = segments.suffix(8)
        let slowAvg = firstQuarter.map(\.normalizedSpeed).reduce(0, +) / Double(firstQuarter.count)
        let fastAvg = lastQuarter.map(\.normalizedSpeed).reduce(0, +) / Double(lastQuarter.count)
        XCTAssertLessThan(slowAvg, fastAvg,
            "Adaptive normalisation must rank slow segments below fast ones")
    }

    func testSegmentsDropPhantomGPSJumps() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let samples: [TrackSample] = [
            sample(53.0, 8.0,   base.addingTimeInterval(0)),
            sample(53.0001, 8.0, base.addingTimeInterval(5)),
            // 5° jump in latitude — clearly a GPS spike.
            sample(58.0, 8.0,   base.addingTimeInterval(10)),
            sample(53.0002, 8.0, base.addingTimeInterval(15)),
        ]
        let segments = SpeedTrackBuilder.segments(from: samples)
        // Either segment count drops two (the jump-out and jump-back are both
        // wider than 1°) or returns just the safe trailing segments — but
        // never includes the phantom-jump leg.
        XCTAssertFalse(segments.contains { abs($0.start.latitude - $0.end.latitude) > 1.0 })
    }

    func testInstantaneousSpeedRequiresTimestamps() {
        let a = TrackSample(coordinate: .init(latitude: 53, longitude: 8), timestamp: nil)
        let b = TrackSample(coordinate: .init(latitude: 53.001, longitude: 8), timestamp: Date())
        XCTAssertNil(SpeedTrackBuilder.instantaneousSpeed(from: a, to: b))
    }

    func testHaversineApproximatesShortDistance() {
        // 0.001° lat at 53° N ≈ 111 m.
        let d = SpeedTrackBuilder.haversine(
            .init(latitude: 53.0, longitude: 8.0),
            .init(latitude: 53.001, longitude: 8.0)
        )
        XCTAssertEqual(d, 111, accuracy: 2,
            "Haversine should agree with the textbook 1° lat ≈ 111 km approximation")
    }

    func testRollingMeanSmoothsSpikes() {
        let raw = [1.0, 1.0, 30.0, 1.0, 1.0]
        let smoothed = SpeedTrackBuilder.rollingMean(raw, window: 3)
        XCTAssertEqual(smoothed.count, raw.count)
        // Centre value should be considerably reduced.
        XCTAssertLessThan(smoothed[2], raw[2] / 2,
            "Rolling mean must dampen a single-sample spike")
    }

    // MARK: - SpeedColors palette

    func testStravaPaletteIsCool​ToWarmMonotonic() {
        let cool = SpeedColors.rgb(for: 0.05)
        let warm = SpeedColors.rgb(for: 0.95)
        // Strava's palette goes from indigo (low blue/red, no green) toward
        // warm red. Brightness (channel sum) need not be monotonic, but the
        // blue→red shift must be: cool has more blue, warm has more red.
        XCTAssertGreaterThan(cool.blue, warm.blue)
        XCTAssertGreaterThan(warm.red, cool.red)
    }

    func testViridisPaletteIsBrightnessMonotonic() {
        let dark = SpeedColors.rgb(for: 0.0, palette: .viridis)
        let bright = SpeedColors.rgb(for: 1.0, palette: .viridis)
        let darkSum = dark.red + dark.green + dark.blue
        let brightSum = bright.red + bright.green + bright.blue
        XCTAssertLessThan(darkSum, brightSum,
            "Viridis must have brighter hot end than cool end")
    }

    // MARK: - LiveBreadcrumbFade

    func testBreadcrumbFadeReturnsThreeBucketsForLongTrails() {
        let coords = (0..<60).map { i in
            CLLocationCoordinate2D(latitude: 53.0 + Double(i) * 0.0001, longitude: 8.0)
        }
        let buckets = LiveBreadcrumbFade.buckets(from: coords)
        XCTAssertEqual(buckets.count, 3)
        // Alpha must monotonically increase from old → new.
        XCTAssertLessThan(buckets[0].alpha, buckets[1].alpha)
        XCTAssertLessThan(buckets[1].alpha, buckets[2].alpha)
        // Buckets must overlap by one point so polylines visually connect.
        XCTAssertEqual(buckets[0].coordinates.last?.latitude, buckets[1].coordinates.first?.latitude)
        XCTAssertEqual(buckets[1].coordinates.last?.latitude, buckets[2].coordinates.first?.latitude)
    }

    func testBreadcrumbFadeReturnsSingleBucketForShortTrails() {
        let coords = [
            CLLocationCoordinate2D(latitude: 53.0, longitude: 8.0),
            CLLocationCoordinate2D(latitude: 53.001, longitude: 8.0),
            CLLocationCoordinate2D(latitude: 53.002, longitude: 8.0),
        ]
        let buckets = LiveBreadcrumbFade.buckets(from: coords)
        XCTAssertEqual(buckets.count, 1)
    }

    func testBreadcrumbFadeEmptyForLessThanTwoCoords() {
        XCTAssertTrue(LiveBreadcrumbFade.buckets(from: []).isEmpty)
        let single = [CLLocationCoordinate2D(latitude: 53, longitude: 8)]
        XCTAssertTrue(LiveBreadcrumbFade.buckets(from: single).isEmpty)
    }

    // MARK: - MapTrackStyle constants

    func testTrackWidthsAreOrderedByContextImportance() {
        XCTAssertLessThan(MapTrackStyle.Width.overview, MapTrackStyle.Width.day)
        XCTAssertLessThan(MapTrackStyle.Width.day,      MapTrackStyle.Width.editor)
        XCTAssertLessThan(MapTrackStyle.Width.editor,   MapTrackStyle.Width.export)
        XCTAssertLessThan(MapTrackStyle.Width.export,   MapTrackStyle.Width.live)
    }

    func testHaloMultiplierProducesWiderUnderlayer() {
        XCTAssertGreaterThan(MapTrackStyle.haloMultiplier, 1.0)
    }

    // MARK: - MapCoordinateGuard

    func testCoordinateGuardRejectsNaN() {
        XCTAssertFalse(MapCoordinateGuard.isValid(.init(latitude: .nan, longitude: 8)))
        XCTAssertFalse(MapCoordinateGuard.isValid(.init(latitude: 53, longitude: .nan)))
    }

    func testCoordinateGuardRejectsInfinity() {
        XCTAssertFalse(MapCoordinateGuard.isValid(.init(latitude: .infinity, longitude: 8)))
        XCTAssertFalse(MapCoordinateGuard.isValid(.init(latitude: 53, longitude: -.infinity)))
    }

    func testCoordinateGuardRejectsOutOfRangeLatitude() {
        XCTAssertFalse(MapCoordinateGuard.isValid(.init(latitude: 91, longitude: 0)))
        XCTAssertFalse(MapCoordinateGuard.isValid(.init(latitude: -91, longitude: 0)))
    }

    func testCoordinateGuardRejectsAppleInvalidSentinel() {
        // kCLLocationCoordinate2DInvalid: lat = lon = -180.
        XCTAssertFalse(MapCoordinateGuard.isValid(.init(latitude: -180, longitude: -180)))
    }

    func testCoordinateGuardAcceptsRealisticCoordinate() {
        XCTAssertTrue(MapCoordinateGuard.isValid(.init(latitude: 53.144, longitude: 8.214)))
    }

    func testCoordinateGuardSanitizeStripsBadEntriesFromList() {
        let mixed: [CLLocationCoordinate2D] = [
            .init(latitude: 53.0, longitude: 8.0),
            .init(latitude: .nan, longitude: 8.0),
            .init(latitude: 53.1, longitude: 8.1),
            .init(latitude: -180, longitude: -180),
            .init(latitude: 53.2, longitude: 8.2),
        ]
        let sanitized = MapCoordinateGuard.sanitize(mixed)
        XCTAssertEqual(sanitized.count, 3)
        XCTAssertTrue(sanitized.allSatisfy(MapCoordinateGuard.isValid))
    }

    // MARK: - Helper

    private func sample(_ lat: Double, _ lon: Double, _ time: Date) -> TrackSample {
        TrackSample(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            timestamp: time
        )
    }
}
#endif
