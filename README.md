# LocationHistory2GPX-iOS

Minimales separates iOS-Consumer-Repo fuer den stabilen App-Export von `LocationHistory2GPX`.

## Rolle dieses Repos

- Consumer only
- keine allgemeine Producer-Pipeline oder Takeout-Aufbereitung fuer Google-Rohdaten
- keine GPX-/GeoJSON-/CSV-Erzeugung
- keine fertige Produkt-App in diesem Schritt
- offline-first, ohne Netzwerkcode, Analytics-Tracking oder Cloud-Sync

## Contract-Herkunft

- Producer-Repo: `dev-roeber/LocationHistory2GPX`
- Referenz-Commit: `7630b0e`
- Uebernommene Contract-Artefakte:
  - `Fixtures/contract/app_export.schema.json`
  - `Fixtures/contract/golden_app_export_*.json`
  - `Fixtures/contract/CONTRACT_SOURCE.json`
- Referenz fuer die Boundary im Producer-Repo: `docs/SEPARATE_IOS_REPO_BOUNDARY.md`

## Was dieses Repo aktuell kann

- App-Export-JSON laden
- Google-Timeline-`location-history.json` und `.zip` lokal direkt importieren
- gegen Swift-Modelle decodieren
- read-only Query-/ViewState-Daten aus dem App-Export ableiten
- eine kleine produktnahe App-Shell-Struktur fuer lokalen JSON-/ZIP-Import bereitstellen
- die App-Shell import-first mit klarerem Quellen-/Statusbereich und Reset-/Replace-Fluss fuehren
- foreground-only Live-Location auf der Karte anzeigen und als getrennten Live-Track lokal aufzeichnen
- aufgezeichnete Live-Tracks getrennt von importierter History lokal persistieren (save on stop, ohne Auto-Resume)
- lokale App-Optionen fuer Distanz-Einheit, Kartenstil, Start-Tab und technische Importdetails speichern
- eine minimale lokale SwiftUI-Demo-Shell mit fixer Golden-Fixture bereitstellen
- in der Demo lokal `app_export.json` fuer denselben Consumer-Contract importieren
- Demo-Quelle, Reset und Fehlerzustaende klar sichtbar fuehren
- Golden-basierte Contract-Tests lokal ausfuehren
- klar dokumentieren, welche Producer-Artefakte konsumiert werden
- Producer-Contract-Artefakte lokal reproduzierbar aktualisieren

## Was dieses Repo aktuell bewusst nicht kann

- Producer-Logik aus dem Python-Repo
- `trips_index.json` konsumieren
- fertiges Background-Location-Tracking
- Auto-Resume eines laufenden Live-Tracks nach App-Neustart
- Mergen aufgezeichneter Live-Tracks in importierte Originaldaten

## Struktur

- `Sources/LocationHistoryConsumer/`
  - `AppExportModels.swift`
  - `AppExportDecoder.swift`
  - `ContractVersion.swift`
  - `Queries/*.swift`
- `Sources/LocationHistoryConsumerAppSupport/`
  - generische Session-/Loader-Typen
  - gemeinsame SwiftUI-Produkt-UI fuer App und Demo (NavigationSplitView, Dashboard, Day-Detail, Map)
  - Live-Location-/Recording-Domain fuer foreground-only Tracking und getrennte Recorded-Track-Persistenz
- `Sources/LocationHistoryConsumerDemoSupport/`
  - `DemoDataLoader.swift`
  - `Resources/golden_app_export_sample_small.json`
- `Sources/LocationHistoryConsumerApp/`
- Produkt-App-Einstieg fuer lokalen JSON-/ZIP-Import
- lokale Optionen-Seite mit `UserDefaults`-basierten App-Preferences
- `Sources/LocationHistoryConsumerDemo/`
  - Demo-/Harness-Einstieg fuer Fixture-zentrierte Verifikation
- `Tests/LocationHistoryConsumerTests/`
  - `AppExportGoldenDecodingTests.swift`
  - `ContractFixturePresenceTests.swift`
  - `AppExportQueriesTests.swift`
  - `DayDetailViewStateTests.swift`
  - `DayMapDataTests.swift`
  - `DemoDataLoaderTests.swift`
  - `ImportBookmarkStoreTests.swift`
- `Fixtures/contract/`
  - `app_export.schema.json`
  - `golden_app_export_*.json`
- `docs/CONTRACT.md`
- `docs/APP_FEATURE_INVENTORY.md`
- `docs/XCODE_APP_PREPARATION.md`
- `docs/XCODE_RUNBOOK.md`
- `docs/APPLE_VERIFICATION_CHECKLIST.md`
- `ROADMAP.md`
- `NEXT_STEPS.md`

## Lokale Nutzung

```bash
swift test
```

