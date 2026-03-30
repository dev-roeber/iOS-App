# Xcode Runbook

## Zweck

Dieses Runbook beschreibt den kleinsten reproduzierbaren Xcode-Laufweg fuer das Swift-Package `LocationHistory2GPX-iOS`.
Es fokussiert bewusst nur den bestehenden Consumer-Scope:

- `LocationHistoryConsumer` bleibt der app_export-Consumer-Core
- `LocationHistoryConsumerDemo` bleibt Harness/Sample
- `LocationHistoryConsumerAppSupport` bleibt app-nahe Session-/State-/Composition-Schicht
- `LocationHistoryConsumerApp` bleibt die produktnaehere App-Shell fuer lokalen JSON-/ZIP-Import

Keine Maps, keine Persistenz, keine Suche, kein Sync und keine Producer-Logik in Swift.

## Voraussetzungen

- macOS mit Xcode und SwiftPM-Unterstuetzung fuer Swift Tools 5.9
- Package-Plattformen gemaess `Package.swift`:
  - iOS 16+
  - macOS 13+
- empfohlen: Xcode 26.3 oder neuer, solange das Paket unveraendert auf Swift 5.9 basiert

Wenn `xcode-select -p` nur auf die Command Line Tools zeigt, sind Xcode-CLI-Schritte trotzdem moeglich, solange das echte Xcode installiert ist. Dann entweder:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -list
```

und fuer SwiftPM-Tests auf derselben Maschine entsprechend:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

oder den aktiven Developer Directory lokal auf Xcode umstellen.

## Repo in Xcode oeffnen

Der vorgesehene Einstieg bleibt das Swift Package, nicht ein separates `.xcodeproj`.

```bash
cd /pfad/zu/LocationHistory2GPX-iOS
open Package.swift
```

Alternativ in Xcode:

1. `File > Open...`
2. `Package.swift` oder das Repo-Verzeichnis waehlen
3. Package-Resolution abwarten

## Relevante Schemes und Schichten

Die fuer diese Phase relevanten Schemes sind:

- `LocationHistoryConsumerApp`
  - produktnaehere App-Shell
  - import-first Startzustand
  - lokale LH2GPX- oder Google-Timeline-Datei oeffnen
  - Demo-Daten nur als Fallback
- `LocationHistoryConsumerDemo`
  - Harness-/Verifikationsoberflaeche
  - startet standardmaessig mit gebuendelter Demo-Fixture
  - kann auf Apple-Plattformen ebenfalls lokales `app_export.json` laden
- `LocationHistoryConsumer`
  - Consumer-Core fuer Contract, Decoder und Query-Layer
- `LocationHistoryConsumerAppSupport`
  - gemeinsame Session-, Loader- und Inhaltsdarstellung fuer App und Demo
- `LocationHistoryConsumerDemoSupport`
  - fixture-zentrierte Demo-Unterstuetzung und gebuendelte Sample-Ressourcen

## Empfohlener Xcode-Run fuer die produktnahe App-Shell

1. In Xcode das Scheme `LocationHistoryConsumerApp` waehlen.
2. Als Destination `My Mac` oder einen passenden Apple-Laufweg waehlen.
3. `Product > Build` ausfuehren.
4. `Product > Run` ausfuehren.

Erwarteter Startzustand:

- leerer import-first Screen
- Titel `Import your location history`
- primaerer Button `Open location history file`
- sekundaerer Button `Load Demo Data`
- noch keine Persistenz oder Dateihistorie

## Demo-Daten in der App-Shell pruefen

Die produktnahe App-Shell darf Demo-Daten laden, bleibt aber nicht der primaere Einstieg.

Schritte:

1. App mit `LocationHistoryConsumerApp` starten
2. `Load Demo Data` klicken

Erwartet:

- Statuskarte `Demo data loaded`
- aktive Quelle `Demo fixture: golden_app_export_sample_small.json`
- Schema `1.0`
- Day-Liste mit `2024-05-01` und `2024-05-02`
- Day-Detail und Overview werden angezeigt
- Actions-Menue bietet danach `Open Another File`, `Reload Demo` und `Clear`

## Lokalen Import pruefen

Fuer den ersten lokalen Import muss kein echtes Produkt-Exportfile vorliegen. Eine Contract-Fixture aus dem Repo reicht fuer LH2GPX-Dateien; alternativ kann eine reale Google-Timeline-Datei verwendet werden:

- `Fixtures/contract/golden_app_export_sample_small.json`
- `Fixtures/contract/golden_app_export_no_days_zero.json`
- alternativ ein anderer `golden_app_export_*.json` Contract-Fall

Schritte:

1. App mit `LocationHistoryConsumerApp` starten
2. `Open location history file` oder spaeter `Open Another File` klicken
3. im Apple-Dateiimporter eine lokale JSON- oder ZIP-Datei waehlen

Erwartet:

- Statuskarte `Location history loaded` oder `Google Timeline loaded`
- aktive Quelle `Imported file: <dateiname>.json` oder `Imported file: <dateiname>.zip`
- Overview wird angezeigt
- Day-Liste und Day-Detail sind sichtbar
- ein weiterer `Open Another File`-Lauf ersetzt den aktuellen Inhalt

## Reset- und Fehlerpfade

Mindestens diese kleinen UI-Laufwege pruefen:

### Clear / Reset

1. nach Demo- oder Datei-Load `Clear` klicken
2. erwarteter Rueckfall in den import-first Leerlaufzustand

Erwartet:

- Status `No location history loaded`
- aktive Quelle `None`
- Buttons `Open location history file` und `Load Demo Data`

### Invalides JSON

1. lokal eine kaputte JSON-Datei bereitstellen, z. B. mit Inhalt `{`
2. ueber `Open location history file` importieren

Erwartet:

- Fehlzustand `Unable to open file` oder `Unsupported file format`
- bei leerem Vorzustand bleibt keine aktive Quelle
- bei bereits geladenem Inhalt bleibt letzter gueltiger Inhalt sichtbar

### Leerer Export / No Days

1. eine echte Zero-Day-Fixture oder ein reales `app_export.json` ohne Tage laden
2. bevorzugt: `Fixtures/contract/golden_app_export_no_days_zero.json`
3. auf Listen- und Detaildarstellung achten

Erwartet:

- Overview bleibt sichtbar
- Day-Liste zeigt `No Days`
- Detailbereich meldet, dass keine Day-Entries vorhanden sind

## Reproduzierbarer CLI-Launch

Fuer einen reproduzierbaren foreground-Start der App-Shell ohne manuelles Xcode-IDE `Product > Run` gibt es ein standardisiertes Script:

```bash
./scripts/run_app_shell_macos.sh
```

Das Script:

1. baut `LocationHistoryConsumerApp` per `swift build`
2. erstellt eine minimale `.app`-Bundle-Struktur unter `.build/AppBundle/`
3. startet die App per `open` als echte foreground-macOS-App

Das ersetzt die fruehere ad-hoc-Methode, das gebaute Binary manuell in eine temporaere App-Wrapper-Struktur zu kopieren. Die `.build/AppBundle/`-Ausgabe wird durch `.gitignore` (`.build/`) automatisch ignoriert.

## Weitere CLI-Hilfsbefehle

Die Xcode-IDE bleibt der bevorzugte manuelle Weg. Fuer reproduzierbare CLI-Pruefung koennen dieselben Schemes ueber das echte Xcode gebaut werden:

```bash
cd /pfad/zu/LocationHistory2GPX-iOS
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -list
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## Reale Verifikation in dieser Phase

Stand 2026-03-17 wurde auf einer echten macOS-/Xcode-Maschine Folgendes real geprueft:

- Host: macOS 15.7
- Xcode: 26.3 (`Build version 17C529`)
- `xcode-select -p` zeigte `/Applications/Xcode.app/Contents/Developer`
- das echte Xcode-CLI wurde fuer die dokumentierten Apple-Kommandos trotzdem explizit ueber `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` verwendet
- `xcodebuild -list` erkannte unter anderem die Schemes `LocationHistoryConsumerApp` und `LocationHistoryConsumerDemo`
- `xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build` lief erfolgreich durch
- das gebaute Binary `.../Build/Products/Debug/LocationHistoryConsumerApp` liess sich bauen und fuer die echte UI-Session starten; der foreground-App-Launch ist seit Phase 13 ueber `scripts/run_app_shell_macos.sh` standardisiert
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` lief fuer den damaligen Snapshot erfolgreich; dieser historische Lauf umfasste 28 Tests
- dieser historische Apple-Testlauf ist nicht der aktuelle Repo-Stand: die frische Linux-Verifikation vom 2026-03-30 zaehlt 217 ausgefuehrte Tests, 2 Skips und 14 Failures; ein neuer Xcode-Testlauf war auf diesem Linux-Host nicht moeglich
- echte interaktive Apple-UI-Laeufe wurden erfolgreich gegen die produktnahe App-Shell ausgefuehrt:
  - sichtbarer import-first Startscreen
  - `Load Demo Data`
  - `Open location history file` ueber nativen Apple-Dateiimporter mit gueltiger lokaler Datei
  - `Open Another File` zum Ersetzen des aktuellen Inhalts
  - `Clear`
  - invalides JSON mit sichtbarer Fehlermeldung bei erhaltenem letztem gueltigen Inhalt
  - echter Zero-Day-Import mit `No Days Available` und `No Day Details Available`
  - sichtbare Day-Liste und Day-Detail-Darstellung fuer Demo und gueltigen Import

Fuer die UI-Laeufe verwendete lokale Dateien:

- gueltiger Import: lokale Kopie von `Fixtures/contract/golden_app_export_sample_small.json`
- invalid: lokale Datei `lh2gpx_invalid.json` mit Inhalt `{`
- no-days: lokale Kopie von `Fixtures/contract/golden_app_export_no_days_zero.json`

Nicht separat als eigener Nachweis festgehalten:

- foreground-Run exakt ueber `Product > Run` in Xcode selbst; die reale UI-Verifikation dieser Phase lief gegen denselben Xcode-gebauten Binary-Output in einer temporaeren lokalen foreground-App-Wrapper-Struktur

## Bekannte Grenzen dieser Phase

- kein `.xcodeproj`, nur Swift Package
- keine Signierung, keine Distribution, keine Entitlements-Arbeit
- kein Sync und keine Cloud-/Server-Anteile
- keine hardware-verifizierte Background-Recording-Session und kein Auto-Resume laufender Live-Tracks
- keine frische Apple-Verifikation fuer das spaeter hinzugekommene Heatmap-Sheet, den dedizierten `Live`-Tab oder Upload-Batching/Upload-Status
- Apple-Verifikation ersetzt nicht `swift test`, und `swift test` ersetzt keinen echten Apple-UI-Lauf
