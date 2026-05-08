# Map Architecture Audit — 2026-05-08

> Status: Audit only — keine Renderer-Migration in diesem Commit. Erstellt im Rahmen der P0-Untersuchung des 46-MB-Google-Timeline-Imports (3. Hardware-Fail 2026-05-07T15:10:44+02:00 nach 95 156 ms, Jetsam auf iPhone 15 Pro Max).

## Phase 9A — Wrapper/AppFlow verdrahtet, Map UI-Hook bleibt blockiert (2026-05-08)

> **Hinweis Phase 9A**: Wrapper (`wrapper/LH2GPXWrapper/ContentView.swift`) und Package-AppShell (`Sources/LocationHistoryConsumerApp/AppShellRootView.swift`) sind jetzt auf den Envelope-Pfad (`loadImportedFileEnvelope` + `LH2GPXAppFlow.apply(envelopeOutcome:to:preserveOnFailure:)`) verdrahtet; eine Landing-View (`LocalTimelineSessionLandingView`) zeigt bei aktiver `localTimelineSession` Session-Metadaten + Lösch-Button. **Der Map-/Heatmap-/Overview UI-Hook gegen `StoreBackedMapDataProvider`/`StoreBackedHeatmapDataProvider` bleibt blockiert hinter dem 46-MB-Gate** (FAILED / pending hardware retest); §4/§5 dieses Audits bleiben Roadmap. Store-Pfad bleibt default AUS (`LH2GPX_LOCAL_TIMELINE_STORE` unverändert).

## Phase 8B — Store-backed Heatmap LOD Cache + Heatmap-Doppelbug-Fix (Foundation only, 2026-05-08)

> **Klarstellung**: Phase 8B führt **(a) den zentralisierten Heatmap-Doppelbug-Fix via Foundation-only `AppHeatmapPathSampler`** und **(b) eine Foundation-only Heatmap-Provider-Schnittstelle + `derived_cache`-Tabelle** über den LocalTimelineStore ein. **KEIN UI-Hook, KEIN UI-Heatmap-Renderer-Hook, KEIN SwiftUI-Map/MKMapView-Hook in dieser Phase.** Der existierende SwiftUI-Heatmap-Renderer (`AppHeatmapView` + `AppHeatmapModel`) bleibt im Renderer/MapKit-Pfad unverändert; lediglich die Punkt-Sampling-Logik in `AppHeatmapModel.swift:55-77` greift jetzt zentral auf `AppHeatmapPathSampler` zurück.

- **Eingecheckt** (siehe `docs/LOCAL_TIMELINE_STORE_RESEARCH.md` Phase-8B-Snapshot):
  - `Sources/LocationHistoryConsumer/AppHeatmapPathSampler.swift` — Foundation-only Helper. Kanonische Priorität: `flatCoordinates` wenn vorhanden + gerade Element-Anzahl, sonst `points` Fallback. Ungerade `flatCoordinates` gelten als malformed → kontrollierter Fallback auf `points`.
  - `Sources/LocationHistoryConsumer/AppHeatmapModel.swift` — Zeilen 55-77 nutzen jetzt den Sampler statt der Doppel-Iteration. **Heatmap-Doppelbug ab Phase 8B zentralisiert gefixt.**
  - `Sources/LocationHistoryConsumerAppSupport/LocalTimelineHeatmapModels.swift` — Foundation-only Modelle (`LocalTimelineHeatmapSample`, `LocalTimelineHeatmapSampleResponse`, `LocalTimelineHeatmapGridCell`, `LocalTimelineHeatmapLODResponse`, `LocalTimelineHeatmapCacheKey`, `LocalTimelineHeatmapCacheEncoding`).
  - `Sources/LocationHistoryConsumerAppSupport/LocalTimelineHeatmapGridAggregator.swift` — deterministischer Grid-Aggregator. Cell-Size pro Detail-Level overview=0.5°/low=0.1°/medium=0.02°/high=0.005°. Hartes `maxCells`/`maxSamplesConsumed`. Stabile Sortierung lat asc, lon asc.
  - `Sources/LocationHistoryConsumerAppSupport/StoreBackedHeatmapDataProvider.swift` — Foundation-only Provider mit `heatmapSamples(...)` (bounded sampling, doppelt bounded `maxRoutes` × `maxPointsPerRoute`, total-bounded `maxSamples`), `heatmapLOD(...)` (Grid-Aggregation, optional cache-backed via `derived_cache`), `clearHeatmapCache(importID:)`. Cache-Payload-Codec deterministisch (Magic `'L8B1'`, little-endian); Cache-Key über `LocalTimelineHeatmapCacheKey.make(...)` mit 1e-3°-Quantisierung; malformed `coord_blob` kontrolliert übersprungen.
  - Schema-Änderung in `LocalTimelineStoreSchema.swift`: neue **additive** Tabelle `derived_cache` mit FK auf `imports.id` und `ON DELETE CASCADE`; zwei neue Indizes `idx_derived_cache_import_kind_key` und `idx_derived_cache_kind_created`. **`userVersion` bleibt 2** (rein additiv, keine semantische Schema-Änderung).
  - `LocalTimelineStore.swift`: CRUD `putDerivedCache`, `derivedCache`, `deleteDerivedCache`, `countDerivedCache`. `deleteAll()` löscht jetzt auch `derived_cache`.
  - 4 neue Test-Dateien Linux-grün (`AppHeatmapModelGeometryTests` 7, `LocalTimelineHeatmapGridAggregatorTests` 7, `StoreBackedHeatmapDataProviderTests` 11 inkl. 50k synthetic store + cache hit/clear roundtrip, `LocalTimelineRTreeCapabilityTests` dokumentiert RTree-Fallback).

