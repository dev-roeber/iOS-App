# NEXT_STEPS

## Aktuell (2026-04-13)
iOS-App ist ab jetzt das zentrale aktive Repo.

### Naechste offene Schritte:
- [x] Widget Extension Target / eingebetteter Widget-Build — im Projekt vorhanden; `LH2GPXWidget` wird per `xcodebuild` mitgebaut (Stand 2026-04-12)
- [x] Widget Privacy Manifest — `wrapper/LH2GPXWidget/PrivacyInfo.xcprivacy` erstellt und im `.xcodeproj` verankert (UserDefaults CA92.1, kein Tracking) (verifiziert 2026-04-12)
- [x] Device Smoke-Test (App startet, kein Crash) — iPhone 15 Pro Max (00008130-00163D0A0461401C): installiert, gestartet, PID stabil (verifiziert 2026-04-12)
- [x] UITests Bundle ID bereinigt — `xagr3k7xdj.de.roeber.lh2gpxwrapper.uitests` → `de.roeber.LH2GPXWrapper.UITests` (2026-04-13)
- [x] Xcode Cloud Vorbereitung — `wrapper/.xcode-version` (26.3), `wrapper/ci_scripts/` (post_clone, pre_build, post_xcodebuild), `docs/XCODE_CLOUD_RUNBOOK.md` (2026-04-13)
- [ ] **Xcode Cloud Workflow anlegen (manuell)** — Product → Xcode Cloud → Create Workflow; Details in `docs/XCODE_CLOUD_RUNBOOK.md`
- [ ] **App ID + App Group im Developer Portal registrieren** — `de.roeber.LH2GPXWrapper` + `group.de.roeber.LH2GPXWrapper` (einmalig, manuell)
- [ ] Apple-UI-Verifikation: Range-Picker, Datumsbereich-Sheet auf echtem iPhone
- [x] KMZ-Export — abgeschlossen 2026-04-12 (KMZBuilder + KMZDocument + Tests)
- [x] App Groups Entitlements / Widget-Datenaustausch — abgeschlossen 2026-04-12 (LH2GPXWrapper.entitlements + LH2GPXWidget.entitlements + pbxproj CODE_SIGN_ENTITLEMENTS)
- [x] fileImporter GPX/TCX im Wrapper — abgeschlossen 2026-04-12 (allowedContentTypes erweitert, UTType.tcx Extension)
- [x] Deep Link lh2gpx://live — abgeschlossen 2026-04-12 (CFBundleURLTypes, onOpenURL, navigateToLiveTabRequested, AppContentSplitView onChange)
- [x] Overview Map Route Budget Fix — abgeschlossen 2026-04-12 (OverviewMapRenderProfile, Grid-Selektion, Douglas-Peucker)
- [ ] Chart-Share per ImageRenderer auf Apple-Host verifizieren
- [ ] Split-Repos (LocationHistory2GPX-iOS, LH2GPXWrapper) als historisch/mirror markieren
- [x] GPS-Jump-Filter als Vorverarbeitungsstufe — `PathFilter.removeOutliers` (distanzbasiert, maxJumpMeters=5000) vor Douglas-Peucker im `.mapMatched`-Modus; 9 Tests, kein echtes Snapping (2026-04-13, cf66dd1)
- [x] Historien-Track-Editor Slice — Route-ausblenden-Overlay: `ImportedPathMutation`, `AppImportedPathMutationStore`, "Route entfernen"-Button + Alert in `AppDayDetailView`; 7 Tests (623 gesamt) (2026-04-13, caedf28)
- [x] Historien-Track-Editor: `AppImportedPathMutationStore` als `@StateObject` in `AppContentSplitView` eingebunden; beide `AppDayDetailView`-Callsites erhalten `mutations:` + `onRemovePath:`; Safety-Fix (Alert-Text) + `testDuplicateDeletionIsIgnored`; 625 Tests (2026-04-14, `3b82761` `8036a01`)
- [x] Historien-Track-Editor: Mutations-Reset bei Import-Wechsel — `validateSource(_:)` in `AppImportedPathMutationStore`; `.onChange(of: session.source)` in `AppContentSplitView` ruft reset auf Datei-Wechsel aus; Mutations bleiben bei gleichem Dateinamen erhalten; 628 Tests (2026-04-14)
- [x] Tage UI/UX Layout-Bugfixes — `GeometryReader` aus `AppDayRow` + `AppDayDetailView.contentView` entfernt; outer `ScrollView`-Wrapper aus compact Nav-Destination entfernt; Segmented Control + Globe-Button in gemeinsame Steuerzeile (`mapControlRow`); Label `"Simplified"` statt `"Simplified (Beta)"`; 630 Tests (2026-04-14)
- [x] Overview Map Performance — `buildRenderDataFast` O(N) Single-Pass ersetzt O(N² log N)-Bottleneck; Set<String>-Date-Lookup; laufende Bounding Box; Point Budget 2 Mio.; flatCoordinates-Fast-Path; Cancellation alle 100 iter.; 634 Tests (2026-04-14)
- [ ] echtes Road-/Path-Matching (Strassen-/Weg-Snapping) konzipieren; aktuelle `Simplified (Beta)`-Darstellung ist GPS-Ausreisserfilterung + Pfadvereinfachung, kein Road-Network-Abgleich
- [x] Auto-Resume einer laufenden Live-Aufzeichnung nach App-Neustart — sauberes Modell umgesetzt: SessionID+Timestamp in UserDefaults, Banner mit relativem Zeitstempel beim Start, "Aufzeichnung fortsetzen" / "Ignorieren" (kein blindes Auto-Resume, bewusst user-controlled) (2026-04-13)
- [ ] app-weite Landscape-Verifikation fuer jede Hauptseite auf Apple-Hardware nachziehen

