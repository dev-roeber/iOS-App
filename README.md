# LocationHistory2GPX-iOS

Minimales separates iOS-Consumer-Repo fuer den stabilen App-Export von `LocationHistory2GPX`.

## Rolle dieses Repos

- Consumer only
- keine allgemeine Producer-Pipeline oder Takeout-Aufbereitung fuer Google-Rohdaten
- keine CSV-/KMZ-Erzeugung und keine allgemeine Producer-Exportpipeline
- keine fertige Produkt-App in diesem Schritt
- offline-first als Standardverhalten, ohne Analytics-Tracking oder Cloud-Sync; optionaler nutzergesteuerter Live-Punkt-Upload ist vorhanden

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
- Google-Timeline-`location-history.json` und `.zip` lokal direkt importieren
- gegen Swift-Modelle decodieren
- read-only Query-/ViewState-Daten aus dem App-Export ableiten
- eine kleine produktnahe App-Shell-Struktur fuer lokalen JSON-/ZIP-Import bereitstellen
- die App-Shell import-first mit klarerem Quellen-/Statusbereich und Reset-/Replace-Fluss fuehren
- Live-Location auf der Karte anzeigen und als getrennten Live-Track lokal aufzeichnen; optional auch im Background weiterfuehren, wenn der Nutzer das lokal aktiviert und `Always Allow` gewaehrt
- aufgezeichnete Live-Tracks getrennt von importierter History lokal persistieren (save on stop, ohne Auto-Resume)
- lokale App-Optionen fuer Distanz-Einheit, Kartenstil, Start-Tab, Sprache, technische Importdetails, optionalen Server-Upload und dessen Upload-Batching speichern
- auf compact iPhone-Layouts unter iOS 17+ einen dedizierten `Live`-Tab fuer Live-Location und Live-Recording anzeigen
- die `Days`-Liste repo-wahr standardmaessig absteigend (`neu -> alt`) anzeigen; Monatssortierung, Suche und Navigation bleiben dabei erhalten
- die `Live`-Seite mit klarer Map-/Recording-/Upload-/Library-Hierarchie, Status-Chips, Quick Actions und erweiterten Live-Metriken wie aktueller Geschwindigkeit, Durchschnittsgeschwindigkeit, letzter Teilstrecke und Update-Alter fuehren
- den optionalen Server-Upload mit Queue-/Failure-/Last-Success-Status, Pause/Resume und manuellem Flush sichtbar und robust in der Live-UI fuehren
- die `Insights`-Seite ueber segmentierte Oberflaechen (`Overview`, `Patterns`, `Breakdowns`), KPI-Karten, Highlight-Karten, `Top Days` und Monatstrends deutlich tiefer aufbereiten
- fuer importierte History auf iOS 17+/macOS 14+ ein eigenes Heatmap-Sheet mit Deckkraft-Regler, Radius-Presets, `Auf Daten zoomen`, kleiner Dichte-Legende, geglaettetem viewport-/LOD-basiertem Aggregations-Rendering sowie frueheren Farbwechseln und sichtbar kraeftigerer Detaildarstellung fuer niedrige und mittlere Dichte oeffnen (implementiert, aber noch nicht separat Apple-/Performance-verifiziert)
- importierte History und gespeicherte Live-Tracks lokal als `GPX`, `KML` oder `GeoJSON` exportieren
- zwischen `Tracks`, `Waypoints` und `Both` als Exportmodus wechseln
- importierte History lokal nach Datum, Genauigkeit, Inhalt, Aktivitaetstyp sowie Bounding Box oder Polygon fuer den Export filtern
- akzeptierte Live-Recording-Punkte optional an einen frei konfigurierbaren HTTP(S)-Endpunkt mit optionalem Bearer-Token senden
- Shell-, Optionen-, Live-Recording- und zentrale Exportoberflaechen auf Deutsch oder Englisch anzeigen
- eine minimale lokale SwiftUI-Demo-Shell mit fixer Golden-Fixture bereitstellen
- in der Demo lokal `app_export.json` fuer denselben Consumer-Contract importieren
- Demo-Quelle, Reset und Fehlerzustaende klar sichtbar fuehren
- Golden-basierte Contract-Tests lokal ausfuehren
- klar dokumentieren, welche Producer-Artefakte konsumiert werden
- Producer-Contract-Artefakte lokal reproduzierbar aktualisieren

