# LH2GPX iOS-App Deep Audit — Post Pull Truth Sync

**Auditor:** Claude Code (Opus 4.7 / 1M).
**Datum:** 2026-05-12 21:30–21:45 CEST.
**Repo:** `dev-roeber/iOS-App` (Monorepo).
**Vorheriger Audit:** `docs/DEEP_AUDIT_2026-05-12.md` (auf damaligem Worktree-HEAD `ae5de1f` erstellt — vor dem 30-Commit-Pull dieses Audits).
**Diese Datei:** **Nachgereichter Post-Pull-Audit** auf HEAD `30015c9` (`ae5de1f` + 30 Remote-Commits + lokaler Keychain-Hardening-Commit).

## 1. Executive Summary

- **Gesamtzustand:** SwiftPM-Code-Basis ist sauber, vollständig getestet (Mac `swift test`: **1518 / 4 skipped / 0 failures**, 105.9s), Privacy/Security-Hygiene auf App-Store-Niveau, keine 3rd-Party-Tracking-SDKs, P1 Keychain-Hardening drauf.
- **Release-/App-Store-Einschätzung:** **Nicht freigegeben.** Ein **echter neuer Release-Blocker (P0)** wurde gefunden: `xcodebuild` für den Wrapper-iOS-Build (`-destination generic/platform=iOS`) und für den Device-Build (`-destination id=…401C`) **bricht** mit `Undefined symbols for architecture arm64: _sqlite3_*` im `LH2GPXWidget.appex`-Linkschritt. Pre-existing auf `origin/main` (verifiziert auf `799adc5`); vom Phase-10-Train durch unbedingten `CSQLite`-Linux-Shim-Dep in `Package.swift` eingeführt. Mein Keychain-Commit ist **nicht** der Verursacher. Mac-SwiftPM-Build geht weiter durch, weil dort der SDK-eigene `SQLite3` via `canImport(SQLite3)` greift; Xcode Cloud für iOS würde aber genauso scheitern.
- **Echte Blocker:** (1) der Wrapper-iOS-Build (CSQLite-Linker-Bug), (2) das weiterhin offene Manual Risk Acceptance Protocol (46-MB-Hardware-Retest, Live Activity / Dynamic Island / Lock Screen, iPad-Layout, ASC/TestFlight/Apple Review).
- **Risiken (nicht-Blocker):** Auskommentiertes `kSecAttrAccessible…UntilFirstUserAuthentication`/`completeUnlessOpen` für SQLite-Store (relevant erst wenn `LH2GPX_LOCAL_TIMELINE_STORE` default ON wird — aktuell OFF), ZIP-Pfad-Memory-Regression im Store-Pfad, Doku-Drift mehrerer Stand-Header/HEAD-Anker/Test-Zahlen.
- **Teststatus:** Mac-SwiftPM grün. xcodebuild iOS rot. Linux nicht gefahren (Audit-Host ist macOS).
- **Empfehlung:** Vor TestFlight-Submit: (a) `Package.swift`-Fix für CSQLite-Conditional (1-Zeiler), (b) Hardware-Retest 46-MB-Crashfall.

## 2. Git-/Repo-Truth

| Feld | Wert |
|---|---|
| Branch | `main` |
| Start-HEAD vor Pull | `ae5de1f` (2026-05-07, fix: reduce memory peak after large timeline import) |
| Remote-HEAD vor Pull | `799adc5` (2026-05-12, docs: add deep audit 2026-05-12) |
| HEAD nach Pull/Rebase | `30015c9` (2026-05-12, fix: set keychain accessibility and sync repo truth docs) |
| Distanz | 30 Commits seit `ae5de1f`, mein Commit obendrauf |
| Working Tree | clean |
| Push-Status | **noch nicht gepusht** (vor diesem Audit-Report); Backup-Branch `backup/keychain-doc-sync-16779b` auf vor-rebase-Commit `16779be` |
| Lokaler Pfad | `/Users/sebastian/Desktop/XCODE/iOS-App` |

Letzte 10 Commits:

```
30015c9 2026-05-12 fix: set keychain accessibility and sync repo truth docs
799adc5 2026-05-12 docs: add deep audit 2026-05-12
aaa31ef 2026-05-09 fix: bound app session projection caches
ec54aba 2026-05-08 fix: gate large in memory imports
354740e 2026-05-08 docs: add deep performance stability map layer audit
d629467 2026-05-08 fix: harden legacy map heatmap preview performance
1270fe6 2026-05-08 feat: optimize local timeline map budgets and point layer
0db6e2a 2026-05-08 feat: wire local timeline import progress ui
3621f05 2026-05-08 feat: add local timeline wal checkpoint recovery
d613f4f 2026-05-08 feat: add cancellable local timeline import progress
```

