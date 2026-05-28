#if canImport(SwiftUI)
import SwiftUI

/// Floating top chrome for the map-first surface: hosts the layers badge on the
/// leading edge and map controls on the trailing edge, grouped into a single
/// Liquid Glass effect group with contract-mandated safe-area offsets.
/// See docs/UI_UX_MAP_FIRST_LIQUID_GLASS_CONTRACT_2026-05-28.md § 5.4.
@available(iOS 26.0, macOS 15.0, *)
public struct LHMapFloatingChrome<LayerContent: View, ControlsContent: View>: View {
    public static var minimumHitRegion: CGFloat { 44 }

    private let topSafeInset: CGFloat
    private let accessibilityPrefix: String
    private let layers: LayerContent
    private let controls: ControlsContent

    public init(
        topSafeInset: CGFloat,
        accessibilityPrefix: String,
        @ViewBuilder layers: () -> LayerContent,
        @ViewBuilder controls: () -> ControlsContent
    ) {
        self.topSafeInset = topSafeInset
        self.accessibilityPrefix = accessibilityPrefix
        self.layers = layers()
        self.controls = controls()
    }

    public var body: some View {
        let topInset = LHMapBase.floatingControlTopInset(deviceTopSafeInset: topSafeInset)
        let side = LHMapBase.floatingControlSideInset

        LGGlassEffectGroup(spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                layers
                    .modifier(FloatingHitRegion(minSize: Self.minimumHitRegion))
                    .accessibilityIdentifier("\(accessibilityPrefix).layers")

                Spacer(minLength: 8)

                controls
                    .modifier(FloatingHitRegion(minSize: Self.minimumHitRegion))
                    .accessibilityIdentifier("\(accessibilityPrefix).controls")
            }
            .padding(.leading, side)
            .padding(.trailing, side)
            .padding(.top, topInset)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityIdentifier("\(accessibilityPrefix).root")
    }
}

@available(iOS 26.0, macOS 15.0, *)
private struct FloatingHitRegion: ViewModifier {
    let minSize: CGFloat
    func body(content: Content) -> some View {
        content
            .frame(minWidth: minSize, minHeight: minSize, alignment: .center)
            .contentShape(Rectangle())
    }
}
#endif
