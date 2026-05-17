# ROADMAP

## Aktiver Stand (2026-05-17, Branch `main`, HEAD pending — Train P)

- **Train P umgesetzt (4 produktive Commits + Doku-Sync):** `56a76ed` Build-179-Baseline · `eaa149f` `ImportValidationSummaryPresentation` (10 Tests; title/range/counts/warnings DE/EN, en_US_POSIX→de_DE/en_US Date-Reformat, Pluralisierung) · `936fae6` `ExportFormatGuidancePresentation` (6 Tests; title/primaryUse/tools/strengths mit `• `-Bullet) · `ecde6cc` `RouteQualitySummaryPresentation` (12 Tests; level labels, gerundete Spacing/Gap-Lines mit 3-Bucket-Rundung, Gap-Surfacing nur für sparse/containsGaps) · `e5cdafc` `AppAccessibilityID.ProductInfo` (15 Konstanten, 2 Tests). Übersprungen: Phasen 4/6/7 (Vorrats-Code/redundant). **Bewusst kein SwiftUI-View-Wiring** — Linux kann Layout-Korrektheit nicht final prüfen; Strings + Identifier sind gelocked, Layout-Integration folgt im nächsten Train. Linux `swift test` **1568 / 2 Skips / 0 Failures** (+30). Train-P-Commits sind **noch nicht** in Build 179.

## Aktiver Stand (2026-05-17, Branch `main`, HEAD pending — Train O)

- **Train O umgesetzt (4 produktive Commits + Doku-Sync):** `f349a06` Build-179-Baseline · `82b685b` `ImportValidationSummary` (Foundation, 10 Tests, Counts/Date-Range/3-Warnungen, Privacy-Vertrag) · `408c93b` `ExportFormatGuidance.copy(for:german:)` (5 Formate × DE/EN, 7 Tests, Format-Default unverändert) · `17b9b6a` `RouteQualitySummary.evaluate(points:)` (Haversine, 10 Tests, empty/sparse/containsGaps/good) · `9a23031` `AppAccessibilityID.Action`-Namespace (6 Konstanten, 2 Tests). Übersprungen: Phasen 4-8 (kein UX-Defekt; Polish-Surface erschöpft). Linux `swift test` **1538 / 2 Skips / 0 Failures** (+29). Train-O-Commits sind **noch nicht** in Build 179.
- **Externer Build 179** auf `ff789a4` (Train M tip) bleibt letzter extern belegter Stand.

## Aktiver Stand (2026-05-17, Branch `main`, HEAD pending — Train M)

- **Xcode Cloud Build 178 extern verifiziert (`docs: record build 178 screenshot smoke baseline`):** Workflow `Release – Archive & TestFlight` Build **178** grün (Archive iOS ✅ + TestFlight-interne Tests ✅), letzter Commit `487833f`. TestFlight zeigt `LH2GPX 1.0.2 (178)` mit Pre-production-Banner. Toolchain Xcode 26.5 (17F42) / macOS Tahoe 26.4 (25E246). Damit Train H/H-Wire-1/I/J/K/L (Cap, Throttle, GenerationGate, iOS-16-Cleanup, CSV-Helper, Heatmap-Lifecycle-Tests, Query-Plan-Hook) extern angekommen. Partieller TestFlight-Screenshot-Smoke: Overview/Live/Insights/Export-Tabs öffnen; Hardware-Sweep / Dynamic Island / iPad / großer Import / externe Export-Validierung bewusst unbestätigt. Kein Hardware-Smoke, keine App-Review-Aussage.
- **Train M umgesetzt (4 produktive Commits + Doku-Sync):** `a476fb0` Build-178-Doku · `efa68c4` Zentrale `AppAccessibilityID`-Struct (`Root`/`Tab`/`Map`, 10 Konstanten, 6 Tests) · `ebae73f` 5 Tab-Identifier in `AppContentSplitView` + Banner-Alias auf bestehenden `localTimeline.testMode.banner` · `5de7017` 4 Map-Root-Identifier (`map.{overview,heatmap,exportPreview,dayDetail}.root`). Übersprungen: Per-Element-Migration der 155 bestehenden Inline-Identifier (kein XCUITest-Konsument) + UI-Test-Smoke-Erweiterung (kein XCUITest-Target im SwiftPM-Tree). Linux `swift test` **1509 / 2 Skips / 0 Failures, 54,6 s**. Train-M-Commits sind **noch nicht** in Build 178.

## Aktiver Stand (2026-05-16, Branch `main`, HEAD `487833f` — Train L)

- **Train L umgesetzt (2 produktive Test-Commits + Doku-Sync):** `574d522` Build-176-Baseline-Doku · `c5e86ef` `HeatmapGenerationLifecycleTests` (8 Tests; A→B→A flip, stale-completion, updateScale-Invalidierung) · `a63f827` `internal LocalTimelineStore.queryPlan(for:)` (EXPLAIN-QUERY-PLAN-Hook) + `LocalTimelineDerivedCacheQueryPlanTests` (3 Tests; Lookup und Prune-ORDER-BY-LIMIT nutzen `idx_derived_cache_*`-Indizes — Train-I-Covering-Index in Praxis verifiziert). Linux `swift test` **1503 / 2 Skips / 0 Failures, 55,2 s** (+11). Train-L-Commits sind **noch nicht** in Build 176. Übersprungen: Phasen 2 (kein Race-Risiko), 4-7 (kein UX-Defekt, AccessibilityIdentifier-Breitenausbau invasiv), 8 (Hotspots in Train H/I/J/K abgedeckt).

## Aktiver Stand (2026-05-16, Branch `main`, HEAD `a01ec7e` — Train K)

- **Train K umgesetzt (4 produktive Commits + Doku-Sync):** `84064c9` Build-176-Baseline-Doku · `924370a` `AppOverviewMapModel` loadGeneration → shared `GenerationGate` (Hash-Token bleibt zusätzlich) · `555123d` 11× `if #available(iOS 16.x, *)`-Runtime-Branches dedenten (ActivityManager 4×, LiveActivityPresentation 1×, AppInsightsContentView 2×, LiveLocationFeatureModel 4×) · `f959f2e` CSV-Row `joinEscapedRow`-Helper (byte-identisch). Übersprungen: Phasen 3 (Test-Injection), 4/5/9 (kein UX-Defekt), 7 (Store-EXPLAIN), 8 (verbleibende offset-id ohne Domain-IDs). Linux `swift test` **1492 / 2 Skips / 0 Failures, 53,7 s**. Noch nicht in Build 176.

## Aktiver Stand (2026-05-16, Branch `main`, HEAD `b5c6dc0` — Train J)

- **Train J umgesetzt (4 produktive Commits + Doku-Sync):** `980111d` Build-176-Baseline-Doku · `731c290` GeoJSON `features.reserveCapacity` (byte-identisch) · `d0b2f1b` neuer `GenerationGate` (Sendable, 8 Tests) + `AppHeatmapModel` Gate-Wiring gegen stale `MainActor.run`-Completions (Bump auf start/updateScale/ensure; `isStillCurrent(token)` in beiden MainActor.run-Blöcken) · `7dfcce7` `LHExportStepIndicator` `id: \.element` (Step Hashable). Übersprungen: Phasen 2 (Import-Progress modelliert, Export-Builder synchron), 3 (Repo bereits konsequent `Task.detached`), 6 (Live-Pipeline modular), 7 (kein UX-Defekt), 8 (13 Indizes, kein EXPLAIN-Beleg). Linux `swift test` **1492 / 2 Skips / 0 Failures, 54,9 s** (+8 GenerationGateTests). Train-J-Commits sind **noch nicht** in Build 176.
- **Train I umgesetzt (4 Commits):** `d0c0a4c` Build-176-Doku · `41a8e6c` Live Camera Throttle (ON, 0,5 s + 25 m, 9 Tests) · `058a131` GPX/KML reserveCapacity + KML direkter Coord-Loop (byte-identisches Output) · `b0d49a3` Index `idx_derived_cache_kind_version_created` (additiv). Übersprungen: Phasen 2/3/6/7 mit Begründung. Linux `swift test` **1484 / 2 Skips / 0 Failures**. Noch nicht in Build 176.
- **Xcode Cloud Build 176 extern verifiziert (`docs: record xcode cloud build 176 verification`):** Workflow `Release – Archive & TestFlight` Build **176** grün (Archive ✅ + TestFlight-interne Tests ✅), letzter Commit `556180c`. TestFlight zeigt `LH2GPX 1.0.2 (176)`. Damit Train H + H-Wire-1 (iOS-16-Gates, CSV reserveCapacity, WAL-Pragmas, `LiveTrackRenderCap` + Wiring) extern angekommen. Repo-Truth lokal weiter `1.0.2 / 171`. Kein Hardware-Smoke, keine App-Review-Aussage.
- **Train H-Wire-1 umgesetzt (`perf: wire live track render cap into map presentation`):** `LiveTrackRenderCap` in `AppLiveTrackingView` verdrahtet. Default-Cap **10 000 Punkte (ON)**, intern. Wirkt nur auf View-State (`polylineCoordinates`, `trackSamples`) — Rohdaten, Persistence, Export unverändert. Erste/letzte Koord. erhalten. DE/EN-Hinweis bei tatsächlicher Cap-Wirkung. Linux `swift test` **1475 / 2 Skips / 0 Failures** (+6 neue `LiveRenderCapWiringTests`).
- **Train H — App Performance / Stability / UX Hardening (4 Commits):** `a741b76` 12× iOS-16-`@available`-Attribute entfernt; `254875a` CSVBuilder `reserveCapacity`; `86b3da6` LocalTimelineStore WAL-Pragmas (`journal_size_limit` 16 MiB, `wal_autocheckpoint` 1000); `7288a5f` neuer Helper `LiveTrackRenderCap` (Foundation-only, 10 Tests, noch nicht im View verdrahtet). Übersprungen: Identity B2 (keine stabilen IDs), Heatmap-Debounce (View hat bereits `.onEnd`), UX-Polish (an Live-Cap-Wiring gekoppelt). Linux `swift test` **1469 / 2 Skips / 0 Failures**. Train-H-Commits sind **noch nicht** in Build 175 — neuer Xcode-Cloud-Build erforderlich.
- **Xcode Cloud Build 175 extern verifiziert (`docs: record xcode cloud build 175 verification`):** Workflow `Release – Archive & TestFlight` Build **175** grün (Archive ✅ + TestFlight-interne Tests ✅), letzter Commit `2bfc009`. Damit `ff963c1` (onChange-Fix) und `2bfc009` (G1 MapKit) extern auf TestFlight (`LH2GPX 1.0.2 (175)`). Toolchain Xcode 26.5 (17F42) / macOS Tahoe 26.4 (25E246). iOS-17-Minimum extern bestätigt. Repo-Truth lokal weiter `1.0.2 / 171` (Cloud-`CI_BUILD_NUMBER`). Kein Hardware-Smoke, keine App-Review-Aussage.
- **Train G1 — Befund: kein Migrationsbedarf (`docs: g1 mapkit ios 17 migration is already complete`):** `rg "coordinateRegion:|annotationItems:|MapMarker|MapAnnotation\("` repo-weit **0 Treffer**. Alle 8 SwiftUI-`Map(...)`-Surfaces (DayMap, LiveTracking 2×, RecordedTrackEditor 2×, LiveLocationSection, Heatmap, OverviewTracksMapView 2×, ExportPreview) nutzen bereits `Map(position: $mapPosition) { MapContent }` mit `MapCameraPosition` + `Marker`/`Annotation`/`MapPolyline`. Audit-Docs korrigiert. Keine Code-Änderung. Linux `swift test` unverändert 1459/2/0. **Nächste sinnvolle Trains:** C (Live Surface Hardening, Feature-Flag default OFF), Cleanup der 18× iOS-16-Gates, G2 (MKMapView-Bridge Mac/Instruments).
- **iOS-17-Deprecation-Fix + Build-174-Doku-Sync umgesetzt (`fix: update ios 17 onchange usage and document build 174`):** `wrapper/LH2GPXWrapper/ContentView.swift:125` (Xcode-Cloud-gemeldete Stelle) auf Zwei-Parameter-`onChange` migriert; repo-weit 23 weitere single-arg `.onChange(of:) { _ in / X in … }` ebenfalls migriert (Insights 10×, Export 3×, ContentSplit 10×). Semantik unverändert. Extern: Xcode Cloud Build **174** grün, TestFlight zeigt `1.0.2 (174)` 90 Tage, iOS 17.0 Minimum extern bestätigt. Repo-Truth lokal weiterhin `1.0.2 / 171` (Build-Nummer kommt aus `CI_BUILD_NUMBER`). Linux `swift test` 1459/2/0.
- **Train F umgesetzt (`chore: raise minimum ios target to 17`):** `Package.swift .iOS(.v17)`, alle 6 `IPHONEOS_DEPLOYMENT_TARGET` im Wrapper-pbxproj auf `17.0`. `MARKETING_VERSION / CURRENT_PROJECT_VERSION` (`1.0.2 / 171`) unverändert. `@available(iOS 16.x, *)`-Gates (18) und `@available(iOS 17, macOS 14, *)`-Gates (28) bewusst nicht abgebaut — letztere bleiben für macOS-Pfade nötig, erstere räumt Folge-Train auf. Linux `swift test` 1459/2/0. Mac/Xcode-Cloud-Smoke + ASC-Validierung extern Pflicht vor Release.
- **Train E1 umgesetzt (`perf: reduce kmz export memory copies`):** `KMZBuilder` nutzt In-Memory-`Archive(accessMode: .create)` + `archive.data` (ZIPFoundation). Entfernt: Temp-Datei-Write + `Data(contentsOf:)` Re-Read. Public API + Output-Bytes unverändert. Linux `swift test` 1459/2/0.
- **Repo-Truth:** `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171` (8 pbxproj-Configs + Info.plist App/Widget konsistent). Frühere Stände `1.0.1 / 100 / 168` in den darunterliegenden Blocks sind historisch.
- **Linux-Verifikation (Swift 6.3.2 via swiftly, `libsqlite3-dev`):** `swift build` clean, `swift test` **1435 / 2 Skips / 0 Failures**, 41,1 s.
- **Repo-Hygiene:** 32 `*__backup_*.md` aus dem aktiven Tree nach `docs/archive/backups-2026-05-16/` verschoben (Doku-Audit-Cleanup).
- **Neu — MapKit & Performance Audit 2026-05-16:** `docs/MAPKIT_PERFORMANCE_AUDIT_2026-05-16.md` mit 6 Map-Surfaces, 17 priorisierten Hotspots und Mess-Baseline-Befund. Vorgeschlagene Trains A–D (siehe `NEXT_STEPS.md`).
- **Neu — Train A „Baseline Strengthening" umgesetzt 2026-05-16:** 3 neue Foundation-only Performance-Test-Files (PathSimplification, PathFilter, ExportBuilders) + GoogleTimelineStreamReader-10k-Erweiterung. Linux `swift test` 1459/2/0 (52,8 s). **Reine Test-Ergänzung, kein Verhaltenswechsel.**
- **Neu — App Performance Modernization Audit 2026-05-16:** `docs/APP_PERFORMANCE_MODERNIZATION_AUDIT_2026-05-16.md` — repo-weite Performance-/Stabilitäts-/Speicher-Analyse + formale iOS-17-Entscheidungsmatrix. **Empfehlung: Option 3 — iOS 17 vorbereiten, nicht in diesem Train anheben.** Inventar 28× iOS-17- + 9× iOS-16.2-Gates, 8 pbxproj-Configs. Top-20-Hotspots, Linux-testbar vs. Mac-only getrennt, Trains E1/E2/E3/C/B2/F/D vorgeschlagen.
- **Neu — Train B1 „Identity Polish — Insights" umgesetzt 2026-05-16:** In `AppInsightsContentView` drei `ForEach(Array(...enumerated()), id: \.offset)`-Stellen (activity / visit / period breakdown) auf stabile Domain-IDs (`\.activityType` / `\.semanticType` / `\.label`) umgestellt. Index war ungenutzt. **Keine** `.onChange`-Konsolidierung, **keine** Live-/Camera-/Map-Änderungen. Linux `swift test` 1459/2/0 (54,3 s) unverändert. Visueller SwiftUI-Identity-Effekt auf Linux nicht prüfbar.
- **Offen / extern nicht prüfbar (unverändert):** ASC-Live-Status für 1.0.2, TestFlight-Upload `1.0.2 (171)`, 46-MiB-Hardware-Retest mit Original-Asset, Dynamic-Island Lock-Screen, iPad-Layout-Sichtprüfung.

---

## Aktiver Stand (2026-05-13, HEAD pending — `perf: optimize heatmap pipeline with golden benchmarks`, Branch `chore/mapkit-az-modernization-3`)

- **MapKit A–Z Train 3** (kein Release, kein Merge): Heatmap-Pipeline mit 11 Golden-Output-Tests gelockt (Cell-Counts, byte-identische `normalizedIntensity` für stabile Insertion-Order, multi-LOD-Äquivalenz ≤ 1e-14). `HeatmapGridBuilder.computeGrid` an `binRaw` + `smoothAndNormalize` delegiert (byte-identisch zum Pre-Refactor). Neue API `computeMultiLODGrids(for:lods:scale:)` — fused single pass über points; **bewusst nicht produktiv verdrahtet**, da Benchmarks keinen Wallclock-Gewinn bei 10k/50k zeigen (Smoothing dominiert). Sim+Device BUILD SUCCEEDED.
- **Map-Train 4 Backlog**: `TaskGroup`-Parallelism über LODs, Metal compute shader für Smoothing, MKMapView+MKMultiPolyline Heavy-Overview Spike, MKTileOverlay-Heatmap, WWDC24 Place ID. Vor jedem Schritt: Memory-/Wallclock-Spike messen, dann erst implementieren.

---

## Aktiver Stand (2026-05-13, HEAD pending — `perf: harden map surfaces and heatmap large-data paths`, Branch `chore/mapkit-az-modernization-2`)

- **MapKit A–Z Train 2** (kein Release, kein Merge): Sanitize-Ausweitung auf **Overview / Heatmap / ExportPreview** über neuen Foundation-only `CoordinateValidity.isValid`. `MapCoordinateGuard.isValid` delegiert dorthin (identische Semantik). Timestamps/Bounds bleiben aligned, Score-/Cap-Logik unverändert. 11 neue Tests grün (5 Validator + 3 Pipeline + 3 XCTMeasure-Benchmarks). Throughput ~4–5 M coords/s Foundation-Filter. Sim+Device BUILD SUCCEEDED.
- **Map-Train 3 Backlog**: Heatmap Single-Pass-Multi-LOD-Sweep mit Golden-Output-Tests, MKMapView+MKMultiPolyline Heavy-Overview Spike (Performance-Vergleich), MKTileOverlay-Heatmap, WWDC24 Place ID / `mapItemDetailSheet` (iOS-18+-Check), optional iOS-Device-Benchmark für `CoordinateValidity`.

---

## Aktiver Stand (2026-05-13, HEAD pending — `perf: modernize map stack and large-data rendering`, Branch `chore/mapkit-az-modernization-1`)

- **MapKit A–Z Train 1** (kein Release, kein Merge): `AppDayMapView` mit Sanitize-Filter (NaN/Inf/Sentinel), Speed-Segment-Cache (Body-Compute → Init-Compute), stabile `Identifiable`-IDs für PathOverlay/VisitAnnotation. 6 neue Tests grün. Sim+Device-Build SUCCEEDED.
- **Map-Train 2 Backlog** (deferred, getrennte Commits Pflicht): Overview-scanCandidates Streaming-Refactor (HIGH-RISK), MKMapView+MKMultiPolyline-Bridging Heavy Overview/Heatmap (separater Perf-Vergleich), MKTileOverlay-Heatmap, AppHeatmapModel Single-Pass Tile-Sweep, Sanitize-Ausweitung auf Overview/Export/Heatmap-Surfaces, WWDC24 Place ID / `mapItemDetailSheet`.
- **Doku**: `docs/MAPKIT_AZ_AUDIT_2026-05-13.md` neu; `docs/MAP_ARCHITECTURE_AUDIT.md` bleibt kanonisch.

---

## Aktiver Stand (2026-05-13, HEAD pending — `chore: prepare release candidate build`)

- **Build-Identitäts-Bump**: `CURRENT_PROJECT_VERSION` 100 → **168** in allen 8 Configs + `CFBundleVersion` in beiden Info.plists. `MARKETING_VERSION` bleibt `1.0.1`. Begründung: ASC/Tester nennt Cloud-Build 167; nächste Submit muss monoton größer sein.
- **Verifikation**: `swift test` 1524/2/0 (250 s); `xcodebuild build` Sim iPhone 17 Pro Max iOS 26.3.1 + Device iPhone 15 Pro Max iOS 26.4 **BUILD SUCCEEDED**; `xcodebuild archive -configuration Release -destination 'generic/platform=iOS'` **ARCHIVE SUCCEEDED** → `/tmp/lh2gpx-release/LH2GPXWrapper-build168.xcarchive` (91 MB inkl. dSYMs, signed Apple Development).
- **Device-UITests nicht erneut**: nur Build-Nummern-Metadaten geändert, kein Runtime-Verhalten. Letzte grüne Verifikation auf `0739d4c` (siehe vorigen Stand-Block).
- **Manuelle Submission**: Lokales Archive ist Smoke-Build; Distribution-Submission läuft per Repo-Konvention über **Xcode Cloud → Organizer → Distribute App → ASC Upload** (siehe `docs/ASC_SUBMIT_RUNBOOK.md`).
- **ASC-Submit-Empfehlung (technisch): JA.**

---

## Aktiver Stand (2026-05-13, HEAD pending — `fix: close map performance gate and verify large import`)

- **P0-EX-2 (Map-Performance) GESCHLOSSEN**: `OverviewMapPreparation.scanCandidates` und `makeCandidate(from overlay:)` cappen `approximateDistance` jetzt über `strideDecimate(coords, maxPoints: 1024)` wenn `distanceM == nil` und `coords.count > 1024`. Tradeoff: Chord-Underestimate für Distanz; Score-Reihenfolge durch `pointWeight = log(coordinates.count)` stabil. 3 neue Unit-Tests in `AppOverviewTracksMapViewTests`.
- **P0-EX-3 (46-MiB-Hardware-Retest) GESCHLOSSEN** für die Streaming-/Parser-/Loader-Pipeline auf iPhone 15 Pro Max iOS 26.4 — autonom über neuen UI-Testing-only Launch-Arg `LH2GPX_UI_LARGE_IMPORT_BYTES` und Test `testLargeImportSyntheticFile` (passed in 126,27 s, kein Crash/Hang/Jetsam).
- **P0-EX-1 (`projectedDays` Sort-vor-Limit)** bleibt **P1** (Dead-Code-Pfad).
- **Verifikation:** `swift test` 1524/2/0; Simulator iPhone 17 Pro Max iOS 26.3.1 BUILD SUCCEEDED; Device iPhone 15 Pro Max iOS 26.4 BUILD SUCCEEDED + TEST SUCCEEDED (9 UI-Tests + 4× LaunchTest, 1299,77 s).
- **ASC-Submit-Empfehlung (technisch):** **JA**.

---

## Aktiver Stand (2026-05-12, HEAD pending — `perf: add measured performance baseline and low-risk optimizations`)

- Zentrales Repo: `iOS-App`. Performance-Deep-Audit auf HEAD `f111afd` durchgeführt; Report unter `docs/PERFORMANCE_DEEP_AUDIT_2026-05-12.md`.
- **Umgesetzt (Low-Risk)**: SQLite-PRAGMAs (`busy_timeout`, `synchronous=NORMAL`, `temp_store=MEMORY`) in `LocalTimelineStore.init(url:)` (Feature-Flag-default-OFF-Pfad); Backup-Exclusion für `RecordedTrackFileStore`; neuer `PathDistanceCalculatorPerformanceTests.swift` (3 Tests, `XCTClockMetric`+`XCTMemoryMetric`).
- **Verifikation**: `swift build` OK, `swift test` **1521/4/0** (+3 ggü. 1518), `xcodebuild generic iOS` BUILD SUCCEEDED, signed Device-Build iPhone 15 Pro Max BUILD SUCCEEDED. Hardware-UITest-Suite nicht erneut gefahren (keine UI-Änderung); letzte 8/8-Acceptance auf `f111afd` bleibt der Anker.
- **Folge-Trains priorisiert** (siehe Audit-Sektion 12): Train 1 P1 Live-Activity-Throttle + CLLocation-Accuracy; Train 2 P1 Upload-Backoff; Train 3 P2 Memory-Warning-Cache-Drop; Train 4 P3 Doku-Drift-Mass-Refresh; Train 5 manuelle Hardware-Tests (46-MB, Live-Activity-Sichtprüfung, iPad, ASC).
- **Manual-Risk-Sektionen unverändert offen**: 46-MB-Crashfall (FAILED, Datei lokal vorhanden, Tester-Handoff), Live-Activity-Lock-Screen-Sichtprüfung, iPad-Layout, ASC/TestFlight/Apple Review.
- Davor HEAD `f111afd` (P0-3 Heatmap-Smoke-Test behoben); davor `9e4a41b` (Hardware-Acceptance-Train mit P0-3-Regression).

## Aktiver Stand (2026-05-12, HEAD pending — `fix: restore heatmap control hardware smoke test`)

- Zentrales Repo: `iOS-App` (`dev-roeber/iOS-App`). Lokaler Pfad: `/Users/sebastian/Desktop/XCODE/iOS-App`. Xcode-Wrapper: `wrapper/LH2GPXWrapper.xcodeproj`.
- **P0-3 geschlossen:** Heatmap-Button im Overview-Tab bekommt HIG-konformes 44pt-Hit-Target, stabilen accessibilityIdentifier; UITest nutzt Identifier + neuen `scrollUntilHittable`-Helper. Hardware-UITest-Suite **8/8 grün** auf iPhone 15 Pro Max (iOS 26.4). Code: `AppContentSplitView.swift:857–863`; Test: `LH2GPXWrapperUITests.swift` (heatmapButton lookup, scrollUntilHittable helper).
- **Baseline grün:** `swift build`, `swift test` 1518/4/0 (116.5 s), `xcodebuild generic iOS` BUILD SUCCEEDED, signed Device-Build BUILD SUCCEEDED.
- **Manual-Risk-Sektionen-Stand (unverändert offen):** Sektion 1 (46-MB-Crashfall) bleibt **FAILED** — Datei `/Users/sebastian/Desktop/Google_Maps/12_05_2026_location-history.json` (~44.5 MiB) verfügbar, Import braucht manuelle UI-Interaktion und ist nicht autonom triggerbar; Sektion 2 (Live Activity / Dynamic Island / Lock Screen) bleibt mit menschlicher Sichtprüfung offen; Sektion 3 (iPad) bleibt offen (iPad offline); Sektion 4 (ASC / TestFlight / Apple Review) bleibt offen (extern).
- Davor HEAD `9e4a41b` (Hardware-Acceptance-Train mit Heatmap-Regression als P0-3); davor HEAD `5f83838` (`fix: conditionally link CSQLite shim for Linux`); davor HEAD `4d6ac87` (Post-Pull Deep-Audit-Truth-Sync); davor HEAD `30015c9` (P1 Keychain `kSecAttrAccessibleAfterFirstUnlock`); davor HEAD `799adc5` (Remote-Stand vor Pull).

## Aktiver Stand (2026-05-12, HEAD pending — `docs: record iPhone hardware acceptance status`)

- Hardware-Acceptance-Train auf iPhone 15 Pro Max (iOS 26.4) auf HEAD `5f83838` durchgeführt. **Resultat:** 7/8 UITests grün — `testAppStoreScreenshots`, `testLandscapeLayoutSmoke`, `testLiveActivityHardwareCaptureDistance/Duration/Points/UploadStatusPendingAndRestart/UploadStatusFailed`. **1 Regression:** `testDeviceSmokeNavigationAndActions` FAILED auf `wrapper/LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift:203` (Heatmap-Button im Overview nicht hittable). War am 2026-05-07 (HEAD `b91a933`) grün — Regression in einem der Phase-10-Commits dazwischen. **In diesem Train nicht gefixt.**
- **Baseline grün:** `swift build` OK, `swift test` 1518/4/0 (118.7 s), `xcodebuild generic iOS` BUILD SUCCEEDED, signed Device-Build BUILD SUCCEEDED.
- **Manual-Risk-Sektionen-Stand (Details in `docs/APPLE_VERIFICATION_CHECKLIST.md`):** Sektion 1 (46 MB) **bleibt FAILED** — keine 46-MB-`location-history.zip` im lokalen Filesystem; Sektion 2 (Live Activity / Dynamic Island / Lock Screen) — UITest-Capture-Suite 5/5 grün, manuelle visuelle Lock-Screen-Sichtprüfung außerhalb der UITests **offen**, Sektion-2-Checkboxen nicht abgehakt; Sektion 3 (iPad-Layout) **bleibt offen** (iPad offline); Sektion 4 (ASC/TestFlight/Apple Review) **bleibt offen** (extern).
- Davor HEAD `5f83838` (`fix: conditionally link CSQLite shim for Linux`); davor HEAD `4d6ac87` (Post-Pull Deep-Audit-Truth-Sync, 2026-05-12); davor HEAD `30015c9` (P1 Keychain `kSecAttrAccessibleAfterFirstUnlock`); davor HEAD `799adc5` (Remote-Stand vor Pull).

## Aktiver Stand (2026-05-12, HEAD pending — `fix: conditionally link CSQLite shim for Linux`)

