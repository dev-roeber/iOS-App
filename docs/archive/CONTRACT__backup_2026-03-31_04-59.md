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
- `golden_app_export_no_days_zero.json`
  - deckt einen echten Zero-Day-Export fuer Apple-UI-Verifikation und no-days-Zustaende ab

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

## App-Support und Schichten

- `Sources/LocationHistoryConsumer/` bleibt Consumer-Core fuer Contract, Decoder und Queries.
- `Sources/LocationHistoryConsumerAppSupport/` enthaelt generische Session-, Loader- und gemeinsame Inhaltsdarstellung fuer Apple-UI-Schichten.
- `Sources/LocationHistoryConsumerDemoSupport/` bleibt fixture-zentrierte Demo-Unterstuetzung.
- `Sources/LocationHistoryConsumerDemo/` bleibt Harness-/Verifikationsoberflaeche.
- `Sources/LocationHistoryConsumerApp/` ist die kleine produktnaehere Einstiegsschicht fuer lokalen JSON-/ZIP-Import.
- `docs/XCODE_RUNBOOK.md` dokumentiert den reproduzierbaren Xcode-Laufweg.
- `docs/APPLE_VERIFICATION_CHECKLIST.md` dokumentiert die konkreten Apple-Pruefschritte und deren Status.
- `docs/XCODE_APP_PREPARATION.md` bleibt die kleinere vorbereitende Notiz aus der Vorphase.

## Demo-Harness

Die SwiftUI-Demo in `Sources/LocationHistoryConsumerDemo/` ist nur ein lokaler Harness:
- Sie laedt eine feste gebuendelte Golden-Fixture aus `LocationHistoryConsumerDemoSupport`.
- Sie kann auf Apple-Plattformen alternativ lokal eine `app_export.json` laden.
- Sie nutzt nur Decoder + Query-Layer, keine neue Domain-Logik.
- Sie fuehrt Quelle, Reset und Fehlerzustand bewusst nur in einer kleinen Demo-Session-Schicht.
- Sie bleibt auf den eingefrorenen Consumer-Contract beschraenkt; der lokal begrenzte Google-Timeline-Import bleibt Consumer-seitig erlaubt.
- Sie ist keine Produkt-App und fuehrt keine Persistenz ein.

## App-Shell

Die kleine App-Shell in `Sources/LocationHistoryConsumerApp/` ist bewusst produktnaeher, aber weiter begrenzt:
- primaerer Einstieg: lokale LH2GPX- oder Google-Timeline-Datei oeffnen
- sekundaerer Fallback: Demo-Daten laden
- gleiche Session-/Content-Typen wie die Demo
- import-first Leerlaufzustand mit klarer Erklaerung der unterstuetzten lokalen JSON-/ZIP-Dateien
- kompakter Quellen-/Contract-Bereich fuer aktive Quelle, Schema-Version, Exportzeitpunkt, Input-Format und Tagesanzahl
- klarer Open-/Replace-/Clear-Fluss ohne Persistenz oder Dateiverlauf
- kein Sync, keine Server-/Cloud-Funktionen und kein Auto-Resume eines laufenden Live-Tracks nach App-Neustart
