//
//  LHMapWorkspace.swift
//  LocationHistoryConsumerAppSupport
//
//  Shared map workspace component (Contract § 5.2, Phase A).
//  See docs/UI_UX_MAP_FIRST_LIQUID_GLASS_CONTRACT_2026-05-28.md § 5.2.
//
//  Phase-A scope:
//    - Renders a single SwiftUI `Map` with the supplied `mapContent`, `style`,
//      and camera binding.
//    - Honors `LHMapPerformancePolicy.cameraUpdateMode` via
//      `.onMapCameraChange(frequency:)`.
//    - Does NOT mutate data, does NOT reset the camera, does NOT gate the map
//      out of the view tree (the `mapInTreeWhenHidden` flag is reserved for a
//      later phase; for now the map is always in tree).
//    - `fitToData` / `adjustZoom` semantics are intentionally NOT handled here;
//      they are wired externally via `AppDayMapCameraController` by the caller.
//
//  iPhone-iOS-26-only. No fallback inside the component — the caller decides
//  whether to instantiate it.
//

#if canImport(SwiftUI) && canImport(MapKit)

import SwiftUI
import MapKit

@available(iOS 26.0, macOS 15.0, *)
public struct LHMapWorkspace<Content: MapContent>: View {

    @Binding private var cameraPosition: MapCameraPosition
    private let style: MapStyle
    private let performancePolicy: LHMapPerformancePolicy
    private let accessibilityIdentifier: String
    private let accessibilityLabelText: String?
    private let mapContent: () -> Content

    public init(
        cameraPosition: Binding<MapCameraPosition>,
        style: MapStyle,
        performancePolicy: LHMapPerformancePolicy,
        accessibilityIdentifier: String = "lhMapWorkspace",
        accessibilityLabel: String? = nil,
        @MapContentBuilder mapContent: @escaping () -> Content
    ) {
        self._cameraPosition = cameraPosition
        self.style = style
        self.performancePolicy = performancePolicy
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabelText = accessibilityLabel
        self.mapContent = mapContent
    }

    public var body: some View {
        Map(position: $cameraPosition) {
            mapContent()
        }
        .mapStyle(style)
        .onMapCameraChange(frequency: performancePolicy.cameraUpdateMode.swiftUIFrequency) { _ in
            // Phase A: no-op. Camera observation is the caller's responsibility
            // via AppDayMapCameraController.
        }
        .accessibilityIdentifier(accessibilityIdentifier)
        .modifier(LHMapWorkspaceAccessibilityLabel(label: accessibilityLabelText))
    }
}

@available(iOS 26.0, macOS 15.0, *)
private struct LHMapWorkspaceAccessibilityLabel: ViewModifier {
    let label: String?
    func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(Text(label))
        } else {
            content
        }
    }
}

@available(iOS 26.0, macOS 15.0, *)
extension LHMapCameraUpdateMode {
    /// Maps the LH camera update mode to the SwiftUI `MapCameraUpdateFrequency`.
    var swiftUIFrequency: MapCameraUpdateFrequency {
        switch self {
        case .onEnd:
            return .onEnd
        case .continuous:
            return .continuous
        }
    }
}

#endif