## Was dieses Repo aktuell bewusst nicht kann

- Producer-Logik aus dem Python-Repo
- `trips_index.json` konsumieren
- Auto-Resume eines laufenden Live-Tracks nach App-Neustart
- Mergen aufgezeichneter Live-Tracks in importierte Originaldaten
- CSV-/KMZ-Export

## Struktur

- `Sources/LocationHistoryConsumer/`
  - `AppExportModels.swift`
  - `AppExportDecoder.swift`
  - `ContractVersion.swift`
  - `Queries/*.swift`
- `Sources/LocationHistoryConsumerAppSupport/`
  - generische Session-/Loader-Typen
  - gemeinsame SwiftUI-Produkt-UI fuer App und Demo (NavigationSplitView, Dashboard, Day-Detail, Map)
- Live-Location-/Recording-Domain fuer lokales Tracking mit optionalem Background-Modus und getrennte Recorded-Track-Persistenz
- optionaler HTTP(S)-Upload akzeptierter Live-Recording-Punkte an einen nutzerkonfigurierten Server
- `Sources/LocationHistoryConsumerDemoSupport/`
  - `DemoDataLoader.swift`
  - `Resources/golden_app_export_sample_small.json`
- `Sources/LocationHistoryConsumerApp/`
- Produkt-App-Einstieg fuer lokalen JSON-/ZIP-Import
- lokale Optionen-Seite mit `UserDefaults`-basierten App-Preferences
- partielle Sprachumschaltung Deutsch/Englisch mit englischem Fallback fuer noch nicht portierte Strings
- `Sources/LocationHistoryConsumerDemo/`
  - Demo-/Harness-Einstieg fuer Fixture-zentrierte Verifikation
- `Tests/LocationHistoryConsumerTests/`
  - `AppExportGoldenDecodingTests.swift`
  - `ContractFixturePresenceTests.swift`
  - `AppExportQueriesTests.swift`
  - `DayDetailViewStateTests.swift`
  - `DayMapDataTests.swift`
  - `DemoDataLoaderTests.swift`
  - `ImportBookmarkStoreTests.swift`
- `Fixtures/contract/`
  - `app_export.schema.json`
  - `golden_app_export_*.json`
- `docs/CONTRACT.md`
- `docs/APP_FEATURE_INVENTORY.md`
- `docs/XCODE_APP_PREPARATION.md`
- `docs/XCODE_RUNBOOK.md`
- `docs/APPLE_VERIFICATION_CHECKLIST.md`
- `ROADMAP.md`
- `NEXT_STEPS.md`

## Lokale Nutzung

```bash
swift test
```

Der Standardweg ist jetzt nativer lokaler Swift 5.9.
Wenn auf macOS das aktive Developer Directory nur auf die Command Line Tools zeigt, kann fuer Apple-komplette Testlaeufe stattdessen das echte Xcode explizit gesetzt werden:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Auf Apple-Plattformen kann die lokale Demo-Harness danach ueber das Swift Package in Xcode oder per `swift run LocationHistoryConsumerDemo` gestartet werden. Sie ist bewusst keine Produkt-App. Standardmaessig nutzt sie eine feste lokale Demo-Fixture, kann aber auch lokal eine `app_export.json` fuer denselben Consumer-Contract laden.

Zusaetzlich gibt es jetzt eine kleine produktnahe App-Shell `LocationHistoryConsumerApp`. Sie startet leerer und import-zentriert, arbeitet standardmaessig offline-first und ist noch keine fertige Produkt-App. Der optionale nutzergesteuerte Server-Upload akzeptierter Live-Recording-Punkte ist separat konfigurierbar und standardmaessig deaktiviert. Unter Linux ist nur der nicht-UI-Teil ueber `swift test` ehrlich verifizierbar.

