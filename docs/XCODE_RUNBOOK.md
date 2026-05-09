# Xcode Runbook

## Zweck

Dieses Runbook beschreibt den kleinsten reproduzierbaren Xcode-Laufweg fuer das Swift-Package im Monorepo `LocationHistory2GPX-Monorepo`.

**Wichtig:** Dieses Runbook bezieht sich auf das Monorepo (`LocationHistory2GPX-Monorepo`), nicht auf das historische Split-Repo `LocationHistory2GPX-iOS`. Der Monorepo-Root enthält `Package.swift`; der Xcode-Wrapper liegt unter `wrapper/LH2GPXWrapper.xcodeproj`.
Es fokussiert bewusst nur den bestehenden Consumer-Scope:

- `LocationHistoryConsumer` bleibt der app_export-Consumer-Core
- `LocationHistoryConsumerDemo` bleibt Harness/Sample
- `LocationHistoryConsumerAppSupport` bleibt app-nahe Session-/State-/Composition-Schicht
- `LocationHistoryConsumerApp` bleibt die produktnaehere App-Shell fuer lokalen JSON-/ZIP-Import

Der aktuelle Scope umfasst bereits Karten, `Days`-Suche, Heatmap-Sheet, segmentierte `Insights`, gespeicherte lokale Live-Tracks und optionalen nutzergesteuerten Upload akzeptierter Live-Recording-Punkte. Weiterhin nicht Teil dieses Runbooks sind Producer-Logik, Cloud-/Account-Sync fuer importierte History und unbewiesene Apple-Review-Claims.

## L-04 Bounded LRU für AppSessionContent-Caches — Linux umgesetzt (2026-05-09)

`AppSessionContent` (in `AppSessionState.swift`) hat fünf bisher unbounded Filter-/Detail-Caches; ab dem L-04-Commit nutzen alle den neuen Foundation-only `BoundedLRU<K,V>` (`Sources/LocationHistoryConsumerAppSupport/BoundedLRU.swift`) mit Capacities 8/8/8/32/16; `projectedDaysCache` (8) ist auf dieselbe Abstraktion umgestellt. Semantik bleibt byte-identisch — Eviction triggert nur deterministische Recomputation. Tester sehen kein anderes UI-Verhalten. Auf Hardware sollte das nach langem Browsen mit vielen Filter-Wechseln eine kleinere Resident-Memory-Kurve zeigen (nicht messbar in dieser Runbook-Stufe).

## L-01 In-Memory-Import-Gate — Linux umgesetzt, Hardware-Aussage offen (2026-05-09)

`AppContentLoader.decodeFile(at:)` lehnt Full-Reads über 64 MiB jetzt kontrolliert ab (`AppContentLoader.maximumInMemoryImportBytes`). Google-Timeline-JSON streamt unverändert. Tester sollten beim Hardware-Retest darauf achten, dass eine LH2GPX-JSON / GPX / TCX > 64 MiB nun mit dem User-Facing-Title "File too large to load safely" abgewiesen wird statt OOM zu triggern. **46-MB-Google-Timeline-Gate bleibt FAILED / pending hardware retest** (Streaming-Pfad, vom L-01-Gate nicht berührt).

## Phase-10C Heatmap-Cap-Verifikation — Mac/Xcode-Pflicht (2026-05-08)

Phase-10C Heatmap-Cap-Verhalten (`AppHeatmapModel.densityPointCap = 500_000` + `HeatmapStats.truncatedDensityPoints`) ist unter MapKit/SwiftUI auf echtem Gerät zu verifizieren. Truncation-UX-Hinweis (UI muss kommunizieren, dass die Heatmap bei Cap-Treffer gekürzt ist) ist **Mac/Xcode-Pflicht** — auf Linux nicht überprüfbar. Legacy-Pfad-Verhalten ist nur bei Extremfällen (>500k density points) sichtbar. **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim).

## Phase-10B (Weg 3) PointLayer-UI-Hook — Mac/Xcode-Pflicht (2026-05-08)

Phase-10B PointLayer-UI-Hook in `LocalTimelineDayMapView` ist **Mac/Xcode-Pflicht** (MKMapView-Annotations + SwiftUI-Map.points werden nur dort getestet). Foundation-only Modelle (`LocalTimelineMapPointLayerModels.swift`) und Provider (`LocalTimelineMapPointLayerProvider.swift`) sind eingecheckt und Linux-getestet; UI-Verdrahtung in `LocalTimelineDayMapViewState` + `LocalTimelineDayMapView` ist WIP. Store-Pfad bleibt feature-flagged / default OFF. **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim).

## P1-C + P1-D: WAL-Checkpoint + Recovery-Test (2026-05-08)

Phase-10A-Folgecommit nach Deep Audit. Setzt **P1-C (WAL-Checkpoint-/Cleanup-Strategie)** und **P1-D (Recovery-Test für Mid-Import-Crash)** aus `docs/DEEP_AUDIT_2026-05-08_LOCAL_TIMELINE_STORE_AND_MAP.md` § 13 um, ausschließlich im Store-Pfad. Keine UI-Änderung; keine Schemaänderung; keine neue Dependency.

Was lokal getestet werden sollte:

1. `swift build` und `swift test` — erwartet **1345 / 2 skipped / 0 failed**.
2. `swift test --filter LocalTimelineStoreWAL` und `swift test --filter LocalTimelineStoreRecovery` decken die neuen Cases ab; existierende `GoogleTimelineStoreImporter`/`LocalTimelineImport*`/`LocalTimelineStoreLifecycle`/`StoreBackedMap`/`StoreBackedHeatmap`/`StoreBackedExport`/`AppFlow`/`AppContentLoader`-Filter bleiben grün.

API-Anker:

- `let info = try store.truncateWAL()` — hard-fail.
- `let info: LocalTimelineStore.WALCheckpointInfo? = store.bestEffortTruncateWAL()` — wirft nicht.
- `LocalTimelineStoreError.checkpointFailed(code:message:)` als neue Fehlerquelle der expliziten API.

Recovery-Vertrag (Linux-Simulation, **kein** echter iOS-Jetsam-Test):

- `store.close()` ohne `writer.finalize()`/`writer.cancel()` ⇒ SQLite verwirft die offene `BEGIN IMMEDIATE`-Transaktion. Reopen ⇒ keine `imports`-Row, FK-Konsistenz erhalten, neuer Import + `deleteAll()` möglich. Power-Loss-/Kernel-Kill-Verhalten auf Hardware bleibt eine separate Verifikation.

## P1-A + P1-B: Cancellable Local Timeline Import Progress (2026-05-08)

