# CHANGELOG

## 2026-05-12 — perf: add measured performance baseline and low-risk optimizations

- Neuer Audit-Report `docs/PERFORMANCE_DEEP_AUDIT_2026-05-12.md` mit 21 priorisierten Hotspots (6 Subagenten parallel: Code+Performance, SQLite/Store, Test/Benchmark, Static-Search-Sweep, Doku-Truth, App-Store-Compliance).
- Code-Low-Risk-Patches: SQLite-PRAGMAs (`busy_timeout`, `synchronous=NORMAL`, `temp_store=MEMORY`) in `LocalTimelineStore.init(url:)` — Feature-Flag-default-OFF-Pfad, keine User-Sichtbarkeit. iCloud/iTunes-Backup-Exclusion für `RecordedTrackFileStore` (defence-in-depth für Live-Track-Standortdaten).
- Test-Addition: `PathDistanceCalculatorPerformanceTests.swift` mit 3 `measure {}`-Tests (XCTClockMetric + XCTMemoryMetric) auf 50 000-Punkt-Pfaden — Baseline für Folgetrain-Regression-Checks.
- `swift test` 1521/4/0 (+3 ggü. 1518), `xcodebuild generic iOS` BUILD SUCCEEDED, signed Device-Build iPhone 15 Pro Max BUILD SUCCEEDED.
- Hardware-UITest-Suite NICHT erneut gefahren — keine UI-Code-Änderung in diesem Train. Letzte 8/8 grün-Acceptance auf `f111afd` bleibt gültig.
- Manuelle Hardware-Restpunkte (46-MB-Retest, Live-Activity Sichtprüfung, iPad, ASC) sind in diesem Train **nicht** angefasst.

## 2026-05-12 — fix: restore heatmap control hardware smoke test

- `AppContentSplitView.swift` Heatmap-Button bekommt 44pt-Hit-Target + stabile `accessibilityIdentifier("overview.range.heatmap.button")`. UITest `testDeviceSmokeNavigationAndActions` nutzt Identifier-Lookup mit Label-Fallback und neuen `scrollUntilHittable`-Helper (window-level coordinate-drag).
- Hardware-UITest-Suite iPhone 15 Pro Max (iOS 26.4): **8/8 grün**. P0-3 aus dem vorigen Train geschlossen.
- Baseline grün: `swift build`, `swift test` 1518/4/0, `xcodebuild generic iOS` BUILD SUCCEEDED, signed Device-Build BUILD SUCCEEDED.
- Manual Risk Acceptance: Sektion 1 (46 MB) bleibt FAILED (Datei `~44.5 MiB` lokal verfügbar, Import braucht manuelle UI-Interaktion); Sektion 2 (Live Activity) — UITest-Capture-Pass, menschliche Sichtprüfung offen; Sektionen 3 (iPad) und 4 (ASC) bleiben offen.

## 2026-05-12 — docs: record iPhone hardware acceptance status

- Hardware-Acceptance-Train auf iPhone 15 Pro Max (iOS 26.4) auf HEAD `5f83838`: 7/8 UITests grün. `testAppStoreScreenshots`, `testLandscapeLayoutSmoke`, alle fünf `testLiveActivityHardwareCapture*` PASSED. **`testDeviceSmokeNavigationAndActions` FAILED** an `LH2GPXWrapperUITests.swift:203` (Heatmap-Button nicht hittable, Regression aus einem Phase-10-Commit) — in diesem Train nicht gefixt.
- Baseline grün: `swift build`, `swift test` 1518/4/0, `xcodebuild generic iOS`, signed Device-Build.
- Manual Risk Acceptance: Sektion 1 (46-MB) bleibt FAILED — keine 46-MB-Datei im lokalen Filesystem. Sektion 2 (Live Activity) — UITest-Pass-Beleg, manuelle visuelle Lock-Screen-Sichtprüfung offen, Checkboxen nicht abgehakt. Sektionen 3 (iPad) und 4 (ASC) bleiben offen.

## 2026-05-12 — fix: conditionally link CSQLite shim for Linux

- `Package.swift` hängt den `CSQLite`-Linux-Shim jetzt nur noch unter `.when(platforms: [.linux])` an `LocationHistoryConsumerAppSupport`. Auf Apple-Plattformen greift weiter der bestehende `#if canImport(SQLite3)`-Gate in `LocalTimelineStore.swift`, sodass die SDK-`SQLite3` benutzt wird.
- Wrapper-`xcodebuild -scheme LH2GPXWrapper -project wrapper/LH2GPXWrapper.xcodeproj -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**; signed Device-Build iPhone 15 Pro Max ebenfalls **BUILD SUCCEEDED**.
- `swift test` 1518/4/0 (Mac, unverändert).
- Manuelle Hardware-Restpunkte (46-MB-Retest, Live Activity, iPad, ASC/TestFlight) sind in diesem Train **nicht** angefasst und bleiben offen.

## 2026-05-09 — L-04 Bounded LRU für AppSessionContent-Caches
- Wrapper-Bundle/Signing/Plist unverändert. Core-Paket: neuer `BoundedLRU<K,V>` (Foundation-only) cappt alle 5 Filter-/Detail-Caches in `AppSessionContent` (8/8/8/32/16) sowie `projectedDaysCache` (8). Semantik unverändert. Wrapper-Konsumenten sehen kein anderes UI-Verhalten.
- 46-MB-Hardware-Gate bleibt FAILED / pending hardware retest.

## 2026-05-09 — L-01 In-Memory-Import-Gate
- Wrapper-Bundle/Signing/Plist unverändert. Core-Paket: `AppContentLoader.decodeFile(at:)` lehnt Full-Reads über 64 MiB jetzt kontrolliert ab (`maximumInMemoryImportBytes`, neuer Error-Case `importTooLargeForInMemoryLoad`). Google-Timeline-JSON streamt weiter durch den bestehenden Streaming-Pfad. Wrapper-Importer-UI zeigt den neuen Error mit `userFacingTitle` "File too large to load safely".
- 46-MB-Hardware-Gate bleibt FAILED / pending hardware retest.

## 2026-05-08 — Phase-10C Legacy hardening
- Phase-10C Legacy hardening (Wrapper-Pfad nicht direkt betroffen; Store-Pfad weiterhin default OFF).
- Heatmap densityPointCap=500_000 + Truncation-Flag, ExportPreview Doppel-Iter entfernt, derived_cache Purge-API, Build-Warnings (visionOS, unused withUnsafeMutableBytes) bereinigt — alles im Core-Paket. Wrapper-Bundle/Signing/Plist unverändert.
- 46-MB-Hardware-Gate bleibt FAILED / pending hardware retest.

## 2026-05-08 — Phase-10B (Weg 3) Foundation-only Provider hinzugefügt
- Phase-10B Foundation-only Provider hinzugefügt (Wrapper-Pfad nicht betroffen, default OFF).
- Zentraler `LocalTimelineMapPerformanceBudget` + `LocalTimelineMapPointLayerProvider` + Modelle im Core-Paket. Wrapper-Code nicht angefasst; Wrapper-Bundle/Signing/Plist unverändert.
- Store-Pfad bleibt pre-production / feature-flagged / default OFF; Legacy-Pfad unverändert. 46-MB-Hardware-Gate bleibt FAILED / pending hardware retest.

## 2026-05-08 — Wrapper: Sichtbare Progress/Cancel-UI verdrahtet
- ContentView: LocalTimelineImportProgressView + LocalTimelineTestModeBanner aus dem Core-Paket eingebunden.
- Pro Import frischer LocalTimelineImportController via LocalTimelineImportUIState.startNewImport().
- Cancel-Button im Loading-Branch sichtbar bei aktivem Store-Pfad-Import; Banner sichtbar bei aktivem TestModeToggle.
- Legacy-Pfad unverändert. Store-Pfad bleibt pre-production / feature-flagged / default OFF. 46-MB-Hardware-Gate bleibt FAILED / pending hardware retest.

## 2026-05-08 (feat: add local timeline wal checkpoint recovery — Wrapper indirekt via Core-Paket)

Wrapper-Code in `wrapper/LH2GPXWrapper/`/`wrapper/LH2GPXWidget/` **nicht angefasst**. Im Core-Paket P1-C (WAL-Checkpoint-/Cleanup-Strategie) und P1-D (Recovery-Test für Mid-Import-Crash) aus dem Deep Audit umgesetzt: neue API `LocalTimelineStore.checkpointWAL(mode:)`/`truncateWAL()`/`bestEffortTruncateWAL()` über `sqlite3_wal_checkpoint_v2` mit Default-Mode `.truncate`. Wiring (alle best-effort, damit Importerfolg/Cancel/Delete nicht von einem fehlschlagenden Checkpoint zerstört werden): `LocalTimelineImportWriter.finalize`/`.cancel` und `LocalTimelineStoreLifecycle.deleteAllLocalTimelineData(store:)` rufen `bestEffortTruncateWAL`. Reads checkpointen nicht — keine Performance-Falle. **Keine Schemaänderung**: `imports`-Row inside `BEGIN IMMEDIATE`, mid-import-Abbruch hinterlässt keine sichtbare Partial-Import-Row. Recovery-Test ist **Linux-Simulation, kein echter iOS-Jetsam-Test**. Bundle/Signing/Plist/Asset/Capabilities/Entitlements unverändert; keine neuen Dependencies. **46-MB-Crashfall bleibt FAILED / pending hardware retest** (verbatim). Keine ASC/Review/Hardware-/TestFlight-Freigabe behauptet. LocalTimelineStore bleibt **default AUS, pre-production / feature-flagged**. Linux-Vollsuite nach diesem Train: 1345 Tests, 2 Skips, 0 Failures (vorher 1332).

## 2026-05-08 (feat: cancellable local timeline import progress — Wrapper indirekt via Core-Paket)

Wrapper-Code in `wrapper/LH2GPXWrapper/`/`wrapper/LH2GPXWidget/` **nicht angefasst**. Im Core-Paket P1-A (Import-Cancel-Pfad) und P1-B (Import-Progress-Surface) aus dem Deep Audit umgesetzt: neuer `LocalTimelineImportProgress`/`LocalTimelineImportCancellation`/`LocalTimelineImportController` (Foundation-only, Linux-testbar), `GoogleTimelineStoreImporter` akzeptiert ein optionales `Hooks`-Tupel (Progress-Sink + Throttle + Cancellation), `AppContentLoader.loadImportedContentEnvelope` und `LH2GPXAppFlow.loadImportedFileEnvelope` reichen `importProgress`/`importCancellation` durch. Cancellation rollt die offene Writer-Transaktion zurück → **kein gültiger Teilimport** im Store. Cancel-Outcome im AppFlow: `.failure(title: "Import cancelled", clearBookmark: false)`; Loader-Fehler: neuer `AppContentLoaderError.importCancelled(_:)`. **SwiftUI-Anbindung im Wrapper (`wrapper/LH2GPXWrapper/ContentView.swift`) ist bewusst nicht Teil dieses Commits** — Service-/Presentation-Schicht ist vollständig und Linux-getestet, der UI-Hook ist als Folgeaufgabe in `NEXT_STEPS.md` und `docs/DEEP_AUDIT_…md` § 13 dokumentiert. Bundle/Signing/Plist/Asset/Capabilities/Entitlements unverändert; keine neuen Dependencies. **46-MB-Crashfall bleibt FAILED / pending hardware retest** (verbatim). Keine ASC/Review/Hardware-/TestFlight-Freigabe behauptet. LocalTimelineStore bleibt **default AUS, pre-production / feature-flagged**. Linux-Vollsuite nach diesem Train: 1332 Tests, 2 Skips, 0 Failures (vorher 1306).

## 2026-05-08 (docs+fix: deep audit & build-info live memory-logging mirror — Wrapper indirekt via Core-Paket)

Wrapper-Code in `wrapper/LH2GPXWrapper/`/`wrapper/LH2GPXWidget/` **nicht angefasst**. Im Core-Paket Deep Audit nach Build 158 (`docs/DEEP_AUDIT_2026-05-08_LOCAL_TIMELINE_STORE_AND_MAP.md`) plus eindeutiger P1-UX-Fix: `AppBuildInfo.isMemoryLoggingEnabled` von gespeichertem `let` auf computed `var` umgestellt (vorher fror der Wert beim Process-Start ein → "Memory Logging Disabled" oben in Build Info, "Memory Logging Resolved Enabled" direkt darunter, sobald Tester den UserDefaults-Toggle umlegte). Wrapper sieht den Fix transparent — `AppBuildInfo.shared` wird im Wrapper nicht direkt gelesen, der Effekt ist sichtbar in Settings → Technical → Build Info. Bundle/Signing/Plist/Asset/Capabilities/Entitlements unverändert; keine neuen Dependencies. **46-MB-Crashfall bleibt FAILED / pending hardware retest** (verbatim). Keine ASC/Review/Hardware-/TestFlight-Freigabe behauptet. LocalTimelineStore default AUS, pre-production / feature-flagged. Linux-Vollsuite nach Fix: 1306 Tests, 2 Skips, 0 Failures.

## 2026-05-08 (feat: add internal test toggles for testflight build 158 prep — Wrapper indirekt via TestFlight-Pfad)

Wrapper indirekt betroffen über den TestFlight-Pfad: **Build 157 ist Xcode Cloud grün und TestFlight-installierbar** (Status „Überprüft", interne Tests erfolgreich) — keine Aussage über Apple-Review-Freigabe oder über das 46-MB-Hardwareverhalten. Da TestFlight-Tester **keine Launch-Argumente / Environment-Variablen** setzen können, sind als Build-158-Vorbereitung zwei interne UserDefaults-Toggles im Core-Paket ergänzt, die der Wrapper über die bestehende Settings → Technical-Sektion automatisch sichtbar macht: "Internal Test Toggles" mit `LH2GPX.localTimelineStoreTestModeEnabled` und `LH2GPX.importMemoryLoggingEnabled` (beides Bool, default `false`, persistiert über `LocalTimelineTechnicalTestSettings`). **Wrapper-Code in `wrapper/LH2GPXWrapper/`/`wrapper/LH2GPXWidget/` ist nicht angefasst** — `AppShellRootView`/`ContentView` werden nicht geändert; die neuen Settings werden im Core-Paket über `.shared` aufgerufen, der Resolver-Overload mit Default-Argument bleibt source-kompatibel. Wrapper-Bundle/Signing/Plist/Asset/Capabilities/Entitlements unverändert; keine neuen externen Dependencies. **Args/ENV bleiben primärer Aktivator** (lokale Xcode-Runs); das Setting aktiviert **zusätzlich** (TestFlight-Strecke), deaktiviert nichts. `ImportMemoryProbe.isLoggingEnabled` ist computed → Toggle wirkt **ohne Relaunch**. Privacy-/Scope-Vertrag: nur Bool unter den beiden Keys, **keine Standortdaten / keine Pfade / keine Tokens** (pinpoint-Test `testOnlyBoolsAreStoredUnderToggleKeys`). Footer-Hinweis am Gerät: "Internal/TestFlight only · Pre-production · Default off · No location data is stored in these settings". LocalTimelineStore-Pfad bleibt **default AUS, pre-production / feature-flagged**. Live-Upload, Recording, Auth-Flows unberührt. **46-MB-Crashfall bleibt FAILED / pending hardware retest** (verbatim). **Keine ASC/Review/Hardware-/TestFlight-Freigabe behauptet** (Build 157 ist TestFlight-installierbar, nicht Apple-Review-frei). **Keine Map-Phase-10B-Aussage**, **keine UI-Änderung außerhalb der Technical-Sektion**.

## 2026-05-08 (fix: resolve xcode heatmap grid key compile failure — Wrapper indirekt betroffen)

Wrapper indirekt betroffen, weil der Xcode-Cloud-Workflow „Release – Archive & TestFlight" bei den Builds **155** (Commit `06f81ae`) und **156** (Commit `5cb7783`) mit **Exit Code 65** fehlgeschlagen ist und damit kein TestFlight-Archive aus dem Wrapper-Target produziert wurde. Root Cause lag im Core-Modul `LocationHistoryConsumerAppSupport`: `Sources/LocationHistoryConsumerAppSupport/LocalTimelineHeatmapGridAggregator.swift` definierte einen top-level `private struct GridKey { let lat: Int; let lon: Int }`, der mit einem ebenfalls top-level `struct GridKey { let lat: Int32; let lon: Int32 }` aus `Sources/LocationHistoryConsumerAppSupport/HeatmapGridBuilder.swift` (gated `#if canImport(MapKit) && canImport(SwiftUI)`) auf Apple-Plattformen kollidierte. Auf Linux schloss der MapKit-Guard die HeatmapGridBuilder-Variante aus, der SwiftPM-Build blieb grün; auf Apple-Plattformen waren beide sichtbar → „Invalid redeclaration of 'GridKey'" + „ambiguous for type lookup" + Folgefehler „Cannot convert value of type 'Int' to expected argument type 'Int32'" auf Zeile 79 des Aggregators. Fix im Core-Paket: `LocalTimelineHeatmapGridAggregator.swift` benennt seinen file-scope `GridKey` → `LocalTimelineHeatmapGridKey` (privat, file-scope). **Wrapper-Code in `wrapper/LH2GPXWrapper/`/`wrapper/LH2GPXWidget/` ist nicht angefasst.** **`wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj` referenziert die SPM-Package-Datei nicht direkt; keine doppelten Compile-File-Referenzen** — die Kollision war rein semantisch zwischen zwei Top-Level-Swift-Definitionen im selben Core-Modul, nicht eine Wrapper-Build-Phase-Doppellistung. Wrapper-Bundle/Signing/Plist/Asset/Capabilities/Entitlements unverändert; keine neuen externen Dependencies. Linux-SwiftPM weiter grün; `swift test` voll grün nach Fix. **Xcode Cloud muss erneut ausgelöst werden — Status: PENDING.** Keine Aussage über echte Apple-Builds, bis Xcode Cloud erneut grün läuft. **46-MB-Crashfall bleibt FAILED / pending hardware retest.** **Keine ASC/TestFlight-Freigabe behauptet.** Store-Pfad bleibt default AUS, pre-production; **keine Map-Phase-10B-Aussage**, **keine UI-Änderung**.