Abgeleitet aus der ROADMAP. Nur die aktuell offenen, fachlich sinnvoll priorisierten Folgepakete.
Der Repo-Truth- und Audit-Sync vom 2026-03-31 ist in diesem Batch bewusst geschlossen und taucht hier nicht mehr als offener Punkt auf.

## Prompt 3 — Simplified Path View + Dynamic Island / Live Activity
**Status: TEILWEISE ABGESCHLOSSEN 2026-04-12**

Umgesetzt:
- Phase B1: Douglas-Peucker PathSimplification (epsilon=15m, keine externen Deps)
- AppDayPathDisplayMode enum (.original / .mapMatched) mit @AppStorage-Persistenz
- Toggle in AppDayDetailView fuer Original vs. vereinfachte Darstellung (`Simplified (Beta)`)
- Phase B2: ActivityKit Live Activity (iOS 16.1+)
- TrackingAttributes + TrackingStatus (ActivityAttributes)
- ActivityManager Singleton: start/update/end/cancelAll
- Integration in LiveLocationFeatureModel und LiveTrackRecorder
- NSSupportsLiveActivities = true in Info.plist
- 9 neue MapMatchingTests + 7 neue LiveActivityTests = 16 neue Tests, 546 gesamt, 0 Failures

Bewusst offen:
- kein echtes Straßen-/Wege-Snapping
- kein Resume laufender Live-Tracks nach Relaunch

## Multi-Source Import Foundation (2026-04-12)

Status: **✅ abgeschlossen (2026-04-12)**

Umgesetzt:
- GPX 1.1 import (`GPXImportParser`): trk/trkseg/trkpt + wpt → AppExport, grouped by local date
- TCX 2.0 import (`TCXImportParser`): TrainingCenterDatabase/.../Trackpoint → AppExport, grouped by local date
- `AppContentLoader.decodeData()` routes GPX/TCX before JSON paths
- ZIP support: GPX/TCX files inside ZIPs are extracted and parsed
- `fileImporter` in `AppShellRootView` accepts .gpx and .tcx
- DE/EN localization strings for GPX/TCX
- 3 contract fixtures: `sample_import.gpx`, `sample_import.tcx`, `sample_import_empty.gpx`
- 19 new tests in `MultiSourceImportTests`; 530 total, 0 failures
- Prompt-1 protected files: untouched

