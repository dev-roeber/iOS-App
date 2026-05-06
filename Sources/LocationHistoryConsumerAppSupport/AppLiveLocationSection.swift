#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit

@available(iOS 17.0, macOS 14.0, *)
public struct AppLiveLocationSection: View {
    @EnvironmentObject private var preferences: AppPreferences
    @ObservedObject private var liveLocation: LiveLocationFeatureModel
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var hasSeededMap = false
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Local Recording"))
                        .font(.headline)
                    Text(t("Current position and saved live tracks stay separate from imported history."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(t("Record"), isOn: toggleBinding)
                    .labelsHidden()
                    .accessibilityLabel(t("Record live track"))
            }

            statusCard

            Group {
                if liveLocation.canDisplayLiveLocation, liveLocation.currentLocation != nil {
                    mapContent
                } else {
                    placeholderMap
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if liveLocation.serverUploadConfigurationState.isEnabled,
               let statusMessage = liveLocation.serverUploadStatusMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Label(t("Upload status"), systemImage: liveLocation.isUploadingToServer ? "arrow.triangle.2.circlepath.circle.fill" : "network")
                        .font(.caption.weight(.semibold))
                    Text(localizedUploadStatus(statusMessage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            savedTracksSection

            Text(liveLocation.prefersBackgroundTracking
                ? t("Completed live tracks are saved when you switch recording off. Background recording still depends on Always Allow permission and does not auto-resume after app relaunch.")
                : t("Completed live tracks are saved when you switch recording off. No automatic resume runs after app relaunch."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task {
            liveLocation.refreshAuthorization()
        }
        .onChange(of: liveLocation.currentLocation?.timestamp) { _, _ in
            guard !hasSeededMap else { return }
            centerOnCurrentLocation()
        }
    }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { liveLocation.isRecording || liveLocation.isAwaitingAuthorization },
            set: { liveLocation.setRecordingEnabled($0) }
        )
    }

    private var statusCard: some View {
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
    }

    private var mapContent: some View {
        Map(position: $mapPosition) {
            if let currentLocation = liveLocation.currentLocation {
                Marker(
                    t("Current Location"),
                    coordinate: CLLocationCoordinate2D(
                        latitude: currentLocation.latitude,
                        longitude: currentLocation.longitude
                    )
                )
                .tint(.blue)
            }

            if liveLocation.liveTrackShouldRender {
                MapPolyline(coordinates: liveLocation.liveTrackPoints.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                })
                .stroke(.green, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(preferences.preferredMapStyle.isHybrid ? .hybrid : .standard(elevation: .realistic))
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 6) {
                LHMapStyleToggleButton()
                Button(action: centerOnCurrentLocation) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .padding(8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .accessibilityLabel(t("Center on current location"))
            }
            .padding(8)
        }
    }

    private var placeholderMap: some View {
        VStack(spacing: 10) {
            Image(systemName: "location.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(t("Live location is off"))
                .font(.headline)
            Text(t("Turn recording on to request foreground-only location access and draw a live track."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .background(Color.secondary.opacity(0.05))
    }

    @ViewBuilder
    private var savedTracksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(t("Saved Live Tracks"), systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
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
                Text(t(SavedTracksPresentation.liveListMessage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(t("Record a short local track, switch Record off, then open the Saved Tracks library to edit points, insert midpoints or delete a finished track."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let onOpenSavedTracksLibrary {
                Button(action: onOpenSavedTracksLibrary) {
                    Label(t(SavedTracksPresentation.libraryButtonTitle), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        guard let currentLocation = liveLocation.currentLocation else {
            return
        }

        hasSeededMap = true
        mapPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: currentLocation.latitude,
                longitude: currentLocation.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    private func localizedUploadStatus(_ message: String) -> String {
        if !preferences.appLanguage.isGerman {
            return message
        }
        if message == "Server upload is enabled, but the URL is invalid." {
            return t(message)
        }
        if let endpoint = messageBody(after: "Server upload ready for ", in: message), endpoint.hasSuffix(".") {
            return "Server-Upload bereit für \(endpoint)"
        }
        if let body = messageBody(after: "Uploading ", in: message), let separator = body.range(of: " point") {
            let count = body[..<separator.lowerBound]
            if let endpointRange = body.range(of: " to ") {
                let endpoint = body[endpointRange.upperBound...].dropLast()
                return "Lade \(count) \(count == "1" ? "Punkt" : "Punkte") zu \(endpoint) hoch."
            }
        }
        if let body = messageBody(after: "Last upload sent ", in: message), let separator = body.range(of: " point") {
            let count = body[..<separator.lowerBound]
            if let endpointRange = body.range(of: " to ") {
                let endpoint = body[endpointRange.upperBound...].dropLast()
                return "Letzter Upload hat \(count) \(count == "1" ? "Punkt" : "Punkte") an \(endpoint) gesendet."
            }
        }
        if let error = messageBody(after: "Server upload failed: ", in: message) {
            return "Server-Upload fehlgeschlagen: \(error)"
        }
        return t(message)
    }

    private func messageBody(after prefix: String, in message: String) -> String? {
        guard message.hasPrefix(prefix) else {
            return nil
        }
        return String(message.dropFirst(prefix.count))
    }
}
#endif
