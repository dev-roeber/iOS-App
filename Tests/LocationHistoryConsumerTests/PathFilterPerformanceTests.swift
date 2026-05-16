import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Train-A baseline (2026-05-16): Foundation-only Linux-CI-portable
/// performance probes for `PathFilter.removeOutliers`. Baseline-only, no
/// hard wall-clock fail-bar; see `PathSimplificationPerformanceTests` for
/// the rationale.
///
/// Two regimes are exercised:
///
/// 1. A clean synthetic walk (no outliers) where the inner Haversine call
///    decides "keep" for every point — worst case for the filter, since
///    nothing is short-circuited.
/// 2. The same walk with every 100th point replaced by a multi-thousand-km
///    jump so the rejection branch becomes hot. Real Google Timeline imports
///    do trigger this branch, but rarely; this case is the canary.
final class PathFilterPerformanceTests: XCTestCase {

    private static let cleanPath1k: [LocationCoordinate2D] = synthesizePath(
        pointCount: 1_000,
        injectOutlierEvery: 0
    )
    private static let cleanPath5k: [LocationCoordinate2D] = synthesizePath(
        pointCount: 5_000,
        injectOutlierEvery: 0
    )
    private static let outlierPath5k: [LocationCoordinate2D] = synthesizePath(
        pointCount: 5_000,
        injectOutlierEvery: 100
    )

    func testRemoveOutliers1kClean() {
        let path = Self.cleanPath1k
        measure {
            _ = PathFilter.removeOutliers(path)
        }
    }

    func testRemoveOutliers5kClean() {
        let path = Self.cleanPath5k
        measure {
            _ = PathFilter.removeOutliers(path)
        }
    }

    func testRemoveOutliers5kWithJumps() {
        let path = Self.outlierPath5k
        measure {
            _ = PathFilter.removeOutliers(path)
        }
    }

    // MARK: - Correctness invariants

    func testRemoveOutliersIsIdentityOnCleanWalk() {
        let filtered = PathFilter.removeOutliers(Self.cleanPath5k)
        XCTAssertEqual(filtered.count, Self.cleanPath5k.count)
        XCTAssertEqual(filtered.first, Self.cleanPath5k.first)
        XCTAssertEqual(filtered.last, Self.cleanPath5k.last)
    }

    func testRemoveOutliersDropsBigJumps() {
        let filtered = PathFilter.removeOutliers(Self.outlierPath5k)
        XCTAssertLessThan(filtered.count, Self.outlierPath5k.count)
        XCTAssertGreaterThanOrEqual(filtered.count, 2)
    }

    func testRemoveOutliersShortInputReturnedAsIs() {
        let one = [LocationCoordinate2D(latitude: 50, longitude: 8)]
        XCTAssertEqual(PathFilter.removeOutliers(one), one)
        let empty: [LocationCoordinate2D] = []
        XCTAssertEqual(PathFilter.removeOutliers(empty), empty)
    }

    // MARK: - Helpers

    /// Deterministic synthetic walk with a configurable outlier rhythm.
    /// `injectOutlierEvery == 0` produces a clean walk; otherwise every Nth
    /// point is replaced by a coordinate ~10 000 km away so the filter's
    /// 5 000 m jump rejection branch fires.
    private static func synthesizePath(
        pointCount: Int,
        injectOutlierEvery: Int
    ) -> [LocationCoordinate2D] {
        var out: [LocationCoordinate2D] = []
        out.reserveCapacity(pointCount)
        for i in 0..<pointCount {
            if injectOutlierEvery > 0, i > 0, i % injectOutlierEvery == 0 {
                // Antipode-ish jump — guaranteed > 5 km.
                out.append(LocationCoordinate2D(latitude: -50, longitude: -100))
            } else {
                let lat = 50.0 + Double(i) * 1e-6
                let lon = 8.0 + Double(i) * 1e-6
                out.append(LocationCoordinate2D(latitude: lat, longitude: lon))
            }
        }
        return out
    }
}
