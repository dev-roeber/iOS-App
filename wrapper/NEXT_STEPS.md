# NEXT_STEPS

Abgeleitet aus der ROADMAP. Nur die aktuell offenen, fachlich sinnvoll priorisierten Folgepakete.
Der Repo-Truth- und Audit-Sync vom 2026-03-31 ist in diesem Batch bewusst geschlossen und taucht hier nicht mehr als offener Punkt auf.

## Abgeschlossen 2026-04-12

- [x] App Groups Entitlements: `LH2GPXWrapper.entitlements` + `LH2GPXWidget.entitlements` mit `group.de.roeber.LH2GPXWrapper`; `CODE_SIGN_ENTITLEMENTS` in `project.pbxproj` fuer alle 4 Build-Konfigurationen gesetzt — Widget-Datenaustausch via `WidgetDataStore` (UserDefaults App Group) funktioniert jetzt korrekt
- [x] fileImporter GPX/TCX: `allowedContentTypes` in `ContentView.swift` auf `[.json, .zip, .gpx, .tcx]` erweitert; `UTType.tcx` Extension in Core hinzugefuegt
- [x] Deep Link `lh2gpx://live`: `CFBundleURLTypes` in `Info.plist`, `onOpenURL`-Handler, `navigateToLiveTabRequested` + `AppContentSplitView` onChange-Observer
- [x] Widget-/Live-Activity-Lokalisierung: harte deutsche Texte ersetzt; Widget bevorzugt via App Group gespiegelte `AppLanguagePreference`, Geraetesprache als Fallback
- [x] Wrapper-/Widget-Build in CI: `wrapper/.github/workflows/xcode-test.yml` baut `LH2GPXWrapper` inkl. eingebettetem `LH2GPXWidget` (Core-Tests laufen separat in `.github/workflows/swift-test.yml`)
- [x] Widget-/Dynamic-Island-Einstellungen im Optionen-Menue sichtbar verdrahtet

## 1. Phase 19.51 – Live / Upload / Insights / Days auf Apple verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- `Days` ist repo-wahr standardmaessig `neu -> alt` sortiert; Initialauswahl und Fallbacks bevorzugen den neuesten inhaltshaltigen Tag
- der dedizierte `Live`-Tab wurde visuell und funktional deutlich ausgebaut: klarere Map-/Recording-/Upload-/Library-Hierarchie, Status-Chips, Quick Actions und mehr Live-Metriken
- der optionale Server-Upload zeigt Queue-, Failure- und Last-Success-Zustaende und unterstuetzt Pause/Resume sowie manuellen Queue-Flush
- die Insights-Seite bietet segmentierte Oberflaechen (`Overview`, `Patterns`, `Breakdowns`) sowie KPI-Karten, Highlight-Karten, `Top Days`, Monatstrends und umschaltbare Distanz-/Route-/Event-Muster
- frischer macOS-lokaler Nachweis fuer den eingebundenen Core-Stand liegt vor: `swift test` mit `964` Tests, `2` Skips und `0` Failures (HEAD post-`70254ff`, 2026-05-06)

Fehlt noch:
- frische Apple-UI-Verifikation fuer den neuen `Live`-Tab inklusive Upload-Zustaenden, Quick Actions und groesserem Stat-Set
- frische Apple-UI-Verifikation fuer die neue `Insights`-Informationsarchitektur und Chart-Lesbarkeit
- frische Apple-UI-Verifikation fuer die absteigende `Days`-Default-Sortierung im echten iPhone-/macOS-Flow
- kein echtes Road-/Path-Matching; aktueller Day-Detail-Switch ist nur Pfadvereinfachung

## 2. Phase 19.52 – Heatmap testen und auf Apple verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- `AppHeatmapView` ist implementiert und als eigenes Heatmap-Sheet verdrahtet
- das Heatmap-Sheet bietet lokale Display-Controls fuer Deckkraft, Radius-Presets, `Auf Daten zoomen` und eine kleine Dichte-Legende
- der Renderer nutzt geglaettete aggregierte Polygon-Zellen, viewport-basierte Zellselektion und wiederverwendbares LOD-/Viewport-Caching
- die spaeteren Detail-Visibility-Polishes machen niedrige und mittlere Dichte frueher sichtbar und farbiger, ohne die LOD-/Viewport-Architektur aufzugeben
- kleine dedizierte Heatmap-Regressionstests liegen im Core-Repo vor
- echter iPhone-15-Pro-Max-AX-Snapshot aus dem Wrapper zeigt `Heatmap` bei geladenem Import sichtbar verdrahtet

Fehlt noch:
- echtes Oeffnen des Heatmap-Sheets auf Apple-Hardware
- visuelle Apple-Verifikation des neuen Polygon-/Aggregations-Renderers inklusive der spaeteren Detail-Visibility-Polishes auf echter Apple-Hardware
- Performance-Nachweis fuer groessere Imports auf Apple-Hardware

## 3. Phase 19.53 – Frischen Apple-CLI-Gegenlauf fuer den aktuellen Stand nachziehen

Status: **abgeschlossen**

- macOS-lokal frisch verifiziert (2026-05-06, HEAD post-`70254ff`):
  - `swift test`: `964` Tests, `2` Skips, `0` Failures
  - `xcodebuild -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.3.1' build`: BUILD SUCCEEDED
- Apple-only Heatmap-Renderingstests sind fuer non-Apple-Plattformen korrekt gegated
- die frueheren Test-vs-Code-Drifts (`minimumBatchSize`, Keychain-first, Gedankenstrich-Formatierung) sind repo-wahr bereinigt

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
- der Wrapper ruft `restoreBookmarkedFile()` beim Start wieder auf
- README und Runbooks beschreiben den Status repo-wahr
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
- repo-wahre Review-/Runbook-Wording-Basis ohne finale Apple-Freigabeclaims

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
