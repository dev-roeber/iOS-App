#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit

// MARK: - View hierarchy (Live Multi-Layer redesign, Phase 19.28)
//
// AppLiveTrackingView (portrait, multi-layer variant) — ZStack
//  ├── Map (full-bleed) — liveMapBase / liveMapPlaceholderContent
//  ├── overlay(.topLeading) → LiveLayerPanel   (Standard/Tempo/Höhe/Wetter)
//  ├── overlay(.topTrailing)→ LiveControlStack (compass / + / − / locate / compact)
//  └── safeAreaInset(.bottom)
//        └── LiveBottomSheet (drag-handle, status legend, recording button below)
//
// The global recording indicator lives in the navigation toolbar
// (GlobalRecordingToolbarIndicator) and is shared by all four tabs.
//
// All strings flow through the preferences.localized() pipeline; german
// strings are added to AppGermanTranslations.values.
// ReduceMotion is respected: pill pulse, layer-panel chevron and sheet drag
// transitions are disabled when the user opts out.

// MARK: - Layer Panel

@available(iOS 17.0, macOS 14.0, *)
struct LiveLayerPanel: View {
    @Binding var selected: AppMapTrackColorMode
    @Binding var showWeather: Bool
    @Binding var showElevation: Bool
    let layersLabel: String
    var weatherAllowed: Bool = true
    var weatherDisabledHint: String = "In Einstellungen aktivieren"

    @State private var isExpanded: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            collapsedHeader
            if isExpanded {
                layerRow(
                    color: .blue,
                    title: "Standard",
                    isOn: Binding(
                        get: { selected == .activity },
                        set: { newValue in if newValue { selected = .activity } }
                    )
                )
                layerRow(
                    color: .orange,
                    title: "Tempo",
                    isOn: Binding(
                        get: { selected == .speed },
                        set: { newValue in if newValue { selected = .speed } else { selected = .activity } }
                    )
                )
                layerRow(
                    color: .green,
                    title: "Höhe",
                    isOn: $showElevation
                )
                layerRow(
                    color: .cyan,
                    title: "Wetter",
                    isOn: weatherAllowed
                        ? $showWeather
                        : .constant(false),
                    disabled: !weatherAllowed
                )
                if !weatherAllowed {
                    Text(weatherDisabledHint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 22)
                }
            }
        }
        .padding(isExpanded ? 12 : 8)
        .frame(width: isExpanded ? 168 : nil)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: isExpanded ? 18 : 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? 18 : 14, style: .continuous)
                .stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
    }

    private var collapsedHeader: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.3.layers.3d")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                Text(layersLabel)
                    .font(.caption2.weight(.heavy))
                    .tracking(0.6)
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                    .lineLimit(1)
                if isExpanded {
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(layersLabel)
        .accessibilityHint(isExpanded ? "Tippen zum Einklappen" : "Tippen zum Ausklappen")
    }

    @ViewBuilder
    private func layerRow(color: Color, title: String, isOn: Binding<Bool>, disabled: Bool = false) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opacity(isOn.wrappedValue ? 0.95 : 0.30))
                .frame(width: 14, height: 14)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isOn.wrappedValue ? .primary : .secondary)
            Spacer(minLength: 4)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .scaleEffect(0.75)
                .frame(width: 36, height: 22)
                .disabled(disabled)
        }
        .opacity(disabled ? 0.5 : 1.0)
    }
}

// MARK: - Layer Section (for embedding in bottom sheet in landscape)
//
// Same data model as `LiveLayerPanel` but rendered as an inline expandable
// section so it can live inside the `LiveBottomSheet` content closure in
// iPhone landscape — where the top-leading overlay would otherwise compete
// with the map for vertical room.

@available(iOS 17.0, macOS 14.0, *)
struct LiveLayerSection: View {
    @Binding var selected: AppMapTrackColorMode
    @Binding var showWeather: Bool
    @Binding var showElevation: Bool
    let layersLabel: String
    var weatherAllowed: Bool = true
    var weatherDisabledHint: String = "In Einstellungen aktivieren"