## 3. Audit-Methode

- 518 getrackte Files insgesamt; 185 Swift in `Sources/`, 153 Swift in `Tests/`, 10 Swift in `wrapper/`, 78 `.md`-Doku-Files.
- Multi-Agent-Aufteilung (parallel):
  - **Agent A** — Doku-Truth-Audit (14 Pflicht-Files + `docs/*.md`, Findings F-01..F-17).
  - **Agent B** — Xcode-/App-Store-/Config-Audit (pbxproj, beide Info.plist, Entitlements, beide PrivacyInfo.xcprivacy, CI-Scripts, Package.swift/.resolved).
  - **Agent C+D** — Code-Audit (Sources + wrapper, ~30 neue Commits klassifiziert, Findings FP-01/ST-01/WR-01/TS-01).
  - **Agent E** — Test-Realität (154 Test-Files, 1538 `func test` gesamt; Findings E1..E5).
  - **Agent F** — Performance/Memory/Import (LocalTimelineStore, BoundedLRU, 64-MiB-Gate, F1..F8).
- Eigene Inline-Reads + Build-/Test-Runs.
- **Grenzen des Audits:** Audit ist Code-/Doku-/SwiftPM-Test-Audit. Nicht geprüft: ASC-Status, TestFlight-Build-Liste, App Review-Status, Hardware-UI-Acceptance, iPad-Layout, Live-Activity-Hardware, Push-Notifications. Hardware-UITests (`testAppStoreScreenshots`, `testLandscapeLayoutSmoke`) wurden in diesem Lauf **nicht** auf Device gefahren (Wrapper-Build bricht).

## 4. Datei-für-Datei-Befunde (Auszüge — vollständige Liste in Sec. 5+8)

| Datei | Zweck | Geprüft gegen | Befund | Aktion |
|---|---|---|---|---|
| `Sources/LocationHistoryConsumerAppSupport/KeychainHelper.swift` | Bearer-Token-Persistenz | Build, Unit-Tests, Code-Read | AfterFirstUnlock im `30015c9`-Commit aktiv (Add + Update-Pfad) | OK |
| `Tests/LocationHistoryConsumerTests/KeychainHelperTests.swift` (NEU) | Keychain-Hardening-Tests | swift test | 4 Tests, 2 davon mit `XCTSkip` auf macOS-Host (kein `pdmn`-Read-Back); Save-Pfad selbst grün | OK |
| `Package.swift` | SwiftPM-Targets | `swift build`, `xcodebuild` | **P0 Bug** — `CSQLite` als unconditional Dep im AppSupport-Target zwingt Widget-Link den Linux-Shim zu suchen, der iOS-Sim/Device nicht hat | P0 |
| `Sources/CSQLite/*` | Linux-pkgConfig-Shim für `libsqlite3` | Code-Read | Nur als Linux-Helfer gedacht; auf iOS sollte SDK `SQLite3` greifen | siehe Package.swift |
| `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStore.swift` | SQLite-disk-first-Store | Code-Read, Tests | Schema v2 + WAL; **Data Protection auskommentiert** (Darwin-Pfad ist No-Op) | siehe S1 |
| `Sources/LocationHistoryConsumerAppSupport/LocalTimelineFileProtection.swift` | iOS Data Protection Helper | Code-Read, Zeile 60–78 | `setAttributes([.protectionKey: .completeUnlessOpen])` ist **Kommentar**, kein Code | P1 |
| `Sources/LocationHistoryConsumerAppSupport/LocalTimelineFeatureFlags.swift` | Feature-Flag-Gate | Code-Read | Zeile 75 `return false` ohne Arg/ENV → Store-Pfad default OFF (bestätigt) | OK |
| `Sources/LocationHistoryConsumerAppSupport/AppContentLoader.swift` | Import-Pipeline | Code-Read | `maximumInMemoryImportBytes = 64 MiB` (Zeile 380); Store-Pfad puffert ZIP-Entry voll in `Data` (Zeile 356–364) → F2 | P1 (nur bei Flag ON relevant) |
| `Sources/LocationHistoryConsumerAppSupport/BoundedLRU.swift` | LRU-Cache | Code-Read | Foundation-only, capacities 8/8/8/8/32/16 in `AppSessionContent` | OK |
| `wrapper/Config/Info.plist` | App-Plist | Read | MARKETING_VERSION `$(MARKETING_VERSION)` (=1.0.1), CFBundleVersion `100`, Location/BG-Modes/Live-Activities korrekt | OK |
| `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj` | Xcode-Projekt | Read | MARKETING_VERSION=1.0.1, CURRENT_PROJECT_VERSION=100 (alle 8 Configs); DEVELOPMENT_TEAM=XAGR3K7XDJ; redundante `INFOPLIST_KEY_*`-Zeilen mit `GENERATE_INFOPLIST_FILE=NO` (Drift-Risiko, kein Bug) | P3 Hygiene |
| `wrapper/LH2GPXWrapper/PrivacyInfo.xcprivacy` | Privacy Manifest | Read | PreciseLocation Linked=false, Tracking=false, Purpose=AppFunctionality; UserDefaults CA92.1 | OK |
| `wrapper/LH2GPXWidget/PrivacyInfo.xcprivacy` | Widget Privacy Manifest | Read | UserDefaults CA92.1, keine CollectedDataTypes | OK |
| `wrapper/LH2GPXWrapper/LH2GPXWrapper.entitlements` | App Entitlements | Read | nur App-Group `group.de.roeber.LH2GPXWrapper` | OK |
| `wrapper/LH2GPXWidget/LH2GPXWidget.entitlements` | Widget Entitlements | Read | identische App-Group | OK |

