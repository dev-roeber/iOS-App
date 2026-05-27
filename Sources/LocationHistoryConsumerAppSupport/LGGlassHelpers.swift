#if canImport(SwiftUI)
import SwiftUI

// MARK: - Liquid-Glass View Modifier Helpers
//
// Single source of truth fuer alle Liquid-Glass-Oberflaechen im Map-/
// Chrome-Pfad. Auf iOS 26 nutzt jeder Helper die native
// `glassEffect(_:in:)`-API (bzw. `buttonStyle(.glass)`), auf aelteren
// Builds faellt er auf `.ultraThinMaterial` + shared
// `LH2GPXTheme.LiquidGlass.hairline`-Stroke zurueck. Hairline-Farbe ist
// damit ueberall identisch — kein Wechsel mehr zwischen `Color.white
// .opacity(0.18)` und Theme-Hairline.

public extension View {

    /// Glas-Oberflaeche mit RoundedRectangle (default 22pt radius).
    @ViewBuilder
    func lgGlassSurface(
        cornerRadius: CGFloat = 22,
        tint: Color? = nil
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, macOS 15.0, *) {
            self
                .glassEffect(tint.map { .regular.tint($0) } ?? .regular, in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8))
        }
    }

    /// Glas-Capsule (Pill) — fuer Layer-Pillen, Toolbar-Capsules,
    /// Resize-Handle. Hairline = Theme-Hairline.
    @ViewBuilder
    func lgGlassPill(tint: Color? = nil) -> some View {
        if #available(iOS 26.0, macOS 15.0, *) {
            self
                .glassEffect(tint.map { .regular.tint($0) } ?? .regular, in: Capsule())
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8))
        }
    }

    /// Glas-Kreis fuer Map-Control-Buttons (compass / + / − / scope / locate).
    /// Default-Durchmesser 38 pt entspricht der bisherigen
    /// `DayDetailControlStack`-/`LiveControlStack`-Pille.
    @ViewBuilder
    func lgGlassCircle(diameter: CGFloat = 38) -> some View {
        if #available(iOS 26.0, macOS 15.0, *) {
            self
                .frame(width: diameter, height: diameter)
                .glassEffect(.regular, in: .circle)
                .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
        } else {
            self
                .frame(width: diameter, height: diameter)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8))
                .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
        }
    }

    @ViewBuilder
    func lgGlassButton() -> some View {
        if #available(iOS 26.0, macOS 15.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func lgGlassButtonProminent(tint: Color = .accentColor) -> some View {
        if #available(iOS 26.0, macOS 15.0, *) {
            self.buttonStyle(.glassProminent).tint(tint)
        } else {
            self.buttonStyle(.borderedProminent).tint(tint)
        }
    }
}

// MARK: - LGGlassEffectGroup
//
// Wrapper um `GlassEffectContainer` (iOS 26+) mit Pass-Through-Fallback
// fuer aeltere Targets. Wenn mehrere Glas-Elemente raeumlich gruppiert
// sind (Layer-Pill + Control-Stack auf Live/DayDetail/Insights), sorgt
// der Container fuer koordinierte Animationen und Specular-Lichter.
// Unter iOS 25 ist der Container ein reines `Group`, das die Children
// unveraendert weiterreicht.

public struct LGGlassEffectGroup<Content: View>: View {
    public var spacing: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        if #available(iOS 26.0, macOS 15.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            // Pass-Through: identisches Layout, kein Container-Effekt.
            content()
        }
    }
}
#endif
