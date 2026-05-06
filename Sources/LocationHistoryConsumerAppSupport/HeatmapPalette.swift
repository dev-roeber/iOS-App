#if canImport(SwiftUI)
import SwiftUI

/// Perceptually-uniform palette identifiers. Replaces the previous rainbow
/// (jet) palette which produced a bullseye target ring at country zoom and
/// is widely considered misleading in modern data-vis (Borland & Taylor 2007).
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

enum HeatmapPalette {
    /// Returns the gradient stops for a palette identifier. Stops are RGB
    /// triples in 0…1 space taken from matplotlib's reference implementations.
    static func gradientStops(for palette: AppHeatmapPalettePreference) -> [(position: Double, color: HeatmapRGB)] {
        switch palette {
        case .magma:   return magma
        case .inferno: return inferno
        case .cividis: return cividis
        }
    }

    /// Magma — dark purple → magenta → cream-yellow. Default palette.
    /// Reads naturally as cool→hot on both standard and hybrid Apple Maps:
    /// the dark low end fades into low-density background while the cream
    /// hot end pops on any basemap. No misleading red/green steps.
    static let magma: [(position: Double, color: HeatmapRGB)] = [
        (0.00, HeatmapRGB(red: 0.000, green: 0.000, blue: 0.016)),
        (0.10, HeatmapRGB(red: 0.110, green: 0.063, blue: 0.267)),
        (0.25, HeatmapRGB(red: 0.314, green: 0.071, blue: 0.482)),
        (0.40, HeatmapRGB(red: 0.549, green: 0.161, blue: 0.506)),
        (0.55, HeatmapRGB(red: 0.784, green: 0.251, blue: 0.443)),
        (0.70, HeatmapRGB(red: 0.941, green: 0.412, blue: 0.357)),
        (0.85, HeatmapRGB(red: 0.996, green: 0.686, blue: 0.471)),
        (1.00, HeatmapRGB(red: 0.988, green: 0.992, blue: 0.749)),
    ]

    /// Inferno — same family as magma, more saturated, "fire" feel.
    static let inferno: [(position: Double, color: HeatmapRGB)] = [
        (0.00, HeatmapRGB(red: 0.000, green: 0.000, blue: 0.016)),
        (0.25, HeatmapRGB(red: 0.341, green: 0.063, blue: 0.431)),
        (0.50, HeatmapRGB(red: 0.733, green: 0.216, blue: 0.329)),
        (0.75, HeatmapRGB(red: 0.976, green: 0.557, blue: 0.035)),
        (1.00, HeatmapRGB(red: 0.988, green: 1.000, blue: 0.643)),
    ]

    /// Cividis — colourblind-safe (deuteranopia). Blue → desaturated → yellow.
    static let cividis: [(position: Double, color: HeatmapRGB)] = [
        (0.00, HeatmapRGB(red: 0.000, green: 0.125, blue: 0.298)),
        (0.50, HeatmapRGB(red: 0.486, green: 0.482, blue: 0.471)),
        (1.00, HeatmapRGB(red: 1.000, green: 0.914, blue: 0.271)),
    ]

    nonisolated static func rgb(for normalized: Double, palette: AppHeatmapPalettePreference) -> HeatmapRGB {
        let stops = gradientStops(for: palette)
        let clamped = min(max(normalized, 0.0), 1.0)
        guard let first = stops.first else {
            return HeatmapRGB(red: 0.0, green: 0.0, blue: 0.0)
        }
        if clamped <= first.position { return first.color }
        for index in 1..<stops.count {
            let previous = stops[index - 1]
            let current = stops[index]
            guard clamped <= current.position else { continue }
            let distance = current.position - previous.position
            let fraction = distance > 0 ? (clamped - previous.position) / distance : 0
            return previous.color.interpolated(to: current.color, fraction: fraction)
        }
        return stops.last?.color ?? first.color
    }

    nonisolated static func color(for normalized: Double, palette: AppHeatmapPalettePreference) -> Color {
        rgb(for: normalized, palette: palette).color
    }
}

struct HeatmapRGB: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    func interpolated(to other: HeatmapRGB, fraction: Double) -> HeatmapRGB {
        let clamped = min(max(fraction, 0.0), 1.0)
        return HeatmapRGB(
            red: red + ((other.red - red) * clamped),
            green: green + ((other.green - green) * clamped),
            blue: blue + ((other.blue - blue) * clamped)
        )
    }
}
#endif
