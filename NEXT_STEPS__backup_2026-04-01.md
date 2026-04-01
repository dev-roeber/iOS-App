# NEXT_STEPS

Abgeleitet aus der ROADMAP. Nur die aktuell offenen, fachlich sinnvoll priorisierten Folgepakete.
Der Repo-Truth- und Audit-Sync vom 2026-03-31 ist in diesem Batch bewusst geschlossen und taucht hier nicht mehr als offener Punkt auf.

## 1. Phase 19.51 – Live / Upload / Insights / Days auf Apple verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- `Days` ist repo-wahr standardmaessig `neu -> alt` sortiert; Initialauswahl und Fallbacks bevorzugen den neuesten inhaltshaltigen Tag
- der dedizierte `Live`-Tab wurde visuell und funktional deutlich ausgebaut: klarere Map-/Recording-/Upload-/Library-Hierarchie, Status-Chips, Quick Actions und mehr Live-Metriken
- der optionale Server-Upload zeigt Queue-, Failure- und Last-Success-Zustaende und unterstuetzt Pause/Resume sowie manuellen Queue-Flush
- die Insights-Seite bietet segmentierte Oberflaechen (`Overview`, `Patterns`, `Breakdowns`) sowie KPI-Karten, Highlight-Karten, `Top Days`, Monatstrends und umschaltbare Distanz-/Route-/Event-Muster
- gezielte Linux-Teilverifikation fuer diese Bereiche liegt vor; der frische Gesamtlauf auf diesem Host ist `swift test` mit `228` Tests, `2` Skips und `0` Failures

Fehlt noch:
- frische Apple-UI-Verifikation fuer den neuen `Live`-Tab inklusive Upload-Zustaenden, Quick Actions und groesserem Stat-Set
- frische Apple-UI-Verifikation fuer die neue `Insights`-Informationsarchitektur und Chart-Lesbarkeit
- frische Apple-UI-Verifikation fuer die absteigende `Days`-Default-Sortierung im echten iPhone-/macOS-Flow

## 2. Phase 19.52 – Heatmap testen und auf Apple verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- `AppHeatmapView` ist implementiert und als eigenes Heatmap-Sheet verdrahtet
- das Heatmap-Sheet bietet lokale Display-Controls fuer Deckkraft, Radius-Presets, `Auf Daten zoomen` und eine kleine Dichte-Legende
- der Renderer nutzt geglaettete aggregierte Polygon-Zellen, viewport-basierte Zellselektion und wiederverwendbares LOD-/Viewport-Caching
- die spaeteren Detail-Visibility-Polishes machen niedrige und mittlere Dichte frueher sichtbar und farbiger, ohne die LOD-/Viewport-Architektur aufzugeben
- kleine dedizierte Heatmap-Regressionstests fuer LOD-Aggregation, viewport-begrenzte Zellselektion sowie Intensitaets-/Opacity-/Palette-Mapping sind vorhanden
- ein echter iPhone-15-Pro-Max-AX-Snapshot aus dem Wrapper zeigt `Heatmap` bei geladenem Import sichtbar verdrahtet

Fehlt noch:
- echtes Oeffnen des Heatmap-Sheets auf Apple-Hardware
- visuelle Apple-Verifikation des neuen Polygon-/Aggregations-Renderers inklusive der spaeteren Detail-Visibility-Polishes auf echter Apple-Hardware
- Performance-Nachweis fuer groessere Imports auf Apple-Hardware

## 3. Phase 19.53 – Frischen Apple-CLI-Gegenlauf fuer den aktuellen Stand nachziehen

Status: **offen**

Bereits drin:
- historische Apple-CLI-Nachweise fuer 2026-03-30 sind dokumentiert
- der frische Linux-Mindestnachweis auf diesem Host ist `swift test`: `228` Tests, `2` Skips und `0` Failures
- Apple-only Heatmap-Renderingstests sind fuer non-Apple-Plattformen korrekt gegated und blockieren den Linux-Lauf nicht
- die frueheren Test-vs-Code-Drifts (`minimumBatchSize`, Keychain-first, Gedankenstrich-Formatierung) sind repo-wahr bereinigt

