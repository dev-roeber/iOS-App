#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

@available(iOS 17.0, macOS 14.0, *)
public struct AppLiveTrackingView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @ObservedObject private var liveLocation: LiveLocationFeatureModel
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var hasSeededMap = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var dashboardTimer: Timer?
    @State private var recordingStartDate: Date?
    @State private var now = Date()

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

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                mapCard
                recordingSection
                if shouldShowUploadSection {
                    uploadSection
                }
                savedTracksSection
                advancedSection
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
        }
        .navigationTitle(t("Live Tracking"))
        .task {
            liveLocation.refreshAuthorization()
            syncTimerState()
        }
        .onDisappear {
            dashboardTimer?.invalidate()
            dashboardTimer = nil
        }
        .onChange(of: liveLocation.currentLocation?.timestamp) { _, _ in
            guard !hasSeededMap else { return }
            centerOnCurrentLocation()
        }
        .onChange(of: liveLocation.isRecording) { _, _ in
            syncTimerState()
        }
    }

    private var metricSnapshot: LiveTrackingMetricSnapshot {
        LiveTrackingPresentation.metrics(
            points: liveLocation.liveTrackPoints,
            currentLocation: liveLocation.currentLocation,
            referenceDate: now,
            recordingDuration: recordingDuration
        )
    }

    private var shouldShowUploadSection: Bool {
        preferences.sendsLiveLocationToServer || liveLocation.pendingUploadPointCount > 0 || liveLocation.serverUploadStatusMessage != nil
    }

    private var statusChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                statusChip(
                    title: liveLocation.isRecording ? t("Recording") : t("Idle"),
                    systemImage: liveLocation.isRecording ? "record.circle.fill" : "pause.circle.fill",
                    color: liveLocation.isRecording ? .red : .secondary
                )
                statusChip(
                    title: liveLocation.isBackgroundTrackingActive ? t("Background Ready") : t("Foreground Only"),
                    systemImage: liveLocation.isBackgroundTrackingActive ? "location.fill.viewfinder" : "location"
                )
                if shouldShowUploadSection {
                    statusChip(
                        title: t(liveLocation.uploadStatusSummary),
                        systemImage: uploadStatusIconName,
                        color: uploadStatusColor
                    )
                }
                if liveLocation.pendingUploadPointCount > 0 {
                    statusChip(
                        title: "\(liveLocation.pendingUploadPointCount) \(t(liveLocation.pendingUploadPointCount == 1 ? "Queued Point" : "Queued Points"))",
                        systemImage: "tray.full.fill",
                        color: .orange
                    )
                }
            }
        }
    }

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

            statusChips

            Group {
                if liveLocation.canDisplayLiveLocation, liveLocation.currentLocation != nil {
                    Map(position: $mapPosition) {
                        if let currentLocation = liveLocation.currentLocation {
                            Annotation(t("Current Location"), coordinate: CLLocationCoordinate2D(
                                latitude: currentLocation.latitude,
                                longitude: currentLocation.longitude
                            )) {
                                ZStack {
                                    Circle()
                                        .fill((liveLocation.isRecording ? Color.red : Color.blue).opacity(0.18))
                                        .frame(width: 42, height: 42)
                                    Circle()
                                        .fill(liveLocation.isRecording ? Color.red : Color.blue)
                                        .frame(width: 15, height: 15)
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                }
                            }
                        }
                        if liveLocation.liveTrackShouldRender {
                            MapPolyline(coordinates: liveLocation.liveTrackPoints.map {
                                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                            })
                            .stroke(.red, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .mapStyle(preferences.preferredMapStyle.isHybrid ? .hybrid : .standard(elevation: .realistic))
                    .frame(height: 290)
                    .overlay(alignment: .topTrailing) {
                        Button(action: centerOnCurrentLocation) {
                            Label(t("Center"), systemImage: "location.fill")
                                .labelStyle(.iconOnly)
                                .font(.subheadline)
                                .padding(10)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(12)
                        .accessibilityLabel(t("Center on current location"))
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 38))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(t("Location not available"))
                            .font(.headline)
                        Text(t("Start recording to request location access and see your position here."))
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
    }

    private var recordingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Recording"))
                        .font(.title3.weight(.semibold))
                    Text(recordingSubtitleText)
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
                    }
                }
            }

            Button(action: { liveLocation.setRecordingEnabled(!liveLocation.isRecording) }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill((liveLocation.isRecording ? Color.red : Color.accentColor).opacity(0.16))
                            .frame(width: 52, height: 52)
                        Image(systemName: liveLocation.isRecording ? "stop.fill" : "record.circle.fill")
                            .font(.title2)
                            .foregroundStyle(liveLocation.isRecording ? .red : .accentColor)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(liveLocation.isRecording ? t("Stop Recording") : t("Start Recording"))
                            .font(.headline)
                        Text(liveLocation.isRecording ? t("Finish the current local track and keep queued uploads ready.") : t("Begin a new local recording session with the current live settings."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background((liveLocation.isRecording ? Color.red : Color.accentColor).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(liveLocation.isAwaitingAuthorization)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statCard(icon: "scope", label: t("GPS Accuracy"), value: accuracyText, color: accuracyColor)
                statCard(icon: "clock.fill", label: t("Duration"), value: durationText, color: .blue)
                statCard(icon: "point.topleft.down.curvedto.point.bottomright.up", label: t("Points"), value: "\(liveLocation.liveTrackPoints.count)", color: .green)
                statCard(icon: "road.lanes", label: t("Distance"), value: liveDistanceText, color: .purple)
                statCard(icon: "speedometer", label: t("Current Speed"), value: currentSpeedText, color: .orange)
                statCard(icon: "chart.line.uptrend.xyaxis", label: t("Average Speed"), value: averageSpeedText, color: .indigo)
                statCard(icon: "arrow.left.and.right.circle", label: t("Last Segment"), value: lastSegmentText, color: .mint)
                statCard(icon: "clock.badge.checkmark", label: t("Update Age"), value: updateAgeText, color: .teal)
            }

            quickActionRow
        }
        .cardChrome()
    }

    private var quickActionRow: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: 10) {
                quickActionButtons
            }
            VStack(spacing: 10) {
                quickActionButtons
            }
        }
    }

    @ViewBuilder
    private var quickActionButtons: some View {
        Button(action: centerOnCurrentLocation) {
            Label(t("Center Map"), systemImage: "location.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(liveLocation.currentLocation == nil)

        if shouldShowUploadSection {
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
        }

        if liveLocation.pendingUploadPointCount > 0 {
            Button(action: { liveLocation.flushPendingUploads() }) {
                Label(t("Flush Queue"), systemImage: "arrow.up.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!liveLocation.canFlushPendingUploads)
        }
    }

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
                statusChip(
                    title: t(liveLocation.uploadStatusSummary),
                    systemImage: uploadStatusIconName,
                    color: uploadStatusColor
                )
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statCard(icon: "network", label: t("Endpoint"), value: preferences.liveLocationServerUploadConfiguration.endpointDisplayName, color: endpointStatusColor)
                statCard(icon: hasBearerTokenConfigured ? "key.fill" : "key.slash", label: t("Auth"), value: hasBearerTokenConfigured ? t("Token set") : t("No token"), color: hasBearerTokenConfigured ? .green : .orange)
                statCard(icon: "square.stack.3d.up.fill", label: t("Batch Size"), value: preferences.liveTrackingUploadBatch.title, color: .blue)
                statCard(icon: "tray.full.fill", label: t("Queue"), value: "\(liveLocation.pendingUploadPointCount) / \(liveLocation.uploadQueueLimit)", color: liveLocation.pendingUploadPointCount > 0 ? .orange : .secondary)
                statCard(icon: "exclamationmark.triangle.fill", label: t("Failures"), value: "\(liveLocation.consecutiveUploadFailures)", color: liveLocation.consecutiveUploadFailures > 0 ? .red : .secondary)
                statCard(icon: "checkmark.circle.fill", label: t("Last Success"), value: lastUploadSuccessText, color: liveLocation.lastSuccessfulUploadAt == nil ? .secondary : .green)
            }

            if let assistive = liveLocation.uploadAssistiveMessage {
                insightBanner(
                    title: t("Upload Guidance"),
                    message: t(assistive),
                    systemImage: liveLocation.consecutiveUploadFailures > 0 ? "exclamationmark.triangle" : "info.circle",
                    tint: liveLocation.consecutiveUploadFailures > 0 ? .orange : .blue
                )
            }

            if let statusMessage = liveLocation.serverUploadStatusMessage {
                insightBanner(
                    title: t("Latest Upload Status"),
                    message: t(statusMessage),
                    systemImage: uploadStatusIconName,
                    tint: uploadStatusColor
                )
            }
        }
        .cardChrome()
    }

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
                    .background(Color.green.opacity(0.12))
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
                insightBanner(
                    title: t("No saved tracks yet"),
                    message: t("Record a short route and stop it once to seed the local track library."),
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                    tint: .green
                )
            }

            if let onOpenSavedTracksLibrary {
                Button(action: onOpenSavedTracksLibrary) {
                    Label(t("Open Track Library"), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .cardChrome()
    }

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
            }

            Toggle(t("Background Recording"), isOn: $preferences.allowsBackgroundLiveTracking)
                .font(.subheadline)

            insightBanner(
                title: t(liveLocation.permissionTitle),
                message: t(liveLocation.permissionMessage),
                systemImage: statusSymbolName,
                tint: permissionTintColor
            )
        }
        .cardChrome()
    }

    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func insightBanner(
        title: String,
        message: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statusChip(title: String, systemImage: String, color: Color = .accentColor) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

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
        case "Invalid endpoint":
            return "exclamationmark.triangle.fill"
        case "Uploading":
            return "arrow.triangle.2.circlepath.circle.fill"
        case "Paused":
            return "pause.circle.fill"
        case "Needs retry":
            return "wifi.exclamationmark"
        case "Queue pending":
            return "tray.full.fill"
        case "Ready":
            return "checkmark.circle.fill"
        default:
            return "network.slash"
        }
    }

    private var uploadStatusColor: Color {
        switch liveLocation.uploadStatusSummary {
        case "Invalid endpoint", "Needs retry":
            return .orange
        case "Uploading":
            return .blue
        case "Paused":
            return .yellow
        case "Queue pending":
            return .orange
        case "Ready":
            return .green
        default:
            return .secondary
        }
    }

    private var permissionTintColor: Color {
        switch liveLocation.authorization {
        case .authorizedAlways:
            return .green
        case .authorizedWhenInUse:
            return liveLocation.needsAlwaysAuthorizationUpgrade ? .orange : .blue
        case .notDetermined:
            return .secondary
        case .restricted, .denied:
            return .red
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
        case ..<10:
            return .green
        case ..<30:
            return .mint
        case ..<65:
            return .orange
        default:
            return .red
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
        guard let speed = metricSnapshot.averageSpeedKMH else { return "–" }
        return formatSpeed(speed, unit: preferences.distanceUnit)
    }

    private var lastSegmentText: String {
        guard let distance = metricSnapshot.lastSegmentDistanceM else { return "–" }
        return formatDistance(distance, unit: preferences.distanceUnit)
    }

    private var updateAgeText: String {
        guard let age = metricSnapshot.lastUpdateAge else { return "–" }
        if age < 60 {
            return preferences.appLanguage.isGerman ? String(format: "%.0f Sek.", age) : String(format: "%.0f s", age)
        }
        if age < 3600 {
            let minutes = age / 60
            return preferences.appLanguage.isGerman ? String(format: "%.0f Min.", minutes) : String(format: "%.0f min", minutes)
        }
        let hours = age / 3600
        return preferences.appLanguage.isGerman ? String(format: "%.1f Std.", hours) : String(format: "%.1f h", hours)
    }

    private var lastUploadSuccessText: String {
        guard let date = liveLocation.lastSuccessfulUploadAt else { return "–" }
        return AppDateDisplay.abbreviatedDateTime(date)
    }

    private var statusSymbolName: String {
        switch liveLocation.authorization {
        case .notDetermined:
            return "location.circle"
        case .restricted:
            return "hand.raised.circle"
        case .denied:
            return "location.slash.circle"
        case .authorizedWhenInUse, .authorizedAlways:
            return liveLocation.isRecording ? "record.circle" : "location.circle.fill"
        }
    }

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

    private func syncTimerState() {
        dashboardTimer?.invalidate()
        now = Date()

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

private extension View {
    func cardChrome() -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.secondary.opacity(0.062))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 14, y: 5)
    }
}

#endif
