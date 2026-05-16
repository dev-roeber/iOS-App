# MapKit & App-Performance Audit — 2026-05-16

> **Update 2026-05-16 (Train G1 — kein Migrationsbedarf):** Verifikation per `rg` repo-weit: **0 Treffer** für `coordinateRegion:`, `annotationItems:`, `MapMarker`, `MapAnnotation(`. Alle 8 SwiftUI-`Map(...)`-Surfaces nutzen bereits `Map(position: $mapPosition) { MapContent }` mit `MapCameraPosition` + `Marker`/`Annotation`/`MapPolyline`. Die in diesem Audit als „deprecated lebt weiter" geführten Stellen existieren tatsächlich nicht (mehr) — Migration war in früherer Phase erfolgt. G1 ist damit eine reine Doku-Korrektur, keine Code-Änderung. **Weiterhin offen** (Mac/Instruments-only, nicht G1-Scope): MKMapView/MKMultiPolyline-Bridge für sehr große Overview-Datasets und MKTileOverlay-Heatmap. Live-Polyline-Cap-UI + Camera-Throttle bleiben Train C.
>
> **Folge-Audit 2026-05-16 (gleicher Tag, nach Trains A + B1):** `docs/APP_PERFORMANCE_MODERNIZATION_AUDIT_2026-05-16.md` ergänzt diesen Report um eine repo-weite Tiefenanalyse (SwiftUI/MapKit/Heatmap/Live/Import-Export/Persistenz/Widgets/Tests, 20 Hotspots, Linux-vs-Mac-Trennung) plus eine formale **iOS-17-Deployment-Target-Entscheidungsmatrix** (Empfehlung: vorbereiten, nicht in diesem Train anheben).


**Branch:** `main`
**HEAD:** `99c1549` (vor Audit-Commit), Audit-Commit folgt
**Version:** `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171`
**Tests:** Linux `swift test` (Swift 6.3.2, libsqlite3-dev): **1435 / 2 Skips / 0 Failures, 41,1 s**

## Scope

Repo-wahrer, **planerischer** Audit aller MapKit-Oberflächen und app-weiter Performance-Hotspots. **Keine Code-Änderung** in diesem Commit. Ziel: belastbares Inventar, Hotspot-Ranking und ein sicherer Umsetzungsplan in kleinen Trains.

Was dieser Report **nicht** ist:
- Keine Performance-Behauptung („schneller", „langsamer") ohne Messung — vorhandene Throughput-Aussagen werden mit Quelle markiert, neue Hypothesen mit „**unmeasured**".
- Keine Modernisierungs-Versprechung — alle Optionen sind availability-gated (iOS 17/18+) und stehen weiterhin unter Mac/Xcode-Verifikationsvorbehalt.
- Keine Deployment-Target-Anhebung. App-Minimum bleibt iOS 16.0 (Widget 16.2).

## Geprüfte Bereiche

**Vollständig durchgelesen:**
- Audit-Docs: `docs/MAP_ARCHITECTURE_AUDIT.md`, `docs/MAPKIT_AZ_AUDIT_2026-05-13.md`, `docs/PERFORMANCE_DEEP_AUDIT_2026-05-12.md`, `docs/DEEP_AUDIT_2026-05-12_LOCAL_TIMELINE_STORE_AND_MAP.md`, `docs/DEEP_AUDIT_2026-05-09_PERFORMANCE_STABILITY_MAP_LAYERS.md`, `docs/DEEP_AUDIT_2026-05-13_CLAUDE.md`, `docs/APP_FEATURE_INVENTORY.md`.
- Root-Doku: `README.md`, `ROADMAP.md`, `NEXT_STEPS.md`, `CHANGELOG.md` (Top), `AGENTS.md`.
- Wrapper: `wrapper/README.md`, `wrapper/docs/TESTFLIGHT_RUNBOOK.md`.

**Stichprobenartig + gezielt** (Code, file:line in Befundtabellen):
- Sources/LocationHistoryConsumerAppSupport: Map-Views, Heatmap, Live, Insights, Day Detail, Export Preview, LocalTimelineDayMap.
- Sources/LocationHistoryConsumer: Builder (GPX/KML/CSV/GeoJSON/KMZ), Queries (PathDistance, PathFilter, DouglasPeucker, AppExportQueries), Streaming-Reader.
- Tests/LocationHistoryConsumerTests: Performance-/Benchmark-/Golden-Test-Inventar.

