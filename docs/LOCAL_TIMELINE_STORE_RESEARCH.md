# LocalTimelineStore — Architektur- und Machbarkeitsprüfung

## P1-C + P1-D — WAL-Checkpoint + Recovery (2026-05-08-Folgecommit)

Phase-10A-Folge des Deep Audits. Der Store hat jetzt eine **explizite WAL-Checkpoint-API**, ein **best-effort Cleanup-Wiring** entlang Import/Cancel/Delete und einen **Linux-Recovery-Test** für mid-import-Abbrüche. Schema und Standard-Aktivierung sind unverändert.

- **API-Oberfläche:** `LocalTimelineStore.checkpointWAL(mode:)`/`truncateWAL()`/`bestEffortTruncateWAL()`. `WALCheckpointMode { passive, full, restart, truncate }` mappt 1:1 auf SQLite's `SQLITE_CHECKPOINT_*`. Rückgabe `WALCheckpointInfo { framesInLog, framesCheckpointed }` — beide `-1`, wenn das WAL nicht aktiv ist (leerer Store / nie geschrieben).
- **Strategie:**
  - **Hard-Fail** (`LocalTimelineStoreError.checkpointFailed(code:message:)`) bei expliziter API. Auf `notOpen` wirft `truncateWAL` ebenfalls; `bestEffortTruncateWAL` liefert dort `nil`.
  - **Best-Effort** im nachgelagerten Cleanup: `LocalTimelineImportWriter.finalize()` ruft nach `COMMIT` `bestEffortTruncateWAL`; `LocalTimelineImportWriter.cancel()` ruft nach `ROLLBACK` `bestEffortTruncateWAL`; `LocalTimelineStoreLifecycle.deleteAllLocalTimelineData(store:)` ruft vor `store.close()` `bestEffortTruncateWAL`. Reads (Reader-Pfade, einzelne Inserts) lösen **keinen** Checkpoint aus — keine Performance-Falle, keine VACUUM-Orgie.
  - Default-Mode `.truncate` ist die bevorzugte Variante nach großen Imports/Delete/Cancel: schreibt WAL-Frames in die Hauptdatei zurück und kürzt `-wal` auf 0 Byte (sofern keine Reader die Datei halten).
- **Recovery-Status:**
  - **Keine Schemaänderung.** Die `imports`-Row wird inside `BEGIN IMMEDIATE` eingefügt — bei mid-import-Abbruch ohne `COMMIT` ist sie nie persistiert. Ein Status-Feld (`importing/completed/cancelled/failed`) wäre redundant, weil Transaktionsgrenzen jede Sichtbarkeit halbfertiger Imports bereits verhindern.
  - **Linux-Simulation** (verbatim): `LocalTimelineStoreRecoveryTests` schließen die Connection ohne `writer.finalize()`/`writer.cancel()`; SQLite verwirft die offene Transaktion automatisch. **Kein echter iOS-Jetsam-Test** — Power-Loss-/Kernel-Kill-Verhalten auf Hardware bleibt eine separate Verifikation.
  - Reopen-Verhalten: keine `imports`-Row, FK-Konsistenz erhalten, neuer Import möglich, `deleteAll()` möglich.
- **Tests:** `LocalTimelineStoreWALCheckpointTests` (7) + `LocalTimelineStoreRecoveryTests` (6). Linux-Vollsuite **1345 / 2 skipped / 0 failed** (vorher 1332/2/0).

## P1-A + P1-B — Cancellable Import Progress (2026-05-08-Folgecommit)

Phase-10A-Folge des Deep Audits. Der Store-Importpfad ist jetzt **kooperativ abbrechbar** und meldet **throttled-Progress**, ohne den Legacy-Pfad zu berühren und ohne den Default-Aktivierungsstand zu ändern.

- **Datenmodell:** `LocalTimelineImportProgress` (Foundation-only, Sendable, value-type) hält Phase, Counter (`entriesProcessed/visitsWritten/activitiesWritten/pathsWritten/skippedEntries`), optionale Byte-Hints, `currentDay`, `startedAt/updatedAt`, `isCancellable`. **Keine Standortdaten** im Snapshot. Phasen: `idle`/`preparing`/`sniffing`/`importing`/`finalizing`/`completed`/`cancelled`/`failed`.
- **Throttle:** `LocalTimelineImportProgressThrottle` (Default 500 Entries) emittiert immer auf Phase-Change und in terminalen Phasen; pro-Byte- und pro-Entry-Spam ist ausgeschlossen.
- **Cancel-Token:** `LocalTimelineImportCancellation` — NSLock-guarded, idempotent, kein globaler State; API `cancel()`, `isCancelled`, `checkCancellation() throws`. Fehler `LocalTimelineImportCancellationError.cancelled`.
- **Importer-Wiring:** `GoogleTimelineStoreImporter.importFromFile/Data` akzeptiert ein optionales `Hooks(progress:throttle:cancellation:clock:)`-Tupel. Cancellation wird **vor Stream-Start, vor jedem Entry, vor Finalize** geprüft. Bei Cancel rollt der Writer (`LocalTimelineImportWriter.cancel()` → SQLite `ROLLBACK`) zurück. **Es bleibt kein gültiger Teilimport im Store** (Test: `testCancelMidStreamRollsBackTransaction`).
- **Loader/AppFlow:** `AppContentLoader.loadImportedContentEnvelope` und `LH2GPXAppFlow.loadImportedFileEnvelope` reichen `importProgress` und `importCancellation` durch. Cancel-Outcome im AppFlow: `EnvelopeImportOutcome.failure(title: "Import cancelled", clearBookmark: false)`. Loader-Fehler: `AppContentLoaderError.importCancelled(_:)`.
- **Service-Layer:** `LocalTimelineImportController` bündelt Token + Sink + `latestProgress` + Observer-API für UI/Tests. Foundation-only, keine SwiftUI-Bindung.
- **Bewusst nicht angefasst:** Der Legacy-Pfad (`loadImportedContent(from:)` für LH2GPX-JSON / GPX / TCX / nicht-eindeutige ZIPs) bleibt unverändert — Progress dort wäre unverhältnismäßig breit für eine kleine Änderung. Default-Argumente halten alle bestehenden Aufrufer source-kompatibel; der Store-Pfad bleibt **pre-production / feature-flagged / default AUS**.
- **Skipped-Semantik:** Importer-Skips (Entry ohne erkannten Payload, malformed `timelinePath`) und Writer-Skips (Entry mit unparseable Timestamp) sind disjunkt — der finale `skippedEntries`-Counter im Snapshot ist die Summe beider.
- **UI-Anbindung offen:** SwiftUI-Hook in Wrapper/AppShell/Landing ist **nicht** Teil dieses Commits. Service-API für die Folge-UI: `LocalTimelineImportController().{cancellation, progressSink, cancel(), latestProgress, addObserver}`. Siehe `NEXT_STEPS.md` und `docs/DEEP_AUDIT_2026-05-08_LOCAL_TIMELINE_STORE_AND_MAP.md` § 13.

**46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim). **Kein ASC/Review/TestFlight/Hardware-Pass behauptet.** **Keine neue Map-Phase**, **kein neuer Activator**.

## Build-158-Vorbereitung — Aktivierungsquellen erweitert (2026-05-08)

Build 157 ist Xcode Cloud grün und TestFlight-installierbar (Status „Überprüft", interne Tests erfolgreich). Da TestFlight-Tester keine Launch-Argumente / Environment-Variablen setzen können, ist die Aktivierungsstrecke des LocalTimelineStore-Pfads ab dieser Iteration **dreigleisig** (im OR-Sinn — Setting aktiviert zusätzlich, deaktiviert nichts):

1. **Launch-Argument** (lokale Xcode-Runs primär): `LH2GPX_LOCAL_TIMELINE_STORE`, `--LH2GPX_LOCAL_TIMELINE_STORE`, `LH2GPX_LOCAL_TIMELINE_STORE=1`/`true`/`yes`/`on` (case-insensitive).
2. **Environment-Variable** (lokale Xcode-Runs primär): identische Schreibweisen über `ProcessInfo.environment`.
3. **NEU UserDefaults-Toggle** (TestFlight-Strecke): Key `LH2GPX.localTimelineStoreTestModeEnabled` (Bool, default `false`), persistiert über `LocalTimelineTechnicalTestSettings` (`final class` ObservableObject, `.shared` + `init(userDefaults:)`). Sichtbar in `AppTechnicalOptionsView` → "Internal Test Toggles". **Nur Bool** im Key — keine Standortdaten/Pfade/Tokens.

Resolver-Overloads: `LocalTimelineFeatureFlags.resolve(arguments:environment:settings:)` und `LocalTimelineFeatureFlags.resolveFromProcess(settings:)`. **Args/ENV bleiben primärer Aktivator**; das Setting aktiviert zusätzlich. Default OFF unverändert; Source-kompatibel via Default-Argument (kein Bruch für bestehende Aufrufer). Analog für `ImportMemoryProbe`: neuer Pure-Overload `isEnabledForEnvironment(_:arguments:settings:)`; runtime-`isLoggingEnabled` ist computed → Toggle wirkt ohne Relaunch. Tests: `LocalTimelineTechnicalTestSettingsTests.swift` (12 Linux-grüne Cases) inkl. `testOnlyBoolsAreStoredUnderToggleKeys` (Bool-only-Pflicht). **Toggle ist interner Testmodus / Pre-production**, Store-Pfad bleibt **default AUS**, Default-Rollout bleibt Legacy-AppExport. **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim). **Keine ASC/Review/Hardware-Freigabe behauptet**, **keine Map-Phase-10B-Aussage.**

## Phase-10A-Spike Snapshot (2026-05-08)

- **Eingecheckt**: feature-flagged Store-**DayMap-UI-Surface** in der bestehenden `LocalTimelineDayDetailView`. Surface bleibt **Spike / pre-production hinter Feature-Flag**; Store-Pfad **default AUS** (`LH2GPX_LOCAL_TIMELINE_STORE` unverändert). **Vollständige sichtbare Kartenmodernisierung wird nicht behauptet.** Legacy-Map unverändert.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayMapViewState.swift` — Foundation-only Presentation Model. Typen: `LocalTimelineDayMapViewState`, `LocalTimelineDayMapSource`, `Budget` (default **12 Routen / 256 Punkte pro Route / 4096 Punkte gesamt**, harte Grenzen pro Route + pro Tag). **Bounded reads**: Candidate-Load liest ausschließlich path metadata; Geometrie ausschließlich für selektierte pathIDs lazy decodiert.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayMapView.swift` — SwiftUI Placeholder (`#if canImport(SwiftUI)`-guarded). **KEIN MapKit-Import.** Echte `MKMapView`-/`MKMultiPolyline`-Verdrahtung bleibt explizit **Phase-10B Mac/Xcode-Pflicht**.
- **Geändert** `LocalTimelineDayDetailView` — neue optionale Map-Sektion. Sektion wird nur sichtbar wenn `mapSource != nil` und Pfad-Metadaten existieren. "Load map"-Button startet bounded Candidate-Load **ohne `coord_blob`-Decodierung**; "Decode all routes" toggelt bounded Geometrie-Decode innerhalb `Budget`.
- **Geändert** `LocalTimelineSessionLandingView` — reicht neuen optionalen `dayMapSource` durch.
- **NEU** `LH2GPXAppFlow.makeProductionDayMapSource(for:)` — production Source-Factory; öffnet eigenen Reader auf `session.storeURL`, bindet `StoreBackedMapDataProvider`, nutzt Visit-Koordinaten als Bounds-Fallback.
- **Geändert** `Sources/LocationHistoryConsumerApp/AppShellRootView.swift` und `wrapper/LH2GPXWrapper/ContentView.swift` — reichen neue Source ans Landing-View durch.
- **NEU Tests** `Tests/LocationHistoryConsumerTests/LocalTimelineDayMapViewStateTests.swift` (7), `LocalTimelineDayMapBoundsTests.swift` (4) — alle Linux-grün.
- **Bounded-Read-Garantien Phase 10A**:
  - Candidates lesen ausschließlich path metadata (kein `coord_blob`-Decodierung).
  - Geometrie ausschließlich für selektierte pathIDs lazy decodiert.
  - Harte Budgets pro Route (256 Punkte) **und** pro Tag (4096 Punkte total, 12 Routen).
  - Bounds primär aus path metadata (union der bbox-Spalten); Fallback auf Visit-Koordinaten via Closure; leerer Tag → `bounds == nil`.
  - Malformed `coord_blob` → kontrollierter `LocalTimelineMapProviderError.malformedCoordBlob` ohne Crash.
  - Anti-Meridian-Behandlung bleibt **Phase 10B/11** (direktes min/max-Reduce).
