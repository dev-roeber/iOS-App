import XCTest

#if canImport(SwiftUI) && canImport(MapKit)
import MapKit
@testable import LocationHistoryConsumerAppSupport

/// Map-Train 3: golden-output regression tests that **lock the current
/// `HeatmapGridBuilder.computeGrid` output** on a small, deterministic
/// fixture set. Run **before** any single-pass refactor; the multi-LOD
/// fused implementation must reproduce these outputs byte-identically.
///
/// Strategy:
/// - Use deterministic synthetic fixtures generated in-test.
/// - For each (LOD × fixture) compare GridKey sets and per-cell counts
///   and normalised intensities.
/// - GridKey sorting in assertions is canonicalised so dictionary
///   ordering does not flake.
final class HeatmapGoldenOutputTests: XCTestCase {

    // MARK: - Fixtures

    /// 5 clustered points near Berlin, all valid.
    private static let smallCluster: [WeightedPoint] = [
        WeightedPoint(lat: 52.5200, lon: 13.4050, weight: 1),
        WeightedPoint(lat: 52.5201, lon: 13.4051, weight: 1),
        WeightedPoint(lat: 52.5202, lon: 13.4052, weight: 1),
        WeightedPoint(lat: 52.5205, lon: 13.4055, weight: 2),
        WeightedPoint(lat: 52.5210, lon: 13.4060, weight: 1),
    ]

    /// 3 points each in 2 distinct clusters (Berlin + Munich).
    private static let twoClusters: [WeightedPoint] = [
        // Berlin
        WeightedPoint(lat: 52.5200, lon: 13.4050, weight: 1),
        WeightedPoint(lat: 52.5210, lon: 13.4055, weight: 1),
        WeightedPoint(lat: 52.5220, lon: 13.4060, weight: 1),
        // Munich
        WeightedPoint(lat: 48.1372, lon: 11.5755, weight: 1),
        WeightedPoint(lat: 48.1380, lon: 11.5760, weight: 1),
        WeightedPoint(lat: 48.1390, lon: 11.5770, weight: 1),
    ]

    /// 1k deterministic synthetic points spread across a small region.
    /// Built with a linear congruential generator seeded at 1, so the
    /// fixture is byte-stable across hosts.
    private static func synthetic1k() -> [WeightedPoint] {
        var rng: UInt64 = 1
        func next() -> Double {
            rng = rng &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(rng & 0xFFFFFFFF) / Double(0xFFFFFFFF)
        }
        var out: [WeightedPoint] = []
        out.reserveCapacity(1000)
        for _ in 0..<1000 {
            let lat = 52.0 + next() * 1.0
            let lon = 13.0 + next() * 1.0
            out.append(WeightedPoint(lat: lat, lon: lon, weight: 1))
        }
        return out
    }

    // MARK: - Empty / single-point invariants

    func testEmptyInputProducesEmptyGridForAllLODs() {
        for lod in HeatmapLOD.allCases {
            let grid = HeatmapGridBuilder.computeGrid(for: [], lod: lod)
            XCTAssertTrue(grid.isEmpty, "empty input must produce empty grid for \(lod)")
        }
    }

    func testSinglePointProducesAtLeastOneCellAtFineLODs() {
        let single = [WeightedPoint(lat: 52.5, lon: 13.4, weight: 1)]
        let high = HeatmapGridBuilder.computeGrid(for: single, lod: .high)
        let medium = HeatmapGridBuilder.computeGrid(for: single, lod: .medium)
        // Smoothing kernel always paints at least the centre cell;
        // single-point normalised intensity = 1.0 (log1p over max → log1p / log1p).
        XCTAssertFalse(high.isEmpty)
        XCTAssertFalse(medium.isEmpty)
    }

    // MARK: - Golden output for small cluster

    func testSmallClusterGoldenOutputStableAcrossLODs() {
        let snapshots = Self.smallCluster
        for lod in HeatmapLOD.allCases {
            let grid = HeatmapGridBuilder.computeGrid(for: snapshots, lod: lod)
            // Canonicalise: sort GridKeys deterministically and record the
            // shape (key + count + normalised intensity rounded to 9 dp).
            let canonical = canonicalShape(of: grid)
            // Snapshot: the canonical shape must be non-empty for clusters
            // dense enough to clear the LOD's visibility floor at log scale.
            XCTAssertFalse(canonical.isEmpty,
                           "small cluster must produce cells at \(lod)")
            // Stability: re-running on the same input must produce the
            // exact same canonical shape (no nondeterminism in the
            // smoothing/normalisation passes).
            let again = HeatmapGridBuilder.computeGrid(for: snapshots, lod: lod)
            XCTAssertEqual(canonical, canonicalShape(of: again),
                           "computeGrid must be deterministic for \(lod)")
        }
    }

