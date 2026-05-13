import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Foundation-only validator shared between `MapCoordinateGuard` and the
/// data-prep layer (`ExportPreviewDataBuilder`, `AppHeatmapModel` collect,
/// `AppOverviewTracksMapView.scanCandidates`).
final class CoordinateValidityTests: XCTestCase {
    func testValidCoordsAccepted() {
        XCTAssertTrue(CoordinateValidity.isValid(latitude: 0, longitude: 0))
        XCTAssertTrue(CoordinateValidity.isValid(latitude: 52.5, longitude: 13.4))
        XCTAssertTrue(CoordinateValidity.isValid(latitude: -89.999, longitude: 179.999))
        XCTAssertTrue(CoordinateValidity.isValid(latitude: 90, longitude: 180))
        XCTAssertTrue(CoordinateValidity.isValid(latitude: -90, longitude: -179.5))
    }

    func testNaNRejected() {
        XCTAssertFalse(CoordinateValidity.isValid(latitude: .nan, longitude: 13.4))
        XCTAssertFalse(CoordinateValidity.isValid(latitude: 52.5, longitude: .nan))
        XCTAssertFalse(CoordinateValidity.isValid(latitude: .nan, longitude: .nan))
    }

    func testInfinityRejected() {
        XCTAssertFalse(CoordinateValidity.isValid(latitude: .infinity, longitude: 13.4))
        XCTAssertFalse(CoordinateValidity.isValid(latitude: -.infinity, longitude: 13.4))
        XCTAssertFalse(CoordinateValidity.isValid(latitude: 52.5, longitude: .infinity))
    }

    func testOutOfRangeRejected() {
        XCTAssertFalse(CoordinateValidity.isValid(latitude: 90.0001, longitude: 0))
        XCTAssertFalse(CoordinateValidity.isValid(latitude: -90.0001, longitude: 0))
        XCTAssertFalse(CoordinateValidity.isValid(latitude: 0, longitude: 180.0001))
        XCTAssertFalse(CoordinateValidity.isValid(latitude: 0, longitude: -180.0001))
    }

    func testAppleSentinelRejected() {
        // kCLLocationCoordinate2DInvalid is (-180, -180); lon=-180 by itself
        // remains valid because the antimeridian is a real coordinate.
        XCTAssertFalse(CoordinateValidity.isValid(latitude: -180, longitude: -180))
        XCTAssertTrue(CoordinateValidity.isValid(latitude: 0, longitude: -180))
    }
}
