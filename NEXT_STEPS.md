# NEXT_STEPS

Abgeleitet aus der ROADMAP. Nur die aktuell offenen, fachlich sinnvoll priorisierten Folgepakete.
Der Repo-Truth- und Audit-Sync vom 2026-03-31 ist in diesem Batch bewusst geschlossen und taucht hier nicht mehr als offener Punkt auf.

## 0. Feature Batch Phase A – Days Range + Map Drilldown

Status: **✅ abgeschlossen (2026-04-02)**

Umgesetzt:
- `Days`-Tab respektiert jetzt denselben globalen Zeitraumfilter wie `Overview`, `Insights` und `Export`; keine doppelte Range-Logik
- sichtbarer Hinweis (`HistoryDateRangeFilterBar`-Chip) im kompakten Days-Tab sowie Toolbar-Item im regulaeren Split-View, wenn ein Zeitraumfilter aktiv ist
- sauberer Empty-State wenn der Zeitraumfilter aktiv ist und keine Tage im Zeitraum liegen
- Suche, Chips, Favoriten und newest-first Sortierung arbeiten korrekt auf der range-projizierten Basis
- `InsightsDrilldownAction.showDayOnMap(String)`: neues Drilldown-Ziel fuer Einzeltag-Drilldowns mit echtem raeumlichem Bezug; navigiert direkt in den Day-Detail-View (dort inline `AppDayMapView`)
- `drilldownTargets(for:)` liefert jetzt drei Targets: `showDay`, `showDayOnMap`, `exportDay`
- keine Fake-Kartenziele fuer aggregierte Werte; keine neue Map-Funktion gebaut
- Linux-Nachweis: `swift test` → `Executed 370 tests, with 2 tests skipped and 0 failures (0 unexpected)`

## 1. Phase 19.51 – Live / Upload / Insights / Days auf Apple verifizieren

Status: **Apple-Device-Basisverifikation abgeschlossen (2026-04-02)**

Verifiziert auf iPhone 15 Pro Max via `testDeviceSmokeNavigationAndActions`:
- Live-Tab: Start/Stop-Recording real auf Geraet geprüft; Location-Permission-Prompt erscheint und wird korrekt behandelt
- Insights-Tab: Share-Button real ausgeloest (ImageRenderer-Pfad)
- Export-Tab: fileExporter real ausgeloest

Noch offen (nicht in UI-Automation testbar):
- Background-Recording-Detailpfade in kontrollierten Szenarien (App-Hintergrund nach laufender Aufnahme, explizites Stop aus Notification): kein bekanntes Problem, aber noch kein isolierter Regressionstest
- Upload-Zustaende, Queue-Flush, Pause/Resume im Live-Tab unter Echtbedingungen
- Insights-Chart-Lesbarkeit und Segmentnavigation visuell auf Device

## 2. Phase 19.52 – Heatmap testen und auf Apple verifizieren

Status: **Heatmap-Sheet-Open auf Apple-Hardware real verifiziert (2026-04-02)**

Verifiziert auf iPhone 15 Pro Max via `testDeviceSmokeNavigationAndActions`:
- Heatmap-Button in Overview erscheint und ist hittable (scroll-robust gefunden)
- Heatmap-Sheet oeffnet real (`navigationBars["Heatmap"]` erscheint)
- Sheet schliesst sauber via Done

Noch offen:
- visuelle Apple-Verifikation des Polygon-/Aggregations-Renderers auf echter Apple-Hardware (kein Produktionsproblem bekannt, nicht automatisiert pruefbar)
- Performance-Nachweis fuer groessere Imports auf Apple-Hardware

## 2a. Phase 19.52b – Restprofiling fuer Map / Day Detail nur nach Apple-Nachweis

Status: **offen, aber nachrangig**

Bereits drin:
- Day-Detail nutzt jetzt gecachte `DayMapData` aus der Session-Projektionsschicht statt wiederholter Neuableitung im View
- Day- und Export-Maps bauen stabile Renderdaten fuer Marker, Polylines und Regionen nur noch bei echten Input-Aenderungen

