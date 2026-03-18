# ROADMAP

## Aktueller Stand (2026-03-18)

### Abgeschlossen
Phasen 2–19 vollstaendig abgeschlossen. Lokaler iPhone-Betrieb real verifiziert (iPhone 15 Pro Max, iPhone 12 Pro Max, 2026-03-17).

### Aktiver lokaler Fokus
Lokale Produktweiterentwicklung (Phase 19.x): UX-Verbesserungen, Lesbarkeit, Robustheit.
Phasen 19.1–19.5 abgeschlossen. Persistenz technisch vorhanden, aktuell bewusst deaktiviert.

### Persistenz-Status
Auto-Restore (ImportBookmarkStore) ist technisch implementiert und funktioniert korrekt (Phase 15).
Aktuell bewusst deaktiviert (Phase 19.5): App startet immer manuell (Open / Demo). Kein automatisches Wiederherstellen der letzten Datei.
Reaktivierung moeglich sobald iPhone-Flow gefestigt und Nutzerwert klar.

### Geparkt / Extern
Apple-/Developer-/ASC-/TestFlight-/Release-Themen (Phasen 20–21): kein aktiver Fokus.
Bleibt geparkt bis Developer-Account-Zugang und tatsaechliche Durchfuehrung moeglich sind.

### Spaeter
- iPad-Betrieb: bewusst zurueckgestellt
- Phase 21 (v1.0 Release): erst nach abgeschlossener Beta-Phase

---

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

- [x] verbessertes Home-/Uebersichts-Layout mit kompakterem Dashboard
- [x] aufgewertete Day-Liste mit besserem Datumsformat und Summary-Cards
- [x] aufgewertetes Day-Detail mit strukturierten Sections und besserem Layout
- [x] Navigation-Flow fuer iPhone und iPad optimieren (NavigationSplitView / NavigationStack)
- [x] Leer-/Fehler-/Ladezustaende visuell polieren

**Definition of Done:** App fuehlt sich auf iPhone und iPad wie eine echte App an, nicht wie ein Harness. Alle bestehenden interaktiven Flows (Import, Demo, Clear, Fehler) funktionieren weiter. Tests gruen.

**Tests:** Bestehende Tests muessen gruen bleiben. Manueller UI-Smoke auf Geraet und Simulator. Apple-Verifikations-Checkliste aktualisieren.

**Betroffene Dateien:** `Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift`, `Sources/LocationHistoryConsumerApp/AppShellRootView.swift`, ggf. neue View-Dateien.

**Nicht-Ziele:** Keine neue Business-Logik. Keine Maps. Keine Persistenz-Erweiterung. Keine neuen Datenquellen.

---

## Phase 18 – Karten-MVP

**Ziel:** Pfade und Besuche aus dem App-Export auf einer Karte darstellen. Natuerliche Kernfunktion fuer Location-History-Daten.

- [x] MapKit-Integration in der Day-Detail-Ansicht
- [x] Pfade als Polylines auf der Karte visualisieren
- [x] Besuche als Marker/Pins darstellen
- [x] Basis-Interaktion: Zoom, Pan, Kartenausschnitt an Tagesdaten anpassen
- [x] sauberer Fallback wenn keine Koordinaten vorhanden

**Definition of Done:** Tagesansicht zeigt Pfade und Besuche auf einer Karte. Tage ohne Koordinaten zeigen keinen Kartenfehler. Tests gruen.

**Tests:** Unit-Tests fuer Coordinate-Extraction aus dem Query-Layer. Manueller Smoke auf Geraet.

**Betroffene Dateien:** `Sources/LocationHistoryConsumerAppSupport/` (neue Map-Views), ggf. `Sources/LocationHistoryConsumer/Queries/` (Coordinate-Helper).

**Nicht-Ziele:** Keine Heatmap. Kein Replay/Animation. Keine eigene Tile-Engine. Kein Offline-Map-Cache.

---

## Phase 19 – QA + Accessibility + Hardening

**Ziel:** App auf Produktionsqualitaet bringen. Barrierefreiheit, Performance bei grossen Dateien und Robustheit sicherstellen.