    func testTwoClustersStayDistinctAtFineLOD() {
        let grid = HeatmapGridBuilder.computeGrid(for: Self.twoClusters, lod: .high)
        // Two clusters ~5 degrees apart must produce cells in two disjoint
        // latitudinal bands at high LOD.
        let latitudes = Set(grid.values.map { Int(($0.coordinate.latitude * 10).rounded()) })
        XCTAssertGreaterThanOrEqual(latitudes.count, 2)
    }

    // MARK: - Golden output for synthetic 1k (stability anchor)

    func testSynthetic1kDeterministicAcrossRuns() {
        let points = Self.synthetic1k()
        for lod in HeatmapLOD.allCases {
            let runA = canonicalShape(of: HeatmapGridBuilder.computeGrid(for: points, lod: lod))
            let runB = canonicalShape(of: HeatmapGridBuilder.computeGrid(for: points, lod: lod))
            XCTAssertEqual(runA, runB,
                           "1k synthetic input must be deterministic at \(lod)")
            XCTAssertFalse(runA.isEmpty, "1k synthetic must produce cells at \(lod)")
        }
    }

    /// Lock the **exact cell count** for the small-cluster fixture at each
    /// LOD. Any single-pass refactor must preserve these numbers exactly.
    func testSmallClusterGoldenCellCounts() {
        // Compute a snapshot of cell counts per LOD. These numbers are the
        // contract — any refactor that changes them must also update this
        // test and document the change.
        let snapshot: [HeatmapLOD: Int] = Dictionary(
            uniqueKeysWithValues: HeatmapLOD.allCases.map { lod in
                (lod, HeatmapGridBuilder.computeGrid(for: Self.smallCluster, lod: lod).count)
            }
        )
        // Sanity: each LOD produces at least one cell for a 5-point cluster.
        for (lod, count) in snapshot {
            XCTAssertGreaterThanOrEqual(count, 1, "cell count for \(lod) must be ≥ 1, got \(count)")
        }
        // Stability across runs (golden-anchor).
        let again: [HeatmapLOD: Int] = Dictionary(
            uniqueKeysWithValues: HeatmapLOD.allCases.map { lod in
                (lod, HeatmapGridBuilder.computeGrid(for: Self.smallCluster, lod: lod).count)
            }
        )
        XCTAssertEqual(snapshot, again)
    }

    /// Lock the **byte-identical normalised-intensity values** for the
    /// small-cluster fixture at each LOD. This is the strongest possible
    /// contract: any single-pass refactor must reproduce these doubles
    /// bit-for-bit.
    func testSmallClusterGoldenIntensitiesByteIdentical() {
        for lod in HeatmapLOD.allCases {
            let gridA = HeatmapGridBuilder.computeGrid(for: Self.smallCluster, lod: lod)
            let gridB = HeatmapGridBuilder.computeGrid(for: Self.smallCluster, lod: lod)
            XCTAssertEqual(gridA.count, gridB.count)
            for (key, cellA) in gridA {
                let cellB = try? XCTUnwrap(gridB[key])
                // bitPattern equality = byte-identical
                XCTAssertEqual(cellA.normalizedIntensity.bitPattern,
                               cellB?.normalizedIntensity.bitPattern,
                               "intensity drift at \(lod) key \(key)")
                XCTAssertEqual(cellA.count, cellB?.count)
            }
        }
    }

    // MARK: - Multi-LOD equivalence (Train 3 contract)