Fehlt noch:
- nur falls Apple-Device-Profiling danach noch Spitzen zeigt: gezieltes Restprofiling fuer Day-Detail-Map, Export-Preview-Map oder weitere Map-Pfade
- keine weitere Map-/Day-Detail-Arbeit ohne belegten Apple-Hotspot

## 3. Phase 19.53 – Frischen Apple-CLI-Gegenlauf fuer den aktuellen Stand nachziehen

Status: **offen**

Bereits drin:
- historische Apple-CLI-Nachweise fuer 2026-03-30 sind dokumentiert
- der frische Linux-Mindestnachweis auf diesem Host ist `swift test`: `Executed 363 tests, with 0 failures (0 unexpected)`
- Apple-only Heatmap-Renderingstests sind fuer non-Apple-Plattformen korrekt gegated und blockieren den Linux-Lauf nicht
- die frueheren Test-vs-Code-Drifts (`minimumBatchSize`, Keychain-first, Gedankenstrich-Formatierung) sind repo-wahr bereinigt

Fehlt noch:
- frischer `xcodebuild`-Gegenlauf fuer genau diesen konsolidierten Repo-Stand; auf diesem Linux-Server derzeit nicht moeglich
- aktualisierter Apple-CLI-Nachweis fuer Core (`LocationHistoryConsumerApp` / `LocationHistoryConsumer-Package`) und Wrapper (`LH2GPXWrapper`) auf einem Apple-Host

## 4. Phase 19.54 – Background-Recording auf echtem iPhone verifizieren

Status: **✅ auf realem Gerät verifiziert (2026-04-02)**

Verifiziert:
- Background-Recording-Codepfad
- `Always Allow`-Upgrade im Live-Location-Modell
- Wrapper-Deklarationen fuer `NSLocationAlwaysAndWhenInUseUsageDescription` und `UIBackgroundModes=location`
- Permission-Upgrade, laufende Aufnahme im Hintergrund und Stop-/Persistenzverhalten: auf echtem iPhone 15 Pro Max real geprüft und bestätigt (2026-04-02)

Bewusst nachgelagert (erfordert Developer Account):
- separater dokumentierter Nachweis im Apple-/Wrapper-Runbook noch nicht formalisiert
- TestFlight/App Store Connect: bewusst verschoben, erfordert Developer Account

## 5. Phase 19.55 – Auto-Restore / Recent Files auf echtem iPhone erneut verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- die App-Shell zeigt jetzt eine sichtbare Recent-Files-Liste im import-first Startzustand
- `Restore Last Import on Launch` ist als sichtbarer Toggle in den Optionen verdrahtet
- der App-Start nutzt den vorhandenen Bookmark-/Recent-Files-Unterbau jetzt opt-in fuer Auto-Restore
- fehlende oder stale Dateien werden sauber abgefangen statt mit rohen Nutzerfehlern eskaliert

Fehlt noch:
- kontrollierte Device-Verifikation fuer positiven Restore, Datei-fehlt-Fallback, Reopen aus Recent Files und `Clear History`
- dokumentierter Nachweis fuer den kompletten Startpfad auf echter Apple-Hardware

## 6. Phase 19.58 – Days / Day Detail / CSV auf Apple verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- `Days` zeigt sichtbare Filterchips fuer `Favorites`, `Has Visits`, `Has Routes`, `Has Distance` und `Exportable`
- Favoriten lassen sich in der Liste per Swipe/Kontextmenue und im Day Detail direkt toggeln; Persistenz bleibt lokal
- Day Detail zeigt sichtbare per-route Auswahl einzelner exportierbarer Routen inklusive `Reset to All Routes`
- `CSV` ist als echtes Dateiformat im bestehenden Export-Flow aktiv und respektiert Zeitraum, Day-Selection und explizite Route-Selektionen
- Linux-Nachweis fuer diesen Batch liegt im frischen Gesamtlauf vor: `swift test` mit `Executed 363 tests, with 0 failures (0 unexpected)`

