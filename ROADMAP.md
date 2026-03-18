# ROADMAP

## Aktueller Stand (2026-03-18)

### Abgeschlossen
Phasen 2–19 vollstaendig abgeschlossen. Lokaler iPhone-Betrieb real verifiziert (iPhone 15 Pro Max, iPhone 12 Pro Max, 2026-03-17).
Lokale Produktweiterentwicklung: Phasen 19.10–19.16 abgeschlossen.

### Aktiver lokaler Fokus
Lokale Produktweiterentwicklung (Phase 19.x): UX-Verbesserungen, Lesbarkeit, Robustheit.
Phasen 19.1–19.16 abgeschlossen. Persistenz technisch vorhanden, aktuell bewusst deaktiviert.

### Bekannte offene Bugs (nicht Teil der abgeschlossenen Phasen)
- **Searchable Days List – Schwarz-Bug (iOS dark mode):** compactDayList wechselt bei Sucheingabe zwischen List und VStack. Der VStack hat keinen Hintergrund; im dark mode erscheint der nackte NavigationStack-Hintergrund als schwarze Flaeche. Reproduzierbar bei beliebiger Sucheingabe. Fix: in Phase 19.17 adressieren.

### Persistenz-Status
Auto-Restore (ImportBookmarkStore) ist technisch implementiert und funktioniert korrekt (Phase 15).
Aktuell bewusst deaktiviert (Phase 19.5): App startet immer manuell (Open / Demo). Kein automatisches Wiederherstellen der letzten Datei.
Reaktivierung moeglich sobald iPhone-Flow gefestigt und Nutzerwert klar.

#
### Phase 19.10 – UX: iPhone TabView-Navigation + Visual Polish

**Datum:** 2026-03-18
**Ziel:** iPhone-Navigation grundlegend ueberarbeiten. TabView fuer compact (Overview + Days Tabs), farbcodierte Cards, Monatsgruppierung in Day List, farbige Stat-Cards, Actions-Menu in AppContentSplitView integriert.

- [x] Adaptive Layout: TabView mit zwei Tabs (Overview + Days) fuer iPhone compact, NavigationSplitView bleibt fuer iPad regular
- [x] Actions-Menu (Open/Demo/Clear) in AppContentSplitView integriert statt extern vom Parent
- [x] NavigationStack mit NavigationLink in Days-Tab: saubere Push-Navigation zu Day Detail
- [x] NavigationPath-Reset bei Content-Wechsel (neuer Import/Demo poppt zum Day-List-Root)
- [x] Farbcodierte Cards: Visit=blau, Activity=gruen, Path=orange (linker Farbbalken + getoeneter Hintergrund)
- [x] Farbige Stat-Cards in Overview (Days=blau, Visits=lila, Activities=gruen, Paths=orange)
- [x] Farbige Quick-Stats in Day Detail (gleiche Farbzuordnung)
- [x] Monatsgruppierung in Day List (Section Headers nach Monat, nur bei >1 Monat)
- [x] Distanzanzeige in Day-List-Rows (totalPathDistanceM, wenn >0)
- [x] Workarounds entfernt: isOverviewPushed, resetForCompact(), onChange-resetForCompact
- [x] AppDayRow als wiederverwendbare private View extrahiert (shared zwischen compact/regular)
- [x] coloredCard ViewBuilder-Helper fuer einheitliche Card-Darstellung

**Problem vorher:** NavigationSplitView kollabierte auf iPhone zu einem Stack. Overview war nur per Toolbar-Button erreichbar, nicht per Tab. Cards (Visit/Activity/Path) waren visuell identisch (gleiches Grau). Day List war flach ohne Monatsstruktur. Stat-Cards alle gleichfarben. Workarounds (resetForCompact, isOverviewPushed) waren noetig fuer brauchbare compact-Navigation.

