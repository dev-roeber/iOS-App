#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

// MARK: - Main Content View (Adaptive Layout)

public struct AppContentSplitView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Binding private var session: AppSessionState
    @ObservedObject private var liveLocation: LiveLocationFeatureModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var daysNavigationPath = NavigationPath()
    @State private var selectedTab = 0
    @State private var daySearchText = ""
    @State private var isShowingExportSheet = false
    @State private var isShowingTracksLibrary = false
    @State private var isShowingOptions = false
    @State private var lastCompactTabInteraction: (tab: Int, timestamp: Date)?

    private let onOpen: () -> Void
    private let onLoadDemo: () -> Void
    private let onClear: () -> Void
    private let compactDaysTabTag = 1
    private let compactDaysReselectInterval: TimeInterval = 0.8

    public init(
        session: Binding<AppSessionState>,
        liveLocation: LiveLocationFeatureModel,
        onOpen: @escaping () -> Void = {},
        onLoadDemo: @escaping () -> Void = {},
        onClear: @escaping () -> Void = {}
    ) {
        self._session = session
        self._liveLocation = ObservedObject(wrappedValue: liveLocation)
        self.onOpen = onOpen
        self.onLoadDemo = onLoadDemo
        self.onClear = onClear
    }

    private var filteredDaySummaries: [DaySummary] {
        DayListPresentation.filteredSummaries(session.daySummaries, query: daySearchText)
    }

    private func highlightIconsFor(_ date: String) -> [String] {
        var icons: [String] = []
        if session.insights?.busiestDay?.date == date { icons.append("flame.fill") }
        if session.insights?.mostVisitsDay?.date == date { icons.append("mappin.circle.fill") }
        if session.insights?.mostRoutesDay?.date == date { icons.append("location.north.circle.fill") }
        if session.insights?.longestDistanceDay?.date == date { icons.append("road.lanes") }
        return icons
    }

    private func normalizeDisplayedSelection() {
        session.selectDayForDisplay(session.selectedDate)
    }

    private var compactTabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                let now = Date()
                let isDaysReselect = newValue == compactDaysTabTag &&
                    selectedTab == compactDaysTabTag &&
                    lastCompactTabInteraction?.tab == compactDaysTabTag &&
                    now.timeIntervalSince(lastCompactTabInteraction?.timestamp ?? .distantPast) <= compactDaysReselectInterval

                selectedTab = newValue
                lastCompactTabInteraction = (newValue, now)

                guard isDaysReselect else { return }
                revealMostRelevantDayInCompactDays()
            }
        )
    }

    private func revealMostRelevantDayInCompactDays() {
        daySearchText = ""
        daysNavigationPath = NavigationPath()
        guard let targetDate = DayListPresentation.reselectTargetDate(session.daySummaries, relativeTo: Date()) else {
            session.selectDayForDisplay(nil)
            return
        }
        session.selectDayForDisplay(targetDate)
        daysNavigationPath.append(targetDate)
    }

    public var body: some View {
        withGlobalSheets {
            if horizontalSizeClass == .compact {
                compactTabView
            } else {
                regularSplitView
            }
        }
    }

    // MARK: - Compact (iPhone) Tab View

    private var compactTabView: some View {
        TabView(selection: compactTabSelection) {
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
                                hasDays: true,
                                liveLocation: liveLocation
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

            NavigationStack {
                AppExportView(session: $session, liveLocation: liveLocation)
                    .navigationTitle("Export")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            actionsMenu
                        }
                    }
            }
            .tabItem {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .tag(3)
            .badge(session.exportSelection.count > 0 ? session.exportSelection.count : 0)
        }
        // Replaces deprecated onChange(of:perform:) — task(id:) fires on
        // appearance and whenever id changes, which is the same behaviour.
        .task(id: session.daySummaries) {
            daysNavigationPath = NavigationPath()
            daySearchText = ""
            selectedTab = preferences.startTab.tabIndex
            normalizeDisplayedSelection()
        }
        .onAppear {
            selectedTab = preferences.startTab.tabIndex
        }
        .onChange(of: preferences.startTab) { newValue in
            selectedTab = newValue.tabIndex
        }
    }

    private var compactDayList: some View {
        let summaries = filteredDaySummaries
        let groups = groupByMonth(summaries)
        return List {
            Section {
                DayListExportSelectionCard(
                    selectionCount: session.exportSelection.count,
                    onOpenExport: { selectedTab = 3 }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }

            if groups.count == 1 {
                ForEach(groups[0].summaries, id: \.date) { summary in
                    if summary.hasContent {
                        NavigationLink(value: summary.date) {
                            AppDayRow(summary: summary, highlightIcons: highlightIconsFor(summary.date), isSelectedForExport: session.exportSelection.isSelected(summary.date))
                        }
                    } else {
                        AppDayRow(summary: summary, highlightIcons: highlightIconsFor(summary.date), isSelectedForExport: session.exportSelection.isSelected(summary.date))
                    }
                }
            } else {
                ForEach(groups) { group in
                    Section(group.title) {
                        ForEach(group.summaries, id: \.date) { summary in
                            if summary.hasContent {
                                NavigationLink(value: summary.date) {
                                    AppDayRow(summary: summary, highlightIcons: highlightIconsFor(summary.date), isSelectedForExport: session.exportSelection.isSelected(summary.date))
                                }
                            } else {
                                AppDayRow(summary: summary, highlightIcons: highlightIconsFor(summary.date), isSelectedForExport: session.exportSelection.isSelected(summary.date))
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
                AppDaySearchEmptyView(
                    query: daySearchText,
                    exportSelectionCount: session.exportSelection.count
                )
            }
        }
    }

    // MARK: - Regular (iPad) Split View

    private var regularSplitView: some View {
        NavigationSplitView {
            AppDayListView(
                summaries: filteredDaySummaries,
                totalSummaryCount: session.daySummaries.count,
                searchQuery: daySearchText,
                selectedDate: Binding(
                    get: { session.selectedDate },
                    set: { session.selectDayForDisplay($0) }
                ),
                exportSelection: session.exportSelection,
                onOpenExport: { isShowingExportSheet = true }
            )
            .navigationTitle("Days")
            .searchable(text: $daySearchText, prompt: "Search by date")
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
            AppSessionStatusView(
                summary: session.sourceSummary,
                message: session.message,
                isLoading: session.isLoading,
                hasDays: session.hasDays
            )

            if let insights = session.insights, !insights.activeFilterDescriptions.isEmpty {
                activeFiltersSection(insights.activeFilterDescriptions)
            }

            if horizontalSizeClass == .compact, session.hasLoadedContent {
                overviewPrimaryActionsSection
            }

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
                        Text(formatDistance(insights.totalDistanceM, unit: preferences.distanceUnit))
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

            localToolsSection
        }
    }

    @ViewBuilder
    private var overviewPrimaryActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Go To")
                .font(.title3.weight(.semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                overviewActionCard(
                    title: "Days",
                    subtitle: "Browse imported history day by day.",
                    icon: "calendar",
                    color: .blue
                ) {
                    selectedTab = 1
                }
                overviewActionCard(
                    title: "Insights",
                    subtitle: "Open charts and aggregate breakdowns.",
                    icon: "chart.xyaxis.line",
                    color: .indigo
                ) {
                    selectedTab = 2
                }
                overviewActionCard(
                    title: "Export",
                    subtitle: "Review selection and create a GPX file.",
                    icon: "square.and.arrow.up",
                    color: .orange
                ) {
                    selectedTab = 3
                }
            }
        }
    }

    @ViewBuilder
    private func overviewHighlights(_ insights: ExportInsights) -> some View {
        let hasHighlights = insights.busiestDay != nil
            || insights.mostVisitsDay != nil
            || insights.mostRoutesDay != nil
            || insights.longestDistanceDay != nil
        if hasHighlights {
            VStack(alignment: .leading, spacing: 12) {
                Text("Highlights")
                    .font(.title3.weight(.semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    if let busiest = insights.busiestDay {
                        highlightCard(
                            title: "Busiest Day",
                            value: busiest.value,
                            date: AppDateDisplay.mediumDate(busiest.date),
                            icon: "flame.fill",
                            color: .orange,
                            onTap: {
                                openDayFromInsights(busiest.date)
                            }
                        )
                    }
                    if let visits = insights.mostVisitsDay {
                        highlightCard(
                            title: "Most Visits",
                            value: visits.value,
                            date: AppDateDisplay.mediumDate(visits.date),
                            icon: "mappin.circle.fill",
                            color: .blue,
                            onTap: {
                                openDayFromInsights(visits.date)
                            }
                        )
                    }
                    if let routes = insights.mostRoutesDay {
                        highlightCard(
                            title: "Most Routes",
                            value: routes.value,
                            date: AppDateDisplay.mediumDate(routes.date),
                            icon: "location.north.circle.fill",
                            color: .green,
                            onTap: {
                                openDayFromInsights(routes.date)
                            }
                        )
                    }
                    if let longest = insights.longestDistanceDay {
                        highlightCard(
                            title: "Longest Distance",
                            value: longestDistanceValue(for: longest),
                            date: AppDateDisplay.mediumDate(longest.date),
                            icon: "road.lanes",
                            color: .purple,
                            onTap: {
                                openDayFromInsights(longest.date)
                            }
                        )
                    }
                }
            }
        }
    }

    private func openDayFromInsights(_ date: String) {
        session.selectDayForDisplay(date)
        guard session.selectedDate == date else { return }

        if horizontalSizeClass == .compact {
            daySearchText = ""
            daysNavigationPath = NavigationPath()
            daysNavigationPath.append(date)
            selectedTab = 1
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
    private func overviewActionCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(color.opacity(0.5))
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
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
                    openDayFromInsights(date)
                }
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No Insights Available")
                    .font(.headline)
                Text("Load a location history file to see detailed insights.")
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
                VStack(alignment: .leading, spacing: 16) {
                    Button {
                        session.selectDay(nil)
                    } label: {
                        Label("Overview", systemImage: "chevron.backward")
                    }
                    .buttonStyle(.bordered)

                    AppDayDetailView(
                        detail: detail,
                        hasDays: true,
                        onBackToOverview: { session.selectDay(nil) },
                        liveLocation: liveLocation
                    )
                }
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
            Divider()
            Button {
                isShowingOptions = true
            } label: {
                Label("Options", systemImage: "slider.horizontal.3")
            }
            if session.hasDays && horizontalSizeClass != .compact {
                Divider()
                Button {
                    isShowingExportSheet = true
                } label: {
                    Label("Export…", systemImage: "square.and.arrow.up")
                }
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

    @ViewBuilder
    private func withGlobalSheets<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .sheet(isPresented: $isShowingExportSheet) {
                NavigationStack {
                    AppExportView(session: $session, liveLocation: liveLocation)
                        .environmentObject(preferences)
                        .navigationTitle("Export")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { isShowingExportSheet = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $isShowingTracksLibrary) {
                NavigationStack {
                    tracksLibrarySheetContent
                        .environmentObject(preferences)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { isShowingTracksLibrary = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $isShowingOptions) {
                NavigationStack {
                    AppOptionsView(preferences: preferences)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { isShowingOptions = false }
                            }
                        }
                }
            }
    }

    private var liveTracksOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(SavedTracksPresentation.libraryTitle, systemImage: SavedTracksPresentation.libraryIcon)
                        .font(.headline)
                    Text(liveTracksOverviewMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(SavedTracksPresentation.libraryButtonTitle) {
                    isShowingTracksLibrary = true
                }
                .buttonStyle(.bordered)
            }

            if let latestTrack = liveLocation.recordedTracks.first {
                HStack(spacing: 12) {
                    Image(systemName: SavedTracksPresentation.libraryIcon)
                        .font(.title3)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(SavedTracksPresentation.latestTrackLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(savedTrackTitle(latestTrack))
                            .font(.subheadline.weight(.semibold))
                        Text("\(latestTrack.pointCount) points · \(formatDistance(latestTrack.distanceM, unit: preferences.distanceUnit))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(liveLocation.recordedTracks.count) total")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var localToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local Tools")
                .font(.title3.weight(.semibold))
            Text("Saved Tracks remain a separate local utility and do not change the imported history above.")
                .font(.caption)
                .foregroundStyle(.secondary)
            liveTracksOverviewSection
        }
    }

    @ViewBuilder
    private var tracksLibrarySheetContent: some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            AppRecordedTracksLibraryView(liveLocation: liveLocation)
        } else {
            VStack(spacing: 12) {
                Image(systemName: SavedTracksPresentation.libraryIcon)
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(SavedTracksPresentation.unavailableTitle)
                    .font(.headline)
                Text(SavedTracksPresentation.unavailableMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            .navigationTitle(SavedTracksPresentation.libraryTitle)
        }
    }

    private var openButtonTitle: String {
        session.hasLoadedContent ? "Open Another File" : "Open location history file"
    }

    private var demoButtonTitle: String {
        session.source == .demoFixture(name: AppContentLoader.defaultDemoFixtureName)
            ? "Reload Demo" : "Demo Data"
    }

    private var liveTracksOverviewMessage: String {
        SavedTracksPresentation.overviewMessage(hasTracks: !liveLocation.recordedTracks.isEmpty)
    }

    private func savedTrackTitle(_ track: RecordedTrack) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: track.startedAt)
    }

    private func longestDistanceValue(for highlight: DayHighlight) -> String {
        guard let summary = session.daySummaries.first(where: { $0.date == highlight.date }) else {
            return highlight.value
        }
        return formatDistance(summary.totalPathDistanceM, unit: preferences.distanceUnit)
    }
}

#endif
