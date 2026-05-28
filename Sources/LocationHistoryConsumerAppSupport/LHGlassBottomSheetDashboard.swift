#if canImport(SwiftUI)
import SwiftUI

// Liquid Glass bottom sheet dashboard.
// See docs/UI_UX_MAP_FIRST_LIQUID_GLASS_CONTRACT_2026-05-28.md § 5.3.

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
        case .full: return expanded
        }
    }
}

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

    private static var fullTopReserve: CGFloat { 64 }
    private static var dragThreshold: CGFloat { 24 }

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
        let floor = detents.expanded + bottomClearance
        guard availableHeight > 0 else { return floor }
        return max(floor, availableHeight - topSafeInset - Self.fullTopReserve)
    }

    private func frameHeight(for detent: LHSheetDetent) -> CGFloat {
        switch detent {
        case .full: return fullHeight
        default:    return detents.height(for: detent) + bottomClearance
        }
    }

    public var body: some View {
        let base = frameHeight(for: currentDetent)
        let clamped = min(max(base - dragOffset, 0), fullHeight)

        VStack(spacing: 0) {
            VStack(spacing: 0) {
                dragHandle
                header
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    bodyContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, bottomClearance)
            }
        }
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity)
        .frame(height: clamped)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 22,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 22,
                style: .continuous
            )
            .fill(Color.black.opacity(0.28))
            .ignoresSafeArea(.container, edges: .bottom)
        )
        .lgGlassSurface(cornerRadius: 22)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.85), value: currentDetent)
        // P0-Fix 2026-05-28 Identifier-Cascading: ohne `children: .contain`
        // erbten alle Sub-Buttons (Stop/Start, Background Recording usw.) den
        // `<prefix>.root`-Identifier statt ihres eigenen — Tests konnten
        // `live.recording.primaryAction` etc. nicht mehr finden. .contain
        // hält den Container als a11y-Element ohne Kinder zu vereinnahmen.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(accessibilityPrefix).root")
    }

    private var dragHandle: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.6))
                .frame(width: 44, height: 6)
                .shadow(color: Color.black.opacity(0.25), radius: 1, y: 0.5)
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
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($dragOffset) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                if value.translation.height < -Self.dragThreshold {
                    promoteDetent()
                } else if value.translation.height > Self.dragThreshold {
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
