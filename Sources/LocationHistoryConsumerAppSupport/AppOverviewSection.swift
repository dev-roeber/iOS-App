#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

// MARK: - Overview Section

public struct AppOverviewSection: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.verticalSizeClass) private var verticalSizeClass
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

    // Portrait: pin to 2 columns so a 4-stat payload renders as a balanced
    // 2x2 grid instead of the previous 3+1 asymmetric layout produced by
    // `.adaptive(minimum: 100)`. For stat counts != 4 we fall back to an
    // adaptive layout so 3/5/6 tiles still wrap sensibly.
    private let portraitColumns2x2 = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let portraitColumnsAdaptive = [
        GridItem(.adaptive(minimum: 140), spacing: 12)
    ]

    // Landscape (compact-vertical) on iPhone: pin to 2 columns so KPI tiles
    // stay legible and values aren't squeezed. See Prompt 06 LANDSCAPE §A2.
    private let landscapeColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private func gridColumns(for statCount: Int) -> [GridItem] {
        if verticalSizeClass == .compact {
            return landscapeColumns
        }
        return statCount == 4 ? portraitColumns2x2 : portraitColumnsAdaptive
    }

    public var body: some View {
        let presentation = OverviewPresentation.section(
            overview: overview,
            daySummaries: daySummaries,
            language: preferences.appLanguage
        )

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Imported History"))
                    .font(.title3.weight(.semibold))
                Text(presentation.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: gridColumns(for: presentation.stats.count),
                spacing: 12
            ) {
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
                .foregroundColor(stat.color.swiftUIColor)
            Text(stat.value)
                .font(.title2.weight(.bold).monospacedDigit())
            Text(t(stat.label))
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
                    .foregroundStyle(stat.color.swiftUIColor.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(
            ZStack {
                // Solid tint base so the tile-color sticht heraus.
                stat.color.swiftUIColor.opacity(0.28)
                // Sanfter Gradient nach unten für etwas Tiefe.
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.04),
                        Color.black.opacity(0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(stat.color.swiftUIColor.opacity(0.35), lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

#endif
