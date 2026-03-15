# LocationHistory2GPX-iOS

Minimales separates iOS-Consumer-Repo fuer den stabilen App-Export von `LocationHistory2GPX`.

## Rolle dieses Repos

- Consumer only
- kein Parser fuer Google-Rohdaten
- keine GPX-/GeoJSON-/CSV-Erzeugung
- keine fertige Produkt-App in diesem Schritt
- offline-first, ohne Netzwerkcode, Tracking oder Cloud-Sync

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
- gegen Swift-Modelle decodieren
- read-only Query-/ViewState-Daten aus dem App-Export ableiten
- eine kleine produktnahe App-Shell-Struktur fuer lokalen `app_export.json`-Import bereitstellen
- die App-Shell import-first mit klarerem Quellen-/Statusbereich und Reset-/Replace-Fluss fuehren
- eine minimale lokale SwiftUI-Demo-Shell mit fixer Golden-Fixture bereitstellen
- in der Demo lokal `app_export.json` fuer denselben Consumer-Contract importieren
- Demo-Quelle, Reset und Fehlerzustaende klar sichtbar fuehren
- Golden-basierte Contract-Tests lokal ausfuehren
- klar dokumentieren, welche Producer-Artefakte konsumiert werden
- Producer-Contract-Artefakte lokal reproduzierbar aktualisieren

## Was dieses Repo aktuell bewusst nicht kann

- fertige Produkt-UI
- Import von Google-Rohdateien
- Producer-Logik aus dem Python-Repo
- `trips_index.json` konsumieren

## Struktur

- `Sources/LocationHistoryConsumer/`
  - `AppExportModels.swift`
  - `AppExportDecoder.swift`
  - `ContractVersion.swift`
  - `Queries/*.swift`
- `Sources/LocationHistoryConsumerAppSupport/`
  - generische Session-/Loader-Typen
  - gemeinsame SwiftUI-Inhaltsdarstellung fuer App und Demo
- `Sources/LocationHistoryConsumerDemoSupport/`
  - `DemoDataLoader.swift`
  - `Resources/golden_app_export_sample_small.json`
- `Sources/LocationHistoryConsumerApp/`
  - produktnahe App-Shell fuer lokalen `app_export.json`-Import
- `Sources/LocationHistoryConsumerDemo/`
  - Demo-/Harness-Einstieg fuer Fixture-zentrierte Verifikation
- `Tests/LocationHistoryConsumerTests/`
  - `AppExportGoldenDecodingTests.swift`
  - `ContractFixturePresenceTests.swift`
  - `AppExportQueriesTests.swift`
  - `DayDetailViewStateTests.swift`
  - `DemoDataLoaderTests.swift`
- `Fixtures/contract/`
  - `app_export.schema.json`
  - `golden_app_export_*.json`
- `docs/CONTRACT.md`
- `docs/XCODE_APP_PREPARATION.md`
- `ROADMAP.md`
- `NEXT_STEPS.md`

## Lokale Nutzung

```bash
swift test
```

Der Standardweg ist jetzt nativer lokaler Swift 5.9.

Auf Apple-Plattformen kann die lokale Demo-Harness danach ueber das Swift Package in Xcode oder per `swift run LocationHistoryConsumerDemo` gestartet werden. Sie ist bewusst keine Produkt-App. Standardmaessig nutzt sie eine feste lokale Demo-Fixture, kann aber auch lokal eine `app_export.json` fuer denselben Consumer-Contract laden.

Zusaetzlich gibt es jetzt eine kleine produktnahe App-Shell `LocationHistoryConsumerApp`. Sie startet leerer und import-zentriert, bleibt aber weiter offline-only und noch keine fertige Produkt-App. Unter Linux ist nur der nicht-UI Teil ueber `swift test` ehrlich verifizierbar.

Die aktuelle Apple-/Xcode-nahe Vorbereitung ist bewusst klein und dokumentiert in `docs/XCODE_APP_PREPARATION.md`. Es gibt absichtlich noch kein als verifiziert behauptetes Xcode-/iOS-Projektsetup.

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
- nutzt weiter nur Decoder + Query-Layer
- zeigt aktive Quelle, Reset auf Demo und klarere Fehler-/Leerzustaende
- keine Persistenz, keine Maps, kein Google-Rohdatenimport
- Fehler beim Fixture- oder Datei-Load werden schlicht als Fehlzustand angezeigt

## App-Shell

Die App-Shell ist die produktnaehere Einstiegsschicht dieses Repos:
- startet mit lokalem `app_export.json`-Import als primaerem Einstieg
- bietet Demo-Daten nur als sekundären Fallback
- nutzt dieselben Decoder-, Query- und Session-Typen wie die Demo
- zeigt klarer, ob noch nichts geladen ist, Demo-Daten aktiv sind, eine Datei importiert wurde oder ein Import fehlgeschlagen ist
- fuehrt Quelle, Dateiname, Schema-Version, Exportzeitpunkt und Tagesanzahl kompakt im UI
- erlaubt Open Another File, Load Demo Data und Clear ohne Persistenz oder Dateiverlauf
- bleibt offline-only und fuehrt keine neue Business-Logik ein

## Apple-/Xcode-Vorbereitung

- `LocationHistoryConsumerApp` ist die vorgesehene produktnahe Apple-App-Huelle
- `LocationHistoryConsumerDemo` bleibt der Harness-/Verifikationspfad
- `LocationHistoryConsumerAppSupport` enthaelt die gemeinsame app-nahe Import-/Session-Logik
- die aktuelle Vorbereitungsnotiz fuer Xcode und Apple-Validierung steht in `docs/XCODE_APP_PREPARATION.md`
- unter Linux bleiben nur SwiftPM-Build und `swift test` ehrlich verifiziert
