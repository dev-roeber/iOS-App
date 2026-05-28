#if canImport(SwiftUI)
import SwiftUI

/// Compact metric tile used inside the map-first bottom sheet dashboard.
/// Renders an icon, value, label and optional subtitle on a Liquid Glass surface
/// and exposes a combined accessibility label so it is never color-only.
/// See docs/UI_UX_MAP_FIRST_LIQUID_GLASS_CONTRACT_2026-05-28.md § 5.5.
@available(iOS 26.0, macOS 15.0, *)
public struct LHMapMetricCard: View {
    private let icon: String
    private let label: String
    private let value: String
    private let subtitle: String?
    private let tint: Color?
    private let accessibilityValueText: String?

    public init(
        icon: String,
        label: String,
        value: String,
        subtitle: String? = nil,
        tint: Color? = nil,
        accessibilityValue: String? = nil
    ) {
        self.icon = icon
        self.label = label
        self.value = value
        self.subtitle = subtitle
        self.tint = tint
        self.accessibilityValueText = accessibilityValue
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill((tint ?? LH2GPXTheme.LiquidGlass.trackPrimary).opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint ?? LH2GPXTheme.LiquidGlass.ink)
                    .accessibilityHidden(true)
            }

            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)

            Text(label)
                .font(.caption)
                .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .lgGlassSurface(cornerRadius: 16, tint: tint?.opacity(0.05))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(combinedAccessibilityLabel))
    }

    private var combinedAccessibilityLabel: String {
        var parts: [String] = [value, label]
        if let subtitle, !subtitle.isEmpty { parts.append(subtitle) }
        if let extra = accessibilityValueText, !extra.isEmpty { parts.append(extra) }
        return parts.joined(separator: ", ")
    }
}
#endif
