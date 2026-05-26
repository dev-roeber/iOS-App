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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(layersLabel)
                .font(.caption2.weight(.heavy))
                .tracking(0.6)
                .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)

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
                isOn: $showWeather
            )
        }
        .padding(12)
        .frame(width: 168)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
    }

    @ViewBuilder
    private func layerRow(color: Color, title: String, isOn: Binding<Bool>) -> some View {
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
        }
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

    var body: some View {
        VStack(spacing: 8) {
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

    private func pillButton(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
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
struct LiveBottomSheet<Content: View>: View {
    let headerCaption: String
    let headlineText: String
    let headlineTint: Color
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.secondary.opacity(0.45))
                .frame(width: 44, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 10)

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
                content()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 22,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 22,
                style: .continuous
            )
            .fill(Color(.systemBackground).opacity(0.92))
        )
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LH2GPXTheme.LiquidGlass.hairline)
                .frame(height: 0.6)
        }
        .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: -6)
    }
}

#endif
