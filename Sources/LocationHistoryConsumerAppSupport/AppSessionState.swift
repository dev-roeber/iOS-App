import Foundation
import LocationHistoryConsumer

/// Identifies where the currently loaded content originated.
public enum AppContentSource: Equatable {
    /// Bundled demo fixture loaded from the app bundle.
    case demoFixture(name: String)
    /// File imported by the user from the local file system.
    case importedFile(filename: String)

    public var displayName: String {
        switch self {
        case let .demoFixture(name):
            return "\(name).json"
        case let .importedFile(filename):
            return filename
        }
    }
}

/// The coarse UI state that drives which view the shell renders.
public enum AppSessionPresentationState: Equatable {
    /// No content loaded, no error. Initial state.
    case idle
    /// Import is in progress.
    case loading
    /// Demo fixture is active.
    case demoLoaded
    /// User-imported file is active.
    case importedLoaded
    /// Last import failed and no prior content is available.
    case failedWithoutContent
    /// Last import failed but prior content remains visible.
    case failedWithContent
}

public struct AppSourceSummary: Equatable {
    public let stateTitle: String
    public let sourceLabel: String
    public let sourceValue: String
    public let schemaVersion: String?
    public let inputFormat: String?
    public let exportedAt: String?
    public let dayCountText: String?
    public let statusText: String
}

public final class AppSessionContent {
    private struct ProjectionCacheKey: Hashable {
        let filter: AppExportQueryFilter?
    }

    private struct DayDetailCacheKey: Hashable {
        let date: String
        let filter: AppExportQueryFilter?
    }

    /// Deep Audit 2026-05-09 L-04 — alle Filter-/Projection-Caches sind ab
    /// jetzt durch `BoundedLRU` capped, statt unbounded `[Key: Value]` zu
    /// wachsen. Limits sind konservativ: realistische Filter-Variation in
    /// dieser App ist klein (eine Handvoll Date-Range-Presets gekreuzt mit
    /// wenigen Activity-Type-Toggles); 8 Einträge decken das ab. Day-/Map-
    /// Caches dürfen etwas größer sein, weil ein Tester durch viele Tage
    /// scrollen kann, ohne das Filter zu wechseln.
    private static let projectedDaysCacheLimit = 8
    private static let filteredProjectionCacheLimit = 8
    private static let dayDetailCacheLimit = 32
    private static let dayMapDataCacheLimit = 16

    public let export: AppExport
    public private(set) lazy var overview: ExportOverview = {
        AppExportQueries.overview(from: export, precomputedDays: cachedProjectedDays(for: nil))
    }()
    public private(set) lazy var daySummaries: [DaySummary] = {
        DaySummaryDisplayOrdering.newestFirst(
            AppExportQueries.daySummaries(from: export, precomputedDays: cachedProjectedDays(for: nil))
        )
    }()
    public private(set) lazy var insights: ExportInsights = {
        AppExportQueries.insights(
            from: export,
            precomputedDays: cachedProjectedDays(for: nil),
            resolvedFilter: AppExportQueries.resolvedFilter(nil, export: export)
        )
    }()
    public let selectedDate: String?
    public let source: AppContentSource
    private let filteredOverviewCache = BoundedLRU<ProjectionCacheKey, ExportOverview>(
        capacity: AppSessionContent.filteredProjectionCacheLimit
    )
    private let filteredDaySummariesCache = BoundedLRU<ProjectionCacheKey, [DaySummary]>(
        capacity: AppSessionContent.filteredProjectionCacheLimit
    )
    private let filteredInsightsCache = BoundedLRU<ProjectionCacheKey, ExportInsights>(
        capacity: AppSessionContent.filteredProjectionCacheLimit
    )
    private let dayDetailCache = BoundedLRU<DayDetailCacheKey, DayDetailViewState>(
        capacity: AppSessionContent.dayDetailCacheLimit
    )
    private let dayMapDataCache = BoundedLRU<DayDetailCacheKey, DayMapData>(
        capacity: AppSessionContent.dayMapDataCacheLimit
    )