- **Harte Grenzen Phase 10A (verbatim)**:
  - Feature-flagged Store-DayMap-UI-Surface — kein Default-Rollout.
  - **KEIN MapKit-Import** in der Phase-10A-View; echte `MKMapView`-Verdrahtung bleibt **Phase-10B Mac/Xcode-Pflicht**.
  - **KEINE vollständige sichtbare Kartenmodernisierung.**
  - **KEIN eager `coord_blob`-Decoding** beim Candidate-Load.
  - Legacy-Map unverändert.
  - **KEIN AppExport-Rebuild aus Store.**
  - **KEIN vollständiger `[Double]`-Import-Buffer.**
  - **KEIN Live-Upload-Mix.**
  - **KEINE neuen externen Dependencies.**
  - **KEINE Hardware-/AppStore-/TestFlight-/ASC-Aussage.**
  - **KEINE Darwin-FileProtection-Aktivierung** (bleibt offene Phase-10B/11-Pflicht).
  - **KEIN RTree** (bleibt deferred, TEXT path-IDs).
  - Heatmap-UI / Overview-UI / Export-UI / Darwin FileProtection / Hardware-Retest / TestFlight bleiben **Phase-10B/11-Pflicht**.
  - **46-MB-Gate bleibt FAILED / pending hardware retest.**
- **Offene Phase-10B/11-Pflichten** (vor produktivem Default-Rollout): echte MapKit-/`MKMapView`-/`MKMultiPolyline`-Verdrahtung der Phase-10A-Placeholder-View (Mac/Xcode-Pflicht; Anti-Meridian); Heatmap-/Overview-UI-Hook gegen `StoreBackedHeatmapDataProvider`; Export-UI-Hook gegen `StoreBackedExportWriter`; Darwin FileProtection-Aktivierung; 46-MB-Hardware-Retest; RTree `path_bounds` (Schema-breaking, deferred); Privacy-Doku-Update; Store-Default-Rollout; TestFlight/Xcode-Cloud Build ≥100.

---

## Phase-9B-Spike Snapshot (2026-05-08)

- **Eingecheckt**: feature-flagged Store-**DayList + DayDetail-UI** über die bestehende `LocalTimelineSessionLandingView`. Surface bleibt **Spike / pre-production hinter Feature-Flag**; Store-Pfad **default AUS** (`LH2GPX_LOCAL_TIMELINE_STORE` unverändert).
- **Geändert** `AppSessionState` — neues Feld `selectedLocalTimelineDayId: String?` + Mutator `selectLocalTimelineDay(_:)`. Wird in `show(localTimeline:)`, `show(content:)` und `clearContent()` mitgenullt.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayBrowserSource.swift` — Foundation-only Source-Struct + `bind(session:reader:)` Convenience für die View-Hooks. **Bounded — kein `coord_blob`, keine Polylines.**
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayListView.swift` (`#if canImport(SwiftUI)`-guarded) — Tage newest-first mit Datum / Routen / Visits / Distanz. **Kein Map-Hook.**
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayDetailView.swift` (`#if canImport(SwiftUI)`-guarded) — Datum + Visits + Activities + Path-Metadaten + Hinweis "Path points available (not decoded)". **Kein eager `coord_blob`-Decoding, keine Map.**
- **NEU** `LH2GPXAppFlow.makeProductionDayBrowserSource(for:)` — production Source-Factory; öffnet `LocalTimelineStore` an `session.storeURL`.
- **Geändert** `LocalTimelineSessionLandingView` — erweitert um optionales `dayBrowser`/`selectedDayId`/`onSelectDay`. Bei aktiv: rendert Liste + sheet-basierte Detail-Navigation (NavigationStack im sheet). **Backward-kompatibel** (defaults nil).
- **Geändert** Wrapper (`wrapper/LH2GPXWrapper/ContentView.swift`) und Package-AppShell (`Sources/LocationHistoryConsumerApp/AppShellRootView.swift`) reichen `LH2GPXAppFlow.makeProductionDayBrowserSource(for: storeSession)` + Selection-Binding durch.
- **NEU Tests** `Tests/LocationHistoryConsumerTests/LocalTimelineDayBrowserSourceTests.swift`, `LocalTimelineSelectionStateTests.swift`.
- **Harte Grenzen Phase 9B (verbatim)**:
  - **KEIN Map-/Heatmap-/Overview-UI-Hook gegen Store.**
  - **KEIN AppExport-Rebuild aus Store.**
  - **KEIN vollständiger `[Double]`-Import-Buffer.**
  - **KEIN eager `coord_blob`-Decoding** in DayList/DayDetail.
  - **KEIN Default-Rollout** — Store-Pfad bleibt feature-flagged, default AUS.
  - **KEIN Live-Upload-Mix.**
  - **KEINE neuen externen Dependencies.**
  - **KEINE Hardware-/AppStore-/TestFlight-Aussage.**
  - **KEINE Darwin-FileProtection-Aktivierung** (bleibt offene Phase-10-Pflicht).
  - **KEIN RTree** (bleibt deferred, TEXT path-IDs).
  - **46-MB-Gate bleibt FAILED / pending hardware retest.**
- **Phase-9 done** (DayList/DayDetail-UI ist erledigt; Map/Heatmap/Overview bleibt offen).
- **Offene Phase-10-Pflichten** (vor produktivem Default-Rollout, Stand vor Phase 10A): Map/Heatmap/Overview UI-Hook gegen Provider; Darwin FileProtection-Aktivierung; 46-MB-Hardware-Retest; RTree `path_bounds` (Schema-breaking, deferred); Privacy-Doku-Update; Store-Default-Rollout; Export-UI-Hook; TestFlight/Xcode-Cloud Build ≥100. **Update**: Store-DayMap-UI-Surface (Foundation-only Presentation Model + SwiftUI Placeholder, kein MapKit-Import) ist in Phase 10A erledigt; echte MapKit-Verdrahtung bleibt Phase-10B Mac/Xcode-Pflicht.

---

## Phase-9A-Spike Snapshot (2026-05-08)

- **Eingecheckt**: Wrapper/AppFlow-Wiring + Settings-Delete-Button + Landing-View für aktive Store-Session. Surface bleibt **Spike / pre-production hinter Feature-Flag**; Store-Pfad **default AUS** (`LH2GPX_LOCAL_TIMELINE_STORE` unverändert).
- **NEU** `LH2GPXAppFlow.apply(envelopeOutcome:to:preserveOnFailure:) -> AppliedEnvelopeRouting` — geteilte Linux-testbare Routing-Helper-Funktion für Wrapper und Package-AppShell. Routet `.legacy(content)` → `session.show(content:)`, `.localTimeline(LocalTimelineSession)` → `session.show(localTimeline:)`, `.failure` mit optionaler Bookmark-Preservation.
- **NEU** `LH2GPXAppFlow.makeProductionDeletionPresentation()` — Convenience für Settings/Technical-Hosts.
- **Geändert** `wrapper/LH2GPXWrapper/ContentView.swift` + `Sources/LocationHistoryConsumerApp/AppShellRootView.swift` — beide nutzen jetzt `loadImportedFileEnvelope(...)` und routen über `apply(...)`.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineSessionLandingView.swift` (`#if canImport(SwiftUI)`-guarded) — Landing-View bei aktiver `localTimelineSession` mit Session-Metadaten + Lösch-Button; **kein `coord_blob`-Read, kein Map/Heatmap/Overview-Hook**; eingebunden in beiden App-Shells via body-Branch `else if let storeSession = session.localTimelineSession`.
- **Geändert** `AppTechnicalOptionsView` (in `AppOptionsView.swift`) — neue Section "Local Timeline Store" mit Feature-Flag-Status (`LocalTimelineFeatureFlags.resolveFromProcess()` Enabled/Disabled), Status-Zeile "Pre-production / Feature-flagged" und Lösch-Button "Delete imported local data" mit kontrollierten States idle/running/succeeded/failed.
- **NEU Tests** `Tests/LocationHistoryConsumerTests/WrapperLocalTimelineEnvelopeRoutingTests.swift` (6 Cases, Linux-grün): legacy/localTimeline/failure(clearBookmark T/F)/Replace-Invariante in beide Richtungen.
- **Harte Grenzen Phase 9A (verbatim)**:
  - **KEIN Map-/Heatmap-/Overview-UI-Hook gegen Store.**
  - **KEIN AppExport-Rebuild aus Store.**
  - **KEIN vollständiger `[Double]`-Import-Buffer.**
  - **KEIN Default-Rollout** — Store-Pfad bleibt feature-flagged, default AUS.
  - **KEIN Live-Upload-Mix.**
  - **KEINE neuen externen Dependencies.**
  - **KEINE Hardware-/AppStore-/TestFlight-Aussage.**
  - **KEINE Darwin-FileProtection-Aktivierung** (bleibt offene Phase-9-Pflicht).
  - **KEIN RTree** (bleibt deferred, TEXT path-IDs).
  - **46-MB-Gate bleibt FAILED / pending hardware retest.**
  - Settings-DayList/DayDetail UI nur als Landing-View für Store-Session sichtbar; vollständige Store-DayList/DayDetail-UI bleibt **Phase 9B**.
- **Trennung Service/Presentation-testbar vs UI-aktiv**: Routing-Helper + Settings-Delete-Button + Landing-View sind **UI-aktiv hinter Feature-Flag**; vollständige Store-DayList/DayDetail/Map/Heatmap/Overview-Surfaces bleiben **nicht UI-aktiv**.
- **Offene Phase-9-Pflichten** (nach 9A): Phase 9B Store-DayList/DayDetail UI; Map/Heatmap/Overview UI-Hook gegen Provider; RTree `path_bounds` (Schema-breaking); Darwin FileProtection-Aktivierung; Export-UI-Hook; 46-MB-Hardware-Retest; TestFlight/Xcode-Cloud Build ≥100; App-Flow-Umschaltung gegen Conditional-Gate; Privacy-Doku-Update.

---

Status: **Research + Phase 1..9A abgeschlossen** (CoordBlob + isolierter SQLite-Store + Storage-Lifecycle + store-backed Streaming-Export + feature-flagged AppSession-Quelle + feature-flagged AppContentLoader-Hook über Envelope-Kapsel + Foundation-only Presentation/ViewState-Schicht + AppSessionState-Extension + Service-layer Envelope-Hook im AppFlow + Foundation-only Store-backed Map Data Provider mit bounded Map-Domain-Modellen, stride-/budget-basiertem Route-Decimator und zwei additiven bbox-Metadata-Indizes + **Heatmap-Doppelbug-Fix zentral via `AppHeatmapPathSampler` + `derived_cache`-Tabelle (additiv, FK CASCADE) + Foundation-only Heatmap-Modelle + deterministischer Grid-Aggregator + Foundation-only Store-backed Heatmap Data Provider mit bounded Sampling, Grid-LOD-Aggregation und cache-backed Roundtrip**, **nicht produktiv genutzt**, keine UI-/App-Flow-Umschaltung, **kein SwiftUI-Map/MKMapView-Hook**). Folge-Commit nach `45e5fcf`.

### Phase-10A P1-A/B (Weg 2) Snapshot (2026-05-08) — UI-Hook umgesetzt
- Progress/Cancel-UI sichtbar verdrahtet in beiden App-Shells (Package-AppShell + Wrapper-Xcode-App).
- Pro Import frischer LocalTimelineImportController über LocalTimelineImportUIState.startNewImport().
- Cancel-Flow: Button → controller.cancel() → Importer cancellation → Writer rollback → bestEffortTruncateWAL → .failure(title="Import cancelled"). Keine Teilimports, Reimport bestätigt durch Linux-Test.
- Store-Pfad weiterhin pre-production / feature-flagged / default AUS. 46-MB-Hardware-Gate weiterhin FAILED / pending hardware retest.

## Phase-8B-Spike Snapshot (2026-05-08)

> **Doku-Sync 2026-05-08 — `fix: resolve xcode heatmap grid key compile failure`**: Phase-8B-Heatmap-Aggregator-Status: `Sources/LocationHistoryConsumerAppSupport/LocalTimelineHeatmapGridAggregator.swift` benennt seinen file-scope `GridKey` → `LocalTimelineHeatmapGridKey` (privat, file-scope), weil die top-level `private struct GridKey { let lat: Int; let lon: Int }` mit dem ebenfalls top-level `struct GridKey { let lat: Int32; let lon: Int32 }` aus `Sources/LocationHistoryConsumerAppSupport/HeatmapGridBuilder.swift` (hinter `#if canImport(MapKit) && canImport(SwiftUI)`) auf Apple-Plattformen kollidierte und Xcode Cloud Builds 155 (`06f81ae`) und 156 (`5cb7783`) im Workflow „Release – Archive & TestFlight" mit Exit Code 65 hat scheitern lassen („Invalid redeclaration of 'GridKey'" + „ambiguous for type lookup" + „Cannot convert value of type 'Int' to expected argument type 'Int32'" auf Zeile 79 des Aggregators). **Heatmap-Logik unverändert. Keine API-Änderung. Keine UI-Änderung. Aggregator-Determinismus, Cell-Size-Tabelle, `maxCells`/`maxSamplesConsumed`-Grenzen, stabile Sortierung, Cache-Codec, `derived_cache`-Schema sind nicht angefasst.** Linux-SwiftPM weiter grün; `swift test` voll grün nach Fix. Xcode Cloud Retest pending — keine Aussage über echte Apple-Builds. **46-MB-Gate bleibt FAILED / pending hardware retest** unverändert. Store-Pfad bleibt default AUS, pre-production. Keine Map-Phase-10B-Aussage; Phase 8B-Hardgrenzen unverändert.