**Jetzt:** iPhone zeigt eine echte TabView mit Overview-Tab und Days-Tab. Jeder Tab hat eigenen NavigationStack. Overview ist immer einen Tab-Tipp entfernt. Day Detail wird per NavigationLink gepusht. Cards sind farblich differenziert. Day List zeigt Monate. Stat-Cards haben individuelle Farben. Die App wirkt wie eine echte iPhone-App statt wie ein Demo-Viewer.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift (Core-Repo, Haupt-Rewrite). AppShellRootView.swift (Core-Repo, Closure-Uebergabe). ContentView.swift (Wrapper-Repo, Closure-Uebergabe).

**Nicht-Ziele:** Kein iPad-Fokus. Keine neue Business-Logik. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit.

---

### Phase 19.11 – UX: Insights-Tab + Activity/Visit-Breakdown + Overview-Enhancement

**Datum:** 2026-03-18
**Ziel:** Dritter Tab "Insights" fuer iPhone mit tiefer Statistik-Auswertung. Bisher ungenutzte Daten aus dem Query-Layer (stats.activities, stats.periods, Visit-Typen, Durchschnitte) endlich sichtbar machen. Overview-Tab mit Datumsbereich und Gesamtdistanz erweitern.

- [x] Neues Datenmodell: ExportInsights mit DateRange, ActivityBreakdown, VisitTypeBreakdown, PeriodBreakdown, DayAverages
- [x] Neue Query: AppExportQueries.insights(from:) — extrahiert Insights aus stats.activities (wenn vorhanden), sonst Fallback aus Day-Daten; aggregiert Visit-Typen, berechnet Tagesdurchschnitte
- [x] AppSessionState + AppSessionContent um insights erweitert
- [x] Neuer "Insights"-Tab im iPhone-TabView (3 Tabs: Overview, Days, Insights)
- [x] Insights-Inhalt: Daily Averages (4 Stat-Cards), Activity Types (Cards mit Count, Distanz, Dauer, Geschwindigkeit), Visit Types (Icons + Count), Period Breakdown (wenn vorhanden)
- [x] Overview-Tab erweitert: Datumsbereich-Header, Total Distance als prominente Anzeige
- [x] iPad regular: Insights unterhalb von Overview im Detail-Pane (alles scrollbar)
- [x] Visit-Typ-Icons: HOME=house, WORK=briefcase, CAFE=cup, PARK=leaf, LEISURE=gamecontroller, EVENT=star, STAY=bed
- [x] Graceful Degradation: wenn stats.activities fehlt, werden Basisdaten aus Day-Entries abgeleitet; wenn stats.periods fehlt, wird die Sektion ausgeblendet

**Problem vorher:** Die App zeigte nur 4 Basiszahlen (Days, Visits, Activities, Paths) und Activity-Typ-Namen als Comma-Text. Die reichen Statistiken aus stats.activities (Distanz, Dauer, Geschwindigkeit pro Typ) und stats.periods (Monats-/Jahresbreakdown) waren im Datenmodell komplett dekodiert aber nie in der UI sichtbar. Visit-Typen (HOME, WORK, CAFE, etc.) wurden nie aggregiert gezeigt. Kein Datumsbereich, keine Gesamtdistanz, keine Tagesdurchschnitte.

**Jetzt:** Die App hat einen vollwertigen Insights-Tab mit 4 Sektionen. Activity Types zeigen Count, Gesamtdistanz, Dauer und Durchschnittsgeschwindigkeit. Visit Types zeigen semantische Icons. Daily Averages liefern schnelle Orientierung. Die Overview zeigt Datumsbereich und Gesamtdistanz. Die App nutzt jetzt die vorhandenen Daten so aus, wie es fuer ein professionelles Produkt erwartet wird.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** ExportInsights.swift (neu, Core-Repo). AppExportQueries.swift (Core-Repo). AppSessionState.swift (Core-Repo). AppContentSplitView.swift (Core-Repo). Wrapper-Repo via SPM automatisch aktuell.

**Nicht-Ziele:** Keine Charts/Graphen. Kein iPad-Fokus. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit.

---

### Phase 19.14 – Days Navigation + Insights Depth

