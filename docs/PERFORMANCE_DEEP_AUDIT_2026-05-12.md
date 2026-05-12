# LH2GPX iOS-App — Performance Deep Audit

**Auditor:** Claude Code (Opus 4.7 / 1M).
**Datum:** 2026-05-12.
**Repo:** `dev-roeber/iOS-App` (Monorepo).
**Audit-HEAD vor Patches:** `f111afd` (`fix: restore heatmap control hardware smoke test`).
**Audit-HEAD nach Patches:** pending — siehe Sektion 11.

## 1. Executive Summary

- **Gesamtzustand:** Code-Basis ist stabil, `swift test` 1521/4/0 grün (+3 neue Perf-Tests in diesem Train), signed Device-Build auf iPhone 15 Pro Max grün, Hardware-UITest-Suite 8/8 grün auf `f111afd`. Privacy-Manifest + Background-Modes konsistent, kein 3rd-Party-Tracking.
- **Größte echte Restrisiken aus diesem Audit:**
  - **P1 Upload-Backoff fehlt** in `LiveLocationFeatureModel.swift` — bei Server-Outage feuert die App pro akzeptiertem Live-Punkt einen neuen POST (Battery + Bandbreite).
  - **P1 Hartcodiertes `kCLLocationAccuracyBest`** in `SystemLiveLocationClient.swift:30` — Battery-Last fix auf höchstem Profil unabhängig vom User-Preference.
  - **P1 Live-Activity-Update pro Sample** in `LiveLocationFeatureModel.syncLiveActivityState` — Battery + iOS-Throttling-Risiko.
  - **P2 Heatmap viewport cache** in `AppHeatmapModel.swift:55` ohne Cap — Memory wächst bei langem Pan/Zoom.
  - **P2 Memory-Warning Hook** in `AppShellRootView.swift:136–141` logt nur, droppt keine Caches.
  - **P2 LH2GPX-JSON > 64 MiB** hartes Reject ohne UI-Action (`AppContentLoader.swift:752–760`).
  - **P2 KMZ-Builder** doppelt-resident im Speicher (`KMZBuilder.swift:9–30`).
  - **P2 iOS Data Protection** für SQLite-Store ist auskommentiert (`LocalTimelineFileProtection.swift:60–78`) — relevant bei Default-ON des Feature-Flags `LH2GPX_LOCAL_TIMELINE_STORE`, aktuell OFF.
- **Manuelle Hardware-Restpunkte (unverändert offen):** 46-MB-Crashfall-Hardware-Retest (Datei `/Users/sebastian/Desktop/Google_Maps/12_05_2026_location-history.json` ~44.5 MiB lokal verfügbar; manueller Tester-Handoff erforderlich), Live-Activity-Lock-Screen-Sichtprüfung außerhalb der UITests, iPad-Layout (iPad offline), ASC/TestFlight (extern).
- **In diesem Train umgesetzt (Low-Risk):**
  1. SQLite-Performance-Pragmas (`busy_timeout`, `synchronous=NORMAL`, `temp_store=MEMORY`) in `LocalTimelineStore.init(url:)`.
  2. iCloud-/iTunes-Backup-Exclusion für `RecordedTrackFileStore`-Verzeichnis + JSON-Datei.
  3. Neuer Performance-Test-File `PathDistanceCalculatorPerformanceTests.swift` mit `XCTClockMetric` + `XCTMemoryMetric` (3 Tests) als Baseline.
- **Bewusst NICHT in diesem Train umgesetzt:** alle P1/P2 oben — sie verändern entweder Production-Verhalten (Live-Tracking-Battery, Live-Activity-Cadence) oder erfordern Refactors (KMZ-Stream, Upload-Backoff, Memory-Warning-Hook). Codex-Folgetrain-Prompts in Sektion 12.

## 2. Recherche / Best-Practice-Basis (Phase 0)

Die folgenden Aussagen sind durch Apple Developer Documentation, Swift.org und sqlite.org gestützt (offizielle Primärquellen). Konkrete Quellenangaben unten:

### SwiftUI Performance
- Body-Recomputation erfolgt bei jeder Änderung an Observable State — Apple WWDC 2023 "Demystify SwiftUI performance". → Relevant für `AppInsightsContentView` (1962 LOC, 5 onChange-Listener) und `AppContentSplitView` (1602 LOC, viele computed properties pro body).
- `GeometryReader` ist explizit als Performance-Hotspot dokumentiert (Apple HIG / WWDC). → 3 Vorkommen im Repo (`AppInsightsContentView:458`, `AppLiveTrackingView:58, 436`).
- `LazyVStack` + `LazyHStack` materialisieren Children erst beim Scrollen. → Bereits in Days-/Insights-Listen verwendet.
- `TimelineView(.periodic)` bzw. `.animation(minimumInterval:)` ist die Apple-empfohlene Alternative zu `Timer.scheduledTimer` in SwiftUI-Views. → Genutzt in `LH2GPXLoadingBackground:126`; nicht genutzt in `AppLiveTrackingView:1163` (1Hz `Timer`).

### Instruments / Profiling
- Time Profiler, Allocations, Leaks, Memory Graph (Xcode > Open Developer Tool > Instruments) und SwiftUI Template sind kanonische Apple-Tools. → Runbook-Empfehlung in `docs/XCODE_RUNBOOK.md` ergänzen.
- `os_signpost` + `XCTOSSignpostMetric` erlauben gezielte Region-Messung. → Heute nicht im Repo verwendet (Agent G: 0 Treffer).
- `xctrace record --template …` ist die CLI-Variante. → Manual Hardware Performance Runbook möglich.

### XCTest Performance
- `XCTClockMetric`, `XCTMemoryMetric`, `XCTCPUMetric`, `XCTOSSignpostMetric`, `XCTApplicationLaunchMetric` sind Apple-Standards (Apple Developer Doc: "Configuring Tests for Performance"). → Aktuell nur 1× `XCTMemoryMetric` im Repo, in diesem Train +1× `XCTClockMetric` und +1× zusätzlicher `XCTMemoryMetric`. `XCTApplicationLaunchMetric` fehlt vollständig.
- `relativeStandardDeviation`/Baseline-Files sind opt-in. Test-File `Tests/README.md:58–63` dokumentiert die "baseline-only, no fail-bar"-Policy bewusst.

### Large File Import / Memory (iOS)
- `Data(contentsOf:)` liest die komplette Datei in den App-Heap. Für Files > 50–100 MB ist `FileHandle` + Chunked-Read empfohlen (Apple Foundation Documentation).
- `JSONSerialization` baut bei großen Inputs einen vollen Tree auf — `autoreleasepool` ist auf Darwin notwendig, damit NSString/NSNumber zwischen den Element-Parsen freigegeben werden (bestätigt durch eigenen 2026-05-07 Jetsam-Fix).
- iOS Memory Warning Notification ist `UIApplication.didReceiveMemoryWarningNotification` — App soll Caches droppen.
- Jetsam tötet Apps mit hohem Resident Memory, besonders im Background und bei `processing`-BackgroundMode.

### SQLite / Local Store
- WAL-Modus + `synchronous = NORMAL` ist die sqlite.org-Empfehlung für App-Stores mit gelegentlichem Crash-Risiko (App-Loss recovery vollständig, Power-Loss-Outerschicht akzeptabel). Quelle: sqlite.org/pragma.html#pragma_synchronous.
- `busy_timeout` lässt SQLite warten statt sofort `SQLITE_BUSY` zu werfen — wichtig wenn mehrere SQLite-Handles offen sind.
- `temp_store = MEMORY` hält Sortier-/Temp-Tabellen im RAM statt auf Disk.
- `mmap_size` mapped die DB-Datei in den Adressraum; auf 64-bit iOS sehr empfohlen, aber Trade-off bei limitiertem Memory.
- `PRAGMA foreign_keys = ON` ist per-connection und muss nach Open gesetzt werden (Apple/sqlite.org).
- File-Protection auf iOS via `NSFileProtectionCompleteUntilFirstUserAuthentication` (Default) bzw. `completeUnlessOpen` für Background-Read-Access (Apple Developer Doc).

### Map / Heatmap / Route Rendering
- MKMapView's Overlay-Renderer ist GPU-beschleunigt für `MKPolyline`/`MKMultiPolyline`/`MKPolygon`; aber bei > einigen hundert Overlays steigt die Vertex-Shader-Last steil. → Empfohlen: Pre-decimate, LOD per Zoom-Level, viewport-culling.
- Heatmap-Aggregation gehört off-main-thread (Apple Concurrency Best Practice). → Bereits in `AppHeatmapModel.densityPrecomputationTask` mit `.utility`-Priority gelöst.