Phase-10A-Folgecommit nach Deep Audit. Setzt **P1-A (Import-Cancel-Pfad)** und **P1-B (Import-Progress-Surface)** aus `docs/DEEP_AUDIT_2026-05-08_LOCAL_TIMELINE_STORE_AND_MAP.md` § 13 um, **ausschließlich im Store-Pfad**.

Was lokal getestet werden sollte, bevor Build 159 ein Xcode-Cloud-Setup bekommt:

1. Lokal `swift build` und `swift test` (Linux ist die kanonische Test-Surface). Erwartet: 1332 / 2 skipped / 0 failed.
2. `swift test --filter "LocalTimelineImportProgress|LocalTimelineImportCancellation|LocalTimelineImportController|GoogleTimelineStoreImporterProgressCancel|AppFlowImportProgressCancel"` deckt die neuen P1-A/B-Cases ab.
3. In Xcode (macOS) den Wrapper laufen lassen, Store-Toggle aktivieren, eine Google-Timeline-JSON importieren. **Aktuell ohne UI-Hook**: Progress + Cancel sind als Service-Layer (`LocalTimelineImportController`) verfügbar, aber `wrapper/LH2GPXWrapper/ContentView.swift` und `LocalTimelineSessionLandingView` zeigen noch keinen Cancel-Button und keine Counter. Folge-Issue: SwiftUI-Anbindung — siehe `NEXT_STEPS.md`.

API-Ankerpunkte für die anstehende UI-Anbindung:

- `let controller = LocalTimelineImportController()`
- `await LH2GPXAppFlow.loadImportedFileEnvelope(at: url, source: .manual, importProgress: controller.progressSink, importCancellation: controller.cancellation)`
- `controller.cancel()` aus dem UI-Cancel-Button.
- `controller.latestProgress` für die aktuelle Anzeige; `controller.addObserver { snap in … }` für reaktive Updates.

**Vertrag bei Cancel:** Writer rollt die offene SQLite-Transaktion zurück, AppFlow gibt `EnvelopeImportOutcome.failure(title: "Import cancelled", clearBookmark: false)` zurück, **kein gültiger Teilimport** verbleibt im Store. Loader-Fehler ist `AppContentLoaderError.importCancelled(_:)`. Idempotent: ein bereits gecancelltes Token wirft beim erneuten Verwenden weiter `LocalTimelineImportCancellationError.cancelled` und schreibt nichts in den Store.

**Privacy-/Scope-Vertrag** unverändert: Progress speichert keine Standortdaten; Snapshots sind reine Counter + Phase + optionale Byte-Hints. Keine UserDefaults-Persistenz, keine Pfade, keine Tokens. **46-MB-Gate bleibt FAILED / pending hardware retest.** LocalTimelineStore bleibt **pre-production / feature-flagged / default AUS**.

**UI-Hook 2026-05-08 (Weg 2):**
- AppShellRootView + wrapper/LH2GPXWrapper/ContentView blenden während des Imports im Loading-Branch eine LocalTimelineImportProgressView ein.
- Cancel-Button nur sichtbar bei progress.isCancellable.
- Test-Mode-Banner sichtbar genau bei aktivem LocalTimelineTechnicalTestSettings.shared.localTimelineStoreTestModeEnabled.
- Aktivierung Test-Mode: Settings → Technical → "Local Timeline Store Test Mode" einschalten (UserDefaults-Bool, default OFF).
- Reimport nach Cancel: bestätigt durch Linux-Test AppFlowImportCancelRoutingTests.testReimportAfterCancelSucceeds.

## Deep Audit 2026-05-08 + AppBuildInfo Live Memory-Logging Mirror

Repo-Truth-Audit nach Build 158 abgelegt unter `docs/DEEP_AUDIT_2026-05-08_LOCAL_TIMELINE_STORE_AND_MAP.md`. P1-UX-Fix (FIX-1): `AppBuildInfo.isMemoryLoggingEnabled` ist jetzt computed (`var`) und liest live `ImportMemoryProbe.isLoggingEnabled`. Vorher fror der Wert beim Process-Start ein → "Memory Logging Disabled" in Build Info widersprach "Memory Logging Resolved Enabled" daneben. Regressions-Pin: `testAppBuildInfoMemoryLoggingReflectsLiveSettingsToggle`.

Linux-Vollsuite nach FIX-1: **1306 Tests, 2 Skips, 0 Failures**. **46-MB-Gate bleibt FAILED / pending hardware retest.** TestFlight-Build-158-Acceptance nicht im Repo dokumentiert.

## Build-158-Vorbereitung — interne Test-Toggles für TestFlight (2026-05-08, implementiert in commit `f7020f6`)

Build 157 ist Xcode Cloud grün und TestFlight-installierbar (Status „Überprüft", interne Tests erfolgreich). Keine Aussage über Apple-Review-Freigabe oder über das 46-MB-Hardwareverhalten — **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim).

Da TestFlight-Tester **keine Launch-Argumente / Environment-Variablen** setzen können, sind als Build-158-Vorbereitung zwei interne UserDefaults-Toggles in `AppTechnicalOptionsView` ("Internal Test Toggles") ergänzt:

- `LH2GPX.localTimelineStoreTestModeEnabled` — aktiviert den feature-flagged LocalTimelineStore-Pfad zusätzlich zu `LH2GPX_LOCAL_TIMELINE_STORE`.
- `LH2GPX.importMemoryLoggingEnabled` — aktiviert `ImportMemoryProbe` zusätzlich zu `LH2GPX_IMPORT_MEMORY_LOG`.

Persistenz über `LocalTimelineTechnicalTestSettings` (`final class` ObservableObject, `.shared` + `init(userDefaults:)`, default `false`, **nur Bool** — keine Standortdaten/Pfade/Tokens). Status-Row "Memory Logging Resolved" zeigt am Gerät den effektiven `ProcessInfo OR Settings`-State. Footer-Hinweis: "Internal/TestFlight only · Pre-production · Default off · No location data is stored in these settings".

**Aktivierungs-Reihenfolge**:

- **Lokale Xcode-Runs** (Mac/Xcode-Handoff): **Args/ENV bleiben primärer Aktivator** — `LH2GPX_IMPORT_MEMORY_LOG=1` / `LH2GPX_LOCAL_TIMELINE_STORE=1` über Run Scheme → Arguments. Beim Debug-Run weiter wie bisher; kein UI-Eingriff nötig.
- **TestFlight-Builds**: Args/ENV stehen Testern nicht zur Verfügung — **Toggles in Settings → Technical → "Internal Test Toggles"** verwenden. Der Resolver (`LocalTimelineFeatureFlags.resolve(arguments:environment:settings:)` / `ImportMemoryProbe.isEnabledForEnvironment(_:arguments:settings:)`) liest **beide Quellen**; Setting aktiviert **zusätzlich**, deaktiviert nichts. `ImportMemoryProbe.isLoggingEnabled` ist computed → Toggle wirkt ohne Relaunch.

LocalTimelineStore-Pfad bleibt **pre-production / feature-flagged / default AUS**. Live-Upload, Recording, Auth-Flows unberührt. **Keine ASC/Review/Hardware-Freigabe behauptet**, **keine Map-Phase-10B-Aussage**, **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim).

