# Deep Audit — Local Timeline Store & Map Readiness

**Datum:** 2026-05-08
**Branch / HEAD:** `main` · Start `f7020f6` (Build-158-Toggles)
**Audit-Umgebung:** Linux SwiftPM 5.9, kein Xcode, kein iOS-Simulator, kein Hardware-Gerät.
**Vorgänger-Audit:** `docs/DEEP_AUDIT_2026-05-06.md`

---

## 1 — Executive Summary

Der LocalTimelineStore-Pfad ist **strukturell vollständig** verdrahtet von Aktivierung über Import, Persistenz, Read-Surface, Day-Browser und Day-Detail bis zur Löschung. Build 158 fügt UserDefaults-Bool-Toggles hinzu, die den feature-flagged Pfad und das Memory-Logging aktivierbar machen, ohne dass der Tester `ProcessInfo`-Argumente setzen muss. Der Legacy-Pfad bleibt byte-identisch und ist getestet.

**Drei harte Schwächen sind in dieser Form weiterhin offen** (P0/P1):

1. **Map-/Heatmap-/Overview-/Export-UI im Store-Pfad ist nicht verdrahtet.** Die Producer (`StoreBackedMapDataProvider`, `StoreBackedHeatmapDataProvider`, `StoreBackedExportWriter`) sind komplett, aber `LocalTimelineSessionLandingView` zeigt nur Summary + DayList + Day-Detail-Sheet. Die Phase-Note macht das transparent, aber der Tester sieht weiterhin keine Karte.
2. **Import ist nicht abbrechbar.** `AppContentLoader` startet `Task.detached(priority: .userInitiated)`, aber es gibt kein Cancel-Hook bis zum `LocalTimelineImportWriter`. Bei großen Files/Memory-Pressure kann der Tester nur die App killen.
3. **WAL-Checkpoint/VACUUM ist nicht aktiv.** `PRAGMA wal_autocheckpoint` wird nicht gesetzt; nach wiederholten `deleteAll`-Zyklen wächst die DB-Datei monoton. `LocalTimelineStoreLifecycle.deleteAllLocalTimelineData` löscht WAL/SHM-Files mit, das funktioniert, aber zwischen zwei Imports gibt es keine Schrumpfung.

**Build 158 / Technical Toggles / TestFlight-Pfad sind sauber:** Singleton (`LocalTimelineTechnicalTestSettings.shared`) wird korrekt aus AppShellRoot, Wrapper und AppOptions konsumiert, OR-Semantik mit Args/ENV ist erhalten, Default OFF, UserDefaults-Scope ausschließlich Bool.

**Eindeutiger P1-UX-Bug gefunden und gefixt** (siehe §13 / FIX-1):
`AppBuildInfo.isMemoryLoggingEnabled` war als gespeicherter `let` definiert und fror den Wert beim Process-Start ein. Wenn der Tester den UserDefaults-Toggle umlegte, zeigte die Build-Info-Sektion weiter "Memory Logging Disabled", während direkt darunter "Memory Logging Resolved Enabled" stand. Fix in diesem Audit-Commit.

---

## 2 — Harte Wahrheit / No-Claim-Zone

Folgendes wird in diesem Audit **nicht** behauptet:

- Kein 46-MB-Hardware-Pass.
- Kein TestFlight-Build-158-Acceptance-Run.
- Keine App-Review-Freigabe für 1.0.1 oder den Store-Pfad.
- Keine vollständige Karten-Modernisierung.
- Keine fertige Heatmap-/Overview-UI im Store-Pfad.
- Keine UITest-Verifizierung auf realem Gerät seit dem letzten dokumentierten Hardware-Lauf.
- Kein Privacy-Manifest-Submission-Pass.
- Keine Aussage über das Verhalten bei iCloud-syncten UserDefaults — die Toggle-Keys sind ausschließlich Bool, aber iCloud-Sync wurde nicht verifiziert.

---

## 3 — Aktueller belegter Stand (Repo-Truth)

