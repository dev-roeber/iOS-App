# NEXT_STEPS

Stand: 2026-05-17 (Branch `main`, nach **Train Q — Product Info SwiftUI Wiring**).

**Train Q umgesetzt (3 produktive Commits + Doku-Sync):**
- `4bad00c` Build-179-Baseline-Doku.
- `9e89340` Neue `ProductInfoCard`-SwiftUI-Komponente (LHCard-basiert, layout-only).
- `80c9dae` `formatGuidanceCard` in `AppExportView` — sichtbar unter Format-Auswahl, rendert ExportFormatGuidancePresentation.
- `a1585af` `importSummaryCard` in `AppExportView` — sichtbar nach Titel bei aktivem Import, rendert ImportValidationSummary-Helper.

**Sichtbare neue UI-Funktionen im Export-Tab:** Import-Übersicht (Counts + Range + Warnungen), Format-Hilfe (Use-Case + Tools + Stärken).

**Übersprungen:** Phasen 3+4 (RouteQuality im Export-Preview / Day-Detail — Multi-Path-Aggregation wäre mehrdeutig; Helper bleiben für Per-Track-Detail bereit), 6 (Layout-Sweep — Cards nutzen bereits LHCard-Konsistenz), 7 (Identifier — bereits in Train P gelocked), 8 (Presentation-Tests bereits in Train P).

**Tests:** `swift test` **1568 / 2 Skips / 0 Failures** (unverändert).

**Externer Stand:** Letzter verifizierter Build = **Xcode Cloud Build 179**. Train-O/P/Q sind **noch nicht** extern.

**Zwingend nächster Schritt:** Neuer Xcode-Cloud-Build (→ Build 180+). Sicht-Verifikation der beiden neuen Cards auf iPhone und iPad.

**Folge-Trains:**
- **Per-Track-Detail-Train:** RouteQuality-Card im Single-Path-Detail, sobald eine Per-Track-Detail-View existiert.
- **XCUITest-Target** für ProductInfo-Identifier auf Mac/Simulator.
- **D / G2** (Mac/Instruments-only): Heatmap-Multi-LOD + MKMapView-Bridge.

---

Vorheriger Stand: 2026-05-17 nach Train P.

**Train P umgesetzt (4 produktive Commits + Doku-Sync):**
- `56a76ed` Build-179-Baseline-Doku.
- `eaa149f` `ImportValidationSummaryPresentation.strings(for:german:)` (10 Tests) — title, rangeSubtitle (long-form DE/EN), countsLine mit Pluralisierung + Zero-Drop, warningLines.
- `936fae6` `ExportFormatGuidancePresentation.rendered(for:german:)` (6 Tests) — title/primaryUse/tools/strengths mit Bullet-Präfix.
- `ecde6cc` `RouteQualitySummaryPresentation.strings(for:german:)` (12 Tests) — level labels DE/EN, gerundete Spacing/Gap-Lines (1 m/5 m/50 m Buckets), Gap-Line nur für sparse/containsGaps.
- `e5cdafc` `AppAccessibilityID.ProductInfo` Namespace (15 Konstanten, 2 Tests).

**Übersprungen:** Phase 4 (Shared Components — Vorrats-Code), 6 (Lokalisierung — direkt in Helpern), 7 (UX-Sweep — erst bei View-Integration sinnvoll).

**Bewusst NICHT in Train P:** Kein SwiftUI-View-Wiring. Train P liefert reine Presentation-Strings + Identifier-Hooks. UI-Layout-Integration ist ein eigener Folge-Train.

**Tests:** `swift test` **1568 / 2 Skips / 0 Failures** (+30).

**Externer Stand:** Letzter verifizierter Build = **Xcode Cloud Build 179**. Train-O- und Train-P-Commits sind **noch nicht** extern.

**Zwingend nächster Schritt:** Neuer Xcode-Cloud-Build (→ Build 180+). Anschließend UI-Layout-Train, der die drei Presentation-Helper + 15 ProductInfo-Identifier in `AppExportView`, `AppDayDetailView` und Active-Source-/Import-Completion-Card verdrahtet.

**Folge-Trains:**
- **UI-Layout-Train:** SwiftUI-Karten für Import-Summary (Active Source / Import-Completion), Export-Format-Hilfe (Export-Sheet Disclosure/Footer), Route-Quality (Export-Preview Card / Day-Detail Tile). Layout-only — alle Strings + Identifier sind bereits gelocked.
- **XCUITest-Target** im Apple-Xcode-Projekt nutzt `AppAccessibilityID.{Tab,Map,Action,ProductInfo}`.
- **D / G2** (Mac/Instruments-only): Heatmap-Multi-LOD + MKMapView-Bridge.

---

Vorheriger Stand: 2026-05-17 nach Train O.

**Build 179 extern grün** (Xcode Cloud) auf `ff789a4` (Train M tip). Train-N (sofern vorhanden) und Train-O sind **nicht** extern in Build 179 enthalten.

**Train O umgesetzt (4 produktive Commits + Doku-Sync):**
- `f349a06` Build-179-Baseline-Doku.
- `82b685b` Neuer `ImportValidationSummary` (Foundation, 10 Tests) — Tage/Visits/Activities/Paths/Points-Counts, sortiertes Datum-Range, 3 Warnungen (`emptyImport`/`noGPSPoints`/`singleDayOnly`). Privacy-Vertrag.
- `408c93b` Neuer `ExportFormatGuidance.copy(for:german:)` (7 Tests) — DE/EN-Use-Case-Hilfe pro Format. Format-Defaults unverändert.
- `17b9b6a` Neuer `RouteQualitySummary.evaluate(points:)` (10 Tests, Haversine) — `empty/sparse/containsGaps/good` mit Average-Spacing + Largest-Gap in Metern.
- `9a23031` `AppAccessibilityID.Action`-Namespace (6 Aliase auf bestehende Inline-Identifier, +2 Tests).

**Übersprungen:** Phasen 4-8 (kein konkreter UX-Defekt; bestehende Architektur sauber; Performance-Polish bereits in Train H-L erschöpft).

**Tests:** `swift test` **1538 / 2 Skips / 0 Failures** (+29).

**Externer Stand:** Letzter verifizierter Build = **Xcode Cloud Build 179**. Train-O-Commits sind **noch nicht** extern.

**Zwingend nächster Schritt:** Neuer Xcode-Cloud-Build (→ Build 180+). Anschließend UI-Wiring-Train, der die drei Helper in passenden Views verdrahtet (Import-Summary nach erfolgreichem Import, Export-Format-Hilfe im Export-Sheet, Route-Quality im Export-Preview/Day-Detail).

**Folge-Trains:**
- **Helper-UI-Wiring-Train:** Helper aus Train O in die zuständigen Views integrieren.
- **XCUITest-Target** im Apple-Xcode-Projekt, das die zentralen `AppAccessibilityID`-Konstanten nutzt.
- **D / G2** (Mac/Instruments-only): Heatmap-Multi-LOD-Wiring + MKMapView-Bridge.

---

Vorheriger Stand: 2026-05-17 nach Train M.

**Build 178 extern grün** (Xcode Cloud, Archive iOS ✅ + TestFlight interne Tests ✅) auf `487833f` (Train L tip). Toolchain Xcode 26.5 (17F42) / macOS Tahoe 26.4 (25E246). TestFlight zeigt `LH2GPX 1.0.2 (178)` mit Pre-production-Banner. Damit Trains I/J/K/L extern angekommen.

**Partieller TestFlight-Screenshot-Smoke Build 178:** Overview/Live/Insights/Export-Tabs öffnen. Hardware-Sweep, Dynamic Island, iPad, großer Import, externe Export-Validierung sind bewusst unbestätigt. App-Review nicht eingereicht.

**Train M umgesetzt (4 produktive Commits + Doku-Sync):**
- `a476fb0` Build-178-Doku.
- `efa68c4` Neuer zentraler `AppAccessibilityID`-Namespace (`Root`/`Tab`/`Map`, 10 Konstanten, 6 Tests).
- `ebae73f` 5 Tab-Identifier (`tab.overview` … `tab.live`) in `AppContentSplitView`; Pre-Production-Banner-Konstante mappt auf bestehenden `localTimeline.testMode.banner`.
- `5de7017` 4 Map-Root-Identifier (`map.overview.root`, `map.heatmap.root`, `map.exportPreview.root`, `map.dayDetail.root`).

**Übersprungen:** Phase 5-8 Per-Element-Identifier-Migration der 155 bestehenden Inline-Identifier (kein XCUITest-Konsument); Phase 9 UI-Test-Smoke (kein XCUITest-Target im SwiftPM-Tree, braucht Apple-Xcode-Projekt).

**Tests:** `swift test` **1509 / 2 Skips / 0 Failures, 54,6 s** (+6).

**Externer Stand:** Letzter verifizierter Build = **Xcode Cloud Build 178**. Train-M-Commits sind **noch nicht** extern.

**Zwingend nächster Schritt:** Neuer Xcode-Cloud-Build (→ Build 179+), Identifier-Existenz via Xcode Accessibility Inspector am Simulator/Gerät prüfen, vollständiger Hardware-Smoke nachreichen.

**Folge-Trains:**
- **XCUITest-Target** im Apple-Xcode-Projekt für Tab-/Map-Navigation-Smoke.
- **Per-Element-Migration** der bestehenden Inline-Identifier in `AppAccessibilityID`, getrieben durch UI-Test-Bedarf.
- **D / G2** (Mac/Instruments-only): Heatmap-Multi-LOD-Wiring + MKMapView-Bridge.

---

Vorheriger Stand: 2026-05-16 nach Train L.

**Train L umgesetzt (2 produktive Test-Commits + Doku-Sync):**
- `574d522` Build-176-Baseline-Doku.
- `c5e86ef` `HeatmapGenerationLifecycleTests` (8 neue Tests, deterministisch, kein Timer; A→B→A flip, stale-completion, updateScale-Invalidierung).
- `a63f827` Neuer `internal LocalTimelineStore.queryPlan(for:)` (EXPLAIN-QUERY-PLAN-Hook für Tests) + `LocalTimelineDerivedCacheQueryPlanTests` (3 Tests; Lookup und Prune-ORDER-BY-LIMIT nutzen beide `idx_derived_cache_*`-Indizes).

**Übersprungene Phasen:** 2 (Heatmap-Debounce-Path-Analyse zeigt kein State-Write-Race-Risiko), 4-7 (kein konkreter UX-Defekt, AccessibilityIdentifier-Breitenausbau invasiv), 8 (alle Allocation-Hotspots in Train H/I/J/K abgedeckt).

**Tests:** `swift test` **1503 / 2 Skips / 0 Failures, 55,2 s** (+11 neue Tests).

**Externer Stand:** Letzter verifizierter Build = **Xcode Cloud Build 176** (basiert auf `556180c`). Train-I/J/K/L sind **noch nicht** extern.

**Zwingend nächster Schritt:** Neuer Xcode-Cloud-Build (→ Build 177+), TestFlight-Install + manueller Smoke siehe CHANGELOG.

**Folge-Trains:**
- **AccessibilityIdentifier-Train**: gezielt 5-10 zentrale UI-Elemente (Heatmap, Live-Status-Chips, Export-Button) identifizieren, getrieben durch konkreten UI-Test-Bedarf.
- **D / G2** (Mac/Instruments-only): Heatmap-Multi-LOD-Wiring + MKMapView/MKMultiPolyline-Bridge.

---

Vorheriger Stand: 2026-05-16 nach Train K.

**Train K umgesetzt (4 produktive Commits + 1 Doku-Sync):**
- `84064c9` Build-176-Baseline-Doku.
- `924370a` `AppOverviewMapModel` `loadGeneration: UInt64` → shared `GenerationGate` (Semantik identisch, Hash-Token bleibt als zweites Race-Guard).
- `555123d` 11× `if #available(iOS 16.x, *)`-Runtime-Branches dedenten (ActivityManager 4×, LiveActivityPresentation 1×, AppInsightsContentView 2×, LiveLocationFeatureModel 4×).
- `f959f2e` CSV `joinEscapedRow`-Helper ersetzt 4× `cols.map{...}.joined()` in row-builders (byte-identisch).

**Übersprungene Phasen:** 3 (Heatmap-Test braucht Scheduler-Injection), 4 (Import-UX bereits modelliert), 5 (Export-UX stabil), 7 (Store-EXPLAIN braucht Public-API-Eingriff), 8 (verbleibende offset-id Sites ohne Domain-IDs), 9 (kein UX-Defekt).

**Tests:** `swift test` **1492 / 2 Skips / 0 Failures, 53,7 s** (unverändert).

**Externer Stand:** Letzter verifizierter Build = **Xcode Cloud Build 176** (basiert auf `556180c`). Train-I/J/K (`d0c0a4c → f959f2e`) sind **noch nicht** extern.

**Zwingend nächster Schritt:** Neuer Xcode-Cloud-Build (→ Build 177+), TestFlight-Install + manueller Smoke siehe CHANGELOG.

**Folge-Trains:**
- **Heatmap-Pipeline-Härtung** mit injizierbarem `Clock`-Protokoll für race-flaky-freie Tests.
- **Store-EXPLAIN-Plan-Test** via testbar gekapselter Friend-Method.
- **D / G2** (Mac/Instruments-only): Heatmap-Multi-LOD-Wiring + MKMapView/MKMultiPolyline-Bridge.

---

Vorheriger Stand: 2026-05-16 nach Train J.

**Train J umgesetzt (4 produktive Commits + 1 Doku-Sync):**

**Train J umgesetzt (4 produktive Commits + 1 Doku-Sync):**
- `980111d` Build-176-Baseline-Doku.
- `731c290` GeoJSON `features.reserveCapacity` (byte-identisch).
- `d0b2f1b` `GenerationGate` (Sendable, 8 Tests) + Heatmap-Wiring gegen stale `MainActor.run`-Completions.
- `7dfcce7` `LHExportStepIndicator` `id: \.element` (Step Hashable, allCases unique).

**Übersprungene Phasen:** 2 (Import-Progress bereits modelliert, Export-Builder sind synchron), 3 (Repo nutzt bereits konsequent `Task.detached`), 6 (Live-Pipeline modular über `LiveStatusResolver`/`LiveTrackingPresentation`), 7 (kein konkreter UX-Defekt), 8 (13 Indizes vorhanden, kein EXPLAIN-Beleg für weitere).

**Tests:** `swift test` **1492 / 2 Skips / 0 Failures, 54,9 s** (+8 neue `GenerationGateTests`).

**Externer Stand:** Letzter verifizierter Build = **Xcode Cloud Build 176** (basiert auf `556180c`). Train-I-Commits **und** Train-J-Commits (`980111d → …`) sind **noch nicht** extern.

**Zwingend nächster Schritt:** Neuer Xcode-Cloud-Build (→ Build 177+), TestFlight-Install + manueller Smoke siehe CHANGELOG.

**Folge-Trains:**
- **Overview-Gate-Migration**: `AppOverviewMapModel.loadGeneration: UInt64` + `currentLoadToken: Int` auf `GenerationGate` umstellen, falls Apple-side stabil.
- **H-Cleanup-2**: 11× `if #available(iOS 16.x, *)`-Runtime-Checks dedenten (mechanisch).
- **Heatmap-Pipeline-Härtung** mit injizierbarem `Clock`-Protokoll für race-flaky-freie Tests.
- **D / G2** (Mac/Instruments-only): Heatmap-Multi-LOD-Wiring + MKMapView/MKMultiPolyline-Bridge.

---

**Train I umgesetzt (4 Commits gepusht):**

Vorheriger Stand: 2026-05-16 nach Train I.

**Train I umgesetzt (4 Commits gepusht):**
- `d0c0a4c` Build 176 dokumentiert.
- `41a8e6c` Live Camera Throttle (0,5 s + 25 m, ON, in `AppLiveTrackingView` verdrahtet; 9 neue Tests).
- `058a131` GPX/KML reserveCapacity + KML direkter String-Loop (Output byte-identisch).
- `b0d49a3` Index `idx_derived_cache_kind_version_created` (additiv).

**Übersprungene Phasen:** 2 (Cap-Refactor ohne Code-Truth-Nutzen), 3 (Heatmap-Race-Härtung braucht Scheduler-Injection für saubere Tests), 6 (Identity B2 — keine garantiert uniquen IDs), 7 (kein UX-Bedarf identifiziert).

**Tests:** `swift test` **1484 / 2 Skips / 0 Failures, 54,5 s** (+9 neue Tests).

**Externer Stand:** Letzter verifizierter Build = **Xcode Cloud Build 176** (basiert auf `556180c`). Train-I-Commits (`d0c0a4c` → letzter Doku-Commit) sind **noch nicht** extern.

**Zwingend nächster Schritt:** Neuer Xcode-Cloud-Build (→ Build 177+), TestFlight-Install + manueller Smoke siehe CHANGELOG.

**Folge-Trains:**
- **H-Cleanup-2**: 11× `if #available(iOS 16.x, *)`-Runtime-Checks dedenten (mechanisch).
- **Heatmap-Pipeline-Härtung** mit injizierbarem `Clock`-Protokoll (Race-Härtung sauber testbar).
- **D / G2** (Mac/Instruments-only): Heatmap-Multi-LOD-Wiring + MKMapView/MKMultiPolyline-Bridge.

---

Vorheriger Stand: nach `perf: wire live track render cap into map presentation`.

**Train H-Wire-1 umgesetzt:**
- `LiveTrackRenderCap` ist jetzt in `AppLiveTrackingView.refreshTrackPresentationState()` verdrahtet.
- Default-Cap: **10 000 Punkte (ON)**, intern als `private static let liveRenderPointCap` (keine User-Settings-UI).
- Wirkt nur auf `@State polylineCoordinates` + `@State trackSamples` (View-State). `liveLocation.liveTrackPoints` (Rohdaten), `LiveTrackRecorder`-Persistence und `RecordedTrack`-Export sind **unverändert**.
- Erste + letzte Koordinate immer erhalten. Hinweis-Banner nur bei tatsächlich gekapptem Track (DE/EN lokalisiert).
- Linux: `swift build` clean, `swift test` **1475 / 2 Skips / 0 Failures** (+6 neue `LiveRenderCapWiringTests`).

**Externer Stand (unverändert):** Letzter verifizierter Build = **Xcode Cloud Build 175** (basiert auf `2bfc009`). Train H und H-Wire-1 sind noch nicht extern verifiziert.

**Zwingend nächster Schritt:** Neuer Xcode-Cloud-Build (→ Build 176+), TestFlight-Install + manueller Smoke:
- Live-Recording 20 000+ Punkte → Hinweis erscheint, Start- + Endposition korrekt.
- Live-Recording <10 000 Punkte → Hinweis erscheint NICHT.
- Export einer gekappten Session → enthält volle Rohdaten.
- Dynamic Island / Live Activity Lock-Screen sichtbar.
- WAL-Korruptions-Check nach Force-Quit.
- iPad-Layout, Widget, CSV-Export-Byte-Identität.

**Folge-Trains:**
- **H-Cleanup-2**: 11× `if #available(iOS 16.x, *)`-Runtime-Checks dedenten.
- **D / G2**: Heatmap-Multi-LOD-Wiring, MKMapView-Bridge (Mac/Instruments).

---

Vorheriger Stand: nach **Train H — App Performance / Stability / UX Hardening**.

**Train H umgesetzt (4 Commits, alle Linux-grün, alle gepusht):**
- `a741b76` `chore: clean redundant ios 16 availability gates` — 12 `@available(iOS 16.x, *)`-Attribute entfernt.
- `254875a` `perf: reduce csv export array reallocations` — CSV-Builder reserveCapacity.
- `86b3da6` `perf: cap wal growth in local timeline store` — `journal_size_limit` + `wal_autocheckpoint` Pragmas.
- `7288a5f` `perf: add live track render cap helper` — Pure Helper `LiveTrackRenderCap` mit 10 Tests, **noch nicht in View verdrahtet**.

**Übersprungene Phasen:**
- Identity Surface B2: Items haben keine garantiert uniquen IDs → Risiko > Nutzen.
- Heatmap-Debounce: View hat bereits `.onMapCameraChange(frequency: .onEnd)` → unnötig.
- UX-Polish: Eng gekoppelt an Live-Render-Cap-Wiring (separater Folge-Train).

**Tests:** `swift test` **1469 / 2 Skips / 0 Failures** (+10 neue Tests).

**Externer Stand:** Letzter extern verifizierter Build ist **Xcode Cloud Build 175** (basiert auf `2bfc009`). Train-H-Commits sind **noch nicht** extern verifiziert.

**Zwingend nächster Schritt:** Neuer Xcode-Cloud-Build auslösen (→ Build 176+), TestFlight-Install + manueller Smoke-Test:
- Live-Recording 5+ Min ohne Crash, Polyline-Update flüssig.
- Live Activity / Dynamic Island sichtbar (iPhone 14 Pro+).
- Großer Import, Force-Quit + Reopen → keine WAL-Korruption.
- Heatmap Pan/Zoom responsiv. CSV-Export byte-identisch.
- Widget zeigt aktuelle Daten. iPad-Layout ok.

**Folge-Trains:**
- **H-Wire-1**: `LiveTrackRenderCap` in `AppLiveTrackingView` verdrahten + Preference-Toggle (Default OFF) + UX-Hinweis.
- **H-Cleanup-2**: 11 `if #available(iOS 16.x, *)`-Runtime-Checks dedenten.
- **D / G2 (Mac/Instruments)**: Heatmap-Multi-LOD-Wiring, MKMapView-Bridge.

---

Vorheriger Stand: nach `docs: record xcode cloud build 175 verification`.

**Xcode Cloud Build 175 extern verifiziert (Screenshots):**
- Workflow `Release – Archive & TestFlight` Build **175** erfolgreich, letzter Commit `2bfc009`.
- Damit sind `ff963c1` (onChange-Fix) und `2bfc009` (G1 MapKit-Stand) extern auf TestFlight angekommen.
- `Archive - iOS` ✅, `TestFlight-interne Tests - iOS` ✅.
- Toolchain: Xcode 26.5 (17F42), macOS Tahoe 26.4 (25E246).
- TestFlight: `LH2GPX 1.0.2 (175)`. App-Info: „Erfordert iOS 17.0 oder neuer".

**Repo-Truth lokal unverändert:** `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171`. Build 175 entstand durch `CI_BUILD_NUMBER`.

**Nicht behauptet:** keine App-Review-Submission/-Accept, kein Hardware-Smoke unter Build 175, keine Dynamic-Island-Sichtprüfung, kein iPad-Layout-Test.

**Nächste empfohlene Schritte:**
- TestFlight-Install Build 175 auf iPhone 14 Pro / iPhone 16 Pro Max: DayMap, LiveTracking, Heatmap, Overview, ExportPreview je einmal manuell, Crash- + Render-Stabilität bestätigen. Dynamic-Island-Lock-Screen-Sichtprüfung. iPad-Layout.
- **Train C** (Linux, Feature-Flag default OFF): Live-Polyline Hard-Cap-UI-Warnung + Camera-Throttle.
- Cleanup-Train: 18× redundante `@available(iOS 16.0/16.1/16.2, *)`-Gates abbauen (mechanisch).