**Nicht prüfbar** (Linux-Host, kein Xcode/SDK):
- `xcodebuild` für Sim/Device, Instruments-Profiling, Memory Graph, MainActor-Hangs auf echtem Gerät, ARKit/MapKit-Render-Frame-Time, Hardware-Sichtprüfung.
- Apple-only Tests: `#if canImport(SwiftUI && MapKit)`/`#if !os(Linux)` — ca. **17+ Test-Cases werden auf Linux übersprungen** (Heatmap-Rendering, AppDayMapRenderData, PathDistanceCalculatorPerformance, etc.).

## Map-Oberflächen-Inventar

Sechs aktive Map-Surfaces im Codebestand.

| # | Surface | Datei (Haupt) | Tech | Datenquelle | Volumen-Schutz heute | State | Tests |
|---|---|---|---|---|---|---|---|
| 1 | **Overview Tracks** | `Sources/LocationHistoryConsumerAppSupport/AppOverviewTracksMapView.swift` | SwiftUI `Map` iOS 17+, `MapPolyline` (halo+core) | `AppExport.data.days` via `OverviewMapPreparation.scanCandidates` | `pointBudget≈2M`, `overlayLimit` 150–300 (Tier), `candidateStorageCap=512`, ε-DP 30–140 m, `onMapCameraChange(.onEnd)` | `@Observable @MainActor AppOverviewMapModel` + `@State mapPosition` | `AppOverviewTracksMapViewTests`, `OverviewMapRenderDataTests` |
| 2 | **Day Detail** | `Sources/LocationHistoryConsumerAppSupport/AppDayMapView.swift` | SwiftUI `Map` iOS 17+, `MapPolyline`+`Marker` | `DayMapData` → `DayMapRenderData` (points-only, flat-aware) | DP+outlier-Präkomputation im Init, `speedSegments` gecached | `@State renderData` (Init-synchron) + `@State mapPosition` | `AppDayMapRenderDataTests` |
| 3 | **Heatmap Tab** | `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift` + `AppHeatmapModel.swift` | SwiftUI `Map` iOS 17+, `MapPolygon` (Hex-Cell + `RadialGradient`) | `WeightedPoint`s aus AppExport (visits 3×, paths/activities 1×) über `AppHeatmapPathSampler` | `densityPointCap=500k` (Truncation-Flag), LOD-Macros 36/72/280/1200, `viewportCache` mit `HeatmapViewportKey`, `.onEnd`-Frequency, `Task.detached` für Precompute | `@Observable @MainActor AppHeatmapModel` | `HeatmapGoldenOutputTests`, `AppHeatmapModelEdgeCaseTests`, `AppHeatmapRenderingTests`, `AppHeatmapModelGeometryTests` |
| 4 | **Live Tracking** | `Sources/LocationHistoryConsumerAppSupport/AppLiveTrackingView.swift` | SwiftUI `Map` iOS 17+, `MapPolyline`+`MapCircle`+`Annotation` | `LiveLocationFeatureModel.liveTrackPoints` (eager mapped) | `MapCoordinateGuard.sanitize` pro Polyline. **Kein Hard-Cap** auf `polylineCoordinates` | `@MainActor` Modell, `@State polylineCoordinates`/`trackSamples` | keine dedizierte Test-Suite — `LiveLocationFeatureModelTests` deckt Logik |
| 5 | **Export Preview** | `Sources/LocationHistoryConsumerAppSupport/AppExportPreviewMapView.swift` + `ExportPreviewDataBuilder.swift` | SwiftUI `Map` iOS 17+, `MapPolyline`+`Marker` | `ExportPreviewData` (points-only, eager Init) | `MapCoordinateGuard`/`CoordinateValidity` im Build, **kein Viewport-Culling, kein Hard-Cap** | `@State renderData` + `@State mapPosition` | `ExportPreviewDataTests`, `ExportPreviewSanitizeTests` |
| 6 | **LocalTimeline Day Map** | `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayMapView.swift` | **Foundation-only Placeholder** (kein MapKit-Import) | LocalTimelineStore-Routen-Metadaten (lazy, `coord_blob` nicht dekodiert) | Budget `maxVisibleRoutes=12` / `maxPointsPerRoute=64` / `maxTotalPoints=800` (`LocalTimelineMapPerformanceBudget`) | `ViewState` Property | `LocalTimelineDayMapViewStateTests`, `LocalTimelineMapPerformanceBudgetTests` |

