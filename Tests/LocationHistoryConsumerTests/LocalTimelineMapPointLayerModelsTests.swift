import Foundation
import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Phase-10B (Weg 3) — Modelle für den Punktelayer (Foundation-only,
/// keine Provider-Abhängigkeit).
final class LocalTimelineMapPointLayerModelsTests: XCTestCase {

    // MARK: - PointKind

    func testPointKindRawValuesAndCaseIterableOrder() {
        XCTAssertEqual(LocalTimelineMapPointKind.visit.rawValue, "visit")
        XCTAssertEqual(LocalTimelineMapPointKind.activityStart.rawValue, "activityStart")
        XCTAssertEqual(LocalTimelineMapPointKind.activityEnd.rawValue, "activityEnd")
        XCTAssertEqual(LocalTimelineMapPointKind.routeSample.rawValue, "routeSample")
        XCTAssertEqual(LocalTimelineMapPointKind.allCases,
                       [.visit, .activityStart, .activityEnd, .routeSample])
    }

    // MARK: - Cluster.dominantKind

    func testClusterDominantKindUniqueMajority() {
        let c = LocalTimelineMapPointCluster(
            centerLat: 0, centerLon: 0,
            count: 10,
            visitCount: 1, activityStartCount: 7, activityEndCount: 1, routeSampleCount: 1
        )
        XCTAssertEqual(c.dominantKind, .activityStart)
    }

    func testClusterDominantKindTieBreakInCaseIterableOrder() {
        // Alle Counts gleich — Tie-Break auf erste Kind in CaseIterable: visit.
        let allEqual = LocalTimelineMapPointCluster(
            centerLat: 0, centerLon: 0,
            count: 4,
            visitCount: 1, activityStartCount: 1, activityEndCount: 1, routeSampleCount: 1
        )
        XCTAssertEqual(allEqual.dominantKind, .visit)

        // visit + activityStart gleich → visit gewinnt.
        let visitTieStart = LocalTimelineMapPointCluster(
            centerLat: 0, centerLon: 0,
            count: 6,
            visitCount: 3, activityStartCount: 3, activityEndCount: 0, routeSampleCount: 0
        )
        XCTAssertEqual(visitTieStart.dominantKind, .visit)

        // activityStart + activityEnd gleich → activityStart gewinnt.
        let startTieEnd = LocalTimelineMapPointCluster(
            centerLat: 0, centerLon: 0,
            count: 4,
            visitCount: 0, activityStartCount: 2, activityEndCount: 2, routeSampleCount: 0
        )
        XCTAssertEqual(startTieEnd.dominantKind, .activityStart)

        // activityEnd + routeSample gleich → activityEnd gewinnt.
        let endTieSample = LocalTimelineMapPointCluster(
            centerLat: 0, centerLon: 0,
            count: 4,
            visitCount: 0, activityStartCount: 0, activityEndCount: 2, routeSampleCount: 2
        )
        XCTAssertEqual(endTieSample.dominantKind, .activityEnd)
    }

    func testClusterDominantKindRouteSampleSoleHigh() {
        let c = LocalTimelineMapPointCluster(
            centerLat: 0, centerLon: 0,
            count: 5,
            visitCount: 0, activityStartCount: 0, activityEndCount: 0, routeSampleCount: 5
        )
        XCTAssertEqual(c.dominantKind, .routeSample)
    }

    // MARK: - PointLayerResponse.isTruncated / pointCount

    func testResponseIsTruncatedAcrossAllFlagCombinations() {
        // 8 Kombinationen aus drei Bool-Flags.
        for v in [false, true] {
            for a in [false, true] {
                for r in [false, true] {
                    let resp = LocalTimelineMapPointLayerResponse(
                        detailLevel: .medium,
                        entries: [],
                        truncatedVisits: v,
                        truncatedActivities: a,
                        truncatedRouteSamples: r,
                        totalRouteCandidatesScanned: 0
                    )
                    XCTAssertEqual(resp.isTruncated, v || a || r,
                        "isTruncated logical-OR mismatch (v=\(v), a=\(a), r=\(r))")
                }
            }
        }
    }

    func testResponsePointCountEqualsEntriesCount() {
        let entries: [LocalTimelineMapPointLayerEntry] = (0..<7).map {
            LocalTimelineMapPointLayerEntry(
                kind: .visit,
                referenceID: "v-\($0)",
                dayID: "day-1",
                latitude: 48.0 + Double($0) * 0.001,
                longitude: 11.0,
                sampleIndex: nil
            )
        }
        let resp = LocalTimelineMapPointLayerResponse(
            detailLevel: .low,
            entries: entries,
            truncatedVisits: false,
            truncatedActivities: false,
            truncatedRouteSamples: false,
            totalRouteCandidatesScanned: 0
        )
        XCTAssertEqual(resp.pointCount, 7)
        XCTAssertEqual(resp.pointCount, resp.entries.count)
        XCTAssertFalse(resp.isTruncated)
    }

    // MARK: - ClusterResponse.isTruncated

    func testClusterResponseIsTruncatedFlagsCovered() {
        let base = LocalTimelineMapPointClusterResponse(
            detailLevel: .medium,
            cellSizeDegrees: 0.01,
            clusters: [],
            totalEntriesAggregated: 0,
            truncatedClusters: false,
            sourceTruncated: false
        )
        XCTAssertFalse(base.isTruncated)

        let clusterTrunc = LocalTimelineMapPointClusterResponse(
            detailLevel: .medium, cellSizeDegrees: 0.01,
            clusters: [], totalEntriesAggregated: 0,
            truncatedClusters: true, sourceTruncated: false
        )
        XCTAssertTrue(clusterTrunc.isTruncated)

        let sourceTrunc = LocalTimelineMapPointClusterResponse(
            detailLevel: .medium, cellSizeDegrees: 0.01,
            clusters: [], totalEntriesAggregated: 0,
            truncatedClusters: false, sourceTruncated: true
        )
        XCTAssertTrue(sourceTrunc.isTruncated)

        let both = LocalTimelineMapPointClusterResponse(
            detailLevel: .medium, cellSizeDegrees: 0.01,
            clusters: [], totalEntriesAggregated: 0,
            truncatedClusters: true, sourceTruncated: true
        )
        XCTAssertTrue(both.isTruncated)
    }
}
