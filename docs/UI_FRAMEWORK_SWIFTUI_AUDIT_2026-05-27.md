# UI Framework / SwiftUI Audit — 2026-05-27

## Executive Summary

Dieser Audit wurde im aktuellen Repo `/home/sebastian/Repos/iOS_App` auf Branch `audit/swiftui-ui-framework-complete` neu ausgeführt. Frühere SwiftUI-/UI-Framework-Findings wurden nicht als verifiziert übernommen.

Befund: Die App ist primär SwiftUI. UIKit ist eng begrenzt und derzeit technisch begründet: Device/UIApplication-Hooks, Clipboard, Security-Scoped/FileCoordinator-Staging, UIImage-Rendering aus `ImageRenderer` und ein isolierter `UIViewControllerRepresentable` für Tab-Re-Selection. Es gibt keine aktive `UIViewRepresentable`-Bridge und keinen produktiven UIKit-`MKMapView`-Renderer.

Low-Risk-Fix in diesem Pass: Der gemeinsame Meldungsbanner im Dateien-Tab kann lokale `AppFilesViewModel`-Meldungen jetzt wirklich verwerfen. Vorher löschte der X-Button nur iCloud-Meldungen.

## UI-Framework-Stack

| Ebene | Befund | Bewertung |
|---|---|---|
| App UI | SwiftUI in `Sources/LocationHistoryConsumerAppSupport`, `Sources/LocationHistoryConsumerApp`, `wrapper/LH2GPXWrapper` | Primärframework |
| Navigation | `NavigationStack`, `NavigationSplitView`, `TabView`, Sheets, Alerts, ConfirmationDialogs | SwiftUI-native, iPad-Pfad separat zu prüfen |
| Karten | SwiftUI `Map(position:)` + MapKit `MapPolyline`/`Annotation`/`Marker` | Modern iOS-17-Pfad |
| Heavy Map UIKit | kein aktiver `MKMapView`-Renderer | Roadmap/Performance-Spike, nicht aktuelle Wahrheit |
| Charts | Swift Charts in Insights/Speed/Elevation | SwiftUI-native |
| Dateien | SwiftUI `fileImporter`/`fileExporter`, `FileDocument`, Cloud-file staging | System-native; UIKit/FileCoordinator nur für Provider-Staging |
| Share | SwiftUI `ShareLink` für gerenderte Charts | SwiftUI-native |
| Designsystem | LH legacy + LHX components + LG Liquid Glass helpers | Funktional, aber parallelisiert |

## View-Inventar

| Bereich | Relevante Views |
|---|---|
| App shell / wrapper | AppShellRootView, ContentView, LocationHistoryConsumerApp, LH2GPXWrapperApp |
| Main navigation | AppContentSplitView, LGTabContainerView, NavigationStack tabs, NavigationSplitView regular layout |
| Home/import | AppShellEmptyStateView, RecentFilesView, GoogleMapsExportHelp* |
| Files | AppFilesView, local/cloud/pending bucket cards |
| Days/timeline | AppDayListView, AppDayRow, AppDayFilterChipsView, AppDayDetailView, AppDayMapView, LocalTimelineDayListView, LocalTimelineDayDetailView, LocalTimelineDayMapView |
| Maps/live | AppOverviewTracksMapView, AppOverviewExploreSheet, LHHeroMapWorkspace, AppLiveTrackingView, AppLiveLocationSection, AppRecordedTrackEditorView, AppExportPreviewMapView, AppHeatmapView |
| Insights/charts | AppInsightsContentView, InsightsStreakCardView, AppSpeedBandView, AppElevationProfileView, Insights* chip/card row views |
| Export | AppExportView, AppExportMultiLayerHero, LHExportStepIndicator, LHExportBottomBar, ProductInfoCard |
| Settings/options | AppOptionsView and subpages, AppICloudOptionsView, AppHistoryDateRangeControl, HistoryDateRangePickerSheet |
| Live/widgets | LGRecordButton, LHLiveBottomBar, LHLiveTrackRow, AppRecordedTracksLibraryView, TrackingLockScreenView, LH2GPX*WidgetView |
| Design system | LH2GPXTheme, LHCard, LHSectionHeader, LHStatusChip, LHMetricCard, LHFilterChip, LHStatusBadge, LHX* components, LG* glass helpers |

## UIKit-Abhängigkeiten

