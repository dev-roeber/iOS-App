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
        .tabViewBottomAccessory {
            if liveLocation.isRecording {
                LGLiveRecordingAccessory(liveModel: liveLocation) {
                    selectedTab = .live
                }
            }
        }
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
                    LHLiquidGlassHeroMark(
                        title: "LH2GPX",
                        subtitle: ""
                    )
                    .padding(.top, 4)
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
                    ? session.historyDateRangeFilter.chipLabel
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
                Label("Aktionen", systemImage: "ellipsis.circle")
            }
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

// MARK: - Live-Pille im tabViewBottomAccessory

@available(iOS 26.0, *)
private struct LGLiveRecordingAccessory: View {
    @ObservedObject var liveModel: LiveLocationFeatureModel
    let onOpenLiveTab: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .symbolEffect(.pulse, options: .repeating, value: liveModel.isRecording)
            Text("Aufnahme läuft")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(String(format: "%.2f km", liveModel.currentDistanceMeters / 1000))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Button(action: onOpenLiveTab) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.small)
            .accessibilityLabel("Live-Aufnahme öffnen")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

#endif