- **RTree (`path_bounds`) bleibt kontrolliert deferred**: `paths.id` ist TEXT (`paths.id TEXT PRIMARY KEY`); SQLite RTree erwartet INTEGER `docid`. Surrogate-Integer-Mapping wäre Schema-breaking (alle bestehenden FKs müssten umgestellt werden). Bbox-Index-Scan aus Phase 8A bleibt aktiv. `LocalTimelineRTreeCapabilityTests` dokumentiert den Fallback.

- **Was Phase 8B NICHT tut**:
  - **KEIN UI-Hook, KEIN UI-Heatmap-Renderer-Hook.** Der existierende SwiftUI-Heatmap-Renderer (`AppHeatmapView`) bleibt unverändert und konsumiert weiter `AppExport`.
  - **KEIN MKMapView-Migrationsschritt.** §4/§5 dieses Audits bleiben **Roadmap, blockiert hinter dem 46-MB-Gate**.
  - **KEIN AppExport-Rebuild aus dem Store.**
  - **KEIN vollständiger `[Double]`-Import-Buffer.**
  - **KEIN Live-Upload-Mix.**
  - Feature-Flag `LH2GPX_LOCAL_TIMELINE_STORE` unverändert; Store-Pfad bleibt **default AUS** / pre-production.
  - **46-MB-Gate bleibt FAILED / pending hardware retest.**

- **Phase-9-Pflichten** (in 8B explizit deferred):
  - RTree (`path_bounds` virtual table) — würde Surrogate-Integer-Mapping erfordern, Schema-breaking.
  - Wrapper/SwiftUI-Wiring der Presentation-/ViewState-Schicht.
  - Settings-Delete-UI-Button.
  - Map/Heatmap/Overview UI-Hook gegen Provider.
  - Darwin FileProtection-Aktivierung.
  - Export-UI-Hook gegen `StoreBackedExportWriter`.
  - 46-MB-Hardware-Retest, TestFlight/Xcode-Cloud Build ≥100.
  - App-Flow-Umschaltung gegen Conditional-Gate.
  - Privacy-Doku-Update vor Rollout.

---

## Phase 8A — Store-backed Map Data Provider (Foundation only, 2026-05-08)

> **Klarstellung**: Phase 8A führt **ausschließlich eine Foundation-only Provider-Schnittstelle** über den LocalTimelineStore ein. **KEIN UI-Hook, KEIN Renderer-Hook, KEIN SwiftUI-Map/MKMapView-Hook in dieser Phase.** Die heutigen Kartenflächen (Overview, Day Detail, Heatmap, Live Tracking, Export Preview) konsumieren **weiterhin den Legacy-`AppExport`-Pfad** — nichts an §1 oder §2 dieses Audits hat sich verschoben.

- **Eingecheckt** (siehe `docs/LOCAL_TIMELINE_STORE_RESEARCH.md` Phase-8A-Snapshot):
  - `Sources/LocationHistoryConsumerAppSupport/LocalTimelineMapModels.swift` — Foundation-only Map-Domain-Modelle (`LocalTimelineMapViewport` mit Anti-Meridian-Reject, `LocalTimelineMapDetailLevel`, `LocalTimelineMapPointBudget`, `LocalTimelineMapQuery`, `LocalTimelineMapRouteCandidate` metadata-only, `LocalTimelineMapPoint`, `LocalTimelineMapRouteGeometry` bounded, `LocalTimelineMapOverviewResponse` mit `truncatedRoutes`/`truncatedPoints`, `LocalTimelineMapBounds`, `LocalTimelineMapProviderError`). **Keine SwiftUI/MapKit/CoreLocation-Abhängigkeit.**
  - `Sources/LocationHistoryConsumerAppSupport/StoreBackedMapDataProvider.swift` — Provider mit `routeCandidates`/`dayRouteCandidates` (metadata-only, kein `coord_blob`-Read), `routeGeometry` (lazy single-path decode via `CoordBlobIterator`), `overviewRoutes` (doppelt bounded mit `maxRoutes` und `budget.maxTotalPoints`), `mapBounds(forImportID:)`/`mapBounds(forDayID:)` (Aggregat über `paths.min/max_lat/lon`-Spalten ohne Geometrie-Decode).
  - `Sources/LocationHistoryConsumerAppSupport/LocalTimelineRouteDecimator.swift` — deterministischer stride-/budget-basierter Decimator, Iterator-basiert, erster + letzter Punkt erhalten, `maxPoints` hart, leere/1-Punkt-Pfade stabil. Douglas-Peucker bleibt Phase 8B/9.
  - Schema-Änderung in `LocalTimelineStoreSchema.swift`: zwei neue **additive** Indizes `idx_paths_bounds_minmax` und `idx_paths_day_bounds`. **`userVersion` bleibt 2** (rein additiv). RTree (`path_bounds` virtuelle Tabelle) wurde in 8A explizit **nicht** angelegt — bleibt **Phase-8B-Pflicht**.
  - Store/Reader: neue public APIs `pathMetadata(forImportId:viewport:limit:)`, `pathMetadata(forDayId:viewport:limit:)`, `pathBoundingBox(forImportId:)`, `pathBoundingBox(forDayId:)`. Bbox-Filter ist linear scan über `min/max_lat/lon`-Spalten; NULL-Bounds konservativ als überlappend gewertet; newest-first `ORDER BY start_time`.
  - 4 neue Test-Dateien, 33 Cases (`StoreBackedMapDataProviderTests` 15, `LocalTimelineRouteDecimatorTests` 8, `LocalTimelineMapBoundsTests` 7, `LocalTimelineMapSchemaIndexTests` 2).