**Datum:** 2026-03-18
**Ziel:** Days-Tab mit Suche und Highlight-Markierungen. Insights mit Wochentags-Chart, Count/Distance-Umschalter fuer Activity-Types und verbesserter Distanz-Zeitachse. Map mit Style-Toggle und farbcodierten Visit-Markern.

- [x] Days-Tab: Suchfeld (filtert nach Datum, z.B. "2024-03" oder "2024-03-15")
- [x] Days-Tab: Busiest Day + Longest Distance Day in der Tagesliste markiert (flame / road Icon)
- [x] Days-Tab: Suchfeld-Reset bei Content-Wechsel
- [x] Insights: Distance-Over-Time-Chart nutzt echte Date-Achse (temporal, nicht kategorisch)
- [x] Insights: Activity-Type-Chart Count/Distance-Toggle (Segmented Picker)
- [x] Insights: Neuer "By Day of Week" Wochentags-Chart (Mon-Sun, avg events per weekday, ab 3 Tagen)
- [x] Insights: Chart-Farben ohne .gradient (bessere Dark-Mode-Lesbarkeit)
- [x] Map: Style-Toggle (Standard / Satellite Hybrid) als overlay Button
- [x] Map: Visit-Marker farbkodiert nach Typ (HOME=blau, WORK=indigo, CAFE=orange, PARK=gruen, etc.)

**Problem vorher:** Days-Liste war nicht durchsuchbar. Highlight-Tage waren nur in Overview sichtbar, nicht in der Tagesliste. Distance-Chart hatte kategorische Achse (String-Dates). Activity-Type-Chart zeigte nur Count, nicht Distanz. Kein Wochentags-Muster sichtbar. Map immer Standard, alle Visit-Marker rot.

**Jetzt:** Days-Tab ist durchsuchbar. Busiest/Longest-Tage haben subtile Icons in der Liste. Distance-Chart hat korrekte temporale Achse mit Luecken bei fehlenden Tagen. Activity-Chart umschaltbar zwischen Count und Distanz. Neuer Wochentags-Chart zeigt Aktivitaetsmuster Mo-So. Map hat Style-Toggle und farbige Visit-Marker nach Typ.

**Tests:** swift test gruen (70/70). swift build + xcodebuild BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift (Days-Suche, Highlight-Icons, Charts). AppDayMapView.swift (Style-Toggle, Visit-Marker-Farben).

**Nicht-Ziele:** Kein iPad-Fokus. Keine Persistenz. Keine Apple-/ASC-Arbeit.

---

### Phase 19.15 – Day-Detail-Timeline + tappbare Overview-Stat-Cards

**Datum:** 2026-03-18
**Ziel:** Gantt-Zeitleiste im Day-Detail. Overview-Stat-Cards navigierbar.

- [x] DayTimelineView: Gantt-Balken fuer Visits (blau) und Activities (gruen) auf gemeinsamer Zeitachse (GeometryReader, ISO8601-Parsing, Start/End-Labels)
- [x] AppDayDetailView: DayTimelineView nach der Karte eingebunden
- [x] AppOverviewSection: statCard mit optionalem action-Parameter; chevron-Indicator bei interaktiven Karten
- [x] Overview-Stat-Cards: Days → Days-Tab, Visits/Activities/Paths → Insights-Tab (nur iPhone compact, iPad nil)

**Tests:** swift test gruen. swift build + xcodebuild BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift.

**Nicht-Ziele:** Kein iPad-Fokus. Kein Tap-Effekt auf Timeline (rein visuell). Keine Persistenz. Keine Apple-/ASC-Arbeit.

---

### Phase 19.16 – ZIP-Import (ZipFoundation)

**Datum:** 2026-03-18
**Ziel:** app_export.json direkt aus einer .zip-Datei importieren.

- [x] Package.swift: ZipFoundation 0.9.19+ als SPM-Dependency; LocationHistoryConsumerAppSupport verknuepft
- [x] AppContentLoader: loadImportedContent erkennt .zip per Dateiendung; loadZipContent sucht app_export.json an Root und in Unterverzeichnissen
- [x] Neuer Fehler jsonNotFoundInZip mit sprechender Meldung
- [x] AppShellRootView (Core-App-Target): fileImporter akzeptiert .json und .zip
- [x] ContentView (Wrapper, tatsaechlich auf iPhone): fileImporter korrigiert auf [.json, .zip]; Labels aktualisiert
- [x] Tests: 6 neue ZIP-Tests (valid/invalid ZIP, Unterverzeichnis, Google-Format in ZIP, Error-Descriptions); alle 76 Tests gruen

