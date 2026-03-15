# Consumer Contract

## Quelle

- Producer-Repo: `dev-roeber/LocationHistory2GPX`
- Producer-Commit: `7630b0e`
- Standard-Updateweg: nativer lokaler Workflow, kein Docker als Primärpfad

## Uebernommene Artefakte

- `Fixtures/contract/app_export.schema.json`
- `Fixtures/contract/CONTRACT_SOURCE.json`
- `Fixtures/contract/golden_app_export_contract_gate.json`
- `Fixtures/contract/golden_app_export_sample_small.json`
- `Fixtures/contract/golden_app_export_sample_medium.json`
- `Fixtures/contract/golden_app_export_sample_placeholder_*.json`

## Consumer-lokale Hardening-Fixtures

- `golden_app_export_consumer_forward_compatible_additive_fields.json`
  - prueft, dass additive unbekannte JSON-Felder das Decoding nicht brechen, solange `schema_version` kompatibel bleibt
- `golden_app_export_multi_day_varied_structure.json`
  - deckt mehrere Tage, gemischte Tagesstruktur und minimale Path-Punkte ab
- `golden_app_export_empty_collections_minimal.json`
  - deckt leere erlaubte Sammlungen und leere Stats-Strukturen ab

## Consumer-Verantwortung

- Schema-konformes App-Export-JSON dekodieren
- additive non-breaking Felder tolerieren, wenn sie optional bleiben
- bei unbekannter `schema_version` defensiv fehlschlagen
- read-only Query-/ViewState-Ergebnisse aus bereits decodierten Contract-Daten ableiten

## Nicht Teil des Contracts

- `trips_index.json`
- Python-CLI/TUI/Shell-Flows
- Producer-interne Model- oder Exportpfade

## Update-Policy

1. Contract-Aenderung startet immer im Producer-Repo.
2. Dort werden Schema, Goldens und Contract-Tests aktualisiert.
3. Danach werden nur die relevanten producer-abgeleiteten Contract-Artefakte in dieses Repo uebernommen.
4. Lokaler Standardweg hier:
   - `./scripts/update_contract_fixtures.sh [/pfad/zum/LocationHistory2GPX]`
   - `swift test`
5. Anschliessend werden Decoder und Tests hier angepasst, falls der Producer-Contract sich erweitert oder bricht.

## Breaking vs Non-breaking

- Breaking: Feld entfernt, umbenannt, verschoben oder bestehende Semantik inkompatibel veraendert.
- Non-breaking: neue optionale Felder oder additive Strukturen.
- Breaking Changes erfordern dokumentierte Versionsaenderung und aktualisierte Goldens.
- Interne Consumer-Refactors ohne Contract-Aenderung aendern `ContractVersion.currentSchemaVersion` nicht.

## Teststandard

- Primär: nativer lokaler Lauf mit `swift test`
- Docker ist kein Standardworkflow dieses Repos mehr

## Read-only Query-Layer

Die Query-Schicht in `Sources/LocationHistoryConsumer/Queries/` ist bewusst consumer-only:
- Sie liest nur `AppExport` und erzeugt kleine Read-Modelle fuer Listen, Detail und Header.
- Sie fuehrt keine Producer-Aufgaben wie Parsing, Dedupe, Trip-Erkennung oder Export-Erzeugung aus.
- Sie ist fuer eine spaetere UI gedacht, bleibt aber selbst UI-frei.