### Quer-Befunde Map-Stack

- **MainActor-Isolation:** Overview-, Heatmap-, Live-Modelle sind `@MainActor`; alle schweren Builds laufen via `Task.detached(.userInitiated)` und schreiben mit `MainActor.run` zurück.
- **Camera-Frequency:** Overview + Heatmap nutzen `.onEnd`. Day Detail + Export Preview reagieren auf `onChange(data)`, nicht auf Kamera. Live Tracking folgt direkt — **kein Frequency-Cap dokumentiert** (Befund H-7).
- **Identity:** Overview verwendet `ForEach(Array(... .enumerated()), id: \.offset)` (file: `AppOverviewTracksMapView.swift` L202, L409). Day Detail nutzt stabile `Identifiable` IDs (L99, L125). Risiko in Overview niedrig (deterministische Sortierung + `.onEnd`-Trigger), aber strukturell unsauber.

## Hotspot-Ranking

Vier Stufen, sortiert nach Nutzen/Risiko/Linux-Verifizierbarkeit. **Schweregrad-Schätzungen sind unmeasured** und stammen aus Code-Analyse.

### P0 — sicherer hoher Nutzen, kleines Risiko (Linux-CI-tauglich)

| ID | Befund | Datei | Vorgeschlagener Train | Tests | Linux |
|---|---|---|---|---|---|
| **P0-1** | **Live-Track Polyline ohne Hard-Cap.** `polylineCoordinates` (`AppLiveTrackingView.swift`) wächst während Recording unbegrenzt. Bei mehrstündigen Sessions potentiell mehrere zehntausend Punkte im `@State`. | `AppLiveTrackingView.swift` (State L24–25) | Hard-Cap + Tail-Decimation (z.B. letzte 5k Punkte voll, davor Douglas-Peucker mit ε~5 m). **Default OFF hinter Feature-Flag**, damit Verhalten unverändert bleibt; Test deckt Cap-Logik in Foundation-Modell ab. | neuer `LiveTrackDecimationTests` (Foundation-only) | **Ja** (Logik) |
| **P0-2** | **DouglasPeucker, PathFilter, AppExportQueries.findDay** haben keine XCTMeasure-Baseline auf Linux. Hot path für viele Map-Surfaces. | `Sources/LocationHistoryConsumer/Queries/DouglasPeucker.swift`, `PathFilter.swift`, `AppExportQueries.swift` | Performance-Tests mit synthetischen Eingaben (10k / 50k) ergänzen, **ohne Fail-Bar** (Baseline-only, wie bestehende `MapSanitizeBenchmarkTests`). | neue `DouglasPeuckerPerformanceTests`, `PathFilterPerformanceTests` | **Ja** |
| **P0-3** | **Export-Builder ohne Throughput-Baseline.** `GPXBuilder`, `KMLBuilder`, `CSVBuilder`, `GeoJSONBuilder`. Linear String-Append (kein O(N²)-Antipattern erkannt), aber Builder-Throughput nicht gemessen. | `Sources/LocationHistoryConsumer/{GPX,KML,CSV,GeoJSON}Builder.swift` | XCTMeasure auf medium Fixture (1k–5k Coords) zur Drift-Erkennung. | neue `ExportBuilderPerformanceTests` | **Ja** |
| **P0-4** | **`ForEach(Array(...).enumerated()), id: \.offset)`** an mind. 13 Stellen. Strukturell unsauber (Index-Identität, neue Array-Allokation pro Render). | u. a. `AppOverviewTracksMapView.swift` L202/L409, `AppRecordedTrackEditorView.swift` L202, `AppLiveTrackingView.swift` L562, `AppInsightsContentView.swift` L940/958/984/1200 | Schrittweise Migration zu stabilen `Identifiable` IDs (existieren bereits in `PathOverlay`/`VisitAnnotation` — `id: Int`). Pro View ein PR, jede Änderung von Golden- oder Render-Tests gedeckt. | bestehende Render-Tests + ggf. neue Identity-Smoke-Tests | **Ja** |
| **P0-5** | **AppInsightsContentView 5× `.onChange` → `refreshDerivedModel`.** Jeder Onchange-Trigger rebuildet die gleichen Aggregationen, statt Dependency-granular. | `AppInsightsContentView.swift` L239–243, L465–469, L551–605 | Einmal `.task(id: combinedDependency)` statt 5 separater `.onChange`. Output muss byte-identisch zu vorher sein. | erweiterter `AppInsightsContentViewModelTests` | **Ja** (Logik via @Observable Modell, View-Body schwerer zu testen) |

