#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer
#if canImport(MapKit)
import MapKit
#endif

// MARK: - Date Formatting

private enum AppDateDisplay {
    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func longDate(_ iso: String) -> String {
        guard let d = isoFormatter.date(from: iso) else { return iso }
        return d.formatted(date: .long, time: .omitted)
    }

    static func mediumDate(_ iso: String) -> String {
        guard let d = isoFormatter.date(from: iso) else { return iso }
        return d.formatted(date: .abbreviated, time: .omitted)
    }

    static func weekday(_ iso: String) -> String {
        guard let d = isoFormatter.date(from: iso) else { return "" }
        return d.formatted(.dateTime.weekday(.wide))
    }
}

// MARK: - Time Formatting

private enum AppTimeDisplay {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    static func time(_ iso8601: String) -> String {
        guard let date = isoFormatter.date(from: iso8601) else { return iso8601 }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Main Split View

public struct AppContentSplitView: View {
    @Binding private var session: AppSessionState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isOverviewPushed = false

    public init(session: Binding<AppSessionState>) {
        self._session = session
    }

    public var body: some View {
        NavigationSplitView {
            AppDayListView(
                summaries: session.daySummaries,
                selectedDate: Binding(
                    get: { session.selectedDate },
                    set: { session.selectDay($0) }
                )
            )
            .navigationTitle("Days")
            #if os(iOS)
            .toolbar {
                if horizontalSizeClass == .compact {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isOverviewPushed = true
                        } label: {
                            Label("Overview", systemImage: "chart.bar.doc.horizontal")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }
            }
            #endif
            .navigationDestination(isPresented: $isOverviewPushed) {
                ScrollView {
                    overviewPaneContent
                        .padding()
                }
                .navigationTitle("Overview")
            }
        } detail: {
            detailPane
        }
        .task { resetForCompact() }
        .onChange(of: session.daySummaries) { _ in resetForCompact() }
    }

    private func resetForCompact() {
        guard horizontalSizeClass == .compact else { return }
        session.selectDay(nil)
    }

