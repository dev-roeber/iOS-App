#if canImport(SwiftUI)
import SwiftUI

/// Wraps an existing background view and progress-based modifies it during a
/// loading phase so the underlying asset visibly "comes to life" as the
/// progress climbs from 0 → 1.
///
/// At `progress == 0` the wrapped background is dim, slightly desaturated,
/// softly blurred and covered by a dark veil with no glow. At
/// `progress == 1` the veil is gone, saturation and contrast are pushed past
/// neutral and a cyan radial glow is fully present.
///
/// The component never replaces the wrapped background — it only layers
/// modifiers and overlays. It is therefore safe to drop in around an existing
/// `Image` / `ZStack` / gradient stack without rebuilding the asset pipeline.
@available(iOS 16.0, macOS 13.0, *)
public struct LH2GPXLoadingBackground<Background: View>: View {
    private let rawProgress: Double
    private let background: Background

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(progress: Double, @ViewBuilder background: () -> Background) {
        self.rawProgress = progress
        self.background = background()
    }

    /// Clamped progress on `[0, 1]`. All visual params derive from this.
    private var p: Double {
        max(0.0, min(1.0, rawProgress))
    }

    /// Linear interpolation helper.
    private func lerp(_ a: Double, _ b: Double) -> Double {
        a + (b - a) * p
    }

    private var brightnessValue: Double {
        // -0.12 (dim/dead) → +0.06 (slightly lifted, still dark)
        lerp(-0.12, 0.06)
    }

    private var saturationValue: Double {
        // 0.65 (desaturated, near-monochrome) → 1.4 (rich cyan/orange present)
        lerp(0.65, 1.4)
    }

    private var contrastValue: Double {
        // 0.95 (flatter) → 1.2 (crisper edges, lines pop)
        lerp(0.95, 1.2)
    }

    /// Soft blur fades from ~3.5pt at 0% to 0pt at 100%.
    /// Capped low to keep fullscreen GPU cost bounded.
    private var blurRadius: Double {
        lerp(3.5, 0.0)
    }

    /// Black veil over the asset — heavy at 0%, almost gone at 100%.
    private var darkVeilOpacity: Double {
        lerp(0.55, 0.10)
    }

    /// Cyan radial glow strengthens as progress climbs.
    private var glowOpacity: Double {
        // 0% nothing, 100% noticeable but not blown-out.
        lerp(0.00, 0.35)
    }

    public var body: some View {
        ZStack {
            // 1) Underlying asset, modified.
            background
                .saturation(saturationValue)
                .brightness(brightnessValue)
                .contrast(contrastValue)
                .blur(radius: blurRadius)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: p)

            // 2) Dark veil — fades with progress.
            Color.black
                .opacity(darkVeilOpacity)
                .blendMode(.multiply)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: p)
                .allowsHitTesting(false)

            // 3) Cyan/teal radial glow that intensifies with progress.
            RadialGradient(
                colors: [
                    Color(red: 0.18, green: 0.85, blue: 0.95).opacity(glowOpacity),
                    Color(red: 0.10, green: 0.55, blue: 0.75).opacity(glowOpacity * 0.55),
                    Color.clear
                ],
                center: .center,
                startRadius: 8,
                endRadius: 520
            )
            .blendMode(.screen)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: p)
            .allowsHitTesting(false)

            // 4) Optional vertical "route pulse" — only when motion is allowed
            // and we are still actively loading. Stops cleanly at progress == 1.
            if !reduceMotion && p > 0.0 && p < 1.0 {
                RoutePulseOverlay(progress: p)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// A very dezent, GPU-cheap vertical glow that drifts up and down along the
/// centre of the frame. Mimics the cinematic "route shimmer" without needing
/// any SVG path data — a soft narrow vertical gradient stripe whose opacity
/// pulses gently. Active only outside Reduce Motion and only mid-load.
@available(iOS 16.0, macOS 13.0, *)
private struct RoutePulseOverlay: View {
    let progress: Double

    var body: some View {
        // 20 Hz is plenty for a 4-second ambient sine pulse and frees up a
        // third of the timer ticks during a parse-heavy import. `paused`
        // tracks the load progress directly so even if the outer
        // `p > 0.0 && p < 1.0` guard is ever loosened, the timer halts
        // when progress reaches completion instead of running forever.
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: progress >= 1.0)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            // 4-second pulse cycle. Output range ~[0.35, 1.0] so it never goes dark.
            let cycle = (sin(phase * .pi / 2.0) + 1.0) * 0.5      // 0…1
            let pulse = 0.35 + cycle * 0.65                        // 0.35…1.0
            // Strength scales with progress so the pulse is whisper-quiet at the
            // start and most visible just before completion.
            let strength = 0.20 * progress * pulse

            GeometryReader { geo in
                let stripeWidth = max(40, geo.size.width * 0.08)
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(red: 0.45, green: 0.95, blue: 1.0).opacity(strength),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: stripeWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .blur(radius: 18)
                .blendMode(.screen)
            }
        }
    }
}
#endif