### Live Tracking / Background
- `CLLocationManager.allowsBackgroundLocationUpdates = true` benötigt `location`-Eintrag in `UIBackgroundModes` + präzisen Privacy-String. → Beides vorhanden.
- `pausesLocationUpdatesAutomatically` sollte `false` sein während aktivem Background-Tracking (Apple-Doc). → Bestätigt in `SystemLiveLocationClient.swift:33, 62–63`.
- `kCLLocationAccuracyBest` ist battery-intensiv; `kCLLocationAccuracyNearestTenMeters` ist iOS-Standard-Empfehlung für Fitness-Tracking. → Heute hartcodiert auf Best, sollte preference-gekoppelt sein.
- Live Activity Update-Budget: iOS throttlet Updates bei zu hoher Frequenz (Apple WWDC 2022 "Meet ActivityKit"). Empfehlung: max 1 Hz.

### App Launch / Cold Start
- Xcode Organizer / Instruments App Launch Template misst Pre-Main / Static Init / `applicationDidFinishLaunching`. → Heute kein `XCTApplicationLaunchMetric` im Repo.
- Empfehlung: alle nicht-essentielle Init in `.task` statt `applicationDidFinishLaunching` / `App.body`. → Bereits in `AppShellRootView.task` umgesetzt.

## 3. Git-/Repo-Preflight

| Feld | Wert |
|---|---|
| Branch | `main` |
| HEAD (Audit-Start) | `f111afd98502bfbdeee53168ca05e3199ae6b6dc` |
| Remote | `https://github.com/dev-roeber/iOS-App.git` |
| Dirty | clean (vor Patch) |
| macOS / Xcode / Swift | 15.7 / Xcode 26.3 (17C529) / Swift 6.2.4 |
| Tracked files | 519 · 349 Swift · 157 Tests · 79 .md |
| iPhone 15 Pro Max | UDID `00008130-00163D0A0461401C`, iOS 26.4, online |
| iPad (17.7.10) | offline |
| Größte Swift-Dateien | `AppInsightsContentView` 1962 · `AppExportView` 1841 · `AppContentSplitView` 1602 · `AppLiveTrackingView` 1217 · `LocalTimelineStore` 1079 · `AppOverviewTracksMapView` 1070 · `LiveLocationFeatureModel` 946 · `AppDayDetailView` 825 · `AppLanguageSupport` 817 · `AppContentLoader` 813 · `AppExportQueries` 807 |

## 4. Audit-Methodik

6 Subagenten parallel:
- **Agent A+C+D+E+F** (Code+Performance) — Import/Streaming/Memory, SwiftUI Responsiveness, Map/Heatmap, Live Tracking/Upload/Widget, Launch/AppShell.
- **Agent B** (SQLite/Store/Persistence) — Schema, WAL, PRAGMAs, FileProtection, Backup, Migration, Storage-Layout.
- **Agent G** (Test/Benchmark) — Test-Coverage, XCTMetric-Nutzung, Performance-Test-Lücken, xctestplan-Aufteilung.
- **Agent X** (Static-Search-Sweep) — `rg`-basierter Such-Sweep für 23 Pattern-Klassen (`Data(contentsOf:)`, `JSONSerialization`, `autoreleasepool`, `Task.detached`, `[weak self]`, `@MainActor`, `@Published`, `GeometryReader`, `onAppear`, `Timer`, etc.) mit Kategorisierung.
- **Agent Y** (Doku-Truth + App-Store-Compliance) — Konsistenz aller 79 .md gegen `f111afd`, Privacy-Manifest, Build-Identität, Manual-Risk-Sektionen.

Eigene Inline-Reads + Build-/Test-Runs.

**Grenzen:** Kein Hardware-Instruments-Trace gefahren (manueller Schritt). Keine kompletten UITests in diesem Lauf — keine UI-Code-Änderung. Kein 46-MB-Hardware-Import (manueller Schritt). Kein iPad. Kein ASC-Portal.

## 5. Datei-für-Datei Hotspot-Inventar (Top-Findings)

Vollständige Tabellen siehe Sub-Agenten-Outputs. Hier die Spitzen aus Agent A/B/D/E/F/X:

| ID | Bereich | Datei:Zeile | Befund | Kost | Prio | Optimierung | Train |
|---|---|---|---|---|---|---|---|
| H1 | Live Upload | `LiveLocationFeatureModel.swift:771-778` | Kein exponential Backoff bei `handleUploadFailure`; jeder neue Sample-POST | Battery + Bandbreite bei Outage | P1 | Backoff 1s → cap 5 min mit `consecutiveUploadFailures` | Folgetrain |
| H2 | Live Activity | `LiveLocationFeatureModel.swift:834-848`, `SystemLiveLocationClient.swift:31` | `syncLiveActivityState` pro Sample (10m / wenige s) | Battery, iOS-Throttling | P1 | Throttle 1 Hz oder 25 m | Folgetrain |
| H3 | CLLocation Accuracy | `SystemLiveLocationClient.swift:30` | Hartcodiert `kCLLocationAccuracyBest` | Battery | P1 | An `preferences.liveTrackingAccuracy` koppeln | Folgetrain |
| H4 | Heatmap | `AppHeatmapModel.swift:55, 196-202` | `viewportCache: [HeatmapViewportKey: [HeatCell]]` unbounded | Memory bei Pan/Zoom | P2 | LRU cap (z.B. 32) | Folgetrain |
| H5 | LH2GPX-JSON >64 MiB | `AppContentLoader.swift:91-97, 752-760` | Hard reject ohne UI-Hint | UX dead-end | P2 | UI-Banner / Doku | Folgetrain |
| H6 | Memory Warning | `AppShellRootView.swift:136-141` | Nur Log, kein Cache-Drop | Memory pressure | P2 | viewportCache + BoundedLRU droppen | Folgetrain |
| H7 | KMZ Builder | `KMZBuilder.swift:9, 30` | Doppelt-resident: KML-String + Data(contentsOf: tmpURL) | Memory peak Export | P2 | Stream-Producer, URL-Return | Folgetrain |
| H8 | Heatmap Tasks | `AppHeatmapModel.swift:73, 173, 223` | `Task.detached` ohne `[weak self]` | Lifecycle, kein Cancel-on-deinit | P2 | `[weak self]` + early guard | Folgetrain |
| H9 | OverviewMap Task | `AppOverviewTracksMapView.swift:52` | `Task.detached` ohne `[weak self]` (Zeile 96 hat es bereits) | Inkonsistenz | P2 | `[weak self]` ergänzen | Folgetrain |
| H10 | ActivityManager Task | `ActivityManager.swift:173` | `Task { ... self ... }` strong | Lifecycle | P3 | `[weak self]` | Folgetrain |
| H11 | LiveTrack 1Hz Timer | `AppLiveTrackingView.swift:1163, 1168` | `Timer.scheduledTimer(1/30)` triggert Body-Recompute | UI-Hitch bei langen Tracks | P3 | `TimelineView(.periodic)` | Folgetrain |
| H12 | Insights onChange-Cascade | `AppInsightsContentView.swift:238-243` | 5 voneinander unabhängige `.onChange`-Listener | Body-Storms | P3 | `.task(id:)`-Konsolidierung | Folgetrain |
| H13 | Heatmap LOD eager | `AppHeatmapModel.swift:223-237` | Alle LODs vorab in detached `.utility` | CPU/Memory burst nach Import | P3 | On-demand LOD | Folgetrain |
| H14 | RecordedTrackStore Load | `RecordedTrackStore.swift:41` | `Data(contentsOf:)` ohne Size-Gate | Wächst mit Sessions | P2 | Size-Cap + Streaming-Decoder | Folgetrain |
| H15 | AppExportDecoder.contentsOf | `AppExportDecoder.swift:10` | Public API ohne Gate, umgeht Loader-Cap | Bibliotheks-Misuse | P3 | Deprecation oder byte-limit Param | Folgetrain |
| H16 | AppOptionsView ConnTest | `AppOptionsView.swift:482, 485` | `URLSession.shared.data(for:)` ohne Custom-Timeout | UI-Hang bei langem Server | P3 | Custom `URLSessionConfiguration` 15 s | Folgetrain |
| H17 | SQLite PRAGMAs fehlen | `LocalTimelineStore.swift:40-41` (vorher) | kein `busy_timeout`, `synchronous`, `temp_store`, `mmap_size` | Write-Overhead, Concurrent-Open-Failure | P2 | PRAGMAs setzen | **JETZT umgesetzt** |
| H18 | RecordedTrackFileStore Backup | `RecordedTrackStore.swift:48-61` (vorher) | Kein `isExcludedFromBackup`-Flag | Live-Tracks landen in iCloud Backup | P2 | `markExcludedFromBackupIfPresent` | **JETZT umgesetzt** |
| H19 | Statement-Caching | `LocalTimelineStore.swift:97-149` | Pro Insert neu prepare+finalize | Import-Throughput | P3 | Statement-Pool | Folgetrain |
| H20 | Widget CFBundleVersion hartcodiert | `wrapper/LH2GPXWidget/Info.plist:21-22` | Hartcodiert `100` statt `$(CURRENT_PROJECT_VERSION)` | Drift bei Bump | P3 | Variable | Folgetrain |
| H21 | `@unchecked Sendable` Boxen | `LocalTimelineImportController.swift:24, 86`, `LocalTimelineImportCancellation.swift:12` | Concurrency-Lock-Korrektheit nicht im Audit-Scope verifiziert | Concurrency-Risiko | P3 | Audit + actor-Modell | Folgetrain |

