# Apple Verification Checklist

## Zweck

Diese Checkliste trennt klar zwischen:

- bereits real verifizierten Apple-Schritten
- noch offenen interaktiven UI-Schritten

Sie gilt fuer die produktnahe App-Shell `LocationHistoryConsumerApp`.

## Statusstand 2026-03-17

### Bereits real verifiziert

- [x] Xcode-Schemes aus dem Swift Package sind ueber das echte Xcode sichtbar
- [x] `LocationHistoryConsumerApp` baut fuer `platform=macOS`
- [x] das gebaute App-Shell-Binary startet sichtbar in einer echten foreground-App-Session
- [x] `Load Demo Data`
- [x] `Open app_export.json`
- [x] `Open Another File` ersetzt bestehenden Inhalt
- [x] `Clear` / Reset
- [x] invalides JSON mit erhaltenem letztem gueltigen Inhalt
- [x] echter Zero-Day-Export / no days
- [x] Day-Liste und Day-Detail als echter UI-Durchgang

### Seit Phase 13 zusaetzlich verifiziert

- [x] reproduzierbarer foreground-Launch via `scripts/run_app_shell_macos.sh` (standardisiertes .app-Bundle statt ad-hoc-Wrapper)

### Noch offen

- [ ] foreground-Run explizit ueber `Product > Run` in Xcode selbst noch einmal separat bestaetigen, falls genau dieser IDE-spezifische Laufweg regressionskritisch wird

## Reale Apple-UI-Session 2026-03-17

- Host: macOS 15.7 (`24G222`)
- Xcode: 26.3 (`Build version 17C529`)
- `xcode-select -p`: `/Applications/Xcode.app/Contents/Developer`
- Swift unter echtem Xcode: `Apple Swift version 6.2.4`
- Apple-CLI-Schritte wurden weiterhin explizit mit `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` gefahren
- fuer die echte interaktive UI-Verifikation wurde das gebaute SwiftPM-App-Binary als foreground-App gestartet; seit Phase 13 ist dieser Schritt ueber `scripts/run_app_shell_macos.sh` standardisiert (baut, wrapped in minimales .app-Bundle, startet per `open`)
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
  - sichtbarer Startscreen mit `Open an app_export.json file` real bestaetigt
  - kein Crash
  - Hinweis: der spezifische IDE-Lauf `Product > Run` wurde in dieser Phase nicht noch einmal separat als foreground-Nachweis festgehalten

### 3. Open `app_export.json`

- Schritt:
  - `Open app_export.json` klicken
  - z. B. `Fixtures/contract/golden_app_export_sample_small.json` waehlen
- Erfolg gilt als:
  - Status `Imported app export loaded`
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
  - Rueckfall auf `No app export loaded`
  - Quelle `None`
  - Startbuttons wieder sichtbar
- Status 2026-03-17:
  - verifiziert
  - Rueckfall auf `Open an app_export.json file` und `No app export loaded` real bestaetigt

### 6. Fehlerfall mit ungueltiger JSON

- Schritt:
  - lokale Datei mit kaputtem JSON importieren
- Erfolg gilt als:
  - Fehlerzustand `Unable to open app export`
  - bei vorhandenem Inhalt bleibt letzter gueltiger Stand sichtbar
- Status 2026-03-17:
  - verifiziert
  - Fehlerkarte `Unable to open app export` erschien real
  - Meldung `Unable to decode app export file: lh2gpx_invalid.json` erschien real
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