## 5. Doku-vs-Code-Truth (Auszug der schwersten Drift-Stellen)

Aus Agent A. Konsistenter Anker: Code-Truth ist `pbxproj` (MARKETING_VERSION=1.0.1, CURRENT_PROJECT_VERSION=100). Test-Truth ist heutiger Mac-Lauf: `swift test`=1518/4/0.

| ID | Doku-Datei | Behauptung | Code-/Test-Truth | Aktion in diesem Train |
|---|---|---|---|---|
| F-01 | `NEXT_STEPS.md:1` | Stand-Header HEAD `37a22b7` | HEAD ist `30015c9` (11+ Commits weiter) | Audit-Report ergänzt; Update verschoben in nächsten Doku-Train |
| F-02 | `README.md:56, 79` | Linux 1400/2/0 (`d629467`) als „aktueller Stand" | Mac-Stand `30015c9` = 1518/4/0; Linux-Re-Run für `30015c9` nicht erfolgt | siehe README-Patch unten |
| F-03 | `docs/DEEP_AUDIT_2026-05-12.md:4, 31, 39, 224` | Audit-HEAD `ae5de1f`, pwd `/Users/sebastian/iOS-App` | HEAD `ae5de1f` ist 5 Commits hinter; Pfad ist `/Users/sebastian/Desktop/XCODE/iOS-App` | dieser Post-Pull-Report ist der Ersatz/Add-on |
| F-04 | `docs/DEEP_AUDIT_2026-05-12.md:6, 70, 114` | ASC zeigt Build 167; Repo Build 100 → P0 MISMATCH | pbxproj=100 verifiziert; ASC=167 unbelegt im Repo (Screenshot-Anker) | wird hier als „nicht lokal verifizierbar" zitiert, kein Doku-Edit |
| F-05 | `docs/APPLE_VERIFICATION_CHECKLIST.md:31, 194, 255` | Acceptance-Anker HEAD `b91a933` | ~15 Commits hinter HEAD; aktueller HEAD `30015c9` | Doku-Update verschoben — Hardware-Acceptance-Logs bleiben unter ihrer Original-HEAD-Anker |
| F-06 | `docs/APP_FEATURE_INVENTORY.md:371, 425` | 927 / 1077 Tests (mehrere veraltete Werte) | Mac-Truth 1518; Linux 1400 (per Remote-Doku) | nicht in diesem Train angefasst |
| F-07 | `docs/XCODE_APP_PREPARATION.md:47, 73` | Build 84 Cloud, `swift test` 964 | beide stark veraltet | siehe ASC-Hinweis unten |
| F-08 | `docs/XCODE_CLOUD_RUNBOOK.md:3, 91` | Stand 2026-04-30, Cloud-Build 55–57 | mehrere Cloud-Builds seither, ASC zeigt 167 | nicht in diesem Train angefasst |
| F-11 | `wrapper/docs/TESTFLIGHT_RUNBOOK.md:3, 11` | Stand 2026-05-05, Marketing 1.0, Build 45 | Repo-Truth 1.0.1 / 100 | **Minimal-Patch in diesem Train** |
| F-14 | `docs/ASC_SUBMIT_RUNBOOK.md` | „aktuellster Cloud-Build: 74" | mind. 84, 155–158 dokumentiert, Audit-2026-05-12 sagt 167 | **Minimal-Patch in diesem Train** |
| F-13 | `wrapper/README.md:103, 152, 164` | „Hardware-Acceptance 2026-05-07 PASSED HEAD pending" | „pending" wurde nie befüllt; aktueller HEAD `30015c9` | nicht in diesem Train angefasst |