## 6. Mess-Baseline (HEAD `f111afd`)

| Befehl | Dauer | Ergebnis | Bemerkung |
|---|---|---|---|
| `swift build` | 1.5 s (cached) / 12.0 s (clean nach Patch) | OK | macOS host build |
| `DEVELOPER_DIR=Xcode swift test` | 115.6 s | 1518 / 4 skipped / 0 failures | Mac SwiftPM suite, post-patch 113.5 s / 1521/4/0 |
| `xcodebuild -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` | 28.6 s | BUILD SUCCEEDED | post-CSQLite-Conditional-Fix |
| `xcodebuild -destination id=…401C build -allowProvisioningUpdates` | siehe Sec. 11 | BUILD SUCCEEDED | signed Debug iPhone 15 Pro Max |
| Hardware UITest Suite (8/8) | 43.4 s + 75.8 s + 597.4 s + 5×37-64 s | grün auf `f111afd` (im vorherigen Train) | nicht erneut gefahren — keine UI-Änderung in diesem Train |

**Performance-Fixture (lokal verfügbar, nicht im Repo):**
- `/Users/sebastian/Desktop/Google_Maps/12_05_2026_location-history.json`
- Größe: 46 657 867 Bytes (~44.5 MiB)
- SHA-256 maskiert: `15c457a66400...b1731893`
- **Nicht committed.** Inhalt nicht geloggt. Manueller Hardware-Tester-Handoff erforderlich für 46-MB-Crashfall-Retest.

**Auto-Bench Mac (in PRAGMA-Optimierungs-Pfad):** keine Vorher/Nachher-Messung in dieser Auditrunde — SQLite-Path ist Feature-Flag-default-OFF, daher kein User-sichtbarer Pfad triggert die PRAGMAs heute; Test-Suite zeigt unverändert grünen Output mit identischen Test-Counts (+3 für neue Perf-Tests). Mikrobenchmark-Beleg über `XCTMemoryMetric` in `PathDistanceCalculatorPerformanceTests` ist die Baseline für Folgetrain-Vergleiche.

## 7. Test-/Benchmark-Realität

- Test-Files: 154 Core + 3 Wrapper = **157**.
- Test-Funktionen: **1520** pre-patch / 1521 post-patch (Mac).
- Performance-Test-Files: 3 (`PerformanceTests.swift`, `GoogleTimelineStreamReaderPerformanceTests.swift`, `LocalTimelineMapPerformanceBudgetTests.swift`) + **NEU** `PathDistanceCalculatorPerformanceTests.swift`.
- XCTMetric-Nutzung: 1 vor diesem Train (`XCTMemoryMetric` in `PerformanceTests:58`) + **2 neu in diesem Train** (`XCTClockMetric` + zweites `XCTMemoryMetric` in PathDistance-Suite).
- `measure {}`-Blöcke: 8 vor + 3 nach diesem Train.
- `XCTOSSignpostMetric`, `XCTCPUMetric`, `XCTClockMetric` (außer neu), `XCTApplicationLaunchMetric`: weiterhin nicht verwendet.
- Test-Plans: `wrapper/CI.xctestplan` enthält nur `LH2GPXWrapperTests` (Wrapper-Unit), `wrapper/LH2GPXWrapper.xctestplan` zusätzlich UITests.
- Performance-Test-Policy: "baseline-only, no fail-bar" (siehe `Tests/README.md:58–63` und `GoogleTimelineStreamReaderPerformanceTests:8–13`).

