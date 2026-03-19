#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

// MARK: - Overview Section

public struct AppOverviewSection: View {
    let overview: ExportOverview
    let daySummaries: [DaySummary]
    var onDaysTap: (() -> Void)? = nil
    var onInsightsTap: (() -> Void)? = nil

    public init(
        overview: ExportOverview,
        daySummaries: [DaySummary] = [],
        onDaysTap: (() -> Void)? = nil,
        onInsightsTap: (() -> Void)? = nil
    ) {
        self.overview = overview
        self.daySummaries = daySummaries
        self.onDaysTap = onDaysTap
        self.onInsightsTap = onInsightsTap
    }

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 160), spacing: 12)
    ]

    public var body: some View {
        let presentation = OverviewPresentation.section(
            overview: overview,
            daySummaries: daySummaries
        )

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Imported History")
                    .font(.title3.weight(.semibold))
                Text(presentation.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(presentation.stats) { stat in
                    statCard(
                        stat,
                        action: stat.id == "days" ? onDaysTap : onInsightsTap
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func statCard(_ stat: OverviewStatPresentation, action: (() -> Void)? = nil) -> some View {
        Group {
            if let action {
                Button(action: action) {
                    statCardBody(stat, isInteractive: true)
                }
                .buttonStyle(.plain)
            } else {
                statCardBody(stat, isInteractive: false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([stat.value, stat.label, stat.note].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(action != nil ? .isButton : [])
    }

    @ViewBuilder
    private func statCardBody(_ stat: OverviewStatPresentation, isInteractive: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: stat.icon)
                .font(.title3)
                .foregroundColor(stat.color)
            Text(stat.value)
                .font(.title2.weight(.bold).monospacedDigit())
            Text(stat.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let note = stat.note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: 28)
            }
            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(stat.color.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(stat.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#endif