**Wichtig:** Vollständiger Mass-Doku-Refresh ist ein separater Train. Dieser Audit ist der **Wahrheits-Anker**; punktuelle Patches in TESTFLIGHT_RUNBOOK + ASC_SUBMIT_RUNBOOK + README adressieren die schädlichsten Drift-Stellen.

## 6. Code-Audit (Zusammenfassung)

### Import / Streaming
- Default-Pfad (Flag OFF): Google-Timeline JSON streamt über `GoogleTimelineStreamReader` (256 KB Chunks, `autoreleasepool` umschließt JSONSerialization + Ingest, 64-KB-Element-Cap-Reset). ZIP-Single-Google-Timeline-Entry streamt chunk-weise.
- LH2GPX-JSON / GPX / TCX direkt: `Data(contentsOf:)` mit hartem 64-MiB-Gate (`maximumInMemoryImportBytes`, `AppContentLoader.swift:380`).
- ZIP-non-Google-Pfad (LH2GPX-/GPX-/TCX-in-ZIP) puffert weiterhin volle `Data`; durch 256-MB-Entry-Cap geschützt (`maxSupportedFileSizeBytes`) — **kein 64-MiB-Gate** dahinter (Finding F3-bei-Agent-F, P1 wenn Hardware-Test mit GPX-ZIP > 64 MiB stattfindet).

### Store-backed Surfaces (Feature-Flag `LH2GPX_LOCAL_TIMELINE_STORE`, default OFF)
- `LocalTimelineStore` (SQLite, Schema v2, WAL).
- `StoreBackedMapDataProvider`, `StoreBackedHeatmapDataProvider`, `StoreBackedExportWriter`, `LocalTimelineImportWriter`/`Controller`/`Cancellation`/`Progress`.
- WAL-Checkpoint-Recovery (`bestEffortTruncateWAL`).
- **Data Protection auskommentiert** auf Darwin (`LocalTimelineFileProtection.swift:60–78`) — relevant erst beim Default-ON.
- **ZIP-Store-Pfad puffert vollen Entry** in `Data` (`AppContentLoader.swift:356–364`) — Memory-Regression vs Legacy-Stream.

### Live Tracking / Upload
- Bearer-Token im Keychain mit `kSecAttrAccessibleAfterFirstUnlock` (Hardening live, `KeychainHelper.swift`).
- HTTPS-Enforcement in `AppPreferences.isValidUploadEndpoint` und `LiveLocationServerUploader` (https oder localhost/127.0.0.1/`[::1]`).
- 30s Request-Timeout; 10k-Punkt-Queue-Cap.
- `URLSession.shared.data(for:)` (Apple-Pfad) / `dataTask`-Bridge (Linux-Pfad).
- Kein Token / keine URL / keine Standortdaten in Logs.

### Caches
- `BoundedLRU` capacities 8/8/8/8/32/16 in `AppSessionContent` (`AppSessionState.swift:65–110`). LRU-Eviction, deterministisch, nicht thread-safe.

### Concurrency
- Keine `@unchecked Sendable`. Keine `Task.detached` ohne `[weak self]` in heißen Pfaden (überprüft).
- Keine `fatalError`/`try!`/`as!` (außer 1 Kommentar in GPXImportParser).
- 6 echte Force-Unwraps in `GoogleTimelineConverter` (3), `GPXImportParser` (2), `TCXImportParser` (1) — alle Pattern `dict[key]!.append(...)` nach defensivem Init.

### 3rd-party-Deps
- Nur `dev-roeber/ZIPFoundation @ 0.9.20-devroeber.1` (exact pin, eigener Fork). Keine Tracking/Analytics-SDKs.

## 7. Security / Privacy / App Store Compliance

