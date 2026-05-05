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
    @State private var overviewShowOnlyFavorites: Bool = false
    @State private var overviewMapHeaderState = LHMapHeaderState(
        visibility: .compact,
        compactHeight: 220,
        expandedHeight: 320
    )
    @State private var daysMapHeaderState = LHMapHeaderState(
        visibility: .compact,
        compactHeight: 180,
        expandedHeight: 260,
        isSticky: true
    )
    @State private var presentedSheet: PresentedSheet?
    @StateObject private var pathMutationStore = AppImportedPathMutationStore()

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

            // "Limit: N days" is a server-side export metadata constraint — the user
            // cannot change it, so displaying it as an active UI filter is confusing.
            if description.hasPrefix("Limit: ") {
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

    private var daysRangeSummaryText: String {
        StartOverviewPresentation.rangeSummary(
            for: session.historyDateRangeFilter,
            language: preferences.appLanguage,
            locale: preferences.appLocale
        )
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
            .onChange(of: session.source) { source in
                if let source = source {
                    pathMutationStore.validateSource(source.displayName)
                }
            }
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
        .onChange(of: liveLocation.navigateToLiveTabRequested) { requested in
            guard requested else { return }
            selectedTab = 3
            liveLocation.navigateToLiveTabRequested = false
        }
    }

    // MARK: - Compact (iPhone) Tab View

    private var compactTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    overviewPaneContent
                }
                .background(Color.black.ignoresSafeArea())
                .navigationTitle("")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
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
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.large)
                    #endif
                    .searchable(text: $daySearchText, prompt: t("Search by date, weekday or month"))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            actionsMenu
                        }
                    }
                    .navigationDestination(for: String.self) { date in
                        AppDayDetailView(
                            detail: session.content?.detail(for: date),
                            mapData: session.content?.mapData(for: date),
                            hasDays: true,
                            exportSelection: $session.exportSelection,
                            isFavorited: favoritedDayIDs.contains(date),
                            onToggleFavorite: { toggleFavoriteDay(date) },
                            liveLocation: liveLocation,
                            onOpenSavedTracks: { presentSheet(.tracksLibrary) },
                            mutations: pathMutationStore.currentMutations,
                            onRemovePath: { index in
                                pathMutationStore.addDeletion(
                                    ImportedPathDeletion(dayKey: date, pathIndex: index)
                                )
                            }
                        )
                        .navigationTitle(AppDateDisplay.longDate(date))
                    }
            }
            .tabItem {
                Label(t("Days"), systemImage: "calendar")
            }
            .tag(1)

            NavigationStack {
                insightsPaneContent
                    // Empty title: the content's own Text("Insights") header acts as the
                    // large title so we don't end up with two "Insights" headings.
                    .navigationTitle("")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
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
                AppExportView(
                    session: $session,
                    liveLocation: liveLocation,
                    onOpenImport: onOpen,
                    onOpenDays: { selectedTab = 1 }
                )
                    // Empty title: AppExportView.titleHeaderSection renders its own
                    // large Text("Export") so we suppress the duplicate NavBar title.
                    .navigationTitle("")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
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
                    .accessibilityIdentifier("days.month.\(group.id)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .safeAreaInset(edge: .top, spacing: 0) {
            daysListStickyHeader
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if session.exportSelection.count > 0 {
                daysExportSelectionBar
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

    private var daysListStickyHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                compactContextPill(text: daysRangeSummaryText, icon: "calendar", identifier: "days.range")
                compactContextPill(
                    text: daySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? t("Days Search") : daySearchText,
                    icon: "magnifyingglass",
                    identifier: "days.search"
                )
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
            daysMapHeaderCard
            Divider()
                .background(LH2GPXTheme.separator)
        }
        .background(Color.black)
        .accessibilityIdentifier("days.stickyHeader")
    }

    private var daysExportSelectionBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LH2GPXTheme.primaryBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(compactExportSelectionTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(t("Open the Export tab to review or save the current selection."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(t("Export")) {
                selectedTab = 3
            }
            .buttonStyle(.borderedProminent)
            .tint(LH2GPXTheme.primaryBlue)
            .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(LH2GPXTheme.elevatedCard)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(LH2GPXTheme.separator),
            alignment: .top
        )
        .accessibilityIdentifier("days.exportBar")
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
                rangeSummaryText: daysRangeSummaryText,
                mapHeader: AnyView(daysMapHeaderCard),
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

    /// Day summaries filtered by the active range and (optionally) by favorites only.
    private var overviewFilteredDaySummaries: [DaySummary] {
        guard overviewShowOnlyFavorites else { return projectedDaySummaries }
        return projectedDaySummaries.filter { favoritedDayIDs.contains($0.date) }
    }

    @ViewBuilder
    private var overviewPaneContent: some View {
        LHPageScaffold(horizontalPadding: 18, verticalPadding: 18, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(t("Overview"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if !localizedProjectedFilterDescriptions.isEmpty {
                    LHContextBar(
                        message: localizedProjectedFilterDescriptions.joined(separator: " · "),
                        systemImage: "line.3.horizontal.decrease.circle",
                        tint: LH2GPXTheme.warningOrange
                    )
                }
            }

            AppSessionStatusView(
                summary: session.sourceSummary,
                message: session.message,
                isLoading: session.isLoading,
                hasDays: session.hasDays
            )

            // Map first — most prominent element when data is present
            if session.hasDays {
                overviewMapCard
            }

            // KPI strip immediately below the map
            if let overview = projectedOverview, let insights = projectedInsights {
                overviewKPISection(overview: overview, insights: insights)
            }

            // Range / filter controls after map and KPIs
            if session.hasDays {
                overviewRangeCard
            }

            if let insights = projectedInsights {
                overviewHighlightsCard(insights)
            }

            if session.hasDays {
                overviewContinueCard
            }

            // Empty state CTA when content is loaded but has no day entries
            if !session.hasDays && !session.isLoading {
                overviewEmptyCallToAction
            }

            liveTracksOverviewSection
        }
    }

    private var overviewEmptyCallToAction: some View {
        LHCard {
            VStack(alignment: .leading, spacing: 12) {
                LHSectionHeader(t("Get Started"))
                Text(t("Import a location history file to explore your journeys, export tracks and see insights."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onOpen) {
                    Label(t("Import File"), systemImage: "doc.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(LH2GPXTheme.primaryBlue)
                .accessibilityIdentifier("overview.empty.import")
            }
        }
        .accessibilityIdentifier("overview.empty")
    }

    private var overviewRangeCard: some View {
        LHCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    LHSectionHeader(
                        t("Time Range"),
                        subtitle: StartOverviewPresentation.rangeSummary(
                            for: session.historyDateRangeFilter,
                            language: preferences.appLanguage,
                            locale: preferences.appLocale
                        )
                    )

                    Spacer()

                    if session.historyDateRangeFilter.isActive {
                        Button(t("Reset")) {
                            session.historyDateRangeFilter.reset()
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LH2GPXTheme.primaryBlue)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    overviewRangeChip(.last7Days, identifier: "overview.range.last7Days")
                    overviewRangeChip(.last30Days, identifier: "overview.range.last30Days")
                    overviewRangeChip(.last90Days, identifier: "overview.range.last90Days")
                    overviewRangeChip(.thisYear, identifier: "overview.range.thisYear")
                }

                HStack(spacing: 8) {
                    if session.hasDays {
                        Button(t("Heatmap")) {
                            presentSheet(.heatmap)
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LH2GPXTheme.primaryBlue)
                    }

                    if !favoritedDayIDs.isEmpty {
                        LHFilterChip(
                            title: overviewShowOnlyFavorites ? t("Favorites Only") : t("All Days"),
                            systemImage: "star",
                            isActive: overviewShowOnlyFavorites
                        ) {
                            overviewShowOnlyFavorites.toggle()
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("overview.range.card")
    }

    @ViewBuilder
    private var overviewMapCard: some View {
        LHCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    LHSectionHeader(
                        t("Map"),
                        subtitle: overviewMapHeaderState.isHidden ? t("Show Map") : t("Simplified preview · export complete")
                    )
                    Spacer()
                    Button(t("Heatmap")) {
                        presentSheet(.heatmap)
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.primaryBlue)
                }

                LHCollapsibleMapHeader(
                    state: $overviewMapHeaderState,
                    language: preferences.appLanguage
                ) {
                    if #available(iOS 17.0, macOS 14.0, *) {
                        AppOverviewTracksMapView(
                            daySummaries: overviewFilteredDaySummaries,
                            content: session.content,
                            queryFilter: projectedQueryFilter,
                            fixedHeight: nil,
                            showsFullscreenControl: false
                        )
                    }
                }
                .accessibilityIdentifier("overview.map.header")
            }
        }
    }

    private func overviewRangeChip(_ preset: HistoryDateRangePreset, identifier: String) -> some View {
        LHFilterChip(
            title: t(preset.title),
            systemImage: "calendar",
            isActive: session.historyDateRangeFilter.preset == preset
        ) {
            session.historyDateRangeFilter = HistoryDateRangeFilter(preset: preset)
        }
        .accessibilityIdentifier(identifier)
    }

    private func overviewKPISection(overview: ExportOverview, insights: ExportInsights) -> some View {
        let activeDays = StartOverviewPresentation.activeDayCount(in: overviewFilteredDaySummaries)
        return LHCard {
            VStack(alignment: .leading, spacing: 12) {
                LHSectionHeader(t("Overview"))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    overviewMetricCard(
                        icon: "road.lanes",
                        label: t("Distance"),
                        value: formatDistance(insights.totalDistanceM, unit: preferences.distanceUnit),
                        color: LH2GPXTheme.primaryBlue,
                        identifier: "overview.kpi.distance"
                    )
                    overviewMetricCard(
                        icon: "calendar",
                        label: t("Active Days"),
                        value: "\(activeDays)",
                        color: LH2GPXTheme.successGreen,
                        identifier: "overview.kpi.activeDays"
                    )
                    overviewMetricCard(
                        icon: "location.north.line",
                        label: t("Routes"),
                        value: "\(overview.totalPathCount)",
                        color: LH2GPXTheme.warningOrange,
                        identifier: "overview.kpi.routes"
                    )
                    overviewMetricCard(
                        icon: "mappin.and.ellipse",
                        label: t("Places"),
                        value: "\(overview.totalVisitCount)",
                        color: LH2GPXTheme.insightPurple,
                        identifier: "overview.kpi.places"
                    )
                }
            }
        }
        .accessibilityIdentifier("overview.kpi.grid")
    }

    private func overviewMetricCard(
        icon: String,
        label: String,
        value: String,
        color: Color,
        identifier: String
    ) -> some View {
        LHMetricCard(icon: icon, label: label, value: value, color: color)
            .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func overviewHighlightsCard(_ insights: ExportInsights) -> some View {
        let mostActivities = StartOverviewPresentation.mostActivitiesHighlight(in: overviewFilteredDaySummaries)
        let hasHighlights = insights.busiestDay != nil || insights.longestDistanceDay != nil || mostActivities != nil
        if hasHighlights {
            LHCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        LHSectionHeader(t("Highlights"))
                        Spacer()
                        Button(t("Show All Insights")) {
                            navigate(for: .insights)
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LH2GPXTheme.primaryBlue)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        if let busiest = insights.busiestDay {
                            highlightRow(
                                title: t("Busiest Day"),
                                value: busiest.value,
                                detail: AppDateDisplay.mediumDate(busiest.date),
                                icon: "flame.fill"
                            )
                        }
                        if let longest = insights.longestDistanceDay {
                            highlightRow(
                                title: t("Longest Distance"),
                                value: longestDistanceValue(for: longest),
                                detail: AppDateDisplay.mediumDate(longest.date),
                                icon: "road.lanes"
                            )
                        }
                        if let mostActivities {
                            highlightRow(
                                title: t("Most Activities"),
                                value: "\(mostActivities.activityCount)",
                                detail: AppDateDisplay.mediumDate(mostActivities.date),
                                icon: "figure.walk"
                            )
                        }
                    }
                }
            }
            .accessibilityIdentifier("overview.highlights")
        }
    }

    private func highlightRow(title: String, value: String, detail: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(LH2GPXTheme.primaryBlue)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline.monospacedDigit())
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var overviewContinueCard: some View {
        LHCard {
            VStack(alignment: .leading, spacing: 10) {
                // Primary action: Browse Days — visually highlighted
                Button {
                    navigate(for: .days)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .foregroundStyle(LH2GPXTheme.primaryBlue)
                            .frame(width: 20, alignment: .center)
                            .accessibilityHidden(true)
                        Text(t("Browse Days"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LH2GPXTheme.primaryBlue.opacity(0.7))
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(LH2GPXTheme.primaryBlue.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("overview.continue.days")

                // Secondary actions
                overviewContinueButton(title: t("Open Insights"), icon: "chart.xyaxis.line", action: .insights, identifier: "overview.continue.insights")
                overviewContinueButton(title: t("Prepare Export"), icon: "square.and.arrow.up", action: .export, identifier: "overview.continue.export")
                overviewContinueButton(title: t("Import New File"), icon: "doc.badge.plus", action: .importFile, identifier: "overview.continue.import")
            }
        }
        .accessibilityIdentifier("overview.continue")
    }

    private func overviewContinueButton(
        title: String,
        icon: String,
        action: OverviewContinueAction,
        identifier: String
    ) -> some View {
        Button {
            navigate(for: action)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(LH2GPXTheme.primaryBlue)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.primaryBlue.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(LH2GPXTheme.elevatedCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
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
        let presentation = DaySummaryRowPresentationBuilder.presentation(
            for: summary,
            unit: preferences.distanceUnit,
            context: .list,
            isFavorited: favoritedDayIDs.contains(summary.date),
            isExported: session.exportSelection.isSelected(summary.date)
        )
        AppDayRow(
            summary: summary,
            highlightIcons: highlightIconsFor(summary.date),
            isSelectedForExport: session.exportSelection.isSelected(summary.date),
            isFavorited: favoritedDayIDs.contains(summary.date),
            presentation: presentation
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

    private var daysMapHeaderCard: some View {
        LHCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    LHSectionHeader(
                        t("Map"),
                        subtitle: daysMapHeaderState.isHidden ? t("Show Map") : daysRangeSummaryText
                    )
                    Spacer()
                }
                LHCollapsibleMapHeader(
                    state: $daysMapHeaderState,
                    language: preferences.appLanguage
                ) {
                    if #available(iOS 17.0, macOS 14.0, *) {
                        AppOverviewTracksMapView(
                            daySummaries: drilldownDaySummaries,
                            content: session.content,
                            queryFilter: projectedQueryFilter,
                            fixedHeight: nil,
                            showsFullscreenControl: false
                        )
                    }
                }
            }
        }
    }

    private func compactContextPill(text: String, icon: String, identifier: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(LH2GPXTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(LH2GPXTheme.elevatedCard)
        .clipShape(Capsule())
        .accessibilityIdentifier(identifier)
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
                allDaySummaries: session.daySummaries,
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
            .padding()
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
                        onOpenSavedTracks: { presentSheet(.tracksLibrary) },
                        mutations: pathMutationStore.currentMutations,
                        onRemovePath: { index in
                            pathMutationStore.addDeletion(
                                ImportedPathDeletion(dayKey: detail.date, pathIndex: index)
                            )
                        }
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
            .background(Color.black.ignoresSafeArea())
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
                    AppExportView(
                        session: $session,
                        liveLocation: liveLocation,
                        onOpenImport: onOpen
                    )
                        .environmentObject(preferences)
                        .navigationTitle("")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
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
                                .navigationTitle(t("Heatmap"))
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
        .accessibilityIdentifier("app.actionsMenu")
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
        LHCard {
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

    private func navigate(for action: OverviewContinueAction) {
        let route = StartOverviewPresentation.route(for: action, isCompact: horizontalSizeClass == .compact)
        if route.callsOnOpen {
            onOpen()
        }
        if let tab = route.selectedTab {
            selectedTab = tab
        }
        if route.presentsExportSheet {
            presentSheet(.export)
        }
    }

    private func longestDistanceValue(for highlight: DayHighlight) -> String {
        guard let summary = session.daySummaries.first(where: { $0.date == highlight.date }) else {
            return highlight.value
        }
        return formatDistance(summary.totalPathDistanceM, unit: preferences.distanceUnit)
    }
}

#endif
