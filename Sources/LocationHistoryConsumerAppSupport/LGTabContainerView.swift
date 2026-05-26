#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

@available(iOS 26.0, *)
public struct LGTabContainerView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Binding private var session: AppSessionState
    @ObservedObject private var liveLocation: LiveLocationFeatureModel
    private let onOpen: () -> Void
    private let onLoadDemo: () -> Void
    private let onClear: () -> Void
    private let onOpenOptions: () -> Void

    @State private var selectedTab: LGTab = .map
    @State private var searchText = ""
    @State private var selectedDate: String?
    @State private var dayListFilter = DayListFilter.empty
    @State private var daysNavigationPath = NavigationPath()
    @State private var favoritedDayIDs: Set<String> = []
    @State private var isExportSheetPresented = false
    @StateObject private var pathMutationStore = AppImportedPathMutationStore()

    public init(
        session: Binding<AppSessionState>,
        liveLocation: LiveLocationFeatureModel,
        onOpen: @escaping () -> Void = {},
        onLoadDemo: @escaping () -> Void = {},
        onClear: @escaping () -> Void = {},
        onOpenOptions: @escaping () -> Void = {}
    ) {
        self._session = session
        self._liveLocation = ObservedObject(wrappedValue: liveLocation)
        self.onOpen = onOpen
        self.onLoadDemo = onLoadDemo
        self.onClear = onClear
        self.onOpenOptions = onOpenOptions
    }

    public enum LGTab: Int, Hashable { case map, days, live, insights }

    // MARK: - Data sources

    private var allDaySummaries: [DaySummary] {
        session.content?.daySummaries(applying: nil) ?? session.daySummaries
    }

    private var filteredDaySummaries: [DaySummary] {
        DayListPresentation.filteredSummaries(
            allDaySummaries,
            query: searchText,
            filter: dayListFilter,
            favorites: favoritedDayIDs
        )
    }

    private var insights: ExportInsights? {
        session.insights ?? session.content?.insights(applying: nil)
    }

    private var overview: ExportOverview? {
        session.overview ?? session.content?.overview(applying: nil)
    }

    // MARK: - Body

    public var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Karte", systemImage: "map", value: LGTab.map) { mapTab }
            Tab("Tage", systemImage: "calendar", value: LGTab.days) { daysTab }
            Tab("Live", systemImage: "record.circle", value: LGTab.live) { liveTab }
            Tab("Insights", systemImage: "chart.xyaxis.line", value: LGTab.insights) { insightsTab }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isExportSheetPresented) {
            NavigationStack {
                AppExportView(
                    session: $session,
                    liveLocation: liveLocation,
                    dayListFilter: dayListFilter,
                    favoritedDayIDs: favoritedDayIDs,
                    pathMutations: pathMutationStore.currentMutations,
                    onOpenImport: onOpen,
                    onOpenDays: { selectedTab = .days; isExportSheetPresented = false },
                    heroEnabled: true
                )
                .navigationTitle("Export")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { isExportSheetPresented = false }
                    }
                }
            }
            .presentationDetents([.large])
            .presentationBackground(.regularMaterial)
        }
        .onAppear { refreshFavoritedDays() }
        .onChange(of: liveLocation.navigateToLiveTabRequested) { _, requested in
            guard requested else { return }
            selectedTab = .live
            liveLocation.navigateToLiveTabRequested = false
        }
    }

    // MARK: - Tabs

    @ViewBuilder
    private var mapTab: some View {
        NavigationStack {
            ScrollView {
                LHPageScaffold {
                    if let overview = overview {
                        AppOverviewSection(
                            overview: overview,
                            daySummaries: allDaySummaries,
                            onDaysTap: { selectedTab = .days },
                            onInsightsTap: { selectedTab = .insights }
                        )
                    } else {
                        ContentUnavailableView(
                            "Keine Daten",
                            systemImage: "map",
                            description: Text("Importiere eine Datei, um die Karte zu sehen.")
                        )
                    }
                }
            }
            .navigationTitle("Karte")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { commonToolbar }
            .background(LHLiquidGlassBackground().ignoresSafeArea())
        }
    }

    @ViewBuilder
    private var daysTab: some View {
        NavigationStack(path: $daysNavigationPath) {
            AppDayListView(
                summaries: filteredDaySummaries,
                selectedForExportDates: session.exportSelection.selectedDates,
                favoriteDayIDs: favoritedDayIDs,
                isRangeFilterActive: session.historyDateRangeFilter.isActive,
                rangeSummaryText: session.historyDateRangeFilter.isActive
                    ? session.historyDateRangeFilter.localizedChipLabel(preferences.localized)
                    : nil,
                selectedDate: Binding(
                    get: { selectedDate ?? session.selectedDate },
                    set: { newValue in
                        selectedDate = newValue
                        if let value = newValue {
                            daysNavigationPath.append(value)
                        }
                    }
                ),
                filter: $dayListFilter,
                onToggleFavorite: { toggleFavorite($0) },
                searchText: $searchText
            )
            .navigationTitle("Tage")
            .navigationDestination(for: String.self) { date in
                AppDayDetailView(
                    detail: session.content?.detail(for: date),
                    mapData: session.content?.mapData(for: date),
                    hasDays: true,
                    exportSelection: $session.exportSelection,
                    isFavorited: favoritedDayIDs.contains(date),
                    onToggleFavorite: { toggleFavorite(date) },
                    liveLocation: liveLocation,
                    onOpenSavedTracks: nil,
                    mutations: pathMutationStore.currentMutations,
                    onRemovePath: { idx in
                        pathMutationStore.addDeletion(
                            ImportedPathDeletion(dayKey: date, pathIndex: idx)
                        )
                    }
                )
            }
            .toolbar { commonToolbar }
            .background(LHLiquidGlassBackground().ignoresSafeArea())
            .searchable(text: $searchText, prompt: "Tage, Datum oder Monat")
        }
    }

    @ViewBuilder
    private var liveTab: some View {
        NavigationStack {
            AppLiveTrackingView(liveLocation: liveLocation)
                .navigationTitle("Live")
                .toolbar { commonToolbar }
        }
    }

    @ViewBuilder
    private var insightsTab: some View {
        NavigationStack {
            Group {
                if let insights = insights {
                    AppInsightsContentView(
                        insights: insights,
                        daySummaries: allDaySummaries,
                        allDaySummaries: session.daySummaries,
                        rangeFilter: $session.historyDateRangeFilter,
                        activeFilterDescriptions: [],
                        onDrilldown: nil,
                        heroContent: session.content,
                        heroQueryFilter: nil,
                        heroEnabled: true
                    )
                } else {
                    ContentUnavailableView(
                        "Keine Insights",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Importiere eine Datei, um Statistiken zu sehen.")
                    )
                }
            }
            .navigationTitle("Insights")
            .toolbar { commonToolbar }
            .background(LHLiquidGlassBackground().ignoresSafeArea())
        }
    }

    // MARK: - Common toolbar

    @ToolbarContentBuilder
    private var commonToolbar: some ToolbarContent {
        if liveLocation.isRecording {
            ToolbarItem(placement: .primaryAction) {
                GlobalRecordingToolbarIndicator(
                    liveModel: liveLocation,
                    onTap: { selectedTab = .live }
                )
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    onOpen()
                } label: {
                    Label("Datei öffnen", systemImage: "doc.badge.plus")
                }
                Button {
                    isExportSheetPresented = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .badge(session.exportSelection.count)
                Button(action: onLoadDemo) {
                    Label("Demo laden", systemImage: "testtube.2")
                }
                Divider()
                Button(action: onOpenOptions) {
                    Label("Optionen", systemImage: "slider.horizontal.3")
                }
                if session.hasLoadedContent {
                    Divider()
                    Button(role: .destructive, action: onClear) {
                        Label("Leeren", systemImage: "xmark.circle")
                    }
                }
            } label: {
                LGToolbarActionsLabel()
            }
            .accessibilityLabel(Text("Aktionen"))
            .accessibilityIdentifier("global.actions.menu")
        }
    }

    // MARK: - Helpers

    private func refreshFavoritedDays() {
        favoritedDayIDs = DayFavoritesStore.load()
    }

    private func toggleFavorite(_ date: String) {
        if favoritedDayIDs.contains(date) {
            DayFavoritesStore.remove(dayIdentifier: date)
            favoritedDayIDs.remove(date)
        } else {
            DayFavoritesStore.add(dayIdentifier: date)
            favoritedDayIDs.insert(date)
        }
    }
}