    /// Cached `[Day]` projections shared across overview/daySummaries/insights/findDay
    /// for the same resolved filter. Keyed by the resolved (non-nil) filter so a
    /// `nil` caller and a caller that explicitly passes the export's default filter
    /// hit the same entry. LRU-Eviction über `BoundedLRU`.
    private let projectedDaysCache = BoundedLRU<AppExportQueryFilter, [Day]>(
        capacity: AppSessionContent.projectedDaysCacheLimit
    )

    public init(export: AppExport, source: AppContentSource) {
        self.export = export
        self.source = source

        // Pick selectedDate from the raw `Day` array directly. We deliberately
        // avoid building daySummaries / running `projectedDays` here: on a 65k
        // entry Google Timeline import the summaries pass allocates 80–130 MB
        // of intermediate arrays, which combined with the still-live importer
        // working set was the post-streaming memory peak that triggered Jetsam
        // on iPhone 15 Pro Max (2026-05-07 hardware fail).
        let days = export.data.days
        var newestContentful: String? = nil
        var newestAny: String? = nil
        for day in days {
            if newestAny == nil || day.date > newestAny! {
                newestAny = day.date
            }
            if !day.visits.isEmpty || !day.activities.isEmpty || !day.paths.isEmpty {
                if newestContentful == nil || day.date > newestContentful! {
                    newestContentful = day.date
                }
            }
        }
        self.selectedDate = newestContentful ?? newestAny
    }

    /// Returns the projected `[Day]` for the given filter, computing once per
    /// resolved filter and reusing the result across overview/daySummaries/
    /// insights/findDay. Bounded LRU keeps memory in check.
    private func cachedProjectedDays(for filter: AppExportQueryFilter?) -> [Day] {
        let resolved = AppExportQueries.resolvedFilter(filter, export: export)
        if let cached = projectedDaysCache.value(forKey: resolved) {
            return cached
        }
        let projected = AppExportQueries.projectedDays(in: export, applying: resolved)
        projectedDaysCache.insert(projected, forKey: resolved)
        return projected
    }

    public func overview(applying filter: AppExportQueryFilter?) -> ExportOverview {
        guard let filter else {
            return overview
        }

        let key = ProjectionCacheKey(filter: filter)
        if let cached = filteredOverviewCache.value(forKey: key) {
            return cached
        }

        let projected = AppExportQueries.overview(
            from: export,
            precomputedDays: cachedProjectedDays(for: filter)
        )
        filteredOverviewCache.insert(projected, forKey: key)
        return projected
    }

    public func daySummaries(applying filter: AppExportQueryFilter?) -> [DaySummary] {
        guard let filter else {
            return daySummaries
        }

        let key = ProjectionCacheKey(filter: filter)
        if let cached = filteredDaySummariesCache.value(forKey: key) {
            return cached
        }

        let projected = DaySummaryDisplayOrdering.newestFirst(
            AppExportQueries.daySummaries(
                from: export,
                precomputedDays: cachedProjectedDays(for: filter)
            )
        )
        filteredDaySummariesCache.insert(projected, forKey: key)
        return projected
    }

    public func insights(applying filter: AppExportQueryFilter?) -> ExportInsights {
        guard let filter else {
            return insights
        }

        let key = ProjectionCacheKey(filter: filter)
        if let cached = filteredInsightsCache.value(forKey: key) {
            return cached
        }

        let resolved = AppExportQueries.resolvedFilter(filter, export: export)
        let projected = AppExportQueries.insights(
            from: export,
            precomputedDays: cachedProjectedDays(for: resolved),
            resolvedFilter: resolved
        )
        filteredInsightsCache.insert(projected, forKey: key)
        return projected
    }

    public func detail(for date: String?, applying filter: AppExportQueryFilter? = nil) -> DayDetailViewState? {
        guard let date else {
            return nil
        }

        let key = DayDetailCacheKey(date: date, filter: filter)
        if let cached = dayDetailCache.value(forKey: key) {
            return cached
        }

        guard let detail = AppExportQueries.dayDetail(for: date, in: export, applying: filter) else {
            return nil
        }

        dayDetailCache.insert(detail, forKey: key)
        return detail
    }