| Bereich | Stand | Beleg |
|---|---|---|
| Feature-Flag (Args/ENV) | Implementiert, OR-verknüpft, Default OFF | `LocalTimelineFeatureFlags.swift:66–84` |
| UserDefaults-Toggle (Build 158) | Implementiert, Bool-only, namespaced `LH2GPX.…` | `LocalTimelineTechnicalTestSettings.swift:26–67` |
| ImportMemoryProbe | Live-Resolver kombiniert Process-Cache + Settings-Bool | `ImportMemoryProbe.swift:32–75` |
| Store-Schema | userVersion=2, additive, IF NOT EXISTS, BBox-Indizes | `LocalTimelineStoreSchema.swift:24, 119–129` |
| WAL aktiviert | `PRAGMA journal_mode=WAL`, FK ON | `LocalTimelineStore.swift:40–42` |
| deleteAll-Vollständigkeit | DB rows + DB-File + WAL + SHM + RenderCache + Import-/Export-Staging + Recreate | `LocalTimelineStoreLifecycle.swift:54–88` |
| Backup-Exclusion | Darwin: `URLResourceKey.isExcludedFromBackupKey`; Linux: no-op | `LocalTimelineFileAttributes.swift:37–87` |
| Bounded Reads | DayList ohne Geometry, DayDetail Lazy, BBox aus Metadaten | `LocalTimelineStoreReader.swift:67–164` |
| `CoordBlobIterator` | Lazy decode pro Pfad, Malformed-Error gefangen | `LocalTimelineStoreReader.swift:155–164` |
| Day-Detail-Map-Surface (Phase 10A) | `LocalTimelineDayMapViewState` + Placeholder-View | `LocalTimelineDayMapView.swift`, `LocalTimelineDayMapViewState.swift` |
| Wrapper / AppShell-Gating | Routing über `LH2GPXAppFlow.loadImportedFileEnvelope` | `wrapper/LH2GPXWrapper/ContentView.swift:362–387`, `AppShellRootView.swift:273–291` |
| Legacy-Fallback | Bei `!flag` → byte-identisch zu vorher | `AppContentLoader.swift:149–206` |
| Tests | 1305 / 2 skipped / 0 failed (Linux SwiftPM, 2026-05-08) | siehe §11 |
| Heatmap-Doppelbug | Phase-8B zentral via `AppHeatmapPathSampler`, `LocalTimelineHeatmapGridAggregator` | `LocalTimelineHeatmapGridAggregator.swift` |
| Xcode-Cloud-GridKey-Fix | commit `96ae6a2` | `LocalTimelineHeatmapGridAggregator.swift` (renamed `GridKey`) |

---

## 4 — Nicht belegter Stand

| Behauptung | Status | Begründung |
|---|---|---|
| 46-MB-Crash auf Hardware behoben | **FAILED / pending** | Letzter dokumentierter Hardware-Lauf 2026-05-05, Build 74. Build-158-Hardware-Run nicht dokumentiert. |
| Phase 158 in TestFlight installierbar und verifiziert | **Teil-belegt** | Build verfügbar laut Doku/UI-Screenshot; eigentliche Verifikations-Suite (UITests) auf Build 158 nicht im Repo dokumentiert. |
| Map-/Heatmap-/Overview-/Export-UI im Store-Pfad | **OFFEN** | Producer existieren, UI-Hooks fehlen. Phase-Note ist transparent. |
| RTree für Path-Bounds | **DEFERRED, dokumentiert** | Schema-Migration auf Integer-Surrogate wäre breaking. |
| FileProtection iOS-aktiv | **Platzhalter** | Code dokumentiert iOS-Rollout-Ziel, aber Aktivierung steht aus (`LocalTimelineFileProtection.swift:60–79`). |
| MetricKit / MXCrashDiagnostics | **Nicht implementiert** | Nur eigenes `[LH2GPX_MEMORY]` Print-Logging. |
| Import-Cancel-API | **Fehlt** | Detached-Task ist zwar `Task.cancel()`-fähig, aber kein UI-Hook und kein expliziter Writer-Cancel-Path. |
| Background-Task / Screen Lock-Resilienz | **Nicht implementiert** | Keine `UIApplication.beginBackgroundTask()`-Wraps um Imports. |
| Multi-process Store-Zugriff (Widget) | **Nicht safe-by-design** | Store ist Single-Writer; Widget-Zugriff aktuell nicht vorgesehen. |

---

