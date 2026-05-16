import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Train-A baseline (2026-05-16): Foundation-only Linux-CI-portable
/// performance probes for `PathSimplification.douglasPeucker`. `measure { … }`
/// reports mean + standard deviation across the default ten runs; **no**
/// `XCTPerformanceMetric_…` fail-bar is configured, so CI does not flake on
/// wall-clock drift. CI / local inspectors compare values visually against
/// the printed median over time.
///
/// Inputs are deterministic synthetic paths (small `1e-5` lat/lon stride,
/// `i % 5_000` wrap to bound the bounding box), the same pattern used by
/// `PathDistanceCalculatorPerformanceTests`. The simplifier is run at
/// `epsilon = 15 m` (default) and `epsilon = 5 m` (denser output) so any
/// future regression in the recursive perpendicular-distance loop is
/// observable in both regimes.
final class PathSimplificationPerformanceTests: XCTestCase {

    private static let path1k: [LocationCoordinate2D] = synthesizePath(pointCount: 1_000)
    private static let path5k: [LocationCoordinate2D] = synthesizePath(pointCount: 5_000)

    // MARK: - Default epsilon (15 m)

    func testDouglasPeucker1kDefaultEpsilon() {
        let path = Self.path1k
        measure {
            _ = PathSimplification.douglasPeucker(path)
        }
    }

    func testDouglasPeucker5kDefaultEpsilon() {
        let path = Self.path5k
        measure {
            _ = PathSimplification.douglasPeucker(path)
        }
    }

    // MARK: - Tight epsilon (5 m)

    /// Denser output / deeper recursion. Visible-regression canary for any
    /// future change to the recursive split heuristic.
    func testDouglasPeucker5kTightEpsilon() {
        let path = Self.path5k
        measure {
            _ = PathSimplification.douglasPeucker(path, epsilon: 5.0)
        }
    }

    // MARK: - Correctness invariants (cheap, run alongside the benchmarks)

    func testDouglasPeuckerPreservesEndpoints() {
        let simplified = PathSimplification.douglasPeucker(Self.path1k)
        XCTAssertGreaterThanOrEqual(simplified.count, 2)
        XCTAssertLessThanOrEqual(simplified.count, Self.path1k.count)
        XCTAssertEqual(simplified.first, Self.path1k.first)
        XCTAssertEqual(simplified.last, Self.path1k.last)
    }

    func testDouglasPeuckerShortPathsReturnedAsIs() {
        let one = [LocationCoordinate2D(latitude: 50, longitude: 8)]
        XCTAssertEqual(PathSimplification.douglasPeucker(one), one)
        let two = [
            LocationCoordinate2D(latitude: 50, longitude: 8),
            LocationCoordinate2D(latitude: 51, longitude: 9),
        ]
        XCTAssertEqual(PathSimplification.douglasPeucker(two), two)
    }

    // MARK: - Helpers

    private static func synthesizePath(pointCount: Int) -> [LocationCoordinate2D] {
        var out: [LocationCoordinate2D] = []
        out.reserveCapacity(pointCount)
        for i in 0..<pointCount {
            let lat = 50.0 + Double(i % 5_000) * 1e-5
            let lon = 8.0 + Double(i % 5_000) * 1e-5
            out.append(LocationCoordinate2D(latitude: lat, longitude: lon))
        }
        return out
    }
}