**Hinweis:** Der urspruengliche Phase-19.16-Commit hatte ContentView.swift im Wrapper vergessen. Der fileImporter dort hatte nur [.json], weshalb ZIP-Dateien ausgegraut waren. Dieser Commit behebt den echten Bug.

**Tests:** swift test 76/76 gruen. xcodebuild BUILD SUCCEEDED.

**Betroffene Dateien:** Package.swift, AppContentLoader.swift, AppShellRootView.swift (Core), ContentView.swift (Wrapper), AppContentLoaderTests.swift.

**Nicht-Ziele:** Kein iPad-Fokus. Keine Persistenz. Keine Apple-/ASC-Arbeit.

---

### Phase 19.13 – Visual Insights: Swift Charts + tappbare Navigation + Politur

**Datum:** 2026-03-18
**Ziel:** Insights-Tab von reinem Zahlenviewer zu echtem Analytics-Bereich transformieren. Swift Charts integriert. Highlight-Cards tappbar (navigieren zu Day Detail). AppSourceSummaryCard kollapsierbar. Path Cards mit Activity-Type-Icon. Map-Polylines farblich nach Activity-Type.

- [x] Swift Charts: Distanz-pro-Tag-Balkendiagramm als Hero-Sektion im Insights-Tab (tappbare Balken navigieren zu Day Detail)
- [x] Swift Charts: Activity-Type-Verteilung als horizontale Balken in Insights
- [x] Swift Charts: Visit-Type-Proportionen als horizontale Balken in Insights
- [x] Highlight-Cards (Busiest Day, Longest Distance) tappbar – navigiert zu Days-Tab + Day Detail
- [x] TabView mit Selection-Binding (selectedTab) fuer programmatischen Tab-Wechsel
- [x] AppSourceSummaryCard: DisclosureGroup – nur Titel + Source immer sichtbar, Details kollapsierbar
- [x] Path Cards: Activity-Type-Icon (Konsistenz zu Visit/Activity Cards)
- [x] Map-Polylines: Farbe nach Activity-Type (Walking=gruen, Cycling=teal, Vehicle=grau, Bus=orange, Train/Subway=lila, Running=rot, default=blau)

**Problem vorher:** Insights-Tab zeigte ausschliesslich Zahlen in Cards/Listen – kein einziger Chart trotz vollstaendiger Datenlage. Overview-Highlights waren tote Zahlen ohne Navigation. AppSourceSummaryCard zeigte Debug-artige Technikdetails immer. Path Cards hatten kein Icon. Alle Polylines waren blau.

**Jetzt:** Insights hat 3 echte Swift Charts. Das Distanz-Balkendiagramm ist die erste visuelle Zeitreihe der App. Tapping eines Balkens springt direkt zum Day Detail. Highlight-Cards sind tappbar und wechseln Tab+Destination. AppSourceSummaryCard ist kompakt (Details per DisclosureGroup erweiterbar). Path Cards haben Activity-Type-Icon. Polylines sind farblich nach Activity-Type differenziert.

**Tests:** swift test gruen (70/70). swift build BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift (Charts, Navigation, SourceSummaryCard, PathCard). AppDayMapView.swift (Polyline-Farben).

**Nicht-Ziele:** Kein iPad-Fokus. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit. Day-Detail-Timeline (Phase 19.14+).

---

### Phase 19.12 – UX: Overview-Highlights + Day-Detail-Enrichment + Filter-Transparenz

**Datum:** 2026-03-18
**Ziel:** App auf ein deutlich hoeheres Reifelevel bringen. Overview mit Highlights (Busiest Day, Longest Distance) und Filter-Transparenz. Day Detail mit Tagesdistanz, Tageszeitraum und semantischen Icons. Insights Period Breakdown farbkodiert. Informationsarchitektur professionalisiert.

