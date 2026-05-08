import Foundation
import XCTest
@testable import LocationHistoryConsumer

/// Verifies that distance calculation is possible directly through the
/// streaming `CoordBlobIterator` without materialising a `[Double]`, and
/// that the result is close to the equivalent flat-coordinates distance.
final class CoordBlobDistanceTests: XCTestCase {

    func testDistanceFromBlobIteratorMatchesFlatBaseline() throws {
        // Berlin → München → Frankfurt
        let flat: [Double] = [
            52.520008, 13.404954,
            48.137154, 11.575382,
            50.110924,  8.682127,
        ]

        let baseline = haversinePolyline(flat: flat)

        let blob = try CoordBlobEncoder.encode(flatCoordinates: flat)
        let iterator = try CoordBlobIterator(blob: blob)
        let viaIterator = totalDistanceMeters(iterator)

        // ~1cm/km tolerance from Int32-microdegree quantisation.
        XCTAssertEqual(viaIterator, baseline, accuracy: max(50.0, baseline * 1e-5))
        XCTAssertGreaterThan(viaIterator, 0)
    }

    func testIteratorCountMatchesEncodedPoints() throws {
        let flat = (0..<10_000).flatMap { i -> [Double] in
            let lat = 50.0 + Double(i) * 1e-5
            let lon = 10.0 + Double(i) * 1e-5
            return [lat, lon]
        }
        let blob = try CoordBlobEncoder.encode(flatCoordinates: flat)
        let iterator = try CoordBlobIterator(blob: blob)
        XCTAssertEqual(iterator.pointCount, 10_000)

        var seen = 0
        var copy = iterator
        while copy.next() != nil { seen += 1 }
        XCTAssertEqual(seen, 10_000)
    }

    // MARK: - helpers

    private func totalDistanceMeters(_ sequence: CoordBlobIterator) -> Double {
        var iterator = sequence
        guard var prev = iterator.next() else { return 0 }
        var total = 0.0
        while let next = iterator.next() {
            total += haversine(prev.latitude, prev.longitude,
                               next.latitude, next.longitude)
            prev = next
        }
        return total
    }

    private func haversinePolyline(flat: [Double]) -> Double {
        var total = 0.0
        var i = 0
        while i + 3 < flat.count {
            total += haversine(flat[i], flat[i+1], flat[i+2], flat[i+3])
            i += 2
        }
        return total
    }

    private func haversine(_ lat1: Double, _ lon1: Double,
                           _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2)
              + cos(lat1 * .pi/180) * cos(lat2 * .pi/180)
              * sin(dLon/2) * sin(dLon/2)
        return r * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
