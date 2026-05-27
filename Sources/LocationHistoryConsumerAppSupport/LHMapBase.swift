import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Single source of truth for the map-first base shared by every screen
/// that renders a primary map (Overview, Days, Day-Detail, Live, Insights,
/// Heatmap, Export). Centralised so a future tweak to the "base" — pill
/// label format, control-stack top inset, canonical track width — is a
/// one-file change and the maps stay visually identical across tabs.
///
/// The map *style* itself (Standard / Hybrid / Imagery + realistic vs flat
/// elevation) keeps flowing through `AppMapStyleResolver` and the shared
/// `AppPreferences.preferredMapStyle`, so all screens already pick up the
/// same chosen style. This type covers the surrounding chrome — the parts
/// the resolver does not own.
public enum LHMapBase {

    // MARK: Layer badge ("LAYERS n/4")

    /// Total number of overlay slots displayed in the multi-layer badge.
    /// Four today: Standard / Tempo / Höhe / Wetter. If a future screen
    /// surfaces fewer, pass an explicit `total` to the formatter — but
    /// prefer keeping the badge shape uniform so users see one affordance.
    public static let totalLayerSlots: Int = 4

    /// Renders the canonical layer badge label, e.g. `"LAYERS 2/4"`.
    /// Pass the localised "LAYERS" word as `localizedLayersWord` so each
    /// screen can keep its existing `t("LAYERS")` translation hook without
    /// pulling a `Localizable` dependency into this base layer.
    public static func layersBadge(
        localizedLayersWord: String,
        activeCount: Int,
        total: Int = LHMapBase.totalLayerSlots
    ) -> String {
        let clamped = max(0, min(activeCount, total))
        return "\(localizedLayersWord) \(clamped)/\(total)"
    }

    // MARK: Floating control insets

    /// Vertical gap between the device safe-area top edge and the first
    /// floating map control (layer pill on the leading side, control stack
    /// on the trailing side). Picked to clear the Dynamic Island / notch
    /// without crowding the map. All map-first screens use this value.
    public static let floatingControlTopGap: CGFloat = 12

    /// Horizontal inset for the leading layer pill and the trailing control
    /// stack from the respective screen edge.
    public static let floatingControlSideInset: CGFloat = 12

    /// Canonical top inset for floating map controls on a given screen.
    /// Pass the device's resolved top safe-area inset (usually via the
    /// existing `lhDeviceTopSafeInset()` helper) and receive the y-offset
    /// where the first floating control should land.
    public static func floatingControlTopInset(
        deviceTopSafeInset: CGFloat
    ) -> CGFloat {
        deviceTopSafeInset + LHMapBase.floatingControlTopGap
    }
}
