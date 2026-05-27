#if canImport(SwiftUI)
import SwiftUI

// MARK: - Deprecated forwards to LGGlassHelpers
//
// Frueher das Single-Source-of-Truth-File fuer die Liquid-Glass-
// Migration. Inzwischen konsolidiert in `LGGlassHelpers.swift`
// (`lgGlassSurface`, `lgGlassPill`, `lgGlassCircle`, `LGGlassEffectGroup`).
// Die alten `lh*`-Aliase bleiben als deprecated forwards bestehen, damit
// externe Call-Sites nicht hart brechen — sie leiten 1:1 auf die neuen
// `lg*`-Helpers weiter.

public extension View {

    @available(*, deprecated, renamed: "lgGlassSurface(cornerRadius:tint:)",
               message: "Use lgGlassSurface(cornerRadius:) — Single Source of Truth in LGGlassHelpers.")
    @ViewBuilder
    func lhGlassBackground<S: InsettableShape>(
        in shape: S,
        prominent: Bool = false
    ) -> some View {
        // Fuer Rueckwaertskompatibilitaet behalten wir die generische
        // Shape-Signatur. Auf iOS 26 nutzt der Pfad nativen glassEffect,
        // sonst Material + Theme-Hairline.
        if #available(iOS 26.0, macOS 15.0, *) {
            self.glassEffect(prominent ? .regular.tint(.accentColor) : .regular, in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8))
        }
    }

    @available(*, deprecated, renamed: "lgGlassCircle(diameter:)",
               message: "Use lgGlassCircle(diameter:) — Single Source of Truth in LGGlassHelpers.")
    @ViewBuilder
    func lhGlassControlPill() -> some View {
        self.lgGlassCircle(diameter: 38)
    }
}
#endif
