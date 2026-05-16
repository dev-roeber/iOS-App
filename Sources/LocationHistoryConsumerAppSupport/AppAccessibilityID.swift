import Foundation

/// Central namespace for SwiftUI `accessibilityIdentifier` constants.
///
/// **What lives here:** stable, static identifiers used as XCUITest hooks.
/// IDs are dot-namespaced (`<screen>.<element>` or
/// `<screen>.<section>.<element>`), all lowercase, no runtime data.
///
/// **What does NOT live here:** the existing 155 identifier literals
/// scattered across `Sources/.../*View.swift` (`home.*`, `days.*`,
/// `dayDetail.*`, `export.*`, `insights.*`, `live.*`, `localTimeline.*`,
/// `options.*`, `app.*`). Those keep their inline string literals to
/// avoid a churn refactor across ~20 files; this namespace is the
/// canonical home for **new** identifiers added in Train M and after.
///
/// Train M, Phase 2.
public enum AppAccessibilityID {

    // MARK: - Root container / Pre-production banner

    public enum Root {
        /// The TestFlight-only "Pre-production / Internal Test" banner
        /// rendered at the top of the app shell on Pre-Prod builds.
        public static let preProductionBanner = "root.preProductionBanner"
    }

    // MARK: - Compact / split tab bar

    public enum Tab {
        public static let overview = "tab.overview"
        public static let days     = "tab.days"
        public static let insights = "tab.insights"
        public static let export   = "tab.export"
        public static let live     = "tab.live"
    }

    // MARK: - Map surfaces (root views, not individual annotations)

    public enum Map {
        /// `AppOverviewTracksMapView` root container.
        public static let overviewRoot      = "map.overview.root"
        /// `AppHeatmapView` root container.
        public static let heatmapRoot       = "map.heatmap.root"
        /// `AppExportPreviewMapView` root container.
        public static let exportPreviewRoot = "map.exportPreview.root"
        /// `AppDayMapView` root container.
        public static let dayDetailRoot     = "map.dayDetail.root"
    }
}
