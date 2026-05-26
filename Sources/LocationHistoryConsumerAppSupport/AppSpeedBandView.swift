// AppSpeedBandView
//
// A reusable, minimizable speed-band visualization for Live / DayDetail /
// Insights / Export. Purely presentational: caller hands in a sequence of
// speed samples (m/s by default; pass `unit: .kmh` if values are already in
// km/h) and an optional highlighted timestamp for the recording-position
// marker. Two height states (compact ≈ 60pt, expanded ≈ 200pt) are toggled
// by tapping the band, with a Reduce-Motion-aware animation.
//
// The card surface follows the LiveBottomSheet glass treatment:
// `Color.white.opacity(0.06)` + a soft white→clear gradient + ultraThinMaterial
// + a hairline outline (`LH2GPXTheme.LiquidGlass.hairline`). On non-SwiftUI
// or non-Charts targets the file is empty so Linux CI keeps building.

#if canImport(SwiftUI)
import SwiftUI

public enum AppSpeedBandUnit: Sendable {
    /// Metres per second (default for raw CoreLocation samples).
    case metersPerSecond
    /// Kilometres per hour (already pre-converted by the caller).
    case kmh
}

public struct AppSpeedBandSample: Sendable, Equatable {
    public let timestamp: Date
    /// Speed in the unit declared on the parent view.
    public let speed: Double

    public init(timestamp: Date, speed: Double) {
        self.timestamp = timestamp
        self.speed = speed
    }
}

@MainActor
public struct AppSpeedBandView: View {
    public static let compactHeight: CGFloat = 60
    public static let expandedHeight: CGFloat = 200

    private let samples: [AppSpeedBandSample]
    private let unit: AppSpeedBandUnit
    private let highlightTimestamp: Date?
    private let title: String

    @State private var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - speeds: A sequence of `AppSpeedBandSample` values in chronological
    ///     order. Empty arrays render an empty-state placeholder.
    ///   - unit: Unit of the `speed` values. Defaults to m/s.
    ///   - highlightTimestamp: Optional timestamp where a vertical marker is
    ///     drawn (e.g. the current recording position). Snapped to the
    ///     nearest sample timestamp.
    ///   - title: Caption rendered above the band. Defaults to "Tempo".
    ///   - initiallyExpanded: Initial detent. Defaults to compact.
    public init(
        speeds: [AppSpeedBandSample],
        unit: AppSpeedBandUnit = .metersPerSecond,
        highlightTimestamp: Date? = nil,
        title: String = "Tempo",
        initiallyExpanded: Bool = false
    ) {
        self.samples = speeds
        self.unit = unit
        self.highlightTimestamp = highlightTimestamp
        self.title = title
        self._isExpanded = State(initialValue: initiallyExpanded)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            bandContent
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: targetHeight, alignment: .top)
        .background(cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { toggle() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(isExpanded ? "Doppeltippen zum Minimieren" : "Doppeltippen zum Maximieren"))
        .accessibilityAddTraits(.isButton)
        .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.86), value: isExpanded)
    }

    private var targetHeight: CGFloat {
        isExpanded ? Self.expandedHeight : Self.compactHeight
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.heavy))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            if !samples.isEmpty {
                Text(displayRangeText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var bandContent: some View {
        if samples.isEmpty {
            emptyPlaceholder
        } else {
            #if canImport(Charts)
            if #available(iOS 16.0, macOS 13.0, *) {
                ChartsBand(
                    samples: samples,
                    speedRange: speedRange,
                    highlightTimestamp: highlightTimestamp,
                    showAxes: isExpanded
                )
            } else {
                gradientFallback
            }
            #else
            gradientFallback
            #endif
        }
    }

    private var emptyPlaceholder: some View {
        HStack {
            Spacer()
            Text("Keine Tempo-Daten")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var gradientFallback: some View {
        // Used on platforms where Swift Charts is not available.
        LinearGradient(
            colors: [
                SpeedColors.color(for: 0.0),
                SpeedColors.color(for: 0.5),
                SpeedColors.color(for: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.white.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var speedRange: ClosedRange<Double> {
        guard let minVal = samples.map(\.speed).min(),
              let maxVal = samples.map(\.speed).max(),
              maxVal > minVal else {
            return 0 ... 1
        }
        return minVal ... maxVal
    }

    private var displayRangeText: String {
        let unitSuffix: String
        switch unit {
        case .metersPerSecond: unitSuffix = "m/s"
        case .kmh: unitSuffix = "km/h"
        }
        let min = String(format: "%.1f", speedRange.lowerBound)
        let max = String(format: "%.1f", speedRange.upperBound)
        return "\(min)–\(max) \(unitSuffix)"
    }

    // MARK: - Internal helpers (exposed @testable)

    internal var debug_isExpanded: Bool { isExpanded }
    internal var debug_speedRange: ClosedRange<Double> { speedRange }

    private func toggle() {
        isExpanded.toggle()
    }
}

#if canImport(Charts)
import Charts

@available(iOS 16.0, macOS 13.0, *)
@MainActor
private struct ChartsBand: View {
    let samples: [AppSpeedBandSample]
    let speedRange: ClosedRange<Double>
    let highlightTimestamp: Date?
    let showAxes: Bool

    var body: some View {
        Chart {
            ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                BarMark(
                    x: .value("Zeit", sample.timestamp),
                    yStart: .value("Min", speedRange.lowerBound),
                    yEnd: .value("Tempo", sample.speed),
                    width: .fixed(2)
                )
                .foregroundStyle(SpeedColors.color(for: normalized(sample.speed)))
            }
            if let highlight = highlightTimestamp {
                RuleMark(x: .value("Position", highlight))
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.recording.opacity(0.85))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .chartYScale(domain: speedRange)
        .chartXAxis(showAxes ? .automatic : .hidden)
        .chartYAxis(showAxes ? .automatic : .hidden)
        .accessibilityHidden(false)
    }

    private func normalized(_ value: Double) -> Double {
        let span = speedRange.upperBound - speedRange.lowerBound
        guard span > 0 else { return 0.5 }
        return (value - speedRange.lowerBound) / span
    }
}
#endif

// MARK: - Testing support

extension AppSpeedBandView {
    /// Test-only initializer mirror that exposes the internal expanded flag
    /// so we can assert the toggle without driving SwiftUI's state.
    @MainActor
    internal static func makeForTesting(
        speeds: [AppSpeedBandSample],
        initiallyExpanded: Bool
    ) -> AppSpeedBandView {
        AppSpeedBandView(speeds: speeds, initiallyExpanded: initiallyExpanded)
    }
}

#endif
