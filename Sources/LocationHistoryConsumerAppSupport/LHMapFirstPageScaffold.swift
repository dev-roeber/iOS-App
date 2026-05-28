//
//  LHMapFirstPageScaffold.swift
//  LocationHistoryConsumerAppSupport
//
//  Shared map-first page scaffold (Contract § 5.1).
//  See docs/UI_UX_MAP_FIRST_LIQUID_GLASS_CONTRACT_2026-05-28.md § 5.1.
//
//  Map-First Hardening (Anchor-Fix):
//    - Das Sheet wird NICHT mehr per `.safeAreaInset(edge: .bottom)` angeheftet
//      (das ließ es je nach Detent/NavigationTitle mittig "schweben", mit Karte
//      ober- UND unterhalb). Stattdessen liegt es in einem
//      `ZStack(alignment: .bottom)` und ist damit deterministisch am unteren
//      Bildschirmrand verankert — flush, ohne Map-Streifen darunter.
//    - Die volle (safe-area-ignorierende) Bildschirmhöhe wird per GeometryReader
//      gemessen und über `lhSheetAvailableHeight` an das Sheet gereicht, damit
//      die `.full`-Raste echtes Vollbild rechnen kann.
//    - z-Order folgt strikt `LHMapBase.LayerOrder`: Karte (0) < Sheet (200)
//      < FloatingChrome (300). Die iOS-26-TabBar (TabView-Chrome) liegt als
//      eigenes System-Overlay weiterhin über allem (LayerOrder.tabBar = 400).
//
//  iPhone-iOS-26-only. Kein Fallback in der Komponente — der Aufrufer entscheidet.
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
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                // Karte: vollbild, unterste Ebene.
                mapBuilder()
                    .ignoresSafeArea()
                    .zIndex(LHMapBase.LayerOrder.map)

                // Floating-Chrome (Layer-Pille, Zoom/Locate-Stack): oben verankert.
                // Top-Inset managen die Aufrufer selbst über ihre Control-Paddings.
                floatingChromeBuilder()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .zIndex(LHMapBase.LayerOrder.floatingChrome)

                // Sheet: hart am unteren Bildschirmrand. Die volle Höhe geben wir
                // per Environment weiter, damit die `.full`-Raste Vollbild kann.
                sheetBuilder()
                    .environment(\.lhSheetAvailableHeight, proxy.size.height)
                    .frame(maxWidth: .infinity, alignment: .bottom)
                    .zIndex(LHMapBase.LayerOrder.bottomSheet)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .ignoresSafeArea()
    }
}

#endif
