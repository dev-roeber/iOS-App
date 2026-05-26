#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

@available(iOS 17.0, macOS 14.0, *)
public struct AppLiveTrackingView: View {
    private struct LiveTrackRenderSignature: Equatable {
        let count: Int
        let firstTimestamp: Date?
        let lastTimestamp: Date?
    }

    @EnvironmentObject private var preferences: AppPreferences
    @ObservedObject private var liveLocation: LiveLocationFeatureModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var hasSeededMap = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var dashboardTimer: Timer?
    @State private var recordingStartDate: Date?
    @State private var now = Date()
    @State private var metricSnapshot = LiveTrackingMetricSnapshot.empty
    @State private var polylineCoordinates: [CLLocationCoordinate2D] = []
    @State private var trackSamples: [TrackSample] = []
    @State private var liveRenderWasCapped: Bool = false
    @State private var lastCameraUpdate: (timestamp: Date, coordinate: LiveCameraUpdateThrottle.Coordinate)?
    @State private var recordButtonState: LGRecordState = .ready

    /// Hard cap on how many `liveTrackPoints` are sent into the SwiftUI/MapKit
    /// render path per frame. Train H-Wire-1 (2026-05-16). Pure render-side
    /// optimization — raw `liveLocation.liveTrackPoints`, persistence
    /// (`LiveTrackRecorder` / `RecordedTrack`) and export are unaffected.
    /// 10 000 chosen to match the existing `uploadQueueLimit` budget so the
    /// mental model stays consistent across the codebase.
    private static let liveRenderPointCap: Int = 10_000
    @State private var isFullscreenMapPresented = false
    @State private var isDiagnosticsExpanded = false
    // Phase 19.28 multi-layer redesign state. `isCompactMap` collapses the
    // full-bleed map to 1/3 screen height (eyes-fold control). `showWeather`
    // and `showElevation` mirror future overlay toggles surfaced by the new
    // LiveLayerPanel; they are display-only flags today and do not change
    // recording or persistence behaviour.
    @State private var isCompactMap: Bool = false
    @State private var showWeatherLayer: Bool = false
    @State private var showElevationLayer: Bool = false
    @State private var liveMapHeaderState = LHMapHeaderState(
        visibility: .compact,
        compactHeight: LHHeroMapLayout.compactHeight,
        expandedHeight: LHHeroMapLayout.expandedHeight,
        isSticky: true
    )

    private let onOpenSavedTracksLibrary: (() -> Void)?

