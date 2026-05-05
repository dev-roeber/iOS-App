#if canImport(SwiftUI)
import SwiftUI

// MARK: - LHLiveBottomBar

/// Sticky bottom bar for the Live Tracking screen.
/// Renders a full-width Start (mint) or Stop (red) CTA button.
public struct LHLiveBottomBar: View {

    let isRecording: Bool
    let isDisabled: Bool
    let startTitle: String
    let stopTitle: String
    let onToggle: () -> Void

    public init(
        isRecording: Bool,
        isDisabled: Bool,
        startTitle: String,
        stopTitle: String,
        onToggle: @escaping () -> Void
    ) {
        self.isRecording = isRecording
        self.isDisabled  = isDisabled
        self.startTitle  = startTitle
        self.stopTitle   = stopTitle
        self.onToggle    = onToggle
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: onToggle) {
                Label(
                    isRecording ? stopTitle : startTitle,
                    systemImage: isRecording ? "stop.fill" : "record.circle.fill"
                )
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(isRecording ? LH2GPXTheme.dangerRed : LH2GPXTheme.liveMint)
            .disabled(isDisabled)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .accessibilityIdentifier(isRecording ? "live.recording.stopAction" : "live.recording.primaryAction")
            .background(.bar)
        }
    }
}

// MARK: - LHLiveTrackRow

/// Dark card row for a saved live track in the library list.
/// Wraps SavedTrackSummaryContentView with the LH2GPX card surface.
struct LHLiveTrackRow: View {

    let presentation: SavedTrackRowPresentation

    var body: some View {
        SavedTrackSummaryContentView(presentation: presentation)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(LH2GPXTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LH2GPXTheme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#endif
