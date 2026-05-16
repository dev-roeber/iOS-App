import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Train M, Phase 2 — locks the central `AppAccessibilityID` constants
/// to their canonical strings so XCUITest call-sites (Mac/Xcode only)
/// can rely on the exact identifier values.
final class AppAccessibilityIDTests: XCTestCase {

    func testRootIdentifiers() {
        XCTAssertEqual(AppAccessibilityID.Root.preProductionBanner, "root.preProductionBanner")
    }

    func testTabIdentifiers() {
        XCTAssertEqual(AppAccessibilityID.Tab.overview, "tab.overview")
        XCTAssertEqual(AppAccessibilityID.Tab.days,     "tab.days")
        XCTAssertEqual(AppAccessibilityID.Tab.insights, "tab.insights")
        XCTAssertEqual(AppAccessibilityID.Tab.export,   "tab.export")
        XCTAssertEqual(AppAccessibilityID.Tab.live,     "tab.live")
    }

    func testTabIdentifiersAreUnique() {
        let all = [
            AppAccessibilityID.Tab.overview,
            AppAccessibilityID.Tab.days,
            AppAccessibilityID.Tab.insights,
            AppAccessibilityID.Tab.export,
            AppAccessibilityID.Tab.live,
        ]
        XCTAssertEqual(Set(all).count, all.count, "Tab identifiers must be unique.")
    }

    func testMapIdentifiers() {
        XCTAssertEqual(AppAccessibilityID.Map.overviewRoot,      "map.overview.root")
        XCTAssertEqual(AppAccessibilityID.Map.heatmapRoot,       "map.heatmap.root")
        XCTAssertEqual(AppAccessibilityID.Map.exportPreviewRoot, "map.exportPreview.root")
        XCTAssertEqual(AppAccessibilityID.Map.dayDetailRoot,     "map.dayDetail.root")
    }

    func testMapIdentifiersAreUnique() {
        let all = [
            AppAccessibilityID.Map.overviewRoot,
            AppAccessibilityID.Map.heatmapRoot,
            AppAccessibilityID.Map.exportPreviewRoot,
            AppAccessibilityID.Map.dayDetailRoot,
        ]
        XCTAssertEqual(Set(all).count, all.count, "Map root identifiers must be unique.")
    }

    func testIdentifiersAreStaticAndNonEmpty() {
        let all = [
            AppAccessibilityID.Root.preProductionBanner,
            AppAccessibilityID.Tab.overview,
            AppAccessibilityID.Tab.days,
            AppAccessibilityID.Tab.insights,
            AppAccessibilityID.Tab.export,
            AppAccessibilityID.Tab.live,
            AppAccessibilityID.Map.overviewRoot,
            AppAccessibilityID.Map.heatmapRoot,
            AppAccessibilityID.Map.exportPreviewRoot,
            AppAccessibilityID.Map.dayDetailRoot,
        ]
        for id in all {
            XCTAssertFalse(id.isEmpty, "Identifier '\(id)' must not be empty.")
            XCTAssertFalse(id.contains(" "), "Identifier '\(id)' must not contain whitespace.")
            XCTAssertFalse(id.contains("\n"), "Identifier '\(id)' must not contain newlines.")
        }
    }
}