## 2026-05-08 (feat: add store backed day map ui surface — Phase 10A Wrapper-Hinweis)

Phase-10A-Wrapper-Wiring: `wrapper/LH2GPXWrapper/ContentView.swift` reicht jetzt zusätzlich zur Phase-9B-Source eine neue `LH2GPXAppFlow.makeProductionDayMapSource(for: storeSession)` an die `LocalTimelineSessionLandingView` durch. Bei aktivem Feature-Flag (`LH2GPX_LOCAL_TIMELINE_STORE`) zeigt jeder geöffnete Day jetzt zusätzlich eine optionale Map-Sektion: "Load map" (bounded Candidate-Load **ohne `coord_blob`-Decodierung**) und "Decode all routes" (bounded Geometrie-Decode innerhalb harter `Budget`-Grenzen — default 12 Routen / 256 Punkte pro Route / 4096 Punkte gesamt). Die View ist ein SwiftUI Placeholder (`LocalTimelineDayMapView`, `#if canImport(SwiftUI)`-guarded) **ohne MapKit-Import**; echte `MKMapView`-/`MKMultiPolyline`-Verdrahtung bleibt explizit **Phase-10B Mac/Xcode-Pflicht**. **Backward-kompatibel** (Landing-View defaults nil), **kein eager `coord_blob`-Decoding beim Candidate-Load**. **Wrapper-Bundle/Signing/Plist/Asset unverändert**, keine neuen externen Dependencies. **Vollständige sichtbare Kartenmodernisierung wird nicht behauptet.** Legacy-Map unverändert. **Store-Pfad bleibt default AUS**. **KEIN Heatmap/Overview/Export UI-Hook**, **KEINE Darwin FileProtection-Aktivierung**, **KEINE Hardware-/AppStore-/TestFlight-/ASC-Aussage**, **46-MB-Crashfall bleibt FAILED**.

## 2026-05-08 (feat: wire local timeline day detail ui — Phase 9B Wrapper-Hinweis)

Phase-9B-Wrapper-Wiring: `wrapper/LH2GPXWrapper/ContentView.swift` reicht jetzt `LH2GPXAppFlow.makeProductionDayBrowserSource(for: storeSession)` + Selection-Binding (`selectedLocalTimelineDayId` / `selectLocalTimelineDay(_:)` auf `AppSessionState`) an die `LocalTimelineSessionLandingView` durch. Bei aktivem Feature-Flag (`LH2GPX_LOCAL_TIMELINE_STORE`) sehen Tester nach Google-Timeline-Import jetzt eine **Tagesliste** (`LocalTimelineDayListView`, newest-first, Datum / Routen / Visits / Distanz) und können pro Tag eine sheet-basierte **Detail-Ansicht** (`LocalTimelineDayDetailView` mit Visits + Activities + Path-Metadaten + "Path points available (not decoded)"-Hinweis) öffnen. **Backward-kompatibel** (Landing-View defaults nil), **kein eager `coord_blob`-Decoding, keine Map**. **Wrapper-Bundle/Signing/Plist/Asset unverändert**, keine neuen externen Dependencies. **Store-Pfad bleibt default AUS**. **KEIN Map/Heatmap/Overview UI-Hook**, **KEINE Darwin FileProtection-Aktivierung**, **KEINE Hardware-/AppStore-/TestFlight-Aussage**, **46-MB-Crashfall bleibt FAILED**.

## 2026-05-08 (feat: wire local timeline day presentation — Phase 9A Wrapper-Hinweis)

Phase-9A-Wrapper-Wiring: `wrapper/LH2GPXWrapper/ContentView.swift` ruft jetzt `loadImportedFileEnvelope(...)` (statt `loadImportedFile(...)`) und routet `.legacy/.localTimeline/.failure` über die neue, geteilte Routing-Helper-Funktion `LH2GPXAppFlow.apply(envelopeOutcome:to:preserveOnFailure:)`. Bei aktiver `localTimelineSession` (nur erreichbar mit gesetztem `LH2GPX_LOCAL_TIMELINE_STORE`-Feature-Flag) zeigt der Wrapper die neue `LocalTimelineSessionLandingView` aus dem Core-Paket (`Sources/LocationHistoryConsumerAppSupport/LocalTimelineSessionLandingView.swift`, `#if canImport(SwiftUI)`-guarded) mit Session-Metadaten + Lösch-Button. Settings → Technical enthält jetzt eine Section "Local Timeline Store" mit Feature-Flag-Status + Lösch-Button "Delete imported local data". **Wrapper-Bundle/Signing/Plist/Asset unverändert**; keine neuen externen Dependencies. **Store-Pfad bleibt default AUS** (`LH2GPX_LOCAL_TIMELINE_STORE`-Flag, Default-Rollout bleibt Legacy-AppExport, byte-identisch wenn Flag aus). **KEIN Map/Heatmap/Overview UI-Hook**, **KEINE Darwin FileProtection-Aktivierung**, **KEINE Hardware-/AppStore-/TestFlight-Aussage**, **46-MB-Crashfall bleibt FAILED**.

## 2026-05-08 (docs: research local timeline store compliance path — Core-Package concern)

Reine Research-/Plan-Doku im Core-Package — **Wrapper unverändert**. Die neue `docs/LOCAL_TIMELINE_STORE_RESEARCH.md` skizziert eine geprüfte Designrichtung (SQLite-C-API + `Int32`-microdegrees-BLOB, Application-Support-Speicherort, `completeUnlessOpen`, backup-excluded) als strukturelle Alternative zum heutigen In-Memory-`AppExport`-Pfad bei sehr großen Importen. Adressat ist das Core-Paket / der AppSupport-Importpfad; das Wrapper-Target (`LH2GPXWrapper`/`LH2GPXWidget`) ist von dieser Research-Doku **nicht** betroffen — keine Bundle-/Signing-/Plist-/Asset-Änderung. Conditional-P0/P1-Gate (P0 falls 46-MB-Hardware-Retest FAILED, P1/P2 falls PASSED) ist in der Research-Doku dokumentiert. **Kein Code in `main`, kein Spike**, keine ASC-/TestFlight-Aussage. **46-MB-Crashfall bleibt FAILED**.

## 2026-05-08 (chore: Linux-Stabilisierung im AppSupport-Target nach P0-Memory-Fix `34bc369`)

Reine Linux-Build-Stabilisierung des Core-Pakets — **Wrapper selbst nicht geändert** (kein Code-Stand-Sprung in `LH2GPXWrapper`/`LH2GPXWidget`, keine Bundle-/Signing-Änderung). Hintergrund: nach dem P0-Memory-Train HEAD `34bc369` waren `swift build` (Vollbuild) und `swift test` auf Linux pre-existing kaputt (iOS-only Heatmap/MapTrack-Color-Preference-Enums in `AppPreferences` referenziert, aber unter `#if canImport(SwiftUI) && canImport(MapKit)`-Guard definiert). Diese Stabilisierung schließt den Linux-Build, ohne iOS-Verhalten zu ändern.

Code-Änderungen im AppSupport-Target (`Sources/LocationHistoryConsumerAppSupport/`):
- **NEU `HeatmapPreferenceEnums.swift`** — extrahiert die vier reinen Preference-Enums `AppHeatmapPalettePreference`, `AppHeatmapScalePreference`, `AppHeatmapRadiusPreset`, `AppMapTrackColorMode` als Linux-buildbare `String`-`RawValue`-Enums. Bisherige Quelldateien (`HeatmapPalette.swift`, `HeatmapLOD.swift`, `AppHeatmapView.swift`, `MapTrackStyling.swift`) verlieren die Enum-Definitionen, behalten aber alle SwiftUI-/MapKit-abhängigen Extensions hinter Plattform-Guards (`scale`-Multiplikator, Color-Resolver).
- `OptionsPresentation.swift` — String-Helpers `uploadStatusText`/`serverUploadPrivacyText` aus dem `#if canImport(SwiftUI)`-Guard herausgehoben; `uploadStatusColor` (Color-returning) bleibt iOS-only Extension.
- `LH2GPXAppFlow.swift` — `url.startAccessingSecurityScopedResource()`/`stopAccessingSecurityScopedResource()` in `#if canImport(UIKit) || canImport(AppKit)`-Guard (Darwin-only).
- `GoogleTimelineStreamReader.swift` — `autoreleasepool { … }` in `#if canImport(Darwin)`-Guard mit Linux-Fallback (gleiche Parse-Logik ohne Pool, kein Verhaltensunterschied auf iOS).
- `DaySummaryRowPresentation.swift` — explizites `import Foundation`.