- [x] Overview neu strukturiert: Highlights-Section (Busiest Day, Longest Distance Day) prominent oben
- [x] Overview: AppSourceSummaryCard (Export Details) nach unten verschoben – nutzbare Info zuerst
- [x] Overview: Activity Types Comma-Text entfernt (redundant mit Insights-Tab)
- [x] Filter-Transparenz: Aktive Export-Filter (Limit, From/To, Activity Types, etc.) als oranges Banner in Overview
- [x] Day Detail: Tagesdistanz als vierte Stat-Card (Distance, purple)
- [x] Day Detail: Tageszeitraum im Header (frueheste Startzeit → spaeteste Endzeit)
- [x] Day Detail: Visit-Cards mit semantischen Typ-Icons (HOME=house, WORK=briefcase, CAFE=cup, etc.)
- [x] Day Detail: Activity-Cards mit Typ-spezifischen Icons (WALKING=figure.walk, CYCLING=bicycle, CAR=car, BUS=bus, etc.)
- [x] Insights: Period Breakdown Cards farbkodiert (purple bei Distanz > 0)
- [x] Icon-Mapping-Funktionen als wiederverwendbare file-level Helfer extrahiert (statt dupliziert in Insights)
- [x] ExportInsights um busiestDay, longestDistanceDay, activeFilterDescriptions erweitert
- [x] AppExportQueries.insights() berechnet Highlights aus DaySummary und Filter-Beschreibungen aus ExportFilters

**Problem vorher:** Overview zeigte technische Quelle (SourceSummaryCard) vor nuetzlicher Info. Keine Highlights fuer Orientierung. Day Detail hatte keine Tagesdistanz, keinen Zeitraum, keine semantischen Icons auf Cards. Visit- und Activity-Cards waren reiner Text ohne visuelle Differenzierung. Export-Filter waren dekodiert aber unsichtbar – Nutzer wusste nicht, ob Daten gefiltert sind. Activity Types als Comma-Text in Overview redundant mit Insights-Tab.

**Jetzt:** Overview fuehrt mit Highlights (orangener Busiest Day, violetter Longest Distance Day) und Total Distance. Technische Export-Details sind sauber am Ende. Aktive Filter sind sofort als oranges Banner sichtbar. Day Detail zeigt Tagesdistanz als 4. Stat-Card, Zeitraum im Header, semantische Icons auf Visit- und Activity-Cards. Period Breakdown Cards haben Farbakzente. Die App wirkt professioneller und nutzt die vorhandenen Daten deutlich besser aus.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** ExportInsights.swift (Core-Repo, DayHighlight + neue Felder). AppExportQueries.swift (Core-Repo, Highlights + Filter). AppContentSplitView.swift (Core-Repo, Haupt-UI-Aenderungen). Wrapper-Repo via SPM automatisch aktuell.

**Nicht-Ziele:** Keine Charts/Graphen. Kein iPad-Fokus. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit.

---
## Geparkt / Extern
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

### Phase 19.6 – UX: Empty-State-Bereinigung
---

### Phase 19.7 – UX: PlaceID-Bereinigung in Visit-Cards

**Datum:** 2026-03-18
**Ziel:** Rohe Google Place IDs aus Visit-Cards entfernen. Die ID (z.B. ChIJP3Sa8ziYEmsRUKgyFmh9AQM) ist fuer Nutzer vollstaendig unlesbar und hat ohne Places-API keinen Wert.

- [x] if-let-placeID-Block aus visitCard() in AppContentSplitView.swift entfernt
- [x] Visit-Cards zeigen jetzt: Typ-Label + Zeitspanne (falls vorhanden) – klar und hinreichend

**Problem vorher:** Jeder Visit-Card mit Place ID zeigte einen rohen Google-Identifier mit building.2-Icon in tertiaerer Farbe. Kein Nutzer kann diesen String interpretieren. Wirkt unfertig.