## 5 — End-to-End-Verdrahtungs-Matrix

| Stufe | Komponente | Status | Datei:Line |
|---|---|---|---|
| Aktivierung | `LocalTimelineFeatureFlags.resolveFromProcess(settings:)` | ✓ | `LocalTimelineFeatureFlags.swift:57–64` |
| Aktivierung | `LocalTimelineTechnicalTestSettings.shared` | ✓ | `LocalTimelineTechnicalTestSettings.swift:35` |
| Aktivierung | `AppOptionsView` Tester-Toggles | ✓ | `AppOptionsView.swift:704–727` |
| Loader | `AppContentLoader.loadImportedContentEnvelope` | ✓ | `AppContentLoader.swift:149–206` |
| Importer | `GoogleTimelineStoreImporter` (JSON + ZIP-Single) | ✓ | `GoogleTimelineStoreImporter.swift:30–85` |
| Importer | LH2GPX-ZIP Multi-Entry | Legacy-Fallback | `AppContentLoader.swift:339–370` |
| Writer | `LocalTimelineImportWriter` | ✓ | `LocalTimelineImportWriter.swift` |
| Store | `LocalTimelineStore` | ✓ (WAL, FK, Schema v2) | `LocalTimelineStore.swift:29–55` |
| Store | `LocalTimelineStoreLifecycle.deleteAllLocalTimelineData` | ✓ vollständig | `LocalTimelineStoreLifecycle.swift:54–88` |
| Read | `LocalTimelineStoreReader.days/dayDetail/pathBoundingBox/coordinateSequence` | ✓ Bounded | `LocalTimelineStoreReader.swift:67–164` |
| Read | `StoreBackedMapDataProvider` mit Budgets | ✓ | `StoreBackedMapDataProvider.swift:44–147` |
| Read | `StoreBackedHeatmapDataProvider` LOD-Cache | ✓ | `StoreBackedHeatmapDataProvider.swift` |
| Read | `StoreBackedExportWriter` GPX/KML/GeoJSON/CSV streaming | ✓ Producer | `StoreBackedExportWriter.swift:36–113` |
| UI | `LocalTimelineSessionLandingView` Header + Summary + DayList + Delete | ✓ | `LocalTimelineSessionLandingView.swift:58–89` |
| UI | DayDetail Map-Section (Load button, decode toggle) | ✓ Placeholder | `LocalTimelineDayDetailView.swift` |
| UI | DayMap real MapKit-Render | **OFFEN** (Phase 10B) | n/a |
| UI | Heatmap im Store-Pfad | **OFFEN** | n/a |
| UI | Overview im Store-Pfad | **OFFEN** | n/a |
| UI | Export-Hook im Store-Pfad | **OFFEN** | n/a |
| UI | Import-Cancel-Button | **OFFEN** | n/a |

---

## 6 — Store-Pfad-Audit

### 6.1 Aktivierung
- Default OFF dreifach garantiert: Args fehlen, ENV fehlt, UserDefaults-Bool default `false`.
- OR-Semantik (`isStoreEnabled(args, env) || settings.localTimelineStoreTestModeEnabled`) deaktiviert nichts; Aktivierung über mehrere Pfade möglich.
- Singleton `LocalTimelineTechnicalTestSettings.shared` in beide App-Shells (`AppShellRootView`, `wrapper/LH2GPXWrapper/ContentView`) verdrahtet.
- UserDefaults-Scope strikt Bool: Test `testOnlyBoolsAreStoredUnderToggleKeys` pinst es regression-fest.

### 6.2 Import-Pfad
- Streaming via `GoogleTimelineStreamReader.IncrementalParser` (Limits: 8 MB / Element, 256 MB / File).
- ZIP-Single-Google-Timeline: extrahiert Eintrag und ruft `importFromData()` mit Streaming-Parser auf — kein `[Double]`-Aufbau.
- ZIP mit mehreren Einträgen oder LH2GPX-Mix: Legacy-Fallback, kontrolliert.
- Implizite Transaktion in `LocalTimelineImportWriter` (BEGIN IMMEDIATE / COMMIT bei `finalize()`); bei Fehler `cancel()` → Rollback.
- **Skipped Entries** werden im Code dokumentiert ("silently skipped"), aber nicht gezählt und nicht in der UI gezeigt.

