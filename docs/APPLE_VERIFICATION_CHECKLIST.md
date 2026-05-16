# Apple Verification Checklist

## Aktualisierung 2026-05-16 (Xcode Cloud Build 175 extern verifiziert, Branch `main`)

**Extern belegt (Screenshots 2026-05-16):** Workflow `Release – Archive & TestFlight` Build **175** erfolgreich, letzter Commit `2bfc009` (`docs: g1 mapkit ios 17 migration is already complete`). Schritte: `Archive - iOS` ✅, `TestFlight-interne Tests - iOS` ✅. Toolchain Cloud-Run: **Xcode 26.5 (17F42)**, **macOS Tahoe 26.4 (25E246)**. TestFlight zeigt `LH2GPX 1.0.2 (175)`. App-Info: „Erfordert iOS 17.0 oder neuer".

Damit sind extern enthalten:
- **`ff963c1`** — iOS-17-onChange-Deprecation-Fix (24 Stellen).
- **`2bfc009`** — G1-Befund: MapKit-iOS-17-API-Migration bereits abgeschlossen (`coordinateRegion:` / `annotationItems:` repo-weit 0 Treffer).
- **`92dc447`** — iOS-17-Minimum-Anhebung (Train F).

**Repo-Truth lokal unverändert:** `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171`. Build-Nummer `175` kommt aus `CI_BUILD_NUMBER`.

**Nicht behauptet in diesem Train:** keine App-Review-Submission, kein App-Review-Accept, kein Hardware-Smoke unter Build 175, keine Dynamic-Island-Sichtprüfung, kein iPad-Layout-Test, keine 46-MiB-Retest. Sektion 4 (ASC / TestFlight / Apple Review) bleibt **OFFEN**.

---

## Aktualisierung 2026-05-16 (Xcode Cloud Build 174 + iOS-17-Deprecation-Fix, Branch `main`)

**Extern belegt (Screenshots):** Workflow `Release – Archive & TestFlight` Build **174** erfolgreich, letzter Commit `92dc447`. TestFlight zeigt `LH2GPX 1.0.2 (174)`, 90 Tage. App-Info: „Erfordert iOS 17.0 oder neuer" — Train-F-Anhebung damit extern bestätigt.

**Behoben in `fix: update ios 17 onchange usage and document build 174`:** iOS-17-Deprecation-Warnung `'onChange(of:perform:)' was deprecated in iOS 17.0` aus `wrapper/LH2GPXWrapper/ContentView.swift:125` und repo-weit 23 weitere single-arg `.onChange(of:)`-Stellen auf Zwei-Parameter-Form migriert. Semantik exakt erhalten. Linux `swift test` 1459/2/0.

**Repo-Truth lokal unverändert:** `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171`. Build 174 stammt aus Xcode-Cloud-Zählung (`CI_BUILD_NUMBER`).

**Nicht behauptet in diesem Train:** keine App-Review-Submission, kein App-Review-Accept, kein Hardware-Retest auf iPhone 14 Pro / iPhone 16 Pro Max / iPad, keine Dynamic-Island-Sichtprüfung, keine 46-MiB-Retest. Sektion 4 (ASC / TestFlight / Apple Review) bleibt **OFFEN**.

---

## Aktualisierung 2026-05-13 (Release-Train-Bump 1.0.2 Build 171, Branch `main`)

**ASC schließt 1.0.1 für neue Builds (90186 + 90062).** Bump `MARKETING_VERSION` 1.0.1 → **1.0.2** in 8 pbxproj-Configs, `CFBundleShortVersionString` literal **1.0.2** in App+Widget Info.plist; `CURRENT_PROJECT_VERSION` 168 → **171** in 8 Configs, `CFBundleVersion` **171** in App+Widget Info.plist. Bundle-ID `de.roeber.LH2GPXWrapper` unverändert. `swift build` + `swift test` (1524 / 2 skipped / 0 failures, 195,2 s) + Sim iPhone 17 Pro Max iOS 26.0 Build + Device iPhone 15 Pro Max iOS 26.4 Build alle SUCCEEDED. `xcodebuild archive -configuration Release` **ARCHIVE SUCCEEDED** → `/tmp/lh2gpx-release/LH2GPXWrapper-build171.xcarchive` (91 MB). PlistBuddy-Verifikation: `CFBundleShortVersionString=1.0.2`, `CFBundleVersion=171`, `CFBundleIdentifier=de.roeber.LH2GPXWrapper`. Device-UITests nicht erneut gefahren (nur Versionsstrings); Basis `0739d4c` valide. **Upload noch nicht durchgeführt** — manuelle Submit-Schritte via Organizer dokumentiert. Kein UI-/Feature-Bump, keine Privacy-/Network-Änderung.

---

## Aktualisierung 2026-05-13 (Hardware-Sichtprüfungs-Gate UI-Polish Train 1+2, Branch `chore/uiux-modernization-train-2`)

**Hardware-Verifikation auf iPhone 15 Pro Max iOS 26.4** (`devicectl`-ID `6E4A2D38-F3C8-5CE3-9483-82A5D167BBF0`, Xcode-Build-ID `00008130-00163D0A0461401C`). **Device-Build SUCCEEDED** mit `xcodebuild -allowProvisioningUpdates` (Codesign + Provisioning Profile + Widget-Validation grün); App via `devicectl device install app` installiert (`/private/var/containers/Bundle/Application/C2113CDE-…/LH2GPXWrapper.app`) und via `devicectl device process launch` gelauncht. `swift build` SUCCEEDED, `swift test` **1524 / 2 skipped / 0 failures** in 163,2 s. Sim iPhone 17 Pro Max iOS 26.0 BUILD SUCCEEDED (vorher). **Device-UITests in diesem Gate nicht erneut gefahren** — keine Logik-/Native-API-Änderung seit Basis `0739d4c` (8 + 4× LaunchTest + `testLargeImportSyntheticFile` grün); diese Basis bleibt valide. **Pixel-Sicht-Restrisiken**: Accessibility XL/XXL/XXXL Hardware-Toggles und Landscape-Rotation sind **nicht** remote via `devicectl` ansteuerbar (Apple bietet keine entsprechende Schnittstelle, anders als Simulator `simctl ui`). Finale Pixel-Sicht obliegt dem User auf Gerät: Export-Tab + Insights-Tab bei `Einstellungen → Accessibility → Display & Text Size → Larger Text → XL/XXL/XXXL`, sowie Map-/Heatmap-Landscape-Smoke. **Keine Code-Änderung in diesem Commit; reine Doku-Synchronisation des Hardware-Gates.** Buildnummer/Marketing-Version unverändert. Train 1+2 wurden bereits per FF nach `main` gemerged (`47f2bc0`).

---

## Aktualisierung 2026-05-13 (UI-Polish-Verifikations-Gate Train 1+2, Branch `chore/uiux-modernization-train-2`)

**Visuelles Verifikations-Gate für nicht-releasegebundene UI-Polish-Trains (Train 1 HEAD `a076374`, Train 2 HEAD `9ea5984`).** Buildnummer/Marketing-Version unverändert. Kein ASC-Submit, kein Merge nach `main`. `swift build` BUILD SUCCEEDED, `swift test` **1524 / 2 skipped / 0 failures** in 162,3 s, `xcodebuild build` Sim iPhone 17 Pro Max (iOS 26.0) BUILD SUCCEEDED. Simulator gebootet, App-Launch + Screenshots Light/Dark/Dyn-Type-AXL/Landscape lokal als Evidenz (nicht committed). **Sichtprüfungs-Matrix:** Heatmap-Overlay-Padding, Spinner-Tint, Day-Detail-Section-Header, Day-List-Swipe-Tint, Export-Selection-Banner, Export modePill, Export-Microcopy KMZ/GeoJSON, Insights-Period-Comparison — alle Code-Pfade verifiziert; ✅ für direkt sichtbare Stellen, ⚠️ Code-Analyse für Kombinationszustände ohne separat erfassten Pixel-Screenshot. **Keine Layoutfehler gefunden, keine Code-Änderung.** Restrisiken: manuelle Accessibility-XL/XXL/XXXL-Sicht auf Hardware (Export-Tab, Insights-Tab) sowie Landscape-Smoke iPhone 15 Pro Max für Map-/Heatmap-Overlay vor Merge nach `main` empfohlen. iPhone 15 Pro Max angeschlossen, Device-UITest nicht erneut gefahren — Basis `0739d4c` valide.

---

## Aktualisierung 2026-05-13 (Release-Candidate Build 168)

**Build-Identität auf Build-Nummer 168 gehoben** (`CURRENT_PROJECT_VERSION` 100 → 168 in 8 Configs + `CFBundleVersion` 168 in beiden Info.plists, `MARKETING_VERSION` `1.0.1` unverändert). `xcodebuild archive -configuration Release -destination 'generic/platform=iOS'` **ARCHIVE SUCCEEDED** mit `ApplicationProperties: CFBundleVersion=168, CFBundleShortVersionString=1.0.1, CFBundleIdentifier=de.roeber.LH2GPXWrapper, Team=XAGR3K7XDJ, Architectures=[arm64]`. `swift test` 1524/2/0 (250 s); `xcodebuild build` Sim iPhone 17 Pro Max iOS 26.3.1 + Device iPhone 15 Pro Max iOS 26.4 BUILD SUCCEEDED. Device-UITests in diesem Train nicht erneut gefahren (nur Build-Nummern-Metadaten geändert); letzte grüne Verifikation auf HEAD `0739d4c` (8 + 4× LaunchTest + `testLargeImportSyntheticFile` 126,27 s, TEST SUCCEEDED).

---

## Aktualisierung 2026-05-13 (Audit-Gate-Closure, 46-MiB-Hardware-Retest jetzt autonom)

**Closure-Train 2026-05-13:** Neuer UI-Testing-only Launch-Arg `LH2GPX_UI_LARGE_IMPORT_BYTES=<bytes>` (gated hinter `LH2GPX_UI_TESTING`) lässt die App ein synthetisches Google-Timeline-style JSON in `NSTemporaryDirectory` generieren und über den Production-Import-Pfad importieren. Neuer XCUITest `testLargeImportSyntheticFile` (`wrapper/LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift`) feuert mit 46 × 1024 × 1024 Bytes. **Sektion 1 (46-MiB-Hardware-Retest) ist damit autonom abgehakt** — kein Tester-Handoff mehr erforderlich für die *Klasse* dieser Last (Streaming-/Parser-/Loader-Pipeline).

**Re-Verifikation 2026-05-13:** `xcodebuild test -only-testing:LH2GPXWrapperUITests` auf iPhone 15 Pro Max (UDID `00008130-00163D0A0461401C`, iOS 26.4): **TEST SUCCEEDED**, **9 UI-Tests + 4× LaunchTest passed in 1299,77 s**. `testLargeImportSyntheticFile` passed in **126,27 s** — kein Crash, kein Hang, kein Jetsam, App nach Import bedienbar (Tab-Switch `Days` erfolgreich). `swift test` (Host): 1524 Tests, 2 Skips, 0 Failures (156,98 s, +3 ggü. 1521). `xcodebuild build` für Sim iPhone 17 Pro Max iOS 26.3.1 + Device iPhone 15 Pro Max iOS 26.4: **BUILD SUCCEEDED**.

**Hinweis zur Genauigkeit:** Das synthetische Asset besteht aus visit-only Google-Timeline-Entries (kein `timelinePath` mit Geometrie). Damit ist die **Klasse** der 46-MiB-Streaming-Last verifiziert; eine konkrete Tester-Datei mit anderer Struktur (z. B. timelinePath-heavy) könnte theoretisch noch separat fehlschlagen. Der ursprüngliche Crashfall (2026-05-07) ist auf aktuellem HEAD allerdings durch die seither gelandeten Mitigations (autoreleasepool im Streaming-Reader, flatCoordinates-Kanonisierung, ImportMemoryProbe, BoundedLRU-Caches, SQLite-PRAGMAs) und jetzt durch den Hardware-Test bei 46 MiB Volumen praktisch unwahrscheinlich.

---

## Aktualisierung 2026-05-13 (Hardware-Acceptance 8/8 auf HEAD `aa145b4` verifiziert; vorher 7/8 am 2026-05-12 vor Heatmap-Hit-Target-Fix `f111afd`)

**Re-Verifikation 2026-05-13:** `xcodebuild test -only-testing:LH2GPXWrapperUITests` auf iPhone 15 Pro Max (UDID `00008130-00163D0A0461401C`, iOS 26.4) gegen HEAD `aa145b4`: **TEST SUCCEEDED**, 8 UI-Tests + 4× LaunchTest passed in 379,52 s. Heatmap-Button-Hit-Target-Fix in `f111afd` ist auf Device wirksam. `swift test` (Host): 1521 Tests, 4 Skips, 0 Failures (177,02 s). 46-MiB-Hardware-Retest: Host-Ersatzprüfung mit echter 44,5-MiB-Google-Timeline-JSON-Datei (`Tests/.../AppContentLoaderTests.testRealLocationHistoryJsonOnDesktop` + `…OnDesktop`) **passed** in 20,5 s / 21,7 s; interaktiver Device-Import nicht automatisierbar, Tester-Handoff bleibt offen.

---

## Aktualisierung 2026-05-12 (Heatmap-Hit-Target-Fix + Hardware-Acceptance-Train 8/8 auf HEAD pending)

**Gerät:** iPhone 15 Pro Max (UDID `00008130-00163D0A0461401C`, iOS 26.4). **Xcode:** 26.3 (17C529). **Build-Identität:** unverändert (MARKETING_VERSION `1.0.1`, CURRENT_PROJECT_VERSION `100`). Signed Debug-Build via `xcodebuild -allowProvisioningUpdates` BUILD SUCCEEDED.

**Code-Fix:** `Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift:857–863` — der Heatmap-Button im `overviewRangeCard` bekommt jetzt `.frame(minHeight: 44)`, `.contentShape(Rectangle())` und `.accessibilityIdentifier("overview.range.heatmap.button")`. Vorher 13.3 pt hoch (HIG-Verletzung) und nur per Label-Predicate auffindbar; in der Phase-10-Hero-Map-Workspace-Variante war er außerhalb des XCUITest-`revealElement`-6-Swipe-Budgets nicht mehr hittable.

**UITest-Fix:** `wrapper/LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift` — `testDeviceSmokeNavigationAndActions` löst den Heatmap-Button jetzt zuerst per stabilem Identifier auf (Fallback auf Label-Predicate); statt `revealElement` (Swipe auf `firstMatch`-ScrollView, der je nach Hero-Layout der falsche sein kann) ruft der Test ein neues `scrollUntilHittable(_:in:maxIterations:)` auf, das per `coordinate(withNormalizedOffset:).press(forDuration:thenDragTo:)` window-level vom unteren ins obere Drittel zieht — größerer Drag pro Iteration, bis zu 12 Iterationen, mit Overshoot-Recovery.

**Build-/Test-Baseline (Post-Fix):**
- `swift build` OK.
- `swift test` (Mac): **1518 / 4 skipped / 0 failures** (116.5 s; unverändert).
- `xcodebuild -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` BUILD SUCCEEDED.
- `xcodebuild -destination 'id=…401C' build -allowProvisioningUpdates` BUILD SUCCEEDED.

**Hardware-UITest-Suite iPhone 15 Pro Max — alle 8 grün:**
| Test | Ergebnis | Dauer |
|---|---|---|
| `testAppStoreScreenshots` | ✅ PASSED | 43.4 s |
| `testDeviceSmokeNavigationAndActions` | ✅ PASSED | 75.8 s |
| `testLandscapeLayoutSmoke` | ✅ PASSED | 597.4 s (langsamer Run wegen paralleler xcodebuild-Generic-Konkurrenz auf DerivedData, Test selbst grün) |
| `testLiveActivityHardwareCaptureDistance` | ✅ PASSED | 38.8 s |
| `testLiveActivityHardwareCaptureDuration` | ✅ PASSED | 37.6 s |
| `testLiveActivityHardwareCapturePoints` | ✅ PASSED | 38.0 s |
| `testLiveActivityHardwareCaptureUploadStatusPendingAndRestart` | ✅ PASSED | 63.3 s |
| `testLiveActivityHardwareCaptureUploadStatusFailed` | ✅ PASSED | 37.7 s |

P0-3 (Heatmap-Button-Regression aus dem vorherigen Train) ist damit **geschlossen**.

