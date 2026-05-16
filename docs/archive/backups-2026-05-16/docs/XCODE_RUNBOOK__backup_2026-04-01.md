# Xcode Runbook

## Zweck

Dieses Runbook beschreibt den kleinsten reproduzierbaren Xcode-Laufweg fuer das Swift-Package `LocationHistory2GPX-iOS`.
Es fokussiert bewusst nur den bestehenden Consumer-Scope:

- `LocationHistoryConsumer` bleibt der app_export-Consumer-Core
- `LocationHistoryConsumerDemo` bleibt Harness/Sample
- `LocationHistoryConsumerAppSupport` bleibt app-nahe Session-/State-/Composition-Schicht
- `LocationHistoryConsumerApp` bleibt die produktnaehere App-Shell fuer lokalen JSON-/ZIP-Import

Der aktuelle Scope umfasst bereits Karten, `Days`-Suche, Heatmap-Sheet, segmentierte `Insights`, gespeicherte lokale Live-Tracks und optionalen nutzergesteuerten Upload akzeptierter Live-Recording-Punkte. Weiterhin nicht Teil dieses Runbooks sind Producer-Logik, Cloud-/Account-Sync fuer importierte History und unbewiesene Apple-Review-Claims.

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

Frischer Host-Truth dieses Audits (2026-03-31):

- Linux-Host mit Swift 5.9
- `swift test`: 228 Tests, 2 Skips, 0 Failures
- `git diff --check`: sauber
- `xcodebuild`: auf diesem Host nicht verfuegbar

Die nachfolgenden Apple-/Xcode-Bloecke bleiben historische Nachweise von Apple-Hosts und wurden in diesem Audit nicht neu ausgefuehrt.

Stand 2026-03-17 wurde auf einer echten macOS-/Xcode-Maschine Folgendes real geprueft:

