#if canImport(SwiftUI)
import SwiftUI

/// Reusable section card on a Liquid Glass surface with optional title and
/// footer. Used to group related controls / metrics inside page scaffolds and
/// bottom-sheet bodies without bespoke per-screen styling.
/// See docs/UI_UX_MAP_FIRST_LIQUID_GLASS_CONTRACT_2026-05-28.md § 5.7.
@available(iOS 26.0, macOS 15.0, *)
public struct LHGlassSectionCard<Content: View>: View {
    private let title: String?
    private let footer: String?
    private let content: Content

    public init(
        title: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
            }

            content

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .lgGlassSurface(cornerRadius: 18)
    }
}
#endif
