#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit

/// Single source of truth for the right-hand layer dropdown rendered on every
/// map surface (Overview, Day, Heatmap, Export, Live, Recorded-Track Editor).
///
/// All map layer toggles, palette pickers, and viewport actions are funnelled
/// through this menu so the user has one consistent entry point on every
/// screen. Each view passes a `Configuration` describing which sections apply
/// to its context — sections without applicable controls are omitted.
@available(iOS 17.0, macOS 14.0, *)
public struct MapLayerMenu: View {
    @EnvironmentObject private var preferences: AppPreferences

    public struct Configuration {
        public var showsTrackColor: Bool
        public var showsLiveOptions: Bool
        public var showsHeatmapControls: Bool
        public var fitToData: (() -> Void)?
        public var centerOnLocation: (() -> Void)?
        public var toggleFullscreen: (() -> Void)?
        public var isFullscreenActive: Bool

        public init(
            showsTrackColor: Bool = false,
            showsLiveOptions: Bool = false,
            showsHeatmapControls: Bool = false,
            fitToData: (() -> Void)? = nil,
            centerOnLocation: (() -> Void)? = nil,
            toggleFullscreen: (() -> Void)? = nil,
            isFullscreenActive: Bool = false
        ) {
            self.showsTrackColor = showsTrackColor
            self.showsLiveOptions = showsLiveOptions
            self.showsHeatmapControls = showsHeatmapControls
            self.fitToData = fitToData
            self.centerOnLocation = centerOnLocation
            self.toggleFullscreen = toggleFullscreen
            self.isFullscreenActive = isFullscreenActive
        }
    }

    private let configuration: Configuration

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    public var body: some View {
        Menu {
            mapStyleSection

            if configuration.showsTrackColor {
                trackColorSection
            }

            if configuration.showsLiveOptions {
                liveOptionsSection
            }

            if configuration.showsHeatmapControls {
                heatmapPaletteSection
                heatmapScaleSection
                heatmapRadiusSection
                heatmapOpacitySection
            }

            actionsSection
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.callout.weight(.semibold))
                .padding(8)
                .frame(width: 34, height: 34)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
        }
        .accessibilityLabel(t("Map layers"))
    }

    // MARK: - Sections

    @ViewBuilder
    private var mapStyleSection: some View {
        Picker(selection: mapStyleBinding) {
            Label(t("Standard"), systemImage: "map").tag(AppMapStylePreference.standard)
            Label(t("Satellite"), systemImage: "globe.europe.africa.fill").tag(AppMapStylePreference.hybrid)
        } label: {
            Label(t("Map style"), systemImage: "square.stack.3d.up")
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var trackColorSection: some View {
        Picker(selection: $preferences.mapTrackColorMode) {
            Label(t("Activity"), systemImage: "paintpalette").tag(AppMapTrackColorMode.activity)
            Label(t("Speed"), systemImage: "speedometer").tag(AppMapTrackColorMode.speed)
        } label: {
            Label(t("Layer"), systemImage: "scribble.variable")
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var liveOptionsSection: some View {
        Section {
            Toggle(isOn: $preferences.livePulseEnabled) {
                Label(t("Pulsing live dot"), systemImage: "dot.radiowaves.left.and.right")
            }
            Toggle(isOn: $preferences.liveAccuracyCircleEnabled) {
                Label(t("Show accuracy circle"), systemImage: "scope")
            }
            Toggle(isOn: $preferences.liveBreadcrumbFadeEnabled) {
                Label(t("Fade older breadcrumbs"), systemImage: "wand.and.stars")
            }
        } header: {
            Text(t("Live tracking"))
        }
    }

    @ViewBuilder
    private var heatmapPaletteSection: some View {
        Picker(selection: $preferences.heatmapPalette) {
            ForEach(AppHeatmapPalettePreference.allCases) { palette in
                Text(t(palette.labelKey)).tag(palette)
            }
        } label: {
            Label(t("Palette"), systemImage: "paintpalette")
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var heatmapScaleSection: some View {
        Picker(selection: $preferences.heatmapScale) {
            ForEach(AppHeatmapScalePreference.allCases) { scale in
                Text(t(scale.labelKey)).tag(scale)
            }
        } label: {
            Label(t("Scale"), systemImage: "function")
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var heatmapRadiusSection: some View {
        Picker(selection: $preferences.heatmapRadius) {
            ForEach(AppHeatmapRadiusPreset.allCases) { preset in
                Text(t(preset.labelKey)).tag(preset)
            }
        } label: {
            Label(t("Radius"), systemImage: "circle.dashed")
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var heatmapOpacitySection: some View {
        Picker(selection: heatmapOpacityBinding) {
            ForEach(MapLayerMenu.opacityPresets, id: \.self) { value in
                Text("\(Int((value * 100).rounded()))%").tag(value)
            }
        } label: {
            Label(t("Opacity"), systemImage: "circle.lefthalf.filled")
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var actionsSection: some View {
        if configuration.fitToData != nil
            || configuration.centerOnLocation != nil
            || configuration.toggleFullscreen != nil
        {
            Section {
                if let fit = configuration.fitToData {
                    Button {
                        fit()
                    } label: {
                        Label(t("Fit to data"), systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                }
                if let center = configuration.centerOnLocation {
                    Button {
                        center()
                    } label: {
                        Label(t("Center on current location"), systemImage: "location.fill")
                    }
                }
                if let fullscreen = configuration.toggleFullscreen {
                    Button {
                        fullscreen()
                    } label: {
                        Label(
                            configuration.isFullscreenActive ? t("Close fullscreen map") : t("Open fullscreen map"),
                            systemImage: configuration.isFullscreenActive
                                ? "arrow.down.right.and.arrow.up.left"
                                : "arrow.up.left.and.arrow.down.right"
                        )
                    }
                }
            }
        }
    }

    // MARK: - Bindings

    private var mapStyleBinding: Binding<AppMapStylePreference> {
        Binding(
            get: { preferences.preferredMapStyle.isHybrid ? .hybrid : .standard },
            set: { preferences.preferredMapStyle = $0 }
        )
    }

    private var heatmapOpacityBinding: Binding<Double> {
        Binding(
            get: { MapLayerMenu.snapToPreset(preferences.heatmapOpacity) },
            set: { preferences.heatmapOpacity = $0 }
        )
    }

    static let opacityPresets: [Double] = [0.25, 0.50, 0.75, 1.00]

    private static func snapToPreset(_ value: Double) -> Double {
        opacityPresets.min(by: { abs($0 - value) < abs($1 - value) }) ?? 0.75
    }
}
#endif