// MARK: - Global Recording Toolbar Indicator
//
// Compact pulsing pill that appears in every tab's toolbar (left of the
// actions menu) whenever `liveLocation.isRecording`. Tapping switches to
// the Live tab. Replaces the previous large `tabViewBottomAccessory` pill.

@available(iOS 26.0, *)
struct GlobalRecordingToolbarIndicator: View {
    @EnvironmentObject private var preferences: AppPreferences
    @ObservedObject var liveModel: LiveLocationFeatureModel
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var distanceText: String {
        String(format: "%.2f km", liveModel.currentDistanceMeters / 1000)
    }

    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .scaleEffect(pulse && !reduceMotion ? 1.35 : 1.0)
                .opacity(pulse && !reduceMotion ? 0.55 : 1.0)
                .frame(minWidth: 44, minHeight: 30)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .task(id: liveModel.isRecording) {
            guard liveModel.isRecording, !reduceMotion else {
                pulse = false
                return
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityLabel(Text("\(preferences.localized("Recording in progress")) · \(distanceText)"))
        .accessibilityHint(Text(preferences.localized("Tap to open Live tab")))
        .accessibilityIdentifier("global.recording.indicator")
    }
}

// MARK: - Toolbar Actions Label
//
// Liquid-Glass-konsistentes Label für das primaryAction-Menu („•••").
// Capsule mit `.ultraThinMaterial` + hairline stroke, passend zum
// `GlobalRecordingToolbarIndicator`. Tap-Target ≥ 44pt via frame.
public struct LGToolbarActionsLabel: View {
    public init() {}
    public var body: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(LH2GPXTheme.LiquidGlass.trackPrimary)
            .frame(minWidth: 44, minHeight: 30)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8))
            .contentShape(Capsule())
    }
}

#endif