**Jetzt:** Visit-Card zeigt Typ-Label (semanticType oder generisch "Visit") und Zeitspanne. Kein technisches Rauschen.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift (Core-Repo, visitCard). Wrapper-Repo via SPM automatisch aktuell.

**Nicht-Ziele:** Keine Places-API-Integration. Kein Netzwerk. Kein Redesign. Keine neuen Features.

---

### Phase 19.8 – UX: Overview auf iPhone compact zugaenglich + Day List als Landing

**Datum:** 2026-03-18
**Ziel:** Overview auf iPhone compact erreichbar machen. Beim Laden von Inhalten soll der Nutzer auf der Day List landen statt direkt im Day Detail des ersten Tages. Expliziter "Overview"-Button im Navigations-Header der Day List auf compact.

- [x] resetForCompact() ersetzt sanitizeCompactSelection(): bei Content-Load auf compact wird Selektion zurueckgesetzt
- [x] "Overview"-Button in Day-List-Toolbar (nur compact, nur iOS) navigiert per .navigationDestination zur Overview-Ansicht
- [x] overviewPaneContent als wiederverwendbarer ViewBuilder extrahiert (genutzt in detailPane und compact-Overview)
- [x] "Select a day from the sidebar" korrigiert zu "Select a day from the list" (platform-neutral)

**Problem vorher:** Beim Laden (Demo oder Import) wurde selectedDate automatisch auf den ersten Tag gesetzt. NavigationSplitView compact pushte sofort in Day Detail. Nutzer sah weder Day List noch Overview als Landing. Overview war auf iPhone compact nie erreichbar.

**Jetzt:** Beim Laden wird selectedDate auf compact zurueckgesetzt. Nutzer landet auf der Day List. Expliziter "Overview"-Button (chart.bar.doc.horizontal) oben links oeffnet die Overview per Push. Day Detail via Zeilentipp in der Liste erreichbar. Alle wichtigen Seiten erreichbar.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift (Core-Repo). Wrapper-Repo via SPM automatisch aktuell.

**Nicht-Ziele:** Kein iPad-Fokus. Keine neue Architektur. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit.



### Phase 19.9 – UX: iPhone Navigation-Shell + UI Polish

**Datum:** 2026-03-18
**Ziel:** iPhone-Navigation professionell ueberarbeiten. Toolbar-Ueberladung beseitigen, NavigationStack fuer Empty State, zentrierter Empty State mit App-Icon, Overview-Button mit Text-Label.

- [x] Toolbar-Buttons (Open, Demo, Clear) in ein einzelnes Actions-Menu konsolidiert (ellipsis.circle)
- [x] NavigationStack um Empty State / Loading: App-Name "LH2GPX" als Navigation-Titel sichtbar
- [x] Empty State zentriert mit Karten-Icon (map.fill): modernes iOS-Muster statt linksbundigem Text
- [x] Overview-Button in Day-List-Toolbar zeigt jetzt Text-Label (.labelStyle(.titleAndIcon)) statt nur Icon

**Problem vorher:** Drei separate Toolbar-Buttons (Open, Demo, Clear) plus Overview-Button drängten sich auf iPhone compact in der Navigation Bar. Labels wurden abgeschnitten, nur Icons sichtbar. Empty State hatte keinen NavigationStack — kein App-Name, keine Toolbar, kein einheitlicher Nav-Container. Empty State war linksbündig und ohne visuelle Identität.

**Jetzt:** Ein einzelner "..."‐Button öffnet ein Menu mit allen Aktionen (Open, Demo, Clear mit Divider). Empty State zeigt Navigation-Titel "LH2GPX", zentriertes Karten-Icon und zentrierte Buttons. Overview-Button in Day List zeigt "Overview" als lesbaren Text. Professioneller, aufgeraeuemter iPhone-Flow.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift (Core-Repo, Overview-Button-Label). AppShellRootView.swift (Core-Repo, NavigationStack + Menu + Empty State). ContentView.swift (Wrapper-Repo, NavigationStack + Menu + Empty State).

