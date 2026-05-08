import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-8A — Stride/Budget-basierter Decimator.
final class LocalTimelineRouteDecimatorTests: XCTestCase {

    private func makeIterator(_ pairs: [(Double, Double)]) -> [EncodedCoordinate] {
        pairs.map { EncodedCoordinate(latitude: $0.0, longitude: $0.1) }
    }

    func testEmptyInputProducesEmpty() {
        let result = LocalTimelineRouteDecimator.decimate(
            [EncodedCoordinate](), originalPointCount: 0, maxPoints: 16
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testSinglePointInputIsStable() {
        let src = makeIterator([(48.0, 11.0)])
        let result = LocalTimelineRouteDecimator.decimate(src, originalPointCount: 1, maxPoints: 16)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].latitude, 48.0)
    }

    func testSmallPathIsReturnedUnchanged() {
        let pairs: [(Double, Double)] = (0..<5).map { (48.0 + Double($0) * 0.001, 11.0) }
        let src = makeIterator(pairs)
        let result = LocalTimelineRouteDecimator.decimate(src, originalPointCount: 5, maxPoints: 256)
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result.first?.latitude ?? .nan, 48.0, accuracy: 1e-9)
        XCTAssertEqual(result.last?.latitude ?? .nan, 48.004, accuracy: 1e-9)
    }

    func testMaxPointsHardCap() {
        let n = 1000
        let pairs: [(Double, Double)] = (0..<n).map { (Double($0) * 0.0001, Double($0) * 0.0001) }
        let src = makeIterator(pairs)
        let result = LocalTimelineRouteDecimator.decimate(src, originalPointCount: n, maxPoints: 64)
        XCTAssertLessThanOrEqual(result.count, 64)
        XCTAssertGreaterThanOrEqual(result.count, 2)
    }

    func testFirstAndLastPointPreserved() {
        let n = 500
        let pairs: [(Double, Double)] = (0..<n).map { (Double($0), Double(n - 1 - $0)) }
        let src = makeIterator(pairs)
        let result = LocalTimelineRouteDecimator.decimate(src, originalPointCount: n, maxPoints: 32)
        XCTAssertEqual(result.first?.latitude, 0.0)
        XCTAssertEqual(result.first?.longitude, Double(n - 1))
        XCTAssertEqual(result.last?.latitude, Double(n - 1))
        XCTAssertEqual(result.last?.longitude, 0.0)
    }

    func testMaxPointsOneKeepsFirstOnly() {
        let pairs: [(Double, Double)] = (0..<100).map { (Double($0), 0.0) }
        let src = makeIterator(pairs)
        let result = LocalTimelineRouteDecimator.decimate(src, originalPointCount: 100, maxPoints: 1)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].latitude, 0.0)
    }

    func testMaxPointsTwoKeepsFirstAndLast() {
        let pairs: [(Double, Double)] = (0..<100).map { (Double($0), 0.0) }
        let src = makeIterator(pairs)
        let result = LocalTimelineRouteDecimator.decimate(src, originalPointCount: 100, maxPoints: 2)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.latitude, 0.0)
        XCTAssertEqual(result.last?.latitude, 99.0)
    }

    func testIteratorOnlyConsumedOnce() throws {
        // Wir nutzen einen echten CoordBlobIterator, um zu beweisen, dass
        // ein single-pass Stream genügt.
        var flat: [Double] = []
        for i in 0..<200 {
            flat.append(48.0 + Double(i) * 0.0001)
            flat.append(11.0 + Double(i) * 0.0001)
        }
        let blob = try CoordBlobEncoder.encode(flatCoordinates: flat)
        let iterator = try CoordBlobIterator(blob: blob)
        let result = LocalTimelineRouteDecimator.decimate(iterator,
                                                          originalPointCount: 200,
                                                          maxPoints: 32)
        XCTAssertLessThanOrEqual(result.count, 32)
        XCTAssertGreaterThanOrEqual(result.count, 2)
        XCTAssertEqual(result.first?.latitude ?? .nan, 48.0, accuracy: 1e-6)
        // Letzter Quell-Punkt: 48.0199
        XCTAssertEqual(result.last?.latitude ?? .nan, 48.0 + 199 * 0.0001, accuracy: 1e-5)
    }
}
