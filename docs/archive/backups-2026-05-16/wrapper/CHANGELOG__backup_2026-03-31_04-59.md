# CHANGELOG

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