- [x] VoiceOver-Unterstuetzung fuer alle Screens pruefen und nachbessern
- [x] Dynamic Type in allen Views korrekt unterstuetzen
- [x] Performance-Test mit grossen App-Exports (>100 Tage, >10k Pfadpunkte)
- [x] Memory-Profiling bei grossen Dateien
- [x] Edge-Cases haerten: leere Felder, extreme Werte, fehlende Koordinaten

**Definition of Done:** VoiceOver navigiert alle Screens. Dynamic Type skaliert korrekt. Grosse Dateien laden in akzeptabler Zeit ohne Crash. Keine bekannten Crasher.

**Tests:** Accessibility-Audit in Xcode. Performance-Test mit `golden_app_export_sample_medium.json` und groesseren Fixtures. Bestehende Tests gruen.

**Betroffene Dateien:** Primaer `Sources/LocationHistoryConsumerAppSupport/` (View-Anpassungen). Ggf. neue Performance-Fixtures.

**Nicht-Ziele:** Keine neuen Features. Keine UI-Redesigns. Keine Lokalisierung (kommt ggf. spaeter).

**Nachgelagert (2026-03-17):** Realer iPhone-Betrieb (iPhone 15 Pro Max, iPhone 12 Pro Max) verifiziert: Demo, Karte, Scrollen. Import-Hardening: Google-Takeout-Format (location-history.json, Array-Root) wird jetzt mit verstaendlicher Fehlermeldung abgelehnt statt generischem Decode-Fehler. 4 neue Regressionstests. 58 Tests gruen.

---

## Lokale Produktweiterentwicklung

> Kleine, saubere lokale Produktschritte nach Phase 19. Kein Apple-Developer-Account noetig.

### Phase 19.1 – UX: Onboarding und Day-Detail-Lesbarkeit

**Datum:** 2026-03-18
**Ziel:** First-Use-Klarheit verbessern und Day-Detail-Anzeige fuer echte Nutzer lesbar machen.

- [x] Tool-Name (LocationHistory2GPX) im Empty-State-Subtitle kommuniziert
- [x] Idle-Statustext erklaert den Tool-Workflow statt generischem Datei-Hinweis
- [x] Zeitangaben in Day-Detail lesbar formatiert (ISO 8601 → lokale Uhrzeit, z. B. "7:20 AM")
- [x] Typ-Labels in Day-Detail formatiert (WALKING → Walking, IN PASSENGER VEHICLE → In Passenger Vehicle, HOME → Home)

**Definition of Done:** Nutzer sieht sofort, womit app_export.json erstellt wird. Day-Detail zeigt lesbare Uhrzeiten und verstaendliche Typ-Labels statt roher ISO-Strings und ALL_CAPS.

**Tests:** `swift test` gruen. Manueller Smoke: Day-Detail mit echten Daten auf Simulator oder Geraet.

**Betroffene Dateien:** `AppShellRootView.swift`, `AppSessionState.swift`, `AppContentSplitView.swift` (Core-Repo); `ContentView.swift` (Wrapper-Repo).

**Nicht-Ziele:** Keine Lokalisierung. Kein Redesign. Keine neuen Features.

### Phase 19.2 – UX: Clear-Flow Ghost-Button Fix

**Datum:** 2026-03-18
**Ziel:** Clear-Button verschwindet nach dem Clearen — kein sinnloser Loop mehr.

- [x] Toolbar-Clear-Button nur noch sichtbar wenn hasLoadedContent oder message.kind == .error
- [x] Empty-State-Clear-Button nur noch sichtbar wenn message.kind == .error

**Problem vorher:** Nach clearContent() setzte der State message = AppUserMessage(kind: .info, ...). Die Clear-Button-Bedingung prueft message != nil, nicht die Art der Message. Resultat: Clear-Button blieb nach dem Clearen sichtbar, obwohl keine Error-Card angezeigt wurde und nichts zu clearen war. Erneutes Klicken erzeugte dieselbe info-Message → Endlosschleife.