    @ViewBuilder
    private var overviewPaneContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            AppSessionStatusView(
                summary: session.sourceSummary,
                message: session.message,
                isLoading: session.isLoading,
                hasDays: session.hasDays
            )
            if let overview = session.overview {
                AppOverviewSection(overview: overview)
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let detail = session.selectedDetail {
            ScrollView {
                AppDayDetailView(
                        detail: detail,
                        hasDays: true,
                        onBackToOverview: horizontalSizeClass == .compact ? { session.selectDay(nil) } : nil
                    )
                    .padding()
            }
            .navigationTitle(AppDateDisplay.longDate(detail.date))
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    overviewPaneContent
                    if session.hasDays {
                        Label(
                            "Select a day from the list to view details.",
                            systemImage: "hand.tap"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Overview")
        }
    }
}

// MARK: - Session Status

public struct AppSessionStatusView: View {
    let summary: AppSourceSummary
    let message: AppUserMessage?
    let isLoading: Bool
    let hasDays: Bool

    public init(summary: AppSourceSummary, message: AppUserMessage?, isLoading: Bool, hasDays: Bool) {
        self.summary = summary
        self.message = message
        self.isLoading = isLoading
        self.hasDays = hasDays
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSourceSummaryCard(summary: summary)

            if let message, message.kind == .error {
                AppMessageCard(message: message)
            }

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !isLoading && !hasDays && summary.dayCountText != nil {
                Label(
                    "This export contains no day entries.",
                    systemImage: "calendar.badge.exclamationmark"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Source Summary Card

public struct AppSourceSummaryCard: View {
    let summary: AppSourceSummary

    public init(summary: AppSourceSummary) {
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary.stateTitle)
                .font(.headline)

            summaryRow("Source", value: summary.sourceValue, icon: "doc")

            if let v = summary.schemaVersion {
                summaryRow("Schema", value: v, icon: "number")
            }
            if let v = summary.inputFormat {
                summaryRow("Format", value: v, icon: "square.grid.2x2")
            }
            if let v = summary.exportedAt {
                summaryRow("Exported", value: v, icon: "clock")
            }
            if let v = summary.dayCountText {
                summaryRow("Days", value: v, icon: "calendar")
            }

            Text(summary.statusText)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func summaryRow(_ label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .center)
                .accessibilityHidden(true)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Message Card

public struct AppMessageCard: View {
    let message: AppUserMessage

    public init(message: AppUserMessage) {
        self.message = message
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(
                message.title,
                systemImage: message.kind == .error ? "exclamationmark.triangle" : "info.circle"
            )
            .font(.subheadline.weight(.semibold))
            Text(message.message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var backgroundColor: Color {
        switch message.kind {
        case .info: return Color.accentColor.opacity(0.12)
        case .error: return Color.red.opacity(0.12)
        }
    }
}

// MARK: - Overview Section

public struct AppOverviewSection: View {
    let overview: ExportOverview

    public init(overview: ExportOverview) {
        self.overview = overview
    }

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 160), spacing: 12)
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.title3.weight(.semibold))

            LazyVGrid(columns: columns, spacing: 12) {
                statCard("\(overview.dayCount)", label: "Days", icon: "calendar")
                statCard("\(overview.totalVisitCount)", label: "Visits", icon: "mappin.and.ellipse")
                statCard("\(overview.totalActivityCount)", label: "Activities", icon: "figure.walk")
                statCard("\(overview.totalPathCount)", label: "Paths", icon: "location.north.line")
            }

            if !overview.statsActivityTypes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Activity Types")
                        .font(.subheadline.weight(.medium))
                    Text(overview.statsActivityTypes.map { $0.capitalized }.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func statCard(_ value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Day List

public struct AppDayListView: View {
    let summaries: [DaySummary]
    @Binding var selectedDate: String?

    public init(summaries: [DaySummary], selectedDate: Binding<String?>) {
        self.summaries = summaries
        self._selectedDate = selectedDate
    }

    public var body: some View {
        if summaries.isEmpty {
            emptyDayList
        } else {
            List(summaries, id: \.date, selection: $selectedDate) { summary in
                dayRow(summary)
                    .tag(summary.date)
            }
        }
    }

    private var emptyDayList: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No Days")
                .font(.headline)
            Text("This export does not contain any day entries.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    @ViewBuilder
    private func dayRow(_ summary: DaySummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AppDateDisplay.weekday(summary.date))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(AppDateDisplay.mediumDate(summary.date))
                .font(.headline)
            HStack(spacing: 12) {
                Label("\(summary.visitCount)", systemImage: "mappin.and.ellipse")
                Label("\(summary.activityCount)", systemImage: "figure.walk")
                Label("\(summary.pathCount)", systemImage: "location.north.line")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(summary.visitCount) Visits, \(summary.activityCount) Activities, \(summary.pathCount) Paths")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Day Detail

public struct AppDayDetailView: View {
    let detail: DayDetailViewState?
    let hasDays: Bool
    let onBackToOverview: (() -> Void)?

    public init(detail: DayDetailViewState?, hasDays: Bool, onBackToOverview: (() -> Void)? = nil) {
        self.detail = detail
        self.hasDays = hasDays
        self.onBackToOverview = onBackToOverview
    }

    // Convenience init for use within the split view
    init(detail: DayDetailViewState) {
        self.detail = detail
        self.hasDays = true
        self.onBackToOverview = nil
    }

    public var body: some View {
        if let detail {
            if detail.hasContent {
                contentView(detail)
            } else {
                emptyDayState(
                    "No Content",
                    message: "This day exists in the export but contains no visits, activities or paths.",
                    recovery: onBackToOverview
                )
            }
        } else if hasDays {
            emptyDayState(
                "No Day Selected",
                message: "Choose a day from the list to view details."
            )
        } else {
            emptyDayState(
                "No Day Details",
                message: "Import a file with day entries to view details."
            )
        }
    }

    @ViewBuilder
    private func contentView(_ detail: DayDetailViewState) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppDateDisplay.weekday(detail.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(AppDateDisplay.longDate(detail.date))
                    .font(.title2.weight(.semibold))
            }

            #if canImport(MapKit)
            if #available(iOS 17.0, macOS 14.0, *) {
                AppDayMapView(mapData: DayMapDataExtractor.mapData(from: detail))
            }
            #endif

            HStack(spacing: 16) {
                quickStat("\(detail.visits.count)", label: "Visits", icon: "mappin.and.ellipse")
                quickStat("\(detail.activities.count)", label: "Activities", icon: "figure.walk")
                quickStat("\(detail.paths.count)", label: "Paths", icon: "location.north.line")
            }

            if !detail.visits.isEmpty {
                detailSection("Visits", icon: "mappin.and.ellipse", count: detail.visits.count) {
                    ForEach(Array(detail.visits.enumerated()), id: \.offset) { _, visit in
                        visitCard(visit)
                    }
                }
            }

            if !detail.activities.isEmpty {
                detailSection("Activities", icon: "figure.walk", count: detail.activities.count) {
                    ForEach(Array(detail.activities.enumerated()), id: \.offset) { _, activity in
                        activityCard(activity)
                    }
                }
            }

            if !detail.paths.isEmpty {
                detailSection("Paths", icon: "location.north.line", count: detail.paths.count) {
                    ForEach(Array(detail.paths.enumerated()), id: \.offset) { _, path in
                        pathCard(path)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func detailSection<Content: View>(
        _ title: String,
        icon: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                Spacer()
                Text("\(count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(count) \(title)")
            content()
        }
    }

    @ViewBuilder
    private func visitCard(_ visit: DayDetailViewState.VisitItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(visit.semanticType?.capitalized ?? "Visit")
                .font(.subheadline.weight(.medium))
            if let start = visit.startTime, let end = visit.endTime {
                Label("\(AppTimeDisplay.time(start)) – \(AppTimeDisplay.time(end))", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func activityCard(_ activity: DayDetailViewState.ActivityItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(activity.activityType?.capitalized ?? "Activity")
                .font(.subheadline.weight(.medium))
            HStack(spacing: 12) {
                if let start = activity.startTime, let end = activity.endTime {
                    Label("\(AppTimeDisplay.time(start)) – \(AppTimeDisplay.time(end))", systemImage: "clock")
                }
                if let dist = activity.distanceM {
                    Label(formatDistance(dist), systemImage: "ruler")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func pathCard(_ path: DayDetailViewState.PathItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(path.activityType?.capitalized ?? "Path")
                .font(.subheadline.weight(.medium))
            HStack(spacing: 12) {
                Label("\(path.pointCount) points", systemImage: "location.north.line")
                if let dist = path.distanceM {
                    Label(formatDistance(dist), systemImage: "ruler")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func quickStat(_ value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func formatDistance(_ meters: Double) -> String {
        guard meters >= 0, meters.isFinite else { return "–" }
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        return measurement.formatted(.measurement(width: .abbreviated, usage: .road))
    }

    @ViewBuilder
    private func emptyDayState(_ title: String, message: String, recovery: (() -> Void)? = nil) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let recovery {
                Button(action: recovery) {
                    Label("Back to Overview", systemImage: "chevron.backward")
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}
#endif
