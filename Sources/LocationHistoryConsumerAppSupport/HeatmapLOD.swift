#if canImport(MapKit)
import Foundation

/// Level-of-detail tier — controls bin step, smoothing kernel, and selection
/// limits across world / country / region / street zoom levels.
enum HeatmapLOD: CaseIterable {
    case macro
    case low
    case medium
    case high

    var step: Double {
        switch self {
        case .macro:  return 2.5
        case .low:    return 0.08
        case .medium: return 0.012
        case .high:   return 0.001
        }
    }

    var overlayOpacityMultiplier: Double {
        switch self {
        case .macro:  return 0.42
        case .low:    return 0.54
        case .medium: return 0.82
        case .high:   return 0.98
        }
    }

    /// Multiplier on the bin step to size the rendered hex tile. Greater
    /// than 1.0 produces visible overlap between adjacent cells, which
    /// blends them into a continuous field instead of a tiled grid.
    var tileSpanMultiplier: Double {
        switch self {
        case .macro:  return 1.85
        case .low:    return 1.65
        case .medium: return 1.50
        case .high:   return 1.35
        }
    }

    var selectionLimit: Int {
        switch self {
        case .macro:  return 36
        case .low:    return 72
        case .medium: return 280
        case .high:   return 1200
        }
    }

    var minimumNormalizedIntensity: Double {
        switch self {
        case .macro:  return 0.025
        case .low:    return 0.032
        case .medium: return 0.010
        case .high:   return 0.0045
        }
    }

    var viewportPaddingFactor: Double {
        switch self {
        case .macro:  return 0.08
        case .low:    return 0.12
        case .medium: return 0.16
        case .high:   return 0.20
        }
    }

    var smoothingKernel: [HeatKernelOffset] {
        switch self {
        case .macro:
            return HeatKernelOffset.gaussian(center: 1.0, edge: 0.65, corner: 0.35)
        case .low:
            return HeatKernelOffset.gaussian(center: 1.0, edge: 0.62, corner: 0.28)
        case .medium:
            return HeatKernelOffset.gaussian(center: 1.0, edge: 0.48, corner: 0.15)
        case .high:
            return HeatKernelOffset.gaussian(center: 1.0, edge: 0.24, corner: 0.07)
        }
    }

    var precomputationVisibilityFactor: Double {
        switch self {
        case .macro:  return 0.45
        case .low:    return 0.40
        case .medium: return 0.28
        case .high:   return 0.18
        }
    }

    static func optimalLOD(for spanDelta: Double) -> HeatmapLOD {
        if spanDelta > 12.0  { return .macro }
        if spanDelta > 1.0   { return .low }
        if spanDelta > 0.12  { return .medium }
        return .high
    }
}

struct HeatKernelOffset {
    let lat: Int32
    let lon: Int32
    let weight: Double

    static func gaussian(center: Double, edge: Double, corner: Double) -> [HeatKernelOffset] {
        [
            HeatKernelOffset(lat: -1, lon: -1, weight: corner),
            HeatKernelOffset(lat: -1, lon:  0, weight: edge),
            HeatKernelOffset(lat: -1, lon:  1, weight: corner),
            HeatKernelOffset(lat:  0, lon: -1, weight: edge),
            HeatKernelOffset(lat:  0, lon:  0, weight: center),
            HeatKernelOffset(lat:  0, lon:  1, weight: edge),
            HeatKernelOffset(lat:  1, lon: -1, weight: corner),
            HeatKernelOffset(lat:  1, lon:  0, weight: edge),
            HeatKernelOffset(lat:  1, lon:  1, weight: corner),
        ]
    }
}

/// User-selectable scale mapping from raw bin counts to normalized intensity.
public enum AppHeatmapScalePreference: String, CaseIterable, Identifiable, Sendable {
    case logarithmic
    case linear

    public var id: String { rawValue }

    public var labelKey: String {
        switch self {
        case .logarithmic: return "Logarithmic"
        case .linear:      return "Linear"
        }
    }
}
#endif