Tests: **NEU** `Tests/LocationHistoryConsumerTests/LinuxStabilizationRegressionTests.swift` (7 Linux-fähige Cases — never-both-shapes-Invariante, points↔flat Distanzparität ±1 m, AppSessionContent-Init/`show(content:)` < 250 ms / 5000 Days, Banner liest aus `meta`, 50k synthetische Timeline-Entries via `incrementalStreamConverter` → alle flat). `LargeImportMemorySafetyTests.swift` `import CoreLocation` und 2 Tests in `#if canImport(CoreLocation) && canImport(MapKit)`-Guard. `UIWiringTests.swift` 8 Tests von `@MainActor` auf `MainActor.assumeIsolated { … }`. `TCXImportParserErrorTests.swift` `testTCXMalformedXMLThrowsInvalidXML` akzeptiert `.invalidXML` ODER `.noTrackPoints` (Linux-corelibs-foundation `XMLParser` ist permissiver als Darwin).

Test-Stand Linux: `swift build` (Vollbuild) clean, `swift build --build-tests` clean, `swift test` **1034/2/0** (vorher 1033 vor 50k-Stress-Test). Erwarteter Mac-Stand (post-Linux-Stabilisierung): **~1133** (1033 + ~100 iOS-only Tests hinter `canImport(SwiftUI)`/`MapKit`/`CoreLocation`/`UIKit`).

**46-MB-Crashfall bleibt FAILED** bis Hardware-Retest auf iPhone 15 Pro Max — die Linux-Stabilisierung ändert iOS-Verhalten nicht und ist keine Aussage über die 46-MB-Hardware-Symptomatik. Mac/iPhone-Handoff, auf Linux-Server nicht durchführbar. Keine ASC/TestFlight-Freigabe behauptet. Map-Modernisierung (MKMultiPolyline/MKTileOverlay) bleibt Roadmap.

## 2026-05-08 (fix: reduce large timeline import memory footprint)

