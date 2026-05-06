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
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var hasSeededMap = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var dashboardTimer: Timer?
    @State private var recordingStartDate: Date?
    @State private var now = Date()
    @State private var metricSnapshot = LiveTrackingMetricSnapshot.empty
    @State private var polylineCoordinates: [CLLocationCoordinate2D] = []
    @State private var trackSamples: [TrackSample] = []
    @State private var isFullscreenMapPresented = false
    @State private var isDiagnosticsExpanded = false
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
            if isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .navigationTitle(t("Live Tracking"))
        .safeAreaInset(edge: .bottom) {
            LHLiveBottomBar(
                isRecording: liveLocation.isRecording,
                isDisabled: liveLocation.isAwaitingAuthorization,
                startTitle: t("Start Recording"),
                stopTitle: t("Stop Recording"),
                onToggle: { liveLocation.setRecordingEnabled(!liveLocation.isRecording) }
            )
        }
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
            } else if liveLocation.isFollowingLocation {
                centerOnCurrentLocation()
            }
        }
        .onChange(of: liveTrackSignature) { _, _ in
            refreshTrackPresentationState()
        }
        .onChange(of: liveLocation.isRecording) { _, _ in
            syncTimerState()
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isFullscreenMapPresented) {
            fullscreenMapView
        }
        #endif
    }

    // MARK: - Layouts

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
        .background(Color.black)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                liveHeroMap
                liveHeroFilterPanel
            }
            .background(Color.black)
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Hero Map (portrait)

    private var liveHeroMap: some View {
        LHCollapsibleMapHeader(
            state: $liveMapHeaderState,
            language: preferences.appLanguage,
            overlayControls: true,
            safeAreaTopInset: lhDeviceTopSafeInset()
        ) {
            if !liveStatus.shouldShowMapOverlayHint, liveLocation.currentLocation != nil {
                Map(position: $mapPosition) {
                    liveAccuracyCircleContent
                    liveTrackContent
                    liveCurrentLocationAnnotation
                }
                .mapStyle(preferences.preferredMapStyle.isHybrid ? .hybrid : .standard(elevation: .realistic))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onMapCameraChange { _ in
                    liveLocation.isFollowingLocation = false
                }
                .overlay(alignment: .topTrailing) {
                    MapLayerMenu(configuration: MapLayerMenu.Configuration(
                        showsTrackColor: true,
                        showsLiveOptions: true,
                        centerOnLocation: liveLocation.currentLocation == nil ? nil : {
                            liveLocation.isFollowingLocation = true
                            centerOnCurrentLocation()
                        },
                        toggleFullscreen: { isFullscreenMapPresented = true },
                        isFullscreenActive: false
                    ))
                    .padding(.top, lhDeviceTopSafeInset() + LHHeroMapLayout.mapControlTopOffset)
                    .padding(.trailing, 8)
                    .padding(.leading, 8)
                    .padding(.bottom, 8)
                }
            } else {
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
                        showsTrackColor: true,
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
            .mapStyle(preferences.preferredMapStyle.isHybrid ? .hybrid : .standard(elevation: .realistic))
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

            Group {
                if !liveStatus.shouldShowMapOverlayHint, liveLocation.currentLocation != nil {
                    Map(position: $mapPosition) {
                        liveAccuracyCircleContent
                        liveTrackContent
                        liveCurrentLocationAnnotation
                    }
                    .mapStyle(preferences.preferredMapStyle.isHybrid ? .hybrid : .standard(elevation: .realistic))
                    .frame(height: 290)
                    .onMapCameraChange { _ in
                        liveLocation.isFollowingLocation = false
                    }
                    .overlay(alignment: .topTrailing) {
                        MapLayerMenu(configuration: MapLayerMenu.Configuration(
                            showsTrackColor: true,
                            showsLiveOptions: true,
                            centerOnLocation: liveLocation.currentLocation == nil ? nil : {
                                liveLocation.isFollowingLocation = true
                                centerOnCurrentLocation()
                            },
                            toggleFullscreen: { isFullscreenMapPresented = true },
                            isFullscreenActive: false
                        ))
                        .padding(8)
                    }
                } else {
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

        if liveLocation.pendingUploadPointCount > 0 {
            Button(action: { liveLocation.flushPendingUploads() }) {
                Label(t("Flush Queue"), systemImage: "arrow.up.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!liveLocation.canFlushPendingUploads)
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

    private func refreshMetricSnapshot() {
        metricSnapshot = LiveTrackingPresentation.metrics(
            points: liveLocation.liveTrackPoints,
            currentLocation: liveLocation.currentLocation
        )
    }

    private func refreshTrackPresentationState() {
        polylineCoordinates = liveLocation.liveTrackPoints.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        trackSamples = liveLocation.liveTrackPoints.map {
            TrackSample(
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                timestamp: $0.timestamp
            )
        }
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