| ID | Bereich | Befund | Beleg | Risiko | Status |
|---|---|---|---|---|---|
| S1 | iOS Data Protection für SQLite-Store | `setAttributes` ist auskommentiert | `LocalTimelineFileProtection.swift:60–78` | mittel (nur wenn Store-Pfad default ON wird) | **P1 vor Default-ON** |
| S2 | Keychain Accessibility | `AfterFirstUnlock` im `30015c9`-Commit | `KeychainHelper.swift:20–34, 47–82` | — | OK |
| S3 | HTTPS-Enforcement | strict (https oder localhost-IPv4/v6) | `AppPreferences.swift:329–342`, `LiveLocationServerUploader.swift:34–38` | — | OK |
| S4 | Privacy Manifest App | PreciseLocation, Linked=false, Tracking=false, AppFunctionality + UserDefaults CA92.1 | `PrivacyInfo.xcprivacy` (App) | — | OK |
| S5 | Privacy Manifest Widget | UserDefaults CA92.1, keine CollectedDataTypes | `PrivacyInfo.xcprivacy` (Widget) | — | OK |
| S6 | ATS | Keine `NSAllowsArbitraryLoads` Override | Info.plists | — | OK |
| S7 | `ITSAppUsesNonExemptEncryption = false` | konsistent App + Widget | beide Info.plist | — | OK |
| S8 | Location Usage Descriptions | präzise, ehrlich, beschreibt Background-Continuation | `wrapper/Config/Info.plist:23–26, 36–39` | — | OK |
| S9 | UIBackgroundModes `location` | konsistent mit Live Tracking | `wrapper/Config/Info.plist` | — | OK |
| S10 | App Group | beide Targets dieselbe Group | beide Entitlements | — | OK |
| S11 | NSSupportsLiveActivities | true (iOS 16.2 Widget Deployment Target) | `wrapper/Config/Info.plist` | — | OK |
| S12 | URL Scheme `lh2gpx` | registriert + verdrahtet in `AppShellRootView.onOpenURL` | `wrapper/Config/Info.plist:47–57` | — | OK |
| S13 | Keine 3rd-Party-Tracker | grep 0 Treffer Firebase/Sentry/Crashlytics/etc | `Sources/`, `Package.swift` | — | OK |
| S14 | Bearer/Token/URL/Standort in Logs | nicht vorhanden | grep + Code-Read | — | OK |
| S15 | App-Review (3.2-Reject 1.0 → Response → Pending Developer Release; 1.0.1 Cloud-Build 84 grün) | extern in ASC | nicht lokal verifizierbar | mittel — Tester-Bestätigung pending | **offen** |
| S16 | Wrapper-iOS-Build | `xcodebuild` BUILD FAILED (Linker `_sqlite3_*` undefined) | `/tmp/xcb_generic.log:97–280` | **HOCH** | **P0 Release-Blocker** |

## 8. Tests / Builds

| Befehl | Ergebnis | Anzahl/Dauer | Bemerkung |
|---|---|---|---|
| `swift build` (Mac) | **BUILD OK** | 112.6s | Warning: brew-`libsqlite3.dylib` 15.0 vs `-target macosx 13.0`. Linux-Shim-Build-Pfad ohne Funktionsfehler. |
| `DEVELOPER_DIR=Xcode swift test` (Mac) | **PASS** | **1518 Tests, 4 skipped, 0 failures** (105.9s) | matcht Agent-E-Befund (1538 `func test` gesamt, davon 1518 in SwiftPM-Suite) |
| `xcodebuild -scheme LH2GPXWrapper -destination generic/platform=iOS build CODE_SIGNING_ALLOWED=NO` (HEAD `30015c9`) | **BUILD FAILED** | Linker | Undefined symbols `_sqlite3_*` in `LH2GPXWidget.appex` |
| `xcodebuild ... -destination id=00008130-…401C build -allowProvisioningUpdates` (HEAD `30015c9`) | **BUILD FAILED** | Linker | gleiche Wurzel |
| `xcodebuild -destination generic/platform=iOS build` (HEAD `799adc5`, pure origin/main, **ohne** Keychain-Commit) | **BUILD FAILED** | Linker | identische Wurzel — **Bug pre-existing, nicht von Keychain-Commit** |
| Hardware-UITests | **NICHT GEFAHREN** | — | Wrapper-Build bricht; UITests setzen erfolgreichen Build voraus |
| `git diff --check` | clean | — | — |

## 9. Offene Punkte (priorisiert)

### P0

