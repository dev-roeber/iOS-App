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
    @State private var recordingTimer: Timer? = nil
    @State private var recordingStartDate: Date? = nil
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
            VStack(alignment: .leading, spacing: 16) {
                mapSection
                recordControlSection
                if liveLocation.isRecording {
                    liveStatsSection
                }
                permissionStatusSection
                if preferences.sendsLiveLocationToServer {
                    serverStatusSection
                }
                savedTracksSection
            }
            .padding(.bottom, 20)
        }
        .navigationTitle(t("Live Tracking"))
        .task {
            liveLocation.refreshAuthorization()
        }
        .onChange(of: liveLocation.currentLocation?.timestamp) { _, _ in
            guard !hasSeededMap else { return }
            centerOnCurrentLocation()
        }
        .onChange(of: liveLocation.isRecording) { _, isRecording in
            if isRecording {
                recordingStartDate = Date()
                recordingDuration = 0
                recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    recordingDuration = Date().timeIntervalSince(recordingStartDate ?? Date())
                }
            } else {
                recordingTimer?.invalidate()
                recordingTimer = nil
                recordingStartDate = nil
                recordingDuration = 0
            }
        }
    }

    // MARK: - Map

    private var mapSection: some View {
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
                                    .fill(liveLocation.isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                Circle()
                                    .fill(liveLocation.isRecording ? Color.red : Color.blue)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            }
                        }
                    }
                    if liveLocation.liveTrackShouldRender {
                        MapPolyline(coordinates: liveLocation.liveTrackPoints.map {
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        })
                        .stroke(.red, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }
                }
                .mapStyle(preferences.preferredMapStyle.isHybrid ? .hybrid : .standard(elevation: .realistic))
                .frame(height: 320)
                .overlay(alignment: .topTrailing) {
                    Button(action: centerOnCurrentLocation) {
                        Image(systemName: "location.fill")
                            .font(.subheadline)
                            .padding(10)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(12)
                    .accessibilityLabel(t("Center on current location"))
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.secondary.opacity(0.05))
                    VStack(spacing: 12) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(t("Location not available"))
                            .font(.headline)
                        Text(t("Start recording to request location access and see your position here."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                .frame(height: 320)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    // MARK: - Record Control

    private var recordControlSection: some View {
        VStack(spacing: 12) {
            Button(action: { liveLocation.setRecordingEnabled(!liveLocation.isRecording) }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(liveLocation.isRecording ? Color.red : Color.accentColor)
                            .frame(width: 48, height: 48)
                        Image(systemName: liveLocation.isRecording ? "stop.fill" : "record.circle")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(liveLocation.isRecording ? t("Stop Recording") : t("Start Recording"))
                            .font(.headline)
                        Text(liveLocation.isRecording ? t("Tap to finish and save the current track.") : t("Tap to begin recording your route."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background((liveLocation.isRecording ? Color.red : Color.accentColor).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(liveLocation.isAwaitingAuthorization)
            .padding(.horizontal)

            Toggle(t("Background Recording"), isOn: $preferences.allowsBackgroundLiveTracking)
                .font(.subheadline)
                .padding(.horizontal)
                .padding(.vertical, 2)
        }
    }

    // MARK: - Live Stats (nur während Aufnahme)

    private var liveStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Live Stats"))
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                liveStatCard(
                    icon: "antenna.radiowaves.left.and.right",
                    label: t("GPS Accuracy"),
                    value: accuracyText,
                    color: accuracyColor
                )
                liveStatCard(
                    icon: "clock",
                    label: t("Duration"),
                    value: durationText,
                    color: .blue
                )
                liveStatCard(
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    label: t("Points"),
                    value: "\(liveLocation.liveTrackPoints.count)",
                    color: .green
                )
                liveStatCard(
                    icon: "road.lanes",
                    label: t("Distance"),
                    value: liveDistanceText,
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
    }

    private func liveStatCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Permission Status

    private var permissionStatusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(t(liveLocation.permissionTitle), systemImage: statusSymbolName)
                .font(.subheadline.weight(.medium))
            Text(t(liveLocation.permissionMessage))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal)
    }

    // MARK: - Server Status

    private var serverStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(t("Server Upload"), systemImage: "network")
                .font(.headline)

            VStack(spacing: 8) {
                serverStatRow(
                    label: t("Endpoint"),
                    value: preferences.liveLocationServerUploadConfiguration.endpointDisplayName
                )
                serverStatRow(
                    label: t("Auth"),
                    value: preferences.liveLocationServerUploadBearerToken.isEmpty ? t("No Token") : t("Token set")
                )
                serverStatRow(
                    label: t("Batch Size"),
                    value: preferences.liveTrackingUploadBatch.title
                )
                if liveLocation.pendingUploadPointCount > 0 {
                    serverStatRow(
                        label: t("Queued"),
                        value: "\(liveLocation.pendingUploadPointCount) \(liveLocation.pendingUploadPointCount == 1 ? t("point") : t("points"))"
                    )
                }
                if let statusMessage = liveLocation.serverUploadStatusMessage {
                    HStack(spacing: 8) {
                        Image(systemName: liveLocation.isUploadingToServer ? "arrow.triangle.2.circlepath.circle.fill" : "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(liveLocation.isUploadingToServer ? .orange : .green)
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }

    private func serverStatRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
        }
    }

    // MARK: - Saved Tracks

    private var savedTracksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(t("Saved Live Tracks"), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.headline)
                Spacer()
                Text("\(liveLocation.recordedTracks.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
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
                Text(t("No saved tracks yet. Start recording to capture your first live track."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let onOpenSavedTracksLibrary {
                Button(action: onOpenSavedTracksLibrary) {
                    Label(t("Open Track Library"), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private var statusSymbolName: String {
        switch liveLocation.authorization {
        case .notDetermined: return "location.circle"
        case .restricted: return "hand.raised.circle"
        case .denied: return "location.slash.circle"
        case .authorizedWhenInUse, .authorizedAlways:
            return liveLocation.isRecording ? "record.circle" : "location.circle.fill"
        }
    }

    private var accuracyText: String {
        guard let loc = liveLocation.currentLocation else { return "–" }
        return String(format: "± %.0f m", loc.horizontalAccuracyM)
    }

    private var accuracyColor: Color {
        guard let loc = liveLocation.currentLocation else { return .secondary }
        switch loc.horizontalAccuracyM {
        case ..<10: return .green
        case ..<30: return .mint
        case ..<65: return .orange
        default: return .red
        }
    }

    private var durationText: String {
        let h = Int(recordingDuration) / 3600
        let m = (Int(recordingDuration) % 3600) / 60
        let s = Int(recordingDuration) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private var liveDistanceText: String {
        let points = liveLocation.liveTrackPoints
        guard points.count >= 2 else { return "0 m" }
        var total = 0.0
        for i in 1..<points.count {
            let a = LocationCoordinate2D(latitude: points[i-1].latitude, longitude: points[i-1].longitude)
            let b = LocationCoordinate2D(latitude: points[i].latitude, longitude: points[i].longitude)
            total += a.distance(to: b)
        }
        if preferences.distanceUnit == .imperial {
            let miles = total / 1609.344
            return miles < 0.1 ? String(format: "%.0f ft", total * 3.28084) : String(format: "%.2f mi", miles)
        }
        return total < 1000 ? String(format: "%.0f m", total) : String(format: "%.2f km", total / 1000)
    }

    private func centerOnCurrentLocation() {
        guard let loc = liveLocation.currentLocation else { return }
        hasSeededMap = true
        mapPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
}
#endif
