# CHANGELOG

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