Der Standardweg ist jetzt nativer lokaler Swift 5.9.
Wenn auf macOS das aktive Developer Directory nur auf die Command Line Tools zeigt, kann fuer Apple-komplette Testlaeufe stattdessen das echte Xcode explizit gesetzt werden:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Auf Apple-Plattformen kann die lokale Demo-Harness danach ueber das Swift Package in Xcode oder per `swift run LocationHistoryConsumerDemo` gestartet werden. Sie ist bewusst keine Produkt-App. Standardmaessig nutzt sie eine feste lokale Demo-Fixture, kann aber auch lokal eine `app_export.json` fuer denselben Consumer-Contract laden.

Zusaetzlich gibt es jetzt eine kleine produktnahe App-Shell `LocationHistoryConsumerApp`. Sie startet leerer und import-zentriert, bleibt aber weiter offline-only und noch keine fertige Produkt-App. Unter Linux ist nur der nicht-UI Teil ueber `swift test` ehrlich verifizierbar.

Die aktuelle Apple-/Xcode-nahe Vorbereitung ist bewusst klein und jetzt in `docs/XCODE_RUNBOOK.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md` und der historischen Vorbereitungsnotiz `docs/XCODE_APP_PREPARATION.md` beschrieben. Es gibt weiterhin absichtlich kein aufgeblasenes `.xcodeproj`.

Fuer einen reproduzierbaren foreground-Start der App-Shell auf macOS:

```bash
./scripts/run_app_shell_macos.sh
```

Das Script baut die App per `swift build`, erstellt ein minimales `.app`-Bundle und startet es als foreground-App.

## Contract-Files aktualisieren

Producer-Updates starten immer im Python-Repo `LocationHistory2GPX`. Wenn dort Schema, Goldens und Contract-Tests aktualisiert wurden, uebernimmst du hier nur die producer-abgeleiteten Consumer-Artefakte:

```bash
./scripts/update_contract_fixtures.sh
swift test
```

Der Sync-Skriptlauf aktualisiert nur:
- `Fixtures/contract/app_export.schema.json`
- producer-abgeleitete `Fixtures/contract/golden_app_export_*.json`
- `Fixtures/contract/CONTRACT_SOURCE.json` mit dem referenzierten Producer-Commit

Consumer-lokale Forward-Compatibility-Fixtures bleiben bewusst unangetastet.

## Query-Layer

Die Query-Schicht ist bewusst read-only und UI-unabhaengig:
- `ExportOverview` fuer Header-/Summary-Daten
- `DaySummary` fuer sortierte Tageslisten
- `DayDetailViewState` fuer eine einzelne Tagesansicht ohne UI-Komponenten
- `AppExportQueries` fuer Lookup und Datumsbereichsfilter

Diese Schicht liest nur den eingefrorenen Consumer-Contract. Parsing, Dedupe, Trips und weitere Producer-Business-Logik bleiben im Python-Repo.

## Demo-Shell

Die Demo-Shell ist nur ein lokaler Harness fuer die Query-Schicht:
- feste gebuendelte Fixture: `golden_app_export_sample_small.json`
- optionaler lokaler Dateiimport fuer `app_export.json`
- zeigt Overview, sortierte Day-Liste und Day-Detail
- nutzt weiter Decoder + Query-Layer; die neue Live-Recording-Domain bleibt davon getrennt
- zeigt aktive Quelle, Reset auf Demo und klarere Fehler-/Leerzustaende
- kein Auto-Resume, kein Background-Tracking, keine Recorded-Track-Exports
- Fehler beim Fixture- oder Datei-Load werden schlicht als Fehlzustand angezeigt

## Produkt-UI