- Zentrales Repo: `iOS-App` (`dev-roeber/iOS-App`). Lokaler Pfad: `/Users/sebastian/Desktop/XCODE/iOS-App`. Xcode-Wrapper: `wrapper/LH2GPXWrapper.xcodeproj`.
- **P0-1 aus `docs/DEEP_AUDIT_2026-05-12_POST_PULL.md` geschlossen:** `Package.swift` macht den `CSQLite`-Linux-Shim jetzt conditional über `.target(name: "CSQLite", condition: .when(platforms: [.linux]))`. Apple-Plattformen nutzen weiterhin SDK-`SQLite3` über `#if canImport(SQLite3)`-Gate in `LocalTimelineStore.swift`. Damit ist der `_sqlite3_*`-Linker-Bruch im `LH2GPXWidget`-iOS-Link weg.
- **Verifikation:** `swift build` OK (79.2 s), `swift test` 1518/4/0 (111.0 s), `xcodebuild ... 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**, `xcodebuild ... 'id=00008130-…401C' build -allowProvisioningUpdates` **BUILD SUCCEEDED** (signed Device-Build iPhone 15 Pro Max). `git diff --check` clean.
- **Weiterhin offen (unverändert, in diesem Train nicht angefasst):** 46-MB-Crashfall-Hardware-Retest (Manual Risk Acceptance Protocol Sektion 1, bleibt **FAILED** bis Tester-Bestätigung Release-Build), Live Activity / Dynamic Island / Lock Screen (Sektion 2), iPad-Layout (Sektion 3), ASC / TestFlight / Apple Review (Sektion 4), iOS-Data-Protection-Aktivierung im `LocalTimelineStore` (P1 aus Audit, relevant erst bei Feature-Flag-Default-ON, aktuell OFF), Hardware-UITest-Suite auf iPhone 15 Pro Max in diesem Train **nicht** gefahren.
- Davor HEAD `4d6ac87` (Post-Pull Deep-Audit-Truth-Sync, 2026-05-12); davor HEAD `30015c9` (P1 Keychain `kSecAttrAccessibleAfterFirstUnlock`); davor HEAD `799adc5` (Remote-Stand vor Pull).

## Aktiver Stand (2026-05-09, L-04 `fix: bound app session projection caches`)
- **[2026-05-09] L-04 — Bounded LRU für AppSessionContent-Caches**: Setzt Deep-Audit-Folgepunkt **L-04** um. **NEU** `BoundedLRU.swift` (Foundation-only generischer LRU). **Geändert** `AppSessionContent` in `AppSessionState.swift`: alle 5 bisher unbounded Caches (`filteredOverviewCache`/`filteredDaySummariesCache`/`filteredInsightsCache` je Cap 8, `dayDetailCache` Cap 32, `dayMapDataCache` Cap 16) sind durch `BoundedLRU` capped; `projectedDaysCache` (Cap 8) nutzt dieselbe Abstraktion. **Semantik unverändert** — Eviction triggert nur deterministische Recomputation. 18 neue Linux-Tests. **L-02/L-03 bleiben offen.** Store-Pfad bleibt **default OFF**. **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim).
- **[2026-05-09] L-01 — In-Memory-Import-Gate für Legacy-Loader**: Setzt Deep-Audit-Folgepunkt **L-01** um. `AppContentLoader.decodeFile(at:)` lehnt Full-Reads via `Data(contentsOf:)` jetzt kontrolliert ab, sobald die Datei größer als `AppContentLoader.maximumInMemoryImportBytes` (64 MiB) ist. Google-Timeline-JSON läuft weiter durch den Streaming-Konverter. Neuer Error-Case `AppContentLoaderError.importTooLargeForInMemoryLoad(filename:bytes:limit:)`; user-facing Title "File too large to load safely"; Beschreibung enthält Dateiname, Größe in MB, Limit in MB — keine Pfade, keine Standortdaten. 5 neue Linux-Tests in `AppContentLoaderTests` (sparse-file basiert). Legacy-ZIP-Pfad unverändert; Streaming-Pfad unverändert; Auto-Restore-Guard unverändert. **L-02/L-03 bleiben offen.** Store-Pfad bleibt **default OFF**. **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim).
- **[2026-05-09] Deep Audit Performance/Stabilität/Map-Layer (audit-only)**: Audit-Bericht `docs/DEEP_AUDIT_2026-05-09_PERFORMANCE_STABILITY_MAP_LAYERS.md` mit 20 Sektionen, End-to-End-Matrix Store/Legacy, 13 Hotspots (3 P0 / 4 P1 / 4 P2 / 2 P3), Punktelayer-Audit, Test-Coverage-Matrix, 7 Folgeprompt-Skizzen. Kein Code-Refactor, nur Doku-Korrekturen (README Test-Stand 1400/2/0, 46-MB-Klarstellung Legacy vs Store). 200-Routen-Limit im Store-Pfad ist bestätigt durch adaptives `maxVisibleRoutes`/`maxRouteCandidates`-Budget ersetzt. Punktelayer-Provider Foundation-fertig, MapKit-Marker auf keiner Karte aktiv (Phase 10B Xcode-Handoff offen). Linux-Vollsuite **1400 / 2 skipped / 0 failed** (unverändert). Store-Pfad bleibt **default OFF**. **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim).

## Vorheriger Stand (2026-05-08, Phase-10A-Folge-Commit `feat: add local timeline wal checkpoint recovery`)
- **[2026-05-08] Phase-10C — Legacy hardening**: Status **Heatmap+ExportPreview+derived_cache+Warnings DONE; Overview-Refactor offen**. `AppHeatmapModel.startPrecomputation` hat Hard-Cap `densityPointCap = 500_000` + `HeatmapStats.truncatedDensityPoints` Signal (Sources/LocationHistoryConsumerAppSupport/AppHeatmapModel.swift); `ExportPreviewData` Doppel-Iteration über `path.points.map` (2× für coordinates + timestamps) durch einen reservedCapacity-Loop ersetzt — Semantik unverändert (Sources/LocationHistoryConsumerAppSupport/ExportPreviewData.swift); `LocalTimelineStore` neue Purge-API `deleteDerivedCache(olderThan:cacheKind:)` + `pruneDerivedCache(maxEntries:cacheKind:)` (deleteAll löscht weiter `derived_cache`); Build-Warnings bereinigt (`LHCollapsibleMapHeader.swift:199/293` `os(iOS) || os(visionOS)` → `os(iOS)`, `StoreBackedHeatmapDataProvider.swift:287/296` unused `withUnsafeMutableBytes` Result `_ =`-discardiert). 8 neue Tests `LocalTimelineDerivedCachePurgeTests.swift`, bestehende grün. **Bewusst NICHT umgesetzt (P1 in NEXT_STEPS)**: `AppOverviewTracksMapView.scanCandidates` lazy/streaming Refactor (Score/Bounds auf full coords L720–725; Risiko HOCH; bereits bounded via `pointBudget=2_000_000` L648, `candidateStorageCap=512`/Route L657, `overlayLimit=150–300` Profile L580–617, `nonisolated static` + `Task.detached` off-Main); `ExportPreview` Sampling (würde Tests + Preview/Export-Match brechen). Store-Pfad bleibt **default OFF**, Legacy-Pfad-Verhalten unverändert (Heatmap-Cap nur bei Extremfällen sichtbar). **46-MB-Gate FAILED / pending hardware retest** (verbatim).
- **[2026-05-08] Phase-10B (Weg 3) — Foundation-only PointLayer-Provider + zentraler PerformanceBudget**: Status **Punktelayer-Foundation + adaptive Budgets DONE; UI-Verdrahtung WIP**. NEU `Sources/LocationHistoryConsumerAppSupport/LocalTimelineMapPerformanceBudget.swift` (zentraler Budget-Typ, adaptive detail-level-/zoom-abhängige Budgets — overview 24/256/1500/8/256, low 48/512/3000/16/512, medium 96/1024/6000/32/1024, high 192/2048/12000/64/2048; plus `dayMap`-Profil 12/64/800/12/256). Ersetzt im Store-Pfad die starre 200-Routen-Vorstellung durch `maxVisibleRoutes` (UI-bounded) + `maxRouteCandidates` (Provider-Over-fetch). NEU `LocalTimelineMapPointLayerModels.swift` (Foundation-only: `PointKind { visit, activityStart, activityEnd, routeSample }`, `Entry`, `Cluster` mit `dominantKind`, `Response`/`ClusterResponse` mit Truncation-Flags). NEU `LocalTimelineMapPointLayerProvider.swift` (`dayPointCandidates`, `pointCandidates`, `dayClusteredPoints`, `clusteredPoints`; bounded-read: Visits/Activities aus Spalten direkt, routeSamples lazy via `CoordBlobIterator + LocalTimelineRouteDecimator`; deterministische Ausgabe). **Modelle + Provider only — in keinem View aktiv**, UI-Verdrahtung in `LocalTimelineDayMapViewState` + `LocalTimelineDayMapView` ist WIP. Legacy-Pfad (AppOverviewTracksMapView, AppHeatmapModel, ExportPreviewData) **unverändert**; Legacy-Tier-overlayLimits (150–300) bleiben. AppExport NICHT materialisiert; vollständige `[Double]`-Materialisierung weiterhin NEIN. Store-Pfad bleibt **pre-production / feature-flagged / default OFF**. **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim). Keine ASC/Review/TestFlight-/Hardware-Freigabe behauptet.
- [x] P1-A/B Progress/Cancel-UI sichtbar verdrahtet (2026-05-08, Weg 2). LocalTimelineImportProgressPresentation (Foundation-only) + LocalTimelineImportUIState (@MainActor) + LocalTimelineImportProgressView/LocalTimelineTestModeBanner (SwiftUI) eingebunden in AppShellRootView und wrapper/LH2GPXWrapper/ContentView; Cancel-Round-Trip Linux-getestet (AppFlowImportCancelRoutingTests, LocalTimelineImportProgressPresentationTests, LocalTimelineImportUIStateTests). Store-Pfad bleibt pre-production / feature-flagged / default AUS. Legacy-Pfad unverändert. 46-MB-Hardware-Gate bleibt FAILED / pending retest.
- **[2026-05-08] Phase-10A-Folge — P1-C + P1-D `feat: add local timeline wal checkpoint recovery`**: Setzt **P1-C (WAL-Checkpoint-/Cleanup-Strategie)** und **P1-D (Recovery-Test für Mid-Import-Crash)** aus `docs/DEEP_AUDIT_2026-05-08_LOCAL_TIMELINE_STORE_AND_MAP.md` § 13 um, ausschließlich im Store-Pfad. Neue API `LocalTimelineStore.checkpointWAL(mode:)`/`truncateWAL()`/`bestEffortTruncateWAL()` über `sqlite3_wal_checkpoint_v2` mit `WALCheckpointMode { passive, full, restart, truncate }` und `WALCheckpointInfo`; Default-Mode `.truncate` schreibt WAL-Frames zurück und kürzt `-wal` auf 0 Byte. Neuer Error-Case `LocalTimelineStoreError.checkpointFailed`. Hard-Fail bei expliziter API; Best-Effort im nachgelagerten Cleanup nach `LocalTimelineImportWriter.finalize`/`cancel` und `LocalTimelineStoreLifecycle.deleteAllLocalTimelineData(store:)` (vor `store.close()` und vor File-Unlink). Reads checkpointen **nicht** — keine Performance-Falle, keine VACUUM-Orgie. **Keine Schemaänderung**: `imports`-Row liegt inside `BEGIN IMMEDIATE`, mid-import-Abbruch hinterlässt keine sichtbare Partial-Import-Row; ein Status-Feld wäre redundant, weil bereits Transaktionsgrenzen jede Sichtbarkeit halbfertiger Imports verhindern. Recovery-Test (`LocalTimelineStoreRecoveryTests`) simuliert abrupten Abbruch durch `store.close()` ohne `writer.finalize()`/`writer.cancel()`; SQLite verwirft die offene `BEGIN IMMEDIATE`-Transaktion automatisch. **Linux-Simulation, kein echter iOS-Jetsam-Test** — Power-Loss-/Kernel-Kill-Verhalten auf Hardware bleibt eine separate Verifikation. **NEU Tests** `LocalTimelineStoreWALCheckpointTests` (7), `LocalTimelineStoreRecoveryTests` (6); Vollsuite **1345 / 2 skipped / 0 failed** (vorher 1332). **Harte Grenzen**: Keine SwiftUI-Anbindung, keine UI-Cancel-/Progress-Verdrahtung (P1-A/P1-B-Folge weiter offen). Legacy-Pfad unverändert; Default-Aufrufe ohne Hooks identisch. Keine neuen Dependencies. Store-Pfad bleibt **default AUS, pre-production / feature-flagged**. **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim). Keine ASC/Review/Hardware/TestFlight-Freigabe behauptet. Keine Map-Phase-10B-Aussage.
- **[2026-05-08] Phase-10A-Folge — P1-A + P1-B `feat: add cancellable local timeline import progress`**: Setzt **P1-A (Import-Cancel-Pfad)** und **P1-B (Import-Progress-Surface)** aus `docs/DEEP_AUDIT_2026-05-08_LOCAL_TIMELINE_STORE_AND_MAP.md` § 13 um, **ausschließlich im Store-Pfad**. **NEU** `LocalTimelineImportProgress` (Foundation-only Sendable Snapshot mit Phase + Counter + optional Byte-Hints, **keine Standortdaten**), `LocalTimelineImportProgressThrottle` (Default 500 Entries, Phase-Change/Terminal-Override), `LocalTimelineImportCancellation` (NSLock-guarded, idempotent, kein globaler State; Fehler `LocalTimelineImportCancellationError.cancelled`), `LocalTimelineImportController` (Service-Layer, bündelt Token + Sink + `latestProgress` + Observer-API, Linux-testbar). **Geändert** `GoogleTimelineStoreImporter.importFromFile/Data` akzeptiert `Hooks(progress:throttle:cancellation:clock:)`; Cancellation wird **vor Stream-Start, vor jedem Entry, vor Finalize** geprüft. Bei Cancel rollt `LocalTimelineImportWriter.cancel()` → SQLite `ROLLBACK` zurück; **es bleibt kein gültiger Teilimport im Store** (`testCancelMidStreamRollsBackTransaction`). **Geändert** `AppContentLoader.loadImportedContentEnvelope` und `LH2GPXAppFlow.loadImportedFileEnvelope` reichen `importProgress`/`importCancellation` durch; Cancel-Outcome im AppFlow ist `EnvelopeImportOutcome.failure(title: "Import cancelled", clearBookmark: false)`; Loader-Fehler ist neuer `AppContentLoaderError.importCancelled(_:)`. Importer-Skip (Entry ohne erkannten Payload, malformed `timelinePath`) und Writer-Skip (unparseable Timestamp) sind disjunkt → finaler `skippedEntries` ist die Summe. **NEU Tests** `Tests/.../LocalTimelineImportProgressTests` (7), `LocalTimelineImportCancellationTests` (5), `LocalTimelineImportControllerTests` (4), `GoogleTimelineStoreImporterProgressCancelTests` (7), `AppFlowImportProgressCancelTests` (3). Linux-Vollsuite **1332 / 2 skipped / 0 failed** (vorher 1306/2/0; +26 neue). **Harte Grenzen:** Keine SwiftUI-Anbindung in `AppShellRootView`/`wrapper/LH2GPXWrapper/ContentView.swift`/`LocalTimelineSessionLandingView` — UI-Hook ist **bewusst Folge-Issue** (siehe `NEXT_STEPS.md`). Legacy-Pfad unverändert; Default-Aufrufe ohne `Hooks` verhalten sich identisch. Keine neuen Dependencies, kein `[Double]`-Materialisieren, kein `AppExport` im Store-Pfad, keine Standortdaten in UserDefaults. Store-Pfad bleibt **default AUS, pre-production / feature-flagged**. **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim). **Keine ASC/Review/Hardware/TestFlight-Freigabe behauptet, keine Map-Phase-10B-Aussage.**
- **[2026-05-08] Build-158-Vorbereitung — `feat: add internal test toggles for testflight build 158 prep`**: Build 157 ist Xcode Cloud grün und TestFlight-installierbar (Status „Überprüft", interne Tests erfolgreich). Da TestFlight-Tester keine Launch-Argumente/ENV setzen können, sind zwei interne UserDefaults-Toggles in `AppTechnicalOptionsView` ergänzt: `LH2GPX.localTimelineStoreTestModeEnabled` und `LH2GPX.importMemoryLoggingEnabled`. **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineTechnicalTestSettings.swift` (`final class` ObservableObject, `.shared` + `init(userDefaults:)`, default `false`, **nur Bool**). `LocalTimelineFeatureFlags.resolve(arguments:environment:settings:)`/`resolveFromProcess(settings:)` und `ImportMemoryProbe.isEnabledForEnvironment(_:arguments:settings:)` ergänzt; Args/ENV bleiben primärer Aktivator, Setting aktiviert zusätzlich. `ImportMemoryProbe.isLoggingEnabled` ist jetzt computed → Toggle wirkt ohne Relaunch. **NEU Tests** `Tests/LocationHistoryConsumerTests/LocalTimelineTechnicalTestSettingsTests.swift` (12 Cases, Linux-grün); `testOnlyBoolsAreStoredUnderToggleKeys` pinpoint die Bool-only-Pflicht. AppShellRootView/Wrapper-ContentView unverändert. **Toggle ist interner Testmodus / Pre-production**; LocalTimelineStore-Pfad bleibt **default AUS**. Live-Upload/Recording/Auth unberührt. **Keine ASC/Review/Hardware-Freigabe behauptet**, **keine Map-Phase-10B-Aussage**, **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim).
- **[2026-05-08] Xcode Cloud Archive-Fail Build 155/156 (Workflow „Release – Archive & TestFlight", Exit 65) — Compile-Fix `fix: resolve xcode heatmap grid key compile failure`**: Namens-Kollision zweier top-level `GridKey`-Definitionen im Modul `LocationHistoryConsumerAppSupport` (`HeatmapGridBuilder.swift` `Int32`-Variante hinter `#if canImport(MapKit) && canImport(SwiftUI)`-Guard vs. `LocalTimelineHeatmapGridAggregator.swift` `private struct GridKey` mit `Int`). Auf Linux schloss der MapKit-Guard die HeatmapGridBuilder-Variante aus → SwiftPM grün; auf Apple-Plattformen Build 155 (`06f81ae`) und 156 (`5cb7783`) → „Invalid redeclaration of 'GridKey'" + „ambiguous for type lookup" + „Cannot convert value of type 'Int' to expected argument type 'Int32'" Zeile 79 des Aggregators. Fix: `LocalTimelineHeatmapGridAggregator.swift` benennt `GridKey` → `LocalTimelineHeatmapGridKey` (privat, file-scope). Heatmap-Logik, API, UI unverändert. Linux-SwiftPM weiter grün; `swift test` voll grün nach Fix. **Xcode Cloud Retest pending — keine Aussage über echte Apple-Builds.** Phase-Status (Phase 10A / Phase 10B / 46-MB-Gate) unverändert. **Phase 10B bleibt offene Mac/Xcode-Pflicht.** **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim). Store-Pfad bleibt default AUS. Keine ASC/TestFlight-Freigabe behauptet.
- Zentrales Repo: `iOS-App` (dev-roeber/iOS-App)
- Vorstufen: LocationHistory2GPX-Monorepo (historisch), LocationHistory2GPX-iOS (historisch), LH2GPXWrapper (historisch)
- **[x] LocalTimelineStore Phase-10A-Spike eingecheckt (2026-05-08, Folge-Commit `feat: add store backed day map ui surface`)**: feature-flagged **Store-DayMap-UI-Surface** in der bestehenden `LocalTimelineDayDetailView`. **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayMapViewState.swift` (Foundation-only Presentation Model: `LocalTimelineDayMapViewState`, `LocalTimelineDayMapSource`, harte `Budget`-Grenzen — default **12 Routen / 256 Punkte pro Route / 4096 Punkte gesamt**). **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayMapView.swift` (SwiftUI `#if canImport(SwiftUI)`-guarded **Placeholder; KEIN MapKit-Import**; echte `MKMapView`-/`MKMultiPolyline`-Verdrahtung explizit **Phase-10B Mac/Xcode-Pflicht**). **Geändert** `LocalTimelineDayDetailView` (neue optionale Map-Sektion; nur sichtbar wenn `mapSource != nil` und Pfad-Metadaten existieren; "Load map"-Button startet bounded Candidate-Load **ohne Koordinatendecodierung**; "Decode all routes" toggelt bounded Geometrie-Decode innerhalb `Budget`). **Geändert** `LocalTimelineSessionLandingView` (reicht neuen optionalen `dayMapSource` durch). **NEU** `LH2GPXAppFlow.makeProductionDayMapSource(for:)` (öffnet eigenen Reader auf `session.storeURL`, bindet `StoreBackedMapDataProvider`, nutzt Visit-Koordinaten als Bounds-Fallback). **Geändert** `Sources/LocationHistoryConsumerApp/AppShellRootView.swift` und `wrapper/LH2GPXWrapper/ContentView.swift` reichen neue Source ans Landing-View durch. **NEU Tests** `Tests/LocationHistoryConsumerTests/LocalTimelineDayMapViewStateTests.swift` (7), `LocalTimelineDayMapBoundsTests.swift` (4) — alle Linux-grün. **Bounded-Read-Garantien Phase 10A**: Candidates lesen ausschließlich path metadata (kein `coord_blob`-Decodierung); Geometrie ausschließlich für selektierte pathIDs lazy decodiert; harte Budgets pro Route + pro Tag; Bounds primär aus path metadata (union der bbox-Spalten), Fallback auf Visit-Koordinaten via Closure, leerer Tag → `bounds == nil`; malformed `coord_blob` → kontrollierter `LocalTimelineMapProviderError.malformedCoordBlob` ohne Crash; Anti-Meridian bleibt Phase 10B/11 (direktes min/max-Reduce). **Harte Grenzen Phase 10A**: Feature-flagged Store-DayMap-UI-Surface, kein Default-Rollout. **KEIN MapKit-Import** in der Phase-10A-View; echte `MKMapView`-Verdrahtung bleibt **Phase-10B Mac/Xcode-Pflicht**. **KEINE vollständige sichtbare Kartenmodernisierung.** Legacy-Map unverändert. KEIN AppExport-Rebuild aus Store. KEIN vollständiger `[Double]`-Import-Buffer. KEIN eager `coord_blob`-Decoding beim Candidate-Load. KEIN Live-Upload-Mix. KEINE neuen externen Dependencies. KEINE Darwin-FileProtection-Aktivierung. KEIN RTree (bleibt deferred, TEXT path-IDs). KEINE Hardware-/AppStore-/TestFlight-/ASC-Aussage. **46-MB-Gate bleibt FAILED / pending hardware retest.** **Phase 10B (verbleibend offen vor produktivem UI-Rollout)**: echte MapKit-/`MKMapView`-/`MKMultiPolyline`-Verdrahtung der Phase-10A-Placeholder-View (Mac/Xcode-Pflicht; Anti-Meridian-Behandlung); Heatmap-/Overview-UI-Hook gegen `StoreBackedHeatmapDataProvider`; Export-UI-Hook gegen `StoreBackedExportWriter`; Darwin FileProtection-Aktivierung; 46-MB-Hardware-Retest; RTree `path_bounds` (Schema-breaking); Privacy-Doku-Update; Store-Default-Rollout; TestFlight/Xcode-Cloud Build ≥100.
- **[x] LocalTimelineStore Phase-9B-Spike eingecheckt (2026-05-08, Folge-Commit `feat: wire local timeline day detail ui`)**: feature-flagged **Store-DayList + DayDetail-UI** über die bestehende `LocalTimelineSessionLandingView`. **Geändert** `AppSessionState` (neues Feld `selectedLocalTimelineDayId: String?` + Mutator `selectLocalTimelineDay(_:)`; in `show(localTimeline:)`/`show(content:)`/`clearContent()` mitgenullt). **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayBrowserSource.swift` (Foundation-only Source-Struct + `bind(session:reader:)` Convenience für die View-Hooks; **bounded — kein `coord_blob`, keine Polylines**). **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayListView.swift` (`#if canImport(SwiftUI)`-guarded; Tage newest-first mit Datum / Routen / Visits / Distanz; **kein Map-Hook**). **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayDetailView.swift` (`#if canImport(SwiftUI)`-guarded; Datum + Visits + Activities + Path-Metadaten + Hinweis "Path points available (not decoded)"; **kein eager `coord_blob`-Decoding, keine Map**). **NEU** `LH2GPXAppFlow.makeProductionDayBrowserSource(for:)` (öffnet `LocalTimelineStore` an `session.storeURL`). **Geändert** `LocalTimelineSessionLandingView` (erweitert um optionales `dayBrowser`/`selectedDayId`/`onSelectDay`; rendert Liste + sheet-basierte Detail-Navigation via NavigationStack; **backward-kompatibel**, defaults nil). **Geändert** `wrapper/LH2GPXWrapper/ContentView.swift` und `Sources/LocationHistoryConsumerApp/AppShellRootView.swift` reichen `makeProductionDayBrowserSource` + Selection-Binding durch. **NEU Tests** `Tests/LocationHistoryConsumerTests/LocalTimelineDayBrowserSourceTests.swift`, `LocalTimelineSelectionStateTests.swift`. **Harte Grenzen Phase 9B**: KEIN Map-/Heatmap-/Overview-UI-Hook gegen Store. KEIN AppExport-Rebuild. KEIN vollständiger `[Double]`-Import-Buffer. KEIN eager `coord_blob`-Decoding. KEIN Default-Rollout — Store-Pfad bleibt feature-flagged via `LH2GPX_LOCAL_TIMELINE_STORE`, default AUS. KEIN Live-Upload-Mix. KEINE neuen externen Dependencies. KEINE Hardware-/AppStore-/TestFlight-Aussage. KEINE Darwin-FileProtection-Aktivierung. KEIN RTree (bleibt deferred, TEXT path-IDs). **46-MB-Gate bleibt FAILED / pending hardware retest.** **Phase 10 (verbleibend offen vor produktivem UI-Rollout)**: Map/Heatmap/Overview UI-Hook gegen Provider, Darwin FileProtection-Aktivierung, 46-MB-Hardware-Retest, RTree `path_bounds` (Schema-breaking), Privacy-Doku-Update, Store-Default-Rollout, Export-UI-Hook, TestFlight/Xcode-Cloud Build ≥100.
- **[x] LocalTimelineStore Phase-9A-Spike eingecheckt (2026-05-08, Folge-Commit `feat: wire local timeline day presentation`)**: **Wrapper/AppFlow-Wiring + Settings-Delete-Button + Landing-View für aktive Store-Session**. **NEU** `LH2GPXAppFlow.apply(envelopeOutcome:to:preserveOnFailure:) -> AppliedEnvelopeRouting` (geteilte Linux-testbare Routing-Helper-Funktion für Wrapper + Package-AppShell; routet `.legacy/.localTimeline/.failure` mit optionaler Bookmark-Preservation), `LH2GPXAppFlow.makeProductionDeletionPresentation()` (Convenience für Settings/Technical-Hosts). **Geändert** `wrapper/LH2GPXWrapper/ContentView.swift` und `Sources/LocationHistoryConsumerApp/AppShellRootView.swift` — beide rufen jetzt `loadImportedFileEnvelope(...)` (statt `loadImportedFile(...)`) und routen via `apply(envelopeOutcome:to:)`. **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineSessionLandingView.swift` (`#if canImport(SwiftUI)`-guarded) — zeigt Session-Metadaten + Lösch-Button bei aktiver `localTimelineSession`; **kein `coord_blob`-Read, kein Map/Heatmap/Overview-Hook**; eingebunden in beiden App-Shells via body-Branch `else if let storeSession = session.localTimelineSession`. **Geändert** `AppTechnicalOptionsView` (in `AppOptionsView.swift`) — neue Section "Local Timeline Store" mit Feature-Flag-Status (`LocalTimelineFeatureFlags.resolveFromProcess()` Enabled/Disabled), Status-Zeile "Pre-production / Feature-flagged", Lösch-Button "Delete imported local data" mit kontrollierten States `idle/running/succeeded/failed`. **NEU Tests** `Tests/LocationHistoryConsumerTests/WrapperLocalTimelineEnvelopeRoutingTests.swift` (6 Cases, Linux-grün): legacy/localTimeline/failure(clearBookmark T/F)/Replace-Invariante in beide Richtungen. **Trennung Service/Presentation-testbar vs UI-aktiv**: Routing-Helper + Settings-Delete-Button + Landing-View sind **UI-aktiv hinter Feature-Flag**; vollständige Store-DayList/DayDetail/Map/Heatmap/Overview-Surfaces bleiben **nicht UI-aktiv**. **Harte Grenzen Phase 9A**: KEIN Map-/Heatmap-/Overview-UI-Hook gegen Store. KEIN AppExport-Rebuild aus Store. KEIN vollständiger `[Double]`-Import-Buffer. KEIN Default-Rollout — Store-Pfad bleibt feature-flagged via `LH2GPX_LOCAL_TIMELINE_STORE`, default AUS. KEIN Live-Upload-Mix. KEINE neuen externen Dependencies. KEINE Hardware-/AppStore-/TestFlight-Aussage. KEINE Darwin-FileProtection-Aktivierung (bleibt offene Phase-9-Pflicht). KEIN RTree (bleibt deferred, TEXT path-IDs). **46-MB-Gate bleibt FAILED / pending hardware retest.** Settings-DayList/DayDetail UI ist nur als Landing-View für Store-Session sichtbar; vollständige Store-DayList/DayDetail-UI bleibt **Phase 9B**. **Phase 9 (verbleibend offen vor produktivem UI-Rollout)**: Phase 9B Store-DayList/DayDetail UI, Map/Heatmap/Overview UI-Hook gegen Provider, RTree `path_bounds` (Schema-breaking), Darwin FileProtection-Aktivierung, Export-UI-Hook gegen `StoreBackedExportWriter`, 46-MB-Hardware-Retest, TestFlight/Xcode-Cloud Build ≥100, App-Flow-Umschaltung gegen Conditional-Gate, Privacy-Doku-Update vor produktivem Rollout.
- **[x] LocalTimelineStore Phase-8B-Spike eingecheckt (2026-05-08, Folge-Commit `feat: add store backed heatmap lod cache`)**: **Heatmap-Doppelbug-Fix zentral via Foundation-only Helper + `derived_cache`-Tabelle (additiv, FK CASCADE auf `imports.id`) + Foundation-only Heatmap-Modelle + deterministischer Grid-Aggregator + Foundation-only Store-backed Heatmap Data Provider mit bounded Sampling, Grid-LOD-Aggregation und cache-backed Roundtrip**. **NEU** `Sources/LocationHistoryConsumer/AppHeatmapPathSampler.swift` (Foundation-only Helper, kanonische Priorität: `flatCoordinates` wenn vorhanden + gerade Element-Anzahl, sonst `points` Fallback; ungerade flatCoordinates gelten als malformed → kontrollierter Fallback auf `points`). **Geändert** `AppHeatmapModel.swift:55-77` nutzt jetzt den Sampler statt der Doppel-Iteration über `path.points` UND `path.flatCoordinates` — **Heatmap-Doppelbug ist ab Phase 8B zentralisiert gefixt** (im `docs/MAP_ARCHITECTURE_AUDIT.md` §2 dokumentiert). **NEU** `LocalTimelineHeatmapModels.swift` (Foundation-only: `LocalTimelineHeatmapSample`, `LocalTimelineHeatmapSampleResponse`, `LocalTimelineHeatmapGridCell`, `LocalTimelineHeatmapLODResponse`, `LocalTimelineHeatmapCacheKey`, `LocalTimelineHeatmapCacheEncoding`), `LocalTimelineHeatmapGridAggregator.swift` (deterministischer Grid-Aggregator: cell-size pro Detail-Level overview=0.5°/low=0.1°/medium=0.02°/high=0.005°; hartes `maxCells`/`maxSamplesConsumed` Limit; stabile Sortierung lat asc, lon asc), `StoreBackedHeatmapDataProvider.swift` (`heatmapSamples(importID:viewport:maxRoutes:maxPointsPerRoute:maxSamples:)` bounded sampling, `heatmapLOD(importID:viewport:options:)` Grid-Aggregation optional cache-backed via `derived_cache`, `clearHeatmapCache(importID:)`; Cache-Payload-Codec deterministisch Magic 'L8B1' little-endian; Cache-Key über `LocalTimelineHeatmapCacheKey.make(...)` mit 1e-3°-Quantisierung; malformed `coord_blob` kontrolliert übersprungen). **Geändert** `LocalTimelineStoreSchema.swift` (neue **additive** Tabelle `derived_cache` mit FK auf `imports.id` + `ON DELETE CASCADE`; zwei neue Indizes `idx_derived_cache_import_kind_key` und `idx_derived_cache_kind_created`; **`userVersion` bleibt 2** rein additiv, keine semantische Schema-Änderung), `LocalTimelineStore.swift` (CRUD: `putDerivedCache`, `derivedCache`, `deleteDerivedCache`, `countDerivedCache`; `deleteAll()` löscht jetzt auch `derived_cache`). **NEU** `Tests/LocationHistoryConsumerTests/AppHeatmapModelGeometryTests.swift` (7 Linux-grüne Cases), `LocalTimelineHeatmapGridAggregatorTests.swift` (7 Cases), `StoreBackedHeatmapDataProviderTests.swift` (11 Cases inkl. 50k synthetic store + cache hit/clear roundtrip), `LocalTimelineRTreeCapabilityTests.swift` (dokumentiert RTree-Fallback). **RTree (`path_bounds`) bleibt kontrolliert deferred** — Pfad-IDs in `paths` sind TEXT (`paths.id TEXT PRIMARY KEY`); RTree erwartet INTEGER `docid`; Surrogate-Integer-Mapping wäre Schema-breaking. Bbox-Index-Scan aus Phase 8A bleibt aktiv. **Bounded-Read-Garantien Phase 8B (zusätzlich zu Phase 8A 1-6)**: 7) `heatmapSamples` viewport-gebunden, doppelt bounded (`maxRoutes` × `maxPointsPerRoute`), total-bounded (`maxSamples`); 8) pro Pfad lazy decode via `CoordBlobIterator`, nie vollständige Import-Geometrie im RAM; 9) `heatmapLOD` aggregiert nur bounded Samples, Cache-Payload trägt Zellen, keine Roh-Punkte; 10) `derived_cache` vom Import-Lifecycle abhängig (FK CASCADE) und über `clearHeatmapCache` invalidierbar. **Status: Spike/pre-production, nicht UI-aktiv. KEIN SwiftUI-Map/MKMapView-Hook, KEIN UI-Heatmap-Renderer-Hook (existierender SwiftUI-Heatmap-Renderer unverändert; konsumiert weiter `AppExport`). KEIN AppExport-Rebuild aus Store. KEIN vollständiger `[Double]`-Import-Buffer. KEIN Live-Upload-Mix. Store-Pfad bleibt default AUS (`LH2GPX_LOCAL_TIMELINE_STORE`-Flag unverändert). Schema additiv, `userVersion` unverändert 2/2. RTree kontrolliert deferred. FileProtection-Status unverändert (Phase-4-Capsule). 46-MB-Gate bleibt FAILED / pending hardware retest.** **Phase 9 (offen vor produktivem UI-Rollout)** — verbleibende Pflichten: RTree `path_bounds` virtual table (würde Surrogate-Integer-Mapping erfordern → Schema-breaking), Wrapper/SwiftUI-Wiring der Presentation-/ViewState-Schicht, Settings-Delete-UI-Button, Map/Heatmap/Overview UI-Hook gegen Provider, **Darwin FileProtection-Aktivierung**, Export-UI-Hook gegen `StoreBackedExportWriter`, 46-MB-Hardware-Retest, TestFlight/Xcode-Cloud Build ≥100, App-Flow-Umschaltung gegen Conditional-Gate, Privacy-Doku-Update (`docs/privacy.html`, `docs/PRIVACY_MANIFEST_SCOPE.md`) vor produktivem Rollout. **Keine Map-Modernisierung. Keine Hardware-/ASC-/TestFlight-Aussagen. 46-MB-Crashfall bleibt FAILED / pending hardware retest unverändert.** MKMapView-Migration bleibt blockiert hinter 46-MB-Gate.
- **[x] LocalTimelineStore Phase-8A-Spike eingecheckt (2026-05-08, Folge-Commit `feat: add store backed map data provider`)**: **Foundation-only Store-backed Map Data Provider + bounded Map-Domain-Modelle + stride-/budget-basierter Route-Decimator + zwei additive bbox-Metadata-Indizes auf `paths`** über den Store-Pfad. **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineMapModels.swift` (Foundation-only Map-Domain-Modelle: `LocalTimelineMapViewport` mit Anti-Meridian-Reject, `LocalTimelineMapDetailLevel` overview/low/medium/high, `LocalTimelineMapPointBudget` default-Tabelle pro Level monoton, `LocalTimelineMapQuery`, `LocalTimelineMapRouteCandidate` metadata-only ohne `coord_blob`, `LocalTimelineMapPoint`, `LocalTimelineMapRouteGeometry` bounded points, `LocalTimelineMapOverviewResponse` mit `truncatedRoutes`/`truncatedPoints`, `LocalTimelineMapBounds`, `LocalTimelineMapProviderError`; **keine SwiftUI/MapKit/CoreLocation-Abhängigkeit**), `StoreBackedMapDataProvider.swift` (`routeCandidates(importID:viewport:limit:)`/`dayRouteCandidates(dayID:viewport:limit:)` metadata-only ohne `coord_blob`, `routeGeometry(pathID:detailLevel:maxPoints:)` lazy single-path decode via `CoordBlobIterator`, `overviewRoutes(query:)` doppelt bounded mit `maxRoutes` und `budget.maxTotalPoints`, `mapBounds(forImportID:)`/`mapBounds(forDayID:)` Aggregat über `paths.min/max_lat/lon`-Spalten ohne Geometrie-Decode), `LocalTimelineRouteDecimator.swift` (deterministischer stride-/budget-basierter Decimator, Iterator-basiert über `Sequence<EncodedCoordinate>`, erster + letzter Punkt erhalten, `maxPoints` hart, leere/1-Punkt-Pfade stabil; **Douglas-Peucker bleibt Phase 8B/9**). **Geändert** `LocalTimelineStoreSchema.swift` (zwei neue **additive** Indizes `idx_paths_bounds_minmax` und `idx_paths_day_bounds`; **`userVersion` bleibt 2**, rein additiv; RTree-`path_bounds` virtuelle Tabelle bleibt **Phase-8B-Pflicht**), `LocalTimelineStore.swift` (neue public APIs `pathMetadata(forImportId:viewportMin/Max...:limit:)`, `pathMetadata(forDayId:viewportMin/Max...:limit:)`, `pathBoundingBox(forImportId:)`, `pathBoundingBox(forDayId:)` plus Test-Helper `indexNames(forTable:)`; bbox-Filter linearer scan über `min/max_lat/lon`-Spalten, NULL-Bounds konservativ als überlappend gewertet, newest-first `ORDER BY start_time`), `LocalTimelineStoreReader.swift` (thin wrappers `pathMetadata(forImportId:viewport:limit:)`, `pathMetadata(forDayId:viewport:limit:)`, `pathBoundingBox(forImportId:)`, `pathBoundingBox(forDayId:)`). 4 neue Test-Dateien, 33 Cases (`StoreBackedMapDataProviderTests` 15 inkl. 50k-synthetic-store-bounded, malformed `coord_blob` → kontrollierter Fehler, unknown import returns empty, unknown path throws, viewport-Filter, day-scope, overview `maxRoutes`/`maxTotalPoints`; `LocalTimelineRouteDecimatorTests` 8; `LocalTimelineMapBoundsTests` 7 inkl. viewport-Validation flipped lat/antimeridian/out-of-range, intersect classic/disjoint/null-bounds, point-budget defaults monoton; `LocalTimelineMapSchemaIndexTests` 2 inkl. fresh-store-hat-beide-Indizes und reopened-store-nach-DROP-gewinnt-sie-additiv-zurück, `userVersion` bleibt `2`). **Bounded-Read-Garantien Phase 8A**: route candidates kein blob, route geometry single-path lazy decode, overview doppelt bounded, mapBounds Aggregat ohne Geometrie-Decode, kein `AppExport` über Provider, kein `[Double]` für ganzen Import. **Status: Spike/pre-production, nicht UI-aktiv. KEIN SwiftUI-Map/MKMapView-Hook, KEIN UI-Hook, KEIN Renderer-Wechsel in dieser Phase. KEIN AppExport-Rebuild aus Store. KEIN vollständiger `[Double]`-Import-Buffer. KEIN Live-Upload-Mix. Store-Pfad bleibt default AUS (`LH2GPX_LOCAL_TIMELINE_STORE`-Flag unverändert). Schema unverändert (`userVersion = 2`, Indizes additiv). FileProtection-Status unverändert (Phase-4-Capsule). Provider ist ab jetzt die kanonische Schnittstelle für künftige UI-Hooks.** Phase 8B (offen vor produktivem UI-Rollout): **RTree `path_bounds` virtual table** (Pflicht, in 8A explizit deferred), `derived_cache`/Heatmap-LOD-Persistenz, Wrapper/SwiftUI-Wiring der Presentation-/ViewState-Schicht, Settings-Delete-UI-Button, Map/Heatmap/Overview UI-Hook gegen Provider, **Darwin FileProtection-Aktivierung**, **Heatmap-Doppelbug-Fix** (`AppHeatmapModel.swift:55-77`, im MAP_AUDIT bereits vermerkt — nicht behauptet, dass behoben), Export-UI-Hook gegen `StoreBackedExportWriter`, 46-MB-Hardware-Retest, TestFlight/Xcode-Cloud, App-Flow-Umschaltung, Privacy-Doku-Update. **Keine Map-Modernisierung. Keine Hardware-/ASC-/TestFlight-Aussagen. 46-MB-Crashfall bleibt FAILED / pending hardware retest unverändert.** MKMapView-Migration bleibt blockiert hinter 46-MB-Gate.
- **Linux-Stabilisierung nach P0-Memory-Fix `34bc369` (2026-05-08)**: Linux-SwiftPM-Vollbuild und `swift test` waren nach `34bc369` pre-existing kaputt (iOS-only Heatmap/MapTrack-Color-Preference-Enums in `AppPreferences` referenziert, aber unter `#if canImport(SwiftUI) && canImport(MapKit)`-Guard definiert). Fix-Train **NEU** `Sources/LocationHistoryConsumerAppSupport/HeatmapPreferenceEnums.swift` extrahiert die vier reinen Preference-Enums (`AppHeatmapPalettePreference`, `AppHeatmapScalePreference`, `AppHeatmapRadiusPreset`, `AppMapTrackColorMode`) aus `HeatmapPalette.swift`/`HeatmapLOD.swift`/`AppHeatmapView.swift`/`MapTrackStyling.swift` als reine `String`-`RawValue`-Enums; iOS-only-Extensions (z. B. `AppHeatmapRadiusPreset.scale`, `uploadStatusColor`) bleiben hinter Plattform-Guards. `OptionsPresentation.swift` hebt die String-Helpers `uploadStatusText`/`serverUploadPrivacyText` aus dem `#if canImport(SwiftUI)`-Guard heraus. `LH2GPXAppFlow.swift` setzt `url.startAccessingSecurityScopedResource()`/`stopAccessingSecurityScopedResource()` in `#if canImport(UIKit) || canImport(AppKit)`-Guard; `GoogleTimelineStreamReader.swift` packt `autoreleasepool { … }` in `#if canImport(Darwin)`-Guard mit Linux-Fallback (gleiche Parse-Logik); `DaySummaryRowPresentation.swift` ergänzt explizites `import Foundation`. Tests: **NEU** `Tests/LocationHistoryConsumerTests/LinuxStabilizationRegressionTests.swift` (7 Linux-fähige Cases: Konverter-Invariante never-both-shapes, points↔flat Distanzparität ±1 m, AppSessionContent-Init < 250 ms / 5000 Days, lazy vars weiter nutzbar, `show(content:)` < 250 ms / 5000 Days, Banner liest aus `meta`, 50k synthetische Timeline-Entries via `incrementalStreamConverter` → alle flat — Linux-Smoke ~24 s, **kein** Hardware-Pass, **kein** iOS-Jetsam-Beleg). `LargeImportMemorySafetyTests.swift` `import CoreLocation` und 2 Tests in `#if canImport(CoreLocation) && canImport(MapKit)`-Guard. `UIWiringTests.swift` 8 Tests von `@MainActor` auf `MainActor.assumeIsolated { … }` umgestellt. `TCXImportParserErrorTests.swift` `testTCXMalformedXMLThrowsInvalidXML` akzeptiert `.invalidXML` ODER `.noTrackPoints` (Linux-corelibs-foundation `XMLParser` ist permissiver als Darwin). **Test-Stand Linux**: `swift build` (Vollbuild) clean, `swift build --build-tests` clean, `swift test` **1034 Tests, 2 Skips, 0 Failures** (vorher 1033 vor 50k-Stress-Test). Erwarteter Mac-Stand (post-Linux-Stabilisierung, mit allen iOS-only Tests hinter `canImport(SwiftUI)`/`MapKit`/`CoreLocation`/`UIKit`): **~1133** (1033 + ~100 iOS-only). **46-MB-Crashfall bleibt FAILED** bis Hardware-Retest auf iPhone 15 Pro Max — Mac/iPhone-Handoff, auf Linux-Server nicht durchführbar; die Linux-Stabilisierung ändert iOS-Verhalten nicht. Map-Modernisierung (MKMultiPolyline/MKTileOverlay) bleibt **Roadmap, nicht erledigt** — siehe `docs/MAP_ARCHITECTURE_AUDIT.md` §5. ASC/TestFlight Build ≥100 nicht angefasst.
- **Großimport-Jetsam-Kill (P0) — dritter Hardware-Fail trotz `ae5de1f`**: am 2026-05-07T15:10:44+02:00 auf iPhone 15 Pro Max (`iPhone16,2`, iOS 26.4 / 23E246, Xcode 26.3, macOS 15.7) erneut Jetsam (`IDEDebugSessionErrorDomain Code 11`, „The app ‘LH2GPXWrapper’ has been killed by the operating system because it is using too much memory.", Operation duration **95.156 ms** vs. 216.606 ms zweiter Fail / 232.341 ms erster Fail). Die deutlich kürzere Op-Dauer signalisiert: der Peak liegt **früher** im Importpfad als bisher angenommen — wahrscheinlich tief im Streaming-/Konverter-Pfad oder beim Übergang Streaming → Session-Materialisierung. Code-Stand vorbereitet (kein verifizierter Erfolg) im HEAD `<commit-tba>` nach `ae5de1f`: Build-Identitäts-Logging `[LH2GPX_BUILD]` immer auf App-Start; `ImportMemoryProbe` verdichtet (Probe-Punkte `import.fileSelected`, `zip.open.*`, `zip.entry.sniff.*`, `zip.stream.chunk` alle 8 Chunks, `stream.elements` alle 1000, `stream.element.outlier`, `stream.before/afterElementParse` throttled, `converter.ingest` alle 1000, `converter.dayMap.count` alle 5000, `converter.before/afterFinalize`, `loader.before/afterSessionContent`, `session.before/afterShowContent`, `app.didReceiveMemoryWarning`); `ImportMemoryProbe.isEnabledForEnvironment(_:arguments:)` akzeptiert env **und** Launch-Argumente; `AppBuildInfo.isMemoryLoggingEnabled` + Settings → Technical → Build Info zeigt „Memory Logging: Enabled/Disabled". **flatCoordinates-Kanonisierung (P0 Fokus 1, Code-Seite done)**: Google-Timeline-Imports schreiben jetzt `flatCoordinates: [Double]` statt `points: [PathPoint]` ohne ISO-Zeitstrings pro Punkt — geschätzte Einsparung ~80–120 MB resident bei 46-MB-ZIP; alle Consumer (`PathDistanceCalculator`, `AppExportQueries`, `DayMapDataExtractor`, `ExportRouteSanitizer`, `AppHeatmapModel`, GPX/KML/GeoJSON/CSV-Builder) flat-aware; `AppHeatmapModel`-Doppelbug (Punkte bei beiden Geometrien doppelt gezählt) gefixt. Hardware-Retest des Release-Builds auf iPhone 15 Pro Max **steht weiter aus** (Mac/iPhone-Handoff — auf Linux-Server nicht durchführbar); 46-MB-Punkt der Manual-Risk-Checkliste **bleibt FAILED** bis Tester-Bestätigung. Tests in dieser Session ergänzt: `ImportMemoryProbeActivationTests.swift` (15 Tests, env+args-Aktivierung) und `FlatCoordinatesGeometryTests.swift` (23 Tests, flat-Kanonisierung über alle Consumer + Heatmap-Doppelbug-Regression). Erwarteter Mac-Test-Stand: ~1081 + 15 + 23 = ~1119 Tests; finale Mac-Run-Zahl wird im nächsten Doku-Sync (post-Hardware-Retest) nachgetragen. SwiftPM-Linux-Vollbuild ist pre-existing kaputt für AppSupport (iOS-only Heatmap/MapTrack-Color-Types in `AppPreferences`); auf dem Linux-Server validiert nur `swift build --target LocationHistoryConsumer` (clean).
- **[x] LocalTimelineStore Phase-7B-Spike eingecheckt (2026-05-08, Folge-Commit `feat: add store backed day presentation surface`)**: **Foundation-only Presentation/ViewState-Schicht + AppSessionState-Extension + Service-layer Envelope-Hook im AppFlow**. **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayListViewState.swift` (Foundation-only ViewState für Day-List-Surface über Store-Pfad), `LocalTimelineDayDetailViewStateAdapter.swift` (Foundation-only Adapter projiziert Reader-Daten in bounded DayDetail-ViewState), `AppSessionPresentationSource.swift` (Presentation-Quelle inkl. `AppSessionState`-Extensions `activeContent` und `isLocalTimelineActive`), `LocalTimelineDeletionPresentation.swift` (Presentation-Schicht über `LocalTimelineDeletionService`; dokumentiert: **kein Bookmark-/Preferences-Cleanup nötig im Store-Pfad** — keine UserDefaults für Standortdaten). **Geändert** `LH2GPXAppFlow.swift` (neue Methode `loadImportedFileEnvelope(...) -> EnvelopeImportOutcome` als feature-flagged Service-layer-Hook; **Legacy `loadImportedFile(...)` byte-identisch unverändert**). 5 neue Test-Dateien (`LocalTimelineDayListViewStateTests`, `LocalTimelineDayDetailViewStateAdapterTests`, `AppSessionLocalTimelinePresentationTests`, `LocalTimelineDeletionPresentationTests`, `AppFlowLocalTimelineEnvelopeTests`). Schema unverändert (`userVersion = 2`). **Status: Spike/pre-production, nicht UI-aktiv. Store-Pfad bleibt default AUS (`LH2GPX_LOCAL_TIMELINE_STORE`-Flag). Kein UI-Hook (kein Wrapper/SwiftUI-Wiring), kein Map/Heatmap/Overview/Export-UI-Hook. Kein AppExport im Store-Pfad materialisiert; keine vollständige `[Double]`-Import-Materialisierung. FileProtection-Status unverändert (Phase-4-Capsule, Aktivierung weiterhin Darwin/iOS-Pflicht). Live-Upload bleibt strikt getrennt. Keine Standortdaten in UserDefaults.** Phase 8 (offen vor produktivem UI-Rollout) deferred: Wrapper/SwiftUI-Wiring der Presentation-/ViewState-Schicht, Map/Heatmap/Overview Provider, `derived_cache`+RTree+`path_bounds`, Export-UI-Hook, **Darwin FileProtection-Aktivierung**, 46-MB-Hardware-Retest, TestFlight/Xcode-Cloud, App-Flow-Umschaltung, Privacy-Doku-Update vor Rollout. **Keine Map-Modernisierung. Keine Hardware-/ASC-/TestFlight-Aussagen. 46-MB-Crashfall bleibt FAILED / pending hardware retest unverändert.**
- **[x] LocalTimelineStore Phase-7A-Spike eingecheckt (2026-05-08, Folge-Commit `feat: add feature flagged local timeline loader path`)**: **feature-flagged AppSession/AppContentLoader-Hook** über Envelope-Kapsel. **NEU** `Sources/LocationHistoryConsumerAppSupport/AppSessionContentSource.swift` — Envelope-Enum mit Cases `inMemory(AppSessionContent)` und `localTimeline(LocalTimelineSession)`. **Kapsel-Approach** — `AppSessionContent` selbst wird **nicht** erweitert; Source-Enum-Verschmelzung in `AppSessionContent` ist explizit **Phase 7B**. **Geändert** `AppSessionState.swift` (neue Property `localTimelineSession: LocalTimelineSession?` + Mutator `show(localTimeline:)` — Banner/Title aus Session-Metadaten, kein AppExport, keine Coord-Decode; `show(content:)` und `clearContent()` setzen mit zurück). **Geändert** `AppContentLoader.swift` (neuer Einstieg `loadImportedContentEnvelope(from:autoRestoreMode:onPhase:flags:storeFactoryProvider:) -> AppSessionContentSource`; **Flag-Off → exakt der Legacy-Pfad**, byte-identisch; Flag-On + Google-Timeline-JSON oder ZIP-mit-genau-einem-Timeline-Entry → `GoogleTimelineStoreImporter` + `LocalTimelineSession.make(...)` → `.localTimeline(...)`; andere Formate — LH2GPX-Objekt-JSON, GPX, TCX — fallen kontrolliert zurück; neuer Error-Case `localTimelineStoreFailed(String)`; Importe additiv mit frischer `importId`; Bulk-Wipe bleibt `LocalTimelineDeletionService`). 3 neue Test-Dateien, 14 neue Cases (`AppSessionLocalTimelineSourceTests` 5, `AppContentLoaderLocalTimelineStoreTests` 5, `LocalTimelineFeatureFlagIntegrationTests` 4). Schema unverändert (`userVersion = 2`). **Status: Spike/pre-production, nicht UI-aktiv. Default-Rollout bleibt Legacy-AppExport — Store-Pfad ist NIE default; gated by feature flag. Kein UI-Hook für DayList/DayDetail/Map/Heatmap/Overview/Export/Settings. Kein AppExport im Store-Pfad materialisiert; kein vollständiger `[Double]`-Import-Buffer. Live-Upload bleibt strikt getrennt. Keine Standortdaten in UserDefaults. Darwin FileProtection nicht aktiviert. Bestehender Legacy-AppExport-Pfad unverändert/byte-identisch.** Phase 7B (offen vor UI-Hook) deferred: `AppSessionContent`-Source-Enum-Verschmelzung statt Envelope-Kapsel, DayList/DayDetail/Map/Heatmap/Overview-UI-Hooks, Settings-UI „Importierte Daten löschen", `derived_cache`/RTree `path_bounds`, **Darwin FileProtection-Aktivierung**, 46-MB-Hardware-Retest, Privacy-Doku-Update vor Rollout. **Keine Map-Modernisierung. Keine Hardware-/ASC-/TestFlight-Aussagen. 46-MB-Crashfall bleibt FAILED / pending hardware retest.**
- **[x] LocalTimelineStore Phase-6-Spike eingecheckt (2026-05-08, Folge-Commit `feat: add feature flagged local timeline session source`)**: **feature-flagged AppSession-Quelle** für den LocalTimelineStore. **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineFeatureFlags.swift` (resolved `LH2GPX_LOCAL_TIMELINE_STORE` aus `ProcessInfo.arguments`/`environment`; `--LH2GPX_LOCAL_TIMELINE_STORE`/bare arg/env-Werte `1`/`true`/`yes`/`on` case-insensitive; default disabled; **keine UserDefaults**), `LocalTimelineSession.swift` (Foundation-only Session-Modell `importID`/`sourceFilename`/`storeURL`/`createdAt`/`importedAt`/`summary` mit `dayCount`/`pathCount`/`visitCount`/`activityCount`/`totalDistanceM`/`dateRange`; `make(reader:importID:storeURL:)` konstruiert ohne Geometrie-Materialisierung; Caller besitzt Store-Lifetime), `LocalTimelineAppSessionAdapter.swift` (projiziert Reader-Daten in bounded ViewState-Modelle `DaySummaryView`/`DayDetailView`/`VisitView`/`ActivityView`/`PathMetadataView`; Methoden `daySummaries()`/`dayDetail(dayId:)`/`coordinates(forPathId:)` explizit on-demand lazy via `CoordBlobIterator`), `LocalTimelineDeletionService.swift` (dünner Wrapper um `LocalTimelineStoreLifecycle.deleteAllLocalTimelineData`; idempotent; **keine UserDefaults-Aufräumung**). 4 neue Test-Dateien, 17 neue Cases (`LocalTimelineFeatureFlagsTests` 8, `LocalTimelineSessionTests` 3, `LocalTimelineAppSessionAdapterTests` 4, `LocalTimelineDeletionServiceTests` 2). Schema unverändert (`userVersion = 2`). **Status: Spike/pre-production, nicht UI-aktiv. Store-Pfad gated by feature flag, kein default-aktiver Pfad. Kein AppExport im Store-Pfad materialisiert; kein vollständiger `[Double]`-Import-Buffer materialisiert. Kein UI-Hook, kein App-Session-Switch, kein AppContentLoader-Hook, kein DayList/DayDetail/Map/Heatmap/Overview-Hook, kein Settings-UI. Darwin FileProtection in diesem PR nicht angefasst. Bestehender AppExport-Exportpfad unverändert.** Phase 7 (offen vor UI-Hook) deferred: `AppSession`/`AppSessionContent`-Erweiterung um `case localTimeline(...)`, AppContentLoader-Hook, Settings-UI „Importierte Daten löschen", DayList/DayDetail/Map/Heatmap/Overview-Hooks, FileProtection-Aktivierung Darwin-Pass, Adapter zu `flatCoordinates`-Konsumenten, `derived_cache`/RTree, App-Flow-Umschaltung, Privacy-Doku. Map-Modernisierung bleibt blockiert. Conditional Gate unverändert. **46-MB-Crashfall bleibt FAILED / pending hardware retest.**
- **[x] LocalTimelineStore Phase-5-Spike eingecheckt (2026-05-08, Folge-Commit `feat: add store backed streaming export`)**: **store-backed Streaming Export** (GPX/KML/GeoJSON/CSV) liest direkt aus `LocalTimelineStoreReader` und schreibt inkrementell in eine Datei unter `LocalTimelineStorageLocations.exportStagingRoot/<uuid>/export.<ext>`. **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineExportTypes.swift` (Foundation-only Typen: `LocalTimelineExportFormat` gpx/kml/geoJSON/csv, `LocalTimelineExportSelection` mit `importID` + optional `dateRange`/`dayIds` + `includeVisits`/`includeActivities`/`includePaths`, `LocalTimelineExportResult` mit `outputURL`/`format`/`bytesWritten`/`dayCount`/`pathCount`/`visitCount`/`activityCount`/`pointCount`, `LocalTimelineExportError` `unknownImport`/`emptySelection`/`malformedCoordBlob`/`ioFailure`/`readerFailure` — empty-selection-Entscheidung explizit als Fehler), `LocalTimelineStreamingTextWriter.swift` (inkrementeller UTF-8-Datei-Writer; parent-dir idempotent; `bytesWritten` zählt UTF-8-Bytes; `finalize()` idempotent), `StoreBackedExportWriter.swift` (`init(reader:locations:)`, `export(selection:format:)`; Days bounded, Visits/Activities/Paths via `dayDetail`, Koordinaten **ausschließlich pro Pfad lazy via `coordinateSequence(forPathId:)`/`CoordBlobIterator`**; **materialisiert KEINEN `AppExport`, KEINEN `[Double]`-Buffer für einen ganzen Import; schreibt direkt in die Datei**). GPX schreibt `<wpt>`+`<trk>/<trkseg>/<trkpt>`; KML `Placemark` mit `Point`/`LineString`; GeoJSON `FeatureCollection` mit Point-/LineString-Features (Properties `kind`/`name`/`mode`/`date`); CSV-Header `type,date,time,lat,lon,name,mode,distance_m`; Activities in CSV als eigene Rows, in GPX/KML/GeoJSON nur gezählt. 3 neue Test-Dateien, 26 neue Cases (`LocalTimelineExportSelectionTests` 6, `LocalTimelineStreamingTextWriterTests` 5, `StoreBackedExportWriterTests` 15). `swift test` **1148/2/0** in 123.7s (+26 vs. 1122). **Bestehende `AppExport`-Builder (`GPXBuilder`/`KMLBuilder`/`GeoJSONBuilder`/`CSVBuilder`) und der bestehende AppExport-Exportpfad bleiben unverändert.** **Status: Spike/pre-production, nicht UI-aktiv. Kein UI-Hook, kein Map-Hook, kein AppContentLoader-Hook, kein App-Session-Switch.** Phase 6 (FileProtection-Aktivierung Darwin-Pass, Adapter zu `flatCoordinates`-Konsumenten, `derived_cache`/RTree, App-Flow-Umschaltung, Settings-Eintrag „Importierte Daten löschen", Privacy-Doku) bleibt offen vor UI-Hook. Map-Modernisierung bleibt blockiert. Conditional Gate unverändert. **46-MB-Crashfall bleibt FAILED / pending hardware retest.**
- **LocalTimelineStore Phase-4-Spike eingecheckt (2026-05-08, Folge-Commit `feat: add local timeline storage lifecycle`)**: **Storage-Lifecycle / iOS-Readiness** eingecheckt. **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStorageLocations.swift` (4 Roots: DB unter `applicationSupportDirectory/LocationHistory2GPX/Imports/` mit `store.sqlite`+WAL/SHM, RenderCache unter `cachesDirectory/LocationHistory2GPX/RenderCache/`, ImportStaging unter `temporaryDirectory/LocationHistory2GPX/ImportStaging/`, ExportStaging unter `temporaryDirectory/LocationHistory2GPX/ExportStaging/`; `temporary(under:)`/`ensureDirectoriesExist` idempotent), `LocalTimelineFileAttributes.swift` (Backup-Exclusion via `URLResourceKey.isExcludedFromBackupKey`; Linux no-op), `LocalTimelineFileProtection.swift` (FileProtection-Kapselung Ziel `completeUnlessOpen`; **Hook nur dokumentiert, nicht aktiviert** — Aktivierung offene Darwin-Pflicht; Linux `"noop-linux"`), `LocalTimelineStoreFactory.swift` (`openStore()`/`temporary(under:)`/`production()`; orchestriert Dirs → Backup-Exclusion → FileProtection-Hook → `LocalTimelineStore(url:)` → Datei-Attribute), `LocalTimelineStoreLifecycle.swift` (High-Level `deleteAllLocalTimelineData(store:)` → `store.deleteAll()` + close + DB+WAL+SHM + RenderCache + ImportStaging + ExportStaging + `ensureDirectoriesExist`; idempotent; keine UserDefaults-Aufräumung). 5 neue Test-Dateien, 26 neue Cases. Schema unverändert (`userVersion = 2`, additiv). **Status: Storage-Lifecycle/iOS-readiness eingecheckt, Spike/pre-production, nicht UI-aktiv, 46-MB-Gate FAILED unverändert.** Kein UI-Hook, kein AppContentLoader-Hook, keine automatische Migration, kein DayList/DayDetail/Map-Hook, kein Export-Umbau, kein `AppExport` über den Store-Pfad. Phase 5 (FileProtection-Aktivierung Darwin-Pass, Adapter zu `flatCoordinates`-Konsumenten, `derived_cache`/RTree, App-Flow-Umschaltung, Settings-Eintrag „Importierte Daten löschen", Privacy-Doku) bleibt offen vor UI-Hook. Map-Modernisierung bleibt blockiert. Conditional Gate unverändert.
- **NEU `docs/MAP_ARCHITECTURE_AUDIT.md`**: Bestandsaufnahme aller Kartenflächen + Roadmap-Pfad zu UIKit `MKMapView`/`MKMultiPolyline` für Heavy Overview/Heatmap. **Documentation/Roadmap — nicht umgesetzt**, keine Karten-Modernisierung als done. Architektur-Pfad steht für späteren Umsetzungs-Train bereit.
- **NEU `docs/LOCAL_TIMELINE_STORE_RESEARCH.md` (2026-05-08, HEAD-Anker `ebd8146`)**: geprüfte Designrichtung für eine on-disk Timeline-Persistenz als strukturelle Alternative zum heutigen In-Memory-`AppExport`-Pfad bei sehr großen Importen. Empfehlung SQLite-C-API + `Int32`-microdegrees-BLOB in `applicationSupportDirectory/LocationHistory2GPX/Imports/`, `completeUnlessOpen`, backup-excluded; Streaming-Decode-Iterator. **Conditional Gate**: **P0 falls 46-MB-Hardware-Retest FAILED** (geht vor Map-Modernisierung und weiterer UI-Politur), **P1/P2 falls PASSED** (Robustheits-/Skalierungsprojekt). Map-Modernisierung (MKMultiPolyline/MKTileOverlay) bleibt blockiert, bis 46-MB-Hardware-Pass ODER LocalTimelineStore-P0-Entscheidung vorliegt. **46-MB-Crashfall bleibt FAILED.**
- **LocalTimelineStore Phase-1-Spike eingecheckt (2026-05-08, Folge-Commit nach `45e5fcf`)**: isolierte Surface, **kein produktiver App-Flow umgestellt**. **NEU** `Sources/CSQLite/` (Linux systemLibrary für `libsqlite3` via `pkg-config sqlite3`); `Sources/LocationHistoryConsumer/CoordBlob.swift` (`CoordBlobEncoder`/`CoordBlobIterator`/`EncodedCoordinate`/`CoordBlobError`, Encoding-Identifier `int32-microdeg-v1`, 8 B/Punkt, lazy Sequence-Decode); `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStore{,Schema,Error}.swift` (SQLite-C-API direkt, Tabellen `imports`/`days`/`paths` mit `ON DELETE CASCADE`, FK enforced via `PRAGMA foreign_keys = ON`, `PRAGMA user_version = 1`, `PRAGMA journal_mode = WAL`, `withTransaction`, `paths(forDayId:)`). **NEU Tests** Linux-grün: `CoordBlobEncoderTests` (13), `CoordBlobDistanceTests` (2), `LocalTimelineStoreTests` (8). `swift test` **1057/2/0** (+23 gegenüber 1034). Conditional Gate aus `45e5fcf` unverändert.
- **LocalTimelineStore Phase-3-Spike eingecheckt (2026-05-08, Folge-Commit `feat: add store backed timeline read surface`)**: **store-backed Read-Surface** für Imports/Days/Visits/Activities/Paths — **kein produktiver App-Flow umgestellt**, **kein UI-Hook**, **kein Map-Hook**, **kein `AppExport` über den Reader**. Schema unverändert (`userVersion = 2`). **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStoreReadModels.swift` (Foundation-only Read-Models `LocalTimelineImportRecord`/`LocalTimelineDayRecord`/`LocalTimelineVisitRecord`/`LocalTimelineActivityRecord`/`LocalTimelinePathRecord` ohne `coord_blob`/`LocalTimelineDayDetailSnapshot`). **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStoreReader.swift` (Foundation-only Adapter über `LocalTimelineStore` mit `imports()`/`importRecord(id:)`/`latestImport()`, `days(forImportId:)`/`dayRecord(id:)`/`dayRecord(forImportId:date:)`/`dayCount(forImportId:)`, `dayDetail(dayId:)` bündelt day + visits + activities + path-METADATA ohne eager Coord-Decode, `paths(forDayId:)`/`pathRecord(id:)`, `coordinateSequence(forPathId:)` lazy via `CoordBlobIterator` mit `ReaderError.unknownPath`/`.malformedCoordBlob`, sowie Aggregate `dayDateRange(forImportId:)`/`totalDistance/totalRouteCount/totalVisitCount(forImportId:)`). Store-intern ergänzt um Read-Helper `imports()`/`importRow(id:)`/`latestImport()`/`dayRow(id:)`/`dayRow(forImportId:date:)`/`dayCount(forImportId:)`/`pathMetadata(forDayId:)` (ohne `coord_blob`)/`pathMetadata(id:)`/`coordBlob(forPathId:)`/`dayDateRange/totalDistance/totalRouteCount/totalVisitCount(forImportId:)`. **Bounded-Read-Garantien (1-6)**: 1) `imports()` ohne paths/visits/activities; 2) `days(forImportId:)` ohne `coord_blob`; 3) `dayDetail(dayId:)` ohne eager Coord-Decode; 4) Path-Koordinaten nur explizit/lazy via `coordinateSequence`; 5) kein `AppExport` im Read-Pfad; 6) kein API materialisiert ein vollständiges `[Double]` für einen ganzen Import. **NEU Tests** Linux-grün: `LocalTimelineStoreReaderTests` (13), `LocalTimelineStoreReadPersistenceTests` (6), `LocalTimelineStoreBoundedReadTests` (5). Erwarteter `swift test`-Stand: 1071 → **~1095** (+24, vorbehaltlich grünem Vollauf). FileProtection-Flag, `applicationSupportDirectory`-Pfad mit `isExcludedFromBackupKey`, `deleteAll()`-Erweiterung um Caches/tmp/Bookmark/Preferences, Adapter zu `flatCoordinates`-Konsumenten, `derived_cache`/RTree, App-Flow-Umschaltung, Settings-Eintrag, Privacy-Doku-Update sind **Phase-4-Arbeit vor UI-Hook**. Status weiterhin **Spike / pre-production**, **nicht produktiv**. **46-MB-Crashfall bleibt FAILED / pending hardware retest.** Map-Modernisierung bleibt blockiert. Conditional Gate unverändert.
- **LocalTimelineStore Phase-2-Spike eingecheckt (2026-05-08, Folge-Commit nach `955c934`)**: **disk-first Google-Timeline-Importpfad** in den Store — **kein produktiver App-Flow umgestellt**, kein UI-Hook, keine Karten-Modernisierung. Schema `userVersion` **1 → 2** additiv: neue Tabellen `visits` (`day_id` FK, lat/lon, semanticType, placeId, probability) und `activities` (`day_id` FK, mode, distance_m, start/end-coords, raw_type, probability), beide mit `ON DELETE CASCADE`. Neue Indizes `idx_days_import_date(import_id,date)`, `idx_paths_day_start(day_id,start_time)`, `idx_visits_day_id`, `idx_activities_day_id`. **NEU** `LocalTimelineImportWriter` (gehaltene `BEGIN IMMEDIATE … COMMIT/ROLLBACK`-Transaktion, bounded per-day-Aggregat, robust skip-statt-throw für ungültige Entries, Activity-start/end produziert 2-Punkt-Pfad). **NEU** `GoogleTimelineStoreImporter` (`importFromFile`/`importFromData` über bestehenden `GoogleTimelineStreamReader`; **kein `AppExport` materialisiert** — typgesichert in `testImporterReturnTypeIsSummaryNotAppExport`). **`LocalTimelineStore.deleteAll()`** löscht in einer Transaktion alle `imports`/`days`/`paths`/`visits`/`activities`-Zeilen, idempotent — **Scope explizit DB-only** (Caches/tmp werden Phase-3 vor UI-Hook ergänzt). **NEU Tests**: `LocalTimelineStoreLifecycleTests` (6), `LocalTimelineImportWriterTests` (4), `GoogleTimelineStoreImporterTests` (4 inkl. 50k-Visit-Smoke über 50 Tage). `swift test` **1071/2/0** (+14 vs. 1057). FileProtection-Flag an `sqlite3_open_v2`, `applicationSupportDirectory`-Pfad mit `isExcludedFromBackupKey`, Caches/tmp-Lifecycle, Adapter zu `flatCoordinates`-Konsumenten, `derived_cache`/RTree `path_bounds`, App-Flow-Umschaltung sind **Phase-3-Arbeit**. **46-MB-Crashfall bleibt FAILED / pending hardware retest.** Map-Modernisierung bleibt blockiert.
- **Vorheriger HEAD `ae5de1f`**: zweiter Hardware-Fail am 2026-05-07T14:14:36+02:00 (216.606 ms). Zweiter Fix-Train: `AppSessionContent.init` ohne `daySummaries`-Materialisierung; `AppSessionState.show(content:)` ohne `content.overview`-Trigger; `ExportBuilder.finalize()` mutating + `removeValue`/`removeAll`; `IncrementalStreamConverter.finalize()` ersetzt Builder; `PathDistanceCalculator` iteriert direkt; `ImportMemoryProbe` (Erst-Version); `AppBuildInfo` + Build-Info-Sektion in App-Optionen; `Info.plist`-`GitCommitSHA` Build-Setting-Injection. War notwendig, aber nicht hinreichend.
- **Vorheriger HEAD `cd77f97`**: erster Großimport-Jetsam-Kill (P0) am 2026-05-07T13:38:37+02:00 (232.341 ms). Root Cause: `JSONSerialization.jsonObject(with: element)` lief außerhalb des `autoreleasepool`. Fix: Parse + Ingest im selben `autoreleasepool`, Element-Capacity-Reset nach Outliern. War notwendig, aber nicht hinreichend.
- Manual Release Risk Acceptance Protocol angelegt in `docs/APPLE_VERIFICATION_CHECKLIST.md` — manuelle Hardware-Abnahme der 4 nicht automatisierbaren Restrisiken (46-MB-Crashfall, Live Activity / Dynamic Island / Lock Screen, iPad-Layout, ASC / TestFlight / Apple Review) muss durch den Tester durchgeführt werden bevor Submit. Acceptance-Anker HEAD `b91a933` (Protokoll-Anlage); 46-MB-Sektion durch dreifachen Hardware-Befund 2026-05-07 von „not verified" auf FAILED hochgesetzt und nach drittem Fail dort weiter dokumentiert. Checkboxen leer (kein Test-Ergebnis). Keine ASC/TestFlight-Freigabe behauptet.

