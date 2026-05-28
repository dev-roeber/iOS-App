#if canImport(SwiftUI)
import SwiftUI

/// Liquid Glass bottom sheet dashboard with four detents (collapsed / medium /
/// expanded / full), a 44pt drag handle and a scrollable body that respects
/// the map attribution / tab-bar bottom clearance from LHMapBase.
///
/// Phase D-1.1 (Flush + Fullscreen):
/// - Neuer Detent `.full` rendert das Sheet flush bis fast unter den
///   System-Status-Bar (topSafeInset + 6 pt Luft) und schaltet auf einen
///   opaken Base-Layer (Apple-iOS-26-large-detent-Verhalten).
/// - Background ist EINE Ebene, die nach unten ueber die Safe-Area lauft
///   (`ignoresSafeArea(.container, edges: .bottom)`), damit die fruehere
///   Luecke zwischen Sheet und TabBar verschwindet. Inhalt bleibt durch
///   `bottomClearance` von der TabBar entkoppelt.
/// See docs/UI_UX_MAP_FIRST_LIQUID_GLASS_CONTRACT_2026-05-28.md § 5.3.
@available(iOS 26.0, macOS 15.0, *)
public enum LHSheetDetent {
    case collapsed
    case medium
    case expanded
    /// Phase D-1.1: Fullscreen-Detent. Hoehe wird dynamisch aus dem
    /// `GeometryReader` ermittelt (verfuegbare Hoehe − topSafeInset − 6 pt).
    case full
}

@available(iOS 26.0, macOS 15.0, *)
public struct LHSheetDetents {
    public let collapsed: CGFloat
    public let medium: CGFloat
    public let expanded: CGFloat

    public init(collapsed: CGFloat, medium: CGFloat, expanded: CGFloat) {
        self.collapsed = collapsed
        self.medium = medium
        self.expanded = expanded
    }

    public static let portrait = LHSheetDetents(collapsed: 140, medium: 240, expanded: 360)
    public static let landscape = LHSheetDetents(collapsed: 140, medium: 200, expanded: 280)
    public static let compactPortrait = LHSheetDetents(collapsed: 160, medium: 320, expanded: 520)

    // MARK: B-5.5 Visual Hardening — per-screen Detent-Profile
    //
    // Eigene Profile pro Surface, damit Detents nicht mehr per Magic
    // Number inline am Aufrufer gesetzt werden. Die Profile sind so
    // gewaehlt, dass:
    //   - collapsed → Header + 1-2 Zeilen sichtbar, Karte dominiert.
    //   - medium    → nutzbare Sheet-Hoehe, ohne Apple-Maps-Attribution
    //                 oder Custom-TabBar zu verdecken.
    //   - expanded  → scrollbarer Inhalt, kein Vollscreen-Block.
    //   - full      → dynamisch aus verfuegbarer Hoehe (Phase D-1.1).
    //
    // Die alten `.portrait` / `.compactPortrait` / `.landscape` bleiben
    // als Default-Profile fuer Komponenten, die kein Surface-Wissen
    // haben.

    /// Map-Tab Hero — Karte soll dominieren, Sheet kompakt.
    public static let mapTab = LHSheetDetents(collapsed: 130, medium: 220, expanded: 380)

    /// Live Tracking — Sheet hostet Status-Liste + Metriken; FAB lebt im
    /// Sheet-Header, deshalb darf das Sheet etwas hoeher starten.
    public static let live = LHSheetDetents(collapsed: 150, medium: 260, expanded: 420)

    /// DayDetail — Sheet hostet Segmented-Content + KPI-Grid + Bands.
    public static let dayDetail = LHSheetDetents(collapsed: 150, medium: 280, expanded: 440)

    /// Insights — Sheet hostet Filter + KPI-Grid + Highlights + Charts-
    /// Einstieg. Hoeher als DayDetail wegen Mode-/Filter-Strips am Top.
    public static let insights = LHSheetDetents(collapsed: 160, medium: 320, expanded: 480)

    /// Export — Sheet hostet die komplette Checkout-Liste inkl. Export-
    /// Button am Ende. Bleibt der hoechste Profil-Wert (Export-Button
    /// muss erreichbar sein).
    public static let export = compactPortrait

    /// Statische Hoehen fuer .collapsed/.medium/.expanded. `.full` wird im
    /// Dashboard dynamisch aus dem GeometryReader berechnet und liefert
    /// hier den `expanded`-Wert als sicheren Fallback fuer Aufrufer, die
    /// die Detents ohne GeometryReader-Kontext abfragen.
    public func height(for detent: LHSheetDetent) -> CGFloat {
        switch detent {
        case .collapsed: return collapsed
        case .medium: return medium
        case .expanded: return expanded
        case .full: return expanded
        }
    }
}

@available(iOS 26.0, macOS 15.0, *)
public struct LHGlassBottomSheetDashboard<HeaderContent: View, BodyContent: View>: View {
    private let detents: LHSheetDetents
    private let bottomClearance: CGFloat
    private let topSafeInset: CGFloat
    private let accessibilityPrefix: String
    private let header: HeaderContent
    private let bodyContent: BodyContent

