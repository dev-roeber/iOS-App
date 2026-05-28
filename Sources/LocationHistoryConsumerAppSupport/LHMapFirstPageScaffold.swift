//
//  LHMapFirstPageScaffold.swift
//  LocationHistoryConsumerAppSupport
//
//  Shared map-first page scaffold (Contract § 5.1, Phase A).
//  See docs/UI_UX_MAP_FIRST_LIQUID_GLASS_CONTRACT_2026-05-28.md § 5.1.
//
//  Phase-A scope:
//    - Provides the canonical map-first layout: full-bleed map, floating chrome
//      anchored to the top, and a bottom sheet attached via
//      `.safeAreaInset(edge: .bottom)`.
//    - Makes NO assumptions about sheet detents or sheet styling — the caller
//      passes whatever sheet view they want (e.g. `LHGlassBottomSheetDashboard`
//      or a plain container).
//    - Does NOT gate the map out of the view tree and does NOT own a camera
//      controller. Camera/data plumbing belongs to `LHMapWorkspace` and the
//      caller's `AppDayMapCameraController`.
//
//  iPhone-iOS-26-only. No fallback inside the component — the caller decides
//  whether to instantiate it.
//

#if canImport(SwiftUI) && canImport(MapKit)

import SwiftUI

@available(iOS 26.0, macOS 15.0, *)
public struct LHMapFirstPageScaffold<MapContent: View, FloatingContent: View, SheetContent: View>: View {

    private let topSafeInset: CGFloat
    private let bottomSafeInset: CGFloat
    private let sheetBottomClearance: CGFloat
    private let mapBuilder: () -> MapContent
    private let floatingChromeBuilder: () -> FloatingContent
    private let sheetBuilder: () -> SheetContent

    public init(
        topSafeInset: CGFloat,
        bottomSafeInset: CGFloat,
        sheetBottomClearance: CGFloat? = nil,
        @ViewBuilder map: @escaping () -> MapContent,
        @ViewBuilder floatingChrome: @escaping () -> FloatingContent,
        @ViewBuilder sheet: @escaping () -> SheetContent
    ) {
        self.topSafeInset = topSafeInset
        self.bottomSafeInset = bottomSafeInset
        self.sheetBottomClearance = sheetBottomClearance
            ?? LHMapBase.bottomSheetTabBarClearance(deviceBottomSafeInset: bottomSafeInset)
        self.mapBuilder = map
        self.floatingChromeBuilder = floatingChrome
        self.sheetBuilder = sheet
    }

    public var body: some View {
        ZStack(alignment: .top) {
            mapBuilder()
                .ignoresSafeArea()
            floatingChromeBuilder()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sheetBuilder()
        }
    }
}

#endif