Die Produkt-UI ist die primaere Inhaltsdarstellung dieses Repos:
- adaptives Layout: iPhone nutzt `TabView` (`Overview`, `Days`, `Insights`, `Export`), regular width nutzt `NavigationSplitView` mit Day-Liste und Detail-Pane
- no-content-Tage bleiben in `Days` sichtbar, werden aber nicht mehr wie normale Detailziele behandelt
- Day-Liste fuehrt jetzt mit einem kleinen Export-Statusblock; exportmarkierte Tage tragen ein klares `Export`-Badge
- Such-Empty-States in `Days` verschweigen vorhandene GPX-Markierungen nicht mehr
- Overview-Dashboard fuehrt mit Import-Status, optionalen Export-Filtern und einem kompakten `Go To`-Block fuer `Days`, `Insights` und `Export`
- Overview-Dashboard mit klar als `Imported History` gerahmtem Statistik-Grid (Days, Visits, Activities, Paths)
- Day-Detail mit strukturierten Sections, Cards und Quick-Stats
- Day-Detail priorisiert importierte Tageshistorie, Kartenkontext und Timeline; lokale Live-Recording-/Track-Werkzeuge bleiben als sekundaerer Block getrennt
- Insights-Tab zeigt jetzt Top-Level- und Section-Empty-States fuer no-days-, sparse- und no-chart-Faelle statt leerer Flaechen
- Insights-Charts zeigen chart-spezifische Low-Data-Hinweise, robustere Day-Tap-Navigation und lesbarere Achsen
- regular-width Detailansicht bietet einen expliziten Rueckweg zur `Overview`
- Karten-MVP: MapKit-Ansicht im Day-Detail mit Pfad-Polylines und Visit-Markern (iOS 17+)
- Live-Recording-Sektion im Day-Detail: manueller Ein/Aus-Schalter, Permission-State, aktueller Standort, Live-Polyline
- Recorded-Track-Persistenz getrennt von importierter History; Speicherung erst beim Stoppen der Aufnahme
- Saved-Tracks-Library mit getrenntem `Edit Track`-Zugang fuer gespeicherte Live-Tracks als separater `Local Tools`-Nebenfluss
- Optionen-Seite fuer lokale Darstellung/Steuerung: Distanz-Einheit, Start-Tab, Kartenstil, technische Importdetails
- VoiceOver-Accessibility: semantische Labels, Gruppierung, dekorative Icons ausgeblendet
- konsistente Leer-/Fehler-/Ladezustaende mit SF Symbols und klaren Texten
- ein zentrales Actions-Menue in der Toolbar fuehrt Import, Demo, Optionen und Clear
- startet mit lokalem JSON-/ZIP-Import als primaerem Einstieg
- bietet Demo-Daten als sekundaeren Fallback
- Export-Flow zeigt jetzt Auswahlstatus, Disabled-Gruende und den vorgeschlagenen GPX-Dateinamen vor dem fileExporter-Dialog
- Import-Persistenz-Code (Security-Scoped Bookmark) vorhanden; Auto-Restore aktuell bewusst deaktiviert (Phase 19.5) – Start immer manuell ueber Import oder Demo
- Live-Track-Persistenz separat in einem dedizierten Recorded-Track-Store; kein Draft-Resume
- bleibt offline-only; die neue Live-Recording-Logik bleibt lokal und klar vom Import-/Query-Layer getrennt

## Apple-/Xcode-Vorbereitung

- `LocationHistoryConsumerApp` ist die Produkt-App-Huelle
- `LocationHistoryConsumerDemo` bleibt der Harness-/Verifikationspfad
- `LocationHistoryConsumerAppSupport` enthaelt die gemeinsame Produkt-UI, Import-/Session-Logik
- das konkrete Xcode-Runbook steht in `docs/XCODE_RUNBOOK.md`
- die konkrete Apple-Verifikations-Checkliste steht in `docs/APPLE_VERIFICATION_CHECKLIST.md`
- `docs/XCODE_APP_PREPARATION.md` bleibt die kleinere vorbereitende Notiz aus Phase 10
- unter Linux bleiben nur SwiftPM-Build und `swift test` ehrlich verifiziert

## Apple-Verifikationsstatus

Stand 2026-03-17 ist auf einer realen macOS-/Xcode-Maschine ehrlich verifiziert:
- Xcode 26.3 erkennt die relevanten Swift-Package-Schemes
- `LocationHistoryConsumerApp` baut fuer `platform=macOS` erfolgreich per `xcodebuild`
- die produktnahe App-Shell startet sichtbar in einer echten foreground-App-Session
- `Load Demo Data`, `Open location history file`, `Open Another File`, `Clear`, invalides JSON und ein echter Zero-Day-Import wurden als reale Apple-UI-Durchgaenge verifiziert
- `swift test` laeuft mit dem echten Xcode-Developer-Dir gruen

Stand 2026-03-17 ist noch offen:
- ein separat protokollierter foreground-Lauf exakt ueber `Product > Run` in Xcode, falls genau dieser IDE-spezifische Weg regressionskritisch wird
- foreground-only Live-Location-/Permission-Flow in einer separat dokumentierten Apple-UI-Session (Simulator oder echtes iPhone)

Zusatz fuer diese konkrete Maschine: mit aktivem `/Library/Developer/CommandLineTools` schlug ein nacktes `swift test` an `no such module 'XCTest'` fehl. Der gruene Testlauf wurde ehrlich mit `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` erreicht.

Fuer den reproduzierbaren no-days-Apple-UI-Fall gibt es jetzt zusaetzlich `Fixtures/contract/golden_app_export_no_days_zero.json`.

Wichtig: Apple-/Xcode-Verifikation ist getrennt von `swift test` zu betrachten. Linux- oder SwiftPM-Erfolge ersetzen keinen echten Apple-UI-Lauf.

## Wrapper-Repo

Das separate Xcode-Wrapper-Projekt `LH2GPXWrapper` ist ein eigenstaendiges Repo ausserhalb dieses SwiftPM-Repos. Wenn es lokal vorhanden ist, bindet es dieses Repo als lokales Swift Package ein und liefert die iOS-App mit Bundle-Metadaten, Signing, App-Icon und Privacy-Manifest. Dieses Library-Repo bleibt die alleinige Quelle fuer Decoder, Queries, AppSupport und DemoSupport.

## Roadmap

Die vollstaendige Delivery-Roadmap bis App v1.0 steht in `ROADMAP.md`. Die naechsten offenen Schritte stehen in `NEXT_STEPS.md`.
Das repo-wahre Funktionsinventar steht in `docs/APP_FEATURE_INVENTORY.md`.
