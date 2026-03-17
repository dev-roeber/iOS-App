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

## Phase 8

- [x] klare Trennung zwischen Core, Demo und App-Shell
- [x] kleine produktnahe App-Shell-Struktur fuer lokalen `app_export.json`-Import
- [x] gemeinsame Session-/Content-Darstellung fuer Demo und App-Shell
- [ ] Produkt-UI

## Phase 9

- [x] import-first Startzustand der App-Shell klarer formulieren
- [x] aktiven Quellen-/Contract-Informationsbereich nachschärfen
- [x] Open / Replace / Demo / Clear-Fluss klarer fuehren
- [x] leere, fehlerhafte und importierte Inhaltszustaende sauberer unterscheiden

## Phase 10

- [x] Apple-/Xcode-nahe Produkt-App-Vorbereitung dokumentarisch ergaenzen
- [x] Rollen von Core / Demo / App-Support / App-Shell weiter schaerfen
- [x] produktnahe App-Shell als Apple-Einstieg klarer positionieren
- [x] Linux- und Apple-Verifikationsgrenzen ehrlich dokumentieren

## Phase 11

- [x] Xcode-Runbook fuer das Swift Package und die produktnahe App-Shell dokumentieren
- [x] Apple-Verifikations-Checkliste mit klaren Erfolgskriterien anlegen
- [x] erste echte macOS-/Xcode-Build-Verifikation fuer `LocationHistoryConsumerApp` dokumentieren
- [x] ersten echten Startversuch des gebauten App-Shell-Binaries dokumentieren
- [x] interaktive Apple-UI-Verifikation fuer Demo-Laden, Dateiimport, Clear und Fehlerfaelle abschliessen

## Phase 12

- [x] erste echte foreground-Apple-UI-Session fuer die produktnahe App-Shell dokumentieren
- [x] nativen Apple-Dateiimporter mit gueltiger Datei, invalidem JSON und no-days-Zustand real verifizieren
- [x] reproduzierbare Zero-Day-Fixture fuer Apple-UI-Verifikation ergaenzen

## Phase 13

- [x] reproduzierbares macOS-Launch-Script fuer die App-Shell (`scripts/run_app_shell_macos.sh`)
- [x] temporaere ad-hoc-App-Wrapper-Konvention durch standardisiertes Script ersetzen
- [x] Apple-Verifikations-Checkliste aktualisieren
- [x] Xcode-Runbook mit CLI-Launch-Abschnitt ergaenzen

## Phase 14 – Roadmap Rebaseline + Truth-Governance

**Ziel:** Belastbare Delivery-Roadmap bis App v1.0 im Repo verankern. Governance-Regeln fuer konsistente Pflege einfuehren.

- [x] feinschrittige Roadmap ab Phase 14 bis v1.0 in ROADMAP.md ergaenzen
- [x] Governance-Regeln fuer Roadmap-Pflege im Repo verankern
- [x] NEXT_STEPS.md auf die naechsten realen offenen Schritte ableiten
- [x] bestehende Doku-Inkonsistenzen bereinigen (XCODE_APP_PREPARATION.md veralteter Status)
- [x] README.md und AGENTS.md nur minimal synchronisieren

**Definition of Done:** Roadmap bis v1.0 vorhanden, Governance-Block in ROADMAP.md, NEXT_STEPS abgeleitet, Doku-Sync sauber, `swift test` gruen, `git diff --check` sauber.

**Tests:** `swift test`, `git diff --check`. Keine Code-Aenderungen, daher keine neuen Tests.

**Betroffene Dateien:** `ROADMAP.md`, `NEXT_STEPS.md`, `README.md`, `AGENTS.md`, `docs/XCODE_APP_PREPARATION.md`.

**Nicht-Ziele:** Keine Implementierung. Keine neuen Features. Keine neuen Dateien ausser ggf. minimale Doku-Korrekturen.

---

## Phase 15 – Lokale Persistenz + Import-Lebenszyklus

**Ziel:** Die App merkt sich die zuletzt importierte Datei und laedt sie beim Neustart automatisch. Ohne das ist die App praktisch bei jedem Start leer.

- [x] Security-Scoped Bookmarks fuer importierte Dateien speichern und wiederherstellen
- [x] letzten Import-Pfad ueber App-Neustarts hinweg persistent halten
- [x] automatischen Re-Load beim App-Start, falls Bookmark vorhanden und gueltig
- [x] sauberen Fallback wenn gespeicherte Datei nicht mehr erreichbar ist
- [x] Tests fuer Bookmark-Speicherung, -Wiederherstellung und Fehlerfaelle

**Definition of Done:** App startet mit zuletzt importierter Datei, wenn vorhanden. Fehlender/ungueltiger Bookmark fuehrt sauber zum import-first-Zustand. Tests gruen.

**Tests:** Unit-Tests fuer Bookmark-Storage-Logik. Manueller Smoke: App schliessen, neu starten, Datei noch da.

**Betroffene Dateien:** `Sources/LocationHistoryConsumerAppSupport/` (neuer Bookmark-/Persistence-Layer), `Sources/LocationHistoryConsumerApp/AppShellRootView.swift`, `Tests/`.

