# LocationHistory2GPX-iOS

Minimales separates iOS-Consumer-Repo fuer den stabilen App-Export von `LocationHistory2GPX`.

## Rolle dieses Repos

- Consumer only
- kein Parser fuer Google-Rohdaten
- keine GPX-/GeoJSON-/CSV-Erzeugung
- keine Produkt-UI in diesem Schritt
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
- eine minimale lokale SwiftUI-Demo-Shell mit fixer Golden-Fixture bereitstellen
- in der Demo lokal `app_export.json` fuer denselben Consumer-Contract importieren
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
- `Sources/LocationHistoryConsumerDemoSupport/`
  - `DemoDataLoader.swift`
  - `Resources/golden_app_export_sample_small.json`
- `Sources/LocationHistoryConsumerDemo/`
  - `LocationHistoryConsumerDemoApp.swift`
  - `RootView.swift`
  - `OverviewSection.swift`
  - `DayListView.swift`
  - `DayDetailView.swift`
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
- `ROADMAP.md`
- `NEXT_STEPS.md`

## Lokale Nutzung

```bash
swift test
```

Der Standardweg ist jetzt nativer lokaler Swift 5.9.

Auf Apple-Plattformen kann die lokale Demo-Harness danach ueber das Swift Package in Xcode oder per `swift run LocationHistoryConsumerDemo` gestartet werden. Sie ist bewusst keine Produkt-App. Standardmaessig nutzt sie eine feste lokale Demo-Fixture, kann aber auch lokal eine `app_export.json` fuer denselben Consumer-Contract laden.

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
- keine Persistenz, keine Maps, kein Google-Rohdatenimport
- Fehler beim Fixture- oder Datei-Load werden schlicht als Fehlzustand angezeigt
