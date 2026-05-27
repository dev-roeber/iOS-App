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

    // MARK: Attribution guard

    /// Mindestabstand zwischen interaktiven, an der Map-Unterkante
    /// schwebenden Overlays (Resize-Pill, Custom-Locate-Buttons) und
    /// dem unteren Map-Frame. Schuetzt die Apple-Maps-Attribution
    /// ("Karten · Rechtl. Informationen") vor Verdeckung — Pflicht
    /// gemaess Apple Map Display Guidelines. 32 pt = Hoehe der
    /// Attribution-Zeile (~14 pt) + 12 pt Luft + 6 pt Pill-Stroke.
    public static let attributionGuardBottomInset: CGFloat = 32

    // MARK: Bottom-Sheet ↔ TabBar Clearance

    /// Hoehe der iOS-26 Liquid-Glass-TabBar exklusive Home-Indicator.
    /// `tabBarMinimizeBehavior(.onScrollDown)` reduziert die TabBar
    /// auf eine schmalere "minimized"-Form; wir reservieren den vollen
    /// Standard-Wert, weil das Sheet auch im NICHT-minimierten Zustand
    /// nicht hinter der Bar verschwinden darf.
    public static let tabBarStandardHeight: CGFloat = 49

    /// Zusaetzlicher Bottom-Inset, den ein selbstgebauter `LiveBottomSheet`
    /// braucht, damit sein Inhalt NICHT unter die TabBar rutscht.
    /// Das Sheet wird per `safeAreaInset(.bottom)` an die View geheftet —
    /// SwiftUI addiert dann den TabBar-Inset NICHT mehr zum Sheet-Frame,
    /// d.h. wir muessen ihn selbst reservieren.
    public static func bottomSheetTabBarClearance(
        deviceBottomSafeInset: CGFloat,
        tabBarBaseHeight: CGFloat = LHMapBase.tabBarStandardHeight
    ) -> CGFloat {
        // Home-Indicator (deviceBottomSafeInset) ist bereits Teil der TabBar
        // safe-area — wir reservieren nur die TabBar-Hoehe darueber.
        max(0, tabBarBaseHeight)
    }
}