- **Provider als kanonische Schnittstelle für künftige UI-Hooks**: Sobald in Phase 8B/9 ein Map/Heatmap/Overview-UI-Hook gegen den Store gewünscht ist, **muss er über `StoreBackedMapDataProvider` gehen** — nicht direkt gegen `LocalTimelineStore`/`LocalTimelineStoreReader`. Das ist die Stelle, an der die Bounded-Read-Garantien (kein blob in Candidate-Reads, single-path lazy decode, doppelt bounded Overview, Aggregate-only mapBounds) zentral verankert sind.

- **Was Phase 8A NICHT tut**:
  - **KEIN UI-Hook, KEIN Renderer-Hook.** Weder Overview, Day Detail, Heatmap, Live Tracking noch Export Preview lesen aus dem Provider. Die heutigen SwiftUI `Map`-Flächen sind unverändert.
  - **KEIN MKMapView-Migrationsschritt.** §4/§5 dieses Audits (UIKit `MKMapView`/`MKMultiPolyline`/`MKTileOverlay`) bleiben **Roadmap, blockiert hinter dem 46-MB-Gate**. Phase 8A bewegt diesen Block nicht.
  - **KEIN Heatmap-Doppelbug-Fix.** Der in §2 / §5-Roadmap-Schritt 2 dokumentierte Doppelbug in `AppHeatmapModel.swift:55-77` ist **nicht behoben** — Fix bleibt **Phase-8B-Pflicht**.
  - **KEIN AppExport-Rebuild aus dem Store.**
  - **KEIN vollständiger `[Double]`-Import-Buffer.**
  - **KEIN Live-Upload-Mix.** Live-Upload bleibt strikt getrennt vom Store-Pfad.
  - Feature-Flag `LH2GPX_LOCAL_TIMELINE_STORE` unverändert; Store-Pfad bleibt **default AUS** / pre-production.
  - **46-MB-Gate bleibt FAILED / pending hardware retest.** MKMapView-Migration bleibt blockiert hinter diesem Gate.

- **Phase-8B/9-Pflichten** (in 8A explizit deferred):
  - RTree (`path_bounds` virtual table) statt linearem bbox scan.
  - `derived_cache`, Heatmap-LOD-Persistenz.
  - Wrapper/SwiftUI-Wiring der Presentation-/ViewState-Schicht.
  - Settings-Delete-UI-Button.
  - Map/Heatmap/Overview UI-Hook gegen Provider.
  - **Heatmap-Doppelbug-Fix (`AppHeatmapModel.swift:55-77`).**
  - Darwin FileProtection-Aktivierung.
  - Export-UI-Hook gegen `StoreBackedExportWriter`.
  - 46-MB-Hardware-Retest, TestFlight/Xcode-Cloud.
  - Privacy-Doku-Update.

---


> **Update 2026-05-08 (Linux-Stabilisierung HEAD `37a22b7` nach `34bc369`)**: Die vier reinen Heatmap-/MapTrack-Color-Preference-Enums `AppHeatmapPalettePreference`, `AppHeatmapScalePreference`, `AppHeatmapRadiusPreset`, `AppMapTrackColorMode` leben jetzt als Linux-buildbare `String`-`RawValue`-Enums in `Sources/LocationHistoryConsumerAppSupport/HeatmapPreferenceEnums.swift` (vorher in `HeatmapPalette.swift` / `HeatmapLOD.swift` / `AppHeatmapView.swift` / `MapTrackStyling.swift` hinter `#if canImport(SwiftUI) && canImport(MapKit)`-Guards). Der `scale`-Multiplikator von `AppHeatmapRadiusPreset` und alle SwiftUI-/MapKit-abhängigen Extensions (z. B. Color-Resolver) bleiben hinter Plattform-Guards. **Keine** Verhaltensänderung am Heatmap-Renderer, an den LOD-Schwellen oder an der Mercator-/cos(lat)-Aggregation. Map-Architektur-Roadmap (P1+, §4/§5) bleibt unverändert: keine Renderer-Migration, keine `MKMultiPolyline`/`MKTileOverlay`-Umsetzung in diesem Commit.

Dieses Dokument ist eine reine Bestandsaufnahme der aktuellen Karten-/Rendering-Pipeline. Es enthält keine Code-Änderungen, keinen Renderer-Wechsel und keine Migrations-Termine. Die Roadmap-Schritte unten sind als spätere, jeweils eigenständige Commits zu verstehen.

## 1. Kartenflächen-Inventar

