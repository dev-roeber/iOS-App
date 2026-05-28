#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

// MARK: - AppMapTabDashboardStrip (Train F.5-B)
//
// Two additive strips below the F.5-A KPI tiles in the iOS-26 Map-Tab:
//
//  1. AppMapTabActivityTimelineStrip — horizontal carousel of the latest
//     active days (chip = weekday, date, distance, path/visit counts).
//     Tap routes the parent NavigationStack into DayDetail via the
//     supplied `onDaySelected` closure.
//  2. AppMapTabQuickActionPills — single-row pill stack with the most
//     frequent shell actions (Live, Tage, Insights, Export). Closure-
//     driven so the existing LGTabContainerView wiring stays the only
//     decision-making layer.
//
// Both live in `LocationHistoryConsumerAppSupport` so the iPad split
// path can pick them up later without duplicating the strip code.
// Pure SwiftUI on top of `lgGlassSurface`/`lgGlassPill` — no new
// dependencies, no new state stores.

// MARK: - Activity Timeline Strip

public struct AppMapTabActivityTimelineStrip: View {
    @EnvironmentObject private var preferences: AppPreferences

    let daySummaries: [DaySummary]
    let onDaySelected: (String) -> Void
    /// Cap on the number of chips rendered. Keeps the carousel snappy
    /// even on imports with thousands of days — older entries are still
    /// reachable through the Days tab.
    var maxChips: Int = 14

    public init(
        daySummaries: [DaySummary],
        onDaySelected: @escaping (String) -> Void,
        maxChips: Int = 14
    ) {
        self.daySummaries = daySummaries
        self.onDaySelected = onDaySelected
        self.maxChips = maxChips
    }

    public var body: some View {
        let chips = Array(activeDays.prefix(maxChips))
        if chips.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(t("Recent activity"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LH2GPXTheme.LiquidGlass.mapGlassPrimaryText)
                    Spacer()
                    Text(formatChipCountLabel(active: chips.count, total: activeDays.count))
                        .font(.caption2)
                        .foregroundStyle(LH2GPXTheme.LiquidGlass.mapGlassSecondaryText)
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(chips, id: \.date) { day in
                            ActivityDayChip(
                                day: day,
                                language: preferences.appLanguage,
                                onTap: { onDaySelected(day.date) }
                            )
                            .accessibilityIdentifier("mapTab.activity.chip.\(day.date)")
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .accessibilityIdentifier("mapTab.activity.strip")
        }
    }

    private var activeDays: [DaySummary] {
        daySummaries
            .filter { $0.hasContent && $0.pathCount > 0 }
            .sorted { $0.date > $1.date }
    }

    private func formatChipCountLabel(active: Int, total: Int) -> String {
        let totalText = "\(total) \(t(total == 1 ? "active day" : "active days"))"
        if active >= total { return totalText }
        return "\(active) / \(totalText)"
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

private struct ActivityDayChip: View {
    let day: DaySummary
    let language: AppLanguagePreference
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(weekdayLabel)
                    .font(.caption2.weight(.heavy))
                    .tracking(0.5)
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.trackPrimary)
                Text(dateLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.mapGlassPrimaryText)
                Text(distanceLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.mapGlassSecondaryText)
                HStack(spacing: 6) {
                    if day.pathCount > 0 {
                        ChipPill(icon: "arrow.triangle.swap", value: "\(day.pathCount)")
                    }
                    if day.visitCount > 0 {
                        ChipPill(icon: "mappin", value: "\(day.visitCount)")
                    }
                }
            }
            .frame(width: 132, alignment: .leading)
            .padding(12)
            .lgGlassSurface(cornerRadius: 16)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel([weekdayLabel, dateLabel, distanceLabel].joined(separator: ", "))
    }

    private var locale: Locale {
        Locale(identifier: language == .german ? "de_DE" : "en_US")
    }

    private var weekdayLabel: String {
        let full = AppDateDisplay.weekday(day.date, locale: locale)
        // Trim weekday to a tight 3-letter chip head (e.g. „MO" / „MON").
        // Falls back gracefully on locales where the abbreviation has a
        // dot, e.g. „Mo.".
        let trimmed = String(full.prefix(3)).trimmingCharacters(in: .punctuationCharacters)
        return trimmed.uppercased()
    }

    private var dateLabel: String {
        // mediumDate yields e.g. „21. März 2026" / „Mar 21, 2026". The
        // chip already shows the weekday above; the medium form gives
        // the user a parseable anchor in their language.
        AppDateDisplay.mediumDate(day.date)
    }

    private var distanceLabel: String {
        let km = day.totalPathDistanceM / 1000.0
        if km < 1 {
            return String(format: "%.0f m", day.totalPathDistanceM)
        }
        return String(format: "%.1f km", km)
    }
}

private struct ChipPill: View {
    let icon: String
    let value: String
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(value)
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(LH2GPXTheme.LiquidGlass.mapGlassSecondaryText)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.06), in: Capsule())
    }
}

// MARK: - Quick Action Pills

public struct AppMapTabQuickActionPills: View {
    @EnvironmentObject private var preferences: AppPreferences

    let onLiveTap: () -> Void
    let onDaysTap: () -> Void
    let onInsightsTap: () -> Void
    let onExportTap: () -> Void
    let onHeatmapTap: () -> Void

    public init(
        onLiveTap: @escaping () -> Void,
        onDaysTap: @escaping () -> Void,
        onInsightsTap: @escaping () -> Void,
        onExportTap: @escaping () -> Void,
        onHeatmapTap: @escaping () -> Void = {}
    ) {
        self.onLiveTap = onLiveTap
        self.onDaysTap = onDaysTap
        self.onInsightsTap = onInsightsTap
        self.onExportTap = onExportTap
        self.onHeatmapTap = onHeatmapTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Quick actions"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LH2GPXTheme.LiquidGlass.mapGlassPrimaryText)

            quickActionRow
        }
        .accessibilityIdentifier("mapTab.quickActions.strip")
    }

    @ViewBuilder
    private var quickActionRow: some View {
        // GlassEffectContainer groups the four pills so their morphing
        // animations stay coordinated. On iOS 25 the container is a
        // pass-through and the row renders as a plain HStack.
        LGGlassEffectGroup(spacing: 10) {
            HStack(spacing: 10) {
                pill(icon: "record.circle", title: t("Live"), tint: .red, action: onLiveTap)
                    .accessibilityIdentifier("mapTab.quickActions.live")
                pill(icon: "calendar", title: t("Days"), tint: LH2GPXTheme.LiquidGlass.trackPrimary, action: onDaysTap)
                    .accessibilityIdentifier("mapTab.quickActions.days")
                pill(icon: "flame.fill", title: t("Heatmap"), tint: .pink, action: onHeatmapTap)
                    .accessibilityIdentifier("mapTab.quickActions.heatmap")
                pill(icon: "chart.xyaxis.line", title: t("Insights"), tint: LH2GPXTheme.LiquidGlass.elevation, action: onInsightsTap)
                    .accessibilityIdentifier("mapTab.quickActions.insights")
                pill(icon: "square.and.arrow.up", title: t("Export"), tint: .orange, action: onExportTap)
                    .accessibilityIdentifier("mapTab.quickActions.export")
            }
        }
    }

    @ViewBuilder
    private func pill(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.mapGlassPrimaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 6)
            .lgGlassSurface(cornerRadius: 16, tint: tint.opacity(0.06))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}
#endif
