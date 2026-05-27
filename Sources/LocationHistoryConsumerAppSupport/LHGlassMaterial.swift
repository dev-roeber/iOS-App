#if canImport(SwiftUI)
import SwiftUI

/// Single source of truth fuer die Liquid-Glass-Migration der Map-First-
/// Chrome (Layer-Pill, Control-Stack-Pillen, Sheet-Handles). Nutzt auf
/// iOS 26 die nativen `glassEffect`/`buttonStyle(.glass)`-APIs und faellt
/// auf aelteren Builds auf `.ultraThinMaterial` zurueck — exakt wie das
/// `LH2GPXTheme.LiquidGlass`-Kommentar es verlangt.
public extension View {

    /// Glas-Untergrund fuer freistehende Map-Overlays (Layer-Pill, Resize-
    /// Pill). Auf iOS 26 nutzt die native `glassEffect(_:in:)`-API.
    @ViewBuilder
    func lhGlassBackground<S: InsettableShape>(
        in shape: S,
        prominent: Bool = false
    ) -> some View {
        if #available(iOS 26.0, macOS 15.0, *) {
            self.glassEffect(prominent ? .regular.tint(.accentColor) : .regular, in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8))
        }
    }

    /// Glas-Pill fuer 38×38 Map-Control-Buttons (compass / + / − / scope).
    @ViewBuilder
    func lhGlassControlPill() -> some View {
        if #available(iOS 26.0, macOS 15.0, *) {
            self
                .frame(width: 38, height: 38)
                .glassEffect(.regular, in: .circle)
                .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
        } else {
            self
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8))
                .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
        }
    }
}
#endif
