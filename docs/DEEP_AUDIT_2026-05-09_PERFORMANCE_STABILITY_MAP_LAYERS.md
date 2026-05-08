# Deep Audit 2026-05-09 — Performance, Stabilität, Map-Layer

**HEAD:** `d629467` (`fix: harden legacy map heatmap preview performance`)
**Branch / Remote:** `main` ↔ `origin/main` synchron
**Scope:** Audit-only, plus kleine eindeutige P0/P1-Fixes erlaubt. Keine neue große Implementierung. Kein Store default ON. Kein RTree-Migration. Keine Hardware-/46-MB-/Review-/TestFlight-Freigabe.

---

## 1. Executive Summary

Build 164 ist grün und enthält Technical Toggles, Store-backed Import, Store-backed DayList/DayDetail/DayMap, sichtbare Import-Progress/Cancel-UI, WAL Checkpoint/Recovery, adaptive Store-Map-Budgets, Foundation-only PointLayer-Provider, Heatmap-Hard-Cap, ExportPreview-Doppel-Iter-Fix und derived_cache-Purge-API. Der Store-Pfad ist vollständig pre-production / feature-flagged / **default OFF** und hat keine MainActor-blockierenden, unbounded Operationen mehr. Der Legacy-Pfad ist die Quelle der weiterhin beobachteten Abstürze: drei P0-Hotspots (`AppContentLoader.Data(contentsOf:)`, `AppExportQueries.projectedDays` Sort-vor-Limit, `AppOverviewTracksMapView.scanCandidates` Score-vor-Decimate) und zwei P1-Cluster (unbounded Filter-Caches in `AppSessionContent`, multipass LOD-Rebuild in `AppHeatmapModel`) sind weiter aktiv. 46-MB-Hardware-Gate bleibt **FAILED / pending**. Der „200-Routen"-Wunsch ist im Store-Pfad bereits sachgerecht abgelöst (`maxVisibleRoutes` 24/48/96/192 + `maxRouteCandidates` 256/512/1024/2048 + `truncatedRoutes`-Signal); Legacy benutzt weiter Score+Stride-Decimate. Der Punktelayer ist Service-/State-fertig, im Store-DayMap als Foundation-Status sichtbar (default OFF), aber **nirgends als echte MapKit-Marker gerendert**.

## 2. Harte Wahrheit / No-Claim-Zone

Was hier **NICHT** behauptet wird:

- 46-MB-Google-Timeline-Import ist **nicht** auf Hardware bestanden. Status verbatim: **FAILED / pending hardware retest**.
- Store-Pfad ist **nicht** Production-ready. Status: pre-production / feature-flagged / **default OFF**.
- Build 164 beweist **keinen** Hardware-Pass und **keinen** App-Review-Pass. Build 164 = Xcode Cloud build & archive grün.
- Die 200-Routen-Aufhebung im Store-Pfad ist **kein** „unlimited routes". Es bleibt ein adaptives Render-Budget pro Detail-Level mit ehrlichem Truncation-Signal.
- Punktelayer ist **nirgends** als MapKit-Marker aktiv. Phase-10B (Xcode-Handoff) steht aus.
- Legacy-Heatmap `densityPointCap=500_000` ist **nicht** durch ein echtes Hardware-Profil validiert. Wurde theoretisch gewählt (≈12 MB für `[WeightedPoint]`).
- Kein FileProtection `complete*`-Modus aktiv (nur `LocalTimelineFileProtection`-Skelett, Apple-only Aktivierung steht aus).
- Kein RTree-Migration (bewusst deferred).
- Live-Upload-Credentials und Standortdaten sind **nicht** in UserDefaults (nur Bool-Toggles).

## 3. Build-164-Status

| Aspekt | Status | Beleg |
|---|---|---|
| Xcode Cloud Build | grün (Build 164) | extern, in Doku referenziert |
| Archive/TestFlight upload | grün | Doku-Stand |
| Hardware-Run dokumentiert | **nein** | kein Run-Log im Repo |
| 46-MB-Pass | **FAILED / pending** | `docs/APPLE_VERIFICATION_CHECKLIST.md` |
| Store-Pfad default | **OFF** (Feature-Flag) | `LocalTimelineFeatureFlags.swift:8,19` |
| Technical Toggles enthalten | ja | `LocalTimelineTechnicalTestSettings.swift:26–67` |
| Memory Logging Resolved | ja | `ImportMemoryProbe.swift:32–35,73–74` |

## 4. 46-MB-Gate-Status