### 6.3 Persistenz
- Schema-Version 2, additive Statements idempotent (`IF NOT EXISTS`).
- WAL aktiv, FK ON. Kein expliziter `wal_autocheckpoint`/`VACUUM` zwischen Imports.
- `deleteAll` löscht: rows · DB · WAL · SHM · RenderCache · ImportStaging · ExportStaging und recreated leere Verzeichnisse.
- Backup-Exclusion auf alle Roots + DB-File.
- FileProtection: dokumentierter Platzhalter, iOS-Aktivierung steht aus.

### 6.4 Read-Surface
- DayList: nur Summary-Felder (kein `coord_blob`).
- DayDetail: Visits, Activities, Path-Metadaten (BBox + Counts) — **kein** Geometry-Read eager.
- Geometry nur on demand via `dayRouteCandidates` + `routeGeometry`, dezimiert über `LocalTimelineRouteDecimator`.
- Bounds primär aus Path-Metadata, Fallback aus Visits-Coords.
- Malformed `coord_blob` → kontrollierter Error bis ins UI/Export.

### 6.5 Build-158-Toggles im Detail
- `localTimelineStoreTestModeEnabled` aktiviert den Loader-Pfad (zusätzlich zu Args/ENV).
- `importMemoryLoggingEnabled` aktiviert die Probe **live** pro Aufruf (`ImportMemoryProbe.isLoggingEnabled` ist computed).
- "Memory Logging Resolved" zeigt den Live-Status; nach FIX-1 mirror't auch die Build-Info-Sektion live.

---

## 7 — Legacy-Pfad-Audit

- Flag deaktiviert → `AppContentLoader.loadImportedContent()` byte-identisch zur Pre-Phase-6-Implementation.
- Flag aktiviert + nicht-Google-Format (LH2GPX JSON, GPX, TCX, multi-entry-ZIP) → Legacy-Fallback transparent.
- Tests `AppContentLoaderLocalTimelineStoreTests` und `LocalTimelineFeatureFlagIntegrationTests` decken Beide Pfade.
- Risiko: Wenn Tester gleichzeitig Toggle ON setzt und einen LH2GPX-Mix-ZIP importiert, fällt der Code auf Legacy zurück, ohne dass die UI das kommuniziert — ist kein Bug, aber UX-Hinweis fehlt.

---

## 8 — Memory-/Stabilitäts-Audit

| # | Risiko | Belegt | Empfehlung | Prio | Aufwand |
|---|---|---|---|---|---|
| S1 | Lange Single-Transaktion bei großen Imports (kein SAVEPOINT-Batching) | `LocalTimelineImportWriter` | OK für <1 M Rows; SAVEPOINT-Batches in Phase 9+ erwägen | P3 | M |
| S2 | Kein WAL-Checkpoint zwischen Imports → DB wächst monoton | `LocalTimelineStore.swift:40–42` | `PRAGMA wal_checkpoint(TRUNCATE)` nach `deleteAll`/`finalize` | P1 | S |
| S3 | Kein `VACUUM` nach großen Deletes | wie oben | optional Phase 9+; konfigurierbar | P3 | M |
| S4 | LH2GPX-ZIP entpackt vollständig in RAM-Array vor Decode | `AppContentLoader.swift:339–370` | Eintragsweise streamen wie Google-Timeline | P2 | M |
| S5 | Kein Import-Cancel-API | `AppContentLoader`, `LocalTimelineImportWriter` | Task.isCancelled-Check pro Element + writer.cancel() Hook | P1 | M |
| S6 | Keine Progress-Anzeige (Entry-Count / Bytes) | `AppContentLoader.swift:73–86` | `ImportPhase.parsing(processedElements:totalEstimate:)` | P1 | M |
| S7 | Recovery nach App-Kill mid-Import nicht regression-getestet | `LocalTimelineStore` | Test: open → write → close ohne commit → reopen → assert empty | P1 | S |
| S8 | Kein `didReceiveMemoryWarning`-Cancel-Hook | `ImportMemoryProbe.swift:126–131` | UI-Layer: Notification → Task.cancel() | P2 | S |
| S9 | Logging via `print()` statt `os.Logger` | `ImportMemoryProbe.swift:79–90` | Privacy-Modernisierung später | P3 | M |
| S10 | Kein MetricKit-Hook | — | Phase 9+ | P3 | M |
| S11 | Background-Task-Wrap fehlt; Screen-Lock kann Import drosseln | `AppContentLoader.swift:107, 219` | Phase 9+ | P2 | M |
| S12 | Security-scoped resource start/stop pairing nicht im Loader-Layer | `AppContentLoader` | Doku-Klarstellung, dass Caller verantwortlich ist | P2 | S |
| S13 | App-Group / Widget-Reader nicht definiert für Store | — | Doku: Store ist private | P3 | S |
| S14 | Skipped-Entry-Count nicht visualisiert | `GoogleTimelineStoreImporter` | UI-Surface in Phase 9+ | P3 | S |