## Manuelle Release-Risiko-Abnahme

Manuelle Release-Risiko-Abnahme: siehe `docs/APPLE_VERIFICATION_CHECKLIST.md` Block „Manual Release Risk Acceptance Protocol". Deckt 46-MB-Crashfall, Live Activity / Dynamic Island / Lock Screen, iPad-Layout sowie ASC / TestFlight / Apple Review — alles vor App-Store-Submission durch Tester abzuhaken.

## Xcode Cloud Archive-Fail Build 155/156 — Compile-Fix `fix: resolve xcode heatmap grid key compile failure` (2026-05-08)

Builds **155** (Commit `06f81ae`) und **156** (Commit `5cb7783`) im Workflow „Release – Archive & TestFlight" sind mit Exit Code 65 fehlgeschlagen. Root Cause: zwei top-level `GridKey`-Definitionen im Modul `LocationHistoryConsumerAppSupport` — `HeatmapGridBuilder.swift` (`struct GridKey { let lat: Int32; let lon: Int32 }` hinter `#if canImport(MapKit) && canImport(SwiftUI)`-Guard, Linux ausgeschlossen, Apple aktiv) und `LocalTimelineHeatmapGridAggregator.swift` (`private struct GridKey { let lat: Int; let lon: Int }` file-scope). Auf Apple-Plattformen waren beide sichtbar → „Invalid redeclaration of 'GridKey'" + „ambiguous for type lookup" + Folgefehler „Cannot convert value of type 'Int' to expected argument type 'Int32'" auf Zeile 79 des Aggregators. Linux blieb grün, weil der MapKit-Guard auf Linux scharf ist. Fix: Aggregator-`GridKey` → `LocalTimelineHeatmapGridKey` (privat, file-scope). Heatmap-Logik, API, UI unverändert. `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj` referenziert die SPM-Package-Datei nicht direkt; keine doppelten Compile-File-Referenzen gefunden.

**Hinweis**: nach diesem Fix-Commit muss der Xcode-Cloud-Workflow „Release – Archive & TestFlight" **erneut ausgelöst** werden. Status: **PENDING** — bis dahin keine Aussage über echte Apple-Builds.

**Lehrsatz**: ein top-level Name (auch `private struct …` auf Datei-Ebene) ist auf Apple-Plattformen ambig, sobald eine andere Datei im selben Modul einen Top-Level-`GridKey` außerhalb eines auf Linux scharfen Plattform-Guards definiert. Linux-SwiftPM grün ist daher kein hinreichender Stellvertreter für Apple-Compile-Sichtbarkeit, wenn iOS-only Symbole hinter `canImport(MapKit)`/`canImport(SwiftUI)` parken. **Konsequenz für künftige PRs**: vor jedem Add eines Top-Level-Typs in `Sources/LocationHistoryConsumerAppSupport/` (oder in einem anderen Modul mit MapKit/SwiftUI-Plattform-Guards) im selben Modul nach Kollisionen suchen — Linux-Build allein beweist nichts.

**46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim). **KEINE Map-Phase-10B-Aussage.** Store-Pfad bleibt default AUS. **KEINE ASC/TestFlight-Freigabe behauptet** durch diesen Fix.

## LocalTimelineStore (Phase 1..10A abgeschlossen, Wrapper/Settings/DayList/DayDetail/DayMap-UI feature-flagged aktiv)

### Phase 10A — Feature-Flag-Test-Handoff Store-DayMap-UI-Surface (2026-05-08)

Stand 2026-05-08: **Phase 10A** ergänzt eine feature-flagged Store-**DayMap-UI-Surface** in der bestehenden `LocalTimelineDayDetailView`. Bei aktivem Feature-Flag (`LH2GPX_LOCAL_TIMELINE_STORE`) sieht der Tester pro Tag eine optionale Map-Sektion: "Load map" startet einen bounded Candidate-Load (path metadata, **kein `coord_blob`-Decoding**); "Decode all routes" toggelt einen bounded Geometrie-Decode innerhalb harter `Budget`-Grenzen (default 12 Routen / 256 Punkte pro Route / 4096 Punkte gesamt). Die View ist ein SwiftUI Placeholder (`LocalTimelineDayMapView`, `#if canImport(SwiftUI)`-guarded) **ohne MapKit-Import** — echte `MKMapView`-/`MKMultiPolyline`-Verdrahtung bleibt **explizit Phase-10B Mac/Xcode-Pflicht** (Linux-Server kann MapKit nicht bauen; Anti-Meridian-Behandlung gehört in Phase 10B/11).

**Mac/Xcode-Handoff für Phase 10B**: das Anbinden der echten MapKit-/`MKMapView`-/`MKMultiPolyline`-Verdrahtung an die Phase-10A-Placeholder-View (`LocalTimelineDayMapView`) muss am Mac/Xcode erfolgen. Eingangspunkt ist `LocalTimelineDayMapViewState`/`LocalTimelineDayMapSource` — die `routeCandidates`/`routeGeometry`-API ist bereits Foundation-only über `StoreBackedMapDataProvider` bedient; nur der SwiftUI/MapKit-Renderer ist zu ergänzen. Anti-Meridian-Behandlung (direktes min/max-Reduce statt naivem union der bbox-Spalten) gehört in denselben Schritt.

**Vollständige sichtbare Kartenmodernisierung wird NICHT behauptet.** Legacy-Map unverändert. Heatmap-/Overview-/Export-UI-Hook bleibt weiter **nicht hookt** und Phase-10B/11-Pflicht. Default-Rollout bleibt Legacy-AppExport (Flag-Off → byte-identischer Legacy-Pfad). **Keine Darwin FileProtection-Aktivierung**, **keine neuen iOS-Build-Schritte (außer dem Phase-10B-MapKit-Wiring)**, **keine ASC/TestFlight-Aussage**, **46-MB-Gate bleibt FAILED / pending hardware retest unverändert**.

### Phase 9B — Feature-Flag-Test-Handoff (2026-05-08)

