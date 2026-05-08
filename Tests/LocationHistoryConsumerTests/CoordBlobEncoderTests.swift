import Foundation
import XCTest
@testable import LocationHistoryConsumer

/// Phase-1 spike coverage for `CoordBlobEncoder` / `CoordBlobIterator`.
/// Plattformneutral; läuft auf Linux.
final class CoordBlobEncoderTests: XCTestCase {

    func testSinglePointRoundTrip() throws {
        let blob = try CoordBlobEncoder.encode(flatCoordinates: [52.520008, 13.404954])
        XCTAssertEqual(blob.count, 8)
        let points = try CoordBlobIterator.decodeAll(blob)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].latitude, 52.520008, accuracy: 5e-7)
        XCTAssertEqual(points[0].longitude, 13.404954, accuracy: 5e-7)
    }

    func testMultiPointRoundTrip() throws {
        let flat: [Double] = [
            52.520008, 13.404954,   // Berlin
            48.137154,  11.575382,  // München
            50.110924,   8.682127,  // Frankfurt
            -33.868820, 151.209296, // Sydney
        ]
        let blob = try CoordBlobEncoder.encode(flatCoordinates: flat)
        XCTAssertEqual(blob.count, 32)
        let points = try CoordBlobIterator.decodeAll(blob)
        XCTAssertEqual(points.count, 4)
        for i in 0..<4 {
            XCTAssertEqual(points[i].latitude, flat[2*i], accuracy: 5e-7)
            XCTAssertEqual(points[i].longitude, flat[2*i + 1], accuracy: 5e-7)
        }
    }

    func testFlatCoordinatesRoundTripBytesPerPoint() throws {
        let flat = (0..<100).flatMap { i -> [Double] in
            let lat = 50.0 + Double(i) * 0.001
            let lon = 10.0 + Double(i) * 0.001
            return [lat, lon]
        }
        let blob = try CoordBlobEncoder.encode(flatCoordinates: flat)
        XCTAssertEqual(blob.count, 100 * CoordBlobEncoding.bytesPerPoint)
        let iterator = try CoordBlobIterator(blob: blob)
        XCTAssertEqual(iterator.pointCount, 100)
    }

    func testEncodingFromSequenceOfPairs() throws {
        let pairs: [(Double, Double)] = [(1.0, 2.0), (3.0, 4.0), (5.0, 6.0)]
        let blob = try CoordBlobEncoder.encode(pairs)
        XCTAssertEqual(blob.count, 24)
        let decoded = try CoordBlobIterator.decodeAll(blob)
        XCTAssertEqual(decoded.map { $0.latitude }, [1.0, 3.0, 5.0])
        XCTAssertEqual(decoded.map { $0.longitude }, [2.0, 4.0, 6.0])
    }

    // MARK: - Validation

    func testRejectsNaNLatitude() {
        XCTAssertThrowsError(try CoordBlobEncoder.encode(flatCoordinates: [.nan, 0])) { e in
            guard case .invalidCoordinate = (e as? CoordBlobError) else {
                return XCTFail("Expected .invalidCoordinate, got \(e)")
            }
        }
    }

    func testRejectsInfiniteLongitude() {
        XCTAssertThrowsError(try CoordBlobEncoder.encode(flatCoordinates: [0, .infinity])) { e in
            guard case .invalidCoordinate = (e as? CoordBlobError) else {
                return XCTFail("Expected .invalidCoordinate, got \(e)")
            }
        }
    }

    func testRejectsLatitudeOutOfRange() {
        XCTAssertThrowsError(try CoordBlobEncoder.encode(flatCoordinates: [91.0, 0.0])) { e in
            guard case .outOfRange = (e as? CoordBlobError) else {
                return XCTFail("Expected .outOfRange, got \(e)")
            }
        }
    }

    func testRejectsLongitudeOutOfRange() {
        XCTAssertThrowsError(try CoordBlobEncoder.encode(flatCoordinates: [0.0, 200.0])) { e in
            guard case .outOfRange = (e as? CoordBlobError) else {
                return XCTFail("Expected .outOfRange, got \(e)")
            }
        }
    }

    func testRejectsUnevenFlatLength() {
        XCTAssertThrowsError(try CoordBlobEncoder.encode(flatCoordinates: [1.0, 2.0, 3.0])) { e in
            guard case .unevenFlatCoordinateCount(3) = (e as? CoordBlobError) else {
                return XCTFail("Expected .unevenFlatCoordinateCount(3), got \(e)")
            }
        }
    }

    func testRejectsMalformedBlobLength() {
        let bad = Data([0x01, 0x02, 0x03]) // not multiple of 8
        XCTAssertThrowsError(try CoordBlobIterator(blob: bad)) { e in
            guard case .malformedBlobLength(3) = (e as? CoordBlobError) else {
                return XCTFail("Expected .malformedBlobLength(3), got \(e)")
            }
        }
    }

    func testEmptyBlobIsValidAndEmpty() throws {
        let blob = try CoordBlobEncoder.encode(flatCoordinates: [])
        XCTAssertEqual(blob.count, 0)
        var iterator = try CoordBlobIterator(blob: blob)
        XCTAssertNil(iterator.next())
        XCTAssertEqual(iterator.pointCount, 0)
    }

    // MARK: - Negative coordinates / signedness

    func testNegativeCoordinatesRoundTrip() throws {
        let flat: [Double] = [-89.999999, -179.999999, -0.000001, -0.000001]
        let blob = try CoordBlobEncoder.encode(flatCoordinates: flat)
        let pts = try CoordBlobIterator.decodeAll(blob)
        XCTAssertEqual(pts[0].latitude,  -89.999999, accuracy: 5e-7)
        XCTAssertEqual(pts[0].longitude, -179.999999, accuracy: 5e-7)
        XCTAssertEqual(pts[1].latitude,   -0.000001, accuracy: 5e-7)
    }

    // MARK: - Encoding identifier

    func testEncodingIdentifierIsStable() {
        XCTAssertEqual(CoordBlobEncoding.int32MicrodegreesV1, "int32-microdeg-v1")
        XCTAssertEqual(CoordBlobEncoding.bytesPerPoint, 8)
    }
}
