#if canImport(MapKit) && canImport(SwiftUI)
import MapKit
import SwiftUI

/// Centralised mapping from `(AppMapStylePreference, mapShowsRealisticElevation)`
/// to a concrete MapKit-for-SwiftUI `MapStyle`. Introduced in Train 9.2 so
/// every map surface in the app reaches the same decision — previously
/// `.standard(elevation: .realistic)` was hard-coded in the Live screens
/// and `.standard` (flat) everywhere else.
///
/// **Pure visual:** the realistic-elevation flag only affects how MapKit
/// renders terrain. It does **not** capture, persist, or expose any
/// altitude data, and it triggers no network calls beyond MapKit's own
/// tile fetching.
public enum AppMapStyleResolver {

    /// Resolves the preferred map style.
    /// - Parameters:
    ///   - preference: user's choice in Settings → Maps (standard / hybrid / muted).
    ///   - showsRealisticElevation: whether 3-D terrain should be requested
    ///     for elevation-aware styles. Honoured on `.standard` and `.hybrid`;
    ///     `.muted` is intentionally flat for readability.
    @available(iOS 17.0, macOS 14.0, *)
    public static func mapStyle(
        for preference: AppMapStylePreference,
        showsRealisticElevation: Bool
    ) -> MapStyle {
        switch preference {
        case .standard:
            return .standard(elevation: showsRealisticElevation ? .realistic : .flat)
        case .hybrid:
            return .hybrid(elevation: showsRealisticElevation ? .realistic : .flat)
        case .muted:
            // `.muted` keeps the flat low-contrast look so route lines stay readable.
            return .standard(elevation: .flat, emphasis: .muted)
        }
    }
}
#endif
