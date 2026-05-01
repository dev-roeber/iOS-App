#if canImport(SwiftUI)
import SwiftUI

// MARK: - LHInsightsMetricItem

/// Data model for a single KPI tile in LHInsightsMetricGrid.
public struct LHInsightsMetricItem: Identifiable {
    public let id: String
    public let icon: String
    public let label: String
    public let value: String
    public let color: Color
    public let accessibilityId: String

    public init(
        id: String,
        icon: String,
        label: String,
        value: String,
        color: Color,
        accessibilityId: String = ""
    ) {
        self.id = id
        self.icon = icon
        self.label = label
        self.value = value
        self.color = color
        self.accessibilityId = accessibilityId
    }
}

// MARK: - LHInsightsMetricGrid

/// 2×2 grid of LHMetricCard tiles for an Insights KPI section.
///
/// Usage:
/// ```swift
/// LHInsightsMetricGrid(items: [
///     LHInsightsMetricItem(id: "distance", icon: "road.lanes", label: "Distance",
///                          value: "42 km", color: .purple, accessibilityId: "insights.kpi.distance"),
///     ...
/// ])
/// ```
public struct LHInsightsMetricGrid: View {
    let items: [LHInsightsMetricItem]

    public init(items: [LHInsightsMetricItem]) {
        self.items = items
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items) { item in
                LHMetricCard(
                    icon: item.icon,
                    label: item.label,
                    value: item.value,
                    color: item.color
                )
                .accessibilityIdentifier(item.accessibilityId)
            }
        }
    }
}

// MARK: - LHInsightsChartCard

/// Section card shell for chart content with an optional share button.
/// Applies LH2GPXTheme card surface, hairline border and shadow.
public struct LHInsightsChartCard<Content: View>: View {
    let title: String
    let systemImage: String
    var shareIdentifier: String?
    var onShare: (() -> Void)?
    @ViewBuilder let content: () -> Content

    public init(
        title: String,
        systemImage: String,
        shareIdentifier: String? = nil,
        onShare: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.shareIdentifier = shareIdentifier
        self.onShare = onShare
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Label(title, systemImage: systemImage)
                    .font(.title3.weight(.semibold))
                Spacer()
                if let onShare, let shareIdentifier {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LH2GPXTheme.primaryBlue)
                            .padding(8)
                            .background(LH2GPXTheme.chipBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(shareIdentifier)
                }
            }
            content()
        }
        .padding(18)
        .background(LH2GPXTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LH2GPXTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: LH2GPXTheme.cardShadow, radius: 10, y: 3)
    }
}

// MARK: - LHInsightsTopDayRow

/// Compact rank row for a Top Days list.
/// Shows rank badge, formatted date text and the primary metric value.
public struct LHInsightsTopDayRow: View {
    let rank: Int
    let dateText: String
    let primaryValue: String
    var accent: Color
    var isInteractive: Bool

    public init(
        rank: Int,
        dateText: String,
        primaryValue: String,
        accent: Color = LH2GPXTheme.warningOrange,
        isInteractive: Bool = false
    ) {
        self.rank = rank
        self.dateText = dateText
        self.primaryValue = primaryValue
        self.accent = accent
        self.isInteractive = isInteractive
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(rank)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(accent.opacity(0.12))
                .clipShape(Circle())

            Text(dateText)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(primaryValue)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(accent)

            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(accent.opacity(0.5))
            }
        }
        .padding(10)
        .background(accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - LHInsightsActionRow

/// A tappable action row used in drilldown confirmation dialogs and action sections.
public struct LHInsightsActionRow: View {
    let label: String
    let systemImage: String
    var tint: Color
    let action: () -> Void

    public init(
        label: String,
        systemImage: String,
        tint: Color = LH2GPXTheme.primaryBlue,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 20)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.caption)
                    .foregroundStyle(tint.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(tint.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#endif
