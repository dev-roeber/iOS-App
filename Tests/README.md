# LocationHistoryConsumerTests

Maintainer-Notiz fuer das Test-Target `Tests/LocationHistoryConsumerTests/`.
Stand: 2026-05-06.

## Uebersicht

- ~84 Test-Files, > 1000 `func test…` Methoden insgesamt.
- Lokal: `swift test` (CLI) oder `xcodebuild test -scheme LocationHistoryConsumer -destination 'platform=iOS Simulator,name=iPhone 15'`.
- Filter einzelner Suiten: `swift test --filter AppExportQueriesTests`.
- Fixtures liegen unter `Fixtures/contract/` und werden via `TestSupport.contractFixturesDirectory()` gefunden (Pfad-Walk vom Test-Source aus).

## Themen-Karte

- **Decoder / Schema** — `AppExportDecoderErrorTests`, `AppExportGoldenDecodingTests`, `AppExportSchemaVersionTests`, `ContractFixturePresenceTests`.
- **Query-Layer** — `AppExportQueriesTests`, `AppExportQueriesFilterCombinationTests`, `HistoryDateRangeFilterTests`, `PathFilterTests`, `DayListFilterTests`.
- **Day Detail / Presentation** — `DayDetailPresentationTests`, `DayDetailContentHierarchyTests`, `DayDetailViewStateTests`, `DaySummaryDisplayOrderingTests`, `DayMapDataTests`.
- **Overview / Lists** — `OverviewAndDaySummaryPresentationTests`, `OverviewFavoritesAndInsightsTests`, `DayListPresentationTests`, `SavedTracksPresentationTests`, `DayFavoritesStoreTests`.
- **Insights** — `InsightsCardPresentationTests`, `InsightsDrilldownTests`, `InsightsDrilldownBridgeTests`, `InsightsMonthlyTrendPresentationTests`, `InsightsPeriodComparisonPresentationTests`, `InsightsStreakPresentationTests`, `InsightsTopDaysPresentationTests`, `InsightsChartSupportTests`.
- **Map / Rendering** — `MapPresentationTests`, `MapTrackStylingTests`, `MapMatchingTests`, `LHMapHeaderTests`, `AppOverviewTracksMapViewTests`, `AppHeatmapRenderingTests`, `AppHeatmapModelEdgeCaseTests`.
- **Import** — `MultiSourceImportTests`, `GPXImportParserErrorTests`, `GPXRoundTripTests`, `TCXImportParserTests`, `TCXImportParserErrorTests`, `ImportBookmarkStoreTests`, `ImportedPathMutationTests`, `AppImportAndHistoryDateRangeBridgeTests`.
- **Google Timeline Streaming** — `GoogleTimelineStreamReaderTests`, `GoogleTimelineConverterTests`, `ZIPGoogleTimelineStreamingPathTests`, `LargeImportMemorySafetyTests` (OOM-Schutz, grosse Dateien), `GoogleTimelineStreamReaderPerformanceTests` (Baseline).
- **Export-Builders** — `GPXBuilderTests`, `KMLBuilderTests`, `GeoJSONBuilderTests`, `KMZExportTests`, `CSVBuilderTests`, `ExportRouteSanitizerTests`, `GoogleMapsExportHelpTests`.
- **Export-Flow / UI** — `ExportPresentationTests`, `ExportPreviewDataTests`, `ExportSelectionContentTests`, `ExportSelectionRouteTests`, `ExportMutationsAndFilterTests`, `ChartShareHelperTests`.
- **Recording / Recorded Tracks** — `LiveTrackRecorderTests`, `RecordedTrackEditorDraftTests`, `RecordedTrackEditorPresentationTests`, `RecordedTrackStoreTests`, `RecordingIntervalPreferenceTests`.
- **Live Location / Server Upload** — `LiveLocationFeatureModelTests`, `LiveLocationFeatureModelStateTransitionTests`, `LiveLocationServerUploaderTests`, `LiveTrackingPresentationTests`, `LiveStatusResolverTests`, `LiveActivityTests`, `WidgetDataStoreTests`.
- **Demo / Loader** — `DemoDataLoaderTests`, `DemoSessionStateTests`, `AppContentLoaderTests`, `LoadingProgressEngineTests`, `RecentFilesStoreTests`.
- **Layout / Wiring / Utility** — `UIWiringTests`, `LandscapeLayoutTests`, `CompactNavigationSafetyTests`, `AppLanguageSupportTests`, `AppPreferencesTests`, `CoordinateUtilsTests`, `PerformanceTests`.

## `@testable`-Inventar

Fast alle Tests importieren `@testable` — entweder das Core-Modul `LocationHistoryConsumer` (Decoder, Builder, Query-Layer, Streaming-Reader) oder das App-Modul `LocationHistoryConsumerAppSupport` (Presentation, ViewState, Map-Adapter, Live-Feature-Models). Ausgewaehlte Files mit nicht-trivialen internal-Symbolen:

