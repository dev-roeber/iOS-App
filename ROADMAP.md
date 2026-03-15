# ROADMAP

## Phase 2

- [x] Minimales Swift-Consumer-Repo bootstrappen
- [x] Contract-Artefakte aus dem Producer-Repo übernehmen
- [x] Decoder-Modelle für den stabilen App-Export anlegen
- [x] Golden-Decoding-Tests anlegen

## Phase 3

- [x] 2-3 zusätzliche realistische Golden-Faelle ergänzen
- [x] Contract- und Fixture-Guards schärfen
- [x] nativen lokalen Swift-Testlauf als Standard dokumentieren
- [x] lokalen Producer-zu-Consumer-Update-Workflow skriptbar machen

## Phase 4

- [x] UI-unabhaengige Query-/ViewState-Schicht
- [x] sortierte Day-Summaries und Day-Detail-Read-Models
- [x] Header-/Overview-Query und Datumsbereichsfilter

## Phase 5

- [x] minimale SwiftUI-Demo-/Harness-Shell
- [x] feste lokale Demo-Fixture
- [x] Overview, Day-Liste und Day-Detail auf Basis der Query-Schicht

## Phase 6

- [x] lokaler Import-Flow fuer `app_export.json` in der Demo
- [x] Demo-Fixture als Fallback neben importierter Datei beibehalten
- [x] klare Fehleranzeige fuer Datei- und Decoding-Fehler

## Phase 7

- [x] klarere Zustandsfuehrung fuer Demo, Import und Fehler
- [x] sichtbare Quelle fuer Demo-Fixture vs. importierte Datei
- [x] bessere Leer- und Fallback-Zustaende fuer Liste und Detail
- [ ] Produkt-UI

## Nicht Teil dieser Phase

- Google-Rohdaten-Import
- Karten-/Listen-UI
- Netzwerk, Analytics oder Cloud-Sync
- Producer-Business-Logik
