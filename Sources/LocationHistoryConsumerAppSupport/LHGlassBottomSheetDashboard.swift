#if canImport(SwiftUI)
import SwiftUI

/// Liquid Glass bottom sheet dashboard with three detents (collapsed / medium /
/// expanded), a 44pt drag handle and a scrollable body that respects the map
/// attribution / tab-bar bottom clearance from LHMapBase.
/// See docs/UI_UX_MAP_FIRST_LIQUID_GLASS_CONTRACT_2026-05-28.md § 5.3.
@available(iOS 26.0, macOS 15.0, *)
public enum LHSheetDetent {
    case collapsed
    case medium
    case expanded
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

    public func height(for detent: LHSheetDetent) -> CGFloat {
        switch detent {
        case .collapsed: return collapsed
        case .medium: return medium
        case .expanded: return expanded
        }
    }
}

@available(iOS 26.0, macOS 15.0, *)
public struct LHGlassBottomSheetDashboard<HeaderContent: View, BodyContent: View>: View {
    private let detents: LHSheetDetents
    private let bottomClearance: CGFloat
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
        accessibilityPrefix: String = "lhSheet",
        @ViewBuilder header: () -> HeaderContent,
        @ViewBuilder body: () -> BodyContent
    ) {
        self.detents = detents
        self.bottomClearance = bottomClearance
        self.accessibilityPrefix = accessibilityPrefix
        self.header = header()
        self.bodyContent = body()
        self._currentDetent = State(initialValue: initialDetent)
    }

    public var body: some View {
        let height = detents.height(for: currentDetent)

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
        // Phase D-0 Visual Readability Hardening (2026-05-28):
        // Map-backed Sheets erzwingen den dark Color-Scheme fuer alle
        // Kinder. SwiftUI-systemnative `.primary`/`.secondary`-Texte
        // rendern damit zuverlaessig hell, unabhaengig vom Geraete-
        // Color-Scheme. Zusammen mit den `mapGlass*Text`-Tokens und dem
        // dunklen Base-Layer entsteht ein konsistentes, lesbares
        // Dashboard auf hellen Satelliten- wie auch dunklen Standardkarten.
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity)
        .frame(height: max(0, height - dragOffset))
        // B-5.5 Visual Hardening + Phase D-0 Verstaerkung: dunklerer
        // Base-Layer UNTER dem Liquid-Glass, damit Sheet-Text auch ueber
        // hellen Satelliten-Karten lesbar bleibt. D-0 hebt die Deckkraft
        // leicht an (0.18 → 0.28), damit Header-Captions ("KARTE",
        // "INSIGHTS", "EXPLORE") nicht mehr im Glass verschwinden.
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 22,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 22,
                style: .continuous
            )
            .fill(Color.black.opacity(0.28))
        )
        .lgGlassSurface(cornerRadius: 22)
        .gesture(dragGesture)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.85), value: currentDetent)
        .accessibilityIdentifier("\(accessibilityPrefix).root")
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
        case .medium: currentDetent = .expanded
        case .expanded: currentDetent = .collapsed
        }
    }

    private func promoteDetent() {
        switch currentDetent {
        case .collapsed: currentDetent = .medium
        case .medium: currentDetent = .expanded
        case .expanded: break
        }
    }

    private func demoteDetent() {
        switch currentDetent {
        case .expanded: currentDetent = .medium
        case .medium: currentDetent = .collapsed
        case .collapsed: break
        }
    }
}
#endif
