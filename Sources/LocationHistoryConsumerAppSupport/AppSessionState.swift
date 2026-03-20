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
    public let export: AppExport
    public private(set) lazy var overview: ExportOverview = {
        AppExportQueries.overview(from: export)
    }()
    public private(set) lazy var daySummaries: [DaySummary] = {
        AppExportQueries.daySummaries(from: export)
    }()
    public private(set) lazy var insights: ExportInsights = {
        AppExportQueries.insights(from: export)
    }()
    public let selectedDate: String?
    public let source: AppContentSource

    public init(export: AppExport, source: AppContentSource) {
        self.export = export
        self.source = source
        
        // Eagerly compute selectedDate based on first contentful day or fallback to first day.
        let summaries = AppExportQueries.daySummaries(from: export)
        self.selectedDate = summaries.first(where: \.hasContent)?.date ?? summaries.first?.date
        
        // Now that all non-lazy stored properties are initialized, we can populate the lazy storage.
        self.daySummaries = summaries
    }

    public func detail(for date: String?) -> DayDetailViewState? {
        guard let date else {
            return nil
        }
        return AppExportQueries.dayDetail(for: date, in: export)
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
    public private(set) var selectedDate: String?
    public private(set) var message: AppUserMessage?
    /// App-wide export selection. Cleared automatically on new import or content clear.
    public var exportSelection: ExportSelectionState = ExportSelectionState()

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
            return "Demo fixture: \(name).json"
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
    }

    public mutating func show(content: AppSessionContent) {
        self.content = content
        selectedDate = content.selectedDate
        exportSelection.clearAll()
        isLoading = false
        let title: String
        if content.source == .demoFixture(name: AppContentLoader.defaultDemoFixtureName) {
            title = "Demo data ready"
        } else if content.overview.inputFormat == "google_timeline" {
            title = "Google Timeline loaded"
        } else {
            title = "Location history ready"
        }
        message = AppUserMessage(
            kind: .info,
            title: title,
            message: sourceDescription ?? content.source.displayName
        )
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

    public mutating func clearContent() {
        isLoading = false
        content = nil
        selectedDate = nil
        exportSelection.clearAll()
        message = AppUserMessage(
            kind: .info,
            title: "No location history loaded",
            message: "Open a local location history file or load the bundled demo data."
        )
    }
}
