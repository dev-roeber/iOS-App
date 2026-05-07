#if canImport(SwiftUI)
import XCTest
import SwiftUI
@testable import LocationHistoryConsumerAppSupport

/// Layout-property tests covering the Audit P2-7 intent (Hero-Map heights
/// 460/560 and map-control offset clears the status-bar chevron) without
/// pulling in a snapshot-testing dependency. Asserts the `LHHeroMapLayout`
/// constants and the derived properties on `LHMapHeaderState`.
final class LHMapHeaderLayoutTests: XCTestCase {

    // MARK: - LHHeroMapLayout constants

    func testCompactHeightMatchesLayoutConstant() {
        XCTAssertEqual(LHHeroMapLayout.compactHeight, 460)
    }

    func testExpandedHeightMatchesLayoutConstant() {
        XCTAssertEqual(LHHeroMapLayout.expandedHeight, 560)
    }

    func testExpandedHeightIsGreaterThanCompactHeight() {
        XCTAssertGreaterThan(LHHeroMapLayout.expandedHeight,
                             LHHeroMapLayout.compactHeight)
    }

    func testMapControlTopOffsetIsPositive() {
        XCTAssertGreaterThan(LHHeroMapLayout.mapControlTopOffset, 0)
    }

    func testMapControlTopOffsetClearsChevron() {
        // Chevron sits at `safeAreaTop + 80` and is ~44pt tall. Offset must
        // clear chevron-bottom (80 + 44 = 124) so map controls don't overlap.
        XCTAssertGreaterThanOrEqual(LHHeroMapLayout.mapControlTopOffset, 124)
    }

    // MARK: - LHMapHeaderState layout wiring

    func testStateInitializesStickyAsConfigured() {
        let sticky = LHMapHeaderState(
            visibility: .compact,
            compactHeight: LHHeroMapLayout.compactHeight,
            expandedHeight: LHHeroMapLayout.expandedHeight,
            isSticky: true
        )
        XCTAssertTrue(sticky.isSticky)
        XCTAssertEqual(sticky.compactHeight, 460)
        XCTAssertEqual(sticky.expandedHeight, 560)
    }

    func testStateDefaultIsNotSticky() {
        let state = LHMapHeaderState()
        XCTAssertFalse(state.isSticky)
    }

    func testCompactStateMapFrameHeightUsesCompactHeight() {
        let state = LHMapHeaderState(
            visibility: .compact,
            compactHeight: LHHeroMapLayout.compactHeight,
            expandedHeight: LHHeroMapLayout.expandedHeight
        )
        XCTAssertEqual(state.mapFrameHeight, LHHeroMapLayout.compactHeight)
    }

    func testStateExpandsWhenVisibilityIsExpanded() {
        var state = LHMapHeaderState(
            visibility: .compact,
            compactHeight: LHHeroMapLayout.compactHeight,
            expandedHeight: LHHeroMapLayout.expandedHeight
        )
        state.expand()
        XCTAssertEqual(state.visibility, .expanded)
        XCTAssertEqual(state.mapFrameHeight, LHHeroMapLayout.expandedHeight)
    }

    func testHiddenStateHasNoFrameHeight() {
        let state = LHMapHeaderState(visibility: .hidden)
        XCTAssertNil(state.mapFrameHeight)
        XCTAssertFalse(state.shouldRenderMap)
    }

    func testFullscreenStateHasNoFrameHeight() {
        // Fullscreen is presented via cover, so the inline frame must be
        // released (no clipping / fixed bleed) — documented as `nil` height.
        let state = LHMapHeaderState(visibility: .fullscreen)
        XCTAssertNil(state.mapFrameHeight)
        XCTAssertTrue(state.shouldRenderMap)
    }

    func testStickyStateCannotBeFullyHidden() {
        var state = LHMapHeaderState(visibility: .compact, isSticky: true)
        state.toggleHidden()
        XCTAssertEqual(state.visibility, .compact,
                       "Sticky map must remain visible after toggleHidden().")
    }
}
#endif