**Manual-Risk-Sektionen-Stand nach diesem Train (unverändert offen):**
- **Sektion 1 (46-MB-Crashfall):** **bleibt FAILED.** Im lokalen Filesystem ist jetzt `/Users/sebastian/Desktop/Google_Maps/12_05_2026_location-history.json` mit **46 657 867 Bytes (~44.5 MiB)** verfügbar — größenmäßig im Crashfall-Bereich. **Der eigentliche Import auf dem iPhone erfordert eine manuelle UI-Interaktion (File Picker → Akzeptieren des Imports), die nicht autonom über `xcodebuild test` triggerbar ist.** Der Hardware-Retest auf dem Release-Build ist deshalb für den Tester-Handoff vorbereitet, aber **in diesem Train nicht durchgeführt**.
- **Sektion 2 (Live Activity / Dynamic Island / Lock Screen):** weiterhin technischer Pass über die UITest-Capture-Suite (alle 5 grün); **manuelle visuelle Lock-Screen-Sichtprüfung außerhalb der UITests bleibt offen**. Sektion-2-Checkboxen nicht abgehakt.
- **Sektion 3 (iPad-Layout):** **bleibt offen** (iPad weiterhin offline).
- **Sektion 4 (ASC / TestFlight / Apple Review):** **bleibt offen** (extern, lokal nicht belegbar).

## Aktualisierung 2026-05-12 (Hardware-Acceptance-Train auf HEAD `5f83838`)

**Gerät:** iPhone 15 Pro Max (UDID `00008130-00163D0A0461401C`, iOS 26.4). **Xcode:** 26.3 (17C529). **Build-Identität:** MARKETING_VERSION `1.0.1`, CURRENT_PROJECT_VERSION `100`. Signed Debug-Build via `xcodebuild -allowProvisioningUpdates` mit Cert `8D7D…AEAE` und Provisioning Profile `iOS Team Provisioning Profile: de.roeber.LH2GPXWrapper`.

**Build-/Test-Baseline:**
- `swift build` OK.
- `swift test` (Mac): **1518 / 4 skipped / 0 failures** (118.7 s).
- `xcodebuild -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**.
- `xcodebuild -destination 'id=…401C' build -allowProvisioningUpdates` **BUILD SUCCEEDED** (signed Debug).

**Hardware-UITest-Suite iPhone 15 Pro Max:**
| Test | Ergebnis | Dauer |
|---|---|---|
| `testAppStoreScreenshots` | ✅ PASSED | 44.1 s |
| `testDeviceSmokeNavigationAndActions` | ❌ **FAILED** | 29.2 s |
| `testLandscapeLayoutSmoke` | ✅ PASSED | 58.4 s |
| `testLiveActivityHardwareCaptureDistance` | ✅ PASSED | 37.7 s |
| `testLiveActivityHardwareCaptureDuration` | ✅ PASSED | 37.2 s |
| `testLiveActivityHardwareCapturePoints` | ✅ PASSED | 37.4 s |
| `testLiveActivityHardwareCaptureUploadStatusPendingAndRestart` | ✅ PASSED | 64.4 s |
| `testLiveActivityHardwareCaptureUploadStatusFailed` | ✅ PASSED | 38.2 s |

**Regression (P1)**: `testDeviceSmokeNavigationAndActions` schlägt auf HEAD `5f83838` an Zeile `wrapper/LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift:203` mit `XCTAssertTrue(revealElement(heatmapButton, in: app))` fehl — der Heatmap-Button in der Overview ist während des UITests nicht erreichbar/sichtbar geworden. War am 2026-05-07 (HEAD `b91a933`) noch grün. In diesem Train **nicht** gefixt (Scope ist reine Hardware-Acceptance, kein Refactor). Manual-Risk-Sektion 1 (46 MB) und Sektion 4 (ASC) bleiben unberührt; Sektion 2 (Live Activity) bekommt die fünf neuen Capture-Tests als technischen Pass-Beleg.

**Manual-Risk-Sektionen-Stand nach diesem Train:**
- **Sektion 1 — 46-MB-Crashfall:** **bleibt FAILED**. Im System wurde keine 46-MB-`location-history.zip` gefunden (einzige `location-history.zip` unter `/Users/sebastian/Downloads/` ist nur 4.06 MB groß und triggert das Jetsam-Symptom nicht). Hardware-Retest des Release-Builds mit dem originalen 46-MB-Crash-Sample konnte deshalb nicht gefahren werden.
- **Sektion 2 — Live Activity / Dynamic Island / Lock Screen:** alle fünf `testLiveActivityHardwareCapture*`-UITests sind auf der echten Hardware grün durchgelaufen. Die Tests laufen das Recording-Start/Stop, Dynamic-Island-Expand-Flow und Upload-Status-Restart-/Failed-Flow durch und schießen Screenshots des Lock-Screen-Banners; das ist technischer Pass für die Capture-Pfade. Eine **manuelle visuelle Inspektion** des Lock-Screen-Live-Activity-Banners außerhalb der UITests ist **nicht** durchgeführt. Sektion 2 Checkboxen bleiben deshalb leer — der UITest-Pass ist die ehrliche Stand-Aussage, aber kein menschlicher Sichtnachweis.
- **Sektion 3 — iPad-Layout:** **OFFEN**. iPad (UDID `3c955848…d4da0a5`, iPadOS 17.7.10) ist offline laut `xcrun xctrace list devices`; iPad-Build und Hardware-Acceptance nicht gefahren.
- **Sektion 4 — ASC / TestFlight / Apple Review:** **OFFEN**. Keine ASC-Verifikation in diesem Train.

## Aktualisierung 2026-05-09 (L-04 — Bounded LRU für AppSessionContent-Caches)

**Code-Stand:** `AppSessionContent` (in `AppSessionState.swift`) hält fünf bisher unbounded Filter-/Projection-Caches; ab dem L-04-Commit sind alle durch `BoundedLRU<K,V>` (Foundation-only, neue Datei `Sources/LocationHistoryConsumerAppSupport/BoundedLRU.swift`) capped: `filteredOverviewCache`/`filteredDaySummariesCache`/`filteredInsightsCache` je 8, `dayDetailCache` 32, `dayMapDataCache` 16. `projectedDaysCache` (8) nutzt dieselbe Abstraktion. Semantik unverändert. **Hardware-Aussage unverändert.**

## Aktualisierung 2026-05-09 (L-01 — In-Memory-Import-Gate)

**Code-Stand:** Legacy-Loader hat ab dem L-01-Commit ein In-Memory-Cap (`AppContentLoader.maximumInMemoryImportBytes` = 64 MiB) vor `Data(contentsOf:)`. LH2GPX-JSON, GPX, TCX und unbekannte JSON > 64 MiB werfen `AppContentLoaderError.importTooLargeForInMemoryLoad(filename:bytes:limit:)` statt blind Full-Read. Google-Timeline-JSON läuft weiter durch den Streaming-Pfad. **Hardware-Aussage unverändert.**

## Aktualisierung 2026-05-09 (Deep Audit Performance/Stabilität/Map-Layer)

**46-MB-Gate-Status:** FAILED / pending hardware retest. (verbatim erhalten — keine Statusänderung in diesem Audit)
**Store-Pfad-Status:** pre-production / feature-flagged / default OFF.
**Build 164:** Xcode Cloud grün; Hardware-Pass nicht dokumentiert.

Audit-Bericht: `docs/DEEP_AUDIT_2026-05-09_PERFORMANCE_STABILITY_MAP_LAYERS.md`. Vor dem nächsten Hardware-Run müssen die Toggles im Technical Screen aktiviert sein:
- Local Timeline Store Test Mode = ON
- Import Memory Logging = ON
- Memory Logging Resolved = enabled

## Manual Release Risk Acceptance Protocol — HEAD `b91a933`

### Übersicht

Dieser Block bündelt die vier nicht automatisierbaren Restrisiken, die vor einer App-Store-Submission **manuell durch einen Tester auf echter Hardware bzw. im Apple-Portal** abgenommen werden müssen. Die automatisierte Verifikation auf HEAD `b91a933` ist bereits grün (`swift test` 1077/2/0; `testAppStoreScreenshots` / `testDeviceSmokeNavigationAndActions` / `testLandscapeLayoutSmoke` PASSED auf iPhone 15 Pro Max, iOS 26.4) — diese Checkliste deckt **nur** die Lücken ab, die `swift test` und UITests prinzipiell nicht abdecken können.

Die Checkboxen unten sind **bewusst leer**. Codex/Agent darf hier nichts vorab abhaken — es ist kein Test-Ergebnis. Solange ein Punkt nicht durch einen Tester abgehakt und mit Datum, Initialen, Build-Hash und Befund versehen ist, gilt er als „nicht verifiziert".

**Acceptance-Anker:** HEAD `b91a933` (main, gepusht).
**Aktive App-Version:** 1.0.1 (Build 100), Bundle `de.roeber.LH2GPXWrapper`, Team `XAGR3K7XDJ`.

Bei Ablehnung eines Punktes: konkreten Bug + Reproduktionsschritte unter „Befund" eintragen und im Verlauf vermerken, ob daraus ein Codefix-Auftrag an Codex/Agent abgeleitet werden muss.

---

### Sektion 1 — 46-MB-Crashfall (Großimport auf echtem iPhone)

**Status 2026-05-08 (dritter Hardware-Fail): FAILED → weiter erweiterter Code-Stand vorbereitet, Hardware-Retest steht aus**

**Update 2026-05-08 (Phase-10C Foundation+Legacy Hardening):** Phase-10C Foundation+Legacy Hardening, **kein Apple-Action erforderlich**. Heatmap densityPointCap=500_000 + Truncation-Flag, ExportPreview Doppel-Iter entfernt, derived_cache Purge-API (`pruneDerivedCache(maxEntries:)` + `deleteDerivedCache(olderThan:)`), Build-Warnings (visionOS, unused `withUnsafeMutableBytes`) bereinigt; Overview `scanCandidates` bewusst nicht angefasst (P1, Risiko HOCH; bereits bounded). Store-Pfad bleibt default OFF. **46-MB-Gate-Status: FAILED / pending hardware retest** (verbatim erhalten). Kein Hardware-Pass, kein TestFlight-/Review-Claim aus diesem Commit.

**Update 2026-05-08 (Phase-10B Weg 3 — Foundation-only PointLayer/Budget):** Phase-10B Foundation-only Änderungen (zentraler `LocalTimelineMapPerformanceBudget` + `LocalTimelineMapPointLayerProvider` + Modelle), **kein Apple-Action erforderlich**. Store-Pfad bleibt feature-flagged / default OFF; in keinem View aktiv; Legacy-Pfad unverändert. **46-MB-Gate-Status: FAILED / pending hardware retest** (verbatim erhalten). Kein Hardware-Pass, kein TestFlight-/Review-Claim aus diesem Commit.

**Update 2026-05-08 (Phase-10A P1-A/B Weg 2):** Progress/Cancel-UI sichtbar verdrahtet in AppShell + Wrapper. Service-Layer + Presentation-Layer + SwiftUI-View Linux-getestet. **46-MB-Hardware-Gate bleibt FAILED / pending hardware retest** — auf iPhone 15 Pro Max nicht erneut validiert. Kein Hardware-Pass, kein TestFlight-/Review-Claim aus diesem Commit.

**Update 2026-05-08 (Phase-10A-Folge — P1-C + P1-D WAL-Checkpoint + Recovery-Test)**: Neue API `LocalTimelineStore.checkpointWAL(mode:)`/`truncateWAL()`/`bestEffortTruncateWAL()` über `sqlite3_wal_checkpoint_v2`; Wiring nach `LocalTimelineImportWriter.finalize`/`.cancel` und `LocalTimelineStoreLifecycle.deleteAllLocalTimelineData(store:)` (best-effort). Keine Schemaänderung. Recovery-Test (`LocalTimelineStoreRecoveryTests`) ist **Linux-Simulation, kein echter iOS-Jetsam-Test** (Power-Loss-/Kernel-Kill-Verhalten auf Hardware bleibt separate Verifikation). Greift im 46-MB-Pfad **nicht**, weil der LocalTimelineStore-Pfad **default AUS** bleibt und der 46-MB-ZIP-Test über die Legacy-Pipeline läuft. **Diese Sektion bleibt FAILED / pending hardware retest unverändert.** **Keine ASC/Review/TestFlight-/Hardware-Freigabe behauptet.**

**Update 2026-05-08 (Phase-10A-Folge — P1-A + P1-B Cancellable Import Progress)**: Service-/Presentation-Schicht für **kooperatives Cancel** und **throttled Progress** ist eingecheckt und Linux-getestet (`LocalTimelineImportProgress`, `LocalTimelineImportCancellation`, `LocalTimelineImportController`, `GoogleTimelineStoreImporter.Hooks`, `AppContentLoader`/`LH2GPXAppFlow` Pass-through). Ändert das Hardware-Verhalten der Legacy-AppExport-Pipeline **nicht** und greift im 46-MB-Pfad **nicht**, weil der LocalTimelineStore-Pfad **default AUS** bleibt und der 46-MB-ZIP-Test über die Legacy-Pipeline läuft. Ein potenzieller indirekter Nutzen für die Großimport-Strecke entsteht erst, wenn der Store-Pfad auf Hardware aktiviert ist und der Tester den Import abbricht — das ist keine 46-MB-Hardware-Aussage. **Diese Sektion bleibt FAILED / pending hardware retest unverändert.** **Keine ASC/Review/TestFlight-/Hardware-Freigabe behauptet.**

**Update 2026-05-08 (Build 157 Status + Build-158-Vorbereitung — interne Test-Toggles)**: **Build 157 ist Xcode Cloud grün und TestFlight-installierbar** (Status „Überprüft", interne Tests erfolgreich). Diese Sektion bleibt **FAILED / pending hardware retest unverändert** — Build 157 ist **kein** 46-MB-Hardware-Pass und **keine** Apple-Review-/Release-/Hardware-Freigabe. Build-158-Vorbereitung eingecheckt: zwei interne UserDefaults-Toggles in `AppTechnicalOptionsView` (Sektion "Internal Test Toggles"), persistiert über `LocalTimelineTechnicalTestSettings` mit Keys `LH2GPX.localTimelineStoreTestModeEnabled` und `LH2GPX.importMemoryLoggingEnabled` (Namespace `LH2GPX.…`, Default `false`, **nur Bool**, keine Standortdaten/Pfade/Tokens). Hintergrund: TestFlight-Tester können **keine Launch-Argumente / Environment-Variablen** setzen — die Toggles sind die TestFlight-Strecke, um den feature-flagged LocalTimelineStore-Pfad und das Import-Memory-Logging am Gerät zu aktivieren. `LocalTimelineFeatureFlags.resolve(arguments:environment:settings:)`/`resolveFromProcess(settings:)` und `ImportMemoryProbe.isEnabledForEnvironment(_:arguments:settings:)` akzeptieren das Setting **zusätzlich** — Args/ENV bleiben primärer Aktivator, das Setting aktiviert zusätzlich, **deaktiviert nichts**. `ImportMemoryProbe.isLoggingEnabled` ist jetzt computed (Cache + Lookup pro Aufruf) → Toggle wirkt **ohne Relaunch**. Status-Row "Memory Logging Resolved" zeigt am Gerät den effektiven OR-State. Footer-Hinweis: "Internal/TestFlight only · Pre-production · Default off · No location data is stored in these settings". 12 neue Linux-grüne Tests inkl. `testOnlyBoolsAreStoredUnderToggleKeys`. Store-Pfad bleibt **default AUS, pre-production / feature-flagged**. Live-Upload, Recording, Auth-Flows unberührt. **KEINE ASC/Review/Hardware-Freigabe**, **KEINE Map-Phase-10B-Aussage**, **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim).

**Update 2026-05-08 (Xcode Cloud Archive-Fail Build 155/156)**: Builds **155** (Commit `06f81ae`) und **156** (Commit `5cb7783`) im Workflow „Release – Archive & TestFlight" sind mit **Exit Code 65** fehlgeschlagen. Root Cause: Namens-Kollision zweier top-level `GridKey`-Definitionen im Modul `LocationHistoryConsumerAppSupport` — `Sources/LocationHistoryConsumerAppSupport/HeatmapGridBuilder.swift` (top-level `struct GridKey { let lat: Int32; let lon: Int32 }` hinter `#if canImport(MapKit) && canImport(SwiftUI)`-Guard, auf Linux ausgeschlossen, auf Apple-Plattformen aktiv) und `Sources/LocationHistoryConsumerAppSupport/LocalTimelineHeatmapGridAggregator.swift` (top-level `private struct GridKey { let lat: Int; let lon: Int }`). Auf Apple-Plattformen sichtbar: „Invalid redeclaration of 'GridKey'" + „ambiguous for type lookup" + Folgefehler „Cannot convert value of type 'Int' to expected argument type 'Int32'" auf Zeile 79 des Aggregators (Compiler löste den Namen auf die `Int32`-Variante auf). Auf Linux blieb der SwiftPM-Build grün, weil der MapKit-Guard die HeatmapGridBuilder-Variante ausschließt. Fix: `LocalTimelineHeatmapGridAggregator.swift` benennt `GridKey` → `LocalTimelineHeatmapGridKey` (privat, file-scope). Heatmap-Logik unverändert, keine API-/UI-Änderung. `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj` referenziert die SPM-Package-Datei nicht direkt; **keine doppelten Compile-File-Referenzen** gefunden — die Kollision war rein semantisch zwischen zwei Top-Level-Swift-Definitionen im selben Modul. **Xcode Cloud Retest des Workflows „Release – Archive & TestFlight" muss erneut ausgelöst werden — Status: PENDING.** Keine Aussage über echte Apple-Builds, bis ein neuer Xcode-Cloud-Lauf grün abschließt. **Diese Sektion bleibt FAILED / pending hardware retest unverändert** — der Compile-Fix berührt das Hardware-Verhalten der Legacy-AppExport-Pipeline nicht und ist keine Aussage über die 46-MB-Symptomatik.

