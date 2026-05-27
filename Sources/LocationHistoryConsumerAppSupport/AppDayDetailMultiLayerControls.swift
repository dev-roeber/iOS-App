#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI

// MARK: - View hierarchy (Day Detail Multi-Layer, Phase 3a)
//
// AppDayDetailView (portrait, multi-layer variant) — ZStack
//  ├── Map (full-bleed) — AppDayMapView(fullBleed: true, hidesBuiltInControls: true)
//  ├── overlay(.topLeading) → DayDetailLayerPanel
//  │     (Standard / Tempo / Höhe / Wetter — drives `mapTrackColorMode`,
//  │      plus a Route-Display toggle when paths exist)
//  ├── overlay(.topTrailing)→ LiveControlStack
//  │     (compass = fit-to-data, +, −, locate = fit-to-data fallback,
//  │      compact toggle is hidden via dedicated DayDetailControlStack below)
//  └── safeAreaInset(.bottom)
//        └── LiveBottomSheet (drag-detents 140/240/360) with the day's
//            headline (weekday + long date + time range) and the segmented
//            content (Overview / Timeline / Routes / Places).
//
// All strings flow through the preferences.localized() pipeline; German
// strings live in `AppLanguageSupport` (`AppGermanTranslations`).
// ReduceMotion is respected on the layer-panel chevron and sheet snap.

// MARK: - DayDetail Layer Panel

@available(iOS 17.0, macOS 14.0, *)
struct DayDetailLayerPanel: View {
    @Binding var selected: AppMapTrackColorMode
    @Binding var routeDisplay: AppDayPathDisplayMode
    /// Independent toggle: when on, the day-detail bottom sheet renders the
    /// `AppSpeedBandView` band under the KPIs. Decoupled from the radio
    /// `selected` map-colour mode so a user can read a tempo band while the
    /// map still shows activity colours, and vice-versa.
    @Binding var showTempoBand: Bool
    /// Same idea for `AppElevationProfileView` under the tempo band.
    @Binding var showElevationBand: Bool
    let hasPaths: Bool
    let layersLabel: String
    let standardLabel: String
    let speedLabel: String
    let elevationLabel: String
    let weatherLabel: String
    let routeDisplayLabel: String
    let routeOriginalLabel: String
    let routeSimplifiedLabel: String

    @State private var isExpanded: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            collapsedHeader
            if isExpanded {
                layerRow(color: .blue, title: standardLabel, isSelected: selected == .activity) {
                    selected = .activity
                }
                layerRow(color: .orange, title: speedLabel, isSelected: selected == .speed || showTempoBand) {
                    let willActivate = !(selected == .speed || showTempoBand)
                    selected = willActivate ? .speed : .activity
                    showTempoBand = willActivate
                }
                layerRow(color: .green, title: elevationLabel, isSelected: selected == .elevation || showElevationBand) {
                    let willActivate = !(selected == .elevation || showElevationBand)
                    selected = willActivate ? .elevation : .activity
                    showElevationBand = willActivate
                }
                layerRow(color: .cyan, title: weatherLabel, isSelected: selected == .weather) {
                    selected = (selected == .weather) ? .activity : .weather
                }
                if hasPaths {
                    Divider().opacity(0.4)
                    Text(routeDisplayLabel)
                        .font(.caption2.weight(.heavy))
                        .tracking(0.6)
                        .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                        .padding(.top, 2)
                    routeDisplayRow(
                        title: routeOriginalLabel,
                        mode: .original
                    )
                    routeDisplayRow(
                        title: routeSimplifiedLabel,
                        mode: .mapMatched
                    )
                }
            }
        }
        .padding(isExpanded ? 12 : 8)
        .frame(width: isExpanded ? 188 : nil)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: isExpanded ? 18 : 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? 18 : 14, style: .continuous)
                .stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
        .accessibilityIdentifier("dayDetail.layerPanel")
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
    }

    @ViewBuilder
    private func layerRow(color: Color, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(isSelected ? 0.95 : 0.30))
                    .frame(width: 14, height: 14)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Spacer(minLength: 4)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(isSelected ? color : Color.secondary.opacity(0.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }

    @ViewBuilder
    private func routeDisplayRow(title: String, mode: AppDayPathDisplayMode) -> some View {
        let isSelected = routeDisplay == mode
        Button { routeDisplay = mode } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.6))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dayDetail.routeDisplay.\(mode.rawValue)")
    }
}

// MARK: - DayDetail Control Stack
//
// Mirrors `LiveControlStack` visuals but with day-specific actions: compass
// = fit-to-data, +/− = zoom, locate = fit-to-data (no follow concept on a
// historical day map). The compact toggle is omitted by design.

@available(iOS 17.0, macOS 14.0, *)
struct DayDetailControlStack: View {
    let onFitToData: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let compassLabel: String
    let zoomInLabel: String
    let zoomOutLabel: String
    let fitLabel: String

    var body: some View {
        VStack(spacing: 8) {
            pillButton(icon: "location.north.fill", label: compassLabel, tint: .red, action: onFitToData)
                .accessibilityIdentifier("dayDetail.control.compass")
            pillButton(icon: "plus", label: zoomInLabel, tint: .primary, action: onZoomIn)
                .accessibilityIdentifier("dayDetail.control.zoomIn")
            pillButton(icon: "minus", label: zoomOutLabel, tint: .primary, action: onZoomOut)
                .accessibilityIdentifier("dayDetail.control.zoomOut")
            pillButton(icon: "scope", label: fitLabel, tint: .primary, action: onFitToData)
                .accessibilityIdentifier("dayDetail.control.fit")
        }
    }

    private func pillButton(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .lhGlassControlPill()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#endif
