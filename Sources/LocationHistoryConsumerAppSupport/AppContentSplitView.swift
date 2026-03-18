#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer
#if canImport(Charts)
import Charts
#endif
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
        guard let d = isoFormatter.date(from: iso) else { return iso }
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
    @State private var selectedTab = 0
    @State private var daySearchText = ""

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

    private var filteredDaySummaries: [DaySummary] {
        guard !daySearchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return session.daySummaries
        }
        return session.daySummaries.filter { $0.date.localizedCaseInsensitiveContains(daySearchText) }
    }

    private func highlightIconsFor(_ date: String) -> [String] {
        var icons: [String] = []
        if session.insights?.busiestDay?.date == date { icons.append("flame.fill") }
        if session.insights?.longestDistanceDay?.date == date { icons.append("road.lanes") }
        return icons
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
        TabView(selection: $selectedTab) {
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
            .tag(0)

            NavigationStack(path: $daysNavigationPath) {
                compactDayList
                    .navigationTitle("Days")
                    .searchable(text: $daySearchText, prompt: "Search by date")
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
            .tag(1)

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
            .tag(2)
        }
        // Replaces deprecated onChange(of:perform:) — task(id:) fires on
        // appearance and whenever id changes, which is the same behaviour.
        .task(id: session.daySummaries) {
            daysNavigationPath = NavigationPath()
            daySearchText = ""
        }
    }

    private var compactDayList: some View {
        let summaries = filteredDaySummaries
        let groups = groupByMonth(summaries)
        return List {
            if groups.count == 1 {
                ForEach(groups[0].summaries, id: \.date) { summary in
                    NavigationLink(value: summary.date) {
                        AppDayRow(summary: summary, highlightIcons: highlightIconsFor(summary.date))
                    }
                }
            } else {
                ForEach(groups) { group in
                    Section(group.title) {
                        ForEach(group.summaries, id: \.date) { summary in
                            NavigationLink(value: summary.date) {
                                AppDayRow(summary: summary, highlightIcons: highlightIconsFor(summary.date))
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if session.daySummaries.isEmpty {
                AppDayListEmptyView()
            } else if summaries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("No Results")
                        .font(.headline)
                    Text("No days match \"\(daySearchText)\".")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
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
                AppOverviewSection(
                    overview: overview,
                    onDaysTap: horizontalSizeClass == .compact ? { selectedTab = 1 } : nil,
                    onInsightsTap: horizontalSizeClass == .compact ? { selectedTab = 2 } : nil
                )
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
                            color: .orange,
                            onTap: {
                                daysNavigationPath.append(busiest.date)
                                selectedTab = 1
                            }
                        )
                    }
                    if let longest = insights.longestDistanceDay {
                        highlightCard(
                            title: "Longest Distance",
                            value: longest.value,
                            date: AppDateDisplay.mediumDate(longest.date),
                            icon: "road.lanes",
                            color: .purple,
                            onTap: {
                                daysNavigationPath.append(longest.date)
                                selectedTab = 1
                            }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func highlightCard(title: String, value: String, date: String, icon: String, color: Color, onTap: (() -> Void)? = nil) -> some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    highlightCardBody(title: title, value: value, date: date, icon: icon, color: color, isInteractive: true)
                }
                .buttonStyle(.plain)
            } else {
                highlightCardBody(title: title, value: value, date: date, icon: icon, color: color, isInteractive: false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value), \(date)")
        .accessibilityAddTraits(onTap != nil ? .isButton : [])
    }

    @ViewBuilder
    private func highlightCardBody(title: String, value: String, date: String, icon: String, color: Color, isInteractive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isInteractive {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(color.opacity(0.5))
                }
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
            AppInsightsContentView(
                insights: insights,
                daySummaries: session.daySummaries,
                onDayTap: { date in
                    daysNavigationPath.append(date)
                    selectedTab = 1
                }
            )
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
        session.hasLoadedContent ? "Open Another File" : "Open app_export.json / .zip"
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
    @State private var isExpanded = false

    public init(summary: AppSourceSummary) {
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(summary.stateTitle)
                    .font(.headline)
                Spacer()
                Text(summary.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            summaryRow("Source", value: summary.sourceValue, icon: "doc")

            let hasDetails = summary.schemaVersion != nil || summary.inputFormat != nil || summary.exportedAt != nil || summary.dayCountText != nil
            if hasDetails {
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
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
                    }
                    .padding(.top, 6)
                } label: {
                    Text("Details")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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
    var onDaysTap: (() -> Void)? = nil
    var onInsightsTap: (() -> Void)? = nil

    public init(overview: ExportOverview, onDaysTap: (() -> Void)? = nil, onInsightsTap: (() -> Void)? = nil) {
        self.overview = overview
        self.onDaysTap = onDaysTap
        self.onInsightsTap = onInsightsTap
    }

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 160), spacing: 12)
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.title3.weight(.semibold))

            LazyVGrid(columns: columns, spacing: 12) {
                statCard("\(overview.dayCount)", label: "Days", icon: "calendar", color: .blue, action: onDaysTap)
                statCard("\(overview.totalVisitCount)", label: "Visits", icon: "mappin.and.ellipse", color: .purple, action: onInsightsTap)
                statCard("\(overview.totalActivityCount)", label: "Activities", icon: "figure.walk", color: .green, action: onInsightsTap)
                statCard("\(overview.totalPathCount)", label: "Paths", icon: "location.north.line", color: .orange, action: onInsightsTap)
            }
        }
    }

    @ViewBuilder
    private func statCard(_ value: String, label: String, icon: String, color: Color, action: (() -> Void)? = nil) -> some View {
        Group {
            if let action {
                Button(action: action) {
                    statCardBody(value, label: label, icon: icon, color: color, isInteractive: true)
                }
                .buttonStyle(.plain)
            } else {
                statCardBody(value, label: label, icon: icon, color: color, isInteractive: false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
        .accessibilityAddTraits(action != nil ? .isButton : [])
    }

    @ViewBuilder
    private func statCardBody(_ value: String, label: String, icon: String, color: Color, isInteractive: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(color.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Day Row

private struct AppDayRow: View {
    let summary: DaySummary
    var highlightIcons: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(AppDateDisplay.weekday(summary.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if !highlightIcons.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(highlightIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
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
    // Combine children so VoiceOver reads the whole card as one item.
    .accessibilityElement(children: .combine)
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
    case "IN TRAIN": return "train.side.front.car"
    case "IN SUBWAY": return "tram.fill"
    case "FLYING": return "airplane"
    default: return "figure.walk"
    }
}

private func displayNameForActivityType(_ type: String?, default defaultName: String = "Activity") -> String {
    switch (type ?? "").uppercased() {
    case "WALKING":              return "Walking"
    case "CYCLING":              return "Cycling"
    case "RUNNING":              return "Running"
    case "FLYING":               return "Flying"
    case "IN PASSENGER VEHICLE": return "Car"
    case "IN BUS":               return "Bus"
    case "IN TRAIN":             return "Train"
    case "IN SUBWAY":            return "Subway"
    default:
        guard let type else { return defaultName }
        return type.capitalized
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
                    "Nothing Recorded",
                    message: "This day has no visits, activities or paths in the export.",
                    recovery: onBackToOverview
                )
            }
        } else if hasDays {
            emptyDayState(
                "Select a Day",
                message: "Choose a day from the list to view details."
            )
        } else {
            emptyDayState(
                "No Day Entries",
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
            } else {
                Label("Map view requires iOS 17 or later.", systemImage: "map")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            #endif

            DayTimelineView(detail: detail)

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
                Text(displayNameForActivityType(activity.activityType))
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
            HStack(spacing: 6) {
                Image(systemName: iconForActivityType(path.activityType))
                    .foregroundColor(CardAccent.path)
                    .font(.subheadline)
                Text(displayNameForActivityType(path.activityType, default: "Path"))
                    .font(.subheadline.weight(.medium))
            }
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
                .foregroundStyle(.secondary)
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


// MARK: - Day Timeline

private struct DayTimelineView: View {
    let detail: DayDetailViewState

    private static let isoParser = ISO8601DateFormatter()

    private struct Slot: Identifiable {
        let id: Int
        let start: Date
        let end: Date
    }

    private func makeSlots(_ pairs: [(start: String?, end: String?)]) -> [Slot] {
        pairs.enumerated().compactMap { idx, pair in
            guard let s = pair.start.flatMap(Self.isoParser.date(from:)),
                  let e = pair.end.flatMap(Self.isoParser.date(from:)),
                  e > s else { return nil }
            return Slot(id: idx, start: s, end: e)
        }
    }

    private var visitSlots: [Slot] {
        makeSlots(detail.visits.map { ($0.startTime, $0.endTime) })
    }

    private var activitySlots: [Slot] {
        makeSlots(detail.activities.map { ($0.startTime, $0.endTime) })
    }

    private var bounds: (start: Date, end: Date)? {
        let all = visitSlots + activitySlots
        guard let earliest = all.map(\.start).min(),
              let latest = all.map(\.end).max(),
              latest > earliest else { return nil }
        return (earliest, latest)
    }

    private var accessibilitySummary: String {
        let from = bounds.map { $0.start.formatted(date: .omitted, time: .shortened) } ?? ""
        let to   = bounds.map { $0.end.formatted(date: .omitted, time: .shortened) } ?? ""
        var parts: [String] = []
        if !visitSlots.isEmpty {
            parts.append("\(visitSlots.count) visit\(visitSlots.count == 1 ? "" : "s")")
        }
        if !activitySlots.isEmpty {
            parts.append("\(activitySlots.count) \(activitySlots.count == 1 ? "activity" : "activities")")
        }
        if !from.isEmpty { parts.append("from \(from) to \(to)") }
        return "Day timeline: \(parts.joined(separator: ", "))"
    }

    var body: some View {
        if let b = bounds {
            let span = b.end.timeIntervalSince(b.start)
            VStack(alignment: .leading, spacing: 8) {
                Label("Timeline", systemImage: "clock.arrow.2.circlepath")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 6) {
                    if !visitSlots.isEmpty {
                        timelineRow(slots: visitSlots, color: CardAccent.visit, label: "Visits", bounds: b, span: span)
                    }
                    if !activitySlots.isEmpty {
                        timelineRow(slots: activitySlots, color: CardAccent.activity, label: "Activities", bounds: b, span: span)
                    }
                }
                HStack {
                    Text(b.start.formatted(date: .omitted, time: .shortened))
                    Spacer()
                    Text(b.end.formatted(date: .omitted, time: .shortened))
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            // Treat the whole Gantt chart as one accessibility element; the
            // individual coloured shapes have no standalone meaning for VoiceOver.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
        }
    }

    @ViewBuilder
    private func timelineRow(slots: [Slot], color: Color, label: String, bounds: (start: Date, end: Date), span: TimeInterval) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .trailing)
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Color.clear
                    ForEach(slots) { slot in
                        let xFrac = slot.start.timeIntervalSince(bounds.start) / span
                        let wFrac = slot.end.timeIntervalSince(slot.start) / span
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.opacity(0.75))
                            .frame(width: max(4, wFrac * geo.size.width), height: 16)
                            .offset(x: xFrac * geo.size.width)
                    }
                }
            }
            .frame(height: 16)
        }
    }
}

// MARK: - Insights Content View

private enum ActivityMetric: String, CaseIterable {
    case count = "Count"
    case distance = "Distance"
}

private struct AppInsightsContentView: View {
    let insights: ExportInsights
    let daySummaries: [DaySummary]
    let onDayTap: ((String) -> Void)?
    @State private var activityMetric: ActivityMetric = .count

    private static let chartDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    init(insights: ExportInsights, daySummaries: [DaySummary] = [], onDayTap: ((String) -> Void)? = nil) {
        self.insights = insights
        self.daySummaries = daySummaries
        self.onDayTap = onDayTap
    }

    private struct WeekdayStat: Identifiable {
        let id: Int
        let name: String
        let avgEvents: Double
    }

    private var weekdayStats: [WeekdayStat] {
        guard daySummaries.count >= 3 else { return [] }
        var buckets: [Int: (total: Int, count: Int)] = [:]
        for summary in daySummaries {
            guard let date = Self.chartDateFormatter.date(from: summary.date) else { continue }
            let wd = Calendar.current.component(.weekday, from: date)
            let events = summary.visitCount + summary.activityCount
            let b = buckets[wd] ?? (total: 0, count: 0)
            buckets[wd] = (total: b.total + events, count: b.count + 1)
        }
        // Mon(2)..Sat(7), Sun(1) last
        let order = [2, 3, 4, 5, 6, 7, 1]
        let names = [1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"]
        return order.compactMap { wd in
            guard let b = buckets[wd], b.count > 0 else { return nil }
            return WeekdayStat(id: wd, name: names[wd]!, avgEvents: Double(b.total) / Double(b.count))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            // Distance Over Time
            #if canImport(Charts)
            let hasDistanceData = daySummaries.contains(where: { $0.totalPathDistanceM > 0 })
            if !daySummaries.isEmpty && hasDistanceData {
                insightSection("Distance Over Time", icon: "chart.bar.fill") {
                    distanceChart
                }
            }
            #endif

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
                    #if canImport(Charts)
                    Picker("", selection: $activityMetric) {
                        ForEach(ActivityMetric.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 4)
                    activityTypeChart
                    #endif
                    ForEach(Array(insights.activityBreakdown.enumerated()), id: \.offset) { _, item in
                        activityBreakdownCard(item)
                    }
                }
            }

            // Visit Types
            if !insights.visitTypeBreakdown.isEmpty {
                insightSection("Visit Types", icon: "mappin.and.ellipse") {
                    #if canImport(Charts)
                    visitTypeChart
                    #endif
                    ForEach(Array(insights.visitTypeBreakdown.enumerated()), id: \.offset) { _, item in
                        visitTypeRow(item)
                    }
                }
            }

            // By Day of Week
            #if canImport(Charts)
            if !weekdayStats.isEmpty {
                insightSection("By Day of Week", icon: "chart.bar") {
                    weekdayChart
                }
            }
            #endif

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
                Text(displayNameForActivityType(item.activityType))
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

    // MARK: - Charts

    #if canImport(Charts)
    @ViewBuilder
    private var distanceChart: some View {
        let showXAxis = daySummaries.count <= 10
        Chart {
            ForEach(daySummaries, id: \.date) { summary in
                if let date = Self.chartDateFormatter.date(from: summary.date) {
                    BarMark(
                        x: .value("Date", date, unit: .day),
                        y: .value("km", summary.totalPathDistanceM / 1000)
                    )
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(3)
                }
            }
        }
        .chartXAxis(showXAxis ? .automatic : .hidden)
        .chartYAxisLabel("km", alignment: .trailing)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let onDayTap else { return }
                        let x = location.x - geometry.frame(in: .local).minX
                        if let tappedDate: Date = proxy.value(atX: x) {
                            let iso = Self.chartDateFormatter.string(from: tappedDate)
                            if daySummaries.contains(where: { $0.date == iso }) {
                                onDayTap(iso)
                            }
                        }
                    }
            }
        }
        .frame(height: 150)
    }

    @ViewBuilder
    private var activityTypeChart: some View {
        let items = insights.activityBreakdown
        let hasDistance = items.contains(where: { $0.totalDistanceKM > 0 })
        let showDistance = activityMetric == .distance && hasDistance
        Chart {
            ForEach(items, id: \.activityType) { item in
                let xVal = showDistance ? item.totalDistanceKM : Double(item.count)
                BarMark(
                    x: .value(showDistance ? "km" : "Count", xVal),
                    y: .value("Type", item.activityType.capitalized)
                )
                .foregroundStyle(Color.green)
                .cornerRadius(4)
                .annotation(position: .trailing) {
                    Text(showDistance ? String(format: "%.1f", item.totalDistanceKM) : "\(item.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartXAxis(.hidden)
        .frame(height: CGFloat(max(items.count, 1)) * 40 + 8)
    }

    @ViewBuilder
    private var visitTypeChart: some View {
        let totalCount = insights.visitTypeBreakdown.reduce(0) { $0 + $1.count }
        if totalCount > 0 {
            Chart {
                ForEach(insights.visitTypeBreakdown, id: \.semanticType) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Type", item.semanticType.capitalized)
                    )
                    .foregroundStyle(Color.blue)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text("\(item.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(max(insights.visitTypeBreakdown.count, 1)) * 40 + 8)
        }
    }
    @ViewBuilder
    private var weekdayChart: some View {
        Chart {
            ForEach(weekdayStats) { stat in
                BarMark(
                    x: .value("Day", stat.name),
                    y: .value("Avg", stat.avgEvents)
                )
                .foregroundStyle(Color.indigo)
                .cornerRadius(4)
            }
        }
        .chartYAxisLabel("avg events", alignment: .trailing)
        .frame(height: 110)
        .padding(.bottom, 2)
    }
    #endif

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