---

## 9 — Map-/Heatmap-/Overview-Audit

- **MapDataProvider:** Doppelte Budget-Enforcement (Routes-Cap + Points-Cap), `truncatedRoutes` und `truncatedPoints` sauber. Kein Edge-Case-Test für Budget-Overspill.
- **HeatmapDataProvider:** LOD-Cache vorhanden; Doppelzählung über GridKey-Aggregation bewusst gelöst, aber kein expliziter Test für Grid-Collision (4 Pfade mit identischem lat/lon-Snap).
- **MapKit-Render:** Heute Placeholder/Text-List in `LocalTimelineDayMapView`. Echte `MKPolyline` Phase 10B (Xcode-Handoff).
- **Overview im Store-Pfad:** existiert nicht. Legacy-`AppOverviewSection` arbeitet ausschließlich auf `AppExport`.
- **Heatmap-UI im Store-Pfad:** existiert nicht.
- **Map-Snapshot in DayList:** nicht implementiert; aktuell nur Summary-Row pro Tag.

---

## 10 — UI-/UX-/Optik-Audit

### Stark
- Wrapper/AppShell-Gating zwischen Legacy- und Store-Session sauber.
- Phase-10A-Hinweis im Day-Detail "Coordinates remain on disk until you tap Load" ist ehrlich.
- Accessibility-Identifier durchgängig gesetzt.
- Dark Mode standardmäßig.

### Schwach (Vorschläge, nicht implementiert)
- Build-Info "Memory Logging" Disabled vs. "Memory Logging Resolved" Enabled war irreführend → **Fix in FIX-1**.
- Drei Memory-Logging-Felder (Build Info / Toggle / Resolved) auf einer Seite ohne Schichten-Erklärung → klarer Header pro Layer.
- Kein "Test Mode aktiv"-Banner — Tester sieht nicht offensichtlich, dass Feature-Flag-Pfad an ist.
- Kein Cancel-Button während Import.
- Keine Confirmation vor `deleteAll`.
- Empty-State (Store-Pfad) zu technisch ("not wired in this build").
- Skeleton/Loading-States generisch.
- Dynamic Type / Landscape iPad noch nicht spezifisch geprüft.
- App-Store-Screenshot-Reife: Phase-Hinweise sollten in Release-Builds nicht prominent sein.

---

## 11 — Testabdeckung

**Linux SwiftPM gesamt:** 1305 Tests · 2 skipped · 0 failed (`swift test`, 2026-05-08, post-FIX-1 → 1306 Tests).

**Stark:**
- GoogleTimelineStreamReader: Happy + Error-Pfade.
- GoogleTimelineStoreImporter: Visit/Activity/Path + Skip-Cases.
- LocalTimelineImportWriter: Multi-Day, Skip, Rollback, BBox.
- LocalTimelineFeatureFlags + Settings: 12 Tests, default OFF, Persistenz, OR-Semantik, Bool-only-Pin.
- ImportMemoryProbe: 16 Aktivierungs-Tests inkl. Settings-Live-Pfad und Build-Info-Mirror.
- LocalTimelineStoreReader / -BoundedRead / -ReadPersistence: vorhanden.
- StoreBackedExportWriter: 4 Formate fixture-getestet.
- Wrapper-Routing: Envelope-Cases (Legacy, Store, Failure).