- **P0-1 Wrapper-iOS-Build gebrochen — BEHOBEN am 2026-05-12 in Folge-Commit nach diesem Audit.** Fix: `Package.swift` macht den `CSQLite`-Linux-Shim jetzt conditional über `.target(name: "CSQLite", condition: .when(platforms: [.linux]))`, sodass Apple-Plattformen über den bereits vorhandenen `#if canImport(SQLite3)`-Gate in `LocalTimelineStore.swift` die SDK-`SQLite3` direkt nutzen und der Linker nicht mehr den Linux-pkgConfig-Shim für iOS zieht. **Verifikation:** `swift build` OK (79.2 s), `swift test` 1518/4/0 (111.0 s), `xcodebuild ... -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**, `xcodebuild ... -destination 'id=00008130-00163D0A0461401C' build -allowProvisioningUpdates` **BUILD SUCCEEDED** (signed Device-Build iPhone 15 Pro Max). Ursprünglicher Befund (historisch):
- **P0-1 (historisch)** `xcodebuild build` für `LH2GPXWrapper`-Scheme bricht im LH2GPXWidget-Linkschritt mit `Undefined symbols for architecture arm64: _sqlite3_bind_blob, _sqlite3_bind_double, _sqlite3_bind_int, _sqlite3_bind_null, _sqlite3_bind_text, _sqlite3_bind_zeroblob, _sqlite3_close_v2, _sqlite3_column_*, _sqlite3_errmsg, _sqlite3_exec, _sqlite3_finalize, ...` (siehe `/tmp/xcb_generic.log`).
  **Root Cause-Hypothese:** `Package.swift` hängt `LocationHistoryConsumerAppSupport` an `CSQLite` (Linux-pkgConfig-Shim) ohne `condition: .when(platforms: [.linux])`. Xcode zieht den CSQLite-Target damit auch für iOS in den Link, wo `libsqlite3` nicht via pkgConfig-Pfad verfügbar ist. Die SDK-`SQLite3`-Linkage greift erst, wenn das nicht passiert.
  **Beleg:** Reproduzierbar auf `799adc5` (pure origin/main); identisches Symbol-Set.
  **Risiko:** Xcode Cloud bricht beim Submit. Lokaler Device-Build unmöglich.
  **Empfehlung:** In `Package.swift` AppSupport-Dependency umstellen:
  ```swift
  .target(
      name: "LocationHistoryConsumerAppSupport",
      dependencies: [
          "LocationHistoryConsumer",
          .target(name: "CSQLite", condition: .when(platforms: [.linux])),
          .product(name: "ZIPFoundation", package: "ZIPFoundation"),
      ]
  ),
  ```
  Plus prüfen, ob `import CSQLite` im Code ebenfalls via `#if !canImport(SQLite3)` gegated ist (Agent F notiert dass `LocalTimelineStore.swift:2-6` einen `#if canImport(SQLite3)` Gate hat — d.h. der iOS-Pfad nutzt SDK-SQLite, der Linker zieht aber CSQLite trotzdem rein).
  **Testbedarf:** xcodebuild iOS-Sim + Device + Linux-Swift-Build alle drei grün.

- **P0-2 Manual Release Risk Acceptance Protocol — Hardware-Acceptance-Train 2026-05-12 (HEAD `5f83838`) durchgeführt, Teilstand:**
  - **Sektion 1 (46-MB-Crashfall): BLEIBT FAILED.** Im lokalen Dateisystem wurde keine 46-MB-`location-history.zip` gefunden (einzige Datei dieses Namens unter `/Users/sebastian/Downloads/` ist 4.06 MB groß). Hardware-Retest des Release-Builds mit dem originalen 46-MB-Crash-Sample wurde nicht gefahren.
  - **Sektion 2 (Live Activity / Dynamic Island / Lock Screen): Technischer Pass über die UITest-Suite, manuelle visuelle Lock-Screen-Inspektion bleibt OFFEN.** Alle fünf `testLiveActivityHardwareCapture*`-UITests grün auf iPhone 15 Pro Max (Distance 37.7 s, Duration 37.2 s, Points 37.4 s, UploadStatusPendingAndRestart 64.4 s, UploadStatusFailed 38.2 s). Sektion-2-Checkboxen werden nicht abgehakt, weil sie eine menschliche Sichtprüfung außerhalb der UITests verlangen.
  - **Sektion 3 (iPad-Layout): BLEIBT OFFEN.** iPad (UDID `3c955848…d4da0a5`, iPadOS 17.7.10) ist offline; nicht gefahren.
  - **Sektion 4 (ASC / TestFlight / Apple Review): BLEIBT OFFEN.** Nicht im Repo verifizierbar; im Train nicht angefasst.