**Status verbatim:** `FAILED / pending hardware retest`.

Was Build 164 **NICHT** beweist:
- 46-MB-Import auf realer Hardware
- Crash/Jetsam-Verhalten ohne TestFlight-Toggle
- Importdauer / Memory-Peak unter Last

Vor Hardwaretest nötig (Toggles ON):
- Local Timeline Store Test Mode = ON
- Import Memory Logging = ON
- Memory Logging Resolved = enabled

Belege, die der Hardwaretest produzieren muss (alle in `docs/APPLE_VERIFICATION_CHECKLIST.md` zu hinterlegen):
- Build-Nummer + Git-SHA
- Gerät + iOS-Version
- Datei + Größe
- Importdauer + Memory-Peak
- Letzte 30 Memory-Log-Zeilen
- Crash/Jetsam ja/nein
- Progress + Cancel + DayList + DayDetail + DayMap + Export sichtbar ja/nein

Vorab am Mac/Linux möglich:
- Vollsuite (siehe Sektion 16)
- `LargeImportMemorySafetyTests` (50-MB-Sniffer, ZIP-Streaming)
- `GoogleTimelineStoreImporter*` Progress/Cancel/Rollback

Nur auf Hardware verifizierbar:
- Jetsam-Schwelle iPhone 15 Pro Max
- Realbenutzer-Drag-Drop / Files-App-Open-In-Place
- TestFlight-Toggle-UX

**Keine Statusänderung auf PASSED ohne echten Test.**

## 5. Store-End-to-End-Matrix

| Bereich | Status | Beleg | Bemerkung |
|---|---|---|---|
| Feature-Flag Default OFF | DONE | `LocalTimelineFeatureFlags.swift:8,19,27–64` | Args+Env+UserDefaults-Resolver |
| UserDefaults nur Bool | DONE | `LocalTimelineTechnicalTestSettings.swift:26–31` | keine Standortdaten |
| Backup Exclusion | DONE (iOS) | `LocalTimelineFileAttributes.swift:37–57` | Linux no-op |
| FileProtection | DEFERRED | `LocalTimelineFileProtection.swift:49–68` | Skelett, Apple-only Aktivierung offen |
| Schema/Migration | DONE | `LocalTimelineStoreSchema.swift:5–24` | userVersion=2 |
| WAL aktiv | DONE | `LocalTimelineStore.swift:41` | `journal_mode = WAL` |
| Foreign Keys | DONE | `LocalTimelineStore.swift:40` | `foreign_keys = ON` |
| derived_cache CRUD + Purge | DONE | `LocalTimelineStore.swift:202–357` | Insert/Replace/Delete/Prune (age + count) |
| deleteAll | DONE | `LocalTimelineStore.swift:183–196` | cascade-sicher |
| close/reopen | DONE | `LocalTimelineStore.swift:50–55` | `sqlite3_close_v2` safe |
| RTree | DEFERRED | `LocalTimelineStoreSchema.swift:17–19` | Bbox-Index aktiv |
| Import Progress sichtbar | UI-ACTIVE | `LocalTimelineImportProgressView.swift:11–107` | Phase + Counters + Cancel |
| Cancel + Rollback | DONE | `GoogleTimelineStoreImporter.swift:67,88,117,145` | + `writer.cancel()` ROLLBACK |
| skippedEntries | DONE | `LocalTimelineImportWriter.swift:117–120` | Importer + Writer separat |
| bestEffortTruncateWAL | DONE | `GoogleTimelineStoreImporter.swift:264,284` | wirft nicht |
| Reimport nach Cancel | PARTIAL | `AppContentLoader.swift:260–275` | Service da, Reimport-UX-Dialog offen |
| ZIP-Pfad | SERVICE-ONLY | `AppContentLoader.swift:451–500` | feature-flag-OFF default |
| Read Surface — DayList | DONE | `LocalTimelineDayListView.swift:14–100` | metadata-only |
| Read Surface — DayDetail | PARTIAL | `LocalTimelineDayDetailView.swift` | Lazy Map Phase 10B |
| Read Surface — DayMap | DONE (Foundation) | `LocalTimelineDayMapView.swift:18–49` | kein MapKit |
| PointLayer in DayMap-State | UI-ACTIVE (default OFF) | `LocalTimelineDayMapViewState.swift:76–80` | nur Status-Text |
| AppExport-Rekonstruktion im Store-Pfad | NO | bestätigt (siehe Provider) | Pflichtinvariante eingehalten |
| Vollständige `[Double]`-Materialisierung | NO | `CoordBlobIterator` lazy | Pflichtinvariante eingehalten |
| Store-default-ON | NO | Feature-Flag default OFF | Pflichtinvariante eingehalten |