- **Eingecheckt**: Heatmap-Doppelbug-Fix zentral via Foundation-only Helper + `derived_cache`-Tabelle (additiv, FK CASCADE auf `imports.id`) + Foundation-only Heatmap-Modelle + deterministischer Grid-Aggregator + Foundation-only Store-backed Heatmap Data Provider mit bounded Sampling, Grid-LOD-Aggregation und cache-backed Roundtrip. **Schema bleibt `userVersion = 2`** — die neue Tabelle `derived_cache` und ihre zwei Indizes (`idx_derived_cache_import_kind_key`, `idx_derived_cache_kind_created`) sind **rein additiv** (`CREATE TABLE/INDEX IF NOT EXISTS`); keine semantische Schema-Änderung. RTree-`path_bounds` virtuelle Tabelle bleibt **kontrolliert deferred** (Begründung unten).
- **NEU `Sources/LocationHistoryConsumer/AppHeatmapPathSampler.swift`**: Foundation-only Helper. Kanonische Priorität: `flatCoordinates` (wenn vorhanden und gerade Element-Anzahl), sonst `points` Fallback. Ungerade `flatCoordinates` gelten als malformed → kontrollierter Fallback auf `points` (dokumentierte Entscheidung).
- **Geändert `Sources/LocationHistoryConsumer/AppHeatmapModel.swift`**: Zeilen 55-77 nutzen jetzt `AppHeatmapPathSampler` statt der bisherigen Doppel-Iteration über `path.points` UND `path.flatCoordinates`. **Heatmap-Doppelbug ist ab Phase 8B zentralisiert gefixt** (im `docs/MAP_ARCHITECTURE_AUDIT.md` §2 dokumentiert).
- **NEU `Sources/LocationHistoryConsumerAppSupport/LocalTimelineHeatmapModels.swift`**: Foundation-only Modelle: `LocalTimelineHeatmapSample`, `LocalTimelineHeatmapSampleResponse`, `LocalTimelineHeatmapGridCell`, `LocalTimelineHeatmapLODResponse`, `LocalTimelineHeatmapCacheKey`, `LocalTimelineHeatmapCacheEncoding`. **Keine SwiftUI-/MapKit-/CoreLocation-Abhängigkeit.**
- **NEU `Sources/LocationHistoryConsumerAppSupport/LocalTimelineHeatmapGridAggregator.swift`**: deterministischer Grid-Aggregator. Cell-Size je Detail-Level (`overview` 0.5°, `low` 0.1°, `medium` 0.02°, `high` 0.005°). Hartes `maxCells` und `maxSamplesConsumed` Limit. Stabile Sortierung (lat asc, lon asc).
- **NEU `Sources/LocationHistoryConsumerAppSupport/StoreBackedHeatmapDataProvider.swift`**: Foundation-only Provider, kanonische Schnittstelle für künftige Heatmap-UI-Hooks.
  - `heatmapSamples(importID:viewport:maxRoutes:maxPointsPerRoute:maxSamples:)` — **bounded sampling**, doppelt bounded (`maxRoutes` × `maxPointsPerRoute`) und total-bounded durch `maxSamples`. Pro Pfad **lazy** dekodiert via `CoordBlobIterator`; malformed `coord_blob` wird kontrolliert übersprungen.
  - `heatmapLOD(importID:viewport:options:)` — Grid-Aggregation, **optional cache-backed via `derived_cache`**. Cache-Key über `LocalTimelineHeatmapCacheKey.make(...)` mit 1e-3°-Quantisierung. Cache-Payload-Codec deterministisch (Magic `'L8B1'`, little-endian).
  - `clearHeatmapCache(importID:)` — Cache-Invalidierung.
- **Geändert `LocalTimelineStoreSchema.swift`**: neue **additive** Tabelle `derived_cache` (`id`, `import_id`, `kind`, `key`, `payload`, `created_at`) mit FK auf `imports.id` und `ON DELETE CASCADE`. Zwei neue Indizes `idx_derived_cache_import_kind_key` und `idx_derived_cache_kind_created`. `userVersion` unverändert auf `2` (rein additiv).
- **Geändert `LocalTimelineStore.swift`**: neue CRUD-APIs `putDerivedCache(...)`, `derivedCache(...)`, `deleteDerivedCache(...)`, `countDerivedCache(...)`. `deleteAll()` löscht jetzt zusätzlich auch `derived_cache`-Zeilen.
- **Tests Linux-grün**, 4 Dateien:
  - `AppHeatmapModelGeometryTests.swift` (7 Cases) — Sampler-Priorität flat-vor-points, ungerade flatCoordinates → fallback points, Doppelbug-Regression.
  - `LocalTimelineHeatmapGridAggregatorTests.swift` (7 Cases) — deterministische Sort, Cell-Size pro Detail-Level monoton, `maxCells`/`maxSamplesConsumed` hard, leere/1-Sample stabil.
  - `StoreBackedHeatmapDataProviderTests.swift` (11 Cases) — 50k synthetic store bounded sampling, cache hit/miss roundtrip, `clearHeatmapCache` Invalidierung, malformed `coord_blob` skip, viewport-Filter, options-quantisierung.
  - `LocalTimelineRTreeCapabilityTests.swift` — dokumentiert RTree-Fallback (`paths.id` TEXT vs RTree INTEGER `docid`).
- **Bounded-Read-Garantien (Phase-8B-Erweiterung der Phase-8A-Garantien 1-6)**:
  7. `heatmapSamples` ist viewport-gebunden, **doppelt bounded** durch `maxRoutes` × `maxPointsPerRoute` und total-bounded durch `maxSamples`.
  8. Pro Pfad wird **lazy** dekodiert via `CoordBlobIterator`; nie vollständige Import-Geometrie im RAM.
  9. `heatmapLOD` aggregiert nur die bounded Samples; Cache-Payload trägt **Zellen, keine Roh-Punkte**.
  10. `derived_cache` ist als abgeleitete Cache-Tabelle vom Import-Lifecycle abhängig (FK CASCADE) und über `clearHeatmapCache(importID:)` invalidierbar.
- **RTree-Fallback-Begründung (kontrolliert deferred)**: Pfad-IDs in `paths` sind TEXT (`paths.id TEXT PRIMARY KEY`); SQLite RTree erwartet INTEGER `docid`. Ein Surrogate-Integer-Mapping wäre Schema-breaking (alle bestehenden Foreign Keys müssten umgestellt werden). Bbox-Index-Scan aus Phase 8A (`idx_paths_bounds_minmax`, `idx_paths_day_bounds`) bleibt aktiv und liefert linearen scan mit Index-Cover. `LocalTimelineRTreeCapabilityTests.swift` dokumentiert den Fallback.
- **Harte Grenzen Phase 8B**:
  - **KEIN SwiftUI-Map/MKMapView-Hook.**
  - **KEIN UI-Heatmap-Renderer-Hook** (existierender SwiftUI-Heatmap-Renderer unverändert; konsumiert weiter `AppExport`).
  - **KEIN AppExport-Rebuild aus Store.**
  - **KEIN vollständiger `[Double]`-Import-Buffer.**
  - **KEIN Live-Upload-Mix.**
  - Store-Pfad bleibt **default AUS** / pre-production.
  - Feature-Flag `LH2GPX_LOCAL_TIMELINE_STORE` unverändert.
  - Schema additiv, **`userVersion` unverändert 2/2**.
  - FileProtection-Status unverändert (Phase-4-Capsule).
  - **46-MB-Gate bleibt FAILED / pending hardware retest** (Wortlaut verbatim aus `docs/APPLE_VERIFICATION_CHECKLIST.md`).
  - Keine Hardware-/ASC-/TestFlight-Aussage.
- **Bewusst nicht in Phase 8B** (= Phase 9 vor produktivem UI-Rollout):
  - **RTree (`path_bounds` virtual table)** — würde Surrogate-Integer-Mapping erfordern (Schema-breaking).
  - Wrapper/SwiftUI-Wiring (DayList/DayDetail/Map/Heatmap/Overview/Export/Settings) — Phase 9.
  - Settings-Delete-UI-Button — Phase 9.
  - Map/Heatmap/Overview UI-Hook gegen Provider — Phase 9.
  - **Darwin FileProtection-Aktivierung** — offene Pflicht vor Rollout.
  - Export-UI-Hook gegen `StoreBackedExportWriter` — Phase 9.
  - 46-MB-Hardware-Retest, TestFlight/Xcode-Cloud — Mac/iPhone-Handoff, FAILED unverändert.
  - Privacy-Doku-Update — vor Rollout zwingend.

## Phase-8A-Spike Snapshot (2026-05-08)

- **Eingecheckt**: Foundation-only Store-backed Map Data Provider + bounded Map-Domain-Modelle + Route-Decimator + zwei additive bbox-Indizes auf `paths`. **Schema bleibt `userVersion = 2`** — die zwei neuen Indizes `idx_paths_bounds_minmax` und `idx_paths_day_bounds` sind **rein additiv** (`CREATE INDEX IF NOT EXISTS`). RTree-`path_bounds` virtuelle Tabelle bleibt explizit **Phase-8B-Pflicht** und wurde in dieser Phase **nicht** angelegt.
- **NEU `Sources/LocationHistoryConsumerAppSupport/LocalTimelineMapModels.swift`**: Foundation-only Map-Domain-Modelle.
  - `LocalTimelineMapViewport` — minLat/maxLat/minLon/maxLon, Anti-Meridian wird **kontrolliert abgelehnt** (kein wraparound silently), Validierung gegen flipped lat / out-of-range / minLon > maxLon.
  - `LocalTimelineMapDetailLevel` — `overview`/`low`/`medium`/`high`.
  - `LocalTimelineMapPointBudget` — default-Tabelle pro Level, monoton steigend; nutzbar als Hard-Cap im Decimator und im `overviewRoutes` Provider-Pfad.
  - `LocalTimelineMapQuery` — viewport + detailLevel + maxRoutes + budget.
  - `LocalTimelineMapRouteCandidate` — **metadata-only**, kein `coord_blob` im Record.
  - `LocalTimelineMapPoint` / `LocalTimelineMapRouteGeometry` — bounded points.
  - `LocalTimelineMapOverviewResponse` — Liste der Geometrien + `truncatedRoutes: Bool` + `truncatedPoints: Bool` (signalisieren, dass `maxRoutes` bzw. `budget.maxTotalPoints` getroffen wurde).
  - `LocalTimelineMapBounds`, `LocalTimelineMapProviderError`.
  - **Keine SwiftUI-/MapKit-/CoreLocation-Abhängigkeit** — Linux-buildbar.
- **NEU `Sources/LocationHistoryConsumerAppSupport/StoreBackedMapDataProvider.swift`**: Provider-Klasse, kanonische Schnittstelle für künftige UI-Hooks.
  - `routeCandidates(importID:viewport:limit:)` / `dayRouteCandidates(dayID:viewport:limit:)` — beide **metadata-only**, **kein `coord_blob`-Read**. Filtert nach Viewport-Overlap über `paths.min/max_lat/lon`-Spalten; NULL-Bounds werden konservativ als überlappend gewertet; newest-first `ORDER BY start_time`.
  - `routeGeometry(pathID:detailLevel:maxPoints:)` — **lazy single-path decode** via `CoordBlobIterator` durch `LocalTimelineRouteDecimator`; `maxPoints` hart; wirft `unknownPath` / `malformedCoordBlob` über `LocalTimelineMapProviderError`.
  - `overviewRoutes(query:)` — **doppelt bounded** durch `maxRoutes` UND `budget.maxTotalPoints`; setzt `truncatedRoutes`/`truncatedPoints` in der Response.
  - `mapBounds(forImportID:)` / `mapBounds(forDayID:)` — Aggregat über `paths.min/max_lat/lon`-Spalten; **kein Geometrie-Decode**.
- **NEU `Sources/LocationHistoryConsumerAppSupport/LocalTimelineRouteDecimator.swift`**: deterministischer stride-/budget-basierter Decimator, Iterator-basiert (`Sequence<EncodedCoordinate>`), erster + letzter Punkt erhalten, `maxPoints` hart, leere/1-Punkt-Pfade stabil. **Douglas-Peucker bleibt Phase 8B/9.**
- **Geändert `LocalTimelineStoreSchema.swift`**: zwei neue additive Indizes `idx_paths_bounds_minmax` und `idx_paths_day_bounds`. `userVersion` unverändert auf `2`. RTree (`path_bounds` virtual table) bleibt Phase-8B/9-Pflicht.
- **Geändert `LocalTimelineStore.swift`**: neue public APIs `pathMetadata(forImportId:viewportMinLat:viewportMaxLat:viewportMinLon:viewportMaxLon:limit:)`, `pathMetadata(forDayId:...:limit:)`, `pathBoundingBox(forImportId:)`, `pathBoundingBox(forDayId:)` plus Test-Helper `indexNames(forTable:)`. Bbox-Filter ist linearer bbox scan über `min/max_lat/lon`-Spalten, NULL-Bounds konservativ als überlappend gewertet, newest-first `ORDER BY start_time`.
- **Geändert `LocalTimelineStoreReader.swift`**: thin wrappers `pathMetadata(forImportId:viewport:limit:)`, `pathMetadata(forDayId:viewport:limit:)`, `pathBoundingBox(forImportId:)`, `pathBoundingBox(forDayId:)`.
- **Tests Linux-grün**, 4 Dateien, 33 Cases:
  - `StoreBackedMapDataProviderTests` (15) — inkl. 50k-synthetic-store-bounded-Test, malformed `coord_blob` → kontrollierter Fehler, unknown import returns empty, unknown path throws, viewport-Filter, day-scope, overview `maxRoutes`/`maxTotalPoints`.
  - `LocalTimelineRouteDecimatorTests` (8) — empty/1-point stable, small unchanged, `maxPoints` hard-cap, first+last preserved, `maxPoints=1`/`=2`, single-pass iterator.
  - `LocalTimelineMapBoundsTests` (7) — viewport valid/invalid (flipped lat / antimeridian / out of range), intersect classic/disjoint/null-bounds, point-budget defaults monoton.
  - `LocalTimelineMapSchemaIndexTests` (2) — fresh store hat beide Indizes; reopened-store nach `DROP` gewinnt sie additiv zurück; `userVersion` bleibt `2`.