    public init(
        liveLocation: LiveLocationFeatureModel,
        onOpenSavedTracksLibrary: (() -> Void)? = nil
    ) {
        self._liveLocation = ObservedObject(wrappedValue: liveLocation)
        self.onOpenSavedTracksLibrary = onOpenSavedTracksLibrary
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    private var liveTrackSignature: LiveTrackRenderSignature {
        LiveTrackRenderSignature(
            count: liveLocation.liveTrackPoints.count,
            firstTimestamp: liveLocation.liveTrackPoints.first?.timestamp,
            lastTimestamp: liveLocation.liveTrackPoints.last?.timestamp
        )
    }

    public var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > 500
            // iPhone landscape => verticalSizeClass == .compact. iPad landscape
            // keeps the existing split layout (regularSizeClass) — the
            // Master-README blocks iPad-specific work until user screenshots
            // arrive (Phase 19.28 follow-up).
            let isCompactLandscape = isLandscape && verticalSizeClass == .compact
            if isCompactLandscape {
                multiLayerLandscapeLayout
            } else if isLandscape {
                landscapeLayout
                    .safeAreaInset(edge: .bottom) {
                        liveRecordingBottomInset
                    }
            } else {
                multiLayerPortraitLayout
            }
        }
        // NavigationTitle is set by the parent (LGTabContainerView → "Live")
        // — no redundant hero title here.
        .task {
            liveLocation.refreshAuthorization()
            refreshTrackPresentationState()
            syncTimerState()
        }
        .onDisappear {
            dashboardTimer?.invalidate()
            dashboardTimer = nil
        }
        .onChange(of: liveLocation.currentLocation?.timestamp) { _, _ in
            refreshMetricSnapshot()
            if !hasSeededMap {
                centerOnCurrentLocation()
                rememberCameraUpdate()
            } else if shouldThrottledCameraFollow() {
                centerOnCurrentLocation()
                rememberCameraUpdate()
            }
        }
        .onChange(of: liveTrackSignature) { _, _ in
            refreshTrackPresentationState()
        }
        .onChange(of: liveLocation.isRecording) { _, _ in
            syncTimerState()
            recordButtonState = liveLocation.isRecording ? .recording : .ready
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isFullscreenMapPresented) {
            fullscreenMapView
        }
        #endif
    }

    // MARK: - Layouts

    @ViewBuilder
    private var liveRecordingBottomInset: some View {
        if #available(iOS 26.0, *) {
            LGRecordButton(
                state: $recordButtonState,
                onStart: { liveLocation.setRecordingEnabled(true) },
                onStop: { liveLocation.setRecordingEnabled(false) },
                onPause: {
                    if liveLocation.canPauseUploads {
                        liveLocation.setUploadPaused(true)
                    }
                },
                onResume: {
                    if liveLocation.isUploadPaused {
                        liveLocation.setUploadPaused(false)
                    }
                    if !liveLocation.isRecording {
                        liveLocation.setRecordingEnabled(true)
                    }
                },
                onLap: { refreshMetricSnapshot() }
            )
            .disabled(liveLocation.isAwaitingAuthorization)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)
        } else {
            LHLiveBottomBar(
                isRecording: liveLocation.isRecording,
                isDisabled: liveLocation.isAwaitingAuthorization,
                startTitle: t("Start Recording"),
                stopTitle: t("Stop Recording"),
                onToggle: { liveLocation.setRecordingEnabled(!liveLocation.isRecording) }
            )
        }
    }

    // MARK: - Multi-Layer Portrait Layout (Phase 19.28)
    //
    // Full-bleed map with floating glass controls and a bottom sheet, modelled
    // on the claude.ai multi-layer demo. The recording button stays in
    // `safeAreaInset(.bottom)` via `liveRecordingBottomInset` so the existing
    // LGRecordButton / LHLiveBottomBar wiring contract continues to hold.

    private var multiLayerPortraitLayout: some View {
        GeometryReader { proxy in
            // Compact = hero-sized map taking roughly half the available
            // height. Falls back to full-bleed (`nil` height) when expanded.
            let compactHeight = max(220, proxy.size.height * 0.5)
            ZStack(alignment: .top) {
                // Solid background fills the area below the map when the
                // map is collapsed; ignored when full-bleed because the map
                // covers it anyway.
                liveBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    multiLayerMapBackground
                        .frame(maxWidth: .infinity)
                        .frame(height: isCompactMap ? compactHeight : nil,
                               alignment: .top)
                        .clipped()
                        // Reserve a thin band below the map so the Apple-Maps
                        // attribution ("Karten · Rechtl. Informationen") and the
                        // system-rendered locate button stay visible above the
                        // bottom sheet's collapsed top edge. Only applies when
                        // the map fills the screen — the compact (~50% hero)
                        // variant already has plenty of room.
                        .padding(.bottom, isCompactMap ? 0 : liveMapAttributionInset)
                    if isCompactMap {
                        // Layer panel drops below the hero map when compact
                        // so it no longer overlays the (now smaller) map.
                        HStack(alignment: .top, spacing: 0) {
                            LiveLayerPanel(
                                selected: $preferences.mapTrackColorMode,
                                showWeather: $showWeatherLayer,
                                showElevation: $showElevationLayer,
                                layersLabel: layersPanelLabel
                            )
                            .padding(.leading, 12)
                            .padding(.top, 10)
                            Spacer(minLength: 0)
                        }
                        Spacer(minLength: 0)
                    }
                }
                // In non-compact mode the map background still bleeds under
                // the leading/trailing/top safe areas, but the bottom respects
                // the sheet inset so the attribution band painted by
                // MKMapView (`.padding(.bottom, liveMapAttributionInset)`
                // applied on the map view above) stays in the visible region.
                .ignoresSafeArea(edges: isCompactMap ? [] : [.top, .leading, .trailing])

                // Floating compact record FAB above the bottom sheet
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        compactRecordFAB
                            .padding(.trailing, 16)
                            .padding(.bottom, 12)
                    }
                }

                HStack(alignment: .top, spacing: 0) {
                    if !isCompactMap {
                        LiveLayerPanel(
                            selected: $preferences.mapTrackColorMode,
                            showWeather: $showWeatherLayer,
                            showElevation: $showElevationLayer,
                            layersLabel: layersPanelLabel
                        )
                        .padding(.leading, 12)
                        .padding(.top, lhDeviceTopSafeInset() + 12)
                    }

                    Spacer()

                    // Reserve clearance below the LiveControlStack so the
                    // floating record FAB (56pt circle + 12pt bottom padding)
                    // never overlaps the pill column on short screens.
                    VStack(spacing: 0) {
                        LiveControlStack(
                            isFollowing: liveLocation.isFollowingLocation,
                            onCompass: { centerOnCurrentLocation() },
                            onZoomIn: { adjustMapZoom(factor: 0.5) },
                            onZoomOut: { adjustMapZoom(factor: 2.0) },
                            onLocate: {
                                liveLocation.isFollowingLocation.toggle()
                                if liveLocation.isFollowingLocation { centerOnCurrentLocation() }
                            },
                            onCompactToggle: {
                                withAnimation(reduceMotion
                                              ? nil
                                              : .smooth(duration: 0.35)) {
                                    isCompactMap.toggle()
                                }
                            },
                            isCompact: isCompactMap
                        )
                        Spacer(minLength: liveFabKeepoutClearance)
                    }
                    .padding(.trailing, 12)
                    .padding(.top, lhDeviceTopSafeInset() + 12)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            multiLayerBottomSheet
        }
    }

    /// Vertical room reserved below the trailing `LiveControlStack` so the
    /// floating record FAB (56pt button + 12pt padding) and the Apple-Maps
    /// attribution / system locate button stay free of the pill column.
    /// Phase 19.29 (no-overlap fix).
    private var liveFabKeepoutClearance: CGFloat { 56 + 12 + 8 }

    /// Vertical room reserved between the map's bottom edge and the sheet's
    /// top edge so the Apple-Maps attribution "Karten · Rechtl. Informationen"
    /// and the system locate-button remain tappable above the collapsed sheet.
    /// Phase 19.29 (no-overlap fix).
    private var liveMapAttributionInset: CGFloat { 36 }

    // MARK: - Multi-Layer Landscape Layout (iPhone, verticalSizeClass == .compact)
    //
    // Same full-bleed map + bottom sheet as portrait, but:
    //  * LiveLayerPanel is *removed* from the top-leading overlay; its content
    //    becomes a "LAYERS" expandable section inside the bottom sheet.
    //  * LiveControlStack stays right-side but in compact size.
    //  * Bottom sheet uses smaller detents (`landscapeCompact`) so the map
    //    stays visible.
    //  * The floating record FAB moves towards the centre — easier reach for
    //    a thumb that holds the device in landscape and doesn't have to
    //    stretch to the bottom-right corner.

    private var multiLayerLandscapeLayout: some View {
        ZStack(alignment: .top) {
            multiLayerMapBackground
                .ignoresSafeArea()

            // Centered floating record FAB above the bottom sheet
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    compactRecordFAB
                        .padding(.bottom, 12)
                    Spacer()
                }
            }

            // Right-aligned compact control stack only — layer panel moves
            // into the bottom-sheet to free horizontal room.
            HStack(alignment: .top, spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                    LiveControlStack(
                        isFollowing: liveLocation.isFollowingLocation,
                        onCompass: { centerOnCurrentLocation() },
                        onZoomIn: { adjustMapZoom(factor: 0.5) },
                        onZoomOut: { adjustMapZoom(factor: 2.0) },
                        onLocate: {
                            liveLocation.isFollowingLocation.toggle()
                            if liveLocation.isFollowingLocation { centerOnCurrentLocation() }
                        },
                        onCompactToggle: { isCompactMap.toggle() },
                        isCompact: isCompactMap,
                        compactSize: true
                    )
                    // Landscape FAB is smaller-feeling (still 56pt) and centred,
                    // but reserve a proportionally smaller clearance so pills
                    // never extend into the bottom-sheet / attribution band.
                    Spacer(minLength: 48)
                }
                .padding(.trailing, 8)
                .padding(.top, lhDeviceTopSafeInset() + 8)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            multiLayerLandscapeBottomSheet
        }
    }

    private var multiLayerLandscapeBottomSheet: some View {
        LiveBottomSheet(
            headerCaption: t("STATUS · LIVE MAP"),
            headlineText: heroStatusTitle,
            headlineTint: heroStatusTint,
            heights: .landscapeCompact
        ) {
            VStack(spacing: 0) {
                LiveLayerSection(
                    selected: $preferences.mapTrackColorMode,
                    showWeather: $showWeatherLayer,
                    showElevation: $showElevationLayer,
                    layersLabel: layersPanelLabel
                )
                Divider().opacity(0.35)
                LiveBottomSheetRow(
                    indicatorColor: accuracyColor,
                    icon: "scope",
                    label: t("GPS Accuracy"),
                    value: accuracyText,
                    trailingTint: accuracyColor
                )
                Divider().opacity(0.35)
                LiveBottomSheetRow(
                    indicatorColor: liveLocation.isFollowingLocation ? .blue : .secondary,
                    icon: liveLocation.isFollowingLocation ? "location.fill" : "location",
                    label: t("Follow"),
                    value: liveLocation.isFollowingLocation ? t("Follow On") : t("Follow Off"),
                    trailingTint: liveLocation.isFollowingLocation ? .blue : .secondary,
                    action: liveLocation.currentLocation == nil ? nil : {
                        liveLocation.isFollowingLocation.toggle()
                        if liveLocation.isFollowingLocation { centerOnCurrentLocation() }
                    }
                )
                Divider().opacity(0.35)
                LiveBottomSheetRow(
                    indicatorColor: preferences.allowsBackgroundLiveTracking ? LH2GPXTheme.liveMint : .secondary,
                    icon: preferences.allowsBackgroundLiveTracking ? "moon.fill" : "moon",
                    label: t("Background Recording"),
                    value: preferences.allowsBackgroundLiveTracking ? t("On") : t("Off"),
                    trailingTint: preferences.allowsBackgroundLiveTracking ? LH2GPXTheme.liveMint : .secondary,
                    action: { preferences.allowsBackgroundLiveTracking.toggle() }
                )
                Divider().opacity(0.35)
                LiveBottomSheetRow(
                    indicatorColor: LH2GPXTheme.liveMint,
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    label: t("Track Library"),
                    value: "\(liveLocation.recordedTracks.count)",
                    trailingTint: LH2GPXTheme.liveMint,
                    action: onOpenSavedTracksLibrary
                )
                Divider().opacity(0.35)
                LiveBottomSheetRow(
                    indicatorColor: permissionTintColor,
                    icon: statusSymbolName,
                    label: t("Permission"),
                    value: permissionShortValue,
                    trailingTint: permissionTintColor
                )

                if liveLocation.hasInterruptedSession {
                    Divider().opacity(0.35)
                    interruptedSessionBanner
                        .padding(.vertical, 6)
                }

                Divider().opacity(0.35)
                diagnosticsDisclosure
            }
        }
        .accessibilityIdentifier("live.bottomSheet")
    }

    @ViewBuilder
    private var multiLayerMapBackground: some View {
        if !liveStatus.shouldShowMapOverlayHint, liveLocation.currentLocation != nil {
            liveMapBase
        } else {
            ZStack {
                Color.secondary.opacity(0.10)
                liveMapPlaceholderContent
            }
        }
    }

    // MARK: - Compact Floating Record Button (portrait)

    @ViewBuilder
    private var compactRecordFAB: some View {
        let isRecording = liveLocation.isRecording
        let icon = isRecording ? "stop.fill" : "record.circle.fill"
        let label = isRecording ? t("Stop Recording") : t("Start Recording")
        Button(action: {
            liveLocation.setRecordingEnabled(!isRecording)
        }) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle().fill(Color.red)
                )
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(liveLocation.isAwaitingAuthorization)
        .accessibilityLabel(label)
        .accessibilityIdentifier(isRecording ? "live.recording.stopAction" : "live.recording.primaryAction")
    }

    private var multiLayerBottomSheet: some View {
        LiveBottomSheet(
            headerCaption: t("STATUS · LIVE MAP"),
            headlineText: heroStatusTitle,
            headlineTint: heroStatusTint,
            heights: isCompactMap ? .compactPortrait : .portrait
        ) {
            VStack(spacing: 0) {
                LiveBottomSheetRow(
                    indicatorColor: accuracyColor,
                    icon: "scope",
                    label: t("GPS Accuracy"),
                    value: accuracyText,
                    trailingTint: accuracyColor
                )
                Divider().opacity(0.35)
                LiveBottomSheetRow(
                    indicatorColor: liveLocation.isFollowingLocation ? .blue : .secondary,
                    icon: liveLocation.isFollowingLocation ? "location.fill" : "location",
                    label: t("Follow"),
                    value: liveLocation.isFollowingLocation ? t("Follow On") : t("Follow Off"),
                    trailingTint: liveLocation.isFollowingLocation ? .blue : .secondary,
                    action: liveLocation.currentLocation == nil ? nil : {
                        liveLocation.isFollowingLocation.toggle()
                        if liveLocation.isFollowingLocation { centerOnCurrentLocation() }
                    }
                )
                Divider().opacity(0.35)
                LiveBottomSheetRow(
                    indicatorColor: preferences.allowsBackgroundLiveTracking ? LH2GPXTheme.liveMint : .secondary,
                    icon: preferences.allowsBackgroundLiveTracking ? "moon.fill" : "moon",
                    label: t("Background Recording"),
                    value: preferences.allowsBackgroundLiveTracking ? t("On") : t("Off"),
                    trailingTint: preferences.allowsBackgroundLiveTracking ? LH2GPXTheme.liveMint : .secondary,
                    action: { preferences.allowsBackgroundLiveTracking.toggle() }
                )
                Divider().opacity(0.35)
                LiveBottomSheetRow(
                    indicatorColor: LH2GPXTheme.liveMint,
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    label: t("Track Library"),
                    value: "\(liveLocation.recordedTracks.count)",
                    trailingTint: LH2GPXTheme.liveMint,
                    action: onOpenSavedTracksLibrary
                )
                Divider().opacity(0.35)
                LiveBottomSheetRow(
                    indicatorColor: permissionTintColor,
                    icon: statusSymbolName,
                    label: t("Permission"),
                    value: permissionShortValue,
                    trailingTint: permissionTintColor
                )

                if liveLocation.hasInterruptedSession {
                    Divider().opacity(0.35)
                    interruptedSessionBanner
                        .padding(.vertical, 6)
                }

                Divider().opacity(0.35)
                diagnosticsDisclosure
            }
        }
        .accessibilityIdentifier("live.bottomSheet")
    }

    /// Lightweight diagnostics disclosure for the bottom-sheet. Reuses the
    /// existing diagnostics grid so its accessibility identifiers stay valid.
    private var diagnosticsDisclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isDiagnosticsExpanded.toggle()
                }
            }) {
                HStack {
                    Text(t("Diagnostics"))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: isDiagnosticsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("live.diagnostics.section")

            if isDiagnosticsExpanded {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    LHMetricCard(icon: "road.lanes", label: t("Distance"), value: liveDistanceText, color: .purple)
                        .accessibilityIdentifier("live.metric.distance")
                    LHMetricCard(icon: "clock.fill", label: t("Duration"), value: durationText, color: .blue)
                        .accessibilityIdentifier("live.metric.duration")
                    LHMetricCard(icon: "point.topleft.down.curvedto.point.bottomright.up", label: t("Points"), value: "\(liveLocation.liveTrackPoints.count)", color: .green)
                        .accessibilityIdentifier("live.metric.points")
                    LHMetricCard(icon: "chart.line.uptrend.xyaxis", label: t("Average Speed"), value: averageSpeedText, color: .indigo)
                        .accessibilityIdentifier("live.metric.averageSpeed")
                    LHMetricCard(icon: "speedometer", label: t("Current Speed"), value: currentSpeedText, color: .orange)
                    LHMetricCard(icon: "clock.badge.checkmark", label: t("Update Age"), value: updateAgeText, color: .teal)
                }
                liveRenderCapHintIfNeeded
            }
        }
    }

    // MARK: - Multi-Layer Helpers

    private var layersPanelLabel: String {
        // Four overlay slots: Standard base map (always on), Tempo color
        // mode, Höhen-Overlay, Wetter-Overlay. Standard counts as active
        // whenever Tempo is off; Tempo counts when it is the active base
        // colour mode.
        let standardActive = preferences.mapTrackColorMode != .speed
        let speedActive = preferences.mapTrackColorMode == .speed
        let count =
            (standardActive ? 1 : 0)
            + (speedActive ? 1 : 0)
            + (showElevationLayer ? 1 : 0)
            + (showWeatherLayer ? 1 : 0)
        return "\(t("LAYERS")) \(count)/4"
    }

    private var permissionShortValue: String {
        switch liveLocation.authorization {
        case .authorizedAlways: return t("Always")
        case .authorizedWhenInUse: return t("In Use")
        case .denied: return t("Denied")
        case .restricted: return t("Restricted")
        case .notDetermined: return t("Tap to grant")
        }
    }

    /// Approximates a zoom step on the live MapCameraPosition. Falls back to
    /// no-op when no anchor region is available — never traps.
    private func adjustMapZoom(factor: Double) {
        let anchor: CLLocationCoordinate2D? = liveLocation.currentLocation.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        guard let center = anchor else { return }
        // Use a span scaled by factor — we cannot read current span back from
        // MapCameraPosition reliably across iOS versions; using a sensible
        // base span (0.01°) and multiplying mirrors a single zoom step.
        let base = 0.01 * factor
        mapPosition = .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: base, longitudeDelta: base)
        ))
    }

    private var portraitLayout: some View {
        ScrollView {
            LHPageScaffold {
                if liveLocation.hasInterruptedSession {
                    interruptedSessionBanner
                }
                heroStatusCard
                diagnosticsSection
                if shouldShowUploadSection {
                    uploadSection
                }
                savedTracksSection
                advancedSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(liveBackground)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                liveHeroMap
                liveHeroFilterPanel
            }
            .background(liveBackground)
        }
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private var liveBackground: some View {
        if #available(iOS 26.0, *) {
            LHLiquidGlassBackground()
                .opacity(0.85)
                .ignoresSafeArea()
        } else {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
        }
    }

    // MARK: - Hero Map (portrait)

    private var liveHeroMap: some View {
        LHCollapsibleMapHeader(
            state: $liveMapHeaderState,
            language: preferences.appLanguage,
            overlayControls: true,
            persistenceKey: LHMapHeightPersistenceKey.live,
            safeAreaTopInset: lhDeviceTopSafeInset()
        ) {
            if !liveStatus.shouldShowMapOverlayHint, liveLocation.currentLocation != nil {
                liveMapBase
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .topLeading) {
                        LGLayerToggleBar(selected: $preferences.mapTrackColorMode)
                            .padding(.top, lhDeviceTopSafeInset() + LHHeroMapLayout.mapControlTopOffset)
                            .padding(.leading, 8)
                    }
                    .overlay(alignment: .topTrailing) {
                        liveMapLayerMenu
                            .padding(.top, lhDeviceTopSafeInset() + LHHeroMapLayout.mapControlTopOffset)
                            .padding(.trailing, 8)
                            .padding(.leading, 8)
                            .padding(.bottom, 8)
                    }
            } else {
                liveMapPlaceholderContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.06))
            }
        }
        .accessibilityIdentifier("live.map.preview")
    }

    private var liveHeroFilterPanel: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Live Map"))
                        .font(.title3.weight(.semibold))
                    Text(mapSubtitleText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let lastSampleDate = metricSnapshot.lastSampleDate {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(t("Last Fix"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(AppDateDisplay.abbreviatedDateTime(lastSampleDate))
                            .font(.caption.monospacedDigit())
                    }
                }
            }
            statusChipsRow
            liveRenderCapHintIfNeeded
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private var landscapeLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            mapCard
                .padding(.leading)
                .padding(.vertical, 14)
                .frame(maxHeight: .infinity, alignment: .top)
            ScrollView {
                LHPageScaffold {
                    if liveLocation.hasInterruptedSession {
                        interruptedSessionBanner
                    }
                    heroStatusCard
                    diagnosticsSection
                    if shouldShowUploadSection {
                        uploadSection
                    }
                    savedTracksSection
                    advancedSection
                }
            }
        }
    }

    // MARK: - Hero Status Card

    private var heroStatusCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(heroStatusTint.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: heroStatusIcon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(heroStatusTint)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(heroStatusTitle)
                    .font(.headline.weight(.semibold))
                Text(heroStatusSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(16)
        .background(heroStatusTint.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(heroStatusTint.opacity(0.15), lineWidth: 1)
        )
        .accessibilityIdentifier("live.status.hero")
    }

    // MARK: - Consolidated Live Status

    /// Single dominant status used by hero card, map overlay and GPS chip
    /// so they never disagree. See `LiveStatusResolver`.
    private var liveStatus: LiveStatus {
        LiveStatusResolver.resolve(
            authorization: liveLocation.authorization,
            isAwaitingAuthorization: liveLocation.isAwaitingAuthorization,
            isRecording: liveLocation.isRecording,
            needsAlwaysUpgrade: liveLocation.needsAlwaysAuthorizationUpgrade,
            currentAccuracyM: liveLocation.currentLocation?.horizontalAccuracyM
        )
    }

    private var heroStatusIcon: String {
        switch liveStatus {
        case .recordingAcquiring, .recordingWeak, .recordingGood:
            return "record.circle.fill"
        case .permissionRequired(awaiting: true):
            return "location.circle"
        case .permissionRequired(awaiting: false):
            return "location.circle"
        case .permissionDenied, .permissionRestricted:
            return "location.slash.circle"
        case .backgroundUpgradePending:
            return "location.circle"
        case .acquiringFix:
            return "location.circle"
        case .readyWeak, .readyGood:
            return "location.circle.fill"
        }
    }

    private var heroStatusTitle: String {
        switch liveStatus {
        case .recordingAcquiring, .recordingWeak, .recordingGood:
            return t("Recording Active")
        case .permissionRequired(awaiting: true):
            return t("Requesting Permission")
        case .permissionRequired(awaiting: false):
            return t("Permission required")
        case .permissionDenied, .permissionRestricted:
            return t("Location Access Denied")
        case .backgroundUpgradePending:
            return t("Ready to Record")
        case .acquiringFix:
            return t("Acquiring fix")
        case .readyWeak, .readyGood:
            return t("Ready to Record")
        }
    }

    private var heroStatusSubtitle: String {
        switch liveStatus {
        case .recordingAcquiring:
            return t("Waiting for first GPS location…")
        case .recordingWeak, .recordingGood:
            return t("Location is being tracked and saved locally.")
        case .permissionRequired(awaiting: true):
            return t("Waiting for location access approval.")
        case .permissionRequired(awaiting: false):
            return t("Tap below to grant access")
        case .permissionDenied, .permissionRestricted:
            return t("Update location permissions in Settings to start recording.")
        case .backgroundUpgradePending:
            return t("Tap Start Recording to begin a new live track.")
        case .acquiringFix:
            return t("Waiting for first GPS location…")
        case .readyWeak, .readyGood:
            return t("Tap Start Recording to begin a new live track.")
        }
    }

    private var heroStatusTint: Color {
        switch liveStatus {
        case .recordingAcquiring, .recordingWeak, .recordingGood:
            return LH2GPXTheme.liveMint
        case .permissionRequired(awaiting: true):
            return .orange
        case .permissionRequired(awaiting: false):
            return .secondary
        case .permissionDenied, .permissionRestricted:
            return .red
        case .backgroundUpgradePending:
            return .orange
        case .acquiringFix:
            return .orange
        case .readyWeak, .readyGood:
            return LH2GPXTheme.primaryBlue
        }
    }

    /// Title shown inside the map overlay placeholder, derived from `liveStatus`.
    private var mapOverlayTitle: String {
        switch liveStatus {
        case .permissionDenied, .permissionRestricted:
            return t("Location not available")
        case .permissionRequired:
            return t("Location not available")
        case .acquiringFix, .recordingAcquiring:
            return t("Acquiring location fix…")
        default:
            return t("Location not available")
        }
    }

    private var mapOverlaySubtitle: String {
        switch liveStatus {
        case .acquiringFix, .recordingAcquiring:
            return t("Waiting for first GPS location…")
        default:
            return t("Start recording to request location access and see your position here.")
        }
    }

    private var mapOverlayIcon: String {
        switch liveStatus {
        case .acquiringFix, .recordingAcquiring:
            return "location.circle"
        default:
            return "location.slash"
        }
    }

    // MARK: - Interrupted Session Banner

    private var interruptedSessionBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Recording interrupted"))
                        .font(.subheadline.weight(.semibold))
                    if let startedAt = liveLocation.sessionStartedAt {
                        Text(interruptedSessionMessage(startedAt: startedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(t("A recording was interrupted. Start a new session?"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Button(action: {
                    liveLocation.dismissInterruptedSession()
                    liveLocation.setRecordingEnabled(true)
                }) {
                    Label(t("Resume recording"), systemImage: "record.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .accessibilityIdentifier("live.interrupted.resume")

                Button(action: {
                    liveLocation.dismissInterruptedSession()
                }) {
                    Text(t("Ignore"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private func interruptedSessionMessage(startedAt: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = preferences.appLocale
        let relativeTime = formatter.localizedString(for: startedAt, relativeTo: Date())
        let format = t("A recording started %@ was interrupted. Start a new session?")
        return String(format: format, relativeTime)
    }

    // MARK: - Fullscreen Map

    private var fullscreenMapView: some View {
        GeometryReader { geometry in
            liveMapContent(height: geometry.size.height)
                .ignoresSafeArea()
                .overlay(alignment: .topTrailing) {
                    MapLayerMenu(configuration: MapLayerMenu.Configuration(
                        showsTrackColor: false,
                        showsLiveOptions: true,
                        centerOnLocation: liveLocation.currentLocation == nil ? nil : {
                            liveLocation.isFollowingLocation = true
                            centerOnCurrentLocation()
                        },
                        toggleFullscreen: { isFullscreenMapPresented = false },
                        isFullscreenActive: true
                    ))
                    .padding(.top, lhDeviceTopSafeInset() + 8)
                    .padding(.trailing, 8)
                }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func liveMapContent(height: CGFloat) -> some View {
        if !liveStatus.shouldShowMapOverlayHint, liveLocation.currentLocation != nil {
            Map(position: $mapPosition) {
                liveAccuracyCircleContent
                liveTrackContent
                liveCurrentLocationAnnotation
            }
            .mapStyle(AppMapStyleResolver.mapStyle(for: preferences.preferredMapStyle, showsRealisticElevation: preferences.mapShowsRealisticElevation))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .onMapCameraChange { _ in
                liveLocation.isFollowingLocation = false
            }
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
    }

    // MARK: - Shared Helpers

    private var shouldShowUploadSection: Bool {
        LiveTrackingPresentation.uploadSectionVisible(
            sendsToServer: preferences.sendsLiveLocationToServer,
            pendingCount: liveLocation.pendingUploadPointCount,
            statusMessage: liveLocation.serverUploadStatusMessage
        )
    }

    private var locationDotColor: Color {
        liveLocation.isRecording ? LH2GPXTheme.liveMint : LH2GPXTheme.primaryBlue
    }

    // MARK: - Live map content helpers

    @MapContentBuilder
    private var liveCurrentLocationAnnotation: some MapContent {
        if let currentLocation = liveLocation.currentLocation,
           currentLocation.latitude.isFinite,
           currentLocation.longitude.isFinite {
            Annotation(t("Current Location"), coordinate: CLLocationCoordinate2D(
                latitude: currentLocation.latitude,
                longitude: currentLocation.longitude
            )) {
                LiveLocationDot(
                    color: locationDotColor,
                    pulseEnabled: liveLocation.isRecording && preferences.livePulseEnabled
                )
            }
        }
    }

    /// GPS accuracy circle around the current location. Stroked, not filled,
    /// so it shows precision without obscuring the basemap. Defensive guards
    /// against CoreLocation's invalid sentinels — horizontalAccuracy can be
    /// `-1` ("invalid"), NaN, or wildly large; MapCircle aborts on any of
    /// those. Coordinates must also be finite (NaN/±Inf trap MapKit's
    /// projection on iOS 17).
    @MapContentBuilder
    private var liveAccuracyCircleContent: some MapContent {
        if preferences.liveAccuracyCircleEnabled,
           let location = liveLocation.currentLocation,
           location.latitude.isFinite,
           location.longitude.isFinite,
           location.horizontalAccuracyM.isFinite,
           location.horizontalAccuracyM > 0,
           location.horizontalAccuracyM < 500 {
            MapCircle(
                center: CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                ),
                radius: location.horizontalAccuracyM
            )
            .foregroundStyle(locationDotColor.opacity(0.10))
            .stroke(locationDotColor.opacity(0.45), lineWidth: 1)
        }
    }

    /// Live trail. Renders speed-coloured segments when the user has chosen
    /// the Tempolayer; otherwise a 3-bucket alpha fade so the older parts of
    /// the trail look subdued and the freshest segment stays solid.
    /// MapPolyline aborts under iOS 17 if the input has fewer than two
    /// finite coordinates — guard that here as a single source of truth.
    @MapContentBuilder
    private var liveTrackContent: some MapContent {
        let safeCoords = MapCoordinateGuard.sanitize(polylineCoordinates)
        if liveLocation.liveTrackShouldRender, safeCoords.count >= 2 {
            MapPolyline(coordinates: safeCoords)
                .stroke(
                    Color.white.opacity(MapTrackStyle.haloOpacity),
                    style: MapTrackStyle.stroke(width: MapTrackStyle.Width.live * MapTrackStyle.haloMultiplier)
                )
            if preferences.mapTrackColorMode == .speed, trackSamples.count >= 2 {
                ForEach(SpeedTrackBuilder.segments(from: trackSamples)) { segment in
                    MapPolyline(coordinates: [segment.start, segment.end])
                        .stroke(
                            SpeedColors.color(for: segment.normalizedSpeed),
                            style: MapTrackStyle.stroke(width: MapTrackStyle.Width.live)
                        )
                }
            } else if preferences.liveBreadcrumbFadeEnabled {
                ForEach(Array(LiveBreadcrumbFade.buckets(from: safeCoords).enumerated()), id: \.offset) { _, bucket in
                    if bucket.coordinates.count >= 2 {
                        MapPolyline(coordinates: bucket.coordinates)
                            .stroke(
                                LH2GPXTheme.liveMint.opacity(bucket.alpha),
                                style: MapTrackStyle.stroke(width: MapTrackStyle.Width.live)
                            )
                    }
                }
            } else {
                MapPolyline(coordinates: safeCoords)
                    .stroke(
                        LH2GPXTheme.liveMint,
                        style: MapTrackStyle.stroke(width: MapTrackStyle.Width.live)
                    )
            }
        }
    }

    // MARK: - Render-Cap Hint

    /// Quiet single-line caption shown only when the render polyline has been
    /// reduced. Calls out that the *display* is optimized, while raw tracking
    /// data is untouched — no panic colour, no "data lost" wording.
    @ViewBuilder
    private var liveRenderCapHintIfNeeded: some View {
        if liveRenderWasCapped {
            Text(t("Live route display optimized for performance. Full tracking data remains unchanged."))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
                .accessibilityIdentifier("liveRenderCapHint")
        }
    }

    // MARK: - Status Chips

    private var statusChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                LHStatusChip(
                    title: liveLocation.isRecording ? t("Recording") : t("Idle"),
                    systemImage: liveLocation.isRecording ? "record.circle.fill" : "pause.circle.fill",
                    color: liveLocation.isRecording ? LH2GPXTheme.liveMint : .secondary
                )
                .accessibilityIdentifier("live.status.ready")

                LHStatusChip(
                    title: t(LiveTrackingPresentation.gpsStatusLabel(accuracyM: liveLocation.currentLocation?.horizontalAccuracyM)),
                    systemImage: liveLocation.currentLocation != nil ? "location.fill" : "location.slash",
                    color: accuracyColor
                )
                .accessibilityIdentifier("live.status.gps")

                if liveLocation.currentLocation != nil {
                    LHStatusChip(
                        title: liveLocation.isFollowingLocation ? t("Follow On") : t("Follow Off"),
                        systemImage: liveLocation.isFollowingLocation ? "location.fill" : "location",
                        color: liveLocation.isFollowingLocation ? .blue : .secondary
                    )
                    .accessibilityIdentifier("live.status.follow")
                }

                if shouldShowUploadSection {
                    LHStatusChip(
                        title: t(liveLocation.uploadStatusSummary),
                        systemImage: uploadStatusIconName,
                        color: uploadStatusColor
                    )
                    .accessibilityIdentifier("live.status.upload")

                    if liveLocation.pendingUploadPointCount > 0 {
                        LHStatusChip(
                            title: "\(liveLocation.pendingUploadPointCount) \(t(liveLocation.pendingUploadPointCount == 1 ? "Queued Point" : "Queued Points"))",
                            systemImage: "tray.full.fill",
                            color: .orange
                        )
                    }
                }
            }
        }
    }

    // MARK: - Shared Live Map Building Blocks

    @ViewBuilder
    private var liveMapBase: some View {
        Map(position: $mapPosition) {
            liveAccuracyCircleContent
            liveTrackContent
            liveCurrentLocationAnnotation
        }
        .mapStyle(AppMapStyleResolver.mapStyle(for: preferences.preferredMapStyle, showsRealisticElevation: preferences.mapShowsRealisticElevation))
        .onMapCameraChange { _ in
            liveLocation.isFollowingLocation = false
        }
    }

    private var liveMapLayerMenu: MapLayerMenu {
        MapLayerMenu(configuration: MapLayerMenu.Configuration(
            showsTrackColor: false,
            showsLiveOptions: true,
            centerOnLocation: liveLocation.currentLocation == nil ? nil : {
                liveLocation.isFollowingLocation = true
                centerOnCurrentLocation()
            },
            toggleFullscreen: { isFullscreenMapPresented = true },
            isFullscreenActive: false
        ))
    }

    @ViewBuilder
    private var liveMapPlaceholderContent: some View {
        VStack(spacing: 12) {
            Image(systemName: mapOverlayIcon)
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(mapOverlayTitle)
                .font(.headline)
            Text(mapOverlaySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Map Card

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Live Map"))
                        .font(.title3.weight(.semibold))
                    Text(mapSubtitleText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let lastSampleDate = metricSnapshot.lastSampleDate {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(t("Last Fix"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(AppDateDisplay.abbreviatedDateTime(lastSampleDate))
                            .font(.caption.monospacedDigit())
                    }
                }
            }

            statusChipsRow
            liveRenderCapHintIfNeeded

            Group {
                if !liveStatus.shouldShowMapOverlayHint, liveLocation.currentLocation != nil {
                    liveMapBase
                        .frame(height: 290)
                        .overlay(alignment: .topTrailing) {
                            liveMapLayerMenu
                                .padding(8)
                        }
                } else {
                    liveMapPlaceholderContent
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .cardChrome()
        .accessibilityIdentifier("live.map.preview")
    }

    // MARK: - Diagnostics Section (collapsible recording metrics)

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isDiagnosticsExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Diagnostics"))
                            .font(.title3.weight(.semibold))
                        Text(isDiagnosticsExpanded
                             ? t("Live recording metrics, GPS accuracy and update statistics.")
                             : t("Tap to view recording metrics and GPS details."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if liveLocation.isRecording {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(t("Session"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(durationText)
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(LH2GPXTheme.liveMint)
                        }
                    }
                    Image(systemName: isDiagnosticsExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
            .buttonStyle(.plain)

            if isDiagnosticsExpanded {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    LHMetricCard(icon: "road.lanes", label: t("Distance"), value: liveDistanceText, color: .purple)
                        .accessibilityIdentifier("live.metric.distance")
                    LHMetricCard(icon: "clock.fill", label: t("Duration"), value: durationText, color: .blue)
                        .accessibilityIdentifier("live.metric.duration")
                    LHMetricCard(icon: "point.topleft.down.curvedto.point.bottomright.up", label: t("Points"), value: "\(liveLocation.liveTrackPoints.count)", color: .green)
                        .accessibilityIdentifier("live.metric.points")
                    LHMetricCard(icon: "chart.line.uptrend.xyaxis", label: t("Average Speed"), value: averageSpeedText, color: .indigo)
                        .accessibilityIdentifier("live.metric.averageSpeed")
                    LHMetricCard(icon: "scope", label: t("GPS Accuracy"), value: accuracyText, color: accuracyColor)
                    LHMetricCard(icon: "speedometer", label: t("Current Speed"), value: currentSpeedText, color: .orange)
                    LHMetricCard(icon: "arrow.left.and.right.circle", label: t("Last Segment"), value: lastSegmentText, color: .mint)
                    LHMetricCard(icon: "clock.badge.checkmark", label: t("Update Age"), value: updateAgeText, color: .teal)
                    // Train 9.2: live elevation. Surfaces altitude only when
                    // CoreLocation reported a positive vertical accuracy —
                    // otherwise shows an em-dash, never a stale or invented value.
                    LHMetricCard(
                        icon: "mountain.2",
                        label: t("Elevation"),
                        value: liveElevationValueText,
                        color: LH2GPXTheme.VariantBPro.terra300
                    )
                    .accessibilityIdentifier("live.metric.elevation")
                    .accessibilityValue(Text(liveElevationAccessibilityValue))
                }
            }
        }
        .cardChrome()
        .accessibilityIdentifier("live.diagnostics.section")
    }

    // MARK: - Upload Section

    private var uploadSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Upload"))
                        .font(.title3.weight(.semibold))
                    Text(t("Review endpoint health, queue pressure and retry state for optional server forwarding."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                LHStatusChip(
                    title: t(liveLocation.uploadStatusSummary),
                    systemImage: uploadStatusIconName,
                    color: uploadStatusColor
                )
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                LHMetricCard(icon: "network", label: t("Endpoint"), value: preferences.liveLocationServerUploadConfiguration.endpointDisplayName, color: endpointStatusColor)
                LHMetricCard(icon: hasBearerTokenConfigured ? "key.fill" : "key.slash", label: t("Auth"), value: hasBearerTokenConfigured ? t("Token set") : t("No token"), color: hasBearerTokenConfigured ? .green : .orange)
                LHMetricCard(icon: "square.stack.3d.up.fill", label: t("Batch Size"), value: preferences.liveTrackingUploadBatch.title, color: .blue)
                LHMetricCard(icon: "tray.full.fill", label: t("Queue"), value: "\(liveLocation.pendingUploadPointCount) / \(liveLocation.uploadQueueLimit)", color: liveLocation.pendingUploadPointCount > 0 ? .orange : .secondary)
                LHMetricCard(icon: "exclamationmark.triangle.fill", label: t("Failures"), value: "\(liveLocation.consecutiveUploadFailures)", color: liveLocation.consecutiveUploadFailures > 0 ? .red : .secondary)
                LHMetricCard(icon: "checkmark.circle.fill", label: t("Last Success"), value: lastUploadSuccessText, color: liveLocation.lastSuccessfulUploadAt == nil ? .secondary : .green)
            }

            if let assistive = liveLocation.uploadAssistiveMessage {
                LHInsightBanner(
                    title: t("Upload Guidance"),
                    message: t(assistive),
                    systemImage: liveLocation.consecutiveUploadFailures > 0 ? "exclamationmark.triangle" : "info.circle",
                    tint: liveLocation.consecutiveUploadFailures > 0 ? .orange : .blue
                )
            }

            if let statusMessage = liveLocation.serverUploadStatusMessage {
                LHInsightBanner(
                    title: t("Latest Upload Status"),
                    message: t(statusMessage),
                    systemImage: uploadStatusIconName,
                    tint: uploadStatusColor
                )
            }

            uploadQuickActions
        }
        .cardChrome()
        .accessibilityIdentifier("live.server.status")
    }

    private var uploadQuickActions: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: 10) { uploadActionButtons }
            VStack(spacing: 10) { uploadActionButtons }
        }
    }

    @ViewBuilder
    private var uploadActionButtons: some View {
        Button(action: {
            if liveLocation.isUploadPaused {
                liveLocation.setUploadPaused(false)
            } else {
                liveLocation.setUploadPaused(true)
            }
        }) {
            Label(
                liveLocation.isUploadPaused ? t("Resume Uploads") : t("Pause Uploads"),
                systemImage: liveLocation.isUploadPaused ? "play.fill" : "pause.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!liveLocation.canPauseUploads)
        .accessibilityIdentifier("live.cta.pause")
        .accessibilityHint(liveLocation.canPauseUploads
            ? t("Stops sending live points to your server without ending the local recording.")
            : t("Available while a live recording is running and uploads are enabled in Settings."))

        if liveLocation.pendingUploadPointCount > 0 {
            Button(action: { liveLocation.flushPendingUploads() }) {
                Label(t("Flush Queue"), systemImage: "arrow.up.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!liveLocation.canFlushPendingUploads)
            .accessibilityIdentifier("live.cta.flushQueue")
            .accessibilityHint(liveLocation.canFlushPendingUploads
                ? t("Immediately sends all queued points to your upload server.")
                : t("Available when there are queued points and the upload configuration is valid."))
        }
    }

    // MARK: - Saved Tracks Section

    private var savedTracksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Track Library"))
                        .font(.title3.weight(.semibold))
                    Text(t("Local recordings stay separate from imported history until you open them for editing or export."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(liveLocation.recordedTracks.count)")
                    .font(.headline.monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LH2GPXTheme.liveMint.opacity(0.12))
                    .clipShape(Capsule())
            }

            if let latestTrack = liveLocation.recordedTracks.first {
                SavedTrackSummaryContentView(
                    presentation: SavedTrackPresentation.row(
                        for: latestTrack,
                        unit: preferences.distanceUnit,
                        language: preferences.appLanguage
                    )
                )
            } else {
                LHInsightBanner(
                    title: t("No saved tracks yet"),
                    message: t("Record a short route and stop it once to seed the local track library."),
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                    tint: LH2GPXTheme.liveMint
                )
            }

            if let onOpenSavedTracksLibrary {
                Button(action: onOpenSavedTracksLibrary) {
                    Label(t("View All Live Tracks"), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(LH2GPXTheme.liveMint)
                .accessibilityIdentifier("live.savedTracks.openAll")
            }
        }
        .cardChrome()
        .accessibilityIdentifier("live.savedTracks.preview")
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Advanced"))
                        .font(.title3.weight(.semibold))
                    Text(t("Permission state, background preference and local capture rules remain visible here."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Button(action: {
                    liveLocation.isFollowingLocation.toggle()
                    if liveLocation.isFollowingLocation {
                        centerOnCurrentLocation()
                    }
                }) {
                    Label(
                        liveLocation.isFollowingLocation ? t("Follow On") : t("Follow Off"),
                        systemImage: liveLocation.isFollowingLocation ? "location.fill" : "location"
                    )
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(liveLocation.isFollowingLocation ? Color.blue.opacity(0.15) : LH2GPXTheme.chipBackground)
                    .foregroundStyle(liveLocation.isFollowingLocation ? .blue : .secondary)
                    .clipShape(Capsule())
                }
                .disabled(liveLocation.currentLocation == nil)
            }

            Toggle(t("Background Recording"), isOn: $preferences.allowsBackgroundLiveTracking)
                .font(.subheadline)

            if liveStatus.isPermissionState {
                LHInsightBanner(
                    title: t(liveLocation.permissionTitle),
                    message: t(liveLocation.permissionMessage),
                    systemImage: statusSymbolName,
                    tint: permissionTintColor
                )
                .accessibilityIdentifier("live.permission.card")
            }
        }
        .cardChrome()
    }

    // MARK: - Display Helpers

    private var mapSubtitleText: String {
        if liveLocation.isRecording {
            return t("A live session is running. The map follows the latest accepted points and current foreground fix.")
        }
        if liveLocation.canDisplayLiveLocation {
            return t("Live location is ready. Start a recording or inspect the current fix before you move.")
        }
        return t("Recording must start once before the app can request foreground location access.")
    }

    private var recordingSubtitleText: String {
        if liveLocation.isRecording {
            return t("Current fix quality, movement speed and queue health update continuously while recording stays active.")
        }
        return t("Start locally, then optionally forward accepted points to your own HTTPS endpoint.")
    }

    private var uploadStatusIconName: String {
        switch liveLocation.uploadStatusSummary {
        case "Invalid endpoint":  return "exclamationmark.triangle.fill"
        case "Uploading":         return "arrow.triangle.2.circlepath.circle.fill"
        case "Paused":            return "pause.circle.fill"
        case "Needs retry":       return "wifi.exclamationmark"
        case "Queue pending":     return "tray.full.fill"
        case "Ready":             return "checkmark.circle.fill"
        default:                  return "network.slash"
        }
    }

    private var uploadStatusColor: Color {
        switch liveLocation.uploadStatusSummary {
        case "Invalid endpoint", "Needs retry": return .orange
        case "Uploading":                        return .blue
        case "Paused":                           return .yellow
        case "Queue pending":                    return .orange
        case "Ready":                            return .green
        default:                                 return .secondary
        }
    }

    private var permissionTintColor: Color {
        switch liveLocation.authorization {
        case .authorizedAlways:                   return .green
        case .authorizedWhenInUse:
            return liveLocation.needsAlwaysAuthorizationUpgrade ? .orange : .blue
        case .notDetermined:                      return .secondary
        case .restricted, .denied:               return .red
        }
    }

    private var endpointStatusColor: Color {
        liveLocation.hasValidServerUploadConfiguration ? .blue : .orange
    }

    private var hasBearerTokenConfigured: Bool {
        liveLocation.hasBearerTokenConfigured
    }

    private var accuracyText: String {
        guard let location = liveLocation.currentLocation else { return "–" }
        return String(format: "± %.0f m", location.horizontalAccuracyM)
    }

    private var accuracyColor: Color {
        guard let location = liveLocation.currentLocation else { return .secondary }
        switch location.horizontalAccuracyM {
        case ..<10:  return .green
        case ..<30:  return .mint
        case ..<65:  return .orange
        default:     return .red
        }
    }

    private var durationText: String {
        let hours = Int(recordingDuration) / 3600
        let minutes = (Int(recordingDuration) % 3600) / 60
        let seconds = Int(recordingDuration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var liveDistanceText: String {
        formatDistance(metricSnapshot.totalDistanceM, unit: preferences.distanceUnit)
    }

    private var currentSpeedText: String {
        guard let speed = metricSnapshot.currentSpeedKMH else { return "–" }
        return formatSpeed(speed, unit: preferences.distanceUnit)
    }

    private var averageSpeedText: String {
        guard recordingDuration > 0, metricSnapshot.totalDistanceM > 0 else { return "–" }
        let speed = (metricSnapshot.totalDistanceM / recordingDuration) * 3.6
        return formatSpeed(speed, unit: preferences.distanceUnit)
    }

    private var lastSegmentText: String {
        guard let distance = metricSnapshot.lastSegmentDistanceM else { return "–" }
        return formatDistance(distance, unit: preferences.distanceUnit)
    }

    // MARK: - Live elevation (Train 9.2)

    /// `Reading` snapshot of the latest sample's altitude/verticalAccuracy.
    /// Routed through `LocationElevationFormatter` so the rule
    /// "verticalAccuracy must be > 0" lives in one place.
    private var liveElevationReading: LocationElevationFormatter.Reading {
        LocationElevationFormatter.reading(
            altitudeM: liveLocation.currentLocation?.altitudeM,
            verticalAccuracyM: liveLocation.currentLocation?.verticalAccuracyM
        )
    }

    /// Compact value text for the metric card (em-dash on `.unavailable`).
    private var liveElevationValueText: String {
        LocationElevationFormatter.compactAltitudeText(for: liveElevationReading) ?? "–"
    }

    /// Full VoiceOver value — includes accuracy when available.
    private var liveElevationAccessibilityValue: String {
        LocationElevationFormatter.displayText(
            for: liveElevationReading,
            german: preferences.appLanguage.isGerman
        )
    }

    private var updateAgeText: String {
        guard let lastSampleDate = metricSnapshot.lastSampleDate else { return "–" }
        let age = max(0, now.timeIntervalSince(lastSampleDate))
        if age < 60 {
            return preferences.appLanguage.isGerman
                ? String(format: "%.0f Sek.", age)
                : String(format: "%.0f s", age)
        }
        if age < 3600 {
            let minutes = age / 60
            return preferences.appLanguage.isGerman
                ? String(format: "%.0f Min.", minutes)
                : String(format: "%.0f min", minutes)
        }
        let hours = age / 3600
        return preferences.appLanguage.isGerman
            ? String(format: "%.1f Std.", hours)
            : String(format: "%.1f h", hours)
    }

    private var lastUploadSuccessText: String {
        guard let date = liveLocation.lastSuccessfulUploadAt else { return "–" }
        return AppDateDisplay.abbreviatedDateTime(date)
    }

    private var statusSymbolName: String {
        switch liveLocation.authorization {
        case .notDetermined:                      return "location.circle"
        case .restricted:                         return "hand.raised.circle"
        case .denied:                             return "location.slash.circle"
        case .authorizedWhenInUse, .authorizedAlways:
            return liveLocation.isRecording ? "record.circle" : "location.circle.fill"
        }
    }

    // MARK: - Map Helpers

    private func centerOnCurrentLocation() {
        guard let location = liveLocation.currentLocation else { return }
        hasSeededMap = true
        mapPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
    }

    /// Train I, Phase 1 (2026-05-16): combine the live `isFollowingLocation`
    /// flag with the pure `LiveCameraUpdateThrottle` decision so that high-
    /// frequency GPS samples do not re-center the map on every tick. Sub-
    /// threshold updates are skipped; the most recent fix is still applied
    /// when both the time- and distance-thresholds are crossed. The throttle
    /// is bypassed entirely for the initial seed (`!hasSeededMap`) and for
    /// the user-tapped "follow now" actions, which both call
    /// `centerOnCurrentLocation()` directly.
    private func shouldThrottledCameraFollow() -> Bool {
        guard let location = liveLocation.currentLocation else { return false }
        let coord = LiveCameraUpdateThrottle.Coordinate(
            latitude: location.latitude,
            longitude: location.longitude
        )
        let decision = LiveCameraUpdateThrottle.shouldUpdate(
            isFollowing: liveLocation.isFollowingLocation,
            coordinate: coord,
            now: Date(),
            lastUpdate: lastCameraUpdate
        )
        return decision == .update
    }

    private func rememberCameraUpdate() {
        guard let location = liveLocation.currentLocation else { return }
        lastCameraUpdate = (
            timestamp: Date(),
            coordinate: LiveCameraUpdateThrottle.Coordinate(
                latitude: location.latitude,
                longitude: location.longitude
            )
        )
    }

    private func refreshMetricSnapshot() {
        metricSnapshot = LiveTrackingPresentation.metrics(
            points: liveLocation.liveTrackPoints,
            currentLocation: liveLocation.currentLocation
        )
    }

    private func refreshTrackPresentationState() {
        // Shape only the render-side projection of liveTrackPoints — raw
        // recording data, persistence, and export are untouched.
        let capResult = LiveTrackRenderCap.apply(
            points: liveLocation.liveTrackPoints,
            cap: Self.liveRenderPointCap
        )
        polylineCoordinates = capResult.points.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        trackSamples = capResult.points.map {
            TrackSample(
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                timestamp: $0.timestamp
            )
        }
        liveRenderWasCapped = capResult.wasCapped
        if liveLocation.isRecording {
            recordingStartDate = liveLocation.liveTrackPoints.first?.timestamp ?? recordingStartDate ?? Date()
        } else if liveLocation.liveTrackPoints.isEmpty {
            recordingStartDate = nil
        }
        refreshMetricSnapshot()
    }

    private func syncTimerState() {
        dashboardTimer?.invalidate()
        now = Date()
        refreshMetricSnapshot()

        if liveLocation.isRecording {
            if recordingStartDate == nil {
                if let firstPoint = liveLocation.liveTrackPoints.first?.timestamp {
                    recordingStartDate = firstPoint
                } else {
                    recordingStartDate = Date()
                }
            }
            recordingDuration = Date().timeIntervalSince(recordingStartDate ?? Date())
            dashboardTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                now = Date()
                recordingDuration = now.timeIntervalSince(recordingStartDate ?? now)
            }
        } else {
            dashboardTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                now = Date()
            }
            recordingStartDate = nil
            recordingDuration = 0
        }
    }
}

// MARK: - LiveLocationDot

/// Pulsing user-location dot for the live tracking maps. State + animation
/// are owned by this view (not the parent's @MapContentBuilder closure) so
/// the iOS 17 "modifying state during view update" precondition cannot
/// fire from the Annotation's content closure. The animation kicks off via
/// `.task` on the first appearance — `.task` is documented to run after
/// the view has been added to the hierarchy, sidestepping the in-update
/// boundary that `onAppear` can land in inside MapContentBuilder.
@available(iOS 17.0, macOS 14.0, *)
private struct LiveLocationDot: View {
    let color: Color
    let pulseEnabled: Bool

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(pulseEnabled ? 0.30 : 0.18))
                .frame(width: 42, height: 42)
                .scaleEffect(pulseEnabled && isPulsing ? 1.55 : 1.0)
                .opacity(pulseEnabled && isPulsing ? 0.0 : 1.0)
                .animation(
                    pulseEnabled
                        ? .easeInOut(duration: 1.4).repeatForever(autoreverses: false)
                        : .default,
                    value: isPulsing
                )
            Circle()
                .fill(color)
                .frame(width: 15, height: 15)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
        }
        .task(id: pulseEnabled) {
            isPulsing = pulseEnabled
        }
    }
}

#endif
