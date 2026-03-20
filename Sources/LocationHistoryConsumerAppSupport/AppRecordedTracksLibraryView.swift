#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct AppRecordedTracksLibraryView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @ObservedObject private var liveLocation: LiveLocationFeatureModel

    init(liveLocation: LiveLocationFeatureModel) {
        self._liveLocation = ObservedObject(wrappedValue: liveLocation)
    }

    var body: some View {
        List {
            summarySection

            if liveLocation.recordedTracks.isEmpty {
                emptyStateSection
            } else {
                tracksSection
            }
        }
        .navigationTitle("Saved Live Tracks")
        .navigationDestination(for: RecordedTrack.self) { track in
            AppRecordedTrackEditorView(track: track, liveLocation: liveLocation)
        }
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Saved Live Tracks", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.headline)
                Text("This local track library is separate from imported history. Open any saved live track to edit points, insert midpoints or remove it from local storage.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    librarySummaryBadge(
                        title: "\(liveLocation.recordedTracks.count) saved",
                        systemImage: "tray.full"
                    )
                    if let latestTrack = liveLocation.recordedTracks.first {
                        librarySummaryBadge(
                            title: AppDateDisplay.abbreviatedDate(latestTrack.startedAt),
                            systemImage: "clock"
                        )
                    }
                }

                if let latestTrack = liveLocation.recordedTracks.first {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(SavedTracksPresentation.latestTrackLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        SavedTrackSummaryContentView(
                            presentation: SavedTrackPresentation.row(
                                for: latestTrack,
                                unit: preferences.distanceUnit
                            )
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyStateSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("No saved live tracks yet.")
                    .font(.subheadline.weight(.semibold))
                Text("Go to any day, open Local Recording, record a short track and switch Record off. The finished track will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var tracksSection: some View {
        Section("Saved Live Tracks") {
            ForEach(liveLocation.recordedTracks) { track in
                NavigationLink(value: track) {
                    SavedTrackSummaryContentView(
                        presentation: SavedTrackPresentation.row(
                            for: track,
                            unit: preferences.distanceUnit
                        )
                    )
                }
            }
        }
    }

    private func librarySummaryBadge(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))
            .clipShape(Capsule())
    }
}
#endif