    @State private var isExpanded: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.3.layers.3d")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                    Text(layersLabel)
                        .font(.caption2.weight(.heavy))
                        .tracking(0.7)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("live.bottomSheet.layers")

            if isExpanded {
                layerRow(color: .blue, title: "Standard", isOn: Binding(
                    get: { selected == .activity },
                    set: { newValue in if newValue { selected = .activity } }
                ))
                layerRow(color: .orange, title: "Tempo", isOn: Binding(
                    get: { selected == .speed },
                    set: { newValue in if newValue { selected = .speed } else { selected = .activity } }
                ))
                layerRow(color: .green, title: "Höhe", isOn: $showElevation)
                layerRow(
                    color: .cyan,
                    title: "Wetter",
                    isOn: weatherAllowed ? $showWeather : .constant(false),
                    disabled: !weatherAllowed
                )
                if !weatherAllowed {
                    Text(weatherDisabledHint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 22)
                }
            }
        }
    }

    @ViewBuilder
    private func layerRow(color: Color, title: String, isOn: Binding<Bool>, disabled: Bool = false) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opacity(isOn.wrappedValue ? 0.95 : 0.30))
                .frame(width: 14, height: 14)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isOn.wrappedValue ? .primary : .secondary)
            Spacer(minLength: 4)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .scaleEffect(0.78)
                .frame(width: 38, height: 24)
                .disabled(disabled)
        }
        .padding(.vertical, 4)
        .opacity(disabled ? 0.5 : 1.0)
    }
}

// MARK: - Control Stack

@available(iOS 17.0, macOS 14.0, *)
struct LiveControlStack: View {
    let isFollowing: Bool
    let onCompass: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onLocate: () -> Void
    let onCompactToggle: () -> Void
    let isCompact: Bool
    /// When true, renders smaller pills with tighter spacing so the stack does
    /// not steal horizontal room in iPhone landscape. Defaults to `false` for
    /// portrait callers (no behaviour change).
    var compactSize: Bool = false

    var body: some View {
        VStack(spacing: compactSize ? 6 : 8) {
            pillButton(icon: "location.north.fill", label: "Compass", tint: .red, action: onCompass)
            pillButton(icon: "plus", label: "Zoom in", tint: .primary, action: onZoomIn)
            pillButton(icon: "minus", label: "Zoom out", tint: .primary, action: onZoomOut)
            pillButton(
                icon: isFollowing ? "location.fill" : "scope",
                label: "Locate",
                tint: isFollowing ? .blue : .primary,
                action: onLocate
            )
            pillButton(
                icon: isCompact ? "rectangle.expand.vertical" : "rectangle.compress.vertical",
                label: "Compact map",
                tint: .primary,
                action: onCompactToggle
            )
        }
    }

    private var pillSize: CGFloat { compactSize ? 30 : 38 }
    private var pillFont: Font { compactSize ? .caption.weight(.semibold) : .subheadline.weight(.semibold) }

    private func pillButton(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(pillFont)
                .foregroundStyle(tint)
                .frame(width: pillSize, height: pillSize)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8))
                .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Bottom Sheet Row

@available(iOS 17.0, macOS 14.0, *)
struct LiveBottomSheetRow: View {
    let indicatorColor: Color
    let icon: String
    let label: String
    let value: String
    var trailingTint: Color = .secondary
    var action: (() -> Void)? = nil

    var body: some View {
        let row = HStack(spacing: 10) {
            ZStack {
                Circle().fill(indicatorColor.opacity(0.18)).frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(indicatorColor)
            }
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(trailingTint)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())

        if let action {
            Button(action: action) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }
}

// MARK: - Bottom Sheet Container

@available(iOS 17.0, macOS 14.0, *)
public enum LiveBottomSheetDetent: CGFloat, CaseIterable {
    case collapsed = 140
    case medium = 240
    case expanded = 360
}

/// Sheet height triple. Defaults match the original portrait values; iPhone
/// landscape callers pass smaller values so the map keeps visible room above
/// the sheet. Public so tests can pin specific scenarios.
@available(iOS 17.0, macOS 14.0, *)
public struct LiveBottomSheetHeights: Equatable {
    public let collapsed: CGFloat
    public let medium: CGFloat
    public let expanded: CGFloat