Stand 2026-05-08: **Phase 9B** ergänzt eine feature-flagged Store-**DayList + sheet-basierte DayDetail-UI** über die bestehende Landing-View. Nach Setzen des Feature-Flags `LH2GPX_LOCAL_TIMELINE_STORE` (über `ProcessInfo.environment` oder Launch-Argument: `LH2GPX_LOCAL_TIMELINE_STORE=1`/`true`/`yes`/`on`, oder `--LH2GPX_LOCAL_TIMELINE_STORE` als bare arg, case-insensitive) und einem Google-Timeline-JSON- oder ZIP-mit-genau-einem-Timeline-Entry-Import sieht der Tester jetzt:

1. die `LocalTimelineSessionLandingView` mit Session-Metadaten (Day-/Path-/Visit-/Activity-Counts, Total Distance, Date Range, Source Filename, Created/Imported At), den sichtbaren Delete-Button **und** eine **Tagesliste** (`LocalTimelineDayListView`, newest-first, Datum / Routen / Visits / Distanz).
2. **Tippen auf einen Tag öffnet die sheet-basierte DayDetail-Ansicht** (`LocalTimelineDayDetailView`) mit Datum, Visits, Activities, Path-Metadaten und dem Hinweis "Path points available (not decoded)" — **kein eager `coord_blob`-Decoding, keine Karte**.
3. in Settings → Technical → "Local Timeline Store" weiterhin den Feature-Flag-Status (Enabled/Disabled), die Status-Zeile "Pre-production / Feature-flagged" und den Lösch-Button "Delete imported local data" mit kontrollierten States idle/running/succeeded/failed.

**Map/Heatmap-UI bleibt weiterhin nicht hookt** — selbst mit gesetztem Flag und geöffnetem DayDetail wird kein Map/Heatmap/Overview UI-Hook gegen `StoreBackedMapDataProvider`/`StoreBackedHeatmapDataProvider` aktiv; das bleibt Phase-10-Pflicht. Default-Rollout bleibt Legacy-AppExport (Flag-Off → byte-identischer Legacy-Pfad). **Keine Darwin FileProtection-Aktivierung**, **keine neuen iOS-Build-Schritte**, **keine ASC/TestFlight-Aussage**, **46-MB-Gate bleibt FAILED / pending hardware retest unverändert**.

### Phase 9A — Wrapper/AppFlow-Wiring + Settings-Delete-Button + Landing-View

Phase 9A bleibt unverändert wirksam: Wrapper + Package-AppShell sind auf den Envelope-Pfad (`loadImportedFileEnvelope` + `LH2GPXAppFlow.apply(envelopeOutcome:to:preserveOnFailure:)`) verdrahtet; Landing-View und Settings-Delete-Button sind UI-aktiv hinter dem Feature-Flag.

### Phase 1..8B — Foundation-only, Linux-testbar, nicht UI-aktiv

Stand 2026-05-08: **Phase 1..8B abgeschlossen**, isoliert, **nicht UI-aktiv** (Store bleibt pre-production). **Phase 8B ist Linux-testbar / Foundation-only — kein Apple-Handoff betroffen.** Phase 8B ergänzt: zentralisierter Heatmap-Doppelbug-Fix via Foundation-only Helper `Sources/LocationHistoryConsumer/AppHeatmapPathSampler.swift` (kanonische Priorität: `flatCoordinates` wenn vorhanden + gerade Element-Anzahl, sonst `points` Fallback; ungerade flatCoordinates gelten als malformed → kontrollierter Fallback auf `points`); `AppHeatmapModel.swift:55-77` ruft jetzt den Sampler auf statt der bisherigen Doppel-Iteration. Foundation-only Heatmap-Modelle (`LocalTimelineHeatmapModels.swift`), deterministischer Grid-Aggregator (`LocalTimelineHeatmapGridAggregator.swift`, cell-size pro Detail-Level overview=0.5°/low=0.1°/medium=0.02°/high=0.005°, hartes `maxCells`/`maxSamplesConsumed`), `StoreBackedHeatmapDataProvider.swift` (Foundation-only; `heatmapSamples` bounded sampling, `heatmapLOD` Grid-Aggregation optional cache-backed via `derived_cache`, `clearHeatmapCache`). Schema-Änderung in `LocalTimelineStoreSchema.swift`: neue **additive** Tabelle `derived_cache` mit FK auf `imports.id` und `ON DELETE CASCADE`; zwei neue Indizes; **`userVersion` bleibt 2** rein additiv, keine semantische Schema-Änderung. Store-CRUD `putDerivedCache`/`derivedCache`/`deleteDerivedCache`/`countDerivedCache`; `deleteAll()` löscht jetzt auch `derived_cache`. **RTree (`path_bounds`) bleibt kontrolliert deferred** (`paths.id` ist TEXT, RTree erwartet INTEGER `docid` → Surrogate-Integer-Mapping wäre Schema-breaking). 4 neue Linux-grüne Test-Dateien: `AppHeatmapModelGeometryTests` (7), `LocalTimelineHeatmapGridAggregatorTests` (7), `StoreBackedHeatmapDataProviderTests` (11 inkl. 50k synthetic store + cache hit/clear roundtrip), `LocalTimelineRTreeCapabilityTests` (dokumentiert RTree-Fallback). **Keine SwiftUI/MapKit/CoreLocation-Abhängigkeit, kein SwiftUI-Map/MKMapView-Hook, kein UI-Heatmap-Renderer-Hook in dieser Phase. Existierender SwiftUI-Heatmap-Renderer (`AppHeatmapView`) unverändert; konsumiert weiter `AppExport`. Keine neuen iOS-Build-Schritte; kein Apple-Handoff betroffen. Store-Pfad bleibt default AUS, weiterhin pre-production.** Phase 9 (offen vor UI-Rollout): RTree path_bounds (Schema-breaking), Wrapper/SwiftUI-Wiring, Settings-Delete-UI-Button, Map/Heatmap/Overview UI-Hook gegen Provider, Darwin FileProtection-Aktivierung, Export-UI-Hook gegen `StoreBackedExportWriter`, 46-MB-Hardware-Retest, TestFlight/Xcode-Cloud Build ≥100, Privacy-Doku-Update.

