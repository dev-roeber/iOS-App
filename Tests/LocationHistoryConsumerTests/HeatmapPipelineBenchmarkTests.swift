import XCTest

#if canImport(SwiftUI) && canImport(MapKit)
import MapKit
@testable import LocationHistoryConsumerAppSupport

/// Map-Train 3: XCTMeasure-based baseline and post-optimisation benchmarks
/// for the heatmap grid pipeline.
///
/// Methodology:
/// - Deterministic synthetic data generated in-test (LCG seed = 1).
/// - Single-LOD calls measure `computeGrid(for:lod:)` for each LOD.
/// - The multi-LOD aggregate call measures `computeMultiLODGrids` once
///   per dataset (computes all 4 LOD grids in one pass over the input).
/// - 10 iterations / case is XCTest's default. RSD is reported by the
///   harness; high-variance cases are interpretation-only.
/// - No flaky absolute thresholds; only baseline-drift detection via
///   Xcode's metric history.
final class HeatmapPipelineBenchmarkTests: XCTestCase {

    private static func synthetic(_ n: Int, seed: UInt64 = 1) -> [WeightedPoint] {
        var rng = seed
        func next() -> Double {
            rng = rng &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(rng & 0xFFFFFFFF) / Double(0xFFFFFFFF)
        }
        var out: [WeightedPoint] = []
        out.reserveCapacity(n)
        for _ in 0..<n {
            // Spread across ~1° × 1° in central Europe to keep all LODs
            // in their normal operating range (no Mercator pole edge).
            let lat = 49.0 + next() * 4.0
            let lon = 9.0 + next() * 6.0
            out.append(WeightedPoint(lat: lat, lon: lon, weight: 1))
        }
        return out
    }

    private static let synthetic1k: [WeightedPoint] = synthetic(1_000)
    private static let synthetic10k: [WeightedPoint] = synthetic(10_000)
    private static let synthetic50k: [WeightedPoint] = synthetic(50_000)

    // MARK: - Baseline: per-LOD compute (4 separate calls)

    /// Baseline: 4 separate `computeGrid` calls (one per LOD). Models the
    /// pre-Train-3 `AppHeatmapModel.ensureDensityPrecomputation` loop.
    func testBaseline_PerLOD_1k() {
        measureGridForAllLODs(points: Self.synthetic1k)
    }

    func testBaseline_PerLOD_10k() {
        measureGridForAllLODs(points: Self.synthetic10k)
    }

    func testBaseline_PerLOD_50k() {
        measureGridForAllLODs(points: Self.synthetic50k)
    }

    // MARK: - Train 3: fused multi-LOD compute

    func testFused_MultiLOD_1k() {
        measureMultiLODGrids(points: Self.synthetic1k)
    }

    func testFused_MultiLOD_10k() {
        measureMultiLODGrids(points: Self.synthetic10k)
    }

    func testFused_MultiLOD_50k() {
        measureMultiLODGrids(points: Self.synthetic50k)
    }

    // MARK: - Helpers

    private func measureGridForAllLODs(points: [WeightedPoint]) {
        measure {
            var total = 0
            for lod in HeatmapLOD.allCases {
                let grid = HeatmapGridBuilder.computeGrid(for: points, lod: lod)
                total &+= grid.count
            }
            XCTAssertGreaterThan(total, 0)
        }
    }

    private func measureMultiLODGrids(points: [WeightedPoint]) {
        measure {
            let grids = HeatmapGridBuilder.computeMultiLODGrids(
                for: points,
                lods: HeatmapLOD.allCases,
                scale: .logarithmic
            )
            var total = 0
            for (_, grid) in grids { total &+= grid.count }
            XCTAssertGreaterThan(total, 0)
        }
    }
}
#endif