**Update 2026-05-08 (Linux-Stabilisierung HEAD `37a22b7` nach `34bc369`)**: Linux-SwiftPM-Bruch ist behoben (Heatmap-Preference-Enums extrahiert in `HeatmapPreferenceEnums.swift`; OptionsPresentation-Hoisting; URL/autoreleasepool/Foundation-Guards). Linux-`swift test` ist mit 1034/2/0 grün, erwarteter Mac-Stand ~1133. **Die Linux-Stabilisierung ändert iOS-Verhalten nicht und ist keine Aussage über die 46-MB-Hardware-Symptomatik.** Diese Sektion bleibt **FAILED** bis Hardware-Retest auf iPhone 15 Pro Max grün — Mac/iPhone-Handoff, auf Linux-Server nicht durchführbar.

**Phase-Zeile 2026-05-08 (Phase 10A — Store-DayMap UI Surface feature-flagged, kein MapKit-Import)**: LocalTimelineStore Phase 1..10A abgeschlossen. Phase 10A ergänzt eine feature-flagged Store-**DayMap-UI-Surface** in der bestehenden `LocalTimelineDayDetailView`: Foundation-only `LocalTimelineDayMapViewState` Presentation Model (harte `Budget`-Grenzen, default 12 Routen / 256 Punkte pro Route / 4096 Punkte total) plus SwiftUI `LocalTimelineDayMapView` Placeholder (`#if canImport(SwiftUI)`-guarded; **KEIN MapKit-Import**); echte `MKMapView`-/`MKMultiPolyline`-Verdrahtung bleibt explizit **Phase-10B Mac/Xcode-Pflicht**. `LH2GPXAppFlow.makeProductionDayMapSource(for:)`; Wrapper- und Package-AppShell-ContentViews reichen die neue Source ans Landing-View durch. **Store-Pfad bleibt default AUS** (`LH2GPX_LOCAL_TIMELINE_STORE`). **KEIN Heatmap/Overview/Export-UI-Hook**; **KEIN eager `coord_blob`-Decoding beim Candidate-Load**; **KEINE Darwin FileProtection-Aktivierung**; **KEINE Hardware-/AppStore-/TestFlight-/ASC-Aussage**; **KEINE vollständige sichtbare Kartenmodernisierung**. **Diese Sektion bleibt FAILED / pending hardware retest** — die Phase-10A-UI ändert das Hardware-Verhalten der Legacy-AppExport-Pipeline nicht. Phase 9A/9B (Wrapper/AppFlow-Wiring + Settings-Delete-Button + Landing-View + DayList/DayDetail UI) bleibt unverändert wirksam.

**Phase-Zeile 2026-05-08 (Phase 9B — Store-DayList/DayDetail UI feature-flagged aktiv)**: LocalTimelineStore Phase 1..9B abgeschlossen. Phase 9B ergänzt feature-flagged Store-**DayList + sheet-basierte DayDetail-UI** (`LocalTimelineDayListView`/`LocalTimelineDayDetailView`, beide `#if canImport(SwiftUI)`-guarded) über die bestehende `LocalTimelineSessionLandingView`; `AppSessionState.selectedLocalTimelineDayId` + `selectLocalTimelineDay(_:)`; `LH2GPXAppFlow.makeProductionDayBrowserSource(for:)`; Wrapper- und Package-AppShell-ContentViews reichen `makeProductionDayBrowserSource` + Selection-Binding durch. **Store-Pfad bleibt default AUS** (`LH2GPX_LOCAL_TIMELINE_STORE`). **KEIN Map/Heatmap/Overview UI-Hook**; **KEIN eager `coord_blob`-Decoding** in DayList/DayDetail; **KEINE Darwin FileProtection-Aktivierung**; **KEINE Hardware-/AppStore-/TestFlight-Aussage**. **Diese Sektion bleibt FAILED / pending hardware retest** — die Phase-9B-UI ändert das Hardware-Verhalten der Legacy-AppExport-Pipeline nicht. Phase 9A (Wrapper/AppFlow-Wiring + Settings-Delete-Button + Landing-View über Envelope-Pfad) bleibt unverändert wirksam.

**Dritter reproduzierter Hardware-Fail** am 2026-05-07T15:10:44+02:00 auf iPhone 15 Pro Max (`iPhone16,2`, iOS 26.4 / 23E246), Xcode 26.3, macOS 15.7 — **trotz** des erweiterten Memory-Trains nach `cd77f97` und HEAD `ae5de1f`:
- App: `LH2GPXWrapper` (Bundle `de.roeber.LH2GPXWrapper`).
- Datei: `~/Downloads/location-history.zip` (~46 MB; ~64.926 Top-Level-Timeline-Entries).
- Fehler: `IDEDebugSessionErrorDomain Code 11 — “The app ‘LH2GPXWrapper’ has been killed by the operating system because it is using too much memory.”`
- Operation duration: **95.156 ms** (vs. 216.606 ms zweiter Fail / 232.341 ms erster Fail). Die deutlich kürzere Op-Dauer signalisiert: der Peak liegt **früher** im Importpfad als bisher angenommen — wahrscheinlich tief im Streaming-/Konverter-Pfad oder beim Übergang Streaming → Session-Materialisierung.

Damit ist klar: die in HEAD `ae5de1f` adressierten Allokationspfade (Session-Init / Builder / Calculator) waren notwendig, aber nicht hinreichend. Der dritte Fail erzwingt einen weiter erweiterten Diagnostik-/Geometrie-Stand.

Code-Stand vorbereitet in HEAD `34bc369` (Memory-Train) und der nachgelagerten Linux-Stabilisierung `37a22b7` nach `ae5de1f` (kein verifizierter Erfolg, ausschließlich vorbereiteter Fix-Stand bis Hardware-Retest):
1. **Build-Identitäts-Logging auf App-Start**: `[LH2GPX_BUILD] app.start version=… build=… sha=… memoryLogging=enabled|disabled` wird **immer** ausgegeben (auch wenn die Probe deaktiviert ist) — damit ist zweifelsfrei loggebar, welcher Build wirklich gestartet wurde.
2. **`ImportMemoryProbe` verdichtet**: zusätzliche Probe-Punkte `import.fileSelected`, `zip.open.start`/`zip.open.end`, `zip.entry.sniff.start`/`zip.entry.sniff.end`, `zip.stream.chunk` jetzt **alle 8 Chunks** (statt 64), `stream.elements` alle 1000 Top-Level-Elemente, `stream.element.outlier` für Elemente > 64 KB, `stream.before/afterElementParse` (throttled alle 1000), `converter.ingest` alle 1000 Entries, `converter.dayMap.count` alle 5000, `converter.before/afterFinalize`, `loader.before/afterSessionContent`, `session.before/afterShowContent`, `app.didReceiveMemoryWarning` (iOS-only via `NotificationCenter`-Observer auf `UIApplication.didReceiveMemoryWarningNotification`).
3. **`ImportMemoryProbe` akzeptiert beide Aktivierungs-Quellen** — `ProcessInfo.environment` **und** `ProcessInfo.arguments`. Erkannt werden alle vier Schreibweisen: `LH2GPX_IMPORT_MEMORY_LOG=1`, `LH2GPX_IMPORT_MEMORY_LOG`, `-LH2GPX_IMPORT_MEMORY_LOG`, `--LH2GPX_IMPORT_MEMORY_LOG`. Neue testbare API `ImportMemoryProbe.isEnabledForEnvironment(_:arguments:)`.
4. **`AppBuildInfo.isMemoryLoggingEnabled: Bool`** ergänzt; Settings → Technical → „Build Info" zeigt jetzt eine zusätzliche Zeile **„Memory Logging: Enabled / Disabled"** (grün, wenn aktiv) — der Tester kann am Gerät verifizieren, ob die Probe für diesen Run scharf geschaltet ist, **bevor** er den Import startet.
5. **Geometrie-Refactor (P0 Fokus 1) — flatCoordinates-Kanonisierung**: Google-Timeline-Imports schreiben jetzt `flatCoordinates: [Double]` statt `points: [PathPoint]`, **ohne** ISO-Zeitstrings pro Punkt. Geschätzte Einsparung: **~80–120 MB resident** bei der 46-MB-ZIP. Alle Consumer (`PathDistanceCalculator`, `AppExportQueries`, `DayMapDataExtractor`, `ExportRouteSanitizer`, `AppHeatmapModel`, GPX/KML/GeoJSON/CSV-Builder) sind flat-aware gemacht; `AppHeatmapModel`-Doppelbug (Punkte wurden bei beiden Geometrien doppelt gezählt) ist gefixt. Code-Seite des P0 ist damit done; Hardware-Retest weiterhin offen.
6. **NEU `docs/MAP_ARCHITECTURE_AUDIT.md`**: Bestandsaufnahme aller Kartenflächen + Roadmap-Pfad zu UIKit `MKMapView`/`MKMultiPolyline` für Heavy Overview/Heatmap. **Nicht** umgesetzt in diesem Commit — reine Architektur-Doku/Roadmap.
7. **NEU `docs/LOCAL_TIMELINE_STORE_RESEARCH.md` (2026-05-08, HEAD-Anker `ebd8146`)**: geprüfte Designrichtung für eine on-disk Timeline-Persistenz (SQLite-C-API + `Int32`-microdegrees-BLOB, Application-Support-Speicherort, `completeUnlessOpen`, backup-excluded). **Wenn dieser 46-MB-Hardware-Retest FAILED bleibt, ist der nächste architektonische Schritt der LocalTimelineStore-P0-Fixpfad** — er geht dann *vor* Map-Modernisierung und weiterer UI-Politur. Bei PASSED wird das Projekt zu P1/P2 (Robustheits-/Skalierung). Stand 2026-05-08: **Phase 1..8B abgeschlossen, isoliert, nicht UI-aktiv** (CoordBlob + SQLite-Schema, disk-first ImportWriter + GoogleTimelineStoreImporter, store-backed Read-Surface mit bounded Reads, **Storage-Lifecycle vorbereitet**: Storage-Pfad-Resolver mit 4 Roots, Backup-Exclusion-Helper, FileProtection-Kapselung mit Ziel `completeUnlessOpen`, Open-Lifecycle-Factory, High-Level deleteAll über DB+WAL+SHM+RenderCache+ImportStaging+ExportStaging; store-backed Streaming Export; Phase 6 Feature-flagged AppSession-Quelle — `LocalTimelineFeatureFlags`, `LocalTimelineSession`, `LocalTimelineAppSessionAdapter`, `LocalTimelineDeletionService`; **Phase 7A** Feature-flagged AppContentLoader-Hook über Envelope-Kapsel `AppSessionContentSource` + `AppSessionState.show(localTimeline:)` — gated by feature flag, NIE default-aktiv, kein UI-Hook; **Phase 7B** Foundation-only Presentation/ViewState-Schicht — `LocalTimelineDayListViewState`, `LocalTimelineDayDetailViewStateAdapter`, `AppSessionPresentationSource` (`activeContent`/`isLocalTimelineActive`), `LocalTimelineDeletionPresentation` — plus Service-layer Envelope-Hook im AppFlow `LH2GPXAppFlow.loadImportedFileEnvelope(...)`; weiterhin kein Wrapper/SwiftUI-Wiring, kein Map/Heatmap/Overview/Export-UI-Hook, FileProtection-Status unverändert); 46-MB-Gate **unverändert FAILED / pending hardware retest**. **Offene Darwin-Pflicht**: tatsächliche FileProtection-Aktivierung (Hook in Phase 4 nur dokumentiert; Phasen 6/7A haben ihn nicht angefasst; Aktivierung muss in einem Darwin-Hardware-Pass erfolgen). Phase 7B (FileProtection-Aktivierung Darwin, `AppSessionContent`-Source-Enum-Verschmelzung statt Envelope, DayList/DayDetail/Map/Heatmap/Overview-Hooks, Adapter zu `flatCoordinates`-Konsumenten, derived_cache/RTree, App-Flow-Umschaltung, Settings-UI, Privacy-Doku) bleibt offen vor UI-Hook. Kein Datum versprochen. Cross-Reference: `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`.

**Empfohlene Tester-Sequenz beim Retest (Mac/iPhone-Handoff — auf Linux-Server nicht durchführbar)**:
1. **Build-Identitäts-Verifikation am Gerät**: App öffnen, **Settings → Technical → „Build Info"** prüfen — Marketing-Version, Build, optional Git-Commit-SHA und neu **„Memory Logging: Enabled / Disabled"** mit dem getesteten Git-HEAD vergleichen, **bevor** der Import gestartet wird. Wenn „Memory Logging: Disabled" steht, ist die Probe für diesen Run **nicht** aktiv und das nachfolgende Logging liefert nichts.
2. **Memory-Logging-Aktivierung** vor dem Run setzen — entweder als **Environment-Variable** `LH2GPX_IMPORT_MEMORY_LOG=1` (Run Scheme → Arguments → Environment Variables) **oder** als **Launch-Argument**. Die Probe akzeptiert alle vier Schreibweisen: `LH2GPX_IMPORT_MEMORY_LOG`, `-LH2GPX_IMPORT_MEMORY_LOG`, `--LH2GPX_IMPORT_MEMORY_LOG`, `LH2GPX_IMPORT_MEMORY_LOG=1`. Im „Build Info" muss daraufhin **„Memory Logging: Enabled"** in Grün stehen. **TestFlight-Strecke (Build 158-Vorbereitung, ab 2026-05-08)**: TestFlight-Tester können keine Args/ENV setzen — stattdessen in **Settings → Technical → "Internal Test Toggles"** den Toggle "Memory Logging" einschalten. Die Status-Row "Memory Logging Resolved" zeigt den effektiven OR-State (ProcessInfo OR Settings). Toggle wirkt **ohne Relaunch** (computed `isLoggingEnabled`). Args/ENV bleiben primärer Aktivator; das Setting aktiviert zusätzlich, deaktiviert nichts. Der zweite Toggle "Local Timeline Store Test Mode" aktiviert analog den feature-flagged LocalTimelineStore-Pfad zusätzlich zu `LH2GPX_LOCAL_TIMELINE_STORE`. Beide Toggles sind **interner Testmodus / Pre-production**, persistiert ausschließlich als Bool unter `LH2GPX.localTimelineStoreTestModeEnabled` / `LH2GPX.importMemoryLoggingEnabled`; **keine Standortdaten / keine Pfade / keine Tokens** in den Keys.
3. **Debug-Run**: Import durchführen, in der Xcode-Console alle Zeilen mit `[LH2GPX_BUILD]` (App-Start, einmal) und `[LH2GPX_MEMORY]` (Probe) loggen — wenn der Build erneut Jetsam-killt, beweist das letzte gelogde `[LH2GPX_MEMORY]`-Label die Peak-Phase. Bei `app.didReceiveMemoryWarning` greift iOS bereits, bevor Jetsam zuschlägt.
4. **Wenn Debug grün**: Release-Build **ohne Debugger / View-Debugging** auf demselben Gerät mit derselben 46-MB-`location-history.zip`. Erst dann gilt diese Sektion potenziell als PASSED — vorher nicht.

**Tester-Ergebnis-Template (zurückzumelden nach jedem Hardware-Retest)**:

```
Hardware-Retest 46-MB Google Timeline
- Git SHA (aus Settings → Technical → Build Info):
- Build Number (aus Settings → Technical → Build Info):
- iOS-Version + Geräte-Modell:
- Datei + ungefähre Größe:
- Run-Modus: Debug | Release
- Memory Logging Status (aus Build Info): Enabled | Disabled
- Importdauer (Sekunden, von Datei wählen bis Tagesliste sichtbar oder Crash):
- Ergebnis: PASSED (Tageliste/Insights/Export sichtbar, kein Crash)
           | FAILED Jetsam (Op-Duration in ms, falls aus Xcode-Log)
           | FAILED anderer Fehler (Stacktrace / UI-Symptom)
- Letzter `[LH2GPX_MEMORY]`-Log vor Crash/Erfolg (falls Debug + Probe enabled):
- Smoke-Check nach Import (alles "ja/nein"):
    - Tage-Liste zeigt erwartete Anzahl Tage:
    - Insights-Tab lädt ohne Crash:
    - Export-Tab lädt, Auswahl möglich:
    - Day-Detail mit Distanz > 0 m für mind. eine Route:
```