**Nicht-Ziele:** Kein Card-Redesign. Kein App-Logo. Keine neue Architektur. Kein iPad-Fokus. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit.

---


**Datum:** 2026-03-18
**Ziel:** AppSourceSummaryCard aus dem leeren (Idle-)Startzustand entfernen. Der Nutzer sieht beim ersten Oeffnen kein technisches Rauschen ("Source: None", "Schema: n/a"), sondern nur Titel, Erklaerungstext und Aktions-Buttons.

- [x] AppSourceSummaryCard aus AppShellEmptyStateView (Core-Repo) entfernt
- [x] summary-Parameter aus AppShellEmptyStateView entfernt (nicht mehr benoetigt)
- [x] AppSourceSummaryCard aus ContentView.emptyStateView (Wrapper-Repo) entfernt
- [x] AppSourceSummaryCard bleibt unveraendert im geladenen Overview-Pane (AppSessionStatusView)

**Problem vorher:** Im Idle-Zustand (kein Export geladen) zeigte die App eine graue Info-Card mit "No app export loaded", "Source: None" und wiederholendem Statustext. Dieser Inhalt duplizierte den bereits vorhandenen Titel/Untertitel und wirkte technisch statt einladend.

**Jetzt:** Empty State zeigt direkt: Titel, Erklaerung, ggf. Fehler-Card, Aktions-Buttons. Kein technisches Rauschen.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** AppShellRootView.swift (Core-Repo); ContentView.swift (Wrapper-Repo).

**Nicht-Ziele:** Keine Aenderung des AppSessionState. Keine Aenderung der AppSourceSummaryCard selbst. Kein Redesign.

---


### Phase 19.10 – UX: iPhone TabView-Navigation + Visual Polish

**Datum:** 2026-03-18
**Ziel:** iPhone-Navigation grundlegend ueberarbeiten. TabView fuer compact (Overview + Days Tabs), farbcodierte Cards, Monatsgruppierung in Day List, farbige Stat-Cards, Actions-Menu in AppContentSplitView integriert.

- [x] Adaptive Layout: TabView mit zwei Tabs (Overview + Days) fuer iPhone compact, NavigationSplitView bleibt fuer iPad regular
- [x] Actions-Menu (Open/Demo/Clear) in AppContentSplitView integriert statt extern vom Parent
- [x] NavigationStack mit NavigationLink in Days-Tab: saubere Push-Navigation zu Day Detail
- [x] NavigationPath-Reset bei Content-Wechsel (neuer Import/Demo poppt zum Day-List-Root)
- [x] Farbcodierte Cards: Visit=blau, Activity=gruen, Path=orange (linker Farbbalken + getoeneter Hintergrund)
- [x] Farbige Stat-Cards in Overview (Days=blau, Visits=lila, Activities=gruen, Paths=orange)
- [x] Farbige Quick-Stats in Day Detail (gleiche Farbzuordnung)
- [x] Monatsgruppierung in Day List (Section Headers nach Monat, nur bei >1 Monat)
- [x] Distanzanzeige in Day-List-Rows (totalPathDistanceM, wenn >0)
- [x] Workarounds entfernt: isOverviewPushed, resetForCompact(), onChange-resetForCompact
- [x] AppDayRow als wiederverwendbare private View extrahiert (shared zwischen compact/regular)
- [x] coloredCard ViewBuilder-Helper fuer einheitliche Card-Darstellung

**Problem vorher:** NavigationSplitView kollabierte auf iPhone zu einem Stack. Overview war nur per Toolbar-Button erreichbar, nicht per Tab. Cards (Visit/Activity/Path) waren visuell identisch (gleiches Grau). Day List war flach ohne Monatsstruktur. Stat-Cards alle gleichfarben. Workarounds (resetForCompact, isOverviewPushed) waren noetig fuer brauchbare compact-Navigation.

