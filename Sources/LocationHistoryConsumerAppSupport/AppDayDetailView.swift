#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer
#if canImport(MapKit)
import MapKit
#endif

// MARK: - Day Detail

public struct AppDayDetailView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let detail: DayDetailViewState?
    let mapData: DayMapData?
    let hasDays: Bool
    let onBackToOverview: (() -> Void)?
    @Binding private var exportSelection: ExportSelectionState
    let isFavorited: Bool
    let onToggleFavorite: (() -> Void)?
    let liveLocation: LiveLocationFeatureModel?
    let onOpenSavedTracks: (() -> Void)?
    let mutations: ImportedPathMutationSet
    let onRemovePath: ((Int) -> Void)?
    @State private var confirmRemovePathIndex: Int? = nil
    @State private var selectedSegment: DayDetailSegment = .overview
    /// Toggles for the Tempo / Höhe overlay bands rendered inside the
    /// multi-layer bottom sheet. Independent from the radio
    /// `mapTrackColorMode` so a user can see the band even when the map
    /// shows activity colours. Mirrors `AppLiveTrackingView`'s additive
    /// layer toggles.
    @State private var showTempoBand: Bool = false
    @State private var showElevationBand: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var segmentNamespace
    @StateObject private var dayMapCamera = AppDayMapCameraController()

    public init(
        detail: DayDetailViewState?,
        mapData: DayMapData? = nil,
        hasDays: Bool,
        onBackToOverview: (() -> Void)? = nil,
        exportSelection: Binding<ExportSelectionState> = .constant(ExportSelectionState()),
        isFavorited: Bool = false,
        onToggleFavorite: (() -> Void)? = nil,
        liveLocation: LiveLocationFeatureModel? = nil,
        onOpenSavedTracks: (() -> Void)? = nil,
        mutations: ImportedPathMutationSet = .empty,
        onRemovePath: ((Int) -> Void)? = nil
    ) {
        self.detail = detail
        self.mapData = mapData
        self.hasDays = hasDays
        self.onBackToOverview = onBackToOverview
        self._exportSelection = exportSelection
        self.isFavorited = isFavorited
        self.onToggleFavorite = onToggleFavorite
        self.liveLocation = liveLocation
        self.onOpenSavedTracks = onOpenSavedTracks
        self.mutations = mutations
        self.onRemovePath = onRemovePath
    }

    init(detail: DayDetailViewState) {
        self.detail = detail
        self.mapData = nil
        self.hasDays = true
        self.onBackToOverview = nil
        self._exportSelection = .constant(ExportSelectionState())
        self.isFavorited = false
        self.onToggleFavorite = nil
        self.liveLocation = nil
        self.onOpenSavedTracks = nil
        self.mutations = .empty
        self.onRemovePath = nil
    }

    public var body: some View {
        Group {
            if let detail {
                if detail.hasContent {
                    contentView(detail)
                } else {
                    emptyDayState(
                        t("Nothing Recorded"),
                        message: t("This day has no visits, activities or paths in the export."),
                        recovery: onBackToOverview
                    )
                }
            } else if hasDays {
                emptyDayState(
                    t("Select a Day"),
                    message: t("Choose a day from the list to view details.")
                )
            } else {
                emptyDayState(
                    t("No Day Entries"),
                    message: t("Import a file with day entries to view details.")
                )
            }
        }
        .alert(
            t("Remove Route"),
            isPresented: Binding(
                get: { confirmRemovePathIndex != nil },
                set: { if !$0 { confirmRemovePathIndex = nil } }
            )
        ) {
            Button(t("Remove"), role: .destructive) {
                if let idx = confirmRemovePathIndex {
                    onRemovePath?(idx)
                }
                confirmRemovePathIndex = nil
            }
            .accessibilityIdentifier("dayDetail.removeRoute.confirm")
            Button(t("Cancel"), role: .cancel) {
                confirmRemovePathIndex = nil
            }
            .accessibilityIdentifier("dayDetail.removeRoute.cancel")
        } message: {
            Text(t("This route will be hidden from this day. The original data is not modified."))
        }
    }

    @ViewBuilder
    private func contentView(_ detail: DayDetailViewState) -> some View {
        let filteredDetail = detail.removingDeletedPaths(for: mutations)
        let resolvedMapData = DayMapDataExtractor.mapData(from: filteredDetail)

        if verticalSizeClass == .compact {
            // Landscape (iPhone) — side-by-side: map left, content right
            HStack(spacing: 0) {
                landscapeMapColumn(detail: filteredDetail, resolvedMapData: resolvedMapData)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                ScrollView {
                    landscapeContentColumn(filteredDetail)
                        .padding()
                }
                .frame(maxWidth: 360)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Portrait — Multi-Layer pattern (Phase 3a): full-bleed map +
            // floating left layer panel + right control stack + bottom-sheet
            // that hosts the day headline, KPIs, segment picker and segmented
            // content. Mirrors AppLiveTrackingView's multi-layer portrait
            // layout while preserving DayDetail's existing data model.
            if #available(iOS 26.0, *) {
                // Phase B-2 (Train F.7): scaffolded layout on iOS 26+.
                // The legacy `multiLayerPortraitLayout` below stays as the
                // iOS-17/25 fallback and as a one-line revert path.
                scaffoldedDayDetailLayout(detail: filteredDetail, resolvedMapData: resolvedMapData)
            } else if #available(iOS 17.0, macOS 14.0, *) {
                multiLayerPortraitLayout(detail: filteredDetail, resolvedMapData: resolvedMapData)
            } else {
                // Pre-iOS 17 fallback: previous scroll layout without the
                // hero map (Map(position:) requires iOS 17).
                ScrollView {
                    portraitContentView(detail: filteredDetail, resolvedMapData: resolvedMapData)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                }
                .background(Color(.systemBackground))
            }
        }
    }

    // MARK: - Phase B-2 (Train F.7): Scaffolded DayDetail Layout (iOS 26+)
    //
    // Wraps the existing `multiLayerMapBackground`, `DayDetailLayerPanel`,
    // `DayDetailControlStack` and bottom-sheet content into the shared
    // `LHMapFirstPageScaffold` + `LHMapFloatingChrome` +
    // `LHGlassBottomSheetDashboard` components. Favorit-, Export-, Route-
    // Display-, Timeline-/Routes-/Places- und ImportedPath-Mutation-Wirings
    // bleiben aus dem Legacy-Pfad unveraendert — nur die aeussere
    // Komposition wechselt auf das Shared-System.

    @available(iOS 26.0, *)
    @ViewBuilder
    private func scaffoldedDayDetailLayout(
        detail: DayDetailViewState,
        resolvedMapData: DayMapData
    ) -> some View {
        let bottomSafe = lhDeviceBottomSafeInset()
        let clearance = LHMapBase.bottomSheetTabBarClearance(
            deviceBottomSafeInset: bottomSafe
        )
        LHMapFirstPageScaffold(
            topSafeInset: lhDeviceTopSafeInset(),
            bottomSafeInset: bottomSafe,
            sheetBottomClearance: clearance
        ) {
            multiLayerMapBackground(resolvedMapData: resolvedMapData)
        } floatingChrome: {
            LHMapFloatingChrome(
                topSafeInset: lhDeviceTopSafeInset(),
                accessibilityPrefix: "dayDetail.scaffold"
            ) {
                DayDetailLayerPanel(
                    selected: $preferences.mapTrackColorMode,
                    routeDisplay: $preferences.dayPathDisplayMode,
                    showTempoBand: $showTempoBand,
                    showElevationBand: $showElevationBand,
                    hasPaths: !detail.paths.isEmpty,
                    layersLabel: dayDetailLayersPanelLabel,
                    standardLabel: t("Standard"),
                    speedLabel: t("Speed"),
                    elevationLabel: t("Elevation"),
                    weatherLabel: t("Weather prepared"),
                    routeDisplayLabel: t("Route Display"),
                    routeOriginalLabel: t("Original"),
                    routeSimplifiedLabel: t("Simplified")
                )
            } controls: {
                DayDetailControlStack(
                    onFitToData: { dayMapCamera.fitToData?() },
                    onZoomIn: { dayMapCamera.adjustZoom?(0.5) },
                    onZoomOut: { dayMapCamera.adjustZoom?(2.0) },
                    compassLabel: t("Fit to Data"),
                    zoomInLabel: t("Zoom in"),
                    zoomOutLabel: t("Zoom out"),
                    fitLabel: t("Fit to Data")
                )
            }
        } sheet: {
            LHGlassBottomSheetDashboard(
                // B-5.5 Visual Hardening: dedizierte `.dayDetail`-Detents
                // statt generischer `.portrait`. Mehr Headroom fuer den
                // Segmented-Content + KPI-Grid + Bands.
                detents: .dayDetail,
                initialDetent: .medium,
                bottomClearance: clearance,
                accessibilityPrefix: "dayDetail.scaffold.sheet"
            ) {
                scaffoldedSheetHeader(detail: detail)
            } body: {
                scaffoldedSheetBody(detail: detail)
            }
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private func scaffoldedSheetHeader(detail: DayDetailViewState) -> some View {
        // Phase D-0: Caption + Headline auf mapGlass-Tokens umgestellt,
        // damit Sheet-Header auf dunklem Glas zuverlaessig lesbar bleibt.
        VStack(alignment: .leading, spacing: 2) {
            Text(t("DAY · DETAIL"))
                .font(.caption2.weight(.heavy))
                .tracking(0.7)
                .foregroundStyle(LH2GPXTheme.LiquidGlass.mapGlassCaptionText)
            Text(bottomSheetHeadline(detail))
                .font(.title3.weight(.bold))
                .foregroundStyle(LH2GPXTheme.LiquidGlass.mapGlassPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private func scaffoldedSheetBody(detail: DayDetailViewState) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppDateDisplay.weekday(detail.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("dayDetail.weekday")
                dayTimeRange(detail)
            }
            metricGrid(detail)
            overlayBands(detail)
            dayActionsSection(detail)
            segmentControl(detail)
            segmentedContent(detail)

            if let liveLocation {
                detailContextHeader(
                    t("Local Recording"),
                    message: t("Live location and saved live tracks stay separate from the imported day data above.")
                )
                AppLiveLocationSection(
                    liveLocation: liveLocation,
                    onOpenSavedTracksLibrary: onOpenSavedTracks
                )
            }
        }
        .accessibilityIdentifier("dayDetail.scaffold.sheet.body")
    }

    // MARK: - Multi-Layer Portrait Layout (Phase 3a)

    @available(iOS 17.0, macOS 14.0, *)
    @ViewBuilder
    private func multiLayerPortraitLayout(detail: DayDetailViewState, resolvedMapData: DayMapData) -> some View {
        ZStack(alignment: .top) {
            multiLayerMapBackground(resolvedMapData: resolvedMapData)
                .ignoresSafeArea()

            LGGlassEffectGroup(spacing: 8) {
            HStack(alignment: .top, spacing: 0) {
                DayDetailLayerPanel(
                    selected: $preferences.mapTrackColorMode,
                    routeDisplay: $preferences.dayPathDisplayMode,
                    showTempoBand: $showTempoBand,
                    showElevationBand: $showElevationBand,
                    hasPaths: !detail.paths.isEmpty,
                    layersLabel: dayDetailLayersPanelLabel,
                    standardLabel: t("Standard"),
                    speedLabel: t("Speed"),
                    elevationLabel: t("Elevation"),
                    weatherLabel: t("Weather prepared"),
                    routeDisplayLabel: t("Route Display"),
                    routeOriginalLabel: t("Original"),
                    routeSimplifiedLabel: t("Simplified")
                )
                .padding(.leading, LHMapBase.floatingControlSideInset)
                .padding(.top, LHMapBase.floatingControlTopInset(deviceTopSafeInset: lhDeviceTopSafeInset()))

                Spacer()

                DayDetailControlStack(
                    onFitToData: { dayMapCamera.fitToData?() },
                    onZoomIn: { dayMapCamera.adjustZoom?(0.5) },
                    onZoomOut: { dayMapCamera.adjustZoom?(2.0) },
                    compassLabel: t("Fit to Data"),
                    zoomInLabel: t("Zoom in"),
                    zoomOutLabel: t("Zoom out"),
                    fitLabel: t("Fit to Data")
                )
                .padding(.trailing, LHMapBase.floatingControlSideInset)
                .padding(.top, LHMapBase.floatingControlTopInset(deviceTopSafeInset: lhDeviceTopSafeInset()))
            }
            } // LGGlassEffectGroup
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            multiLayerBottomSheet(detail: detail)
        }
    }

    @available(iOS 17.0, macOS 14.0, *)
    @ViewBuilder
    private func multiLayerMapBackground(resolvedMapData: DayMapData) -> some View {
        if resolvedMapData.hasMapContent {
            AppDayMapView(
                mapData: resolvedMapData,
                fillHeight: true,
                hidesBuiltInControls: true,
                fullBleed: true,
                cameraController: dayMapCamera
            )
            .accessibilityIdentifier("dayDetail.map")
        } else {
            ZStack {
                Color.secondary.opacity(0.10)
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text(t("No map data for this day."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("dayDetail.map.placeholder")
        }
    }

    @available(iOS 17.0, macOS 14.0, *)
    @ViewBuilder
    private func multiLayerBottomSheet(detail: DayDetailViewState) -> some View {
        LiveBottomSheet(
            headerCaption: t("DAY · DETAIL"),
            headlineText: bottomSheetHeadline(detail),
            headlineTint: LH2GPXTheme.LiquidGlass.ink,
            bottomClearance: LHMapBase.bottomSheetTabBarClearance(
                deviceBottomSafeInset: lhDeviceBottomSafeInset()
            )
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Compact weekday + time-range underline below the bold headline.
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppDateDisplay.weekday(detail.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("dayDetail.weekday")
                    dayTimeRange(detail)
                }
                metricGrid(detail)
                overlayBands(detail)
                dayActionsSection(detail)
                segmentControl(detail)
                segmentedContent(detail)

                if let liveLocation {
                    detailContextHeader(
                        t("Local Recording"),
                        message: t("Live location and saved live tracks stay separate from the imported day data above.")
                    )
                    AppLiveLocationSection(
                        liveLocation: liveLocation,
                        onOpenSavedTracksLibrary: onOpenSavedTracks
                    )
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .accessibilityIdentifier("dayDetail.bottomSheet")
    }

    /// Stacks the speed band + elevation profile under the KPIs whenever
    /// the matching layer toggle in the `DayDetailLayerPanel` is on.
    /// Order is Tempo → Höhe so a single active band stays "primary".
    /// Empty path geometry → the components render their own empty state
    /// (no manual fallback needed here).
    @ViewBuilder
    private func overlayBands(_ detail: DayDetailViewState) -> some View {
        let speeds = showTempoBand ? DayDetailOverlayBands.speedSamples(from: detail) : []
        let elevations = showElevationBand ? DayDetailOverlayBands.elevationSamples(from: detail) : []
        VStack(spacing: 10) {
            if showTempoBand {
                AppSpeedBandView(
                    speeds: speeds,
                    unit: .metersPerSecond,
                    highlightTimestamp: nil,
                    title: t("Speed")
                )
                .accessibilityIdentifier("dayDetail.speedBand")
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if showElevationBand {
                AppElevationProfileView(
                    points: elevations,
                    title: t("Elevation")
                )
                .accessibilityIdentifier("dayDetail.elevationProfile")
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: showTempoBand)
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: showElevationBand)
    }

    /// Day headline = long date + distance summary (when paths exist), shown
    /// as the bold accent inside the bottom sheet.
    private func bottomSheetHeadline(_ detail: DayDetailViewState) -> String {
        let date = AppDateDisplay.longDate(detail.date)
        let totalMeters = detail.paths.compactMap(\.distanceM).reduce(0, +)
            + detail.activities.compactMap(\.distanceM).reduce(0, +)
        guard totalMeters > 0 else { return date }
        let distance = formatDistance(totalMeters, unit: preferences.distanceUnit)
        return "\(date) · \(distance)"
    }

    @ViewBuilder
    private func landscapeMapColumn(detail: DayDetailViewState, resolvedMapData: DayMapData) -> some View {
        VStack(spacing: 0) {
            #if canImport(MapKit)
            if #available(iOS 17.0, macOS 14.0, *) {
                mapControlRow(detail: detail, resolvedMapData: resolvedMapData, fillHeight: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Label(t("Map view requires iOS 17 or later."), systemImage: "map")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            #else
            Color.secondary.opacity(0.1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            #endif
        }
    }

    @ViewBuilder
    private func landscapeContentColumn(_ detail: DayDetailViewState) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppDateDisplay.weekday(detail.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(AppDateDisplay.longDate(detail.date))
                    .font(.title3.weight(.semibold))
                dayTimeRange(detail)
            }
            metricGrid(detail)
            dayActionsSection(detail)
            segmentControl(detail)
            segmentedContent(detail)
            if let liveLocation {
                detailContextHeader(
                    t("Local Recording"),
                    message: t("Live location and saved live tracks stay separate from the imported day data above.")
                )
                if #available(iOS 17.0, macOS 14.0, *) {
                    AppLiveLocationSection(
                        liveLocation: liveLocation,
                        onOpenSavedTracksLibrary: onOpenSavedTracks
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func portraitContentView(detail: DayDetailViewState, resolvedMapData: DayMapData) -> some View {
        // Map and date/time-range header now live in the sticky hero header / filter
        // panel above this scroll content. Empty-state branches still bypass this view.
        VStack(alignment: .leading, spacing: 24) {
            metricGrid(detail)
            dayActionsSection(detail)
            segmentControl(detail)
            segmentedContent(detail)

            if let liveLocation {
                detailContextHeader(
                    t("Local Recording"),
                    message: t("Live location and saved live tracks stay separate from the imported day data above.")
                )
                if #available(iOS 17.0, macOS 14.0, *) {
                    AppLiveLocationSection(
                        liveLocation: liveLocation,
                        onOpenSavedTracksLibrary: onOpenSavedTracks
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

/// Combined control row: route-display picker (when paths exist) + map style toggle,
    /// followed by the map itself. The map's built-in style toggle is suppressed so both
    /// controls sit in one horizontal strip above the map.
    @available(iOS 17.0, macOS 14.0, *)
    @ViewBuilder
    private func mapControlRow(
        detail: DayDetailViewState,
        resolvedMapData: DayMapData,
        fillHeight: Bool = false
    ) -> some View {
        VStack(spacing: 6) {
            if !detail.paths.isEmpty {
                HStack(spacing: 8) {
                    Picker(t("Route Display"), selection: $preferences.dayPathDisplayMode) {
                        ForEach(AppDayPathDisplayMode.allCases) { mode in
                            Text(t(mode.label)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("dayDetail.routeDisplay.control")
                    .accessibilityHint(Text(t("Switches between simplified and full route rendering on the day map.")))
                }
                .padding(.horizontal, fillHeight ? 12 : 0)
                .padding(.top, fillHeight ? 12 : 0)
            }
            AppDayMapView(mapData: resolvedMapData, fillHeight: fillHeight)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("dayDetail.map")
        }
    }

    @ViewBuilder
    private func metricGrid(_ detail: DayDetailViewState) -> some View {
        let items = DayDetailPresentation.kpis(detail: detail, unit: preferences.distanceUnit)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(items) { item in
                LHMetricCard(
                    icon: item.icon,
                    label: t(item.label),
                    value: item.value,
                    color: metricColor(for: item.id)
                )
                .accessibilityIdentifier("dayDetail.metric.\(item.id)")
            }
        }
    }

    @ViewBuilder
    private func segmentControl(_ detail: DayDetailViewState) -> some View {
        let segments = DayDetailPresentation.segments(detail: detail)
        HStack(spacing: 8) {
            ForEach(segments) { segment in
                Button {
                    selectedSegment = segment
                } label: {
                    Text(t(segment.title))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedSegment == segment ? AnyShapeStyle(.primary) : AnyShapeStyle(LH2GPXTheme.textSecondary))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .background(
                            ZStack {
                                Capsule().fill(LH2GPXTheme.elevatedCard)
                                if selectedSegment == segment {
                                    Capsule()
                                        .fill(LH2GPXTheme.liveMint)
                                        .matchedGeometryEffect(id: "segmentPill", in: segmentNamespace)
                                }
                            }
                        )
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(segmentIdentifier(segment))
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: selectedSegment)
    }

    @ViewBuilder
    private func segmentedContent(_ detail: DayDetailViewState) -> some View {
        switch selectedSegment {
        case .overview:
            overviewSegment(detail)
        case .timeline:
            timelineSegment(detail)
        case .routes:
            routesSegment(detail)
        case .places:
            placesSegment(detail)
        }
    }

    @ViewBuilder
    private func overviewSegment(_ detail: DayDetailViewState) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            timelineCard(detail)
            if !detail.activities.isEmpty {
                detailSection(t("Activities"), icon: "figure.walk", count: detail.activities.count) {
                    ForEach(Array(detail.activities.prefix(3).enumerated()), id: \.offset) { _, activity in
                        activityCard(activity)
                    }
                }
            }
            if !detail.visits.isEmpty {
                detailSection(t("Places"), icon: "mappin.and.ellipse", count: detail.visits.count) {
                    ForEach(Array(detail.visits.prefix(3).enumerated()), id: \.offset) { _, visit in
                        visitCard(visit)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func timelineSegment(_ detail: DayDetailViewState) -> some View {
        timelineCard(detail)
        if !detail.activities.isEmpty {
            detailSection(t("Activities"), icon: "figure.walk", count: detail.activities.count) {
                ForEach(Array(detail.activities.enumerated()), id: \.offset) { _, activity in
                    activityCard(activity)
                }
            }
        }
    }

    @ViewBuilder
    private func routesSegment(_ detail: DayDetailViewState) -> some View {
        let visibleRoutes = Array(detail.paths.enumerated())
        detailSection(t("Routes"), icon: "location.north.line", count: visibleRoutes.count) {
            routeSelectionSummary(detail)
            ForEach(visibleRoutes, id: \.offset) { item in
                pathCard(
                    item.element,
                    dayIdentifier: detail.date,
                    routeIndex: item.offset,
                    availableRouteIndices: exportableRouteIndices(for: detail),
                    onRemove: onRemovePath != nil ? { confirmRemovePathIndex = item.offset } : nil
                )
            }
        }
    }

    @ViewBuilder
    private func placesSegment(_ detail: DayDetailViewState) -> some View {
        detailSection(t("Places"), icon: "mappin.and.ellipse", count: detail.visits.count) {
            ForEach(Array(detail.visits.enumerated()), id: \.offset) { _, visit in
                visitCard(visit)
            }
        }
    }

    @ViewBuilder
    private func timelineCard(_ detail: DayDetailViewState) -> some View {
        let entries = DayDetailPresentation.timeline(detail: detail)
        LHCard {
            VStack(alignment: .leading, spacing: 10) {
                LHSectionHeader(t("Day Timeline"))
                ForEach(entries) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(timelineColor(for: entry.kind))
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t(entry.title))
                                .font(.subheadline.weight(.semibold))
                            if let subtitle = entry.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let timeText = entry.timeText {
                            Text(timeText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("dayDetail.timeline")
        .accessibilityHint(Text(t("Chronological list of visits and activities for this day. Tap a row to reveal more details.")))
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
                    .font(.headline.weight(.semibold))
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
    private func detailContextHeader(_ title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func dayActionsSection(_ detail: DayDetailViewState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Day Actions"))
                .font(.title3.weight(.semibold))

            HStack(spacing: 10) {
                if let onToggleFavorite {
                    Button(action: onToggleFavorite) {
                        Label(
                            isFavorited ? t("Remove Favorite") : t("Add Favorite"),
                            systemImage: isFavorited ? "star.slash.fill" : "star.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(isFavorited ? .gray : .yellow)
                }

                Button {
                    exportSelection.toggle(detail.date)
                } label: {
                    Label(
                        exportSelection.isSelected(detail.date) ? t("Remove Day from Export") : t("Add Day to Export"),
                        systemImage: exportSelection.isSelected(detail.date) ? "square.and.arrow.up.fill" : "square.and.arrow.up"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("dayDetail.routeSelection")
            }

            if !detail.paths.isEmpty {
                Text(routeSelectionStatus(detail))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func routeSelectionSummary(_ detail: DayDetailViewState) -> some View {
        let exportableIndices = exportableRouteIndices(for: detail)
        if exportableIndices.isEmpty {
            Label(t("No exportable routes are available for this day."), systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(t("Route Export"), systemImage: "line.3.horizontal.decrease.circle")
                        .font(.subheadline.weight(.medium))
                    Text(routeSelectionStatus(detail))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if exportSelection.routeSelections[detail.date] != nil {
                    Button(t("Reset to All Routes")) {
                        exportSelection.clearRouteSelection(day: detail.date)
                    }
                    .font(.caption.weight(.medium))
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func visitCard(_ visit: DayDetailViewState.VisitItem) -> some View {
        coloredCard(color: CardAccent.visit) {
            HStack(spacing: 6) {
                Image(systemName: iconForVisitType(visit.semanticType))
                    .foregroundColor(CardAccent.visit)
                    .font(.subheadline)
                Text(t(visit.semanticType?.capitalized ?? "Visit"))
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
                Text(displayNameForActivityType(activity.activityType, language: preferences.appLanguage))
                    .font(.subheadline.weight(.medium))
            }
            HStack(spacing: 12) {
                if let start = activity.startTime, let end = activity.endTime {
                    Label("\(AppTimeDisplay.time(start)) – \(AppTimeDisplay.time(end))", systemImage: "clock")
                }
                if let dist = activity.distanceM {
                    Label(formatDistance(dist, unit: preferences.distanceUnit), systemImage: "ruler")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func pathCard(
        _ path: DayDetailViewState.PathItem,
        dayIdentifier: String,
        routeIndex: Int,
        availableRouteIndices: Set<Int>,
        onRemove: (() -> Void)? = nil
    ) -> some View {
        let isExportable = availableRouteIndices.contains(routeIndex)
        let hasExplicitSelection = exportSelection.routeSelections[dayIdentifier] != nil
        let isSelected = isExportable && exportSelection.isRouteSelected(day: dayIdentifier, routeIndex: routeIndex)

        coloredCard(color: CardAccent.path) {
            HStack(alignment: .top, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: iconForActivityType(path.activityType))
                        .foregroundColor(CardAccent.path)
                        .font(.subheadline)
                    Text(displayNameForActivityType(path.activityType, default: t("Route"), language: preferences.appLanguage))
                        .font(.subheadline.weight(.medium))
                }
                Spacer()
                if isExportable {
                    Button {
                        if !exportSelection.isSelected(dayIdentifier) {
                            exportSelection.toggle(dayIdentifier)
                        }
                        exportSelection.toggleRoute(
                            day: dayIdentifier,
                            routeIndex: routeIndex,
                            availableRouteIndices: availableRouteIndices
                        )
                    } label: {
                        Label(
                            routeSelectionLabel(isSelected: isSelected, hasExplicitSelection: hasExplicitSelection),
                            systemImage: isSelected ? "checkmark.circle.fill" : "circle"
                        )
                        .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .accessibilityLabel(routeSelectionLabel(isSelected: isSelected, hasExplicitSelection: hasExplicitSelection))
                } else {
                    Image(systemName: "slash.circle")
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel(t("Route unavailable for export"))
                }
            }
            HStack(spacing: 12) {
                Label(pointCountText(path.pointCount), systemImage: "location.north.line")
                if let dist = path.distanceM {
                    Label(formatDistance(dist, unit: preferences.distanceUnit), systemImage: "ruler")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if isExportable {
                Text(routeSelectionHint(isSelected: isSelected, hasExplicitSelection: hasExplicitSelection))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(t("This route has no exportable geometry."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let onRemove {
                Divider()
                    .padding(.vertical, 2)
                Button(role: .destructive, action: onRemove) {
                    Label(t("Remove Route"), systemImage: "trash")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .accessibilityIdentifier("dayDetail.removeRoute")
            }
        }
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
                    Label(t("Back to Overview"), systemImage: "chevron.backward")
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    /// "LAYERS n/4" label for the DayDetail layer panel — mirrors the Live
    /// and Insights tabs so the affordance is identical across the map-first
    /// screens. Counts: Standard (when not Speed-coloured) / Tempo (when
    /// Speed-coloured *or* Tempo band visible) / Höhe (band visible) /
    /// Wetter (placeholder slot, currently always off on DayDetail).
    private var dayDetailLayersPanelLabel: String {
        let standardActive = preferences.mapTrackColorMode != .speed
        let speedActive = preferences.mapTrackColorMode == .speed || showTempoBand
        let count =
            (standardActive ? 1 : 0)
            + (speedActive ? 1 : 0)
            + (showElevationBand ? 1 : 0)
            + 0
        return LHMapBase.layersBadge(localizedLayersWord: t("LAYERS"), activeCount: count)
    }

    private func metricColor(for identifier: String) -> Color {
        switch identifier {
        case "distance": return LH2GPXTheme.distancePurple
        case "routes": return LH2GPXTheme.routeOrange
        case "activities": return LH2GPXTheme.primaryBlue
        case "places": return LH2GPXTheme.liveMint
        default: return LH2GPXTheme.primaryBlue
        }
    }

    private func timelineColor(for kind: DayDetailTimelineEntryPresentation.Kind) -> Color {
        switch kind {
        case .start, .end: return LH2GPXTheme.primaryBlue
        case .drive: return LH2GPXTheme.routeOrange
        case .visit: return LH2GPXTheme.liveMint
        }
    }

    private func segmentIdentifier(_ segment: DayDetailSegment) -> String {
        switch segment {
        case .overview: return "dayDetail.segment.overview"
        case .timeline: return "dayDetail.segment.timeline"
        case .routes: return "dayDetail.segment.routes"
        case .places: return "dayDetail.segment.places"
        }
    }

    private func pointCountText(_ count: Int) -> String {
        preferences.appLanguage.isGerman
            ? "\(count) \(count == 1 ? "Punkt" : "Punkte")"
            : "\(count) \(count == 1 ? "point" : "points")"
    }

    private func exportableRouteIndices(for detail: DayDetailViewState) -> Set<Int> {
        Set(
            detail.paths.enumerated().compactMap { index, path in
                let rawPath = Path(
                    startTime: path.startTime,
                    endTime: path.endTime,
                    activityType: path.activityType,
                    distanceM: path.distanceM,
                    sourceType: "day_detail",
                    points: path.points.map {
                        PathPoint(
                            lat: $0.lat,
                            lon: $0.lon,
                            time: $0.time,
                            accuracyM: $0.accuracyM
                        )
                    },
                    flatCoordinates: nil
                )
                return ExportRouteSanitizer.sanitizedPath(rawPath) == nil ? nil : index
            }
        )
    }

    private func routeSelectionStatus(_ detail: DayDetailViewState) -> String {
        let exportableIndices = exportableRouteIndices(for: detail)
        guard !exportableIndices.isEmpty else {
            return t("No exportable routes are available for this day.")
        }

        if let explicitSelection = exportSelection.routeSelections[detail.date] {
            let selectedCount = explicitSelection.intersection(exportableIndices).count
            if preferences.appLanguage.isGerman {
                return "\(selectedCount) von \(exportableIndices.count) exportierbaren \(exportableIndices.count == 1 ? "Route" : "Routen") ausgewählt. Besuche und Aktivitäten bleiben vom Exportmodus abhängig."
            }
            return "\(selectedCount) of \(exportableIndices.count) exportable route\(exportableIndices.count == 1 ? "" : "s") selected. Visits and activities still follow the export mode."
        }

        if preferences.appLanguage.isGerman {
            return "Standardmäßig sind alle \(exportableIndices.count) exportierbaren \(exportableIndices.count == 1 ? "Route" : "Routen") enthalten. Tippe auf eine Route, um auf eine benutzerdefinierte Auswahl umzuschalten."
        }
        return "All \(exportableIndices.count) exportable route\(exportableIndices.count == 1 ? "" : "s") are included by default. Tap a route to switch to a custom subset."
    }

    private func routeSelectionLabel(isSelected: Bool, hasExplicitSelection: Bool) -> String {
        if hasExplicitSelection {
            return isSelected ? t("Selected for Export") : t("Not Selected for Export")
        }
        return t("Included by default")
    }

    private func routeSelectionHint(isSelected: Bool, hasExplicitSelection: Bool) -> String {
        if preferences.appLanguage.isGerman {
            if hasExplicitSelection {
                return isSelected ? "Tippe, um diese Route aus der Exportauswahl zu entfernen." : "Tippe, um diese Route zur Exportauswahl hinzuzufügen."
            }
            return "Tippe, um eine benutzerdefinierte Routenauswahl für diesen Tag zu starten."
        }
        if hasExplicitSelection {
            return isSelected ? "Tap to remove this route from the export subset." : "Tap to add this route to the export subset."
        }
        return "Tap to start a custom route subset for this day."
    }
}

#endif