- **Bounded-Read-Garantien (Phase-8A-Erweiterung der Phase-3-Garantien)**:
  1. `routeCandidates(importID:viewport:limit:)` / `dayRouteCandidates(dayID:viewport:limit:)` lesen **kein `coord_blob`**, nur path-Metadaten + bbox-Filter.
  2. `routeGeometry(pathID:detailLevel:maxPoints:)` decodiert **single-path lazy** via `CoordBlobIterator`, hart bounded durch `maxPoints` aus `LocalTimelineMapPointBudget`.
  3. `overviewRoutes(query:)` ist **doppelt bounded** durch `maxRoutes` UND `budget.maxTotalPoints`, schreibt `truncatedRoutes`/`truncatedPoints` in die Response.
  4. `mapBounds(forImportID:)` / `mapBounds(forDayID:)` aggregieren ausschließlich über `paths.min/max_lat/lon`-Spalten — **kein Geometrie-Decode**.
  5. **Kein API materialisiert `AppExport`** über den Provider.
  6. **Kein API materialisiert `[Double]`** für einen ganzen Import.
- **Harte Grenzen Phase 8A**:
  - **KEIN SwiftUI-Map/MKMapView-Hook in Phase 8A.**
  - **KEIN UI-Hook**, **kein Renderer-Wechsel**.
  - **KEIN AppExport-Rebuild aus Store.**
  - **KEIN vollständiger `[Double]`-Import-Buffer.**
  - **KEIN Live-Upload-Mix.**
  - Store-Pfad bleibt **default AUS** / pre-production.
  - Feature-Flag `LH2GPX_LOCAL_TIMELINE_STORE` unverändert.
  - Schema unverändert (`userVersion = 2`); Indizes rein additiv.
  - FileProtection-Status unverändert (Phase-4-Capsule).
  - **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim aus `docs/APPLE_VERIFICATION_CHECKLIST.md`).
  - Keine Hardware-/ASC-/TestFlight-Aussage.
- **Bewusst nicht in Phase 8A** (= Phase 8B/9 vor produktivem UI-Rollout):
  - **RTree (`path_bounds` virtual table)** für O(log n) Viewport-Intersect — **Phase-8B-Pflicht**, explizit deferred.
  - `derived_cache`, Heatmap-LOD-Persistenz — Phase 8B/9.
  - Wrapper/SwiftUI-Wiring (DayList/DayDetail/Map/Heatmap/Overview/Export/Settings) — Phase 8B/9.
  - Settings-Delete-UI-Button — Phase 8B/9.
  - Map/Heatmap/Overview UI-Hook gegen Provider — Phase 8B/9 (Provider ist ab jetzt die kanonische Schnittstelle, aber kein UI-Hook in 8A).
  - **Heatmap-Doppelbug-Fix** (`AppHeatmapModel.swift:55-77`) — **Phase-8B-Pflicht** (im `docs/MAP_ARCHITECTURE_AUDIT.md` bereits vermerkt; nicht behauptet, dass behoben).
  - Export-UI-Hook gegen `StoreBackedExportWriter` — Phase 8B/9.
  - **Darwin FileProtection-Aktivierung** — offene Pflicht vor Rollout.
  - 46-MB-Hardware-Retest, TestFlight/Xcode-Cloud — Mac/iPhone-Handoff, FAILED unverändert.
  - Privacy-Doku-Update — vor Rollout zwingend.

## Phase-7B-Spike Snapshot (2026-05-08)

- **Eingecheckt**: Foundation-only Presentation/Adapter-Schicht + `AppSessionState`-Extension + Service-layer Envelope-Hook im AppFlow. Schema unverändert (`userVersion = 2`). **Kein direktes UI-Wiring, kein Map/Heatmap/Overview/Export-UI-Hook, kein Wrapper/SwiftUI-Wiring.**
- **NEU `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayListViewState.swift`**: Foundation-only ViewState für Day-List-Surface über den Store-Pfad.
- **NEU `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayDetailViewStateAdapter.swift`**: Foundation-only Adapter, der Reader-Daten in eine bounded DayDetail-ViewState projiziert.
- **NEU `Sources/LocationHistoryConsumerAppSupport/AppSessionPresentationSource.swift`**: Presentation-Quelle inkl. `AppSessionState`-Extensions `activeContent` und `isLocalTimelineActive`.
- **NEU `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDeletionPresentation.swift`**: Presentation-Schicht über `LocalTimelineDeletionService`. Dokumentiert: **kein Bookmark-/Preferences-Cleanup nötig im Store-Pfad** (keine UserDefaults für Standortdaten).
- **Geändert `Sources/LocationHistoryConsumerAppSupport/LH2GPXAppFlow.swift`**: neue Methode `loadImportedFileEnvelope(...) -> EnvelopeImportOutcome` als feature-flagged Service-layer-Hook; **Legacy `loadImportedFile(...)` byte-identisch unverändert**.
- **Tests**: `LocalTimelineDayListViewStateTests`, `LocalTimelineDayDetailViewStateAdapterTests`, `AppSessionLocalTimelinePresentationTests`, `LocalTimelineDeletionPresentationTests`, `AppFlowLocalTimelineEnvelopeTests`.
- **Harte Grenzen Phase 7B**: Store-Pfad bleibt **default AUS** (`LH2GPX_LOCAL_TIMELINE_STORE`-Flag). **Kein UI-Hook (kein Wrapper/SwiftUI-Wiring). Kein Map/Heatmap/Overview/Export-UI-Hook.** **Kein AppExport im Store-Pfad materialisiert. Keine vollständige `[Double]`-Import-Materialisierung.** **FileProtection-Status unverändert** (Phase-4-Capsule, Aktivierung weiterhin Darwin/iOS-Pflicht). **46-MB-Gate bleibt FAILED / pending hardware retest unverändert.** **LocalTimelineStore weiterhin pre-production.** Live-Upload bleibt strikt getrennt. **Keine Standortdaten in UserDefaults.**
- **Bewusst nicht in Phase 7B** (= Phase 8 vor produktivem UI-Rollout):
  - Wrapper/SwiftUI-Wiring der Presentation-/ViewState-Schicht — deferred.
  - Map/Heatmap/Overview Provider, `derived_cache`+RTree+`path_bounds` — deferred.
  - Export-UI-Hook (Settings/Export-Tab) — deferred.
  - **Darwin FileProtection-Aktivierung** — offene Pflicht vor Rollout.
  - 46-MB-Hardware-Retest, TestFlight/Xcode-Cloud — Mac/iPhone-Handoff, FAILED unverändert.
  - Privacy-Doku-Update — vor Rollout zwingend.

## Phase-7A-Spike Snapshot (2026-05-08)

- **Eingecheckt**: feature-flagged AppSession/AppContentLoader-Hook über **Envelope-Kapsel** (statt Source-Enum-Mutation auf `AppSessionContent`). Schema unverändert (`userVersion = 2`).
- **NEU `Sources/LocationHistoryConsumerAppSupport/AppSessionContentSource.swift`**: Envelope-Enum mit Cases `inMemory(AppSessionContent)` und `localTimeline(LocalTimelineSession)`. **Kapsel-Approach** — `AppSessionContent` selbst wird **nicht** erweitert. Source-Enum-Verschmelzung in `AppSessionContent` ist explizit Phase-7B-Pflicht.
- **Geändert `AppSessionState.swift`**: neue Property `localTimelineSession: LocalTimelineSession?` plus neuer Mutator `show(localTimeline:)`. Banner/Title werden ausschließlich aus Session-Metadaten gelesen — **kein AppExport, keine Coord-Decode**. `show(content:)` und `clearContent()` setzen die neue Property mit zurück.
- **Geändert `AppContentLoader.swift`**: neuer Einstieg `loadImportedContentEnvelope(from:autoRestoreMode:onPhase:flags:storeFactoryProvider:) -> AppSessionContentSource`. **Bei deaktiviertem Feature-Flag exakt der Legacy-Pfad** → `.inMemory(...)` (byte-identisch). Bei aktivem Flag + Google-Timeline-JSON oder ZIP-mit-genau-einem-Timeline-Entry → `GoogleTimelineStoreImporter.importFromFile/Data` + `LocalTimelineSession.make(...)` → `.localTimeline(...)`. Andere Formate (LH2GPX-Objekt-JSON, GPX, TCX) fallen kontrolliert auf den Legacy-Pfad zurück. Neuer Error-Case `AppContentLoaderError.localTimelineStoreFailed(String)`. Importe sind additiv (frische `importId` pro Call); **Bulk-Wipe bleibt `LocalTimelineDeletionService`**.
- **Tests Linux-grün**: `AppSessionLocalTimelineSourceTests` (5), `AppContentLoaderLocalTimelineStoreTests` (5), `LocalTimelineFeatureFlagIntegrationTests` (4) — zusammen 14 Cases.
- **Harte Grenzen Phase 7A**: Store-Pfad ist **NICHT default** (Default-Rollout bleibt Legacy-AppExport); gated by feature flag. **Kein UI-Hook** für DayList/DayDetail/Map/Heatmap/Overview/Export/Settings. **Keine Map-Modernisierung. Keine Hardware-/ASC-/TestFlight-Aussagen.** **Kein 46-MB-Pass behauptet — 46-MB-Gate bleibt FAILED / pending hardware retest.** **LocalTimelineStore bleibt pre-production / Spike, nicht UI-aktiv.** Kein vollständiges `AppExport` im Store-Pfad. Keine vollständige `[Double]`-Import-Materialisierung im Store-Pfad. **Live-Upload bleibt strikt getrennt. Keine Standortdaten in UserDefaults.**
- **Bewusst nicht in Phase 7A** (= Phase 7B vor UI-Hook):
  - `AppSessionContent`-Source-Enum-Verschmelzung (statt Envelope) — bewusst deferred.
  - DayList/DayDetail/Map/Heatmap/Overview-UI-Hooks — deferred.
  - Settings-UI „Importierte Daten löschen" — deferred.
  - `derived_cache`/RTree `path_bounds` — deferred.
  - **Darwin FileProtection-Aktivierung** — offene Pflicht vor Rollout.
  - 46-MB-Hardware-Retest — Mac/iPhone-Handoff, FAILED unverändert.
  - Privacy-Doku-Update — vor Rollout zwingend.

## Phase-2-Spike Snapshot (2026-05-08)

- **Eingecheckt**: Schema-Bump `userVersion` **1 → 2** mit neuen Tabellen `visits` und `activities` + Indizes (`idx_days_import_date`, `idx_paths_day_start`, `idx_visits_day_id`, `idx_activities_day_id`). Migration ist additiv (`CREATE TABLE/INDEX IF NOT EXISTS`); v1-DBs werden beim Re-Open transparent angehoben (Test `LocalTimelineStoreLifecycleTests.testMigrationFromSimulatedV1KeepsExistingRowsAndAddsNewTables`).
- **NEU `LocalTimelineImportWriter`**: gehaltene `BEGIN IMMEDIATE … COMMIT/ROLLBACK`-Transaktion, bounded per-day-Aggregat (`(dayId, routeCount, visitCount, distanceM)` pro Datum), Day-Summaries werden im `finalize()` per `UPDATE` geschrieben. Ungültige Entries werden gezählt und übersprungen; `LocalTimelineImportSummary` exponiert `totalEntries`/`skippedEntries`/`dayCount`. Activities mit gültigem `start`+`end` erzeugen automatisch einen 2-Punkt-Pfad in `paths.coord_blob`.
- **NEU `GoogleTimelineStoreImporter`**: `importFromFile`/`importFromData` orchestrieren `GoogleTimelineStreamReader` → Writer. **Materialisiert kein `AppExport`** — durch `testImporterReturnTypeIsSummaryNotAppExport` typgesichert. Visit/Activity/timelinePath-Dispatch analog zur bestehenden `GoogleTimelineConverter.ExportBuilder`-Semantik.
- **`LocalTimelineStore.deleteAll()`**: löscht in einer einzigen Transaktion alle Zeilen aus `activities`/`visits`/`paths`/`days`/`imports`. Idempotent (nicht-throwing auf leerer DB). **Scope explizit DB-only** — Caches/tmp werden in Phase 3 vor UI-Hook ergänzt; das ist im Doc-Kommentar der API und in NEXT_STEPS festgehalten.
- **Linux-Tests grün**: `LocalTimelineStoreLifecycleTests` (6), `LocalTimelineImportWriterTests` (4), `GoogleTimelineStoreImporterTests` (4) inkl. 50k-Visit-Smoke über 50 Tage. `swift test` 1071/2/0 (+14 vs. 1057).
- **Bewusst nicht in Phase 2**:
  - FileProtection-Flag an `sqlite3_open_v2` (iOS-Header).
  - `applicationSupportDirectory/LocationHistory2GPX/Imports/` als produktiver Pfad mit `isExcludedFromBackupKey = true`.
  - Caches/tmp-Lifecycle in `deleteAll()`.
  - Adapter zu `flatCoordinates`-Konsumenten (DayList/DayDetail/Map/Heatmap/Distance/Export).
  - `derived_cache`, RTree `path_bounds`.
  - App-Flow-Umschaltung gegen Conditional Gate.
