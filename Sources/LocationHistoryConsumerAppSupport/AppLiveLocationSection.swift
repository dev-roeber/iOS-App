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

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Recording")
                        .font(.headline)
                    Text("Current position and saved live tracks stay separate from imported history.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Record", isOn: toggleBinding)
                    .labelsHidden()
                    .accessibilityLabel("Record live track")
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

            savedTracksSection

            Text("Completed live tracks are saved when you switch recording off. No automatic resume runs after app relaunch.")
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
            Label(liveLocation.permissionTitle, systemImage: statusSymbolName)
                .font(.subheadline.weight(.medium))
            Text(liveLocation.permissionMessage)
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
                    "Current Location",
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
            Button(action: centerOnCurrentLocation) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(8)
            .accessibilityLabel("Center on current location")
        }
    }

    private var placeholderMap: some View {
        VStack(spacing: 10) {
            Image(systemName: "location.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Live location is off")
                .font(.headline)
            Text("Turn recording on to request foreground-only location access and draw a live track.")
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
                Label("Saved Live Tracks", systemImage: "slider.horizontal.3")
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
                        unit: preferences.distanceUnit
                    )
                )
                Text(SavedTracksPresentation.liveListMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Record a short local track, switch Record off, then open the Saved Tracks library to edit points, insert midpoints or delete a finished track.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let onOpenSavedTracksLibrary {
                Button(action: onOpenSavedTracksLibrary) {
                    Label(SavedTracksPresentation.libraryButtonTitle, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
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
}
#endif