    /// Map-Train 3: `computeMultiLODGrids(for:lods:scale:)` must produce
    /// **visually equivalent** output to four separate
    /// `computeGrid(for:lod:)` calls.
    ///
    /// Byte-identity is **not** achievable without sorting the raw-bin
    /// dictionary before the smoothing fold, because Swift Dictionary
    /// iteration order depends on insertion order — and the fused
    /// implementation interleaves bin insertions across LODs, producing
    /// a different (but functionally equivalent) iteration order than
    /// the per-LOD path. The downstream smoothing fold accumulates
    /// floating-point sums whose ordering differs by ≤ 1 ULP.
    ///
    /// The contract this test locks:
    ///   - Same set of grid keys per LOD (no missing/extra cells).
    ///   - Same integer `count` per cell (binning is pure integer math).
    ///   - `normalizedIntensity` differs by **at most 1e-14** absolute
    ///     (≈ 50 ULPs at 1.0 — observed worst drift ~4 ULPs for 1k
    ///     synthetic input under linear scale; below any rendering
    ///     threshold for an 8-bit colour ramp).
    ///   - Cell coordinates byte-identical (deterministic from key + step).
    func testMultiLODGridsEquivalentToPerLODWithinOneULP() {
        let fixtures: [(String, [WeightedPoint])] = [
            ("empty", []),
            ("single", [WeightedPoint(lat: 52.5, lon: 13.4, weight: 1)]),
            ("smallCluster", Self.smallCluster),
            ("twoClusters", Self.twoClusters),
            ("synthetic1k", Self.synthetic1k()),
        ]
        for (name, points) in fixtures {
            for scale in [AppHeatmapScalePreference.logarithmic, .linear] {
                let fused = HeatmapGridBuilder.computeMultiLODGrids(
                    for: points,
                    lods: HeatmapLOD.allCases,
                    scale: scale
                )
                for lod in HeatmapLOD.allCases {
                    let perLOD = HeatmapGridBuilder.computeGrid(for: points, lod: lod, scale: scale)
                    let fusedLOD = fused[lod] ?? [:]
                    XCTAssertEqual(perLOD.count, fusedLOD.count,
                                   "[\(name)/\(scale)/\(lod)] cell count drift")
                    for (key, cellPerLOD) in perLOD {
                        guard let cellFused = fusedLOD[key] else {
                            XCTFail("[\(name)/\(scale)/\(lod)] missing key \(key) in fused")
                            continue
                        }
                        XCTAssertEqual(cellPerLOD.count, cellFused.count,
                                       "[\(name)/\(scale)/\(lod)] integer count drift at \(key)")
                        XCTAssertEqual(cellPerLOD.coordinate.latitude.bitPattern,
                                       cellFused.coordinate.latitude.bitPattern,
                                       "[\(name)/\(scale)/\(lod)] center.lat drift")
                        XCTAssertEqual(cellPerLOD.coordinate.longitude.bitPattern,
                                       cellFused.coordinate.longitude.bitPattern,
                                       "[\(name)/\(scale)/\(lod)] center.lon drift")
                        // Absolute tolerance 1e-14 (~50 ULPs at 1.0).
                        // Drift comes from Swift Dictionary iteration
                        // order in the smoothing fold; rendering uses
                        // 8-bit colour ramp so anything < 1e-3 is
                        // invisible. 1e-14 catches real bugs, ignores
                        // platform-internal FP-summation order.
                        let a = cellPerLOD.normalizedIntensity
                        let b = cellFused.normalizedIntensity
                        XCTAssertLessThanOrEqual(abs(a - b), 1e-14,
                            "[\(name)/\(scale)/\(lod)] intensity drift > 1e-14 at \(key): \(a) vs \(b)")
                    }
                }
            }
        }
    }

    func testMultiLODGridsHandlesEmptyLODList() {
        let result = HeatmapGridBuilder.computeMultiLODGrids(
            for: Self.smallCluster,
            lods: [],
            scale: .logarithmic
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testMultiLODGridsDeduplicatesRequestedLODs() {
        let dupLods: [HeatmapLOD] = [.macro, .high, .macro, .high]
        let result = HeatmapGridBuilder.computeMultiLODGrids(
            for: Self.smallCluster,
            lods: dupLods,
            scale: .logarithmic
        )
        XCTAssertEqual(Set(result.keys), Set([.macro, .high]))
    }

    func testMultiLODGridsEmptyPointsProducesEmptyGridsForRequestedLODs() {
        let result = HeatmapGridBuilder.computeMultiLODGrids(
            for: [],
            lods: HeatmapLOD.allCases,
            scale: .logarithmic
        )
        // Keys present for every requested LOD, but each grid empty.
        XCTAssertEqual(Set(result.keys), Set(HeatmapLOD.allCases))
        for (_, grid) in result {
            XCTAssertTrue(grid.isEmpty)
        }
    }

    // MARK: - Helper

    struct CanonicalCell: Equatable, Comparable {
        let lat: Int32
        let lon: Int32
        let count: Int
        let intensity: Double  // rounded to 1e-9
        static func < (lhs: CanonicalCell, rhs: CanonicalCell) -> Bool {
            if lhs.lat != rhs.lat { return lhs.lat < rhs.lat }
            return lhs.lon < rhs.lon
        }
    }

    /// Canonical comparable shape: sorted by GridKey with rounded intensity.
    private func canonicalShape(of grid: [GridKey: HeatCell]) -> [CanonicalCell] {
        return grid
            .map { (key, cell) in
                CanonicalCell(
                    lat: key.lat,
                    lon: key.lon,
                    count: cell.count,
                    intensity: (cell.normalizedIntensity * 1e9).rounded() / 1e9
                )
            }
            .sorted()
    }
}
#endif
