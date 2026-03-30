# NEXT_STEPS

Abgeleitet aus der ROADMAP. Nur die aktuell offenen, fachlich sinnvoll priorisierten Folgepakete.
Der Audit-/Doku-Sync aus Phase 19.50 ist in diesem Batch geschlossen und steht deshalb nicht mehr als offener Punkt hier.

## 1. Phase 19.51 – Live / Upload / Insights / Days auf Apple verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- `Days` ist jetzt repo-wahr standardmaessig `neu -> alt` sortiert; Initialauswahl und Fallbacks bevorzugen den neuesten inhaltshaltigen Tag
- der dedizierte `Live`-Tab wurde visuell und funktional deutlich ausgebaut: klarere Map-/Recording-/Upload-/Library-Hierarchie, Status-Chips, Quick Actions und mehr Live-Metriken
- der optionale Server-Upload zeigt jetzt Queue-, Failure- und Last-Success-Zustaende und unterstuetzt Pause/Resume sowie manuellen Queue-Flush
- die Insights-Seite bietet jetzt segmentierte Oberflaechen (`Overview`, `Patterns`, `Breakdowns`) sowie KPI-Karten, Highlight-Karten, `Top Days` und Monatstrends
- gezielte Linux-Verifikation fuer diesen Batch liegt vor: `swift test --filter Live`, `Insight`, `Day`, `Upload`

Fehlt noch:
- frische Apple-UI-Verifikation fuer den neuen `Live`-Tab inklusive Upload-Zustaenden, Quick Actions und groesserem Stat-Set
- frische Apple-UI-Verifikation fuer die neue `Insights`-Informationsarchitektur und Chart-Lesbarkeit
- frische Apple-UI-Verifikation fuer die absteigende `Days`-Default-Sortierung im echten iPhone-/macOS-Flow

## 2. Phase 19.52 – Heatmap testen und auf Apple verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- `AppHeatmapView` ist implementiert und als eigenes Heatmap-Sheet verdrahtet
- Heatmap-UX Batch 1 hat die Darstellung fuer mittlere/grosse Zoomstufen beruhigt und die Heatmap bei herausgezoomter Karte weniger flaechig dominant gemacht
- das Heatmap-Sheet bietet jetzt lokale Display-Controls fuer Deckkraft, Radius-Presets, `Auf Daten zoomen` und eine kleine Dichte-Legende
- der Heatmap-Startzustand zoomt jetzt auf die vorhandenen Daten statt nur auf einen generischen Mittelpunkt
- Heatmap Visual & Performance Batch 2 hat den Renderer auf geglaettete aggregierte Polygon-Zellen umgestellt, per-LOD sichtbare Elemente gedeckelt und viewport-basiertes Caching fuer ruhigere Zoom-/Pan-Reaktionen eingebaut
- Heatmap Color / Contrast / Opacity Batch 3 hat die Farbpallette, Intensitaetskurve und die interne Slider-Kennlinie fuer Deckkraft sichtbar verstaerkt, damit mittlere/hohe Dichte bei 100 % deutlich deckender und waermer erscheint
- kleine dedizierte Heatmap-Regressionstests fuer LOD-Aggregation, viewport-begrenzte Zellselektion sowie Intensitaets-/Opacity-/Palette-Mapping sind jetzt vorhanden
- Heatmap ist jetzt in README, ROADMAP und Feature-Inventar repo-wahr dokumentiert
- echter iPhone-15-Pro-Max-AX-Snapshot aus dem Wrapper zeigt `Heatmap` bei geladenem Import im Uebersichtsbildschirm sichtbar und erreichbar verdrahtet

Fehlt noch:
- echtes Oeffnen des Heatmap-Sheets auf Apple-Hardware
- visuelle Apple-Verifikation des neuen Polygon-/Aggregations-Renderers inklusive des kraeftigeren Batch-3-Farb-/Kontrast-Mappings auf echter Apple-Hardware
- Performance-Nachweis fuer groessere Imports auf Apple-Hardware

## 3. Phase 19.53 – Apple-CLI-Tests auf aktuellem Core-Stand stabilisieren

Status: **geschlossen (Apple Stabilization Batch 2, 2026-03-30)**

