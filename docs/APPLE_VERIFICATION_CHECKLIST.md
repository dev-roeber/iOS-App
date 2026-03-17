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
- [x] das gebaute App-Shell-Binary startet und bleibt aktiv, bis es manuell beendet wird

### Noch offen

- [ ] sichtbarer App-Start mit bestaetigtem Fenster in Xcode
- [ ] `Load Demo Data`
- [ ] `Open app_export.json`
- [ ] `Open Another File` ersetzt bestehenden Inhalt
- [ ] `Clear` / Reset
- [ ] invalides JSON
- [ ] leerer Export / no days
- [ ] Day-Liste und Day-Detail als echter UI-Durchgang

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
  - `Product > Run`
- Erfolg gilt als:
  - App startet in den import-first Leerlaufzustand
  - kein sofortiger Crash
- Status 2026-03-17:
  - teilweise verifiziert
  - Binary-Start real geprueft
  - sichtbares Fenster noch nicht ehrlich bestaetigt

### 3. Open `app_export.json`

- Schritt:
  - `Open app_export.json` klicken
  - z. B. `Fixtures/contract/golden_app_export_sample_small.json` waehlen
- Erfolg gilt als:
  - Status `Imported app export loaded`
  - Quelle `Imported file: <dateiname>.json`
  - Overview, Day-Liste und Day-Detail sichtbar
- Status 2026-03-17:
  - offen

### 4. Demo laden

- Schritt:
  - `Load Demo Data` klicken
- Erfolg gilt als:
  - Status `Demo data loaded`
  - Quelle `Demo fixture: golden_app_export_sample_small.json`
  - zwei Demo-Tage sichtbar
- Status 2026-03-17:
  - offen

### 5. Clear / Reset

- Schritt:
  - nach geladenem Inhalt `Clear` klicken
- Erfolg gilt als:
  - Rueckfall auf `No app export loaded`
  - Quelle `None`
  - Startbuttons wieder sichtbar
- Status 2026-03-17:
  - offen

### 6. Fehlerfall mit ungueltiger JSON

- Schritt:
  - lokale Datei mit kaputtem JSON importieren
- Erfolg gilt als:
  - Fehlerzustand `Unable to open app export`
  - bei vorhandenem Inhalt bleibt letzter gueltiger Stand sichtbar
- Status 2026-03-17:
  - offen

### 7. Leerer Export / no days

- Schritt:
  - no-days-geeignete Exportdatei laden
- Erfolg gilt als:
  - Overview bleibt sichtbar
  - Day-Liste zeigt `No Days Available`
  - Detailbereich bleibt im no-days-Zustand
- Status 2026-03-17:
  - offen

### 8. Darstellung Day-Liste / Day-Detail

- Schritt:
  - mit Demo oder importierter Datei durch die Liste navigieren
- Erfolg gilt als:
  - Day-Auswahl reagiert
  - Detailbereich zeigt Daten fuer den gewaehlten Tag
  - keine neue Business-Logik wird dafuer benoetigt
- Status 2026-03-17:
  - offen