## 6. Legacy-End-to-End-Matrix

| Bereich | Status | Bemerkung |
|---|---|---|
| Legacy DayList/Detail/Map | UI-ACTIVE | Default-Pfad |
| AppHeatmapModel.startPrecomputation | DONE (Cap 500_000) | hartes Cap, Multipass-LOD-Rebuild offen (P1) |
| AppOverviewTracksMapView.scanCandidates | RISK | Score auf full coords vor Stride-Decimate, P0 |
| ExportPreviewData | PARTIAL | Doppel-Iter gefixt, Sampling fehlt (P1) |
| AppContentLoader Data(contentsOf:) | RISK | unbounded JSON load auf Z.715 (P0) |
| AppSessionContent filter caches | RISK | drei unbounded Dicts (Z.82–84) (P1) |
| GPX/KML/GeoJSON Builder | PARTIAL | eager array-build, kein cancel-check (P2/P3) |

## 7. Performance-/Crash-Hotspots

Notation: `Datei:Zeile — Befund (Priorität / Aufwand)`. „MainActor?" und „Bounded?" werden expliziert.

### P0 (Crash- oder OOM-Risiko, Legacy-Pfad)

1. `AppContentLoader.swift:715` — `data = try Data(contentsOf: url)` ohne Größe-Cap, lädt bei 46-MB-Import bis ~150–200 MB transient. **MainActor:** abhängig vom Aufrufer, im Importflow off-Main; Risiko bleibt bei großem Hauptspeicherpeak. **Bounded:** nein. **Pfad:** Legacy + Store-Vorstufe. **Empfehlung:** in feature-flag-OFF-Pfad NICHT mehr genutzt; Legacy-Pfad sollte zwingend `GoogleTimelineStreamReader` nutzen, sobald Datei > Schwelle. **Aufwand: M.** Sofort fixbar: ja (Routing).
2. `Sources/LocationHistoryConsumer/Queries/AppExportQueries.swift` — `projectedDays`: sort + compactMap vor Limit-Anwendung; bei 65k Tagen transient ~80–130 MB. **MainActor:** wird im Query-Flow synchron aufgerufen. **Bounded:** ja (limit), aber zu spät. **Pfad:** Legacy. **Empfehlung:** Limit-Pruning vor Sort durchschleifen. **Aufwand: M.** Sofort fixbar: ja.
3. `AppOverviewTracksMapView.swift:~720–740` — `scanCandidates` berechnet Score und Bounds auf Full-Coords, decimiert danach via Stride. Test-Suite (`AppOverviewTracksMapViewTests`, ~26 Tests) pinnt Score-Reihenfolge. **MainActor:** off-Main via `Task.detached`. **Bounded:** indirekt (`pointBudget=2_000_000`, `candidateStorageCap=512`, `overlayLimit=150–300`). **Pfad:** Legacy. **Empfehlung:** P1-Folgeprompt mit doppelter Zielsetzung — Score-/Bounds-Berechnung lazy-fähig + Score-Invariant-Tests. **Aufwand: L.** Sofort fixbar: nein.

### P1 (Stabilität / Memory)

4. `AppHeatmapModel.swift:223–238` — `ensureDensityPrecomputation` rebuildet `lodGrids` für **alle** `HeatmapLOD.allCases` in einem Task-detached, schreibt das Endresultat-Dict synchron auf MainActor. **MainActor:** ja (final write). **Bounded:** indirekt via `densityPointCap=500_000`. **Pfad:** Legacy. **Empfehlung:** single-pass tile-sweep statt level-iteration; alternativ Streaming-Write der Grids pro LOD mit Yielding zwischen Levels. **Aufwand: M.**
5. `AppSessionState.swift:82–84` — drei unbounded Filter-Caches (`filteredOverviewCache`, `filteredDaySummariesCache`, `filteredInsightsCache`) ohne LRU-Eviction (anders als `projectedDaysCache` mit Limit 8). **MainActor:** ja (Session-State). **Bounded:** **nein**. **Pfad:** Legacy. **Empfehlung:** generischen LRU-Wrapper auf alle drei anwenden; Limit 16. **Aufwand: M.** Sofort fixbar: ja, aber separater Auftrag.
6. `ExportPreviewData.swift:71` — `allCoordinates = waypointAnnotations.map(\.coordinate) + pathOverlays.flatMap(\.coordinates)` — zweiter Materialisierungs-Pass für `computeRegion`. **MainActor:** ja (View-Init). **Bounded:** nein (kein Sampling). **Pfad:** Legacy. **Empfehlung:** `computeRegion` über min/max-Akkumulator beim Append in einer Schleife. **Aufwand: S.**
7. `Sources/LocationHistoryConsumer/Queries/DayMapData.swift` — Doppel-`map` über `path.points` (analog ehemaligem ExportPreview-Doppelbug). **MainActor:** ja. **Bounded:** nein. **Pfad:** Legacy. **Empfehlung:** single-loop. **Aufwand: S.** Sofort fixbar: ja.