| Abhängigkeit | Nachweis | Status | Bewertung |
|---|---|---|---|
| SwiftUI | 84 Swift files import SwiftUI; 64 productive View declarations found | necessary | Primary app UI framework. |
| UIKit | 6 files import UIKit | necessary/prüfen | Necessary for UIDevice/UIApplication memory notifications, UIPasteboard, UIImage PNG rendering, NSFileCoordinator/security-scoped staging and TabView reselection bridge. |
| UIViewControllerRepresentable | IOSTabReselectionObserver | necessary | SwiftUI has no native tab reselection callback; bridge is isolated. |
| UIViewRepresentable | 0 hits | not present | No custom UIView bridge found. |
| MapKit for SwiftUI | 13 Map(...) surfaces; 15 MapKit imports | necessary | Current map renderer stack. |
| UIKit MKMapView | No active MKMapView renderer; references only comments/provider docs | ersetzbar/roadmap | Heavy Overview/Heatmap MKMapView migration remains a measured future spike, not current code. |
| Charts | 3 files import Charts: AppInsightsContentView, AppSpeedBandView, AppElevationProfileView | necessary | Charts/insights surfaces. |
| File importer/exporter | fileImporter in app shell/wrapper/demo/files; fileExporter in AppExportView; documents in GPXDocument/CSVDocument | necessary | System-native picker/export paths. |
| Share | ShareLink in AppInsightsContentView | necessary | SwiftUI-native sharing for rendered chart PNG. |
| WeatherKit | AppWeatherKitService only | necessary | Current-weather live pill path; Day/Overview/Export weather layer remains prepared tint only. |

## Navigation / Presentation Inventory

| Pattern | Aktuelle Verwendung |
|---|---|
| `NavigationStack` | App shell, wrapper, compact tabs, files, insights, overview explore, date-range sheets, local timeline sheets |
| `NavigationSplitView` | `AppContentSplitView` regular-width/iPad path |
| `TabView` | `AppContentSplitView` compact fallback and `LGTabContainerView` iOS-26 Liquid Glass path |
| `.sheet` | Options, export regular, heatmap/explore/help, insights share, date-range picker, local timeline detail |
| `.popover` | Keine Treffer |
| `.toolbar` | App shell/wrapper/actions, tab screens, modal navigation bars |
| `.alert` | Files delete, export failure, day detail, insights share failure |
| `confirmationDialog` | Recorded-track editor, insights drilldowns, iCloud delete |

## MapKit / Charts / File Paths

| Bereich | Status |
|---|---|
| MapKit for SwiftUI | Active in DayMap, DayDetail, Overview, Live, Heatmap, Export Preview, Recorded Track Editor |
| UIKit MapKit | No active renderer; only documentation/comments/provider references to future MKMapView work |
| Charts/Insights | Swift Charts marks in `AppInsightsContentView`, `AppSpeedBandView`, `AppElevationProfileView`; no UIKit charting |
| FileImporter | App shell/wrapper/demo + Files-tab parent presentation; nested importer intentionally avoided in `AppFilesView` |
| FileExporter | Single exporter in `AppExportView`; `GPXDocument`/`CSVDocument` support documents |
| ShareSheet | `ShareLink` in Insights; no custom `UIActivityViewController` bridge |

## Designsystem-Abweichungen

| Bereich | Befund | Risiko | Nächste Maßnahme |
|---|---|---|---|
| Force dark | wrapper ContentView and AppShellRootView/LGTabContainerView call preferredColorScheme(.dark); several components assume dark/glass backgrounds | risk | Light Mode not ready; do not claim full adaptive color support. |
| Mixed design systems | LH* legacy cards/chips coexist with LHX* and LG Liquid Glass helpers | prüfen | Low-risk adoption should continue screen-by-screen; avoid full redesign. |
| Files tab empty states | Plain Text empty rows inside LHCard | prüfen | Could move to LHXEmptyState later; not changed in this pass to avoid visual churn. |
| iCloud options | Uses custom LGICloudSection/LHLiquidGlassSurface rather than LHX cards everywhere | prüfen | Intentional Liquid Glass pass, but increases parallel styling. |
| Regular width | NavigationSplitView remains AppContentSplitView path; iPad target is enabled in pbxproj but iPad device/sim smoke not rerun here | risk | Code path exists; verification remains open. |
| Store timeline map | LocalTimelineDayMapView is SwiftUI placeholder with bounded data; no MapKit renderer | risk | Feature-flagged/default off; real renderer remains Apple-host task. |

## UI-State Coverage

