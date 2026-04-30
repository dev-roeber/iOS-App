import XCTest
@testable import LocationHistoryConsumerAppSupport

// MARK: - LHMapHeaderVisibility

final class LHMapHeaderVisibilityTests: XCTestCase {

    func testAllCasesPresent() {
        let all = LHMapHeaderVisibility.allCases
        XCTAssertTrue(all.contains(.hidden))
        XCTAssertTrue(all.contains(.compact))
        XCTAssertTrue(all.contains(.expanded))
        XCTAssertTrue(all.contains(.fullscreen))
    }

    func testRawValueRoundTrip() {
        for v in LHMapHeaderVisibility.allCases {
            XCTAssertEqual(LHMapHeaderVisibility(rawValue: v.rawValue), v)
        }
    }
}

// MARK: - LHMapHeaderState — shouldRenderMap invariant

final class LHMapHeaderStateRenderInvariantTests: XCTestCase {

    func testHiddenStateDoesNotRenderMap() {
        let state = LHMapHeaderState(visibility: .hidden)
        XCTAssertFalse(state.shouldRenderMap,
            "Performance invariant: map must NOT be in the view tree when hidden")
    }

    func testCompactStateRendersMap() {
        XCTAssertTrue(LHMapHeaderState(visibility: .compact).shouldRenderMap)
    }

    func testExpandedStateRendersMap() {
        XCTAssertTrue(LHMapHeaderState(visibility: .expanded).shouldRenderMap)
    }

    func testFullscreenStateRendersMap() {
        // Fullscreen cover also renders the map content
        XCTAssertTrue(LHMapHeaderState(visibility: .fullscreen).shouldRenderMap)
    }
}

// MARK: - LHMapHeaderState — mapFrameHeight

final class LHMapHeaderStateFrameHeightTests: XCTestCase {

    func testMapFrameHeightIsNilWhenHidden() {
        XCTAssertNil(LHMapHeaderState(visibility: .hidden).mapFrameHeight)
    }

    func testMapFrameHeightIsCompactHeight() {
        let state = LHMapHeaderState(visibility: .compact, compactHeight: 180)
        XCTAssertEqual(state.mapFrameHeight, 180)
    }

    func testMapFrameHeightIsExpandedHeight() {
        let state = LHMapHeaderState(visibility: .expanded, expandedHeight: 320)
        XCTAssertEqual(state.mapFrameHeight, 320)
    }

    func testMapFrameHeightIsNilForFullscreen() {
        // Fullscreen uses a cover, not a fixed frame height
        XCTAssertNil(LHMapHeaderState(visibility: .fullscreen).mapFrameHeight)
    }

    func testCustomHeightsAreStored() {
        let state = LHMapHeaderState(visibility: .compact, compactHeight: 200, expandedHeight: 400)
        XCTAssertEqual(state.compactHeight, 200)
        XCTAssertEqual(state.expandedHeight, 400)
        XCTAssertEqual(state.mapFrameHeight, 200)
    }

    func testDefaultHeightsMatchConstants() {
        let state = LHMapHeaderState()
        XCTAssertEqual(state.compactHeight, LHMapHeaderState.defaultCompactHeight)
        XCTAssertEqual(state.expandedHeight, LHMapHeaderState.defaultExpandedHeight)
    }
}

// MARK: - LHMapHeaderState — transitions

final class LHMapHeaderStateTransitionTests: XCTestCase {

    // toggleHidden

    func testToggleHiddenFromHiddenBecomesCompact() {
        var state = LHMapHeaderState(visibility: .hidden)
        state.toggleHidden()
        XCTAssertEqual(state.visibility, .compact)
    }

    func testToggleHiddenFromCompactBecomesHidden() {
        var state = LHMapHeaderState(visibility: .compact)
        state.toggleHidden()
        XCTAssertEqual(state.visibility, .hidden)
    }

    func testToggleHiddenFromExpandedBecomesHidden() {
        var state = LHMapHeaderState(visibility: .expanded)
        state.toggleHidden()
        XCTAssertEqual(state.visibility, .hidden)
    }

    func testToggleHiddenFromFullscreenBecomesHidden() {
        var state = LHMapHeaderState(visibility: .fullscreen)
        state.toggleHidden()
        XCTAssertEqual(state.visibility, .hidden)
    }

    // expand

