#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI

/// Visual mapping helpers — turn a normalized intensity into the
/// final perceived display intensity, palette colour position, and
/// effective alpha used during cell rendering.
enum HeatmapVisualStyle {
    nonisolated static func displayIntensity(for normalized: Double) -> Double {
        let clamped = min(max(normalized, 0.0), 1.0)
        // Slight curve to keep mid-density visible while letting hotspots
        // separate cleanly. Softer than the previous double-pow blend.
        let liftedLow = pow(clamped, 0.55)
        let hotspotBoost = pow(clamped, 1.35)
        let value = (liftedLow * 0.55) + (clamped * 0.20) + (hotspotBoost * 0.30)
        return min(max(value, 0.0), 1.0)
    }

    /// Colour position into the active palette. Magma/Inferno/Cividis are
    /// already perceptually uniform, so we apply a gentle lift to mid-low
    /// values and don't need the previous warm/cool detail bias.
    nonisolated static func colorPosition(for normalized: Double) -> Double {
        let clamped = min(max(normalized, 0.0), 1.0)
        return pow(clamped, 0.78)
    }

    /// Slider position (0.15…1.0) → effective alpha multiplier (0.20…1.0).
    nonisolated static func remappedControlOpacity(_ overlayOpacity: Double) -> Double {
        let clamped = min(max(overlayOpacity, 0.1), 1.0)
        return 0.20 + (clamped - 0.1) / 0.9 * 0.80
    }

    /// Final alpha for a cell. The base is intentionally lower than before
    /// (~0.45 instead of ~0.84) because each cell now also carries a radial
    /// alpha falloff via its RadialGradient fill — keeping the overall
    /// composited density looking like a glow instead of a stack of solid
    /// hexagons (which produced the bullseye target rings on country zoom).
    nonisolated static func effectiveOpacity(
        normalizedIntensity: Double,
        overlayOpacity: Double,
        lod: HeatmapLOD
    ) -> Double {
        let displayIntensity = displayIntensity(for: normalizedIntensity)
        let controlOpacity = remappedControlOpacity(overlayOpacity)
        // Base sits in the soft 0.18–0.55 range — overlapping cells composite
        // additively (within Apple Maps' source-over) without saturating.
        let base = 0.18 + (displayIntensity * 0.45)
        let detailBoost: Double
        switch lod {
        case .macro:  detailBoost = 0.85
        case .low:    detailBoost = 0.92
        case .medium: detailBoost = 1.00
        case .high:   detailBoost = 1.05
        }
        let value = base * controlOpacity * lod.overlayOpacityMultiplier * detailBoost
        let maxOpacity = 0.55 + (controlOpacity * 0.30)
        return min(max(value, 0.04), maxOpacity)
    }
}
#endif