**Schwach / fehlend:**
- ZIP-Import-End-to-End (GoogleTimelineStoreImporter via ZIP-URL) nur indirekt über `ZIPGoogleTimelineStreamingPathTests` und `AppContentLoader`.
- Recovery nach App-Kill mid-Import (WAL-Behavior, Reopen).
- Malformed-`coord_blob` mid-decode (gibt es nur happy-path-Tests).
- Schema-Migrations-Test (v1→v2 vorwärts).
- Heatmap-Grid-Collision (Doppelzählung).
- DayMap-Budget-Overspill.
- `deleteAllLocalTimelineData` mit echten RenderCache-/Staging-Inhalten.
- Cancel-Pfad (Task-Cancel mid-Import → writer.cancel()).
- MainActor-Marshalling der `onPhase`-Callbacks.

---

## 12 — Doku-Widersprüche

1. **`wrapper/README.md` Hardware-Datierung 2026-05-07 vs. letzter belegter Hardware-Lauf 2026-05-05** → klären.
2. **`README.md` Hardware-Disclaimer** erwähnt "2026-05-05 offen", nennt aber neue Commits (Hero-Map 2026-05-06, Toggles 2026-05-08) nicht explizit als un-verifiziert.
3. **Build-158-Toggle-Beschreibung in `XCODE_RUNBOOK.md`** war vor Build-158-Commit `f7020f6` als geplant formuliert; Code ist jetzt im Repo, Doku müsste auf "implementiert (commit f7020f6)" wechseln.
4. **Phase-10A-Status:** in `MAP_ARCHITECTURE_AUDIT.md` und `XCODE_RUNBOOK.md` konsistent als "Placeholder, kein MapKit". OK.
5. **Test-Zahlen-Update:** README/wrapper/CHANGELOG zitieren 1034 (Linux-Stabilisierung HEAD `37a22b7`); aktueller Server-Stand ist 1305 (Phase 10A + Build 158). Doku muss aktualisiert werden.
6. **`docs/DEEP_AUDIT_2026-05-06.md`** kennt commit `96ae6a2` (GridKey-Fix) und `f7020f6` (Toggles) noch nicht — kein Widerspruch, aber referentiell veraltet.

---

## 13 — Maßnahmenliste P0/P1/P2/P3

### P0
*(keine)* — keine produktiven Crashes/Datenverluste im aktuellen Build belegbar. P0 wäre erst, wenn Hardware-46-MB-Pass nach Build 158 ausstünde und der `print()`-Spam Jetsam triggert; das ist Spekulation, nicht Repo-Truth.

### P1

**FIX-1 (umgesetzt in diesem Audit) — AppBuildInfo Memory Logging Live-Status**
- **ID:** FIX-1
- **Titel:** AppBuildInfo `isMemoryLoggingEnabled` von gespeichertem `let` auf computed property umstellen.
- **Beleg:** `AppBuildInfo.swift:16,30` (vor Fix); `AppOptionsView.swift:651–658` zeigte cached "Disabled", direkt darunter live "Resolved Enabled".
- **Risiko vor Fix:** TestFlight-Tester glaubt Toggle wirkt nicht / Build defekt → falsche Bug-Reports.
- **Empfehlung:** computed `var` mit `ImportMemoryProbe.isLoggingEnabled` (live).
- **Aufwand:** S.
- **Tests:** Bestehender `testAppBuildInfoExposesMemoryLoggingFlag` weiterhin grün; neu `testAppBuildInfoMemoryLoggingReflectsLiveSettingsToggle`.
- **Doku-Auswirkung:** Erwähnung in `CHANGELOG.md`, `XCODE_RUNBOOK.md`.
- **Privacy:** Keine.
- **Status:** **DONE** (in diesem Commit).

**P1-A — Import-Cancel-API**
- Ziel: Task-Cancel-Pfad bis `LocalTimelineImportWriter.cancel()`. UI: Cancel-Button im Loading-State.
- Aufwand M; Tests S; Doku S.

**P1-B — Import-Progress (entry-count + bytes)**
- Ziel: `ImportPhase.parsing(processedElements:totalEstimate:)` + UI-Binding.
- Aufwand M; Tests S.

**P1-C — `PRAGMA wal_checkpoint(TRUNCATE)` nach `finalize` und `deleteAll`**
- Aufwand S; Test: assert WAL-File schrumpft nach Aufruf.

