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
            // iOS-26 Now-Playing-Pattern: globaler Recording-Indikator,
            // der oberhalb der TabBar als Liquid-Glass-Pill schwebt, solange
            // `liveLocation.isRecording`. Tap fuehrt zum Live-Tab.
            if liveLocation.isRecording {
                GlobalRecordingBottomAccessory(
                    liveModel: liveLocation,
                    onTap: { selectedTab = .live }
                )
            }
        }
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
                VStack(spacing: 16) {
                    if let overview = overview {
                        // F.5-A: echte Karte als immersiver Hero statt
                        // nur Stat-Cards. Wiederverwendet die bestehende
                        // `AppOverviewTracksMapView`-Implementierung, die
                        // auch auf Insights/Overview als Single Source of
                        // Truth dient.
                        AppOverviewTracksMapView(
                            daySummaries: allDaySummaries,
                            content: session.content,
                            queryFilter: nil,
                            fixedHeight: 300,
                            showsFullscreenControl: true,
                            mapControlTopPadding: 8
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                        LHPageScaffold {
                            AppOverviewGlassSection(
                                overview: overview,
                                daySummaries: allDaySummaries,
                                onDaysTap: { selectedTab = .days },
                                onInsightsTap: { selectedTab = .insights }
                            )
                        }
                    } else {
                        mapEmptyState
                    }
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .navigationTitle("Karte")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { commonToolbar }
            .background(LHLiquidGlassBackground().ignoresSafeArea())
        }
    }

    @ViewBuilder
    private var mapEmptyState: some View {
        LHPageScaffold {
            VStack(spacing: 14) {
                Image(systemName: "map")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.trackPrimary)
                Text("Keine Daten")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
                Text("Importiere eine Datei, um die Karte zu sehen.")
                    .font(.subheadline)
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                    .multilineTextAlignment(.center)
                Button(action: onOpen) {
                    Label("Datei öffnen", systemImage: "doc.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .tint(LH2GPXTheme.LiquidGlass.trackPrimary)
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.top, 40)
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
                .lgGlassPill()
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

// MARK: - Global Recording Bottom Accessory (iOS 26 Now-Playing-Pattern)
//
// Schwebt direkt oberhalb der Liquid-Glass-TabBar, solange
// `liveLocation.isRecording`. `tabViewBottomAccessoryPlacement` aus dem
// Environment steuert die Opacity: in der `.inline`-Platzierung tritt der
// Inhalt voll auf, in `.expanded` (TabBar minimiert) wird der Indikator
// auf 60% reduziert, damit das Now-Playing-Pattern den Map-/Sheet-Inhalt
// nicht stoert. Der Toolbar-Indikator (`GlobalRecordingToolbarIndicator`)
// bleibt als Fallback fuer Hosts ohne `tabViewBottomAccessory`-Support.

@available(iOS 26.0, *)
struct GlobalRecordingBottomAccessory: View {
    @EnvironmentObject private var preferences: AppPreferences
    @ObservedObject var liveModel: LiveLocationFeatureModel
    let onTap: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var distanceText: String {
        String(format: "%.2f km", liveModel.currentDistanceMeters / 1000)
    }

    private var placementOpacity: Double {
        // `.expanded` (TabBar minimiert) => Inhalt dezent halten,
        // `.inline` (TabBar voll sichtbar) => Inhalt voll aufdrehen.
        switch placement {
        case .expanded: return 0.6
        case .inline:   return 1.0
        default:        return 1.0
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .scaleEffect(pulse && !reduceMotion ? 1.35 : 1.0)
                    .opacity(pulse && !reduceMotion ? 0.55 : 1.0)
                Text(preferences.localized("Live Recording"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(distanceText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(placementOpacity)
        .task(id: liveModel.isRecording) {
            guard liveModel.isRecording, !reduceMotion else {
                pulse = false
                return
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityLabel(Text("\(preferences.localized("Live Recording")) · \(distanceText)"))
        .accessibilityHint(Text(preferences.localized("Tap to open Live tab")))
        .accessibilityIdentifier("global.recording.bottomAccessory")
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
            .lgGlassPill()
            .contentShape(Capsule())
    }
}

#endif