**Definition of Done:** Nach Clear kehrt die App in den sauberen Idle-Zustand zurueck. Kein Clear-Button sichtbar. Kein Loop.

**Tests:** swift test gruen (61/61). xcodebuild build im Wrapper-Repo erfolgreich.

**Betroffene Dateien:** AppShellRootView.swift (Core-Repo); ContentView.swift (Wrapper-Repo).

**Nicht-Ziele:** Kein Redesign. Keine State-Machine-Aenderung. Keine neuen Features.

### Phase 19.3 – UX: Activity-Types-Formatierung in Overview-Statistik

**Datum:** 2026-03-18
**Ziel:** Konsistenz zwischen Day-Detail-Typ-Labels (Phase 19.1) und Overview-Statistik herstellen.

- [x] statsActivityTypes in AppOverviewSection mit .capitalized formatiert (WALKING → Walking, IN PASSENGER VEHICLE → In Passenger Vehicle)

**Problem vorher:** Phase 19.1 hatte Typ-Labels in Day-Detail-Cards formatiert, aber die Statistik-Sektion in der Overview zeigte weiterhin Rohstrings (WALKING, IN PASSENGER VEHICLE, CYCLING, IN BUS). Jeder Nutzer mit Aktivitaetsdaten sah diesen Widerspruch.

**Definition of Done:** Overview-Statistik zeigt dieselbe lesbare Formatierung wie Day-Detail. WALKING → Walking, IN PASSENGER VEHICLE → In Passenger Vehicle, IN BUS → In Bus.

**Tests:** swift test gruen (61/61). Fixture-Verifizierung: Rohdaten sind UPPER CASE mit Leerzeichen, .capitalized korrekt.

**Betroffene Dateien:** AppContentSplitView.swift (Core-Repo, AppOverviewSection). Wrapper-Repo via SPM automatisch aktuell.

**Nicht-Ziele:** Keine Daten-Layer-Aenderung. Kein Redesign. Keine neuen Features.

### Phase 19.4 – UX: Locale-aware Distanzformatierung

**Datum:** 2026-03-18
**Ziel:** Distanzangaben in Aktivitäts- und Pfad-Cards zeigen jetzt Einheiten entsprechend der Geräte-Locale (Meilen für US-Nutzer, km für metrische Locales).

- [x] formatDistance() in AppDayDetailView durch Measurement.formatted(.measurement(width: .abbreviated, usage: .road)) ersetzt
- [x] Hardcodierte Metrisch-Formatierung (km/m) entfernt

**Problem vorher:** formatDistance() verwendete immer km und m (z. B. "1.9 km"), unabhängig von der Geräte-Locale. US-iPhone-Nutzer sahen metrische Einheiten statt Meilen/Feet.

**Jetzt:** System-Locale wird automatisch verwendet. US: "1.1 mi", "350 ft". Metrisch: "1.9 km", "350 m". Konsistent mit der Datum/Uhrzeit-Locale-Awareness aus Phase 19.1.

**Tests:** swift test grün (61/61). Deployment target iOS 26.2, Measurement.formatted seit iOS 15 verfügbar.

**Betroffene Dateien:** AppContentSplitView.swift (Core-Repo, formatDistance in AppDayDetailView). Wrapper-Repo via SPM automatisch aktuell.

**Nicht-Ziele:** Keine Einheitenauswahl durch Nutzer. Kein eigener Einheitenkonverter. Keine neuen Features.

### Phase 19.5 – Persistenz-Pause + iPhone-Einstieg klar machen

**Datum:** 2026-03-18
**Ziel:** Auto-Restore vorläufig deaktivieren. App startet immer bewusst manuell. iPhone-Einstieg ist klar und vorhersehbar.

- [x] Auto-Restore (restoreBookmarkedFile) in AppShellRootView und ContentView auskommentiert und als PARKED dokumentiert
- [x] Persistenz-Code (ImportBookmarkStore, restoreBookmarkedFile) vollstaendig erhalten
- [x] Kommentar-Dokumentation direkt im Code: "PARKED: Auto-restore temporarily disabled (Phase 19.5)"
- [x] ROADMAP und NEXT_STEPS aktualisiert