### P1 — hoher Nutzen, mittleres Risiko

| ID | Befund | Datei | Vorgeschlagener Train | Tests |
|---|---|---|---|---|
| **P1-6** | **Heatmap `computeMultiLODGrids` fused Single-Pass-API existiert (`AppHeatmapModel`), wird aber bewusst nicht produktiv genutzt** — Train 3 Audit-Befund: kein messbarer Wallclock-Gewinn bei 10k/50k auf Mac. Auf iOS-Hardware ungemessen. | `HeatmapGridBuilder.swift` (`computeMultiLODGrids`), `AppHeatmapModel.swift` | Mac-/Device-Benchmark auf realistischer Datenmenge (echte Heatmap-Sessions 100k+). Erst wenn dort Gewinn, dann Wiring. | bestehende `HeatmapPipelineBenchmarkTests` (Mac-only) erweitern | nein (Mac/Device) |
| **P1-7** | **Live Tracking — Camera-Update-Frequenz ungated.** Folge-Kamera reagiert auf jeden eingehenden Track-Point. | `AppLiveTrackingView.swift` (onChange liveTrackSignature) | Throttle (z.B. 0,5–1 s) für Camera-Updates im Follow-Mode. Hinter Feature-Flag default OFF. | Foundation-Modell-Test für Throttle-Logik | **Ja** (Logik) |
| **P1-8** | **Day-Detail `DayMapRenderData.init` skaliert linear mit Pfad-Anzahl.** DP+SpeedSegment-Präkomputation im Init; bei pathologischen Google-Timeline-Exports (50+ Paths/Day) potenziell spürbar. | `AppDayMapView.swift` L201–236 | Lazy/Chunked Init oder Background-Hop. Erst messen (Mac), dann entscheiden. | `AppDayMapRenderDataTests` ist MapKit-gated — Linux-Smoke nur teilweise möglich | teilweise |

### P2 — größere Refactorings (mit Vorbehalt)

| ID | Befund | Datei | Skizze | Hinweis |
|---|---|---|---|---|
| **P2-9** | **MKMapView + MKMultiPolyline Bridging.** Single render-pass statt Loop. Aus Audit 2026-05-13 als „separater Perf-Vergleich" Phase 2. | Overview, Day Detail | UIViewRepresentable-Wrapper; pflichtweise Side-by-Side-Benchmark vs SwiftUI `Map`. Apple selbst empfiehlt SwiftUI `Map` für iOS 17+; nur fortsetzen, wenn Messung Vorteil zeigt. | **Mac/Device-Pflicht** |
| **P2-10** | **MKTileOverlay-Heatmap.** Vorgeneriertes Tile-Set statt MapPolygon-Loop über 36–1200 Zellen. | Heatmap | Tile-Cache-Codec (`derived_cache` aus Phase 8B vorhanden), Invalidierung bei `updateScale`. | Mac/Device |
| **P2-11** | **OverviewMapPreparation.scanCandidates Streaming-Refactor.** Aus mehreren Audits als HIGH-RISK markiert; Score+Bounds heute über `path.flatCoordinates` voll. | `OverviewMapPreparation.swift` | Lazy/Chunked Streaming; bricht aktuelle Score-Test-Invarianten. | testaufwendig |
| **P2-12** | **TaskGroup-Parallelism für LODs / Per-Day-Scan.** Heutige `Task.detached` läuft sequenziell pro LOD bzw. global. | `AppHeatmapModel.swift`, `OverviewMapPreparation.swift` | `withTaskGroup` pro LOD/Chunk. Auf Linux nicht messbar — Schwung-Gewinn nur auf echter Multi-Core-Hardware. | Mac/Device |

### Mac-only (Hardware / Xcode-Pflicht)

