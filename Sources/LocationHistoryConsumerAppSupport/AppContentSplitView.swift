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

    static func monthYear(_ iso: String) -> String {
        guard let d = isoFormatter.date(from: iso) else { return String(iso.prefix(7)) }
        return d.formatted(.dateTime.month(.wide).year())
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

// MARK: - Card Accent Colors

private enum CardAccent {
    static let visit = Color.blue
    static let activity = Color.green
    static let path = Color.orange
}

// MARK: - Distance Formatting

private func formatDistance(_ meters: Double) -> String {
    guard meters >= 0, meters.isFinite else { return "–" }
    let measurement = Measurement(value: meters, unit: UnitLength.meters)
    return measurement.formatted(.measurement(width: .abbreviated, usage: .road))
}

// MARK: - Month Grouping

private struct MonthGroup: Identifiable {
    let key: String
    let title: String
    let summaries: [DaySummary]
    var id: String { key }
}

private func groupByMonth(_ summaries: [DaySummary]) -> [MonthGroup] {
    var groups: [(key: String, summaries: [DaySummary])] = []
    var currentKey: String?
    var currentSummaries: [DaySummary] = []

    for summary in summaries {
        let key = String(summary.date.prefix(7))
        if key != currentKey {
            if let prevKey = currentKey {
                groups.append((key: prevKey, summaries: currentSummaries))
            }
            currentKey = key
            currentSummaries = [summary]
        } else {
            currentSummaries.append(summary)
        }
    }
    if let prevKey = currentKey {
        groups.append((key: prevKey, summaries: currentSummaries))
    }

    return groups.map { group in
        MonthGroup(
            key: group.key,
            title: AppDateDisplay.monthYear(group.summaries[0].date),
            summaries: group.summaries
        )
    }
}

// MARK: - Main Content View (Adaptive Layout)

public struct AppContentSplitView: View {
    @Binding private var session: AppSessionState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var daysNavigationPath = NavigationPath()

    private let onOpen: () -> Void
    private let onLoadDemo: () -> Void
    private let onClear: () -> Void

    public init(
        session: Binding<AppSessionState>,
        onOpen: @escaping () -> Void = {},
        onLoadDemo: @escaping () -> Void = {},
        onClear: @escaping () -> Void = {}
    ) {
        self._session = session
        self.onOpen = onOpen
        self.onLoadDemo = onLoadDemo
        self.onClear = onClear
    }

    public var body: some View {
        if horizontalSizeClass == .compact {
            compactTabView
        } else {
            regularSplitView
        }
    }

    // MARK: - Compact (iPhone) Tab View

    private var compactTabView: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    overviewPaneContent
                        .padding()
                }
                .navigationTitle("Overview")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        actionsMenu
                    }
                }
            }
            .tabItem {
                Label("Overview", systemImage: "chart.bar.doc.horizontal")
            }

            NavigationStack(path: $daysNavigationPath) {
                compactDayList
                    .navigationTitle("Days")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            actionsMenu
                        }
                    }
                    .navigationDestination(for: String.self) { date in
                        ScrollView {
                            AppDayDetailView(
                                detail: session.content?.detail(for: date),
                                hasDays: true
                            )
                            .padding()
                        }
                        .navigationTitle(AppDateDisplay.longDate(date))
                    }
            }
            .tabItem {
                Label("Days", systemImage: "calendar")
            }

            NavigationStack {
                ScrollView {
                    insightsPaneContent
                        .padding()
                }
                .navigationTitle("Insights")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        actionsMenu
                    }
                }
            }
            .tabItem {
                Label("Insights", systemImage: "chart.xyaxis.line")
            }
        }
        .onChange(of: session.daySummaries) { _ in
            daysNavigationPath = NavigationPath()
        }
    }

    @ViewBuilder
    private var compactDayList: some View {
        let groups = groupByMonth(session.daySummaries)
        if session.daySummaries.isEmpty {
            AppDayListEmptyView()
        } else if groups.count == 1 {
            List {
                ForEach(groups[0].summaries, id: \.date) { summary in
                    NavigationLink(value: summary.date) {
                        AppDayRow(summary: summary)
                    }
                }
            }
        } else {
            List {
                ForEach(groups) { group in
                    Section(group.title) {
                        ForEach(group.summaries, id: \.date) { summary in
                            NavigationLink(value: summary.date) {
                                AppDayRow(summary: summary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Regular (iPad) Split View

    private var regularSplitView: some View {
        NavigationSplitView {
            AppDayListView(
                summaries: session.daySummaries,
                selectedDate: Binding(
                    get: { session.selectedDate },
                    set: { session.selectDay($0) }
                )
            )
            .navigationTitle("Days")
        } detail: {
            Group {
                detailPane
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    actionsMenu
                }
            }
        }
    }

    // MARK: - Shared Content

    @ViewBuilder
    private var overviewPaneContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let range = session.insights?.dateRange {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                    Text("\(AppDateDisplay.mediumDate(range.firstDate)) – \(AppDateDisplay.mediumDate(range.lastDate))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let insights = session.insights, insights.totalDistanceM > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "road.lanes")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Distance")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatDistance(insights.totalDistanceM))
                            .font(.title3.weight(.semibold))
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if let insights = session.insights {
                overviewHighlights(insights)
            }

            if let overview = session.overview {
                AppOverviewSection(overview: overview)
            }

            if let insights = session.insights, !insights.activeFilterDescriptions.isEmpty {
                activeFiltersSection(insights.activeFilterDescriptions)
            }

            AppSessionStatusView(
                summary: session.sourceSummary,
                message: session.message,
                isLoading: session.isLoading,
                hasDays: session.hasDays
            )
        }
    }

    @ViewBuilder
    private func overviewHighlights(_ insights: ExportInsights) -> some View {
        let hasHighlights = insights.busiestDay != nil || insights.longestDistanceDay != nil
        if hasHighlights {
            VStack(alignment: .leading, spacing: 12) {
                Text("Highlights")
                    .font(.title3.weight(.semibold))
                HStack(spacing: 12) {
                    if let busiest = insights.busiestDay {
                        highlightCard(
                            title: "Busiest Day",
                            value: busiest.value,
                            date: AppDateDisplay.mediumDate(busiest.date),
                            icon: "flame.fill",
                            color: .orange
                        )
                    }
                    if let longest = insights.longestDistanceDay {
                        highlightCard(
                            title: "Longest Distance",
                            value: longest.value,
                            date: AppDateDisplay.mediumDate(longest.date),
                            icon: "road.lanes",
                            color: .purple
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func highlightCard(title: String, value: String, date: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.headline.monospacedDigit())
            Text(date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value), \(date)")
    }

    @ViewBuilder
    private func activeFiltersSection(_ filters: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Filtered Export", systemImage: "line.3.horizontal.decrease.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.orange)
            Text(filters.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var insightsPaneContent: some View {
        if let insights = session.insights {
            AppInsightsContentView(insights: insights)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No Insights Available")
                    .font(.headline)
                Text("Load an app export to see detailed insights.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let detail = session.selectedDetail {
            ScrollView {
                AppDayDetailView(
                    detail: detail,
                    hasDays: true,
                    onBackToOverview: { session.selectDay(nil) }
                )
                .padding()
            }
            .navigationTitle(AppDateDisplay.longDate(detail.date))
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    overviewPaneContent
                    insightsPaneContent
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

    // MARK: - Actions Menu

    @ViewBuilder
    private var actionsMenu: some View {
        Menu {
            Button {
                onOpen()
            } label: {
                Label(openButtonTitle, systemImage: "doc.badge.plus")
            }
            Button(action: onLoadDemo) {
                Label(demoButtonTitle, systemImage: "testtube.2")
            }
            if session.hasLoadedContent || session.message?.kind == .error {
                Divider()
                Button(role: .destructive, action: onClear) {
                    Label("Clear", systemImage: "xmark.circle")
                }
            }
        } label: {
            Label("Actions", systemImage: "ellipsis.circle")
        }
    }

    private var openButtonTitle: String {
        session.hasLoadedContent ? "Open Another File" : "Open app_export.json"
    }

    private var demoButtonTitle: String {
        session.source == .demoFixture(name: AppContentLoader.defaultDemoFixtureName)
            ? "Reload Demo" : "Demo Data"
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
                statCard("\(overview.dayCount)", label: "Days", icon: "calendar", color: .blue)
                statCard("\(overview.totalVisitCount)", label: "Visits", icon: "mappin.and.ellipse", color: .purple)
                statCard("\(overview.totalActivityCount)", label: "Activities", icon: "figure.walk", color: .green)
                statCard("\(overview.totalPathCount)", label: "Paths", icon: "location.north.line", color: .orange)
            }

        }
    }

    @ViewBuilder
    private func statCard(_ value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
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
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Day Row

private struct AppDayRow: View {
    let summary: DaySummary

    var body: some View {
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
                if summary.totalPathDistanceM > 0 {
                    Label(formatDistance(summary.totalPathDistanceM), systemImage: "ruler")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(summary.visitCount) Visits, \(summary.activityCount) Activities, \(summary.pathCount) Paths")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Day List (Selection-based, for regular layout)

public struct AppDayListView: View {
    let summaries: [DaySummary]
    @Binding var selectedDate: String?

    public init(summaries: [DaySummary], selectedDate: Binding<String?>) {
        self.summaries = summaries
        self._selectedDate = selectedDate
    }

    public var body: some View {
        if summaries.isEmpty {
            AppDayListEmptyView()
        } else {
            let groups = groupByMonth(summaries)
            if groups.count == 1 {
                List(summaries, id: \.date, selection: $selectedDate) { summary in
                    AppDayRow(summary: summary)
                        .tag(summary.date)
                }
            } else {
                List(selection: $selectedDate) {
                    ForEach(groups) { group in
                        Section(group.title) {
                            ForEach(group.summaries, id: \.date) { summary in
                                AppDayRow(summary: summary)
                                    .tag(summary.date)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Day List Empty

private struct AppDayListEmptyView: View {
    var body: some View {
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
}

// MARK: - Colored Card Helper

@ViewBuilder
private func coloredCard<Content: View>(
    color: Color,
    @ViewBuilder content: () -> Content
) -> some View {
    HStack(spacing: 0) {
        color
            .frame(width: 4)
        VStack(alignment: .leading, spacing: 4) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.06))
    }
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
}

// MARK: - Icon Helpers

private func iconForVisitType(_ type: String?) -> String {
    switch (type ?? "").uppercased() {
    case "HOME": return "house.fill"
    case "WORK": return "briefcase.fill"
    case "CAFE": return "cup.and.saucer.fill"
    case "PARK": return "leaf.fill"
    case "LEISURE": return "gamecontroller.fill"
    case "EVENT": return "star.fill"
    case "STAY": return "bed.double.fill"
    default: return "mappin"
    }
}

private func iconForActivityType(_ type: String?) -> String {
    switch (type ?? "").uppercased() {
    case "WALKING": return "figure.walk"
    case "CYCLING": return "bicycle"
    case "IN PASSENGER VEHICLE": return "car.fill"
    case "IN BUS": return "bus.fill"
    case "RUNNING": return "figure.run"
    case "IN TRAIN": return "tram.fill"
    case "IN SUBWAY": return "tram.fill"
    case "FLYING": return "airplane"
    default: return "figure.walk"
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
                dayTimeRange(detail)
            }

            #if canImport(MapKit)
            if #available(iOS 17.0, macOS 14.0, *) {
                AppDayMapView(mapData: DayMapDataExtractor.mapData(from: detail))
            }
            #endif

            let dayDistance = detail.paths.reduce(0.0) { $0 + ($1.distanceM ?? 0) }
            HStack(spacing: 12) {
                quickStat("\(detail.visits.count)", label: "Visits", icon: "mappin.and.ellipse", color: .blue)
                quickStat("\(detail.activities.count)", label: "Activities", icon: "figure.walk", color: .green)
                quickStat("\(detail.paths.count)", label: "Paths", icon: "location.north.line", color: .orange)
                if dayDistance > 0 {
                    quickStat(formatDistance(dayDistance), label: "Distance", icon: "road.lanes", color: .purple)
                }
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
        coloredCard(color: CardAccent.visit) {
            HStack(spacing: 6) {
                Image(systemName: iconForVisitType(visit.semanticType))
                    .foregroundColor(CardAccent.visit)
                    .font(.subheadline)
                Text(visit.semanticType?.capitalized ?? "Visit")
                    .font(.subheadline.weight(.medium))
            }
            if let start = visit.startTime, let end = visit.endTime {
                Label("\(AppTimeDisplay.time(start)) – \(AppTimeDisplay.time(end))", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func activityCard(_ activity: DayDetailViewState.ActivityItem) -> some View {
        coloredCard(color: CardAccent.activity) {
            HStack(spacing: 6) {
                Image(systemName: iconForActivityType(activity.activityType))
                    .foregroundColor(CardAccent.activity)
                    .font(.subheadline)
                Text(activity.activityType?.capitalized ?? "Activity")
                    .font(.subheadline.weight(.medium))
            }
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
    }

    @ViewBuilder
    private func pathCard(_ path: DayDetailViewState.PathItem) -> some View {
        coloredCard(color: CardAccent.path) {
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
    }

    @ViewBuilder
    private func quickStat(_ value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
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
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func dayTimeRange(_ detail: DayDetailViewState) -> some View {
        let allStarts = detail.visits.compactMap(\.startTime) + detail.activities.compactMap(\.startTime) + detail.paths.compactMap(\.startTime)
        let allEnds = detail.visits.compactMap(\.endTime) + detail.activities.compactMap(\.endTime) + detail.paths.compactMap(\.endTime)
        let earliest = allStarts.min()
        let latest = allEnds.max()
        if let earliest, let latest {
            Label("\(AppTimeDisplay.time(earliest)) – \(AppTimeDisplay.time(latest))", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
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


// MARK: - Insights Content View

private struct AppInsightsContentView: View {
    let insights: ExportInsights

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Daily Averages
            insightSection("Daily Averages", icon: "chart.bar.fill") {
                let avg = insights.averagesPerDay
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    avgCard(String(format: "%.1f", avg.avgVisitsPerDay), label: "Visits / Day", icon: "mappin.and.ellipse", color: .blue)
                    avgCard(String(format: "%.1f", avg.avgActivitiesPerDay), label: "Activities / Day", icon: "figure.walk", color: .green)
                    avgCard(String(format: "%.1f", avg.avgPathsPerDay), label: "Paths / Day", icon: "location.north.line", color: .orange)
                    avgCard(formatDistance(avg.avgDistancePerDayM), label: "Distance / Day", icon: "road.lanes", color: .purple)
                }
            }

            // Activity Types
            if !insights.activityBreakdown.isEmpty {
                insightSection("Activity Types", icon: "figure.walk") {
                    ForEach(Array(insights.activityBreakdown.enumerated()), id: \.offset) { _, item in
                        activityBreakdownCard(item)
                    }
                }
            }

            // Visit Types
            if !insights.visitTypeBreakdown.isEmpty {
                insightSection("Visit Types", icon: "mappin.and.ellipse") {
                    ForEach(Array(insights.visitTypeBreakdown.enumerated()), id: \.offset) { _, item in
                        visitTypeRow(item)
                    }
                }
            }

            // Period Breakdown
            if !insights.periodBreakdown.isEmpty {
                insightSection("Period Breakdown", icon: "calendar.badge.clock") {
                    ForEach(Array(insights.periodBreakdown.enumerated()), id: \.offset) { _, item in
                        periodRow(item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func insightSection<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.title3.weight(.semibold))
            content()
        }
    }

    @ViewBuilder
    private func avgCard(_ value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.monospacedDigit())
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func activityBreakdownCard(_ item: ActivityBreakdownItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.activityType.capitalized)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(item.count)×")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
            HStack(spacing: 16) {
                if item.totalDistanceKM > 0 {
                    Label(String(format: "%.1f km", item.totalDistanceKM), systemImage: "ruler")
                }
                if item.totalDurationH > 0 {
                    Label(formatDuration(item.totalDurationH), systemImage: "clock")
                }
                if item.avgSpeedKMH > 0 {
                    Label(String(format: "%.1f km/h", item.avgSpeedKMH), systemImage: "speedometer")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func visitTypeRow(_ item: VisitTypeItem) -> some View {
        HStack {
            Image(systemName: iconForVisitType(item.semanticType))
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(item.semanticType.capitalized)
                .font(.subheadline)
            Spacer()
            Text("\(item.count)")
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func periodRow(_ item: PeriodBreakdownItem) -> some View {
        let periodColor = item.distanceM > 0 ? Color.purple : Color.secondary
        VStack(alignment: .leading, spacing: 6) {
            Text(item.label)
                .font(.subheadline.weight(.medium))
            HStack(spacing: 16) {
                Label("\(item.days) days", systemImage: "calendar")
                Label("\(item.visits) visits", systemImage: "mappin.and.ellipse")
                if item.distanceM > 0 {
                    Label(formatDistance(item.distanceM), systemImage: "ruler")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(periodColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func formatDuration(_ hours: Double) -> String {
        if hours < 1 {
            return String(format: "%.0f min", hours * 60)
        }
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

}
#endif