### P2 (Latenz / Determinismus)

8. `LocalTimelineHeatmapGridAggregator` (Sortier-vor-Cap-Truncation) — bounded, aber sortiert alle Cells bevor `Array(sortedKeys.prefix(maxCells))`. Kein Crash-Risiko, nur Latenz. **Aufwand: S.**
9. `StoreBackedHeatmapDataProvider.readU32/readF64` — `withUnsafeMutableBytes` in tightem Sample-Loop bis 500k+ Punkte. Kein Crash, Profiling-Kandidat. **Aufwand: M.**
10. `LocalTimelineMapPointLayerProvider.swift:~129,141` — Visits/Activities `.flatMap.sorted` redundant materialisierend, bevor Filter-Loop läuft. **Aufwand: S.**
11. `AppOverviewTracksMapView` — `currentLoadToken` wird vor `Task.detached`-Start erfasst; minimales Race-Window. **Aufwand: S.**

### P3 (Polish)

12. `AppExportPreviewMapView` `Array(enumerated())` in `ForEach` (Identity reicht). Kein Risiko.
13. GPX/KML/GeoJSON Builder ohne `Task.isCancelled`-Checks im Element-Loop (nur Memory-Halt bei abgebrochenem Export). **Aufwand: S.**

### Store-Pfad — keine P0/P1 gefunden

Alle Store-backed Provider (`StoreBackedMapDataProvider`, `StoreBackedHeatmapDataProvider`, `LocalTimelineMapPointLayerProvider`) sind bounded, lazy, und schreiben kein vollständiges `AppExport`/`[Double]`. Truncation-Signale werden ehrlich gesetzt.

## 8. Map-Budget- / 200-Routen-Audit

Ergebnis: Im **Store-Pfad** existiert **kein** starres 200-Routen-Produktlimit mehr. Die Begrenzung ist detail-level-adaptiv:

| Detail-Level | maxVisibleRoutes | maxRouteCandidates | maxPointsPerRoute | maxTotalPoints |
|---|---|---|---|---|
| overview | 24 | 256 | 256 | 8 000 |
| low | 48 | 512 | 128 | 16 000 |
| medium | 96 | 1 024 | 256 | 32 000 |
| high | 192 | 2 048 | 512 | 64 000 |
| dayMap | 12 | 64 | 12 | 800 |

`maxRouteCandidates >= maxVisibleRoutes` (Precondition in `LocalTimelineMapPerformanceBudget`). `truncatedRoutes`/`truncatedPoints`-Signale werden ehrlich gesetzt. Tests pinnen Defaults monoton, **nicht** `200`.

**Legacy-Pfad** behält weiterhin `pointBudget=2_000_000`, `candidateStorageCap=512`, `overlayLimit=150–300`. Diese Caps sind ausreichend solange `scanCandidates` Score+Bounds **nicht** auf full coords macht (s. P0/3). Solange das so bleibt, ist Legacy-Overview unter Last fragil.

**Empfehlung Folgeschritte (Prioritäten getrennt):**
- Paging via `maxRouteCandidates`-Over-Fetch + `truncatedRoutes`-Signal in UI
- Viewport-/Zoom-getriggerter Detail-Level-Switch (existiert konzeptuell, UI-Binding offen)
- Cluster-Layer aktivieren (`maxClusters` schon im Budget vorhanden)
- Legacy-Doku-Kommentar zu `candidateStorageCap` als veraltet markieren

## 9. Punktelayer-Audit

