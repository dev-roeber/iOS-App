#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct AppRecordedTracksLibraryView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @ObservedObject private var liveLocation: LiveLocationFeatureModel

    let onNewTrack: (() -> Void)?

    init(liveLocation: LiveLocationFeatureModel, onNewTrack: (() -> Void)? = nil) {
        self._liveLocation = ObservedObject(wrappedValue: liveLocation)
        self.onNewTrack = onNewTrack
    }

    var body: some View {
        ScrollView {
            LHPageScaffold {
                infoCard
                trackListSection
                if let onNewTrack {
                    newTrackButton(action: onNewTrack)
                }
            }
        }
        .navigationTitle(t("Live Tracks"))
        .navigationDestination(for: RecordedTrack.self) { track in
            AppRecordedTrackEditorView(track: track, liveLocation: liveLocation)
        }
        .accessibilityIdentifier("liveTracks.title")
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(t("Stored Locally"), systemImage: "internaldrive")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LH2GPXTheme.liveMint)

            Text(t("Separate from imported history"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(t("This local track library is separate from imported history. Open any saved live track to edit points, insert midpoints or remove it from local storage."))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                librarySummaryBadge(
                    title: savedCountText(liveLocation.recordedTracks.count),
                    systemImage: "tray.full"
                )
                if let latestTrack = liveLocation.recordedTracks.first {
                    librarySummaryBadge(
                        title: AppDateDisplay.abbreviatedDate(latestTrack.startedAt),
                        systemImage: "clock"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardChrome()
        .accessibilityIdentifier("liveTracks.info")
    }

    // MARK: - Track List

    @ViewBuilder
    private var trackListSection: some View {
        if liveLocation.recordedTracks.isEmpty {
            emptyStateCard
        } else {
            VStack(alignment: .leading, spacing: 10) {
                LHSectionHeader(t("Live Tracks"))

                ForEach(Array(liveLocation.recordedTracks.enumerated()), id: \.element.id) { index, track in
                    NavigationLink(value: track) {
                        LHLiveTrackRow(
                            presentation: SavedTrackPresentation.row(
                                for: track,
                                unit: preferences.distanceUnit,
                                language: preferences.appLanguage
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("liveTracks.row.\(index)")
                }
            }
            .accessibilityIdentifier("liveTracks.list")
        }
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(t("No saved tracks yet"), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LH2GPXTheme.liveMint)
            Text(t("Go to any day, open Local Recording, record a short track and switch Record off. The finished track will appear here."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LH2GPXTheme.liveMint.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LH2GPXTheme.liveMint.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func newTrackButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(t("New Track"), systemImage: "record.circle.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(LH2GPXTheme.liveMint)
        .accessibilityIdentifier("liveTracks.newTrack")
    }

    // MARK: - Helpers

    private func librarySummaryBadge(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))
            .clipShape(Capsule())
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    private func savedCountText(_ count: Int) -> String {
        preferences.appLanguage.isGerman
            ? "\(count) gespeichert"
            : "\(count) saved"
    }
}
#endif