    public func mapData(for date: String?, applying filter: AppExportQueryFilter? = nil) -> DayMapData? {
        guard let date else {
            return nil
        }

        let key = DayDetailCacheKey(date: date, filter: filter)
        if let cached = dayMapDataCache.value(forKey: key) {
            return cached
        }

        guard let detail = detail(for: date, applying: filter) else {
            return nil
        }

        let mapData = DayMapDataExtractor.mapData(from: detail)
        dayMapDataCache.insert(mapData, forKey: key)
        return mapData
    }
}

public enum AppMessageKind: Equatable {
    case info
    case error
}

public struct AppUserMessage: Equatable {
    public let kind: AppMessageKind
    public let title: String
    public let message: String

    public init(kind: AppMessageKind, title: String, message: String) {
        self.kind = kind
        self.title = title
        self.message = message
    }
}

/// Value-type state machine that drives the app shell UI.
///
/// Mutations are performed via the `mutating` helper methods (`beginLoading`,
/// `show(content:)`, `showFailure`, `clearContent`, `selectDay`). Views should
/// derive their display state from `presentationState` and the computed properties.
public struct AppSessionState {
    public private(set) var isLoading: Bool
    public private(set) var content: AppSessionContent?
    /// Phase-7A — feature-flagged Store-backed Session.
    /// Wird ausschließlich über `show(localTimeline:)` gesetzt, parallel zu
    /// `content`. **Kein** UI-Hook für DayList/Map/Heatmap; nur Banner/Title
    /// werden hieraus abgeleitet. `content` bleibt nil, solange dieser Pfad
    /// aktiv ist — die Legacy-Properties (`overview`, `daySummaries`, …)
    /// liefern weiterhin die bisherige Empty-Semantik ohne Crash.
    public private(set) var localTimelineSession: LocalTimelineSession?
    /// Phase-9B — getrennt vom Legacy-`selectedDate`. Hält die aktuell
    /// ausgewählte Store-Day-ID, solange `localTimelineSession != nil`.
    /// Wird beim Setzen einer neuen Session, beim Laden Legacy-Contents
    /// und in `clearContent` zurückgesetzt.
    public private(set) var selectedLocalTimelineDayId: String?
    public private(set) var selectedDate: String?
    public private(set) var message: AppUserMessage?
    /// App-wide export selection. Cleared automatically on new import or content clear.
    public var exportSelection: ExportSelectionState = ExportSelectionState()
    /// App-wide date range filter applied across Days, Insights and Export tabs.
    public var historyDateRangeFilter: HistoryDateRangeFilter = HistoryDateRangeFilter(preset: .last7Days)
    /// Active drilldown action originating from the Insights tab.
    /// Set when a user taps a drilldown target in Insights; cleared by the receiving tab.
    public var activeDrilldownFilter: InsightsDrilldownAction?

    public init(
        isLoading: Bool = false,
        content: AppSessionContent? = nil,
        selectedDate: String? = nil,
        message: AppUserMessage? = nil
    ) {
        self.isLoading = isLoading
        self.content = content
        self.selectedDate = selectedDate
        self.message = message
    }

    public var overview: ExportOverview? {
        content?.overview
    }

    public var insights: ExportInsights? {
        content?.insights
    }

    public var daySummaries: [DaySummary] {
        content?.daySummaries ?? []
    }

    public var selectedDetail: DayDetailViewState? {
        content?.detail(for: selectedDate)
    }

    public var source: AppContentSource? {
        content?.source
    }

    public var sourceDescription: String? {
        guard let source else {
            return nil
        }
        switch source {
        case let .demoFixture(name):
            // Show a friendly label for the default demo fixture instead of the
            // internal filename, which is confusing to users and App Store reviewers.
            let label = name == AppContentLoader.defaultDemoFixtureName
                ? "Bundled sample"
                : name
            return "Demo fixture: \(label)"
        case let .importedFile(filename):
            return "Imported file: \(filename)"
        }
    }

    public var hasLoadedContent: Bool {
        content != nil
    }

    public var hasDays: Bool {
        !daySummaries.isEmpty
    }

    public var presentationState: AppSessionPresentationState {
        if isLoading {
            return .loading
        }
        if hasLoadedContent, message?.kind == .error {
            return .failedWithContent
        }
        if hasLoadedContent {
            switch source {
            case .demoFixture:
                return .demoLoaded
            case .importedFile:
                return .importedLoaded
            case nil:
                return .idle
            }
        }
        if message?.kind == .error {
            return .failedWithoutContent
        }
        return .idle
    }