**P1-D — Recovery-Test (mid-Import-Crash)**
- open → bulk-insert → close ohne commit → reopen → assert rows == 0.
- Aufwand S.

**P1-E — UX-Polish AppOptionsView Memory-Logging-Section**
- Drei Felder in zwei Layern reorganisieren ("Build Configuration" / "Tester Override" / "Active Status"). Nach FIX-1 nicht mehr blocking, aber Klarheit verbessert.
- Aufwand S; Tests S.

### P2

**P2-A — Heatmap-Grid-Collision-Test**
**P2-B — DayMap-Budget-Overspill-Test**
**P2-C — Test-Mode-Banner in AppOptionsView (sichtbar wenn flag aktiv)**
**P2-D — Delete-Confirmation-Alert vor `deleteAll`**
**P2-E — `deleteAllLocalTimelineData` Test mit echten RenderCache-Files**
**P2-F — LH2GPX-ZIP eintragsweise streamen (S4)**
**P2-G — Schema-Migration-Test v1→v2**
**P2-H — UI: Skipped-Entry-Count in Loading-Footer**

### P3

**P3-A — `os.Logger` statt `print()` für Probe (Privacy-Modernisierung)**
**P3-B — MetricKit / MXCrashDiagnostics**
**P3-C — Background-Task-Wrap für Imports**
**P3-D — Periodic VACUUM (konfigurierbar)**
**P3-E — App-Group/Widget-Strategie für Store-Reads**
**P3-F — Map-Snapshot in DayList**

---

## 14 — Konkrete nächste Prompts

1. **"Implementiere Import-Cancel-Path und Progress-Surface (P1-A + P1-B)"**
   Scope: `Task.isCancelled` in `GoogleTimelineStoreImporter` + `LocalTimelineImportWriter.cancel()` Forward, UI-Cancel-Button in `LH2GPXAppFlow`-Loading-State, neue `ImportPhase.parsing(processedElements:totalEstimate:)`-Variante, Tests für beide Pfade.

2. **"WAL-Checkpoint und Recovery-Test (P1-C + P1-D)"**
   Scope: `PRAGMA wal_checkpoint(TRUNCATE)` nach `finalize`/`deleteAll`, Test der WAL-Datei-Schrumpfung, Test des Mid-Import-Crash-Recovery.

3. **"UI-Polish AppOptions Memory-Section + Test-Mode-Banner (P1-E + P2-C + P2-D)"**
   Scope: Reorganisation der drei Memory-Felder in zwei klare Layer, Test-Mode-Banner sichtbar nur wenn `featureFlags.isLocalTimelineStoreEnabled`, Confirmation-Alert vor `deleteAll`. Snapshot-Test optional.

4. **"Heatmap-Grid-Collision + DayMap-Budget-Overspill Tests (P2-A + P2-B)"**
   Scope: Synthetische Fixtures, Provider-Tests, Regression-Pin gegen Doppelzählung und Cap-Overflow.

5. **"LH2GPX-ZIP eintragsweise streamen (S4 / P2-F)"**
   Scope: `loadZipContent` von Array-Materialisierung auf Lazy-Iterator umstellen; Memory-Tests mit künstlich großen ZIPs.

---

## 15 — Was bewusst NICHT behauptet wird

- Kein Hardware-46-MB-Pass auf Build 158.
- Kein TestFlight-Run-Ergebnis für Build 158.
- Kein App-Review-Pass.
- Keine vollständige Karten-/Heatmap-/Overview-/Export-UI im Store-Pfad.
- Keine FileProtection-Aktivierung auf iOS produktiv.
- Keine Aussage über iCloud-UserDefaults-Sync-Verhalten der Toggle-Keys (Bool-only ja, aber Sync nicht verifiziert).
- Kein RTree.
- Keine Background-Task-Resilienz beim Import.
- Keine MetricKit-Integration.
- Keine ASC-/Privacy-Manifest-Submission-Bewertung.
- Keine UITest-Verifizierung auf realem Gerät seit 2026-05-05 (Build 74).

---

**Audit-Ende.** Repo-Truth zuerst. Im Zweifel: nicht behaupten.