| Fläche | Datei | Renderer | Datenquelle | Erwartete Spitzenmenge | eager / lazy | Caching | Purge | Bekannte Risiken |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Overview / Tage Hero Map | `AppOverviewTracksMapView.swift` | SwiftUI `Map` + `MapPolyline` (halo + core pro Pfad) | `AppExport.data.days` direkt; Scan über `OverviewMapPreparation.scanCandidates` (flat-aware, mit `path.points` Fallback) | `pointBudget = 2_000_000`; `candidateStorageCap = 512` Punkte pro Kandidat; `overlayLimit` 150–300 abhängig vom `OverviewMapRenderProfile` | lazy: `.task(id: taskKey)` triggert `loadData`; Pan/Zoom ruft nur `rebuildOverlays` (kein Re-Scan) | `allCandidates` im Modell gehalten; `OverviewMapRenderData` als `@Observable` State | Generation-Counter + Hash-Token Race-Guard; `Task.cancel()` auf Filter-Wechsel; `.task(id:)` triggert Re-Scan | Scan iteriert `export.data.days` synchron auf detached Task; pro Kandidat 2 `MapPolyline` (halo + core); `pointBudget` schützt nur die Sammelphase, nicht die parallel laufende Decoded `AppExport`-Struktur. Hard Cap 150–300 Polylines reicht historisch bis ~150k Punkte; bei 46 MB Google Timeline tritt Jetsam vor dem Scan auf (Decode + parallele Projektionen). |
| Day Detail | `AppDayMapView.swift` | SwiftUI `Map` mit `MapPolyline` (halo + core pro Pfad) plus optional `SpeedTrackBuilder.segments` (eine Polyline pro Segment) und `Marker` für Visits | `DayMapData` (flat-unaware; siehe `DayMapDataExtractor`) | Ein Tag, üblicherweise wenige Pfade; Punkte in `simplifiedCoordinates` nach Douglas-Peucker | eager: `DayMapRenderData.init` läuft synchron im View-Init und in `onChange(of: mapData)`; berechnet einmalig `removeOutliers` + `douglasPeucker`. | `DayMapRenderData` als `@State` | Wird bei `mapData` Change neu erzeugt (kompletter Replace) | Speed-Modus erzeugt eine `MapPolyline` pro Segment (ein Segment pro PathPoint-Paar); points-only (vor flatCoordinates-Refactor) — Google-Timeline-Tage profitieren nicht von flatCoordinates. Per-Frame Map-Body ruft `displayCoords` 2× pro Pfad (halo + core), Daten aber präkomputiert. |
| Heatmap | `AppHeatmapModel.swift` + `AppHeatmapView.swift` (+ `HeatmapGridBuilder`, `HeatmapLOD`, `HeatmapPalette`, `HeatmapVisualStyle`) | SwiftUI `Map` mit `MapPolygon` pro `HeatCell`, Fill via `RadialGradient` | `AppExport.data.days` → `WeightedPoint`-Liste (Visits, Path-Punkte, Activity Start/End, Activity-flatCoordinates, Path-flatCoordinates) | Ein `WeightedPoint` pro Roh-Punkt + ein zusätzlicher Punkt pro flatCoordinates-Paar bei Imports mit beidem (siehe Bug §2). LOD-Selection-Limits: macro 36, low 72, medium 280, high 1200. | lazy: `startPrecomputation` läuft in detached Task, baut `densityPoints` und alle 4 LODs (`computeGrid` pro LOD). `debounceUpdateForRegion` mit 100 ms Debounce. | `lodGrids: [HeatmapLOD: [GridKey: HeatCell]]`, `viewportCache: [HeatmapViewportKey: [HeatCell]]` (volle Lebensdauer des Modells) | `lodGrids = [:]` + `viewportCache = [:]` bei `updateScale`; sonst kein TTL/Eviction | **Doppelbug** (s. §2): bei Imports mit gleichzeitig `points` und `flatCoordinates` werden Pfade doppelt gewichtet. `densityPoints` ist eine flache `[WeightedPoint]`-Kopie aller Punkte → bei großen Imports voller Speicher-Peak parallel zur `AppExport`-Decoded-Struktur. Pro Cell ein `MapPolygon` (Hexagon-Polygon mit 7 Koordinaten) + `RadialGradient`. |
| Live Tracking | `AppLiveTrackingView.swift` | SwiftUI `Map` mit `MapPolyline` (halo + core, optional Speed-Segmente oder `LiveBreadcrumbFade`-Buckets), `MapCircle` für Genauigkeit, `Annotation` mit `LiveLocationDot` | `LiveLocationFeatureModel.liveTrackPoints` → `polylineCoordinates` + `trackSamples` | Live-Track einer aktuellen Recording-Session (typischerweise hunderte bis wenige tausend Punkte) | eager bei jedem `liveTrackSignature` Change: `refreshTrackPresentationState` mappt komplette `liveTrackPoints` in `polylineCoordinates` und `trackSamples`. | `polylineCoordinates`, `trackSamples`, `metricSnapshot` als `@State` | Wird bei jedem Track-Change komplett ersetzt; bei `liveTrackPoints.isEmpty && !isRecording` → `recordingStartDate = nil` | `MapCoordinateGuard.sanitize` wird auf jede Polyline angewendet (NaN/±Inf/Apple-Sentinel-Filter); ansonsten kein Hard Cap auf Punkte. |
| Export Preview | `AppExportPreviewMapView.swift` (+ `ExportPreviewData.swift`) | SwiftUI `Map` mit `MapPolyline` (halo + core pro Pfad) und `Marker` für Waypoints | `ExportPreviewData` aus `ExportPreviewDataBuilder.previewData` — points-only: liest `path.points` und mappt direkt nach `DayMapCoordinate`; ignoriert `path.flatCoordinates` komplett. | Hängt an Export-Auswahl: alle ausgewählten Days × Pfade (kein Hard-Cap auf Polylines). | eager: `ExportPreviewRenderData.init` läuft im View-Init und im `onChange(of: previewData)` synchron auf MainActor. | `@State renderData: ExportPreviewRenderData` | Bei `previewData` Change komplett ersetzt | Live-Map ohne Decimation/Simplification — bei großen Auswahlen (z. B. ganzes Jahr Google Timeline) wird jeder Pfad in voller Auflösung gerendert. Kein Snapshot. |
| Snapshot-/Preview-Flächen in Listen | — | Aktuell **keine** dedizierten kleinen Snapshot-MapViews in Listen gefunden. Day-Listen zeigen Stat-Chips, keine Mini-Maps; Saved-Track-Library nutzt `SavedTrackSummaryContentView` ohne Map. | n/a | n/a | n/a | n/a | n/a | Falls in Zukunft Mini-Maps in Listen eingeführt werden, müssen sie zwingend Snapshot-basiert sein (s. Roadmap §5). |