### Verifikation Post-Fix Hardware-Re-Run iPhone 15 Pro Max (2026-05-07, HEAD pending — Commit folgt)

Reine Re-Verifikation nach Day-Detail-Distance-Fix (Commit `853d8d3`). Keine Code-Änderungen.

- testAppStoreScreenshots (iPhone 15 Pro Max, iOS 26.4): PASSED (41.8s)
- testDeviceSmokeNavigationAndActions (iPhone 15 Pro Max, iOS 26.4): PASSED (71.2s)
- testLandscapeLayoutSmoke (iPhone 15 Pro Max, iOS 26.4): PASSED (829.9s)
- `swift test`: **1077 Tests, 2 Skips, 0 Failures** (unverändert gegenüber `853d8d3`).
- `git diff --check`: clean.
- Xcode 26.3 (17C529); App 1.0.1 (100); Bundle `de.roeber.LH2GPXWrapper`; UDID `00008130-00163D0A0461401C`.
- HEAD: pending — Commit folgt.

Hardware-Re-Verifikation jetzt vollständig nach Day-Detail-Distance-Fix: beim Commit `853d8d3` war nur Smoke-Navigation post-Fix verifiziert; testAppStoreScreenshots + testLandscapeLayoutSmoke sind jetzt erneut gefahren und grün.