- `AppExportQueriesTests`, `AppExportQueriesFilterCombinationTests` — internal `AppExportQueries`-Funktionen + Filter-Helpers.
- `AppExportDecoderErrorTests`, `AppExportGoldenDecodingTests`, `AppExportSchemaVersionTests` — internal Decoder-Errors / Schema-Versions-Enum.
- `GoogleTimelineStreamReaderTests`, `GoogleTimelineStreamReaderPerformanceTests`, `ZIPGoogleTimelineStreamingPathTests` — `GoogleTimelineStreamReader`, `IncrementalParser`, `convertStreaming(contentsOf:)`, `convert(data:)` sind internal.
- `LargeImportMemorySafetyTests` — internal Streaming-Hooks von `AppContentLoader.streamGoogleTimelineCandidateIfApplicable`.
- `AppHeatmapRenderingTests`, `AppHeatmapModelEdgeCaseTests` — internal Heatmap-Tile-Builder.
- `DayDetailViewStateTests`, `DayDetailPresentationTests` — internal `DayDetailViewState`, Section-Builder.
- `ExportRouteSanitizerTests`, `ExportMutationsAndFilterTests` — internal Mutation/Sanitizer-Helpers.
- `LiveLocationServerUploaderTests` — internal Uploader-Konfiguration und URLProtocol-Hook.
- `UIWiringTests` — internal SwiftUI-Wiring (`StartOverviewRedesignTests` Sub-Suite).
- `DemoDataLoaderTests` — `@testable import LocationHistoryConsumerDemoSupport` (Demo-Modul, internal Demo-Bundle-Lookup).

Die Live-Tests `LiveLocationFeatureModelTests`, `LiveLocationFeatureModelStateTransitionTests`, `LiveTrackingPresentationTests`, `LiveActivityTests`, `LiveStatusResolverTests`, `LiveTrackRecorderTests` nutzen **kein** `@testable` — sie testen ueber das oeffentliche AppSupport-API.

## Test-Helper / Mocks

- `TestSupport.swift` — einziger gemeinsamer Helper. Stellt `contractFixturesDirectory()`, `contractFixtureURL(named:)` und `contractFixtureURLs(prefix:suffix:)` bereit (Pfad-Walk zu `Fixtures/contract`).
- `StateTransitionMockLiveLocationClient` (in `LiveLocationFeatureModelStateTransitionTests.swift`) — file-private Mock, der `LiveLocationClient` mit konfigurierbarem Authorization-State implementiert.
- `MockURLProtocolRegistry` / `MockURLProtocol` (in `LiveLocationServerUploaderTests.swift`) — registriert Request-Handler fuer `URLSession`-Stubs in Server-Upload-Tests.
- Es gibt aktuell **keinen** modul-weiten `MockLiveLocationClient`. Die Mocks sind pro Test-File `private final class` und nicht geteilt.

## Performance-Tests

`GoogleTimelineStreamReaderPerformanceTests` ist als Baseline-only deklariert:

- Verwendet `XCTest.measure { … }` (10 Runs, Mittel + Stabw.).
- **Kein Fail-Bar** — absolute Zeiten variieren zwischen Hosts/Sim-Configs zu stark.
- Drei Pfade abgedeckt: `convertStreaming(contentsOf:)` (Disk), `convert(data:)` (In-Memory) und `IncrementalParser` mit 1 KB-Chunks (ZIP-Streaming-Hot-Path).
- Lokale Anlaeufe: `swift test --filter GoogleTimelineStreamReaderPerformanceTests` — Median ablesen, mit vorigem Baseline vergleichen.
- Regressionen werden in CI **nur** durch visuelle Inspektion erkannt.

## Bekannte Coverage-Luecken

- **Mock-Client-Refactor pending** — `MockLiveLocationClient` ist nicht geteilt. Wenn weitere Live-Suiten dazukommen, sollte ein gemeinsamer Helper in `TestSupport`/eigenes File extrahiert werden.
- **Hardware-Verifikation** — Live-Tracking, Background-Updates, Live-Activity-Lifecycle und Standort-Authorisation sind nur logisch/State-getestet. Echte Geraete-Verifikation (UDID-Devices) wird ausserhalb des Test-Targets gefahren (siehe Hauptsession-Notes).
- **Privacy / TCC-Flows** — keine automatisierten Tests fuer Permission-Dialoge oder Privacy-Manifeste.
- **UI-Snapshots** — Presentation-Tests verifizieren View-State, **keine** Pixel-Snapshots / Accessibility-Tree-Diff.
- **Performance-Regressions-Bar** — bewusst ausgelassen (siehe oben).
- **Fixture-Drift** — `ContractFixturePresenceTests` prueft Existenz, aber kein Schema-Drift-Detector ueber Versions hinweg.