    func testExpandFromCompactBecomesExpanded() {
        var state = LHMapHeaderState(visibility: .compact)
        state.expand()
        XCTAssertEqual(state.visibility, .expanded)
    }

    func testExpandFromHiddenIsNoOp() {
        var state = LHMapHeaderState(visibility: .hidden)
        state.expand()
        XCTAssertEqual(state.visibility, .hidden)
    }

    func testExpandFromExpandedIsNoOp() {
        var state = LHMapHeaderState(visibility: .expanded)
        state.expand()
        XCTAssertEqual(state.visibility, .expanded)
    }

    func testExpandFromFullscreenIsNoOp() {
        var state = LHMapHeaderState(visibility: .fullscreen)
        state.expand()
        XCTAssertEqual(state.visibility, .fullscreen)
    }

    // collapse

    func testCollapseFromExpandedBecomesCompact() {
        var state = LHMapHeaderState(visibility: .expanded)
        state.collapse()
        XCTAssertEqual(state.visibility, .compact)
    }

    func testCollapseFromCompactIsNoOp() {
        var state = LHMapHeaderState(visibility: .compact)
        state.collapse()
        XCTAssertEqual(state.visibility, .compact)
    }

    func testCollapseFromHiddenIsNoOp() {
        var state = LHMapHeaderState(visibility: .hidden)
        state.collapse()
        XCTAssertEqual(state.visibility, .hidden)
    }

    func testCollapseFromFullscreenIsNoOp() {
        var state = LHMapHeaderState(visibility: .fullscreen)
        state.collapse()
        XCTAssertEqual(state.visibility, .fullscreen)
    }

    // enterFullscreen

    func testEnterFullscreenFromExpandedBecomesFullscreen() {
        var state = LHMapHeaderState(visibility: .expanded)
        state.enterFullscreen()
        XCTAssertEqual(state.visibility, .fullscreen)
    }

    func testEnterFullscreenFromCompactIsNoOp() {
        var state = LHMapHeaderState(visibility: .compact)
        state.enterFullscreen()
        XCTAssertEqual(state.visibility, .compact)
    }

    func testEnterFullscreenFromHiddenIsNoOp() {
        var state = LHMapHeaderState(visibility: .hidden)
        state.enterFullscreen()
        XCTAssertEqual(state.visibility, .hidden)
    }

    // exitFullscreen

    func testExitFullscreenBecomesExpanded() {
        var state = LHMapHeaderState(visibility: .fullscreen)
        state.exitFullscreen()
        XCTAssertEqual(state.visibility, .expanded)
    }

    func testExitFullscreenFromExpandedIsNoOp() {
        var state = LHMapHeaderState(visibility: .expanded)
        state.exitFullscreen()
        XCTAssertEqual(state.visibility, .expanded)
    }

    func testExitFullscreenFromCompactIsNoOp() {
        var state = LHMapHeaderState(visibility: .compact)
        state.exitFullscreen()
        XCTAssertEqual(state.visibility, .compact)
    }

    func testExitFullscreenFromHiddenIsNoOp() {
        var state = LHMapHeaderState(visibility: .hidden)
        state.exitFullscreen()
        XCTAssertEqual(state.visibility, .hidden)
    }
}

// MARK: - LHMapHeaderState — convenience predicates

final class LHMapHeaderStatePredicateTests: XCTestCase {

    func testIsHiddenPredicates() {
        XCTAssertTrue(LHMapHeaderState(visibility: .hidden).isHidden)
        XCTAssertFalse(LHMapHeaderState(visibility: .compact).isHidden)
        XCTAssertFalse(LHMapHeaderState(visibility: .expanded).isHidden)
        XCTAssertFalse(LHMapHeaderState(visibility: .fullscreen).isHidden)
    }

    func testIsCompactPredicates() {
        XCTAssertTrue(LHMapHeaderState(visibility: .compact).isCompact)
        XCTAssertFalse(LHMapHeaderState(visibility: .hidden).isCompact)
        XCTAssertFalse(LHMapHeaderState(visibility: .expanded).isCompact)
        XCTAssertFalse(LHMapHeaderState(visibility: .fullscreen).isCompact)
    }