    public var sourceSummary: AppSourceSummary {
        let overview = self.overview
        let dayCountText = overview.map { "\($0.dayCount) days" }

        switch presentationState {
        case .idle:
            return AppSourceSummary(
                stateTitle: "No location history loaded",
                sourceLabel: "Active Source",
                sourceValue: "None",
                schemaVersion: nil,
                inputFormat: nil,
                exportedAt: nil,
                dayCountText: nil,
                statusText: message?.message ?? "Open an LH2GPX app_export.json or .zip from the LocationHistory2GPX tool, or a Google Timeline location-history.json or .zip. Demo data is available as a fallback."
            )
        case .loading:
            return AppSourceSummary(
                stateTitle: "Opening location history",
                sourceLabel: "Active Source",
                sourceValue: sourceDescription ?? "Pending",
                schemaVersion: overview?.schemaVersion,
                inputFormat: displayInputFormat(overview?.inputFormat),
                exportedAt: overview?.exportedAt,
                dayCountText: dayCountText,
                statusText: "Processing location history data."
            )
        case .demoLoaded:
            return AppSourceSummary(
                stateTitle: "Demo data loaded",
                sourceLabel: "Active Source",
                sourceValue: sourceDescription ?? "Demo fixture",
                schemaVersion: overview?.schemaVersion,
                inputFormat: displayInputFormat(overview?.inputFormat),
                exportedAt: overview?.exportedAt,
                dayCountText: dayCountText,
                statusText: hasDays
                    ? "Bundled demo data is active. Open a local location history file to replace it."
                    : "Bundled demo data decoded successfully but does not contain any day entries."
            )
        case .importedLoaded:
            let isGoogleTimeline = overview?.inputFormat == "google_timeline"
            return AppSourceSummary(
                stateTitle: isGoogleTimeline ? "Google Timeline loaded" : "Location history loaded",
                sourceLabel: "Active Source",
                sourceValue: sourceDescription ?? "Imported file",
                schemaVersion: overview?.schemaVersion,
                inputFormat: displayInputFormat(overview?.inputFormat),
                exportedAt: overview?.exportedAt,
                dayCountText: dayCountText,
                statusText: hasDays
                    ? "Local file content is active. Open another file to replace it."
                    : "The file was decoded successfully but does not contain any day entries."
            )
        case .failedWithoutContent:
            return AppSourceSummary(
                stateTitle: message?.title ?? "Unable to open location history",
                sourceLabel: "Active Source",
                sourceValue: "None",
                schemaVersion: nil,
                inputFormat: nil,
                exportedAt: nil,
                dayCountText: nil,
                statusText: "No location history is currently active. Open a local location history file or load demo data."
            )
        case .failedWithContent:
            return AppSourceSummary(
                stateTitle: message?.title ?? "Last loaded content remains visible",
                sourceLabel: "Active Source",
                sourceValue: sourceDescription ?? "Current content",
                schemaVersion: overview?.schemaVersion,
                inputFormat: displayInputFormat(overview?.inputFormat),
                exportedAt: overview?.exportedAt,
                dayCountText: dayCountText,
                statusText: "The last successfully loaded content remains visible. Open another file to replace it or Clear to reset."
            )
        }
    }

    private func displayInputFormat(_ raw: String?) -> String? {
        guard let raw else { return nil }
        switch raw {
        case "google_timeline": return "Google Timeline"
        default: return raw
        }
    }

    public mutating func beginLoading() {
        isLoading = true
        message = nil
        activeDrilldownFilter = nil
    }