- **Conditional Gate unverändert**: P0 falls 46-MB-Retest FAILED, P1/P2 falls PASSED. **46-MB-Crashfall bleibt FAILED / pending hardware retest.**

---

## Phase-3-Spike Snapshot (2026-05-08)

- **Eingecheckt**: `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStoreReadModels.swift` und `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStoreReader.swift`. Schema unverändert (`userVersion = 2`).
- Foundation-only Read-Models: `LocalTimelineImportRecord`, `LocalTimelineDayRecord`, `LocalTimelineVisitRecord`, `LocalTimelineActivityRecord`, `LocalTimelinePathRecord` (NUR Metadaten, KEIN `coord_blob` im Record), `LocalTimelineDayDetailSnapshot` (day + visits + activities + paths-METADATEN).
- Read-Adapter `LocalTimelineStoreReader` mit Bounded-Read-APIs:
  - `imports()`, `importRecord(id:)`, `latestImport()`
  - `days(forImportId:)`, `dayRecord(id:)`, `dayRecord(forImportId:date:)`, `dayCount(forImportId:)`
  - `dayDetail(dayId:) -> LocalTimelineDayDetailSnapshot?` — bündelt day + visits + activities + path-METADATA (KEINE Coord-Decodierung)
  - `paths(forDayId:)`, `pathRecord(id:)`
  - `coordinateSequence(forPathId:)` — wirft `.unknownPath` / `.malformedCoordBlob`, decodiert lazy via `CoordBlobIterator`
  - `dayDateRange(forImportId:) -> ClosedRange<String>?`, `totalDistance/totalRouteCount/totalVisitCount(forImportId:)`
- **Bounded-Read-Garantien** (im Reader-Doc-Kommentar verankert): 1) `imports()` ohne paths/visits/activities, 2) `days(forImportId:)` ohne `coord_blob`, 3) `dayDetail(dayId:)` ohne eager coord-Decode, 4) Path-Koordinaten nur explizit/lazy via `coordinateSequence`, 5) kein `AppExport` im Read-Pfad, 6) kein API materialisiert ein vollständiges `[Double]` für einen ganzen Import.
- **Tests Linux-grün**: `LocalTimelineStoreReaderTests` (13), `LocalTimelineStoreReadPersistenceTests` (6), `LocalTimelineStoreBoundedReadTests` (5). 50k-Visit-Smoke verifiziert strukturell summary-only Day-List-Reads (kein coord-Decode). Erwarteter `swift test`-Stand: 1071 → ~1095 (+24).
- **Bewusst nicht in Phase 3**: FileProtection-Flag an `sqlite3_open_v2`, `applicationSupportDirectory/LocationHistory2GPX/Imports/`-Pfad mit `isExcludedFromBackupKey = true`, `deleteAll()`-Erweiterung um Caches/tmp/Bookmark/Preferences, Adapter zum bestehenden `flatCoordinates`-Konsumenten-Set, `derived_cache`/RTree `path_bounds`, App-Flow-Umschaltung gegen Conditional Gate, Settings-Eintrag „Importierte Daten löschen", Privacy-Doku. Alle als **Phase 4 vor UI-Hook** markiert.
- **Conditional Gate unverändert**: P0 falls 46-MB-Retest FAILED, P1/P2 falls PASSED. **46-MB-Crashfall bleibt FAILED / pending hardware retest.**

---

## Phase-6-Spike Snapshot (2026-05-08)

- **Eingecheckt**: 4 neue Source-Dateien unter `Sources/LocationHistoryConsumerAppSupport/`, 4 neue Test-Dateien unter `Tests/LocationHistoryConsumerTests/`, 17 neue Cases. Schema unverändert (`userVersion = 2`). **Kein UI-Hook, kein App-Session-Switch, kein AppContentLoader-Hook, kein DayList/DayDetail/Map/Heatmap/Overview-Hook, kein Settings-UI. Bestehende `AppSession`/`AppSessionContent`-Typen wurden NICHT erweitert. Darwin FileProtection in diesem PR nicht angefasst. Bestehender AppExport-Exportpfad bleibt unverändert.**
- **Feature-Flag** — `LocalTimelineFeatureFlags.swift`:
  - Resolved `LH2GPX_LOCAL_TIMELINE_STORE` aus `ProcessInfo.arguments` und `ProcessInfo.environment`.
  - Akzeptiert `--LH2GPX_LOCAL_TIMELINE_STORE`, bare `LH2GPX_LOCAL_TIMELINE_STORE` als Argument, sowie env-Werte `1`/`true`/`yes`/`on` (case-insensitive).
  - Default: disabled. **Keine UserDefaults-Persistenz.**
- **Session-Modell** — `LocalTimelineSession.swift`:
  - Foundation-only: `importID`, `sourceFilename`, `storeURL`, `createdAt`, `importedAt`, `summary` (`dayCount`, `pathCount`, `visitCount`, `activityCount`, `totalDistanceM`, `dateRange`).
  - `make(reader:importID:storeURL:)` konstruiert das Session-Objekt aus einem `LocalTimelineStoreReader` **ohne Geometrie-Materialisierung**.
  - Caller besitzt die Lifetime des Stores.
- **AppSession-Adapter** — `LocalTimelineAppSessionAdapter.swift`:
  - Projiziert Reader-Daten in bounded ViewState-Modelle: `DaySummaryView`, `DayDetailView`, `VisitView`, `ActivityView`, `PathMetadataView`.
  - Methoden: `daySummaries()`, `dayDetail(dayId:)`, `coordinates(forPathId:)` (explizit on-demand, lazy via `CoordBlobIterator`).
- **Deletion-Service** — `LocalTimelineDeletionService.swift`:
  - Dünner Wrapper um `LocalTimelineStoreLifecycle.deleteAllLocalTimelineData`.
  - Idempotent. **Keine UserDefaults-Aufräumung.**
- **Tests Linux-grün**: `LocalTimelineFeatureFlagsTests` (8), `LocalTimelineSessionTests` (3), `LocalTimelineAppSessionAdapterTests` (4), `LocalTimelineDeletionServiceTests` (2) — zusammen 17 Cases.
- **Bewusst nicht in Phase 6** (= Phase 7 vor UI-Hook):
  - `AppSession`/`AppSessionContent`-Erweiterung um `case localTimeline(...)` — in diesem PR zu riskant, deferred.
  - AppContentLoader-Hook, der auf den Feature-Flag verzweigt.
  - Settings-UI „Importierte Daten löschen" (nur die Service-API ist vorbereitet).
  - DayList/DayDetail/Map/Heatmap/Overview-UI-Hooks.
  - `derived_cache` / RTree / `path_bounds`.
  - Darwin FileProtection: in diesem PR **nicht angefasst** (existierende Factory hat bereits FileProtection-Hinweise; keine Änderung gemacht).
  - Hardware-Retest, ASC/TestFlight-Pass — nicht beansprucht.
- **Status**: weiterhin **Spike / pre-production, nicht UI-aktiv**. Store-Pfad **gated by feature flag**, kein default-aktiver Pfad. Conditional Gate unverändert: P0 falls 46-MB-Retest FAILED, P1/P2 falls PASSED. **46-MB-Crashfall bleibt FAILED / pending hardware retest.**

---

## Phase-5-Spike Snapshot (2026-05-08)

- **Eingecheckt**: 3 neue Source-Dateien unter `Sources/LocationHistoryConsumerAppSupport/`, 3 neue Test-Dateien unter `Tests/LocationHistoryConsumerTests/`, 26 neue Cases (alle Linux-grün). Schema unverändert (`userVersion = 2`). **Kein UI-Hook, kein App-Session-Switch, kein AppContentLoader-Default auf den Store, kein DayList/DayDetail/Map-Hook. Bestehender AppExport-Exportpfad bleibt unverändert; bestehende `AppExport`-Builder (`GPXBuilder`/`KMLBuilder`/`GeoJSONBuilder`/`CSVBuilder`) sind unangetastet.**
- **Foundation-only Export-Typen** — `LocalTimelineExportTypes.swift`:
  - `LocalTimelineExportFormat`: `gpx` / `kml` / `geoJSON` / `csv`.
  - `LocalTimelineExportSelection`: `importID`, optional `dateRange`, optional `dayIds`, `includeVisits` / `includeActivities` / `includePaths`.
  - `LocalTimelineExportResult`: `outputURL`, `format`, `bytesWritten`, `dayCount`, `pathCount`, `visitCount`, `activityCount`, `pointCount`.
  - `LocalTimelineExportError`: `unknownImport`, `emptySelection`, `malformedCoordBlob`, `ioFailure`, `readerFailure`.
  - **Empty-Selection-Entscheidung explizit**: leere/nichts-auswählende Selection wirft `LocalTimelineExportError.emptySelection` statt eine leere Datei zu erzeugen.
- **Streaming-Datei-Writer** — `LocalTimelineStreamingTextWriter.swift`:
  - Schreibt inkrementell UTF-8 nach `LocalTimelineStorageLocations.exportStagingRoot/<uuid>/export.<ext>`.
  - Parent-Verzeichnis wird idempotent angelegt; `bytesWritten` zählt UTF-8-Bytes; `finalize()` ist idempotent.
- **Store-backed Export-Pfad** — `StoreBackedExportWriter.swift`:
  - `init(reader:locations:)`, `export(selection:format:) throws -> LocalTimelineExportResult`.
  - Liest Days bounded, Visits/Activities/Paths via `LocalTimelineStoreReader.dayDetail(dayId:)`.
  - **Koordinaten ausschließlich pro Pfad lazy via `coordinateSequence(forPathId:)` / `CoordBlobIterator`.**
  - **Nicht-Materialisierungs-Garantien**: **materialisiert KEINEN `AppExport`**; **materialisiert KEINEN `[Double]`-Buffer für einen ganzen Import**; **schreibt direkt in die Datei** via `LocalTimelineStreamingTextWriter` (kein In-Memory-String-Buildup eines vollständigen Exports).
  - Ausgabepfad: `LocalTimelineStorageLocations.exportStagingRoot/<uuid>/export.<ext>`.
- **Format-Hinweise**:
  - GPX: `<wpt>` (für Visits) plus `<trk>/<trkseg>/<trkpt>` (für Pfade).
  - KML: `Placemark` mit `Point` (Visits) bzw. `LineString` (Pfade).
  - GeoJSON: `FeatureCollection` mit Point- und LineString-Features; Properties `kind` / `name` / `mode` / `date`.
  - CSV: Header `type,date,time,lat,lon,name,mode,distance_m`. Activities werden in CSV als eigene Rows ausgegeben.
  - Activities in GPX/KML/GeoJSON: nur gezählt, **nicht** als Geometrie geschrieben (kein nativer Activity-Typ in diesen Formaten).
- **Tests Linux-grün**: `LocalTimelineExportSelectionTests` (6), `LocalTimelineStreamingTextWriterTests` (5), `StoreBackedExportWriterTests` (15) — zusammen 26 Cases. `swift test` **1148/2/0** in 123.7s (vorher 1122 → +26).
- **Bewusst nicht in Phase 5** (= Phase 6 vor UI-Hook):
  - Tatsächliche FileProtection-Aktivierung auf Darwin (Hook ist da, Aktivierung pending).
  - Adapter `LocalTimelineStore`/`LocalTimelineStoreReader` → bestehende `flatCoordinates`-Konsumenten (DayList/DayDetail/Map/Heatmap/Distance/Export).
  - `derived_cache`/RTree `path_bounds`.
  - App-Flow-Umschaltung gegen Conditional Gate (AppContentLoader-Default, Session-Switch).
  - Settings-Eintrag „Importierte Daten löschen" mit Bookmark/Preferences-Cleanup.
  - Privacy-Doku-Update auf den tatsächlichen Rollout-Stand.
- **Status**: weiterhin **Spike / pre-production, nicht UI-aktiv**. Conditional Gate unverändert: P0 falls 46-MB-Retest FAILED, P1/P2 falls PASSED. **46-MB-Crashfall bleibt FAILED / pending hardware retest.**

---

## Phase-4-Spike Snapshot (2026-05-08)