Auf dem aktuellen Linux-Server bleibt der non-Apple-Testpfad fuer dieses Repo der ehrliche Mindestnachweis. Fuer den aktuellen Live-/Upload-/Insights-/Days-Batch wurden gezielt `swift test --filter Live`, `swift test --filter Insight`, `swift test --filter Day` und `swift test --filter Upload` ausgefuehrt; diese Teilmengen sind auf diesem Server gruen. Apple-only Heatmap-Renderingstests werden auf non-Apple-Plattformen korrekt ausgeklammert.

Die aktuelle Apple-/Xcode-nahe Vorbereitung ist bewusst klein und jetzt in `docs/XCODE_RUNBOOK.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md` und der historischen Vorbereitungsnotiz `docs/XCODE_APP_PREPARATION.md` beschrieben. Es gibt weiterhin absichtlich kein aufgeblasenes `.xcodeproj`.

Fuer einen reproduzierbaren foreground-Start der App-Shell auf macOS:

```bash
./scripts/run_app_shell_macos.sh
```

Das Script baut die App per `swift build`, erstellt ein minimales `.app`-Bundle und startet es als foreground-App.

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
- nutzt weiter Decoder + Query-Layer; die neue Live-Recording-Domain bleibt davon getrennt
- zeigt aktive Quelle, Reset auf Demo und klarere Fehler-/Leerzustaende
- kein Auto-Resume, kein Background-Tracking, keine Recorded-Track-Exports
- Fehler beim Fixture- oder Datei-Load werden schlicht als Fehlzustand angezeigt

## Produkt-UI

