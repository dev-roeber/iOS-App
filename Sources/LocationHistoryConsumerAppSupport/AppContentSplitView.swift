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
    @State private var dayListFilter = DayListFilter.empty
    @State private var favoritedDayIDs: Set<String> = []
    @State private var presentedSheet: PresentedSheet?

    private let onOpen: () -> Void
    private let onLoadDemo: () -> Void
    private let onClear: () -> Void

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
        DayListPresentation.filteredSummaries(
            drilldownDaySummaries,
            query: daySearchText,
            filter: dayListFilter,
            favorites: favoritedDayIDs
        )
    }

    private var availableDayFilterChips: [DayListFilterChip] {
        DayListPresentation.availableFilterChips(
            summaries: drilldownDaySummaries,
            favorites: favoritedDayIDs
        )
    }

    private var activeDayDrilldownAction: InsightsDrilldownAction? {
        InsightsDrilldownBridge.dayListAction(from: session.activeDrilldownFilter)
    }

    private var drilldownDaySummaries: [DaySummary] {
        InsightsDrilldownBridge.filteredSummaries(
            projectedDaySummaries,
            applying: activeDayDrilldownAction,
            favorites: favoritedDayIDs
        )
    }

    private var activeDayDrilldownDescription: String? {
        InsightsDrilldownBridge.description(
            for: activeDayDrilldownAction,
            language: preferences.appLanguage
        )
    }

    private var baseQueryFilter: AppExportQueryFilter? {
        session.content.map { AppExportQueryFilter(exportFilters: $0.export.meta.filters) }
    }

    private var projectedQueryFilter: AppExportQueryFilter? {
        AppHistoryDateRangeQueryBridge.mergedFilter(
            base: baseQueryFilter,
            rangeFilter: session.historyDateRangeFilter
        )
    }

    private var projectedOverview: ExportOverview? {
        session.content?.overview(applying: projectedQueryFilter)
    }

    private var projectedDaySummaries: [DaySummary] {
        session.content?.daySummaries(applying: projectedQueryFilter) ?? []
    }

    private var projectedInsights: ExportInsights? {
        session.content?.insights(applying: projectedQueryFilter)
    }

    private var localizedProjectedFilterDescriptions: [String] {
        guard let projectedInsights else {
            return []
        }

        return projectedInsights.activeFilterDescriptions.compactMap { description in
            if session.historyDateRangeFilter.isActive,
               description.hasPrefix("From: ") || description.hasPrefix("To: ") {
                return nil
            }

            if let value = description.split(separator: ":", maxSplits: 1).last,
               description.hasPrefix("Max accuracy: ") {
                return "\(t("Maximum accuracy")):\(value)"
            }

            if let value = description.split(separator: ":", maxSplits: 1).last,
               description.hasPrefix("Activity types: ") {
                return "\(t("Activity types")):\(value)"
            }

            switch description {
            case "Area: Bounding box":
                return t("Area: Bounding box")
            case "Area: Polygon":
                return t("Area: Polygon")
            case "Area: Combined filters":
                return t("Area: Combined filters")
            default:
                return description
            }
        }
    }

    private enum PresentedSheet: String, Identifiable {
        case export
        case tracksLibrary
        case options
        case heatmap

        var id: String { rawValue }
    }

    private static let currentDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func highlightIconsFor(_ date: String) -> [String] {
        var icons: [String] = []
        if session.insights?.busiestDay?.date == date { icons.append("flame.fill") }
        if session.insights?.longestDistanceDay?.date == date { icons.append("road.lanes") }
        return icons
    }

    private func normalizeDisplayedSelection() {
        session.selectDayForDisplay(session.selectedDate)
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    public var body: some View {
        liveTrackingObservers
            .environment(\.locale, preferences.appLocale)
    }

    private var liveTrackingObservers: some View {
        liveTrackingObserversBase
            .onChange(of: preferences.sendsLiveLocationToServer) { _ in syncLiveRecordingSettings() }
            .onChange(of: preferences.liveLocationServerUploadURLString) { _ in syncLiveRecordingSettings() }
            .onChange(of: preferences.liveLocationServerUploadBearerToken) { _ in syncLiveRecordingSettings() }
            .onChange(of: preferences.liveTrackingUploadBatch) { _ in syncLiveRecordingSettings() }
    }

    private var liveTrackingObserversBase: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactTabView
            } else {
                regularSplitView
            }
        }
        .onAppear {
            syncLiveRecordingSettings()
        }
        .onChange(of: preferences.liveTrackingAccuracy) { _ in syncLiveRecordingSettings() }
        .onChange(of: preferences.liveTrackingDetail) { _ in syncLiveRecordingSettings() }
        .onChange(of: preferences.allowsBackgroundLiveTracking) { _ in syncLiveRecordingSettings() }
    }

    // MARK: - Compact (iPhone) Tab View

    private var compactTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    overviewPaneContent
                        .padding()
                }
                .navigationTitle(t("Overview"))
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        actionsMenu
                    }
                }
            }
            .tabItem {
                Label(t("Overview"), systemImage: "chart.bar.doc.horizontal")
            }
            .tag(0)

            NavigationStack(path: $daysNavigationPath) {
                compactDayList
                    .navigationTitle(t("Days"))
                    .searchable(text: $daySearchText, prompt: t("Search by date, weekday or month"))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            actionsMenu
                        }
                    }
                    .navigationDestination(for: String.self) { date in
                        ScrollView {
                            AppDayDetailView(
                                detail: session.content?.detail(for: date),
                                mapData: session.content?.mapData(for: date),
                                hasDays: true,
                                exportSelection: $session.exportSelection,
                                isFavorited: favoritedDayIDs.contains(date),
                                onToggleFavorite: { toggleFavoriteDay(date) },
                                liveLocation: liveLocation,
                                onOpenSavedTracks: { presentSheet(.tracksLibrary) }
                            )
                            .padding()
                        }
                        .navigationTitle(AppDateDisplay.longDate(date))
                    }
            }
            .tabItem {
                Label(t("Days"), systemImage: "calendar")
            }
            .tag(1)

            NavigationStack {
                ScrollView {
                    insightsPaneContent
                        .padding()
                }
                .navigationTitle(t("Insights"))
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        actionsMenu
                    }
                }
            }
            .tabItem {
                Label(t("Insights"), systemImage: "chart.xyaxis.line")
            }
            .tag(2)

            NavigationStack {
                AppExportView(session: $session, liveLocation: liveLocation)
                    .navigationTitle(t("Export"))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            actionsMenu
                        }
                    }
            }
            .tabItem {
                Label(t("Export"), systemImage: "square.and.arrow.up")
            }
            .tag(3)
            .badge(session.exportSelection.count)

            if #available(iOS 17.0, macOS 14.0, *) {
                NavigationStack {
                    AppLiveTrackingView(
                        liveLocation: liveLocation,
                        onOpenSavedTracksLibrary: { presentSheet(.tracksLibrary) }
                    )
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            actionsMenu
                        }
                    }
                }
                .tabItem {
                    Label(t("Live"), systemImage: "record.circle")
                }
                .tag(4)
            }
        }
        #if canImport(UIKit) && os(iOS)
        .background(
            IOSTabReselectionObserver { index, isReselection in
                guard isReselection, index == 1 else { return }
                handleDaysTabReselection()
            }
        )
        #endif
        // Replaces deprecated onChange(of:perform:) — task(id:) fires on
        // appearance and whenever id changes, which is the same behaviour.
        .task(id: session.daySummaries) {
            daysNavigationPath = NavigationPath()
            daySearchText = ""
            dayListFilter.clearAll()
            selectedTab = preferences.startTab.tabIndex
            normalizeDisplayedSelection()
            refreshFavoriteDays()
        }
        .onAppear {
            selectedTab = preferences.startTab.tabIndex
            refreshFavoriteDays()
        }
        .onChange(of: preferences.startTab) { newValue in
            selectedTab = newValue.tabIndex
        }
    }

    private var compactDayList: some View {
        let summaries = filteredDaySummaries
        let groups = groupByMonth(summaries, locale: preferences.appLocale)
        return List {
            if let activeDayDrilldownDescription {
                Section {
                    drilldownBanner(
                        description: activeDayDrilldownDescription,
                        clearAction: clearActiveDayDrilldown
                    )
                }
            }
            if session.historyDateRangeFilter.isActive {
                Section {
                    HStack(spacing: 10) {
                        HistoryDateRangeFilterBar(filter: $session.historyDateRangeFilter)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
            if !availableDayFilterChips.isEmpty || dayListFilter.isActive {
                Section {
                    AppDayFilterChipsView(filter: $dayListFilter, availableChips: availableDayFilterChips)
                }
            }
            if session.exportSelection.count > 0 {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(compactExportSelectionTitle)
                                .font(.subheadline.weight(.semibold))
                            Text(t("Open the Export tab to review or save the current selection."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(t("Export")) {
                            selectedTab = 3
                        }
                        .font(.caption.weight(.semibold))
                    }
                    .padding(.vertical, 4)
                }
            }
            if groups.count == 1, let firstGroup = groups.first {
                ForEach(firstGroup.summaries, id: \.date) { summary in
                    if summary.hasContent {
                        NavigationLink(value: summary.date) {
                            compactDayRow(summary)
                        }
                    } else {
                        compactDayRow(summary)
                    }
                }
            } else {
                ForEach(groups) { group in
                    Section(group.title) {
                        ForEach(group.summaries, id: \.date) { summary in
                            if summary.hasContent {
                                NavigationLink(value: summary.date) {
                                    compactDayRow(summary)
                                }
                            } else {
                                compactDayRow(summary)
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
                    Image(systemName: session.historyDateRangeFilter.isActive ? "calendar.badge.exclamationmark" : "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(compactEmptyStateHeadline)
                        .font(.headline)
                    Text(compactEmptyStateMessage)
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
                summaries: drilldownDaySummaries,
                selectedForExportDates: session.exportSelection.selectedDates,
                favoriteDayIDs: favoritedDayIDs,
                drilldownDescription: activeDayDrilldownDescription,
                isRangeFilterActive: session.historyDateRangeFilter.isActive,
                selectedDate: Binding(
                    get: { session.selectedDate },
                    set: { session.selectDayForDisplay($0) }
                ),
                filter: $dayListFilter,
                onClearDrilldown: clearActiveDayDrilldown,
                onToggleFavorite: toggleFavoriteDay,
                highlightIconsForDate: highlightIconsFor,
                searchText: $daySearchText
            )
            .navigationTitle(t("Days"))
            .searchable(text: $daySearchText, prompt: t("Search by date, weekday or month"))
            .toolbar {
                if session.historyDateRangeFilter.isActive {
                    ToolbarItem(placement: .status) {
                        HistoryDateRangeFilterBar(filter: $session.historyDateRangeFilter)
                    }
                }
            }
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

            overviewPrimaryActionsSection

            AppHistoryDateRangeControl(filter: $session.historyDateRangeFilter)

            if let range = projectedInsights?.dateRange {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                    Text("\(AppDateDisplay.mediumDate(range.firstDate)) – \(AppDateDisplay.mediumDate(range.lastDate))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let insights = projectedInsights, insights.totalDistanceM > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "road.lanes")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("Total Distance"))
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

            if let insights = projectedInsights {
                overviewHighlights(insights)
            }

            if let overview = projectedOverview {
                AppOverviewSection(
                    overview: overview,
                    daySummaries: projectedDaySummaries,
                    onDaysTap: horizontalSizeClass == .compact ? { selectedTab = 1 } : nil,
                    onInsightsTap: horizontalSizeClass == .compact ? { selectedTab = 2 } : nil
                )
            }

            if !localizedProjectedFilterDescriptions.isEmpty {
                activeFiltersSection(localizedProjectedFilterDescriptions)
            }

            liveTracksOverviewSection
        }
    }

    @ViewBuilder
    private var overviewPrimaryActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Primary Actions"))
                .font(.title3.weight(.semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                overviewActionButton(
                    title: openButtonTitle,
                    subtitle: t("Replace the current import with another local file."),
                    icon: "doc.badge.plus",
                    color: .accentColor,
                    action: onOpen
                )

                if horizontalSizeClass == .compact {
                    overviewActionButton(
                    title: t("Browse Days"),
                        subtitle: t("Jump into the day list and open imported history entries."),
                        icon: "calendar",
                        color: .blue
                    ) {
                        selectedTab = 1
                    }

                    overviewActionButton(
                    title: t("Open Insights"),
                        subtitle: t("Switch to charts and derived breakdowns for the current import."),
                        icon: "chart.xyaxis.line",
                        color: .indigo
                    ) {
                        selectedTab = 2
                    }

                    if session.hasDays {
                        overviewActionButton(
                            title: t("Export GPX"),
                            subtitle: t("Choose days and prepare a GPX export from recorded routes."),
                            icon: "square.and.arrow.up",
                            color: .green
                        ) {
                            selectedTab = 3
                        }
                    }
                }

                overviewActionButton(
                    title: t("Saved Live Tracks"),
                    subtitle: t("Open the separate local track library and edit finished recordings there."),
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    color: .mint
                ) {
                    presentSheet(.tracksLibrary)
                }

                if session.hasDays {
                    overviewActionButton(
                        title: t("Heatmap"),
                        subtitle: t("Visualize your movement density on a map."),
                        icon: "thermometer.medium",
                        color: .red
                    ) {
                        presentSheet(.heatmap)
                    }
                }

                if horizontalSizeClass != .compact, session.hasDays {
                    overviewActionButton(
                        title: t("Export GPX"),
                        subtitle: t("Open the export sheet for the current imported history."),
                        icon: "square.and.arrow.up",
                        color: .green
                    ) {
                        presentSheet(.export)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func overviewHighlights(_ insights: ExportInsights) -> some View {
        let hasHighlights = insights.busiestDay != nil || insights.longestDistanceDay != nil
        if hasHighlights {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("Highlights"))
                    .font(.title3.weight(.semibold))
                HStack(spacing: 12) {
                    if let busiest = insights.busiestDay {
                        highlightCard(
                            title: t("Busiest Day"),
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
                            title: t("Longest Distance"),
                            value: longestDistanceValue(for: longest),
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
    private func overviewActionButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(color)
                    .frame(width: 18, alignment: .center)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(color.opacity(0.5))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(color.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func activeFiltersSection(_ filters: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(t("Filtered Export"), systemImage: "line.3.horizontal.decrease.circle.fill")
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
    private func compactDayRow(_ summary: DaySummary) -> some View {
        AppDayRow(
            summary: summary,
            highlightIcons: highlightIconsFor(summary.date),
            isSelectedForExport: session.exportSelection.isSelected(summary.date),
            isFavorited: favoritedDayIDs.contains(summary.date)
        )
        .contextMenu {
            Button {
                toggleFavoriteDay(summary.date)
            } label: {
                Label(
                    favoritedDayIDs.contains(summary.date) ? t("Remove Favorite") : t("Add Favorite"),
                    systemImage: favoritedDayIDs.contains(summary.date) ? "star.slash" : "star"
                )
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                toggleFavoriteDay(summary.date)
            } label: {
                Label(
                    favoritedDayIDs.contains(summary.date) ? t("Unfavorite") : t("Favorite"),
                    systemImage: favoritedDayIDs.contains(summary.date) ? "star.slash.fill" : "star.fill"
                )
            }
            .tint(favoritedDayIDs.contains(summary.date) ? .gray : .yellow)
        }
    }

    private var compactEmptyStateHeadline: String {
        if session.historyDateRangeFilter.isActive && daySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !dayListFilter.isActive {
            return t("No Days in Range")
        }
        return dayListFilter.isActive ? t("No Matching Days") : t("No Results")
    }

    private var compactEmptyStateMessage: String {
        let trimmed = daySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && dayListFilter.isActive {
            return preferences.localized(format: "No days match \"%@\" with the current filters.", arguments: [trimmed])
        }
        if !trimmed.isEmpty {
            return preferences.localized(format: "No days match \"%@\".", arguments: [trimmed])
        }
        if session.historyDateRangeFilter.isActive {
            return t("No days fall within the selected date range. Change the range above to see more days.")
        }
        if activeDayDrilldownDescription != nil {
            return t("No day matches the current drilldown and filter combination.")
        }
        return t("No day matches the active filter chips.")
    }

    private var compactExportSelectionTitle: String {
        if preferences.appLanguage.isGerman {
            return "\(session.exportSelection.count) \(session.exportSelection.count == 1 ? "Tag" : "Tage") für den Export ausgewählt"
        }
        return "\(session.exportSelection.count) day\(session.exportSelection.count == 1 ? "" : "s") selected for export"
    }

    private func refreshFavoriteDays() {
        favoritedDayIDs = DayFavoritesStore.load()
    }

    private func toggleFavoriteDay(_ date: String) {
        _ = DayFavoritesStore.toggle(dayIdentifier: date)
        refreshFavoriteDays()
    }

    private func clearActiveDayDrilldown() {
        session.activeDrilldownFilter = nil
    }

    private func applyInsightsDrilldown(_ action: InsightsDrilldownAction) {
        // Map drilldown: navigate directly to the day detail so the inline map is immediately visible.
        if case let .showDayOnMap(date) = action {
            session.activeDrilldownFilter = action
            session.selectDayForDisplay(date)
            daysNavigationPath = NavigationPath()
            if horizontalSizeClass == .compact {
                daysNavigationPath.append(date)
            }
            selectedTab = 1
            return
        }

        if let dayAction = InsightsDrilldownBridge.dayListAction(from: action) {
            session.activeDrilldownFilter = dayAction
            session.selectDay(nil)
            daysNavigationPath = NavigationPath()
            selectedTab = 1
            return
        }

        guard let exportAction = InsightsDrilldownBridge.exportAction(from: action) else {
            return
        }

        session.activeDrilldownFilter = exportAction
        session.exportSelection.clearAll()
        let selectedDates = InsightsDrilldownBridge.prefillDates(
            for: exportAction,
            availableDates: session.daySummaries.map(\.date)
        ).sorted()
        session.exportSelection.selectAll(from: selectedDates)

        if horizontalSizeClass == .compact {
            selectedTab = 3
        } else {
            presentSheet(.export)
        }
    }

    @ViewBuilder
    private func drilldownBanner(description: String, clearAction: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "scope")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(t("Insights Drilldown"))
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(t("Reset")) {
                clearAction()
            }
            .font(.caption.weight(.medium))
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var insightsPaneContent: some View {
        if let insights = projectedInsights {
            AppInsightsContentView(
                insights: insights,
                daySummaries: projectedDaySummaries,
                rangeFilter: $session.historyDateRangeFilter,
                activeFilterDescriptions: localizedProjectedFilterDescriptions,
                onDrilldown: applyInsightsDrilldown
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(t("No Insights Available"))
                    .font(.headline)
                Text(t("Load a location history file to see detailed insights."))
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
                        Label(t("Overview"), systemImage: "chevron.backward")
                    }
                    .buttonStyle(.bordered)

                    AppDayDetailView(
                        detail: detail,
                        mapData: session.content?.mapData(for: detail.date),
                        hasDays: true,
                        onBackToOverview: { session.selectDay(nil) },
                        exportSelection: $session.exportSelection,
                        isFavorited: favoritedDayIDs.contains(detail.date),
                        onToggleFavorite: { toggleFavoriteDay(detail.date) },
                        liveLocation: liveLocation,
                        onOpenSavedTracks: { presentSheet(.tracksLibrary) }
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
                            t("Select a day from the list to view details."),
                            systemImage: "hand.tap"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle(t("Overview"))
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
                presentSheet(.options)
            } label: {
                Label(t("Options"), systemImage: "slider.horizontal.3")
            }
            Divider()
            Button {
                presentSheet(.tracksLibrary)
            } label: {
                Label(t("Saved Live Tracks"), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
            }
            if session.hasDays && horizontalSizeClass != .compact {
                Divider()
                Button {
                    presentSheet(.export)
                } label: {
                    Label("\(t("Export"))…", systemImage: "square.and.arrow.up")
                }
            }
            if session.hasLoadedContent || session.message?.kind == .error {
                Divider()
                Button(role: .destructive, action: onClear) {
                    Label(t("Clear"), systemImage: "xmark.circle")
                }
            }
        } label: {
            Label(t("Actions"), systemImage: "ellipsis.circle")
        }
        .sheet(item: $presentedSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .export:
                    AppExportView(session: $session, liveLocation: liveLocation)
                        .environmentObject(preferences)
                        .navigationTitle(t("Export"))
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(t("Done")) { presentedSheet = nil }
                            }
                        }
                case .tracksLibrary:
                    tracksLibrarySheetContent
                        .environmentObject(preferences)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(t("Done")) { presentedSheet = nil }
                            }
                        }
                case .options:
                    AppOptionsView(preferences: preferences)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(t("Done")) { presentedSheet = nil }
                            }
                        }
                case .heatmap:
                    if let export = session.content?.export {
                        if #available(iOS 17.0, macOS 14.0, *) {
                            AppHeatmapView(export: export)
                                .environmentObject(preferences)
                                .navigationTitle("Heatmap")
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button(t("Done")) { presentedSheet = nil }
                                    }
                                }
                        }
                    }
                }
            }
        }
    }

    private func presentSheet(_ sheet: PresentedSheet) {
        DispatchQueue.main.async {
            presentedSheet = sheet
        }
    }

    private func syncLiveRecordingSettings() {
        liveLocation.updateRecorderConfiguration(preferences.liveTrackRecorderConfiguration)
        liveLocation.setBackgroundTrackingPreference(preferences.allowsBackgroundLiveTracking)
        liveLocation.setServerUploadConfiguration(preferences.liveLocationServerUploadConfiguration)
    }

    private func handleDaysTabReselection() {
        daySearchText = ""
        daysNavigationPath = NavigationPath()

        let todayKey = Self.currentDayFormatter.string(from: Date())
        guard let todaySummary = session.daySummaries.first(where: { $0.date == todayKey }) else {
            return
        }

        guard todaySummary.hasContent else {
            session.selectDay(nil)
            return
        }

        session.selectDayForDisplay(todaySummary.date)
        daysNavigationPath.append(todaySummary.date)
    }

    private var liveTracksOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(t("Saved Live Tracks"), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.headline)
                    Text(liveTracksOverviewMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(t("Open Library")) {
                    presentSheet(.tracksLibrary)
                }
                .buttonStyle(.borderedProminent)
            }

            if let latestTrack = liveLocation.recordedTracks.first {
                HStack(spacing: 12) {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.title3)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(savedTrackTitle(latestTrack))
                            .font(.subheadline.weight(.semibold))
                        Text("\(latestTrack.pointCount) points · \(formatDistance(latestTrack.distanceM, unit: preferences.distanceUnit))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(liveLocation.recordedTracks.count) saved")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var tracksLibrarySheetContent: some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            AppRecordedTracksLibraryView(liveLocation: liveLocation)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(t("Saved Live Tracks Unavailable"))
                    .font(.headline)
                Text("Saved live tracks can be reviewed and edited on platforms that support the local track library.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            .navigationTitle(t("Saved Live Tracks"))
        }
    }

    private var openButtonTitle: String {
        session.hasLoadedContent ? t("Open Another File") : t("Open location history file")
    }

    private var demoButtonTitle: String {
        session.source == .demoFixture(name: AppContentLoader.defaultDemoFixtureName)
            ? t("Reload Demo") : t("Demo Data")
    }

    private var liveTracksOverviewMessage: String {
        if liveLocation.recordedTracks.isEmpty {
            return t("Saved live tracks live in a separate local library. Record a short track on any day, then open it from here.")
        }
        return t("Open the local track library directly from Overview to edit points, insert midpoints or delete a saved live track.")
    }

    private func savedTrackTitle(_ track: RecordedTrack) -> String {
        AppDateDisplay.abbreviatedDateTime(track.startedAt)
    }

    private func longestDistanceValue(for highlight: DayHighlight) -> String {
        guard let summary = session.daySummaries.first(where: { $0.date == highlight.date }) else {
            return highlight.value
        }
        return formatDistance(summary.totalPathDistanceM, unit: preferences.distanceUnit)
    }
}

#endif