Bewusst nicht umgesetzt (Follow-up):
- **FIT format**: Kein wartbares Swift-Framework ohne externe Dependency. Garmin FIT ist ein Binärformat mit proprietärem SDK. Follow-up wenn Community-Swift-Parser verfügbar.
- **GeoJSON import** (als Import, nicht Export): GeoJSON als Importquelle ist optional und komplex (FeatureCollection mit LineString/MultiLineString). Follow-up in separatem Branch.

## UI Polish Batch – Overview / Insights / Heatmap / Landscape (2026-04-12)

Status: **✅ abgeschlossen (2026-04-12)**

Umgesetzt (Tasks 1–10):
- Time-range control promoted to first position in overview pane
- Favorites-only toggle (Capsule chip) with live filter; persisted via `@State`
- `AppOverviewTracksMapView`: async polyline overview map, iOS 17+, Task.detached, reactive `.task(id:)`
- Heatmap Mode/Radius pickers replaced with Capsule chip buttons matching `AppDayFilterChipsView`
- Stray `Text("No data")` removed from `AppDayRow` empty state (stray bullet fix)
- `InsightsTopDaysPresentation.topDays(limit:)` raised from 5 to 20
- `HistoryDateRangeFilter.isoFormatter` timezone fixed from UTC to `.autoupdatingCurrent`
- `AppInsightsContentView.refreshDerivedModel()` metric-state applied atomically (`withTransaction(animation: nil)`)
- ~30 new German translation strings in `AppGermanTranslations`
- Heatmap controls scrollable in landscape (partial task 10)
- 14 new unit tests in `OverviewFavoritesAndInsightsTests`; 511 total, 0 failures

Noch offen (bewusst nachgelagert):
- Task 10 vollständig: 2-Spalten-Layout für Overview/Days/Insights in Landscape
- Apple-Device-Verifikation der neuen Overview-Map und Heatmap-Chips
- `docs/APP_FEATURE_INVENTORY.md` und `XCODE_RUNBOOK.md` für neue Features sync-en

## P1 Critical Fixes — Deep Audit 2026-04-12

Status: **✅ abgeschlossen (2026-04-12)**

Umgesetzt:
- `KeychainHelper`: `encodingFailed` Case + guard statt force-unwrap
- `AppExportQueries.effectiveDistance`: Logik auf `if pathDistance > 0` umgestellt + Kommentar
- `GeoJSONBuilder`: `throws` statt silent fallback; `AppExportView` fängt Fehler ab
- `MockURLProtocol` (Test): `httpBodyStream`-Fix für macOS (pre-existing crash behoben)
- 9 neue Tests (effectiveDistance-Fallback, GeoJSON-Leerlauf, Keychain round-trip + error case)
- `swift test` → 481 Tests, 0 Failures, macOS + Linux-Pfad grün
- Google-Timeline-Timezone-/DST-Audit nachgezogen: `GoogleTimelineConverter` mit deterministischen `Z`-/`+01:00`-/`+02:00`-/DST-/Tagesgrenzen-Tests verifiziert; kein Produktivfix nötig
- Downstream verifiziert: `AppExportQueries.daySummaries` und `insights` bleiben für Google-Timeline-Imports auf stabilen UTC-Day-Keys
- Aktueller Nachweis nach diesem Audit-Follow-up: `swift test` → 492 Tests, 0 Failures

## 0a. Phase 19.57b – Konfigurierbarer GPS-Aufnahmeintervall für Live-Recording

Status: **✅ abgeschlossen (2026-04-03)**

Umgesetzt:
- `RecordingIntervalPreference` / `RecordingIntervalUnit` als `Codable`/`Equatable`/`Sendable`-Typen modelliert; Default 5 s; Validation clampt auf Einheitsgrenzen
- `LiveTrackRecorderConfiguration.minimumRecordingIntervalS` als absolutes Zeit-Gate im Recorder
- `AppPreferences.recordingInterval` mit JSON-Persistenz und Reset-Support
- `AppOptionsView`: Stepper + Unit-Picker im Abschnitt „Live Recording"
- DE-Lokalisierung aller neuen Strings
- 21 neue Tests in `RecordingIntervalPreferenceTests`, 3 neue Tests in `LiveTrackRecorderTests`, erweiterte `AppPreferencesTests`
- Linux-Nachweis: alle neuen und geänderten Tests grün
- Follow-up 2026-04-10: Mindestabstand jetzt auch `0` (`No minimum`), keine obere Clamp mehr (`Maximum Time Gap: Unlimited`), Persistenz + Tests für `0` und große Werte ergänzt