**Problem vorher:** App startete automatisch mit zuletzt importierter Datei. Auf iPhone fuehrte das zu einem eingeschraenkten, schwer vorhersehbaren Einstiegspunkt. Nutzer landete direkt in der Navigation ohne sichtbaren Ausgangspunkt.

**Jetzt:** Jeder App-Start beginnt mit dem manuellen Einstieg (Open app_export.json / Load Demo Data). Persistenz-Logik ist vollstaendig erhalten und kann jederzeit wieder aktiviert werden.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** AppShellRootView.swift (Core-Repo); ContentView.swift (Wrapper-Repo). Persistenz-Code unangetastet.

**Nicht-Ziele:** Keine Loeschung der Persistenz-Logik. Kein neues Design. Keine neue Navigation. Keine neuen Features.

---

## Geparkt / Extern

> **Apple-/Developer-/ASC-/TestFlight-/Release-Themen bleiben geparkt,**
> **bis Developer-Account-Zugang und tatsaechliche Durchfuehrung moeglich sind.**
> Diese Phasen sind vollstaendig dokumentiert, aber kein aktiver Fokus.
> iPad ebenfalls spaeter.

### Phase 20 – TestFlight + App Store Readiness (GEPARKT)

**Wartet auf:** Apple Developer Account / ASC-Zugang.

- [ ] App Store Beschreibung und Metadaten (Vorentwurf in docs/TESTFLIGHT_RUNBOOK.md im Wrapper-Repo)
- [x] App Store Screenshots fuer iPhone und iPad
- [ ] TestFlight-Build hochladen und interne Beta starten
- [x] App Store Review Guidelines pruefen (insbesondere Datenschutz, Minimal Functionality)
- [ ] Feedback aus Beta-Phase einarbeiten

**Definition of Done:** TestFlight-Build an Tester verteilt. App Store Metadaten vollstaendig. Keine Review-Guideline-Verstoesse bekannt.

**Lokal verifiziert (2026-03-17):** `xcodebuild archive` erfolgreich (v1.0, Build 1). PrivacyInfo.xcprivacy konform. Review-Guidelines geprueft: konform. App Icon ersetzt (Map-Pin + LH2GPX, kein Gradient-Placeholder mehr). Screenshot-Simulator-Workflow dokumentiert. TestFlight-Runbook in `docs/TESTFLIGHT_RUNBOOK.md` im Wrapper-Repo.

**Lokal abgeschlossen (2026-03-17):** Screenshots via UI-Test erstellt (iPhone 17 Pro Max + iPad Pro 13" M5, iOS 26.3.1). Liegen in `docs/appstore-screenshots/` im Wrapper-Repo.

**Extern – bewusst geparkt (2026-03-17):** ASC-Zugang aktuell nicht verfuegbar. Verbleibend: App Store Connect Projekt anlegen, Metadaten eintragen, Upload, TestFlight-Beta aktivieren.

**Nachgelagert:** Beta-Feedback einarbeiten (erst nach laufender Beta relevant).

**Tests:** TestFlight-Install auf echtem Geraet. Beta-Tester-Feedback. Crash-Reports pruefen.

**Betroffene Dateien:** Primaer Wrapper-Repo (App Store Connect Metadaten, Screenshots, docs/TESTFLIGHT_RUNBOOK.md). In diesem Repo ggf. kleinere Fixes aus Beta-Feedback.

**Nicht-Ziele:** Kein oeffentlicher Launch. Kein Marketing. Keine Android-Version.

---

### Phase 21 – v1.0 Release (GEPARKT – erst nach Beta-Feedback)

**Wartet auf:** Abgeschlossene TestFlight-Beta-Phase (Phase 20).

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

9. **Apple-/ASC-/TestFlight-/Release-Themen bleiben geparkt.** Phasen 20 und 21 werden erst aktiviert, wenn Developer-Account-Zugang tatsaechlich vorhanden ist. Kein Checkbox-Update in diesen Phasen solange der Zugang fehlt.