| Karte | Provider | UI-Hook | MapKit Marker | Default | Bounded | Bemerkung |
|---|---|---|---|---|---|---|
| Store-DayMap | DONE | DONE (View-State) | **NO (nur Status-Text)** | OFF | ja | `LocalTimelineDayMapView` Foundation-only |
| Legacy DayMap (`AppDayMapView`) | NO | NO | nur Visit-Marker | ON | ja | kein PointLayer |
| Overview (`AppOverviewTracksMapView`) | NO | NO | Polylines | ON | indirekt | kein PointLayer |
| Heatmap (`AppHeatmapModel`) | NO | NO | Grid Cells | ON | ja (Cap 500k) | kein Marker-Layer |
| ExportPreview | NO | NO | Waypoints | ON | nein (kein Sampling) | siehe P1/6 |
| Live Tracking | NO | NO | Current-Loc + Polyline | ON | ja | kein Bulk-PointLayer |

**Befund:** Punktelayer-Infrastruktur ist solide (Models, Provider, Budgets, Tests, deterministische Sortierung, Cluster, Truncation-Signale). **MapKit-Rendering existiert auf keiner Karte.** Echter Sichtbarkeitsgewinn auf jede Karte ist Phase-10B Xcode-Handoff.

## 10. Heatmap-Audit

- Store-backed: `StoreBackedHeatmapDataProvider` + `LocalTimelineHeatmapGridAggregator` — bounded, lazy, derived_cache (LOD-Cache mit `lodCacheKind="heatmap-lod"`, Version 1, deterministischer LE-Codec). Cache-Invalidation via `clearHeatmapCache(importID:)`. **UI-Hook fehlt** — service-only.
- Legacy: `AppHeatmapModel` — Cap 500_000 aktiv, `truncatedDensityPoints`-Signal in `HeatmapStats`. P1-Risiko: multipass LOD-Rebuild + finale MainActor-Allokation.
- Tests: `LocalTimelineHeatmapGridAggregatorTests`, `StoreBackedHeatmapDataProviderTests`, `AppHeatmapRenderingTests` (Apple-only), `AppHeatmapModelGeometryTests` (Apple-only), `AppHeatmapModelEdgeCaseTests` (Apple-only).

## 11. Overview-Audit

- `AppOverviewTracksMapView` ist die einzige Top-N-Routen-Übersicht. Tests pinnen Counts, **nicht** Score-Reihenfolge. Risiko: stille Reordering bei Faktoränderung.
- `OverviewMapRenderProfile.resolve()` + Douglas-Peucker + strideDecimate halten Render-Pfad bounded; Score+Bounds auf Full-Coords sind das Hauptproblem.
- Empfehlung: P1-Folgeprompt mit Score-Invariant-Tests (`testScoreOrderingDeterministic_largeFixture`, `testScoreOrderingStableAcrossFilters`) plus minimaler Refactor.

## 12. ExportPreview-Audit

- Doppel-Iteration `path.points.map` (Coords + Times) ist gefixt. Single-Loop mit `reserveCapacity`.
- Sampling fehlt weiterhin: `pathOverlays` enthält **alle** Path-Coords; `allCoordinates` materialisiert sie nochmal für `computeRegion`.
- Preview/Export-Konsistenz: Tests pinnen `5 pts`, `CSVBuilder` nutzt `path.points.first/last`. Sampling braucht Test-Update (`5 pts` → range bracket).
- Empfehlung P1-Folgeprompt: `computeRegion` über min/max-Akkumulator + adaptives Sampling mit Pinning auf erst/letzten Punkt.

## 13. Store-backed Provider-/UI-Audit

| Bereich | Service | Tests | UI verkabelt | MapKit | Bounded | Default | Risiken | Nächster Schritt |
|---|---|---|---|---|---|---|---|---|
| StoreBackedMapDataProvider | DONE | DONE | PARTIAL | NO | DONE | OFF | Anti-Meridian Viewport | MapKit Hook (Phase 10B) |
| StoreBackedHeatmapDataProvider | DONE | DONE | SERVICE-ONLY | NO | DONE | OFF | UI fehlt | Heatmap-UI-Layer |
| StoreBackedExportWriter | DONE | DONE | SERVICE-ONLY | NO | DONE | OFF | UI fehlt | Export-Flow-Integration |
| LocalTimelineDayMapView | DONE (Foundation) | PARTIAL | UI-ACTIVE | NO | DONE | OFF | MapKit-Hook | Xcode-Runbook offen |
| LocalTimelineMapPointLayerProvider | DONE | DONE | PARTIAL (Status-Text) | NO | DONE | OFF | Cluster-Cell-Default | PointLayer-UI Toggle |
| Overview-UI (Store) | n/a | n/a | NO | NO | UNVERIFIED | n/a | Import-weite Geometrie | separater Auftrag |
| Heatmap-UI (Store) | SERVICE-ONLY | über Provider | NO | NO | DONE | n/a | Color-Palette / Map-Hook | UI-Layer |
| Export-UI (Store) | SERVICE-ONLY | über Writer | NO | NO | DONE | n/a | Selektions-/Format-UX | UI-Layer |