    func testIsExpandedPredicates() {
        XCTAssertTrue(LHMapHeaderState(visibility: .expanded).isExpanded)
        XCTAssertFalse(LHMapHeaderState(visibility: .hidden).isExpanded)
        XCTAssertFalse(LHMapHeaderState(visibility: .compact).isExpanded)
        XCTAssertFalse(LHMapHeaderState(visibility: .fullscreen).isExpanded)
    }

    func testIsFullscreenPredicates() {
        XCTAssertTrue(LHMapHeaderState(visibility: .fullscreen).isFullscreen)
        XCTAssertFalse(LHMapHeaderState(visibility: .hidden).isFullscreen)
        XCTAssertFalse(LHMapHeaderState(visibility: .compact).isFullscreen)
        XCTAssertFalse(LHMapHeaderState(visibility: .expanded).isFullscreen)
    }
}

// MARK: - LHMapHeaderState — button labels (accessibility)

final class LHMapHeaderStateButtonLabelTests: XCTestCase {

    func testToggleButtonLabelWhenHidden() {
        XCTAssertEqual(LHMapHeaderState(visibility: .hidden).toggleButtonLabel, "Show Map")
    }

    func testToggleButtonLabelWhenCompact() {
        XCTAssertEqual(LHMapHeaderState(visibility: .compact).toggleButtonLabel, "Collapse Map")
    }

    func testToggleButtonLabelWhenExpanded() {
        XCTAssertEqual(LHMapHeaderState(visibility: .expanded).toggleButtonLabel, "Collapse Map")
    }

    func testToggleButtonLabelWhenFullscreen() {
        XCTAssertEqual(LHMapHeaderState(visibility: .fullscreen).toggleButtonLabel, "Collapse Map")
    }

    func testExpandButtonLabel() {
        XCTAssertEqual(LHMapHeaderState().expandButtonLabel, "Expand Map")
    }

    func testCollapseButtonLabel() {
        XCTAssertEqual(LHMapHeaderState().collapseButtonLabel, "Collapse Map")
    }

    func testFullscreenButtonLabel() {
        XCTAssertEqual(LHMapHeaderState().fullscreenButtonLabel, "Fullscreen")
    }

    func testCloseFullscreenButtonLabel() {
        XCTAssertEqual(LHMapHeaderState().closeFullscreenButtonLabel, "Close Map")
    }

    func testMapPreviewLabel() {
        XCTAssertEqual(LHMapHeaderState().mapPreviewLabel, "Map Preview")
    }
}

// MARK: - LHMapHeaderState — Equatable

final class LHMapHeaderStateEquatableTests: XCTestCase {

    func testEqualStatesAreEqual() {
        XCTAssertEqual(
            LHMapHeaderState(visibility: .compact, compactHeight: 180, expandedHeight: 320),
            LHMapHeaderState(visibility: .compact, compactHeight: 180, expandedHeight: 320)
        )
    }

    func testDifferentVisibilityNotEqual() {
        XCTAssertNotEqual(
            LHMapHeaderState(visibility: .hidden),
            LHMapHeaderState(visibility: .compact)
        )
    }

    func testDifferentHeightNotEqual() {
        XCTAssertNotEqual(
            LHMapHeaderState(visibility: .compact, compactHeight: 180),
            LHMapHeaderState(visibility: .compact, compactHeight: 200)
        )
    }
}

// MARK: - Round-trip transition sequences

final class LHMapHeaderStateSequenceTests: XCTestCase {

    func testFullVisibleCycle() {
        var state = LHMapHeaderState(visibility: .hidden)
        state.toggleHidden()              // → compact
        XCTAssertEqual(state.visibility, .compact)
        state.expand()                    // → expanded
        XCTAssertEqual(state.visibility, .expanded)
        state.enterFullscreen()           // → fullscreen
        XCTAssertEqual(state.visibility, .fullscreen)
        state.exitFullscreen()            // → expanded
        XCTAssertEqual(state.visibility, .expanded)
        state.collapse()                  // → compact
        XCTAssertEqual(state.visibility, .compact)
        state.toggleHidden()              // → hidden
        XCTAssertEqual(state.visibility, .hidden)
    }

    func testDoubleToggleRestoresCompact() {
        var state = LHMapHeaderState(visibility: .compact)
        state.toggleHidden()
        XCTAssertEqual(state.visibility, .hidden)
        state.toggleHidden()
        XCTAssertEqual(state.visibility, .compact)
    }
}