Weiterhin offen: 46-MB-Crashfall geräteseitig (manueller Import nötig), Live Activity / Dynamic Island / Lock-Screen-Visuals (UI-interaktiv), iPad-Layout, ASC / TestFlight / Apple Review.

### Verifikation Day-Detail-Distance-Fix (2026-05-07, HEAD pending — Commit folgt)

P0/P1-Bug: Day-Detail-Ansicht zeigte „Distance 0" für Routen mit sichtbarer Geometrie, während Insights/Übersicht korrekte Distanzen zeigten. Root Cause: `AppExportQueries.summary` nutzte `effectiveDistance(for: path)`-Fallback (raw `distanceM > 0` ODER Polyline aus Punkten), aber `DayDetailViewState.PathItem` führte nur raw `distanceM` und `DayDetailPresentation` summierte `path.distanceM ?? 0`. Google-Timeline-`timelinePath`-Imports liefern oft `distanceM == nil` aber valide `points` — daher 0 km im Detail.

Fix: neue `PathDistanceCalculator` (Single-Source-of-Truth, `Sources/LocationHistoryConsumer/Queries/PathDistanceCalculator.swift`, inline Haversine ohne CoreLocation); `DayDetailViewState.PathItem.effectiveDistanceM: Double` (non-optional, immer berechnet, raw `distanceM: Double?` bleibt); `AppExportQueries.dayDetail(...)` setzt `effectiveDistanceM` über Calculator; `DayDetailPresentation` liest `effectiveDistanceM` an 5 Stellen (KPI-Card, Route-Subtitle, Summary-Aggregation, Section-Subtitle, Dominant-Mode, Route-Intensity). Bestehende `DayMapDataTests` und `ImportedPathMutationTests` mit `effectiveDistanceM:`-Parameter ergänzt. `DayDetailPresentationTests.testRoutePresentationKeepsPointCountAsConcreteMetric` von 2-Chip auf 3-Chip-Erwartung angepasst (Distance-Chip erscheint jetzt korrekt). 12 neue Cases in `PathDistanceCalculatorTests` (Calculator-Semantik raw>0 wins, nil/zero/negative/NaN fallback, polyline/flatCoordinates fallback, too-few-points, Wrapper-Verhalten, Summary↔DayDetail-Konsistenz-Regression).

- `swift test`: **1077 Tests, 2 Skips, 0 Failures** (+12 gegenüber 1065).
- Device-Smoke iPhone 15 Pro Max (iOS 26.4): `testDeviceSmokeNavigationAndActions` PASSED (75s).
- HEAD: pending — Commit folgt.
- Volle 3-UITest-Suite (testAppStoreScreenshots / testLandscapeLayoutSmoke) für aktuellen HEAD nicht erneut gefahren — nur Smoke-Navigation post-Fix verifiziert.
- Weiterhin offen: 46-MB-Crashfall geräteseitig nach Fix nicht erneut validiert; Live Activity / Lock Screen / iPad / ASC / TestFlight nicht geprüft.

### Verifikation Hardware-Re-Verifikation iPhone 15 Pro Max (2026-05-07, HEAD pending — Commit folgt)

