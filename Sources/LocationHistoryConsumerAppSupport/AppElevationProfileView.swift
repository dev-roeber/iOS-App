// AppElevationProfileView
//
// Reusable elevation-profile component. Caller supplies a sequence of
// `(distance, elevation)` samples (both in metres). The view renders a
// glass-card with a Swift Charts `AreaMark` profile when Charts is
// available; on platforms without Charts (or below iOS 16/macOS 13) a
// gradient placeholder line is drawn instead so Linux CI keeps building.
//
// Two height states: compact (≈ 60pt) shows just the profile silhouette;
// expanded (≈ 200pt) reveals chart axes plus min/max labels. Tapping the
// card toggles between the two with a Reduce-Motion-safe spring animation.
// The card surface mirrors LiveBottomSheet (white opacity .06, soft
// gradient, ultraThinMaterial, hairline outline).

#if canImport(SwiftUI)
import SwiftUI

public struct AppElevationProfileSample: Sendable, Equatable {
    /// Cumulative distance in metres.
    public let distance: Double
    /// Elevation in metres above sea level.
    public let elevation: Double

    public init(distance: Double, elevation: Double) {
        self.distance = distance
        self.elevation = elevation
    }
}

@MainActor
public struct AppElevationProfileView: View {
    public static let compactHeight: CGFloat = 60
    public static let expandedHeight: CGFloat = 200

    private let points: [AppElevationProfileSample]
    private let title: String

    @State private var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - points: Ordered distance/elevation samples. Empty array renders
    ///     an empty-state placeholder.
    ///   - title: Caption above the profile. Defaults to "Höhe".
    ///   - initiallyExpanded: Initial detent. Defaults to compact.
    public init(
        points: [AppElevationProfileSample],
        title: String = "Höhe",
        initiallyExpanded: Bool = false
    ) {
        self.points = points
        self.title = title
        self._isExpanded = State(initialValue: initiallyExpanded)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            profileContent
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
        .onTapGesture { isExpanded.toggle() }
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
            if let (lo, hi) = elevationBounds {
                Text(String(format: "%.0f–%.0f m", lo, hi))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var profileContent: some View {
        if points.isEmpty {
            emptyPlaceholder
        } else {
            #if canImport(Charts)
            if #available(iOS 16.0, macOS 13.0, *) {
                ChartsProfile(points: points, showAxes: isExpanded)
            } else {
                placeholderLine
            }
            #else
            placeholderLine
            #endif
        }
    }

    private var emptyPlaceholder: some View {
        HStack {
            Spacer()
            Text("Keine Höhendaten")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderLine: some View {
        LinearGradient(
            colors: [
                LH2GPXTheme.LiquidGlass.elevation.opacity(0.55),
                LH2GPXTheme.LiquidGlass.elevation.opacity(0.10)
            ],
            startPoint: .top,
            endPoint: .bottom
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

    private var elevationBounds: (lo: Double, hi: Double)? {
        guard let lo = points.map(\.elevation).min(),
              let hi = points.map(\.elevation).max() else { return nil }
        return (lo, hi)
    }

    // MARK: - Testing helpers
    internal var debug_isExpanded: Bool { isExpanded }
    internal var debug_pointCount: Int { points.count }
    internal var debug_elevationBounds: (lo: Double, hi: Double)? { elevationBounds }
}

#if canImport(Charts)
import Charts

@available(iOS 16.0, macOS 13.0, *)
@MainActor
private struct ChartsProfile: View {
    let points: [AppElevationProfileSample]
    let showAxes: Bool

    var body: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value("Distanz", point.distance),
                    y: .value("Höhe", point.elevation)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            LH2GPXTheme.LiquidGlass.elevation.opacity(0.65),
                            LH2GPXTheme.LiquidGlass.elevation.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Distanz", point.distance),
                    y: .value("Höhe", point.elevation)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(LH2GPXTheme.LiquidGlass.elevation)
                .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
        }
        .chartXAxis(showAxes ? .automatic : .hidden)
        .chartYAxis(showAxes ? .automatic : .hidden)
    }
}
#endif

#endif