- Host: macOS 15.7
- Xcode: 26.3 (`Build version 17C529`)
- `xcode-select -p` zeigte `/Applications/Xcode.app/Contents/Developer`
- das echte Xcode-CLI wurde fuer die dokumentierten Apple-Kommandos trotzdem explizit ueber `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` verwendet
- `xcodebuild -list` erkannte unter anderem die Schemes `LocationHistoryConsumerApp` und `LocationHistoryConsumerDemo`
- `xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build` lief erfolgreich durch
- das gebaute Binary `.../Build/Products/Debug/LocationHistoryConsumerApp` liess sich bauen und fuer die echte UI-Session starten; der foreground-App-Launch ist seit Phase 13 ueber `scripts/run_app_shell_macos.sh` standardisiert
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` lief fuer den damaligen Snapshot erfolgreich; dieser historische Lauf umfasste 28 Tests
- fuer den aktuellen Repo-Stand wurde am 2026-03-30 auf diesem Mac neu geprueft:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build`: BUILD SUCCEEDED
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumer-Package -destination 'platform=macOS' test`: 224 Tests, 0 Failures
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: 224 Tests, 0 Failures
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project /Users/sebastian/Code/LH2GPXWrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build`: BUILD SUCCEEDED
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project /Users/sebastian/Code/LH2GPXWrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -only-testing:LH2GPXWrapperTests test`: TEST SUCCEEDED
- Heatmap UX Batch 1 (2026-03-30) hat den aktuellen Core-Stand danach erneut per CLI abgesichert:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: 222 Tests, 0 Failures
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build`: BUILD SUCCEEDED
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumer-Package -destination 'platform=macOS' test`: 222 Tests, 0 Failures
  - dabei wurden nur Heatmap-UI-/Display-Details geaendert (ruhigere low-zoom Darstellung, lokale Controls fuer Deckkraft/Radius/`Auf Daten zoomen`, kleine Dichte-Legende); kein neuer Apple-Device-Lauf fuer das Sheet selbst
- Heatmap Visual & Performance Batch 2 (2026-03-30) hat den Renderer danach erneut per CLI abgesichert:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: 224 Tests, 0 Failures
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build`: BUILD SUCCEEDED
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumer-Package -destination 'platform=macOS' test`: 224 Tests, 0 Failures
  - dabei wurde die Heatmap auf geglaettete aggregierte Polygon-Zellen mit viewport-basierter Zellselektion, per-LOD begrenzten sichtbaren Elementen und wiederverwendbarem Viewport-Cache umgestellt; ein neuer Apple-Device-Lauf fuer das Sheet selbst fand in diesem Batch bewusst nicht statt
- Heatmap Color / Contrast / Opacity Batch 3 (2026-03-30) hat die visuelle Schicht des Polygon-/LOD-Renderers danach erneut per CLI abgesichert:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: 227 Tests, 0 Failures
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build`: BUILD SUCCEEDED
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumer-Package -destination 'platform=macOS' test`: 227 Tests, 0 Failures
  - dabei wurden die Farbpalette, die Intensitaetskurve und die interne 100-%-Deckkraft-Kennlinie der Heatmap sichtbar verstaerkt; LOD, viewport-basierte Zellselektion und Cache-Struktur blieben bestehen, und ein neuer Apple-Device-Lauf fuer das Sheet selbst fand in diesem Batch bewusst nicht statt
- der anschliessende Live-/Upload-/Insights-/Days-Batch vom 2026-03-30 wurde auf diesem Linux-Server nur gezielt abgesichert:
  - `swift test --filter Live`: gruen
  - `swift test --filter Insight`: gruen
  - `swift test --filter Day`: gruen
  - `swift test --filter Upload`: gruen
  - dabei wurden die Live-Seite, Upload-Zustaende, die Insights-Informationsarchitektur und die Default-Sortierung von `Days` funktional ausgebaut; ein neuer Apple-CLI- oder Apple-UI-Lauf fuer genau diese Batch-Aenderungen fand bewusst noch nicht statt
- fuer den anschliessenden Device-End-to-End-Block am 2026-03-30 wurde zusaetzlich ein echtes iPhone verwendet:
  - Geraet: `iPhone 15 Pro Max` (`iPhone16,2`), iOS `26.3 (23D127)`, via USB verfuegbar, entsperrt, Developer Mode aktiv
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -allowProvisioningUpdates -project /Users/sebastian/Code/LH2GPXWrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'id=00008130-00163D0A0461401C' -only-testing:LH2GPXWrapperUITests`: echter Device-Lauf
  - `LH2GPXWrapperUITestsLaunchTests.testLaunch` lief auf dem Geraet erfolgreich; der Wrapper startet auf aktueller Hardware stabil
  - `LH2GPXWrapperUITests.testAppStoreScreenshots` scheiterte nicht an Launch oder Signing, sondern an einer inhaltlichen Erwartung: statt leerem Import-State war bereits eine wiederhergestellte `location-history.zip` aktiv, deshalb erschien kein `Demo Data`-Button
  - der zugehoerige echte AX-Snapshot zeigte den Uebersichtsbildschirm mit aktiver importierter Quelle, sichtbarer `Heatmap`-Aktion und sichtbarem dediziertem `Live`-Tab
  - damit sind Wrapper-Launch, sichtbarer Auto-Restore und die Praesenz von `Heatmap`/`Live` auf Device belegt; echtes Oeffnen des Heatmap-Sheets, Live-Recording, Background-Recording und Upload-End-to-End wurden in diesem Batch nicht erreicht
- die 2 in Batch 1 noch offenen Test-vs-Code-Widersprueche sind in Batch 2 repo-wahr geklaert:
  - `AppPreferencesTests.testStoredValuesAreLoaded`: Test-Setup folgt jetzt dem Keychain-first-Produktpfad auf Apple
  - `DayDetailPresentationTests.testTimeRangeFormattingAvoidsRawISOStrings`: Test-Erwartung folgt jetzt der im Produktcode konsistent verwendeten Gedankenstrich-Formatierung
- ein manueller Xcode-Start auf dem verbundenen iPhone bleibt fuer diesen Batch ein positiver Teilbefund, wird hier aber bewusst getrennt von den CLI-Build-/Testresultaten gefuehrt
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
- kein Cloud-/Account-Sync fuer importierte History; optionaler Server-Upload bleibt davon getrennt und ist hier nicht neu auf Apple-Hardware verifiziert
- keine hardware-verifizierte Background-Recording-Session und kein Auto-Resume laufender Live-Tracks
- keine frische Apple-Verifikation fuer das spaeter hinzugekommene Heatmap-Sheet inklusive der neuen lokalen UX-Controls und des spaeter nachgezogenen Aggregations-/Polygon-Renderers, den dedizierten `Live`-Tab oder Upload-Batching/Upload-Status
- Apple-Verifikation ersetzt nicht `swift test`, und `swift test` ersetzt keinen echten Apple-UI-Lauf
