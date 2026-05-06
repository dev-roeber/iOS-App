#if canImport(SwiftUI)
import SwiftUI

/// Shared map-chrome style-toggle button. Mirrors the inline button used inside
/// `AppDayMapView` so all map surfaces (Overview, Insights, Export, Live) render
/// the identical pill. Functionality and appearance must stay byte-equivalent
/// with the AppDayMapView original — change one, change both.
@available(iOS 17.0, macOS 14.0, *)
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