**Nicht-Ziele:** Keine Dateihistorie. Kein Cloud-Sync. Keine Multi-File-Verwaltung. Kein UserDefaults fuer Inhaltsdaten.

---

## Phase 16 – Wrapper-Projekt + Bundle-Grundlagen

**Ziel:** Das Xcode-Wrapper-Projekt (`LH2GPXWrapper`) wird fuer echte Geraete-Nutzung und spaetere App-Store-Einreichung vorbereitet.

- [x] App-Icon mindestens als Platzhalter in allen erforderlichen Groessen
- [x] Info.plist mit korrekten Bundle-Metadaten (Display Name, Version, Build)
- [x] PrivacyInfo.xcprivacy mit den fuer App Store Review erforderlichen Deklarationen
- [x] Signing-Konfiguration fuer Development und Distribution pruefen
- [x] Launch-Screen oder Launch-Storyboard konfigurieren
- [x] SPM-Dependency auf dieses Package stabil und reproduzierbar halten

**Definition of Done:** Wrapper baut auf echtem Geraet mit korrektem Icon, Bundle-Metadaten und Privacy-Manifest. Xcode-Archive-Build moeglich.

**Tests:** `xcodebuild archive` muss ohne Fehler durchlaufen. Geraete-Deploy manuell pruefen.

**Betroffene Dateien:** Primaer im Wrapper-Repo `LH2GPXWrapper/`. In diesem Repo ggf. kleinere Package.swift-Anpassungen.

**Nicht-Ziele:** Kein App-Store-Submit. Kein TestFlight. Kein finales Icon-Design.

**Hinweis:** Diese Phase betrifft hauptsaechlich das Wrapper-Repo, nicht dieses Library-Repo. Die Roadmap bildet den Gesamtweg bis v1.0 ab.

---

## Phase 17 – Produkt-UI: Navigation + Layout

**Ziel:** Die bestehende Basis-UI wird zu einer nutzbaren Produkt-Oberflaeche ausgebaut. Das schliesst den offenen Punkt `Produkt-UI` aus Phase 8 ab.

- [ ] verbessertes Home-/Uebersichts-Layout mit kompakterem Dashboard
- [ ] aufgewertete Day-Liste mit besserem Datumsformat und Summary-Cards
- [ ] aufgewertetes Day-Detail mit strukturierten Sections und besserem Layout
- [ ] Navigation-Flow fuer iPhone und iPad optimieren (NavigationSplitView / NavigationStack)
- [ ] Leer-/Fehler-/Ladezustaende visuell polieren

**Definition of Done:** App fuehlt sich auf iPhone und iPad wie eine echte App an, nicht wie ein Harness. Alle bestehenden interaktiven Flows (Import, Demo, Clear, Fehler) funktionieren weiter. Tests gruen.

**Tests:** Bestehende Tests muessen gruen bleiben. Manueller UI-Smoke auf Geraet und Simulator. Apple-Verifikations-Checkliste aktualisieren.

**Betroffene Dateien:** `Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift`, `Sources/LocationHistoryConsumerApp/AppShellRootView.swift`, ggf. neue View-Dateien.

**Nicht-Ziele:** Keine neue Business-Logik. Keine Maps. Keine Persistenz-Erweiterung. Keine neuen Datenquellen.

---

## Phase 18 – Karten-MVP

**Ziel:** Pfade und Besuche aus dem App-Export auf einer Karte darstellen. Natuerliche Kernfunktion fuer Location-History-Daten.

- [ ] MapKit-Integration in der Day-Detail-Ansicht
- [ ] Pfade als Polylines auf der Karte visualisieren
- [ ] Besuche als Marker/Pins darstellen
- [ ] Basis-Interaktion: Zoom, Pan, Kartenausschnitt an Tagesdaten anpassen
- [ ] sauberer Fallback wenn keine Koordinaten vorhanden

**Definition of Done:** Tagesansicht zeigt Pfade und Besuche auf einer Karte. Tage ohne Koordinaten zeigen keinen Kartenfehler. Tests gruen.

**Tests:** Unit-Tests fuer Coordinate-Extraction aus dem Query-Layer. Manueller Smoke auf Geraet.

**Betroffene Dateien:** `Sources/LocationHistoryConsumerAppSupport/` (neue Map-Views), ggf. `Sources/LocationHistoryConsumer/Queries/` (Coordinate-Helper).

**Nicht-Ziele:** Keine Heatmap. Kein Replay/Animation. Keine eigene Tile-Engine. Kein Offline-Map-Cache.

---

## Phase 19 – QA + Accessibility + Hardening

**Ziel:** App auf Produktionsqualitaet bringen. Barrierefreiheit, Performance bei grossen Dateien und Robustheit sicherstellen.

- [ ] VoiceOver-Unterstuetzung fuer alle Screens pruefen und nachbessern
- [ ] Dynamic Type in allen Views korrekt unterstuetzen
- [ ] Performance-Test mit grossen App-Exports (>100 Tage, >10k Pfadpunkte)
- [ ] Memory-Profiling bei grossen Dateien
- [ ] Edge-Cases haerten: leere Felder, extreme Werte, fehlende Koordinaten

