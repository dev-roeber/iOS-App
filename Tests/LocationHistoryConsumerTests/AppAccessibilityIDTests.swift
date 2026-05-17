import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Train M, Phase 2 — locks the central `AppAccessibilityID` constants
/// to their canonical strings so XCUITest call-sites (Mac/Xcode only)
/// can rely on the exact identifier values.
final class AppAccessibilityIDTests: XCTestCase {

    func testRootIdentifiers() {
        XCTAssertEqual(AppAccessibilityID.Root.preProductionBanner, "localTimeline.testMode.banner")
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

    // MARK: - Product info constants (Train P)

    func testProductInfoIdentifierStringsAreCanonical() {
        XCTAssertEqual(AppAccessibilityID.ProductInfo.importSummaryRoot,     "productInfo.importSummary.root")
        XCTAssertEqual(AppAccessibilityID.ProductInfo.importSummaryTitle,    "productInfo.importSummary.title")
        XCTAssertEqual(AppAccessibilityID.ProductInfo.importSummaryRange,    "productInfo.importSummary.range")
        XCTAssertEqual(AppAccessibilityID.ProductInfo.importSummaryCounts,   "productInfo.importSummary.counts")
        XCTAssertEqual(AppAccessibilityID.ProductInfo.importSummaryWarning,  "productInfo.importSummary.warning")
        XCTAssertEqual(AppAccessibilityID.ProductInfo.exportGuidanceRoot,       "productInfo.exportGuidance.root")
        XCTAssertEqual(AppAccessibilityID.ProductInfo.exportGuidanceTitle,      "productInfo.exportGuidance.title")
        XCTAssertEqual(AppAccessibilityID.ProductInfo.exportGuidancePrimaryUse, "productInfo.exportGuidance.primaryUse")
        XCTAssertEqual(AppAccessibilityID.ProductInfo.exportGuidanceTools,      "productInfo.exportGuidance.tools")
        XCTAssertEqual(AppAccessibilityID.ProductInfo.exportGuidanceStrength,   "productInfo.exportGuidance.strength")
        XCTAssertEqual(AppAccessibilityID.ProductInfo.routeQualityRoot,       "productInfo.routeQuality.root")
        XCTAssertEqual(AppAccessibilityID.ProductInfo.routeQualityLevel,      "productInfo.routeQuality.level")
        XCTAssertEqual(AppAccessibilityID.ProductInfo.routeQualityHint,       "productInfo.routeQuality.hint")
        XCTAssertEqual(AppAccessibilityID.ProductInfo.routeQualitySpacing,    "productInfo.routeQuality.spacing")
        XCTAssertEqual(AppAccessibilityID.ProductInfo.routeQualityLargestGap, "productInfo.routeQuality.largestGap")
    }

    func testProductInfoIdentifiersAreUnique() {
        let all = [
            AppAccessibilityID.ProductInfo.importSummaryRoot,
            AppAccessibilityID.ProductInfo.importSummaryTitle,
            AppAccessibilityID.ProductInfo.importSummaryRange,
            AppAccessibilityID.ProductInfo.importSummaryCounts,
            AppAccessibilityID.ProductInfo.importSummaryWarning,
            AppAccessibilityID.ProductInfo.exportGuidanceRoot,
            AppAccessibilityID.ProductInfo.exportGuidanceTitle,
            AppAccessibilityID.ProductInfo.exportGuidancePrimaryUse,
            AppAccessibilityID.ProductInfo.exportGuidanceTools,
            AppAccessibilityID.ProductInfo.exportGuidanceStrength,
            AppAccessibilityID.ProductInfo.routeQualityRoot,
            AppAccessibilityID.ProductInfo.routeQualityLevel,
            AppAccessibilityID.ProductInfo.routeQualityHint,
            AppAccessibilityID.ProductInfo.routeQualitySpacing,
            AppAccessibilityID.ProductInfo.routeQualityLargestGap,
        ]
        XCTAssertEqual(Set(all).count, all.count, "ProductInfo identifiers must be unique.")
        for id in all {
            XCTAssertFalse(id.contains(" "), "ID '\(id)' must not contain whitespace.")
            XCTAssertFalse(id.contains("\n"), "ID '\(id)' must not contain newlines.")
            XCTAssertFalse(id.isEmpty)
        }
    }

    // MARK: - Action constants (Train O, Phase 9)

    func testActionIdentifiersMatchExistingInlineLiterals() {
        // Each Action.* constant must equal the inline string literal
        // already used at the matching view's call-site. If a view
        // renames its identifier, this test must be updated in lockstep.
        XCTAssertEqual(AppAccessibilityID.Action.homeImportPrimary,  "home.import.primary")
        XCTAssertEqual(AppAccessibilityID.Action.exportPrimary,      "export.primaryButton")
        XCTAssertEqual(AppAccessibilityID.Action.livePauseCTA,       "live.cta.pause")
        XCTAssertEqual(AppAccessibilityID.Action.insightsShareChart, "insights.share.chart")
        XCTAssertEqual(AppAccessibilityID.Action.daysExportBar,      "days.exportBar")
    }

    func testActionIdentifiersAreUnique() {
        let all = [
            AppAccessibilityID.Action.homeImportPrimary,
            AppAccessibilityID.Action.exportPrimary,
            AppAccessibilityID.Action.livePauseCTA,
            AppAccessibilityID.Action.insightsShareChart,
            AppAccessibilityID.Action.daysExportBar,
            AppAccessibilityID.Action.exportStepRoot,
        ]
        XCTAssertEqual(Set(all).count, all.count, "Action identifiers must be unique.")
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
            AppAccessibilityID.Action.homeImportPrimary,
            AppAccessibilityID.Action.exportPrimary,
            AppAccessibilityID.Action.livePauseCTA,
            AppAccessibilityID.Action.insightsShareChart,
            AppAccessibilityID.Action.daysExportBar,
            AppAccessibilityID.Action.exportStepRoot,
        ]
        for id in all {
            XCTAssertFalse(id.isEmpty, "Identifier '\(id)' must not be empty.")
            XCTAssertFalse(id.contains(" "), "Identifier '\(id)' must not contain whitespace.")
            XCTAssertFalse(id.contains("\n"), "Identifier '\(id)' must not contain newlines.")
        }
    }
}
