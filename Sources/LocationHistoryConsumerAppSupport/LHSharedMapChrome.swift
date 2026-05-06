#if canImport(SwiftUI)
import SwiftUI

/// Legacy single-purpose map style toggle. Superseded by `MapLayerMenu`
/// which consolidates every map layer control into one right-side dropdown.
/// Kept only to avoid breaking external Source-Compatibility — internal
/// callers were migrated.
@available(iOS 17.0, macOS 14.0, *)
@available(*, deprecated, message: "Use MapLayerMenu instead — every map surface now uses the unified layer dropdown.")
public struct LHMapStyleToggleButton: View {
    @EnvironmentObject private var preferences: AppPreferences

    public init() {}

    public var body: some View {
        Button {
            preferences.preferredMapStyle.toggle()
        } label: {
            Image(systemName: preferences.preferredMapStyle.isHybrid ? "map" : "globe")
                .font(.caption)
                .padding(7)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .accessibilityLabel(preferences.localized(
            preferences.preferredMapStyle.isHybrid
                ? "Switch to standard map"
                : "Switch to satellite map"
        ))
    }
}
#endif