---

Vorheriger Stand: nach `docs: g1 mapkit ios 17 migration is already complete`.

**Train G1 — Befund: kein Migrationsbedarf.**
- `rg "coordinateRegion:|annotationItems:|MapMarker|MapAnnotation\("` repo-weit: **0 Treffer**.
- Alle 8 SwiftUI-`Map(...)`-Surfaces sind bereits auf `Map(position: $mapPosition) { … }` mit `MapCameraPosition` + `Marker` / `Annotation` / `MapPolyline` (DayMap, LiveTracking 2×, RecordedTrackEditor 2×, LiveLocationSection, Heatmap, OverviewTracksMapView 2×, ExportPreview).
- Migration war in früherer Phase vor diesem Audit erfolgt; die Audit-Annahme „deprecated lebt weiter, falls noch genutzt" war ungenau.
- Audit-Docs `docs/APP_PERFORMANCE_MODERNIZATION_AUDIT_2026-05-16.md` + `docs/MAPKIT_PERFORMANCE_AUDIT_2026-05-16.md` korrigiert.
- Keine Code-Änderung, keine API-Brüche, keine Versions-Bumps. Linux `swift test` unverändert 1459/2/0.

**Externer Stand (unverändert):** Xcode Cloud Build 174 basiert auf `92dc447`; weder `ff963c1` (`onChange`-Fix) noch G1-Doku darin enthalten. **Neuer Xcode-Cloud-Build erforderlich**, damit `onChange`-Deprecation-Warnung extern entfällt.

**Nächste empfohlene Schritte:**
- Externer Xcode-Cloud-Build auf aktuellem `main` (HEAD nach G1) + TestFlight-Install Smoke auf iPhone 14 Pro / iPhone 16 Pro Max (DayMap / LiveTracking / Heatmap / Overview / ExportPreview je einmal manuell, Crash- + Render-Stabilität).
- **Train C** (Live Surface Hardening, Feature-Flag default OFF): Live-Polyline-Hard-Cap-UI-Warnung + Camera-Throttle.
- ODER **Cleanup-Train**: 18× redundante `@available(iOS 16.0/16.1/16.2, *)`-Gates abbauen (mechanisch).
- **G2** (Mac/Instruments-only, nicht in Linux-Trains): MKMapView/MKMultiPolyline-Bridge-Prototyp für Overview-Heavy-Datasets.

---

Vorheriger Stand: nach `fix: update ios 17 onchange usage and document build 174`.

**iOS-17-Deprecation-Warnung behoben + extern Build-174-Stand dokumentiert:**
- `wrapper/LH2GPXWrapper/ContentView.swift:125` (Xcode-Cloud-gemeldete Stelle) auf zwei-Parameter-Form migriert.
- Repo-weit alle 23 verbleibenden single-arg `.onChange(of:) { _ in / X in … }` ebenfalls auf `{ _, _ in / _, X in … }` umgestellt (AppInsightsContentView 10×, AppExportView 3×, AppContentSplitView 10×). Semantik exakt erhalten.
- `rg "\.onChange\(of: [^)]+\) \{ [a-zA-Z_]+ in"`: 0 Treffer.
- Linux: `swift build` clean, `swift test` 1459/2/0.

**Extern belegter Stand (Screenshots):**
- Xcode Cloud Build **174** erfolgreich, Workflow `Release – Archive & TestFlight`, letzter Commit `92dc447`.
- TestFlight: `LH2GPX 1.0.2 (174)`, 90 Tage.
- App-Info: „Erfordert iOS 17.0 oder neuer" — Train-F-Anhebung extern bestätigt.

**Repo-Truth (lokal):** `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171`. Build 174 entstand durch Xcode-Cloud-Zählung (`ci_pre_xcodebuild.sh` überschreibt `CFBundleVersion` mit `CI_BUILD_NUMBER`). Lokale Build-Nummer bewusst nicht auf 174 gezogen.

**Nicht belegt / nicht behauptet:** keine App-Review-Submission, kein Hardware-Retest, keine Dynamic-Island-Sichtprüfung, kein iPad-Layout-Test.

**Nächste empfohlene Schritte:**
- Mac/Device: TestFlight-Install Build 174 auf iPhone 14 Pro / iPhone 16 Pro Max, Live-Activity- + Dynamic-Island-Sichtprüfung, iPad-Layout.
- ODER Train **G**: MapKit-iOS-17-API-Migration (`coordinateRegion:` / `annotationItems:` durch `MapContentBuilder` / `MapCameraPosition` ablösen).
- Optional: 18× redundante `@available(iOS 16.x, *)`-Gates abbauen (risikoarm, reines Aufräumen).

---

Vorheriger Stand: nach `chore: raise minimum ios target to 17`.

**Train F umgesetzt (iOS-17-Anhebung):**
- `Package.swift`: `.iOS(.v16)` → `.iOS(.v17)`; `macOS(.v13)` unverändert.
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: alle 6 `IPHONEOS_DEPLOYMENT_TARGET` auf `17.0` (vorher 4× `16.0` + 2× `16.2`).
- `README.md` + `wrapper/README.md` ziehen den neuen Minimum-Stand nach.
- Marketing-Version / Build (`1.0.2 / 171`) unverändert.
- **Bewusst nicht abgebaut:** `@available(iOS 16.0/16.1/16.2, *)`-Gates bleiben (4 + 5 + 9 = 18 Stellen). Durch iOS-17-Minimum redundant, aber funktional korrekt — Aufräumung separater Folge-Train.
- **Bewusst nicht angetastet:** `@available(iOS 17, macOS 14, *)`-Gates (28 Stellen). Viele gaten zusätzlich macOS 14, das bleibt nötig.
- Linux: `swift build` clean, `swift test` 1459/2/0 ~53,6 s.

**Zwingender Mac/Xcode-Cloud-Smoke vor weiterer Arbeit:**
1. Wrapper in Xcode öffnen, Sim-Build iOS 17 grün.
2. Geräte-Smoke `xcodebuild -destination 'generic/platform=iOS'` grün.
3. Xcode-Cloud-Archive `1.0.2 (171)` mit neuem Minimum erstellen + ASC-Validierung.
4. ASC-Reichweiten-Snapshot (`developer.apple.com/support/app-store/`) prüfen.

**Nächster empfohlener Train:**
- **G** (Linux + Mac): MapKit-iOS-17-API-Migration — `Map { … }`-Builder durchgängig, `MapCameraPosition`, deprecated `coordinateRegion:`/`annotationItems:` ersetzen. Großer Refactor, jetzt sauber möglich.
- ODER **C** (gemischt, Feature-Flag default OFF): Live-Polyline-Hard-Cap-UI-Warnung + Camera-Throttle.

---

Vorheriger Stand: nach `perf: reduce kmz export memory copies`.

**Train E1 umgesetzt (KMZ-Memory-Refactor):**
- `KMZBuilder.build(from:)` schreibt jetzt direkt in einen In-Memory-`Archive` (ZIPFoundation `Archive(data:, accessMode: .create)` + `archive.data`).
- Entfernt: `temporaryDirectory`-Roundtrip + `Data(contentsOf: tmpURL)` Re-Read.
- API/Output-Bytes unverändert. 1459/2/0 grün, 6 KMZ-Tests grün.
- iOS-Memory-Pressure-Effekt nur am Gerät mit Instruments verifizierbar.

**Nächster empfohlener Train: F (iOS-17-Anhebung).** Räumt iOS-16-Reste konsistent ab; Voraussetzung für saubere MapKit-iOS-17-API-Migration.

---

Vorheriger Stand: nach `docs: audit app performance modernization and ios 17 path`.

**App Performance Modernization Audit 2026-05-16 (umgesetzt, nur Doku):**
- Neu: `docs/APP_PERFORMANCE_MODERNIZATION_AUDIT_2026-05-16.md` — repo-weite Performance-Tiefenanalyse + iOS-17-Entscheidungsmatrix.
- **Deployment-Target-Empfehlung:** Option 3 — iOS 17 **vorbereiten, NICHT** in diesem Train anheben. Inventar: 28× iOS-17-Gates + 9× iOS-16.2-Gates, `Package.swift .iOS(.v16)`, 8 pbxproj-Configs auf 16.0/16.2.
- Top-20-Hotspot-Liste mit P0/P1/P2/M, Linux-testbar vs. Mac-only getrennt.
- Linux `swift test` 1459/2/0 (~54 s) unverändert.

**Empfohlene Trains (in Reihenfolge):**
- **E1** (Linux, klein): KMZ-Streaming-Writer — `KMZBuilder` heute mit Doppel-Pufferung (KML-String → Data → tmpURL → `Data(contentsOf:)`). Streaming-Provider direkt aus KML-File-Handle, kein zweiter In-Memory-Load.
- **E2** (Linux, mittel): GPX/KML/CSV/GeoJSON optionale Stream-API (`build(into: URL)`-Variante). Bestehende API additiv erhalten.
- **E3** (Linux, klein): `LocalTimelineStore` Pragmas — `journal_size_limit`, `wal_autocheckpoint`, optional `mmap_size`. iOS-Effekt nicht Linux-prüfbar.
- **C** (gemischt, Feature-Flag default OFF): Live-Polyline Hard-Cap + Tail-Decimation + Camera-Throttle.
- **B2** (gemischt): DayDetail/Overview/Export Identity-Wrapper.
- **F** (Doku + Build): iOS-17-Anhebung (Reichweite vor Anhebung verifizieren via `developer.apple.com/support/app-store/`).
- **D** (Mac/Device/ASC): Heatmap-Multi-LOD-Wiring, MKMapView-Bridging, MKTileOverlay-Heatmap, Apple-Review-Resubmit.

---

Vorheriger Stand 2026-05-16 (nach `perf: stabilize swiftui identity surfaces`).

**Train B1 „Identity Polish — Insights" 2026-05-16 (umgesetzt, kein Verhaltenswechsel beabsichtigt):**
- `Sources/.../AppInsightsContentView.swift` — 3 sichere `ForEach(Array(...enumerated()), id: \.offset)`-Stellen auf stabile Domain-IDs umgestellt (`id: \.activityType` / `\.semanticType` / `\.label`). Keine Index-Variable wurde genutzt.
- **Bewusst NICHT enthalten:**
  - Keine `.onChange`-Konsolidierung (Agent-Analyse: `.task(id:)` wäre keine semantik-äquivalente Ersetzung — würde `refreshDerivedModel()` doppelt anstoßen, Picker-Reset duplizieren).
  - Keine Eingriffe in `AppRecordedTrackEditorView` (Index-getragene Bindings), `LHExportComponents` (Index aktiv genutzt), `AppDayDetailView`-Rows, Live-Pfade, Map-Overlays.
  - Kein Live-Polyline-Cap, kein Camera-Throttle (Train C).
- Linux `swift test`: **1459 / 2 Skips / 0 Failures, 54,3 s** — identisch zur Baseline vor Train B1.
- **Auf Linux nicht visuell prüfbar:** SwiftUI-Identity-Diffing-Effekt; nur über Build/Test grün-gehalten.