**Coverage-Lücken (nicht in diesem Train geschlossen):** HeatmapGridAggregator (G1), StoreBackedExportWriter (G3), StoreBackedMapDataProvider (G4), StoreBackedHeatmapDataProvider (G5), LocalTimelineImportWriter (G6), BoundedLRU (G7), App Launch (G8), OSSignpost-Coverage (G9), Sanitizer/ExportBuilder (G10).

## 8. Security / Privacy / App Store

Vollständige Tabelle siehe Sub-Agent Y. Kein neuer Befund gegenüber dem Post-Pull-Audit:
- Privacy Manifest, Background Modes, ATS strict, ITSAppUsesNonExemptEncryption=false, App-Group, URL-Scheme, keine 3rd-Party-Tracking-SDKs — alles OK.
- Bearer-Token im Keychain mit `AfterFirstUnlock` (post-`30015c9`).
- HTTPS-Enforcement strict (https oder localhost/[::1]).
- **Offen:** iOS Data Protection für SQLite-Store (Feature-Flag default-OFF).
- **Verbessert in diesem Train:** Backup-Exclusion für `RecordedTrackFileStore`-Disk-Layout.

## 9. Offene Punkte (priorisiert)

### P0
- **P0-1 46-MB-Crashfall-Hardware-Retest:** bleibt **FAILED** — `12_05_2026_location-history.json` (~44.5 MiB) ist lokal verfügbar; Tester-Handoff erforderlich (manueller Import auf Release-Build).

### P1
- **P1-1 Upload Backoff** (H1).
- **P1-2 Live Activity Throttle** (H2).
- **P1-3 CLLocation Accuracy preference-coupling** (H3).
- **P1-4 iOS Data Protection für SQLite-Store** (auskommentiert; relevant bei Default-ON).

### P2
- **P2-1 Heatmap viewport cache LRU** (H4).
- **P2-2 LH2GPX-JSON >64 MiB UI-Hint** (H5).
- **P2-3 Memory-Warning Cache-Drop** (H6).
- **P2-4 KMZ-Builder Streaming** (H7).
- **P2-5 RecordedTrackStore Size-Gate** (H14).
- **P2-6 SQLite Statement-Caching** (H19).
- **P2-7 [weak self] auf Heatmap+OverviewMap Tasks** (H8, H9).
- **P2-8 Live-Activity Lock-Screen-Sichtprüfung** (manueller Punkt).
- **P2-9 iPad-Layout-Acceptance** (manueller Punkt).
- **P2-10 ASC/TestFlight Build-Liste** (extern).

### P3
- **P3-1 LiveTrack 1Hz Timer → TimelineView** (H11).
- **P3-2 Insights onChange-Cascade** (H12).
- **P3-3 Heatmap LOD on-demand** (H13).
- **P3-4 ActivityManager [weak self]** (H10).
- **P3-5 AppExportDecoder.decode(contentsOf:) Gate** (H15).
- **P3-6 AppOptionsView Timeout** (H16).
- **P3-7 Widget CFBundleVersion Variable** (H20).
- **P3-8 @unchecked Sendable Boxen Audit** (H21).
- **P3-9 Doku-Drift** (`wrapper/README.md`, `wrapper/CHANGELOG.md`, `wrapper/docs/TESTFLIGHT_RUNBOOK.md`, `docs/XCODE_APP_PREPARATION.md`, `docs/XCODE_CLOUD_RUNBOOK.md`, `docs/APP_FEATURE_INVENTORY.md`).
- **P3-10 Backup-Files konsolidieren** (32 `*__backup_*.md`).
- **P3-11 Leere Duplikatordner** (`Sources 2/`, `Tests 2/`, etc.).
- **P3-12 INFOPLIST_KEY_* Redundanz** im pbxproj.

## 10. In diesem Train umgesetzt

### Code-Patches (3 Files)