## 14. UI-/UX-/Optik-Audit

Implementiert (UI sichtbar):
- First Launch + Import Screen
- Testmode-Banner (`LocalTimelineImportProgressView:113–150`)
- Import Progress Card mit Phase + Bytes/Percent + Counters + Cancel-Button
- Cancel + Cancel-Result (Rollback)
- Technical Screen mit Toggles
- Memory Logging Anzeige
- Delete local data
- Store-DayList / Store-DayDetail
- Store-DayMap (Foundation-Status, kein MapKit)
- PointLayer-Status-Text in Store-DayMap (default OFF)

Vorschläge (NICHT implementiert, klar als Vorschlag markiert):
- Status-Badges „Service ready / UI pending / MapKit handoff offen"
- „Large Import Mode" sichtbar im UI
- Fortschritt zusätzlich in „Tag X von Y" / „Entries X von Y"
- ETA nur falls seriös ableitbar (sonst weglassen)
- Fehlerdetails kopierbar (Long-Press → Clipboard)
- Diagnostics-Export als ZIP (Build, SHA, letzte Logs)
- Safe Mode nach Crash (Feature-Flag-Override)
- Resume / Clear failed import
- Map Layer Panel (Points / Routes / Visits / Heatmap-Toggles)
- Cluster-Legende
- LOD-Legende
- „Optimized subset"-Hinweis
- Export Summary (Counts, Reihenfolge, Filter)
- TestFlight-Tester-Guide in der App

Dark Mode / Dynamic Type / Landscape / iPad: aus Code nicht abschließend audit-fähig (SwiftUI-Defaults greifen, aber kein UI-Snapshot-Test). **Nicht als „abgeschlossen" markieren.**

## 15. App-Store-/Privacy-/Policy-Audit (Engineering-Compliance, keine Rechtsberatung)

| Punkt | Status | Beleg |
|---|---|---|
| Local storage Application Support | OK | `LocalTimelineFileAttributes.swift` |
| Backup exclusion | OK (iOS) | `isExcludedFromBackup=true` |
| FileProtection complete* | DEFERRED | Skelett nur |
| UserDefaults: nur Bool? | OK | `LocalTimelineTechnicalTestSettings` |
| Standortdaten in UserDefaults | NEIN | grep clean |
| Keychain Upload-Token | n/a | außerhalb Scope |
| Live Upload getrennt | OK | separate Komponente |
| Privacy manifest | UNVERIFIED hier | `docs/PRIVACY_MANIFEST_SCOPE.md` |
| privacy.html | UNVERIFIED hier | `docs/privacy.html` |
| Delete löscht lokal | OK | `deleteAll` |
| TestFlight-Internal-Toggles sichtbar | OK | Technical Screen |
| App-Review-Risiko Toggle-Sichtbarkeit | RISK | „Local Timeline Store Test Mode" Label kann in Release-Build verständlicher / hidden sein. Empfehlung: vor Release-Submission Toggle-Block hinter `#if DEBUG || TESTFLIGHT` setzen. |

## 16. Test-Coverage-Matrix (verkürzt)

- Test-Dateien: **150**
- `swift test` Ergebnis dieses Audits: **1400 / 2 skipped / 0 failed** in 126.9 s (Linux, Swift 5.9). Identische Bilanz wie nach `d629467`.

| Bereich | Schutz | Lücke |
|---|---|---|
| Feature Flags | DONE | — |
| ImportMemoryProbe | DONE | Hardware-Pass offen |
| Store Import / Cancel / Progress | DONE | — |
| WAL Checkpoint | DONE | unter Last-Test |
| Recovery | DONE | partial-ZIP-Recovery |
| derived_cache Purge | DONE | unter laufender Query |
| DayList/Detail/Map | DONE | — |
| PointLayer (Store) | DONE | MapKit-Wiring |
| Heatmap (Store) | DONE | — |
| Heatmap (Legacy) | Apple-only | Memory-Stress |
| Overview | Apple-only | Score-Invariants fehlen |
| ExportPreview | Smoke | Sampling-Tests fehlen |
| StoreBackedExport | DONE | Streaming-Memory-Tests |
| Legacy fallback | DONE | — |
| AppFlow / AppSession / Wrapper | DONE | Filter-Cache-Eviction-Tests fehlen |

