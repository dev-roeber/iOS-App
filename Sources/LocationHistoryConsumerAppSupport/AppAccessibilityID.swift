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
        /// rendered by `LocalTimelineTestModeBanner` at the top of the
        /// app shell whenever the local-timeline feature flag is active.
        /// The string matches the existing inline identifier on that
        /// view to avoid a churn rename.
        public static let preProductionBanner = "localTimeline.testMode.banner"
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

    // MARK: - Product info tiles (Train P)

    /// Identifier hooks for the three Train-O / Train-P info tiles
    /// (`ImportValidationSummaryPresentation`,
    /// `ExportFormatGuidancePresentation`,
    /// `RouteQualitySummaryPresentation`). UI integration ships in a
    /// follow-up; the namespace fixes the canonical strings now so
    /// XCUITest call-sites and Apple-side wiring can refer to them.
    public enum ProductInfo {
        // Import summary tile
        public static let importSummaryRoot     = "productInfo.importSummary.root"
        public static let importSummaryTitle    = "productInfo.importSummary.title"
        public static let importSummaryRange    = "productInfo.importSummary.range"
        public static let importSummaryCounts   = "productInfo.importSummary.counts"
        public static let importSummaryWarning  = "productInfo.importSummary.warning"

        // Export format guidance tile
        public static let exportGuidanceRoot       = "productInfo.exportGuidance.root"
        public static let exportGuidanceTitle      = "productInfo.exportGuidance.title"
        public static let exportGuidancePrimaryUse = "productInfo.exportGuidance.primaryUse"
        public static let exportGuidanceTools      = "productInfo.exportGuidance.tools"
        public static let exportGuidanceStrength   = "productInfo.exportGuidance.strength"

        // Export selection summary tile (Train R)
        public static let exportSelectionRoot   = "productInfo.exportSelection.root"
        public static let exportSelectionTitle  = "productInfo.exportSelection.title"
        public static let exportSelectionDetail = "productInfo.exportSelection.detail"

        // Route quality tile
        public static let routeQualityRoot       = "productInfo.routeQuality.root"
        public static let routeQualityLevel      = "productInfo.routeQuality.level"
        public static let routeQualityHint       = "productInfo.routeQuality.hint"
        public static let routeQualitySpacing    = "productInfo.routeQuality.spacing"
        public static let routeQualityLargestGap = "productInfo.routeQuality.largestGap"
    }

    // MARK: - Action controls (Train O, Phase 9)
    //
    // These constants are aliases that mirror existing inline identifier
    // literals used by user-facing action buttons so XCUITest call-sites
    // can refer to them through the central namespace without forcing a
    // churn rename of the view files. The right-hand-side string is the
    // canonical inline value — keep both in lockstep.

    public enum Action {
        /// Home-tab primary "Choose file…" / import button.
        public static let homeImportPrimary    = "home.import.primary"
        /// Export-flow primary CTA at the bottom of the export sheet.
        public static let exportPrimary        = "export.primaryButton"
        /// Live-tracking "Pause recording" button on the recording screen.
        public static let livePauseCTA         = "live.cta.pause"
        /// Insights chart-share affordance (per-card share button is
        /// `insights.share.<rawValue>`, this is the surface-level one).
        public static let insightsShareChart   = "insights.share.chart"
        /// Days list "Edit export bar" surface (multi-select selection bar).
        public static let daysExportBar        = "days.exportBar"
        /// Export step indicator (one entry per Step.allCases via
        /// `export.step.<accessibilityID>`; this constant is the surface
        /// alias for the indicator root used by the four-step UI.
        public static let exportStepRoot       = "export.step.root"
    }
}