Fehlt noch:
- frischer `xcodebuild`-Gegenlauf fuer genau diesen konsolidierten Repo-Stand; auf diesem Linux-Server derzeit nicht moeglich
- aktualisierter Apple-CLI-Nachweis fuer Core (`LocationHistoryConsumerApp` / `LocationHistoryConsumer-Package`) und Wrapper (`LH2GPXWrapper`) auf einem Apple-Host

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
- optionaler Bearer-Token (im Keychain gespeichert)
- Retry-on-next-sample
- Upload-Batching
- Pause/Resume, manueller Flush sowie Queue-/Failure-/Last-Success-Status
- repo-wahre Review-/Runbook-Wording-Basis ohne finale Apple-Freigabeclaims
- hart kodierter Test-Server-Endpunkt entfernt: `defaultTestEndpointURLString = ""`
- PrivacyInfo.xcprivacy vorhanden unter `wrapper/LH2GPXWrapper/PrivacyInfo.xcprivacy`: `NSPrivacyTracking: false`, UserDefaults CA92.1 deklariert
- `NSPrivacyCollectedDataTypes` in PrivacyInfo.xcprivacy ist derzeit leer

Fehlt noch:
- End-to-End-Device-Verifikation mit echtem HTTPS-Endpunkt
- Apple-seitige Scope-/Review-Entscheidung: muss `NSPrivacyCollectedDataTypes` für den optionalen Standort-Upload (Lat/Lon/Timestamp/Accuracy) in PrivacyInfo.xcprivacy ergänzt werden? Benötigt Apple-Hardware und ggf. Store-Review-Feedback
- Prüfen ob ZIPFoundation-Abhängigkeit file-timestamp-Zugriffe deklarieren muss (`NSPrivacyAccessedAPICategoryFileTimestamp` in PrivacyInfo.xcprivacy) — auf Apple-Host mit `xcodebuild` prüfen
- Datenschutzrichtlinien-URL und Support-URL für App Store Connect (extern, Pflichtfelder)
- Technische Basis ist dokumentiert in `docs/PRIVACY_MANIFEST_SCOPE.md`

## 7. Phase 19.57 – Weiterer Insights-Ausbau + breitere Lokalisierung (teilweise umgesetzt)

Status: **teilweise umgesetzt**

Bereits drin (2026-04-01 DE-Lokalisierung):
- alle neuen Analytics/Insights/Overview/Custom-Range-Strings vollstaendig auf DE lokalisiert: Preset-Chips, KPI-Labels, KPI-Notes, Custom-Range-Sheet, Overlap-Map-Strings, Filter-Picker, Map-Meldungen, Empty/Sparse-States
- `AppCustomDateRangeSheet` leitet alle 9 user-facing Strings ueber `preferences.localized(_:)` — kein EN-Hardcode mehr
- `AppOverlapMapView` leitet alle UI-Strings ueber `t(_:)`
- 3 Duplikat-Schluessel beseitigt (verhinderten RuntimeFatal); alle 309 Tests gruen

Bereits drin (2026-04-01 DE-Lokalisierung Finish – Format-Strings + Monatsnamen):
- `CustomDateRangeValidator.chipLabel` lokalisiert: Monatsnamen via `DateFormatter.shortMonthSymbols` mit `locale`-Parameter; kein hardkodiertes EN-Array mehr
- `AppInsightsContentView`: fuenf EN-Hardcodes entfernt – `"of N total"`, `"N events"`, EN-Wochentagsnamen-Dictionary und `"N day/days"` ueber `t()` bzw. `localizedWeekdayName(_:)` lokalisiert; alle 309 Tests gruen

Bereits drin (2026-04-01 DE-Lokalisierung Final – rangeDescription):
- `AppLanguagePreference.localized(_:pluralFmt:count:)` – neue Hilfsmethode fuer Singular/Plural-Format-Keys
- `AnalyticsDateRangeBuilder.rangeDescription` – alle Presets mit Format-String-Lookup und Singular/Plural; kein `day`/`days`-Hardcode mehr
- `OverviewPresentation.rangeKPIs` – `rangeNote` ab Erzeugung lokalisiert; alle 319 Tests gruen

Bereits drin (2026-04-01 InsightsChartSupport rangeNote-Lokalisierung):
- `InsightsChartSupport.distanceSectionMessage`, `.monthlyTrendSectionHint` und `.weekdaySectionHint` – optionaler `language`-Parameter; Basis und Suffix aus Dictionary
- `AppInsightsContentView` – alle drei Aufrufstellen auf `language: preferences.appLanguage`
- 6 neue Tests; alle 325 Tests gruen, 2 Skips, 0 Failures

Fehlt noch:
- weitere Exportformate wie `CSV` oder `KMZ`
- frische Apple-UI-Verifikation fuer Range-Picker, Custom-Datumsbereich-Sheet und Overlap-Karte auf echtem iPhone
- vollstaendige Lokalisierungsabdeckung aller verbleibenden EN-Strings (Rest-Abdeckung)

Contract-Files werden weiterhin ausschliesslich vom Producer-Repo aus aktualisiert.