Alle Kartenflächen verwenden derzeit ausschließlich SwiftUI `Map` (iOS 17+). Es gibt aktuell keine Verwendung von UIKit `MKMapView` mit `MKMultiPolyline`, kein `MKTileOverlay`, keine `MKMapSnapshotter`-Snapshots in der App.

## 2. Geometriequellen-Konsistenz

Das Modell `Path` (`Sources/LocationHistoryConsumer/AppExportModels.swift`) hält parallel:

- `points: [PathPoint]` — strukturiert (lat, lon, time?, accuracy_m?), pro Punkt ein optionaler ISO-Zeitstring
- `flatCoordinates: [Double]?` — flaches Array `[lat0, lon0, lat1, lon1, …]`, ohne Zeitstempel

`Activity` hält ebenfalls `flatCoordinates: [Double]?` (kein equivalentes `points`-Array).

### Pro Consumer welcher Pfad bevorzugt wird

| Consumer | Datei | flat-aware? | Strategie |
| --- | --- | --- | --- |
| `PathDistanceCalculator.polylineDistanceMeters(for path:)` | `Sources/LocationHistoryConsumer/Queries/PathDistanceCalculator.swift:83-86` | dual | `path.points.count >= 2` → `polylineDistanceMetersFromPathPoints`; sonst `path.flatCoordinates` (≥ 4) |
| `AppExportQueries.effectiveDistance` (über `effectiveCoordinates`) | `Sources/LocationHistoryConsumer/Queries/AppExportQueries.swift:686-696` | dual | Bevorzugt `path.points`; fällt auf `flatCoordinates` zurück, wenn points leer/zu kurz |
| `OverviewMapPreparation.scanCandidates` | `AppOverviewTracksMapView.swift:678-715` | flat-first | `if let flat = path.flatCoordinates, flat.count >= 4, flat.count.isMultiple(of: 2)` zuerst; sonst `path.points` Fallback |
| `AppHeatmapModel.startPrecomputation` | `AppHeatmapModel.swift:55-77` | **BUG (beide)** | Iteriert `path.points` UND zusätzlich `path.flatCoordinates` falls beide gesetzt → doppelte Gewichtung. Gleiche Konstruktion bei `activity.flatCoordinates` (Aktivitäten haben kein `points`-Array, daher dort kein Doppelbug, aber zusätzliche Punkte werden pro Activity-flatCoordinate-Paar emittiert). |
| `KMLBuilder` | `Sources/LocationHistoryConsumer/KMLBuilder.swift` | points-only | nutzt `path.points` (kein flatCoordinates-Branch sichtbar) |
| `GeoJSONBuilder` | `Sources/LocationHistoryConsumer/GeoJSONBuilder.swift` | points-only | analog points-only |
| `GPXBuilder` | `Sources/LocationHistoryConsumer/GPXBuilder.swift` | points-only | analog points-only |
| `CSVBuilder` | `Sources/LocationHistoryConsumer/CSVBuilder.swift` | points-only | analog points-only |
| `DayMapDataExtractor.mapData(from detail:)` | `Sources/LocationHistoryConsumer/Queries/DayMapData.swift:99-108` | points-only | `path.points.map { DayMapCoordinate(...) }`; flatCoordinates wird nicht konsultiert |
| `ExportRouteSanitizer` | `Sources/LocationHistoryConsumer/ExportRouteSanitizer.swift:20-29` | points-only (Sanitization), reicht flatCoordinates unverändert durch | `deduplicatedPoints(path.points)`; `flatCoordinates: path.flatCoordinates` wird unverändert in den neuen `Path` übernommen — d. h. nach Sanitization können beide weiterhin gleichzeitig gesetzt sein |
| `ExportPreviewDataBuilder.previewData` | `Sources/LocationHistoryConsumerAppSupport/ExportPreviewData.swift:46-58` | points-only | `path.points.map { DayMapCoordinate(...) }`; flatCoordinates ignoriert |

