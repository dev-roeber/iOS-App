# Apple Verification Checklist

## Zweck

Diese Checkliste trennt klar zwischen:

- bereits real verifizierten Apple-Schritten
- noch offenen interaktiven UI-Schritten

Sie gilt fuer die produktnahe App-Shell `LocationHistoryConsumerApp`.

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
- [ ] Live-Location-/Permission-Flow inklusive optionaler `Always Allow`-Erweiterung fuer Background-Recording in einer echten Apple-UI-Session verifizieren und separat protokollieren
- [ ] den dedizierten `Live`-Tab auf iPhone/iOS 17+ funktional verifizieren; Sichtbarkeit im realen AX-Snapshot ist belegt, echte Interaktion noch nicht
- [ ] das Heatmap-Sheet fuer importierte History auf Apple-Hardware visuell und performanceseitig verifizieren; der Einstieg ist im realen AX-Snapshot sichtbar, das Sheet selbst noch nicht geoefnet, und die spaeter hinzugekommenen UX-Controls, der neue Aggregations-/Polygon-Renderer sowie das Batch-3-Farb-/Kontrast-Mapping sind auf Device ebenfalls noch nicht separat bestaetigt
- [ ] die neue `Days`-Default-Sortierung (`neu -> alt`) in compact und regular auf Apple-Hardware funktional bestaetigen
- [ ] den deutlich ausgebauten `Live`-Tab auf Apple-Hardware funktional bestaetigen, inklusive Status-Chips, Quick Actions und erweitertem Stat-Set
- [ ] die neue segmentierte Insights-Oberflaeche (`Overview`, `Patterns`, `Breakdowns`) auf Apple-Hardware auf Lesbarkeit und Navigation pruefen
- [ ] Upload-Batching, Upload-Status und optionalen Server-Upload-Flow in einer echten Apple-Session separat verifizieren
- [ ] Background-Recording auf echtem iPhone verifizieren (Permission-Upgrade, Background-Aufnahme, Stop/Persistenz)
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
