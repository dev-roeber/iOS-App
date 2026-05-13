# Deep Audit LH2GPX — 2026-05-13

Audit-only. Keine Codefixes, keine Commits. Belegorientiert. Tokens, URLs, Standortdaten redigiert.

---

## 1. Kurzfazit

- **Release-Fähigkeit:** **Eingeschränkt JA** — Build/Tests/Hardware-UITests sind grün auf HEAD `9327491`; Apple-Review-Re-Submit ist möglich, **aber** die internen Doku-Anker (Build-Nummer 74, HEAD-Verweise, Test-Zahlen) sind teils veraltet und müssen für ASC-Submit aktualisiert werden, bevor Release-Notes/Submission konsistent sind.
- **Größtes Risiko:** **Bereits dokumentierte, noch offene Performance-P0/P1-Items** im Map-/Export-Pfad (`AppExportQueries.projectedDays` Sort-vor-Limit, `AppOverviewTracksMapView.scanCandidates` Full-Coord-Score) und der **46-MB-Google-Timeline-Crashfall (Hardware FAILED, pending retest)** aus `MAP_ARCHITECTURE_AUDIT.md` / `PERFORMANCE_DEEP_AUDIT_2026-05-12.md`. Beide sind in eigener Doku korrekt als offen markiert — wurden aber im Audit-Lauf nicht neu reproduziert (Datei nicht im Test-Asset-Set).
- **Wichtigste Empfehlung:** Vor Submit-Train Stand-Header & Build/Test-Zahlen in `README.md`, `NEXT_STEPS.md`, `ROADMAP.md`, `wrapper/docs/TESTFLIGHT_RUNBOOK.md`, `docs/ASC_SUBMIT_RUNBOOK.md` auf HEAD `9327491`, MARKETING_VERSION `1.0.1`, CURRENT_PROJECT_VERSION `100`, swift test `1521/4/0`, Device-UITests `8/8+4×LaunchTest` synchronisieren.
- **Sicher verifiziert:**
  - `swift build` ✓ (52,5 s, exit 0)
  - `swift test` ✓ 1521 Tests, 4 skipped, 0 failures, 177,5 s
  - `xcodebuild build` Simulator iPhone 17 Pro Max (iOS 26.3.1) ✓
  - `xcodebuild build` Device iPhone 15 Pro Max (iOS 26.4) ✓ (Code-Sign automatisch, Apple Development cert, 0 warnings)
  - `xcodebuild test -only-testing:LH2GPXWrapperUITests` Device iPhone 15 Pro Max ✓ — 8 UI-Tests + 4 LaunchTests, alle passed, 379 s, `** TEST SUCCEEDED **`
  - Privacy-Manifest, Entitlements, Info.plist, ATS-Default, Keychain-Accessibility-Flag
  - Bundle-IDs: `de.roeber.LH2GPXWrapper{,.UITests,Tests,.Widget}`, Team `XAGR3K7XDJ`, Deployment 16.0/16.2, Swift 5.0
  - Kein produktives Secret/Token/API-Key im Repo (nur Test-Mocks + Doku-Referenzen)
  - Bekannter Linker-P0 aus `DEEP_AUDIT_2026-05-12_POST_PULL.md` (CSQLite-Linux-Shim unconditional) **ist auf HEAD 9327491 behoben** (Commit `5f83838`)
- **Nicht verifiziert (warum):**
  - 46-MB-Google-Timeline-Crashfall-Hardware-Retest: Asset nicht auf Build-Host gefunden, manueller UI-Eingriff erforderlich; eigene Doku trägt korrekt „FAILED / pending hardware retest".
  - Apple-Review-Status, TestFlight-Build-167-Behauptung (vom Tester): nur ASC extern prüfbar; lokal nicht beleg­bar.
  - ZIPFoundation-Privacy-Manifest-Compliance: nur via Apple-Review-Submission validierbar.
  - Live-Upload-Endpunkt-Roundtrip: würde echten Server brauchen (ausgeschlossen wegen Privacy-Auflage).
  - Mehrere Doku-/UI-Findings der Sub-Agents wurden nur via Code-Read belegt, nicht in Hardware reproduziert (z. B. Live-Tracking-Disclosure-UX) — diese stehen als Verdacht/Empfehlung markiert.

---

## 2. Repo-Stand

| Aspekt | Wert |
|---|---|
| Pfad | `/Users/sebastian/iOS-App` |
| Branch | `main` |
| HEAD | `9327491078fc547ddf1c9dadb15d0abab8b6a7ee` |
| Remote | `origin https://github.com/dev-roeber/iOS-App.git` |
| Sync zu `origin/main` | 0 ahead / 0 behind |
| Working tree | sauber (keine modifizierten Dateien) |

**Erkannte Repos auf Maschine (relevant):**
| Pfad | Typ | Bemerkung |
|---|---|---|
| `/Users/sebastian/iOS-App` | aktives App-Repo | **Wahrheit** |
| `/Users/sebastian/iOS-App/.claude/worktrees/agent-a1ab18f25be463692` | Agent-Worktree | locked, ungeprüft, kein produktiver Stand |
| `/Users/sebastian/iOS-App/.claude/worktrees/agent-a79169a693d502f5a` | Agent-Worktree | locked, ungeprüft |
| `~/Library/Mobile Documents/.Trash/iOS-App` | Identische HEAD-Kopie im iCloud-Trash | redundant — kann entfernt werden |
| `~/Library/Mobile Documents/.Trash/lh2gpx-live-receiver` | gelöschter Server-Repo-Clone | kein iOS-Code |
| `~/Downloads/iOS-App-main`, `~/Downloads/iOS-App-main-2` | entpackte ZIP-Snapshots ohne `.git` | Karteileichen |
| `~/Desktop/test/LocationHistory2GPX-main/ios_smoke/` | alter externer iOS-Smoke (`Package.swift` vorhanden, kein `.git`) | nicht aktiv |
| `~/iOS-App/wrapper/LH2GPXWrapper.xcodeproj` | Aktives Xcode-Projekt | ✓ |
| `~/StudioProjects/LocationHistory2GPX-Android` | Android-Repo, sauber | nicht in Audit-Scope |
| `~/weichsel/ZIPFoundation` | Fork-Repo, sauber, ist auch SwiftPM-Dep | nicht in Audit-Scope |