**Dritter Hardware-Fail** auf iPhone 15 Pro Max (`iPhone16,2`, iOS 26.4 / 23E246, Xcode 26.3, macOS 15.7) am 2026-05-07T15:10:44+02:00 trotz erweitertem Memory-Train nach `cd77f97` und HEAD `ae5de1f`: erneut Jetsam-Kill (`IDEDebugSessionErrorDomain Code 11`, „The app ‘LH2GPXWrapper’ has been killed by the operating system because it is using too much memory.", Operation duration **95.156 ms** vs. 216.606 ms zweiter Fail / 232.341 ms erster Fail — schneller Fail = Peak liegt früher).

Wrapper-Sicht im vorbereiteten Fix-Stand HEAD `<commit-tba>` nach `ae5de1f` (kein verifizierter Erfolg):
- **Build-Info-Sichtbarkeit erweitert**: Settings → Technical → „Build Info" zeigt jetzt zusätzlich **„Memory Logging: Enabled / Disabled"** (grün, wenn aktiv). Tester kann am Gerät verifizieren, ob die `ImportMemoryProbe` für diesen Run scharf geschaltet ist, **bevor** der Import gestartet wird. Aktivierung per env `LH2GPX_IMPORT_MEMORY_LOG=1` oder Launch-Argument (`LH2GPX_IMPORT_MEMORY_LOG`, `-LH2GPX_IMPORT_MEMORY_LOG`, `--LH2GPX_IMPORT_MEMORY_LOG`, `LH2GPX_IMPORT_MEMORY_LOG=1`).
- **Memory-Warning-Observer im Wrapper-`ContentView`**: `NotificationCenter`-Observer auf `UIApplication.didReceiveMemoryWarningNotification` füttert die `ImportMemoryProbe` mit `app.didReceiveMemoryWarning`-Probe-Punkten — iOS-only, sichtbar nur wenn die Probe aktiv ist.
- Build-Identitäts-Logging `[LH2GPX_BUILD] app.start version=… build=… sha=… memoryLogging=enabled|disabled` wird auf App-Start **immer** ausgegeben (unabhängig von Probe-Status), damit der gestartete Build im Hardware-Run zweifelsfrei aus der Console hervorgeht.

Tests neu in dieser Session: `ImportMemoryProbeActivationTests.swift` (15 Tests) + `FlatCoordinatesGeometryTests.swift` (23 Tests); zwei DST-Tests in `GoogleTimelineConverterTests` auf Geometrie-Erhalt umgeschrieben. Erwarteter Mac-Test-Stand: ~1119 Tests; Linux-Vollbuild ist pre-existing kaputt (iOS-only Heatmap/MapTrack-Color-Types in `AppPreferences`), `swift build --target LocationHistoryConsumer` ist Linux-clean, `swift test` läuft Mac/Xcode-Cloud-seitig. **46-MB-Crashfall bleibt FAILED** bis Hardware-Retest auf iPhone 15 Pro Max grün — der finale Retest ist Mac/iPhone-Handoff und kann auf dem Linux-Server nicht durchgeführt werden. Keine Karten-Modernisierung als done; `docs/MAP_ARCHITECTURE_AUDIT.md` ist Architektur-Doku/Roadmap. Keine ASC/TestFlight-Freigabe behauptet.

## 2026-05-07 (fix: reduce memory peak after large timeline import)

Zweiter Hardware-Fail auf iPhone 15 Pro Max (iOS 26.4, Xcode 26.3) am 2026-05-07T14:14:36+02:00 trotz Autoreleasepool-Fix `cd77f97`: erneut Jetsam-Kill (`IDEDebugSessionErrorDomain Code 11`, Operation duration 216.606 ms vs. 232.341 ms erster Fail). Damit war klar: der Peak liegt nach dem Streaming. Fix-Train: `AppSessionContent.init` ermittelt `selectedDate` direkt aus `export.data.days` ohne `daySummaries`-Materialisierung; `AppSessionState.show(content:)` liest `inputFormat` aus `meta.source.inputFormat` statt `content.overview` zu erzwingen; `GoogleTimelineConverter.ExportBuilder.finalize()` ist mutating und nutzt `dayMap.removeValue(forKey:)` + finales `removeAll(keepingCapacity: false)`; `IncrementalStreamConverter.finalize()` ersetzt internen Builder durch frische Instanz; `PathDistanceCalculator.effectiveDistance(for: Path)` iteriert direkt über points/flatCoordinates ohne Tuple-Kopien. Diagnostik: neue `ImportMemoryProbe` (mach `task_vm_info`, gated auf `LH2GPX_IMPORT_MEMORY_LOG=1`, `[LH2GPX_MEMORY]`-Logs im ZIP-Streaming-Pfad). Build-Identität: neuer `AppBuildInfo` + „Build Info“-Sektion in `AppTechnicalOptionsView`; `Info.plist`-Schlüssel `GitCommitSHA = $(GIT_COMMIT_SHA)` injizierbar via `xcodebuild GIT_COMMIT_SHA=$(git rev-parse --short HEAD)`. Drei neue Regressionstests in `DemoSessionStateTests`. `swift test` 1081/2/0 (+3). Hardware-Retest des Release-Builds auf iPhone 15 Pro Max steht weiter aus; 46-MB-Punkt der Manual-Risk-Checkliste **bleibt FAILED**, bis Tester ihn grün bestätigt.

## 2026-05-07 (fix: drain autorelease objects during timeline stream parsing)

iPhone 15 Pro Max (iOS 26.4) reproduzierte beim manuellen Import einer 46 MB `location-history.zip` (~64.926 Entries) einen Jetsam-Kill (`IDEDebugSessionErrorDomain Code 11`). Root Cause: in `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineStreamReader.swift` lief `JSONSerialization.jsonObject(with: element)` außerhalb des `autoreleasepool` — der Pool umschloss nur das nachgelagerte `onElement(parsed)`. Dadurch akkumulierten transiente Foundation-Objekte über alle Top-Level-Elemente. Fix: Parse + Ingest laufen jetzt im selben `autoreleasepool`; nach Outliern > 64 KB wird `element` neu reserviert. Neuer Regressionstest `testHighElementCountWithLargeOutlierSucceeds` (50k Elemente + 1-MB-Outlier). `swift test` 1078/2/0 (+1). Hardware-Retest mit der originalen 46-MB-ZIP auf iPhone 15 Pro Max steht aus; 46-MB-Punkt der Manual-Risk-Checkliste bleibt **FAILED**, bis Tester ihn nachweislich grün bestätigt.

## 2026-05-07 (Manual release risk acceptance protocol added)

Reine Doku — keine Code-Änderung. Siehe Hauptblock in `docs/APPLE_VERIFICATION_CHECKLIST.md` („Manual Release Risk Acceptance Protocol — HEAD `b91a933`") sowie `CHANGELOG.md` (Top-Eintrag 2026-05-07). Deckt 4 nicht automatisierbare Restrisiken: 46-MB-Crashfall, Live Activity / Dynamic Island / Lock Screen, iPad-Layout, ASC / TestFlight / Apple Review. Checkboxen leer — durch Tester auszufüllen. `swift test` 1077/2/0 unverändert.

## 2026-05-07 (Post-fix hardware re-verification on iPhone 15 Pro Max)

Pure verification pass after the day-detail distance fix (commit `853d8d3`). No code changes.

### Hardware-Verifikation iPhone 15 Pro Max (iOS 26.4)
- testAppStoreScreenshots: PASSED (41.8s)
- testDeviceSmokeNavigationAndActions: PASSED (71.2s)
- testLandscapeLayoutSmoke: PASSED (829.9s)
- swift test: 1077/2/0 (unverändert).
- git diff --check: clean.

Im Commit `853d8d3` war nur Smoke-Navigation post-Fix gefahren; die volle 3-UITest-Acceptance-Suite ist jetzt grün.

### Weiterhin offen
- 46-MB-Crashfall geräteseitig (manueller iPhone-Import nötig)
- Live Activity / Dynamic Island / Lock-Screen visuell (UI-interaktiv)
- iPad-Layout, ASC / TestFlight / Apple Review

## 2026-05-07 (fix: day-detail distance consistency — P0/P1 bug)

### Bug
Day-Detail zeigte „Distance 0" für Routen mit sichtbarer Geometrie, obwohl Insights/Übersicht korrekte Distanzen lieferten. Root Cause: Summary nutzte `effectiveDistance`-Fallback, Detail-Pfad las nur raw `distanceM`. Google-Timeline-`timelinePath`-Imports trafen das, weil ihr `distanceM == nil` aber valide `points`.

### Fix
- PathDistanceCalculator als Single-Source-of-Truth (neue Datei in LocationHistoryConsumer/Queries).
- DayDetailViewState.PathItem bekommt `effectiveDistanceM: Double` (immer berechnet); raw `distanceM` bleibt für Caller die zwischen „nichts gemeldet" und „expliziter Wert" unterscheiden müssen.
- DayDetailPresentation liest `effectiveDistanceM` an allen 5 Stellen (KPI-Card, Route-Subtitle, Summary-Aggregat, Section-Subtitle, Dominant-Mode, Route-Intensity).
- 12 neue Cases in PathDistanceCalculatorTests inkl. Summary↔DayDetail-Konsistenz-Regression.

### Verifikation
- swift test: 1077/2/0 (+12 gegenüber 1065).
- Device-Smoke iPhone 15 Pro Max (iOS 26.4): testDeviceSmokeNavigationAndActions PASSED.

### Weiterhin offen
- 46-MB-Crashfall geräteseitig nach Fix nicht erneut validiert
- Live Activity / Lock Screen / iPad / ASC / TestFlight nicht geprüft

## 2026-05-07 (Hardware re-verification on iPhone 15 Pro Max + 44pt clear-date-range hit-target fix)

### Hardware-Bug + Fix
- HistoryDateRangeFilterBar: clear-date-range button (xmark.circle.fill) had a 12×12pt hit area, below Apple's 44pt HIG minimum and unhittable in real-device automation. Added `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` so the visible glyph stays unchanged but the tap area meets HIG.

### Hardware-Verifikation iPhone 15 Pro Max (iOS 26.4, HEAD pending — Commit folgt)
- testAppStoreScreenshots: PASSED (42.9s)
- testDeviceSmokeNavigationAndActions: PASSED (72.2s)
- testLandscapeLayoutSmoke: PASSED (830s)

### Verifikation
- swift test: 1065/2/0 (unverändert).
- Wrapper xcodebuild auf iPhone 15 Pro Max: BUILD + TEST SUCCEEDED.

### Weiterhin offen
- 46-MB-Crashfall geräteseitig (manueller iPhone-Import nötig, kein UITest)
- Live Activity / Dynamic Island / Lock-Screen visuelle Verifikation (Always-Permission braucht UI)
- ASC / TestFlight / Apple Review nicht geprüft

## 2026-05-07 (P1 release-readiness fix: doc-truth sync + stability hardening)

### Doku-Wahrheits-Sync
- ROADMAP.md Aktiver-Stand-Header auf HEAD `3811bc3`, Datum 2026-05-07 gesetzt (in einem Folge-Doku-Sync direkt nach diesem Commit nochmal von `5c69afe` auf `3811bc3` korrigiert).
- Alle `pending — Commit folgt`-Verifikations-Blöcke mit echten HEAD-Hashes aufgefüllt.
- README.md:78 lange Test-Nachweis-Zeile auf chronologische 3-Stufen-History gekürzt.
- README UI-Begriffe an echte UI-Labels angeglichen: `Simplified` (kein Beta-Suffix), `Rectangle / Bounding Box`, exakte Banner-Labels.

### Stabilitäts-Härtung
- DaySummaryRowPresentation: `distanceText!` Force-Unwrap durch sichere `let`-Bindung ersetzt.
- AppOverviewMapModel: `rebuildOverlays`-Task-Closures von `[self]` auf `[weak self]` umgestellt; Race-Token-Logik unverändert.
- AppPreferences: `liveLocationServerUploadURLString` validiert jetzt vor UserDefaults-Write — `https://`, `localhost`, `127.0.0.1`, `[::1]` akzeptiert; sonst Reject mit Reset auf alten Wert. Token-Property + Keychain unverändert.
- 8 neue Tests in `AppPreferencesUploadURLValidationTests.swift`.

### Verifikation
- `swift test`: **1065 Tests, 2 Skips, 0 Failures** (vorher 1057).
- Wrapper xcodebuild iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.

### Weiterhin offen
- Hardware-Re-Verifikation iPhone 15 Pro Max für aktuellen HEAD steht aus (letzte echte Acceptance: 2026-05-05).
- ASC/TestFlight-Status nicht geprüft.
- 46-MB-Crashfall geräteseitig nicht validiert.

## 2026-05-07 (UX/Layout batch + mock helpers: insights-picker, overview-header, map-pill, settings-form, hero-map-layout-tests)

### refactor/ux/test: 6 Achsen

1. **Mock-Client extrahiert** — `Tests/LocationHistoryConsumerTests/Helpers/MockLiveLocationClient.swift` (NEU); `LiveLocationFeatureModelStateTransitionTests` und `LiveLocationFeatureModelTests` nutzen den Helper.
2. **Insights Triple-Range-Picker konsolidiert** — `AppInsightsContentView.swift`: nur Hero-Strip im `heroEnabled`-Pfad; Card + Pills ausgeblendet (Legacy/iPad behält Card).
3. **Overview Doppel-Header gelöst** — Card "Overview" → "Statistics" (de: "Statistik"); Page-Header bleibt; Strings in `AppLanguageSupport.swift`.
4. **Map-Pill-Overlap gefixt** — `AppOverviewTracksMapView.swift`: Badge + Optimization-Banner in `VStack(alignment: .trailing)` an `.bottomTrailing`; linke untere Ecke frei.
5. **Form-vs-LHCard-Konsistenz Settings (schmaler Scope)** — `AppPrivacyOptionsView` + `AppTechnicalOptionsView` auf `Form`/`Section`. LiveRecording/Upload/Widget-LiveActivity bleiben bewusst LHCard (Custom-Preview + Status-Chips).
6. **Hero-Map-Layout-Tests** — `Tests/LocationHistoryConsumerTests/LHMapHeaderLayoutTests.swift` (NEU): 12 property-based Cases (compactHeight=460, expandedHeight=560, mapControlTopOffset≥124, sticky-Init, expand()-Transition, Sticky-cannot-hide, mapFrameHeight für compact/expanded/hidden/fullscreen). Kein SnapshotTesting-Framework im Repo.

### Verifikation
- `swift test`: **1057 Tests, 2 Skips, 0 Failures** (vorher 1045; +12 Cases).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: **BUILD SUCCEEDED**.

**Ehrlich offen:** Form-vs-LHCard nur teilweise (5/8 Sub-Views). Hardware-Re-Verifikation iPhone 15 Pro Max steht weiter aus. Layout-Tests sind property-based, keine Pixel-Snapshots.

## 2026-05-07 (Audit batch — Phase 1-5: caching/index/race-token/live-map dedup, drift-extraction, importing-protocol, mock-state-tests, doc-truth-cleanup)

### refactor/perf/test/docs: 14 Audit-Achsen über zwei Commits

Zwei Commits gepusht: `21b4026` (Phase 1) und `20877ae` (Phase 2-5).

**Phase 1 — `21b4026` (5 Achsen):**
- **Item 3** — `projectedDays`-Cache (Memoization).
- **Item 4** — Mutations-Index in `AppImportedPathMutationStore` (O(1)-Lookup).
- **Item 5** — Race-Token in async Filter-/Day-Switch-Pfaden.
- **Item 6** — Live-Map-Dedup (geteilte Map-Render-Helper).
- **Item 8** — `@testable import` → `import` Cleanup-Folge.

**Phase 2-5 — `20877ae` (9 Achsen):**
- **Item 7** — Mock-Client + State-Transition-Tests (Mock extrahiert; Placeholder ersetzt durch zwei echte Cases — netto +1 Case).
- **Item 11 + Item 2** — `LH2GPXAppFlow` extrahiert (Drift Wrapper ↔ Package-App-Einstieg) plus Auto-Restore-Phasen.
- **Item 9** — API-Naming als additives Importing-Protokoll umgesetzt (kein Rename, Folgerisiken vermieden).
- **Item 10 (SKIP)** — `wrapper/CI.xctestplan` SwiftPM-Coverage: pbxproj-Integration zu fragil, weiterhin out-of-scope. `.github/workflows/swift-test.yml` deckt SwiftPM-Suite ab.
- **Item 12** — `Tests/README.md` aktualisiert.
- **Items 13/14/15** — Doku-Truth-Cleanup (ROADMAP/NEXT_STEPS/CHANGELOG/README/wrapper-Docs/Apple-Checklist).

### Verifikation
- `swift test`: **1045 Tests, 2 Skips, 0 Failures** (vorher 1044; +1 Case durch Mock-Refactor in Item 7).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: **BUILD SUCCEEDED**.

**Ehrlich offen:** Item 9 als additives Protokoll (kein Rename). Item 10 als bekannte SKIP. Hardware-Re-Verifikation iPhone 15 Pro Max steht weiterhin aus.

## 2026-05-07 (Audit batch — Bündel B+C+D+A: dead-code removal, perf restposten, @testable cleanup, test hardening)

### refactor/perf/test: 22 Audit-Achsen über vier Bündel

**Bündel B — Dead-Code (~158 Zeilen weniger):**
- `Sources/LocationHistoryConsumerAppSupport/AppDayDetailView.swift`: `quickStat(_:label:icon:color:)` (~21 Zeilen) und `private struct DayTimelineView` (~123 Zeilen) entfernt — beide ohne Caller.
- `Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift`: `activeFiltersSection(_:)` (~14 Zeilen, kein Caller) entfernt.
- `Sources/LocationHistoryConsumerAppSupport/LHSharedMapChrome.swift`: gesamte Datei gelöscht. **`LHMapStyleToggleButton` public API entfernt** — keine externen Caller bekannt, war seit MapLayerMenu-Train `@available(*, deprecated)`, durch `MapLayerMenu` ersetzt. P2-8 (Live `mapCard`/`liveHeroMap` Duplikate) bewusst nicht angefasst — Audit-Beschreibung war ungenau, `mapControlRow` hat realen Caller.

**Bündel C — Perf-Restposten:**
- `AppOverviewTracksMapView.swift`: `OverviewMapRenderData: Equatable` mit Hand-`==` (totalRouteCount/isOptimized/isLoading/pathOverlays + center.lat/lon + span.deltas); `approximateDistance(for:)` inline Haversine (Erdradius 6 371 000 m) statt `CLLocation`-Allokation pro Coord-Pair.
- `HeatmapGridBuilder.swift`: Doppel-Sort durch Single-Sort + `suffix`-Trim ersetzt; Render-Reihenfolge cold→hot bleibt.
- `AppExportQueries.swift`: `findDay(on:in:applying:)` Fast-Path für `isPassthrough`-Filter — DayDetail-Open ohne volle `projectedDays`-Projektion.

**Bündel D — Architektur:**
- `wrapper/CI.xctestplan` **unverändert (SKIP)** — referenziert `LH2GPXWrapper.xcodeproj`-containerPath, kann SwiftPM-Test-Target `LocationHistoryConsumerPackageTests` ohne pbxproj-Integration nicht aufnehmen. `.github/workflows/swift-test.yml` deckt SwiftPM-Suite weiterhin ab.
- `@testable import` → reines `import` für 15 Test-Files (DayFavoritesStoreTests, RecentFilesStoreTests, LiveLocationFeatureModelTests, HistoryDateRangeFilterTests, ExportSelectionRouteTests, RecordingIntervalPreferenceTests, AppLanguageSupportTests, ImportBookmarkStoreTests, ChartShareHelperTests, LHMapHeaderTests, LiveStatusResolverTests, LoadingProgressEngineTests, RecordedTrackStoreTests, LiveTrackRecorderTests, InsightsDrilldownTests). 7 weitere Files behalten `@testable` (internal nötig).
- API-Naming-Vereinheitlichung (P2-16) und `HeatmapGridBuilder` MapKit-Entkopplung (P2-18) bewusst out-of-scope — public-API-Renames mit Folgerisiken.

**Bündel A — Test-Härtung (9 neue Test-Files, 27 neue Cases):**
- `AppExportDecoderErrorTests` (5), `GPXImportParserErrorTests` (3), `TCXImportParserErrorTests` (2), `GPXRoundTripTests` (2), `AppExportQueriesFilterCombinationTests` (4), `AppHeatmapModelEdgeCaseTests` (3), `LiveLocationFeatureModelStateTransitionTests` (1 Placeholder; Mock-Client-Refactor pending), `ExportMutationsAndFilterTests` (4), `ZIPGoogleTimelineStreamingPathTests` (3).

### Verifikation
- `swift test`: **1044 Tests, 2 Skips, 0 Failures** (vorher 1017; +27 Cases).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.

**Ehrlich offen:** API-Naming (P2-16) und HeatmapGridBuilder MapKit-Entkopplung (P2-18) bewusst not done. `wrapper/CI.xctestplan` SKIP (pbxproj-Integration out-of-scope). `LiveLocationFeatureModelStateTransitionTests` ist 1 Placeholder, Mock-Client-Refactor steht aus. Audit-Item P2-8 bewusst nicht angefasst. Hardware-Re-Verifikation iPhone 15 Pro Max steht aus.

## 2026-05-07 (Audit batch — Block 1-2: WidgetSharedKeys consolidation, onOpenURL in package target, ZIP-entry streaming, import-phase progress)

### fix/feat: 7 Audit-Achsen über zwei Blöcke

**Block 1 — Wiring / Config:**
- `Sources/LocationHistoryConsumerAppSupport/WidgetSharedKeys.swift` (NEU): public `enum` als Single-Source-of-Truth für App-Group-Suite-Name und UserDefaults-Key-Konstanten — ersetzt String-Literale.
- `Sources/LocationHistoryConsumerAppSupport/WidgetDataStore.swift` und `wrapper/LH2GPXWidget/WidgetDataStore.swift` referenzieren jetzt `WidgetSharedKeys.*`. Wrapper-Mirror um `saveDynamicIslandCompactDisplay` ergänzt — beide Mirrors decken jetzt dieselbe Methoden-Surface (P1-3 erledigt).
- `Sources/LocationHistoryConsumerApp/AppShellRootView.swift`: `.onOpenURL { handleDeepLink($0) }` + `handleDeepLink(_:)`. `lh2gpx://live` springt jetzt auch im Package-App-Target den Live-Tab an (P1-4 erledigt).
- Deployment-Target-Inkonsistenz dokumentiert: App 16.0 vs Widget 16.2 (Live Activities erfordern 16.2) — bewusste Entscheidung, in `wrapper/README.md` als Note verankert.

**Block 2 — Streaming-Folge:**
- `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineStreamReader.swift`: neue public `IncrementalParser` (stateful chunk-fed Parser).
- `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineConverter.swift`: neue API `incrementalStreamConverter()` + `IncrementalStreamConverter`.
- `Sources/LocationHistoryConsumerAppSupport/AppContentLoader.swift`: `loadZipContent` nutzt `streamGoogleTimelineCandidateIfApplicable` als Early-Path (Sniff der ersten 1 KB jedes JSON-Entries; greift bei genau einem Google-Timeline-Entry und keinem LH2GPX-Object-Entry) — Peak RAM für ZIP-Google-Timeline jetzt ~ein Element statt voller entpackter Datei (P1-5 erledigt). `loadImportedContent` mit `onPhase: ((ImportPhase) -> Void)?`. Neuer public `enum ImportPhase { reading, parsing, building }`.
- `Sources/LocationHistoryConsumerAppSupport/LoadingProgressEngine.swift`: `@Published var phase: ImportPhase?`, `setPhase(_:)`; `cancel()`/`complete()` setzen Phase auf nil.
- `wrapper/LH2GPXWrapper/ContentView.swift`: `loadImportedFile(at:)` reicht `onPhase`-Closure an `loadingProgress.setPhase(_:)`. ProgressView zeigt lokalisiertes `loadingPhaseLabel` ("Reading file…", "Parsing entries…", "Building model…", Fallback "Opening location history...").

**Tests neu:**
- `GoogleTimelineStreamReaderTests`: 2 neue Cases (`testIncrementalParserAcrossArbitraryChunkBoundaries`, `testIncrementalParserMatchesInMemoryPath`).
- `GoogleTimelineStreamReaderPerformanceTests` (NEU): 3 XCTest-`measure`-Cases (disk-streaming, in-memory, incremental small chunks). Baseline-Logging, kein fail-on-regression bar.

### Verifikation
- `swift test`: **1017 Tests, 2 Skips, 0 Failures** (vorher 1012; 5 neue Cases).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.

**Ehrlich offen:** Mikro-Benchmarks sind Baseline-Logging, kein gemessener Speedup-Faktor. ZIP-Streaming greift nur bei genau einem Google-Timeline-Entry und keinem LH2GPX-Object-Entry — Mixed-ZIPs fallen auf den Legacy-Pfad. Hardware-Re-Verifikation iPhone 15 Pro Max steht aus. Auto-Restore reicht den `onPhase`-Callback bewusst nicht durch. Verbleibend offen: 7× P1-Test-Lücken (P1-18..P1-24), ~19× P2.

## 2026-05-06 (Audit batch — Block 1-4: data-loss wiring + concurrency + edge-case crashes + perf hot-paths)

### fix/feat/perf: 19 Audit-Achsen über vier Blöcke

**Block 1 — Datenverlust / falsche User-Daten (Items 1-6):**
- `LiveLocationServerUploader.swift`: 30 s Per-Request-Timeout (`requestTimeoutSeconds`) — hängender Server blockiert Upload-Queue nicht mehr bis Jetsam.
- `AppExportView.swift`: neue init-Parameter `dayListFilter`, `favoritedDayIDs`, `pathMutations` (default `.empty`); `filteredSummaries` wendet Day-Tab-Chips an, `prepareExport` + beide `ExportPreviewDataBuilder.previewData`-Aufrufer reichen `pathMutations` durch — gelöschte Routen verschwinden aus GPX/KMZ/KML/GeoJSON/CSV + Vorschau.
- `AppContentSplitView.swift`: beide `AppExportView`-Call-Sites übergeben `dayListFilter`, `favoritedDayIDs`, `pathMutationStore.currentMutations`.
- `AppImportedPathMutationStore.swift`: `persist()` schluckt JSON-Encode-Fehler nicht mehr; `@Published var lastPersistFailed`.
- `ExportSelectionContent.swift`: neuer Parameter `mutations: ImportedPathMutationSet = .empty` an `exportDays(...)`; private `applyMutations` filtert `Day.paths` ohne Original-Mutation.
- `ExportPreviewData.swift`: `previewData(...)` erweitert um `mutations`-Parameter.

**Block 2 — Concurrency / Resource-Lecks (Items 7-10):**
- `ActivityManager.swift`: `_endActivityInternal` Identity-Check auf `activity.id`; `_cancelAllActivitiesInternal`-Task `@MainActor`; `_updateActivityInternal`-Task `[weak self]`.
- `LiveLocationFeatureModel.swift`: neuer `deinit { uploadTask?.cancel() }`.
- `AppOptionsView.swift`: `testConnection()` von Completion-Closure auf `Task { @MainActor in await URLSession.shared.data(for:) }` migriert.
- `AppContentSplitView.swift`: `presentSheet(_:)` nutzt `Task { @MainActor in ... }` statt `DispatchQueue.main.async`.

**Block 3 — Edge-Case-Crashes / stillschweigende Fehler (Items 11-13):**
- `KMZBuilder.swift`: ZIPFoundation-`provider`-Closure Bounds-Guard gegen `kmlData.count` — kein NSException mehr.
- `AppContentLoader.swift` (sniffEntryHead): innerer `catch` differenziert `StopExtraction` (collected zurück) von echten ZIPFoundation-Fehlern (`nil` zurück).
- `ImportBookmarkStore.swift`: `restore(userDefaults:)` ruft `startAccessingSecurityScopedResource()` auf der resolved URL; neue `releaseAccessIfNeeded(url:)`-API.

**Block 4 — Performance-Hotspots (Items 14-19):**
- `AppDayMapView.swift`: `DayMapRenderData.PathOverlay.simplifiedCoordinates` precomputed im Init (kein 2× Recompute pro Pfad pro Frame); ISO8601-Formatter statisch.
- `AppExportQueries.swift` + `DaySummaryDisplayOrdering.swift`: Doppel-Sort gefixt (`newestFirst` reverst monoton-asc-Input statt Voll-Sort); `weekdayForDate` mit statischem `utcGregorianCalendar`.
- `AppInsightsContentView.swift`: `weekdayStats` aus pre-computed `derivedModel.weekdayStatsByMetric: [InsightsWeekdayMetric: [InsightsWeekdayMetricStat]]`; Body-Tick recomputet nicht mehr.
- `DaySummaryRowPresentation.swift`: `dayKeyFormatter`/`gregorianCalendar` statische `private static let`.
- `AppHeatmapView.swift`: statischer `baseCountFormatter`; `.continuous` `.onMapCameraChange` entfernt (`.onEnd` reicht).
- `AppDisplayHelpers.swift`: `weekday(_:locale:)` / `monthYear(_:locale:)` mit `NSCache<NSString, DateFormatter>`.

### Verifikation
- `swift test`: **1012 Tests, 2 Skips, 0 Failures** (unverändert; bestehende Tests laufen über die neuen Pfade — keine neuen Tests in diesem Train).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.

**Ehrlich offen:** keine Mikro-Benchmarks der Performance-Optimierungen — Designziel, kein gemessener Speedup-Faktor. Hardware-Re-Verifikation iPhone 15 Pro Max steht aus. Block-1-Mutations-im-Export ändert das bisherige bewusste Verhalten — README-Aussage entfernt. Nicht erledigt: P1-3 (`WidgetDataStore`-Duplikat), P1-4 (`onOpenURL` fehlt im Package-Target), P1-18..P1-24 (Test-Lücken), Live-Activity-Lock-Screen, ZIP-Entry-Streaming.

## 2026-05-06 (P0 audit fixes 3/N — GPX safety, Keychain, schema forward-compat, LoadingBackground frame-rate, ROADMAP truth-pinning)

### fix/feat: tighten six P0 audit findings on five code axes plus ROADMAP
- `Sources/LocationHistoryConsumerAppSupport/GPXImportParser.swift` (P0-2): Force-Cast `as! String` in der Sort-Closure von `buildDaysDict` durch `as? String ?? ""` ersetzt — kein `EXC_BAD_INSTRUCTION` mehr bei malformiertem GPX.
- `Sources/LocationHistoryConsumerAppSupport/GPXImportParser.swift` (P0-3): `fatalError` in `makeExport` entfernt; Funktion ist jetzt `throws` und wirft bei Roundtrip-Fehler `AppContentLoaderError.decodeFailed(fileName)`. `parse(_:fileName:)` propagiert.
- `Sources/LocationHistoryConsumerAppSupport/KeychainHelper.swift` (P0-4): `kCFBooleanTrue!` Force-Unwrap → `true as CFBoolean`. Kein UB-Risiko mehr in App-Extension-Sandboxes.
- `Sources/LocationHistoryConsumer/AppExportModels.swift` (P0-5): `AppExportSchemaVersion` jetzt `struct` mit `rawValue: String` (vorher geschlossenes Enum). Forward-kompatibel — `"2.0"` decodiert weiter; neue Property `isSupportedByThisBuild`. `.v1_0` Konstante bleibt API-kompatibel.
- `Sources/LocationHistoryConsumerAppSupport/LH2GPXLoadingBackground.swift` (P0-6): `RoutePulseOverlay`-TimelineView 30 Hz → 20 Hz; `paused: progress >= 1.0` als defensiver Stop.
- `ROADMAP.md` (P0-8): Test-Count-Widerspruch (964 vs 1006) aufgelöst, neue commit-verankerte Verifikations-Historie.

### Tests
- `testRejectsUnknownSchemaVersion` umgenannt zu `testForwardCompatibleSchemaVersionDecodesAndReportsUnsupported` und Erwartung invertiert.
- Neue `Tests/LocationHistoryConsumerTests/AppExportSchemaVersionTests.swift` mit 6 Cases.
- `swift test`: **1012 Tests, 2 Skips, 0 Failures** (vorher 1006).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.

**Ehrlich offen:** Hardware-Re-Verifikation auf iPhone 15 Pro Max steht weiterhin aus. Mikro-Benchmark der Streaming-Pipeline weiterhin nicht gemessen. 24× P1 + 19× P2 aus dem Audit weiterhin offen. ZIP-Entry-Streaming weiterhin nicht implementiert. Der `paused`-Bind in der TimelineView ist defensives Hardening (die äußere `p < 1.0`-Guard greift schon), kein gemessener Speedup.

## 2026-05-06 (Performance pass on streaming Google Timeline import — UnsafeBytes tokenizer, 256 KB chunks, autoreleasepool, direct model build)

### perf: tighten streaming Google Timeline pipeline on four axes
- `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineStreamReader.swift`: Tokenizer läuft jetzt über `Data.withUnsafeBytes` mit direktem `UnsafePointer<UInt8>`-Zugriff statt `Data.Index`-Iteration. Strukturelle Bytevergleiche per Hex-Literal (`0x5B`/`0x7B`/…) statt `UInt8(ascii:)`. `@inline(__always)` auf `processByte` und `isJSONWhitespace`. Default-`chunkSize` 64 KB → **256 KB**. Per-Element `onElement`-Aufruf in `autoreleasepool` gewrappt — verhindert Akkumulation von Foundation-Zwischenobjekten (NSString/NSNumber/NSDictionary aus `JSONSerialization.jsonObject`) über den Importlauf.
- `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineConverter.swift`: Output-Pfad gibt den `[String: Any]`-Foundation-Tree und den `JSONSerialization`+`AppExportDecoder`-Roundtrip auf. Neue interne `ExportBuilder`-Struktur akkumuliert direkt `Visit`/`Activity`/`Path`/`PathPoint`-Modelle pro DayKey; `finalize()` baut `AppExport` direkt mit den neuen public memberwise-Initializern. Spart auf einer 50k-Entry-Datei: einen kompletten Foundation-Tree-Build, eine JSON-Encode-Pass, eine JSON-Parse-Pass und einen Codable-Decode-Pass.
- `Sources/LocationHistoryConsumer/AppExportModels.swift`: neue `public init(...)`-Memberwise-Initializer für `AppExport`, `Meta`, `Source`, `Output`, `ExportConfig`, `ExportFilters`, `DataBlock`, `Visit`, `Activity` (Cross-Module-Voraussetzung für den Direct-Model-Build). `Day`, `Path`, `PathPoint` hatten bereits public inits.
- `swift test`: **1006 Tests, 2 skipped, 0 failures** (gleicher Umfang; bestehende Tests laufen unverändert über die optimierten Pfade).
- Wrapper `xcodebuild` (iPhone 17 Pro Max Sim 26.3.1): BUILD SUCCEEDED.

**Ehrlich offen:** kein ZIP-Entry-Streaming (ZIPFoundation extrahiert weiterhin in eine `Data`, dann läuft der Reader darauf). Auto-Restore lehnt rohe Google Timeline weiterhin ab. Hardware-Re-Verifikation auf iPhone 15 Pro Max mit echter 46-MB-Datei steht weiterhin aus. Keine Mikro-Benchmarks gemessen — die genannten Einsparungen sind erwartete Größenordnungen / Designziel, kein gemessener Speedup-Faktor.

## 2026-05-06 (Element-based streaming parser for Google Timeline JSON)

### feat: streaming reader for raw Google Timeline JSON imports
- Manuelle Imports laden die Datei nicht länger komplett zusammen mit einem `JSONSerialization`-Tree.
- Neue Datei `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineStreamReader.swift`: `forEachObjectElement(contentsOf url:)` streamt Top-Level-Array-Elemente via FileHandle in 64-KB-Chunks; pro Element wird nur ein Object-Slice an `JSONSerialization.jsonObject(with:)` übergeben. Schwester-Variante `forEachObjectElement(in data:)` für ZIP-extrahierte Daten. State-Machine-Tokenizer mit String-/Escape-/Depth-Tracking, BOM-Skip, RFC-8259-Whitespace. Hard-Cap pro Element 8 MB → `StreamError.elementTooLarge`. Errors: `notArray`, `malformedJSON`, `ioFailure`, `elementTooLarge`.
- `GoogleTimelineConverter.swift`: `convert(data:)` läuft jetzt intern über den Streaming-Reader; neue API `convertStreaming(contentsOf url:)` für direkte JSON-Datei-Imports ohne Full-Data-Load. Ingest in `ingestEntry(...)` gemeinsam für beide Pfade.
- `AppContentLoader.swift`: `decodeFile(at:sourceName:)` sniffed die ersten 1 KB; bei `[` direkt in `convertStreaming(contentsOf:)`. Auto-Restore-Skip-Verhalten unverändert (Streaming ist speichersicher, aber Sekunden bis Minuten — bewusst nutzergesteuert).
- Tests neu: `Tests/LocationHistoryConsumerTests/GoogleTimelineStreamReaderTests.swift` mit 15 Cases (Happy Path, BOM/Whitespace, String mit `}]`, escaped Quote, nested Path, Error-Pfade, byte-by-byte-Chunking-Boundary-Test, 5 000-Entry-Synthetik, `convert(data:)` ↔ `convertStreaming` Äquivalenz).
- `swift test`: **1006 Tests, 2 skipped, 0 failures** (vorher 991).

**Ehrlich offen:** ZIP-Entry-Streaming bleibt aus — ZIPFoundation extrahiert weiterhin in eine `Data`, dann läuft der Streaming-Reader darauf (Memory-Peak ≈ Größe der entpackten Datei, aber ohne zusätzlichen 150–200-MB-`JSONSerialization`-Tree). Hardware-Re-Verifikation auf iPhone 15 Pro Max mit echter 46-MB-Datei steht aus. Auto-Restore lehnt rohe Google Timeline weiterhin ab. Bei >500 k Entries bleibt das einmalig aufgebaute `dayMap` ein nichttriviales RAM-Plateau, aber Größenordnungen unter dem alten Pfad.

## 2026-05-06 (Memory-Safety-Folgefix: Sniffer-Skip im Auto-Restore)

### fix: skip raw Google Timeline files during auto-restore regardless of size
- Folgefix zum Memory-Safety-Commit `8abe7ec`: Der vorherige reine 50-MB-Cap erfasste den realen 46-MB-iPhone-Crashfall NICHT (46 < 50). Der ergänzte Sniffer-Skip schließt die Lücke.
- `Sources/LocationHistoryConsumerAppSupport/AppContentLoader.swift`: Funktion `assertSizeWithinAutoRestoreLimitIfNeeded` umbenannt zu `assertAutoRestoreEligible`. Im Auto-Restore-Modus genügt das Sniffer-Ergebnis (`firstStructuralByte == '['`), um eine rohe Google-Timeline abzulehnen — **unabhängig von der Größe**. Gilt für direkte JSON-Dateien und für ZIPs mit Google-Timeline-Entry (Head-Sniff via begrenztem ZIP-extract-Abbruch).
- Manueller Import (`autoRestoreMode == false`) bleibt unberührt; bei manueller Auswahl gilt weiter der ehrliche 256-MB-Cap. Ein echter Streaming-Parser fehlt nach wie vor.
- `userFacingTitle`: "Large Google Timeline import detected" → "Import not auto-restored". `errorDescription` erweitert um den Grund "Raw Google Timeline exports and large files are skipped on launch …".
- 4 neue Tests in `LargeImportMemorySafetyTests` (`testAutoRestoreSkipsRawGoogleTimelineUnderSizeCap`, `testAutoRestoreSkipsRawGoogleTimelineZipEntryUnderSizeCap`, `testAutoRestoreAllowsSmallAppExportLikeFile`, `testManualLoadAllowsRawGoogleTimeline`) — Suite jetzt 18 Cases.
- `swift test`: 991 Tests, 2 skipped, 0 failures (vorher 987).
- **Ehrlich offen:** Manuelle Importe großer roher Google-Timeline-Dateien (>~30–40 MB) bleiben weiterhin riskant — kein echter Streaming-Parser. Hardware-Re-Verifikation des 46-MB-Falls auf iPhone 15 Pro Max steht aus.

## 2026-05-06 (Memory-Safety-Fix)

### fix: guard large Google Timeline restore against memory pressure
- iPhone-15-Pro-Max-Hardware meldete einen Jetsam-Kill für `LH2GPXWrapper` beim App-Start, wenn ein zuvor importiertes 46-MB-Google-Timeline-File (`location-history.zip`, ~65 k Einträge) per Auto-Restore wieder geladen wurde. Drei volle `JSONSerialization`-Passes plus Zwischen-Modelle = transienter Peak ~400–500 MB → Jetsam-fatal.
- **Auto-Restore-Schutz:** `AppContentLoader.loadImportedContent(from:autoRestoreMode:)` prüft im Auto-Restore-Modus die Dateigröße **vor** dem Read (`autoRestoreMaxFileSizeBytes = 50 MB`). Für ZIPs werden Entry-Metadaten via ZIPFoundation iteriert, ohne zu extrahieren. Über dem Cap wirft `AppContentLoaderError.autoRestoreSkippedLargeFile`. `wrapper/LH2GPXWrapper/ContentView` zeigt dedizierte User-Hinweis-Message ("Großer Google-Timeline-Import erkannt … bitte manuell importieren") und behält das Bookmark.
- **Sniffer-Detection:** `GoogleTimelineConverter.isGoogleTimeline` und neuer `isJSONObject` lesen nur das erste 1 KB (skippt Whitespace + UTF-8-BOM) und prüfen das erste Strukturzeichen. AppContentLoader-ZIP-Pfad nutzt den Object-Sniffer statt Array-Vollparse — erspart pro Aufruf ~150–200 MB transient.
- **Query-Fast-Path:** `AppExportQueryFilter.isPassthrough` (public, neu) + `AppExportQueries.projectedDays`-Fast-Path: bei deaktiverten Constraints werden Tage direkt sortiert zurückgegeben statt pro Tag eine `projectedDay(...)`-Kopie zu erzeugen. Spart ~80–130 MB transient pro Aufruf auf 65 k-Tage-Imports.
- **OverviewMap bounded coordinates:** `OverviewMapPathCandidate.fullCoordinates` wird in der Scan-Phase auf max 512 Punkte stride-decimiert. Visuell verlustfrei (Douglas-Peucker läuft trotzdem in `makeOverlay`), spart ~70–90 % residenten RAM bei dichten Tracks.
- 14 neue Tests in `LargeImportMemorySafetyTests` (Sniffer/Auto-Restore-Skip JSON+ZIP/Manueller-Import-bypass-Cap/`isPassthrough`/Query-Fast-Path/`strideDecimate`).
- `swift test`: 987 Tests, 2 skipped, 0 failures.
- `xcodebuild` (iPhone 17 Pro Max Sim 26.3.1): BUILD SUCCEEDED.
- Hardware-Verifikation auf iPhone 15 Pro Max mit echter 46-MB-Datei: pending (manuell).
- **Ehrlich offen:** echter Streaming-/Chunked-Google-Timeline-Parser noch nicht umgesetzt. Manuelle Importe > 50 MB sind weiterhin riskant; im Auto-Restore-Pfad wird der Fix zuverlässig greifen. **Nachtrag 2026-05-06 (Folgefix):** Der reine 50-MB-Cap allein war nicht ausreichend — er erfasste den realen 46-MB-Crashfall nicht. Ein zusätzlicher Sniffer-Skip lehnt rohe Google-Timeline-Dateien im Auto-Restore jetzt unabhängig von der Größe ab; siehe Eintrag oben.

## 2026-05-06 (post-Hero-Map)

### docs: deep audit + repo-truth-sync (HEAD post-`70254ff`)
- Wrapper-Doku Datei-fuer-Datei und Zeile-fuer-Zeile gegen Code abgeglichen.
- README: SPM-Pfad `../..` → `..` korrigiert (war seit `379b835` falsch dokumentiert); `fileImporter`-Aussage auf reale `allowedContentTypes` `[.json, .zip, .gpx, .tcx]` korrigiert (KML/GeoJSON sind Export-only); ASC-/Build-Status auf `CURRENT_PROJECT_VERSION = 100` aktualisiert.
- ROADMAP/NEXT_STEPS: Test-Zahl `228` (Linux, 2026-03-31) → `964` (macOS, 2026-05-06). Phase 19.53 als abgeschlossen markiert.
- xcode-test.yml: Kommentar zum SPM-relativePath korrigiert.

### feat: unify map layer controls into single right-side dropdown (commit `70254ff`)
- Neue Komponente `MapLayerMenu.swift` (Configuration-driven Dropdown) konsolidiert ALLE Map-Layer-Controls (Map-Style, Track-Color, Live-Optionen, Heatmap-Palette/Scale/Radius/Opacity, Fit-to-Data, Center-on-Location, Fullscreen).
- `LHMapStyleToggleButton` als `@available(*, deprecated)` markiert.
- Heatmap-Bottom-Sheet, Capsule-Chip-Cluster, Follow-Pill, Fullscreen-Close-X, standalone Style-Toggles und Fit-Buttons auf allen Map-Surfaces entfernt — durch das Menü ersetzt.
- Heatmap-Opacity snappt auf `25 / 50 / 75 / 100 %` Presets (Slider war im SwiftUI-Menu nicht moeglich).
- Heatmap-Stats bleiben als kleines bottom-leading Badge (Punkte · Tage · Datumsbereich).
- Tote Parameter (`verticalMapControls`, `showStyleToggle`) und Hilfsfunktionen (`mapControlButton`, `exploreControlButton`, `styleToggleIcon`) entfernt; alle Aufrufer aktualisiert.
- Day-Map nutzt jetzt `mapPosition`-State (statt statisches `initialPosition`) — Viewport springt bei Tag-Wechsel und Fit-to-Data ist verdrahtet.
- Export-Preview Fit-to-Data ergänzt; Overview `isFullscreenActive` korrekt an `isExpanded` gebunden.
- Live-Tracking Landscape-Card und Fullscreen nutzen jetzt die geteilten `liveAccuracyCircleContent` / `liveTrackContent` / `liveCurrentLocationAnnotation` MapContent-Builder — vorher hat das Landscape-Layout `MapLayerMenu`-Flags ignoriert (Speed-Coloring, Fade-Buckets, Accuracy-Circle).
- Heatmap-Overlay-Pattern auf einheitliches `.overlay(alignment:)` umgestellt; Padding repo-weit auf `8 pt`.
- Build green: `swift test` 964/2/0; Wrapper-`xcodebuild` (iPhone 17 Pro Max Sim 26.3.1) BUILD SUCCEEDED.

### fix: defensive guards against SIGABRT on launch (commit `74300a6`)
- Live-Tracking-Domain mit Defensiv-Guards gegen seltene Crash-Pfade beim App-Start.

### feat: maps next-level — Tempolayer, halo strokes, live polish (commit `ab054c7`)
- SpeedColors-Tempolayer als optionales Track-Coloring (cool→warm).
- Halo-Understrokes für bessere Kontraste auf Hybrid-Maps; Track-Width-Hierarchie nach Kontext (live > day > overview > export).

### feat: home screen — electric lightning background (commit `fa006cd`)
- `HomeBackground.imageset` für den Start-Bildschirm der Wrapper-App.

### feat: heatmap next-level — Magma palette, log-scale, soft-glow cells (commit `9118ac6`)
- Magma/Inferno-Paletten (perzeptuell uniform); Log-Scale-Aggregation; Soft-Glow-Cells via Radialgradient — bullseye-Ringe und harte Hex-Kanten visuell aufgelöst.

### feat: remove Routes mode from heatmap entirely (commit `fc3ccc5`)
- Routes-Modus aus der Heatmap entfernt; ausschliesslich Density.

### fix: heatmap P0 follow-up batches (commits `825a3de`, `50b4c58`, `bbd9e3b`, `f5de284`)
- Vier Verifikations-Batches mit Defaults für Streetzoom, weniger Burnout, sane low-density-Sichtbarkeit.

### feat: heatmap density Tier 2 — pointy-top hexagons + Mercator + cos(lat) (commits `a2f50bc`, `2e1c928`, `6a7c361`)
- Pointy-top Hexagon-Polygone als Tile-Geometrie; Mercator-Latitude-Korrektur; cos(lat)-Bin-Aggregation.

### fix: heatmap Tier 1 — kill lens-flare, soften block edges, fix i18n (commit `e7a2379`)
- Lens-Flare-Star entfernt; weichere Tile-Kanten; deutsche Lokalisierung der Heatmap-Beschriftungen korrigiert.

### feat: replace bundled demo fixture with real recorded LH2GPX track (commit `b1d65cb`)
- Bundled Demo-Fixture jetzt ein realer aufgezeichneter LH2GPX-Track (Oldenburg → Dänemark).

### chore: bump build number 96 → 100 (commit `8854eef`)
- `CURRENT_PROJECT_VERSION` auf `100` in pbxproj (alle 8 Build-Konfigurationen); `CFBundleVersion = 100` hartcodiert in beiden Info.plist-Dateien (App + Widget). Naechster ASC-Submit-Kandidat: Build ≥100 aus Xcode Cloud.

## 2026-05-06

### feat: LiveStatusResolver + Export-Empty-State-Cleanup + Polish
- Neuer `LiveStatusResolver` konsolidiert Live-Status (Permission/Acquiring/Ready/Recording × Weak/Good). Eine dominante Hauptmeldung pro Zustand. GPS-Chip "Searching" statt "Weak" wenn kein Fix.
- Export: Ende der widersprüchlichen Empty-Messages — Hero-Placeholder + Chip + Card adaptieren, `Select All`-CTA prominent.
- Doppelte Karte auf Export-Tab behoben (Preview-Card unterdrückt Map-Render bei `heroEnabled`).
- Settings/Insights Quick-Wins: Lesbarkeit der Beschreibungen, KPI-Grid Dynamic-Type-robust.
- `swift test`: 949 Tests, 2 skipped, 0 failures ✅
- Privacy/Upload-Defaults und Recording-Verhalten unverändert.

### feat: Hero-Map-Workspace auf Übersicht/Insights/Export/Live ausrollen (Tage-Optik)
- Neue gemeinsame Komponente `LHHeroMapWorkspace.swift` (Layout-Konstanten + `lhDeviceTopSafeInset()`).
- Compact iPhone: Map auf Übersicht/Insights/Export/Live/DayDetail-Portrait läuft jetzt full-bleed unter Status-Bar / Dynamic Island, vertikaler Control-Stack rechts oben, Filter/Range/Format-Chips unter der Map (analog Tage).
- Bestehende Funktionen (Heatmap, fileExporter, Recording/Follow/Fullscreen, ExportPreviewDataBuilder, AppOverviewMapModel-Pan-Invariante) erhalten.
- iPad/Regular + Landscape: Legacy-Pfade unverändert.
- `swift test`: 933 Tests, 2 skipped, 0 failures ✅
- App-Store: Build 96 noch nötig vor Submit; Visual-Verifikation auf echtem Gerät offen.

### fix: consolidate Days top workspace + map controls below status bar (Build 96 nötig)

- **Root Cause Statusbar**: Map-Controls (Globe/Fit-to-data) in `AppOverviewTracksMapView.compactMapView` lagen mit nur `.padding(8)` direkt am oberen Map-Rand. Da Days die Map per `.ignoresSafeArea(edges: .top)` hinter Dynamic Island/Statusbar zieht, landeten die Buttons sichtbar im Statusbar-Bereich.
- **Fix Statusbar**: Neuer Initializer-Param `mapControlTopPadding: CGFloat = 8` (Default unverändert für Overview/Detail). Days reicht `deviceTopSafeInset + 12` durch — Buttons liegen sichtbar unter Dynamic Island.
- **Root Cause LHCollapsibleMapHeader**: `safeAreaTopInset`-Parameter existierte, wurde aber im Body ignoriert. `geometry.safeAreaInsets.top` liefert in `safeAreaInset/ignoresSafeArea`-Kontexten 0.
- **Fix LHCollapsibleMapHeader**: `overlayControlBar(safeAreaTop: max(geometry.safeAreaInsets.top, safeAreaTopInset))` — der von außen gemessene Wert wird wirksam.
- **Konsolidierung Top-Workspace**: Die zwei separaten `.safeAreaInset(edge: .top)`s aus dem vorigen Eintrag (Map + Filter) sind jetzt zu EINEM `safeAreaInset` mit `VStack { daysListStickyHeader; daysFilterPanel }.background(.black)` zusammengefasst. Robuster gegen List-/Section-Header-Insets, kein Gap zwischen den beiden Stickys.
- **Filter-Padding**: Top-Padding 8 → 4, damit Suchleiste flush an Map sitzt.
- **Test-Hooks**: Suchfeld bekommt `accessibilityIdentifier("days.searchField")`.
- `swift test`: 933/0 (2 skipped) ✅
- `xcodebuild` iPhone 17 Pro Sim 26.3.1: **BUILD SUCCEEDED** ✅
- `xcodebuild` iPhone 15 Pro Max physisch (UDID 00008130-00163D0A0461401C): **BUILD SUCCEEDED** ✅
- `devicectl install` + `process launch` auf iPhone 15 Pro Max ✅
- **Visuelle Verifikation am echten Gerät steht aus** (User testet lokal). Build-96-Einreichung erst nach OK.

### fix: filter panel as second safeAreaInset, eliminates 80pt gap (Build 96 nötig)

- **Root Cause**: 80pt schwarzer Streifen zwischen Map-Unterkante und Searchbar entstand durch List-internes Top-Padding (Nav-Bar-Safe-Area 44pt + First-Section-Header-Inset ~36pt). Weder `.listStyle(.plain)` noch `.ignoresSafeArea(.all)` auf der Map konnten das beheben — beide adressieren nur die Safe-Area-Seite, nicht die List-interne Seite.
- **Fix**: `daysFilterPanel` komplett aus der List entfernt und als ZWEITES `.safeAreaInset(.top)` direkt unter dem Map-StickyHeader gestapelt. Beide sind jetzt sticky und garantiert flush — Searchbar liegt immer direkt an der Map-Unterkante.
- **UX-Bonus**: Searchbar + Date/Filter-Chips sind jetzt während des Scrollens immer sichtbar (vorher verschwanden sie beim Hochscrollen).
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone 15 Pro Max **BUILD SUCCEEDED** ✅

### polish: compact days controls below map (Build 96 nötig — Build 95 veraltet)

- **Control-Clearance erhöht**: `overlayControlBar` in `LHCollapsibleMapHeader` padded jetzt `.padding(.top, safeAreaTop + 80)` statt `+ 56` — ergibt ~139 pt ab Bildschirmoberkante auf iPhone 15 Pro Max (Dynamic Island). Keine App-Controls mehr im Bereich von Uhrzeit, Akku, Mobilfunk oder Dynamic Island.
- **Schwarze Lücke zwischen Map und Searchbar entfernt**: Root Cause war der `.insetGrouped` List-Default-Style mit seinem Top-Content-Inset. Fix: `.listStyle(.plain)` auf `compactDayList` — Searchbar beginnt jetzt direkt unter der Karte.
- **Filter-Panel kompaktiert**: `compactContextPill` (passive Datumsanzeige) durch interaktive `HistoryDateRangeFilterBar` direkt im Chip-Row ersetzt. Die separate `HistoryDateRangeFilterBar`-Section (die bei aktivem Filter zusätzlich erschien und "Last 7 Days" doppelt anzeigte) entfernt. Eine Zeile statt zwei für den Datumsfilter.
- Build 95 (Commit c5a81f7) ist **veraltet** — enthält diesen Fix nicht. Nächster Submit-Build: **Build 96**.
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone 15 Pro Max **BUILD SUCCEEDED** ✅

### polish: Days Map-Höhe erhöht, schwarze Lücke über Filter-Panel entfernt (Build 95 nötig — veraltet)

- **Map-Höhe angehoben**: `daysMapHeaderState.compactHeight` 340 → 460 pt, `expandedHeight` 420 → 560 pt — Map-Unterkante auf iPhone 15 Pro Max nun bei ca. 460 pt ab y=0, innerhalb der Zielmarke.
- **Schwarze Lücke eliminiert**: SwiftUI-List-Default-Section-Spacing (≈20 pt) zwischen Map-StickyHeader und erstem List-Section entfernt via `DaysListSectionSpacingModifier` (`.listSectionSpacing(0)`, iOS-17-only, no-op auf iOS 16).
- **iOS-16-Kompatibilität**: Modifier als `private struct DaysListSectionSpacingModifier: ViewModifier` mit `if #available(iOS 17.0, *)` Guard — compiliert auf allen Zielplattformen.
- Build 94 (Commit 728f50a) ist **veraltet** — enthält diesen Fix nicht. Nächster Submit-Build: **Build 95**.
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone 15 Pro Max **BUILD SUCCEEDED** ✅

### polish: Days Filter below Map, DayCard Layout tightened (Build 94 nötig — veraltet, Build 94 enthält diesen Fix nicht)

- **Search + Date-Filter aus dem Map-Overlay entfernt**: Search-Bar und Date-Range-Pill lagen bisher als ZStack-Overlay direkt auf der Karte (und damit teilweise hinter dem Dynamic Island). Beides jetzt als kompakter `daysFilterPanel` direkt unterhalb der Karte im scrollbaren List-Content.
- **Safe-Zone freihalten**: Die Expand/Collapse-Buttons in `LHCollapsibleMapHeader` (overlayControls-Modus) nutzen jetzt einen `GeometryReader`, der `geometry.safeAreaInsets.top` liest und als `.padding(.top, ...)` auf die Button-Group anwendet — iOS-16-kompatibel, keine `safeAreaPadding`-API nötig.
- **DayCard horizontales Padding reduziert**: `AppDayRow` von `.padding(14)` auf `.padding(.horizontal, 8).padding(.vertical, 12)` — mehr Breite, Touch-Targets ≥ 44pt erhalten.
- **DayList Row-Insets verkleinert**: `.listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))` auf allen DayRows (compact + iPad) — dichtere Liste, weniger Luft zwischen Karten.
- **Separator + Row-Background**: `.listRowSeparator(.hidden)` und `.listRowBackground(Color.clear)` auf DayRows gesetzt — konsistenter mit dem Dark-Design.
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone 15 Pro Max **BUILD SUCCEEDED** ✅

### polish: Days Map Edge-to-Edge Hero with Overlay Controls (Build 93)

- **Edge-to-Edge Hero**: Karte füllt volle Breite und beginnt bei y=0 hinter Dynamic Island/Statusbar (`ignoresSafeArea(.container, edges: .top)` auf `daysMapHeaderCard` im ZStack-Hero)
- **NavigationBar transparent**: `.toolbarBackground(.hidden, for: .navigationBar)` auf dem compact Days-Tab — kein schwarzer Header-Block mehr über der Karte
- **Searchbar als Map-Overlay**: Native `.searchable` ersetzt durch Custom TextField in `.thinMaterial`-Container, direkt auf der Karte als ZStack-Overlay (SafeArea-bewusst)
- **Context-Pill als Map-Overlay**: Date-Range-Pill (bisher unterhalb der NavBar) jetzt ebenfalls als transparentes Overlay auf der Karte
- **Map-Höhe erhöht**: `compactHeight` 280 → 340 pt, `expandedHeight` 360 → 420 pt — mehr Karte sichtbar
- **Day-Row Chips nicht mehr abgeschnitten**: `metricPill`-HStack in `AppDayRow` in `ScrollView(.horizontal)` gewrappt; `.lineLimit(1)` durch `.fixedSize(horizontal: true, vertical: false)` ersetzt — "6 visits", "3 routes", "23.2 km" vollständig sichtbar
- **Chip-Spacing reduziert**: 10 → 8 pt für kompaktere Darstellung; alle 4 Metric-Chips in einer Zeile
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone 15 Pro Max **BUILD SUCCEEDED** ✅

## 2026-05-05

### UI-Layout-Fix Tage-Seite: Suchleiste stabil, Karte größer

- **Suchleiste stabil**: `navigationBarTitleDisplayMode` auf Days-Tab von `.large` → `.inline` — verhindert das Heruntergleiten der iOS-SearchBar beim Scrollen und die Überlagerung des Sticky-Headers
- **Karte deutlich größer**: `daysMapHeaderState.compactHeight` 180 → 280 pt, `expandedHeight` 260 → 360 pt — die eigentliche Map-Viewport-Fläche entspricht nun ca. 30–33 % des sichtbaren Bereichs
- **Leerer Streifen eliminiert**: `LHSectionHeader("Map")` aus `daysMapHeaderCard` entfernt — der `LHCollapsibleMapHeader.controlBar` übernimmt die Steuerung; kein doppelter Header mehr
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone 15 Pro Max (iOS 26.4): **BUILD SUCCEEDED** ✅

### UI Polish: Doppeltitel-Fix, Limit-Badge, Demo-Label, Privacy-Banner (Commit ce993d9)

- **Doppeltitel behoben** (Insights + Export): `.navigationTitle("")` + `.navigationBarTitleDisplayMode(.inline)` — kein doppelter Titel mehr in den Sheet-Überschriften
- **Limit-Badge unterdrückt**: `localizedProjectedFilterDescriptions` blendet „Limit: N days"-Badge aus der UI aus
- **Demo-Fixture-Label**: Anzeigename von `golden_app_export_sample_small.json` auf `Bundled sample` geändert (nutzerfreundlicher)
- **Privacy-Banner im Empty State**: `ContentView` zeigt Privacy-Hinweis-Row im leeren Zustand
- **DemoSessionStateTests**: an neues Demo-Label angepasst
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone_15_Pro_Max (arm64, iOS 26.4): **BUILD SUCCEEDED** ✅
- Commit `ce993d9`, Branch `main`, Push ✅
- **Hinweis**: ce993d9 wurde nach Xcode Cloud Build 84 gepusht. Vor Submit for Review ist ein neuer Xcode Cloud Build erforderlich.

### Stop-Ship-Fixes: Auto-Split, Widget-Daten, Widget-Family (Commit 3469bcc)

- **Bug 1 — LiveTrackRecorder Auto-Split Datenverlust behoben**:
  - `start()` löscht `splitOffTrack` nicht mehr (zuvor sofortiger Datenverlust nach dem Split)
  - `handleLocationSamples` draint `splitOffTrack` nach jedem Sample-Batch: persistiert den fertigen Segment-Track, setzt neue `currentRecordingSessionID`, aktualisiert `liveTrackPoints` auf das neue Segment
  - 4 neue Tests in `LiveTrackRecorderTests` + 2 neue Integrationstests in `LiveLocationFeatureModelTests`
- **Bug 2 — Home-Widget erhält echte Echtdaten**:
  - `stopRecordingFlow()` und Split-Drain rufen `updateWidgetData()` auf
  - `updateWidgetData()` schreibt `WidgetDataStore.save(recording:)` + berechnet und schreibt `saveWeeklyStats()` (Wochenbasis, `Calendar.current`)
  - `ContentView` reloaded WidgetKit-Timelines via `WidgetCenter.shared.reloadAllTimelines()` bei `preferences.widgetAutoUpdate == true`; `import WidgetKit` ergänzt
- **Bug 3 — Home-Widget Family-Switch**:
  - `LH2GPXWidgetEntryView` (neu) mit `@Environment(\.widgetFamily)`: `systemSmall` → `LH2GPXSmallWidgetView`, sonst → `LH2GPXMediumWidgetView`
  - `LH2GPXHomeWidget.body` nutzt jetzt `LH2GPXWidgetEntryView` statt immer `LH2GPXMediumWidgetView`
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone_15_Pro_Max (arm64, iOS 26.4): **BUILD SUCCEEDED** ✅
- Commit `3469bcc`, Branch `main`, Push ✅

### Xcode Cloud Build 84 — erfolgreich (Version 1.0.1)

- **Build 84**: Xcode Cloud Workflow `Release – Archive & TestFlight` — `Archive - iOS` ✅, `TestFlight-interne Tests - iOS` ✅
- **Version**: `1.0.1 (84)` — erster valider Build für den 1.0.1-Train
- **Befund**: MARKETING_VERSION-Fix aus Commit `fdd48a9` hat das ITMS-90186/90062-Problem behoben
- **Nächster manueller Schritt**: In ASC Version `1.0.1` → Build `84` auswählen, Screenshots prüfen/ersetzen (6 iPhone-15-Pro-Max-PNGs aus `docs/app-store-assets/screenshots/iphone-67/`), speichern, `Zur Prüfung einreichen`
- `swift test`: 927/0 ✅ — `git diff --check`: sauber ✅
- Build 83 (und 80–82): ungültig, ignorieren — scheiterten an geschlossenem 1.0-Train, nicht an Code

### Version-Bump 1.0 → 1.0.1 (ASC Upload-Fix)

- **Root Cause Build 83**: ASC lehnte Upload mit ITMS-90186 (`Invalid Pre-Release Train — 1.0 closed`) + ITMS-90062 (`CFBundleShortVersionString [1.0] must be higher than previously approved [1.0]`) ab. Kein Code-, Signing- oder Xcode-Cloud-Problem.
- **Fix**: `MARKETING_VERSION` in `project.pbxproj` von `1.0` → `1.0.1` (alle 8 Build-Konfigurationen: LH2GPXWrapper Debug/Release, Widget Debug/Release, Tests Debug/Release, UITests Debug/Release)
- Plists bleiben unverändert: `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` — kein hardcodierter Wert
- `CURRENT_PROJECT_VERSION = 45` bleibt lokaler Fallback; `CI_BUILD_NUMBER` injiziert weiterhin echte Buildnummer via `ci_pre_xcodebuild.sh`
- ASC Version `1.0.1` bereits angelegt; nächster Xcode Cloud Build (≥ 84) soll unter `1.0.1` hochgeladen werden
- `swift test`: 927/0 ✅ — `git diff --check`: sauber ✅

### Landscape-Verifikation + UITest-Fix

- **testLandscapeLayoutSmoke** (neu): Landscape-Smoke-Test für alle 5 Haupt-Tabs (Overview, Days, Export, Insights, Live) auf iPhone 15 Pro Max — PASSED (62s); Portrait-first-Strategie mit Tab-Rotation pro Tab; Screenshots als Testanhänge
- **Live-Activity-Identifier-Fix** (`runLiveActivityCaptureFlow`): stale Identifier `live.recording.start/stop` → `live.recording.primaryAction/stopAction` korrigiert (alle 5 Capture-Tests waren ohne diese Korrektur nicht lauffähig)
- Landscape-Befund: kein Layout-Crash in allen 5 Tabs; `live.recording.primaryAction`-Accessibility in Landscape als bekannte UITest-Einschränkung (XCTest nach Rotation) dokumentiert
- APPLE_VERIFICATION_CHECKLIST.md: Landscape-Sektion ergänzt mit PASSED-Befund und bekannter Accessibility-Lücke
- NEXT_STEPS.md: Landscape-Checkbox abgehakt

## 2026-04-30

### Release Prep Truth Sync
- lokales Wrapper-Projekt auf Build `45` angehoben, damit der naechste Release-Kandidat ueber dem bereits dokumentierten TestFlight-Build `1.0 (44)` liegt
- explizite Release-`CODE_SIGN_IDENTITY` fuer App + Widget entfernt; `CODE_SIGN_STYLE = Automatic` bleibt der einzige Repo-Signing-Pfad
- lokaler Release-Befund dokumentiert: `xcodebuild archive` erfolgreich, `xcodebuild -exportArchive` auf diesem Host weiterhin blockiert (`No signing certificate "iOS Distribution" found`)

## 2026-04-30

### Verification Doc Truth Sync
- Wrapper-Doku und Runbooks auf aktuellen Release-Truth gezogen: `TARGETED_DEVICE_FAMILY = 1` (iPhone-only v1), keine iPad-Screenshot-Pflicht fuer den aktuellen Build
- Deployment-Target-Doku fuer App/Widget auf `iOS 16.0 / 16.2` korrigiert
- keine Produktcode-Aenderung; nur Verifikations- und Runbook-Drift bereinigt

## 2026-04-29

### Dynamic Island / Live Activity Truth Sync
- Wrapper-Doku auf den aktuellen Core-Stand fuer Dynamic-Island-Konfiguration gezogen: persistenter Primärwert (`Distanz`, `Dauer`, `Punkte`, `Upload-Status`), sichtbare Fallback-Hinweise bei deaktivierten / nicht verfuegbaren Live Activities und kompakterer Heatmap-Einstieg in der Overview
- frischer lokaler Nachweis ergaenzt: `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build` erfolgreich
- frischer Simulator-Testlauf fuer `LH2GPXWrapperTests` konnte auf diesem Host nicht repo-wahr als gruen verbucht werden; der Launch brach mit `NSMachErrorDomain Code=-308 (ipc/mig server died)` ab und bleibt deshalb offen dokumentiert

## 2026-04-12

### Truth Sync
- Wrapper-Doku auf den aktiven `iOS-App`-Repo-Kontext nachgezogen; historische Monorepo-Hinweise bleiben nur als Kontext
- aktueller Linux-Nachweis auf `swift test` im aktiven Repo korrigiert: `575` Tests, `2` Skips, `0` Failures
- Wrapper-Beschreibung auf echten Produktstand angeglichen: dedizierter Live-Tab, Widget-/Dynamic-Island-Optionen, Fullscreen-/Follow-Live-Karte und ehrliche Abgrenzung von offenen Punkten wie fehlendem Auto-Resume und fehlendem echtem Road-Matching

## 2026-04-12

### App Groups Entitlements / Widget-Datenaustausch
- `wrapper/LH2GPXWrapper/LH2GPXWrapper.entitlements` erstellt mit `com.apple.security.application-groups: group.de.roeber.LH2GPXWrapper`
- `wrapper/LH2GPXWidget/LH2GPXWidget.entitlements` erstellt mit `com.apple.security.application-groups: group.de.roeber.LH2GPXWrapper`
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: `CODE_SIGN_ENTITLEMENTS` fuer alle 4 Build-Konfigurationen beider Targets (`LH2GPXWrapper` + `LH2GPXWidget`) gesetzt
- Widget-Datenaustausch via `WidgetDataStore` (UserDefaults App Group) funktioniert jetzt korrekt; vorher zeigte Widget immer "Keine Aufzeichnung"

### fileImporter GPX/TCX
- `allowedContentTypes` in `ContentView.swift` von `[.json, .zip]` auf `[.json, .zip, .gpx, .tcx]` erweitert
- `UTType.tcx` Extension in Core (`GPXDocument.swift`) hinzugefuegt

### Deep Link lh2gpx://live
- `CFBundleURLTypes` mit Schema `lh2gpx://` in `wrapper/Config/Info.plist` registriert
- `onOpenURL`-Handler + `handleDeepLink()` in `ContentView.swift` hinzugefuegt; navigiert zu Live-Tab (`selectedTab = 3`) via `navigateToLiveTabRequested` in `LiveLocationFeatureModel`

## 2026-03-31

### Repo-Truth Deep Audit / Doc Sync

- repo-weite Deep-Audit-Synchronisierung gegen Code, Wrapper-Konfiguration und Host-Realitaet; aktuelle Truth-Bloecke jetzt auf den frischen Core-Linux-Nachweis `swift test`: `228` Tests, `2` Skips und `0` Failures gezogen
- historische Apple-/Device-/Simulator-Nachweise vom 2026-03-17 und 2026-03-30 expliziter als historische Nachweise markiert; fuer diesen Audit-Host wird jetzt klar festgehalten, dass `xcodebuild` auf Linux nicht verfuegbar ist
- `README.md`, `ROADMAP.md`, `NEXT_STEPS.md`, `docs/LOCAL_IPHONE_RUNBOOK.md` und `docs/TESTFLIGHT_RUNBOOK.md` repo-wahr auf aktuellen Core-Scope (`Live`, `Upload`, `Insights`, `Days`, Heatmap), offene Apple-Verifikation und entschaerftes Privacy-/Review-Wording geglaettet

## 2026-03-30

### Branch Consolidation / Doc Truth Sync

- `ROADMAP.md` und `NEXT_STEPS.md` auf den konsolidierten `main`-Stand gezogen; veraltete Aussagen zu fehlender Heatmap-Testabdeckung und offenen Linux-Failures entfernt
- Wrapper-Doku trennt jetzt sauber zwischen dem aktuellen Core-Linux-Check (`swift test`: `217` Tests, `2` Skips, `0` Failures) und den historischen Apple-CLI-/Device-Nachweisen vom 2026-03-30

### Apple Device Verification Batch 1

- `docs/LOCAL_IPHONE_RUNBOOK.md`, `NEXT_STEPS.md`: echter iPhone-15-Pro-Max-Lauf repo-wahr nachgezogen
- `xcodebuild test -allowProvisioningUpdates -scheme LH2GPXWrapper -destination 'id=00008130-00163D0A0461401C' -only-testing:LH2GPXWrapperUITests` lief gegen das verbundene reale Geraet
- `LH2GPXWrapperUITestsLaunchTests.testLaunch` lief real auf dem Device erfolgreich durch
- `LH2GPXWrapperUITests.testAppStoreScreenshots` scheiterte an einem echten Produktzustand statt an Infrastructure: beim Start war bereits `Imported file: location-history.zip` aktiv, daher erschien der erwartete `Demo Data`-Button nicht
- Accessibility-Snapshot aus dem Device-Lauf zeigt sichtbare `Heatmap`-Aktion, sichtbaren dedizierten `Live`-Tab und beobachtbaren Wrapper-Auto-Restore
- Background-Recording, aktives Heatmap-Oeffnen, aktiver `Live`-Flow und End-to-End-Upload bleiben offen

### Apple Stabilization Batch 1

- `LH2GPXWrapper.xcodeproj/project.pbxproj`: SPM-Pfad von `../../../Code/LocationHistory2GPX-iOS` auf `../LocationHistory2GPX-iOS` korrigiert – falscher Pfad verhinderte Package-Resolution und jeden lokalen Build auf diesem Mac
- `docs/TESTFLIGHT_RUNBOOK.md`: Privacy-Text korrigiert – "Alle Daten verbleiben lokal" durch sachlich korrekte Aussage ersetzt: lokales Standardverhalten, optionaler nutzergesteuerter Server-Upload standardmaessig deaktiviert
- `README.md`: Privacy-Manifest-Beschreibung korrigiert – "keine Datenerhebung" entfernt, optionaler Upload nuechterner beschrieben; Review-Guidelines-Stand auf "offen/teilweise" gesetzt statt "konform"
- README, ROADMAP, NEXT_STEPS und Runbooks nach erneutem Apple-CLI-Rerun nachgeschaerft – korrekter lokaler SPM-Pfad dokumentiert, Wrapper-Simulator-Tests als gruen eingetragen und die 2 verbleibenden roten macOS-/SwiftPM-Tests explizit offengelassen

### Audit Fix / Truth Sync
- README, ROADMAP, NEXT_STEPS und Runbooks auf den aktuellen Wrapper-Repo-Truth fuer Auto-Restore, optionales Networking und ehrlichen Verifikationsstatus synchronisiert
- Review-/Privacy-Wording fuer den optionalen Server-Upload nuechterner formuliert

## 2026-03-20

### Import / Restore Flow
- `ContentView` nutzt den asynchronen Datei-Ladepfad
- `restoreBookmarkedFile()` wird beim App-Start wieder aufgerufen; der Wrapper-Auto-Restore ist damit reaktiviert

### Core Export Capabilities Surfaced In Wrapper
- die ueber das Core-Package eingebundene Export-UI schaltet jetzt `GeoJSON` als drittes aktives Exportformat frei
- Export bietet jetzt `Tracks`, `Waypoints` und `Both` als Moduswahl
- lokale Exportfilter im Wrapper decken jetzt auch Bounding Box und Polygon fuer importierte History ab

### Core Language / Upload Capabilities Surfaced In Wrapper
- die ueber das Core-Package eingebundene Optionen-Seite bietet jetzt Deutsch/Englisch als Sprachwahl
- der Wrapper uebernimmt jetzt die partielle deutsche Shell-/Optionen-/Live-Recording-Abdeckung aus dem Core-Repo
- akzeptierte Live-Recording-Punkte koennen jetzt optional an einen frei konfigurierbaren HTTP(S)-Endpunkt mit optionalem Bearer-Token gesendet werden
- der Standard-Testendpunkt ist mit `https://178-104-51-78.sslip.io/live-location` vorbelegt und damit konsistent zur HTTPS-Validierung des Core-Codes

### Background Recording Wrapper Support
- Wrapper-Build-Einstellungen enthalten jetzt zusaetzlich `NSLocationAlwaysAndWhenInUseUsageDescription`
- `UIBackgroundModes` aktiviert `location`, damit die optionale Background-Live-Recording-Unterstuetzung aus dem Core-Repo auf iOS sauber deklariert ist
- Device-Verifikation fuer den erweiterten Permission-Flow bleibt separat offen

## 2026-03-19

### Local Options Wrapper Integration
- Wrapper-ContentView exposes the shared `AppOptionsView` from the core package via the `Actions` menu
- shared `AppPreferences` are injected so start-tab, distance-unit, map-style and technical-details settings take effect in the wrapper too
- README updated to document the new local options surface

## 2026-03-18

### Live Recording Wrapper Integration
- iOS-Wrapper auf die neue Live-Recording-Domain aus dem Core-Repo verdrahtet
- `NSLocationWhenInUseUsageDescription` fuer foreground-only Live-Location hinzugefuegt
- README und Runbooks auf direkten Google-Takeout-Import, getrennte Live-Track-Persistenz und deaktiviertes Auto-Resume korrigiert