- **P0-3 UITest-Regression auf `testDeviceSmokeNavigationAndActions` (NEU 2026-05-12).** Auf HEAD `5f83838` schlägt `wrapper/LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift:203` mit `XCTAssertTrue(revealElement(heatmapButton, in: app))` fehl — Heatmap-Button in der Overview wird auf echter Hardware nicht hittable. Vergleich: am 2026-05-07 (HEAD `b91a933`) war derselbe Test grün. Mögliche Ursachen aus dem Phase-10-Train (Heatmap-Cap, Map-Layer-Audit, BoundedLRU): nicht in diesem Train geklärt. **Risiko:** Hardware-Smoke-Pfad nicht mehr UITest-grün — bevor TestFlight-Submit muss entweder UITest aktualisiert oder ggf. die UI-Regression behoben werden.

### P1

- **P1-1 iOS Data Protection für SQLite-Store auskommentiert** — `LocalTimelineFileProtection.swift:60–78`. Relevant erst wenn `LH2GPX_LOCAL_TIMELINE_STORE` default ON wird. Aktuell **default OFF**, daher nicht produktionskritisch heute, aber ein Pre-Default-ON-Blocker.
- **P1-2 ZIP-Store-Pfad puffert kompletten ZIP-Entry in `Data`** (`AppContentLoader.swift:356–364`) — Memory-Regression vs Legacy-Stream-Pfad. Nur bei Flag-ON.
- **P1-3 LH2GPX-ZIP-Legacy-Pfad ohne 64-MiB-Gate** (`AppContentLoader.swift:510–514`) — durch 256-MB-Entry-Cap geschützt, aber zwischen 64 MiB und 256 MiB unsicher auf 4-GB-Geräten.
- **P1-4 Test-Lücken**: keine echten E2E-UITests auf Hardware-Pfaden (Live-Tracking, Photo-Import, Share-Sheet), Live Activity Content / Dynamic Island Rendering ungetestet (Agent E E2, E4).
- **P1-5 Doku-Drift in TESTFLIGHT_RUNBOOK + ASC_SUBMIT_RUNBOOK** mit falscher Build-Nummer-Realität (Build 45 / Build 74 vs aktuell 100/167). **Minimal-Patch in diesem Train enthalten.**

### P2

- **P2-1 `BoundedLRU` ohne Memory-Druck-basierte Eviction.** Bei 65k-Entry-Export ggf. 80–150 MB für Projection-Caches (Agent F F4).
- **P2-2 `LocalTimelineStore` nicht intern synchronisiert.** Single-Owner-Vertrag, nicht durch Actor-Wrapper erzwungen (Agent C+D ST-01).
- **P2-3 pbxproj/Plist-Redundanz** (`INFOPLIST_KEY_*` parallel zu Info.plist mit `GENERATE_INFOPLIST_FILE=NO`). Drift-Risiko, kein Bug heute.
- **P2-4 `tmp/ImportStaging/` wird beim App-Start nicht aufgeräumt** (Agent F F7).

### P3 Hygiene

- **P3-1 leere Duplikat-Ordner** `Sources 2/`, `Tests 2/`, `Fixtures 2/`, `.swiftpm 2/`, `.github 2/` weiter im Filesystem (0 bytes, nicht in git, kein Build-Impact).
- **P3-2 viele `*__backup_*.md` Doku-Dateien** committed (Hygiene).
- **P3-3 Localization** über `t(_:)`-Helper + `language.isGerman`-Boolean statt `Localizable.xcstrings`.
- **P3-4 Drei UI-Dateien > 1500 LOC** (`AppInsightsContentView`, `AppExportView`, `AppContentSplitView`).
- **P3-5 Mac-File-Keychain-Test-Skip** für Accessibility-Read-Back-Tests (auf iOS Device/Sim wären sie grün).

## 10. Was bewusst NICHT behauptet wird

- 46-MB-Crashfall **nicht** Hardware-grün — bleibt **FAILED** bis Tester-Retest Release-Build.
- Live Activity / Dynamic Island / Lock Screen **nicht** vollständig verifiziert — Checkboxen leer.
- iPad-Layout **nicht** vollständig verifiziert.
- ASC / TestFlight Build-Liste / Apple Review-Status **nicht** lokal belegbar; ASC-Build-167-Aussage aus `docs/DEEP_AUDIT_2026-05-12.md` ist Screenshot-Anker, nicht Repo-Truth.
- Hardware-UITests in diesem Audit-Lauf **nicht** gefahren (Wrapper-Build bricht; Sim-Build ebenfalls).
- Test-Anzahlen werden ehrlich getrennt nach Mac (1518) / Linux (heute nicht gefahren, Remote-Doku claimt 1400 für `d629467`) / Test-Funcs-gesamt (1538 inkl. UITests).
- LocalTimelineStore Phase-10-Code als **pre-production / feature-flagged / default OFF** verbucht — keine Behauptung, dass er auf User-Geräten aktiv ist.