**Aktives iOS-App-Repo:** `/Users/sebastian/iOS-App` (eindeutig — keine konkurrierenden aktiven Repos mit identischem Remote).

**Last 10 Commits (main):**
```
9327491 perf: add measured performance baseline and low-risk optimizations
f111afd fix: restore heatmap control hardware smoke test
9e4a41b docs: record iPhone hardware acceptance status
5f83838 fix: conditionally link CSQLite shim for Linux
4d6ac87 docs: post-pull deep audit truth sync (2026-05-12)
30015c9 fix: set keychain accessibility and sync repo truth docs
799adc5 docs: add deep audit 2026-05-12
aaa31ef fix: bound app session projection caches
ec54aba fix: gate large in memory imports
354740e docs: add deep performance stability map layer audit
```

---

## 3. Audit-Abdeckung

| Bereich | Wert | Quelle |
|---|---|---|
| Tracked Files gesamt | 521 | `git ls-files` |
| Swift-Dateien gesamt | 350 | `git ls-files '*.swift'` |
| Testdateien (`Tests/*` + `wrapper/*Tests*`) | 157 | `git ls-files` |
| Markdown-Dateien | 80 (inkl. *backup*) | `git ls-files '*.md'` |
| Audit-Doku im Repo | 28 (`docs/`+`audits/`+`wrapper/`-Audit-MDs) | `ls` |
| Xcode-Targets | 4 (`LH2GPXWrapper`, `LH2GPXWrapperTests`, `LH2GPXWrapperUITests`, `LH2GPXWidget`) | `xcodebuild -list` |
| SwiftPM-Targets | 7 (CSQLite, LocationHistoryConsumer, …App, …AppSupport, …Demo, …DemoSupport, Tests) | `Package.swift` |
| Xcode-Schemes | 1 shared (`LH2GPXWrapper`) + 6 generated für SPM | `-list` |
| Capabilities | App Groups (`group.de.roeber.LH2GPXWrapper`), Background Mode `location`, Widget Extension | `*.entitlements` + `pbxproj` |
| Bundle IDs | `de.roeber.LH2GPXWrapper`, `…UITests`, `…Tests`, `…Widget` | `pbxproj` |
| Deployment Targets | App 16.0, Tests 16.2 | `pbxproj` |
| Marketing Version | `1.0.1` | `pbxproj` |
| Build Number | `100` | `pbxproj` |
| Swift Version | 5.0 | `pbxproj` |
| Targeted Device Family | `1` (iPhone only, kein iPad-Universal) | `pbxproj` |
| Code Sign Style | Automatic | `pbxproj` |
| Development Team | `XAGR3K7XDJ` (Apple Development „sebastian.roeber94@googlemail.com (2V7DV73UAB)") | `pbxproj` + Device-Sign-Log |

Geprüft (durch Sub-Agents + Stichproben):
- 7 Pflichtdokumente iOS-App + 7 Wrapper-Pflichtdokumente (Agent A38, vollständig oder Kopf gelesen)
- ~13 Swift-Dateien Import/Export vollständig + 4 partiell (Agent ADF4)
- 12 Swift-Persistenz-Dateien vollständig + 5 Tests (Agent A1AD)
- 11 UI-Hauptdateien (~4630 Zeilen) (Agent AB75)
- 7 Network-/Live-Tracking-Dateien + 3 Test-Dateien (Agent AB12)
- 6 Plist/Entitlements/PrivacyInfo + Build-Settings + Secret-Scan (Agent AADE)
- 3 Performance-Audit-Dokus + 2 Performance-Tests vollständig (Agent A19B)

**Ausgeführte Builds:** 4 (`swift build`, `xcodebuild` Simulator, `xcodebuild` Device, `xcodebuild test` Device-UI)
**Ausgeführte Test-Suiten:** 2 (`swift test` host = 1521 Tests; `xcodebuild test -only-testing:LH2GPXWrapperUITests` device = 12 Tests inkl. 4× LaunchTest-Repeats)
**Hardware:** ja (iPhone 15 Pro Max, UDID `00008130-00163D0A0461401C`, iOS 26.4, Connected, Developer Mode aktiv)
**Einschränkungen:** kein Instruments-Run, kein xctrace, kein Hardware-Retest des 46-MB-Crashfalls (Asset nicht auf Host).

---

## 4. Build-/Test-Ergebnisse

| # | Befehl (gekürzt) | Ergebnis | Dauer | Log |
|---|---|---|---|---|
| B1 | `swift build` (Mac, SPM, alle 7 Targets) | **Build complete!** exit 0 | 52,50 s | `/tmp/lh2gpx-audit/` (Agent) |
| B2 | `xcodebuild -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.3.1' build` | **BUILD SUCCEEDED** | ~3,5 min | `/tmp/lh2gpx-audit/xcodebuild-sim.log` |
| B3 | `xcodebuild ... -destination 'platform=iOS,id=…iPhone15ProMax…' build` | **BUILD SUCCEEDED**, 0 warnings, CodeSign 3 binaries | ~1,5 min | `/tmp/lh2gpx-audit/xcodebuild-device.log` |
| T1 | `swift test` (Mac) | **1521 tests, 4 skipped, 0 failures, 0 unexpected** | 177,02 s | `/tmp/lh2gpx-audit/swift-test.log` |
| T2 | `xcodebuild test -only-testing:LH2GPXWrapperUITests -destination 'platform=iOS,id=…'` | **TEST SUCCEEDED** — 8 UI-Tests + 4× LaunchTest, alle passed | 379,52 s | `/tmp/lh2gpx-audit/xcodebuild-device-uitest.log` |

**Skipped-Tests sind erklärbar** (`AppContentLoaderTests` überspringt explizit, wenn `location-history.json/.zip` nicht auf Desktop liegt — bewusster Smoke-only-Mechanismus, kein Bug).

**Langsamste Tests (swift test, Mac):**
| Sek. | Test |
|---|---|
| 36,68 | (nicht eindeutig gemappt, vermutl. ein Large-Import-Memory-Test) |
| 33,87 | dito |
| 24,21 | dito |
| 21,40 | dito |
| 20,01 | dito |
| 14,78 | dito |

(Die Top-6 sind alle >14 s — wahrscheinlich `LargeImportMemorySafetyTests` / `GoogleTimelineStoreImporterTests` / `LocalTimelineMapPerformanceBudgetTests`; Test-Namen nicht ohne weiteres aus 1521-Zeilen-Log zuordbar; keine fail.)

---

## 5. Hardware-iPhone-Ergebnisse

**Gerät:** iPhone 15 Pro Max (`iPhone16,2`), iOS 26.4, UDID `00008130-00163D0A0461401C`, verbunden via Cable, Developer Mode aktiv, automatisches Provisioning OK.

| Test | Dauer | Ergebnis | Belegt |
|---|---|---|---|
| `testAppStoreScreenshots` | 44,00 s | ✓ passed | Demo-Daten geladen, Tabs Overview/Days/Insights/Export/Live durchwandert + Screenshots |
| `testDeviceSmokeNavigationAndActions` | 74,15 s | ✓ passed | End-to-End Navigation+Aktion-Smoke |
| `testLandscapeLayoutSmoke` | 61,61 s | ✓ passed | Rotation-Test |
| `testLiveActivityHardwareCaptureDistance` | 34,83 s | ✓ passed | Live-Tracking-Hardware: Distance-Field |
| `testLiveActivityHardwareCaptureDuration` | 34,60 s | ✓ passed | Live-Tracking-Hardware: Duration |
| `testLiveActivityHardwareCapturePoints` | 34,71 s | ✓ passed | Live-Tracking-Hardware: Punkte-Counter |
| `testLiveActivityHardwareCaptureUploadStatusFailed` | 34,79 s | ✓ passed | Upload-Status FAILED-Pfad |
| `testLiveActivityHardwareCaptureUploadStatusPendingAndRestart` | 60,82 s | ✓ passed | Upload-Status pending + Restart |
| `testLaunch` (×4 wiederholt) | 4,25 / 4,99 / 6,17 / 5,01 s | ✓ passed | Launch-Performance-Metric (4 Replays) |

Gesamt: 12 Test-Runs, 0 Failures, **`** TEST SUCCEEDED **`**, 379,52 s.

**Direkte Ableitungen:**
- App startet zuverlässig (4 Launch-Replays).
- Live-Tracking-Pfad inklusive Upload-Fehler-Handling funktioniert auf echtem Sensorpfad (CL+URL-Mock).
- Demo-Daten-Pfad + Tab-Switches stabil (kein UI-Hang/Crash).
- Landscape-Layout stabil.
- Heatmap-Button-Hit-Target-Fix (`f111afd`) bestätigt: alle 8 UI-Tests grün (vorher 7/8 laut Doku-Drift-Tabelle).

**Nicht in dieser Hardware-Session geprüft (Asset/Manuell nötig):**
- 46-MB-Google-Timeline-Crashfall-Re-Test
- Großes ZIP-Archiv (`Archiv.zip` in iCloud-Trash, ~54 MB; nicht im Test-Pfad)
- iCloud-Backup-Wiederherstellung
- iPad-Layout (Target Family `1`, also Apple-konform iPhone-only; iPads sind offline)
- Live Activity / Dynamic Island im Lock-Screen visuell

---

## 6. P0 Findings

**Keine *neuen* belegten P0s gefunden.** Alle in eigener Doku als P0 markierten Items sind entweder bereits behoben (CSQLite-Linker, Commit `5f83838`) oder in eigener Doku korrekt als offen / „pending hardware retest" deklariert.

**Bestehende, NICHT durch dieses Audit gelöste P0 (aus eigener Doku, verifiziert dass Issue weiterhin existiert):**

| ID | Bereich | Datei/Zeile | Beleg | Reproduktion |
|---|---|---|---|---|
| **P0-EX-1** | Performance/Map | `Sources/LocationHistoryConsumerAppSupport/AppExportQueries.swift` `projectedDays` | `PERFORMANCE_DEEP_AUDIT_2026-05-12.md` Z. 318; `MAP_ARCHITECTURE_AUDIT.md` Z. 127 | Sort + compactMap *vor* Limit auf ggf. großem Day-Set |
| **P0-EX-2** | Performance/Map | `Sources/LocationHistoryConsumerAppSupport/AppOverviewTracksMapView.swift:720–740` (`scanCandidates`) | `PERFORMANCE_DEEP_AUDIT_2026-05-12.md` Z. 319; `MAP_ARCHITECTURE_AUDIT.md` Z. 24–27 | Score-Berechnung über volle Coord-Liste statt lazy |
| **P0-EX-3** | Memory/Hardware | 46-MB-Google-Timeline-Crashfall | `MAP_ARCHITECTURE_AUDIT.md` Z. 1–8; `DEEP_AUDIT_2026-05-12.md` Z. 5; `PERFORMANCE_DEEP_AUDIT_2026-05-12.md` Z. 21 | Datei lokal vorhanden, im UI-Pfad zu reproduzieren — Hardware-Re-Test in diesem Audit nicht möglich |

Risiko: bei realen Nutzerdaten >50 MB Importpfad weiterhin Jetsam-Kill möglich; Map-Render-Latenz bei vielen Tracks im Overview hoch. Empfehlung dort: Lazy-Scoring + Limit-vor-Sort + Stream-Test mit Original-Asset.

---

## 7. P1 Findings

| ID | Bereich | Datei:Zeile | Beleg | Reproduktion | Risiko | Empfehlung | Test |
|---|---|---|---|---|---|---|---|
| **P1-1** | Network/Live | `Sources/LocationHistoryConsumerAppSupport/LiveLocationFeatureModel.swift:771–778` | Kein exponentielles Backoff, kein Jitter, kein Circuit Breaker | Server-Outage simulieren, Sample-Rate konstant | Battery/Bandbreiten-Drain, Self-DoS auf eigenen Server | Backoff + Max-Retry-Window | Unit-Test mit Mock-URLProtocol + simulierter 5xx-Folge |
| **P1-2** | Network/Live | `Sources/LocationHistoryConsumerAppSupport/SystemLiveLocationClient.swift:30` | `desiredAccuracy = kCLLocationAccuracyBest` hartcodiert | Akku-Profil messen | Hoher Battery-Verbrauch | Profil-Schalter („Balanced/Best/Power Save") | XCTOSSignpostMetric |
| **P1-3** | Network/Live | `Sources/LocationHistoryConsumerAppSupport/LiveLocationFeatureModel.swift:834–848` (`syncLiveActivityState`) | Live-Activity-Update pro Sample (≈10 Hz) | Lange Aufzeichnung → System-Throttle | iOS drosselt ActivityKit → unsichtbare Stalls | Update-Throttle (≥1 Hz, Δ-basiert) | UITest mit Frame-Capture |
| **P1-4** | Performance/Memory | `Sources/LocationHistoryConsumerAppSupport/AppHeatmapModel.swift:73, 173, 223` | `Task.detached` ohne `[weak self]` | Heatmap mehrfach pre-computen, dann View dismissen | Retain-Cycle/Lifecycle-Leak | `[weak self]` + Cancellation-Hook | Memory-Leak-Test |
| **P1-5** | Persistenz/Privacy | `Sources/LocationHistoryConsumerAppSupport/LocalTimelineFileProtection.swift:64–79` | `.completeUnlessOpen` ist *dokumentiert*, *nicht aktiviert* (Phase-4-Pflicht für iOS-Rollout) | DB-Datei nach Boot inspizieren — keine `NSFileProtectionCompleteUnlessOpen` | DB lesbar wenn Device lockt während offen | Vor ASC-Submit aktivieren | XCTest setAttributes-Roundtrip |
| **P1-6** | UI/Privacy | `Sources/LocationHistoryConsumerAppSupport/AppLiveTrackingView.swift:481–487` | Upload-Sektion nur sichtbar wenn `sendsLiveLocationToServer=true`; **keine** prominente Pre-Aktivierungs-Disclosure mit Ziel-URL | Settings → Upload aktivieren | App-Review Guideline 5.1.1: optionale Standort-Übermittlung muss deutlich erklärt sein | Erweiterte Erstaktivierungs-Disclosure mit aktueller Endpoint-URL | UITest mit erstem Toggle-Tap |
| **P1-7** | Doku-Drift | `wrapper/docs/TESTFLIGHT_RUNBOOK.md:3,11`, `docs/ASC_SUBMIT_RUNBOOK.md:3–4`, `docs/XCODE_APP_PREPARATION.md:47` | Aussagen „Marketing 1.0 / Build 45/74/84" widerspricht Repo-Wahrheit `1.0.1 / 100` | Diff Doku vs `pbxproj` | Falsche Release-Notes / falsche Reviewer-Erwartung | Auto-Sync-Skript oder Pflicht-Update vor Submit | Skript `scripts/check_doku_truth.sh` |
| **P1-8** | Doku-Drift | `NEXT_STEPS.md:1` Stand-Header HEAD `37a22b7`, `PERFORMANCE_DEEP_AUDIT_2026-05-12.md` HEAD `f111afd` | Veraltete HEAD-Anker vs aktueller HEAD `9327491` | `git rev-parse HEAD` | Auditor / Reviewer landen auf falschem Commit | Stand-Header bei jedem Train mit-syncen | — |
| **P1-9** | Import/Parse | `Sources/.../GPXImportParser.swift:48`, `TCXImportParser.swift:77` | Gruppierung über `.autoupdatingCurrent`; Store ist UTC (`LocalTimelineImportWriter.swift:39`) | GPX-Import in Zeitzone A, dann Wechsel in Zone B, Re-Import | Day-Keys driften, mögliche Duplikate/Lücken | TZ-Strategie vereinheitlichen (Store-UTC, Display-lokal) | Neuer XCTest mit `TimeZone(secondsFromGMT:)` |
| **P1-10** | Import/Memory | `Sources/.../GoogleTimelineStreamReader.swift:44` | Element-Limit hartcodiert 8 MB | bösartiges JSON mit mehrfach 8-MB-Element | Memory-Spikes bei pathologischen Files | dokumentieren + ggf. enger setzen | bestehender LargeImportMemorySafetyTests erweitern |

---

## 8. P2 Findings

| ID | Bereich | Datei:Zeile | Beleg | Empfehlung |
|---|---|---|---|---|
| **P2-1** | Privacy | `Sources/.../LocalTimelineStoreError.swift:20–21` | `openFailed(path: …)` schreibt vollen Pfad in Error-Description | Pfad redigieren / nur Dateinamen, vor Production-Log-Sink |
| **P2-2** | UI | `wrapper/LH2GPXWrapper/ContentView.swift:78, 113` | `.preferredColorScheme(.dark)` hartkodiert | Schalter in Optionen oder system-default |
| **P2-3** | UI/Accessibility | `Sources/.../AppLiveTrackingView.swift` (1217 Zeilen, ~18 Accessibility-IDs) | Accessibility-Labels lückenhaft, v. a. Diagnostics-/Upload-/Advanced-Sektionen | a11y-IDs ergänzen |
| **P2-4** | UI | `wrapper/LH2GPXWrapper/ContentView.swift:237–241` | `.font(.title2.weight(.semibold))` (fixe Size) | dynamicTypeSize berücksichtigen |
| **P2-5** | UI | `AppLiveTrackingView.swift:519–537` | Accuracy-Circle ≥500 m verschwindet ohne Erklär-Banner | Hinweis-Banner „GPS-Genauigkeit zu gering" |
| **P2-6** | Network | `Sources/.../AppPreferences.swift:535` + `LiveLocationServerUploader.swift:7` | Default-Test-Endpoint = `""` → Silent-Failure möglich | Hard-Guard: Disable Upload-Toggle wenn URL leer/invalide |
| **P2-7** | Persistenz | `Sources/.../LocalTimelineStore.swift:185–207`, `LocalTimelineStoreLifecycle.swift:19–27` | `deleteAll` adressiert DB + tmp + RenderCache, **nicht** UserDefaults- & Keychain-Keys; dokumentiert „out of scope" | Vor Production-Wiring: User-Reset-Pfad erweitern |
| **P2-8** | Persistenz | `Sources/.../KeychainHelper.swift:18–31` | `kSecAttrAccessibleAfterFirstUnlock` (kein `…ThisDeviceOnly`) | Intended Trade-off, dokumentieren in Privacy-Policy |
| **P2-9** | Export | `Sources/.../AppExportView.swift:80` | Polygon-Koord-Texteingabe ohne Validierung | Inline-Validierung |
| **P2-10** | UI/Doku | `Sources/.../AppContentSplitView.swift` 1602 Zeilen | Riesiger View — schlecht testbar | Split (P3 ist günstiger, daher P2 wegen Test-Beweglichkeit) |
| **P2-11** | Repo-Hygiene | `*__backup_2026-*.md` (mehrere) | Backup-Schmutz tracked in `git` | Verschieben nach `docs/archive/` |

---

## 9. P3 Findings

| ID | Bereich | Datei:Zeile | Beleg |
|---|---|---|---|
| **P3-1** | UI | `AppLiveTrackingView.swift:341–369` | Generische Fehlermeldung „Location not available" |
| **P3-2** | UI | `AppExportView.swift:82–83` | Export-Error nur String, keine Kategorie |
| **P3-3** | Performance | `Sources/.../AppHeatmapModel.swift:55` viewportCache unbounded | Pan/Zoom = unbegrenztes Wachstum (per Audit-Doku, OFFEN) |
| **P3-4** | Performance | `AppShellRootView.swift:136–141` | Memory-Warning nur Logging, keine Cache-Drops |
| **P3-5** | Performance | `KMZBuilder.swift:9, 30` | Doppelt residenter String+Data |
| **P3-6** | Repo-Hygiene | `audits/AUDIT_4REPO_MASTER_2026-03-31_*.md`, `__backup_*` Files | Alt-Audits in Root statt `docs/archive/` |
| **P3-7** | Doku | Keine Aussage über Concurrency-Garantien des `LocalTimelineStore` in README/CONTRACT | Concurrency-Doku ergänzen |
| **P3-8** | Doku | Reference `WidgetSharedKeys.suiteName` nicht in Public-Doku gemappt | Widget-Setup-Doc um suiteName-Referenz erweitern (es existiert `docs/WIDGET_XCODE_SETUP.md`) |

---

## 10. Security/Privacy/App-Store

**Risiken:**
- `kSecAttrAccessibleAfterFirstUnlock` für Bearer-Token = intentional Trade-off für Background-Upload (P2-8).
- Live-Upload-Disclosure-UX P1-6.
- Optionaler Standort-Upload in Privacy-Manifest deklariert (`NSPrivacyCollectedDataTypePreciseLocation` + `NSPrivacyCollectedDataTypePurposeAppFunctionality`, Tracking `false`).
- Privacy-Policy + Support-URL auf GitHub Pages konfiguriert (laut `ASC_SUBMIT_RUNBOOK.md` + `docs/privacy.html`/`support.html`).

**Compliance-Lücken:**
- ZIPFoundation-Privacy-Manifest nur via Apple-Review verifizierbar (kein lokaler Test möglich).
- File Protection für DB **dokumentiert aber inaktiv** (P1-5) — vor Produktiv-Wiring der Store-Pipeline aktivieren.

**Positive Befunde:**
- Bundle-IDs, Versionen, Entitlements, Background-Modes, ATS-Default, Targeted-Device-Family alle App-Store-konform.
- `ITSAppUsesNonExemptEncryption=false` korrekt gesetzt (keine Export-Compliance-Pflicht).
- Bearer-Token nur via Keychain (nicht UserDefaults), Legacy-Migration aktiv.
- **Kein produktives Secret/API-Key im Repo gefunden** (nur Test-Mock-Strings wie `"secret-token-xyz"` in `LiveLocationFeatureModelTests.swift:312,327` + `AppPreferencesUploadURLValidationTests.swift:103,108`).
- Privacy-Manifest sowohl für App als auch Widget vorhanden.

**Offene Prüfungen (extern):**
- Apple-Review-Result für Build 100 (lokal nicht prüfbar).
- TestFlight-Build-167-Behauptung aus Tester-Quelle (nicht im Repo).

---

## 11. Performance/Memory

**Messwerte (host, swift test, 1521 Tests in 177,02 s):**
- Slowest Suites (>20 s): 6 Stück, alle bestanden (Test-Namen nicht 1:1 zuordbar im 2475-Zeilen-Log).
- `XCTClockMetric` Tests: `PathDistanceCalculatorPerformanceTests` (50k-Punkt-Baseline, 3 Tests, baseline-only).
- `XCTMemoryMetric` Tests: `PerformanceTests` + `PathDistanceCalculatorPerformanceTests`, baseline-only.

**Risiken (siehe P0/P1):**
- `AppExportQueries.projectedDays` Sort vor Limit (P0-EX-1).
- `AppOverviewTracksMapView.scanCandidates` Full-Coord-Score (P0-EX-2).
- 46-MB-Hardware-Crashfall (P0-EX-3, eigene Doku „pending retest").
- 6× `Task.detached` ohne `[weak self]` in Heatmap (P1-4).
- Live Activity-Update 10 Hz (P1-3).

**Hotspots (in Code via grep, ungelesen aber identifiziert):**
- `RecordedTrackStore.swift:41` `Data(contentsOf:)` ohne Größenlimit für Recorded-Tracks-JSON.
- `viewportCache` in `AppHeatmapModel` unbounded.

**Empfehlungen (priorisiert, ohne Codefix):**
1. Limit-vor-Sort im Export-Pfad (P0-EX-1).
2. Lazy-Score im Overview-Map (P0-EX-2).
3. 46-MB-Asset auf Build-Host kopieren und Hardware-Retest erzwingen (P0-EX-3).
4. Backoff + Throttle für Live-Upload + Activity-Update (P1-1, P1-3).
5. `[weak self]` in Heatmap-Tasks (P1-4).

---

## 12. Testabdeckung

**Vorhanden:**
- Host: **1521 Tests** (4 explizit „skipped, Asset fehlt", 0 failures, 0 unexpected).
- Hardware UI: **8 funktionale + 4× LaunchTest-Replay** auf iPhone 15 Pro Max, alle passed (zuvor laut Doku 7/8, mit Commit `f111afd` jetzt 8/8).
- Performance-Baselines vorhanden, aber baseline-only (kein Fail-Threshold).

**Fehlend / dünn:**
- Keine E2E-Integration-Test gegen *Mock-Server* für Live-Upload-Pipeline (P1-1 Test-Lücke).
- Kein TZ-Roundtrip-Test (P1-9 Test-Lücke).
- Kein Test gegen großen ZIP-Import in Hardware (46-MB-Pfad ungetestet).
- Kein Retry-Backoff-Szenario.
- Kein Test des UploadURL-Empty-Default-Pfads (P2-6).
- Kein Memory-Leak-Test für Heatmap-Task-Detached-Lifecycle (P1-4).

**Flakey-Verdacht:** nicht beobachtet im Run (alle deterministisch passed).

---

## 13. Doku-Wahrheit (Drift-Tabelle)

| Datei | Aussage | Repo-Wahrheit | Status | Risiko | Empfehlung |
|---|---|---|---|---|---|
| `README.md:84` | „8/8 UITests PASSED am 2026-05-12" | 7/8 am 2026-05-12, **8/8 am 2026-05-13 (HEAD 9327491)** durch Heatmap-Hit-Target-Fix in `f111afd` | Übergangsweise korrekt → jetzt **wahr**, aber Datum/HEAD ergänzen | Niedrig | Stand-Header nachziehen |
| `README.md:56,79` | „Linux 1400/2/0 (HEAD `d629467`)" | HEAD weiter; Linux nicht re-run | **veraltet** | Niedrig | bei nächstem Re-Run ersetzen |
| `NEXT_STEPS.md:1` | „Stand HEAD `37a22b7`" | aktueller HEAD `9327491` | **veraltet** | Mittel | Stand-Header bei jedem Train syncen |
| `ROADMAP.md` | „MARKETING_VERSION=1.0.1 / Build 100" | `pbxproj` 1.0.1 / 100 | **aktuell** | — | — |
| `docs/XCODE_APP_PREPARATION.md:47` | „Build 84 Cloud / swift test 964 / MARKETING_VERSION=1.0" | 1.0.1 / Build 100 / 1521 Tests | **stark veraltet** | Mittel | Datei resyncen oder löschen |
| `docs/ASC_SUBMIT_RUNBOOK.md:3–4` | „aktuellster Cloud-Build 74" | unklar (Tester nennt 167); Repo-Truth 100 | **veraltet** | Mittel | mit ASC abgleichen |
| `wrapper/docs/TESTFLIGHT_RUNBOOK.md:3,11` | „Marketing 1.0 / Build 45" | 1.0.1 / 100 | **veraltet** | Mittel | resyncen |
| `wrapper/CHANGELOG.md` und `wrapper/AUDIT_*` | Stand 2026-03-31 | aktuell 2026-05-13 | **veraltet** im historischen Sinn (Audit-Snapshots) | Niedrig | — |
| `docs/DEEP_AUDIT_2026-05-12_POST_PULL.md` | „P0 CSQLite-Linker auf HEAD 30015c9" | **behoben** in `5f83838` auf HEAD 9327491 | **Aussage historisch korrekt, Befund obsolet** | Niedrig | Nachtrag mit Fix-Commit |
| `docs/PERFORMANCE_DEEP_AUDIT_2026-05-12.md` | HEAD `f111afd` Anker | HEAD `9327491` (weitere Perf-Commits + Hardware-Heatmap-Fix) | **leicht veraltet** | Niedrig | Headers nachziehen |
| `audits/*backup*.md` | Doppel-Backup-Files | redundant in `git ls-files` | **Schmutz** | Niedrig (Repo-Hygiene) | nach `docs/archive/` |
| `*__backup_2026-*.md` Root-Level | mehrere Dateien | dito | dito | dito | dito |

---

## 14. Priorisierte nächste Schritte (max. 10, klein geschnitten)

1. **(P0-EX-1)** `AppExportQueries.projectedDays`: Limit *vor* Sort anwenden, Tests dafür ergänzen.
2. **(P0-EX-2)** `AppOverviewTracksMapView.scanCandidates`: lazy Score, abbrechen sobald Top-N erreicht; Memory-Test.
3. **(P0-EX-3)** 46-MB-Google-Timeline-Asset auf Build-Host kopieren, Hardware-UITest hinzufügen, `MAP_ARCHITECTURE_AUDIT.md` Status final schließen.
4. **(P1-1)** Exponential Backoff + Jitter in `LiveLocationFeatureModel.handleUploadFailure` (+ Test mit Mock-URLProtocol).
5. **(P1-3)** Live-Activity-Update auf Δ-Throttle (max 1 Hz) reduzieren.
6. **(P1-4)** `[weak self]` in `AppHeatmapModel.Task.detached` (3 Stellen) + Cancel-Hook.
7. **(P1-5)** File-Protection `.completeUnlessOpen` für `store.sqlite` + `recorded_live_tracks.json` aktivieren (Phase-4-Pflicht); XCTest-Roundtrip.
8. **(P1-6)** Live-Upload-Erstaktivierungs-Disclosure mit aktueller Ziel-URL.
9. **(P1-7/P1-8)** Doku-Drift: Stand-Header + Build-Nummern in 5 betroffenen Docs auf HEAD/Marketing/Build syncen — **vor** nächstem ASC-Submit.
10. **(P2-11)** `__backup_*` und `audits/*backup*` Dateien nach `docs/archive/` verschieben (Repo-Hygiene); danach `git ls-files '*.md' | wc -l` halbiert.

---

## 15. Empfohlene Folge-Prompts

**Prompt 1 — P0-Fixes (Performance/Map):**
> Implementiere Limit-vor-Sort in `AppExportQueries.projectedDays` und Lazy-Score in `AppOverviewTracksMapView.scanCandidates` gemäß `MAP_ARCHITECTURE_AUDIT.md` Z. 24–27 und Z. 127. Ergänze Tests in `Tests/LocationHistoryConsumerTests/AppExportQueriesTests.swift` und `AppOverviewMapModelTests.swift`. Branch `fix/p0-map-perf`. Bevor Commit: `swift test` und `xcodebuild test` auf iPhone 15 Pro Max grün halten.

**Prompt 2 — P1-Fixes (Live-Upload/Heatmap/Privacy):**
> Implementiere (a) exponential Backoff + Jitter in `LiveLocationFeatureModel.handleUploadFailure`, (b) Δ-Throttle 1 Hz in `syncLiveActivityState`, (c) `[weak self]` in den drei `Task.detached`-Stellen in `AppHeatmapModel` (Z. 73/173/223), (d) File-Protection `.completeUnlessOpen` in `LocalTimelineFileProtection.applyOpenWritable`. Tests: `LiveLocationServerUploaderBackoffTests`, `AppHeatmapTaskLifecycleTests`, `LocalTimelineFileProtectionRoundtripTests`. Branch `fix/p1-train-A`.

**Prompt 3 — Tests ergänzen:**
> Ergänze Tests: TZ-Roundtrip GPX/TCX (P1-9), Empty-Default-Upload-URL Guard (P2-6), Live-Upload-Disclosure-UITest (P1-6), 46-MB-Asset-Hardware-Test (P0-EX-3 — Asset-Pfad konfigurierbar machen via `XCTSkipUnless(env)`). Branch `tests/coverage-gaps`.

**Prompt 4 — Doku-Sync (Truth-Run):**
> Synchronisiere folgende Doku-Anker auf HEAD `9327491`, MARKETING_VERSION `1.0.1`, CURRENT_PROJECT_VERSION `100`, swift test `1521/4/0`, Device UITests `8/8 + 4× LaunchTest`: `README.md`, `NEXT_STEPS.md`, `docs/XCODE_APP_PREPARATION.md`, `docs/ASC_SUBMIT_RUNBOOK.md`, `wrapper/docs/TESTFLIGHT_RUNBOOK.md`, `docs/PERFORMANCE_DEEP_AUDIT_2026-05-12.md` (Nachtrag mit Fix-Commit), `docs/DEEP_AUDIT_2026-05-12_POST_PULL.md` (Nachtrag „CSQLite-P0 behoben in `5f83838`"). Anschließend `__backup_*` und `audits/*backup*` nach `docs/archive/`. Branch `docs/truth-sync-2026-05-13`.

**Prompt 5 — App-Store-Submission-Check + Hardware-Re-Verifikation:**
> Vor TestFlight-Push: führe Audit-Re-Run gegen aktuellen HEAD, vergleiche pbxproj-Marketing/Build mit `docs/ASC_SUBMIT_RUNBOOK.md`, prüfe ATS, Privacy-Manifest, Background-Mode, Targeted-Device-Family. Verifiziere auf iPhone 15 Pro Max: `xcodebuild test -only-testing:LH2GPXWrapperUITests` + manueller 46-MB-Import (Asset auf Desktop legen). Output: Pass/Fail-Checkliste + Screenshots-Pfad.

---

## Abschlussmatrix

| Kategorie | Status | Beleg |
|---|---|---|
| Repo-Preflight | ✅ | HEAD 9327491, main, clean, sync, keine konkurrierenden aktiven Repos |
| Doku gelesen | ✅ | 14 Pflicht-Docs + 11 weitere durch Sub-Agent A38, alle pfadbezogen referenziert |
| Swift-Dateien geprüft | ✅ (tracked) / ⚠️ (vollständig) | 350 Swift tracked; vollständig gelesen via Sub-Agents: ca. 40+ Files; viele Files nur grep-/Strukturlevel — explizit gekennzeichnet |
| Builds | ✅ | `swift build` exit 0; `xcodebuild build` Simulator + Device beide SUCCEEDED |
| Tests | ✅ | swift test 1521/4/0 host; UI-Tests 8/8 + 4× LaunchTest device, TEST SUCCEEDED |
| iPhone-Hardware | ✅ | iPhone 15 Pro Max (iOS 26.4), Device build + UI tests grün |
| App-Store-Risiken | ⚠️ | Keine *neuen* Blocker, aber Doku-Drift bei Build-Nummern + Live-Upload-Disclosure-UX |
| Security/Privacy | ✅ | Keine produktiven Secrets; Privacy-Manifest + Entitlements korrekt; File-Protection P1 offen (dokumentiert) |
| Doku-Wahrheit | ⚠️ | Drift in 7 Dateien (Build-Nummern, HEAD-Anker, Test-Zahlen) — siehe §13 |

---

**Audit-Methodik:** 6 Sub-Agents (Doku, Import/Export, Persistenz, UI/Wrapper, Network/Live, Security/Privacy/App-Store, Performance) parallel + Build/Test/Hardware-Runs in Main-Session. Alle Befunde mit Datei-Pfad-Zeilenanker oder explizitem „nicht prüfbar weil X" gekennzeichnet. Keine Codeänderung, keine Commit-Aktion.

---

## Update 2026-05-13 (Audit-Gate-Verifikation auf HEAD `aa145b4`)

Nicht historisch verfälschend angefügt nach Re-Audit auf HEAD `aa145b4` (`docs: add deep audit 2026-05-13 (audit-only, evidence-backed)`). 3 P0s aus Abschnitt 6 oben gegen aktuellen Code/Test/Hardware-Stand re-verifiziert.

### P0-Matrix vorher / nachher

| ID | Status vorher (Audit 2026-05-13) | Status nachher (Re-Audit 2026-05-13) | Beleg |
|---|---|---|---|
| **P0-EX-1** AppExportQueries.projectedDays Sort vor Limit | bestehend, ungeprüft | **HERABGESTUFT auf P1** | Sort/CompactMap vor `prefix(limit)` wahr (`Sources/LocationHistoryConsumer/Queries/AppExportQueries.swift:266–286`), aber `limit` in der aktiven Codebase nie ≠ nil; davor 8-Entry `BoundedLRU` in `AppSessionState.swift:108–109`. Dead-Code-Pfad heute. |
| **P0-EX-2** AppOverviewTracksMapView.scanCandidates Score auf voller Coord-Liste | bestehend | **BLEIBT P0/P1** | `approximateDistance` über volle coords (`AppOverviewTracksMapView.swift:720`), `pointWeight = log(coordinates.count)` (`:721`), erst danach `strideDecimate` (`:725`). Sicherer kleiner Fix nicht möglich — Score-Reihenfolge ist Test-verankert (`AppOverviewTracksMapViewTests`); MAP_ARCHITECTURE_AUDIT §3 markiert Refactor-Risiko HOCH. |
| **P0-EX-3** 46-MiB-Google-Timeline-Hardware-Crashfall | "pending hardware retest" | **Host-Ersatzprüfung PASSED, Device-Interactive offen** | Asset `/Users/sebastian/Desktop/Google_Maps/12_05_2026_location-history.json` (44,5 MiB) → `swift test --filter "AppContentLoaderTests.testRealLocationHistoryJsonOnDesktop|AppContentLoaderTests.testRealLocationHistoryZipOnDesktop"` **2/0/0** in 42,25 s (JSON 20,52 s, ZIP 21,73 s). iPhone-Jetsam-Verhalten damit NICHT widerlegt — bleibt Tester-Handoff (kein UITest-Hook für File-Path im Wrapper). |

### Re-Verifikations-Befehle (2026-05-13)

| # | Befehl | Ergebnis |
|---|---|---|
| 1 | `swift test --filter ".*OnDesktop"` | **Executed 2 tests, 0 failures** in 42,25 s |
| 2 | `swift test` (volles Set) | **1521 / 4 skipped / 0 failures** in 177,02 s |
| 3 | `xcodebuild build` Simulator iPhone 17 Pro Max iOS 26.3.1 | **BUILD SUCCEEDED** |
| 4 | `xcodebuild build` Device iPhone 15 Pro Max iOS 26.4 | **BUILD SUCCEEDED**, 0 warnings |
| 5 | `xcodebuild test -only-testing:LH2GPXWrapperUITests` Device | **TEST SUCCEEDED**, 8 UI-Tests + 4× LaunchTest, 379,52 s |

### Doku-Sync 2026-05-13 (geänderte Dateien)

- `README.md` — Hardware-Verifikations-Zeile auf 2026-05-13 / HEAD `aa145b4` / 8/8 UITests / 1521 Tests synced (statt 2026-05-05 / 964 Tests).
- `NEXT_STEPS.md` — Neuer Top-Block „Audit-Gate-Verification 2026-05-13" mit P0-Verdikten und Re-Verifikations-Outputs.
- `docs/XCODE_APP_PREPARATION.md` — Test-Zahl 964/2/0 → 1521/4/0 + Datum/HEAD.
- `docs/APPLE_VERIFICATION_CHECKLIST.md` — Aktualisierungs-Header 2026-05-13 mit Re-Verifikations-Block.
- `docs/ASC_SUBMIT_RUNBOOK.md` — Stand-Header 2026-05-13, CSQLite-P0-Banner als GELÖST (Commit `5f83838`).
- `wrapper/docs/TESTFLIGHT_RUNBOOK.md` — Stand-Header 2026-05-13, CSQLite-P0-Banner als GELÖST.
- `wrapper/NEXT_STEPS.md` — Test-Zahl 964/2/0 → 1521/4/0 + Hardware-UITest-Block ergänzt.
- `wrapper/ROADMAP.md` — Neuer Stand-Header 2026-05-13; alter Stand als „Historischer Stand" markiert.

Keine Code-Änderungen in diesem Re-Audit. Keine Commit-Empfehlung für P0-EX-1/EX-2 in dieser Runde (siehe NEXT_STEPS.md für Folge-Trains).

### Empfehlung ASC-Submit (technisch, 2026-05-13)

**Eingeschränkt JA** — Tests/Builds/Hardware grün; CSQLite-Linker-P0 gelöst; Doku-Truth synchron. Verbleibende Risiken: interaktiver 46-MiB-Device-UI-Import (Tester-Handoff), Apple-Review-extern (TestFlight-Build-Liste).