    @State private var currentDetent: LHSheetDetent
    @GestureState private var dragOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        detents: LHSheetDetents = .portrait,
        initialDetent: LHSheetDetent = .medium,
        bottomClearance: CGFloat,
        topSafeInset: CGFloat = 0,
        accessibilityPrefix: String = "lhSheet",
        @ViewBuilder header: () -> HeaderContent,
        @ViewBuilder body: () -> BodyContent
    ) {
        self.detents = detents
        self.bottomClearance = bottomClearance
        self.topSafeInset = topSafeInset
        self.accessibilityPrefix = accessibilityPrefix
        self.header = header()
        self.bodyContent = body()
        self._currentDetent = State(initialValue: initialDetent)
    }

    public var body: some View {
        GeometryReader { proxy in
            // Phase D-1.1: verfuegbare Hoehe + topSafeInset ergeben die
            // dynamische Fullscreen-Hoehe. 6 pt Luft unter dem System-
            // Status-Bar/Notch, damit der Drag-Handle nicht hinter die
            // Dynamic Island wandert. Fallback auf `detents.expanded`,
            // damit die Fullscreen-Hoehe niemals KLEINER als der bekannte
            // expanded-Wert wird (Surface-Profile-Schutz).
            let available = proxy.size.height
            let fullHeight = max(detents.expanded, available - topSafeInset - 6)
            let baseHeight = resolvedHeight(fullHeight: fullHeight)
            let isFull = (currentDetent == .full)

            VStack(spacing: 0) {
                dragHandle

                header
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        bodyContent
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, bottomClearance)
                }
            }
            // Phase D-0: dark color-scheme erzwungen, damit Sheet-Text
            // ueber hellen Satelliten- und dunklen Standardkarten
            // gleichbleibend hell rendert.
            .environment(\.colorScheme, .dark)
            .frame(maxWidth: .infinity)
            .frame(height: max(0, baseHeight - dragOffset))
            // Phase D-1.1 FLUSH-FIX: Eine einzige background-Ebene, die
            // nach unten in die Safe-Area hineinlaeuft. Vorher rendere
            // Dark-Base + lgGlassSurface zwei getrennte Layer, was eine
            // sichtbare Luecke zwischen Sheet und TabBar/Attribution
            // hinterliess. Im .full-Detent wird die Base-Opacity
            // auf ~0.92 angehoben (iOS-26 large-detent ist opak).
            .background(flushBackground(isFull: isFull))
            .gesture(dragGesture)
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.85), value: currentDetent)
            .accessibilityIdentifier("\(accessibilityPrefix).root")
        }
    }

    /// Resolved height for the current detent. `.full` uses the dynamic
    /// fullscreen height; other detents fall back to the surface profile.
    private func resolvedHeight(fullHeight: CGFloat) -> CGFloat {
        switch currentDetent {
        case .collapsed: return detents.collapsed
        case .medium:    return detents.medium
        case .expanded:  return detents.expanded
        case .full:      return fullHeight
        }
    }

    /// Flush background that extends through the device bottom safe-area
    /// so there is no visible gap between the sheet and the TabBar /
    /// Apple-Maps attribution. Bottom radius collapses to 0 in `.full`
    /// (iOS-26 large detent = flush opaque) and stays at 0 otherwise so
    /// the sheet sits flush on the bottom edge.
    @ViewBuilder
    private func flushBackground(isFull: Bool) -> some View {
        let topRadius: CGFloat = isFull ? 0 : 22
        let baseOpacity: Double = isFull ? 0.92 : 0.28
        UnevenRoundedRectangle(
            topLeadingRadius: topRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: topRadius,
            style: .continuous
        )
        .fill(Color.black.opacity(baseOpacity))
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: topRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: topRadius,
                style: .continuous
            )
            .fill(.clear)
            .modifier(LHFlushGlassSurface(cornerRadius: topRadius))
        )
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var dragHandle: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(LH2GPXTheme.LiquidGlass.hairline)
                .frame(width: 40, height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Sheet-Griff"))
        .accessibilityValue(Text(detentAccessibilityValue))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("\(accessibilityPrefix).handle")
        .onTapGesture { cycleDetent() }
    }

    private var detentAccessibilityValue: String {
        switch currentDetent {
        case .collapsed: return "Eingeklappt"
        case .medium: return "Mittel"
        case .expanded: return "Ausgeklappt"
        case .full: return "Vollbild"
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragOffset) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let threshold: CGFloat = 40
                if value.translation.height < -threshold {
                    promoteDetent()
                } else if value.translation.height > threshold {
                    demoteDetent()
                }
            }
    }

    private func cycleDetent() {
        switch currentDetent {
        case .collapsed: currentDetent = .medium
        case .medium:    currentDetent = .expanded
        case .expanded:  currentDetent = .full
        case .full:      currentDetent = .collapsed
        }
    }

    private func promoteDetent() {
        switch currentDetent {
        case .collapsed: currentDetent = .medium
        case .medium:    currentDetent = .expanded
        case .expanded:  currentDetent = .full
        case .full:      break
        }
    }

    private func demoteDetent() {
        switch currentDetent {
        case .full:      currentDetent = .expanded
        case .expanded:  currentDetent = .medium
        case .medium:    currentDetent = .collapsed
        case .collapsed: break
        }
    }
}

/// Thin wrapper that re-uses the existing `lgGlassSurface` modifier for the
/// Liquid-Glass material. Kept as a `ViewModifier` so the flush background
/// composition stays readable.
@available(iOS 26.0, macOS 15.0, *)
private struct LHFlushGlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    func body(content: Content) -> some View {
        content.lgGlassSurface(cornerRadius: cornerRadius)
    }
}
#endif