- **Eingecheckt**: 5 neue Source-Dateien unter `Sources/LocationHistoryConsumerAppSupport/`, 5 neue Test-Dateien unter `Tests/LocationHistoryConsumerTests/`, 26 neue Cases (alle Linux-grün). Schema unverändert (`userVersion = 2`, additiv). **Kein UI-Hook, kein App-Session-Switch, kein AppContentLoader-Default auf Store, kein DayList/DayDetail/Map-Hook, kein Export-Umbau, kein `AppExport` über den Store-Pfad.**
- **Storage-Layout (4 Roots)** — `LocalTimelineStorageLocations.swift`:
  - DB-Verzeichnis: `applicationSupportDirectory/LocationHistory2GPX/Imports/`, DB-Datei `store.sqlite` plus `-wal`/`-shm`-Geschwister.
  - RenderCache: `cachesDirectory/LocationHistory2GPX/RenderCache/` (regenerierbar, system-purgeable).
  - ImportStaging: `temporaryDirectory/LocationHistory2GPX/ImportStaging/` (kurzlebig).
  - ExportStaging: `temporaryDirectory/LocationHistory2GPX/ExportStaging/` (kurzlebig, finaler User-Save geht unverändert über `documentsDirectory`/`fileExporter`).
  - Test-Hook `temporary(under:)`; `ensureDirectoriesExist` ist idempotent.
- **Backup-Exclusion-Strategie** — `LocalTimelineFileAttributes.swift`:
  - Apple: setzt `URLResourceKey.isExcludedFromBackupKey = true` auf DB-Verzeichnis und DB-Datei (defensiv: DB ist regenerierbarer Cache aus der Original-Quelldatei via Bookmark; Re-Import bleibt günstig).
  - Linux: no-op; `isExcludedFromBackup` liefert `false`.
- **FileProtection-Ziel** — `LocalTimelineFileProtection.swift`:
  - Ziel iOS: `completeUnlessOpen` (sensitive Geometrie; Live-Activity-kompatibel).
  - **Phase 4 hat den Hook nur dokumentiert, nicht aktiviert** (siehe Kommentar im File). `defaultProtectionDescription` liefert auf Linux `"noop-linux"`.
  - **Offene Darwin-Pflicht**: tatsächliches Setzen von `URLResourceKey.fileProtectionKey` (oder `SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN` an `sqlite3_open_v2`) auf Apple-Plattformen muss vor produktivem Rollout in einem Darwin-Hardware-Pass aktiviert und verifiziert werden.
- **Factory-Open-Lifecycle** — `LocalTimelineStoreFactory.swift`:
  - `openStore()` orchestriert: Verzeichnisse erzeugen → Backup-Exclusion auf DB-Dir → FileProtection-Hook → `LocalTimelineStore(url:)` → Backup-Exclusion + FileProtection auf der DB-Datei.
  - Statische Helfer `temporary(under:)` (Tests) und `production()` (Produktivpfad ohne UI-Hook).
  - Kein AppContentLoader-Hook, keine automatische Migration.
- **Lifecycle deleteAll-Scope** — `LocalTimelineStoreLifecycle.swift`:
  - `deleteAllLocalTimelineData(store:)` → `store.deleteAll()` + Store schließen + DB-Datei + `-wal` + `-shm` + RenderCache-Dir + ImportStaging-Dir + ExportStaging-Dir + abschließendes `ensureDirectoriesExist`.
  - Idempotent, stabil bei fehlenden Verzeichnissen.
  - **Keine UserDefaults-Aufräumung** — explizit dokumentiert: keine Standortdaten in UserDefaults; Bookmark-/Preferences-Cleanup verbleibt im UI-Hook (Phase 5).
- **Explizit dokumentiert**:
  - **Keine Standortdaten in UserDefaults** — bleibt eingehalten. Token im Keychain, Preferences/Bookmark-Metadaten in UserDefaults; tatsächliche Geometrie ausschließlich im Store.
  - **Keine UI-Aktivierung** — der Store ist weiterhin Spike/pre-production. Kein produktiver App-Flow umgestellt.
- **Tests Linux-grün**: `LocalTimelineStorageLocationsTests`, `LocalTimelineFileAttributesTests`, `LocalTimelineFileProtectionTests`, `LocalTimelineStoreFactoryTests`, `LocalTimelineStoreLifecycleDeleteAllTests` — zusammen 26 Cases.
- **Bewusst nicht in Phase 4** (= Phase 5 vor UI-Hook):
  - Tatsächliche FileProtection-Aktivierung auf Darwin (Hook ist da, Aktivierung pending).
  - Adapter `LocalTimelineStore`/`LocalTimelineStoreReader` → bestehende `flatCoordinates`-Konsumenten (DayList/DayDetail/Map/Heatmap/Distance/Export).
  - `derived_cache`/RTree `path_bounds`.
  - App-Flow-Umschaltung gegen Conditional Gate (AppContentLoader-Default, Session-Switch).
  - Settings-Eintrag „Importierte Daten löschen" mit Bookmark/Preferences-Cleanup.
  - Privacy-Doku-Update auf den tatsächlichen Rollout-Stand.
- **Conditional Gate unverändert**: P0 falls 46-MB-Retest FAILED, P1/P2 falls PASSED. **46-MB-Crashfall bleibt FAILED / pending hardware retest.**

---

## Phase-1-Spike Snapshot (2026-05-08)

- **Eingecheckt**: `Sources/CSQLite/{module.modulemap, shim.h}` (Linux-Shim, pkgConfig `sqlite3`), `Sources/LocationHistoryConsumer/CoordBlob.swift`, `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStore{,Schema,Error}.swift`. Test-Surface: `CoordBlobEncoderTests` (13), `CoordBlobDistanceTests` (2), `LocalTimelineStoreTests` (8). Linux `swift test` 1057/2/0 (vorher 1034 → +23).
- **Encoding bestätigt**: `int32-microdeg-v1`, 8 Bytes/Punkt, lazy Sequence-Decode ohne `[Double]`-Materialisierung. Distanz-Iteration matched Haversine-Baseline auf <1e-5 Relativabweichung.
- **Spike-Schema**: `imports`/`days`/`paths` mit `ON DELETE CASCADE`, Indizes auf `import_id`/`date`/`day_id`, `PRAGMA user_version = 1`, `PRAGMA journal_mode = WAL`. **Nicht** im Spike: `visits`, `activities`, `derived_cache`, RTree `path_bounds` — Phase-2.
- **Bewusst weggelassen**:
  - FileProtection-Flag an `sqlite3_open_v2` (`SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN` ist iOS-only Header) — wird beim iOS-Rollout nachgezogen.
  - `LocalTimelineStore.deleteAll()` (DB + Caches + tmp) — Phase-2-Pflicht vor jedem produktiven App-Hook.
  - `URLResourceKey.isExcludedFromBackupKey` — nicht im Spike, weil Spike keinen `applicationSupportDirectory`-Pfad öffnet, sondern nur `tmpDirectory` für Tests.
  - Adapter zu `flatCoordinates`-Konsumenten — bewusst nicht in dieser Iteration, kein Contract-Break in `main`.
- **Conditional Gate unverändert**: P0 falls 46-MB-Retest FAILED, P1/P2 falls PASSED. **46-MB-Crashfall bleibt FAILED / pending hardware retest.**

---

## Original Research (unverändert)

Status: **Research / Plan**, kein Code in `main` umgesetzt.
Stand: 2026-05-08, HEAD-Anker `ebd8146`, Linux Swift 5.9, 1034/2/0 Tests grün.
Scope: Strukturelle Alternative zum aktuellen In-Memory-`AppExport`-Pfad für sehr große Google-Timeline-Importe (z. B. 46 MB ZIP). **Keine Kartenmodernisierung. Keine ASC-/TestFlight-Aussage. 46-MB-Crashfall bleibt FAILED bis Hardware-Retest.**

Dieses Dokument ist ein Engineering-Compliance-Check, keine Rechtsberatung und keine Apple-Review-Freigabe.

---

## 0. Kontext (Repo-Wahr, kurz)

- **Aktuell**: `AppContentLoader` → `GoogleTimelineStreamReader` → `GoogleTimelineConverter.IncrementalStreamConverter` → `AppExport` (komplett im RAM, `Day`-Liste mit Paths in `flatCoordinates: [Double]`-Form).
- Jetsam-Trigger 2026-05-07 auf iPhone 15 Pro Max iOS 26.4 wurde beim **Erst-Render der lazy projections** (`projectedDays()` / `daySummaries`) auf einer 46-MB-ZIP gemessen, nicht im Streaming-Reader selbst — Streaming + autoreleasepool sind seit `34bc369`/`37a22b7` stabil, das verbleibende Peak liegt im *Materialisieren* der Tagesprojektionen über die volle In-Memory-`[Day]`-Liste.
- **Persistenz heute**: `UserDefaults` (Preferences, `RecentFilesStore`, `WidgetDataStore` per App Group), `ImportBookmarkStore` (Security-Scoped Bookmark, **keine Inhaltsdaten**), `RecordedTrackStore` (`applicationSupportDirectory/LocationHistory2GPX/RecordedTracks/recorded_live_tracks.json`, atomic write, **eigener User-Track-Pfad, kein Import-Cache**). **Kein SQLite, kein CoreData, kein SwiftData, keine eigene Binary-DB.**
- Auto-Restore nach App-Start re-importiert die zuletzt gewählte Datei über den Bookmark — und cappt bei 50 MB, weil es kein lokal persistiertes parsed-State-Cache gibt.

Der LocalTimelineStore existiert **nicht** im Code; dieses Dokument beschreibt eine Zielarchitektur und prüft Machbarkeit.

---

## Aufgabe A — Engineering-Compliance-Check (Privacy / Storage / Backup / FileProtection)

### A.1 Was lokal gespeichert werden darf

Aus reiner Engineering-Sicht (Apple Data Privacy Guidelines + DSGVO-Datenminimierung als Designhilfe; **keine Rechtsberatung, keine Apple-Freigabe-Aussage**) ist on-device-Storage von Standortdaten genau dann unbedenklich, wenn der Nutzer der Importierende ist und die Daten das Gerät nicht verlassen:

| Kategorie | OK lokal? | Begründung im LH2GPX-Kontext |
|---|---|---|
| Importierte Google-Timeline-Daten (ZIP/JSON) | Ja | Nutzer initiierter Import; "All data stays local" ist Repo-Truth (README, APP_FEATURE_INVENTORY). |
| Normalisierte Tage / Pfade / Visits / Activities | Ja | Reiner View über die Importdaten, gleiche Privacy-Klasse. |
| Lokale Indizes (Datum, Bounding-Box) | Ja | Abgeleitet, nicht zusätzlich sensitiv. |
| Render-/Heatmap-/LOD-Caches | Ja | Reproduzierbar aus dem Import; reine Performance-Optimierung. |
| Optionaler Live-Recording-Track | Ja | Bereits heute in `RecordedTrackStore`. **Bleibt getrennt vom Importpfad.** |
| Bearer-Token / Server-URL für Live-Upload | Token Keychain, URL UserDefaults | **Bleibt** wie heute (`KeychainHelper`, `AppPreferences`). |
| Importdaten in `UserDefaults` | **Nein** | UserDefaults ist nicht für massive/sensitive Daten gedacht; Apple PrivacyInfo CA92.1 bezieht sich auf "App Functionality"-Preferences. |

### A.2 Wo gespeichert werden soll

| Verzeichnis | Verwendung im LocalTimelineStore | iOS-Backup-Verhalten | Begründung |
|---|---|---|---|
| `applicationSupportDirectory/LocationHistory2GPX/Imports/` | Persistente Import-DB (z. B. `timeline.sqlite` oder eigene `.bin`) | Backup default; **Empfehlung: `URLResourceKey.isExcludedFromBackupKey = true`**, weil reproduzierbar aus der Original-Quelldatei | Apple-Standard für App-interne dauerhafte App-Daten, aufräumbar nur durch App-Delete. |
| `cachesDirectory/LocationHistory2GPX/RenderCache/` | Heatmap-LOD-Tiles, Day-Snapshots, decimierte Overview-Geometrie | Nie gebackuped, system-purgeable | Reproduzierbar; perfekter Use-Case für `Caches`. |
| `tmpDirectory/LH2GPX-Import-<uuid>/` | Import-Staging (entpackte ZIP-Entries, Streaming-Pufferdateien), Export-Staging (`.gpx`/`.kml` vor User-Save) | Nie gebackuped, system-clean | Kurzlebig; muss am Ende oder beim nächsten Launch garbage-collected werden. |
| `documentsDirectory/` | **Nur** vom Nutzer initiierte Export-Dateien, falls Nutzer sie behalten will | Backup default | Sichtbar in Files-App; wäre Privacy-relevant, falls Importrohdaten dort lägen → **liegen sie nicht**. |
| `applicationSupportDirectory/LocationHistory2GPX/RecordedTracks/` | **Unverändert** (Live-Track-Pfad, separat vom Import) | Wie heute | Bleibt getrennt; Dokumentation-Hinweis im LocalTimelineStore-Doc nötig, dass dies *nicht* der LocalTimelineStore ist. |

### A.3 Privacy-Regeln (Engineering-Check)

