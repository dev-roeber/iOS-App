# CHANGELOG

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