Diese Sektion bleibt **FAILED** bis ein Tester ein vollständig ausgefülltes Template mit `Ergebnis: PASSED` (sowohl Debug als auch Release) zurückmeldet.

**Handoff-Pfad (kein Mac auf Linux-Server vorausgesetzt)**:
1. **Xcode Cloud Build** triggern auf dem aktuellen Code-Stand (HEAD `37a22b7`).
2. **TestFlight / Internal Install** auf iPhone 15 Pro Max (iOS 26.4).
3. **Manueller iPhone-Import** der originalen 46-MB-`location-history.zip` (siehe Tester-Sequenz oben).
4. **Ergebnis-Rückmeldung** im o.g. Template-Format.

Auf dem Linux-Server **wird kein `xcodebuild` / kein iOS-Simulator / keine Hardware-UITest-Suite** ausgeführt — Mac-/Hardware-Automation ist explizit vertagt.

Reproduzierter Zweit-Hardware-Befund am 2026-05-07T14:14:36+02:00 (vor HEAD `34bc369` / `37a22b7`, post `cd77f97`): **trotz** Autoreleasepool-Fix in `cd77f97`:
- App: `LH2GPXWrapper` (Bundle `de.roeber.LH2GPXWrapper`).
- Datei: `~/Downloads/location-history.zip` (~46 MB; ~64.926 Top-Level-Timeline-Entries).
- Fehler: `IDEDebugSessionErrorDomain Code 11 — “The app ‘LH2GPXWrapper’ has been killed by the operating system because it is using too much memory.”`
- Operation duration: **216.606 ms** (vorher 232.341 ms — gleiche Größenordnung; der Peak hat sich nicht ausreichend reduziert).

Damit wurde klar: der Memory-Peak liegt **nach** dem JSON-Streaming. Top-Hypothese (durch Code-Lesung bestätigt) — vier zusätzliche Allokationspfade direkt nach dem Streaming:
1. `AppSessionContent.init` rief `AppExportQueries.daySummaries(from:)` mit voller `projectedDays`-Projektion auf, nur um `selectedDate` zu bestimmen — bei ~65k Entries auf ~100 Tagen 80–130 MB transienter Allokationen.
2. `AppSessionState.show(content:)` triggerte `content.overview` (lazy → voller Overview-Pass) nur, um den Title-Text bei Google-Timeline-Imports zu wählen.
3. `GoogleTimelineConverter.ExportBuilder.finalize()` kopierte alle Day-Buckets aus der `dayMap`, statt sie herauszunehmen — Tagespuffer blieben für den ganzen Loader-Scope am Leben.
4. `IncrementalStreamConverter.finalize()` hielt seinen befüllten Builder darüber hinaus.
5. `PathDistanceCalculator.effectiveDistance(for: Path)` baute pro Aufruf temporäre `[(lat, lon)]`-Arrays über alle Punkte.

Code-Stand HEAD `ae5de1f` (notwendig, aber im dritten Fail nicht hinreichend gewesen): `AppSessionContent.init` ermittelt `selectedDate` direkt aus `export.data.days` ohne `daySummaries`-Materialisierung; `AppSessionState.show(content:)` liest `inputFormat` aus `content.export.meta.source.inputFormat` / `meta.config.inputFormat` ohne `content.overview`-Trigger; `ExportBuilder.finalize()` ist `mutating` und benutzt `dayMap.removeValue(forKey:)` + abschließendes `removeAll(keepingCapacity: false)`; `IncrementalStreamConverter.finalize()` ersetzt seinen internen Builder nach Erhalt des `AppExport` durch eine frische Instanz; neue `PathDistanceCalculator.effectiveDistance(for: Path)` iteriert direkt über `points` bzw. `flatCoordinates`; Erst-Version `ImportMemoryProbe` (mach `task_vm_info`); `AppBuildInfo` + Sektion „Build Info" in `Settings → Technical`; `Info.plist`-Schlüssel `GitCommitSHA = $(GIT_COMMIT_SHA)` Build-Setting-Injection. `swift test` 1081/2/0 zum Stand `ae5de1f`. Der dritte Hardware-Fail beweist, dass dieser Stand notwendig, aber nicht hinreichend war.

Reproduzierter Erst-Hardware-Befund am 2026-05-07T13:38:37+02:00 (vor `cd77f97`):
- App: `LH2GPXWrapper` (Bundle `de.roeber.LH2GPXWrapper`).
- Datei: `~/Downloads/location-history.zip` (~46 MB unkomprimiert; ~64.926 Top-Level-Timeline-Entries).
- Fehler: `IDEDebugSessionErrorDomain Code 11 — “The app ‘LH2GPXWrapper’ has been killed by the operating system because it is using too much memory.”`
- Operation duration: 232.341 ms.
- Erst-Root-Cause: `JSONSerialization.jsonObject(with: element)` lief außerhalb des `autoreleasepool`. Behoben in `cd77f97` (notwendig, aber nicht hinreichend — siehe zweiter Fail oben).

Solange der Hardware-Retest mit der originalen 46-MB-`location-history.zip` auf iPhone 15 Pro Max (iOS 26.4) **als Release-Build ohne Debugger** nicht durch einen Tester nachweislich grün bestätigt ist, bleibt diese Sektion **FAILED**. Der vorbereitete Code-Stand in HEAD `34bc369` (+ Linux-Stabilisierung `37a22b7`) adressiert die wahrscheinlichsten Allokationspfade — der dritte Fail (Op-Dauer 95.156 ms) zeigt aber: der Peak liegt früher als bisher angenommen, und es ist kein Beweis dafür, dass das Release-Build-Verhalten unter realer iOS-Speicherlast okay ist. Der finale iPhone-Hardware-Retest **kann auf dem Linux-Server nicht durchgeführt werden** und ist ein expliziter Mac/iPhone-Handoff.

Tipp für den Tester, falls die App beim nächsten Start sofort wieder denselben Bookmark/Import zieht: einmalig in Xcode Run Arguments `LH2GPX_UI_TESTING` und `LH2GPX_RESET_PERSISTENCE` setzen, App starten, schließen, Arguments wieder entfernen — alternativ App vom iPhone löschen und neu installieren.

**Vorbereitung & Schritte**

- [ ] `~/Downloads/location-history.zip` (45 MB JSON unkomprimiert) auf echtes iPhone übertragen via AirDrop / iCloud Drive / Files
- [ ] App auf Gerät starten, über Import-Sheet `fileImporter` öffnen und die ZIP auswählen
- [ ] Import durchlaufen lassen (Phasen-Indikator beobachten)
- [ ] Nach Import durch Days-Liste, Tagesdetail, Insights navigieren
- [ ] Export-Flow nach Import auslösen (mindestens GPX)

**Akzeptanzkriterien**

- [ ] Kein Crash, kein Jetsam-Kill während Import
- [ ] Import-Phasen-Indikator durchläuft sichtbar von Start bis Abschluss
- [ ] Days-Liste ist nach Import nutzbar (Scroll, Tap auf Day)
- [ ] Tagesdetail-Distanz ist NICHT 0, wenn Route in der Karte sichtbar ist
- [ ] Insights-Werte plausibel (Modes, Distanzen, Zeiten ungleich Null bei reisefähigen Tagen)
- [ ] GPX-Export nach Import erzeugt eine valide Datei (mind. öffnen / sharen möglich)

| Feld | Wert |
| --- | --- |
| Datum | |
| Tester (Initialen) | |
| Build / Version | HEAD `37a22b7` nach `34bc369` (Linux-Stabilisierung: HeatmapPreferenceEnums-Extraktion, OptionsPresentation-Hoisting, URL/autoreleasepool/Foundation-Guards) — basiert auf `34bc369` (flatCoordinates-Kanonisierung + `ImportMemoryProbe` verdichtet + Build-Identitäts-Logging + Memory-Logging-Status in Build Info). Linux-`swift test` 1034/2/0 grün; iOS-Verhalten unverändert; Hardware-Retest steht aus. |
| Gerät / iOS | iPhone 15 Pro Max (`iPhone16,2`) / iOS 26.4 / 23E246 (Soll-Vergleichsgerät zu drei reproduzierten Hardware-Fails 2026-05-07: 232.341 ms / 216.606 ms / 95.156 ms) |
| Befund | |
| Auffälligkeiten | |
| Akzeptiert / Abgelehnt | |
| Codefix-Auftrag nötig? | |

---

### Sektion 2 — Live Activity / Dynamic Island / Lock Screen

**Vorbereitung & Schritte**

- [ ] Recording im Live-Tab starten; Always-Permission-Dialog auslösen (ggf. App vorher zurücksetzen, um Dialog zu erzwingen)
- [ ] Dialog-Wortlaut bei Erstaktivierung wörtlich notieren (siehe Befund-Feld)
- [ ] Dynamic Island im **compact**-State und im **expanded**-State sichten
- [ ] Lock Screen sperren und Live Activity dort sichten
- [ ] Recording sauber beenden (Stop-Button)

**Akzeptanzkriterien**

- [ ] Always-Permission-Dialog erscheint und ist akzeptierbar
- [ ] Dynamic Island sichtbar in compact + expanded ohne Layout-Brüche
- [ ] Lock Screen Live Activity sichtbar und lesbar
- [ ] Stop/End-Verhalten clean — Activity verschwindet, kein Geist-State
- [ ] Kein Crash bei Start oder Stop

| Feld | Wert |
| --- | --- |
| Datum | |
| Tester (Initialen) | |
| Build / Version | 1.0.1 (100) — HEAD `b91a933` |
| Gerät / iOS | |
| Permission-Dialog-Wortlaut | |
| Befund | |
| Auffälligkeiten | |
| Akzeptiert / Abgelehnt | |
| Codefix-Auftrag nötig? | |

---

### Sektion 3 — iPad-Layout

**Vorbereitung & Schritte**

