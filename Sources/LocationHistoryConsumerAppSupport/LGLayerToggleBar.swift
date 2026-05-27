#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct LGLayerToggleBar: View {
    @Binding private var selected: AppMapTrackColorMode
    @Namespace private var namespace

    public init(selected: Binding<AppMapTrackColorMode>) {
        self._selected = selected
    }

    public var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(AppMapTrackColorMode.allCases) { layer in
                        glassButton(for: layer)
                            .glassEffectID(layer.rawValue, in: namespace)
                    }
                }
            }
            .animation(.smooth(duration: 0.35), value: selected)
        } else {
            fallbackBar
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private func glassButton(for layer: AppMapTrackColorMode) -> some View {
        let isActive = selected == layer
        if isActive {
            Button {
                selected = layer
            } label: {
                Label(layer.glassLayerTitle, systemImage: layer.glassLayerIcon)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(layer.glassLayerTint)
            .accessibilityAddTraits(.isSelected)
        } else {
            Button {
                selected = layer
            } label: {
                Image(systemName: layer.glassLayerIcon)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(layer.glassLayerTitle)
        }
    }

    private var fallbackBar: some View {
        HStack(spacing: 6) {
            ForEach(AppMapTrackColorMode.allCases) { layer in
                fallbackButton(for: layer)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.32), lineWidth: 0.8))
    }

    private func fallbackButton(for layer: AppMapTrackColorMode) -> some View {
        let isActive = selected == layer
        return Button {
            withAnimation(.smooth(duration: 0.35)) {
                selected = layer
            }
        } label: {
            Label {
                if isActive {
                    Text(layer.glassLayerTitle)
                }
            } icon: {
                Image(systemName: layer.glassLayerIcon)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isActive ? Color.white : layer.glassLayerTint)
            .padding(.horizontal, isActive ? 10 : 8)
            .frame(minHeight: 44)
            .background(isActive ? layer.glassLayerTint : Color.clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(layer.glassLayerTitle)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

@available(iOS 17.0, macOS 14.0, *)
private extension AppMapTrackColorMode {
    var glassLayerTitle: String {
        switch self {
        case .activity:  return "Standard"
        case .speed:     return "Tempo"
        case .elevation: return "Höhenmeter"
        case .weather:   return "Wetter vorbereitet"
        }
    }

    var glassLayerIcon: String {
        switch self {
        case .activity:  return "map"
        case .speed:     return "speedometer"
        case .elevation: return "mountain.2"
        case .weather:   return "cloud.sun"
        }
    }

    var glassLayerTint: Color {
        switch self {
        case .activity:  return .blue
        case .speed:     return .orange
        case .elevation: return .green
        case .weather:   return .cyan
        }
    }
}
#endif