Noch offen (bewusst nachgelagert):
- **Apple-Device-Verifikation** des Aufnahmeintervalls unter realen GPS-Bedingungen (iPhone); kein bekanntes Problem, aber noch nicht auf Gerät geprüft

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
- Start-Gate fuer Background-Recording: Recording startet bei aktivierter Hintergrundaufzeichnung erst nach aufgeloestem `Always Allow`-Upgrade; denied/restricted und Mehrfachtrigger sind testlich abgesichert (2026-04-12)
- Wrapper-Deklarationen fuer `NSLocationAlwaysAndWhenInUseUsageDescription` und `UIBackgroundModes=location`
- Permission-Upgrade, laufende Aufnahme im Hintergrund und Stop-/Persistenzverhalten: auf echtem iPhone 15 Pro Max real geprüft und bestätigt (2026-04-02)

Bewusst nachgelagert (erfordert Developer Account):
- frischen Device-Nachweis fuer den jetzt gegateten Startpfad (`awaitingAlwaysUpgrade` -> `recording`) auf echter Apple-UI nachziehen
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
- PrivacyInfo.xcprivacy vorhanden unter `wrapper/LH2GPXWrapper/PrivacyInfo.xcprivacy`: `NSPrivacyTracking: false`, UserDefaults CA92.1 und `NSPrivacyCollectedDataTypePreciseLocation` fuer den optionalen Live-Upload deklariert
- **End-to-End-Device-Verifikation mit eigenem HTTPS-Endpunkt: auf realem Gerät verifiziert (2026-04-02)**

Fehlt noch (bewusst verschoben, erfordert Developer Account):
- Apple-seitige Scope-/Review-Entscheidung: bestaetigt Apple die jetzt eingetragene `NSPrivacyCollectedDataTypes`-Deklaration fuer den optionalen Standort-Upload (Lat/Lon/Timestamp/Accuracy) so? Benoetigt Apple-Hardware und ggf. Store-Review-Feedback
- [x] ZIPFoundation-Abhaengigkeit file-timestamp: ZIPFoundation 0.9.20 bringt eigenes Privacy Manifest mit (FileTimestamp 0A2A.1) — kein Handlungsbedarf (verifiziert 2026-04-12)
- Datenschutzrichtlinien-URL und Support-URL für App Store Connect (extern, Pflichtfelder)
- Technische Basis ist dokumentiert in `docs/PRIVACY_MANIFEST_SCOPE.md`

## 9. Phase 19.57 – Weiterer Insights-Ausbau + breitere Lokalisierung (teilweise umgesetzt)

Status: **teilweise umgesetzt** (Phase B abgeschlossen 2026-04-02)

Bereits drin (2026-04-02 Phase B):
- `InsightsStreakPresentation`: Longest- und Recent-Streak aus `[DaySummary]`; Active/Total-Day-Counts; in Overview-Tab als `Activity Streak`-Sektion verdrahtet
- `InsightsPeriodComparisonPresentation`: Vergleich aktiver Zeitraum vs. Vorperiod gleicher Laenge; Delta-Text und Delta-Richtung; in Patterns-Tab als `Period Comparison`-Sektion verdrahtet (wird leer dargestellt wenn kein Range aktiv)
- `InsightsCardType.streak` und `.periodComparison` in `ChartShareHelper`; Share-Button in beiden neuen Sektionen verdrahtet
- `AppInsightsContentView`: neues `allDaySummaries`-Argument fuer Vorperiod-Basis; neue `Active Days`-Karte in Summary-Cards
- Linux-Nachweis: `swift test` → `Executed 398 tests, with 2 tests skipped and 0 failures (0 unexpected)`

Kandidaten B, C, D nicht umgesetzt: B (Weekday Pattern) war bereits vorhanden; C (Time-of-Day) hat keine stundengenaue Basis in DaySummary; D (New Places Trend) hat keine Place-Cluster-Daten in DaySummary.

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
