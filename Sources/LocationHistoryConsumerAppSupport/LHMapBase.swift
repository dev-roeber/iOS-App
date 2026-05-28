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
    ///
    /// B-5.5 Visual Hardening: von 49 auf 70 angehoben. iOS 26 LG-TabBar
    /// rendert deutlich groesser als die UIKit-Legacy-49pt-Bar, und in
    /// allen migrierten Surfaces (Live/DayDetail/Insights/Map-Tab/Export)
    /// klemmten Sheet-Unterkante und Apple-Maps-Attribution zu eng — die
    /// 49pt unterreservierten den realen TabBar-Footprint.
    public static let tabBarStandardHeight: CGFloat = 70

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

    // MARK: - Phase D-1: MapLayerMenu Hit-Region
    //
    // MapLayerMenu rendert eine kompakte Glass-Pill (visuell 34 pt), aber
    // die interaktive Tap-Flaeche muss laut Apple HIG mindestens 44 × 44 pt
    // betragen. Beide Konstanten leben hier zentral, damit der visuelle
    // Footprint nicht versehentlich auf 44 pt aufgeblaeht wird und der
    // Hit-Region-Floor nicht in einem einzelnen View versteckt landet.

    /// Sichtbare Groesse der MapLayerMenu-Pill (Glass-Surface). Beruehrt
    /// das Layout der Karten-Overlays — nicht erhoehen, ohne zuerst die
    /// Map-First-Spec zu pruefen.
    public static let mapLayerMenuVisualSize: CGFloat = 34

    /// Apple-HIG-konforme minimale Tap-Flaeche fuer MapLayerMenu, gemessen
    /// an `contentShape(Rectangle())`. Die Pill bleibt visuell bei
    /// `mapLayerMenuVisualSize`, aber der Button reagiert auf die
    /// gesamte 44 × 44 pt Region.
    public static let mapLayerMenuMinimumHitSize: CGFloat = 44

    // MARK: - Phase D-1: Bottom-Pill Clearance (Live + Map-Tab)
    //
    // Die Live-Recording-Bar und die Map-Tab-Zusatzpills (Simplified-
    // Preview, Optimized-Overview-Badge) sitzen am unteren Map-Rand und
    // duerfen nicht in die Apple-Maps-Attribution oder die iOS-26
    // TabBar hineinwachsen. Statt jeden Aufrufer eigene Magic Numbers
    // pflegen zu lassen, liefert `combinedBottomPillClearance` den
    // gemeinsamen Floor: `bottomSheetTabBarClearance` + `attributionGuardBottomInset`.

    /// Kombinierter Bottom-Inset fuer schwebende Map-Pills (Live-Recording,
    /// Simplified-Preview, Optimized-Overview-Badge), wenn die Pill keinen
    /// Sheet darunter hat. Der Wert reserviert sowohl die TabBar-Hoehe
    /// als auch den Attribution-Guard.
    public static func combinedBottomPillClearance(
        deviceBottomSafeInset: CGFloat
    ) -> CGFloat {
        bottomSheetTabBarClearance(deviceBottomSafeInset: deviceBottomSafeInset)
            + attributionGuardBottomInset
    }

    // MARK: - Phase D-1: Layer Order Contract
    //
    // Visuelle Stapel-Reihenfolge der Map-Surfaces. Wird im Code als
    // einheitliche `zIndex`-Quelle genutzt — wer Map-Overlays bauen
    // moechte, soll diese Konstanten verwenden, nicht eigene Magic
    // zIndex-Werte.
    //
    //   ┌──────────────────────────────────────┐
    //   │ tabBar              (zIndex 400, top)│
    //   │ floating chrome / menu (zIndex 300)  │
    //   │ bottom sheet / dashboard (zIndex 200)│
    //   │ map overlays / pills  (zIndex 100)   │
    //   │ map         (zIndex 0, background)   │
    //   └──────────────────────────────────────┘

    public enum LayerOrder {
        /// Karte selbst — bleibt immer untere Ebene.
        public static let map: Double = 0
        /// Schwebende Map-Pills (Simplified-Preview, Recording-Indicator).
        public static let mapOverlay: Double = 100
        /// Bottom-Sheets, Dashboards.
        public static let bottomSheet: Double = 200
        /// Floating-Chrome, MapLayerMenu, expandierbares Menue.
        public static let floatingChrome: Double = 300
        /// TabBar — bleibt ueber allem.
        public static let tabBar: Double = 400
    }
}
