import XCTest
@testable import LocationHistoryConsumer

final class CoordinateUtilsTests: XCTestCase {

    // MARK: - Haversine distance

    /// Same coordinate must return exactly 0.
    func testSamePointIsZero() {
        let berlin = LocationCoordinate2D(latitude: 52.52, longitude: 13.405)
        XCTAssertEqual(berlin.distance(to: berlin), 0.0)
    }

    /// One degree of longitude at the equator ≈ 111 195 m.
    /// Reference: 2π · 6 371 000 / 360 = 111 194.9 m
    func testOneDegreeLongitudeAtEquator() {
        let a = LocationCoordinate2D(latitude: 0.0, longitude: 0.0)
        let b = LocationCoordinate2D(latitude: 0.0, longitude: 1.0)
        XCTAssertEqual(a.distance(to: b), 111_195, accuracy: 500)
    }

    /// Berlin → Paris straight-line distance ≈ 878 km.
    /// Verified independently via Haversine with R = 6 371 km.
    func testBerlinToParisApproximate() {
        let berlin = LocationCoordinate2D(latitude: 52.52, longitude: 13.405)
        let paris  = LocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        XCTAssertEqual(berlin.distance(to: paris), 878_000, accuracy: 3_000)
    }

    /// Haversine must be symmetric: d(A, B) == d(B, A).
    func testSymmetry() {
        let berlin = LocationCoordinate2D(latitude: 52.52, longitude: 13.405)
        let paris  = LocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        XCTAssertEqual(berlin.distance(to: paris), paris.distance(to: berlin))
    }

    /// Half the equator: (0°, 0°) → (0°, 180°) = π · R = 6 371 000π m ≈ 20 015 087 m.
    /// This is an analytically exact result for the Haversine formula.
    func testHalfEquatorLength() {
        let a = LocationCoordinate2D(latitude: 0.0, longitude: 0.0)
        let b = LocationCoordinate2D(latitude: 0.0, longitude: 180.0)
        let expected = 6_371_000.0 * Double.pi
        XCTAssertEqual(a.distance(to: b), expected, accuracy: 1.0)
    }
}
