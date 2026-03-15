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
- Golden-basierte Contract-Tests lokal ausfuehren
- klar dokumentieren, welche Producer-Artefakte konsumiert werden
- Producer-Contract-Artefakte lokal reproduzierbar aktualisieren

## Was dieses Repo aktuell bewusst nicht kann

- Karten-/Listen-/SwiftUI-Produkt-UI
- Import von Google-Rohdateien
- Producer-Logik aus dem Python-Repo
- `trips_index.json` konsumieren

## Struktur

- `Sources/LocationHistoryConsumer/`
  - `AppExportModels.swift`
  - `AppExportDecoder.swift`
  - `ContractVersion.swift`
  - `Queries/*.swift`
- `Tests/LocationHistoryConsumerTests/`
  - `AppExportGoldenDecodingTests.swift`
  - `ContractFixturePresenceTests.swift`
  - `AppExportQueriesTests.swift`
  - `DayDetailViewStateTests.swift`
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