1. **Lokal-only ist im Apple-PrivacyInfo-Modell keine "Data Collection".** Die `PrivacyInfo.xcprivacy` muss für reines on-device-Storage **nicht** um zusätzliche `NSPrivacyCollectedDataTypes` erweitert werden.
2. **Server-Upload ist Collection.** Der bestehende, optional aktivierbare Live-Upload (`PreciseLocation`, opt-in, default-off) bleibt **getrennt** vom Importpfad; Importdaten dürfen ohne expliziten neuen Nutzer-Consent **nicht** in den Upload-Pfad geleitet werden.
3. **Keine Standortdaten in `UserDefaults`** — bleibt eingehalten; LocalTimelineStore liegt in `Application Support`, nicht `UserDefaults`.
4. **Keychain-only für Tokens** — bleibt.
5. **Löschfunktion erforderlich.** Engineering-Anforderung an LocalTimelineStore: API `LocalTimelineStore.deleteAll()` muss DB-Datei + `Caches` + `tmp`-Reste entfernen, idempotent, ohne App-Neustart.
   - Exposed in Settings → "Importierte Daten löschen" (Engineering-Pflicht; nicht in dieser Iteration umzusetzen, aber Architekturanforderung).
6. **Privacy Policy Update (Doku, nicht Apple-Aussage)** — `docs/privacy.html` (und `docs/PRIVACY_MANIFEST_SCOPE.md`) müssten beim tatsächlichen Rollout erwähnen: lokale Verarbeitung, keine Drittweitergabe, Retention bis Nutzer-Delete, Backup-Verhalten. **Heute keine Änderung dort, weil LocalTimelineStore noch nicht implementiert ist.**

### A.4 Backup-Regeln

- LocalTimelineStore-DB ist **regenerierbarer Cache** aus der Original-Quelldatei (sofern die noch via Bookmark erreichbar ist) → `isExcludedFromBackupKey = true`.
- Ist die Quelldatei vom Nutzer im Files-App-Container und LH2GPX nur Konsument, dann ist **Re-Import billig**; Backup-Exklusion ist defensiv.
- Falls in Zukunft die DB selbst zur "Source of Truth" wird (d. h. Original-Datei wird nach Import gelöscht), müsste die Backup-Strategie auf **opt-in Backup mit explizitem Nutzer-Setting** umgestellt werden. Für den ersten Wurf bleibt: **DB = Cache, Original = Truth.**
- `Caches` und `tmp` werden nie als nonpurgeable Source of Truth genutzt; LOD-Tiles dürfen durch das System gelöscht werden.

### A.5 File-Protection

| Pfad | Empfohlene `FileProtection` | Begründung |
|---|---|---|
| LocalTimelineStore-DB-Datei | **`completeUnlessOpen`** | Standortdaten sind sensitiv; Background-Refresh / Live-Activity könnten das geöffnet halten. `complete` würde Live-Activity stören. |
| Temp-Exports (`tmp/...`) | `completeUnlessOpen` | Halbsensitiv (Geometrie); gleiche Kompromiss-Logik. |
| Render-Caches (`Caches/...`) | `completeUntilFirstUserAuthentication` (default) | Reine Performance-Tiles, keine direkten Koordinaten in lesbarer Form. |
| Recorded-Live-Tracks (`RecordedTrackStore`) | **Heute kein expliziter Schutz** — Empfehlung im LocalTimelineStore-Rollout: gleichzeitig auf `completeUnlessOpen` heben. |

Engineering-Note: `URLResourceKey.fileProtectionKey` setzen direkt nach Erstellung; bei SQLite via `sqlite3_open_v2` zusätzlich `SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN`-Flag (iOS-only Header).

---

## Aufgabe B — LocalTimelineStore-Architektur (Zielzustand)

### B.1 Pipeline

```
location-history.zip / .json
    │
    ▼
GoogleTimelineStreamReader (existing, unchanged)
    │   per-element JSON object (autoreleasepool on Darwin)
    ▼
LocalTimelineImportWriter (new, replaces ExportBuilder for the on-disk path)
    │   batched INSERTs / append-only writes; bounded RAM working-set
    ▼
LocalTimelineStore.sqlite  (or BinaryStore, see C)
    │
    ├──► LocalTimelineQuery (lazy)
    │       │
    │       ├── Day list      → SELECT day_key, summary_blob FROM days …
    │       ├── Day detail    → SELECT * FROM paths WHERE day_id=?
    │       ├── Overview      → bounds + decimierte Geometrie via path_bounds
    │       ├── Insights      → aggregierte days-Spalten
    │       ├── Heatmap       → derived_cache lookup oder bounded compute
    │       └── Export (GPX/KML/GeoJSON/CSV) → Cursor → Streaming-Builder → tmp/<file>
    │
    └──► AppExport-Compat-Adapter
            (rebuilds in-memory AppExport on demand for legacy UI surfaces;
             scoped/limited; not the default render path)
```

**Invarianten:**

- Beim Import wird **kein** vollständiger `AppExport` mehr im RAM materialisiert.
- Day/Path-Render-Pfade lesen ausschließlich über bounded Queries.
- Export streamt aus DB in eine `tmp/`-Datei; finaler `URL` wird an den iOS-Share-Sheet/`fileExporter` gegeben — keine vollständige Result-`Data` im RAM.

### B.2 Minimales Schema (SQLite-bevorzugt; gleiche Logik in BinaryStore)

```sql
-- Header pro Importvorgang. Mehrere Importe könnten koexistieren; v1: nur ein "current".
CREATE TABLE imports (
    id              INTEGER PRIMARY KEY,
    source          TEXT NOT NULL,        -- 'google_timeline' | 'lh2gpx_app_export' | 'gpx' | 'tcx'
    file_name       TEXT NOT NULL,
    file_size       INTEGER NOT NULL,
    file_sha256     TEXT,
    imported_at     INTEGER NOT NULL,     -- epoch
    schema_version  INTEGER NOT NULL,
    input_format    TEXT,                 -- AppExportInputFormat raw value
    meta_json       TEXT                  -- AppExportMeta JSON; small
);

CREATE TABLE days (
    id              INTEGER PRIMARY KEY,
    import_id       INTEGER NOT NULL REFERENCES imports(id) ON DELETE CASCADE,
    day_key         TEXT NOT NULL,        -- 'YYYY-MM-DD' UTC
    bounds_min_lat  REAL, bounds_max_lat REAL,
    bounds_min_lon  REAL, bounds_max_lon REAL,
    distance_m      REAL,                 -- aggregated effective distance
    visit_count     INTEGER,
    path_count      INTEGER,
    activity_count  INTEGER,
    summary_blob    BLOB                  -- compact `DaySummary` (Codable→CBOR/JSON)
);
CREATE INDEX idx_days_import_day ON days(import_id, day_key);

CREATE TABLE paths (
    id              INTEGER PRIMARY KEY,
    day_id          INTEGER NOT NULL REFERENCES days(id) ON DELETE CASCADE,
    start_epoch     INTEGER, end_epoch INTEGER,
    distance_m      REAL,
    bounds_min_lat  REAL, bounds_max_lat REAL,
    bounds_min_lon  REAL, bounds_max_lon REAL,
    point_count     INTEGER NOT NULL,
    coord_blob      BLOB NOT NULL          -- Int32 microdegrees (lat,lon pairs)
);
CREATE INDEX idx_paths_day ON paths(day_id);

CREATE TABLE visits (
    id              INTEGER PRIMARY KEY,
    day_id          INTEGER NOT NULL REFERENCES days(id) ON DELETE CASCADE,
    start_epoch     INTEGER, end_epoch INTEGER,
    lat             REAL, lon REAL,
    label           TEXT,
    confidence      REAL
);
CREATE INDEX idx_visits_day ON visits(day_id);

CREATE TABLE activities (
    id              INTEGER PRIMARY KEY,
    day_id          INTEGER NOT NULL REFERENCES days(id) ON DELETE CASCADE,
    kind            TEXT,                  -- raw activity-type string
    start_epoch     INTEGER, end_epoch INTEGER,
    distance_m      REAL,
    coord_blob      BLOB                   -- optional, same encoding as paths
);
CREATE INDEX idx_activities_day ON activities(day_id);

-- Render-/Insights-Caches; rein abgeleitet, jederzeit verwerfbar.
CREATE TABLE derived_cache (
    cache_key       TEXT PRIMARY KEY,      -- e.g. 'heatmap.zoom=10.viewport=…'
    payload         BLOB NOT NULL,
    generated_at    INTEGER NOT NULL,
    schema_version  INTEGER NOT NULL
);

-- Optional: nur falls SQLite RTree-Modul verfügbar ist (iOS bringt es mit).
CREATE VIRTUAL TABLE path_bounds USING rtree(
    id,
    min_lat, max_lat,
    min_lon, max_lon
);
```

**Hinweise:**
- `paths.coord_blob` speichert **Int32 microdegrees** (siehe B.3). Kein redundantes `points`-Feld; `flatCoordinates` ist ein in-memory-View auf den Blob.
- `summary_blob` und `meta_json` halten kleine, schnell deserialisierbare Aggregate; keine Geometrie.
- Single-Import-Modell für v1 (`imports`-Tabelle hat genau eine Zeile bei "current"); `ON DELETE CASCADE` macht "Importierte Daten löschen" zur Ein-Zeilen-Operation.

### B.3 Coordinate-Encoding — Vergleich und Empfehlung

| Variante | Bytes/Punkt | CPU-Decode | Genauigkeit | Streaming-fähig | Bewertung |
|---|---|---|---|---|---|
| `Double`-Pair BLOB (16 B) | 16 | trivial (`load(fromByteOffset:as:)`) | volle IEEE-754 | ja | Status quo `flatCoordinates`. **Zu groß** für 1 M-Punkt-Importe (~16 MB pro Pfad-Layer in DB). |
| **`Int32`-microdegrees BLOB (8 B)** | 8 | trivial (`Int32` × 1e-6) | ~11 cm Lat-Auflösung; >> GPS-Rauschen | ja | **Empfohlen.** Halbiert Speicher gegenüber Double; reine Bitshift-Decode; vollständig kompatibel zur bestehenden `flatCoordinates`-Konsument-Logik (Adapter projiziert `Int32` → `Double` lazy). |
| Encoded Polyline (Google Algorithmus) | ~3–5 B (variable) | nicht-trivial; sequenziell | ~1 cm bei `precision=5` | nur sequenziell | Beste Kompression, aber **kein Random-Access**, kein Bounding-Box-Scan ohne Voll-Decode. Ungeeignet für Heatmap-LOD-Iteration. |
| Delta-encoded Int32 + Varint | ~2–3 B | mittel | gleich Int32 | sequenziell | Erspart weitere ~30 %, lohnt sich erst bei sehr großen Pfaden; **Phase 2**. |

**Empfehlung Phase 1**: Int32 microdegrees als 8-Byte little-endian Pairs.

```swift
// Encoder: lat,lon: Double in [-180, 180] → Int32 microdegrees
let latI = Int32((lat * 1_000_000).rounded())
let lonI = Int32((lon * 1_000_000).rounded())
// 8 bytes per point; appendLittleEndian-style write
```

**Streaming-Decode-Iterator** (Pflicht; **kein vollständiges `[Double]`-Materialisieren** für Overview/Export):

```swift
public struct CoordBlobIterator: Sequence, IteratorProtocol {
    public typealias Element = (lat: Double, lon: Double)
    private let blob: Data
    private var offset: Int = 0
    public mutating func next() -> Element? {
        guard offset + 8 <= blob.count else { return nil }
        let latI: Int32 = blob.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset,     as: Int32.self) }
        let lonI: Int32 = blob.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset + 4, as: Int32.self) }
        offset += 8
        return (Double(latI) * 1e-6, Double(lonI) * 1e-6)
    }
}
```

Tests müssen invariant prüfen: **Iterator-Konsumenten allokieren nie ein voll-materialisiertes `[Double]`** (Distance, GPX/KML/GeoJSON-Builder, Heatmap-Aggregator). Stichprobentest: Pfad mit 1 M-Punkten, Memory-Probe vor/nach Distanz-Berechnung darf < 1 MB Delta haben.

### B.4 Query-Architektur

| UI-Surface | Heutiger Pfad | Ziel-Pfad |
|---|---|---|
| Day list | `AppExportQueries.projectedDays()` über volle `[Day]` | `SELECT day_key, distance_m, visit_count, path_count, summary_blob FROM days WHERE import_id=? ORDER BY day_key` (LRU 8). |
| Day detail | Index in `[Day]` | `SELECT * FROM days WHERE id=?`, dann `paths`/`visits`/`activities` per `day_id`. |
| Overview-Karte | Volle Coords-Materialisierung pro Pfad | RTree-Range-Query → Top-N-Pfade nach Bounds-Overlap → Decode-Iterator + Stride-Decimierung (`MapPolyline`-Limit, **bestehende** `OverviewMap`-Logik). |
| Insights | Reduktion über `[Day]` | Aggregation per SQL (`SUM(distance_m)`, `COUNT()`) für Top-Level; Detail-Reductions weiterhin in-Swift, aber bounded. |
| Heatmap | `AppHeatmapModel` über volle Coords | Lookup `derived_cache` für Zoom/Viewport → Cache-Hit; Cache-Miss → bounded compute über RTree-Filter + Decode-Iterator. |
| Export | `[Day]` → String → `Data` | Cursor `SELECT … ORDER BY day_id, path_id` → `CoordBlobIterator` → `OutputStream`-write nach `tmp/<uuid>/<file>.gpx`. **Nie** Voll-String im RAM. |