**Fehlende Tests P0/P1:**
- `AppOverviewTracksMapViewTests.testScoreOrderingDeterministic_largeFixture` (P1)
- `AppOverviewTracksMapViewTests.testScoreOrderingStableAcrossFilters` (P1)
- `AppSessionContentTests.testFilterCacheEvictionUnderLoad` (P1)
- `AppHeatmapMemorySafetyTests` (P1, Apple-CI)
- `LocalTimelineDerivedCachePurgeUnderQueryTests` (P1)
- `ExportCancellationTests.testGPXBuildCancelledMidway` (P2)
- `LocalTimelineStoreConcurrencyTests` (P0, falls echte Multi-Reader-Pfade entstehen — derzeit single-owning-thread)

## 17. Doku-Widersprüche

| Datei:Zeile | Aussage | Repo-Truth | Aktion |
|---|---|---|---|
| `README.md:56` | „1034 Tests, 2 Skips, 0 Failures (2026-05-08)" | aktueller Linux-Stand HEAD `d629467`: **1400 / 2 / 0** | **fix:** auf 1400/2/0 aktualisieren |
| `README.md:79` | Linux 1034/2/0, erwarteter Mac ~1133 | überholt | **fix:** synchronisieren auf 1400/2/0 |
| `wrapper/README.md:101–109` | Hardware-Acceptance 2026-05-07 ohne Build-Nummer | Build/SHA fehlt | **fix:** Build/SHA klarstellen oder „Build 74" markieren |
| `README.md:84` | „46-MB-Crashfall bleibt FAILED" — impliziter Fix-Eindruck | Vorbeugung im Legacy, Store ist default OFF | **fix:** Klarstellung Legacy vs Store |
| `CHANGELOG.md:111` | Test-Count 1306 (post FIX-1) | seither weitere Cases | **passt** (CHANGELOG ist chronologisch korrekt) |
| `LocalTimelineMapModels.swift:95–96` | Kommentar zu `candidateStorageCap=512` Legacy | im Store-Pfad nicht mehr geführt | **optional:** Doku-Cleanup |

Keine **falschen** „erledigt"-Markierungen oder unbewiesene Hardware-Claims gefunden. ROADMAP/NEXT_STEPS verwenden konsistent `[ ]` für Offenes.

## 18. P0/P1/P2/P3 Maßnahmenliste

| ID | P | Titel | Bereich | Datei/Zeile | Beleg | Risiko | Empfehlung | Aufwand | Tests | Doku | App-Store | sofort |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| L-01 | P0 | AppContentLoader Streaming-Force | Legacy-Loader | `AppContentLoader.swift:715` | `Data(contentsOf:)` | OOM bei 46 MB | Streaming-Reader für JSON > Schwelle | M | LargeImportMemorySafetyTests erweitern | yes | low | ja |
| L-02 | P0 | projectedDays Limit-vor-Sort | Legacy-Queries | `Sources/LocationHistoryConsumer/Queries/AppExportQueries.swift` | sort+compactMap vor limit | Memory-Spike | Pre-prune über filter+limit | M | neue Test-Suite | yes | low | ja |
| L-03 | P0 | Overview scanCandidates Score-Lazy | Legacy-Map | `AppOverviewTracksMapView.swift:~720–740` | full-coords pre-decimate | RAM/Latenz | Score-Invariant-Tests + minimaler Refactor | L | 2 neue Tests | yes | low | nein |
| L-04 | P1 | Filter-Cache LRU | Legacy-Session | `AppSessionState.swift:82–84` | unbounded Dicts | Memory-Leak | generischer LRU-Wrapper | M | EvictionTest | yes | low | ja |
| L-05 | P1 | Heatmap LOD single-pass | Legacy-Heatmap | `AppHeatmapModel.swift:223–238` | Multipass LOD | Latenz | tile-sweep | M | Apple-CI | yes | low | nein |
| L-06 | P1 | ExportPreview Sampling + Region-Akku | Legacy-Export | `ExportPreviewData.swift:71` | doppelter Pass | Latenz | Akkumulator + Sampling | S–M | Test-Update | yes | low | ja |
| L-07 | P1 | DayMapData Doppel-map | Legacy-Map | `Sources/LocationHistoryConsumer/Queries/DayMapData.swift` | doppelte path.points-Iter | Latenz | single-loop | S | smoke | yes | low | ja |
| S-01 | P2 | PointLayerProvider Filter-Lazy | Store-Map | `LocalTimelineMapPointLayerProvider.swift` | flatMap+sorted vor Filter | Latenz | filter-first | S | smoke | yes | low | ja |
| S-02 | P2 | StoreBackedHeatmap LE-Codec Profil | Store-Heatmap | `StoreBackedHeatmapDataProvider.swift` | tight loop | Latenz | bench | M | bench | yes | low | nein |
| L-08 | P3 | GPX/KML/GeoJSON Cancel-Check | Legacy-Export | Builder | eager append | UX | Task.isCancelled | S | cancel-test | yes | low | ja |
| L-09 | P3 | Overview load-token race | Legacy-Map | `AppOverviewTracksMapView` | Race-Window | stale render | Token in Task verschieben | S | smoke | yes | low | ja |
| D-01 | P1 | README Test-Zahlen aktualisieren | Doku | `README.md:56,79,84` | überholt | Vertrauen | Sync | S | — | yes | none | ja |
| D-02 | P2 | wrapper/README Hardware-Build klarstellen | Doku | `wrapper/README.md:101–109` | mehrdeutig | Vertrauen | Build/SHA | S | — | yes | none | ja |
| U-01 | P1 | Punktelayer MapKit-Hook | Store-Map UI | `LocalTimelineDayMapView` | Foundation-only | Feature unsichtbar | Phase 10B | L | UI/Snapshot | yes | none | nein |
| U-02 | P2 | Heatmap-UI für Store-Pfad | Store-Heatmap UI | n/a | service-only | Feature unsichtbar | Phase 10B+ | L | UI | yes | none | nein |

