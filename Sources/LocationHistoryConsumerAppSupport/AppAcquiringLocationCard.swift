// AppAcquiringLocationCard.swift
//
// A Liquid-Glass styled "Acquiring location fix" card shown in the Live tab
// while the recording session is running but no GPS fix has been resolved yet.
// Replaces the hard black map placeholder + lone compass icon with a richer
// composition (radar sweep, satellite-constellation dots, halo'd compass and
// optional stopwatch pill) that matches the rest of the app's dark-mode glass
// aesthetic.
//
// Wired into AppLiveTrackingView.acquiringFixView in a follow-up PR after
// fix/live-no-overlap-and-sheet-tint merges. This file intentionally ships the
// component in isolation so it can be reviewed without touching
// AppLiveTrackingView.swift / AppLiveMultiLayerControls.swift while a parallel
// agent is editing those files.

#if canImport(SwiftUI)
import SwiftUI

/// Visual placeholder for the Live map while GPS is still acquiring a fix.
///
/// - Parameters:
///   - elapsed: Seconds since the recording started without a fix. When `nil`
///     the stopwatch pill is hidden (e.g. before recording was tapped, or for
///     state-driven copy that has no timer).
///   - lastKnownAccuracyMeters: Optional horizontal accuracy of the most
///     recent (rejected) sample, used to hint the user that the GPS is warm
///     but not yet precise enough.
@available(iOS 17.0, macOS 14.0, *)
public struct AppAcquiringLocationCard: View {
    public let elapsed: TimeInterval?
    public let lastKnownAccuracyMeters: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var radarPhase: CGFloat = 0
    @State private var haloPhase: CGFloat = 0

    public init(
        elapsed: TimeInterval? = nil,
        lastKnownAccuracyMeters: Double? = nil
    ) {
        self.elapsed = elapsed
        self.lastKnownAccuracyMeters = lastKnownAccuracyMeters
    }

    public var body: some View {
        ZStack {
            backgroundCanvas
                .accessibilityHidden(true)

            constellation
                .accessibilityHidden(true)

            radarSweep
                .accessibilityHidden(true)

            VStack(spacing: 18) {
                compassMark
                textStack
                if elapsed != nil || lastKnownAccuracyMeters != nil {
                    metaPills
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(combinedAccessibilityLabel))
        .onAppear { startAnimations() }
    }

    // MARK: - Background

    private var backgroundCanvas: some View {
        LinearGradient(
            colors: [
                Color(red: 14/255, green: 17/255, blue: 22/255),
                Color(red: 22/255, green: 26/255, blue: 34/255),
                Color(red: 10/255, green: 12/255, blue: 16/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 220
            )
        )
    }

    private var constellation: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                star(at: CGPoint(x: w * 0.18, y: h * 0.22), size: 2.6, opacity: 0.08)
                star(at: CGPoint(x: w * 0.78, y: h * 0.18), size: 1.8, opacity: 0.06)
                star(at: CGPoint(x: w * 0.84, y: h * 0.72), size: 2.4, opacity: 0.07)
                star(at: CGPoint(x: w * 0.22, y: h * 0.78), size: 1.6, opacity: 0.05)
                star(at: CGPoint(x: w * 0.52, y: h * 0.12), size: 1.4, opacity: 0.04)
            }
        }
    }

    private func star(at point: CGPoint, size: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(Color.white.opacity(opacity))
            .frame(width: size, height: size)
            .position(point)
    }

    private var radarSweep: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height) * 0.55
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: diameter, height: diameter)
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    .frame(width: diameter * 0.66, height: diameter * 0.66)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.08 * (reduceMotion ? 0.5 : (1 - radarPhase))),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: diameter * 0.5
                        )
                    )
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(reduceMotion ? 1.0 : (0.6 + radarPhase * 0.5))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    // MARK: - Compass mark

    private var compassMark: some View {
        ZStack {
            // Outer halo ring (pulses)
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                .frame(width: 96, height: 96)
                .scaleEffect(reduceMotion ? 1.0 : (1.0 + haloPhase * 0.12))
                .opacity(reduceMotion ? 0.7 : (1.0 - haloPhase * 0.6))

            // Inner glass disc
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 72, height: 72)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                )

            Image(systemName: iconName)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .frame(width: 96, height: 96)
    }

    private var iconName: String {
        // location.viewfinder reads as "looking for a fix"; the slash variant
        // would imply permission denied which is a different state.
        "location.viewfinder"
    }

    // MARK: - Text stack

    private var textStack: some View {
        VStack(spacing: 6) {
            Text(headline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(subline)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.66))
                .multilineTextAlignment(.center)
        }
    }

    private var headline: String { "Acquiring location fix..." }
    private var subline: String { "GPS searching for satellites · No position available yet" }

    // MARK: - Meta pills

    private var metaPills: some View {
        HStack(spacing: 8) {
            if let elapsed {
                pill(icon: "stopwatch", text: "Searching for \(Self.formatElapsed(elapsed))")
            }
            if let accuracy = lastKnownAccuracyMeters {
                pill(icon: "scope", text: "Last accuracy ±\(Int(accuracy.rounded())) m")
            }
        }
    }

    private func pill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(text)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(Color.white.opacity(0.78))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color.white.opacity(0.08))
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.6)
        )
    }

    // MARK: - Helpers

    static func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private var combinedAccessibilityLabel: String {
        var label = "Acquiring location fix. Searching for GPS satellites."
        if let elapsed {
            label += " Elapsed \(Self.formatElapsed(elapsed))."
        }
        if let accuracy = lastKnownAccuracyMeters {
            label += " Last accuracy \(Int(accuracy.rounded())) meters."
        }
        return label
    }

    private func startAnimations() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            radarPhase = 1
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            haloPhase = 1
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
struct AppAcquiringLocationCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AppAcquiringLocationCard()
                .frame(width: 360, height: 480)
                .preferredColorScheme(.dark)
                .previewDisplayName("Idle")

            AppAcquiringLocationCard(elapsed: 32)
                .frame(width: 360, height: 480)
                .preferredColorScheme(.dark)
                .previewDisplayName("Searching 0:32")

            AppAcquiringLocationCard(elapsed: 95, lastKnownAccuracyMeters: 240)
                .frame(width: 360, height: 480)
                .preferredColorScheme(.dark)
                .previewDisplayName("With accuracy hint")
        }
    }
}
#endif
#endif