### Heatmap-Doppelbug (lines 55-77 `AppHeatmapModel.swift`)

> **Update 2026-05-08 (Phase 8B)**: Der hier dokumentierte Doppelbug ist **ab Phase 8B zentralisiert gefixt** via Foundation-only Helper `Sources/LocationHistoryConsumer/AppHeatmapPathSampler.swift`. Kanonische Priorität: `flatCoordinates` (wenn vorhanden und gerade Element-Anzahl), sonst `points` Fallback; ungerade `flatCoordinates` gelten als malformed → kontrollierter Fallback auf `points`. `AppHeatmapModel.swift:55-77` ruft jetzt den Sampler auf statt beide Geometrien zu iterieren. 7 neue Linux-grüne Tests in `Tests/LocationHistoryConsumerTests/AppHeatmapModelGeometryTests.swift` decken Sampler-Priorität, Fallback und Doppelbug-Regression ab. Der unten zitierte Codeblock zeigt den **bisherigen** (vor Phase 8B) Zustand.


```swift
for path in day.paths {
    for point in path.points {
        points.append(WeightedPoint(lat: point.lat, lon: point.lon, weight: 1))
    }
    if let flats = path.flatCoordinates {
        for index in stride(from: 0, to: flats.count - 1, by: 2) {
            points.append(WeightedPoint(lat: flats[index], lon: flats[index + 1], weight: 1))
        }
    }
}
```

Sind `path.points` und `path.flatCoordinates` beide gefüllt (Pipeline-Vorbedingung nach `ExportRouteSanitizer` möglich), wird jeder Pfad doppelt in den Heatmap-Eingang aufgenommen — einmal aus `points`, einmal aus `flatCoordinates`. Folge:

- `WeightedPoint`-Anzahl in `densityPoints` ist bis zu doppelt so groß wie nötig.
- `HeatmapStats.totalPoints` zeigt diesen Doppelwert an.
- Speicher-Peak bei großen Imports steigt entsprechend (pro `WeightedPoint` 24 B + Bookkeeping → bei mehreren Hunderttausend Punkten relevant).
- Density-Normalisierung bleibt visuell formell unverändert, weil sie auf `maxCount` rebased; der Mehraufwand ist also Speicher und CPU, nicht Bildausgabe.

`Activity`-Branch (Zeilen 65-77) hat keinen Doppel-Effekt, weil `Activity` kein `points`-Array hat — es kommen nur Start/End-Coords und flatCoordinates rein. Bei Google Timeline (vor dem Refactor) ist `activity.flatCoordinates == nil` ohnehin, daher dort aktuell kein Schaden.

## 3. Aktuelle Schutzmechanismen

- **ZIP-Streaming** mit `streamGoogleTimelineCandidateIfApplicable` — peakt bei ~one element, vermeidet Vollextraktion eines Google-Timeline-Eintrags ins RAM, bevor er geparsed wird.
- **AutoreleasePool** um Parse + Ingest in `GoogleTimelineStreamReader.processByte` (Commit cd77f97) — schließt CFString-/NSDictionary-Allokationen pro Element.
- **`mutating finalize()`** in `GoogleTimelineConverter.ExportBuilder` (`GoogleTimelineConverter.swift:156-179`, ae5de1f) — `dayMap.removeValue(forKey:)` pro Tag, statt zu kopieren; final `dayMap.removeAll(keepingCapacity: false)` + `orderedDayKeys.removeAll(keepingCapacity: false)`. ARC kann Buckets eagerly freigeben.
- **`IncrementalStreamConverter.finalize()`** (`GoogleTimelineConverter.swift:96-106`) resettet `builder = ExportBuilder()` direkt nach `finalize` — die per-day Buckets bleiben nicht für die Lebensdauer des Loader-Scopes alive.
- **`AppSessionContent.init`** (Hinweis aus dem Auftrag — nicht im Audit-Set re-verifiziert): pickt selectedDate ohne lazy projections, d. h. kein impliziter Trigger einer Overview-Berechnung beim Init.
- **`AppSessionState.show(content:)`** (Hinweis aus dem Auftrag — nicht im Audit-Set re-verifiziert): liest `inputFormat` direkt aus `meta` (kein lazy-overview-Trigger).
- **OverviewMap candidate stride-decimate**: `candidateStorageCap = 512` Punkte pro Kandidat (`AppOverviewTracksMapView.swift:725`); `OverviewMapPreparation.strideDecimate` linearer Scan, nicht-allokierend über das Result-Array hinaus. Score wird auf den un-decimated Coords berechnet, damit dichte Pfade ihre Priorität behalten.
- **OverviewMap Tier-System**: `OverviewMapRenderProfile.resolve` (`AppOverviewTracksMapView.swift:589-622`) staffelt `overlayLimit` (150 / 200 / 250 / 300 / N), `simplificationEpsilonM` (140 / 100 / 70 / 50 / 30 m) und `maxPolylinePoints` (64 / 96 / 120 / 160 / 220) abhängig von Routen- und Punktzahl.
- **Heatmap Tier-/LOD-System**: `HeatmapLOD` (`HeatmapLOD.swift`) mit `selectionLimit` 36/72/280/1200, plus Hard-Filter `minimumNormalizedIntensity * precomputationVisibilityFactor` in `computeGrid` (`HeatmapGridBuilder.swift:113`); `viewportPaddingFactor` für Off-Screen-Vorlauf; `optimalLOD(for spanDelta)` mappt Zoom auf LOD.
- **Heatmap-LOD multi-grid pre-computation**: alle 4 LODs in einer detached Task aufgebaut (`AppHeatmapModel.swift:189-204`), Viewport-Wechsel triggern nur Culling + ggf. Cache-Hit, nicht Re-Compute.
- **Douglas-Peucker** zentral in `PathSimplification.swift`. `OverviewMapPreparation.makeOverlay` ruft mit `epsilon = profile.simplificationEpsilonM`; `DayMapRenderData.init` ruft Default-`epsilon = 15.0`.
- **Outlier-Filter**: `PathFilter.removeOutliers` (Default `maxJumpMeters = 5000`) wird im DayMap-Pfad vor Douglas-Peucker angewendet. Overview-Pfad nutzt nur Douglas-Peucker, keinen Outlier-Filter.
- **DayMapView**: `simplifiedCoordinates` einmalig in `DayMapRenderData.init` (`AppDayMapView.swift:204-207`) — Per-Frame Map-Body ruft `displayCoords` 2× pro Pfad (halo + core), aber ohne Re-Simplifikation.
- **MapKit-Sentinel-Schutz**: `MapCoordinateGuard.sanitize` (`MapTrackStyling.swift:12-25`) filtert NaN, ±Inf, lat outside ±90°, lon outside ±180° und Apples `kCLLocationCoordinate2DInvalid` (-180,-180). Aktuell aktiv im Live-Track-Pfad (`AppLiveTrackingView.liveTrackContent:546`); Overview/Day/Export rufen es nicht.
- **Race-Guard im OverviewMapModel**: `loadGeneration` Counter + `currentLoadToken` Hash-Token (P2-12) gegen Filter-Switch-Races.
- **Heatmap Debounce**: `debounceUpdateForRegion` mit 100 ms Sleep + `Task.cancel` auf jedem Region-Update.
- **Heatmap Viewport-Cache**: `viewportCache: [HeatmapViewportKey: [HeatCell]]` — Pan zurück zur vorigen Position trifft Cache.