    public init(collapsed: CGFloat, medium: CGFloat, expanded: CGFloat) {
        self.collapsed = collapsed
        self.medium = medium
        self.expanded = expanded
    }

    public static let portrait = LiveBottomSheetHeights(collapsed: 140, medium: 240, expanded: 360)
    public static let landscapeCompact = LiveBottomSheetHeights(collapsed: 140, medium: 200, expanded: 280)
    /// Phase 19.28 follow-up: when the live map collapses to ~50% in the
    /// portrait compact variant, the sheet can grow further to give the
    /// status legend / metrics list more room.
    public static let compactPortrait = LiveBottomSheetHeights(collapsed: 160, medium: 320, expanded: 520)
}

@available(iOS 17.0, macOS 14.0, *)
struct LiveBottomSheet<Content: View>: View {
    let headerCaption: String
    let headlineText: String
    let headlineTint: Color
    var heights: LiveBottomSheetHeights = .portrait
    /// Reservierter Bottom-Inset INNERHALB des Sheets, damit der unterste
    /// Inhalt (Track-Library, Orte, Diagnostics) NICHT von der iOS-26-Tab-
    /// Bar verdeckt wird. Uebergeben aus den jeweiligen Screens via
    /// `LHMapBase.bottomSheetTabBarClearance(...)`.
    var bottomClearance: CGFloat = 0
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var detentIndex: Int = 1 // 0 = collapsed, 1 = medium, 2 = expanded
    @GestureState private var dragOffset: CGFloat = 0

    private var detentValue: CGFloat {
        switch detentIndex {
        case 0: return heights.collapsed
        case 2: return heights.expanded
        default: return heights.medium
        }
    }

    private var currentHeight: CGFloat {
        // Negative dragOffset = drag up = larger height. Clamp to [80, expanded+40].
        let raw = detentValue - dragOffset
        let maxH = heights.expanded + 40 + bottomClearance
        return min(max(raw, 80), maxH)
    }

    var body: some View {
        VStack(spacing: 0) {
            handle
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerCaption)
                        .font(.caption2.weight(.heavy))
                        .tracking(0.7)
                        .foregroundStyle(.secondary)
                    Text(headlineText)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(headlineTint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ScrollView(.vertical, showsIndicators: false) {
                    content()
                        .padding(.bottom, bottomClearance)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12 + bottomClearance)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: currentHeight + bottomClearance, alignment: .top)
        .background(sheetSurface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LH2GPXTheme.LiquidGlass.hairline)
                .frame(height: 0.6)
        }
        .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: -6)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.85), value: detentIndex)
    }

    private var handle: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.secondary.opacity(0.55))
                .frame(width: 44, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.height
                }
                .onEnded { value in
                    snap(to: value.predictedEndTranslation.height)
                }
        )
        .onTapGesture { cycleDetent() }
        .accessibilityElement()
        .accessibilityLabel("Sheet-Griff")
        .accessibilityAddTraits(.isButton)
    }

    private var sheetSurface: some View {
        // Phase 19.29: trim the white surface tint and the top→bottom gradient
        // so the underlying map shows through more. ultraThinMaterial stays as
        // the base blur so the hairline outline and legibility are preserved.
        UnevenRoundedRectangle(
            topLeadingRadius: 22,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 22,
            style: .continuous
        )
        .fill(Color.white.opacity(0.03))
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.025), Color.white.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 22,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 22,
                    style: .continuous
                )
            )
        )
        .background(.ultraThinMaterial,
            in: UnevenRoundedRectangle(
                topLeadingRadius: 22,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 22,
                style: .continuous
            )
        )
    }

    private func snap(to predictedTranslation: CGFloat) {
        // Up = negative translation. Pick the nearest detent to (current - translation).
        let target = detentValue - predictedTranslation
        if target > (heights.medium + heights.expanded) / 2 {
            detentIndex = 2
        } else if target > (heights.collapsed + heights.medium) / 2 {
            detentIndex = 1
        } else {
            detentIndex = 0
        }
    }

    private func cycleDetent() {
        detentIndex = (detentIndex + 1) % 3
    }
}

#endif
