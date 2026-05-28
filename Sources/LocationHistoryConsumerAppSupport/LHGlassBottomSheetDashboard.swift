#if canImport(SwiftUI)
import SwiftUI

/// Liquid Glass bottom sheet dashboard mit jetzt VIER Rasten
/// (collapsed / medium / expanded / full), 44pt Drag-Handle und scrollbarem
/// Body, der die Map-Attribution / TabBar-Clearance aus LHMapBase respektiert.
///
/// Änderungen ggü. Vorversion (Map-First Hardening):
///   1. Neue `.full`-Raste → Sheet bis Vollbild ziehbar. Die echte Höhe wird
///      aus der vom Scaffold gelieferten verfügbaren Höhe gerechnet
///      (Environment `lhSheetAvailableHeight`), gedeckelt nach oben durch
///      `topSafeInset` (Sheet-Griff bleibt unter der Status Bar / Dynamic Island).
///   2. Bei `.full`: Eckenradius → 0 und Base-Layer opak (0.92) — exakt das
///      iOS-26-Verhalten ("large detent" = flush + opak).
///   3. Flush bis zur Bildschirmkante: Das Scaffold pinnt das Sheet hart an den
///      unteren Bildschirmrand (siehe LHMapFirstPageScaffold). Der Base-Layer
///      ignoriert zusätzlich die untere Safe Area, damit das Glas auch unter
///      dem Home-Indicator durchläuft. Content behält `bottomClearance`.
///
/// See docs/UI_UX_MAP_FIRST_LIQUID_GLASS_CONTRACT_2026-05-28.md § 5.3.
@available(iOS 26.0, macOS 15.0, *)
public enum LHSheetDetent {
    case collapsed
    case medium
    case expanded
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

    // MARK: B-5.5 Visual Hardening — per-screen Detent-Profile (unverändert)
    public static let mapTab = LHSheetDetents(collapsed: 130, medium: 220, expanded: 380)
    public static let live = LHSheetDetents(collapsed: 150, medium: 260, expanded: 420)
    public static let dayDetail = LHSheetDetents(collapsed: 150, medium: 280, expanded: 440)
    public static let insights = LHSheetDetents(collapsed: 160, medium: 320, expanded: 480)
    public static let export = compactPortrait

    public func height(for detent: LHSheetDetent) -> CGFloat {
        switch detent {
        case .collapsed: return collapsed
        case .medium: return medium
        case .expanded: return expanded
        case .full: return expanded   // Fallback; echte Vollbild-Höhe rechnet die View
        }
    }
}

// MARK: - Verfügbare Höhe aus dem Scaffold (für die .full-Raste)
//
// Das Scaffold misst per GeometryReader die volle (safe-area-ignorierende)
// Bildschirmhöhe und gibt sie über das Environment nach unten an das Sheet,
// ohne dass jeder Aufrufer das selbst durchreichen muss. Default 0 → wenn das
// Sheet ohne Scaffold benutzt würde, fällt `.full` sauber auf `.expanded` zurück.
private struct LHSheetAvailableHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}
extension EnvironmentValues {
    var lhSheetAvailableHeight: CGFloat {
        get { self[LHSheetAvailableHeightKey.self] }
        set { self[LHSheetAvailableHeightKey.self] = newValue }
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
    @Environment(\.lhSheetAvailableHeight) private var availableHeight

    /// Abstand zwischen Sheet-Oberkante und Status Bar / Dynamic Island im
    /// `.full`-Zustand, zusätzlich zum `topSafeInset`.
    private static var fullTopGap: CGFloat { 8 }

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

    private var fullHeight: CGFloat {
        guard availableHeight > 0 else { return detents.expanded }
        return max(detents.expanded, availableHeight - topSafeInset - Self.fullTopGap)
    }

    private func resolvedHeight(_ detent: LHSheetDetent) -> CGFloat {
        switch detent {
        case .full: return fullHeight
        default:    return detents.height(for: detent)
        }
    }

    private var isFull: Bool { currentDetent == .full }

    public var body: some View {
        let target = resolvedHeight(currentDetent)
        // Live-Drag: nach oben über die aktuelle Raste hinaus erlauben, aber
        // hart bei der Vollbild-Höhe deckeln; nach unten nie < 0.
        let clamped = min(max(target - dragOffset, 0), fullHeight)
        let radius: CGFloat = isFull ? 0 : 22
        let baseOpacity: Double = isFull ? 0.92 : 0.28

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
        // Map-backed Sheets erzwingen dark Color-Scheme für lesbaren Text.
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity)
        .frame(height: clamped)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: radius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: radius,
                style: .continuous
            )
            .fill(Color.black.opacity(baseOpacity))
            // Base-Layer läuft flush unter den Home-Indicator durch.
            .ignoresSafeArea(.container, edges: .bottom)
        )
        .lgGlassSurface(cornerRadius: radius)
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
        case .medium: currentDetent = .expanded
        case .expanded: currentDetent = .full
        case .full: currentDetent = .collapsed
        }
    }

    private func promoteDetent() {
        switch currentDetent {
        case .collapsed: currentDetent = .medium
        case .medium: currentDetent = .expanded
        case .expanded: currentDetent = .full
        case .full: break
        }
    }

    private func demoteDetent() {
        switch currentDetent {
        case .full: currentDetent = .expanded
        case .expanded: currentDetent = .medium
        case .medium: currentDetent = .collapsed
        case .collapsed: break
        }
    }
}
#endif