### Phase 1..8A — vorherige Stufen (unverändert)

 Phase 8A führt einen Foundation-only Store-backed Map Data Provider (`LocalTimelineMapModels` + `StoreBackedMapDataProvider` + `LocalTimelineRouteDecimator`) plus zwei additive bbox-Metadata-Indizes auf `paths` ein (`idx_paths_bounds_minmax`, `idx_paths_day_bounds`); `userVersion` bleibt `2` (rein additiv); RTree (`path_bounds` virtual table) bleibt Phase-8B-Pflicht. Keine SwiftUI/MapKit/CoreLocation-Abhängigkeit, **kein SwiftUI-Map/MKMapView-Hook, kein UI-Hook, kein Renderer-Wechsel** in dieser Phase. Keine neuen iOS-Build-Schritte; kein Apple-Handoff betroffen. 33 neue Linux-grüne Tests (4 neue Test-Dateien). **Weiterhin kein direkter UI-Hook**; Wrapper/SwiftUI-Wiring der Presentation-/ViewState-Schicht ist offene Phase-8-Pflicht. Auf Linux über die SQLite-C-API (`import SQLite3` via Apple-Plattformen bzw. `Sources/CSQLite/` Linux-Shim mit `pkg-config sqlite3`/`libsqlite3-dev`) gebaut und getestet. Phase 4 ergänzt Storage-Pfad-Resolver (`LocalTimelineStorageLocations` mit 4 Roots: DB unter `applicationSupportDirectory/LocationHistory2GPX/Imports/`, RenderCache unter `cachesDirectory`, ImportStaging + ExportStaging unter `temporaryDirectory`), Backup-Exclusion-Helper (`LocalTimelineFileAttributes`, Linux no-op), FileProtection-Kapselung (`LocalTimelineFileProtection`, Ziel `completeUnlessOpen`), Open-Lifecycle-Factory (`LocalTimelineStoreFactory`) und High-Level `deleteAllLocalTimelineData` über DB+WAL+SHM+RenderCache+ImportStaging+ExportStaging. Phase 5 ergänzt store-backed Streaming Export. Phase 6 ergänzt feature-flagged AppSession-Quelle: `LocalTimelineFeatureFlags`, `LocalTimelineSession`, `LocalTimelineAppSessionAdapter`, `LocalTimelineDeletionService`. **Phase 7A** ergänzt feature-flagged AppContentLoader-Hook über Envelope-Kapsel: `AppSessionContentSource` (Cases `inMemory(AppSessionContent)`/`localTimeline(LocalTimelineSession)`, `AppSessionContent` selbst NICHT erweitert), `AppSessionState.show(localTimeline:)` (Banner/Title aus Session-Metadaten, kein AppExport, keine Coord-Decode), `AppContentLoader.loadImportedContentEnvelope(...)` (Flag-Off → exakt der Legacy-Pfad byte-identisch; Flag-On + Google-Timeline-JSON oder ZIP-mit-genau-einem-Timeline-Entry → `.localTimeline`; andere Formate fallen kontrolliert auf den Legacy-Pfad zurück; neuer Error-Case `localTimelineStoreFailed`); Tests Linux-grün (3 neue Test-Dateien, 14 neue Cases: `AppSessionLocalTimelineSourceTests` 5, `AppContentLoaderLocalTimelineStoreTests` 5, `LocalTimelineFeatureFlagIntegrationTests` 4). **Phase 7B** ergänzt Foundation-only Presentation/ViewState-Schicht: `LocalTimelineDayListViewState`, `LocalTimelineDayDetailViewStateAdapter`, `AppSessionPresentationSource` (`AppSessionState`-Extensions `activeContent`/`isLocalTimelineActive`), `LocalTimelineDeletionPresentation` plus Service-layer Envelope-Hook im AppFlow (`LH2GPXAppFlow.loadImportedFileEnvelope(...) -> EnvelopeImportOutcome`; Legacy `loadImportedFile(...)` byte-identisch unverändert); 5 neue Test-Dateien (`LocalTimelineDayListViewStateTests`, `LocalTimelineDayDetailViewStateAdapterTests`, `AppSessionLocalTimelinePresentationTests`, `LocalTimelineDeletionPresentationTests`, `AppFlowLocalTimelineEnvelopeTests`). **Offene Darwin-Pflicht**: tatsächliche FileProtection-Aktivierung (`URLResourceKey.fileProtectionKey = .completeUnlessOpen` bzw. `SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN` an `sqlite3_open_v2`) muss auf Apple-Plattformen aktiviert und in einem Darwin-Hardware-Pass verifiziert werden — Phase 4 hat den Hook nur dokumentiert; Phasen 6/7A/7B haben ihn nicht angefasst. **Keine neuen iOS-Build-Schritte** in diesem Runbook (**weiterhin kein direkter UI-Hook** für DayList/DayDetail/Map/Heatmap/Overview/Export/Settings, **weiterhin pre-production**, kein App-Session-Switch auf Store als Default, keine automatische Migration; Store-Pfad ist gated by feature flag und niemals default-aktiv — Default-Rollout bleibt Legacy-AppExport). **Wrapper/SwiftUI-Wiring** der Presentation-/ViewState-Schicht ist **offene Phase-8-Pflicht**. Conditional-P0/P1-Gate (P0 falls 46-MB-Hardware-Retest FAILED, P1/P2 falls PASSED) ist in der Research-Doku dokumentiert.

## Voraussetzungen

- macOS mit Xcode und SwiftPM-Unterstuetzung fuer Swift Tools 5.9
- Package-Plattformen gemaess `Package.swift`:
  - iOS 16+
  - macOS 13+
- empfohlen: Xcode 26.3 oder neuer, solange das Paket unveraendert auf Swift 5.9 basiert