**Definition of Done:** VoiceOver navigiert alle Screens. Dynamic Type skaliert korrekt. Grosse Dateien laden in akzeptabler Zeit ohne Crash. Keine bekannten Crasher.

**Tests:** Accessibility-Audit in Xcode. Performance-Test mit `golden_app_export_sample_medium.json` und groesseren Fixtures. Bestehende Tests gruen.

**Betroffene Dateien:** Primaer `Sources/LocationHistoryConsumerAppSupport/` (View-Anpassungen). Ggf. neue Performance-Fixtures.

**Nicht-Ziele:** Keine neuen Features. Keine UI-Redesigns. Keine Lokalisierung (kommt ggf. spaeter).

---

## Phase 20 – TestFlight + App Store Readiness

**Ziel:** App ist bereit fuer externe Beta-Tester und App Store Review.

- [ ] App Store Beschreibung und Metadaten
- [ ] App Store Screenshots fuer iPhone und iPad
- [ ] TestFlight-Build hochladen und interne Beta starten
- [ ] App Store Review Guidelines pruefen (insbesondere Datenschutz, Minimal Functionality)
- [ ] Feedback aus Beta-Phase einarbeiten

**Definition of Done:** TestFlight-Build an Tester verteilt. App Store Metadaten vollstaendig. Keine Review-Guideline-Verstoesse bekannt.

**Tests:** TestFlight-Install auf echtem Geraet. Beta-Tester-Feedback. Crash-Reports pruefen.

**Betroffene Dateien:** Primaer Wrapper-Repo (App Store Connect Metadaten, Screenshots). In diesem Repo ggf. kleinere Fixes aus Beta-Feedback.

**Nicht-Ziele:** Kein oeffentlicher Launch. Kein Marketing. Keine Android-Version.

---

## Phase 21 – v1.0 Release

**Ziel:** Erste oeffentliche Version im App Store.

- [ ] finale QA-Runde auf aktuellem iOS
- [ ] App Store Submit
- [ ] v1.0 Tag in beiden Repos
- [ ] README/Docs auf v1.0-Stand aktualisieren

**Definition of Done:** App im App Store verfuegbar. v1.0 Tag gesetzt. Doku aktuell.

**Tests:** Finaler manueller Durchlauf aller Flows auf Produktions-Build. Crash-Reports nach Release beobachten.

**Betroffene Dateien:** Beide Repos. Tags, README, ROADMAP-Status.

**Nicht-Ziele:** Keine neuen Features nach Feature-Freeze. Kein Android. Kein Cloud-Sync.

---

## Dauerhaft ausserhalb des Scopes

- Google-Rohdaten-Import oder -Parsing
- Producer-Business-Logik (bleibt im Python-Repo)
- Netzwerk, Analytics oder Cloud-Sync
- `trips_index.json` konsumieren
- Android / Play Store (ggf. separates Projekt)

---

## Roadmap-Governance

Diese Regeln gelten fuer alle kuenftigen Aenderungen an dieser Roadmap:

1. **Nur [x] bei echtem Repo-Nachweis.** Eine Checkbox wird nur abgehakt, wenn die Umsetzung im Repo nachweisbar ist UND relevante Tests gruen sind UND betroffene Doku synchronisiert wurde.

2. **Historische Eintraege nicht loeschen oder umsortieren.** Abgeschlossene Phasen bleiben unveraendert stehen. Korrekturen nur bei nachweislich falschen Aussagen, dann mit Kommentar.

3. **Neue Implementierungen muessen in ROADMAP und Doku aufgenommen werden.** Jeder Commit, der eine Phase betrifft, muss die zugehoerige Checkbox und ggf. NEXT_STEPS aktualisieren.

4. **NEXT_STEPS darf nur offene, priorisierte naechste Arbeit enthalten.** Keine erledigten Punkte. Keine vagen Wuensche. Nur die konkret naechsten 2-4 Schritte.

5. **Doku-Sync ist Pflicht.** Wenn Code und Doku sich widersprechen, muss die Doku im selben Arbeitsgang korrigiert werden. Nicht spaeter, nicht in einer separaten Phase.

6. **App-Phasen duerfen nicht als fertig gelten, solange Gates nicht real nachweisbar sind.** Insbesondere: kein App-Store-Claim ohne echten TestFlight-Build, keine Accessibility-Behauptung ohne Audit, keine Performance-Aussage ohne Messung.

7. **Zwei-Repo-Grenze ehrlich abbilden.** Phasen, die das Wrapper-Repo `LH2GPXWrapper` betreffen, muessen das klar benennen. Dieses Repo bleibt die Library-Quelle.

8. **Phase-8-Restpunkt `Produkt-UI` ist nach Phase 17 abgeschlossen.** Der offene Punkt aus Phase 8 wird nicht nachtraeglich abgehakt, sondern durch Phase 17 abgeloest.
