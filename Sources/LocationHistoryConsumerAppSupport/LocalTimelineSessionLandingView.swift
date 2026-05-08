import Foundation
#if canImport(SwiftUI)
import SwiftUI

/// Phase-9A — Minimaler SwiftUI-Hook für aktive `LocalTimelineSession`.
///
/// Zeigt Session-Metadaten (importID, Source-Filename, Tages-/Pfad-/Visit-/
/// Activity-Counts aus `LocalTimelineSession.Summary`) und einen kontrollierten
/// Lösch-Button. **Kein** coord_blob-Read, **kein** Map-/Heatmap-/Overview-Hook
/// und **kein** AppExport-Rebuild — Karten/Heatmap-UI gegen den Store bleiben
/// Phase-9B-Pflicht.
///
/// Eine vollständige Store-DayList/DayDetail-UI wäre in dieser Phase zu breit
/// (sie würde Reader/Lifecycle in der View-Schicht halten und Sichtbarkeitslogik
/// für Filter/Detail einbauen). Stattdessen wird die Presentation-Schicht
/// (`LocalTimelineDayListViewState`, `LocalTimelineDayDetailViewStateAdapter`)
/// vollständig testbar gehalten und in Phase-9B als View-Hook angeschlossen.
public struct LocalTimelineSessionLandingView: View {

    private let session: LocalTimelineSession
    private let onClear: () -> Void
    private let deletionPresentation: LocalTimelineDeletionPresentation?
    @State private var deleteState: DeleteState = .idle
    @State private var deleteMessage: String?

    private enum DeleteState: Equatable {
        case idle
        case running
        case succeeded
        case failed
    }

    public init(session: LocalTimelineSession,
                onClear: @escaping () -> Void,
                deletionPresentation: LocalTimelineDeletionPresentation? = nil) {
        self.session = session
        self.onClear = onClear
        self.deletionPresentation = deletionPresentation
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summary
                if deletionPresentation != nil {
                    deleteSection
                }
                phaseNote
            }
            .padding(20)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("localTimeline.session.landing")
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Google Timeline (Local Store)")
                .font(.title2.weight(.semibold))
            Text(session.sourceFilename)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("localTimeline.session.filename")
        }
    }

    @ViewBuilder
    private var summary: some View {
        let s = session.summary
        VStack(alignment: .leading, spacing: 4) {
            row("Days", "\(s.dayCount)")
            row("Routes", "\(s.pathCount)")
            row("Visits", "\(s.visitCount)")
            row("Activities", "\(s.activityCount)")
            if let range = s.dateRange {
                row("Range", "\(range.lowerBound) … \(range.upperBound)")
            }
        }
        .accessibilityIdentifier("localTimeline.session.summary")
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(role: .destructive) {
                performDelete()
            } label: {
                Label("Delete imported local data", systemImage: "trash")
            }
            .disabled(deleteState == .running)
            .accessibilityIdentifier("localTimeline.session.delete")

            if let deleteMessage {
                Text(deleteMessage)
                    .font(.footnote)
                    .foregroundStyle(deleteState == .failed ? .red : .secondary)
                    .accessibilityIdentifier("localTimeline.session.delete.status")
            }

            Button {
                onClear()
            } label: {
                Label("Clear session", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var phaseNote: some View {
        Text("Map / Heatmap / Overview UI for the local store is not wired in this build. Coordinates are not decoded eagerly.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func performDelete() {
        guard let presenter = deletionPresentation else { return }
        deleteState = .running
        deleteMessage = "Deleting…"
        let result = presenter.performDelete()
        switch result {
        case let .deleted(report):
            deleteState = .succeeded
            deleteMessage = "Deleted. Files: \(report.removedDBFiles.count), Dirs: \(report.removedDirectories.count)"
            onClear()
        case let .failed(reason):
            deleteState = .failed
            deleteMessage = "Failed: \(reason)"
        }
    }
}
#endif