| ID | Befund | Ort |
|---|---|---|
| **M-13** | **46-MiB Original-Tester-Asset (timelinePath-Geometrie) Retest** auf iPhone 15 Pro Max. Synthetisches 46-MiB-Asset war am 2026-05-13 grün; Original weiter ausstehend. | UITest + Hardware |
| **M-14** | **Dynamic-Island Lock-Screen + Live Activity** visuelle Sichtprüfung auf iPhone 15 Pro Max iOS 26.4. | Hardware |
| **M-15** | **iPad-Layout** (UDID `3c955848…d4da0a5`, iPadOS 17.7.10) — Gerät beim letzten Train offline. | Hardware |
| **M-16** | **Instruments Time Profiler** auf Heatmap-Rebuild, Overview-scanCandidates, Day-Detail-Init mit pathologischen Imports. | Mac+Hardware |
| **M-17** | **`xcarchive 1.0.2 (171)` Upload nach ASC** via Organizer; Apple-Review-Resubmit für 1.0.2. | Mac+ASC |

## Mess-Baseline — Ist-Zustand

**Existierende `measure()`-Tests:** 5 Files, ~16 `measure()`-Calls.

| Datei | Tests | Linux-tauglich? |
|---|---|---|
| `MapSanitizeBenchmarkTests.swift` | 2 | **Ja** |
| `GoogleTimelineStreamReaderPerformanceTests.swift` | 3 | **Ja** |
| `HeatmapPipelineBenchmarkTests.swift` | 6 | nein (`#if canImport(SwiftUI && MapKit)`) |
| `PathDistanceCalculatorPerformanceTests.swift` | 3 | nein (`#if !os(Linux)`) |
| `PerformanceTests.swift` | 4+1 | gemischt |

**Linux-CI-Baseline heute:** ~5 belastbare Performance-Tests (`MapSanitize` + `GoogleTimelineStreamReader`). Alles andere ist Apple-only oder Memory-Metric-gated.

**Dokumentierte Throughputs** (alle mit Repo-Quelle, reproduzierbar):

- ~4–5 M coords/s `CoordinateValidity.isValid` auf Foundation-only Filter (10k/50k), Quelle `NEXT_STEPS.md`.
- Heatmap-Refactor 1k: 37→32 ms (RSD 15 %), Quelle `NEXT_STEPS.md` — Apple-only-Benchmark.
- `swift test` Linux Gesamt: 1435 / 2 Skips / 0 Failures, **41,1 s** (Swift 6.3.2, HEAD `99c1549`).

**Schwächen der Baseline** (Befund Agent C, transparent dokumentiert):
- Kein Fail-Bar in `measure()`-Tests → Regressionen nur per Sichtprüfung erkannt.
- Nur synthetische Inputs (keine echte Memory-Fragmentierung, Page-Faults).
- Builder, DouglasPeucker, PathFilter ohne Linux-Baseline.
- Hardware-/Memory-Verhalten nicht im Repo prüfbar.

## Statusupdate 2026-05-16 — Train B1 umgesetzt (kleinste sichere Teilmenge von P0-4)

- `Sources/.../AppInsightsContentView.swift` — drei `ForEach(Array(...enumerated()), id: \.offset)` (Z. 940, 958, 984) auf stabile Domain-IDs (`\.activityType` / `\.semanticType` / `\.label`). Index in allen drei Fällen ungenutzt; Listen statisch pro Render.
- **Nicht in B1 enthalten (bewusst aufgeschoben):**
  - P0-5 `.onChange`-Konsolidierung in `AppInsightsContentView`: `.task(id:)` ist hier **keine** semantik-äquivalente Ersetzung (zusätzlicher Lauf auf Appear → duplizierter `refreshDerivedModel`, duplizierte Picker-Resets). Kombiniertes `Equatable`-Struct hätte keinen messbaren Vorteil. **Status: KEEP AS IS.**
  - P0-4 Rest: `AppRecordedTrackEditorView` (Index aktiv in Bindings), `LHExportComponents` (Index aktiv im Label), `AppInsightsContentView` `topDays` (Index angezeigt), Live-Breadcrumb-Buckets (Live-Pfad ausdrücklich nicht in B1), Overview/Export/DayDetail-Rows (Modelle ohne stabile Domain-ID — separater Train B2 nötig).
- Linux `swift test`: **1459 / 2 Skips / 0 Failures, 54,3 s** — unverändert zum Stand vor Train B1.
- **Auf Linux nicht visuell prüfbar:** SwiftUI-Identity-Diffing bei tatsächlichen `breakdown`-Insertions/Updates auf iOS-Renderer.

