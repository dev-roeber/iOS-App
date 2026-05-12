import XCTest
@testable import LocationHistoryConsumer

/// Micro-benchmark coverage for `PathDistanceCalculator`.
///
/// The calculator is the single-source-of-truth for path length on every
/// import surface (Day Detail KPI, Insights, Overview map, Export
/// pipeline). Large Google Timeline imports can produce paths with tens of
/// thousands of points; this suite walks 50k-point synthetic paths via the
/// two canonical entry points so a future regression in the haversine
/// hot loop is visible in `xcodebuild test` output.
///
/// Like the other performance tests in this target the suite is
/// **baseline-only** — `measure { … }` averages ten runs and prints
/// mean + standard deviation, no `XCTPerformanceMetric_…` fail-bar is
/// configured. CI inspects the values manually.
///
/// Gated to Apple platforms so `XCTClockMetric` / `XCTMemoryMetric` are
/// available; on Linux SwiftPM still loads the file but the tests are
/// not compiled.
#if !os(Linux)
@available(macOS 13.0, iOS 16.0, *)
final class PathDistanceCalculatorPerformanceTests: XCTestCase {

    // MARK: - Path-based convenience (`points` shape)

    func testEffectiveDistanceClockOnLargePathPoints() throws {
        let path = synthesizePath(pointCount: 50_000, useFlatCoordinates: false)
        measure(metrics: [XCTClockMetric()]) {
            _ = PathDistanceCalculator.effectiveDistance(for: path)
        }
    }

    // MARK: - Path-based convenience (`flatCoordinates` shape)

    /// Newer Google Timeline imports prefer `flatCoordinates: [Double]`
    /// over `[PathPoint]` to drop the per-point ISO-string allocation
    /// (see GoogleTimelineConverter flat-coords refactor 2026-05-08).
    /// This case walks the same data via the flat-array hot path so any
    /// future regression on the lat/lon-pair haversine loop is visible.
    func testEffectiveDistanceClockOnLargeFlatCoordinatesPath() throws {
        let path = synthesizePath(pointCount: 50_000, useFlatCoordinates: true)
        measure(metrics: [XCTClockMetric()]) {
            _ = PathDistanceCalculator.effectiveDistance(for: path)
        }
    }

    // MARK: - Memory profile (Darwin only)

    func testEffectiveDistanceMemoryOnLargePathPoints() throws {
        let path = synthesizePath(pointCount: 50_000, useFlatCoordinates: false)
        measure(metrics: [XCTMemoryMetric()]) {
            _ = PathDistanceCalculator.effectiveDistance(for: path)
        }
    }

    // MARK: - Helpers

    /// Deterministic synthetic walk. `(i % 30)` keeps the path bounded so
    /// numerical hops stay reasonable, but the structure is identical
    /// between the points / flatCoordinates variants so the measurements
    /// stay comparable.
    private func synthesizePath(
        pointCount: Int,
        useFlatCoordinates: Bool
    ) -> Path {
        var points: [PathPoint] = []
        var flat: [Double] = []
        if useFlatCoordinates {
            flat.reserveCapacity(pointCount * 2)
        } else {
            points.reserveCapacity(pointCount)
        }
        for i in 0..<pointCount {
            let lat = 50.0 + Double(i % 5_000) * 1e-5
            let lon = 8.0 + Double(i % 5_000) * 1e-5
            if useFlatCoordinates {
                flat.append(lat)
                flat.append(lon)
            } else {
                points.append(PathPoint(lat: lat, lon: lon, time: nil, accuracyM: nil))
            }
        }
        return Path(
            startTime: nil,
            endTime: nil,
            activityType: nil,
            distanceM: nil,
            sourceType: nil,
            points: useFlatCoordinates ? [] : points,
            flatCoordinates: useFlatCoordinates ? flat : nil
        )
    }
}
#endif
