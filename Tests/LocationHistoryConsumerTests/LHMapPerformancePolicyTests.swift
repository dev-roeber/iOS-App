import XCTest
@testable import LocationHistoryConsumerAppSupport

final class LHMapPerformancePolicyTests: XCTestCase {

    // MARK: - Profile inventory

    func test_defaultProfiles_includeAllSevenSurfaces() {
        let profiles = LHMapPerformancePolicy.defaultProfiles
        XCTAssertEqual(profiles.count, 7)
        // Spot-check identity by salient field combinations.
        XCTAssertTrue(profiles.contains(LHMapPerformancePolicy.live))
        XCTAssertTrue(profiles.contains(LHMapPerformancePolicy.dayDetail))
        XCTAssertTrue(profiles.contains(LHMapPerformancePolicy.overview))
        XCTAssertTrue(profiles.contains(LHMapPerformancePolicy.insights))
        XCTAssertTrue(profiles.contains(LHMapPerformancePolicy.export))
        XCTAssertTrue(profiles.contains(LHMapPerformancePolicy.heatmap))
        XCTAssertTrue(profiles.contains(LHMapPerformancePolicy.editor))
    }

    // MARK: - Invariants

    func test_allProfiles_haveNonNegativeCaps() {
        for policy in LHMapPerformancePolicy.defaultProfiles {
            XCTAssertGreaterThanOrEqual(policy.renderPointCap, 0)
            XCTAssertGreaterThanOrEqual(policy.routeOverlayLimit, 0)
        }
    }

    func test_init_clampsNegativeCapsToZero() {
        let p = LHMapPerformancePolicy(
            renderPointCap: -10,
            routeOverlayLimit: -5,
            viewportFilteringEnabled: false,
            lod: .medium,
            mapInTreeWhenHidden: false,
            cameraUpdateMode: .onEnd
        )
        XCTAssertEqual(p.renderPointCap, 0)
        XCTAssertEqual(p.routeOverlayLimit, 0)
    }

    // MARK: - Profile-specific contract

    func test_liveProfile_keepsMapInTreeAndUsesContinuousCamera() {
        let p = LHMapPerformancePolicy.live
        XCTAssertTrue(p.mapInTreeWhenHidden)
        XCTAssertEqual(p.cameraUpdateMode, .continuous)
        XCTAssertEqual(p.lod, .high)
    }

    func test_overviewProfile_enablesViewportFilteringWithLowLOD() {
        let p = LHMapPerformancePolicy.overview
        XCTAssertTrue(p.viewportFilteringEnabled)
        XCTAssertEqual(p.lod, .low)
        XCTAssertEqual(p.cameraUpdateMode, .onEnd)
    }

    func test_heatmapProfile_hasZeroPolylineCaps() {
        // Heatmap rendering owns the budget via the aggregate pipeline; the
        // polyline render cap is 0 by contract.
        let p = LHMapPerformancePolicy.heatmap
        XCTAssertEqual(p.renderPointCap, 0)
        XCTAssertEqual(p.routeOverlayLimit, 0)
    }

    func test_exportProfile_keepsViewportFilteringOff() {
        // Export must surface everything that will ship; viewport filtering
        // would silently truncate the preview vs the file.
        let p = LHMapPerformancePolicy.export
        XCTAssertFalse(p.viewportFilteringEnabled)
    }

    func test_editorProfile_keepsViewportFilteringOff() {
        // Handles must remain reachable at every zoom; no viewport culling.
        let p = LHMapPerformancePolicy.editor
        XCTAssertFalse(p.viewportFilteringEnabled)
    }

    // MARK: - Enums

    func test_cameraUpdateMode_casesAreOnEndAndContinuous() {
        XCTAssertEqual(LHMapCameraUpdateMode.allCases, [.onEnd, .continuous])
    }

    func test_lod_casesAreLowMediumHigh() {
        XCTAssertEqual(LHMapLOD.allCases, [.low, .medium, .high])
    }
}