| State | Befund |
|---|---|
| loading | Present for import/progress and some cloud refreshes; inconsistent visual treatment between wrapper and package shell. |
| empty | Present across home/days/export/insights/files, but some files/cloud cards use inline text. |
| error | Present via alerts/banners for import/export/files/cloud; LHXErrorState underused. |
| permission denied | Partly covered by importer/cloud/file staging errors; not every surface has dedicated recovery copy. |
| no iCloud | iCloud settings and files cloud actions gate disabled/unavailable states. |
| no file | Import-first state and Files empty buckets present. |
| no exportable data | Export empty/disabled reasons present. |
| import failed | Import error message path present; recent-file stale handling present. |
| sync failed | CloudKit health, cloud-file, backup states present; external CloudKit validation still required. |

## Bewertung

1. Primäres UI-Framework: SwiftUI.
2. Sauberer SwiftUI-Einsatz: Navigation, Maps, Charts, fileImporter/fileExporter, ShareLink, reusable View-Komponenten.
3. Technisch notwendiges UIKit: Tab reselection observer, device idiom/memory notifications, pasteboard copy, ImageRenderer PNG extraction, security-scoped upload staging.
4. Unnötig/ersetzbar: kein harter unnötiger UIKit-Renderer gefunden; einzelne UIKit-Imports sind zu isolierten APIs gebunden.
5. Designsystem-Umgehungen: Files empty rows, Teile von settings/options, legacy LH* and newer LHX/LG coexist.
6. Alter/Dark-Stil: Force-Dark bleibt reale Code-Wahrheit; Light Mode/Liquid-Glass-adaptive Vollprüfung offen.
7. iPad/regular-width: `TARGETED_DEVICE_FAMILY = 1,2` ist im aktuellen pbxproj gesetzt, aber iPad-Sim/Device-Smoke wurde in diesem Pass nicht ausgeführt.
8. iOS-26/Liquid-Glass-ready: `LGTabContainerView`, `LGRecordButton`, `LGLayerToggleBar`, `LHLiquidGlass*` helpers, iCloud page glass shell.
9. Fallback/uneinheitliche Effekte: iOS 17-25 and iPad use `AppContentSplitView` fallback; styles are mixed but functional.
10. Missing/weak states: permission-denied copy, Light Mode, iPad verification, and LocalTimeline store-map renderer remain open.

## Implementierte Low-Risk-Fixes

| Datei | Änderung | Risiko |
|---|---|---|
| `AppFileManagementViewModel.swift` | `clearActionMessage()` ergänzt, setzt Message und Fehlerflag zurück | Niedrig |
| `AppFilesView.swift` | Banner-X löscht jetzt iCloud- oder lokale Meldung abhängig von der sichtbaren Quelle | Niedrig |
| `AppFileManagementTests.swift` | Regressionstest für lokalen Banner-Reset | Niedrig |

## Priorisierte Modernisierungsphasen

1. Designsystem-Adoption ohne Redesign: Files empty states and options/status cards schrittweise auf LHX/LG vereinheitlichen.
2. iPad/regular-width verification: iPad simulator/device build plus smoke through SplitView, export sheet, files tab and maps.
3. Light/adaptive color audit: force-dark usages abbauen oder bewusst als Produktentscheidung dokumentieren.
4. Map performance spike: only after hardware baseline; compare SwiftUI Map vs MKMapView for Overview/Heatmap heavy datasets.
5. UI-state polish: permission/no-iCloud/import failed/sync failed copy and LHXErrorState/LHXLoadingState adoption.

## Risiken

- Apple/Xcode-specific UI paths were not fully verifiable on this Linux host.
- iPad target is enabled in the project file, but no iPad build/smoke was run in this pass before this document was first written.
- WeatherKit, CloudKit, TestFlight and signed entitlement checks remain external unless Xcode/Developer Portal access is available.
- `swift build`/`swift test` results are recorded after execution below; do not infer pass before those commands run.

## Testresultate

Nicht ausgeführt. Die Test-/Build-Phase wurde nach Start von `swift build` vom User abgebrochen und danach ausdrücklich mit „tests überspringen“ übersprungen. Es wird kein `swift build`-, `swift test`-, UI-Test- oder Xcode-Erfolg behauptet.

## Konkrete nächste Aufgaben

- Nach User-Freigabe: `swift build`, `swift test` und fokussiert `swift test --filter AppFileManagementTests` ausführen.
- Auf macOS/Xcode-Host: Wrapper-Simulator-Build und relevante UI-Smoke-Tests ausführen.
- Follow-up: iPad regular-width visual smoke and Light Mode decision.