Wenn `xcode-select -p` nur auf die Command Line Tools zeigt, sind Xcode-CLI-Schritte trotzdem moeglich, solange das echte Xcode installiert ist. Dann entweder:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -list
```

und fuer SwiftPM-Tests auf derselben Maschine entsprechend:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

oder den aktiven Developer Directory lokal auf Xcode umstellen.

## Repo in Xcode oeffnen

Der vorgesehene Einstieg bleibt das Swift Package, nicht ein separates `.xcodeproj`.

```bash
cd /Users/sebastian/iOS-App
open Package.swift
```

Alternativ in Xcode:

1. `File > Open...`
2. `Package.swift` oder das Repo-Verzeichnis waehlen
3. Package-Resolution abwarten

## Relevante Schemes und Schichten

Die fuer diese Phase relevanten Schemes sind:

- `LocationHistoryConsumerApp`
  - produktnaehere App-Shell
  - import-first Startzustand
  - lokale LH2GPX- oder Google-Timeline-Datei oeffnen
  - Demo-Daten nur als Fallback
- `LocationHistoryConsumerDemo`
  - Harness-/Verifikationsoberflaeche
  - startet standardmaessig mit gebuendelter Demo-Fixture
  - kann auf Apple-Plattformen ebenfalls lokales `app_export.json` laden
- `LocationHistoryConsumer`
  - Consumer-Core fuer Contract, Decoder und Query-Layer
- `LocationHistoryConsumerAppSupport`
  - gemeinsame Session-, Loader- und Inhaltsdarstellung fuer App und Demo
- `LocationHistoryConsumerDemoSupport`
  - fixture-zentrierte Demo-Unterstuetzung und gebuendelte Sample-Ressourcen

## Empfohlener Xcode-Run fuer die produktnahe App-Shell

1. In Xcode das Scheme `LocationHistoryConsumerApp` waehlen.
2. Als Destination `My Mac` oder einen passenden Apple-Laufweg waehlen.
3. `Product > Build` ausfuehren.
4. `Product > Run` ausfuehren.

Erwarteter Startzustand:

- leerer import-first Screen
- Titel `Import your location history`
- primaerer Button `Open location history file`
- sekundaerer Button `Load Demo Data`
- optional sichtbare Recent Files / Clear-History-Aktionen, wenn bereits Imports vorliegen; Auto-Restore bleibt opt-in

## Demo-Daten in der App-Shell pruefen

Die produktnahe App-Shell darf Demo-Daten laden, bleibt aber nicht der primaere Einstieg.

Schritte:

1. App mit `LocationHistoryConsumerApp` starten
2. `Load Demo Data` klicken

Erwartet:

- Statuskarte `Demo data loaded`
- aktive Quelle `Demo fixture: golden_app_export_sample_small.json`
- Schema `1.0`
- Day-Liste mit `2024-05-01` und `2024-05-02`
- Day-Detail und Overview werden angezeigt
- Actions-Menue bietet danach `Open Another File`, `Reload Demo` und `Clear`

## Lokalen Import pruefen

Fuer den ersten lokalen Import muss kein echtes Produkt-Exportfile vorliegen. Eine Contract-Fixture aus dem Repo reicht fuer LH2GPX-Dateien; alternativ kann eine reale Google-Timeline-Datei verwendet werden:

- `Fixtures/contract/golden_app_export_sample_small.json`
- `Fixtures/contract/golden_app_export_no_days_zero.json`
- alternativ ein anderer `golden_app_export_*.json` Contract-Fall

Unterstuetzte Import-Formate: LH2GPX JSON/ZIP, Google Timeline JSON/ZIP, GPX 1.1 (`.gpx`), TCX 2.0 (`.tcx`). GPX- und TCX-Dateien koennen auch innerhalb von `.zip`-Archiven erkannt werden. Fixtures fuer GPX/TCX-Import: `Fixtures/contract/sample_import.gpx`, `Fixtures/contract/sample_import.tcx`.

Schritte:

1. App mit `LocationHistoryConsumerApp` starten
2. `Open location history file` oder spaeter `Open Another File` klicken
3. im Apple-Dateiimporter eine lokale JSON- oder ZIP-Datei waehlen

Erwartet:

- Statuskarte `Location history loaded` oder `Google Timeline loaded`
- aktive Quelle `Imported file: <dateiname>.json` oder `Imported file: <dateiname>.zip`
- Overview wird angezeigt
- Day-Liste und Day-Detail sind sichtbar
- ein weiterer `Open Another File`-Lauf ersetzt den aktuellen Inhalt

## Reset- und Fehlerpfade

Mindestens diese kleinen UI-Laufwege pruefen:

### Clear / Reset

1. nach Demo- oder Datei-Load `Clear` klicken
2. erwarteter Rueckfall in den import-first Leerlaufzustand

Erwartet:

- Status `No location history loaded`
- aktive Quelle `None`
- Buttons `Open location history file` und `Load Demo Data`

### Invalides JSON

1. lokal eine kaputte JSON-Datei bereitstellen, z. B. mit Inhalt `{`
2. ueber `Open location history file` importieren

Erwartet:

- Fehlzustand `Unable to open file` oder `Unsupported file format`
- bei leerem Vorzustand bleibt keine aktive Quelle
- bei bereits geladenem Inhalt bleibt letzter gueltiger Inhalt sichtbar

### Leerer Export / No Days

1. eine echte Zero-Day-Fixture oder ein reales `app_export.json` ohne Tage laden
2. bevorzugt: `Fixtures/contract/golden_app_export_no_days_zero.json`
3. auf Listen- und Detaildarstellung achten

Erwartet:

- Overview bleibt sichtbar
- Day-Liste zeigt `No Days`
- Detailbereich meldet, dass keine Day-Entries vorhanden sind

## Reproduzierbarer CLI-Launch

Fuer einen reproduzierbaren foreground-Start der App-Shell ohne manuelles Xcode-IDE `Product > Run` gibt es ein standardisiertes Script:

```bash
./scripts/run_app_shell_macos.sh
```

Das Script:

1. baut `LocationHistoryConsumerApp` per `swift build`
2. erstellt eine minimale `.app`-Bundle-Struktur unter `.build/AppBundle/`
3. startet die App per `open` als echte foreground-macOS-App

Das ersetzt die fruehere ad-hoc-Methode, das gebaute Binary manuell in eine temporaere App-Wrapper-Struktur zu kopieren. Die `.build/AppBundle/`-Ausgabe wird durch `.gitignore` (`.build/`) automatisch ignoriert.

## Weitere CLI-Hilfsbefehle

Die Xcode-IDE bleibt der bevorzugte manuelle Weg. Fuer reproduzierbare CLI-Pruefung koennen dieselben Schemes ueber das echte Xcode gebaut werden:

```bash
cd ~/Desktop/XCODE/iOS-App
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -list
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## Reale Verifikation in dieser Phase

Frischer Linux-Host-Truth (2026-05-08, HEAD `37a22b7` nach `34bc369` — Linux-Stabilisierung):

- `swift build` (Vollbuild): clean ✅
- `swift build --build-tests`: clean ✅
- `swift test`: **1034 Tests, 2 Skips, 0 Failures** ✅ (vorher 1033 vor 50k-Stress-Test in `LinuxStabilizationRegressionTests`).
- Erwarteter Mac-Stand (post-Linux-Stabilisierung, mit allen iOS-only Tests hinter `canImport(SwiftUI)`/`MapKit`/`CoreLocation`/`UIKit`): **~1133** (1033 Linux + ~100 iOS-only). Finale Mac-Run-Zahl wird nach Mac-Sync nachgetragen.
- Linux-SwiftPM-Bruch nach `34bc369` ist behoben durch HeatmapPreferenceEnums-Extraktion (`Sources/LocationHistoryConsumerAppSupport/HeatmapPreferenceEnums.swift`), OptionsPresentation-Hoisting, URL-/`autoreleasepool`-/`import Foundation`-Guards.
- **46-MB-Crashfall bleibt FAILED** bis Hardware-Retest auf iPhone 15 Pro Max (Mac/iPhone-Handoff, auf Linux-Server nicht durchführbar). Linux-Stabilisierung ändert iOS-Verhalten nicht.
- ASC/TestFlight Build ≥100 nicht angefasst.

Frischer Host-Truth (2026-04-29) — macOS, Xcode 26.3, iPhone 15 Pro Max (ios 26.3):

- `swift test`: 643 Tests, 0 Failures, 0 Skips ✅ (2× bestätigt)
- `xcodebuild -scheme LH2GPXWrapper -destination generic/platform=iOS build`: BUILD SUCCEEDED ✅
- `xcodebuild -scheme LocationHistoryConsumerApp -destination platform=macOS build`: BUILD SUCCEEDED ✅
- CI.xctestplan Wrapper-Unit-Tests (iPhone 17 Pro Max Simulator, iOS 26.3.1): TEST SUCCEEDED ✅
- **UITests 6/6 PASSED auf iPhone 15 Pro Max** (00008130-00163D0A0461401C) ✅
  - `testLaunch` × 4, `testAppStoreScreenshots`, `testDeviceSmokeNavigationAndActions`
  - `testDeviceSmokeNavigationAndActions` verifiziert auf Gerät: Demo-Load, Overview/All-Time-Filter, Heatmap, Insights Share, Export fileExporter, Live Start/Stop
- Wrapper Release-Signing fuer Xcode Cloud/App Store bereinigt: `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM = XAGR3K7XDJ`, keine feste Release-`PROVISIONING_PROFILE_SPECIFIER`, keine explizite Release-`CODE_SIGN_IDENTITY`, Buildnummer `45`
- frischer Host-Nachweis 2026-04-30: `xcodebuild archive` gruen (Build 45, v1.0); `xcodebuild -exportArchive` blockiert — exakter Fehler: `Failed to load profile. Profile is missing the required UUID property.` (Root Cause: 0 Signing-Identities + 0 Provisioning-Profile im lokalen Keychain; `security find-identity -v -p codesigning` ergibt 0 valid identities)
- Widget-Embed-Phase: `LH2GPXWidget.appex` wird mit `CodeSignOnCopy` eingebettet
- `git diff --check` / `git status --short` nur fuer den jeweils aktuellen Arbeitsstand wiederholen; fruehere Gruen-Angaben waren Zwischenstaende und gelten nicht pauschal fuer spaetere Worktrees

ASC-Truth (2026-04-30, historisch):
- `LH2GPX` Version `1.0` ist in App Store Connect eingereicht und steht auf `Warten auf Prüfung`
- auf der Versionsseite ist bewusst Build `52` sichtbar
- der Xcode-Cloud-Workflow `Release – Archive & TestFlight` zeigt erfolgreiche Builds `55`, `56`, `57`
- Review-Entscheidung: Build `52` bleibt in App Review; kein Nachreichen von `57` ohne Apple-Feedback oder bestaetigten release-kritischen Fehler
- App Review ist nicht mehr am Upload-Schritt blockiert, aber fuer Live Activity / Dynamic Island weiter nicht voll hardware-verifiziert

ASC-Truth (2026-05-06, aktuell):
- Build `74` (Version 1.0) ist nach Review-Response am 2026-05-05 **akzeptiert**, ASC-Status `Pending Developer Release` — bewusst nicht freigegeben; 1.0-Train geschlossen
- Builds `80`–`83` (1.0-Train) wurden wegen geschlossenem Train mit ITMS-90186 / ITMS-90062 verworfen — kein Code-Fehler
- `MARKETING_VERSION` auf `1.0.1` angehoben; ASC hat Version `1.0.1` angelegt
- Xcode Cloud Build `84` (1.0.1) erfolgreich (Archive ✓, TestFlight Internal ✓)
- Build `95` ist veraltet — `CURRENT_PROJECT_VERSION` lokal auf `100` angehoben (commit `8854eef`); Build `≥100` muss vor dem nächsten Submit aus Xcode Cloud getriggert werden, damit der MapLayerMenu-/Heatmap-Tier-2-/Tempolayer-/SIGABRT-Fix-Stand vom 2026-05-06 enthalten ist
- `swift test`: 964 Tests, 2 Skips, 0 Failures (lokal HEAD post-`70254ff`, 2026-05-06 nach Doku-/Wiring-Audit-Polish; vorher 949 unter `93109e0`)
- `xcodebuild -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.3.1' build`: BUILD SUCCEEDED (lokal HEAD post-`70254ff`, 2026-05-06)

Frischer Host-Truth (2026-03-31, historisch):

- Linux-Host mit Swift 5.9
- `swift test`: 228 Tests, 2 Skips, 0 Failures
- `git diff --check`: sauber
- `xcodebuild`: auf diesem Host nicht verfuegbar

Die nachfolgenden Apple-/Xcode-Bloecke bleiben historische Nachweise von Apple-Hosts und wurden in diesem Audit nicht neu ausgefuehrt.

Stand 2026-03-17 wurde auf einer echten macOS-/Xcode-Maschine Folgendes real geprueft:

- Host: macOS 15.7
- Xcode: 26.3 (`Build version 17C529`)
- `xcode-select -p` zeigte `/Applications/Xcode.app/Contents/Developer`
- das echte Xcode-CLI wurde fuer die dokumentierten Apple-Kommandos trotzdem explizit ueber `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` verwendet
- `xcodebuild -list` erkannte unter anderem die Schemes `LocationHistoryConsumerApp` und `LocationHistoryConsumerDemo`
- `xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build` lief erfolgreich durch
- das gebaute Binary `.../Build/Products/Debug/LocationHistoryConsumerApp` liess sich bauen und fuer die echte UI-Session starten; der foreground-App-Launch ist seit Phase 13 ueber `scripts/run_app_shell_macos.sh` standardisiert
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` lief fuer den damaligen Snapshot erfolgreich; dieser historische Lauf umfasste 28 Tests
- fuer den aktuellen Repo-Stand wurde am 2026-03-30 auf diesem Mac neu geprueft:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build`: BUILD SUCCEEDED
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumer-Package -destination 'platform=macOS' test`: 224 Tests, 0 Failures
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: 224 Tests, 0 Failures
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project /Users/sebastian/Code/LH2GPXWrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build`: BUILD SUCCEEDED
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project /Users/sebastian/Code/LH2GPXWrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -only-testing:LH2GPXWrapperTests test`: TEST SUCCEEDED
- Heatmap UX Batch 1 (2026-03-30) hat den aktuellen Core-Stand danach erneut per CLI abgesichert:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: 222 Tests, 0 Failures
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build`: BUILD SUCCEEDED
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumer-Package -destination 'platform=macOS' test`: 222 Tests, 0 Failures
  - dabei wurden nur Heatmap-UI-/Display-Details geaendert (ruhigere low-zoom Darstellung, lokale Controls fuer Deckkraft/Radius/`Auf Daten zoomen`, kleine Dichte-Legende); kein neuer Apple-Device-Lauf fuer das Sheet selbst
- Heatmap Visual & Performance Batch 2 (2026-03-30) hat den Renderer danach erneut per CLI abgesichert:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: 224 Tests, 0 Failures
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build`: BUILD SUCCEEDED
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumer-Package -destination 'platform=macOS' test`: 224 Tests, 0 Failures
  - dabei wurde die Heatmap auf geglaettete aggregierte Polygon-Zellen mit viewport-basierter Zellselektion, per-LOD begrenzten sichtbaren Elementen und wiederverwendbarem Viewport-Cache umgestellt; ein neuer Apple-Device-Lauf fuer das Sheet selbst fand in diesem Batch bewusst nicht statt
- Heatmap Color / Contrast / Opacity Batch 3 (2026-03-30) hat die visuelle Schicht des Polygon-/LOD-Renderers danach erneut per CLI abgesichert:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: 227 Tests, 0 Failures
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build`: BUILD SUCCEEDED
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumer-Package -destination 'platform=macOS' test`: 227 Tests, 0 Failures
  - dabei wurden die Farbpalette, die Intensitaetskurve und die interne 100-%-Deckkraft-Kennlinie der Heatmap sichtbar verstaerkt; LOD, viewport-basierte Zellselektion und Cache-Struktur blieben bestehen, und ein neuer Apple-Device-Lauf fuer das Sheet selbst fand in diesem Batch bewusst nicht statt
- der anschliessende Live-/Upload-/Insights-/Days-Batch vom 2026-03-30 wurde auf diesem Linux-Server nur gezielt abgesichert:
  - `swift test --filter Live`: gruen
  - `swift test --filter Insight`: gruen
  - `swift test --filter Day`: gruen
  - `swift test --filter Upload`: gruen
  - dabei wurden die Live-Seite, Upload-Zustaende, die Insights-Informationsarchitektur und die Default-Sortierung von `Days` funktional ausgebaut; ein neuer Apple-CLI- oder Apple-UI-Lauf fuer genau diese Batch-Aenderungen fand bewusst noch nicht statt
- fuer den anschliessenden Device-End-to-End-Block am 2026-03-30 wurde zusaetzlich ein echtes iPhone verwendet:
  - Geraet: `iPhone 15 Pro Max` (`iPhone16,2`), iOS `26.3 (23D127)`, via USB verfuegbar, entsperrt, Developer Mode aktiv
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -allowProvisioningUpdates -project /Users/sebastian/Code/LH2GPXWrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'id=00008130-00163D0A0461401C' -only-testing:LH2GPXWrapperUITests`: echter Device-Lauf
  - `LH2GPXWrapperUITestsLaunchTests.testLaunch` lief auf dem Geraet erfolgreich; der Wrapper startet auf aktueller Hardware stabil
  - `LH2GPXWrapperUITests.testAppStoreScreenshots` scheiterte nicht an Launch oder Signing, sondern an einer inhaltlichen Erwartung: statt leerem Import-State war bereits eine wiederhergestellte `location-history.zip` aktiv, deshalb erschien kein `Demo Data`-Button
  - der zugehoerige echte AX-Snapshot zeigte den Uebersichtsbildschirm mit aktiver importierter Quelle, sichtbarer `Heatmap`-Aktion und sichtbarem dediziertem `Live`-Tab
  - damit sind Wrapper-Launch, sichtbarer Auto-Restore und die Praesenz von `Heatmap`/`Live` auf Device belegt; echtes Oeffnen des Heatmap-Sheets, Live-Recording, Background-Recording und Upload-End-to-End wurden in diesem Batch nicht erreicht
- die 2 in Batch 1 noch offenen Test-vs-Code-Widersprueche sind in Batch 2 repo-wahr geklaert:
  - `AppPreferencesTests.testStoredValuesAreLoaded`: Test-Setup folgt jetzt dem Keychain-first-Produktpfad auf Apple
  - `DayDetailPresentationTests.testTimeRangeFormattingAvoidsRawISOStrings`: Test-Erwartung folgt jetzt der im Produktcode konsistent verwendeten Gedankenstrich-Formatierung
- ein manueller Xcode-Start auf dem verbundenen iPhone bleibt fuer diesen Batch ein positiver Teilbefund, wird hier aber bewusst getrennt von den CLI-Build-/Testresultaten gefuehrt
- echte interaktive Apple-UI-Laeufe wurden erfolgreich gegen die produktnahe App-Shell ausgefuehrt:
  - sichtbarer import-first Startscreen
  - `Load Demo Data`
  - `Open location history file` ueber nativen Apple-Dateiimporter mit gueltiger lokaler Datei
  - `Open Another File` zum Ersetzen des aktuellen Inhalts
  - `Clear`
  - invalides JSON mit sichtbarer Fehlermeldung bei erhaltenem letztem gueltigen Inhalt
  - echter Zero-Day-Import mit `No Days Available` und `No Day Details Available`
  - sichtbare Day-Liste und Day-Detail-Darstellung fuer Demo und gueltigen Import

Fuer die UI-Laeufe verwendete lokale Dateien:

- gueltiger Import: lokale Kopie von `Fixtures/contract/golden_app_export_sample_small.json`
- invalid: lokale Datei `lh2gpx_invalid.json` mit Inhalt `{`
- no-days: lokale Kopie von `Fixtures/contract/golden_app_export_no_days_zero.json`

Nicht separat als eigener Nachweis festgehalten:

- foreground-Run exakt ueber `Product > Run` in Xcode selbst; die reale UI-Verifikation dieser Phase lief gegen denselben Xcode-gebauten Binary-Output in einer temporaeren lokalen foreground-App-Wrapper-Struktur

## Bekannte Grenzen dieser Phase

- kein `.xcodeproj`, nur Swift Package
- keine Signierung, keine Distribution, keine Entitlements-Arbeit
- kein Cloud-/Account-Sync fuer importierte History; optionaler Server-Upload bleibt davon getrennt und ist hier nicht abschliessend Apple-review-verifiziert
- kein Auto-Resume laufender Live-Tracks; Background-Recording wurde historisch auf echter Apple-Hardware verifiziert, ist aber nicht fuer alle heutigen Review-Pfade erneut vollstaendig nachgewiesen
- keine frische Apple-Verifikation fuer das spaeter hinzugekommene Heatmap-Sheet inklusive der neuen lokalen UX-Controls und des spaeter nachgezogenen Aggregations-/Polygon-Renderers, den dedizierten `Live`-Tab oder Upload-Batching/Upload-Status
- Apple-Verifikation ersetzt nicht `swift test`, und `swift test` ersetzt keinen echten Apple-UI-Lauf