## Statusupdate 2026-05-16 — Train A umgesetzt

- 3 neue Foundation-only Performance-Test-Files + 1 Erweiterung committed (siehe `CHANGELOG.md`-Eintrag zum gleichen Datum):
  - `PathSimplificationPerformanceTests` (5 Cases)
  - `PathFilterPerformanceTests` (6 Cases)
  - `ExportBuildersPerformanceTests` (12 Cases, KMZ ausgelassen — wrappt KML)
  - `GoogleTimelineStreamReaderPerformanceTests` +1 10k-Case
- Linux `swift test`: **1459 / 2 Skips / 0 Failures, 52,8 s** (vorher 1435).
- **Keine Code-/Verhaltens-Änderung an App-Surfaces.** Alle P0/P1/P2/Mac-only Hotspots aus diesem Report bleiben **offen**.

## Empfohlene Trains (Train A umgesetzt, Rest planerisch)

**Train A — „Baseline Strengthening" (Linux-CI, low risk, kein Verhaltenswechsel):**
- P0-2: DouglasPeucker, PathFilter Performance-Tests.
- P0-3: Export-Builder Performance-Tests.
- Optional: GoogleTimeline 10k-Entries (heute 5k) erweitern.

**Train B — „Identity & Surface Polish" (low risk, kein Verhaltenswechsel):**
- P0-4: `ForEach(Array(...enumerated()))` Stellen schrittweise auf stabile IDs.
  - **B1 umgesetzt 2026-05-16** — 3 Stellen in `AppInsightsContentView` (activity/visit/period breakdown). Siehe Statusupdate oben.
  - B2 offen — DayDetail-Rows, Overview/Export-Overlays, RecordedTrackEditor (Modelle ohne Domain-ID; benötigt `Identifiable`-Erweiterung).
- P0-5: AppInsightsContentView `.task(id:)`-Konsolidierung. **Nach Analyse 2026-05-16: KEEP AS IS** — `.task(id:)` ist keine semantik-äquivalente Ersetzung der bestehenden 5× `.onChange`-Cluster (würde Initial-Lauf duplizieren).

**Train C — „Live Surface Hardening" (mittel, Default OFF):**
- P0-1: Live-Track Polyline-Cap mit Tail-Decimation, Feature-Flag.
- P1-7: Camera-Update-Throttle im Follow-Mode, Feature-Flag.

**Train D — „Mac/Device only" (separat, manuell):**
- M-13/14/15: Hardware-Sichtprüfungen.
- M-17: ASC-Upload 1.0.2 (171), Review-Resubmit-Vorbereitung.
- P1-6 / P2-9 / P2-10 / P2-12: Erst mit Instruments messen, dann entscheiden.

## Teststatus

- **`swift test` Linux (Swift 6.3.2 via swiftly, libsqlite3-dev installiert):** 1435 / 2 Skips / 0 Failures, 41,1 s — grün auf HEAD `99c1549`.
- **Apple/Mac Tests:** im Audit nicht ausgeführt; letzter dokumentierter Stand 1524/2/0 am 2026-05-13 (siehe `NEXT_STEPS.md`).
- **UITests / Hardware:** im Audit nicht ausgeführt; letzter dokumentierter Stand 9 UITests + 4× LaunchTest am 2026-05-13 (iPhone 15 Pro Max).

## Offene Mac-/Hardware-Verifikation

Übernommen aus laufender Doku (in diesem Audit nicht erledigt, nicht widerlegt):
- 46-MiB Original-Tester-Asset Hardware-Retest.
- Dynamic Island Lock-Screen visuell.
- iPad-Layout.
- `xcarchive 1.0.2 (171)` Upload, ASC-Review-Resubmit.

## Was dieser Audit ausdrücklich nicht behauptet

- **Keine** Aussage „nach Refactor X% schneller" — alles ist Plan, nichts ist gemessen.
- **Keine** Aussage „Live-Tracking braucht Cap, weil RAM-Limit überschritten" — nur strukturell unbegrenzt; Realmessungen fehlen.
- **Keine** Aussage „MKMapView+MKMultiPolyline ist schneller" — Apple empfiehlt SwiftUI `Map` für iOS 17+; jeder Wechsel braucht Side-by-Side-Messung.
- **Keine** Roadmap-Verschiebung — bestehende Trains und Versionsstrategie unangetastet.