    /// Phase-7A — aktive Session aus dem feature-flagged
    /// `LocalTimelineStore`-Pfad annehmen. Setzt **keine**
    /// `AppSessionContent`/`AppExport`-Materialisierung an, triggert keine
    /// Lazy-Property-Auswertung und führt keine Koordinaten-Decodierung aus.
    /// `content` wird bewusst geleert: der bisherige In-Memory-Pfad und der
    /// Store-Pfad sind im selben State niemals beide aktiv.
    public mutating func show(localTimeline session: LocalTimelineSession) {
        ImportMemoryProbe.log("session.beforeShowLocalTimeline")
        self.content = nil
        self.localTimelineSession = session
        selectedDate = nil
        selectedLocalTimelineDayId = nil
        exportSelection.clearAll()
        activeDrilldownFilter = nil
        historyDateRangeFilter = HistoryDateRangeFilter(preset: .last7Days)
        isLoading = false
        message = AppUserMessage(
            kind: .info,
            title: "Google Timeline loaded",
            message: "Imported file: \(session.sourceFilename)"
        )
        ImportMemoryProbe.log("session.afterShowLocalTimeline")
    }

    public mutating func show(content: AppSessionContent) {
        ImportMemoryProbe.log("session.beforeShowContent")
        self.content = content
        self.localTimelineSession = nil
        selectedLocalTimelineDayId = nil
        selectedDate = content.selectedDate
        exportSelection.clearAll()
        activeDrilldownFilter = nil
        // Reset to the standard initial time window on every new import so the
        // overview starts with a manageable, recent slice of data by default.
        historyDateRangeFilter = HistoryDateRangeFilter(preset: .last7Days)
        isLoading = false
        let title: String
        if content.source == .demoFixture(name: AppContentLoader.defaultDemoFixtureName) {
            title = "Demo data ready"
        } else if content.export.meta.source.inputFormat == "google_timeline"
                    || content.export.meta.config.inputFormat == "google_timeline" {
            // Read inputFormat directly from meta so we don't trigger lazy
            // `overview` materialisation (a full projectedDays pass) just to
            // pick a localized title — this was part of the post-stream peak
            // that Jetsam-killed the app on iPhone 15 Pro Max (2026-05-07).
            title = "Google Timeline loaded"
        } else {
            title = "Location history ready"
        }
        message = AppUserMessage(
            kind: .info,
            title: title,
            message: sourceDescription ?? content.source.displayName
        )
        ImportMemoryProbe.log("session.afterShowContent")
    }

    public mutating func selectDay(_ date: String?) {
        guard let date else {
            selectedDate = nil
            return
        }

        if daySummaries.contains(where: { $0.date == date }) {
            selectedDate = date
        } else {
            selectedDate = daySummaries.first?.date
        }
    }

    /// UI-safe day selection: prefers contentful days and drops selections that
    /// would only lead into an empty detail state.
    public mutating func selectDayForDisplay(_ date: String?) {
        guard let date else {
            selectedDate = nil
            return
        }

        if let summary = daySummaries.first(where: { $0.date == date }) {
            selectedDate = summary.hasContent ? summary.date : nil
            return
        }

        selectedDate = daySummaries.first(where: \.hasContent)?.date ?? daySummaries.first?.date
        sanitizeSelectionIfContentEmpty()
    }

    public mutating func showFailure(title: String, message: String, preserveCurrentContent: Bool) {
        isLoading = false
        self.message = AppUserMessage(kind: .error, title: title, message: message)
        if !preserveCurrentContent {
            content = nil
            selectedDate = nil
        }
    }

    /// Clears selectedDate if the currently selected day has no content.
    /// Call this on compact width to prevent dead-end navigation to empty detail screens.
    public mutating func sanitizeSelectionIfContentEmpty() {
        guard let detail = selectedDetail, !detail.hasContent else { return }
        selectedDate = nil
    }

    /// Phase-9B — Store-Day-Auswahl. Akzeptiert nur, wenn eine
    /// `localTimelineSession` aktiv ist; ohne Store-Session bleibt das Feld
    /// nil. `nil` als Eingabe deselektiert explizit.
    public mutating func selectLocalTimelineDay(_ dayId: String?) {
        guard localTimelineSession != nil else {
            selectedLocalTimelineDayId = nil
            return
        }
        selectedLocalTimelineDayId = dayId
    }

    public mutating func clearContent() {
        isLoading = false
        content = nil
        localTimelineSession = nil
        selectedLocalTimelineDayId = nil
        selectedDate = nil
        exportSelection.clearAll()
        activeDrilldownFilter = nil
        message = AppUserMessage(
            kind: .info,
            title: "No location history loaded",
            message: "Open a local location history file or load the bundled demo data."
        )
    }
}