## 4. Zielarchitektur (Roadmap-Pfad, NICHT Stand)

> **Hinweis**: Dieser Abschnitt ist eine mittelfristige Soll-Skizze. Kein pauschaler Engine-Wechsel, kein hartes Migrationsdatum. **MapKit (sowohl SwiftUI `Map` als auch UIKit `MKMapView`) bleibt Baseline.** Jeder Schritt ist als eigenständige, mess-vergleichende Migration zu fahren.

- **Kanonische Geometrie**: Pfade aus großen Imports (Google Timeline, ggf. später iOS Time Travel) bevorzugen `flatCoordinates: [Double]` ohne pro-Punkt ISO-Zeitstrings — entweder `points` ODER `flatCoordinates`, nicht beides. Die Tempolayer-Funktion (Speed-coloured rendering) erfordert PathPoint-Timestamps und entfällt damit für solche Pfade.
- **Leichte Kartenflächen** (Day Detail, Live Tracking, kleine Previews) bleiben SwiftUI `Map`. Diese Flächen rendern wenige Pfade mit moderaten Punktzahlen — der SwiftUI-Renderer ist hier ausreichend.
- **Heavy Overview / Heatmap** perspektivisch UIKit `MKMapView` mit:
  - `MKMultiPolyline` für Overview (eine Overlay-Instanz für alle Routen, statt N `MapPolyline` SwiftUI-Views)
  - Annotation Clustering (built-in `MKClusterAnnotation`) für Visit-Marker
  - Optional `MKTileOverlay` für vorberechnete Heatmap-Tiles, statt N `MapPolygon`-Hexagone pro Frame
- **Snapshots statt Live-Maps** in Listen / Previews (`MKMapSnapshotter` einmalig, dann `Image`-View). Aktuell gibt es keine Mini-Maps in Listen — falls neu eingeführt, von Anfang an Snapshot-basiert.
- **Zoom-/Viewport-abhängige LOD** bleibt zentrales Prinzip auch unter `MKMapView` — die LOD-Tiers (`OverviewMapRenderProfile`, `HeatmapLOD`) sind Renderer-agnostisch und wandern mit.
- **Keine doppelte Geometriespeicherung**: Build-Pipeline und Sanitizer stellen sicher, dass am Ende eines Imports höchstens eine der beiden Repräsentationen pro `Path` gefüllt ist.

Diese Zielarchitektur wird **nicht** in einem Big-Bang-Commit umgesetzt. Jeder Renderer-Wechsel braucht eine eigenständige Performance-Vergleichsmessung (RAM-Peak, FPS, First-Render-Time auf 4 GB-Geräten).

> **Update 2026-05-08 (LocalTimelineStore-Research, HEAD-Anker `ebd8146`)**: Map-Modernisierung (UIKit `MKMapView`/`MKMultiPolyline`/`MKTileOverlay`) bleibt **blockiert**, bis entweder (a) der 46-MB-Hardware-Retest auf iPhone 15 Pro Max grün PASSED oder (b) eine klare LocalTimelineStore-P0-Entscheidung vorliegt — je nachdem, was zuerst kommt. Begründung: ein Renderer-Wechsel auf einem strukturell instabilen Datenmodell (In-Memory-`AppExport` mit Jetsam-Risiko) wäre ein bewegliches Ziel. Cross-Reference: `docs/LOCAL_TIMELINE_STORE_RESEARCH.md` (Aufgabe D — P0-Entscheidungsgate). Kein Code in `main`, kein Spike.

