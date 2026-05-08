import Foundation

// MARK: - Heatmap & Map Track preference enums (Linux-buildable)
//
// These four enums are pure preference identifiers persisted via UserDefaults
// in `AppPreferences`. They do not depend on SwiftUI / MapKit / UIKit and were
// previously trapped inside iOS-only `#if canImport(SwiftUI) && canImport(MapKit)`
// guards in their respective view/styling files (HeatmapPalette.swift,
// AppHeatmapView.swift, HeatmapLOD.swift, MapTrackStyling.swift), which broke
// `swift build` on Linux because `AppPreferences` references them at the
// AppSupport-target level. Hoisting them here keeps the SwiftUI/MapKit
// rendering code iOS-only while letting the AppSupport target compile on
// Linux for headless test runs.

/// Perceptually-uniform heatmap palette identifier. Replaces the previous
/// rainbow (jet) palette which produced bullseye target rings at country
/// zoom and is widely considered misleading in modern data-vis (Borland &
/// Taylor 2007). The matching gradient stops live next to the SwiftUI
/// renderer in HeatmapPalette.swift (iOS-only).
public enum AppHeatmapPalettePreference: String, CaseIterable, Identifiable, Sendable {
    case magma
    case inferno
    case cividis

    public var id: String { rawValue }

    public var labelKey: String {
        switch self {
        case .magma:   return "Magma"
        case .inferno: return "Inferno"
        case .cividis: return "Cividis"
        }
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

/// Heatmap radius preset (compact / balanced / wide). The numeric `scale`
/// multiplier used by the SwiftUI renderer stays internal-only in
/// AppHeatmapView.swift since it has no meaning outside the iOS render path.
public enum AppHeatmapRadiusPreset: String, CaseIterable, Identifiable, Sendable {
    case compact
    case balanced
    case wide

    public var id: String { rawValue }

    public var labelKey: String {
        switch self {
        case .compact:  return "Compact"
        case .balanced: return "Standard"
        case .wide:     return "Wide"
        }
    }
}

/// Determines whether tracks render in their semantic activity-type colour
/// or in a speed-coloured gradient ("Tempolayer").
public enum AppMapTrackColorMode: String, CaseIterable, Identifiable, Sendable {
    case activity
    case speed

    public var id: String { rawValue }

    public var labelKey: String {
        switch self {
        case .activity: return "Activity"
        case .speed:    return "Speed"
        }
    }
}