## 19. Konkrete nächste Prompts

1. **L-01**: „Refactor AppContentLoader.swift:715 to route file imports above 16 MB through `GoogleTimelineStreamReader` (streaming chunks 256 KB). Behalten: Fallback-Pfad für JSON < 16 MB. Tests: `LargeImportMemorySafetyTests` erweitern um Hybrid-Routing-Assertion. Kein UI-Wechsel."
2. **L-02**: „In `AppExportQueries.projectedDays`: `limit` vor `.sorted` durchschleifen. Wenn semantisch problematisch (Stable-Sort über alle), Top-N-Heap einsetzen. Tests: neue Suite `AppExportQueriesProjectionTests` mit 2 Cases (1k/65k Tage)."
3. **L-03**: „Overview `scanCandidates` Score-/Bounds-Berechnung lazy-fähig machen, ohne 26 bestehende Tests zu brechen. Vorher 2 Score-Invariant-Tests anlegen (`testScoreOrderingDeterministic_largeFixture`, `testScoreOrderingStableAcrossFilters`). Erst dann Refactor."
4. **L-04**: „Generischer `BoundedLRU<Key, Value>` Wrapper. Auf alle drei Filter-Caches in AppSessionContent anwenden, Limit 16. Test: 100 distinct Filter-Kombis → Cache-Größe ≤ 16."
5. **L-05**: „AppHeatmapModel LOD-Build single-pass: gemeinsame Tile-Cell-Aggregation, daraus alle LOD-Stufen ableiten. Apple-CI."
6. **L-06**: „ExportPreviewData: `computeRegion` über min/max-Akkumulator beim Coord-Append; optional Sampling auf `maxPathPreviewPoints` mit Pinning-Tests aktualisiert."
7. **U-01**: „LocalTimelineDayMapView MapKit-Hook hinter `#if canImport(MapKit)`: PointLayer als `MKAnnotationView` rendern, Default OFF, Toggle im Technical Screen."

## 20. Was bewusst NICHT behauptet wird

- Keine Aussage, dass der 46-MB-Import auf Hardware funktioniert.
- Keine Aussage, dass Build 164 App-Review oder TestFlight-Public-Phase passiert hat.
- Keine Aussage, dass der Store-Pfad Default-aktiv ist oder werden sollte.
- Keine Aussage, dass `densityPointCap=500_000` für alle realen Profile ausreicht.
- Keine Aussage, dass die 200-Routen-Begrenzung weg ist. Sie ist durch ein adaptives Render-Budget mit Truncation-Signalen ersetzt.
- Keine Aussage, dass der Punktelayer auf einer Karte als MapKit-Marker sichtbar ist.
- Keine Aussage, dass die Legacy-Hotspots in diesem Audit gefixt wurden. Die kleinen Doku-Korrekturen (D-01/D-02) sind erlaubt; Code-Refactors L-01..L-09 sind als Folgeprompts aufgelistet, nicht ausgeführt.
- Keine Rechtsberatung. Engineering-Compliance-Einschätzung in Sektion 15.