**`Sources/LocationHistoryConsumerAppSupport/LocalTimelineStore.swift`** (Zeile 41–53):
- Nach `PRAGMA journal_mode = WAL;` werden jetzt drei zusätzliche PRAGMAs gesetzt: `busy_timeout = 3000;`, `synchronous = NORMAL;`, `temp_store = MEMORY;`.
- Begründung im Kommentar: WAL-safe Pairing (sqlite.org), Concurrent-Open-Resilienz, Sortier-/Temp-Tabellen-RAM. `mmap_size` bewusst nicht gesetzt — Memory-Trade-off mit 4-GB-Geräten.
- Verhalten unter Feature-Flag default-OFF: keine User-Sichtbarkeit, aber Tests greifen über `LocalTimelineStoreTests` etc. → 0 Regression.

**`Sources/LocationHistoryConsumerAppSupport/RecordedTrackStore.swift`** (neuer Aufruf nach `data.write(to:)`):
- Markiert `RecordedTrackFileStore`-Verzeichnis + JSON-Datei via `LocalTimelineFileAttributes.markExcludedFromBackupIfPresent(urls:)` als excluded-from-iCloud-Backup.
- Defense-in-depth: Live-Track-Standortdaten landen nicht in generischem iCloud/iTunes-Backup. Failure `try?`-geschluckt (Backup-Flag ist defensiv, nicht korrektheitskritisch).
- Symmetrisch zum bereits aktiven Pattern in `LocalTimelineStoreFactory`.

### Test-Addition (1 File)

**`Tests/LocationHistoryConsumerTests/PathDistanceCalculatorPerformanceTests.swift`** (neu):
- 3 Tests: `testEffectiveDistanceClockOnLargePathPoints` (50 000-Punkt-`Path` via `points`), `testEffectiveDistanceClockOnLargeFlatCoordinatesPath` (gleiche Größe via `flatCoordinates`), `testEffectiveDistanceMemoryOnLargePathPoints`.
- `XCTClockMetric` + `XCTMemoryMetric`. Apple-only via `#if !os(Linux)` + `@available(macOS 13.0, iOS 16.0, *)`.
- Deterministische Synth-Fixtures (`(i % 5000) * 1e-5`).
- "Baseline-only, no fail-bar" konform zur Test-File-Policy.

## 11. Verifikation

| Befehl | Ergebnis | Wert |
|---|---|---|
| `git diff --check` | clean | — |
| `swift build` | OK | post-patch clean |
| `DEVELOPER_DIR=Xcode swift test` | **1521 / 4 skipped / 0 failures** | 113.5 s, +3 ggü. pre-patch 1518 |
| `xcodebuild -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` | BUILD SUCCEEDED | siehe Sec. 12 commit |
| `xcodebuild -destination id=…401C build -allowProvisioningUpdates` | BUILD SUCCEEDED | signed Debug iPhone 15 Pro Max |
| Hardware UITest Suite | **NICHT erneut gefahren** — keine UI-Code-Änderung in diesem Train (nur Store-PRAGMAs, RecordedTrackStore Backup-Flag, neue Perf-Test-Datei) | letzte Acceptance 8/8 grün auf `f111afd` aus dem vorigen Train |
| 46-MB-Hardware-Retest | **NICHT gefahren** — manueller Tester-Handoff | bleibt FAILED |

## 12. Nächste Optimierungs-Trains (copy/paste-ready Codex-Prompts)