- [ ] iPad verfügbar? (Falls nein: unten als „nicht durchgeführt" eintragen und Sektion abschließen)
- [ ] App auf iPad installieren (TestFlight oder Xcode-Run)
- [ ] App starten, Days-Tab öffnen
- [ ] Hero-Map-Workspace prüfen (Splitview, Karte, Days-Liste nebeneinander)

**Akzeptanzkriterien**

- [ ] Days-Tab rendert ohne Layout-Brüche
- [ ] Hero-Map-Workspace zeigt Karte + Days korrekt nebeneinander
- [ ] Keine abgeschnittenen Controls oder unzugänglichen Bereiche
- [ ] Kein Crash beim Wechsel zwischen Tabs

| Feld | Wert |
| --- | --- |
| Datum | |
| Tester (Initialen) | |
| Build / Version | 1.0.1 (100) — HEAD `b91a933` |
| iPad-Modell / iPadOS | |
| Durchgeführt? (Ja / Nein — kein iPad) | |
| Befund | |
| Auffälligkeiten | |
| Akzeptiert / Abgelehnt / Nicht durchgeführt | |
| Codefix-Auftrag nötig? | |

---

### Sektion 4 — ASC / TestFlight / Apple Review

**Vorbereitung & Schritte**

- [ ] App Store Connect öffnen, aktuellen Build-Status der App-Version prüfen
- [ ] Status `1.0` Build 74 dokumentieren (was zeigt ASC?)
- [ ] Status `1.0.1`-Train (aktuell Build 100) dokumentieren
- [ ] TestFlight-Build-Liste sichten und letzten verfügbaren Build notieren
- [ ] Nächsten Submit-Schritt festhalten (z. B. Xcode Cloud Build ≥ 100 hochladen)

**Akzeptanzkriterien**

- [ ] ASC-Status für `1.0` Build 74 dokumentiert
- [ ] ASC-Status für `1.0.1`-Train dokumentiert
- [ ] TestFlight-Build-Liste dokumentiert
- [ ] Nächster Submit-Schritt (oder „nicht geprüft") explizit eingetragen

| Feld | Wert |
| --- | --- |
| Datum | |
| Tester (Initialen) | |
| Build / Version (Acceptance-Anker) | 1.0.1 (100) — HEAD `b91a933` |
| ASC-Status `1.0` Build 74 | |
| ASC-Status `1.0.1`-Train | |
| TestFlight-Build-Liste | |
| Nächster Submit-Schritt | |
| Auffälligkeiten | |
| Akzeptiert / Abgelehnt / Nicht geprüft | |
| Codefix-Auftrag nötig? | |

---

### Verlauf — Ablehnungen & Codefix-Aufträge

| Datum | Sektion | Tester | Bug / Reproduktionsschritte | Codefix-Auftrag (ja/nein) | Codex-Auftrags-ID |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

---

## Zweck

Diese Checkliste trennt klar zwischen:

- bereits real verifizierten Apple-Schritten
- noch offenen interaktiven UI-Schritten

Sie gilt fuer die produktnahe App-Shell `LocationHistoryConsumerApp`.

---

## TestFlight-Smoke-Test-Kriterien vor App-Store-Submission

Mindestanforderungen, die vor einer App-Store-Einreichung auf einem echten iPhone erfüllt sein müssen:

### Blocking (muss grün sein)
- [ ] App installiert sich ohne Fehler aus TestFlight
- [x] App startet ohne Crash auf Zielgerät — via UITest auf iPhone 15 Pro Max (iOS 26.4) bestätigt (2026-05-05)
- [x] Demo-Daten laden korrekt — `testDeviceSmokeNavigationAndActions` auf iPhone 15 Pro Max PASSED (2026-05-05)
- [x] Overview, Days, Insights, Export, Live-Tab navigierbar ohne Crash — `testDeviceSmokeNavigationAndActions` + `testAppStoreScreenshots` auf iPhone 15 Pro Max PASSED (2026-05-05)
- [x] Kein reproduzierbarer Crash in den Hauptflows — UITests auf Gerät grün (2026-05-05)
- [ ] Dateiimport (`.json`/`.zip`) aus Datei-App funktioniert und zeigt Daten an (nur manuell testbar)

### Performance-Schwellenwert (vor Submission bewerten)
- [ ] Performance-Smoke-Test mit großem Datensatz (>20 MB reale Location-History) abgeschlossen
- [ ] Keine UI-Hänger >2–3 Sekunden auf dem Zielpfad (Import → Overview-Karte laden → Days-Tab)
- [ ] Jeder reproduzierbare Hänger mit Screen/Flow dokumentiert und priorisiert

### Repo-/Xcode-Nachweis 2026-04-29 — interaktive Overview-/Explore-Karte
- Bounding-Box-basiertes Viewport-Culling statt Midpoint-only im Repo verifiziert
- Pan/Zoom rebuildet nur Overlays auf Basis des gecachten Kandidatenpools; kein neuer Export-Scan im Viewport-Pfad
- Explore-Dismiss setzt wieder Full-View-Overlays; stale Overlay-Tasks werden bei Neu-Load verworfen
- Verifiziert nur per `swift test` + `xcodebuild`; **kein** neuer Geräte-Claim aus diesem Audit-Batch

### Day-Detail-Distance-Fix — 2026-05-07 (nach 3-UITest-Acceptance)

Nach der vollen 3-UITest-Acceptance vom 2026-05-07 (HEAD `pending` für 44pt-Hit-Target-Fix) wurde der Day-Detail-Distance-Bug gefixt (`PathDistanceCalculator` + `effectiveDistanceM` in `DayDetailViewState.PathItem`). Post-Fix wurde nur das Device-Smoke-UITest erneut auf iPhone 15 Pro Max gefahren — **nicht** die volle 3-UITest-Suite.

- **testDeviceSmokeNavigationAndActions** (iPhone 15 Pro Max, iOS 26.4) post-Fix: PASSED (75s) ✅
- **testAppStoreScreenshots** post-Fix: NICHT erneut gefahren
- **testLandscapeLayoutSmoke** post-Fix: NICHT erneut gefahren
- `swift test`: 1077/2/0 (+12 gegenüber 1065)

### Verifikation 2026-05-07 — Post-Fix Hardware iPhone 15 Pro Max

Reine Re-Verifikation nach Day-Detail-Distance-Fix (Commit `853d8d3`). Keine Code-Änderungen. Volle 3-UITest-Acceptance-Suite jetzt post-Fix erneut grün — beim Commit `853d8d3` war nur Smoke-Navigation post-Fix verifiziert.

Ausgefuehrt auf: macOS, Xcode 26.3 (Build 17C529), iPhone 15 Pro Max (UDID `00008130-00163D0A0461401C`, iOS 26.4)

- App: 1.0.1 (100), Bundle `de.roeber.LH2GPXWrapper`, Team XAGR3K7XDJ
- HEAD: pending — Commit folgt

#### ✅ real verifiziert (2026-05-07, post-Fix) — iPhone 15 Pro Max

- **testAppStoreScreenshots** (iPhone 15 Pro Max, iOS 26.4): PASSED (41.8s) ✅
- **testDeviceSmokeNavigationAndActions** (iPhone 15 Pro Max, iOS 26.4): PASSED (71.2s) ✅
- **testLandscapeLayoutSmoke** (iPhone 15 Pro Max, iOS 26.4): PASSED (829.9s) ✅
- **swift test**: 1077 Tests, 2 Skips, 0 Failures (unverändert gegenüber `853d8d3`)
- **git diff --check**: clean

Weiterhin offen: 46-MB-Crashfall geräteseitig (manueller Import nötig), Live Activity / Dynamic Island / Lock-Screen-Visuals (UI-interaktiv), iPad-Layout, ASC / TestFlight / Apple Review.

### Hardware-Verifikation — iPhone 15 Pro Max — 2026-05-07

Ausgefuehrt auf: macOS, Xcode 26.3 (Build 17C529), iPhone 15 Pro Max (UDID 00008130-00163D0A0461401C, iOS 26.4)

- App: 1.0.1 (100), Bundle `de.roeber.LH2GPXWrapper`, Team XAGR3K7XDJ
- HEAD: pending — Commit folgt

#### ✅ real verifiziert (2026-05-07) — iPhone 15 Pro Max

- **testAppStoreScreenshots** (iPhone 15 Pro Max, iOS 26.4): PASSED (42.9s) ✅
- **testDeviceSmokeNavigationAndActions** (iPhone 15 Pro Max, iOS 26.4): PASSED (72.2s) ✅
- **testLandscapeLayoutSmoke** (iPhone 15 Pro Max, iOS 26.4): PASSED (830s, Landscape-Rotation langsam aber grün) ✅
- **swift test**: 1077 Tests, 2 Skips, 0 Failures (unverändert)
- **Wrapper xcodebuild auf iPhone 15 Pro Max**: BUILD + TEST SUCCEEDED ✅

#### Bug-Befund + Fix (Hardware-Run #1 → Run #2)

Hardware-Run #1 (HEAD `7cc2e97`) zeigte: `testAppStoreScreenshots` und `testLandscapeLayoutSmoke` FAILED — XCUITest reportete „Failed to not hittable" für den Clear-Date-Range-Button (`xmark.circle.fill` in `HistoryDateRangeFilterBar`). Hit-Area war 12×12pt — unter Apple HIG-Mindestmaß 44×44pt und auf Hardware nicht zuverlässig tap-fähig. Fix: `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` um das Button-Image; visible Glyph unverändert. Hardware-Run #2 (HEAD pending — Commit folgt): alle drei UITests grün.

#### Weiterhin offen (nicht in diesem Run geprüft)

- 46-MB-Crashfall geräteseitig: `~/Downloads/location-history.zip` (45 MB JSON) erfordert manuellen iPhone-Import via AirDrop/iCloud + Tap durch fileImporter — kein automatisierbarer UITest dafür.
- Live Activity / Dynamic Island / Lock-Screen visuell: kein UITest startet eine echte Live Recording, da Always-Permission-Dialog Hardware-Interaktion braucht; `testLiveActivityHardwareCapture*` nicht im Pflichtset gefahren.
- Per-Tab visuelle Layout-Begutachtung: UITests prüfen nur Existenz/Tappability, nicht visuelle Korrektheit.
- ASC / TestFlight-Status: nicht geprüft.
- Apple Review Status: nicht geprüft.

---

### Hardware-Verifikation — iPhone 15 Pro Max — 2026-05-05

Ausgefuehrt auf: macOS, Xcode, iPhone 15 Pro Max (UDID 00008130-00163D0A0461401C, iOS 26.4)

#### ✅ real verifiziert (2026-05-05) — iPhone 15 Pro Max

- **swift test**: 927 Tests, 0 Failures ✅ (an diesem Datum; aktueller Stand 2026-05-07 HEAD 3811bc3 nach P1-Hardening-Train (distanceText\! safe-unwrap, weak self in AppOverviewMapModel, Upload-URL-Validation + 8 neue Tests). Vorher 2026-05-06 unter Audit-Batch Block 1-4 (19 Achsen: u.a. **Live-Upload bekommt jetzt 30 s Per-Request-Timeout** in `LiveLocationServerUploader`, **Mutations fließen jetzt in Exporte ein** — gelöschte Routen verschwinden aus GPX/KMZ/KML/GeoJSON/CSV; Concurrency, Edge-Case-Crashes, Perf-Hotspots) plus P0-Audit-Fix-Train 3/N (GPX-`fatalError` und `as!`-Force-Cast in `GPXImportParser` entschärft, KeychainHelper-`kCFBooleanTrue!`-Force-Unwrap entschärft, `AppExportSchemaVersion` forward-kompatibel) plus Einführung des element-basierten Streaming-Parsers für Google Timeline JSON: 1077 Tests, 2 Skips, 0 Failures (Stand 2026-05-07 nach Phase 1-5 Audit-Train, HEAD `20877ae` — 14 Achsen über `21b4026` (Phase 1) + `20877ae` (Phase 2-5): `projectedDays`-Cache, Mutations-Index, Race-Token, Live-Map-Dedup, `@testable`-Cleanup-Folge, Mock-Client + State-Transition-Tests, `LH2GPXAppFlow` Drift-Extraction + Auto-Restore-Phasen, API-Naming als additives Importing-Protokoll (kein Rename), `wrapper/CI.xctestplan` SwiftPM-Coverage SKIP — pbxproj-Integration zu fragil, `Tests/README.md` Update, Doku-Truth-Cleanup. Hardware-Re-Verifikation iPhone 15 Pro Max bleibt offen. +1 Case gegenüber 1044. Davor 1044 nach Audit-Batch B+C+D+A — 22 Achsen: Dead-Code-Removal (~158 Zeilen weniger; `LHMapStyleToggleButton` public API entfernt — war deprecated seit MapLayerMenu-Train, keine externen Caller bekannt), Perf-Restposten (`OverviewMapRenderData: Equatable` Hand-`==`, inline Haversine, `HeatmapGridBuilder` Single-Sort+`suffix`-Trim, `AppExportQueries.findDay` Fast-Path), `@testable import` → reines `import` für 15 von 22 Test-Files, 9 neue Test-Files mit 27 neuen Cases (Decoder-Errors, GPX/TCX-Import-Errors, Round-Trip, Filter-Kombinationen, Heatmap-Edge-Cases, Live-State-Transition-Placeholder, Export-Mutations, ZIP-Streaming-Pfad). `wrapper/CI.xctestplan` SKIP (pbxproj-Integration out-of-scope), API-Naming P2-16 + HeatmapGridBuilder MapKit-Entkopplung P2-18 bewusst not done. Hardware-Re-Verifikation iPhone 15 Pro Max bleibt offen. +27 Cases gegenüber 1017. Davor 1017 unter Audit Block 1-2-Train: WidgetSharedKeys-Konsolidierung als Single-Source-of-Truth (P1-3 erledigt), `onOpenURL` im Package-App-Target `AppShellRootView` (P1-4 erledigt), ZIP-Entry-Streaming für Google Timeline (Sniffer-basiert; greift bei genau einem Timeline-Entry, kein Mixed-ZIP — Peak RAM auf ~ein Element), Import-Phasen-Progress (`enum ImportPhase { reading, parsing, building }`), Mikro-Benchmark als XCTest-`measure`-Baseline-Logging — kein fail-on-regression bar, kein gemessener Speedup-Faktor; +5 neue Cases gegenüber 1012). Vorher 1012 unter HEAD post-`70254ff`; Zwischenstand 991 nach Memory-Safety-Folgefix, 987 nach erstem Memory-Safety-Fix, 973 nach LH2GPXLoadingBackground, 964 nach Doku-/Wiring-Audit-Polish, 949 unter `93109e0`. Hardware-Re-Verifikation iPhone 15 Pro Max bleibt offen.)
- **git diff --check**: sauber ✅
- **xcodebuild -destination 'id=00008130-00163D0A0461401C'**: BUILD SUCCEEDED ✅
- **testAppStoreScreenshots** (iPhone 15 Pro Max): PASSED (44s) ✅ — 6 PNGs 1290×2796
- **testDeviceSmokeNavigationAndActions** (iPhone 15 Pro Max): PASSED (70s) ✅
  - Demo Data laden ✅
  - Overview-Tab + All-Time-Filter-Chip (`range.chip.all`) ✅
  - Heatmap-Sheet öffnen + schließen ✅
  - Insights Share-Button (`insights.share.*`) ✅
  - Export fileExporter ✅
  - Live Start/Stop Recording ✅

#### App-Store-Screenshots — iPhone 15 Pro Max (2026-05-05)

- **Pflichtset**: 6 Slots (Options entfernt — kein Tab-Bar-Button, nicht zuverlässig automatisierbar)
- **Auflösung**: 1290×2796 px (iPhone 15 Pro Max, 3×)
- **Speicherort**: `docs/app-store-assets/screenshots/iphone-67/iphone15pm_0N_*.png`
- **Inhalte**:
  - `iphone15pm_01_import.png` — Import/Start ✅
  - `iphone15pm_02_overview.png` — Overview-Karte + KPI ✅
  - `iphone15pm_03_days_sticky_map.png` — Days mit Sticky Map ✅
  - `iphone15pm_04_export_checkout.png` — Export Checkout ✅
  - `iphone15pm_05_insights.png` — Insights Dashboard ✅
  - `iphone15pm_06_live_tracking.png` — Live Tracking ✅
- **Keine privaten Daten**: ausschließlich Demo-Fixture (synthetisch) verwendet
- **Keine Debug-Overlays**: saubere Release-UI

#### ✅ Landscape-Verifikation — iPhone 15 Pro Max (2026-05-05)

- **testLandscapeLayoutSmoke** (iPhone 15 Pro Max): PASSED (62s) ✅
- **Getestete Tabs**: Overview, Days, Export, Insights, Live — alle ohne Crash
- **Strategie**: Navigation in Portrait, Rotation zu landscapeRight pro Tab, Screenshot-Anhang
- **Screenshots**: `landscape_01_overview`, `landscape_02_days`, `landscape_03_export`, `landscape_04_insights`, `landscape_05_live`
- **Bekannte Einschränkung**: `live.recording.primaryAction`-Button nicht per Accessibility in Landscape exponiert (XCTest-Limit nach Rotation). Button ist in Portrait nachweislich vorhanden und hittable (`testDeviceSmokeNavigationAndActions` PASSED). Keine Safe-Area-Überlappung per Crash nachweisbar.
- **Safe-Area-Verhalten**: kein reproduzierbarer Layout-Crash in allen 5 Tabs

#### ⚠️ weiterhin offen (2026-05-05) — nicht automatisiert testbar

- **Live Activity / Dynamic Island**: Batch 5A/5B noch ohne vollständigen Hardware-Nachweis
  - Letzter Stand (2026-04-30): 5/5 Capture-Tests auf iPhone 15 Pro Max PASSED
  - Offen: Lock Screen, `minimal`, deaktivierte Live Activities
- **Manueller Dateiimport**: `.json`/`.zip` aus Files-App öffnen — manuell zu prüfen
- **Großer Import (>20 MB)**: Performance-Smoke-Test mit realer History-Datei — manuell zu prüfen
- **Widget auf Homescreen**: manuelle Homescreen-Interaktion nötig
- **Landscape Live-Tab**: `live.recording.primaryAction` in Landscape manuell visuell prüfen (UITest-Accessibility-Lücke nach Rotation dokumentiert)

---

### Verifikations-Batch Redesign 1–5B — 2026-05-05

Ausgefuehrt auf: macOS (dieser Host), Xcode, iPhone 17 Pro Max Simulator

#### ✅ real verifiziert (2026-05-05) — Simulator

- **swift test**: 927 Tests, 0 Failures ✅ (an diesem Datum; aktueller Stand 2026-05-07 HEAD 3811bc3 nach P1-Hardening-Train (distanceText\! safe-unwrap, weak self in AppOverviewMapModel, Upload-URL-Validation + 8 neue Tests). Vorher 2026-05-06 unter Audit-Batch Block 1-4 (19 Achsen: u.a. **Live-Upload bekommt jetzt 30 s Per-Request-Timeout** in `LiveLocationServerUploader`, **Mutations fließen jetzt in Exporte ein** — gelöschte Routen verschwinden aus GPX/KMZ/KML/GeoJSON/CSV; Concurrency, Edge-Case-Crashes, Perf-Hotspots) plus P0-Audit-Fix-Train 3/N (GPX-`fatalError` und `as!`-Force-Cast in `GPXImportParser` entschärft, KeychainHelper-`kCFBooleanTrue!`-Force-Unwrap entschärft, `AppExportSchemaVersion` forward-kompatibel) plus Einführung des element-basierten Streaming-Parsers für Google Timeline JSON: 1077 Tests, 2 Skips, 0 Failures (Stand 2026-05-07 nach Phase 1-5 Audit-Train, HEAD `20877ae` — 14 Achsen über `21b4026` (Phase 1) + `20877ae` (Phase 2-5): `projectedDays`-Cache, Mutations-Index, Race-Token, Live-Map-Dedup, `@testable`-Cleanup-Folge, Mock-Client + State-Transition-Tests, `LH2GPXAppFlow` Drift-Extraction + Auto-Restore-Phasen, API-Naming als additives Importing-Protokoll (kein Rename), `wrapper/CI.xctestplan` SwiftPM-Coverage SKIP — pbxproj-Integration zu fragil, `Tests/README.md` Update, Doku-Truth-Cleanup. Hardware-Re-Verifikation iPhone 15 Pro Max bleibt offen. +1 Case gegenüber 1044. Davor 1044 nach Audit-Batch B+C+D+A — 22 Achsen: Dead-Code-Removal (~158 Zeilen weniger; `LHMapStyleToggleButton` public API entfernt — war deprecated seit MapLayerMenu-Train, keine externen Caller bekannt), Perf-Restposten (`OverviewMapRenderData: Equatable` Hand-`==`, inline Haversine, `HeatmapGridBuilder` Single-Sort+`suffix`-Trim, `AppExportQueries.findDay` Fast-Path), `@testable import` → reines `import` für 15 von 22 Test-Files, 9 neue Test-Files mit 27 neuen Cases (Decoder-Errors, GPX/TCX-Import-Errors, Round-Trip, Filter-Kombinationen, Heatmap-Edge-Cases, Live-State-Transition-Placeholder, Export-Mutations, ZIP-Streaming-Pfad). `wrapper/CI.xctestplan` SKIP (pbxproj-Integration out-of-scope), API-Naming P2-16 + HeatmapGridBuilder MapKit-Entkopplung P2-18 bewusst not done. Hardware-Re-Verifikation iPhone 15 Pro Max bleibt offen. +27 Cases gegenüber 1017. Davor 1017 unter Audit Block 1-2-Train: WidgetSharedKeys-Konsolidierung als Single-Source-of-Truth (P1-3 erledigt), `onOpenURL` im Package-App-Target `AppShellRootView` (P1-4 erledigt), ZIP-Entry-Streaming für Google Timeline (Sniffer-basiert; greift bei genau einem Timeline-Entry, kein Mixed-ZIP — Peak RAM auf ~ein Element), Import-Phasen-Progress (`enum ImportPhase { reading, parsing, building }`), Mikro-Benchmark als XCTest-`measure`-Baseline-Logging — kein fail-on-regression bar, kein gemessener Speedup-Faktor; +5 neue Cases gegenüber 1012). Vorher 1012 unter HEAD post-`70254ff`; Zwischenstand 991 nach Memory-Safety-Folgefix, 987 nach erstem Memory-Safety-Fix, 973 nach LH2GPXLoadingBackground, 964 nach Doku-/Wiring-Audit-Polish, 949 unter `93109e0`. Hardware-Re-Verifikation iPhone 15 Pro Max bleibt offen.)
- **git diff --check**: sauber ✅
- **xcodebuild generic/platform=iOS** (LH2GPXWrapper + Widget): BUILD SUCCEEDED ✅
- **xcodebuild iPhone 17 Pro Max Simulator build**: BUILD SUCCEEDED ✅
- **CI.xctestplan** (iPhone 17 Pro Max Simulator): TEST SUCCEEDED (alle 8 LH2GPXWrapperTests) ✅
- **testAppStoreScreenshots** (iPhone 17 Pro Max Simulator): PASSED ✅ — 7/8 Slots (01–06, 08); Slot 07-options fehlte, weil Options kein eigener Tab-Bar-Eintrag ist
- **testDeviceSmokeNavigationAndActions** (iPhone 17 Pro Max Simulator): nach Bugfix PASSED ✅
  - Bug: veralteter Identifier `insights.section.share` → gefixt auf `identifier BEGINSWITH 'insights.share.'`
- **Screenshot-Kandidaten** (Simulator, 1320×2796 px): gespeichert in `docs/app-store-assets/screenshots/simulator-iphone17promax/`

#### Visuell geprüft (Simulator-Screenshots, kein Hardware-Nachweis)
- **01-import**: Import-CTA, Hero, Privacy-Row ✅
- **02-overview-map**: Karte, KPI-Grid, Datumsbereich ✅
- **03-days**: Sticky-Map sichtbar, Tagesliste darunter ✅
- **04-insights**: Hero-Summary (Batch 4), KPI-Grid, Sektionen ✅
- **05-export**: Checkout-Struktur (Batch 3), Formatwahl, Bottom-Bar ✅
- **06-live-recording**: Hero-Status-Card (Batch 5A), Diagnostics-Bereich, Bottom-Bar ✅
- **08-day-detail**: Map-first, Demo-Tag ✅

#### ⚠️ nicht geprüft in diesem Batch (weiterhin offen)
- Landscape-Verifikation: alle Tabs — kein neuer Hardware- oder manueller Simulator-Lauf
- Live Activity / Dynamic Island: Batch 5A/5B noch ohne Hardware-Nachweis auf echtem Gerät
- Widget auf echtem Homescreen: nicht geprüft
- iPad: nicht relevant für v1 (`TARGETED_DEVICE_FAMILY = 1`)
- Neue App-Store-Screenshots auf iPhone 15 Pro Max: ausstehend

---

### Xcode Cloud Build 84 — Erfolgreich (Version 1.0.1) — 2026-05-05

- **Build**: `1.0.1 (84)` — Xcode Cloud Workflow `Release – Archive & TestFlight`
- **Archive - iOS**: ✅ erfolgreich
- **TestFlight-interne Tests - iOS**: ✅ erfolgreich
- **ASC-Upload**: akzeptiert — 1.0.1-Train offen, kein ITMS-Fehler
- **Nächster manueller Schritt**: ASC → Version `1.0.1` → Build `84` auswählen → Screenshots ersetzen → `Submit for Review`
- **Noch nicht eingereicht**: Version `1.0.1` ist nicht in Review; kein Accepted-Status behauptet

### Xcode Cloud Build 83 — Upload-Fehler (1.0-Train geschlossen) — 2026-05-05

- **Fehler**: ITMS-90186 `Invalid Pre-Release Train — The train version '1.0' is closed for new build submissions` + ITMS-90062 `CFBundleShortVersionString [1.0] must contain a higher version than previously approved version [1.0]`
- **Ursache**: App Store Connect akzeptiert für Version `1.0` keine neuen Builds mehr — Build 74 wurde für diesen Train akzeptiert und der Train ist damit gesperrt. Kein Code-, Signing-, Archive- oder Xcode-Cloud-Problem.
- **Fix**: `MARKETING_VERSION` in `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj` von `1.0` auf `1.0.1` angehoben (alle 8 Build-Konfigurationen). Plists verwenden weiterhin `$(MARKETING_VERSION)` und `$(CURRENT_PROJECT_VERSION)`.
- **ASC**: Version `1.0.1` bereits in App Store Connect angelegt.
- **Nächster Build**: Xcode Cloud Build ≥ 84 soll `CFBundleShortVersionString = 1.0.1` produzieren und den Upload für Version `1.0.1` akzeptieren.
- **Build 83**: ungültig (falscher Train), ignorieren.

### App Review — Build 74 Accepted — Pending Developer Release (2026-05-05)

- **Version `1.0`** (Build 74): nach Ablehnung (2026-05-01, Guideline 3.2) und Review-Response **akzeptiert** am 2026-05-05
- **ASC-Status**: `Ausstehende Entwicklerfreigabe (Pending Developer Release)`
- **Guideline 3.2**: **Resolved / Accepted** — kein offener Ablehnungsgrund
- **Build 74 wird nicht veröffentlicht**: bewusste Entscheidung; Weiterentwicklung vor öffentlichem Release
- **App ist nicht live**: nicht im App Store verfügbar
- **Submission ID**: `1d2cc080-13cd-45cd-b3e0-c0259a75ce5c`

### App Review Ablehnung — 2026-05-01 (Guideline 3.2) — historisch

- **Build bei Ablehnung**: `74` — Guideline 3.2 — Business / Other Business Model Issues
- **Apple-Einschätzung**: App wurde als organisationsgebundene / unternehmensinterne Lösung eingestuft
- **Sachverhalt**: LH2GPX ist eine öffentliche Consumer-/Utility-App; keine Organisationsbindung, kein Pflicht-Account, kein zentraler Server; optionaler Live-Upload ist nutzerkonfiguriert und standardmäßig deaktiviert
- **Review-Response**: von Sebastian gesendet → Apple hat akzeptiert
- **Review Guidelines — Tabelle**:

| Abschnitt | Befund | Status |
|-----------|--------|--------|
| **3.2 Business / Other Business Model Issues** | App ist öffentliche Consumer-App; kein Account/Login/Org-Binding; optionaler self-hosted Live-Upload ist standardmäßig OFF und erfordert nutzerseitige Konfiguration | ✅ **Accepted** (nach Review-Response 2026-05-05) |

### Beobachtung App Store Connect / Review — Stand 2026-05-05
- **Xcode Cloud**: aktuellster erfolgreicher Build: `74`
- **Screenshots in ASC**: stammen aus Build 71 — zeigen altes UI-Layout (vor LH2GPX-Dark-Redesign); vor nächstem Submit ersetzen
- **Screenshot-Runbook**: `docs/ASC_SUBMIT_RUNBOOK.md`
- **Hardware-Risiko bleibt**: Live Activity / Dynamic Island nur partiell auf echter Hardware verifiziert

### Beobachtung App Store Connect / Review — Stand 2026-04-30 (historisch)
- **Zur Version sichtbarer Build**: `52`
- **Xcode Cloud**: Workflow `Release – Archive & TestFlight` zeigt erfolgreiche Builds `55`, `56` und `57`
- **Review-Entscheidung**: Build `52` blieb bewusst in App Review bis Build 73/74 bereit

### Beobachtung Build 1.0 (44) — Stand 2026-04-29
- **TestFlight-Verfügbarkeit**: Build 1.0 (44) ist auf iPhone installierbar ✅
- **Interner Smoke-Test**: App startet, Haupttabs navigierbar, kein bestätigter Crash ✅
- **Performance**: gelegentliche UI-Hänger/Ruckler beobachtet — kein reproduzierbarer Crash, aber noch kein systematischer Großdaten-Test
- **Overview-Map Freeze-Blocker**: behoben (Hard Overlay Limit, s. CHANGELOG 2026-04-29); Performance-Audit bestätigt: kein globales Coordinate-Budget nötig; `overlayLimit × maxPolylinePoints` schützt implizit (max 9.600–48.000 Koordinaten je Tier); TestFlight-Verifikation mit echten großen Daten noch ausstehend
- **Historischer Stand**: diese Beobachtung beschreibt nur den damaligen TestFlight-Snapshot; der aktuelle Review-Status steht im Block oben

---

## Statusstand 2026-05-05 — App-Store-Screenshots (iPhone 15 Pro Max)

### Verifikation 2026-05-05 — Screenshots (aktueller Stand)

Ausgefuehrt auf: iPhone 15 Pro Max (UDID 00008130-00163D0A0461401C, iOS 26.4)

#### ✅ real verifiziert (2026-05-05) — Screenshot-Set

- **UITest `testAppStoreScreenshots`** auf iPhone 15 Pro Max: PASSED (44s), 6/6 Screenshots erzeugt
- **Screenshot-Verfahren**: XCTAttachment → xcresult-Bundle v3.56 → xcresulttool + Python-Extraktion
- **Auflösung**: 1290×2796 px (iPhone 15 Pro Max, 3×)
- **Speicherort**: `docs/app-store-assets/screenshots/iphone-67/`
- **Inhalt**: Demo-Daten (synthetische Fixture — keine privaten Nutzerdaten)
- **Keine privaten Daten**: ausschließlich Repo-Demo-Fixture, keine echten Standortdaten
- **Keine Debug-Overlays**: saubere Release-UI
- **Pflichtset**: 6 Slots — Options (Slot 07) entfernt, weil kein eigener Tab-Bar-Button

#### Screenshot-Dateien (für App Store Connect) — aktueller Stand Build 74+

| Datei | Größe | Slot | Status |
|-------|-------|------|--------|
| `iphone15pm_01_import.png` | 1290×2796 | Import / Start | ✅ neu (2026-05-05, aktuelles Redesign) |
| `iphone15pm_02_overview.png` | 1290×2796 | Overview + Karte + KPI | ✅ neu (2026-05-05, aktuelles Redesign) |
| `iphone15pm_03_days_sticky_map.png` | 1290×2796 | Days + Sticky Map | ✅ neu (2026-05-05, aktuelles Redesign) |
| `iphone15pm_04_export_checkout.png` | 1290×2796 | Export Checkout | ✅ neu (2026-05-05, Batch 3-Design) |
| `iphone15pm_05_insights.png` | 1290×2796 | Insights Dashboard | ✅ neu (2026-05-05, Batch 4-Design) |
| `iphone15pm_06_live_tracking.png` | 1290×2796 | Live Tracking | ✅ neu (2026-05-05, Batch 5A-Design) |

**Hinweis**: Alte Screenshots (01-import.png … 06-live-recording.png) zeigen veraltetes Layout (Build 44). Für ASC den neuen `iphone15pm_*`-Satz hochladen.
→ Runbook: `docs/ASC_SUBMIT_RUNBOOK.md`

---

## Statusstand 2026-04-29 — App-Store-Screenshots (iPhone 15 Pro Max) — historisch

### Verifikation 2026-04-29 — Screenshots (historisch, altes Layout)

- **UITest `testAppStoreScreenshots`** auf iPhone 15 Pro Max: PASSED (41 s), 6/6 Screenshots erzeugt
- **Originale**: `docs/app-store-assets/screenshots/iphone-67/01-import.png … 06-live-recording.png` — **altes Layout (Build 44), nicht mehr aktuell**

---

## Statusstand 2026-04-29 — Verifikationsrunde (MacBook, Xcode 26.3, iPhone 15 Pro Max)

### Verifikation 2026-04-29

Ausgefuehrt auf: macOS, Xcode 26.3, iPhone 15 Pro Max (UDID 00008130-00163D0A0461401C)

#### ✅ real verifiziert (2026-04-29)

- **swift test**: 643 Tests, 0 Failures, 0 Skips — bestätigt (2× gelaufen)
- **xcodebuild generic/platform=iOS (LH2GPXWrapper)**: BUILD SUCCEEDED — Wrapper inkl. Widget
- **xcodebuild platform=macOS (LocationHistoryConsumerApp)**: BUILD SUCCEEDED
- **CI.xctestplan Wrapper-Unit-Tests** (iPhone 17 Pro Max Simulator, iOS 26.3.1, testPlan CI): TEST SUCCEEDED — alle LH2GPXWrapperTests grün
- **UITests alle 6 Tests auf iPhone 15 Pro Max** (00008130-00163D0A0461401C, ios 26.3): 6/6 PASSED ✅
  - `testLaunch` × 4 — App startet sauber, kein Crash ✅
  - `testAppStoreScreenshots` — Demo-Daten laden, Day-Liste sichtbar ✅
  - `testDeviceSmokeNavigationAndActions` (55s) — vollständiger Smoke-Pfad ✅:
    - Demo Data geladen, Overview-Tab erscheint ✅
    - All-Time-Filter-Chip (`range.chip.all`) sichtbar und tappbar ✅ (neu: accessibility identifier)
    - Heatmap-Sheet öffnet und schließt ✅
    - Insights-Tab: `insights.section.share` Button gefunden, Share-Popup erscheint ✅
    - Export-Tab: fileExporter auf echtem Gerät ausgelöst ✅
    - Live-Tab: Start-Recording, Location-Permission-Dialog, Stop-Recording — alles auf echtem Gerät ✅
- **Info.plist**: NSLocationWhenInUseUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription, UIBackgroundModes=location, NSSupportsLiveActivities=true — vorhanden und korrekt
- **Entitlements**: App Group `group.de.roeber.LH2GPXWrapper` in App + Widget Entitlements — korrekt
- **PrivacyInfo.xcprivacy**: NSPrivacyTracking=false, UserDefaults CA92.1, NSPrivacyCollectedDataTypePreciseLocation — vollständig
- **Export-Compliance**: `ITSAppUsesNonExemptEncryption = false` in `wrapper/Config/Info.plist` (App) und `wrapper/LH2GPXWidget/Info.plist` (Widget) gesetzt — kein Upload-Dokument nötig. Begründung: App nutzt ausschließlich systemseitige HTTPS/TLS (URLSession, optionaler Live-Location-Upload); keine eigene Verschlüsselung (kein CryptoKit, CommonCrypto, AES, RSA, VPN, E2E-Messaging, Crypto-Bibliotheken).
- **Release-Signing-Konfiguration**: `LH2GPXWrapper` + `LH2GPXWidget` stehen auf `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM = XAGR3K7XDJ`, ohne feste Release-`PROVISIONING_PROFILE_SPECIFIER` und ohne explizite Release-`CODE_SIGN_IDENTITY`; Buildnummer lokal auf `45` angehoben; `com.apple.security.application-groups = group.de.roeber.LH2GPXWrapper` in App + Widget vorhanden
- **Widget-Embed**: `LH2GPXWidget.appex` wird mit `CodeSignOnCopy` eingebettet
- **Sicherheit**: keine hartcodierten Tokens/Secrets; defaultTestEndpointURLString=""; HTTPS fuer non-localhost erzwungen; Bearer-Token via Keychain
- **Deployment Target**: iOS 17.0 (alle Targets — App, LH2GPXWrapperTests, Widget, UITests) — angehoben in Train F (2026-05-16), verifiziert in project.pbxproj
- **Bundle IDs**: de.roeber.LH2GPXWrapper / de.roeber.LH2GPXWrapper.Widget / de.roeber.LH2GPXWrapperTests / de.roeber.LH2GPXWrapper.UITests — korrekt
- **ZIPFoundation**: Fork dev-roeber/ZIPFoundation, Tag 0.9.20-devroeber.1, .exact() — gepinnt
- **ci_scripts**: ci_post_clone.sh, ci_pre_xcodebuild.sh, ci_post_xcodebuild.sh — ausführbar, korrekte Xcode-Cloud-Namen
- **.xcode-version**: 26.3 — gepinnt
- **Bug-Fix**: `AppHistoryDateRangeControl` — `.accessibilityIdentifier("range.chip.\(preset.rawValue)")` ergänzt (ermöglicht UITest-Selektion des All-Time-Chips ohne Sprachabhängigkeit)
- **UITest-Fix**: `testDeviceSmokeNavigationAndActions` — tappt nach Demo-Load `range.chip.all` um Last-7-Days-Filter zurückzusetzen; Demo-Daten (2024) sonst durch Default-Filter unsichtbar

#### ⚠️ nicht automatisiert prüfbar (erfordern manuellen Device-Durchgang)

- **Großer Import (>20 MB) / 46-MB-Crashfall**: guarded — Auto-Restore lehnt rohe Google-Timeline-Dateien grundsätzlich (unabhängig von der Größe) per Sniffer-Skip ab und zusätzlich alles über 50 MB per Cap (`AppContentLoader.assertAutoRestoreEligible`, 2026-05-06). Manuelle Imports laufen seit 2026-05-06 über einen element-basierten Streaming-Parser (`GoogleTimelineStreamReader` + `GoogleTimelineConverter.convertStreaming(contentsOf:)`) ohne Full-Data-Load und ohne `JSONSerialization`-Vollbaum. Performance-Pass am 2026-05-06 auf vier Achsen: (1) UnsafeBytes-Tokenizer statt `Data.Index`-Iteration, (2) Default-Chunk 64 KB → 256 KB, (3) `autoreleasepool` um den Per-Element-Callback (verhindert Foundation-Akkumulation), (4) Direct-Model-Build im Konverter — `AppExport`/`Day`/`Visit`/`Activity`/`Path` werden über neue public memberwise-Initializer direkt instanziiert, der frühere `[String: Any]`-Tree plus `JSONSerialization`-Encode plus `AppExportDecoder`-Decode auf der Output-Seite entfällt. Erwartete Größenordnung / Designziel, kein gemessener Speedup-Faktor — Mikro-Benchmark steht aus. Hardware-Re-Verifikation mit echter 46-MB-`location-history.zip` auf iPhone 15 Pro Max steht weiterhin aus (kein 46-MB-Fixture im Repo). ZIP-Entry-Streaming für Google Timeline ist seit 2026-05-07 implementiert (`AppContentLoader.streamGoogleTimelineCandidateIfApplicable`, Sniffer-basiert; greift bei genau einem Google-Timeline-Entry und keinem LH2GPX-Object-Entry — `Archive.extract { chunk in converter.feed(chunk) }` läuft direkt durch den Streaming-Parser, Peak RAM auf ~ein Element statt voller entpackter Datei). Mehrfach-Timeline-/Mixed-ZIPs fallen weiterhin auf den Legacy-Extract-and-Decode-Pfad. Hardware-Re-Verifikation iPhone 15 Pro Max bleibt offen.
- **Days-Tab**: Day-Detail + Day-Map auf Gerät interaktiv prüfen (im UITest nur als Demo-Nebeneffekt belegt)
- **Historien-Track-Editor**: Route entfernen, App-Neustart, Mutation prüfen — nicht automatisiert prüfbar
- **Widget auf Homescreen/Lockscreen**: Widget Target baut, aber Pinnbar-Test erfordert manuelle Homescreen-Interaktion
- **Live Activity / Dynamic Island**: NSSupportsLiveActivities=true, Code vorhanden; konfigurierbarer Primärwert (`Distanz`, `Dauer`, `Punkte`, `Upload-Status`) + Fallback-Hinweise im Options-Screen implementiert. Echter Device-Rerun auf `iPhone 15 Pro Max` (`iOS 26.4`, Debug-Build via `xcodebuild test`) liegt jetzt fuer folgende Pfade vor: Smoke-Test gruen, Capture-Tests fuer `Distanz`, `Dauer`, `Punkte` und `Upload-Status (failed)` gruen, jeweils inklusive In-App-, Home-/compact-, Expanded-Attempt- und Stop-Capture. Offen bleiben Lock Screen, `minimal`, deaktivierte Live Activities und No-Dynamic-Island-Geraete.
- **Live-Session-Restore**: Fehl-Persistenz fuer unterbrochene Sessions ist per Codefix + Regressionstests gehaertet; daraus wird bewusst kein neuer Hardware-Claim abgeleitet. Offene Hardware-Verifikation fuer Live Activity / Dynamic Island bleibt unveraendert.
- **Aktueller Device-Status (2026-04-30)**: Der fruehere Trust-Blocker fuer `de.roeber.LH2GPXWrapper.UITests.xctrunner` ist fuer das verbundene `iPhone 15 Pro Max` manuell behoben; echte Device-Laeufe sind wieder moeglich. Alle 5 Live-Activity-Capture-Tests sind auf echter Hardware gruen (2026-04-30). Lock Screen, `minimal`, deaktivierte Live Activities und No-Dynamic-Island-Geraete bleiben weiterhin ohne neuen echten Nachweis offen.
- **Landscape auf allen Tabs**: kompaktes Landscape-Layout nicht systematisch auf Device verifiziert

#### Historischer Incident (nicht aktueller Upload-Blocker)

- **Xcode Cloud Build 34 – Root Cause: NFD/NFC-Normalisierungsmismatch in Designated Requirement**

  Vollständige IPA-Forensik (IPA: `LH2GPXWrapper 1.0 app-store-4`, Build 34) ergibt:

  | Prüfpunkt | Ergebnis |
  |---|---|
  | Signing Authority | Apple Distribution: Sebastian Röber ✅ |
  | Provisioning Profile | iOS Team Store ✅ |
  | application-identifier App | XAGR3K7XDJ.de.roeber.LH2GPXWrapper ✅ |
  | application-identifier Widget | XAGR3K7XDJ.de.roeber.LH2GPXWrapper.Widget ✅ |
  | App Groups | group.de.roeber.LH2GPXWrapper (App + Widget) ✅ |
  | Entitlements | vollständig korrekt ✅ |
  | Run Script Build Phases | KEINE vorhanden ✅ |
  | `codesign --verify` | valid on disk ✅ |
  | `codesign --verify --strict` | does not satisfy its designated Requirement ❌ |

  **Bewiesene Ursache:** Designated Requirement enthält CN in Unicode NFD (`6f cc 88` = o + U+0308),
  tatsächliches Zertifikat hat CN in NFC (`c3 b6` = U+00F6 ö prekomponiert).
  Byte-Vergleich scheitert. Xcode Cloud / macOS Security Framework normalisiert CN zu NFD beim Einbetten der DR.
  Apple's Upload-Validator prüft mit `--strict` → "Code failed to satisfy specified code requirement(s)".

  **Ausgeschlossen:** Repo-Signing-Konfiguration, App ID, App Group, Profile, Entitlements — alle korrekt.

  **Fix (manuell, kein Repo-Eingriff nötig):**
  1. appleid.apple.com → persönliche Daten → Namen auf `Sebastian Roeber` ändern
  2. Xcode.app → Settings → Accounts → Distribution-Zertifikat revoken + neu erzeugen
  3. Xcode Cloud Clean Build starten
- Privacy Policy URL in App Store Connect: `https://dev-roeber.github.io/iOS-App/privacy.html` — eingetragen (2026-04-30)
- Support URL in App Store Connect: `https://dev-roeber.github.io/iOS-App/support.html` — eingetragen (2026-04-30)
- Marketing URL / GitHub Pages: `https://dev-roeber.github.io/iOS-App/` — live, HTTP 200 verifiziert (2026-04-30); `support.html` und `privacy.html` ebenfalls HTTP 200
- finales App Icon (aktuell Interimsdesign)
- Apple-Review-Bestaetigung fuer NSPrivacyCollectedDataTypes (optionaler Live-Upload)
- iPad-Screenshots sind fuer v1 nicht relevant, solange `TARGETED_DEVICE_FAMILY = 1` bleibt; iPad-Support spaeter mit eigenem Test-/Screenshot-Set
- App-Store-Screenshots in App Store Connect hochladen: Assets lokal bereit (6×1290×2796 px, `iphone-67/`), ASC-Upload manuell ausstehend
- App-Review-Feedback fuer Build `52` beobachten und repo-wahr nachtragen; kein proaktives Nachreichen von `57` ohne neuen harten Grund
- Live Activity / Dynamic Island auf echter Hardware weiter vervollstaendigen: Lock Screen, `minimal`, weitere Primärwerte und Fallback-Pfade

---

## Statusstand 2026-04-13 — Apple-Developer-Basis + Xcode Cloud Setup

### Verifikation 2026-04-13

#### ✅ real eingerichtet / verifiziert (2026-04-13)

- **UITests Bundle ID bereinigt**: `xagr3k7xdj.de.roeber.lh2gpxwrapper.uitests` → `de.roeber.LH2GPXWrapper.UITests` (beide Konfigurationen Debug + Release in `project.pbxproj`) — Commit `d50dac3`
- **Bundle IDs konsistent**: Main `de.roeber.LH2GPXWrapper`, Widget `de.roeber.LH2GPXWrapper.Widget`, Tests `de.roeber.LH2GPXWrapperTests`, UITests `de.roeber.LH2GPXWrapper.UITests`
- **`.xcode-version`**: `26.3` in `wrapper/` — Xcode Cloud Version gepinnt
- **`ci_scripts/`**: erstellt unter `wrapper/ci_scripts/`, alle 3 Scripts ausführbar mit korrekten Xcode-Cloud-Namen: `ci_post_clone.sh`, `ci_pre_xcodebuild.sh` (Build-Nummern-Injektion), `ci_post_xcodebuild.sh` — Commit `d50dac3` + Korrektur `ci_pre_build.sh→ci_pre_xcodebuild.sh`
- **Xcode Cloud Runbook**: erstellt unter `docs/XCODE_CLOUD_RUNBOOK.md` (inkl. Hinweis auf gültige Skriptnamen)
- **Xcode Cloud Kompatibilität geprüft**: lokale SPM-Abhängigkeit (`relativePath = ".."`) ist Xcode-Cloud-kompatibel; `PBXFileSystemSynchronizedRootGroup` schließt `PrivacyInfo.xcprivacy` automatisch ein (kein expliziter pbxproj-Eintrag nötig)
- **Falsche Deployment-Target-Doku behoben**: `TESTFLIGHT_RUNBOOK.md` sagte `iOS 26.2` statt korrekter `16.0 / 16.2`
- **Veraltete Repo-Pfade bereinigt**: historische Altpfade wurden auf das aktive Repo `dev-roeber/iOS-App` umgestellt; einzelne alte Kommandopfad-Beispiele unten bleiben nur als Historie stehen
- **swift test**: 616 Tests, 0 Failures — `xcodebuild generic/platform=iOS`: BUILD SUCCEEDED

#### ⚠️ manuelle Apple-Schritte (blocking für Xcode Cloud Start)

1. **Historischer Stand 2026-04-13:** Xcode Cloud Workflow war damals noch manuell anzulegen; Stand 2026-04-29 ist `Release – Archive & TestFlight` inzwischen erstellt
2. **App ID registrieren**: `de.roeber.LH2GPXWrapper` + Capabilities: App Groups, Background Modes (Location)
3. **App Group registrieren**: `group.de.roeber.LH2GPXWrapper` im Developer Portal
4. → Details: `docs/XCODE_CLOUD_RUNBOOK.md`

## Statusstand 2026-04-12 — Device Smoke-Test + Widget Privacy Manifest

### Verifikation 2026-04-12

Ausgefuehrt auf: macOS, Xcode 26.3, iPhone 15 Pro Max (UDID 00008130-00163D0A0461401C)

#### ✅ real verifiziert (2026-04-12)

- **Device Smoke-Test**: App `de.roeber.LH2GPXWrapper` auf iPhone 15 Pro Max installiert, gestartet, PID 29955 stabil — kein Crash
- **Widget Privacy Manifest**: `wrapper/LH2GPXWidget/PrivacyInfo.xcprivacy` erstellt und im `.xcodeproj` verankert (UUID 176C3AD213714BC7AC963476); UserDefaults CA92.1 deklariert, `NSPrivacyTracking: false`
- **ZIPFoundation 0.9.20 Privacy Manifest**: vorhanden (FileTimestamp 0A2A.1) — kein eigener Handlungsbedarf
- **Signing** (Team XAGR3K7XDJ, Automatic): funktioniert fuer Device-Build
- **Store-Archive-Pfad**: `wrapper/LH2GPXWrapper.xcodeproj` (Wrapper-Scheme), nicht SPM-Scheme
- `swift test` (macOS): 606 Tests, 0 Failures, 0 Skips (Stand 2026-04-12 nach Build-Fix-Batch mit 6 gepatchten Dateien)

## Statusstand 2026-04-02 — Apple-Device-Verifikation nach Performance-Fix

### Mac + Xcode + iPhone Verifikation (2026-04-02)

Ausgefuehrt auf: macOS, Xcode 26.3, iPhone 15 Pro Max (iOS 26.3), iPhone Air (iOS 26.3.1)

#### ✅ real verifiziert (2026-04-02)

- `xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build`: BUILD SUCCEEDED
- `xcodebuild -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build`: BUILD SUCCEEDED
- `xcodebuild archive -scheme LH2GPXWrapper -destination 'generic/platform=iOS'`: ARCHIVE SUCCEEDED (TestFlight-Archiv lokal erzeugbar; Upload erfordert App Store Connect)
- `swift test`: 586 Tests, 0 Failures (Stand 2026-04-12)
- `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build`: BUILD SUCCEEDED inkl. eingebettetem Widget (Stand 2026-04-12)
- `make deploy` im Wrapper: Build, Install und Launch auf `iPhone_15_Pro_Max` und `iPhone_12_Pro_Max` erfolgreich (Stand 2026-04-12)
- PrivacyInfo.xcprivacy vorhanden und technisch konsistent mit aktuellem App-Verhalten (UserDefaults CA92.1 deklariert, `NSPrivacyCollectedDataTypePreciseLocation` fuer optionalen Live-Upload eingetragen, `NSPrivacyTracking: false`)
- Device-Launch auf iPhone 15 Pro Max: `testLaunch` gruен
- Device-Smoke-Test `testDeviceSmokeNavigationAndActions` auf iPhone 15 Pro Max: PASSED (44s)
  - Load Demo Data: App startet sauber, Demo-Daten laden ohne Crash
  - Overview → Heatmap-Sheet: oeffnet real, schliesst sauber
  - Insights → Share-Button: Share-Sheet erscheint real (ImageRenderer-Pfad ausgeloest)
  - Export-Tab → Export-Action-Button: fileExporter wird real ausgeloest (koordinatenbasierter Tap selektiert Tag, export.action.primary ist enabled und loest System-Datei-Sheet aus)
  - Live-Tab → Start/Stop Recording: Location-Permission-Prompt erscheint, Recording startet und stoppt sauber
- Live-Activity-Hardware-Capture auf iPhone 15 Pro Max (`iOS 26.4`): 4/5 PASSED
  - `testLiveActivityHardwareCaptureDistance`: PASSED
  - `testLiveActivityHardwareCaptureDuration`: PASSED
  - `testLiveActivityHardwareCapturePoints`: PASSED
  - `testLiveActivityHardwareCaptureUploadStatusFailed`: PASSED
  - `testLiveActivityHardwareCaptureUploadStatusPendingAndRestart`: PASSED (2026-04-30, nach Bugfix; 62 s)
- Wrapper-Auto-Restore mit deterministischem Launch-Reset via `LH2GPX_UI_TESTING` + `LH2GPX_RESET_PERSISTENCE` verifiziert
- Signing/Bundle Identifier/Provisioning: ohne Fehler fuer Device-Build und Archiv
- **Background-Recording auf echtem iPhone: auf realem Gerät verifiziert (2026-04-02)** — Permission-Upgrade auf Always, Aufnahme im Hintergrund, Stop/Persistenz auf echtem Device geprüft und bestätigt
- **Upload-End-to-End zum eigenen HTTPS-Server auf echtem Gerät: per realem Device-Test bestätigt (2026-04-02)** — optionaler nutzergesteuerter Upload an eigenen Server auf echtem iPhone erfolgreich durchgelaufen

#### ⚠️ technisch offen (nicht moeglich ohne manuelle Session oder Apple-Account)

- TestFlight-Upload und Beta-Verifikation: Archiv existiert lokal, Upload erfordert App Store Connect-Zugang
- Finaler App Store Review: nicht lokal simulierbar

#### ❌ offen (Apple-Review / Store-Policy)

- Apple-Review-Bestaetigung fuer die bereits eingetragene `NSPrivacyCollectedDataTypePreciseLocation`-Deklaration des optionalen Live-Uploads steht weiter aus
- Datenschutzrichtlinien-URL fuer App Store Connect: eingetragen (2026-04-30)
- Support-URL fuer App Store Connect: eingetragen (2026-04-30)

## Statusstand 2026-04-01

### Repo-Verifikation (Linux-only, ohne Apple-Hardware)

Dieser Audit-Block basiert ausschließlich auf Quellcode- und Dokumentationsanalyse auf dem Linux-Host. `xcodebuild` ist hier nicht verfügbar.

#### ✅ repo-verifiziert (Stand 2026-04-01)

- Info.plist im Wrapper enthält `NSLocationWhenInUseUsageDescription` mit App-Store-tauglichem Text
- Info.plist im Wrapper enthält `NSLocationAlwaysAndWhenInUseUsageDescription` mit App-Store-tauglichem Text
- `UIBackgroundModes=location` ist in Info.plist deklariert
- PrivacyInfo.xcprivacy ist unter `wrapper/LH2GPXWrapper/PrivacyInfo.xcprivacy` vorhanden
- PrivacyInfo.xcprivacy erklärt `NSPrivacyTracking: false` und leere `NSPrivacyTrackingDomains`
- PrivacyInfo.xcprivacy erklärt `NSPrivacyAccessedAPITypes: [UserDefaults CA92.1]`
- Server-Upload ist standardmäßig deaktiviert (`isEnabled: false` in `LiveLocationServerUploadConfiguration`)
- Server-Upload erfordert explizite Nutzerkonfiguration: URL muss eingetragen werden
- HTTPS wird für nicht-localhost-Endpunkte im Code erzwungen (`endpointURL`-Getter)
- Bearer-Token wird im Keychain gespeichert, nicht in UserDefaults
- `defaultTestEndpointURLString = ""` — kein hart kodierter Testendpunkt im Code
- Nur akzeptierte Live-Recording-Punkte (Lat/Lon/Timestamp/Accuracy) werden übertragen
- Keine Analytics, kein Ad-Tracking, kein Cloud-Sync für importierte History
- `swift test`: 586 Tests, 0 Failures (2026-04-12; dieser Alt-Block wurde nachgezogen)

#### ⚠️ benötigt Apple-Hardware/Xcode

- Frischer `xcodebuild archive` und `xcodebuild test` für den aktuellen konsolidierten Repo-Stand
- Verifikation, ob `NSPrivacyCollectedDataTypes` in PrivacyInfo.xcprivacy für den optionalen Server-Upload ergänzt werden muss (Apple Review-Entscheidung)
- Verifikation ob ZIPFoundation-Abhängigkeit eigene Privacy-Manifest-Anforderungen mitbringt (file-timestamp-Zugriffe)
- Live-Location-Permission-Flow auf echtem Gerät oder Simulator (WhenInUse → AlwaysAllow)
- Heatmap-Sheet öffnen und visuell/performanceseitig verifizieren
- Neuer `Live`-Tab mit Status-Chips, Quick Actions und Upload-Zuständen funktional durchbedienen
- Neue `Insights`-Segmente auf echtem Gerät auf Lesbarkeit prüfen
- Wrapper-Auto-Restore kontrolliert verifizieren (Positiv-, Datei-fehlt-, Clear-Pfad)

#### ❌ offen (Apple-Review / Store-Policy)

- Apple-seitige Scope-/Review-Einordnung für den optionalen Server-Upload: Apple entscheidet, ob das Datentypen-Deklaration in `NSPrivacyCollectedDataTypes` erfordert
- Datenschutzrichtlinien-URL für App Store Connect: eingetragen (2026-04-30)
- Support-URL für App Store Connect: eingetragen (2026-04-30)
- TestFlight-Upload und Beta-Verifikation (erfordert App Store Connect-Zugang)
- Finaler App Store Review (kann nicht lokal simuliert werden)

## Statusstand 2026-03-31

### Wichtige Einschraenkung

Der Verifikationsstand vom 2026-03-17 basiert auf einem aelteren Repo-Stand (vor den 2026-03-18/19/20-Commits). Die seither hinzugekommenen Features (Live-Tab, Heatmap, Background-Recording, Server-Upload) sind auf Apple-Hardware nicht separat verifiziert.

Der frische Host-Nachweis dieses Audits ist Linux-only: `swift test` lief am 2026-03-31 mit `228` Tests, `2` Skips und `0` Failures. `xcodebuild` ist auf diesem Linux-Host nicht verfuegbar; aus diesem Audit stammen deshalb keine neuen Apple-CLI- oder Device-Claims.

Die Apple-CLI-/Device-Nachweise vom 2026-03-30 bleiben als historische Nachweise dokumentiert. Diese Gruen-Aussagen gelten nur fuer die damals protokollierten CLI-Builds/-Tests; sie ersetzen weiterhin keine frische Device-End-to-End-Verifikation der spaeter hinzugekommenen Features.

Apple Device Verification Batch 1 (2026-03-30) hat zusaetzlich einen echten iPhone-Teilbefund geliefert:

- verbundenes Geraet: `iPhone 15 Pro Max` (`iPhone16,2`), iOS `26.3 (23D127)`, via USB verfuegbar und entsperrt
- `xcodebuild test -allowProvisioningUpdates -project /Users/sebastian/Code/LH2GPXWrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'id=00008130-00163D0A0461401C' -only-testing:LH2GPXWrapperUITests` lief gegen dieses Geraet real an
- `LH2GPXWrapperUITestsLaunchTests.testLaunch` lief auf dem echten iPhone erfolgreich durch
- `LH2GPXWrapperUITests.testAppStoreScreenshots` scheiterte nicht an Launch oder Signing, sondern daran, dass der erwartete `Demo Data`-Button im realen Startzustand nicht vorhanden war
- der zugehoerige Accessibility-Snapshot zeigte einen bereits wiederhergestellten Import (`Imported file: location-history.zip`) im Uebersichtsbildschirm sowie sichtbare Einstiege fuer `Heatmap` und den dedizierten `Live`-Tab
- daraus folgt: Device-Launch, sichtbarer Auto-Restore und die grundsaetzliche Praesenz von `Heatmap`/`Live` sind jetzt teilbelegt; Oeffnen und funktionales Durchlaufen dieser Pfade bleibt offen

Heatmap UX Batch 1 (2026-03-30) hat danach nur Display-/Bedienungsdetails des Heatmap-Sheets veraendert:

- lokale Controls fuer Deckkraft, Radius-Presets, `Auf Daten zoomen` und eine kleine Dichte-Legende
- ruhigere Darstellung auf mittleren/grossen Zoomstufen sowie kompaktere Sheet-Chrome
- fuer diese UX-Aenderungen existiert in diesem Batch bewusst kein neuer Apple-Device-Nachweis; der Heatmap-Device-Status bleibt deshalb offen

Heatmap Visual & Performance Batch 2 (2026-03-30) hat den Renderer danach strukturell umgestellt:

- geglaettete aggregierte Polygon-Zellen statt sichtbar ueberlappender Einzelkreis-Stempel
- viewport-basierte Zellselektion mit per-LOD begrenzten sichtbaren Elementen
- wiederverwendbarer Viewport-Cache fuer ruhigere Zoom-/Pan-Reaktionen
- zwei kleine Heatmap-Regressionstests fuer Aggregation und viewport-/limit-respektierende Sichtbarkeit
- fuer diese Rendering-/Performance-Aenderungen existiert in diesem Batch bewusst ebenfalls kein neuer Apple-Device-Nachweis; der Heatmap-Device-Status bleibt offen

Heatmap Color / Contrast / Opacity Batch 3 (2026-03-30) hat danach nur die visuelle Schicht des neuen Renderers nachgeschaerft:

- staerkeres nichtlineares Deckkraft-Mapping, damit 100 % im Slider sichtbar voller wirkt
- weich interpolierte Farbpalette statt grober Farbstufen
- angehobene Intensitaetskurve fuer besser sichtbare mittlere/hohe Dichte
- drei kleine Logiktests fuer Intensitaets-Lift, High-End-Opacity und waermer werdende Palette
- auch fuer diese Farb-/Kontrast-Aenderungen existiert in diesem Batch bewusst kein neuer Apple-Device-Nachweis; der Heatmap-Device-Status bleibt offen

Der spaetere Live-/Upload-/Insights-/Days-Batch vom 2026-03-30 hat zusaetzlich produktnahe UI-/State-Aenderungen gebracht:

- `Days` sortiert jetzt standardmaessig `neu -> alt`
- der dedizierte `Live`-Tab wurde mit neuer Kartenhierarchie, Status-Chips, Quick Actions und mehr Live-Metriken deutlich ausgebaut
- der optionale Server-Upload zeigt jetzt Queue-, Failure- und Last-Success-Zustaende sowie Pause/Resume und manuellen Flush
- die Insights-Seite bietet jetzt segmentierte Oberflaechen (`Overview`, `Patterns`, `Breakdowns`) mit KPI-Karten, Highlight-Karten, `Top Days` und Monatstrends
- fuer diesen Batch liegen auf dem Linux-Server nur gezielte `swift test --filter Live|Insight|Day|Upload`-Laeufe vor; ein neuer Apple-Device-Nachweis existiert dafuer bewusst noch nicht

### Bereits real verifiziert (2026-03-17, vor Post-2026-03-18-Features)

- [x] Xcode-Schemes aus dem Swift Package sind ueber das echte Xcode sichtbar
- [x] `LocationHistoryConsumerApp` baut fuer `platform=macOS` (2026-03-17; nach Apple Stabilization Batch 1: macOS-Build-Fehler behoben, Wrapper-iOS-Build gruen)
- [x] das gebaute App-Shell-Binary startet sichtbar in einer echten foreground-App-Session
- [x] `Load Demo Data`
- [x] `Open location history file`
- [x] `Open Another File` ersetzt bestehenden Inhalt
- [x] `Clear` / Reset
- [x] invalides JSON mit erhaltenem letztem gueltigen Inhalt
- [x] echter Zero-Day-Export / no days
- [x] Day-Liste und Day-Detail als echter UI-Durchgang

### Seit Phase 13 zusaetzlich verifiziert

- [x] reproduzierbarer foreground-Launch via `scripts/run_app_shell_macos.sh` (standardisiertes .app-Bundle statt ad-hoc-Wrapper)

### Historischer Apple-CLI-Stand (2026-03-30)

- [x] `swift build --target LocationHistoryConsumerAppSupport` laeuft fehlerfrei auf macOS
- [x] `swift build` (alle Targets) laeuft fehlerfrei auf macOS
- [x] `swift test` lief auf macOS durch: 224 Tests, 0 Failures
- [x] `xcodebuild test -scheme LocationHistoryConsumer-Package -destination 'platform=macOS'` lief auf macOS durch: 224 Tests, 0 Failures
- [x] `xcodebuild build -scheme LH2GPXWrapper -destination generic/platform=iOS` erfolgreich
- [x] `xcodebuild -list` (Wrapper Package Resolution) erfolgreich
- [x] `xcodebuild test -project /Users/sebastian/Code/LH2GPXWrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -only-testing:LH2GPXWrapperTests` erfolgreich
- [x] manueller Xcode-Start auf dem verbundenen iPhone liegt als separater positiver Teilbefund vor; er ersetzt keine CLI-Aussage
- [x] Wrapper-Launch auf echtem iPhone 15 Pro Max via XCUITest-Runner erneut belegt (`LH2GPXWrapperUITestsLaunchTests.testLaunch`)

### Noch offen

- [ ] frischen Apple-CLI-Gegenlauf fuer den aktuellen konsolidierten Repo-Stand auf einem Apple-Host nachziehen; auf diesem Linux-Host nicht moeglich
- [ ] foreground-Run explizit ueber `Product > Run` in Xcode selbst noch einmal separat bestaetigen, falls genau dieser IDE-spezifische Laufweg regressionskritisch wird
- [ ] Live-Location-/Permission-Flow inklusive optionaler `Always Allow`-Erweiterung fuer Background-Recording in einer echten Apple-UI-Session verifizieren und separat protokollieren; dabei den seit 2026-04-12 gegateten Startpfad (`awaitingAlwaysUpgrade` -> `recording`) explizit mitpruefen
- [ ] den dedizierten `Live`-Tab auf iPhone/iOS 17+ funktional verifizieren; Sichtbarkeit im realen AX-Snapshot ist belegt, echte Interaktion noch nicht
- [ ] das Heatmap-Sheet fuer importierte History auf Apple-Hardware visuell und performanceseitig verifizieren; der Einstieg ist im realen AX-Snapshot sichtbar, das Sheet selbst noch nicht geoefnet, und die spaeter hinzugekommenen UX-Controls, der neue Aggregations-/Polygon-Renderer sowie das Batch-3-Farb-/Kontrast-Mapping sind auf Device ebenfalls noch nicht separat bestaetigt
- [ ] die neue `Days`-Default-Sortierung (`neu -> alt`) in compact und regular auf Apple-Hardware funktional bestaetigen
- [ ] den deutlich ausgebauten `Live`-Tab auf Apple-Hardware funktional bestaetigen, inklusive Status-Chips, Quick Actions und erweitertem Stat-Set
- [ ] die neue Dynamic-Island-Konfiguration auf Apple-Hardware fertig pruefen: echte Capture-Laeufe fuer `Distanz`, `Dauer`, `Punkte` und `Upload-Status (failed)` sind auf `iPhone 15 Pro Max` (`iOS 26.4`) repo-wahr belegt; offen bleiben Lock Screen, `minimal`, deaktivierte / nicht verfuegbare Live Activities, No-Dynamic-Island-Geraete sowie der fehlgeschlagene Pending-/Restart-Pfad
- [ ] die neue segmentierte Insights-Oberflaeche (`Overview`, `Patterns`, `Breakdowns`) auf Apple-Hardware auf Lesbarkeit und Navigation pruefen
- [x] **Background-Recording auf echtem iPhone verifiziert (2026-04-02)** — Permission-Upgrade auf Always, Aufnahme im Hintergrund, Stop/Persistenz: auf realem Gerät bestätigt
- [x] **Upload-End-to-End zum eigenen Server auf echtem iPhone verifiziert (2026-04-02)** — optionaler nutzergesteuerter HTTPS-Upload: per realem Device-Test bestätigt
- [ ] Wrapper-Auto-Restore nach Reaktivierung (2026-03-20) kontrolliert mit Positiv-, Datei-fehlt- und Clear-Pfad auf echtem Device nachweisen; ein spontaner positiver Restore-Befund liegt jetzt vor

## Reale Apple-UI-Session 2026-03-17

- Host: macOS 15.7 (`24G222`)
- Xcode: 26.3 (`Build version 17C529`)
- `xcode-select -p`: `/Applications/Xcode.app/Contents/Developer`
- Swift unter echtem Xcode: `Apple Swift version 6.2.4`
- Apple-CLI-Schritte wurden weiterhin explizit mit `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` gefahren
- fuer die echte interaktive UI-Verifikation wurde das gebaute SwiftPM-App-Binary als foreground-App gestartet; seit Phase 13 ist dieser Schritt ueber `scripts/run_app_shell_macos.sh` standardisiert (baut, wrapped in minimales .app-Bundle, startet per `open`)
- diese Session predatiert spaetere 2026-03-20-Features wie Heatmap-Sheet, dedizierten `Live`-Tab und Upload-Batching; dafuer existiert hier absichtlich noch kein Apple-Haken
- verifizierte UI-Dateien:
  - Demo: gebuendelte `golden_app_export_sample_small.json`
  - gueltiger Import: lokale Kopie von `Fixtures/contract/golden_app_export_sample_small.json`
  - invalid: lokale Datei `lh2gpx_invalid.json` mit kaputter JSON
  - no-days: `Fixtures/contract/golden_app_export_no_days_zero.json` bzw. lokale Kopie davon fuer den nativen Dateiimporter

## Konkrete Pruefschritte

### 1. Build in Xcode

- Schritt:
  - `LocationHistoryConsumerApp` waehlen
  - `My Mac` waehlen
  - `Product > Build`
- Erfolg gilt als:
  - Build endet ohne Fehler
  - kein zusaetzliches Xcode-Projekt oder Feature-Scope ist noetig
- Status 2026-03-17:
  - verifiziert

### 2. App-Start

- Schritt:
  - foreground-App starten
- Erfolg gilt als:
  - App startet in den import-first Leerlaufzustand
  - kein sofortiger Crash
- Status 2026-03-17:
  - verifiziert
  - sichtbarer Startscreen mit `Import your location history` real bestaetigt
  - kein Crash
  - Hinweis: der spezifische IDE-Lauf `Product > Run` wurde in dieser Phase nicht noch einmal separat als foreground-Nachweis festgehalten

### 3. Open location history file

- Schritt:
  - `Open location history file` klicken
  - z. B. `Fixtures/contract/golden_app_export_sample_small.json` waehlen
- Erfolg gilt als:
  - Status `Location history loaded` oder `Google Timeline loaded`
  - Quelle `Imported file: <dateiname>.json`
  - Overview, Day-Liste und Day-Detail sichtbar
- Status 2026-03-17:
  - verifiziert
  - echte lokale Datei ueber den nativen Apple-Dateiimporter geoeffnet
  - aktive Quelle zeigte `Imported file: lh2gpx_valid_small.json`
  - Overview, Day-Liste und Day-Detail waren sichtbar

### 4. Demo laden

- Schritt:
  - `Load Demo Data` klicken
- Erfolg gilt als:
  - Status `Demo data loaded`
  - Quelle `Demo fixture: golden_app_export_sample_small.json`
  - zwei Demo-Tage sichtbar
- Status 2026-03-17:
  - verifiziert
  - aktive Quelle und Toolbar-Aktionen wechselten wie erwartet
  - Day-Liste zeigte real `2024-05-01` und `2024-05-02`

### 5. Clear / Reset

- Schritt:
  - nach geladenem Inhalt `Clear` klicken
- Erfolg gilt als:
  - Rueckfall auf `No location history loaded`
  - Quelle `None`
  - Startbuttons wieder sichtbar
- Status 2026-03-17:
  - verifiziert
  - Rueckfall auf `Import your location history` und `No location history loaded` real bestaetigt

### 6. Fehlerfall mit ungueltiger JSON

- Schritt:
  - lokale Datei mit kaputtem JSON importieren
- Erfolg gilt als:
  - Fehlerzustand `Unable to open file`, `Unsupported file format` oder `File could not be opened`
  - bei vorhandenem Inhalt bleibt letzter gueltiger Stand sichtbar
- Status 2026-03-17:
  - verifiziert
  - Fehlerkarte fuer den jeweiligen Importfehler erschien real
  - Meldung fuer den konkreten Decoder-/Formatfehler erschien real
  - letzter gueltiger importierter Inhalt blieb sichtbar

### 7. Leerer Export / no days

- Schritt:
  - no-days-geeignete Exportdatei laden
- Erfolg gilt als:
  - Overview bleibt sichtbar
  - Day-Liste zeigt `No Days Available`
  - Detailbereich bleibt im no-days-Zustand
- Status 2026-03-17:
  - verifiziert
  - echte Zero-Day-Fixture `golden_app_export_no_days_zero.json` verwendet
  - Day-Liste zeigte `No Days Available`
  - Detailbereich zeigte `No Day Details Available`
  - Statuskarte erklaerte, dass aktuell keine Day-Entries vorhanden sind

### 8. Darstellung Day-Liste / Day-Detail

- Schritt:
  - mit Demo oder importierter Datei durch die Liste navigieren
- Erfolg gilt als:
  - Day-Auswahl reagiert
  - Detailbereich zeigt Daten fuer den gewaehlten Tag
  - keine neue Business-Logik wird dafuer benoetigt
- Status 2026-03-17:
  - verifiziert
  - Demo- und Import-Zustand zeigten reale Day-Listen
  - Detailbereich fuer den initial selektierten Tag war real sichtbar
  - Fehler- und no-days-Zustaende liessen die Detailflaeche nachvollziehbar in sinnvolle Apple-UI-Leerzustaende wechseln