Die Produkt-UI ist die primaere Inhaltsdarstellung dieses Repos:
- adaptives Layout: iPhone nutzt `TabView` (`Overview`, `Days`, `Insights`, `Export` und unter iOS 17+ `Live`), regular width nutzt `NavigationSplitView` mit Day-Liste und Detail-Pane
- no-content-Tage bleiben in `Days` sichtbar, werden aber nicht mehr wie normale Detailziele behandelt
- `Days` ist standardmaessig `neu -> alt` sortiert; initiale Auswahl und Fallbacks bevorzugen den neuesten inhaltshaltigen Tag
- Day-Liste fuehrt jetzt mit einem kleinen Export-Statusblock; exportmarkierte Tage tragen ein klares `Export`-Badge
- Such-Empty-States in `Days` verschweigen vorhandene GPX-Markierungen nicht mehr
- Overview-Dashboard fuehrt mit Import-Status, optionalen Export-Filtern und einem kompakten `Go To`-Block fuer `Days`, `Insights` und `Export`
- Overview-Dashboard mit klar als `Imported History` gerahmtem Statistik-Grid (Days, Visits, Activities, Paths)
- Day-Detail mit strukturierten Sections, Cards und Quick-Stats
- Day-Detail priorisiert importierte Tageshistorie, Kartenkontext und Timeline; lokale Live-Recording-/Track-Werkzeuge bleiben als sekundaerer Block getrennt
- Insights-Tab zeigt jetzt Top-Level- und Section-Empty-States fuer no-days-, sparse- und no-chart-Faelle statt leerer Flaechen
- Insights-Charts zeigen chart-spezifische Low-Data-Hinweise, robustere Day-Tap-Navigation und lesbarere Achsen
- regular-width Detailansicht bietet einen expliziten Rueckweg zur `Overview`
- Karten-MVP: MapKit-Ansicht im Day-Detail mit Pfad-Polylines und Visit-Markern (iOS 17+)
- Live-Recording-Sektion im Day-Detail und dedizierter `Live`-Tab: manueller Ein/Aus-Schalter, Permission-State, aktueller Standort, Live-Polyline, klarere Recording-/Upload-Hierarchie, Status-Chips und Quick Actions
- Live-Tracking zeigt jetzt zusaetzlich aktuelle Geschwindigkeit, Durchschnittsgeschwindigkeit, letzte Teilstrecke, Update-Alter, Distanz, Dauer, Punktzahl und Genauigkeit als sichtbare Stat-Karten
- Recorded-Track-Persistenz getrennt von importierter History; Speicherung erst beim Stoppen der Aufnahme
- Saved-Tracks-Library mit getrenntem `Edit Track`-Zugang fuer gespeicherte Live-Tracks als separater `Local Tools`-Nebenfluss
- Optionen-Seite fuer lokale Darstellung/Steuerung: Distanz-Einheit, Start-Tab, Kartenstil, Sprache, technische Importdetails und optionaler Server-Upload
- VoiceOver-Accessibility: semantische Labels, Gruppierung, dekorative Icons ausgeblendet
- konsistente Leer-/Fehler-/Ladezustaende mit SF Symbols und klaren Texten
- ein zentrales Actions-Menue in der Toolbar fuehrt Import, Demo, Optionen und Clear
- das Actions-Menue kann auf unterstuetzten Apple-Plattformen zusaetzlich ein eigenes Heatmap-Sheet fuer importierte History mit lokalen Darstellungsreglern, geglaettetem viewport-basiert aggregiertem Dichte-Rendering und verstaerktem Farb-/Kontrast-Mapping oeffnen
- Heatmap-Detailzoom zeigt jetzt auch bei duennen Daten deutlich frueher Farbe, mehr Hue-Unterschiede im Low-/Mid-Bereich und weniger blasse Flaechen, ohne den bestehenden LOD-/Viewport-Ansatz aufzugeben
- die Insights-Seite bietet jetzt segmentierte Oberflaechen (`Overview`, `Patterns`, `Breakdowns`) mit KPI-Karten, Highlight-Karten, `Top Days`, Monatstrends, Wochentags- und Aktivitaetsauswertungen
- startet mit lokalem JSON-/ZIP-Import als primaerem Einstieg
- bietet Demo-Daten als sekundaeren Fallback
- Export-Flow zeigt jetzt Auswahlstatus, Disabled-Gruende und den vorgeschlagenen Dateinamen passend zum aktiven Exportformat vor dem fileExporter-Dialog
- Export-Flow zeigt jetzt eine sichtbare Vorschaukarte fuer Routen und Waypoints und schaltet `GPX`, `KML` und `GeoJSON` als aktive Dateiformate frei
- Export-Flow bietet jetzt lokale Filter fuer importierte History nach Datumsfenster, maximaler Genauigkeit, erforderlichem Inhalt, Aktivitaetstyp sowie Bounding Box oder Polygon; gespeicherte Live-Tracks bleiben davon bewusst unberuehrt
- Export-Flow bietet jetzt die Modi `Tracks`, `Waypoints` und `Both`; Waypoints werden aus importierten Visits sowie Activity-Start/-End-Koordinaten erzeugt
- Import-Persistenz-Code (Security-Scoped Bookmark) ist vorhanden; die Core-App-Shell haelt Auto-Restore weiterhin bewusst geparkt, waehrend der separate Wrapper `restoreBookmarkedFile()` beim Start wieder aufruft
- Live-Track-Persistenz separat in einem dedizierten Recorded-Track-Store; kein Draft-Resume
- bleibt standardmaessig lokal/offline-first; optionaler Server-Upload betrifft nur akzeptierte Live-Recording-Punkte und bleibt klar vom Import-/Query-Layer getrennt

## Apple-/Xcode-Vorbereitung

- `LocationHistoryConsumerApp` ist die Produkt-App-Huelle
- `LocationHistoryConsumerDemo` bleibt der Harness-/Verifikationspfad
- `LocationHistoryConsumerAppSupport` enthaelt die gemeinsame Produkt-UI, Import-/Session-Logik
- das konkrete Xcode-Runbook steht in `docs/XCODE_RUNBOOK.md`
- die konkrete Apple-Verifikations-Checkliste steht in `docs/APPLE_VERIFICATION_CHECKLIST.md`
- `docs/XCODE_APP_PREPARATION.md` bleibt die kleinere vorbereitende Notiz aus Phase 10
- unter Linux bleiben nur SwiftPM-Build und `swift test` ehrlich verifiziert

## Apple-Verifikationsstatus

Stand 2026-03-17 ist auf einer realen macOS-/Xcode-Maschine ehrlich verifiziert:
- Xcode 26.3 erkennt die relevanten Swift-Package-Schemes
- `LocationHistoryConsumerApp` baut fuer `platform=macOS` erfolgreich per `xcodebuild`
- die produktnahe App-Shell startet sichtbar in einer echten foreground-App-Session
- `Load Demo Data`, `Open location history file`, `Open Another File`, `Clear`, invalides JSON und ein echter Zero-Day-Import wurden als reale Apple-UI-Durchgaenge verifiziert

