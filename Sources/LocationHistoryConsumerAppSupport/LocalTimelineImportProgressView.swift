#if canImport(SwiftUI)
import SwiftUI

/// Phase-10A P1-A/B (Weg 2) — sichtbare Progress/Cancel-UI für den
/// feature-flagged Store-Import.
///
/// Zeigt Phase, Counter-Block, optional Bytes/Prozent und (sofern
/// `progress.isCancellable`) einen "Cancel"-Button. Dark-Mode-freundlich,
/// Accessibility-Labels für Status und Cancel-Button. Keine Animation,
/// keine Karte/Heatmap/Overview-Änderung — nur die Loading-Surface.
public struct LocalTimelineImportProgressView: View {

    @ObservedObject private var state: LocalTimelineImportUIState
    private let onCancel: (() -> Void)?
    private let onCleared: (() -> Void)?

    public init(
        state: LocalTimelineImportUIState,
        onCancel: (() -> Void)? = nil,
        onCleared: (() -> Void)? = nil
    ) {
        self._state = ObservedObject(wrappedValue: state)
        self.onCancel = onCancel
        self.onCleared = onCleared
    }

    public var body: some View {
        if let presentation = state.presentation {
            content(presentation)
        } else {
            // Erster Render-Frame: noch kein Snapshot geliefert. Platzhalter
            // bleibt unsichtbar, damit der Legacy-Spinner sichtbar bleibt.
            EmptyView()
        }
    }

    @ViewBuilder
    private func content(_ p: LocalTimelineImportProgressPresentation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if p.isCancellable {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .accessibilityHidden(true)
                }
                Text(p.statusText)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("localTimeline.progress.status")
                    .accessibilityLabel(Text(p.statusText))
                Spacer(minLength: 0)
            }

            Text(p.countsText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("localTimeline.progress.counts")

            if let skipped = p.skippedText {
                Text(skipped)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("localTimeline.progress.skipped")
            }

            if let day = p.currentDayText {
                Text(day)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("localTimeline.progress.day")
            }

            if let bytes = p.bytesText, let percent = p.percentText {
                HStack(spacing: 6) {
                    Text(percent)
                        .font(.footnote.weight(.semibold))
                    Text("·").foregroundStyle(.secondary)
                    Text(bytes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("localTimeline.progress.bytes")
            }

            if p.isCancellable {
                Button(role: .cancel, action: { onCancel?() }) {
                    Text("Cancel import")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
                .accessibilityIdentifier("localTimeline.progress.cancel")
                .accessibilityLabel(Text("Cancel import"))
                .accessibilityHint(Text("Stops the running import and rolls back the open transaction."))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.18))
        )
        .frame(maxWidth: 520)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
    }
}

/// Test-Mode-Banner — eine Zeile, die ausschließlich bei aktivem
/// `LocalTimelineFeatureFlags.isLocalTimelineStoreEnabled`-Pfad gerendert wird.
/// Macht den Pre-production-Status für TestFlight-Tester deutlich sichtbar.
public struct LocalTimelineTestModeBanner: View {

    private let title: String
    private let subtitle: String

    public init(
        title: String = "Pre-production · Internal test mode",
        subtitle: String = "Local Timeline Store path is feature-flagged and default OFF outside this build."
    ) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "testtube.2")
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.18))
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .accessibilityIdentifier("localTimeline.testMode.banner")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title). \(subtitle)"))
    }
}
#endif
