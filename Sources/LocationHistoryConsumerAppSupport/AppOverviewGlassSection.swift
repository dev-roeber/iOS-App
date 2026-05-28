#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

// MARK: - AppOverviewGlassSection (Train F.5-A)
//
// Drop-in alternative to `AppOverviewSection` that renders the KPI tiles
// in the Liquid-Glass language introduced by `AppShellWelcomeView` (F.4).
// Same init shape, same `OverviewPresentation.section(...)` data source —
// only the chrome around each tile changes.
//
// Behaviour:
//  - iOS 26+ : tiles morph inside a `GlassEffectContainer`, each tile is
//              identified via `glassEffectID(_, in: namespace)` so taps
//              and content changes animate as a coordinated group.
//  - iOS 25  : plain `LazyVGrid` with `lgGlassSurface(cornerRadius:)`
//              backing — keeps the same visual rhythm without the native
//              glass morph.
//
// Legacy `AppOverviewSection` is intentionally NOT touched: the iPad
// `AppContentSplitView` path keeps its long-running stat-card design,
// and a one-word revert in the iPhone `mapTab` falls back to it.

public struct AppOverviewGlassSection: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Namespace private var tilesNamespace

    let overview: ExportOverview
    let daySummaries: [DaySummary]
    var onDaysTap: (() -> Void)?
    var onInsightsTap: (() -> Void)?

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

    // Same grid heuristic as the legacy `AppOverviewSection` — 2x2 for
    // exactly four stats, adaptive otherwise; landscape always 2 columns.
    private let portraitColumns2x2 = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    private let portraitColumnsAdaptive = [
        GridItem(.adaptive(minimum: 140), spacing: 12)
    ]
    private let landscapeColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private func gridColumns(for statCount: Int) -> [GridItem] {
        if verticalSizeClass == .compact { return landscapeColumns }
        return statCount == 4 ? portraitColumns2x2 : portraitColumnsAdaptive
    }

    public var body: some View {
        let presentation = OverviewPresentation.section(
            overview: overview,
            daySummaries: daySummaries,
            language: preferences.appLanguage
        )

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t("Imported History"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
                Text(presentation.subtitle)
                    .font(.caption)
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
            }

            tilesGrid(stats: presentation.stats)
        }
    }

    @ViewBuilder
    private func tilesGrid(stats: [OverviewStatPresentation]) -> some View {
        if #available(iOS 26.0, macOS 15.0, *) {
            GlassEffectContainer(spacing: 12) {
                LazyVGrid(columns: gridColumns(for: stats.count), spacing: 12) {
                    ForEach(stats) { stat in
                        tile(stat)
                            .glassEffectID(stat.id, in: tilesNamespace)
                    }
                }
            }
        } else {
            LazyVGrid(columns: gridColumns(for: stats.count), spacing: 12) {
                ForEach(stats) { stat in
                    tile(stat)
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ stat: OverviewStatPresentation) -> some View {
        let action = stat.id == "days" ? onDaysTap : onInsightsTap
        Group {
            if let action {
                Button(action: action) { tileBody(stat, isInteractive: true) }
                    .buttonStyle(.plain)
            } else {
                tileBody(stat, isInteractive: false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([stat.value, stat.label, stat.note].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(action != nil ? .isButton : [])
    }

    @ViewBuilder
    private func tileBody(_ stat: OverviewStatPresentation, isInteractive: Bool) -> some View {
        let tint = stat.color.swiftUIColor
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.20))
                    .frame(width: 32, height: 32)
                Image(systemName: stat.icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(tint)
            }
            Text(stat.value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
            Text(t(stat.label))
                .font(.caption)
                .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
            if let note = stat.note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: 28)
            }
            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .lgGlassSurface(cornerRadius: 16, tint: tint.opacity(0.05))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}
#endif