Hardware-Re-Verifikation iPhone 15 Pro Max nach 44pt-Hit-Target-Fix in `HistoryDateRangeFilterBar`. Während des ersten Hardware-Runs (HEAD `7cc2e97`) als P1-UX-Bug gefunden: clear-date-range Button (xmark.circle.fill) hatte 12×12pt Hit-Area (unter Apple HIG 44pt-Minimum, XCUITest „Failed to not hittable"). Fix: `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` um das Button-Image; visible Glyph unverändert.

- testAppStoreScreenshots (iPhone 15 Pro Max, iOS 26.4): PASSED (42.9s)
- testDeviceSmokeNavigationAndActions (iPhone 15 Pro Max, iOS 26.4): PASSED (72.2s)
- testLandscapeLayoutSmoke (iPhone 15 Pro Max, iOS 26.4): PASSED (830s)
- `swift test`: **1065 Tests, 2 Skips, 0 Failures** (unverändert).
- Wrapper xcodebuild iPhone 15 Pro Max: BUILD + TEST SUCCEEDED.
- Xcode 26.3 (17C529); App 1.0.1 (100); Bundle `de.roeber.LH2GPXWrapper`; Team XAGR3K7XDJ.
- HEAD: pending — Commit folgt.
- Weiterhin offen: 46-MB-Crashfall geräteseitig (manueller Import nötig, kein UITest), Live Activity / Dynamic Island / Lock-Screen-Visuals (Always-Permission braucht UI), ASC / TestFlight / Apple Review nicht geprüft.

### Verifikation P1-Hardening-Train (2026-05-07, HEAD `3811bc3`)

P1-Hardening-Train: B1 distanceText! safe-unwrap in `DaySummaryRowPresentation` + B2 `[weak self]` in `AppOverviewMapModel.rebuildOverlays` + B3 Upload-URL-Validation in `AppPreferences.liveLocationServerUploadURLString` (akzeptiert `https://`, `localhost`, `127.0.0.1`, `[::1]`; rejected http remote / garbage; Reset auf `oldValue` per Re-Entrancy-Flag) + 8 neue Tests in `AppPreferencesUploadURLValidationTests.swift`. Token-Property + Keychain unverändert.

- `swift test`: **1065 Tests, 2 Skips, 0 Failures** (+8 gegenüber 1057).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.
- HEAD: `3811bc3`.
- Hardware-Re-Verifikation iPhone 15 Pro Max: weiterhin offen.

### Verifikation UX/Layout-Train + Mock-Helper (2026-05-07, HEAD `5c69afe`)

UX/Layout-Train + Mock-Helper: 6 Achsen — Mock-Client extrahiert (`Tests/LocationHistoryConsumerTests/Helpers/MockLiveLocationClient.swift`), Insights Triple-Range-Picker konsolidiert (`AppInsightsContentView`), Overview Doppel-Header gelöst (Card → "Statistics"/"Statistik"), Map-Pill-Overlap gefixt (`AppOverviewTracksMapView`), Form-vs-LHCard-Konsistenz Settings schmaler Scope (`AppPrivacyOptionsView` + `AppTechnicalOptionsView` → `Form`/`Section`; LiveRecording/Upload/Widget-LiveActivity bleiben LHCard), Hero-Map-Layout-Tests (`LHMapHeaderLayoutTests.swift`, 12 property-based Cases — keine SnapshotTesting-Dependency). Details in `CHANGELOG.md` und `NEXT_STEPS.md`.

- `swift test`: **1057 Tests, 2 Skips, 0 Failures** (+12 gegenüber 1045 — neue Layout-Tests).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.
- HEAD: `5c69afe`.
- Hardware-Re-Verifikation iPhone 15 Pro Max: weiterhin offen.

### Audit-Verifikation Phase 1-5 Audit-Train (2026-05-07, HEAD `20877ae`)

Phase 1-5 Audit-Train (Items 2-15) über zwei Commits — `21b4026` (Phase 1: items 3, 4, 5, 6, 8) + `20877ae` (Phase 2-5: items 7, 11+2, 9, 10, 12, 13+14+15). Inhalt: `projectedDays`-Cache, Mutations-Index, Race-Token, Live-Map-Dedup, `@testable`-Cleanup-Folge, Mock-Client + State-Transition-Tests, `LH2GPXAppFlow` Drift-Extraction + Auto-Restore-Phasen, API-Naming als additives Importing-Protokoll (kein Rename), `wrapper/CI.xctestplan` SwiftPM-Coverage als SKIP dokumentiert (pbxproj-Integration zu fragil), `Tests/README.md` Update, Doku-Truth-Cleanup. Details in `CHANGELOG.md` und `NEXT_STEPS.md`.

- `swift test`: **1045 Tests, 2 Skips, 0 Failures** (+1 gegenüber 1044; Mock-Refactor in Item 7 ersetzt Placeholder-Case durch zwei echte Cases — netto +1).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.
- Hardware-Re-Verifikation iPhone 15 Pro Max: weiterhin offen.

### Audit-Verifikation Bündel B+C+D+A (2026-05-07, Doku-Train, HEAD `e3dae15`)

22 Audit-Achsen aus den Bündeln B (Dead-Code), C (Performance-Restposten), D (Architektur), A (Test-Härtung) als erledigt verbucht; Details in `CHANGELOG.md` und `NEXT_STEPS.md`.

- `swift test`: **1044 Tests, 2 Skips, 0 Failures** (+27 gegenüber 1017; 9 neue Test-Files in `Tests/LocationHistoryConsumerTests/`).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.
- Inhalt: Audit-Batch B+C+D+A.
  - **Bündel B (Dead-Code, ~158 Zeilen weniger):** `quickStat`/`DayTimelineView` aus `AppDayDetailView`, `activeFiltersSection` aus `AppContentSplitView`, gesamte Datei `LHSharedMapChrome.swift` gelöscht — `LHMapStyleToggleButton` public API entfernt (war deprecated, keine externen Caller bekannt). P2-8 bewusst nicht angefasst (`mapControlRow` hat realen Caller in `landscapeMapColumn`).
  - **Bündel C (Perf-Restposten):** `OverviewMapRenderData: Equatable` Hand-`==`, inline Haversine in `approximateDistance(for:)`, `HeatmapGridBuilder` Single-Sort+`suffix`-Trim, `AppExportQueries.findDay` Fast-Path für `isPassthrough`-Filter.
  - **Bündel D (Architektur):** `@testable import` → reines `import` für 15 von 22 Test-Files; 7 behalten `@testable` (internal nötig). `wrapper/CI.xctestplan` SKIP — pbxproj-Integration für SwiftPM-Test-Target out-of-scope. API-Naming (P2-16) und `HeatmapGridBuilder` MapKit-Entkopplung (P2-18) bewusst not done.
  - **Bündel A (Test-Härtung):** 9 neue Test-Files mit 27 Cases — `AppExportDecoderErrorTests`, `GPXImportParserErrorTests`, `TCXImportParserErrorTests`, `GPXRoundTripTests`, `AppExportQueriesFilterCombinationTests`, `AppHeatmapModelEdgeCaseTests`, `LiveLocationFeatureModelStateTransitionTests` (1 Placeholder, Mock-Client-Refactor pending), `ExportMutationsAndFilterTests`, `ZIPGoogleTimelineStreamingPathTests`.
- Hardware-Re-Verifikation iPhone 15 Pro Max: weiterhin offen.
- Verbleibend offen aus dem Audit: P2-8 (Live-Duplicate-Refactor bewusst nicht angefasst), P2-16 (API-Naming), P2-18 (HeatmapGridBuilder MapKit-Entkopplung), P2-17 (CI.xctestplan SKIP), Mock-Client-Refactor.

### Audit-Verifikation Block 1-2-Train (2026-05-07, Doku-Train, HEAD `e3dae15`)

7 Audit-Achsen aus Block 1 (Wiring/Config) und Block 2 (Streaming-Folge) als erledigt verbucht; Details in `CHANGELOG.md` und `NEXT_STEPS.md`.

- `swift test`: **1017 Tests, 2 Skips, 0 Failures** (+5 gegenüber 1012; 2 neue `IncrementalParser`-Cases in `GoogleTimelineStreamReaderTests` plus 3 `measure`-Cases in neuer `GoogleTimelineStreamReaderPerformanceTests`).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.
- Inhalt:
  - Block 1: `WidgetSharedKeys.swift` (NEU) als Single-Source-of-Truth für App-Group-Suite + UserDefaults-Keys; beide `WidgetDataStore.swift`-Mirrors konsumieren die Konstanten (Wrapper-Mirror ergänzt um `saveDynamicIslandCompactDisplay`); P1-3 erledigt. `AppShellRootView` bekommt `.onOpenURL { handleDeepLink($0) }` im Package-App-Target — P1-4 erledigt. Deployment-Target-Inkonsistenz (App 16.0 vs Widget 16.2) bewusst, in `wrapper/README.md` notiert.
  - Block 2: ZIP-Entry-Streaming für Google Timeline (`AppContentLoader.streamGoogleTimelineCandidateIfApplicable`, Sniffer-basiert, greift bei genau einem Google-Timeline-Entry und keinem LH2GPX-Object-Entry); `GoogleTimelineStreamReader.IncrementalParser` + `GoogleTimelineConverter.incrementalStreamConverter()`. Import-Phasen-Progress (`enum ImportPhase { reading, parsing, building }`, `LoadingProgressEngine.phase`, lokalisierte Labels im Wrapper-`ContentView`). Mikro-Benchmark als XCTest-`measure`-Baseline (kein fail-on-regression bar).
- Hardware-Re-Verifikation iPhone 15 Pro Max: weiterhin offen.
- Verbleibend offen aus dem Audit: 7× P1 (P1-18..P1-24 Test-Lücken), ~19× P2.

### Audit-Verifikation Block 1-4 (2026-05-06, Doku-Train)

19 Audit-Achsen über vier Blöcke (Datenverlust-Wiring, Concurrency, Edge-Case-Crashes, Performance-Hotspots) als erledigt verbucht; Details in `CHANGELOG.md` und `NEXT_STEPS.md`.

- `swift test`: **1012 Tests, 2 Skips, 0 Failures** (unverändert; bestehende Tests laufen über die neuen Pfade — keine neuen Tests in diesem Train).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.
- Hardware-Re-Verifikation iPhone 15 Pro Max: weiterhin offen.
- Mikro-Benchmark der Performance-Optimierungen: weiterhin offen — Designziel, kein gemessener Speedup.
- Verbleibend offen aus dem Audit: ~7× P1 (P1-3 `WidgetDataStore`-Duplikat, P1-4 `onOpenURL` fehlt im Package-Target, P1-18..P1-24 Test-Lücken), ~19× P2.
- Track-Editor-Mutations fliessen jetzt in Exporte ein — die bisherige bewusst-offen-Aussage in `README.md` wurde entfernt.

### Memory-Safety: Auto-Restore-Schutz gegen Jetsam (2026-05-06, abends)

**Reaktion auf realen Crash:** Xcode meldete auf iPhone 15 Pro Max einen Memory-Issue/Jetsam-Kill für `LH2GPXWrapper` beim App-Start nach Import einer 46 MB Google-Timeline (`location-history.zip`, ~65 k Timeline-Einträge). Auto-Restore re-parste die Datei vollständig im Launch-Pfad mit drei `JSONSerialization`-Vollparses → transienter RAM-Peak ~400–500 MB → Jetsam-fatal.

**Implementiert (Zwei-Bedingungs-Skip im Auto-Restore-Pfad, Stand 2026-05-06):**
- Sniffer-basierte Format-Detection (`GoogleTimelineConverter.isGoogleTimeline` + neuer `isJSONObject`) ersetzt drei volle `JSONSerialization`-Parses durch einen 1-KB-Byte-Check.
- Auto-Restore lehnt im aktuellen Stand ab, **wenn entweder** (a) der Sniffer eine rohe Google-Timeline (`firstStructuralByte == '['`) erkennt — **unabhängig von der Größe** — **oder** (b) die Datei über dem 50-MB-Cap (`AppContentLoader.autoRestoreMaxFileSizeBytes`) liegt. Implementierung in `assertAutoRestoreEligible` (vorher `assertSizeWithinAutoRestoreLimitIfNeeded`); gilt für direkte JSONs und für ZIPs mit Google-Timeline-Entry (Head-Sniff via begrenztem ZIP-extract-Abbruch). Der reine Größencap allein erfasste den realen 46-MB-Crashfall nicht (46 < 50); der Sniffer-Skip schließt diese Lücke.
- Neuer Fehler `autoRestoreSkippedLargeFile`, userFacingTitle "Import not auto-restored", errorDescription erwähnt jetzt explizit "Raw Google Timeline exports and large files are skipped on launch …". Manueller Import (`autoRestoreMode == false`) bleibt unberührt (256-MB-Cap, kein Sniffer-Skip).
- Query-Fast-Path: `AppExportQueryFilter.isPassthrough` + `AppExportQueries.projectedDays`-Fast-Path schneidet ~80–130 MB transient pro Aufruf auf 65 k-Tage-Imports.
- OverviewMap bounded coordinates: `OverviewMapPathCandidate.fullCoordinates` per `strideDecimate` auf max 512 Punkte gekappt — visuell verlustfrei (Douglas-Peucker läuft trotzdem in `makeOverlay`), spart ~70–90 % residenten RAM bei dichten Tracks.

**Verifikation:** `swift test`: 1006 Tests, 2 skipped, 0 failures (vorher 991 vor Streaming-Parser; 987 vor Sniffer-Skip-Folgefix; davor 973). 18 Tests in `LargeImportMemorySafetyTests` (4 neu: raw Google-Timeline-Skip JSON+ZIP unter Cap, AppExport bleibt restorbar, manueller Pfad bleibt frei). `xcodebuild` (iPhone 17 Pro Max Sim 26.3.1): BUILD SUCCEEDED. Hardware-Re-Verifikation des 46-MB-Falls auf iPhone 15 Pro Max steht aus.

**Streaming-Parser ergänzt (2026-05-06):** `GoogleTimelineStreamReader` (FileHandle, 256-KB-Chunks (vorher 64 KB), UnsafeBytes-Tokenizer mit `@inline(__always)`-Hot-Path und Hex-Literal-Bytevergleichen, String-/Escape-/Depth-Tracking, BOM-Skip, 8-MB-Element-Hard-Cap) plus `GoogleTimelineConverter.convertStreaming(contentsOf url:)`. `AppContentLoader.decodeFile` sniffed `[` und geht direkt in den URL-Pfad ohne `Data(contentsOf:)`. `convert(data:)` läuft jetzt intern ebenfalls über den Reader. 15 neue Tests (`GoogleTimelineStreamReaderTests`).

**Performance-Pass auf der Streaming-Pipeline (2026-05-06):** vier Achsen — (1) UnsafeBytes-Tokenizer statt `Data.Index`-Iteration, (2) Default-Chunk 64 KB → 256 KB, (3) `autoreleasepool` um den Per-Element-`onElement`-Aufruf gegen Foundation-Akkumulation, (4) Direct-Model-Build im Konverter: neue `ExportBuilder`-Struktur akkumuliert direkt `Visit`/`Activity`/`Path`/`PathPoint` und `finalize()` baut `AppExport` über public memberwise-Initializer in `AppExportModels.swift`. Damit entfallen auf der Output-Seite ein `[String: Any]`-Tree-Build, eine `JSONSerialization.data`-Pass, eine JSON-Parse-Pass und ein `AppExportDecoder`-Codable-Decode. Test-Umfang unverändert (1006/2/0); keine Mikro-Benchmarks gemessen — Designziel ist Reduktion der transienten Allokationen, kein gemessener Speedup-Faktor.

**Ehrlich offen:** ZIP-Entry-Streaming nicht umgesetzt — ZIPFoundation extrahiert weiterhin in eine `Data`, der Streaming-Reader läuft danach darauf (Memory-Peak ≈ Größe der entpackten Datei, aber kein zusätzlicher 150–200-MB-`JSONSerialization`-Tree). Auto-Restore lehnt rohe Google-Timeline-Dateien weiterhin ab (Streaming ist speichersicher, aber Sekunden bis Minuten — bewusst nutzergesteuert). Hardware-Re-Verifikation des 46-MB-Falls auf iPhone 15 Pro Max steht aus. Mikro-Benchmark steht aus. Bei sehr vielen Entries (>500 k) bleibt das einmalig aufgebaute Export-Modell ein nichttriviales RAM-Plateau, aber Größenordnungen unter dem alten Pfad.

### Map / Heatmap / Live Next-Level (2026-05-06)

Abgeschlossene Arbeit nach Phase 19.27 / nach dem Hardware-Verifikations-Block 2026-05-05, getrennt nach Feature-Themen:

- **MapLayerMenu (commit `70254ff`)**: alle Map-Layer-Controls auf jeder Map-Surface laufen über ein einziges Right-Side-Dropdown. Ersetzt `LHMapStyleToggleButton` (deprecated), Heatmap-Bottom-Sheet, Capsule-Chip-Cluster, Follow-Pill, Fullscreen-Close-X, standalone Style-/Fit-/Center-Buttons.
- **MapLayerMenu Wiring-Audit-Polish (Doku-Audit 2026-05-06 Abend)**: Day-Map mit `mapPosition`-State + Fit-to-Data, Export-Preview Fit-to-Data, Overview `isFullscreenActive` korrekt verdrahtet, Live-Tracking Landscape-Card nutzt geteilte MapContent-Helpers, Heatmap-Overlay-Pattern vereinheitlicht, tote Parameter (`verticalMapControls`, `showStyleToggle`) entfernt.
- **Heatmap Tier 1 + 2** (commits `e7a2379`, `a2f50bc`, `2e1c928`, `6a7c361`): Lens-Flare entfernt, weichere Kanten, i18n-Fix; pointy-top Hexagon-Polygone; Mercator-Korrektur; cos(lat)-Bin-Aggregation.
- **Heatmap P0 Follow-up Batches** (commits `f5de284`, `bbd9e3b`, `50b4c58`, `825a3de`): sane defaults für Streetzoom, weniger Burnout.
- **Heatmap Next-Level** (commit `9118ac6`): Magma/Inferno-Paletten, Log-Scale, Soft-Glow-Cells.
- **Routes-Modus aus Heatmap entfernt** (commit `fc3ccc5`): Density-only.
- **Maps next-level** (commit `ab054c7`): Tempolayer (Speed-Coloring), Halo-Strokes, Live-Polish.
- **Home-Screen Lightning-Background** (commit `fa006cd`).
- **SIGABRT-Defensivguards** (commit `74300a6`): defensive Patterns gegen Crash beim Live-Tracking-Launch.
- **Demo-Fixture-Swap** (commit `b1d65cb`): bundled Demo ist jetzt ein realer LH2GPX-Track (Oldenburg → Dänemark).
- **Build-Number-Bump** (commit `8854eef`): `CURRENT_PROJECT_VERSION = 100` lokal gesetzt; Xcode Cloud Build ≥100 als naechster ASC-Submit-Kandidat.

Verifikations-Historie für diesen Themenblock (commit-verankert, jüngste zuerst — auflösung des bisherigen 964 vs 1006-Widerspruchs in dieser Datei):
- HEAD `df7071b` (P0-Audit-Patch: Live-Tab-Deeplink + TCX-Doku-Lüge, 2026-05-06): `swift test` 1006/2/0, `xcodebuild` iPhone 17 Pro Max Sim 26.3.1 BUILD SUCCEEDED.
- HEAD `04dea98` (Streaming-Performance-Pass, 2026-05-06): 1006/2/0.
- HEAD `cfa332e` (Streaming-Parser eingeführt, 2026-05-06): 1006/2/0.
- HEAD `838863c` (Sniffer-Skip-Folgefix, 2026-05-06): 991/2/0.
- HEAD `8abe7ec` (Memory-Safety-Auto-Restore-Fix, 2026-05-06): 987/2/0.
- HEAD post-`70254ff` (MapLayerMenu Wiring-Audit-Polish, 2026-05-06 nachmittags): 964/2/0.
- HEAD post-`70254ff` (vor Doku-Audit, 2026-05-05): 927/2/0 (Hardware-Acceptance iPhone 15 Pro Max).

iPhone-15-Pro-Max-Hardware-Verifikation für jeden Stand ab `8abe7ec`: offen — letzte echte Hardware-Acceptance war 2026-05-05 (HEAD-Vorstufe von `70254ff`). Nachfolgende Builds wurden nur via Simulator (iPhone 17 Pro Max Sim 26.3.1) verifiziert.

### Hardware-Verifikation iPhone 15 Pro Max (2026-05-05)

Ausgefuehrt auf: iPhone 15 Pro Max (UDID 00008130-00163D0A0461401C, iOS 26.4)

Implementiert und verifiziert:
- **swift test**: 927 Tests, 0 Failures ✅
- **xcodebuild** (iPhone 15 Pro Max): BUILD SUCCEEDED ✅
- **testAppStoreScreenshots** (iPhone 15 Pro Max): PASSED (44s) ✅ — 6 neue Screenshots 1290×2796
- **testDeviceSmokeNavigationAndActions** (iPhone 15 Pro Max): PASSED (70s) ✅
  - Demo-Load, Overview/All-Time, Heatmap, Insights-Share, Export fileExporter, Live Start/Stop ✅
- **Screenshot-Pflichtset**: 6 Slots (Option 1 — ohne Options-Tab), Dateinamen `iphone15pm_01–06_*.png`
- **UITest vereinfacht**: Slot 07 (Options) und Slot 08 (Day Detail) aus Pflichtset entfernt

Nicht als abgeschlossen markieren:
- Landscape auf allen Tabs: weiter ohne Hardware-Nachweis
- Live Activity / Dynamic Island Batch 5A/5B: Lock Screen, `minimal`, weitere Pfade offen
- Widget auf Homescreen: manuelle Interaktion nötig
- Großer Import-Performance-Test: kein 20MB-Fixture im Repo

### Verifikations-Batch Redesign 1–5B (2026-05-05)

Implementiert und verifiziert:
- **swift test**: 927 Tests, 0 Failures ✅
- **xcodebuild** (generic/platform=iOS + iPhone 17 Pro Max Simulator): BUILD SUCCEEDED ✅
- **CI-Tests** (iPhone 17 Pro Max Simulator, testPlan CI): TEST SUCCEEDED ✅
- **testAppStoreScreenshots** (iPhone 17 Pro Max Simulator): PASSED — 7/8 Screenshots ✅
- **Bugfix UITest**: `insights.section.share` → `insights.share.*` (Identifier-Rename seit Batch 4)
- **Screenshot-Kandidaten** (Simulator): 7 PNGs in `docs/app-store-assets/screenshots/simulator-iphone17promax/`
- **Visuell geprüft** (Simulator): Start, Overview, Days (Sticky Map), Insights (Hero), Export (Checkout), Live (Hero+Diagnostics), Day Detail

### UI/UX Redesign Batch 5B — Live Activity / Dynamic Island / Widget Safety (2026-05-05)

Implementiert und getestet:
- **Content-Safety-Review**: `TrackingStatus` (ContentState), `TrackingAttributes` (statisch) und `WidgetDataStore.LastRecording` enthalten keine Koordinaten, Server-URLs oder Bearer-Token — bestätigt durch Codable-Encoding-Tests und Mirror-Reflexion
- **`minimalView`-Bugfix** (`TrackingLiveActivityWidget.swift`): Tote Bedingung entfernt; Minimal-Icon zeigt nun konsistent `pause.circle.fill` (Pause) oder `location.fill.viewfinder` (aktiv)
- **Dynamic Island (Compact/Expanded/Lock Screen)**: Kein Änderungsbedarf — Inhalte sind bereits auf Statuswerte und Metriken begrenzt; keine sensitiven Felder
- 9 neue Safety-Tests (`LiveActivitySafetyBatch5BTests`), lokaler Nachweis: **927 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- Keine echte iPhone-/Hardware-Verifikation der Live Activity / Dynamic Island
- Keine Lock-Screen-Verifikation auf echter Hardware
- No-Dynamic-Island-Gerät (Pending-/Restart-Pfad) weiter ungeprüft

### UI/UX Redesign Batch 5A — Live Tracking Foundation (2026-05-05)

Implementiert und getestet:
- **Hero/Status-Card** (`heroStatusCard`): Klare Statusanzeige oben im Live-Tracking-Flow; leitet sich aus `isRecording`, `isAwaitingAuthorization` und `authorization` ab — keine neue State-Logik
- **Einklappbarer Diagnostics-Bereich** (`diagnosticsSection`): Alle 8 bestehenden Metriken kollabiert hinter einem Tippen-Trigger; `live.diagnostics.section`-Identifier
- **7 neue Accessibility-Identifier**: `live.status.hero`, `live.map.preview`, `live.recording.primaryAction`, `live.recording.stopAction`, `live.permission.card`, `live.server.status`, `live.diagnostics.section`
- **Token-Masking**: Bearer-Token bleibt in UI auf "Token set" / "No token" reduziert; kein Wert exposed
- 11 neue DE-Strings, lokaler Nachweis: **918 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- Keine echte iPhone-/Hardware-Verifikation
- Keine Landscape-/iPad-Verifikation
- Live Activity / Dynamic Island weiter ungeprüft auf echter Hardware
- Neue App-Store-Screenshots weiter ausstehend
- Server-/Token-Konfiguration funktional unverändert (Scope: nur UI)

### UI/UX Redesign Batch 4 — Insights Dashboard (2026-05-05)

Implementiert und getestet:
- **Hero-Bereich**: `insightsDashboardHero` direkt unter dem Titel — zeigt Datumsbereich und Anzahl aktiver Tage aus repo-wahren Projektionen
- **Verbesserter Leer-Zustand**: `insightsFullEmptyState` mit Two-Path-Logik:
  - Filter aktiv + keine Treffer → kontextueller Hinweis + „Filter zurücksetzen"-Button
  - Keine Daten → statischer Hinweis
- **Overview-Tab Reihenfolge**: Highlights → Activity Streak → Top Days → Daily Averages (Streak prominenter für persönliches Engagement)
- Keine neuen Analyse-Engines, keine Fake-Metriken; alle bestehenden Drilldowns unverändert
- lokaler Nachweis: **897 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- keine neue Insights-Analyse, kein neues Chart-Format
- Insights-Tab visuell noch nicht auf echter Hardware verifiziert

### UI/UX Redesign Batch 3 — Export Checkout (2026-05-05)

Implementiert und getestet:
- Export-Flow in `AppExportView` als klarer Review-/Checkout-Flow neu geordnet: `Review Selection` → `Preview` → `Choose Format` → `What to include` → `Export Destination`
- `Review Selection` zeigt echte Auswahlmetriken aus bestehender Projektion: Tage, Zeitraum, Tracks, Punkte sowie Distanz-/Wegpunkt-/Routen-Badges
- Vorschau nutzt weiter die bestehende Export-Map; ohne stabile Geometrie fällt die UI auf eine kompakte Summary zurück statt eine Fake-Karte zu rendern
- `Export Destination` erklärt jetzt den realen vorhandenen Systempfad: generierte Datei über `.fileExporter` sichern oder teilen
- `ExportPresentation.reviewSnapshot(...)` und `selectionSummary(...)` ergänzen die Checkout-Präsentation, ohne neue Exportlogik einzuführen
- `AppContentSplitView` verdrahtet Rückführung aus dem Export zurück zu `Days` oder `Import`
- lokaler Nachweis: **881 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- keine neue Exportfunktion, kein neues Format, keine neue Serverfunktion
- keine neue Hardware- oder Landscape-Verifikation für Export
- iPad-/regular-width Export-Sheet visuell weiter ungeprüft
- App-Store-Screenshots müssen weiter neu aufgenommen werden; Export-Slot ist nach diesem Batch veraltet

### UI/UX Redesign Batch 2 — Start + Overview (2026-05-05)

Implementiert und getestet:
- **Startseite**: `HomeLocalPrivacyRow` — kompaktes Privacy-+Formate-Banner nach dem Titel; kein Account, lokal verarbeitet, JSON/ZIP/GPX/TCX
- **Übersicht — Reihenfolge**: Karte zuerst (vor Zeitraum/Filter), KPI direkt darunter; Dashboard-Struktur statt verstreuter Karten
- **Übersicht — Empty State**: `overviewEmptyCallToAction` wenn keine Daten geladen; Zeitraum-Card + Continue-Card bei leerem State ausgeblendet
- **Continue-Card vereinfacht**: "Browse Days" als visuell hervorgehobene Primär-Aktion; Insights/Export/Import als sekundäre Zeilen
- 19 neue Tests; Gesamt: **878 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- Hardware-Verifikation auf echtem iPhone ausstehend (Start + Overview)
- Landscape-Verifikation für Start + Overview ausstehend
- App-Store-Screenshots müssen neu aufgenommen werden (zeigen noch altes Layout)

### Sticky Map Workspace — Days-Tab (2026-05-05)

Implementiert und verifiziert:
- `LHMapHeaderState.isSticky`: neue Flag, die `toggleHidden()` blockiert — Map bleibt immer sichtbar
- `daysMapHeaderState` startet mit `.compact` + `isSticky: true` — Days-Map immer visible
- `daysListStickyHeader`: Map-Header + Kontext-Pills via `.safeAreaInset(edge: .top)` — fixed, scrollt nicht weg
- `daysExportSelectionBar`: persistente Export-Bottom-Bar via `.safeAreaInset(edge: .bottom)` — erscheint bei Auswahl
- 16 neue Tests in `LHMapHeaderStateStickyTests`; Gesamt: **849 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- Hardware-Verifikation der neuen sticky Map auf echtem Gerät ausstehend
- App-Store-Screenshots müssen neu aufgenommen werden (zeigen noch altes Layout)
- Landscape-Verifikation für Days sticky Header ausstehend

### Build 74 Accepted — Pending Developer Release (2026-05-05)

Repo-wahr dokumentiert:
- Apple hat Version 1.0 (Build 74) nach Review-Response **akzeptiert**
- ASC-Status: **Ausstehende Entwicklerfreigabe (Pending Developer Release)**
- Statusverlauf: Abgelehnt (2026-05-01) → Wird geprüft → Ausstehende Entwicklerfreigabe
- **Guideline 3.2**: resolved — kein offener Ablehnungsgrund
- **Build 74 wird bewusst nicht veröffentlicht**: Weiterentwicklung vor öffentlichem Release geplant
- Strategie für neuen Build: Developer Reject in ASC → neuen Xcode-Cloud-Build erzeugen → neuen Build + neue Screenshots einreichen
- App ist **nicht** im App Store live

### App Review Ablehnung + Public Audience Clarification (2026-05-05)

Repo-wahr dokumentiert:
- Apple lehnte Version 1.0 (Build 74) am 2026-05-01 unter **Guideline 3.2 — Business / Other Business Model Issues** ab
- Submission ID: `1d2cc080-13cd-45cd-b3e0-c0259a75ce5c`
- Ablehnungsgrund: App wurde fälschlich als organisationsgebundene Lösung eingestuft
- Sachverhalt: LH2GPX ist eine öffentliche Consumer-/Utility-App für persönliche Google-Maps-Standorthistorie
- Kein Account, kein Login, keine Organisationszugehörigkeit erforderlich
- Optionaler Live-Upload = nutzerkonfigurierter Self-hosted-Endpunkt, standardmäßig deaktiviert
- README, App-Feature-Inventory, TESTFLIGHT_RUNBOOK und APPLE_VERIFICATION_CHECKLIST klargestellt
- Response-Entwurf erstellt: `docs/APP_REVIEW_RESPONSE_GUIDELINE_3_2.md`
- Review-Response von Sebastian gesendet → Apple hat akzeptiert (s. Abschnitt oben)

### Build 73 + Screenshot-Submit-Vorbereitung (2026-05-01)

Repo-wahr dokumentiert:
- ASC Version 1.0: `Warten auf Prüfung`, sichtbarer Build `71`
- Xcode Cloud aktuellster erfolgreicher Build: `73`
- Repo-Stand für Build 73: `34734ce` (main HEAD nach Final Truth Sync)
- Screenshots in ASC: aus Build 71, altes UI-Layout — müssen neu aufgenommen werden
- Neue Screenshot-Slots 07 (Options) und 08 (Day Detail) in `testAppStoreScreenshots` vorbereitet
- Runbook für manuelle ASC-Schritte erstellt: `docs/ASC_SUBMIT_RUNBOOK.md`
- Noch nicht ausgeführt: Version aus Prüfung entfernen, Build 73 wählen, Screenshots ersetzen, Submit

### App Store Connect Truth Update (2026-04-30)

Repo-wahr dokumentiert:
- App Store Connect zeigt fuer `LH2GPX` Version `1.0` den Status `Warten auf Prüfung`
- die Version ist eingereicht; Veröffentlichung bleibt manuell
- auf der Versionsseite ist aktuell bewusst Build `52` sichtbar
- der Xcode-Cloud-Workflow `Release – Archive & TestFlight` hat erfolgreichere neuere Builds `55`, `56` und `57`

Nicht als abgeschlossen markieren:
- Build `52` bleibt bewusst in Review; Build `57` wird nicht ohne Apple-Feedback oder bestaetigten release-kritischen Fehler nachgereicht
- App Review ist nicht mehr durch Upload blockiert, aber weiterhin nicht durch vollstaendige Live-Activity-/Dynamic-Island-Hardware-Verifikation abgesichert

### Priorisierte Optimierungs-Roadmap (2026-04-30)

P0 — Release / Review / Hardware-Verifikation
- App-Review-Fortschritt auf Build `52` beobachten und rueckmelden
- offene ASC-Metadaten: Support-URL und Privacy-URL eingetragen (2026-04-30); GitHub Pages live (HTTP 200 verifiziert 2026-04-30); Screenshot-Assets lokal bereit, ASC-Upload manuell ausstehend
- Live Activity / Dynamic Island auf echter Hardware fuer Lock Screen, `minimal`, deaktivierte / nicht verfuegbare Live Activities und No-Dynamic-Island-Geraete vervollstaendigen (Pending-/Restart-Pfad gruen seit 2026-04-30)
- grossen echten Device-Smoke-Test fuer Overview-/Explore-Karte dokumentieren

P1 — Vorhandene Produktflaechen belastbar machen
- Chart-Share auf Apple-Hardware pruefen
- app-weite Landscape-Verifikation auf Apple-Hardware nachziehen
- Homescreen-Widget gesondert auf echter Hardware pruefen
- Simulator-/Host-Testlage fuer `LH2GPXWrapperTests` stabilisieren
- Track-Editor-/Export-Grenze weiter dokumentieren oder produktseitig spaeter anpassen

P2 — Nachgelagerte Optimierung
- Design-System (`LH2GPXTheme`) vollständig auf alle Produktionscreens ausgerollt (Start / Overview / Days / Day Detail / Insights / Export / Live Tracking / Live Tracks Library); Widget/Dynamic-Island nur bei sicherem Token-Pfad
- Apple-Review-/Privacy-Einordnung fuer den optionalen Server-Upload weiter sauber beobachten
- veraltete Notion-/Wrapper-/Split-Repo-Doku weiter abbauen
- echtes Road-/Path-Matching nur als spaeteren separaten Produktscope betrachten

### Final UI/Localization Truth Sync (2026-05-01)

Implementiert und verifiziert:
- 9 fehlende deutsche Übersetzungen in `AppLanguageSupport.swift` ergänzt (Invalid URL, Widget & Live Activity, Live Activity, Reachable/Unreachable, Test Connection, Testing…, Automatic Widget Update, Last tour + weekly status)
- `widgetAutoUpdate` und `maximumRecordingGapSeconds` in `AppPreferencesTests` abgedeckt
- 2 neue Testgruppen in `AppLanguageSupportTests` für Truth-Sync-Strings
- lokaler Nachweis: `swift test` **832 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- App-Store-Screenshots zeigen noch das alte Options-Layout — Aktualisierung auf neue Designs ausstehend
- Apple-Hardware-Verifikation für alle Redesign-Screens weiterhin ausstehend

### Options + Widget/Live Settings Redesign Truth Update (2026-05-01)

Implementiert und lokal verifiziert:
- `AppOptionsView` vollständig auf NavigationLink-Grid mit 8 modular strukturierten Section-Rows umgestellt
- `RecordingPreset`-Enum mit deterministischem Computed-Property auf `AppPreferences` (kein neuer UserDefaults-Key)
- `LHOptionsComponents.swift`: `LHOptionsSectionRow`, `LHLiveRecordingPresetSelector`, `LHUploadSettingsCard` (Token nur als `SecureField`), `LHDynamicIslandPreviewCard`, `LHWidgetPreviewCard`
- `OptionsPresentation.swift`: statische Darstellungs-Helpers für Upload-Status
- 36 neue DE/EN-Strings in `AppLanguageSupport.swift`
- lokaler Nachweis: `swift test` **830 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- kein Apple-Hardware-Claim für Options-Redesign
- Dynamic Island / Widget / Live Activity weiterhin nur auf echter Hardware vollständig verifizierbar

### Live Tracking + Library Redesign Truth Update (2026-05-01)

Implementiert und lokal verifiziert:
- `AppLiveTrackingView` ist sichtbar auf LH2GPX-Dark-Layout umgestellt: `ScrollView`+`LHPageScaffold`+Sticky-`LHLiveBottomBar`, Mint-Polyline/-Standortpunkt, Status-Chips mit Accessibility-Identifiern, Recording-Card ohne eingebetteten Button, Upload-Quick-Actions in Upload-Sektion
- `AppRecordedTracksLibraryView` ist sichtbar neu strukturiert: `ScrollView`+`LHPageScaffold`, Info-Card, `LHLiveTrackRow`-Zeilen, Titel „Live Tracks"
- `LHLiveBottomBar` und `LHLiveTrackRow` als neue Komponenten in `LHLiveComponents.swift`
- `LiveTrackingPresentation` um testbare Helpers `gpsStatusLabel` und `uploadSectionVisible` erweitert
- Alle bestehenden Verdrahtungen vollständig erhalten
- lokaler Nachweis: `swift test` 793 Tests, 0 Failures

Nicht als abgeschlossen markieren:
- kein Apple-Hardware-Claim für Live-Tracking-Redesign
- Dynamic Island / Lock Screen / Live Activity nur auf echter Hardware verifizierbar
- `AppRecordedTrackEditorView` bewusst unverändert gelassen

### Export Checkout Redesign Truth Update (2026-05-01)

Implementiert und lokal verifiziert:
- `AppExportView` ist vollstaendig von `List`-basiertem Layout auf `ScrollView`+`LHPageScaffold`+Sticky-`LHExportBottomBar` umgestellt
- `LHExportStepIndicator`: 4-Schritt-Progress (Auswahl / Format / Inhalt / Fertig) mit completed/active/pending Zustaenden
- `LHExportBottomBar`: Sticky `.safeAreaInset`-Bar mit Item-Count + Format-Label und primaerem Export-Button; optionaler Disabled-Reason-Caption
- `LHExportFilterDisclosure`: kollabierbare Advanced-Filters-Card mit oranger Active-State-Border und Chip-Badge
- Auswahl-Summary-Card mit 4-KPI-Grid (Days / Routes / Period / Places); „Auswahl bearbeiten" scrollt per `ScrollViewReader` zur Tages-Card
- Format-Pills (GPX / KMZ / KML / GeoJSON / CSV) und Mode-Pills (Tracks / Waypoints / Both) mit aktivem Fill-Highlight
- `ExportPresentation.bottomBarSummary` und `ExportPresentation.disabledReason` neu; bestehende `ExportPresentation.readiness` unveraendert
- alle bestehenden Verdrahtungen erhalten: `fileExporter`, per-Route-Auswahl, Insights-Drilldown, alle Filter, `ExportSelectionState`, Builder, Kontrakt
- lokaler Nachweis: `swift test` 773 Tests, 0 Failures

Nicht als abgeschlossen markieren:
- kein neuer Apple-Hardware-Claim fuer den Export-Checkout-Umbau
- keine neue Exportfaehigkeit, kein neues Format, keine Kontrakt-Aenderung
- display-only Track-Editor-Mutations fliessen weiterhin nicht in den Export-Truth ein

### Days + Day Detail Redesign Truth Update (2026-04-30)

Implementiert und lokal verifiziert:
- `Days` ist sichtbar auf das neue LH2GPX-Dark-Layout umgestellt: grosser Titel, kompakte Zeitraum-/Suche-Context-Zeile, reduzierte Filterchips, dunkle Card-Rows und optionaler kollabierbarer Map-Header
- die Days-Map nutzt weiter den bestehenden projizierten / gefilterten Tageskontext; bei verborgenem Header bleibt die `LHCollapsibleMapHeader`-Performance-Invariante erhalten und die Map wird nicht instanziiert
- Day Rows trennen Favorit und Exportstatus jetzt sichtbar voneinander; Orte, Routen, Aktivitaeten und Distanz bleiben getrennt praesentiert
- Day Detail ist sichtbar map-first umgebaut: `AppDayMapView` direkt oben, danach KPI-Karten fuer Distanz / Routen / Aktivitaeten / Orte sowie Segmentumschaltung fuer `Overview`, `Timeline`, `Routes`, `Places`
- bestehende Business-Verdrahtung bleibt erhalten: `daysNavigationPath`, `selectedDayID`, `daySearchText`, `dayListFilter`, `DayListPresentation.filteredSummaries`, `DaySummaryRowPresentationBuilder`, `DayDetailPresentation`, `DayMapDataExtractor`, `ExportSelectionState.routeSelections`, `AppImportedPathMutationStore`, `ImportedPathDeletion`, Insights-Drilldown und SplitView-/Tab-Reselection-Verhalten
- lokaler Nachweis: `swift test` 741 Tests, 0 Failures

Nicht als abgeschlossen markieren:
- kein neuer Apple-Hardware-Claim fuer den sichtbaren Days-/Day-Detail-Umbau
- keine neue Exportfaehigkeit, kein neues Road-Snapping, kein neues Map-Matching
- keine Aenderung daran, dass display-only entfernte importierte Routen nicht in den Export-Truth einfliessen

### Start + Overview Redesign Truth Update (2026-04-30)

Implementiert und lokal verifiziert:
- import-first Startseite ist sichtbar auf das neue LH2GPX-Redesign umgestellt: schwarzer Hintergrund, grosser `LH2GPX`-Titel, kompakter Subtitle, grosser blauer Import-Button, dunkle Action Rows fuer Hilfe und Demo
- `RecentFilesView` ist jetzt die produktive `Zuletzt verwendet`-Card auf der Startseite; Dateiname, Datum und optionale Dateigroesse sind sichtbar, Reopen-/Remove-/Clear-Logik bleibt erhalten
- Overview ist sichtbar neu strukturiert: Importstatus-Card, Zeitraum-Card, KPI-Grid, Highlights-Card, `Weiterarbeiten`-Card
- `LHCollapsibleMapHeader` ist jetzt auf der ersten echten Produktseite (`Overview`) pilotiert; `LHPageScaffold` und `LHContextBar` sind dort ebenfalls produktiv im Einsatz
- `AppOverviewTracksMapView` bleibt die bestehende Overview-Karte; bei verborgenem Header wird die Map-Closure nicht ausgewertet, die bestehende Overlay-/Simplification-/Cancellation-Logik bleibt unveraendert
- lokaler Nachweis: `swift test` 739 Tests, 0 Failures

Prompt-2-Doku-Korrektur:
- der bisher noch offene NEXT_STEPS-/ROADMAP-Punkt zum ersten echten `LHCollapsibleMapHeader`-Pilot war nach Prompt 2 weiterhin korrekt offen; mit diesem Slice ist er repo-wahr erledigt und als offener Punkt entfernt bzw. auf weitere Rollout-Arbeit umformuliert

Nicht als abgeschlossen markieren:
- kein neuer Apple-Hardware-Claim fuer Home-/Overview-Layout, Heatmap, Range-Chips oder die neue Startseiten-IA
- keine Aussage zu App-Store-Screenshot-Aktualitaet nach dem sichtbaren UI-Umbau

### Dynamic Island / Live Activity Truth Update (2026-04-30)

Implementiert und lokal verifiziert:
- konfigurierbarer Dynamic-Island-Primärwert (`Distanz`, `Dauer`, `Punkte`, `Upload-Status`) mit Persistenz
- konsistente Wertedarstellung fuer Lock Screen, expanded, compact trailing und minimal (minimal bewusst icon-basiert)
- sichtbare Fallback-Logik in den Optionen fuer nicht verfuegbare / deaktivierte Live Activities
- Upload-/Pause-Zustand wird jetzt aus dem Live-Modell tatsaechlich in die Live Activity propagiert
- Overview-Heatmap-Einstieg als Capsule-Chip an die bestehende Chip-Sprache angepasst

Auf echter Hardware bestaetigt:
- `iPhone 15 Pro Max` (`iOS 26.4`, Debug-Build via `xcodebuild test`): Recording-Start, Dynamic Island `compact` fuer Primärwert `Distanz`, Dynamic Island `expanded` fuer Primärwert `Distanz`, Stop-/Dismiss-Verhalten nach Aufnahmeende

Nicht als abgeschlossen markieren:
- echte Apple-Hardware-Verifikation fuer Live Activity / Dynamic Island bleibt teilweise offen: Lock Screen, `minimal`, deaktivierte / nicht verfuegbare Live Activities und No-Dynamic-Island-Geraete sind noch nicht repo-wahr bestaetigt; Pending-/Restart-Pfad gruen seit 2026-04-30
- Wrapper-Simulator-Testlauf war auf diesem Host nicht belastbar abschliessbar (`NSMachErrorDomain Code=-308`)

### Live-Session-Restore Truth Update (2026-04-30)

Implementiert und lokal verifiziert:
- interrupted-session Persistenz wird erst nach echtem Recording-Start geschrieben, nicht mehr schon bei Initialisierung oder vor erfolgreichem Authorization-/Startpfad
- Restore-Banner erscheint nur noch bei gueltiger Kombination aus `sessionID` (UUID) und `sessionStartedAt` (gueltiger Timestamp)
- denied/restricted sowie abgelehntes `Always`-Upgrade raeumen verwaisten Restore-State jetzt defensiv auf
- `dismissInterruptedSession()` und sauberer Stop entfernen Persistenz und In-Memory-State konsistent
- Regressionstests decken Initialisierung ohne Recording, Persistenz beim Start, Loeschung bei Stop/Ignore sowie kaputte oder partielle `UserDefaults`-Werte ab

### Release / TestFlight Truth Update (2026-04-30)

Implementiert und lokal verifiziert:
- `CURRENT_PROJECT_VERSION = 45` im Wrapper-Projekt, damit ein neuer lokaler Release-Kandidat oberhalb des bereits dokumentierten TestFlight-Builds `1.0 (44)` liegt
- Release-Archive fuer `LH2GPXWrapper` sind lokal wieder erzeugbar
- Release-Signing-Konflikt im Repo bereinigt: keine explizite Release-`CODE_SIGN_IDENTITY`, `CODE_SIGN_STYLE = Automatic` bleibt aktiv

Nicht als abgeschlossen markieren:
- lokaler Export/Upload nach App Store Connect bleibt fuer diesen Host offen: aktueller Host hat keine verfuegbare Distribution-Identitaet und keine konfigurierte ASC-CLI-Authentifizierung; App Review selbst ist aber nicht mehr am Upload-Schritt blockiert
- App Review bleibt bis zur vollstaendigeren Hardware-Verifikation von Live Activity / Dynamic Island offen

## Aktueller Stand (2026-04-29)

### Overview-Map Freeze/Crash-Fix – Hard Overlay Limit (2026-04-29)

Abgeschlossen (647 Tests, 0 Failures):
- **Problem**: `AppOverviewTracksMapView` frierte ein oder crashte bei „Gesamtzeitraum" + großen Datenmengn. Root Cause: `selectCandidates` lieferte alle Kandidaten unsortiert ohne Overlay-Limit; MapKit erhielt tausende `MapPolyline`-Objekte.
- **Fix**: Hard `overlayLimit` in `OverviewMapRenderProfile` eingeführt. Tier-basierte Limits: sehr groß (>500 Routen/>150k Punkte) → 150, groß → 200, mittel-groß → 250, mittel → 300, klein → kein Cap.
- `selectCandidates` schneidet nach Score-Sortierung auf `overlayLimit` ab.
- `isOptimized` ist `true` wenn Cap greift — View zeigt Badge „Karte vereinfacht – Export vollständig".
- Export-Daten unverändert. Rohdatenmodell und Export-Pipeline kein Eingriff.
- 5 neue Tests (Fix): `overlayLimit`-Werte per Tier, synthetisches 600-Routen-Dataset gecapped, kleines Dataset ungecapped, Start-/Endpunkt-Erhaltung, Export-Daten-Unveränderlichkeit.
- **Performance-Audit (2026-04-29)**: `overlayLimit × maxPolylinePoints` ergibt implizites hartes globales Coordinate-Budget (max 9.600–48.000 je Tier). Kein separates globales Budget nötig. 3 neue Invarianten-Tests: Total-Coordinate-Cap, Einzelrouten-Decimation, Badge-Logik bei Simplification-ohne-Cap. 650 Tests, 0 Failures.

---

## Aktueller Stand (2026-04-12)

### Multi-Source Import Foundation — GPX + TCX (2026-04-12)

Abgeschlossen (530 Tests, 0 Failures):
- GPX 1.1 Import: `GPXImportParser` (trk/trkseg/trkpt + wpt → AppExport, local-date grouping)
- TCX 2.0 Import: `TCXImportParser` (TrainingCenterDatabase/Trackpoint/Position → AppExport)
- `AppContentLoader`: GPX/TCX-Routing in `decodeData()` und ZIP-Scan
- `fileImporter` akzeptiert `.gpx` und `.tcx` zusätzlich zu `.json` und `.zip`
- DE/EN-Strings für GPX/TCX-Import ergänzt
- 3 neue Contract-Fixtures (`sample_import.gpx`, `.tcx`, `_empty.gpx`)
- 19 neue Tests in `MultiSourceImportTests`
- FIT-Format: bewusst nicht implementiert (kein wartbares Swift-Framework ohne externe Dependency)
- GeoJSON-Import: bewusst als Follow-up aufgeschoben (Komplexität; Export bleibt unberührt)
- Prompt-1-Schutz: alle 7 geschützten Dateien unberührt

### UI Polish – Overview / Insights / Heatmap / Landscape (2026-04-12)

Abgeschlossen (511 Tests, 0 Failures):
- Overview-Pane umgeordnet: Time-Range-Control an erster Position
- Favorites-Only-Toggle (Capsule-Chip) im Overview; filtert Statistiken und Map reaktiv
- `AppOverviewTracksMapView`: async Polyline-Uebersichtskarte (iOS 17+), Task.detached, `.task(id:)`, keine versteckte Route-Kappung fuer den aktiven Zeitraum; Performance ueber Vereinfachung/Decimation
- Heatmap Mode/Radius-Picker als Capsule-Chips (passend zu `AppDayFilterChipsView`); Controls scrollbar in Landscape
- Stray `Text("No data")` aus `AppDayRow` entfernt (visueller Stray-Bullet behoben)
- `InsightsTopDaysPresentation.topDays(limit:)` von 5 auf 20 erhöht
- `HistoryDateRangeFilter.isoFormatter`: UTC → `.autoupdatingCurrent` (Timezone-Off-by-One-Fix)
- `AppInsightsContentView.refreshDerivedModel()`: Metric-State atomar ohne Animation angewendet (State-Shift-Fix)
- ~30 neue DE-Strings (`AppGermanTranslations`): Favorites, Range-Map, Heatmap, Insights, Accessibility
- 14 neue Unit-Tests (`OverviewFavoritesAndInsightsTests`): Favorites-Filter, Timezone, Top-Days, Lokalisierung

### P1 Critical Security + Stability Fixes (2026-04-12)

Abgeschlossen (481 Tests, 0 Failures):
- `KeychainHelper.encodingFailed`: force-unwrap durch throwing guard ersetzt
- `AppExportQueries.effectiveDistance`: Logik explizit und kommentiert
- `GeoJSONBuilder`: wirft `GeoJSONBuildError.serializationFailed` statt silent fallback
- `MockURLProtocol` macOS-Fix: `httpBodyStream` wird gelesen wenn `httpBody` nil ist

---

## Aktueller Stand (2026-04-01)

### Repo-Truth-Zusammenfassung
Die letzte real belegte Apple-/Device-Verifikation bleibt der dokumentierte Apple-Stand vom 2026-03-17 beziehungsweise 2026-03-30; in diesem Audit wurde kein neuer Apple-Host-Lauf vorgetaeuscht.
Der Audit-Block vom 2026-04-01 ist in dieser Revision eingearbeitet: sichtbare Zeitraumfilter-Verdrahtung, Recent Files, Auto-Restore, Days-Filterchips, Favoriten, per-route Auswahl, CSV-Export-Verdrahtung, Heatmap-Teststabilisierung, spaetere Live-/Projektions-Entschaerfung und der aktuelle Teststatus sind jetzt dokumentarisch an den aktuellen Code angeglichen.
Diese ROADMAP trennt ab hier explizit zwischen `fertig`, `implementiert aber noch nicht voll verifiziert` und `noch nicht umgesetzt`.
Historische Phasen weiter unten bleiben als Zeitstrahl stehen; wenn spaetere Commits fruehere Zwischenstaende ueberholt haben, gilt der aktuelle Kopfblock als massgeblicher Repo-Truth.
Der frische Host-Nachweis dieses Audits ist Linux-only: `swift test` lief am 2026-04-01 mit `Executed 363 tests, with 0 failures (0 unexpected)`, `git diff --check` ist sauber, und `xcodebuild` ist auf diesem Host nicht verfuegbar.
Der Live-/Upload-/Insights-/Days-Batch vom 2026-03-30 ist im Code umgesetzt und in dieser ROADMAP als repo-wahrer Produktstand eingearbeitet; fuer diesen Batch liegen auf Linux gezielte Teilnachweise vor, aber kein neuer Apple-UI-Nachweis.
Der spaetere UI-Polish-/Heatmap-Detail-Batch vom 2026-03-30 staerkt vor allem die Heatmap-Detailsichtbarkeit sowie kleine visuelle Kanten in `Live`, `Insights` und `Days`; auf diesem Linux-Host liegen dazu nur nicht-Apple-Nachweise vor.

### Repo-wahr abgeschlossen

- Import von LH2GPX-`app_export.json`/`.zip` sowie Google-Timeline-`location-history.json`/`.zip`
- Overview, Days, Day Detail, Insights und Export als produktnahe App-Shell
- Suche in compact und regular `Days`
- `Days` standardmaessig absteigend (`neu -> alt`) inklusive neuer newest-first Session-Projektion sowie contentful-first Initialauswahl/Fallbacks
- Re-Select-Verhalten fuer `Days` auf iPhone: erneutes Tab-Tippen fuehrt zum aktuellen Tag
- stabile Sheet-Praesentation fuer Optionen, Export, Heatmap und `Saved Live Tracks`
- eigene `Saved Live Tracks`-Library plus Editor fuer gespeicherte lokale Tracks
- aktuelle Position auf der Karte anzeigen
- Live-Recording mit lokalen Einstellungen fuer Accuracy-Filter und Recording-Detail
- Live-Tracking-Oberflaeche mit klarer Recording-/Upload-/Library-Hierarchie, erweiterten Stat-Karten und Quick Actions fuer Zentrieren, Pause/Resume der Uploads und manuellen Queue-Flush
- optionaler Server-Upload mit Queue-/Failure-/Last-Success-Status, Pause/Resume und manuellem Flush
- segmentierte Insights-Oberflaechen (`Overview`, `Patterns`, `Breakdowns`) mit KPI-Karten, Highlight-Karten, `Top Days` und Monatstrends
- Monatstrends respektieren den aktiven Zeitraum ohne 24-Monats-Cap; Tabellen-/Listenanzeige priorisiert neueste Monate
- GPX-, KML-, GeoJSON- und **CSV**-Export fuer importierte History und gespeicherte Live-Tracks
- Exportmodi fuer `Tracks`, `Waypoints` und `Both`
- Waypoint-Export aus importierten Visits sowie Activity-Start/-End-Koordinaten
- sichtbare Export-Vorschaukarte direkt auf der Export-Seite
- lokale Export-Filter fuer importierte History nach Datumsfenster, maximaler Genauigkeit, erforderlichem Inhalt, Aktivitaetstyp sowie Bounding Box oder Polygon
- **per-route Auswahl** innerhalb eines Tages (`ExportSelectionState.routeSelections`; implizit alle Routen wenn keine explizite Auswahl), sichtbar im Day Detail mit Reset auf implizit alle exportierbaren Routen
- **globaler Zeitraumfilter** (`HistoryDateRangeFilter`): Presets + Custom + Reset; sichtbar in `Overview`, `Insights` und `Export` verdrahtet
- **Recent Files** (`RecentFilesStore`): bis zu 10 Eintraege, Stale-Pruefung, Reopen/Remove/Clear im import-first Startzustand
- **Auto-Restore-Option** (`AppPreferences.autoRestoreLastImport`, Default `false`): sichtbarer Toggle plus opt-in Restore beim App-Start
- **Tage-Favoriten** (`DayFavoritesStore`): Stern-Marking, Persistenz, sichtbarer Toggle in Day-Liste und Day Detail, `DayListFilterChip.favorites`
- **Days-Filterchips** (`DayListFilter`): Favorites / Has Visits / Has Routes / Has Distance / Exportable; sichtbar in `Days` und mit Suche kombinierbar
- **Insights-Drilldown** (`InsightsDrilldown`): `filterDaysToDate`, `filterDaysToDateRange`, `prefillExportForDate`, `prefillExportForDateRange`; `activeDrilldownFilter` in `AppSessionState`
- **Chart-Share-Payload** (`ChartShareHelper`): UI-freier Payload-Builder; Dateiname-Format; sichtbare Share-Aktionen jetzt in den wichtigsten Insights-Sektionen verdrahtet; echte ImageRenderer-/Share-Sheet-Verifikation bleibt Apple-Host-Arbeit
- zentrale filter-key-basierte Session-Projektionsschicht fuer `Overview`, `Days`, `Insights`, `Export` und Day-Detail-Map-Daten; wiederholte Export-/Day-Projektionen laufen nicht mehr breit im UI-Renderpfad
- Live-Stabilitaet: geringerer Timer-bedingter Voll-Refresh, sauberere Upload-Cancellation/Serialisierung und entschärfte Queue-Mutationen fuer den optionalen Server-Upload
- Heatmap-/Map-Restoptimierung: vorbereitete Route-Tracks, lazy Density-LOD-Aufbau, gecachte `DayMapData` und stabile Renderdaten fuer Day-/Export-Maps reduzieren First-Open- und Re-Render-Arbeit ohne Semantikaenderung
- Sprachwahl `English` / `Deutsch` in den Optionen; breite DE-Abdeckung fuer Shell-, Optionen-, Live-Recording-, Import-Entry-, Export-, Days-/Day-Detail- und Analytics/Insights/Overview-Oberflaechen inkl. Format-Strings, Monatsnamen, rangeDescription-Singular/Plural, Custom-Date-Range-Sheet, Overlap-Map, Recent Files, Auto-Restore, Days-Filterchips, Route-Export-Aktionen und InsightsChartSupport-Hints (Stand 2026-04-01: `swift test` -> `Executed 363 tests, with 0 failures (0 unexpected)`)

### Implementiert, aber noch nicht voll verifiziert

- **Heatmap**
  `AppHeatmapView` und das Heatmap-Sheet sind implementiert und jetzt dokumentiert.
  Heatmap UX Batch 1 hat die Darstellung auf mittleren/grossen Zoomstufen beruhigt und kleine lokale Controls fuer Deckkraft, Radius und `Auf Daten zoomen` hinzugefuegt.
  Heatmap Visual & Performance Batch 2 hat danach auf geglaettete aggregierte Polygon-Zellen, viewport-basierte Zellselektion, per-LOD begrenzte sichtbare Elemente und einen wiederverwendbaren Viewport-Cache umgestellt, um den sichtbaren Kreis-/Stempel-Look zu reduzieren und Pan/Zoom ruhiger zu machen.
  Heatmap Color / Contrast / Opacity Batch 3 hat danach die Farbpalette von harten Stufen auf weich interpolierte Gradient-Stops umgestellt, mittlere/hohe Dichte per Intensitaets-Mapping sichtbar angehoben und die 100-%-Deckkraft ueber eine staerkere High-End-Kennlinie auf einen wirklich volleren Sichtbarkeitsmodus gemappt.
  Der UI-Polish-/Heatmap-Detail-Batch hat danach die Detailsichtbarkeit weiter angehoben: niedrigere Detailschwellen, fruehere Farbe bei duennen Daten, mehr sichtbare Low-/Mid-Density im Detailzoom und etwas klarere Legenden-/Opacity-Abstimmung.
  Der Phase-3-Restbatch vom 2026-04-01 baut Route-Grids und vorbereitete Route-Tracks jetzt einmalig vor, verschiebt Dichte-LOD-Aufbau auf echten Bedarf im Density-Modus und reduziert wiederholte Export-Traversierung bei Viewport-Wechseln auf groesseren Kartenflaechen.
  Kleine dedizierte Heatmap-Regressionstests fuer Aggregation, viewport-begrenzte Zellselektion und das neue Intensitaets-/Opacity-/Palette-Mapping sind jetzt vorhanden.
  Offen bleibt die visuelle/performance-seitige Apple-Verifikation dieses neuen Renderers samt Batch-3-Farbwirkung auf echter Hardware.
- **`Live`-Tab**
  Der dedizierte 5. Tab fuer compact iOS 17+ ist implementiert und jetzt dokumentiert.
  Der Batch vom 2026-03-30 hat den Tab inhaltlich deutlich ausgebaut (moderne Karten-/Card-Hierarchie, Quick Actions, mehr Live-Metriken, Upload-Zustaende).
  Offen bleiben echte iPhone-UX-/Device-Nachweise fuer diesen Pfad.
- **Background-Live-Tracking**
  Codepfad, Permissions-Upgrade und Wrapper-Deklaration sind vorhanden.
  Offen bleiben reale Apple-Hardware-Verifikation, Suspend/Resume-Kantenfaelle und ein sauber protokollierter Device-Durchlauf.
- **Auto-Restore / Recent Files**
  Recent Files und der opt-in Restore-Pfad sind jetzt in der App-Shell sichtbar verdrahtet.
  Offen bleibt eine frische Device-Verifikation fuer Reopen, Clear History und den Restore-beim-Start-Pfad.
- **Server-Upload**
  HTTPS-Upload, Bearer-Token, Retry-on-next-sample, Upload-Batching, Queue-/Failure-/Last-Success-Status, Pause/Resume und manueller Flush sind implementiert.
  Hart kodierter Testendpunkt (`sslip.io`) entfernt: `defaultTestEndpointURLString` ist jetzt `""`.
  Offen bleiben End-to-End-Device-Verifikation sowie finale Review-/Privacy-Einordnung auf Apple-Seite.
- **Insights / Days UX**
  Die Insights-Seite ist deutlich ausgebaut und `Days` ist jetzt repo-wahr `neu -> alt` sortiert.
  Insights-Drilldown nach `Days`/`Export` und sichtbare Share-Aktionen fuer zentrale Insight-Sektionen sind jetzt UI-seitig verdrahtet.
  Day-Detail nutzt jetzt gecachte `DayMapData`, und Day-/Export-Karten halten stabile Renderdaten fuer Marker, Polylines und Regionen statt wiederholter Koordinaten-Neuaufbereitung pro Render.
  Offen bleiben frische Apple-UI-Nachweise fuer die neue Informationsarchitektur, Chart-Lesbarkeit, den jetzt sichtbaren Zeitraumfilter in `Overview`/`Insights`/`Export`, die sichtbaren Days-Filterchips/Favoriten/per-route Actions, den neuen Insights-Drilldown sowie den echten Chart-Share-Flow auf Apple-Hardware.
- **Linux-/Apple-Teststatus**
  Historische Apple-Nachweise vom 2026-03-30 bleiben dokumentiert, gelten aber nicht als frischer Gegenlauf fuer diesen Audit.
  Der aktuelle Linux-Mindestnachweis dieses Audits ist `swift test` mit `Executed 363 tests, with 0 failures (0 unexpected)`; `git diff --check` ist sauber.
  Die 3 bekannten Problemfaelle sind als Test-Drift klassifiziert und behoben:
  `testAcceptedSamplesUploadToConfiguredServer` und `testFailedUploadRetriesWhenAnotherAcceptedSampleArrives` scheiterten an minimumBatchSize=5 (nicht Plattform), Tests auf minimumBatchSize=1 gesetzt;
  `testBackgroundPreferenceActivatesClientWhenAlwaysAuthorized` prueft jetzt korrektes Verhalten (Client-Config beim Recording-Start, nicht bei Preference-Aenderung).
  Batch 2 hat die 2 verbliebenen Test-vs-Code-Widersprueche repo-wahr aufgeloest:
  `AppPreferencesTests.testStoredValuesAreLoaded` folgt jetzt dem Keychain-first-Produktverhalten,
  `DayDetailPresentationTests.testTimeRangeFormattingAvoidsRawISOStrings` folgt jetzt der im Produktcode konsistent genutzten Gedankenstrich-Formatierung.
  Ein frischer Apple-CLI-Rerun fuer den aktuellen Stand bleibt offen, weil `xcodebuild` auf diesem Linux-Host nicht vorhanden ist.

### Noch nicht umgesetzt

- echtes Road-/Path-Matching; aktuell gibt es nur Pfadvereinfachung im Day-Detail
- KMZ-Export — ✅ abgeschlossen (2026-04-12); KMZBuilder (ZIPFoundation), KMZDocument (BinaryExportDocument), ExportFormat.kmz, 6 neue Tests
- Live Activity Widget UI — ✅ Widget-Target und Swift-Dateien sind vorhanden (`wrapper/LH2GPXWidget/`); offene Arbeit ist reale Apple-Hardware-Verifikation, nicht Target-Anlage
- weitere Insight-Arbeit: Apple-Host-Verifikation fuer den jetzt verdrahteten Drilldown-/Chart-Share-Flow sowie optional spaeter map-linked Cross-Filtering
- Auto-Resume einer laufenden Live-Aufzeichnung nach App-Neustart
- breitere Lokalisierungsabdeckung und eine strengere Lokalisierungspruefung
- Cloud-/Sync- oder Account-Features

### Reihenfolge der naechsten offenen Bloecke

1. kurzen echten iPhone-Heatmap-Check fuer den neuen Aggregations-/Polygon-Renderer inklusive Batch-3-Farb-/Kontrast-Mapping und des spaeteren Detail-Visibility-Polish fahren und visuelle/performance-seitige Befunde dokumentieren
2. dedizierten iPhone-UI-Check fuer den deutlich umgebauten `Live`-Tab, die Upload-Zustaende und die neue `Days`-Default-Sortierung fahren und dokumentieren
3. Background-Recording auf echtem iPhone verifizieren und im Runbook belegen
4. Auto-Restore / Recent Files auf echtem iPhone erneut verifizieren und dokumentieren
5. `Days` / Day Detail / CSV-Export auf echter Apple-Hardware gegenpruefen und dokumentieren
6. optionalen Server-Upload end-to-end auf Device pruefen; Apple-Review-/Privacy-Einordnung fuer den Upload-Pfad weiter klaeren
7. erst danach weitere neue Feature-Arbeit (weiterer Insights-Ausbau, KMZ, `Days`-seitige Zeitraumsauswahl)

Apple-/ASC-/TestFlight-/Release-Themen sind nicht geparkt, sondern bleiben bis zu Apple-Feedback und vollstaendigerer Hardware-Verifikation aktiv. iPad bleibt nachrangig. Phase 21 bleibt fuer spaetere Folgearbeit reserviert.

### Phase 19.51 – Apple Stabilization Batch 1

**Datum:** 2026-03-30
**Ziel:** Audit-belegte P0/P1-Probleme beheben, Apple-Build-/Testlage auf belastbaren Stand bringen, Doku repo-wahr synchronisieren.

- [x] macOS-Compile-Fehler behoben: `.textInputAutocapitalization(.never)` in `#if os(iOS)` eingeschlossen
- [x] macOS-Compile-Fehler behoben: `if #available(iOS 17.0, macOS 14.0, *)` fuer `AppLiveTrackingView` und `AppLiveLocationSection`
- [x] Demo- und App-Shell-Compile-Fehler behoben: `loadImportedFile(at:)` async gemacht (fehlte nach `DemoDataLoader`-Aenderung)
- [x] Wrapper-SPM-Pfad korrigiert: `../../../Code/...` auf `../LocationHistory2GPX-iOS`
- [x] Upload-Tests als Test-Drift klassifiziert und korrigiert (minimumBatchSize=1 im Test-Setup)
- [x] Background-Preference-Test als Test-Drift klassifiziert und korrigiert
- [x] Privacy-Text in TestFlight-Runbook sachlich korrekt formuliert
- [x] README-Widerspruch (offline-only vs. optionaler Upload) behoben
- [x] `swift test` auf macOS: 222 Tests, 2 verbleibende rote Tests ausserhalb dieses Batch-Scope, alle 3 audit-relevanten Problemfaelle gruen
- [x] `xcodebuild test -scheme LocationHistoryConsumer-Package -destination 'platform=macOS'`: 222 Tests, dieselben 2 verbleibenden roten Tests
- [x] `xcodebuild build -scheme LH2GPXWrapper -destination generic/platform=iOS`: BUILD SUCCEEDED
- [x] `xcodebuild test -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -only-testing:LH2GPXWrapperTests`: TEST SUCCEEDED

**Nicht-Ziele:** Keine neue Produktfunktion, keine neue Apple-Device-Verifikation.

### Phase 19.50 – Audit Fix + Roadmap Granularization

**Datum:** 2026-03-30
**Ziel:** Audit vom 2026-03-30 in repo-wahre Doku, Roadmap und Verifikationsaussagen ueberfuehren, ohne neue Produktfeatures zu bauen.

- [x] Audit-Datei gesichert und gegen den aktuellen Repo-Stand abgeglichen
- [x] README, ROADMAP, NEXT_STEPS, Feature-Inventar und Runbooks auf Heatmap, `Live`-Tab, Upload-Batching und Wrapper-Auto-Restore synchronisiert
- [x] Default-Endpunkt in der Doku auf `https://178-104-51-78.sslip.io/live-location` korrigiert
- [x] Test-/Verifikationsstatus von historischem Xcode-Stand gegen den aktuellen Linux-Stand abgegrenzt
- [x] Core- und Wrapper-ROADMAP/NEXT_STEPS wieder inhaltlich synchronisiert

**Nicht-Ziele:** Keine neue Produktfunktion, keine neue Apple-Behauptung ohne Nachweis, keine kosmetischen Feature-Claims.

### Phase 19.41 – Exportmodi / Waypoints vs Tracks

**Datum:** 2026-03-20
**Ziel:** Export klar zwischen Route-, Waypoint- und Mischmodus unterscheiden, ohne bestehende GPX/KML-Flows zu zerbrechen.

- [x] neuer `ExportMode` fuer `Tracks`, `Waypoints` und `Both`
- [x] GPX-, KML- und GeoJSON-Builder respektieren jetzt den aktiven Modus
- [x] Waypoint-Export basiert auf importierten Visits sowie Activity-Start/-End-Koordinaten
- [x] Export-UI, Dateiname und Disabled-Reasons reagieren jetzt auf den aktiven Modus
- [x] Saved Live Tracks bleiben bewusst track-only und werden in Waypoint-only-Modi nicht faelschlich als exportierbar dargestellt
- Bewusst nicht in diesem Schritt: per-route Auswahl, Track-/Waypoint-Editierung importierter Daten

### Phase 19.40 – Weitere Exportformate

**Datum:** 2026-03-20
**Ziel:** Nach GPX/KML ein drittes sinnvolles Exportziel aktivieren, ohne einen unklaren Formatfriedhof aufzubauen.

- [x] `GeoJSON` als drittes aktives Exportformat freigeschaltet
- [x] `ExportDocument` / `UTType` und Export-UI kennen jetzt `.geojson`
- [x] GeoJSON exportiert Tracks als `LineString` und Waypoints als `Point`-Features
- [x] Tests decken das neue Format fuer route-only und mixed content ab
- Bewusst nicht in diesem Schritt: `CSV`, `KMZ`, serverseitige Zielsysteme

### Phase 19.39 – Export-Filter vervollstaendigen

**Datum:** 2026-03-20
**Ziel:** Die bereits vorhandenen Query-Unterbauten fuer Flaechenfilter sichtbar und produktiv nutzbar machen.

- [x] lokale Bounding-Box-UI fuer importierte History
- [x] lokale Polygon-UI per Koordinatenliste fuer importierte History
- [x] Upstream- und lokale Area-Filter werden konservativ kombiniert statt gegenseitig still zu ueberschreiben
- [x] Vorschau und Export reagieren jetzt auf Bounding-Box/Punkt-in-Polygon-Filter
- [x] Nutzerhinweise machen explizit, dass lokale Filter nur importierte History betreffen und Saved Live Tracks unberuehrt lassen
- Bewusst nicht in diesem Schritt: interaktives Polygonzeichnen auf der Karte

### Phase 19.38 – Export-UX-Politur

**Datum:** 2026-03-20
**Ziel:** Export-Flow fuer GPX sichtbarer machen, ohne neue Formate oder neue Exportlogik einzufuehren.

- [x] Export-Selektion zeigt jetzt einen eigenen Summary-Block mit Anzahl, route-faehigen Tagen und Distanzsumme
- [x] Dateinamenvorschau wird direkt aus der aktuellen Auswahl angezeigt
- [x] Day Rows markieren Tage ohne GPX-faehige Routen expliziter
- [x] Disabled-Reasons unterhalb des Export-Buttons erklaeren jetzt klar, warum kein Export moeglich ist
- [x] ausgewaehlte Day Rows erhalten zusaetzlich eine subtile visuelle Hervorhebung
- Bewusst nicht in diesem Schritt: KML/CSV, per-route Export, neue Share-Ziele

### Phase 19.37 – Visualisierung / Charts-Politur

**Datum:** 2026-03-20
**Ziel:** Vorhandene Insights-Visualisierungen lesbarer und erklaerender machen, ohne neue Analysemetriken zu erfinden.

- [x] Distance-, Activity- und Visit-Charts zeigen jetzt explizitere Achsen statt weitgehend versteckter Skalen
- [x] Distance-Chart erklaert die Tap-Navigation zu einzelnen Tagen direkt im UI
- [x] Activity- und Weekday-Charts ergaenzen kurze Erklaerhinweise fuer die gezeigte Metrik
- [x] Weekday-Chart zeigt zusaetzliche Werteannotationen ueber den Bars
- [x] Low-Data- und chart-unverfuegbar-Faelle bleiben weiter mit expliziten Empty States abgesichert
- Bewusst nicht in diesem Schritt: neue Statistiken, Zoom-/Density-Controls, Export von Charts

### Phase 19.36 – Track-Library / Track-Editor-Zugang

**Datum:** 2026-03-20
**Ziel:** Gespeicherte Live-Tracks ueber Overview, Day Detail, Library und Editor konsistenter benennen und klar als lokalen Nebenfluss markieren.

- [x] Overview-Karte fuehrt jetzt konsistent unter `Saved Live Tracks` statt mit wechselndem `Track Editor`-Wording
- [x] Library, Empty States und Sheet-Fallback nutzen jetzt dieselbe Benennung fuer gespeicherte Live-Tracks
- [x] Day-Detail-/Live-Recording-Bereich fuehrt gespeicherte Tracks jetzt klar als lokale Aufnahme-/Bearbeitungsfunktion
- [x] Track-Editor-Titel benennt den konkreten Bearbeitungszweck jetzt als `Edit Saved Track`
- [x] Trennung zwischen importierter History und lokal gespeicherten Tracks wird in den Begleittexten expliziter gemacht
- Bewusst nicht in diesem Schritt: neue Track-Funktionen, Merge in importierte History, Background-Resume

### Phase 19.35 – Day-Detail-Hierarchie

**Datum:** 2026-03-20
**Ziel:** Importierte Tagesdaten, Live-Recording und Track-bezogene Nebenfluesse im Day Detail klarer staffeln.

- [x] Quick-Stats direkt unter Header/Zeitraum gezogen
- [x] expliziter Abschnitt `Imported Day Data` vor Karte, Timeline und importierten Sections
- [x] `AppLiveLocationSection` unter die importierten Visits/Activities/Routes verschoben
- [x] separater Kontextblock `Local Recording` fuer foreground-only Aufnahme und gespeicherte Live-Tracks
- [x] keine neue Business-Logik, nur klare Trennung zwischen importierter History und lokalem Recording
- Bewusst nicht in diesem Schritt: neue Track-Funktionen, Background-Tracking, Import-Merge

### Phase 19.34 – Days List / Export-Koharenz

**Datum:** 2026-03-20
**Ziel:** Day-List-, Such- und Exportzustand visuell klarer zusammenfuehren, ohne die vorhandene Days-Navigation neu zu bauen.

- [x] Export-Selektion in Day Rows jetzt als deutlicheres `Export`-Badge statt nur als kleines Icon
- [x] exportierte Tage erhalten zusaetzlich eine subtile visuelle Hervorhebung in der Liste
- [x] compact `Days` zeigt bei aktiver Export-Selektion einen eigenen Export-Hinweis mit direktem Sprung in den Export-Tab
- [x] regular-width `Days` zeigt denselben Export-Kontext oberhalb der Liste
- [x] Such- und Leerzustaende bleiben erhalten, werden aber nicht mehr vom Exportzustand optisch verdraengt
- Bewusst nicht in diesem Schritt: neue Exportformate, per-route Auswahl, neue Filterlogik

### Phase 19.33 – Overview-Informationsarchitektur / Primaeraktionen

**Datum:** 2026-03-20
**Ziel:** Overview wieder staerker als Startpunkt fuer Status und Hauptnavigation ausrichten, ohne bestehende Inhalte zu verlieren.

- [x] `AppSessionStatusView` an den Anfang der Overview geholt
- [x] neue Sektion `Primary Actions` fuer `Open`, `Browse Days`, `Open Insights` und `Export GPX`
- [x] compact Overview kann jetzt direkt in die Kernbereiche springen statt nur Informationen zu zeigen
- [x] regular Overview behaelt denselben Primarfluss und oeffnet Export ueber das bestehende Sheet
- [x] Track-Library-/Track-Editor-Einstieg bleibt sichtbar, ist aber klar hinter Status, Primaeraktionen, Highlights und Statistik eingeordnet
- Bewusst nicht in diesem Schritt: neue Importquellen, neue Track-Features, iPad-spezifische Neustrukturierung

### Phase 19.32 – Insights Empty / No-Data Hardening

**Datum:** 2026-03-20
**Ziel:** Insights auch bei duennen oder unvollstaendigen Daten als klares Produktverhalten statt als halbleere Seite darstellen.

- [x] page-level Empty State fuer Imports ohne Day-Summaries
- [x] explizite section-level Empty States fuer fehlende Distanz-, Activity-, Visit-, Weekday- und Period-Daten
- [x] Daily Averages zeigen jetzt einen klaren Hinweis statt still zu verschwinden, wenn weniger als zwei Tage vorliegen
- [x] Charts zeigen einen erklaerenden Fallback fuer no-chart-/low-data-Faelle statt leerer Flaechen
- [x] `Limited Insight Data`-Hinweis fuer duenne, technisch gueltige Imports
- Bewusst nicht in diesem Schritt: neue Analysemetriken, Export/Share fuer Charts, Cross-Filtering

### Phase 19.31 – Navigation / Dead-End Hardening

**Datum:** 2026-03-19
**Ziel:** Day-Navigation und Auswahlverhalten fuer iPhone/regular width so haerten, dass no-content-Tage und implizite Dead Ends nicht wie normale Detailziele behandelt werden.

- [x] `DaySummary` fuehrt jetzt repo-wahr `hasContent`, abgeleitet aus Visits/Activities/Paths
- [x] `AppSessionContent` waehlt nach Import/Demo bevorzugt den ersten inhaltshaltigen Tag statt blind den ersten Kalendertag
- [x] `selectDayForDisplay(_:)` fuehrt UI-sichere Tagesauswahl ein und verwirft no-content-Ziele statt leere Detailnavigation zu erzwingen
- [x] compact `Days`-Navigation oeffnet nur noch Tage mit echtem Inhalt; no-content-Tage bleiben sichtbar, aber nicht tappbar
- [x] regular-width `Days`-Liste deaktiviert no-content-Tage als Detailziele und zeigt einen expliziten Rueckweg zur `Overview`
- [x] Export-Badge in gruppierter und ungruppierter Day-Liste jetzt konsistent
- [x] 2 neue Session-State-Tests und erweiterte Query-Assertions decken contentful-first Auswahl und no-content-Verhalten ab
- Bewusst nicht in diesem Schritt: Insights-No-Data-States, Day-Detail-Umbau, neue Exportformate oder Background-Tracking

### Phase 19.28 – Lokale Optionen / Produktsteuerung

**Datum:** 2026-03-19
**Ziel:** Eine echte Optionen-Seite fuer die iPhone-App einfuehren, mit wenigen glaubwuerdigen lokalen Einstellungen statt Fake-Toggles.

- [x] Neue `AppPreferences`-Domain auf Basis von `UserDefaults`
- [x] Option fuer Distanz-Einheit (`Kilometers` / `Miles`)
- [x] Option fuer den Start-Tab auf iPhone (`Overview`, `Days`, `Insights`, `Export`)
- [x] Option fuer den bevorzugten Kartenstil (`Standard`, `Satellite Hybrid`)
- [x] Option zum Ein-/Ausblenden technischer Importdetails
- [x] `AppOptionsView` als echte Optionen-Seite mit Bereichen fuer Darstellung, Karten, Privacy und Technical
- [x] Optionen im Core-App-Einstieg und im Wrapper ueber das bestehende Actions-Menue erreichbar
- [x] App-weite Wirkung: Distanz-/Speed-Formatierung, Kartenstil, Start-Tab und technische Metadaten folgen jetzt denselben lokalen Preferences
- [x] 4 neue Tests fuer Default-Werte, Persistenz, Reset und Fallback-Handling; `swift test` jetzt 135/135 gruen
- Bewusst nicht in diesem Schritt: Cloud-/Sync-/Server-Toggles, Background-Location-Optionen, Fake-Privacy-Controls

### Phase 19.30 – Live Recording MVP: aktueller Standort, foreground-only Track, getrennte Persistenz

**Datum:** 2026-03-18
**Ziel:** Nutzer kann den eigenen Standort auf der Karte anzeigen, foreground-only live aufzeichnen und den Track getrennt von importierter History lokal speichern.

- [x] `LiveLocationFeatureModel`: klar getrennte Recording-Domain ausserhalb von `AppSessionState`
- [x] `SystemLiveLocationClient`: `CLLocationManager`-Adapter mit while-in-use-Fokus, ohne Background-Mode
- [x] `LiveTrackRecorder`: Accuracy-/Duplikat-/Mindestdistanz-/Flood-Filter fuer Live-Punkte
- [x] `RecordedTrackFileStore`: dedizierte JSON-Persistenz fuer abgeschlossene Live-Tracks (`RecordedTracks/recorded_live_tracks.json`)
- [x] `AppLiveLocationSection`: Toggle, Permission-State, aktueller Standort, Live-Polyline, gespeicherte Live-Tracks
- [x] Integration in `AppDayDetailView` / `AppContentSplitView` / Wrapper-App
- [x] Wrapper-Info.plist: `NSLocationWhenInUseUsageDescription` fuer lokale While-In-Use-Funktion
- [x] 13 neue Tests (Recorder, Store, FeatureModel); `swift test` jetzt 125/125 gruen
- Bewusst nicht in diesem Schritt: Background-Tracking, Auto-Resume nach Neustart, Merge in importierte History, Export aufgezeichneter Live-Tracks

### Phase 19.29 – Export MVP: GPX-Export mit app-weiter Tages-Selektion

**Datum:** 2026-03-18
**Ziel:** Nutzer kann Tage fuer GPX-Export markieren und Datei per System-Share-Sheet speichern/teilen.

- [x] `GPXBuilder` (Core): GPX 1.1, Path.points → Tracks, XML-Escaping, Dateinamen-Helfer
- [x] `ExportSelectionState` (AppSupport): Value-Type Set<String>, in AppSessionState eingebettet
- [x] `GPXDocument: FileDocument` fuer fileExporter-Flow
- [x] `AppExportView`: Tage-Liste mit Checkboxen, Select All/Deselect All, GPX-Format-Badge,
      Export-Button (disabled bei leerer Auswahl oder keine Routes), Fehlermeldung, Empty State
- [x] `ExportFormat` Enum: GPX jetzt aktiv, Architektur fuer KML/CSV/etc. vorbereitet
- [x] 4. Tab "Export" (iPhone/compact) mit Badge fuer ausgewaehlte Tage
- [x] "Export..." Menueintrag + Sheet fuer iPad/regular Layout
- [x] AppDayRow: Export-Badge-Icon wenn Tag fuer Export markiert
- [x] 16 neue Tests (GPXBuilder + ExportSelectionState); 112/112 gruen
- Bewusst nicht in diesem Schritt: Visits als Waypoints, per-Track-Selektion, KML/CSV

### Persistenz-Status
Auto-Restore (ImportBookmarkStore) ist technisch implementiert und funktioniert korrekt (Phase 15).
Aktuell repo-wahr aktivierbar: die App startet weiterhin manuell, solange `Restore Last Import on Launch` deaktiviert bleibt; bei aktivem Toggle wird der letzte erfolgreiche Import opt-in automatisch wiederhergestellt.
Recent Files sind im import-first Startzustand sichtbar und koennen dort erneut geoeffnet, einzeln entfernt oder komplett geleert werden.
Recorded Live-Tracks sind jetzt separat aktiv: save-on-stop in einem dedizierten Store, ohne Draft-Persistenz und ohne Auto-Resume.

### Phase 19.21b – Google Timeline JSON direkt importierbar

**Datum:** 2026-03-18
**Ziel:** Google Location History JSON (`location-history.json`) direkt importierbar (ohne ZIP-Verpackung).

- [x] `decodeFile`: erkennt JSON-Array-Root → probiert `GoogleTimelineConverter.convert` vor `AppExportDecoder`
- [x] `GoogleTimelineConverter.convert`: `hasValidEntry`-Guard – leere Arrays und `[{}]` ohne `startTime` werfen `notGoogleTimeline` (→ `unsupportedFormat`)
- [x] Real getestet: `location-history.json` mit 64.926 Eintraegen importiert korrekt
- [x] 2 neue Tests (`testImportsGoogleTimelineJsonDirectly`, `testRealLocationHistoryJsonOnDesktop`); 96/96 gruen

**Problem vorher:** Direkte JSON-Datei mit Array-Root warf sofort `unsupportedFormat`. Nur ZIP-Verpackung funktionierte.

---

### Phase 19.21 – Google Timeline ZIP direkt importierbar

**Datum:** 2026-03-18
**Ziel:** Google Takeout ZIP (`location-history.zip`) direkt in der App oeffnen ohne vorherige Konvertierung.

- [x] `GoogleTimelineConverter`: konvertiert Google Timeline JSON-Array → AppExport per JSON-Dictionary-Roundtrip
- [x] `loadGoogleTimelineFromZip`: Fallback wenn kein LH2GPX-Export im ZIP; bevorzugt `location-history.json` bei Mehrdeutigkeit
- [x] `isGoogleTimeline`: prueft Array-Root; `convert` prueft zusaetzlich auf mindestens einen gueltigen `startTime`-Eintrag
- [x] Unterstuetzt: `visit`, `activity`, `timelinePath`-Eintraege; `geo:lat,lon`-Format; `distanceMeters` als String oder Double
- [x] ISO8601-Parser mit und ohne Bruchteile; Zeitzonenoffsets (`+02:00`) korrekt behandelt
- [x] Real getestet: `location-history.zip` (64.926 Eintraege) importiert korrekt
- [x] 6 neue Tests fuer Google Timeline ZIP; 94/94 gruen

**Problem vorher:** ZIP musste einen LH2GPX-App-Export enthalten. Google Takeout ZIPs wurden mit `jsonNotFoundInZip` abgewiesen.

---

### Phase 19.20 – ZIP-Import: Dateiname-agnostisch

**Datum:** 2026-03-18
**Ziel:** ZIP-Import nicht mehr auf exakten Dateinamen `app_export.json` beschraenken.

- [x] `loadZipContent`: alle `.json`-Kandidaten im ZIP sammeln (case-insensitive, `__MACOSX/` + Hidden-Files ignoriert)
- [x] Jeden Kandidaten inhaltlich gegen AppExportDecoder pruefen (Contract unveraendert)
- [x] 0 gueltige → `jsonNotFoundInZip`; 1 gueltige → laden; mehrere gueltige → `app_export.json` bevorzugen, sonst `multipleExportsInZip`
- [x] Neuer Error-Case `multipleExportsInZip` mit `userFacingTitle` + `errorDescription`
- [x] `jsonNotFoundInZip` errorDescription nennt nicht mehr `app_export.json` als Pflicht
- [x] 7 neue Tests; 88/88 gruen
- [x] Wrapper README aktualisiert

**Problem vorher:** `loadZipContent` suchte exakt `app_export.json` an Root oder als `/app_export.json`-Pfadsuffix. Jede andere Benennung fiel durch.

---

### Phase 19.18 – Searchable Days List Dark Mode Fix

**Datum:** 2026-03-18
**Ziel:** Schwarz-Bug in der Days-List bei Sucheingabe beheben.

- [x] compactDayList: immer `List` als Root-View
- [x] No-Results-State und Empty-State als `.overlay` auf der List statt als VStack-Ersatz
- [x] Dark-Mode-Hintergrund der List bleibt korrekt bei jeder Sucheingabe erhalten

**Problem vorher:** compactDayList wechselte bei leerer Suche zwischen `List` (mit Hintergrund) und `VStack` (ohne Hintergrund). Im Dark Mode erschien der nackte NavigationStack-Hintergrund als schwarze Flaeche.

---

### Phase 19.17 – Import Entry / Error UX Hardening

**Datum:** 2026-03-18
**Ziel:** Fehlerbehandlung beim Import verbessern. Fehlertitel je Error-Typ spezifisch statt generisch. emptyStateView-Text nutzerfreundlicher.

- [x] `userFacingTitle` in `AppContentLoaderError` pro Case: "Unable to read file" / "Unsupported file format" / "File could not be opened" / "No export found in ZIP" / "Demo data unavailable"
- [x] Alle `errorDescription` Werte actionable und nutzerfreundlich; `jsonNotFoundInZip` erklaert Konvertierungs-Workflow
- [x] `loadImportedFile` in ContentView.swift (Wrapper) nutzt `userFacingTitle` statt generischem Titel
- [x] `loadImportedFile` in AppShellRootView.swift (Core) nutzt `userFacingTitle` statt generischem Titel
- [x] emptyStateView-Text in ContentView.swift und AppShellRootView.swift verbessert
- [x] 5 neue Tests fuer `userFacingTitle` + `jsonNotFoundInZip`-Beschreibung; 81/81 gruen

**Problem vorher:** Alle Import-Fehler zeigten denselben generischen Titel "Unable to open app export". Nutzer konnten nicht unterscheiden ob die Datei kaputt, falsch formatiert, oder kein app_export.json enthalten war.

---

### Phase 19.10 – UX: iPhone TabView-Navigation + Visual Polish

**Datum:** 2026-03-18
**Ziel:** iPhone-Navigation grundlegend ueberarbeiten. TabView fuer compact (Overview + Days Tabs), farbcodierte Cards, Monatsgruppierung in Day List, farbige Stat-Cards, Actions-Menu in AppContentSplitView integriert.

- [x] Adaptive Layout: TabView mit zwei Tabs (Overview + Days) fuer iPhone compact, NavigationSplitView bleibt fuer iPad regular
- [x] Actions-Menu (Open/Demo/Clear) in AppContentSplitView integriert statt extern vom Parent
- [x] NavigationStack mit NavigationLink in Days-Tab: saubere Push-Navigation zu Day Detail
- [x] NavigationPath-Reset bei Content-Wechsel (neuer Import/Demo poppt zum Day-List-Root)
- [x] Farbcodierte Cards: Visit=blau, Activity=gruen, Path=orange (linker Farbbalken + getoeneter Hintergrund)
- [x] Farbige Stat-Cards in Overview (Days=blau, Visits=lila, Activities=gruen, Paths=orange)
- [x] Farbige Quick-Stats in Day Detail (gleiche Farbzuordnung)
- [x] Monatsgruppierung in Day List (Section Headers nach Monat, nur bei >1 Monat)
- [x] Distanzanzeige in Day-List-Rows (totalPathDistanceM, wenn >0)
- [x] Workarounds entfernt: isOverviewPushed, resetForCompact(), onChange-resetForCompact
- [x] AppDayRow als wiederverwendbare private View extrahiert (shared zwischen compact/regular)
- [x] coloredCard ViewBuilder-Helper fuer einheitliche Card-Darstellung

**Problem vorher:** NavigationSplitView kollabierte auf iPhone zu einem Stack. Overview war nur per Toolbar-Button erreichbar, nicht per Tab. Cards (Visit/Activity/Path) waren visuell identisch (gleiches Grau). Day List war flach ohne Monatsstruktur. Stat-Cards alle gleichfarben. Workarounds (resetForCompact, isOverviewPushed) waren noetig fuer brauchbare compact-Navigation.

**Jetzt:** iPhone zeigt eine echte TabView mit Overview-Tab und Days-Tab. Jeder Tab hat eigenen NavigationStack. Overview ist immer einen Tab-Tipp entfernt. Day Detail wird per NavigationLink gepusht. Cards sind farblich differenziert. Day List zeigt Monate. Stat-Cards haben individuelle Farben. Die App wirkt wie eine echte iPhone-App statt wie ein Demo-Viewer.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift (Core-Repo, Haupt-Rewrite). AppShellRootView.swift (Core-Repo, Closure-Uebergabe). ContentView.swift (Wrapper-Repo, Closure-Uebergabe).

**Nicht-Ziele:** Kein iPad-Fokus. Keine neue Business-Logik. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit.

---

### Phase 19.11 – UX: Insights-Tab + Activity/Visit-Breakdown + Overview-Enhancement

**Datum:** 2026-03-18
**Ziel:** Dritter Tab "Insights" fuer iPhone mit tiefer Statistik-Auswertung. Bisher ungenutzte Daten aus dem Query-Layer (stats.activities, stats.periods, Visit-Typen, Durchschnitte) endlich sichtbar machen. Overview-Tab mit Datumsbereich und Gesamtdistanz erweitern.

- [x] Neues Datenmodell: ExportInsights mit DateRange, ActivityBreakdown, VisitTypeBreakdown, PeriodBreakdown, DayAverages
- [x] Neue Query: AppExportQueries.insights(from:) — extrahiert Insights aus stats.activities (wenn vorhanden), sonst Fallback aus Day-Daten; aggregiert Visit-Typen, berechnet Tagesdurchschnitte
- [x] AppSessionState + AppSessionContent um insights erweitert
- [x] Neuer "Insights"-Tab im iPhone-TabView (3 Tabs: Overview, Days, Insights)
- [x] Insights-Inhalt: Daily Averages (4 Stat-Cards), Activity Types (Cards mit Count, Distanz, Dauer, Geschwindigkeit), Visit Types (Icons + Count), Period Breakdown (wenn vorhanden)
- [x] Overview-Tab erweitert: Datumsbereich-Header, Total Distance als prominente Anzeige
- [x] iPad regular: Insights unterhalb von Overview im Detail-Pane (alles scrollbar)
- [x] Visit-Typ-Icons: HOME=house, WORK=briefcase, CAFE=cup, PARK=leaf, LEISURE=gamecontroller, EVENT=star, STAY=bed
- [x] Graceful Degradation: wenn stats.activities fehlt, werden Basisdaten aus Day-Entries abgeleitet; wenn stats.periods fehlt, wird die Sektion ausgeblendet

**Problem vorher:** Die App zeigte nur 4 Basiszahlen (Days, Visits, Activities, Paths) und Activity-Typ-Namen als Comma-Text. Die reichen Statistiken aus stats.activities (Distanz, Dauer, Geschwindigkeit pro Typ) und stats.periods (Monats-/Jahresbreakdown) waren im Datenmodell komplett dekodiert aber nie in der UI sichtbar. Visit-Typen (HOME, WORK, CAFE, etc.) wurden nie aggregiert gezeigt. Kein Datumsbereich, keine Gesamtdistanz, keine Tagesdurchschnitte.

**Jetzt:** Die App hat einen vollwertigen Insights-Tab mit 4 Sektionen. Activity Types zeigen Count, Gesamtdistanz, Dauer und Durchschnittsgeschwindigkeit. Visit Types zeigen semantische Icons. Daily Averages liefern schnelle Orientierung. Die Overview zeigt Datumsbereich und Gesamtdistanz. Die App nutzt jetzt die vorhandenen Daten so aus, wie es fuer ein professionelles Produkt erwartet wird.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** ExportInsights.swift (neu, Core-Repo). AppExportQueries.swift (Core-Repo). AppSessionState.swift (Core-Repo). AppContentSplitView.swift (Core-Repo). Wrapper-Repo via SPM automatisch aktuell.

**Nicht-Ziele:** Keine Charts/Graphen. Kein iPad-Fokus. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit.

---

### Phase 19.14 – Days Navigation + Insights Depth

**Datum:** 2026-03-18
**Ziel:** Days-Tab mit Suche und Highlight-Markierungen. Insights mit Wochentags-Chart, Count/Distance-Umschalter fuer Activity-Types und verbesserter Distanz-Zeitachse. Map mit Style-Toggle und farbcodierten Visit-Markern.

- [x] Days-Tab: Suchfeld (filtert nach Datum, z.B. "2024-03" oder "2024-03-15")
- [x] Days-Tab: Busiest Day + Longest Distance Day in der Tagesliste markiert (flame / road Icon)
- [x] Days-Tab: Suchfeld-Reset bei Content-Wechsel
- [x] Insights: Distance-Over-Time-Chart nutzt echte Date-Achse (temporal, nicht kategorisch)
- [x] Insights: Activity-Type-Chart Count/Distance-Toggle (Segmented Picker)
- [x] Insights: Neuer "By Day of Week" Wochentags-Chart (Mon-Sun, avg events per weekday, ab 3 Tagen)
- [x] Insights: Chart-Farben ohne .gradient (bessere Dark-Mode-Lesbarkeit)
- [x] Map: Style-Toggle (Standard / Satellite Hybrid) als overlay Button
- [x] Map: Visit-Marker farbkodiert nach Typ (HOME=blau, WORK=indigo, CAFE=orange, PARK=gruen, etc.)

**Problem vorher:** Days-Liste war nicht durchsuchbar. Highlight-Tage waren nur in Overview sichtbar, nicht in der Tagesliste. Distance-Chart hatte kategorische Achse (String-Dates). Activity-Type-Chart zeigte nur Count, nicht Distanz. Kein Wochentags-Muster sichtbar. Map immer Standard, alle Visit-Marker rot.

**Jetzt:** Days-Tab ist durchsuchbar. Busiest/Longest-Tage haben subtile Icons in der Liste. Distance-Chart hat korrekte temporale Achse mit Luecken bei fehlenden Tagen. Activity-Chart umschaltbar zwischen Count und Distanz. Neuer Wochentags-Chart zeigt Aktivitaetsmuster Mo-So. Map hat Style-Toggle und farbige Visit-Marker nach Typ.

**Tests:** swift test gruen (70/70). swift build + xcodebuild BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift (Days-Suche, Highlight-Icons, Charts). AppDayMapView.swift (Style-Toggle, Visit-Marker-Farben).

**Nicht-Ziele:** Kein iPad-Fokus. Keine Persistenz. Keine Apple-/ASC-Arbeit.

---

### Phase 19.15 – Day-Detail-Timeline + tappbare Overview-Stat-Cards

**Datum:** 2026-03-18
**Ziel:** Gantt-Zeitleiste im Day-Detail. Overview-Stat-Cards navigierbar.

- [x] DayTimelineView: Gantt-Balken fuer Visits (blau) und Activities (gruen) auf gemeinsamer Zeitachse (GeometryReader, ISO8601-Parsing, Start/End-Labels)
- [x] AppDayDetailView: DayTimelineView nach der Karte eingebunden
- [x] AppOverviewSection: statCard mit optionalem action-Parameter; chevron-Indicator bei interaktiven Karten
- [x] Overview-Stat-Cards: Days → Days-Tab, Visits/Activities/Paths → Insights-Tab (nur iPhone compact, iPad nil)

**Tests:** swift test gruen. swift build + xcodebuild BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift.

**Nicht-Ziele:** Kein iPad-Fokus. Kein Tap-Effekt auf Timeline (rein visuell). Keine Persistenz. Keine Apple-/ASC-Arbeit.

---

### Phase 19.16 – ZIP-Import (ZipFoundation)

**Datum:** 2026-03-18
**Ziel:** app_export.json direkt aus einer .zip-Datei importieren.

- [x] Package.swift: ZipFoundation 0.9.19+ als SPM-Dependency; LocationHistoryConsumerAppSupport verknuepft
- [x] AppContentLoader: loadImportedContent erkennt .zip per Dateiendung; loadZipContent sucht alle .json-Kandidaten im ZIP (dateiname-agnostisch, __MACOSX ignoriert)
- [x] Neuer Fehler jsonNotFoundInZip mit sprechender Meldung
- [x] AppShellRootView (Core-App-Target): fileImporter akzeptiert .json und .zip
- [x] ContentView (Wrapper, tatsaechlich auf iPhone): fileImporter korrigiert auf [.json, .zip]; Labels aktualisiert
- [x] Tests: 6 neue ZIP-Tests (valid/invalid ZIP, Unterverzeichnis, Google-Format in ZIP, Error-Descriptions); alle 76 Tests gruen

**Hinweis:** Der urspruengliche Phase-19.16-Commit hatte ContentView.swift im Wrapper vergessen. Der fileImporter dort hatte nur [.json], weshalb ZIP-Dateien ausgegraut waren. Dieser Commit behebt den echten Bug.

**Tests:** swift test 76/76 gruen. xcodebuild BUILD SUCCEEDED.

**Betroffene Dateien:** Package.swift, AppContentLoader.swift, AppShellRootView.swift (Core), ContentView.swift (Wrapper), AppContentLoaderTests.swift.

**Nicht-Ziele:** Kein iPad-Fokus. Keine Persistenz. Keine Apple-/ASC-Arbeit.

---

### Phase 19.13 – Visual Insights: Swift Charts + tappbare Navigation + Politur

**Datum:** 2026-03-18
**Ziel:** Insights-Tab von reinem Zahlenviewer zu echtem Analytics-Bereich transformieren. Swift Charts integriert. Highlight-Cards tappbar (navigieren zu Day Detail). AppSourceSummaryCard kollapsierbar. Path Cards mit Activity-Type-Icon. Map-Polylines farblich nach Activity-Type.

- [x] Swift Charts: Distanz-pro-Tag-Balkendiagramm als Hero-Sektion im Insights-Tab (tappbare Balken navigieren zu Day Detail)
- [x] Swift Charts: Activity-Type-Verteilung als horizontale Balken in Insights
- [x] Swift Charts: Visit-Type-Proportionen als horizontale Balken in Insights
- [x] Highlight-Cards (Busiest Day, Longest Distance) tappbar – navigiert zu Days-Tab + Day Detail
- [x] TabView mit Selection-Binding (selectedTab) fuer programmatischen Tab-Wechsel
- [x] AppSourceSummaryCard: DisclosureGroup – nur Titel + Source immer sichtbar, Details kollapsierbar
- [x] Path Cards: Activity-Type-Icon (Konsistenz zu Visit/Activity Cards)
- [x] Map-Polylines: Farbe nach Activity-Type (Walking=gruen, Cycling=teal, Vehicle=grau, Bus=orange, Train/Subway=lila, Running=rot, default=blau)

**Problem vorher:** Insights-Tab zeigte ausschliesslich Zahlen in Cards/Listen – kein einziger Chart trotz vollstaendiger Datenlage. Overview-Highlights waren tote Zahlen ohne Navigation. AppSourceSummaryCard zeigte Debug-artige Technikdetails immer. Path Cards hatten kein Icon. Alle Polylines waren blau.

**Jetzt:** Insights hat 3 echte Swift Charts. Das Distanz-Balkendiagramm ist die erste visuelle Zeitreihe der App. Tapping eines Balkens springt direkt zum Day Detail. Highlight-Cards sind tappbar und wechseln Tab+Destination. AppSourceSummaryCard ist kompakt (Details per DisclosureGroup erweiterbar). Path Cards haben Activity-Type-Icon. Polylines sind farblich nach Activity-Type differenziert.

**Tests:** swift test gruen (70/70). swift build BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift (Charts, Navigation, SourceSummaryCard, PathCard). AppDayMapView.swift (Polyline-Farben).

**Nicht-Ziele:** Kein iPad-Fokus. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit. Day-Detail-Timeline (Phase 19.14+).

---

### Phase 19.12 – UX: Overview-Highlights + Day-Detail-Enrichment + Filter-Transparenz

**Datum:** 2026-03-18
**Ziel:** App auf ein deutlich hoeheres Reifelevel bringen. Overview mit Highlights (Busiest Day, Longest Distance) und Filter-Transparenz. Day Detail mit Tagesdistanz, Tageszeitraum und semantischen Icons. Insights Period Breakdown farbkodiert. Informationsarchitektur professionalisiert.

- [x] Overview neu strukturiert: Highlights-Section (Busiest Day, Longest Distance Day) prominent oben
- [x] Overview: AppSourceSummaryCard (Export Details) nach unten verschoben – nutzbare Info zuerst
- [x] Overview: Activity Types Comma-Text entfernt (redundant mit Insights-Tab)
- [x] Filter-Transparenz: Aktive Export-Filter (Limit, From/To, Activity Types, etc.) als oranges Banner in Overview
- [x] Day Detail: Tagesdistanz als vierte Stat-Card (Distance, purple)
- [x] Day Detail: Tageszeitraum im Header (frueheste Startzeit → spaeteste Endzeit)
- [x] Day Detail: Visit-Cards mit semantischen Typ-Icons (HOME=house, WORK=briefcase, CAFE=cup, etc.)
- [x] Day Detail: Activity-Cards mit Typ-spezifischen Icons (WALKING=figure.walk, CYCLING=bicycle, CAR=car, BUS=bus, etc.)
- [x] Insights: Period Breakdown Cards farbkodiert (purple bei Distanz > 0)
- [x] Icon-Mapping-Funktionen als wiederverwendbare file-level Helfer extrahiert (statt dupliziert in Insights)
- [x] ExportInsights um busiestDay, longestDistanceDay, activeFilterDescriptions erweitert
- [x] AppExportQueries.insights() berechnet Highlights aus DaySummary und Filter-Beschreibungen aus ExportFilters

**Problem vorher:** Overview zeigte technische Quelle (SourceSummaryCard) vor nuetzlicher Info. Keine Highlights fuer Orientierung. Day Detail hatte keine Tagesdistanz, keinen Zeitraum, keine semantischen Icons auf Cards. Visit- und Activity-Cards waren reiner Text ohne visuelle Differenzierung. Export-Filter waren dekodiert aber unsichtbar – Nutzer wusste nicht, ob Daten gefiltert sind. Activity Types als Comma-Text in Overview redundant mit Insights-Tab.

**Jetzt:** Overview fuehrt mit Highlights (orangener Busiest Day, violetter Longest Distance Day) und Total Distance. Technische Export-Details sind sauber am Ende. Aktive Filter sind sofort als oranges Banner sichtbar. Day Detail zeigt Tagesdistanz als 4. Stat-Card, Zeitraum im Header, semantische Icons auf Visit- und Activity-Cards. Period Breakdown Cards haben Farbakzente. Die App wirkt professioneller und nutzt die vorhandenen Daten deutlich besser aus.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** ExportInsights.swift (Core-Repo, DayHighlight + neue Felder). AppExportQueries.swift (Core-Repo, Highlights + Filter). AppContentSplitView.swift (Core-Repo, Haupt-UI-Aenderungen). Wrapper-Repo via SPM automatisch aktuell.

**Nicht-Ziele:** Keine Charts/Graphen. Kein iPad-Fokus. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit.

---
## Geparkt / Extern
Apple-/Developer-/ASC-/TestFlight-/Release-Themen (Phasen 20–21): kein aktiver Fokus.
Bleibt geparkt bis Developer-Account-Zugang und tatsaechliche Durchfuehrung moeglich sind.

### Spaeter
- iPad-Betrieb: bewusst zurueckgestellt
- Phase 21 (v1.0 Release): erst nach abgeschlossener Beta-Phase

---

## Phase 2

- [x] Minimales Swift-Consumer-Repo bootstrappen
- [x] Contract-Artefakte aus dem Producer-Repo übernehmen
- [x] Decoder-Modelle für den stabilen App-Export anlegen
- [x] Golden-Decoding-Tests anlegen

## Phase 3

- [x] 2-3 zusätzliche realistische Golden-Faelle ergänzen
- [x] Contract- und Fixture-Guards schärfen
- [x] nativen lokalen Swift-Testlauf als Standard dokumentieren
- [x] lokalen Producer-zu-Consumer-Update-Workflow skriptbar machen

## Phase 4

- [x] UI-unabhaengige Query-/ViewState-Schicht
- [x] sortierte Day-Summaries und Day-Detail-Read-Models
- [x] Header-/Overview-Query und Datumsbereichsfilter

## Phase 5

- [x] minimale SwiftUI-Demo-/Harness-Shell
- [x] feste lokale Demo-Fixture
- [x] Overview, Day-Liste und Day-Detail auf Basis der Query-Schicht

## Phase 6

- [x] lokaler Import-Flow fuer `app_export.json` in der Demo
- [x] Demo-Fixture als Fallback neben importierter Datei beibehalten
- [x] klare Fehleranzeige fuer Datei- und Decoding-Fehler

## Phase 7

- [x] klarere Zustandsfuehrung fuer Demo, Import und Fehler
- [x] sichtbare Quelle fuer Demo-Fixture vs. importierte Datei
- [x] bessere Leer- und Fallback-Zustaende fuer Liste und Detail

## Phase 8

- [x] klare Trennung zwischen Core, Demo und App-Shell
- [x] kleine produktnahe App-Shell-Struktur fuer lokalen `app_export.json`-Import
- [x] gemeinsame Session-/Content-Darstellung fuer Demo und App-Shell
- [ ] Produkt-UI

## Phase 9

- [x] import-first Startzustand der App-Shell klarer formulieren
- [x] aktiven Quellen-/Contract-Informationsbereich nachschärfen
- [x] Open / Replace / Demo / Clear-Fluss klarer fuehren
- [x] leere, fehlerhafte und importierte Inhaltszustaende sauberer unterscheiden

## Phase 10

- [x] Apple-/Xcode-nahe Produkt-App-Vorbereitung dokumentarisch ergaenzen
- [x] Rollen von Core / Demo / App-Support / App-Shell weiter schaerfen
- [x] produktnahe App-Shell als Apple-Einstieg klarer positionieren
- [x] Linux- und Apple-Verifikationsgrenzen ehrlich dokumentieren

## Phase 11

- [x] Xcode-Runbook fuer das Swift Package und die produktnahe App-Shell dokumentieren
- [x] Apple-Verifikations-Checkliste mit klaren Erfolgskriterien anlegen
- [x] erste echte macOS-/Xcode-Build-Verifikation fuer `LocationHistoryConsumerApp` dokumentieren
- [x] ersten echten Startversuch des gebauten App-Shell-Binaries dokumentieren
- [x] interaktive Apple-UI-Verifikation fuer Demo-Laden, Dateiimport, Clear und Fehlerfaelle abschliessen

## Phase 12

- [x] erste echte foreground-Apple-UI-Session fuer die produktnahe App-Shell dokumentieren
- [x] nativen Apple-Dateiimporter mit gueltiger Datei, invalidem JSON und no-days-Zustand real verifizieren
- [x] reproduzierbare Zero-Day-Fixture fuer Apple-UI-Verifikation ergaenzen

## Phase 13

- [x] reproduzierbares macOS-Launch-Script fuer die App-Shell (`scripts/run_app_shell_macos.sh`)
- [x] temporaere ad-hoc-App-Wrapper-Konvention durch standardisiertes Script ersetzen
- [x] Apple-Verifikations-Checkliste aktualisieren
- [x] Xcode-Runbook mit CLI-Launch-Abschnitt ergaenzen

## Phase 14 – Roadmap Rebaseline + Truth-Governance

**Ziel:** Belastbare Delivery-Roadmap bis App v1.0 im Repo verankern. Governance-Regeln fuer konsistente Pflege einfuehren.

- [x] feinschrittige Roadmap ab Phase 14 bis v1.0 in ROADMAP.md ergaenzen
- [x] Governance-Regeln fuer Roadmap-Pflege im Repo verankern
- [x] NEXT_STEPS.md auf die naechsten realen offenen Schritte ableiten
- [x] bestehende Doku-Inkonsistenzen bereinigen (XCODE_APP_PREPARATION.md veralteter Status)
- [x] README.md und AGENTS.md nur minimal synchronisieren

**Definition of Done:** Roadmap bis v1.0 vorhanden, Governance-Block in ROADMAP.md, NEXT_STEPS abgeleitet, Doku-Sync sauber, `swift test` gruen, `git diff --check` sauber.

**Tests:** `swift test`, `git diff --check`. Keine Code-Aenderungen, daher keine neuen Tests.

**Betroffene Dateien:** `ROADMAP.md`, `NEXT_STEPS.md`, `README.md`, `AGENTS.md`, `docs/XCODE_APP_PREPARATION.md`.

**Nicht-Ziele:** Keine Implementierung. Keine neuen Features. Keine neuen Dateien ausser ggf. minimale Doku-Korrekturen.

---

## Phase 15 – Lokale Persistenz + Import-Lebenszyklus

**Ziel:** Die App merkt sich die zuletzt importierte Datei und laedt sie beim Neustart automatisch. Ohne das ist die App praktisch bei jedem Start leer.

- [x] Security-Scoped Bookmarks fuer importierte Dateien speichern und wiederherstellen
- [x] letzten Import-Pfad ueber App-Neustarts hinweg persistent halten
- [x] automatischen Re-Load beim App-Start, falls Bookmark vorhanden und gueltig
- [x] sauberen Fallback wenn gespeicherte Datei nicht mehr erreichbar ist
- [x] Tests fuer Bookmark-Speicherung, -Wiederherstellung und Fehlerfaelle

**Definition of Done:** App startet mit zuletzt importierter Datei, wenn vorhanden. Fehlender/ungueltiger Bookmark fuehrt sauber zum import-first-Zustand. Tests gruen.

**Tests:** Unit-Tests fuer Bookmark-Storage-Logik. Manueller Smoke: App schliessen, neu starten, Datei noch da.

**Betroffene Dateien:** `Sources/LocationHistoryConsumerAppSupport/` (neuer Bookmark-/Persistence-Layer), `Sources/LocationHistoryConsumerApp/AppShellRootView.swift`, `Tests/`.

**Nicht-Ziele:** Keine Dateihistorie. Kein Cloud-Sync. Keine Multi-File-Verwaltung. Kein UserDefaults fuer Inhaltsdaten.

---

## Phase 16 – Wrapper-Projekt + Bundle-Grundlagen

**Ziel:** Das Xcode-Wrapper-Projekt (`LH2GPXWrapper`) wird fuer echte Geraete-Nutzung und spaetere App-Store-Einreichung vorbereitet.

- [x] App-Icon mindestens als Platzhalter in allen erforderlichen Groessen
- [x] Info.plist mit korrekten Bundle-Metadaten (Display Name, Version, Build)
- [x] PrivacyInfo.xcprivacy mit den fuer App Store Review erforderlichen Deklarationen
- [x] Signing-Konfiguration fuer Development und Distribution pruefen
- [x] Launch-Screen oder Launch-Storyboard konfigurieren
- [x] SPM-Dependency auf dieses Package stabil und reproduzierbar halten

**Definition of Done:** Wrapper baut auf echtem Geraet mit korrektem Icon, Bundle-Metadaten und Privacy-Manifest. Xcode-Archive-Build moeglich.

**Tests:** `xcodebuild archive` muss ohne Fehler durchlaufen. Geraete-Deploy manuell pruefen.

**Betroffene Dateien:** Primaer im Wrapper-Repo `LH2GPXWrapper/`. In diesem Repo ggf. kleinere Package.swift-Anpassungen.

**Nicht-Ziele:** Kein App-Store-Submit. Kein TestFlight. Kein finales Icon-Design.

**Hinweis:** Diese Phase betrifft hauptsaechlich das Wrapper-Repo, nicht dieses Library-Repo. Die Roadmap bildet den Gesamtweg bis v1.0 ab.

---

## Phase 17 – Produkt-UI: Navigation + Layout

**Ziel:** Die bestehende Basis-UI wird zu einer nutzbaren Produkt-Oberflaeche ausgebaut. Das schliesst den offenen Punkt `Produkt-UI` aus Phase 8 ab.

- [x] verbessertes Home-/Uebersichts-Layout mit kompakterem Dashboard
- [x] aufgewertete Day-Liste mit besserem Datumsformat und Summary-Cards
- [x] aufgewertetes Day-Detail mit strukturierten Sections und besserem Layout
- [x] Navigation-Flow fuer iPhone und iPad optimieren (NavigationSplitView / NavigationStack)
- [x] Leer-/Fehler-/Ladezustaende visuell polieren

**Definition of Done:** App fuehlt sich auf iPhone und iPad wie eine echte App an, nicht wie ein Harness. Alle bestehenden interaktiven Flows (Import, Demo, Clear, Fehler) funktionieren weiter. Tests gruen.

**Tests:** Bestehende Tests muessen gruen bleiben. Manueller UI-Smoke auf Geraet und Simulator. Apple-Verifikations-Checkliste aktualisieren.

**Betroffene Dateien:** `Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift`, `Sources/LocationHistoryConsumerApp/AppShellRootView.swift`, ggf. neue View-Dateien.

**Nicht-Ziele:** Keine neue Business-Logik. Keine Maps. Keine Persistenz-Erweiterung. Keine neuen Datenquellen.

---

## Phase 18 – Karten-MVP

**Ziel:** Pfade und Besuche aus dem App-Export auf einer Karte darstellen. Natuerliche Kernfunktion fuer Location-History-Daten.

- [x] MapKit-Integration in der Day-Detail-Ansicht
- [x] Pfade als Polylines auf der Karte visualisieren
- [x] Besuche als Marker/Pins darstellen
- [x] Basis-Interaktion: Zoom, Pan, Kartenausschnitt an Tagesdaten anpassen
- [x] sauberer Fallback wenn keine Koordinaten vorhanden

**Definition of Done:** Tagesansicht zeigt Pfade und Besuche auf einer Karte. Tage ohne Koordinaten zeigen keinen Kartenfehler. Tests gruen.

**Tests:** Unit-Tests fuer Coordinate-Extraction aus dem Query-Layer. Manueller Smoke auf Geraet.

**Betroffene Dateien:** `Sources/LocationHistoryConsumerAppSupport/` (neue Map-Views), ggf. `Sources/LocationHistoryConsumer/Queries/` (Coordinate-Helper).

**Nicht-Ziele:** In dieser damaligen Phase keine Heatmap. Kein Replay/Animation. Keine eigene Tile-Engine. Kein Offline-Map-Cache.

---

## Phase 19 – QA + Accessibility + Hardening

**Ziel:** App auf Produktionsqualitaet bringen. Barrierefreiheit, Performance bei grossen Dateien und Robustheit sicherstellen.

- [x] VoiceOver-Unterstuetzung fuer alle Screens pruefen und nachbessern
- [x] Dynamic Type in allen Views korrekt unterstuetzen
- [x] Performance-Test mit grossen App-Exports (>100 Tage, >10k Pfadpunkte)
- [x] Memory-Profiling bei grossen Dateien
- [x] Edge-Cases haerten: leere Felder, extreme Werte, fehlende Koordinaten

**Definition of Done:** VoiceOver navigiert alle Screens. Dynamic Type skaliert korrekt. Grosse Dateien laden in akzeptabler Zeit ohne Crash. Keine bekannten Crasher.

**Tests:** Accessibility-Audit in Xcode. Performance-Test mit `golden_app_export_sample_medium.json` und groesseren Fixtures. Bestehende Tests gruen.

**Betroffene Dateien:** Primaer `Sources/LocationHistoryConsumerAppSupport/` (View-Anpassungen). Ggf. neue Performance-Fixtures.

**Nicht-Ziele:** Keine neuen Features. Keine UI-Redesigns. Keine Lokalisierung (kommt ggf. spaeter).

**Nachgelagert (2026-03-17):** Realer iPhone-Betrieb (iPhone 15 Pro Max, iPhone 12 Pro Max) verifiziert: Demo, Karte, Scrollen. Import-Hardening: Google-Takeout-Format (location-history.json, Array-Root) wird jetzt mit verstaendlicher Fehlermeldung abgelehnt statt generischem Decode-Fehler. 4 neue Regressionstests. 58 Tests gruen.

---

## Lokale Produktweiterentwicklung

> Kleine, saubere lokale Produktschritte nach Phase 19. Kein Apple-Developer-Account noetig.

### Phase 19.1 – UX: Onboarding und Day-Detail-Lesbarkeit

**Datum:** 2026-03-18
**Ziel:** First-Use-Klarheit verbessern und Day-Detail-Anzeige fuer echte Nutzer lesbar machen.

- [x] Tool-Name (LocationHistory2GPX) im Empty-State-Subtitle kommuniziert
- [x] Idle-Statustext erklaert den Tool-Workflow statt generischem Datei-Hinweis
- [x] Zeitangaben in Day-Detail lesbar formatiert (ISO 8601 → lokale Uhrzeit, z. B. "7:20 AM")
- [x] Typ-Labels in Day-Detail formatiert (WALKING → Walking, IN PASSENGER VEHICLE → In Passenger Vehicle, HOME → Home)

**Definition of Done:** Nutzer sieht sofort, womit app_export.json erstellt wird. Day-Detail zeigt lesbare Uhrzeiten und verstaendliche Typ-Labels statt roher ISO-Strings und ALL_CAPS.

**Tests:** `swift test` gruen. Manueller Smoke: Day-Detail mit echten Daten auf Simulator oder Geraet.

**Betroffene Dateien:** `AppShellRootView.swift`, `AppSessionState.swift`, `AppContentSplitView.swift` (Core-Repo); `ContentView.swift` (Wrapper-Repo).

**Nicht-Ziele:** Keine Lokalisierung. Kein Redesign. Keine neuen Features.

### Phase 19.2 – UX: Clear-Flow Ghost-Button Fix

**Datum:** 2026-03-18
**Ziel:** Clear-Button verschwindet nach dem Clearen — kein sinnloser Loop mehr.

- [x] Toolbar-Clear-Button nur noch sichtbar wenn hasLoadedContent oder message.kind == .error
- [x] Empty-State-Clear-Button nur noch sichtbar wenn message.kind == .error

**Problem vorher:** Nach clearContent() setzte der State message = AppUserMessage(kind: .info, ...). Die Clear-Button-Bedingung prueft message != nil, nicht die Art der Message. Resultat: Clear-Button blieb nach dem Clearen sichtbar, obwohl keine Error-Card angezeigt wurde und nichts zu clearen war. Erneutes Klicken erzeugte dieselbe info-Message → Endlosschleife.

**Definition of Done:** Nach Clear kehrt die App in den sauberen Idle-Zustand zurueck. Kein Clear-Button sichtbar. Kein Loop.

**Tests:** swift test gruen (61/61). xcodebuild build im Wrapper-Repo erfolgreich.

**Betroffene Dateien:** AppShellRootView.swift (Core-Repo); ContentView.swift (Wrapper-Repo).

**Nicht-Ziele:** Kein Redesign. Keine State-Machine-Aenderung. Keine neuen Features.

### Phase 19.3 – UX: Activity-Types-Formatierung in Overview-Statistik

**Datum:** 2026-03-18
**Ziel:** Konsistenz zwischen Day-Detail-Typ-Labels (Phase 19.1) und Overview-Statistik herstellen.

- [x] statsActivityTypes in AppOverviewSection mit .capitalized formatiert (WALKING → Walking, IN PASSENGER VEHICLE → In Passenger Vehicle)

**Problem vorher:** Phase 19.1 hatte Typ-Labels in Day-Detail-Cards formatiert, aber die Statistik-Sektion in der Overview zeigte weiterhin Rohstrings (WALKING, IN PASSENGER VEHICLE, CYCLING, IN BUS). Jeder Nutzer mit Aktivitaetsdaten sah diesen Widerspruch.

**Definition of Done:** Overview-Statistik zeigt dieselbe lesbare Formatierung wie Day-Detail. WALKING → Walking, IN PASSENGER VEHICLE → In Passenger Vehicle, IN BUS → In Bus.

**Tests:** swift test gruen (61/61). Fixture-Verifizierung: Rohdaten sind UPPER CASE mit Leerzeichen, .capitalized korrekt.

**Betroffene Dateien:** AppContentSplitView.swift (Core-Repo, AppOverviewSection). Wrapper-Repo via SPM automatisch aktuell.

**Nicht-Ziele:** Keine Daten-Layer-Aenderung. Kein Redesign. Keine neuen Features.

### Phase 19.4 – UX: Locale-aware Distanzformatierung

**Datum:** 2026-03-18
**Ziel:** Distanzangaben in Aktivitäts- und Pfad-Cards zeigen jetzt Einheiten entsprechend der Geräte-Locale (Meilen für US-Nutzer, km für metrische Locales).

- [x] formatDistance() in AppDayDetailView durch Measurement.formatted(.measurement(width: .abbreviated, usage: .road)) ersetzt
- [x] Hardcodierte Metrisch-Formatierung (km/m) entfernt

**Problem vorher:** formatDistance() verwendete immer km und m (z. B. "1.9 km"), unabhängig von der Geräte-Locale. US-iPhone-Nutzer sahen metrische Einheiten statt Meilen/Feet.

**Jetzt:** System-Locale wird automatisch verwendet. US: "1.1 mi", "350 ft". Metrisch: "1.9 km", "350 m". Konsistent mit der Datum/Uhrzeit-Locale-Awareness aus Phase 19.1.

**Tests:** swift test grün (61/61). Deployment target iOS 26.2, Measurement.formatted seit iOS 15 verfügbar.

**Betroffene Dateien:** AppContentSplitView.swift (Core-Repo, formatDistance in AppDayDetailView). Wrapper-Repo via SPM automatisch aktuell.

**Nicht-Ziele:** Keine Einheitenauswahl durch Nutzer. Kein eigener Einheitenkonverter. Keine neuen Features.

### Phase 19.5 – Persistenz-Pause + iPhone-Einstieg klar machen

**Datum:** 2026-03-18
**Ziel:** Auto-Restore vorläufig deaktivieren. App startet immer bewusst manuell. iPhone-Einstieg ist klar und vorhersehbar.

- [x] Auto-Restore (restoreBookmarkedFile) in AppShellRootView und ContentView auskommentiert und als PARKED dokumentiert
- [x] Persistenz-Code (ImportBookmarkStore, restoreBookmarkedFile) vollstaendig erhalten
- [x] Kommentar-Dokumentation direkt im Code: "PARKED: Auto-restore temporarily disabled (Phase 19.5)"
- [x] ROADMAP und NEXT_STEPS aktualisiert

**Problem vorher:** App startete automatisch mit zuletzt importierter Datei. Auf iPhone fuehrte das zu einem eingeschraenkten, schwer vorhersehbaren Einstiegspunkt. Nutzer landete direkt in der Navigation ohne sichtbaren Ausgangspunkt.

**Jetzt:** Jeder App-Start beginnt mit dem manuellen Einstieg (Open location history file / Load Demo Data). Persistenz-Logik ist vollstaendig erhalten und kann jederzeit wieder aktiviert werden.

**Spaeterer Repo-Truth:** Diese Phase bleibt als historischer Zwischenstand korrekt, ist aber nicht mehr der aktuelle Gesamtstatus. Die Core-App-Shell haelt Auto-Restore weiter geparkt, der Wrapper hat `restoreBookmarkedFile()` am 2026-03-20 wieder aktiviert und braucht dafuer eine frische Device-Verifikation.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** AppShellRootView.swift (Core-Repo); ContentView.swift (Wrapper-Repo). Persistenz-Code unangetastet.

**Nicht-Ziele:** Keine Loeschung der Persistenz-Logik. Kein neues Design. Keine neue Navigation. Keine neuen Features.

---

### Phase 19.6 – UX: Empty-State-Bereinigung
---

### Phase 19.7 – UX: PlaceID-Bereinigung in Visit-Cards

**Datum:** 2026-03-18
**Ziel:** Rohe Google Place IDs aus Visit-Cards entfernen. Die ID (z.B. ChIJP3Sa8ziYEmsRUKgyFmh9AQM) ist fuer Nutzer vollstaendig unlesbar und hat ohne Places-API keinen Wert.

- [x] if-let-placeID-Block aus visitCard() in AppContentSplitView.swift entfernt
- [x] Visit-Cards zeigen jetzt: Typ-Label + Zeitspanne (falls vorhanden) – klar und hinreichend

**Problem vorher:** Jeder Visit-Card mit Place ID zeigte einen rohen Google-Identifier mit building.2-Icon in tertiaerer Farbe. Kein Nutzer kann diesen String interpretieren. Wirkt unfertig.

**Jetzt:** Visit-Card zeigt Typ-Label (semanticType oder generisch "Visit") und Zeitspanne. Kein technisches Rauschen.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift (Core-Repo, visitCard). Wrapper-Repo via SPM automatisch aktuell.

**Nicht-Ziele:** Keine Places-API-Integration. Kein Netzwerk. Kein Redesign. Keine neuen Features.

---

### Phase 19.8 – UX: Overview auf iPhone compact zugaenglich + Day List als Landing

**Datum:** 2026-03-18
**Ziel:** Overview auf iPhone compact erreichbar machen. Beim Laden von Inhalten soll der Nutzer auf der Day List landen statt direkt im Day Detail des ersten Tages. Expliziter "Overview"-Button im Navigations-Header der Day List auf compact.

- [x] resetForCompact() ersetzt sanitizeCompactSelection(): bei Content-Load auf compact wird Selektion zurueckgesetzt
- [x] "Overview"-Button in Day-List-Toolbar (nur compact, nur iOS) navigiert per .navigationDestination zur Overview-Ansicht
- [x] overviewPaneContent als wiederverwendbarer ViewBuilder extrahiert (genutzt in detailPane und compact-Overview)
- [x] "Select a day from the sidebar" korrigiert zu "Select a day from the list" (platform-neutral)

**Problem vorher:** Beim Laden (Demo oder Import) wurde selectedDate automatisch auf den ersten Tag gesetzt. NavigationSplitView compact pushte sofort in Day Detail. Nutzer sah weder Day List noch Overview als Landing. Overview war auf iPhone compact nie erreichbar.

**Jetzt:** Beim Laden wird selectedDate auf compact zurueckgesetzt. Nutzer landet auf der Day List. Expliziter "Overview"-Button (chart.bar.doc.horizontal) oben links oeffnet die Overview per Push. Day Detail via Zeilentipp in der Liste erreichbar. Alle wichtigen Seiten erreichbar.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift (Core-Repo). Wrapper-Repo via SPM automatisch aktuell.

**Nicht-Ziele:** Kein iPad-Fokus. Keine neue Architektur. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit.



### Phase 19.9 – UX: iPhone Navigation-Shell + UI Polish

**Datum:** 2026-03-18
**Ziel:** iPhone-Navigation professionell ueberarbeiten. Toolbar-Ueberladung beseitigen, NavigationStack fuer Empty State, zentrierter Empty State mit App-Icon, Overview-Button mit Text-Label.

- [x] Toolbar-Buttons (Open, Demo, Clear) in ein einzelnes Actions-Menu konsolidiert (ellipsis.circle)
- [x] NavigationStack um Empty State / Loading: App-Name "LH2GPX" als Navigation-Titel sichtbar
- [x] Empty State zentriert mit Karten-Icon (map.fill): modernes iOS-Muster statt linksbundigem Text
- [x] Overview-Button in Day-List-Toolbar zeigt jetzt Text-Label (.labelStyle(.titleAndIcon)) statt nur Icon

**Problem vorher:** Drei separate Toolbar-Buttons (Open, Demo, Clear) plus Overview-Button drängten sich auf iPhone compact in der Navigation Bar. Labels wurden abgeschnitten, nur Icons sichtbar. Empty State hatte keinen NavigationStack — kein App-Name, keine Toolbar, kein einheitlicher Nav-Container. Empty State war linksbündig und ohne visuelle Identität.

**Jetzt:** Ein einzelner "..."‐Button öffnet ein Menu mit allen Aktionen (Open, Demo, Clear mit Divider). Empty State zeigt Navigation-Titel "LH2GPX", zentriertes Karten-Icon und zentrierte Buttons. Overview-Button in Day List zeigt "Overview" als lesbaren Text. Professioneller, aufgeraeuemter iPhone-Flow.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift (Core-Repo, Overview-Button-Label). AppShellRootView.swift (Core-Repo, NavigationStack + Menu + Empty State). ContentView.swift (Wrapper-Repo, NavigationStack + Menu + Empty State).

**Nicht-Ziele:** Kein Card-Redesign. Kein App-Logo. Keine neue Architektur. Kein iPad-Fokus. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit.

---


**Datum:** 2026-03-18
**Ziel:** AppSourceSummaryCard aus dem leeren (Idle-)Startzustand entfernen. Der Nutzer sieht beim ersten Oeffnen kein technisches Rauschen ("Source: None", "Schema: n/a"), sondern nur Titel, Erklaerungstext und Aktions-Buttons.

- [x] AppSourceSummaryCard aus AppShellEmptyStateView (Core-Repo) entfernt
- [x] summary-Parameter aus AppShellEmptyStateView entfernt (nicht mehr benoetigt)
- [x] AppSourceSummaryCard aus ContentView.emptyStateView (Wrapper-Repo) entfernt
- [x] AppSourceSummaryCard bleibt unveraendert im geladenen Overview-Pane (AppSessionStatusView)

**Problem vorher:** Im Idle-Zustand (kein Export geladen) zeigte die App eine graue Info-Card mit "No app export loaded", "Source: None" und wiederholendem Statustext. Dieser Inhalt duplizierte den bereits vorhandenen Titel/Untertitel und wirkte technisch statt einladend.

**Jetzt:** Empty State zeigt direkt: Titel, Erklaerung, ggf. Fehler-Card, Aktions-Buttons. Kein technisches Rauschen.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** AppShellRootView.swift (Core-Repo); ContentView.swift (Wrapper-Repo).

**Nicht-Ziele:** Keine Aenderung des AppSessionState. Keine Aenderung der AppSourceSummaryCard selbst. Kein Redesign.

---


### Phase 19.10 – UX: iPhone TabView-Navigation + Visual Polish

**Datum:** 2026-03-18
**Ziel:** iPhone-Navigation grundlegend ueberarbeiten. TabView fuer compact (Overview + Days Tabs), farbcodierte Cards, Monatsgruppierung in Day List, farbige Stat-Cards, Actions-Menu in AppContentSplitView integriert.

- [x] Adaptive Layout: TabView mit zwei Tabs (Overview + Days) fuer iPhone compact, NavigationSplitView bleibt fuer iPad regular
- [x] Actions-Menu (Open/Demo/Clear) in AppContentSplitView integriert statt extern vom Parent
- [x] NavigationStack mit NavigationLink in Days-Tab: saubere Push-Navigation zu Day Detail
- [x] NavigationPath-Reset bei Content-Wechsel (neuer Import/Demo poppt zum Day-List-Root)
- [x] Farbcodierte Cards: Visit=blau, Activity=gruen, Path=orange (linker Farbbalken + getoeneter Hintergrund)
- [x] Farbige Stat-Cards in Overview (Days=blau, Visits=lila, Activities=gruen, Paths=orange)
- [x] Farbige Quick-Stats in Day Detail (gleiche Farbzuordnung)
- [x] Monatsgruppierung in Day List (Section Headers nach Monat, nur bei >1 Monat)
- [x] Distanzanzeige in Day-List-Rows (totalPathDistanceM, wenn >0)
- [x] Workarounds entfernt: isOverviewPushed, resetForCompact(), onChange-resetForCompact
- [x] AppDayRow als wiederverwendbare private View extrahiert (shared zwischen compact/regular)
- [x] coloredCard ViewBuilder-Helper fuer einheitliche Card-Darstellung

**Problem vorher:** NavigationSplitView kollabierte auf iPhone zu einem Stack. Overview war nur per Toolbar-Button erreichbar, nicht per Tab. Cards (Visit/Activity/Path) waren visuell identisch (gleiches Grau). Day List war flach ohne Monatsstruktur. Stat-Cards alle gleichfarben. Workarounds (resetForCompact, isOverviewPushed) waren noetig fuer brauchbare compact-Navigation.

**Jetzt:** iPhone zeigt eine echte TabView mit Overview-Tab und Days-Tab. Jeder Tab hat eigenen NavigationStack. Overview ist immer einen Tab-Tipp entfernt. Day Detail wird per NavigationLink gepusht. Cards sind farblich differenziert. Day List zeigt Monate. Stat-Cards haben individuelle Farben. Die App wirkt wie eine echte iPhone-App statt wie ein Demo-Viewer.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift (Core-Repo, Haupt-Rewrite). AppShellRootView.swift (Core-Repo, Closure-Uebergabe). ContentView.swift (Wrapper-Repo, Closure-Uebergabe).

**Nicht-Ziele:** Kein iPad-Fokus. Keine neue Business-Logik. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit.

---

### Phase 19.11 – UX: Insights-Tab + Activity/Visit-Breakdown + Overview-Enhancement

**Datum:** 2026-03-18
**Ziel:** Dritter Tab "Insights" fuer iPhone mit tiefer Statistik-Auswertung. Bisher ungenutzte Daten aus dem Query-Layer (stats.activities, stats.periods, Visit-Typen, Durchschnitte) endlich sichtbar machen. Overview-Tab mit Datumsbereich und Gesamtdistanz erweitern.

- [x] Neues Datenmodell: ExportInsights mit DateRange, ActivityBreakdown, VisitTypeBreakdown, PeriodBreakdown, DayAverages
- [x] Neue Query: AppExportQueries.insights(from:) — extrahiert Insights aus stats.activities (wenn vorhanden), sonst Fallback aus Day-Daten; aggregiert Visit-Typen, berechnet Tagesdurchschnitte
- [x] AppSessionState + AppSessionContent um insights erweitert
- [x] Neuer "Insights"-Tab im iPhone-TabView (3 Tabs: Overview, Days, Insights)
- [x] Insights-Inhalt: Daily Averages (4 Stat-Cards), Activity Types (Cards mit Count, Distanz, Dauer, Geschwindigkeit), Visit Types (Icons + Count), Period Breakdown (wenn vorhanden)
- [x] Overview-Tab erweitert: Datumsbereich-Header, Total Distance als prominente Anzeige
- [x] iPad regular: Insights unterhalb von Overview im Detail-Pane (alles scrollbar)
- [x] Visit-Typ-Icons: HOME=house, WORK=briefcase, CAFE=cup, PARK=leaf, LEISURE=gamecontroller, EVENT=star, STAY=bed
- [x] Graceful Degradation: wenn stats.activities fehlt, werden Basisdaten aus Day-Entries abgeleitet; wenn stats.periods fehlt, wird die Sektion ausgeblendet

**Problem vorher:** Die App zeigte nur 4 Basiszahlen (Days, Visits, Activities, Paths) und Activity-Typ-Namen als Comma-Text. Die reichen Statistiken aus stats.activities (Distanz, Dauer, Geschwindigkeit pro Typ) und stats.periods (Monats-/Jahresbreakdown) waren im Datenmodell komplett dekodiert aber nie in der UI sichtbar. Visit-Typen (HOME, WORK, CAFE, etc.) wurden nie aggregiert gezeigt. Kein Datumsbereich, keine Gesamtdistanz, keine Tagesdurchschnitte.

**Jetzt:** Die App hat einen vollwertigen Insights-Tab mit 4 Sektionen. Activity Types zeigen Count, Gesamtdistanz, Dauer und Durchschnittsgeschwindigkeit. Visit Types zeigen semantische Icons. Daily Averages liefern schnelle Orientierung. Die Overview zeigt Datumsbereich und Gesamtdistanz. Die App nutzt jetzt die vorhandenen Daten so aus, wie es fuer ein professionelles Produkt erwartet wird.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** ExportInsights.swift (neu, Core-Repo). AppExportQueries.swift (Core-Repo). AppSessionState.swift (Core-Repo). AppContentSplitView.swift (Core-Repo). Wrapper-Repo via SPM automatisch aktuell.

**Nicht-Ziele:** Keine Charts/Graphen. Kein iPad-Fokus. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit.

---
## Geparkt / Extern

> **Apple-/Developer-/ASC-/TestFlight-/Release-Themen bleiben geparkt,**
> **bis Developer-Account-Zugang und tatsaechliche Durchfuehrung moeglich sind.**
> Diese Phasen sind vollstaendig dokumentiert, aber kein aktiver Fokus.
> iPad ebenfalls spaeter.

### Phase 20 – TestFlight + App Store Readiness (GEPARKT)

**Wartet auf:** Apple Developer Account / ASC-Zugang.

- [ ] App Store Beschreibung und Metadaten (Vorentwurf in docs/TESTFLIGHT_RUNBOOK.md im Wrapper-Repo)
- [x] App Store Screenshots fuer iPhone und iPad
- [ ] TestFlight-Build hochladen und interne Beta starten
- [x] App Store Review Guidelines pruefen (insbesondere Datenschutz, Minimal Functionality)
- [ ] Feedback aus Beta-Phase einarbeiten

**Definition of Done:** TestFlight-Build an Tester verteilt. App Store Metadaten vollstaendig. Keine Review-Guideline-Verstoesse bekannt.

**Historischer lokaler Nachweis (2026-03-17):** `xcodebuild archive` erfolgreich (v1.0, Build 1). `PrivacyInfo.xcprivacy` war vorhanden und dokumentierte lokal sichtbar kein Tracking plus UserDefaults CA92.1. Die damalige Review-Notiz war nur eine lokale Arbeitsbewertung und kein belastbarer Apple-Freigabeclaim. App Icon ersetzt (Map-Pin + LH2GPX, kein Gradient-Placeholder mehr). Screenshot-Simulator-Workflow dokumentiert. TestFlight-Runbook in `docs/TESTFLIGHT_RUNBOOK.md` im Wrapper-Repo.

**Lokal abgeschlossen (2026-03-17):** Screenshots via UI-Test erstellt (iPhone 17 Pro Max + iPad Pro 13" M5, iOS 26.3.1). Liegen in `docs/appstore-screenshots/` im Wrapper-Repo.

**Extern – bewusst geparkt (2026-03-17):** ASC-Zugang aktuell nicht verfuegbar. Verbleibend: App Store Connect Projekt anlegen, Metadaten eintragen, Upload, TestFlight-Beta aktivieren.

**Update 2026-04-29:** lokaler Transporter-Upload weiterhin ungueltig (`Invalid Signature` fuer `LH2GPXWrapper` + `LH2GPXWidget`). Repo-Signing fuer den Xcode-Cloud-Pfad wurde auf `Automatic` + Team `XAGR3K7XDJ` bereinigt; der Workflow `Release – Archive & TestFlight` ist angelegt und jetzt der bevorzugte Uploadpfad. Phase 20 bleibt offen, bis ein echter Build in App Store Connect erscheint.

**Update 2026-04-29 (Overview-/Explore-Map):** die frisch gepushte interaktive Overview-Karte wurde nachauditert und gehaertet: kein Re-Scan bei Pan/Zoom, Viewport-Auswahl per Bounding-Box-Intersection, stale Overlay-Tasks werden bei Neu-Load verworfen, Explore-Dismiss setzt wieder Full-View-Overlays. Der Batch liefert nur Code-/Test-/Xcode-Nachweise, keine neuen Device-Claims.

**Nachgelagert:** Beta-Feedback einarbeiten (erst nach laufender Beta relevant).

**Tests:** TestFlight-Install auf echtem Geraet. Beta-Tester-Feedback. Crash-Reports pruefen.

**Betroffene Dateien:** Primaer Wrapper-Repo (App Store Connect Metadaten, Screenshots, docs/TESTFLIGHT_RUNBOOK.md). In diesem Repo ggf. kleinere Fixes aus Beta-Feedback.

**Nicht-Ziele:** Kein oeffentlicher Launch. Kein Marketing. Keine Android-Version.

---

### Phase 21 – v1.0 Release (GEPARKT – erst nach Beta-Feedback)

**Wartet auf:** Abgeschlossene TestFlight-Beta-Phase (Phase 20).

- [ ] finale QA-Runde auf aktuellem iOS
- [ ] App Store Submit
- [ ] v1.0 Tag in beiden Repos
- [ ] README/Docs auf v1.0-Stand aktualisieren

**Definition of Done:** App im App Store verfuegbar. v1.0 Tag gesetzt. Doku aktuell.

**Tests:** Finaler manueller Durchlauf aller Flows auf Produktions-Build. Crash-Reports nach Release beobachten.

**Betroffene Dateien:** Beide Repos. Tags, README, ROADMAP-Status.

**Nicht-Ziele:** Keine neuen Features nach Feature-Freeze. Kein Android. Kein Cloud-Sync.

---

## Dauerhaft ausserhalb des Scopes

- Google-Rohdaten-Import oder -Parsing
- Producer-Business-Logik (bleibt im Python-Repo)
- Netzwerk, Analytics oder Cloud-Sync
- `trips_index.json` konsumieren
- Android / Play Store (ggf. separates Projekt)

---

## Roadmap-Governance

Diese Regeln gelten fuer alle kuenftigen Aenderungen an dieser Roadmap:

1. **Nur [x] bei echtem Repo-Nachweis.** Eine Checkbox wird nur abgehakt, wenn die Umsetzung im Repo nachweisbar ist UND relevante Tests gruen sind UND betroffene Doku synchronisiert wurde.

2. **Historische Eintraege nicht loeschen oder umsortieren.** Abgeschlossene Phasen bleiben unveraendert stehen. Korrekturen nur bei nachweislich falschen Aussagen, dann mit Kommentar.

3. **Neue Implementierungen muessen in ROADMAP und Doku aufgenommen werden.** Jeder Commit, der eine Phase betrifft, muss die zugehoerige Checkbox und ggf. NEXT_STEPS aktualisieren.

4. **NEXT_STEPS darf nur offene, priorisierte naechste Arbeit enthalten.** Keine erledigten Punkte. Keine vagen Wuensche. Nur die konkret naechsten 2-4 Schritte.

5. **Doku-Sync ist Pflicht.** Wenn Code und Doku sich widersprechen, muss die Doku im selben Arbeitsgang korrigiert werden. Nicht spaeter, nicht in einer separaten Phase.

6. **App-Phasen duerfen nicht als fertig gelten, solange Gates nicht real nachweisbar sind.** Insbesondere: kein App-Store-Claim ohne echten TestFlight-Build, keine Accessibility-Behauptung ohne Audit, keine Performance-Aussage ohne Messung.

7. **Monorepo-Architektur-Grenze ehrlich abbilden.** Phasen, die den `wrapper/`-Bereich betreffen, muessen das klar benennen. Der Core-Root bleibt die Library-Quelle; kein Xcode-spezifischer Code wandert in den Core.

8. **Phase-8-Restpunkt `Produkt-UI` ist nach Phase 17 abgeschlossen.** Der offene Punkt aus Phase 8 wird nicht nachtraeglich abgehakt, sondern durch Phase 17 abgeloest.

9. **Apple-/ASC-/TestFlight-/Release-Themen bleiben geparkt.** Phasen 20 und 21 werden erst aktiviert, wenn Developer-Account-Zugang tatsaechlich vorhanden ist. Kein Checkbox-Update in diesen Phasen solange der Zugang fehlt.