## 5. Roadmap-Schritte (priorisiert)

1. **flatCoordinates kanonisch für Google Timeline Imports** (P0 — diese Aufgabe). `GoogleTimelineConverter.makePath` baut aktuell `points: [PathPoint]` mit ISO-Zeitstrings; Ziel ist `flatCoordinates: [Double]` ohne pro-Punkt ISO. Kein Tempolayer-Support für Google-Timeline-Pfade ist akzeptiert.
2. **AppHeatmapModel Doppelbug fixen** (P0 — diese Aufgabe). `AppHeatmapModel.swift:55-77`: entweder `path.points` ODER `path.flatCoordinates`, nicht beides.
3. **Memory-Probe-Verdichtung + Build-Identitäts-Logging** (P0 — diese Aufgabe). Jetsam-Diagnose braucht Build-/Commit-Identität in den Probes, sonst sind Hardware-Fails nicht eindeutig zuordenbar.
4. **Map-Architektur-Audit dokumentieren** (P0 — diese Datei).
5. **ExportPreview Map: Snapshot statt Live-Map** (P1). `AppExportPreviewMapView` rendert aktuell jede ausgewählte Route in voller SwiftUI-Map-Auflösung. Bei großen Export-Auswahlen ist das eine zweite Speicherspitze parallel zum Export selbst.
6. **Overview Map auf MKMapView Pfad evaluieren** (P1, eigener Commit, Performance-Mess-Vergleich). `MKMultiPolyline` statt N `MapPolyline`-Views in der `compactMapView` und im Explore-Sheet.
7. **Heatmap auf MKTileOverlay vorberechneten Tiles** (P2, größere Designarbeit). Cell-Polygone werden durch vorberechnete Bitmap-Tiles pro LOD ersetzt; spart Polygon-Rendering pro Frame.
8. **UIKit-Annotation-Clustering Pilot** (P2). Setzt MKMapView-Migration der entsprechenden Fläche voraus.

## 6. Offene Fragen / Risiken

- **iOS Map.maxPolylineCount (SwiftUI)** — empirisch ~150-300 sichere Spitze; bestätigt durch die `OverviewMapRenderProfile.overlayLimit`-Staffelung. Keine offizielle Apple-Doku zum Hard Cap.
- **MKMultiPolyline Performance auf 4 GB RAM Geräten** ohne tatsächliche `MKMapView`-Migration in dieser Session **nicht messbar**. Der Performance-Gewinn gegenüber SwiftUI `Map` ist Annahme, kein Messwert.
- **Tempolayer (Speed-coloured rendering)** braucht aktuell `PathPoint.time` — entfällt für Google Timeline nach flatCoordinates-Refactor. Akzeptiert als nicht-blockierend für die P0-Aufgabe; für selbstaufgenommene Live-Tracks bleibt Speed-Layer verfügbar (PathPoints behalten Timestamps).
- **iPad-Layout / Live Activity / Dynamic Island** wurden in dieser Session nicht erneut auditiert. `AppLiveTrackingView` hat einen `landscapeLayout` mit side-by-side Map; das Verhalten unter Stage Manager / iPad Multitasking ist hier nicht abgedeckt.
- **`ExportRouteSanitizer`** lässt `path.flatCoordinates` unverändert durch (Zeile 29) und sanitisiert `path.points`. Nach Sanitization können beide Repräsentationen weiterhin parallel existieren — der Heatmap-Doppelbug kann also auch nach Sanitization auftreten.
- **`Activity.flatCoordinates`** wird vom Heatmap-Pfad in der Aggregation berücksichtigt (Zeilen 72-76). `GoogleTimelineConverter.makeActivity` setzt `flatCoordinates: nil` — also derzeit kein zusätzlicher Beitrag aus Google-Timeline-Activities. Das kann sich nach dem flatCoordinates-Refactor ändern und wäre dann konsistent zu behandeln.
- **OverviewMap Outlier-Filter**: Im Day-Pfad läuft `PathFilter.removeOutliers` vor Douglas-Peucker; im Overview-Pfad wird nur Douglas-Peucker angewendet. Ein einzelner GPS-Spike kann damit das `OverviewMapPathCandidate.boundsMinLat/Max…`-Bounding-Box verzerren und die Viewport-Intersection-Logik beeinflussen.
- **`MapCoordinateGuard.sanitize`** wird derzeit nur im Live-Pfad aufgerufen. Overview, Day und Export-Preview reichen Coordinates ungeprüft an MapKit weiter — der "Sentinel-Crash"-Schutz ist also nicht überall aktiv.

## 7. Aktualisierungsregel

Diese Datei wird bei jedem strukturellen Eingriff in die Karten-Pipeline ergänzt — **nicht ersetzt**. Neue Audit-Sektionen mit Datumsheader (z. B. `# Map Architecture Audit — YYYY-MM-DD`) anhängen. Begriffsdefinitionen, Tabellen-Spalten und Roadmap-Schritte werden in jedem neuen Audit-Block selbständig wiederholt, damit jeder Datumsstand für sich allein lesbar bleibt.