**Jetzt:** iPhone zeigt eine echte TabView mit Overview-Tab und Days-Tab. Jeder Tab hat eigenen NavigationStack. Overview ist immer einen Tab-Tipp entfernt. Day Detail wird per NavigationLink gepusht. Cards sind farblich differenziert. Day List zeigt Monate. Stat-Cards haben individuelle Farben. Die App wirkt wie eine echte iPhone-App statt wie ein Demo-Viewer.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** AppContentSplitView.swift (Core-Repo, Haupt-Rewrite). AppShellRootView.swift (Core-Repo, Closure-Uebergabe). ContentView.swift (Wrapper-Repo, Closure-Uebergabe).

**Nicht-Ziele:** Kein iPad-Fokus. Keine neue Business-Logik. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit.

---

### Phase 19.11 – UX: Insights-Tab + Activity/Visit-Breakdown + Overview-Enhancement

**Datum:** 2026-03-18
**Ziel:** Dritter Tab "Insights" fuer iPhone mit tiefer Statistik-Auswertung. Bisher ungenutzte Daten aus dem Query-Layer (stats.activities, stats.periods, Visit-Typen, Durchschnitte) endlich sichtbar machen. Overview-Tab mit Datumsbereich und Gesamtdistanz erweitern.

- [x] Neues Datenmodell: ExportInsights mit DateRange, ActivityBreakdown, VisitTypeBreakdown, PeriodBreakdown, DayAverages
- [x] Neue Query: AppExportQueries.insights(from:) — extrahiert Insights aus stats.activities (wenn vorhanden), sonst Fallback aus Day-Daten; aggregiert Visit-Typen, berechnet Tagesdurchschnitte
- [x] AppSessionState + AppSessionContent um insights erweitert
- [x] Neuer "Insights"-Tab im iPhone-TabView (3 Tabs: Overview, Days, Insights)
- [x] Insights-Inhalt: Daily Averages (4 Stat-Cards), Activity Types (Cards mit Count, Distanz, Dauer, Geschwindigkeit), Visit Types (Icons + Count), Period Breakdown (wenn vorhanden)
- [x] Overview-Tab erweitert: Datumsbereich-Header, Total Distance als prominente Anzeige
- [x] iPad regular: Insights unterhalb von Overview im Detail-Pane (alles scrollbar)
- [x] Visit-Typ-Icons: HOME=house, WORK=briefcase, CAFE=cup, PARK=leaf, LEISURE=gamecontroller, EVENT=star, STAY=bed
- [x] Graceful Degradation: wenn stats.activities fehlt, werden Basisdaten aus Day-Entries abgeleitet; wenn stats.periods fehlt, wird die Sektion ausgeblendet

**Problem vorher:** Die App zeigte nur 4 Basiszahlen (Days, Visits, Activities, Paths) und Activity-Typ-Namen als Comma-Text. Die reichen Statistiken aus stats.activities (Distanz, Dauer, Geschwindigkeit pro Typ) und stats.periods (Monats-/Jahresbreakdown) waren im Datenmodell komplett dekodiert aber nie in der UI sichtbar. Visit-Typen (HOME, WORK, CAFE, etc.) wurden nie aggregiert gezeigt. Kein Datumsbereich, keine Gesamtdistanz, keine Tagesdurchschnitte.

**Jetzt:** Die App hat einen vollwertigen Insights-Tab mit 4 Sektionen. Activity Types zeigen Count, Gesamtdistanz, Dauer und Durchschnittsgeschwindigkeit. Visit Types zeigen semantische Icons. Daily Averages liefern schnelle Orientierung. Die Overview zeigt Datumsbereich und Gesamtdistanz. Die App nutzt jetzt die vorhandenen Daten so aus, wie es fuer ein professionelles Produkt erwartet wird.

**Tests:** swift test gruen (70/70). xcodebuild build im Wrapper-Repo BUILD SUCCEEDED.

**Betroffene Dateien:** ExportInsights.swift (neu, Core-Repo). AppExportQueries.swift (Core-Repo). AppSessionState.swift (Core-Repo). AppContentSplitView.swift (Core-Repo). Wrapper-Repo via SPM automatisch aktuell.

**Nicht-Ziele:** Keine Charts/Graphen. Kein iPad-Fokus. Keine Persistenz-Aktivierung. Keine Apple-/ASC-Arbeit.

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
