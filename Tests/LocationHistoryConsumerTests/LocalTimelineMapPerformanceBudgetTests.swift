import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-10B (Weg 3) — `LocalTimelineMapPerformanceBudget` defaults &
/// invariants. Foundation-only, kein UI/Threading.
final class LocalTimelineMapPerformanceBudgetTests: XCTestCase {

    func testDefaultsAreMonotonicallyIncreasingPerDetailLevel() {
        let levels: [LocalTimelineMapDetailLevel] = [.overview, .low, .medium, .high]
        let budgets = levels.map { LocalTimelineMapPerformanceBudget.default(for: $0) }
        for i in 1..<budgets.count {
            let prev = budgets[i - 1]
            let curr = budgets[i]
            XCTAssertGreaterThanOrEqual(curr.maxVisibleRoutes, prev.maxVisibleRoutes,
                "maxVisibleRoutes must be non-decreasing (\(prev.detailLevel) → \(curr.detailLevel))")
            XCTAssertGreaterThanOrEqual(curr.maxRouteCandidates, prev.maxRouteCandidates)
            XCTAssertGreaterThanOrEqual(curr.maxPointLayerSamples, prev.maxPointLayerSamples)
            XCTAssertGreaterThanOrEqual(curr.maxRouteSamplePointsPerRoute,
                                        prev.maxRouteSamplePointsPerRoute)
            XCTAssertGreaterThanOrEqual(curr.maxClusters, prev.maxClusters)
        }
    }

    func testCandidatesAreAtLeastVisibleRoutesForAllDefaults() {
        for lvl in LocalTimelineMapDetailLevel.allCases {
            let b = LocalTimelineMapPerformanceBudget.default(for: lvl)
            XCTAssertGreaterThanOrEqual(b.maxRouteCandidates, b.maxVisibleRoutes,
                "maxRouteCandidates >= maxVisibleRoutes invariant violated for \(lvl)")
        }
    }

    func testEqualityEquatableContract() {
        let a = LocalTimelineMapPerformanceBudget.default(for: .medium)
        let b = LocalTimelineMapPerformanceBudget.default(for: .medium)
        let c = LocalTimelineMapPerformanceBudget.default(for: .high)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testDayMapPinnedValues() {
        let dm = LocalTimelineMapPerformanceBudget.dayMap
        XCTAssertEqual(dm.detailLevel, .medium)
        XCTAssertEqual(dm.maxVisibleRoutes, 12)
        XCTAssertEqual(dm.maxRouteCandidates, 64)
        XCTAssertEqual(dm.maxPointLayerSamples, 800)
        XCTAssertEqual(dm.maxRouteSamplePointsPerRoute, 12)
        XCTAssertEqual(dm.maxClusters, 256)
        XCTAssertEqual(dm.pointBudget.maxPointsPerRoute, 256)
        XCTAssertEqual(dm.pointBudget.maxTotalPoints, 4_096)
        // Invariante muss auch fürs Day-Map-Profil gelten.
        XCTAssertGreaterThanOrEqual(dm.maxRouteCandidates, dm.maxVisibleRoutes)
    }

    func testNonNegativePreconditionsHoldForAllDefaults() {
        for lvl in LocalTimelineMapDetailLevel.allCases {
            let b = LocalTimelineMapPerformanceBudget.default(for: lvl)
            XCTAssertGreaterThanOrEqual(b.maxVisibleRoutes, 0)
            XCTAssertGreaterThanOrEqual(b.maxRouteCandidates, 0)
            XCTAssertGreaterThanOrEqual(b.maxPointLayerSamples, 0)
            XCTAssertGreaterThanOrEqual(b.maxRouteSamplePointsPerRoute, 0)
            XCTAssertGreaterThanOrEqual(b.maxClusters, 0)
        }
        let dm = LocalTimelineMapPerformanceBudget.dayMap
        XCTAssertGreaterThanOrEqual(dm.maxVisibleRoutes, 0)
        XCTAssertGreaterThanOrEqual(dm.maxClusters, 0)
    }

    func testPointBudgetMatchesDefaultTablePerDetailLevel() {
        for lvl in LocalTimelineMapDetailLevel.allCases {
            let b = LocalTimelineMapPerformanceBudget.default(for: lvl)
            let expected = LocalTimelineMapPointBudget.default(for: lvl)
            XCTAssertEqual(b.pointBudget, expected,
                "pointBudget on default(for: \(lvl)) must equal LocalTimelineMapPointBudget.default(for:)")
            XCTAssertEqual(b.detailLevel, lvl)
        }
    }

    func testExplicitPinnedDefaultsTable() {
        let overview = LocalTimelineMapPerformanceBudget.default(for: .overview)
        XCTAssertEqual(overview.maxVisibleRoutes, 24)
        XCTAssertEqual(overview.maxRouteCandidates, 256)
        XCTAssertEqual(overview.maxPointLayerSamples, 1_500)
        XCTAssertEqual(overview.maxRouteSamplePointsPerRoute, 8)
        XCTAssertEqual(overview.maxClusters, 256)

        let low = LocalTimelineMapPerformanceBudget.default(for: .low)
        XCTAssertEqual(low.maxVisibleRoutes, 48)
        XCTAssertEqual(low.maxRouteCandidates, 512)
        XCTAssertEqual(low.maxPointLayerSamples, 3_000)
        XCTAssertEqual(low.maxRouteSamplePointsPerRoute, 16)
        XCTAssertEqual(low.maxClusters, 512)

        let medium = LocalTimelineMapPerformanceBudget.default(for: .medium)
        XCTAssertEqual(medium.maxVisibleRoutes, 96)
        XCTAssertEqual(medium.maxRouteCandidates, 1_024)
        XCTAssertEqual(medium.maxPointLayerSamples, 6_000)
        XCTAssertEqual(medium.maxRouteSamplePointsPerRoute, 32)
        XCTAssertEqual(medium.maxClusters, 1_024)

        let high = LocalTimelineMapPerformanceBudget.default(for: .high)
        XCTAssertEqual(high.maxVisibleRoutes, 192)
        XCTAssertEqual(high.maxRouteCandidates, 2_048)
        XCTAssertEqual(high.maxPointLayerSamples, 12_000)
        XCTAssertEqual(high.maxRouteSamplePointsPerRoute, 64)
        XCTAssertEqual(high.maxClusters, 2_048)
    }
}