Erledigt:
- macOS-Build-Fehler behoben (iOS-only Guards, Availability-Guards, async-Fix)
- `swift test` laeuft auf macOS durch: 224 Tests, 0 Failures
- `xcodebuild test -scheme LocationHistoryConsumer-Package -destination 'platform=macOS'` laeuft auf macOS durch: 224 Tests, 0 Failures
- `swift test` laeuft auf dem aktuellen Linux-Server wieder durch: 217 Tests, 2 Skips, 0 Failures
- Apple-only Heatmap-Renderingstests sind fuer non-Apple-Plattformen korrekt gegated und blockieren den Linux-Lauf nicht mehr
- Die 3 bekannten Problemfaelle sauber klassifiziert:
  - `testAcceptedSamplesUploadToConfiguredServer`: Test-Drift – minimumBatchSize=5 blockierte 1-Punkt-Test; Test auf minimumBatchSize=1 korrigiert, jetzt gruen
  - `testFailedUploadRetriesWhenAnotherAcceptedSampleArrives`: Test-Drift – gleiche Batch-Ursache; Test korrigiert, jetzt gruen
  - `testBackgroundPreferenceActivatesClientWhenAlwaysAuthorized`: Test-Drift – Client-Konfiguration erfolgt erst beim Recording-Start, nicht bei Preference-Aenderung allein; Test an korrektes Verhalten angepasst, jetzt gruen
- `AppPreferencesTests.testStoredValuesAreLoaded`: Test an Keychain-first-Produktverhalten angepasst, jetzt gruen
- `DayDetailPresentationTests.testTimeRangeFormattingAvoidsRawISOStrings`: Test an die konsistente Gedankenstrich-Formatierung des Produktcodes angepasst, jetzt gruen

## 4. Phase 19.54 – Background-Recording auf echtem iPhone verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- Background-Recording-Codepfad
- `Always Allow`-Upgrade im Live-Location-Modell
- Wrapper-Deklarationen fuer `NSLocationAlwaysAndWhenInUseUsageDescription` und `UIBackgroundModes=location`
- echter iPhone-15-Pro-Max-Lauf bestaetigt stabilen Wrapper-Launch; der eigentliche Recording-/Background-Pfad wurde dabei noch nicht bedient

Fehlt noch:
- echte Device-Verifikation fuer Permission-Upgrade, laufende Aufnahme im Hintergrund und Stop-/Persistenzverhalten
- separater dokumentierter Nachweis im Apple-/Wrapper-Runbook

## 5. Phase 19.55 – Wrapper-Auto-Restore auf echtem iPhone erneut verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- Core-App-Shell haelt Auto-Restore bewusst geparkt
- Wrapper ruft `restoreBookmarkedFile()` beim Start wieder auf
- README und Runbooks beschreiben den Status jetzt repo-wahr
- echter iPhone-15-Pro-Max-Lauf zeigte beim App-Start bereits wiederhergestellte Quelle `Imported file: location-history.zip`

Fehlt noch:
- kontrollierte Device-Verifikation fuer den seit 2026-03-20 wieder aktiven Restore-Pfad
- dokumentierter Nachweis fuer positiven Restore, Datei-fehlt-Fallback und Clear-nach-Restore

## 6. Phase 19.56 – Server-Upload / Review / Privacy finalisieren

Status: **teilweise umgesetzt**

Bereits drin:
- HTTPS-Endpunktvalidierung
- optionaler Bearer-Token
- Retry-on-next-sample
- Upload-Batching
- Pause/Resume, manueller Flush sowie Queue-/Failure-/Last-Success-Status
- repo-wahre Review-/Runbook-Wording-Basis

Fehlt noch:
- End-to-End-Device-Verifikation mit echtem HTTPS-Endpunkt
- Apple-Review-/Privacy-Einordnung fuer den optionalen Upload-Pfad ueber die jetzt korrigierten lokalen Texte hinaus
- Entscheidung, ob Privacy-Dokumentation ueber den aktuellen Manifest-/Runbook-Stand hinaus erweitert werden muss

## 7. Phase 19.57 – Erst danach weitere Feature-Arbeit

Status: **bewusst nachgelagert**

Kommt erst nach den Verifikations- und Wahrheitsthemen oben:
- weitere Exportformate wie `CSV` oder `KMZ`
- weiterer Insights-Ausbau ueber den aktuellen Batch hinaus sowie Zeitraumsauswahl
- breitere Lokalisierungsabdeckung

Contract-Files werden weiterhin ausschliesslich vom Producer-Repo aus aktualisiert.
