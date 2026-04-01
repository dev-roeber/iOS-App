# Codex Agent – Projektprofil: LocationHistory2GPX-Monorepo

## Projektrolle

- Dieses Repo ist ausschliesslich Consumer des stabilen App-Exports aus `LocationHistory2GPX`.
- Keine Producer-Verantwortung hierher ziehen.
- Keine allgemeine Producer-Pipeline fuer Google-Rohdaten hierher ziehen.
- Der lokal begrenzte Import von Google-Timeline-`location-history.json` / `.zip` in die Consumer-App ist erlaubt.
- Keine vollstaendige Produkt-App oder neue Produktfeatures in diesem Schritt bauen.
- Read-only Query-/ViewState-Schicht ist erlaubt, solange sie contract-basiert bleibt.
- Eine minimale lokale Demo-/Harness-Shell ist erlaubt, solange sie nur Decoder + Query-Layer nutzt.
- Ein lokaler `app_export.json`-Import in der Demo ist erlaubt, solange er nur den Consumer-Contract laedt und keine Persistenz oder Producer-Logik einfuehrt.
- Kleine Demo-Zustandslogik fuer Quelle, Reset, Auswahl und Fehler ist erlaubt, solange sie in der Harness-Schicht bleibt und testbar bleibt.
- Eine kleine produktnahe App-Shell ist erlaubt, solange sie lokalen LH2GPX-`app_export.json`-/`.zip`-Import und den eng begrenzten Google-Timeline-Import anbietet und dieselben Core-/Support-Typen wiederverwendet.
- Kleine app-nahe Informationsarchitektur fuer Quelle, Status, Replace- und Reset-Fluss ist erlaubt, solange sie nur Composition/State bleibt und keine neue Fachlogik einfuehrt.
- Security-Scoped Bookmark-Persistenz fuer die zuletzt importierte Datei ist erlaubt, solange sie nur UserDefaults nutzt und keine Inhaltsdaten persistiert.
- Ehrliche Apple-/Xcode-Vorbereitung ist erlaubt, solange Linux-Tests intakt bleiben und keine ungetestete Apple-Verifikation behauptet wird.
- `docs/XCODE_RUNBOOK.md` und `docs/APPLE_VERIFICATION_CHECKLIST.md` sind die kanonischen Stellen fuer Apple-Laufweg und Verifikationsstatus.

## Stabiler Contract

- Formale Quelle: `Fixtures/contract/app_export.schema.json`
- Decoder-Referenzen: `Fixtures/contract/golden_app_export_*.json`
- Update-Herkunft: Producer-Repo `dev-roeber/LocationHistory2GPX` ab Commit `7630b0e`
- `trips_index.json` gehoert nicht zum Consumer-Contract
- `./scripts/update_contract_fixtures.sh` ist der lokale Standardweg fuer producer-abgeleitete Fixture-Updates
- `./scripts/run_app_shell_macos.sh` ist der standardisierte Weg fuer reproduzierbaren foreground-Launch der App-Shell auf macOS

## Arbeitsstil

- Foundation-first, keine unnötigen Frameworks
- Decoder und Modelle klein, klar, testbar halten
- Query-Typen klein, wertbasiert und UI-unabhaengig halten
- generische Session-/Loader-Typen in app-nahem Support halten, nicht in Demo-spezifischen Views vergraben
- Demo-Views dumm halten; keine neue Business-Logik in SwiftUI schieben
- Apple-spezifische Dateiimport-UI von plattformneutralem DemoSupport trennen
- Apple-Build, Apple-Start und interaktive UI-Verifikation getrennt dokumentieren; einen erfolgreichen Build nie als UI-Lauf verkaufen
- additive Felder optional modellieren
- unbekannte additive JSON-Felder tolerieren, aber unbekannte `schema_version` weiter ablehnen
- Breaking Changes nur mit dokumentierter Contract-Version

## Monorepo-Architektur

- Dieses Repo (`LocationHistory2GPX-Monorepo`) ist das primaere integrierte Repo fuer Core Swift Package und Wrapper.
- Der Core Swift Package (Decoder, Queries, AppSupport, DemoSupport) liegt im Monorepo-Root (`Package.swift`).
- Der Xcode-Wrapper liegt unter `wrapper/` im Monorepo-Root.
- Das Xcode-Projekt referenziert den Core als lokales Swift Package per `relativePath = "../.."` (Monorepo-Root).
- Die historischen Split-Repos `LocationHistory2GPX-iOS` und `LH2GPXWrapper` bestehen weiter, aber die primaere integrierte Weiterentwicklung findet im Monorepo statt.
- Keine Business-Logik oder neue Fachtypen in den `wrapper/`-Bereich schieben.
- Keine Xcode-Projektdateien oder Bundle-Config in den Core-Root schieben.

## Roadmap-Governance

- `ROADMAP.md` enthaelt die verbindliche Delivery-Roadmap bis v1.0 einschliesslich Governance-Regeln.
- Checkboxen nur abhaken wenn Umsetzung + Tests + Doku-Sync nachweisbar.
- NEXT_STEPS darf nur offene, priorisierte naechste Arbeit enthalten.
- `wrapper/` im Monorepo-Root ist das Xcode-Projekt fuer die fertige iOS-App.

## Pflichtchecks

- `swift test`
- nativer lokaler Swift ist der Primärweg; Docker hoechstens als Ausnahmefall, nicht als Standard
- fuer Apple-Phasen zusaetzlich `git diff --check` und, wenn echte Xcode-Verifikation behauptet wird, die konkreten Xcode-Schritte im Runbook ehrlich gegenpruefen
