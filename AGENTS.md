# Codex Agent – Projektprofil: LocationHistory2GPX-iOS

## Projektrolle

- Dieses Repo ist ausschliesslich Consumer des stabilen App-Exports aus `LocationHistory2GPX`.
- Keine Producer-Verantwortung hierher ziehen.
- Keine Google-Rohdaten parsern.
- Keine Produkt-UI in diesem Schritt bauen.
- Read-only Query-/ViewState-Schicht ist erlaubt, solange sie contract-basiert bleibt.

## Stabiler Contract

- Formale Quelle: `Fixtures/contract/app_export.schema.json`
- Decoder-Referenzen: `Fixtures/contract/golden_app_export_*.json`
- Update-Herkunft: Producer-Repo `dev-roeber/LocationHistory2GPX` ab Commit `7630b0e`
- `trips_index.json` gehoert nicht zum Consumer-Contract
- `./scripts/update_contract_fixtures.sh` ist der lokale Standardweg fuer producer-abgeleitete Fixture-Updates

## Arbeitsstil

- Foundation-first, keine unnötigen Frameworks
- Decoder und Modelle klein, klar, testbar halten
- Query-Typen klein, wertbasiert und UI-unabhaengig halten
- additive Felder optional modellieren
- unbekannte additive JSON-Felder tolerieren, aber unbekannte `schema_version` weiter ablehnen
- Breaking Changes nur mit dokumentierter Contract-Version

## Pflichtchecks

- `swift test`
- nativer lokaler Swift ist der Primärweg; Docker hoechstens als Ausnahmefall, nicht als Standard
