#if canImport(SwiftUI)
import SwiftUI

public extension View {
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
                .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 0.8))
        }
    }

    @ViewBuilder
    func lgGlassPill(tint: Color? = nil) -> some View {
        if #available(iOS 26.0, macOS 15.0, *) {
            self
                .glassEffect(tint.map { .regular.tint($0) } ?? .regular, in: Capsule())
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
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
#endif