### B.5 Kompatibilität & Migration

- **Contract bleibt unangetastet.** `AppExport`/`AppExportDecoder`/`AppExportEncoder` bleiben für *Import* (v. a. LH2GPX-Format aus Producer) und *Export* (Roundtrip-Test) erhalten.
- **Bestehende `flatCoordinates: [Double]`-Konsumenten** werden über einen **In-Memory-Adapter** bedient: der LocalTimelineStore-Render-Pfad konvertiert *für eine begrenzte Day-Auswahl* on-demand in den heute erwarteten `Path`-Wert mit `flatCoordinates`. Großdatei-Pfade lassen den Adapter aus und gehen direkt über `CoordBlobIterator`.
- **Demo-/Onboarding-Pfade** (kleine Fixtures) gehen weiterhin über In-Memory-`AppExport` ohne DB; LocalTimelineStore wird **nur** für tatsächlich importierte Dateien aktiviert. Dies hält Tests klein und Onboarding schnell.
- **Heatmap-LOD-Cache** kann sofort vom RAM in `derived_cache` migrieren — schon heute reproduzierbar, Kandidat für Phase 1.5.

---

## Aufgabe C — Machbarkeit im Code (SQLite vs. BinaryStore vs. CoreData)

### C.1 SQLite C-API (libsqlite3.tbd auf iOS, libsqlite3 auf Linux)

| Punkt | Bewertung |
|---|---|
| iOS-Verfügbarkeit | **Ja, ohne Dependency.** `libsqlite3` ist Teil des iOS-SDK; in Swift via `import SQLite3` nach `linkerSettings(.linkedLibrary("sqlite3"))` in `Package.swift`. |
| Linux-Verfügbarkeit | **Ja**, distributionsabhängig (`sudo apt install libsqlite3-dev`). Im aktuellen Container vorhanden? Zu prüfen via `pkg-config --modversion sqlite3` beim Spike-Start. |
| SwiftPM-Setup | Ein neuer `linkerSettings(.linkedLibrary("sqlite3"))` reicht für iOS; Linux braucht `pkgConfig: "sqlite3"` oder system-include-Pfade. **Risiko**: pkgConfig nicht in allen CI-Linux-Containern, evtl. Fallback-Spike-Pfad nötig. |
| RTree-Modul | iOS-`libsqlite3` enthält `SQLITE_ENABLE_RTREE` standardmäßig. Linux hängt vom Build der Distro ab; im Zweifel als optional behandeln (Schema bedingt anlegen, sonst Fallback auf "Index über bounds_min/max + Linear-Scan"). |
| FileProtection | Per `sqlite3_open_v2(... | SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN, ...)` (iOS-Header). Auf Linux ignoriert, wie erwartet. |
| Test-Aufwand | Headless XCTest-Suite ist machbar; CRUD + RTree-Smoke + Iterator-Invariant-Tests in 4–8 Tests abdeckbar. |

### C.2 Eigener BinaryStore

Append-only File mit Header + indexierten Records (Format vergleichbar zu Capnproto/FlatBuffers light):

| Punkt | Bewertung |
|---|---|
| iOS- und Linux-Verfügbarkeit | **Ja** (reines `Foundation.FileHandle` + `Data`). Keine Dependency. |
| Schema-Evolution | Wir müssen Versionsnummer + Migration selbst bauen; SQLite hat dafür `PRAGMA user_version` + bewährte Patterns. |
| Range-Queries / RTree-Äquivalent | Müssten wir selbst implementieren (z. B. einfacher Bounding-Box-Index als sortiertes Sub-File). Aufwand non-trivial. |
| Reaktionsfähigkeit auf Apple-Reviews | Ein eigener Storage-Layer ist okay, erhöht aber Test-/Review-Oberfläche. |

### C.3 CoreData / SwiftData

| Punkt | Bewertung |
|---|---|
| iOS-Verfügbarkeit | Ja. |
| **Linux-Verfügbarkeit** | **Nein.** `CoreData`/`SwiftData` sind Darwin-only — würde unsere Linux-CI-Test-Strategie brechen. |
| Strikter Modellzwang | Mehr Boilerplate; weniger natürliche Abbildung des `coord_blob`-Modells. |

### C.4 Empfehlung

**SQLite-C-API** (Phase 1), mit klar definierten Linux-Test-Guards:

1. Keine neue externe Swift-Dependency (kein GRDB/SQLite.swift initial), sondern direkter `import SQLite3` + ein dünner `LH2GPXSQLite`-Wrapper im AppSupport-Target.
2. Linker-Setting in `Package.swift`:
   - iOS-Targets: `.linkedLibrary("sqlite3")`
   - Linux-Test-Target: gleiche Library; falls Container-Variation existiert, Fallback-Skip-Mechanismus (ähnlich `#if canImport(MapKit)`-Skips bestehender Tests).
3. **Falls** Linux-Build `libsqlite3-dev` nicht zur Verfügung stellt, **dann** als Fallback BinaryStore-Spike rein in Foundation; SQLite bleibt iOS-Pfad. Diese Entscheidung fällt beim Spike-Aufschlag, nicht in diesem Doku-Commit.
4. **Kein** GRDB/SQLite.swift in v1 — vermeidet Apple-Review-Komplikation und Lieferketten-Risiko.

### C.5 Mini-Probe / Spike — Scope für nächste Iteration

Wenn ein Spike kommt, dann **isoliert**:

- `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStorePlan.swift` als pure-Swift Schema-Plan-Datei (keine UI-Umschaltung).
- `Tests/LocationHistoryConsumerTests/CoordinateBlobEncodingTests.swift`:
  - Encode/Decode round-trip, microdegree-Genauigkeit.
  - Streaming-Iterator allokiert kein `[Double]` (Memory-Probe Delta < Threshold).
- `Tests/LocationHistoryConsumerTests/LocalTimelineStoreSchemaPlanTests.swift`:
  - DDL-String-Stabilität (kanonische Schema-Hash-Snapshot-Test, damit Schema-Änderungen review-pflichtig werden).
  - Migrationspfad `schema_version=1 → 2` skizzieren.
- **Keine** Migration der App-UI in dem Commit.

In **diesem** Commit hier wird kein Spike eingecheckt — das Doc setzt nur das Gate.

---

## Aufgabe D — P0-Entscheidungsgate

Bindend an das offene 46-MB-Hardware-Retest-Ergebnis (HEAD `ebd8146`):

- **Wenn `ebd8146` Hardware-Retest PASSED** (vollständige `[LH2GPX_MEMORY]`-Logs, kein Jetsam-Kill, Day/Insights/Export-Smoke grün, Tester-Template aus `docs/APPLE_VERIFICATION_CHECKLIST.md` vollständig ausgefüllt zurückgemeldet): LocalTimelineStore wird **P1/P2 Robustheits-/Skalierungsprojekt** — Adressat sind Importe deutlich >50 MB und Geräte mit knapperem RAM-Budget (4 GB-Klasse). Reihenfolge nach P0-Restpunkten (Live Activity / iPad / Apple Review).
- **Wenn `ebd8146` Hardware-Retest FAILED** (erneuter Jetsam, gleiche oder neue Repro): LocalTimelineStore wird **P0-Fixpfad** — geht *vor* Map-Modernisierung und vor weiterer UI-Politur. Begründung: weiteres Stream-Tuning hat in `34bc369` und `37a22b7` bereits den Streaming-Reader gehärtet; verbleibender Peak liegt im *Render-Materialisieren* der lazy projections und ist ohne strukturelle Änderung (= Storage statt RAM) nicht weiter zu drücken.
- **Map-Modernisierung** (Overview UIKit MKMapView/MKMultiPolyline/MKTileOverlay, Heatmap-Tile-Overlay) bleibt **vor 46-MB-Pass oder klarer LocalTimelineStore-P0-Entscheidung blockiert**, weil sie ein bewegliches Ziel auf einem instabilen Datenmodell wäre.

---

## Offene Risiken (nur Engineering)

1. **Linux-`libsqlite3`-Verfügbarkeit** in der konkreten CI-Container-Variante muss beim Spike geprüft werden; sonst BinaryStore-Fallback.
2. **Schema-Migration** ist v1 nicht ausgereizt (single-import Modell). Multi-Import / mehrere Quellen gleichzeitig ist eine Phase-2-Erweiterung.
3. **Adapter-Aufwand**: Bestehende `Path.flatCoordinates`-Konsumenten umzustellen ist eher Surface-Aufwand als Algorithmus-Aufwand, aber breit verteilt (DayMap, Heatmap, Distance, ExportBuilder, Snapshots). Die Adapter-Strategie hält v1 kompatibel; v2 entfernt den Adapter.
4. **Apple-Review**: Reine on-device-Persistenz ohne neuen Datenpunkt erfordert *kein* `PrivacyInfo.xcprivacy`-Update; sollte sich der Speicherort (`Application Support`) oder die Backup-Strategie ändern, ist eine Aktualisierung von `docs/PRIVACY_MANIFEST_SCOPE.md` und `docs/privacy.html` Pflicht **vor** TestFlight-Resubmit. **Keine Apple-Freigabe-Aussage hier.**
5. **46-MB-Crashfall bleibt FAILED**, bis ein vollständiges Tester-Ergebnis-Template mit `Ergebnis: PASSED` zurückgemeldet ist. Nichts in diesem Doku-Commit ändert daran.

---

## Zusammenfassung für CHANGELOG/NEXT_STEPS

- Research-Doku angelegt: `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`.
- Empfehlung: **SQLite-C-API + Int32-microdegrees-BLOB**, Application-Support-Speicherort, `completeUnlessOpen`, backup-excluded.
- Conditional-P0-Gate definiert; Map-Modernisierung weiter blockiert.
- Kein Code in `main` umgeschaltet. Spike in dedizierter Folge-Iteration; Test-Plan dort: `CoordinateBlobEncodingTests`, `LocalTimelineStoreSchemaPlanTests`, Iterator-No-Allocation-Invariant.

## Phase-10B-Snapshot (2026-05-08, Weg 3 — Foundation-only)

- **PointLayer-Modelle** (`Sources/LocationHistoryConsumerAppSupport/LocalTimelineMapPointLayerModels.swift`): `PointKind { visit, activityStart, activityEnd, routeSample }`, `Entry`, `Cluster` mit `dominantKind`, `Response`/`ClusterResponse` mit Truncation-Flags (Foundation-only, keine MapKit/SwiftUI-Abhängigkeit).
- **PointLayer-Provider** (`Sources/LocationHistoryConsumerAppSupport/LocalTimelineMapPointLayerProvider.swift`): `dayPointCandidates`, `pointCandidates`, `dayClusteredPoints`, `clusteredPoints`. Bounded-read: Visits/Activities aus Spalten direkt; routeSamples lazy via `CoordBlobIterator + LocalTimelineRouteDecimator`. Deterministische Sortierung.
- **Adaptive Budgets** (`Sources/LocationHistoryConsumerAppSupport/LocalTimelineMapPerformanceBudget.swift`): zentraler Budget-Typ, detail-level-/zoom-abhängig. Defaults overview 24/256/1500/8/256, low 48/512/3000/16/512, medium 96/1024/6000/32/1024, high 192/2048/12000/64/2048; `dayMap`-Profil 12/64/800/12/256. Ersetzt im Store-Pfad die starre 200-Routen-Vorstellung durch `maxVisibleRoutes` (UI-bounded) + `maxRouteCandidates` (Provider-Over-fetch).
- **Lazy CoordBlobIterator**: pro Pfad, kein vollständiger `[Double]`-Buffer; deterministische Ausgabe.
- **Status**: Modelle + Provider only — **in keinem View aktiv**. UI-Verdrahtung in `LocalTimelineDayMapViewState`/`LocalTimelineDayMapView` ist WIP. Legacy-Pfad unverändert. Store-Pfad bleibt default OFF. **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim).

## Phase-10C-Snapshot (2026-05-08, Legacy hardening — derived_cache Purge-API)

- **derived_cache Purge-API** ist ab Phase-10C **das offizielle Cache-Lifecycle-Werkzeug** für Store-backed Heatmap-LOD- und zukünftige Derived-Caches:
  - `LocalTimelineStore.deleteDerivedCache(olderThan: Date, cacheKind: String?)` — TTL-basiertes Purge.
  - `LocalTimelineStore.pruneDerivedCache(maxEntries: Int, cacheKind: String?)` — Größen-basiertes Purge (LRU-artig auf `created`).
  - `deleteAll` löscht weiter `derived_cache` (FK-CASCADE-konform).
- Tests: `LocalTimelineDerivedCachePurgeTests.swift` (8 Cases, Linux-grün).
- Begleitend: `AppHeatmapModel.densityPointCap = 500_000` + `HeatmapStats.truncatedDensityPoints` (Legacy-Pfad), `ExportPreviewData` Doppel-Iter entfernt, Build-Warnings (visionOS, unused `withUnsafeMutableBytes`) bereinigt. Overview `scanCandidates` Refactor bleibt P1 (Risiko HOCH; bereits bounded).
- Store-Pfad bleibt **default OFF**, pre-production / feature-flagged. **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim).
