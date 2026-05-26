#if canImport(SwiftUI)
import SwiftUI

/// LG-stil KPI-Tile for the Liquid-Glass Dashboard.
///
/// Spec §8 (`03_LG_ROOT.md`): The `label` parameter is mandatory and must be
/// non-empty. This is enforced via `precondition` so debug builds crash early
/// when a tile is wired without a localized label (a recurring P1.4 issue in
/// pre-Prompt-03 builds).
///
/// Visual tokens are sourced from the existing `LH2GPXTheme.LiquidGlass`
/// palette to stay consistent with `LHLiquidGlassMetricTile` and the rest of
/// the LG components in `LocationHistoryConsumerAppSupport`. The component is
/// intentionally backdrop-agnostic — wrap callers in `LHLiquidGlassSurface`
/// (or any other Liquid-Glass surface) to add the floating glass background.
public struct LGKPITile: View {
    public let value: String
    public let label: String
    public let icon: String
    public let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didAppear = false

    public init(value: String, label: String, icon: String, tint: Color) {
        precondition(!label.isEmpty, "LGKPITile requires a non-empty label")
        self.value = value
        self.label = label
        self.icon = icon
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
            }
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption.weight(.medium))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: LH2GPXTheme.LiquidGlass.cardRadius,
                style: .continuous
            )
            .fill(Color.white.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: LH2GPXTheme.LiquidGlass.cardRadius,
                style: .continuous
            )
            .stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
        .opacity(reduceMotion ? 1 : (didAppear ? 1 : 0))
        .scaleEffect(reduceMotion ? 1 : (didAppear ? 1 : 0.96))
        .onAppear {
            guard !reduceMotion else {
                didAppear = true
                return
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                didAppear = true
            }
        }
    }
}

#endif