## 11. Nächster sinnvoller Codex-Prompt

```
Pflichtblock LH2GPX:
- Vor Arbeitsbeginn vollständiger Repo-Preflight (pwd, git status, HEAD).
- Repo-Truth: aktuelles Monorepo iOS-App, HEAD nach Push dieses Audits ist die Commit-SHA aus dem Push.
- Keine Notion-Punkte abhaken außer wirklich umgesetzt.
- Commit + Push nach Tests, nicht davor.

Aufgabe: P0 Wrapper-iOS-Build-Fix — CSQLite konditional auf Linux einschränken.

1. Code:
   In Package.swift Target "LocationHistoryConsumerAppSupport" die Dependency "CSQLite" durch
       .target(name: "CSQLite", condition: .when(platforms: [.linux]))
   ersetzen.

   Falls weitere Targets CSQLite als unconditional Dep haben (z.B. Tests), gleich anpassen.

   Falls Source-Files `import CSQLite` ohne `#if !canImport(SQLite3)` Gate enthalten, jeweils auf
   die SDK-SQLite3-only Variante umstellen:
       #if canImport(SQLite3)
       import SQLite3
       #elseif canImport(CSQLite)
       import CSQLite
       #endif

2. Verifikation in dieser Reihenfolge:
   a. swift build (Mac) → grün (sollte unverändert sein)
   b. DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test → grün, ≥ 1518 Tests
   c. xcodebuild -scheme LH2GPXWrapper -project wrapper/LH2GPXWrapper.xcodeproj -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO → BUILD SUCCEEDED
   d. xcodebuild -scheme LH2GPXWrapper -project wrapper/LH2GPXWrapper.xcodeproj -destination 'id=00008130-00163D0A0461401C' build -allowProvisioningUpdates → BUILD SUCCEEDED (signed)
   e. git diff --check clean

3. Doku-Sync:
   - docs/DEEP_AUDIT_2026-05-12_POST_PULL.md Sektion 9 P0-1: Eintrag schließen, Verweis auf den Fix-Commit, xcodebuild-Ergebnis ergänzen.
   - CHANGELOG.md: neuer Eintrag "fix: gate CSQLite linux shim on linux only".
   - wrapper/CHANGELOG.md analog.
   - ROADMAP.md/NEXT_STEPS.md: P0-Eintrag entfernen wenn wirklich grün.
   - 46-MB-Hardware-Retest, Live Activity, iPad, ASC bleiben weiterhin OFFEN.

4. Commit + Push:
   git commit -m "fix: gate CSQLite linux shim on linux only — restore Wrapper-iOS xcodebuild"
   git push origin main

5. Falls Linux-CI (in Xcode Cloud nicht aktiv, aber lokal/Swift-Linux-CI ggf. weiter genutzt):
   - DEVELOPER_DIR=... swift test im Container/auf Linux-Host grün halten.
   - Falls Linux nicht erreichbar: nicht in diesem Train fahren, im Audit-Report als "noch zu verifizieren" hinterlassen.

Wichtig:
- Keine Phase-10-Logik anfassen.
- Keine Default-ON-Drehung des LocalTimelineStore-Flags.
- Keine Hardware-Punkte als erledigt markieren.
- Wenn xcodebuild iOS weiterhin bricht: stoppen, Konflikt sauber im Audit-Report dokumentieren statt blind weiter zu pushen.
```

---

**Audit-Ende.** Dieser Report ist die Wahrheits-Anker-Datei zwischen `799adc5` (vorigem Remote-Audit `docs/DEEP_AUDIT_2026-05-12.md` auf HEAD `ae5de1f`) und dem nächsten Train. Punktuelle Doku-Patches in diesem Train: `wrapper/docs/TESTFLIGHT_RUNBOOK.md` (Build-Identität), `docs/ASC_SUBMIT_RUNBOOK.md` (Build-Liste), `README.md` (Teststand). Vollständiger Mass-Doku-Refresh ist ein separater Train.