## 7. Phase 19.59 – Insights Drilldown / Chart Share auf Apple verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- datenverankerte Highlights, `Top Days`, Distanz-Zeitreihe sowie Monats-/Periodenbereiche in `Insights` koennen jetzt sichtbar nach `Days` drillen oder den `Export` vorbefuellen
- `Days` und `Export` zeigen aktive Insights-Drilldowns sichtbar als Banner und bieten eine echte Reset-Aktion
- sichtbare Share-Aktionen fuer die wichtigsten Insight-Sektionen sind verdrahtet und nutzen den vorhandenen `ChartShareHelper`
- auf Apple-Hosts rendert die View-Schicht per `ImageRenderer` eine PNG-Datei fuer den System-Share-Flow; Linux-seitig ist diese Verdrahtung nur indirekt ueber Code und Tests absicherbar
- Linux-Nachweis fuer diesen Batch liegt im frischen Gesamtlauf vor: `swift test` mit `Executed 363 tests, with 0 failures (0 unexpected)`

Fehlt noch:
- frische Apple-UI-Verifikation fuer den Drilldown-Flow von `Insights` nach `Days`
- frische Apple-UI-Verifikation fuer den Drilldown-Flow von `Insights` nach `Export`
- echte Apple-Host-Verifikation fuer `ImageRenderer`-Rendering, PNG-Ausgabe und Share-Sheet-Interaktion

Fehlt noch:
- frische Apple-UI-Verifikation fuer die Filterchip-Leiste und deren Zusammenspiel mit Suche und newest-first Sortierung
- frische Apple-UI-Verifikation fuer Favoriten-Toggle in Liste und Day Detail
- frische Apple-UI-Verifikation fuer per-route Auswahl, Reset auf alle Routen und Export-Summary auf echter Apple-Hardware
- frische Apple-UI-Verifikation fuer den sichtbaren CSV-Exportpfad inkl. Dateiname, Disabled-Reasons und `fileExporter`

## 8. Phase 19.56 – Server-Upload / Review / Privacy finalisieren

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
- **End-to-End-Device-Verifikation mit eigenem HTTPS-Endpunkt: auf realem Gerät verifiziert (2026-04-02)**

Fehlt noch (bewusst verschoben, erfordert Developer Account):
- Apple-seitige Scope-/Review-Entscheidung: muss `NSPrivacyCollectedDataTypes` für den optionalen Standort-Upload (Lat/Lon/Timestamp/Accuracy) in PrivacyInfo.xcprivacy ergänzt werden? Benötigt Apple-Hardware und ggf. Store-Review-Feedback
- Prüfen ob ZIPFoundation-Abhängigkeit file-timestamp-Zugriffe deklarieren muss (`NSPrivacyAccessedAPICategoryFileTimestamp` in PrivacyInfo.xcprivacy) — auf Apple-Host mit `xcodebuild` prüfen
- Datenschutzrichtlinien-URL und Support-URL für App Store Connect (extern, Pflichtfelder)
- Technische Basis ist dokumentiert in `docs/PRIVACY_MANIFEST_SCOPE.md`

## 9. Phase 19.57 – Weiterer Insights-Ausbau + breitere Lokalisierung (teilweise umgesetzt)

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
- frische Apple-UI-Verifikation fuer Range-Picker, Custom-Datumsbereich-Sheet und Overlap-Karte auf echtem iPhone
- vollstaendige Lokalisierungsabdeckung aller verbleibenden EN-Strings (Rest-Abdeckung)
- weitere View-seitige Verdrahtung offener State-Felder ausserhalb dieses Batches: Chart-Share-Button in `InsightsCardView`
- Chart-Share per ImageRenderer auf Apple-Host verifizieren
- KMZ-Export

Contract-Files werden weiterhin ausschliesslich vom Producer-Repo aus aktualisiert.
