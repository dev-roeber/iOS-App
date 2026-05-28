#if canImport(SwiftUI)
import SwiftUI

/// Page scaffold for non-map screens that need the Liquid Glass background plus
/// a large title / subtitle header. Wraps content into the shared LHPageScaffold
/// so spacing tokens stay consistent across the app.
/// See docs/UI_UX_MAP_FIRST_LIQUID_GLASS_CONTRACT_2026-05-28.md § 5.6.
@available(iOS 26.0, macOS 15.0, *)
public struct LHGlassPageScaffold<Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let content: Content

    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LHPageScaffold {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(title)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)

                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                        }

                        content
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(LHLiquidGlassBackground().ignoresSafeArea())
        }
    }
}
#endif