### Train 1 — P1 Live Activity Update Throttle + CLLocation Accuracy preference-coupling
```
Pflichtblock LH2GPX:
- Repo-Preflight in /Users/sebastian/Desktop/XCODE/iOS-App.
- Repo-Truth, Test-Truth, Code-Truth.
- Kein App-Store-/Hardware-Punkt blind abhaken.
- Commit + Push nur wenn alle Pflicht-Verifikationen grün und Hardware-UITest-Suite weiterhin 8/8 ist.

Aufgabe: P1 Live Tracking battery-cost reduction.

1. CLLocation Accuracy preference-coupling:
   Sources/LocationHistoryConsumerAppSupport/SystemLiveLocationClient.swift:30
   `manager.desiredAccuracy = kCLLocationAccuracyBest` durch eine Mapping
   aus AppPreferences.liveTrackingAccuracy ersetzen (Preference existiert
   bereits, siehe AppContentSplitView.swift:219). Default-Wert
   kCLLocationAccuracyBest beibehalten, aber konfigurierbar machen.

2. Live Activity Throttle:
   Sources/LocationHistoryConsumerAppSupport/LiveLocationFeatureModel.swift:834-848
   syncLiveActivityState wird heute pro Sample aufgerufen. Throttle auf
   max 1 Hz (Apple WWDC 2022 ActivityKit-Empfehlung). Implementierung:
   eigene Timestamp-State-Variable `lastLiveActivityUpdate`, skip wenn
   delta < 1.0 s. Stop/Start/Error-Pfade bleiben unbedingt (kein Throttle
   bei Status-Wechsel).

3. Tests:
   - LiveActivityTests erweitern um Throttle-Verhalten.
   - LiveLocationFeatureModelStateTransitionTests erweitern um
     Accuracy-Preference-Round-Trip.

4. Hardware-Verifikation:
   - swift test 1521 → mindestens unverändert (+ neue Tests).
   - xcodebuild generic + signed Device iPhone 15 Pro Max.
   - Hardware-UITest-Suite 8/8 erneut fahren (alle Live-Activity-Tests
     müssen grün bleiben; achten auf testLiveActivityHardwareCapture* —
     diese pollen Live-Activity-State, eine Throttle-Verzögerung darf sie
     nicht falsch failen lassen).

5. Doku-Sync:
   - docs/PERFORMANCE_DEEP_AUDIT_2026-05-12.md P1-2 + P1-3 als erledigt
     mit Hardware-Beleg markieren.
   - CHANGELOG.md, wrapper/CHANGELOG.md neuer Eintrag.

Wichtig: KEINE Doku-Punkte aus Sektion 9 P0/P1-1/P1-4/P2/P3 mit anpacken.
Nur 2 Achsen in diesem Train.
```

### Train 2 — P1 Upload Backoff
```
Aufgabe: Exponential Backoff für LiveLocationServerUploader.

1. Code:
   Sources/LocationHistoryConsumerAppSupport/LiveLocationFeatureModel.swift:771-778
   handleUploadFailure: zähle consecutiveUploadFailures, berechne
   backoffSeconds = min(300, 2^consecutiveFailures), starte
   Task.sleep(nanoseconds:) bevor schedulePendingUploadIfNeeded
   re-triggert. Cap 5 min. Reset bei successful upload.

2. Tests:
   - LiveLocationServerUploaderTests erweitern.
   - Neuer Test "testBackoffDelayDoublesOnRepeatedFailure".
   - Test für Reset nach Success.

3. Verifikation + Doku-Sync wie Train 1.
```

### Train 3 — P2 Memory-Warning Hook
```
Aufgabe: AppShellRootView memory-warning-handler droppt Caches.

1. Public reset-Hooks für:
   - AppHeatmapModel.dropAllCaches() (viewportCache + lodGrids)
   - AppSessionContent.dropProjectionCaches() (5 BoundedLRUs)
2. Wire in AppShellRootView.swift:136-141.
3. Tests: synthetisch UIApplication.didReceiveMemoryWarningNotification
   posten und Cache-Counts prüfen.
```

### Train 4 — P3 Doku-Drift Mass-Refresh
```
Aufgabe: wrapper/README, wrapper/CHANGELOG, wrapper/docs/TESTFLIGHT_RUNBOOK,
docs/XCODE_APP_PREPARATION, docs/XCODE_CLOUD_RUNBOOK, docs/APP_FEATURE_INVENTORY
auf HEAD post-Performance-Audit aktualisieren. Build-45/Build-74-Snapshots
klar als historisch markieren. Keine offenen Manual-Risk-Punkte abhaken.
```

### Train 5 — Manuelle Hardware-Tests
```
Aufgabe für menschlichen Tester:
- 46-MB-Import auf Release-Build mit
  /Users/sebastian/Desktop/Google_Maps/12_05_2026_location-history.json
  (~44.5 MiB) auf iPhone 15 Pro Max. Ergebnis dokumentieren in
  docs/APPLE_VERIFICATION_CHECKLIST.md Sektion 1.
- Live Activity / Dynamic Island / Lock Screen visuelle Sichtprüfung
  außerhalb der UITests; Screenshot-Block in Sektion 2.
- iPad-Layout: iPad online schalten, App installieren, Tabs durchgehen.
- ASC/TestFlight: Build-Liste im Apple-Portal abgleichen.
```

---

**Audit-Ende.** Dieser Report ist der Wahrheits-Anker zwischen `f111afd` (Pre-Audit) und den vorgeschlagenen 5 Folge-Trains. Manual hardware open points stay open; no false claim about ASC, TestFlight, or App Review.
