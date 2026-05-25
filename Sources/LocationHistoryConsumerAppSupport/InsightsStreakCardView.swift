#if canImport(SwiftUI)
import SwiftUI

/// Single streak metric tile rendered inside the Insights "Activity Streak"
/// section. Extracted from `AppInsightsContentView.streakCard(...)` during
/// the Insights-Refactor train to shrink the parent view's body and give
/// the tile a clear, separately-testable identity.
///
/// Pure presentation — no `@State`, no `@EnvironmentObject`, no
/// calculation logic. Receives already-formatted display strings from
/// the caller so the streak math stays in `InsightsStreakPresentation`
/// / `derivedModel.streak` and is not duplicated here.
struct InsightsStreakCardView: View {
    let value: String
    let unit: String
    let label: String
    let icon: String
    let color: Color
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2.weight(.semibold).monospacedDigit())
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value) \(unit)")
    }
}

#endif