Stand 2026-03-30 ist auf diesem aktuellen Mac-Repo-Stand per CLI erneut geprueft:
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumerApp -destination 'platform=macOS' build`: BUILD SUCCEEDED
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme LocationHistoryConsumer-Package -destination 'platform=macOS' test`: 224 Tests, 0 Failures
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: 224 Tests, 0 Failures
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project /Users/sebastian/Code/LH2GPXWrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build`: BUILD SUCCEEDED
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project /Users/sebastian/Code/LH2GPXWrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -only-testing:LH2GPXWrapperTests test`: TEST SUCCEEDED
- ein manueller Xcode-Start auf dem verbundenen iPhone bleibt fuer diesen Batch ein positiver Teilbefund, ist aber bewusst getrennt von den CLI-Build-/Test-Ergebnissen zu lesen

Stand 2026-03-30 fuer den hier dokumentierten Live-/Upload-/Insights-/Days-Batch ist auf diesem Linux-Server nur gezielt verifiziert:
- `swift test --filter Live`
- `swift test --filter Insight`
- `swift test --filter Day`
- `swift test --filter Upload`
- fuer die deutlich umgebauten Live-/Insights-Oberflaechen sowie die neue absteigende Day-Default-Sortierung existiert in diesem Batch bewusst kein frischer Apple-UI-Nachweis

Stand 2026-03-17 ist noch offen:
- ein separat protokollierter foreground-Lauf exakt ueber `Product > Run` in Xcode, falls genau dieser IDE-spezifische Weg regressionskritisch wird
- Live-Location-/Permission-Flow inklusive optionaler `Always Allow`-Erweiterung fuer Background-Recording in einer separat dokumentierten Apple-UI-Session (Simulator oder echtes iPhone)
- Heatmap-Sheet inklusive des spaeter nachgezogenen geglaetteten Aggregations-Renderers, des Batch-3-Farb-/Kontrast-Mappings und der lokalen Darstellungsregler, dedizierter `Live`-Tab sowie Upload-Batching/Upload-Status sind auf Apple-Hardware noch nicht separat verifiziert

Die zuletzt 2 roten SwiftPM-/macOS-Tests sind auf dem aktuellen Repo-Stand in Batch 2 geklaert:
- `AppPreferencesTests.testStoredValuesAreLoaded`: gruen; Test-Setup folgt jetzt dem Keychain-first-Produktverhalten
- `DayDetailPresentationTests.testTimeRangeFormattingAvoidsRawISOStrings`: gruen; Testerwartung folgt jetzt der im UI konsistent verwendeten Gedankenstrich-Formatierung

Zusatz fuer diese konkrete Maschine: mit aktivem `/Library/Developer/CommandLineTools` schlug ein nacktes `swift test` an `no such module 'XCTest'` fehl. Die aktuellen Apple-CLI-Laeufe wurden deshalb ehrlich mit `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` gefahren.

Fuer den reproduzierbaren no-days-Apple-UI-Fall gibt es jetzt zusaetzlich `Fixtures/contract/golden_app_export_no_days_zero.json`.

Wichtig: Apple-/Xcode-Verifikation ist getrennt von `swift test` zu betrachten. Linux- oder SwiftPM-Erfolge ersetzen keinen echten Apple-UI-Lauf.

## Wrapper-Repo

Das separate Xcode-Wrapper-Projekt `LH2GPXWrapper` ist ein eigenstaendiges Repo ausserhalb dieses SwiftPM-Repos. Wenn es lokal vorhanden ist, bindet es dieses Repo als lokales Swift Package ein und liefert die iOS-App mit Bundle-Metadaten, Signing, App-Icon und Privacy-Manifest. Dieses Library-Repo bleibt die alleinige Quelle fuer Decoder, Queries, AppSupport und DemoSupport.

## Roadmap

Die vollstaendige Delivery-Roadmap bis App v1.0 steht in `ROADMAP.md`. Die naechsten offenen Schritte stehen in `NEXT_STEPS.md`.
Das repo-wahre Funktionsinventar steht in `docs/APP_FEATURE_INVENTORY.md`.