**Empfohlener nächster Train (Stand 2026-05-16, nach Train B1):**
- **Train B2 („Surface Polish — DayDetail/Overview Rows")** — `Identifiable`-Wrapper oder ID-Erweiterung für `DayDetailViewState.VisitItem` / `ActivityItem` und Overview/Export-Overlay-Typen. Erfordert Modell-Edit, daher separater Train.
- Alternativ **Train C („Live Surface Hardening", Feature-Flag Default OFF)** — Live-Track Polyline Hard-Cap + Tail-Decimation, Camera-Update-Throttle im Follow-Mode.

**Train A „Baseline Strengthening" 2026-05-16 (umgesetzt, kein Verhaltenswechsel):**
- 3 neue Performance-Test-Files (Foundation-only, Linux-CI-portabel, ohne Fail-Bar) + 1 Erweiterung:
  - `Tests/.../PathSimplificationPerformanceTests.swift` (5 Cases — DouglasPeucker 1k/5k @ ε=15 m, 5k @ ε=5 m, Korrektheits-Invarianten)
  - `Tests/.../PathFilterPerformanceTests.swift` (6 Cases — removeOutliers clean/outlier, Korrektheits-Invarianten)
  - `Tests/.../ExportBuildersPerformanceTests.swift` (12 Cases — GPX/KML/CSV/GeoJSON 1k + 3×5k + Struktur-Asserts)
  - `Tests/.../GoogleTimelineStreamReaderPerformanceTests.swift` — neuer 10k-Disk-Streaming-Case
- Linux `swift test`: 1459 / 2 Skips / 0 Failures, 52,8 s (vorher 1435).
- **Keine Performance-Verbesserung behauptet** — Train A ergänzt nur Mess-Baselines.
- **KMZ-Builder ausgelassen:** wrappt KML in ZIPFoundation-Archive; KML-Baseline ist die relevante Messung.

**Empfohlener nächster Train (Stand 2026-05-16):**
- **Train B („Identity & Surface Polish")** — pro View ein PR, Verhalten unverändert:
  - `ForEach(Array(...enumerated()), id: \.offset)` an 13 Stellen schrittweise auf stabile `Identifiable`-IDs.
  - AppInsightsContentView 5× `.onChange` zu einer `.task(id:)`-Konsolidierung.
- alternativ **Train C („Live Surface Hardening", Feature-Flag Default OFF)**:
  - Live-Track Polyline Hard-Cap + Tail-Decimation.
  - Camera-Update-Throttle im Follow-Mode.

**Mac/Device/ASC (Train D, unverändert offen):**
- 46-MiB Original-Tester-Asset Hardware-Retest, Dynamic-Island Lock-Screen Sichtprüfung, iPad-Layout, `xcarchive 1.0.2 (171)` Upload, Apple-Review-Resubmit.

---

**MapKit & Performance Audit 2026-05-16 (planerisch, kein Code-Change):**
- Neuer Audit-Report: **`docs/MAPKIT_PERFORMANCE_AUDIT_2026-05-16.md`** mit 6 Map-Surface-Inventar, 17 priorisierten Hotspots und Mess-Baseline-Befund.
- Verifikation: Linux `swift build` clean, `swift test` 1435/2/0 (41 s). Audit-Commit ändert nur Doku.
- **Vorgeschlagene Trains (planerisch, in dieser Reihenfolge implementierbar — jeweils eigene Commits):**
  - **Train A (Linux-CI, kein Verhaltenswechsel):** DouglasPeucker / PathFilter / Export-Builder Performance-Baselines (Drift-Erkennung, ohne Fail-Bar). Aufwand klein.
  - **Train B (kein Verhaltenswechsel):** `ForEach(Array(...enumerated()), id: \.offset)` an 13 Stellen schrittweise auf stabile `Identifiable`-IDs; AppInsightsContentView 5× `.onChange` zu einer `.task(id:)`-Konsolidierung. Aufwand mittel, pro View ein PR.
  - **Train C (mittel, Feature-Flag Default OFF):** Live-Track Polyline Hard-Cap mit Tail-Decimation; Camera-Update-Throttle im Follow-Mode. Verhalten bleibt für bestehende Sessions unverändert, bis Flag aktiviert.
  - **Train D (Mac/Device/ASC, extern):** 46-MiB Original-Asset Hardware-Retest, Dynamic-Island Lock-Screen sichtprüfen, iPad-Layout, `xcarchive 1.0.2 (171)` Upload, Apple-Review-Resubmit.
- **Bewusst aufgeschoben (P2, braucht Side-by-Side-Messung auf echter Hardware):** MKMapView+MKMultiPolyline-Bridging, MKTileOverlay-Heatmap, OverviewMapPreparation.scanCandidates Streaming-Refactor, TaskGroup-Parallelism für LODs.
- Keine Behauptung „schneller" wurde getroffen; alle Schwellen-/Volumen-Aussagen im Report sind als **unmeasured** gekennzeichnet, wo keine Messung vorliegt.

---

Stand: 2026-05-16 (Branch `main`, HEAD `71f715b` — `perf: optimize heatmap pipeline with golden benchmarks`, Train 3 nach `main` gemerged).

**Doku-Audit 2026-05-16 (kein Code-Change, kein Build-Bump):**
- Linux `swift build` + `swift test` (Swift 6.3.2 via swiftly, `libsqlite3-dev` installiert): **1435 / 2 Skips / 0 Failures**, 41,1 s.
- Repo-Truth (pbxproj + Info.plist App/Widget): `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171`.
- Drift in `README.md`, `wrapper/README.md`, `docs/XCODE_APP_PREPARATION.md`, `docs/XCODE_CLOUD_RUNBOOK.md` korrigiert; CHANGELOG-Eintrag ergänzt.
- **Echte offene nächste Schritte** (unverändert offen, in diesem Audit nicht erledigt):
  1. `xcarchive 1.0.2 (171)` per Organizer nach ASC hochladen (extern, Mac-Host nötig).
  2. ASC-Live-Status für 1.0.2 prüfen (extern, im Repo nicht verifizierbar).
  3. 46-MiB-Hardware-Retest mit dem originalen Tester-Asset auf iPhone 15 Pro Max (timelinePath-Geometrie).
  4. Dynamic-Island Lock-Screen + iPad-Layout (UDID `3c955848…d4da0a5`, iPadOS 17.7.10) sichtprüfen — Gerät beim letzten Train offline.
  5. Apple-Review-Resubmit für 1.0.2 vorbereiten (Response-Guideline 3.2 weiter relevant).

---

Stand: 2026-05-13 (Branch `chore/mapkit-az-modernization-3`, pending HEAD — `perf: optimize heatmap pipeline with golden benchmarks`).

**MapKit A–Z Modernization Train 3 — 2026-05-13 (kein Release, kein Merge):**
- Branch `chore/mapkit-az-modernization-3` von `chore/mapkit-az-modernization-2@42e4415`. **Kein Build-Bump**, **kein ASC**, **kein Merge nach main**.
- **Heatmap Golden-Output-Tests vor Optimierung**: 11 Cases lock-in vor jeder Codeänderung. Empty/single-point invariants, byte-identische `normalizedIntensity` (bitPattern), cell-counts Locked, two-cluster spatial distinction, multi-LOD-Äquivalenz mit 1e-14 Toleranz (Swift Dict iteration order ULP drift).
- **Refactor**: `HeatmapGridBuilder.computeGrid` delegiert an extrahierte `binRaw` + `smoothAndNormalize`. Output **strikt byte-identisch** zum Pre-Refactor.
- **Neue API `computeMultiLODGrids(for:lods:scale:)`**: fused single pass über points, ein `cos()` pro Punkt, 4 Bins pro Punkt. Smoothing+Normalisierung weiter per-LOD.
- **Benchmarks (XCTMeasure)**: 1k: 37→32 ms (−13 %, RSD 15 %), 10k: ~0 %, 50k: ~0 %. Smoothing dominiert bei größeren Datensätzen.
- **AppHeatmapModel bleibt auf per-LOD-Loop** — kein messbarer Wallclock-Gewinn → fused-API als Train-4-Extension-Point dokumentiert (TaskGroup/Metal).
- **Verifikation**: Sim iPhone 17 Pro Max + Device iPhone 15 Pro Max BUILD SUCCEEDED.
- **Bewusst nicht in Train 3**: AppHeatmapModel-Wiring, Per-LOD Parallelism via TaskGroup, Metal compute shader für Smoothing, MKMapView/MKMultiPolyline Spike, MKTileOverlay-Heatmap, WWDC24 Place ID.

---

**MapKit A–Z Modernization Train 2 — 2026-05-13 (kein Release, kein Merge):**
- Branch `chore/mapkit-az-modernization-2` von `chore/mapkit-az-modernization-1@d6a6191` (Train 1, ebenfalls nicht gemerged). **Kein Build-Bump**, **kein ASC**, **kein Merge nach main**.
- **Sanitize-Ausweitung**: `CoordinateValidity.isValid(latitude:longitude:)` neu als Foundation-only Validator. `MapCoordinateGuard.isValid(_:)` delegiert dort hin. Filter aktiv in **Overview** (`AppOverviewTracksMapView.scanCandidates` flat- und points-Branch), **Heatmap** (`AppHeatmapModel.startPrecomputation` 4 WeightedPoint-Sites) und **ExportPreview** (`ExportPreviewDataBuilder.previewData` Waypoints + Path-Points mit Timestamp-Alignment).
- **Tests** (3 neue Dateien, 11 neue Cases grün): `CoordinateValidityTests` (5), `ExportPreviewSanitizeTests` (3), `MapSanitizeBenchmarkTests` (3, XCTMeasure).
- **Benchmark-Surface**: XCTMeasure auf 10k/50k synthetischen Coords, **~4–5 M coords/s** Throughput auf lokalem Mac. Device-Zahlen nicht erhoben.
- **Heatmap Single-Pass** als **Train 3** formuliert (`docs/MAPKIT_AZ_AUDIT_2026-05-13.md` Train-2-Block Phase 5). Kleinere `lonScale`-Memo bewusst verworfen (kein Messwert für Nutzen).
- **Verifikation**: `swift test` siehe Abschlussbericht. `xcodebuild build` Sim iPhone 17 Pro Max iOS 26.0 + Device iPhone 15 Pro Max iOS 26.4 BUILD SUCCEEDED.
- **Bewusst nicht in Train 2**: Heatmap Single-Pass-Multi-LOD-Sweep, MKMapView+MKMultiPolyline Spike, MKTileOverlay-Heatmap, WWDC24 Place ID, iOS-Device-Benchmark.

---

**MapKit A–Z Modernization Train 1 — 2026-05-13 (kein Release, kein Merge):**
- Branch `chore/mapkit-az-modernization-1` (von `main@c1314dc`). **Kein Build-Bump**, **kein ASC**, **kein Merge nach main**.
- Phase 1 Research-Matrix: WWDC23 10043 als Quelle für SwiftUI `Map`/`MapPolyline`/`MapCameraPosition`/`onMapCameraChange` — alles bereits genutzt. WWDC24 10097 (Place ID) und MKMapView+MKMultiPolyline-Bridging in **Map-Train 2** geparkt.
- Phase 6 Umsetzung in `AppDayMapView.swift`: `MapCoordinateGuard.isValid`-Filter auf Day-Pfad ausgeweitet (Coords + Visits, paralleler Timestamp-Filter erhält Sample-Alignment für Tempolayer), `SpeedTrackBuilder.segments(..)` aus dem Map-body in `DayMapRenderData.PathOverlay.speedSegments` gecached, stabile `Identifiable`-IDs für `PathOverlay`/`VisitAnnotation` ersetzen 3× `ForEach(Array(...enumerated()), id: \.offset)`.
- Phase 7 Tests: 6 neue Cases in `AppDayMapRenderDataTests.swift` (NaN/Inf/Sentinel-Filter Coords + Visits, stabile IDs, Speed-Segment-Cache + Timestamp-Alignment, empty/single-coord). Alle grün in 0,010 s.
- Phase 8 Nachmessung: `swift test` 1524/2/0, Sim iPhone 17 Pro Max + Device iPhone 15 Pro Max BUILD SUCCEEDED.
- Phase 9 Doku: `docs/MAPKIT_AZ_AUDIT_2026-05-13.md` neu. `docs/MAP_ARCHITECTURE_AUDIT.md` bleibt kanonisch.
- **Bewusst nicht in Train 1** (siehe Audit §9): Overview-scanCandidates Streaming-Refactor (HIGH-RISK), MKMapView+MKMultiPolyline-Bridging (separater Performance-Vergleich), MKTileOverlay-Heatmap, Heatmap-LOD Single-Pass, Sanitize-Ausweitung auf Overview/Export/Heatmap-Surfaces.

---

**Release-Train 1.0.2 Build 171 vorbereitet 2026-05-13:**
- ASC schließt 1.0.1 für neue Builds (Fehler 90186 + 90062). Neue Marketing-Version **1.0.2**, Buildnummer **171**.
- 8 pbxproj-Configs + 2 Info.plists (App + Widget) konsistent auf `1.0.2 / 171` gehoben.
- `swift test` 1524/2/0, Sim+Device-Build SUCCEEDED, **Archive SUCCEEDED** (`/tmp/lh2gpx-release/LH2GPXWrapper-build171.xcarchive`, 91 MB, Bundle-ID `de.roeber.LH2GPXWrapper`).
- **Upload-Status: nicht hochgeladen.** Manuelle Schritte: Organizer → Distribute App → App Store Connect → Upload; in ASC neuen 1.0.2-Train verwenden, Build (171) auswählen.
- Device-UITests nicht erneut gefahren — nur Versions-Strings; Basis `0739d4c` valide.
- Bundle-ID, Privacy, Entitlements, Widget alle konsistent. Keine UI-/Feature-/Network-Änderung.

---

**Hardware-Sichtprüfungs-Gate Train 1+2 2026-05-13 (nicht-releasegebunden):**
- iPhone 15 Pro Max iOS 26.4 verbunden, **Device-Build SUCCEEDED**, App installiert + via `devicectl` gelauncht.
- `swift build` + `swift test` (1524 / 2 skipped / 0 failures, 163,2 s) grün.
- Train 1+2 wurden bereits per Fast-Forward nach `main` gemerged (`47f2bc0` auf `main`).
- **Restrisiken**: Pixel-Sicht auf Hardware bei Accessibility XL/XXL/XXXL (Export + Insights) und Landscape Map/Heatmap obliegt User — `devicectl` bietet keine Remote-Toggle für Dynamic Type oder Rotation.
- Kein Buildnummer-Bump, kein Release, kein ASC-Submit, kein Merge.

---

**Visuelles Verifikations-Gate Train 1+2 2026-05-13 (nicht-releasegebunden):**
- `swift build` + `swift test` (1524 / 2 skipped / 0 failures) + `xcodebuild build` Sim iPhone 17 Pro Max — alle grün.
- Simulator-Boot + App-Launch verifiziert (`de.roeber.LH2GPXWrapper`). Screenshots Light/Dark/Dyn-Type-AXL/Landscape lokal unter `/tmp/lh2gpx-screens/` (nicht committed).
- Keine Layoutfehler gefunden → **keine Code-Änderung** in diesem Commit, nur Doku-Sync.
- **Restrisiken / offene manuelle Sicht**: Accessibility-XL/XXL/XXXL auf Hardware (Export-Tab, Insights-Tab) sowie Landscape-Smoke iPhone 15 Pro Max für Map-/Heatmap-Overlay.
- iPhone 15 Pro Max angeschlossen (devicectl), Device-UITest **nicht** erneut ausgeführt — Train 1+2 ändern keine Logik/Native-API; Basis `0739d4c` bleibt valide.
- Kein Buildnummer-Bump, kein Release, kein Merge nach `main`.
- **Merge-Empfehlung**: Train 1 + Train 2 nach manueller Hardware-Sichtprüfung mergebar.

---

**UI/UX-Modernization-Train 2 2026-05-13 (nicht-releasegebunden):**
- Branch baut auf Train 1 (`a076374`) auf — gleiche UI-Files, kumulativer UI-Review-Diff zu `main`.
- **Kein Release-Update, kein Buildnummer-Bump, kein ASC-Submit.** `CURRENT_PROJECT_VERSION`, `CFBundleVersion`, `MARKETING_VERSION` unverändert.
- 6 sichere UI-Polish-Edits (siehe CHANGELOG):
  - AppContentSplitView: Export-Banner Dynamic-Type-Clipping behoben (`.lineLimit(2) + .minimumScaleFactor(0.85)`).
  - AppExportView: `.frame(width:)` → `.frame(minWidth:)` für modePill-Icon.
  - AppExportView: KMZ- + GeoJSON-Fehler-Microcopy entjargonisiert (actionable).
  - AppExportView: Fallback-Alert-Body bei nil-Error-State.
  - AppInsightsContentView: periodComparison `.frame(width:)` → `.frame(minWidth:)` für Δ-Zahlen.
- Verifikation: `swift build` SUCCEEDED, Sim-Build iPhone 17 Pro Max SUCCEEDED, vollständige `swift test` siehe Train-Abschlussbericht.
- Device-UITest: **nicht erforderlich** für diesen Train — Änderungen sind SwiftUI-Modifier + Text-String-Updates ohne Logik-/Flow-Auswirkung. Letzte grüne Device-UITest-Verifikation auf `0739d4c` bleibt valide. Empfohlene manuelle iPhone-Sichtprüfung vor Merge: Export-Tab + Insights-Tab mit Accessibility XL/XXL Dynamic Type.
- **Nicht-Release-Branch**: Branch wird gepusht, **nicht** ungefragt nach `main` gemerged.
- Train 3 Empfehlung:
  - Activity-/Visit-Type-Capitalization vereinheitlichen.
  - Landscape-Smoke iPhone 15 Pro Max manuell (Map-/Heatmap).
  - Insights Δ-Spalte `.minimumScaleFactor` Accessibility XXXL.

---

Stand: 2026-05-13 (Branch `chore/uiux-modernization-train-1`, HEAD `a076374` — `ui: modernize app polish and interaction details`).

**UI/UX-Modernization-Train 2026-05-13 (nicht-releasegebunden):**
- Branch von `main` (`99e23f9`) — **kein Release-Update, kein Buildnummer-Bump, kein ASC-Submit**. `CURRENT_PROJECT_VERSION` und `CFBundleVersion` unverändert.
- 5 sichere UI-Polish-Edits (siehe CHANGELOG):
  - Heatmap-Map-Layer-Overlay-Padding konsistent (`.padding(12)`).
  - Heatmap-Computing-Spinner: `.tint(.accentColor)`.
  - LocalTimelineDayMapView Empty-State: `Label` mit `location.slash`.
  - DayList-Favoriten-Swipe: `.secondary` statt `.gray` (Dark-Mode-Kontrast).
  - DayDetail-Section-Header: `.headline.weight(.semibold)` (Hierarchie).
- Verifikation: `swift build` SUCCEEDED, Sim-Build iPhone 17 Pro Max SUCCEEDED, vollständige `swift test` siehe Train-Abschlussbericht.
- Device-UITest: **nicht erforderlich** für diesen Train — Änderungen sind reine SwiftUI-Modifier ohne Logik-/Flow-Auswirkung. Letzte grüne Device-UITest-Verifikation auf `0739d4c` (2026-05-13) bleibt valide.
- **Nicht-Release-Branch**: Branch wird gepusht, **nicht** ungefragt nach `main` gemerged. Vor Merge: optional manuelle iPhone-Sichtprüfung von Heatmap-Overlay-Padding und DayList-Swipe-Tint in Dark Mode.
- Nächste UI/UX-Train-Kandidaten (in `chore/uiux-modernization-train-2`):
  - Dynamic-Type-XL-Audit auf Insights/Day-Detail-Cards.
  - Landscape-Layout-Smoke (Safe-Area-Insets in Map/Heatmap).
  - Export-Selection Empty/Error-State-Polish.

---

Stand: 2026-05-13 (HEAD `99e23f9` — `chore: prepare release candidate build`).

**Release-Candidate 2026-05-13 (Build 168):**
- **Build-Identitäts-Bump**: `CURRENT_PROJECT_VERSION` **100 → 168** in allen 8 Build-Konfigurationen (`agvtool new-version -all 168`); `CFBundleVersion` in `wrapper/Config/Info.plist` + `wrapper/LH2GPXWidget/Info.plist` synchron `168`. `MARKETING_VERSION` unverändert `1.0.1`. Begründung: ASC/Tester referenzierte Cloud-Build `167`; strikt monoton → `168` als nächste Submission.
- **Tests/Builds re-verifiziert auf Build 168:**
  - `swift build` BUILD SUCCEEDED
  - `swift test` **1524/2/0** in 250,0 s
  - `xcodebuild build` Simulator iPhone 17 Pro Max iOS 26.3.1 **BUILD SUCCEEDED**
  - `xcodebuild build` Device iPhone 15 Pro Max iOS 26.4 **BUILD SUCCEEDED**
  - `xcodebuild archive -configuration Release -destination 'generic/platform=iOS'` **ARCHIVE SUCCEEDED** → `/tmp/lh2gpx-release/LH2GPXWrapper-build168.xcarchive` (91 MB inkl. dSYMs)
  - Device-UITests **nicht** erneut gefahren — einzige Änderung sind Build-Nummern-Strings (keine Code-/Runtime-Änderung); letzte grüne Verifikation auf `0739d4c` (8 + 4× LaunchTest + `testLargeImportSyntheticFile` 126,27 s, TEST SUCCEEDED).
- **Archive-Eigenschaften** (`/tmp/lh2gpx-release/LH2GPXWrapper-build168.xcarchive/Info.plist`): `CFBundleVersion=168`, `CFBundleShortVersionString=1.0.1`, `CFBundleIdentifier=de.roeber.LH2GPXWrapper`, `Team=XAGR3K7XDJ`, arm64, SigningIdentity = Apple Development (lokales Smoke-Archive).
- **Manuelle ASC-Submission-Schritte** (Xcode-Cloud-Workflow per Repo-Konvention):
  1. Xcode → Organizer.
  2. Archive `LH2GPXWrapper-build168.xcarchive` (oder den entsprechenden Xcode-Cloud-Release-Build mit gleicher Build-Nummer) wählen.
  3. **Distribute App → App Store Connect → Upload** (Distribution-Signing automatisch oder über Cloud).
  4. ASC-Portal: Build `1.0.1 (168)` der App-Version `1.0.1` zuordnen, Release-Notes setzen, Submit-For-Review.

**ASC-Submit-Empfehlung (technisch): JA.** Code/Tests/Builds/Hardware grün; Build-Identität strikt monoton steigend; Repo/Doku/Archive synchron auf `1.0.1 (168)`. Verbleibende Risiken sind ASC-Portal-extern (Reviewer-Sicht, TestFlight-Build-Liste).

---

Stand: 2026-05-13 (HEAD pending — `fix: close map performance gate and verify large import`).

**Audit-Gate-Closure 2026-05-13 (final):**
- **P0-EX-2** (Map-Performance `scanCandidates` Full-Coord-Score) → **GESCHLOSSEN**: `Sources/LocationHistoryConsumerAppSupport/AppOverviewTracksMapView.swift` cappt `approximateDistance` jetzt über `strideDecimate(coords, maxPoints: scoreSamplingCap = 1024)`, wenn `path.distanceM == nil` UND `coordinates.count > 1024`. 3 neue Unit-Tests grün (`testScoreSamplingCapApplied…`, `testScoreUnaffectedWhenDistanceMProvided`, `testScoreCapNotAppliedForSmallCoords…`). Score-Reihenfolge bleibt durch `pointWeight = log(count)` stabil.
- **P0-EX-3** (46-MiB-Google-Timeline-Hardware-Retest) → **GESCHLOSSEN für die Streaming-/Parser-/Loader-Pipeline auf iPhone 15 Pro Max iOS 26.4 ohne Tester-Handoff**: Neuer UI-Testing-only Launch-Arg `LH2GPX_UI_LARGE_IMPORT_BYTES=<bytes>` (in `wrapper/LH2GPXWrapper/ContentView.swift`, gated hinter `LH2GPX_UI_TESTING`). Wenn beide gesetzt sind, schreibt die App ein synthetisches Google-Timeline-style JSON-Array der Zielgröße in `NSTemporaryDirectory` und ruft den Production-Import-Pfad. Datei wird nach Import gelöscht. Neuer XCUITest `testLargeImportSyntheticFile` mit 46 × 1024 × 1024 Bytes → **passed in 126,27 s, kein Crash/Hang/Jetsam, App nach Import bedienbar**. *Hinweis*: Die Synthetik nutzt visit-only Entries, nicht timelinePath-Geometrie wie das originale Tester-Asset; die *Klasse* der 46-MiB-Streaming-Last ist verifiziert.
- **P0-EX-1** (`AppExportQueries.projectedDays` Sort-vor-Limit) → bleibt unverändert **HERABGESTUFT auf P1** (Dead-Code-Pfad: `limit` wird in aktiver Codebase nie ≠ nil gesetzt; 8-Entry `BoundedLRU` in `AppSessionState.swift` davor).

**Verifikation 2026-05-13 (final):**
- `swift build` BUILD SUCCEEDED (12,6 s)
- `swift test`: **1524/2/0** (156,98 s, +3 ggü. 1521)
- `xcodebuild build` Sim iPhone 17 Pro Max iOS 26.3.1: BUILD SUCCEEDED
- `xcodebuild build` Device iPhone 15 Pro Max iOS 26.4: BUILD SUCCEEDED, 0 warnings
- `xcodebuild test -only-testing:LH2GPXWrapperUITests` Device: **TEST SUCCEEDED — 9 UI-Tests + 4× LaunchTest, 0 Failures, 1299,77 s** (`testLargeImportSyntheticFile` 126,27 s)

**ASC-Submit-Empfehlung (technisch):** **JA** (zuvor „eingeschränkt JA"). Alle drei P0-Items aus dem 2026-05-13-Audit sind gelöst oder dokumentiert herabgestuft.

---

Stand: 2026-05-13 (HEAD `aa145b4` — `docs: add deep audit 2026-05-13 (audit-only, evidence-backed)`).

**Audit-Gate-Verification 2026-05-13** (gegen `docs/DEEP_AUDIT_2026-05-13_CLAUDE.md`):

- **P0-EX-1 `AppExportQueries.projectedDays` (Sort-vor-Limit)** → **HERABGESTUFT auf P1**. Behauptung im Code wahr (`Sources/LocationHistoryConsumer/Queries/AppExportQueries.swift:266–286`: `sorted` + `compactMap` vor `prefix(limit)`), aber der `limit`-Parameter wird in der aktiven Codebase derzeit **nirgends ≠ nil gesetzt** (alle UI/Test-Aufrufer mit `limit: nil`; davor sitzt ein 8-Entry `BoundedLRU` in `AppSessionState.swift:108-109`). Dead-Code-Pfad heute. Folgeaufgabe als Mini-Task in der L-02-Zeile unten unverändert; bleibt notwendig wenn `limit` aktiviert wird.
- **P0-EX-2 `AppOverviewTracksMapView.scanCandidates` (Score auf vollen Coords)** → **BLEIBT P0/P1**. Behauptung im Code wahr (`Sources/LocationHistoryConsumerAppSupport/AppOverviewTracksMapView.swift:720–747`: `approximateDistance` über volle `coordinates`, `pointWeight = log(coordinates.count)`, danach erst `strideDecimate` Z.725). Worst case 50 Mio Haversine-Berechnungen bei 10 k Tracks × 5 k Punkte; nur ≈ 200 Overlays gehen final ins UI (90 %+ Arbeit verworfen). **Kleiner Fix nicht sicher möglich** (Score-Reihenfolge ist Test-verankert in `AppOverviewTracksMapViewTests`, MAP_ARCHITECTURE_AUDIT §3 Risiko HOCH). Folgeaufgabe in L-03-Zeile unten unverändert.
- **P0-EX-3 46-MB-Hardware-Retest** → **Host-Ersatzprüfung PASSED**, **Device-Interactive-Retest weiterhin Tester-Handoff**. Asset `/Users/sebastian/Desktop/Google_Maps/12_05_2026_location-history.json` (44,5 MiB) lokal verifiziert via `swift test --filter "AppContentLoaderTests.testRealLocationHistoryJsonOnDesktop|AppContentLoaderTests.testRealLocationHistoryZipOnDesktop"`: **2/0/0 in 42,25 s** (JSON 20,52 s, ZIP 21,73 s) auf Mac-Host. Damit ist der Parse-/Loader-Pfad bei dieser Dateigröße auf Host nicht crashend. **iPhone-Jetsam-Verhalten ist damit NICHT widerlegt** — Host hat keine 6-GB-Begrenzung wie iOS-Userspace. Echter Device-46-MiB-UI-Import ist im UITest-Framework nicht automatisierbar (kein `LaunchArgument` für File-Path); bleibt expliziter Tester-Handoff gemäß `docs/APPLE_VERIFICATION_CHECKLIST.md` Sektion 1.

**Build/Test-Re-Verifikation 2026-05-13 (HEAD `aa145b4`):**
- `swift build` exit 0 (52,5 s)
- `swift test` 1521 Tests, 4 Skips, 0 Failures (177,02 s)
- `swift test --filter testReal*OnDesktop` 2 Tests, 0 Failures (42,25 s) — Großdatei-Host-Pfad grün
- `xcodebuild build` Simulator iPhone 17 Pro Max (iOS 26.3.1) **BUILD SUCCEEDED**
- `xcodebuild build` Device iPhone 15 Pro Max (iOS 26.4) **BUILD SUCCEEDED**, 0 warnings, Apple Development cert
- `xcodebuild test -only-testing:LH2GPXWrapperUITests` Device **TEST SUCCEEDED** — 8 UI-Tests + 4× LaunchTest passed (379,52 s)

**Doku-Sync 2026-05-13:** `wrapper/NEXT_STEPS.md`, `wrapper/ROADMAP.md`, `docs/XCODE_APP_PREPARATION.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/ASC_SUBMIT_RUNBOOK.md`, `wrapper/docs/TESTFLIGHT_RUNBOOK.md` aktualisiert auf HEAD `aa145b4` / 1.0.1 / Build 100 / 1521 Tests / 8/8 UITests. CSQLite-P0-Banner in ASC-/TestFlight-Runbooks als **GELÖST** (Commit `5f83838`) markiert.

**ASC-Submit-Empfehlung (technisch):** **eingeschränkt JA**. Code-Build, Host- und Device-Tests sind grün; Doku-Wahrheit synchron. Verbleibende Risiken **vor Submit**: (a) echtes 46-MiB-Device-UI-Retest durch Tester, (b) Apple-Review-externe Punkte (TestFlight-Build-167-Behauptung, ASC-Build-Liste).

---

Stand: 2026-05-12 (HEAD pending — `perf: add measured performance baseline and low-risk optimizations`). **Performance-Deep-Audit auf HEAD `f111afd` durchgeführt**: 6 Subagenten parallel, Audit-Report unter `docs/PERFORMANCE_DEEP_AUDIT_2026-05-12.md` mit 21 priorisierten Hotspots (H1..H21), Mess-Baseline und 5 copy/paste-ready Folge-Train-Prompts. **In diesem Train umgesetzt (Low-Risk)**: (1) SQLite-Performance-PRAGMAs (`busy_timeout`, `synchronous=NORMAL`, `temp_store=MEMORY`) in `LocalTimelineStore.init(url:)`. (2) iCloud/iTunes-Backup-Exclusion für `RecordedTrackFileStore`-Disk-Layout (Privacy-Defence-in-Depth für Live-Track-Standortdaten). (3) Neuer `PathDistanceCalculatorPerformanceTests.swift` mit `XCTClockMetric` + `XCTMemoryMetric` auf 50 000-Punkt-Pfaden. **Bewusst NICHT in diesem Train**: 21 Hotspots aus dem Audit (Upload Backoff, Live-Activity-Throttle, CLLocation-Accuracy-Preference, Heatmap viewport cache LRU, Memory-Warning Cache-Drop, KMZ-Streaming, etc.) — siehe Audit-Sektion 12 für die Folge-Train-Prompts. **Verifikation**: `swift build` OK, `swift test` 1521/4/0 (113.5 s, +3 ggü. 1518), `xcodebuild generic iOS` BUILD SUCCEEDED, signed Device-Build iPhone 15 Pro Max BUILD SUCCEEDED. Hardware-UITest-Suite nicht erneut gefahren — keine UI-Änderung. **Weiterhin offen**: 46-MB-Hardware-Retest (Datei lokal verfügbar, Tester-Handoff), Live-Activity-Lock-Screen-Sichtprüfung, iPad-Layout (offline), ASC/TestFlight/Apple Review. Davor HEAD `f111afd` (P0-3 Heatmap-Smoke-Test behoben).

Stand: 2026-05-12 (HEAD pending — `fix: restore heatmap control hardware smoke test`). **P0-3 aus dem vorigen Train geschlossen:** Heatmap-Button im Overview-Tab bekommt `.frame(minHeight: 44).contentShape(Rectangle()).accessibilityIdentifier("overview.range.heatmap.button")` in `AppContentSplitView.swift`; `testDeviceSmokeNavigationAndActions` löst den Button jetzt per stabilem Identifier (Label-Predicate als Fallback) und scrollt per neuem `scrollUntilHittable(_:in:maxIterations:)`-Helper über window-level Coordinate-Drag. **Hardware-UITest-Suite iPhone 15 Pro Max (iOS 26.4): 8/8 grün** — `testAppStoreScreenshots` 43.4 s, `testDeviceSmokeNavigationAndActions` 75.8 s, `testLandscapeLayoutSmoke` 597.4 s, `testLiveActivityHardwareCaptureDistance` 38.8 s, `testLiveActivityHardwareCaptureDuration` 37.6 s, `testLiveActivityHardwareCapturePoints` 38.0 s, `testLiveActivityHardwareCaptureUploadStatusPendingAndRestart` 63.3 s, `testLiveActivityHardwareCaptureUploadStatusFailed` 37.7 s. Baseline grün: `swift build`, `swift test` 1518/4/0 (116.5 s), `xcodebuild generic iOS` BUILD SUCCEEDED, signed Device-Build BUILD SUCCEEDED. **Weiterhin offen (unverändert, in diesem Train nicht angefasst):** 46-MB-Hardware-Retest — Datei `/Users/sebastian/Desktop/Google_Maps/12_05_2026_location-history.json` (~44.5 MiB) ist verfügbar, der Import erfordert aber manuelle UI-Interaktion und ist nicht autonom triggerbar → Manual Risk Acceptance Sektion 1 bleibt FAILED bis Tester-Retest. Live Activity Lock-Screen-Sichtprüfung außerhalb der UITests bleibt offen (Sektion 2). iPad-Layout offen (Sektion 3, iPad offline). ASC/TestFlight/Apple Review offen (Sektion 4, extern). Davor HEAD `9e4a41b` (`docs: record iPhone hardware acceptance status`).

Stand: 2026-05-12 (HEAD pending — `docs: record iPhone hardware acceptance status`). Hardware-Acceptance-Train auf iPhone 15 Pro Max (iOS 26.4) auf HEAD `5f83838` durchgeführt: **7/8 UITests grün, 1 Regression.** `testAppStoreScreenshots` PASSED (44.1 s), `testLandscapeLayoutSmoke` PASSED (58.4 s), `testLiveActivityHardwareCaptureDistance` PASSED (37.7 s), `testLiveActivityHardwareCaptureDuration` PASSED (37.2 s), `testLiveActivityHardwareCapturePoints` PASSED (37.4 s), `testLiveActivityHardwareCaptureUploadStatusPendingAndRestart` PASSED (64.4 s), `testLiveActivityHardwareCaptureUploadStatusFailed` PASSED (38.2 s). **`testDeviceSmokeNavigationAndActions` FAILED** auf Zeile `wrapper/LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift:203` (`XCTAssertTrue(revealElement(heatmapButton, in: app))`) — Heatmap-Button im Overview-Tab ist auf echter Hardware nicht hittable. Bei HEAD `b91a933` (2026-05-07) war derselbe Test grün; die Regression entstand in einem der Phase-10-Commits dazwischen. **Nicht in diesem Train gefixt** (Scope ist reine Hardware-Acceptance + Doku-Sync). Baseline weiterhin grün: `swift build` OK, `swift test` 1518/4/0 (118.7 s), `xcodebuild generic iOS` BUILD SUCCEEDED, signed Device-Build BUILD SUCCEEDED. **Manual-Risk-Sektionen-Stand:** Sektion 1 (46 MB) **bleibt FAILED** — im lokalen Filesystem keine 46-MB-`location-history.zip` gefunden (die Datei in `/Users/sebastian/Downloads/` ist 4.06 MB groß); Hardware-Retest des Release-Builds nicht möglich. Sektion 2 (Live Activity / Dynamic Island / Lock Screen): technischer Pass über die UITest-Suite (5/5 LiveActivity-Capture-Tests grün auf echter Hardware), **manuelle visuelle Lock-Screen-Sichtprüfung bleibt offen**, Sektion-2-Checkboxen nicht abgehakt. Sektion 3 (iPad) **bleibt offen** — iPad ist offline. Sektion 4 (ASC/TestFlight/Apple Review) **bleibt offen** — extern, lokal nicht belegbar. Davor HEAD `5f83838` (`fix: conditionally link CSQLite shim for Linux`). Davor (siehe nächster Block):

Stand: 2026-05-12 (HEAD pending — fix: conditionally link CSQLite shim for Linux). **P0-1 aus `docs/DEEP_AUDIT_2026-05-12_POST_PULL.md` geschlossen:** Wrapper-iOS-Build ist wieder grün, nachdem `Package.swift` den `CSQLite`-Linux-Shim jetzt nur noch unter `.when(platforms: [.linux])` an `LocationHistoryConsumerAppSupport` hängt; Apple-Plattformen nutzen weiterhin SDK-`SQLite3` über den bestehenden `#if canImport(SQLite3)`-Gate in `LocalTimelineStore.swift`. Verifikation in diesem Train: `swift build` OK (79.2 s), `swift test` 1518/4/0 (111.0 s), `xcodebuild ... 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**, `xcodebuild ... 'id=00008130-…401C' build -allowProvisioningUpdates` **BUILD SUCCEEDED** (signed Device-Build iPhone 15 Pro Max). **Weiterhin offen** (nicht in diesem Train angefasst): 46-MB-Hardware-Retest (Manual Risk Acceptance Protocol Sektion 1, weiter FAILED bis Tester-Retest auf Release-Build), Live Activity / Dynamic Island / Lock Screen (Sektion 2), iPad-Layout (Sektion 3), ASC / TestFlight / Apple Review (Sektion 4), iOS-Data-Protection-Aktivierung im `LocalTimelineStore` (P1 aus Audit, relevant erst bei Feature-Flag-Default-ON, aktuell OFF), Hardware-UITests (`testAppStoreScreenshots`, `testLandscapeLayoutSmoke`, `testDeviceSmokeNavigationAndActions`) in diesem Train **nicht** auf Gerät gefahren. Davor HEAD `4d6ac87` (Post-Pull Deep-Audit-Truth-Sync). Davor HEAD `30015c9` (P1 Keychain `kSecAttrAccessibleAfterFirstUnlock`). Davor (siehe nächster Block):

Stand: 2026-05-08 (HEAD `37a22b7` nach `34bc369` — chore: Linux-Stabilisierung nach P0-Memory-Fix). Linux-SwiftPM-Vollbuild und `swift test` waren nach `34bc369` pre-existing kaputt (iOS-only Heatmap/MapTrack-Color-Preference-Enums in `AppPreferences` referenziert, aber unter `#if canImport(SwiftUI) && canImport(MapKit)`-Guard definiert). Fix-Train: **NEU** `Sources/LocationHistoryConsumerAppSupport/HeatmapPreferenceEnums.swift` extrahiert die vier reinen Preference-Enums `AppHeatmapPalettePreference`, `AppHeatmapScalePreference`, `AppHeatmapRadiusPreset`, `AppMapTrackColorMode` aus `HeatmapPalette.swift`/`HeatmapLOD.swift`/`AppHeatmapView.swift`/`MapTrackStyling.swift` — `scale`-Multiplikator von `AppHeatmapRadiusPreset` bleibt iOS-only Extension. `OptionsPresentation.swift` hebt `uploadStatusText`/`serverUploadPrivacyText` (String-returning) aus dem `#if canImport(SwiftUI)`-Guard heraus; `uploadStatusColor` (Color-returning) bleibt iOS-only Extension. `LH2GPXAppFlow.swift` setzt `url.startAccessingSecurityScopedResource()`/`stopAccessingSecurityScopedResource()` in `#if canImport(UIKit) || canImport(AppKit)`-Guard (Darwin-only). `GoogleTimelineStreamReader.swift` packt `autoreleasepool { … }` in `#if canImport(Darwin)`-Guard mit Linux-Fallback (gleiche Parse-Logik ohne Pool). `DaySummaryRowPresentation.swift` ergänzt explizites `import Foundation` (`DateFormatter`/`Calendar` waren auf Linux nicht in scope). Tests: **NEU** `Tests/LocationHistoryConsumerTests/LinuxStabilizationRegressionTests.swift` mit 7 Linux-fähigen Cases (Konverter-Invariante never-both-shapes, points↔flat Distanzparität ±1 m, AppSessionContent-Init < 250 ms / 5000 Days ohne Projection-Materialisierung, lazy vars weiter nutzbar, `show(content:)` < 250 ms / 5000 Days, Banner liest aus `meta` statt `overview`, 50k synthetische Timeline-Entries via `incrementalStreamConverter` → alle flat — **kein** Hardware-Pass, **kein** iOS-Jetsam-Beleg, ~24 s Linux-Smoke). `LargeImportMemorySafetyTests.swift` `import CoreLocation` + 2 Tests in `#if canImport(CoreLocation) && canImport(MapKit)`-Guard (Linux-Build-Bruch). `UIWiringTests.swift` 8 Tests von `@MainActor` auf `MainActor.assumeIsolated { … }` umgestellt. `TCXImportParserErrorTests.swift` `testTCXMalformedXMLThrowsInvalidXML` akzeptiert `.invalidXML` ODER `.noTrackPoints` (Linux-corelibs-foundation `XMLParser` ist permissiver als Darwin). **Test-Stand Linux**: `swift build` (Vollbuild) clean, `swift build --build-tests` clean, `swift test` **1034 Tests, 2 skipped, 0 Failures** (vorher 1033 vor 50k-Stress-Test). Erwarteter Mac-Stand: **~1133** (1033 + ~100 iOS-only Tests hinter `canImport(SwiftUI)`/`MapKit`/`CoreLocation`/`UIKit`). **46-MB-Crashfall bleibt FAILED bis Hardware-Retest** — Mac/iPhone-Handoff, auf Linux-Server nicht durchführbar; die Linux-Stabilisierung ändert iOS-Verhalten nicht und ist keine Aussage über die 46-MB-Hardware-Symptomatik. ASC/TestFlight Build ≥100 nicht angefasst. Map-Modernisierung (MKMultiPolyline/MKTileOverlay) bleibt Roadmap (siehe `docs/MAP_ARCHITECTURE_AUDIT.md` §5). Davor HEAD `34bc369` (kein verifizierter Erfolg) — fix: reduce large timeline import memory footprint. **Dritter Hardware-Fail** auf iPhone 15 Pro Max (`iPhone16,2`, iOS 26.4 / 23E246, Xcode 26.3, macOS 15.7) am 2026-05-07T15:10:44+02:00 trotz erweitertem Memory-Train (`ae5de1f`): erneut Jetsam-Kill (`IDEDebugSessionErrorDomain Code 11`, „The app ‘LH2GPXWrapper’ has been killed by the operating system because it is using too much memory."), Operation duration **95.156 ms** (vs. 232.341 ms erster Fail / 216.606 ms zweiter Fail). Die deutlich kürzere Op-Dauer signalisiert: der Peak liegt **früher** im Importpfad als bisher angenommen — wahrscheinlich tief im Streaming-/Konverter-Pfad oder beim Übergang Streaming → Session-Materialisierung. Der 46-MB-Punkt der Manual-Risk-Checkliste **bleibt FAILED**; der finale iPhone-Hardware-Retest kann auf dem Linux-Server **nicht** durchgeführt werden und ist ein expliziter Mac/iPhone-Handoff. Code-Stand vorbereitet (kein verifizierter Erfolg): (1) Build-Identitäts-Logging `[LH2GPX_BUILD] app.start version=… build=… sha=… memoryLogging=enabled|disabled` wird **immer** auf App-Start ausgegeben — damit ist zweifelsfrei loggebar, welcher Build gestartet wurde, auch wenn die Memory-Probe deaktiviert ist. (2) `ImportMemoryProbe` verdichtet — zusätzliche Probe-Punkte `import.fileSelected`, `zip.open.start/end`, `zip.entry.sniff.start/end`, `zip.stream.chunk` jetzt alle 8 Chunks (statt 64), `stream.elements` alle 1000 Top-Level-Elemente, `stream.element.outlier` für Elemente > 64 KB, `stream.before/afterElementParse` throttled (alle 1000), `converter.ingest` alle 1000 Entries, `converter.dayMap.count` alle 5000, `converter.before/afterFinalize`, `loader.before/afterSessionContent`, `session.before/afterShowContent`, `app.didReceiveMemoryWarning` (iOS-only via `NotificationCenter`-Observer auf `UIApplication.didReceiveMemoryWarningNotification`). (3) `ImportMemoryProbe` akzeptiert jetzt **beide** Aktivierungs-Quellen — `ProcessInfo.environment` und `ProcessInfo.arguments`; erkannt werden `LH2GPX_IMPORT_MEMORY_LOG=1`, `LH2GPX_IMPORT_MEMORY_LOG`, `-LH2GPX_IMPORT_MEMORY_LOG`, `--LH2GPX_IMPORT_MEMORY_LOG`; neue testbare API `ImportMemoryProbe.isEnabledForEnvironment(_:arguments:)`. (4) `AppBuildInfo.isMemoryLoggingEnabled: Bool` ergänzt; Settings → Technical → „Build Info" zeigt jetzt eine zusätzliche Zeile **„Memory Logging: Enabled/Disabled"** (grün wenn aktiv) — der Tester kann am Gerät verifizieren, ob die Probe scharf geschaltet ist. (5) **Geometrie-Refactor (P0 Fokus 1) — flatCoordinates-Kanonisierung**: Google-Timeline-Imports schreiben jetzt `flatCoordinates: [Double]` statt `points: [PathPoint]`, **ohne** ISO-Zeitstrings pro Punkt — geschätzte Einsparung **~80–120 MB resident** bei der 46-MB-ZIP. Alle Consumer (`PathDistanceCalculator`, `AppExportQueries`, `DayMapDataExtractor`, `ExportRouteSanitizer`, `AppHeatmapModel`, GPX/KML/GeoJSON/CSV-Builder) sind flat-aware gemacht; `AppHeatmapModel`-Doppelbug (Punkte wurden bei beiden Geometrien doppelt gezählt) ist gefixt. Code-Seite des P0 ist damit done; Hardware-Retest weiterhin offen. (6) **NEU** `docs/MAP_ARCHITECTURE_AUDIT.md` als Bestandsaufnahme aller Kartenflächen + Roadmap-Pfad zu UIKit `MKMapView`/`MKMultiPolyline` für Heavy Overview/Heatmap — **nicht umgesetzt** in diesem Commit, reine Architektur-Doku. Tests neu in dieser Session: `Tests/.../ImportMemoryProbeActivationTests.swift` (15 Tests, env+args-Aktivierungslogik) und `Tests/.../FlatCoordinatesGeometryTests.swift` (23 Tests, flat-Kanonisierung über `ExportRouteSanitizer`/`AppExportQueries`/`PathDistanceCalculator`/`DayMapDataExtractor`/GPX/KML/GeoJSON/CSV-Builder/`GoogleTimelineConverter`/`AppHeatmapModel`-Doppelbug-Regression). Plus die zwei DST-Tests in `GoogleTimelineConverterTests` umgeschrieben auf Geometrie-Erhalt (Per-Punkt-ISO-Zeitstrings entfallen mit flat-Kanonisierung). Erwarteter Mac-Test-Stand: **~1081 + 15 + 23 = ~1119 Tests** (finale Mac-Run-Zahl wird im nächsten Doku-Sync post-Hardware-Retest nachgetragen). SwiftPM-Linux-Vollbuild ist pre-existing kaputt für AppSupport (iOS-only `AppHeatmapRadiusPreset`/`AppHeatmapPalettePreference`/`AppHeatmapScalePreference`/`AppMapTrackColorMode`-Referenzen in `AppPreferences`); auf dem Linux-Server validiert nur `swift build --target LocationHistoryConsumer` (clean), `swift test` läuft Mac/Xcode-Cloud-seitig. Davor zweiter Hardware-Fail auf iPhone 15 Pro Max (iOS 26.4, Xcode 26.3) am 2026-05-07T14:14:36+02:00 trotz Autoreleasepool-Fix `cd77f97`: erneut `IDEDebugSessionErrorDomain Code 11`, Operation duration 216.606 ms (vs. 232.341 ms erster Fail). Damit war klar: der Peak liegt nach dem Streaming. Top-Hypothese bestätigt durch Code-Lesung — `AppSessionContent.init` erzwang volle `daySummaries`-Materialisierung; `AppSessionState.show(content:)` triggerte `content.overview` nur für Title-Text; `ExportBuilder.finalize()` kopierte alle Day-Buckets statt sie aus der dayMap rauszunehmen; `IncrementalStreamConverter.finalize()` hielt den Builder; `PathDistanceCalculator` baute temporäre `[(lat, lon)]`-Arrays. Fix in einem Train: selectedDate jetzt direkt aus `export.data.days` (kein Summaries-Pass), `show(content:)` liest inputFormat aus `meta.source.inputFormat`, `ExportBuilder.finalize()` ist mutating und nutzt `removeValue(forKey:)` + finales `removeAll(keepingCapacity: false)`, `IncrementalStreamConverter` ersetzt builder durch frische Instanz, neue `PathDistanceCalculator.effectiveDistance(for: Path)` iteriert direkt ohne Tuple-Kopien. Diagnostik: `ImportMemoryProbe` (mach `task_vm_info`, gated auf Launch-Arg/ENV `LH2GPX_IMPORT_MEMORY_LOG=1`, Probe-Punkte im ZIP-Streaming-Pfad, Logs greppbar als `[LH2GPX_MEMORY]`). Build-Identität: neuer `AppBuildInfo` + „Build Info“-Sektion in `AppTechnicalOptionsView` (Marketing/Build/optional Git-SHA via Info.plist `GitCommitSHA = $(GIT_COMMIT_SHA)`). `swift test` 1081/2/0 (+3). `git diff --check` clean. Restrisiko: Hardware-Retest des Release-Builds auf iPhone 15 Pro Max steht weiter aus; 46-MB-Crashfall **bleibt FAILED** bis Tester ihn ohne Debugger grün bestätigt. Empfohlen: zuerst Debug mit `LH2GPX_IMPORT_MEMORY_LOG=1` zur Peak-Lokalisierung, dann Release-Build. Davor HEAD `cd77f97` — fix: drain autorelease objects during timeline stream parsing. iPhone 15 Pro Max (iOS 26.4) reproduzierte beim manuellen Import einer 46 MB `location-history.zip` (~64.926 Entries) einen Jetsam-Kill (`IDEDebugSessionErrorDomain Code 11`, Operation duration 232.341 ms). Damit war der bislang als „not verified" geführte 46-MB-Punkt der Manual-Risk-Checkliste real **FAILED**. Root Cause: `JSONSerialization.jsonObject(with: element)` in `GoogleTimelineStreamReader.TopLevelArrayParser.processByte` lief außerhalb des `autoreleasepool` — der Pool umschloss nur das nachgelagerte `onElement`. Transiente Foundation-Objekte (`NSString`/`NSNumber`/`NSDictionary`/`NSArray`) akkumulierten dadurch über alle ~65k Top-Level-Elemente. Fix: Parse + Ingest laufen jetzt im selben `autoreleasepool { ... }`; nach Outliern > 64 KB wird die `element`-Data neu reserviert (statt nur Inhalt zu leeren), damit ein einzelner Ausreißer die Parser-Footprint nicht permanent inflationiert. Streaming-Pfade (ZIP + direkte JSON) unverändert. Neuer Regressionstest `GoogleTimelineStreamReaderTests.testHighElementCountWithLargeOutlierSucceeds` (50.000 Elemente + 1-MB-Outlier in der Mitte) läuft in 0,87 s durch. `swift test` 1078/2/0 (+1). Restrisiko: Code-seitig adressiert, aber Release-Build-Hardware-Retest mit der originalen 46-MB-ZIP auf iPhone 15 Pro Max steht aus — der 46-MB-Punkt der Manual-Risk-Checkliste **bleibt FAILED**, bis Tester ihn nachweislich grün bestätigt. Davor HEAD `b91a933` „Manual Release Risk Acceptance Protocol" angelegt in `docs/APPLE_VERIFICATION_CHECKLIST.md`; deckt 4 nicht automatisierbare Restrisiken (46-MB-Crashfall, Live Activity / Dynamic Island / Lock Screen, iPad-Layout, ASC / TestFlight / Apple Review) mit leeren Checkboxen, durch Tester auf echter Hardware bzw. im Apple-Portal abzunehmen; keine Code-Änderung; `swift test` 1077/2/0 unverändert. Davor Post-Fix-Hardware-Re-Verifikation: volle 3-UITest-Suite (testAppStoreScreenshots 41.8s, testDeviceSmokeNavigationAndActions 71.2s, testLandscapeLayoutSmoke 829.9s) PASSED auf iPhone 15 Pro Max (iOS 26.4) nach Day-Detail-Distance-Fix (Commit `853d8d3`); `swift test` 1077/2/0 unverändert; `git diff --check` clean. Beim letzten Doku-Eintrag (`853d8d3`) war nur Smoke-Navigation post-Fix verifiziert; Screenshots + Landscape sind jetzt erneut gefahren und grün. 46-MB-Crashfall geräteseitig, Live Activity / Dynamic Island / Lock Screen visuell, iPad-Layout, ASC / TestFlight / Apple Review weiterhin offen. Davor Day-Detail-Distance-Bug-Fix: Day-Detail zeigte „Distance 0" für Routen mit sichtbarer Geometrie (Google-Timeline-`timelinePath`-Imports mit `distanceM == nil` aber validen `points`). Fix: neue `PathDistanceCalculator` als Single-Source-of-Truth in `Sources/LocationHistoryConsumer/Queries/`; `DayDetailViewState.PathItem.effectiveDistanceM: Double` (immer berechnet); `DayDetailPresentation` liest `effectiveDistanceM` an 5 Stellen (KPI, Route-Subtitle, Summary, Section-Subtitle, Dominant-Mode, Route-Intensity); 12 neue Cases in `PathDistanceCalculatorTests` inkl. Summary↔DayDetail-Konsistenz-Regression. `swift test` 1077/2/0 (+12 gegenüber 1065). Device-Smoke iPhone 15 Pro Max (iOS 26.4) `testDeviceSmokeNavigationAndActions` PASSED (75s) — volle Hardware-Acceptance (3-UITest-Suite) für aktuellen HEAD weiterhin offen, nur Smoke-Navigation post-Fix verifiziert. 46-MB-Crashfall geräteseitig nach Fix nicht erneut validiert; Live Activity / Lock Screen / iPad / ASC / TestFlight nicht geprüft. Davor Hardware-Re-Verifikation iPhone 15 Pro Max (iOS 26.4): testAppStoreScreenshots / testDeviceSmokeNavigationAndActions / testLandscapeLayoutSmoke PASSED am 2026-05-07. Während des Hardware-Runs P1-UX-Bug gefixt: `HistoryDateRangeFilterBar` clear-date-range Button (xmark.circle.fill) hatte 12×12pt Hit-Area; jetzt `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` (HIG-konform). Davor HEAD `3811bc3` P1-Hardening-Train: distanceText! safe-unwrap, `[weak self]` in `AppOverviewMapModel.rebuildOverlays`, Upload-URL-Validation in `AppPreferences` + 8 neue URL-Validation-Tests, Doku-Wahrheits-Sync. `swift test` 1065/2/0 unverändert; Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1 BUILD SUCCEEDED. 46-MB-Crashfall + Live Activity weiterhin offen; ASC/TestFlight-Status nicht geprüft; Xcode Cloud Build ≥100 weiterhin nötig vor Submit.)

Diese Datei enthaelt bewusst nur offene, priorisierte Arbeit. Abgeschlossene oder rein historische Batches bleiben im `CHANGELOG.md` und in den archivierten Phasen der `ROADMAP.md`.

### Offen — Deep Audit 2026-05-09 Performance/Stabilität/Map-Layer (`docs/DEEP_AUDIT_2026-05-09_PERFORMANCE_STABILITY_MAP_LAYERS.md`)

Audit-only. Maßnahmenliste mit 15 IDs (3 P0, 4 P1, 4 P2, 2 P3, 2 Doku); Folgeprompt-Skizzen in Sektion 19 des Audit-Dokuments.

Zentrale offene Punkte (Code unverändert in diesem Audit):

1. ✓ **L-01 (P0)** erledigt 2026-05-09: `AppContentLoader.decodeFile(at:)` lehnt Full-Reads über 64 MiB jetzt kontrolliert ab (`maximumInMemoryImportBytes`, neuer Error-Case `importTooLargeForInMemoryLoad`). Google-Timeline läuft weiter durch den Streaming-Pfad. Betroffen: LH2GPX-JSON / GPX / TCX / unbekannte JSON > 64 MiB. 5 neue Linux-Tests in `AppContentLoaderTests`.
2. **L-02 (P0)** AppExportQueries.projectedDays — `limit` vor `.sorted` durchschleifen (Top-N-Heap).
3. **L-03 (P0)** AppOverviewTracksMapView.scanCandidates — Score-Invariant-Tests zuerst, dann lazy/streaming Refactor.
4. ✓ **L-04 (P1)** erledigt 2026-05-09: Generischer `BoundedLRU<K,V>` in `Sources/LocationHistoryConsumerAppSupport/BoundedLRU.swift`. Migriert in `AppSessionState.swift`: `filteredOverviewCache`, `filteredDaySummariesCache`, `filteredInsightsCache` (je 8), `dayDetailCache` (32), `dayMapDataCache` (16) und `projectedDaysCache` (8). Semantik unverändert. 18 neue Linux-Tests (`BoundedLRUTests`, `AppSessionContentCacheBoundsTests`).
5. **L-05 (P1)** AppHeatmapModel — single-pass tile-sweep statt Multipass-LOD-Rebuild.
6. **L-06 (P1)** ExportPreviewData — `computeRegion` über min/max-Akkumulator + adaptives Sampling mit Pin-Tests.
7. **L-07 (P1)** Sources/LocationHistoryConsumer/Queries/DayMapData.swift — Doppel-`map` über `path.points` durch single-loop ersetzen.
8. **U-01 (P1)** Punktelayer MapKit-Hook für `LocalTimelineDayMapView` (Phase 10B Xcode-Handoff).
9. **U-02 (P2)** Heatmap-UI für Store-Pfad (service-only).

46-MB-Hardware-Gate bleibt **FAILED / pending hardware retest**. Store-Pfad bleibt **default OFF**.

### Offen — P1-Rest nach Deep Audit 2026-05-08 (`docs/DEEP_AUDIT_2026-05-08_LOCAL_TIMELINE_STORE_AND_MAP.md`)

Im Audit als **P1** belegt; nach diesem Commit (P1-A + P1-B + P1-C + P1-D erledigt) verbleibend:

1. **UI-Hook für Cancel + Progress** (Folge von P1-A/P1-B). ✓ erledigt 2026-05-08 (Weg 2): LocalTimelineImportProgressView + Cancel-Button im Loading-Branch beider App-Shells, Test-Mode-Banner, Linux-Tests grün. Service-Layer (`LocalTimelineImportController`) ist verdrahtet und Linux-getestet; SwiftUI-Anbindung in `AppShellRootView` / `wrapper/LH2GPXWrapper/ContentView` ist jetzt ebenfalls live (Progress-Counter entries / visits / activities / paths / skipped / optional bytes, Cancel-Outcome-Hinweis). `LocalTimelineSessionLandingView`-Fallweise-UI-Polish bleibt offen, Foundation- und View-Layer sind stabil.
2. **UX-Polish AppOptionsView Memory-Logging-Section** (P1-E). Drei Felder in zwei Layern (Build Configuration / Tester Override / Active Status) reorganisieren — nach FIX-1 nicht mehr blocking, aber Klarheit verbessert.
3. **PointLayer in Store-DayMap UI verdrahten (Phase 10B Hook)** — Foundation-only Provider + `LocalTimelineMapPerformanceBudget` sind eingecheckt; UI-Verdrahtung in `LocalTimelineDayMapViewState` + `LocalTimelineDayMapView` ist WIP. Store-Pfad bleibt default OFF.
4. **PointLayer-Cluster-Marker SwiftUI-Annotations Mac/Xcode-Verifikation** — MKMapView-Annotations und SwiftUI-Map-Points sind nur dort testbar; Mac/Xcode-Pflicht.
5. **Legacy-Map-Crash-Hotspots (P1-Folgepunkt aus DEEP_AUDIT § 13)** — Phase-10C-Update:
   - ✓ erledigt 2026-05-08 (Phase-10C): `AppHeatmapModel.startPrecomputation` hat `densityPointCap = 500_000` + `HeatmapStats.truncatedDensityPoints` (Sources/LocationHistoryConsumerAppSupport/AppHeatmapModel.swift); `ExportPreviewData` Doppel-Iteration über `path.points.map` durch einen reservedCapacity-Loop ersetzt (Sources/LocationHistoryConsumerAppSupport/ExportPreviewData.swift); `LocalTimelineStore.pruneDerivedCache(maxEntries:cacheKind:)` + `deleteDerivedCache(olderThan:cacheKind:)`; Build-Warnings (visionOS-Guard in `LHCollapsibleMapHeader.swift`, unused `withUnsafeMutableBytes` Result in `StoreBackedHeatmapDataProvider.swift`) bereinigt; 8 neue Tests in `LocalTimelineDerivedCachePurgeTests.swift`.
   - **Offen (P1)**: `AppOverviewTracksMapView.scanCandidates` lazy/streaming Refactor (Score/Bounds werden auf full coords berechnet, ~Z. 720–725; Refactoring würde Test-Assertions zu Score-Reihenfolge brechen). Risiko **HOCH**. Bereits bounded via `pointBudget=2_000_000` (L648), `candidateStorageCap=512`/Route (L657), `overlayLimit=150–300` (Profile L580–617), `nonisolated static` + `Task.detached` off-Main. Refactor-Skizze: erst Score/Bounds streamend ermitteln, dann Decimate streaming.
   - **Offen (P1)**: `ExportPreviewData` Sampling-Strategie (würde Tests mit exakten Punkt-Counts wie "5 pts" brechen und Preview/Export-Mismatch erzeugen) — gemeinsame Strategie für Tests + Preview/Export-Match nötig.
   - **Offen (P1)**: `AppHeatmapModel` `densityPointCap = 500_000` mit echten 46-MB-Datasets nach Hardware-Retest validieren (kein Linux-Beleg möglich).

P0 ist bewusst leer: keine produktiven Crashes/Datenverluste im Repo belegbar; das **46-MB-Hardware-Gate bleibt FAILED / pending hardware retest** (verbatim) als externe Verifikation.

### Erledigt — P1-C + P1-D WAL-Checkpoint + Recovery-Test (2026-05-08)

`LocalTimelineStore.checkpointWAL(mode:)`/`truncateWAL()`/`bestEffortTruncateWAL()` über `sqlite3_wal_checkpoint_v2`; Default `.truncate` schreibt Frames zurück und kürzt `-wal` auf 0 Byte. Hard-Fail bei expliziter API; Best-Effort im nachgelagerten Cleanup nach `finalize`/`cancel`/`deleteAllLocalTimelineData` (Importerfolg/Cancel/Delete bleiben unangetastet, wenn Checkpoint scheitert). Reads checkpointen **nicht**. **Keine Schemaänderung**: `imports`-Row liegt inside `BEGIN IMMEDIATE`, mid-import-Abbruch hinterlässt keine sichtbare Partial-Import-Row. Recovery-Test (`LocalTimelineStoreRecoveryTests`) simuliert abrupten Abbruch via `store.close()` ohne `finalize`/`cancel` — Linux-Simulation, **kein** echter iOS-Jetsam-Test. 13 neue Cases (Linux-grün), Vollsuite 1345 / 2 skipped / 0 failed.

### Erledigt — P1-A + P1-B Cancel/Progress (Service-Schicht) (2026-05-08)

`LocalTimelineImportProgress` (Sendable Snapshot mit Phase + Counter, Foundation-only, keine Standortdaten), `LocalTimelineImportProgressThrottle` (Default 500 Entries, Phase-Change-Override), `LocalTimelineImportCancellation` (NSLock-guarded, idempotent, kein globaler State, `LocalTimelineImportCancellationError.cancelled`), `LocalTimelineImportController` (bündelt Token + Sink + Observer-API, Linux-testbar). `GoogleTimelineStoreImporter.importFromFile/Data` akzeptiert `Hooks` (progress/throttle/cancellation); Cancel rollt Writer-Transaktion zurück → **kein gültiger Teilimport**. Loader/AppFlow propagieren `importProgress`/`importCancellation`; Cancel-Outcome ist `.failure(title: "Import cancelled", clearBookmark: false)`. Legacy-Pfad unverändert; Default-Aufrufpfad ist source-kompatibel; Store-Pfad bleibt **pre-production / feature-flagged / default AUS**. SwiftUI-Anbindung als Folgeschritt offen (siehe oben). Tests: 26 neue Cases (Linux-grün), Vollsuite 1332 / 2 skipped / 0 failed.

### Erledigt — Deep Audit + AppBuildInfo Live-Memory-Logging-Mirror (2026-05-08)

Deep Audit nach Build 158: Repo-Truth-Abgleich von LocalTimelineStore-Pfad, Toggles, ImportMemoryProbe, Map/Heatmap/Overview/Export-Verdrahtung, Stabilität, Tests und Doku. Audit-Dokument `docs/DEEP_AUDIT_2026-05-08_LOCAL_TIMELINE_STORE_AND_MAP.md` (15 Sektionen, P0/P1/P2/P3-Maßnahmenliste).

P1-UX-Fix in diesem Commit (FIX-1): `AppBuildInfo.isMemoryLoggingEnabled` von gespeichertem `let` auf computed `var` umgestellt. Vorher fror der Wert beim Process-Start ein, sodass die Build-Info-Sektion "Disabled" zeigte, während die Toggle-Sektion direkt darunter "Memory Logging Resolved Enabled" auflöste. Neuer Regressions-Pin `testAppBuildInfoMemoryLoggingReflectsLiveSettingsToggle`.

Linux-Vollsuite: 1306 Tests, 2 Skips, 0 Failures (nach FIX-1).

### Erledigt — Build-158-Vorbereitung: interne Test-Toggles (2026-05-08)

Build 157 ist **Xcode Cloud grün** und **TestFlight-installierbar** (Status „Überprüft", interne Tests erfolgreich). Keine Aussage über Apple-Review-Freigabe, Release oder Hardware. Da TestFlight-Tester keine Launch-Argumente / Environment-Variablen setzen können, ist als Build-158-Vorbereitung ein interner UserDefaults-basierter Toggle-Mechanismus eingecheckt, der den feature-flagged LocalTimelineStore-Pfad **und** das Import-Memory-Logging über die Technical-Sektion in der App scharf schaltet.

- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineTechnicalTestSettings.swift` — `final class` ObservableObject mit zwei `@Published Bool`-Toggles, persistiert über UserDefaults. Keys (Namespace `LH2GPX.…`): `LH2GPX.localTimelineStoreTestModeEnabled`, `LH2GPX.importMemoryLoggingEnabled`. Default `false`. **Nur Booleans.** Keine Standortdaten, keine Pfade, keine Tokens. `.shared`-Singleton + `init(userDefaults:)` für Tests.
- `LocalTimelineFeatureFlags`: neue Resolver-Overloads `resolve(arguments:environment:settings:)` / `resolveFromProcess(settings:)`. Args/ENV bleiben primärer Aktivator; Setting aktiviert **zusätzlich**, deaktiviert nichts. Default OFF unverändert.
- `ImportMemoryProbe`: neuer Pure-Overload `isEnabledForEnvironment(_:arguments:settings:)`. Runtime-`isLoggingEnabled` ist jetzt computed (Cache für ProcessInfo + Settings-Lookup pro Aufruf), damit der Toggle **ohne Relaunch** wirkt.
- `AppOptionsView` (`AppTechnicalOptionsView`): neue Sektion "Internal Test Toggles" mit zwei `Toggle`-Bindings (`$technicalTestSettings.…`), Status-Row "Memory Logging Resolved" (zeigt ProcessInfo-OR-Settings-State) und Footer-Hinweis "Internal/TestFlight only · Pre-production · Default off · No location data is stored in these settings".
- **Nicht angefasst**: `AppShellRootView`, Wrapper-`ContentView` — Settings werden über `.shared` aufgerufen; Resolver-Overload mit Default-Argument bleibt source-kompatibel.
- Tests: `Tests/LocationHistoryConsumerTests/LocalTimelineTechnicalTestSettingsTests.swift` (12 Cases) — Linux-Suite voll grün nach Fix. `testOnlyBoolsAreStoredUnderToggleKeys` pinpoint die Privacy-/Scope-Pflicht.
- **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim). LocalTimelineStore-Pfad bleibt **pre-production / feature-flagged / default AUS**. Toggles sind interner Testmodus (Pre-production); aktivieren zusätzlich, deaktivieren nichts. **KEINE ASC/Review/Hardware-Freigabe behauptet.** **KEINE Map-Phase-10B-Aussage.** Live-Upload, Recording, Auth-Flows unberührt.
- **Hardware-Retest bleibt offen**: 46-MB-Crashfall-Retest auf iPhone 15 Pro Max (Mac/iPhone-Handoff — auf Linux-Server nicht durchführbar) ist von dieser Build-158-Vorbereitung **unberührt** und steht unverändert aus. Siehe Block „Manual Release Risk Acceptance Protocol" weiter unten.

### Verbleibend offen — Xcode Cloud Archive-Fail Build 155/156 Retest (2026-05-08)

Xcode Cloud Builds **155** (Commit `06f81ae`) und **156** (Commit `5cb7783`) sind im Workflow „Release – Archive & TestFlight" mit Exit Code 65 fehlgeschlagen. Root Cause war eine Namens-Kollision für `GridKey` zwischen `Sources/LocationHistoryConsumerAppSupport/HeatmapGridBuilder.swift` (top-level `struct GridKey { let lat: Int32; let lon: Int32 }`, `#if canImport(MapKit) && canImport(SwiftUI)`-gated — auf Linux ausgeschlossen, auf Apple-Plattformen aktiv) und `Sources/LocationHistoryConsumerAppSupport/LocalTimelineHeatmapGridAggregator.swift` (top-level `private struct GridKey { let lat: Int; let lon: Int }`). Auf Linux schloss der MapKit-Guard die HeatmapGridBuilder-Variante aus → SwiftPM-Build grün; auf Apple-Plattformen waren beide sichtbar → „Invalid redeclaration of 'GridKey'" + „ambiguous for type lookup" + Folgefehler „Cannot convert value of type 'Int' to expected argument type 'Int32'" auf Zeile 79 des Aggregators (Compiler löste den Namen auf die `Int32`-Variante auf). Fix: `LocalTimelineHeatmapGridAggregator.swift` benennt `GridKey` → `LocalTimelineHeatmapGridKey` (privat, file-scope). Heatmap-Logik unverändert, keine API-/UI-Änderung. `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj` referenziert die SPM-Package-Datei nicht direkt; keine doppelten Compile-File-Referenzen gefunden. Linux-SwiftPM bleibt grün, `swift test` voll grün nach Fix.

- [ ] **Xcode Cloud Retest „Release – Archive & TestFlight" auslösen** auf dem post-Fix-HEAD nach Commit. Status: **PENDING** — keine Aussage über echte Apple-Builds, bis Xcode Cloud erneut grün läuft.
- **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim).
- Store-Pfad bleibt **default AUS**, pre-production.
- **KEINE Map-Phase-10B-Aussage**, **KEINE UI-Änderung**, **KEINE ASC/TestFlight/Apple-Review-Freigabe behauptet** durch diesen Fix.

### Verbleibend offen — Manual Release Risk Acceptance Protocol (HEAD `b91a933`)

Nicht automatisierbar; muss durch Tester abgehakt werden. Details + leere Checkboxen + Felder (Datum, Tester, Befund, Akzeptiert/Abgelehnt) im Block „Manual Release Risk Acceptance Protocol — HEAD `b91a933`" in `docs/APPLE_VERIFICATION_CHECKLIST.md`.

- [ ] **46-MB-Crashfall (Großimport echtes iPhone)** — Status **FAILED** (drei reproduzierte Hardware-Fails am 2026-05-07: 13:38:37+02:00 / Op-Dauer 232.341 ms, 14:14:36+02:00 / 216.606 ms, 15:10:44+02:00 / **95.156 ms** auf iPhone 15 Pro Max, iOS 26.4 / 23E246, Xcode 26.3, macOS 15.7); Code-Stand vorbereitet bis HEAD `<commit-tba>` nach `ae5de1f` (autoreleasepool, Session/Builder/Calculator-Fix, **flatCoordinates-Kanonisierung** ~80–120 MB-Ersparnis, ImportMemoryProbe verdichtet, Build-Identitäts-Logging immer auf App-Start, Memory-Logging-Status in Settings → Technical → Build Info sichtbar) — kein verifizierter Erfolg. **Hardware-Retest mit der originalen 46-MB-ZIP steht weiter aus** (Mac/iPhone-Handoff — auf Linux-Server nicht durchführbar), bleibt FAILED bis Tester ihn grün bestätigt. Siehe Sektion 1 in `docs/APPLE_VERIFICATION_CHECKLIST.md` (Manual Release Risk Acceptance Protocol)
- [ ] **Hardware-Retest mit Build-Identitäts-Verifikation** — Tester muss vor dem Retest am Gerät Settings → Technical → „Build Info" öffnen und Marketing-Version + Build + (falls injiziert) Git-Commit-SHA + **„Memory Logging: Enabled"** mit dem getesteten Git-HEAD vergleichen, **bevor** der Import gestartet wird. Memory-Logging-Aktivierung: env `LH2GPX_IMPORT_MEMORY_LOG=1` **oder** Launch-Argument (`LH2GPX_IMPORT_MEMORY_LOG`, `-LH2GPX_IMPORT_MEMORY_LOG`, `--LH2GPX_IMPORT_MEMORY_LOG`, `LH2GPX_IMPORT_MEMORY_LOG=1`). Erst Debug-Run loggen (`[LH2GPX_BUILD]` + `[LH2GPX_MEMORY]` in Xcode-Console greppen), dann Release-Build ohne Debugger. **Restrisiko**: Code-Stand adressiert die wahrscheinlichsten Allokationspfade, ist aber kein Beweis für Release-Build-Verhalten unter realer iOS-Memory-Pressure — der dritte Fail (95 s Op-Dauer) zeigt: Peak liegt früher als bisher angenommen.
- **LocalTimelineStore (Phase 1..8B abgeschlossen, conditional P0/P1)** — store-backed Read-Surface + Storage-Lifecycle/iOS-Readiness + store-backed Streaming Export + feature-flagged AppSession-Quelle + feature-flagged AppContentLoader-Hook (Phase 7A) + Foundation-only Presentation/ViewState-Schicht + AppSessionState-Extension + Service-layer Envelope-Hook im AppFlow (Phase 7B) + **Store-backed Map Data Provider + Map-Domain-Modelle + Route-Decimator + zwei additive bbox-Indizes (Phase 8A)** + **Heatmap-Doppelbug-Fix via `AppHeatmapPathSampler` + `derived_cache`-Tabelle (additiv, FK CASCADE) + Foundation-only Heatmap-Modelle + Grid-Aggregator + `StoreBackedHeatmapDataProvider` mit bounded Sampling/Grid-LOD/Cache-Roundtrip (Phase 8B)** stehen **isoliert** zur Verfügung. **Default-Rollout bleibt Legacy-AppExport — Store-Pfad ist NIE default; nur bei aktivem Feature-Flag, gated. Kein produktiver UI-Flow nutzt den Store; keine UI-Migration; kein Map-Hook; kein DayList/DayDetail/Heatmap/Overview/Export/Settings-UI-Hook; kein `AppExport` über den Reader/Store-Pfad; bestehender Legacy-AppExport-Pfad unverändert/byte-identisch.**
  - Research-Doku: `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`. Phase-1-Anker `955c934`, Phase-2 (`visits`/`activities` + Writer + Importer + `deleteAll()`), Phase-3 (Foundation-only Read-Models + `LocalTimelineStoreReader`), Phase-4 (Storage-Pfad-Resolver, Backup-Exclusion-Helper, FileProtection-Kapselung, Open-Lifecycle-Factory, High-Level deleteAll).
  - Conditional Gate unverändert: **P0 falls 46-MB-Retest FAILED** (geht *vor* Map-Modernisierung und vor weiterer UI-Politur), **P1/P2 falls PASSED**.
  - Phase-2 umgesetzt: SQLite-Schema `userVersion` 1→2 (additiv), `visits`/`activities`-Tabellen, `LocalTimelineImportWriter` mit gehaltener Transaktion + bounded per-day-Aggregat, `GoogleTimelineStoreImporter` über bestehenden `GoogleTimelineStreamReader` ohne `AppExport`-Materialisierung. `LocalTimelineStore.deleteAll()` löscht **DB-Inhalt** in einer Transaktion (idempotent).
  - Phase-3 umgesetzt: Foundation-only Read-Models (`LocalTimelineImportRecord`, `LocalTimelineDayRecord`, `LocalTimelineVisitRecord`, `LocalTimelineActivityRecord`, `LocalTimelinePathRecord` ohne `coord_blob`, `LocalTimelineDayDetailSnapshot`) + `LocalTimelineStoreReader` (`imports`/`days`/`dayDetail`/`paths`/`coordinateSequence` + Aggregate `dayDateRange`/`totalDistance`/`totalRouteCount`/`totalVisitCount`). **Bounded-Read-Garantien (1-6)**: kein paths-/visits-/activities-Read in `imports()`, kein `coord_blob` in `days(forImportId:)`, kein eager Coord-Decode in `dayDetail(dayId:)`, Coord-Decode nur explizit/lazy via `coordinateSequence(forPathId:)`, kein `AppExport` im Read-Pfad, kein `[Double]` für einen ganzen Import. Schema unverändert (`userVersion = 2`).
  - ✅ **Phase-4 erledigt (Storage-Lifecycle / iOS-Readiness)**: **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStorageLocations.swift` (Pfad-Resolver, 4 Roots: DB unter `applicationSupportDirectory/LocationHistory2GPX/Imports/`, RenderCache unter `cachesDirectory/LocationHistory2GPX/RenderCache/`, ImportStaging unter `temporaryDirectory/LocationHistory2GPX/ImportStaging/`, ExportStaging unter `temporaryDirectory/LocationHistory2GPX/ExportStaging/`; `temporary(under:)` für Tests; `ensureDirectoriesExist` idempotent; DB-Datei `store.sqlite` + `-wal`/`-shm`-Geschwister), `LocalTimelineFileAttributes.swift` (Backup-Exclusion via `URLResourceKey.isExcludedFromBackupKey`; Linux no-op), `LocalTimelineFileProtection.swift` (FileProtection-Kapselung mit Ziel iOS `completeUnlessOpen`; **Hook nur dokumentiert, nicht aktiviert** — Aktivierung ist offene Darwin-Pflicht; Linux `"noop-linux"`), `LocalTimelineStoreFactory.swift` (`openStore()`: Dirs → Backup-Exclusion → FileProtection-Hook → `LocalTimelineStore(url:)` → Backup-Exclusion + FileProtection auf DB-Datei; `temporary(under:)`/`production()`; **kein UI-Hook, kein AppContentLoader-Hook, keine automatische Migration**), `LocalTimelineStoreLifecycle.swift` (High-Level `deleteAllLocalTimelineData(store:)` → `store.deleteAll()` + close + DB+WAL+SHM + RenderCache + ImportStaging + ExportStaging + `ensureDirectoriesExist`; idempotent; **keine UserDefaults-Aufräumung** — Bookmark/Preferences-Cleanup verbleibt im UI-Hook). 5 neue Test-Dateien, 26 neue Cases (`LocalTimelineStorageLocationsTests`, `LocalTimelineFileAttributesTests`, `LocalTimelineFileProtectionTests`, `LocalTimelineStoreFactoryTests`, `LocalTimelineStoreLifecycleDeleteAllTests`).
  - ✅ **Phase-5 erledigt (Store-backed Streaming Export)**: **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineExportTypes.swift` (Foundation-only Typen: `LocalTimelineExportFormat` `gpx`/`kml`/`geoJSON`/`csv`; `LocalTimelineExportSelection` mit `importID`, optional `dateRange`, optional `dayIds`, `includeVisits`/`includeActivities`/`includePaths`; `LocalTimelineExportResult` mit `outputURL`/`format`/`bytesWritten`/`dayCount`/`pathCount`/`visitCount`/`activityCount`/`pointCount`; `LocalTimelineExportError` mit `unknownImport`/`emptySelection`/`malformedCoordBlob`/`ioFailure`/`readerFailure` — empty-selection-Entscheidung explizit als Fehler), `LocalTimelineStreamingTextWriter.swift` (inkrementeller UTF-8-Datei-Writer nach `ExportStaging/<uuid>/export.<ext>`; parent-dir idempotent; `bytesWritten` zählt UTF-8-Bytes; `finalize()` idempotent), `StoreBackedExportWriter.swift` (`init(reader:locations:)`, `export(selection:format:) throws -> LocalTimelineExportResult`; liest Days bounded, Visits/Activities/Paths via `dayDetail`, Koordinaten **ausschließlich pro Pfad lazy via `coordinateSequence(forPathId:)`/`CoordBlobIterator`**; **materialisiert KEINEN `AppExport`, KEINEN `[Double]`-Buffer für einen ganzen Import; schreibt direkt in die Datei via `StreamingTextWriter`**; Output-Pfad `LocalTimelineStorageLocations.exportStagingRoot/<uuid>/export.<ext>`). Format-Hinweise: GPX `<wpt>`+`<trk>/<trkseg>/<trkpt>`; KML `Placemark` mit `Point`/`LineString`; GeoJSON `FeatureCollection` mit Point-/LineString-Features (Properties `kind`/`name`/`mode`/`date`); CSV-Header `type,date,time,lat,lon,name,mode,distance_m`; Activities werden in CSV als eigene Rows geschrieben, in GPX/KML/GeoJSON nur gezählt. **Bestehende `AppExport`-Builder (`GPXBuilder`/`KMLBuilder`/`GeoJSONBuilder`/`CSVBuilder`) bleiben unverändert; bestehender AppExport-Exportpfad unverändert. Kein UI-Hook, kein Map-Hook.** 3 neue Test-Dateien, 26 neue Cases (`LocalTimelineExportSelectionTests` 6, `LocalTimelineStreamingTextWriterTests` 5, `StoreBackedExportWriterTests` 15). `swift test`: **1148/2/0** in 123.7s (vorher 1122 → +26).
  - ✅ **Phase-7A erledigt (feature-flagged AppSession/AppContentLoader-Hook)**: **NEU** `Sources/LocationHistoryConsumerAppSupport/AppSessionContentSource.swift` — Envelope-Enum mit Cases `inMemory(AppSessionContent)` und `localTimeline(LocalTimelineSession)`. **Kapsel-Approach** — `AppSessionContent` selbst wird **nicht** erweitert (kein Bruch der bestehenden Source-Form); Source-Enum-Verschmelzung in `AppSessionContent` ist explizit Phase-7B. **Geändert** `AppSessionState.swift` (neue Property `localTimelineSession: LocalTimelineSession?` + Mutator `show(localTimeline:)` — Banner/Title aus Session-Metadaten, **kein AppExport, keine Coord-Decode**; `show(content:)` und `clearContent()` setzen die Property mit zurück). **Geändert** `AppContentLoader.swift` (neuer Einstieg `loadImportedContentEnvelope(from:autoRestoreMode:onPhase:flags:storeFactoryProvider:) -> AppSessionContentSource`; **bei deaktiviertem Flag exakt der Legacy-Pfad** → `.inMemory(...)` byte-identisch; bei aktivem Flag + Google-Timeline-JSON oder ZIP-mit-genau-einem-Timeline-Entry → `GoogleTimelineStoreImporter.importFromFile/Data` + `LocalTimelineSession.make(...)` → `.localTimeline(...)`; andere Formate — LH2GPX-Objekt-JSON, GPX, TCX — fallen kontrolliert auf den Legacy-Pfad zurück; neuer Error-Case `localTimelineStoreFailed(String)`; Importe additiv mit frischer `importId` pro Call; Bulk-Wipe bleibt `LocalTimelineDeletionService`). 3 neue Test-Dateien, 14 neue Cases (`AppSessionLocalTimelineSourceTests` 5, `AppContentLoaderLocalTimelineStoreTests` 5, `LocalTimelineFeatureFlagIntegrationTests` 4). Schema unverändert (`userVersion = 2`). **Status: Spike/pre-production, nicht UI-aktiv. Store-Pfad ist NIE default — gated by feature flag. Default-Rollout bleibt Legacy-AppExport. Kein UI-Hook für DayList/DayDetail/Map/Heatmap/Overview/Export/Settings. Kein AppExport im Store-Pfad materialisiert; kein vollständiger `[Double]`-Import-Buffer. Live-Upload bleibt strikt getrennt. Keine Standortdaten in UserDefaults. Darwin FileProtection nicht aktiviert. Keine Map-Modernisierung. Keine Hardware-/ASC-/TestFlight-Aussagen. 46-MB-Gate bleibt FAILED / pending hardware retest.**
  - ✅ **Phase-6 erledigt (Feature-flagged AppSession-Quelle)**: **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineFeatureFlags.swift` (resolved `LH2GPX_LOCAL_TIMELINE_STORE` aus `ProcessInfo.arguments`/`environment`; `--LH2GPX_LOCAL_TIMELINE_STORE`/bare arg/env `1`/`true`/`yes`/`on` case-insensitive; default disabled; **keine UserDefaults**), `LocalTimelineSession.swift` (Foundation-only Session-Modell `importID`/`sourceFilename`/`storeURL`/`createdAt`/`importedAt`/`summary` mit `dayCount`/`pathCount`/`visitCount`/`activityCount`/`totalDistanceM`/`dateRange`; `make(reader:importID:storeURL:)` konstruiert ohne Geometrie-Materialisierung; Caller besitzt Store-Lifetime), `LocalTimelineAppSessionAdapter.swift` (projiziert Reader-Daten in bounded ViewState-Modelle `DaySummaryView`/`DayDetailView`/`VisitView`/`ActivityView`/`PathMetadataView`; Methoden `daySummaries()`/`dayDetail(dayId:)`/`coordinates(forPathId:)` lazy via `CoordBlobIterator`), `LocalTimelineDeletionService.swift` (dünner Wrapper um `LocalTimelineStoreLifecycle.deleteAllLocalTimelineData`; idempotent; **keine UserDefaults-Aufräumung**). 4 neue Test-Dateien, 17 neue Cases (`LocalTimelineFeatureFlagsTests` 8, `LocalTimelineSessionTests` 3, `LocalTimelineAppSessionAdapterTests` 4, `LocalTimelineDeletionServiceTests` 2). **Status: Spike/pre-production, nicht UI-aktiv. Kein default-aktiver Pfad — gated by feature flag. Kein UI-Hook, kein App-Session-Switch, kein AppContentLoader-Hook, kein DayList/DayDetail/Map/Heatmap/Overview-Hook, kein Settings-UI. Darwin FileProtection in diesem PR nicht angefasst. Bestehender AppExport-Exportpfad unverändert. 46-MB-Gate bleibt FAILED / pending hardware retest.**
  - ✅ **Phase-7B erledigt (Foundation-only Presentation/ViewState-Schicht + AppSessionState-Extension + Service-layer Envelope-Hook im AppFlow)**: **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayListViewState.swift` (Foundation-only ViewState für Day-List-Surface über Store-Pfad), `LocalTimelineDayDetailViewStateAdapter.swift` (Foundation-only Adapter projiziert Reader-Daten in bounded DayDetail-ViewState), `AppSessionPresentationSource.swift` (Presentation-Quelle inkl. `AppSessionState`-Extensions `activeContent` und `isLocalTimelineActive`), `LocalTimelineDeletionPresentation.swift` (Presentation-Schicht über `LocalTimelineDeletionService`; dokumentiert: **kein Bookmark-/Preferences-Cleanup nötig im Store-Pfad** — keine UserDefaults für Standortdaten). **Geändert** `LH2GPXAppFlow.swift` (neue Methode `loadImportedFileEnvelope(...) -> EnvelopeImportOutcome` als feature-flagged Service-layer-Hook; **Legacy `loadImportedFile(...)` byte-identisch unverändert**). 5 neue Test-Dateien (`LocalTimelineDayListViewStateTests`, `LocalTimelineDayDetailViewStateAdapterTests`, `AppSessionLocalTimelinePresentationTests`, `LocalTimelineDeletionPresentationTests`, `AppFlowLocalTimelineEnvelopeTests`). Schema unverändert (`userVersion = 2`). **Status: Spike/pre-production, nicht UI-aktiv. Store-Pfad bleibt default AUS (LH2GPX_LOCAL_TIMELINE_STORE-Flag). Kein UI-Hook (kein Wrapper/SwiftUI-Wiring), kein Map/Heatmap/Overview/Export-UI-Hook. Kein AppExport im Store-Pfad materialisiert; keine vollständige `[Double]`-Import-Materialisierung. FileProtection-Status unverändert (Phase-4-Capsule, Aktivierung weiterhin Darwin/iOS-Pflicht). 46-MB-Gate bleibt FAILED / pending hardware retest unverändert.**
  - ✅ **Phase-8B erledigt (Store-backed Heatmap LOD Cache, Foundation-only)**: **NEU** `Sources/LocationHistoryConsumer/AppHeatmapPathSampler.swift` (Foundation-only Helper, kanonische Priorität: `flatCoordinates` wenn vorhanden + gerade Element-Anzahl, sonst `points` Fallback; ungerade flatCoordinates → kontrollierter Fallback auf points; **Heatmap-Doppelbug ab Phase 8B zentralisiert gefixt**), `LocalTimelineHeatmapModels.swift` (Foundation-only: `LocalTimelineHeatmapSample`, `LocalTimelineHeatmapSampleResponse`, `LocalTimelineHeatmapGridCell`, `LocalTimelineHeatmapLODResponse`, `LocalTimelineHeatmapCacheKey`, `LocalTimelineHeatmapCacheEncoding`), `LocalTimelineHeatmapGridAggregator.swift` (deterministischer Grid-Aggregator: cell-size pro Detail-Level overview=0.5°/low=0.1°/medium=0.02°/high=0.005°; hartes `maxCells`/`maxSamplesConsumed` Limit; stabile Sortierung lat asc, lon asc; 7 Tests), `StoreBackedHeatmapDataProvider.swift` (Foundation-only; `heatmapSamples(importID:viewport:maxRoutes:maxPointsPerRoute:maxSamples:)` bounded sampling, `heatmapLOD(importID:viewport:options:)` Grid-Aggregation optional cache-backed via `derived_cache`, `clearHeatmapCache(importID:)`; Cache-Payload-Codec deterministisch Magic 'L8B1' little-endian; Cache-Key über `LocalTimelineHeatmapCacheKey.make(...)` mit 1e-3°-Quantisierung; malformed `coord_blob` kontrolliert übersprungen; 11 Tests inkl. 50k synthetic store + cache hit/clear roundtrip). **Geändert** `AppHeatmapModel.swift:55-77` nutzt jetzt `AppHeatmapPathSampler` statt der bisherigen Doppel-Iteration über `path.points` UND `path.flatCoordinates` (7 neue Linux-grüne Tests in `AppHeatmapModelGeometryTests.swift`). **Geändert** `LocalTimelineStoreSchema.swift` (neue **additive** Tabelle `derived_cache` mit FK auf `imports.id` + `ON DELETE CASCADE`; zwei neue Indizes `idx_derived_cache_import_kind_key` und `idx_derived_cache_kind_created`; **`userVersion` bleibt 2** rein additiv, keine semantische Schema-Änderung), `LocalTimelineStore.swift` (CRUD: `putDerivedCache`, `derivedCache`, `deleteDerivedCache`, `countDerivedCache`; `deleteAll()` löscht jetzt auch `derived_cache`). **NEU** `LocalTimelineRTreeCapabilityTests.swift` dokumentiert RTree-Fallback (`paths.id` ist TEXT, RTree erwartet INTEGER `docid` → Surrogate-Integer-Mapping wäre Schema-breaking → RTree `path_bounds` bleibt **kontrolliert deferred**; Bbox-Index-Scan aus Phase 8A bleibt aktiv). **Bounded-Read-Garantien Phase 8B (zusätzlich zu 1-6 aus Phase 8A)**: 7) `heatmapSamples` viewport-gebunden, doppelt bounded (`maxRoutes` × `maxPointsPerRoute`), total-bounded (`maxSamples`); 8) pro Pfad lazy decode via `CoordBlobIterator`, nie vollständige Import-Geometrie im RAM; 9) `heatmapLOD` aggregiert nur bounded Samples, Cache-Payload trägt Zellen, keine Roh-Punkte; 10) `derived_cache` vom Import-Lifecycle abhängig (FK CASCADE) und über `clearHeatmapCache` invalidierbar. **Status: Spike/pre-production, nicht UI-aktiv. KEIN SwiftUI-Map/MKMapView-Hook, KEIN UI-Heatmap-Renderer-Hook (existierender SwiftUI-Heatmap-Renderer unverändert; konsumiert weiter `AppExport`). KEIN AppExport-Rebuild. KEIN vollständiger `[Double]`-Import-Buffer. KEIN Live-Upload-Mix. Store-Pfad bleibt default AUS. Schema additiv, `userVersion` unverändert 2/2. RTree kontrolliert deferred (Schema-breaking ohne Surrogate-Integer-Mapping). 46-MB-Gate bleibt FAILED / pending hardware retest.**
  - ✅ **Phase-10A erledigt (Store-DayMap UI Surface feature-flagged, 2026-05-08)**: feature-flagged Store-**DayMap-UI-Surface** in der bestehenden `LocalTimelineDayDetailView`. **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayMapViewState.swift` (Foundation-only Presentation Model: `LocalTimelineDayMapViewState`, `LocalTimelineDayMapSource`, harte `Budget`-Grenzen — default **12 Routen / 256 Punkte pro Route / 4096 Punkte gesamt**). **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayMapView.swift` (SwiftUI `#if canImport(SwiftUI)`-guarded **Placeholder; KEIN MapKit-Import**; echte `MKMapView`-/`MKMultiPolyline`-Verdrahtung explizit **Phase-10B Mac/Xcode-Pflicht**). **Geändert** `LocalTimelineDayDetailView` (neue optionale Map-Sektion; nur sichtbar wenn `mapSource != nil` und Pfad-Metadaten existieren; "Load map"-Button startet bounded Candidate-Load **ohne Koordinatendecodierung**; "Decode all routes" toggelt bounded Geometrie-Decode innerhalb `Budget`). **Geändert** `LocalTimelineSessionLandingView` (reicht neuen optionalen `dayMapSource` durch). **NEU** `LH2GPXAppFlow.makeProductionDayMapSource(for:)` (öffnet eigenen Reader auf `session.storeURL`, bindet `StoreBackedMapDataProvider`, nutzt Visit-Koordinaten als Bounds-Fallback). **Geändert** `Sources/LocationHistoryConsumerApp/AppShellRootView.swift` und `wrapper/LH2GPXWrapper/ContentView.swift` reichen neue Source ans Landing View durch. **NEU Tests** `Tests/LocationHistoryConsumerTests/LocalTimelineDayMapViewStateTests.swift` (7), `LocalTimelineDayMapBoundsTests.swift` (4) — alle Linux-grün. **Bounded-Read-Garantien Phase 10A**: Candidates lesen ausschließlich path metadata (kein `coord_blob`-Decodierung); Geometrie ausschließlich für selektierte pathIDs lazy decodiert; harte Budgets pro Route + pro Tag; Bounds primär aus path metadata (union der bbox-Spalten), Fallback auf Visit-Koordinaten via Closure, leerer Tag → `bounds == nil`; malformed `coord_blob` → kontrollierter `LocalTimelineMapProviderError.malformedCoordBlob` ohne Crash; Anti-Meridian bleibt Phase 10B/11. **Harte Grenzen Phase 10A**: Feature-flagged Store-DayMap-UI-Surface, kein Default-Rollout. **KEIN MapKit-Import** in der Phase-10A-View; echte `MKMapView`-Verdrahtung bleibt **Phase-10B Mac/Xcode-Pflicht**. **KEINE vollständige sichtbare Kartenmodernisierung.** Legacy-Map unverändert. KEIN AppExport-Rebuild aus Store. KEIN vollständiger `[Double]`-Import-Buffer. KEIN eager `coord_blob`-Decoding beim Candidate-Load. KEIN Live-Upload-Mix. KEINE neuen externen Dependencies. KEINE Darwin-FileProtection-Aktivierung. KEIN RTree. KEINE Hardware-/AppStore-/TestFlight-/ASC-Aussage. **46-MB-Gate bleibt FAILED / pending hardware retest.**
  - ✅ **Phase-9B erledigt (Store-DayList/DayDetail UI, 2026-05-08)**: feature-flagged Store-DayList + sheet-basierte DayDetail-Surface über die bestehende Landing-View. **Geändert** `AppSessionState` (neues Feld `selectedLocalTimelineDayId: String?` + Mutator `selectLocalTimelineDay(_:)`; in `show(localTimeline:)`/`show(content:)`/`clearContent()` mitgenullt). **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayBrowserSource.swift` (Foundation-only Source-Struct + `bind(session:reader:)` Convenience für die View-Hooks; **bounded — kein `coord_blob`, keine Polylines**). **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayListView.swift` (`#if canImport(SwiftUI)`-guarded) — Tage newest-first mit Datum / Routen / Visits / Distanz; **kein Map-Hook**. **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayDetailView.swift` (`#if canImport(SwiftUI)`-guarded) — Datum + Visits + Activities + Path-Metadaten + Hinweis "Path points available (not decoded)"; **kein eager `coord_blob`-Decoding, keine Map**. **NEU** `LH2GPXAppFlow.makeProductionDayBrowserSource(for:)` (öffnet `LocalTimelineStore` an `session.storeURL`). **Geändert** `LocalTimelineSessionLandingView` (erweitert um optionales `dayBrowser`/`selectedDayId`/`onSelectDay`; rendert Liste + sheet-basierte Detail-Navigation via NavigationStack; **backward-kompatibel**, defaults nil). **Geändert** `wrapper/LH2GPXWrapper/ContentView.swift` und `Sources/LocationHistoryConsumerApp/AppShellRootView.swift` reichen `makeProductionDayBrowserSource` + Selection-Binding durch. **NEU Tests** `Tests/LocationHistoryConsumerTests/LocalTimelineDayBrowserSourceTests.swift`, `LocalTimelineSelectionStateTests.swift`. **Harte Grenzen Phase 9B**: KEIN Map-/Heatmap-/Overview-UI-Hook gegen Store. KEIN AppExport-Rebuild. KEIN vollständiger `[Double]`-Import-Buffer. KEIN eager `coord_blob`-Decoding. KEIN Default-Rollout — Store-Pfad bleibt feature-flagged, default AUS. KEIN Live-Upload-Mix. KEINE neuen externen Dependencies. KEINE Darwin-FileProtection-Aktivierung. KEIN RTree. **46-MB-Gate bleibt FAILED / pending hardware retest.**
  - ✅ **Phase-9A erledigt (Wrapper/AppFlow-Wiring + Settings-Delete-Button + Landing-View, 2026-05-08)**: **NEU** `LH2GPXAppFlow.apply(envelopeOutcome:to:preserveOnFailure:) -> AppliedEnvelopeRouting` (geteilte Linux-testbare Routing-Helper-Funktion für Wrapper + Package-AppShell), `LH2GPXAppFlow.makeProductionDeletionPresentation()` (Convenience für Settings/Technical-Hosts). **Geändert** `wrapper/LH2GPXWrapper/ContentView.swift` und `Sources/LocationHistoryConsumerApp/AppShellRootView.swift` — beide rufen jetzt `loadImportedFileEnvelope(...)` (statt `loadImportedFile(...)`) und routen `.legacy/.localTimeline/.failure` über `apply(envelopeOutcome:to:)`. **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineSessionLandingView.swift` (`#if canImport(SwiftUI)`-guarded) — Landing-View bei aktiver `localTimelineSession` mit Session-Metadaten + Lösch-Button; **kein `coord_blob`-Read, kein Map/Heatmap/Overview-Hook**; eingebunden in beiden App-Shells via body-Branch `else if let storeSession = session.localTimelineSession`. **Geändert** `AppTechnicalOptionsView` (in `AppOptionsView.swift`) — neue Section "Local Timeline Store" mit Feature-Flag-Status (`LocalTimelineFeatureFlags.resolveFromProcess()` Enabled/Disabled), Status-Zeile "Pre-production / Feature-flagged", Lösch-Button "Delete imported local data" mit kontrollierten States idle/running/succeeded/failed. **NEU Tests** `Tests/LocationHistoryConsumerTests/WrapperLocalTimelineEnvelopeRoutingTests.swift` (6 Cases, Linux-grün): legacy/localTimeline/failure(clearBookmark T/F)/Replace-Invariante in beide Richtungen. **Status: Service- und Presentation-Schicht **UI-aktiv hinter Feature-Flag** — Tester mit `LH2GPX_LOCAL_TIMELINE_STORE=1` sehen Store-Session-Landing-View und Settings-Delete-Button. KEIN Map-/Heatmap-/Overview-UI-Hook gegen Store. KEIN AppExport-Rebuild aus Store. KEIN vollständiger `[Double]`-Import-Buffer. KEIN Default-Rollout — Store-Pfad bleibt feature-flagged, default AUS. KEIN Live-Upload-Mix. KEINE neuen externen Dependencies. KEINE Darwin-FileProtection-Aktivierung. KEIN RTree (bleibt deferred, TEXT path-IDs). 46-MB-Gate bleibt FAILED / pending hardware retest. Settings-DayList/DayDetail UI ist nur als Landing-View für Store-Session sichtbar; vollständige Store-DayList/DayDetail-UI bleibt Phase 9B.**
  - **Phase-10B (verbleibend offen vor produktivem UI-Rollout, nach Phase 10A)** — verbleibende Pflichten:
    - **Echte MapKit-/`MKMapView`-/`MKMultiPolyline`-Verdrahtung** der Phase-10A Store-DayMap-Placeholder-View — Mac/Xcode-Pflicht (Linux-Server kann MapKit nicht bauen). Anti-Meridian-Behandlung (direktes min/max-Reduce) gehört in diesen Schritt.
    - **Heatmap-/Overview-UI-Hook** gegen `StoreBackedHeatmapDataProvider` — deferred (Provider ist ab Phase 8B kanonische Schnittstelle, aber kein UI-Hook).
    - **Export-UI-Hook** (Settings/Export-Tab) gegen `StoreBackedExportWriter` — deferred.
    - **Darwin FileProtection-Aktivierung** (`URLResourceKey.fileProtectionKey = .completeUnlessOpen` bzw. `SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN` an `sqlite3_open_v2`) auf Apple-Plattformen, mit Hardware-Verifikation. Phase-4-Capsule unverändert.
    - **46-MB-Hardware-Retest** auf iPhone 15 Pro Max (Mac/iPhone-Handoff) — bleibt FAILED / pending bis Tester-Bestätigung.
    - **RTree (`path_bounds` virtual table)** — würde Surrogate-Integer-Mapping erfordern (`paths.id` TEXT vs RTree INTEGER `docid`) → Schema-breaking; bewusst deferred.
    - **Privacy-Doku-Update** (`docs/privacy.html`, `docs/PRIVACY_MANIFEST_SCOPE.md`) auf den tatsächlichen Rollout-Stand — vor Rollout zwingend.
    - **Store-Default-Rollout** / App-Flow-Umschaltung gegen Conditional-Gate-Entscheidung (AppContentLoader-Default auf Store, Session-Switch).
    - **TestFlight / Xcode-Cloud Build ≥100** — nicht beansprucht.
    - ✅ **Wrapper/AppFlow-Wiring** der Presentation-/ViewState-Schicht (Routing-Helper + Wrapper-/AppShell-Umstellung auf Envelope-Pfad) — erledigt in Phase 9A.
    - ✅ **Settings-Delete-UI-Button** „Delete imported local data" in `AppTechnicalOptionsView` — erledigt in Phase 9A.
    - ✅ **Store-DayList/DayDetail UI** (`LocalTimelineDayListView`/`LocalTimelineDayDetailView`, feature-flagged) — erledigt in Phase 9B.
    - ✅ **Store-DayMap-UI-Surface (Foundation-only Presentation Model + SwiftUI Placeholder, kein MapKit-Import)** — erledigt in Phase 10A.
  - ✅ **Phase-8A erledigt (Store-backed Map Data Provider, Foundation-only)**: **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineMapModels.swift` (Foundation-only Map-Domain-Modelle: `LocalTimelineMapViewport` mit Anti-Meridian-Reject, `LocalTimelineMapDetailLevel` overview/low/medium/high, `LocalTimelineMapPointBudget` default-Tabelle pro Level monoton, `LocalTimelineMapQuery`, `LocalTimelineMapRouteCandidate` metadata-only, `LocalTimelineMapPoint`, `LocalTimelineMapRouteGeometry` bounded points, `LocalTimelineMapOverviewResponse` mit `truncatedRoutes`/`truncatedPoints`, `LocalTimelineMapBounds`, `LocalTimelineMapProviderError`; **keine SwiftUI/MapKit/CoreLocation-Abhängigkeit**), `StoreBackedMapDataProvider.swift` (`routeCandidates(importID:viewport:limit:)`/`dayRouteCandidates(dayID:viewport:limit:)` metadata-only ohne `coord_blob`, `routeGeometry(pathID:detailLevel:maxPoints:)` lazy single-path decode via `CoordBlobIterator`, `overviewRoutes(query:)` doppelt bounded mit `maxRoutes` und `budget.maxTotalPoints`, `mapBounds(forImportID:)`/`mapBounds(forDayID:)` Aggregat über `paths.min/max_lat/lon` ohne Geometrie-Decode), `LocalTimelineRouteDecimator.swift` (deterministischer stride-/budget-basierter Decimator, Iterator-basiert über `Sequence<EncodedCoordinate>`, erster + letzter Punkt erhalten, `maxPoints` hart, leere/1-Punkt-Pfade stabil; **Douglas-Peucker bleibt Phase 8B/9**). **Geändert** `LocalTimelineStoreSchema.swift` (zwei neue **additive** Indizes `idx_paths_bounds_minmax` und `idx_paths_day_bounds`; **`userVersion` bleibt 2**; RTree-`path_bounds` virtuelle Tabelle bleibt Phase-8B-Pflicht), `LocalTimelineStore.swift` (neue public APIs `pathMetadata(forImportId:viewportMin/Max...:limit:)`, `pathMetadata(forDayId:viewportMin/Max...:limit:)`, `pathBoundingBox(forImportId:)`, `pathBoundingBox(forDayId:)` plus Test-Helper `indexNames(forTable:)`; bbox-Filter linear scan über `min/max_lat/lon`, NULL-Bounds konservativ als überlappend gewertet, newest-first `ORDER BY start_time`), `LocalTimelineStoreReader.swift` (thin wrappers `pathMetadata(forImportId:viewport:limit:)`, `pathMetadata(forDayId:viewport:limit:)`, `pathBoundingBox(forImportId:)`, `pathBoundingBox(forDayId:)`). 4 neue Test-Dateien, 33 Cases (`StoreBackedMapDataProviderTests` 15 inkl. 50k-synthetic-store-bounded, malformed `coord_blob`-Fehlerpfad, unknown import returns empty, unknown path throws, viewport-Filter, day-scope, overview maxRoutes/maxTotalPoints; `LocalTimelineRouteDecimatorTests` 8; `LocalTimelineMapBoundsTests` 7 inkl. viewport-Validation flipped lat/antimeridian/out-of-range, intersect classic/disjoint/null-bounds, point-budget defaults monoton; `LocalTimelineMapSchemaIndexTests` 2 inkl. fresh-store-hat-beide-Indizes und reopened-store-nach-DROP-gewinnt-sie-additiv-zurück, `userVersion` bleibt 2). **Bounded-Read-Garantien Phase 8A** (in Provider-Doc-Kommentaren verankert): route candidates lesen kein blob, route geometry single-path lazy decode, overview doppelt bounded (`maxRoutes` + `budget.maxTotalPoints`), mapBounds-Aggregat ohne Geometrie-Decode, kein `AppExport` über Provider, kein `[Double]` für ganzen Import. **Status: Spike/pre-production, nicht UI-aktiv. KEIN SwiftUI-Map/MKMapView-Hook, KEIN UI-Hook, KEIN Renderer-Wechsel in dieser Phase. KEIN AppExport-Rebuild aus Store. KEIN vollständiger `[Double]`-Import-Buffer. KEIN Live-Upload-Mix. Store-Pfad bleibt default AUS (`LH2GPX_LOCAL_TIMELINE_STORE`-Flag unverändert). Schema unverändert (`userVersion = 2`, Indizes additiv). FileProtection-Status unverändert (Phase-4-Capsule). Provider ist ab jetzt die kanonische Schnittstelle für künftige UI-Hooks. 46-MB-Gate bleibt FAILED / pending hardware retest unverändert.**
  - **(Phase-8B-Punkte aus dieser Stelle entfernt; ersetzt durch Phase-9-Block oben — Heatmap-Doppelbug, `derived_cache`, Heatmap-LOD-Persistenz sind in Phase 8B erledigt; RTree, UI-Wiring, FileProtection, Export-UI, 46-MB-Retest, Privacy-Doku rollen weiter in Phase 9.)**
  - Map-Modernisierung (UIKit `MKMapView`/`MKMultiPolyline`/`MKTileOverlay`) bleibt **blockiert**, bis 46-MB-Hardware-Pass ODER klare LocalTimelineStore-P0-Entscheidung vorliegt. **46-MB-Gate bleibt FAILED unverändert.**
- [ ] **Live Activity / Dynamic Island / Lock Screen** — siehe Sektion 2 in `docs/APPLE_VERIFICATION_CHECKLIST.md` (Manual Release Risk Acceptance Protocol)
- [ ] **iPad-Layout (Days-Tab + Hero-Map-Workspace)** — siehe Sektion 3 in `docs/APPLE_VERIFICATION_CHECKLIST.md` (Manual Release Risk Acceptance Protocol)
- [ ] **ASC / TestFlight / Apple Review (1.0 Build 74 vs 1.0.1 Train, Build-Liste, nächster Submit-Schritt, ggf. Xcode Cloud Build ≥ 100)** — siehe Sektion 4 in `docs/APPLE_VERIFICATION_CHECKLIST.md` (Manual Release Risk Acceptance Protocol)

### Audit-Status 2026-05-06 (P0)

Acht P0-Findings aus `docs/DEEP_AUDIT_2026-05-06.md` sind jetzt umgesetzt:
- P0-1 Live-Tab-Deeplink (`AppContentSplitView`, vorheriger Patch)
- P0-2 GPX-Force-Cast `as!` in `GPXImportParser.buildDaysDict` durch defensives `as? String ?? ""` ersetzt
- P0-3 `fatalError` in `GPXImportParser.makeExport` entfernt — wirft jetzt `AppContentLoaderError.decodeFailed`
- P0-4 `kCFBooleanTrue!` Force-Unwrap in `KeychainHelper` durch `true as CFBoolean` ersetzt
- P0-5 `AppExportSchemaVersion` jetzt forward-kompatibel (`struct` mit `rawValue: String`, `isSupportedByThisBuild`); zukünftige Tool-Versionen sind decodierbar, statt mit `unknownSchemaVersion` abgelehnt zu werden
- P0-6 `LH2GPXLoadingBackground.RoutePulseOverlay`: TimelineView 30 Hz → 20 Hz, `paused: progress >= 1.0` als defensiver Stop
- P0-7 TCX-Export-Doku-Lüge in `README.md` (vorheriger Patch)
- P0-8 ROADMAP-Test-Count-Widerspruch (964 vs 1006) per commit-verankerter Verifikations-Historie aufgelöst

Verbleibend offen: ~7× P1 (P1-18..P1-24 Test-Lücken), ~19× P2. P1-3 (`WidgetDataStore`-Duplikat) und P1-4 (`onOpenURL` fehlt im Package-Target) im Doku-Train 2026-05-07 erledigt. ZIP-Entry-Streaming (Audit-Folge) erledigt 2026-05-07. Mikro-Benchmark als Baseline-Logging hinzugekommen (kein fail-on-regression bar). Hardware-Re-Verifikation auf iPhone 15 Pro Max steht weiterhin aus.

### Audit-Batch 2026-05-06 (Block 1-4) — 19 Achsen erledigt

19 Audit-Achsen aus den Blöcken 1-4 sind in diesem Doku-Train als erledigt verbucht (`swift test` 1012/2/0 unverändert; `xcodebuild` iPhone 17 Pro Max Sim 26.3.1 BUILD SUCCEEDED):

**Block 1 — Datenverlust / falsche User-Daten (Audit-Items 1-4 erledigt):**
- [x] Item 1: 30 s Per-Request-Timeout in `LiveLocationServerUploader` — hängender Server blockiert Upload-Queue nicht mehr.
- [x] Item 2: `AppExportView` filtert jetzt nach `dayListFilter`, `favoritedDayIDs`, `pathMutations` (Default `.empty`) — Day-Tab-Filter und gelöschte Routen wirken in GPX/KMZ/KML/GeoJSON/CSV-Exports + Vorschau.
- [x] Item 3: `AppContentSplitView` reicht `dayListFilter`, `favoritedDayIDs`, `pathMutationStore.currentMutations` an beide `AppExportView`-Call-Sites.
- [x] Item 4: `AppImportedPathMutationStore.persist()` verschluckt Encode-Fehler nicht mehr — `@Published var lastPersistFailed`.

**Block 2 — Concurrency / Resource-Lecks (Audit-Items 5-8 erledigt):**
- [x] Item 5: `ActivityManager._endActivityInternal` Identity-Check; `_cancelAllActivitiesInternal` `@MainActor`; `_updateActivityInternal` `[weak self]`.
- [x] Item 6: `LiveLocationFeatureModel.deinit` cancelt `uploadTask`.
- [x] Item 7: `AppOptionsView.testConnection()` auf `Task { @MainActor in ... }` migriert.
- [x] Item 8: `AppContentSplitView.presentSheet(_:)` auf `Task { @MainActor in ... }` migriert.

**Block 3 — Edge-Case-Crashes / stillschweigende Fehler (Audit-Items 9-11 erledigt):**
- [x] Item 9: `KMZBuilder` Bounds-Guard in ZIPFoundation-`provider`-Closure.
- [x] Item 10: `AppContentLoader.sniffEntryHead` differenziert `StopExtraction` von echten ZIPFoundation-Fehlern — kein leerer „valider"-Export mehr durch verschluckte Read-Fehler.
- [x] Item 11: `ImportBookmarkStore.restore(userDefaults:)` ruft `startAccessingSecurityScopedResource()` auf der resolved URL auf; neue API `releaseAccessIfNeeded(url:)`.

**Block 4 — Performance-Hotspots (Audit-Items 12-19 erledigt):**
- [x] Item 12: `DayMapRenderData.PathOverlay.simplifiedCoordinates` precomputed im Init.
- [x] Item 13: Doppel-Sort gefixt in `AppExportQueries.projectedDays` + `DaySummaryDisplayOrdering.newestFirst` (O(n) Reverse statt O(n log n) Sort auf monoton-asc-Input).
- [x] Item 14: `AppInsightsContentView.weekdayStats` aus `derivedModel.weekdayStatsByMetric` gelesen, Pre-Computation in `refreshDerivedModel`.
- [x] Item 15: `DaySummaryRowPresentation`-Formatter sind jetzt `private static let`.
- [x] Item 16: `AppHeatmapView.formatCount` mit statischem `baseCountFormatter`; `.continuous`-CameraChange-Handler entfernt.
- [x] Item 17: `DayMapRenderData.init` ISO8601-Formatter als statische Properties.
- [x] Item 18: `AppExportQueries.weekdayForDate` mit statischem `utcGregorianCalendar`.
- [x] Item 19: `AppDisplayHelpers.weekday(_:locale:)` / `monthYear(_:locale:)` nutzen `NSCache<NSString, DateFormatter>`.

Nicht in diesem Train erledigt (weiterhin offen): P1-18..P1-24 (Test-Lücken), Hardware-Verifikation iPhone 15 Pro Max, Live-Activity-Lock-Screen.

### Audit-Batch 2026-05-07 (Block 1-2 Wiring + Streaming-Folge) — 7 Achsen erledigt

7 Audit-Achsen in diesem Doku-Train als erledigt verbucht (`swift test` 1017/2/0; +5 neue Cases gegenüber 1012; `xcodebuild` iPhone 17 Pro Max Sim 26.3.1 BUILD SUCCEEDED):

**Block 1 — Wiring / Config:**
- [x] `WidgetSharedKeys.swift` (NEU) als Single-Source-of-Truth für App-Group-Suite + UserDefaults-Keys; `Sources/.../WidgetDataStore.swift` und `wrapper/LH2GPXWidget/WidgetDataStore.swift` referenzieren die Konstanten; `saveDynamicIslandCompactDisplay` ist im Wrapper-Mirror ergänzt (P1-3 erledigt).
- [x] `AppShellRootView.swift` mit `.onOpenURL { handleDeepLink($0) }` im Package-App-Target — `lh2gpx://live` springt jetzt auch dort den Live-Tab an (P1-4 erledigt).
- [x] Deployment-Target-Inkonsistenz (App 16.0 vs Widget 16.2) als bewusste Entscheidung in `wrapper/README.md` notiert (Live Activities erfordern 16.2).

**Block 2 — Streaming-Folge:**
- [x] **ZIP-Entry-Streaming** für Google Timeline implementiert (`AppContentLoader.streamGoogleTimelineCandidateIfApplicable`): Sniffer-basiert, greift bei genau einem Google-Timeline-Entry und keinem LH2GPX-Object-Entry; Peak RAM auf ~ein Element statt voller entpackter Datei (P1-5 erledigt).
- [x] `GoogleTimelineStreamReader.IncrementalParser` (stateful chunk-fed) plus `GoogleTimelineConverter.incrementalStreamConverter()`/`IncrementalStreamConverter`.
- [x] **Import-Phasen-Progress**: `AppContentLoader.loadImportedContent` mit `onPhase: ((ImportPhase) -> Void)?` und `enum ImportPhase { reading, parsing, building }`; `LoadingProgressEngine.phase` + `setPhase(_:)`; `wrapper/.../ContentView.swift` zeigt lokalisiertes Phase-Label. Auto-Restore-Pfad reicht den Callback bewusst nicht durch.
- [x] **Mikro-Benchmark**: `GoogleTimelineStreamReaderPerformanceTests` (3 `measure`-Cases) — Baseline-Logging, kein fail-on-regression bar, kein gemessener Speedup-Faktor.

### Audit-Batch 2026-05-07 (Bündel B+C+D+A) — 22 Achsen erledigt

22 Audit-Achsen aus den Bündeln B (Dead-Code), C (Performance-Restposten), D (Architektur), A (Test-Härtung) als erledigt verbucht (`swift test` **1044/2/0**; +27 Cases gegenüber 1017; Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1 BUILD SUCCEEDED):

**Bündel B — Dead-Code (5 Items, ~158 Zeilen weniger):**
- [x] **P2-5**: `AppDayDetailView.quickStat(_:label:icon:color:)` (~21 Zeilen, kein Caller) entfernt.
- [x] **P2-6**: `AppDayDetailView.DayTimelineView` (~123 Zeilen, kein Caller) entfernt.
- [x] **P2-7**: `AppContentSplitView.activeFiltersSection(_:)` (~14 Zeilen, kein Caller) entfernt.
- [x] **P2-9**: `LHSharedMapChrome.swift` gelöscht — `LHMapStyleToggleButton` public API entfernt (war deprecated, keine externen Caller bekannt, durch `MapLayerMenu` ersetzt).
- [ ] **P2-8** (bewusst nicht angefasst): Live `mapCard` (Landscape) und `liveHeroMap` (Portrait) Duplikat-Refactor. `mapControlRow` hat realen Caller in `landscapeMapColumn` — Audit-Beschreibung war ungenau.

**Bündel C — Perf-Restposten (4 Items):**
- [x] **P2-10**: `OverviewMapRenderData: Equatable` mit Hand-`==` (totalRouteCount/isOptimized/isLoading/pathOverlays + center.lat/lon + span.deltas).
- [x] **P2-11**: `approximateDistance(for:)` inline Haversine (Erdradius 6 371 000 m) — keine `CLLocation`-Allokation mehr im Distance-Fallback.
- [x] **P2-12**: `HeatmapGridBuilder` Single-Sort + `suffix`-Trim statt Doppel-Sort.
- [x] **P2-13**: `AppExportQueries.findDay(on:in:applying:)` Fast-Path für `isPassthrough`-Filter — DayDetail-Open ohne volle `projectedDays`-Projektion.

**Bündel D — Architektur (4 Items):**
- [~] **P2-17 (SKIP)**: `wrapper/CI.xctestplan` unverändert. Test-Plan referenziert `LH2GPXWrapper.xcodeproj`-containerPath; SwiftPM-Test-Target `LocationHistoryConsumerPackageTests` ohne pbxproj-Integration nicht aufnehmbar. `.github/workflows/swift-test.yml` deckt SwiftPM-Suite weiterhin separat ab.
- [x] **P2-19**: `@testable import` → reines `import` für **15 von 22 Test-Files** (APIs sind dort vollständig public): `DayFavoritesStoreTests`, `RecentFilesStoreTests`, `LiveLocationFeatureModelTests`, `HistoryDateRangeFilterTests`, `ExportSelectionRouteTests`, `RecordingIntervalPreferenceTests`, `AppLanguageSupportTests`, `ImportBookmarkStoreTests`, `ChartShareHelperTests`, `LHMapHeaderTests`, `LiveStatusResolverTests`, `LoadingProgressEngineTests`, `RecordedTrackStoreTests`, `LiveTrackRecorderTests`, `InsightsDrilldownTests`. 7 Files behalten `@testable` (internal-Symbole nötig): `AppContentLoaderTests`, `AppPreferencesTests`, `LiveActivityTests`, `LiveTrackingPresentationTests`, `RecordedTrackEditorDraftTests`, `RecordedTrackEditorPresentationTests`, `SavedTracksPresentationTests`, `WidgetDataStoreTests`.
- [ ] **P2-16** (bewusst nicht angefasst): API-Naming-Vereinheitlichung `parse`/`convert`/`decode`/`load` — public-API-Rename mit Folgerisiken.
- [ ] **P2-18** (bewusst nicht angefasst): `HeatmapGridBuilder` MapKit-Entkopplung — public-API-Rename mit Folgerisiken.

**Bündel A — Test-Härtung (9 neue Test-Files, 27 neue Cases):**
- [x] **P1-18**: `AppExportDecoderErrorTests.swift` (5 Cases): leere Data, korrupter JSON, missing data/meta/schema_version.
- [x] **P1-19**: `GPXImportParserErrorTests.swift` (3 Cases): malformed XML, leere Trackpoints, nicht parsebare Timestamps.
- [x] **P1-20**: `TCXImportParserErrorTests.swift` (2 Cases): malformed XML, leere Trackpoints. `exportRoundTripFailed` defensive Branch dokumentiert geskippt.
- [x] **P1-21**: `GPXRoundTripTests.swift` (2 Cases): Track-Coordinates 1e-6, Waypoints.
- [x] **P1-22**: `AppExportQueriesFilterCombinationTests.swift` (4 Cases): date+accuracy, activityType+date, accuracy+activityType, Dreifach-Kombi.
- [x] **P1-23**: `AppHeatmapModelEdgeCaseTests.swift` (3 Cases): empty/single-day/no-paths.
- [x] **P1-24**: `LiveLocationFeatureModelStateTransitionTests.swift` (1 Placeholder-Case) — Mock-Client `private` im bestehenden Test-File; Refactor pending; explicit-doc-comment im Test.
- [x] (extra) `ExportMutationsAndFilterTests.swift` (4 Cases): Mutations respektiert, empty leaves unchanged, hasRoutes-Chip, favorites-Parameter.
- [x] (extra) `ZIPGoogleTimelineStreamingPathTests.swift` (3 Cases): Timeline-Entry, AppExport-Fallback, Mixed-ZIP.

**Verbleibend offen aus dem Audit:** P2-8 (Live-Duplicate-Refactor, bewusst nicht angefasst), P2-18 (HeatmapGridBuilder MapKit-Entkopplung). Hardware-Re-Verifikation iPhone 15 Pro Max bleibt offen.

### Audit-Batch 2026-05-07 (Phase 1-5, items 2-15) — 14 Achsen erledigt

14 Audit-Achsen über zwei Commits in diesem Train (`swift test` **1045/2/0**; +1 Case gegenüber 1044 — Mock-Refactor in Item 7 ersetzt einen Placeholder-Case durch zwei echte Cases, netto +1; Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1 BUILD SUCCEEDED). Commits: `21b4026` (Phase 1) + `20877ae` (Phase 2-5).

**Phase 1 — `21b4026`:**
- [x] **Item 3** — `projectedDays`-Cache (Memoization, Re-Compute nur bei Input-Änderung).
- [x] **Item 4** — Mutations-Index (O(1)-Lookup im `AppImportedPathMutationStore`).
- [x] **Item 5** — Race-Token (Stale-Result-Guard in async Filter-/Day-Switch-Pfaden).
- [x] **Item 6** — Live-Map-Dedup (geteilte Map-Render-Helper im Live-Feature).
- [x] **Item 8** — `@testable import` → `import` Cleanup-Folge.

**Phase 2-5 — `20877ae`:**
- [x] **Item 7** — Mock-Client + State-Transition-Tests (Mock extrahiert; Placeholder ersetzt durch zwei echte Cases; netto +1 Case).
- [x] **Item 11 + Item 2** — `LH2GPXAppFlow` extrahiert (Drift Wrapper ↔ Package-App-Einstieg) plus Auto-Restore-Phasen.
- [x] **Item 9** — API-Naming (sanft umgesetzt — kein Rename, additives Importing-Protokoll).
- [~] **Item 10** — `wrapper/CI.xctestplan` SwiftPM-Coverage **SKIP** — pbxproj-Integration zu fragil, out-of-scope.
- [x] **Item 12** — `Tests/README.md` aktualisiert.
- [x] **Items 13/14/15** — Doku-Truth-Cleanup (ROADMAP/NEXT_STEPS/CHANGELOG/README/wrapper-Docs/Apple-Checklist konsistent).

**Verbleibend offen:** Item 10 als bekannte SKIP, Hardware-Re-Verifikation iPhone 15 Pro Max, alle Hardware-Items, plus die noch nicht angefassten UX-P1 (P1-31..P1-40 falls nummeriert).

### P1-Hardening-Train 2026-05-07 — 3 Achsen erledigt + 8 neue Tests

P1-Hardening-Train (`swift test` **1065/2/0**; +8 Cases gegenüber 1057; Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1 BUILD SUCCEEDED; HEAD `3811bc3`):

- [x] **B1 distanceText! Force-Unwrap entfernt** (2026-05-07): `DaySummaryRowPresentation.swift:88-103` — `formatDistance` (non-optional) in lokale Konstante gebunden; Verhalten unverändert.
- [x] **B2 weak self in AppOverviewMapModel** (2026-05-07): `AppOverviewTracksMapView.swift` — `rebuildOverlays` Task-Closures von `[self]` auf `[weak self]` mit `guard let self else { return }` vor MainActor-Writes; Race-Token-Logik unverändert.
- [x] **B3 Upload-URL-Validation** (2026-05-07): `AppPreferences.swift` — neuer privater Helper `Self.isValidUploadEndpoint(_:)`; `liveLocationServerUploadURLString.didSet` validiert vor UserDefaults-Write; `https://`, `localhost`, `127.0.0.1`, `[::1]` akzeptiert; sonst Reject mit Reset auf `oldValue` per Re-Entrancy-Flag `isRevertingUploadURL`. Token-Property + Keychain unverändert; kein Logging des Inputs.
- [x] **C 8 neue URL-Validation-Tests** (2026-05-07): `Tests/LocationHistoryConsumerTests/AppPreferencesUploadURLValidationTests.swift`.

**Verbleibend offen:** Hardware-Re-Verifikation iPhone 15 Pro Max für aktuellen HEAD; ASC/TestFlight-Status nicht geprüft; 46-MB-Crashfall geräteseitig nicht validiert.

### UX/Layout-Train + Mock-Helper 2026-05-07 — 6 Achsen erledigt

6 Achsen in diesem Train als erledigt verbucht (`swift test` **1057/2/0**; +12 Cases gegenüber 1045 — neue Hero-Map-Layout-Tests; Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1 BUILD SUCCEEDED; HEAD `5c69afe`):

- [x] **Mock-Client extrahiert** — neuer File `Tests/LocationHistoryConsumerTests/Helpers/MockLiveLocationClient.swift` (`MockLiveLocationClient`, `InMemoryRecordedTrackStore`, `emitLocationSamples`-Convenience). `LiveLocationFeatureModelStateTransitionTests` und `LiveLocationFeatureModelTests` nutzen den geteilten Helper. Mock-Client-Refactor (Folge zu Phase 1-5 Item 7) damit erledigt.
- [x] **Insights Triple-Range-Picker konsolidiert** — `AppInsightsContentView.swift` zeigt im `heroEnabled`-Pfad nur den Hero-Strip; Card + innere Pills ausgeblendet. Legacy/iPad-Pfad behält Card als Fallback.
- [x] **Overview Doppel-Header gelöst** — Card "Overview" → "Statistics" (de: "Statistik"); Page-Header bleibt. Lokalisierung in `AppLanguageSupport.swift`.
- [x] **Map-Pill-Overlap gefixt** — `AppOverviewTracksMapView.swift` Badge+Banner in `VStack(alignment: .trailing)` an `.bottomTrailing` zusammengeführt.
- [x] **Form-vs-LHCard-Konsistenz Settings (schmaler Scope)** — `AppPrivacyOptionsView` + `AppTechnicalOptionsView` auf `Form`/`Section`. Hinweis: schmaler Scope — Privacy + Technical migriert; LiveRecording/Upload/Widget-LiveActivity bleiben LHCard (Custom-Preview-Karten + Status-Chips).
- [x] **Hero-Map-Layout-Tests** — neuer File `LHMapHeaderLayoutTests.swift` mit 12 property-based Layout-Cases (kein SnapshotTesting-Framework im Repo).

**Verbleibend offen:** Hardware-Re-Verifikation iPhone 15 Pro Max, Cleanup-Follow-up Hero-Map (Live-Duplicate-Refactor P2-8), volle Form-Migration der verbleibenden 3 LHCard-Sub-Views.

## P0 — Release / Review / Hardware-Verifikation

- [x] **Review-Response senden (Guideline 3.2)**: gesendet von Sebastian. Apple hat Build 74 nach Review-Response akzeptiert. Status: **Ausstehende Entwicklerfreigabe (Pending Developer Release)**. Guideline 3.2: resolved. (2026-05-05)
- [x] **Build 74 / 1.0-Train abgeschlossen**: Version 1.0 (Build 74) bleibt in „Pending Developer Release" — 1.0-Train ist in ASC geschlossen. Builds 80–83 scheiterten wegen geschlossenem 1.0-Train (ITMS-90186/90062), nicht wegen Code-Fehler.
- [x] **MARKETING_VERSION auf 1.0.1 angehoben** (2026-05-05): `project.pbxproj` alle 8 Konfigurationen auf `1.0.1`; Plists weiterhin via `$(MARKETING_VERSION)`. ASC hat Version `1.0.1` bereits angelegt.
- [x] **Xcode Cloud Build 84 erfolgreich** (2026-05-05): `1.0.1 (84)` — Archive ✅, TestFlight-interne Tests ✅. Erster valider Build für den 1.0.1-Train.
- [ ] **Xcode Cloud Build ≥100 triggern** (Pflicht vor Submit):
  - Build 95 ist veraltet; `CURRENT_PROJECT_VERSION` lokal auf `100` angehoben (commit `8854eef`, 2026-05-06).
  - Neuester Commit-Stand: `feat: unify map layer controls into single right-side dropdown` (`70254ff`) plus Doku-/Wiring-Audit-Polish.
  - Xcode Cloud Workflow `Release – Archive & TestFlight` manuell anstoßen.
  - Visuelle Verifikation am echten iPhone 15 Pro Max steht noch aus (App ist installiert + gestartet).
- [ ] **Days-Screenshot (iphone15pm_03) neu aufnehmen**: UITest `testAppStoreScreenshots` auf iPhone 15 Pro Max ausführen — Days-Layout erneut verändert (Control-Clearance, kein schwarzer Gap, kompakter Filter). Neues PNG in `docs/app-store-assets/screenshots/iphone-67/` ablegen.
- [ ] **Version 1.0.1 in App Store Connect finalisieren** (nach neuem Cloud-Build):
  1. ASC → LH2GPX → Vertrieb → iOS-App Version `1.0.1` öffnen
  2. Neuen Build (**≥ 100**, nach diesem Commit) auswählen, speichern — **nicht Build 95 oder früher**
  3. Screenshots prüfen: 6 iPhone-15-Pro-Max-PNGs aus `docs/app-store-assets/screenshots/iphone-67/` hochladen (iphone15pm_01–06, 1290×2796 px)
  4. `Zur Prüfung einreichen` (`Submit for Review`)
  - Runbook: `docs/ASC_SUBMIT_RUNBOOK.md`
- [x] **Neue Screenshots aufnehmen**: UITest `testAppStoreScreenshots` auf iPhone 15 Pro Max ausgeführt → 6 neue PNGs (iphone15pm_01_import bis iphone15pm_06_live_tracking, 1290×2796 px) in `docs/app-store-assets/screenshots/iphone-67/` gespeichert (2026-05-05). Screenshot-Pflichtset auf 6 Top-Level-Flows reduziert: Options (kein Tab) entfernt.
- [x] Support-URL in App Store Connect eingetragen: `https://dev-roeber.github.io/iOS-App/support.html` (2026-04-30)
- [x] Privacy-URL in App Store Connect eingetragen: `https://dev-roeber.github.io/iOS-App/privacy.html` (2026-04-30)
- [x] GitHub Pages fuer `/docs` live und oeffentlich erreichbar (HTTP 200 verifiziert 2026-04-30): `https://dev-roeber.github.io/iOS-App/`, `/support.html`, `/privacy.html`
- [ ] Live Activity / Dynamic Island auf echter Hardware vervollstaendigen: Lock Screen, `minimal`, Fallback bei deaktivierten / nicht verfuegbaren Live Activities, No-Dynamic-Island-Geraet (Pending-/Restart-Pfad jetzt gruen)
- [x] Live Tracking / Live Tracks Library auf echter Apple-Hardware verifiziert: UITest `testDeviceSmokeNavigationAndActions` auf iPhone 15 Pro Max (iOS 26.4) PASSED (2026-05-05); Start/Stop Recording, Live-Tab-Navigation bestätigt
- [x] Days-Tab: Landscape-Verifikation auf echtem Gerät — `testLandscapeLayoutSmoke` auf iPhone 15 Pro Max PASSED (62s), 5 Tabs ohne Crash (2026-05-05); Live-Start-Button Accessibility in Landscape als UITest-Limit dokumentiert
- [ ] Days-Tab: iPad-Verifikation — `regularSplitView` nutzt `daysMapHeaderCard` via `AnyView`, visuell ungeprüft
- [ ] **Hero-Map-Workspace iPad/Landscape-Verifikation**: Compact iPhone vereinheitlicht (commit e11d4d7, 2026-05-06) — Übersicht/Insights/Export/Live nutzen Tage-Hero-Stil. iPad-Regular und Landscape behalten Legacy-Pfade; visuelle Verifikation an realem iPad + iPhone-Landscape steht aus.
- [x] **Hero-Map-Layout-Tests ergänzt** (2026-05-07): neuer File `Tests/LocationHistoryConsumerTests/LHMapHeaderLayoutTests.swift` mit 12 property-based Layout-Cases (compactHeight=460, expandedHeight=560, mapControlTopOffset≥124, sticky-Init, expand()-Transition, Sticky-cannot-hide, mapFrameHeight für compact/expanded/hidden/fullscreen). Kein SnapshotTesting-Framework im Repo — Layout-Tests sind property-based.
- [ ] **Cleanup-Follow-up Hero-Map**: `AppDayDetailView.mapControlRow` ist im Portrait toter Code (Landscape-only). Live `mapCard` (Landscape) und `liveHeroMap` (Portrait) duplizieren Map-Rendering — Konsolidierung in shared ViewBuilder.
- [x] **Insights Triple-Range-Picker konsolidiert** (2026-05-07): `AppInsightsContentView.swift` zeigt im `heroEnabled`-Pfad nur noch den Hero-Strip; `AppHistoryDateRangeControl`-Card + innere Pills ausgeblendet. Im Legacy/iPad-Pfad bleibt die Card als Fallback.
- [x] **Overview Doppel-Header gelöst** (2026-05-07): Card-Header in `overviewKPISection` umbenannt von "Overview" → "Statistics" (de: "Statistik"); Page-Header + `navigationTitle` bleiben "Overview". Lokalisierung in `AppLanguageSupport.swift` ergänzt.
- [x] **Map-Pill-Overlap gefixt** (2026-05-07): `AppOverviewTracksMapView.swift` — Route-Count-Badge + Optimization-Banner in einen `VStack(alignment: .trailing)` an `.bottomTrailing`-Overlay konsolidiert. Linke untere Ecke frei → keine Kollision mit Range-Chips.
- [x] **Import-Phasen-Progress** (2026-05-07): `AppContentLoader.loadImportedContent` hat `onPhase: ((ImportPhase) -> Void)?`-Parameter; `enum ImportPhase { reading, parsing, building }`; `LoadingProgressEngine.phase` + `setPhase(_:)`; Wrapper-`ContentView` zeigt lokalisiertes Phase-Label. Auto-Restore reicht den Callback bewusst nicht durch.
- [x] **Memory-Safety: Auto-Restore-Schutz gegen Jetsam-Kill** (2026-05-06): kombinierter Schutz im Auto-Restore-Pfad (`AppContentLoader.assertAutoRestoreEligible`) — (a) Sniffer-Skip für rohe Google-Timeline-Dateien (`firstStructuralByte == '['`) **unabhängig von der Größe**, gilt für direkte JSONs und ZIP-Einträge (Head-Sniff via begrenztem ZIP-extract-Abbruch); (b) zusätzlicher 50-MB-Cap (`autoRestoreMaxFileSizeBytes`) für sonstige große Dateien. Neuer Error `autoRestoreSkippedLargeFile`, userFacingTitle "Import not auto-restored". Manueller Import bleibt vom Sniffer-Skip unberührt (256-MB-Cap). Sniffer-basierte Format-Detection ersetzt 3× `JSONSerialization` durch 1-KB-Byte-Check (`isGoogleTimeline` + `isJSONObject`). Query-Fast-Path in `AppExportQueries.projectedDays` für `isPassthrough`-Filter. OverviewMap-Kandidaten-Storage auf 512 Punkte stride-decimiert. 18 Tests in `LargeImportMemorySafetyTests`. `swift test`: 991/2/0.
- [ ] **46-MB-Crashfall — Hardware-Re-Verifikation**: durch Sniffer-Skip im Auto-Restore-Pfad guarded (rohe Google-Timeline wird unabhängig von der Größe nicht mehr auto-restored, deckt 46 < 50 MB-Lücke). Hardware-Re-Verifikation auf iPhone 15 Pro Max mit echter 46-MB-`location-history.zip` steht aus (kein Simulator hat den Fall realistisch nachgestellt).
- [~] **Streaming-/Chunked-Google-Timeline-Parser**: implementiert für direkte JSON-Imports (2026-05-06) — `GoogleTimelineStreamReader` (FileHandle, jetzt 256-KB-Chunks, UnsafeBytes-Tokenizer mit `@inline(__always)`-Hot-Path und Hex-Literalen, 8-MB-Element-Cap) plus `GoogleTimelineConverter.convertStreaming(contentsOf:)`; `AppContentLoader.decodeFile` sniffed `[` und geht direkt in den URL-Pfad ohne `Data(contentsOf:)`. **Direct-Model-Build umgesetzt (2026-05-06):** `GoogleTimelineConverter` baut `AppExport`/`Day`/`Visit`/`Activity`/`Path` jetzt direkt über public memberwise-Initializer; der frühere `[String: Any]`-Tree + `JSONSerialization`-Encode + Re-Decode auf der Output-Seite entfällt. Per-Element-`onElement` läuft in `autoreleasepool`, damit Foundation-Zwischenobjekte nicht akkumulieren. **Offen:** Mikro-Benchmark (kein gemessener Speedup-Faktor — bislang nur erwartete Größenordnungen) und Hardware-Re-Verifikation auf iPhone 15 Pro Max mit echter 46-MB-Datei. ZIP-Entry-Streaming wurde am 2026-05-07 ergänzt (Sniffer-basiert; greift bei genau einem Google-Timeline-Entry, kein Mixed-ZIP — Peak RAM auf ~ein Element). Mikro-Benchmark als `XCTest`-`measure`-Baseline ergänzt (kein fail-on-regression bar; weiterhin kein gemessener Speedup-Faktor). Auto-Restore lehnt rohe Google-Timeline-Dateien weiterhin ab.
- [x] **Form-vs-LHCard-Konsistenz Settings (schmaler Scope)** (2026-05-07): `AppPrivacyOptionsView` und `AppTechnicalOptionsView` von `LHCard` auf native `Form`/`Section` migriert. Schmaler Scope: Privacy + Technical migriert; LiveRecording/Upload/Widget-LiveActivity bleiben bewusst LHCard (Custom-Preview-Karten + Status-Chips). 5/8 Sub-Views auf Form, 3 auf LHCard.
- [x] **Startseite**: auf iPhone 15 Pro Max verifiziert — Screenshot iphone15pm_01_import erzeugt (2026-05-05)
- [x] **Übersicht**: auf iPhone 15 Pro Max verifiziert — Screenshot iphone15pm_02_overview erzeugt (2026-05-05)
- [x] **Export**: auf iPhone 15 Pro Max verifiziert — Screenshot iphone15pm_04_export_checkout erzeugt (2026-05-05)
- [ ] Performance-Smoke-Test auf echtem iPhone mit grosser realer History (>20 MB, Gesamtzeitraum) fuer Overview-/Explore-Karte dokumentieren — neu motiviert durch Jetsam-Kill bei 46 MB Google-Timeline-Auto-Restore (Auto-Restore-Schutz greift; manueller Import des großen Files muss noch hardware-verifiziert werden)

## P1 — Produktverifikation und Ausbau vorhandener Flaechen

- [ ] Chart-Share / ImageRenderer auf Apple-Hardware gezielt verifizieren
- [ ] app-weite Landscape-Verifikation fuer `Overview`, `Days`, `Insights`, `Export`, `Live`
- [ ] Homescreen-Widget auf echter Hardware gezielt verifizieren
- [x] Track-Editor-Verhalten gegen reale Export-Erwartung: Mutations fliessen jetzt in Exporte ein (Audit-Batch 2026-05-06, Block 1 Items 2-3, 5-6) — `AppExportView`/`ExportSelectionContent`/`ExportPreviewData` reichen `pathMutations` durch, gelöschte Routen verschwinden aus GPX/KMZ/KML/GeoJSON/CSV.
- [ ] Wrapper-Simulator-Testlauf fuer `LH2GPXWrapperTests` auf diesem Host stabilisieren oder auf anderem Apple-Host gegentesten (`NSMachErrorDomain Code=-308`)
- [x] **Stop-Ship Bug 1 — Auto-Split Datenverlust** (2026-05-05): `start()` löscht `splitOffTrack` nicht mehr; `handleLocationSamples` draint Split-Track, persistiert ihn als `RecordedTrack` und setzt neue `currentRecordingSessionID`. 4 neue Tests in `LiveTrackRecorderTests`, 2 neue in `LiveLocationFeatureModelTests`.
- [x] **Stop-Ship Bug 2 — Widget Echtdaten** (2026-05-05): `stopRecordingFlow()` und Split-Drain rufen `updateWidgetData()` auf → `WidgetDataStore.save(recording:)` + `saveWeeklyStats()`. `ContentView` reloaded via `WidgetCenter.shared.reloadAllTimelines()` bei `widgetAutoUpdate == true`.
- [x] **Stop-Ship Bug 3 — Widget Family-Switch** (2026-05-05): `LH2GPXWidgetEntryView` mit `@Environment(\.widgetFamily)` → `systemSmall` → `LH2GPXSmallWidgetView`, sonst `LH2GPXMediumWidgetView`.

## P2 — Nachgelagerte Optimierung

- [x] Verifikations-Batch Redesign 1–5B (2026-05-05): swift test 927/0, xcodebuild ✅, CI-Tests ✅, testAppStoreScreenshots Simulator PASSED (7/8 Slots), testDeviceSmokeNavigationAndActions Bugfix (`insights.section.share` → `insights.share.*`)
- [x] Design-System: Live Activity / Dynamic Island / Widget Safety Batch 5B implementiert (2026-05-05); Content-Safety-Review bestanden (keine Koordinaten/Token/URLs im ContentState), `minimalView`-Bug gefixt, 9 neue Safety-Tests, 927 Tests grün
- [x] Design-System: Live-Tracking-Redesign Batch 5A implementiert (2026-05-05); Hero/Status-Card, einklappbarer Diagnostics-Bereich, 7 neue Accessibility-Identifier, 11 neue DE-Strings, 918 Tests grün
- [x] Design-System: Insights-Dashboard-Redesign Batch 4 implementiert (2026-05-05); Hero-Bereich mit Datumsbereich + aktive Tage, verbesserte Leer-Zustände mit Reset-CTA, Sektion-Reihenfolge angepasst (Highlights → Streak → Top Days → Daily Averages)
- [x] Design-System: Export-Checkout-Redesign Batch 3 implementiert (2026-05-05); Export nutzt jetzt klare Review-/Checkout-Struktur mit Auswahlprüfung, Preview-Fallback, Formatwahl, Exportziel und finaler Bottom-Bar-CTA
- [x] Design-System: Live-Tracking-Redesign abgeschlossen (2026-05-01); Live Tracking + Live Tracks Library jetzt im LH2GPX-Dark-Redesign
- [x] Design-System: Options + Widget/Live Settings Redesign abgeschlossen (2026-05-01); alle 8 Sections modular, RecordingPreset-Wiring, Token nur als SecureField, 830 Tests
- [x] Final Truth-Sync: fehlende DE-Strings ergänzt (Invalid URL, Widget & Live Activity, Reachable/Unreachable, Test Connection, Automatic Widget Update etc.), widgetAutoUpdate/maximumRecordingGapSeconds getestet; 832 Tests (2026-05-01)
- [x] Days-Tab: Sticky Map Workspace (LHMapHeaderState.isSticky, daysListStickyHeader, daysExportSelectionBar) — 849 Tests, 0 Failures (2026-05-05)
- [x] App-Store-Screenshot-Aktualisierung: UITest `testAppStoreScreenshots` auf iPhone 15 Pro Max ausgeführt (2026-05-05) → 6 Slots iphone15pm_01–06 in `docs/app-store-assets/screenshots/iphone-67/` (1290×2796 px). Pflichtset auf 6 Flows reduziert (ohne Options-Slot).
- [ ] Widget/Dynamic-Island nur bei sicherem Token-Pfad weiter ausbauen
- [ ] `LHCollapsibleMapHeader` in erste echte Seite einbauen (Kandidat: Insights-Heatmap-Kontext oder Overview-Map); nur wenn Daten sauber verfügbar
- [ ] Apple-Review-/Privacy-Einordnung fuer den optionalen Server-Upload weiter beobachten und nach Review-Feedback repo-wahr nachziehen
- [ ] `docs/NOTION_SYNC_DRAFT.md` nur noch als manuell gepflegten Snapshot nutzen oder spaeter durch einen schlankeren Status-Export ersetzen
- [ ] historische Split-Repos `LocationHistory2GPX-iOS` und `LH2GPXWrapper` konsistent als historisch/mirror markieren
- [ ] echtes Road-/Path-Matching nur als spaeteren separaten Produktentscheid evaluieren; aktueller Stand bleibt bewusst `Simplified` statt Snapping
