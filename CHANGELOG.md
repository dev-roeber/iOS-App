# CHANGELOG

## [2026-05-05] — chore: Guideline 3.2 Public Audience Clarification (fix/review-guideline-3.2-public-audience-clarification)

### App Review Ablehnung dokumentiert

- **Version 1.0 (Build 74)** vom Apple App Review am 2026-05-01 abgelehnt
- **Submission ID**: `1d2cc080-13cd-45cd-b3e0-c0259a75ce5c`
- **Ablehnungsgrund**: Guideline 3.2 — Business / Other Business Model Issues
- **Apple-Einschätzung**: App wurde fälschlich als organisationsgebundene/unternehmensinterne App eingestuft
- **Sachverhalt**: LH2GPX ist eine öffentliche Consumer-/Utility-App; kein Account, kein Login, keine Org-Zugehörigkeit erforderlich; alle Daten bleiben lokal; optionaler Live-Upload ist nutzerkonfigurierter self-hosted Endpunkt, standardmäßig deaktiviert

### Klarstellungen und neues Dokument

- `README.md`: Consumer-/Utility-Charakter explizit in „Was die App macht" ergänzt; `lh2gpx-live-receiver` als Beispiel-/Referenzimplementierung (nicht zentraler Dienst) klargestellt; Live-Aufzeichnungs-Feature um „kein zentraler Dienst, keine Organisationsbindung" erweitert; aktuellen Review-Status nachgezogen
- `docs/APP_REVIEW_RESPONSE_GUIDELINE_3_2.md`: neu — vollständige Ablehungs-Dokumentation + Response-Entwurf für ASC (EN)
- `docs/APP_FEATURE_INVENTORY.md`: neuer Abschnitt „Public Audience Statement" — Zielgruppe, kein Account-Zwang, lokale Datenhaltung, Self-hosted-Upload-Natur
- `docs/APPLE_VERIFICATION_CHECKLIST.md`: Ablehnungsdetails (Build 74, Submission ID, Guideline 3.2) ergänzt; Guidelines-Tabelle um 3.2-Zeile erweitert
- `docs/ASC_SUBMIT_RUNBOOK.md`: Status auf Abgelehnt (Build 74) aktualisiert; Guideline-3.2-Response als aktuell blockierenden Schritt ergänzt
- `wrapper/docs/TESTFLIGHT_RUNBOOK.md`: ASC-Stand auf Abgelehnt (Build 74) + Guideline-3.2-Eintrag in Guidelines-Tabelle
- `NEXT_STEPS.md`: P0 — Review-Response als oberste Priorität; Build-Einreichung erst nach positivem Outcome
- `ROADMAP.md`: Ablehnung und Clarification-Stand dokumentiert

### Keine Code-Änderungen an Produktlogik oder Tests

- `swift test`: 832 Tests, 0 Failures (unverändert)
- keine ASC-Aktion ausgeführt — nur Repo-Vorbereitung und Doku

## [2026-05-01] — chore: Build 73 Screenshot + Submit Prep (release/build-73-screenshots-submit-prep)

### ASC-Stand aktualisiert

- **Version 1.0**: `Warten auf Prüfung`, sichtbarer Build jetzt `71` (von Sebastian bestätigt)
- **Xcode Cloud Build 73**: aktuellster erfolgreicher Build, entspricht Repo-Stand `34734ce`
- **Lokale Build-Nummer** in `project.pbxproj`: `CURRENT_PROJECT_VERSION = 45` (Xcode Cloud überschreibt mit `CI_BUILD_NUMBER`)
- **Build-73-Kandidatenstatus**: Repository-Stand eindeutig zu Build 73 passend; kein neuer Code nach truth sync; Build 73 ≠ lokal archivierter Build — Xcode Cloud ist der alleinige Upload-Pfad

### Screenshot-Infrastruktur erweitert

- `wrapper/LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift`: `testAppStoreScreenshots` um Slots 07 (`07-options`) und 08 (`08-day-detail`) erweitert; bestehende Slots 01–06 für das neue Redesign-Layout kommentiert
- `docs/app-store-assets/screenshots/README.md`: vollständig überarbeitet mit Status-Tabelle (01–06 vorhanden/alt, 07–08 ausstehend), Sicherheitsregeln, Slot-Übersicht für Build 73

### Neues Runbook

- `docs/ASC_SUBMIT_RUNBOOK.md`: vollständige manuelle ASC-Schritte für Build 73 (Screenshot-Extraktion, Version aus Prüfung entfernen, Build-Tausch, Screenshot-Upload, erneutes Submit)

### Dokumentation nachgezogen

- `docs/APPLE_VERIFICATION_CHECKLIST.md`: ASC-Status auf Build 71 / Xcode Cloud Build 73 aktualisiert; Screenshot-Status (altes Layout) und Handlungsanweisung ergänzt
- `NEXT_STEPS.md`: P0-Aufgaben für Build 73 + neue Screenshots als oberste Priorität gesetzt
- `ROADMAP.md`: Build-73-Vorbereitungsstand dokumentiert
- `wrapper/docs/TESTFLIGHT_RUNBOOK.md`: ASC-Stand auf Build 71 / Xcode Cloud Build 73 nachgezogen

### Keine Code-Änderungen an Produktlogik oder Tests

- `swift test`: 832 Tests, 0 Failures (unverändert)
- kein Archive, kein Upload, keine ASC-Aktion — nur Repo-Vorbereitung

## [2026-05-01] — chore: Final UI/Localization Truth Sync (ui/redesign-final-truth-sync)

### Fehlende deutsche Übersetzungen ergänzt

9 Strings, die in der Options/Widget/Upload-UI mit `t()` verwendet werden, fehlten im deutschen Dictionary:
- `"Invalid URL"` → `"Ungültige URL"` (Upload-Status-Chip)
- `"Automatic Widget Update"` → `"Automatisches Widget-Update"` (Widget-Toggle)
- `"Widget & Live Activity"` → `"Widget & Live-Activity"` (Section-Titel und Nav-Link)
- `"Live Activity"` → `"Live-Activity"` (Section-Titel)
- `"Reachable"` → `"Erreichbar"` (Verbindungstest-Ergebnis)
- `"Unreachable"` → `"Nicht erreichbar"` (Verbindungstest-Fehler)
- `"Test Connection"` → `"Verbindung testen"` (Upload-Subpage-Button)
- `"Testing…"` → `"Testen…"` (Verbindungstest Spinner-Label)
- `"Last tour + weekly status"` → `"Letzte Tour + Wochenstatus"` (Widget-Vorschau)

### Tests erweitert

- `AppPreferencesTests.testDefaultsAreSensible`: prüft jetzt auch `widgetAutoUpdate = true` und `maximumRecordingGapSeconds = 300`
- `AppPreferencesTests.testResetRestoresDefaults`: prüft Reset von `widgetAutoUpdate` und `maximumRecordingGapSeconds`
- `AppLanguageSupportTests`: +2 neue Gruppen für Truth-Sync-Strings (DE + EN Identity)
- **Gesamtergebnis: 832 Tests, 0 Failures** (vorher 830)

### Doku

- `NEXT_STEPS.md`: Truth-Sync als abgeschlossen markiert; Screenshot-Aktualisierungsaufgabe als neues P2-Item ergänzt
- `ROADMAP.md`: Truth-Sync-Stand dokumentiert

## [2026-05-01] — feat: Options + Widget/Live Settings Redesign (ui/options-widget-live-settings)

### Neu: `RecordingPreset` (in `AppPreferences.swift`)

- Enum `RecordingPreset` mit Cases `battery`, `balanced`, `precise`, `custom`
- Computed property `recordingPreset` auf `AppPreferences`: deterministisch aus `liveTrackingAccuracy` + `liveTrackingDetail` abgeleitet; kein neuer UserDefaults-Key
- Setter: `battery` → `.relaxed`/`.batterySaver`, `balanced` → `.balanced`/`.balanced`, `precise` → `.strict`/`.detailed`, `custom` → no-op

### Neu: `OptionsPresentation.swift`

- Statische Helpers `uploadStatusText`, `uploadStatusColor`, `serverUploadPrivacyText` — reine Darstellungslogik, kein Business-Code

### Neu: `LHOptionsComponents.swift`

- `LHOptionsSectionRow(icon:title:description:color:)` — dunkle Card-Zeile mit Icon-Badge, Titel, Beschreibung, Chevron
- `LHLiveRecordingPresetSelector(preset:t:)` — horizontale Chip-Leiste für 4 Presets (farbkodiert) mit Accessibility-Identifiern
- `LHUploadSettingsCard(preferences:t:)` — Toggle + URL-Feld + `SecureField` für Bearer-Token (nie im Klartext) + Batch-Picker + Status-Dot
- `LHDynamicIslandPreviewCard(display:availability:t:)` — Icon-Badge, Titel, Availability-Chip; Identifier `options.dynamicIsland.preview`
- `LHWidgetPreviewCard(distanceUnit:t:)` — Icon-Badge, Titel+Beschreibung; Identifier `options.widget.preview`

### Redesign: `AppOptionsView.swift`

- Hauptseite: NavigationLink-Grid mit 8 Section-Rows (General, Maps, Import, Live Recording, Upload, Widget & Live Activity, Privacy, Technical); schwarzer Hintergrund, dunkle Cards
- `AppLiveRecordingOptionsView`: Preset-Card + Settings-Card; Advanced-Werte nur bei `.custom` vollständig editierbar
- `AppUploadOptionsView`: `LHUploadSettingsCard` + optionaler Verbindungstest + Hinweis-Banner; Token nur als `SecureField`
- `AppWidgetLiveActivityOptionsView`: DI-Picker + Vorschau-Card + Widget-Card + Verfügbarkeits-Banner
- Sub-pages General, Maps, Import, Privacy, Technical vollständig erhalten

### Erweiterung: `AppLanguageSupport.swift`

- 36 neue DE/EN-Einträge für Options/Widget/Live-Activity-Redesign (General, Live Recording, Preset-Namen, Token-Felder, DI-Werte, Widget-Strings, Section-Descriptions, Reset-Disclaimer)

### Tests

- `AppPreferencesTests`: +7 neue Testmethoden (RecordingPreset-Mapping, DI-Persist, Upload-Persist)
- `UIWiringTests`: +9 neue Tests (Preset-Wiring, DI-Cases, OptionsPresentation-Helpers, Accessibility-IDs)
- `LandscapeLayoutTests`: +4 neue Tests (OptionsPresentation orientierungsunabhängig, Preset-Berechnung, DI-localizedName)
- `AppLanguageSupportTests`: +3 neue Testgruppen (Options-Redesign, Widget/LA-Strings, English-Identity)
- `LiveActivityTests`: +6 neue Tests (DI-Primärwert-Formatierung für alle 4 Cases, Not-Recording-Fallback)
- `WidgetDataStoreTests`: +3 neue Tests (allCases round-trip, suiteName, App-Group-Mirroring)
- `LiveLocationServerUploaderTests`: +3 neue Tests (Token nicht im Body, trimmedBearerToken empty→nil, whitespace→nil)
- **Gesamtergebnis: 830 Tests, 0 Failures** (vorher 793)

## [2026-05-01] — feat: Live Tracking + Library Redesign (ui/live-tracking-redesign)

### Neu: `LHLiveComponents.swift`

Zwei neue spezialisierte UI-Komponenten für das Live-Tracking-Redesign:
- `LHLiveBottomBar` — Sticky Bottom Bar mit vollem Start-CTA (Mint) oder Stop-CTA (Rot); Identifier `live.cta.start / live.cta.stop`
- `LHLiveTrackRow` — Dark-Card-Zeile für die Live-Tracks-Bibliothek; wraps `SavedTrackSummaryContentView` mit LH2GPX-Kartenoberfläche

### Redesign: `AppLiveTrackingView`

Vollständiger Umbau des Live-Tracking-Screens auf LH2GPX-Dark-Designsystem:
- `ScrollView` + `LHPageScaffold` ersetzt alte padding-basierte Struktur; Sticky `LHLiveBottomBar` via `.safeAreaInset(edge: .bottom)`
- Kartenpolyline: `.red` → `LH2GPXTheme.liveMint`; Standortpunkt: Mint bei Aufzeichnung, Blau im Leerlauf
- Status-Chips-Zeile mit Accessibility-Identifiern: `live.status.ready`, `live.status.gps`, `live.status.follow`, `live.status.upload`
- Recording-Card ohne eingebetteten Start-/Stop-Button; Dauer-Anzeige in Mint bei laufender Aufzeichnung; Identifier `live.recording.card`
- Primäre 4 Metriken mit Accessibility-Identifiern: `live.metric.distance`, `live.metric.duration`, `live.metric.points`, `live.metric.averageSpeed`
- Upload-Quick-Actions aus `recordingSection` in `uploadSection` verschoben; Pause-Button Identifier `live.cta.pause`
- Saved-Tracks-Karte: Mint-Badge, „Alle Live-Tracks anzeigen"-Button; Identifier `live.savedTracks.preview / live.savedTracks.openAll`
- Advanced-Section: Follow-Toggle als Capsule-Chip statt separater Zeile; Background-Recording-Toggle unverändert
- Interrupted-Session-Banner vollständig erhalten; Identifier `live.interrupted.resume` unverändert
- Fullscreen-Map-Flow und alle `.onChange`-Handler vollständig erhalten

### Redesign: `AppRecordedTracksLibraryView`

Umbau der Saved-Live-Tracks-Bibliothek auf LH2GPX-Dark-Layout:
- `navigationTitle` von „Saved Live Tracks" auf „Live Tracks" (nutzt bestehende DE-Übersetzung „Live-Tracks")
- `List` ersetzt durch `ScrollView` + `LHPageScaffold`; `navigationDestination(for: RecordedTrack.self)` vollständig erhalten
- Info-Card mit „Lokal gespeichert"-Label, Trennungshinweis und Track-Zähler-Badge
- Track-Zeilen als `LHLiveTrackRow` mit `NavigationLink(value:)` + Index-Identifier `liveTracks.row.<index>`; Identifier `liveTracks.list`
- Neues optionales `onNewTrack: (() -> Void)?`-Parameter — zeigt „Neuer Track"-Button wenn gesetzt; Identifier `liveTracks.newTrack`
- Accessibility-Identifier `liveTracks.info`, `liveTracks.title`

### Erweiterung: `LiveTrackingPresentation`

Neue testbare statische Presentation-Helpers:
- `gpsStatusLabel(accuracyM:) -> String` — „GPS Good" / „GPS Weak" basierend auf Genauigkeitsschwellwert (< 30 m)
- `uploadSectionVisible(sendsToServer:pendingCount:statusMessage:) -> Bool`

### Neue DE/EN Strings in `AppLanguageSupport`

13 neue Strings: GPS Good/Weak, Upload Active/Off/Waiting, View All Live Tracks, New Track, Stored Locally, Separate from imported history, Follow On/Off, Recording Active

### Tests: +20 neue Tests

- `LiveTrackingPresentationTests`: +9 (GPS-Status, Upload-Visibility)
- `UIWiringTests`: +7 (Deep-Link, CTA-State, GPS-Status, Track-Row)
- `LandscapeLayoutTests`: +3 (Metric-Snapshot, Track-Row, GPS-Status)
- `AppLanguageSupportTests`: +2 (DE/EN Live-Tracking-Strings)
- 793 Tests gesamt, 0 Failures

### Unverändert (kein Eingriff)

Alle bestehenden Verdrahtungen erhalten: `LiveLocationFeatureModel`, `LiveTrackRecorder`, `RecordedTrackStore`, `WidgetDataStore`, `TrackingAttributes`, `ActivityManager`, `LiveActivityPresentation`, `LiveLocationServerUploader`, `AppContentSplitView.syncLiveRecordingSettings`, Upload Pause/Resume/Flush, Start/Stop/Save-Track-Pfad, Interrupted-Session-Resume-Flow, Deep-Link `lh2gpx://live`, Widget-/App-Group-Mirroring, `AppRecordedTrackEditorView` vollständig unverändert

---

## [2026-05-01] — feat: Export Checkout Redesign (ui/export-checkout-redesign)

### Neu: `LHExportComponents.swift`

Drei neue spezialisierte UI-Komponenten für den Export-Checkout-Flow:
- `LHExportStepIndicator` — linearer 4-Schritt-Fortschrittsindikator (Auswahl / Format / Inhalt / Fertig); Identifier `export.step.*`
- `LHExportBottomBar` — Sticky Bottom Bar mit kompakter Zusammenfassung und primärem Export-Button; Identifier `export.bottomBar / export.summary / export.primaryButton / export.disabledReason`
- `LHExportFilterDisclosure` — einklappbare Disclosure-Card für erweiterte Exportfilter; Identifier `export.advancedFilters`

### `AppExportView.swift` — Checkout-/Wizard-Redesign

- Layout: `List` + `exportBar`-VStack → `ScrollViewReader { ScrollView { LHPageScaffold { … } } }` mit `.safeAreaInset(edge: .bottom)`
- Titel `Export` mit `.title.weight(.bold)`; Identifier `export.title`
- `LHExportStepIndicator` basierend auf `ExportPresentation.readiness` (nothingSelected → step 0, noExportableContent → step 1, ready → step 3)
- Insights-Drilldown-Card: `LHCard` mit Label "Aus Insights übernommen" + Reset-Button; Identifier `export.resetDrilldown`
- Range-Filter-Card: `AppHistoryDateRangeControl` in `LHCard`; Identifier `export.range.card`
- Vorschau-Card: `AppExportPreviewMapView` in `LHCard` (hidden → kein Rendern); Identifier `export.map.preview`
- Auswahl-Card: 4-KPI-Grid (Tage/Routen/Zeitraum/Orte mit `LHMetricCard`) + Badge-Scroll + "Auswahl bearbeiten"-Button mit `ScrollViewProxy`; Identifier `export.selection.card / export.selection.edit`
- Tage-Card + Live-Tracks-Card: `ForEach`-Rows ohne `List`; Identifier `export.liveTracks.card`
- Format-Card: 5 Formatpillen (GPX/KMZ/KML/GeoJSON/CSV) mit aktivem Highlight-Background; Identifier `export.format.card`
- Inhalt-Card: 3 Moduspillen (Tracks/Waypoints/Both) mit aktivem Highlight-Background; Identifier `export.content.card`
- Erweiterte Filter: `LHExportFilterDisclosure` mit Dismiss-Button in LHContextBar
- `LHExportBottomBar` ersetzt alten `exportBar`: Zusammenfassung "N Einträge · GPX" links, primärer Button rechts, Disabled-Grund darunter
- Alle bestehenden Verdrahtungen unverändert: fileExporter, onChange, prepareExport, per-route-selection, InsightsDrilldown, Area-/Date-/Accuracy-/Content-/ActivityType-Filter

### `ExportPresentation.swift` — Checkout-UI-Helfer

- `bottomBarSummary(...)` — liefert kurze Bottom-Bar-Zusammenfassung ("N Einträge · GPX")
- `disabledReason(...)` — liefert nil wenn bereit, sonst lesbaren Grund

### `AppLanguageSupport.swift` — neue DE/EN-Strings

Selection / Content / Edit Selection / Export Format / Advanced Filters / No exportable data selected / No exportable routes selected / Reset Drilldown / Adopted from Insights / Live Tracks / Tracks + Waypoints

### Tests

- `ExportPresentationTests` + 10 neue Tests: bottomBarSummary, disabledReason, Format-Labels, Step-Readiness
- `UIWiringTests` + 8 neue Tests: Drilldown-Export-Wiring, Format-Pillen, Export-Button disabled/enabled, Live-Tracks-Bottom-Bar
- `LandscapeLayoutTests` + 2 neue Tests: Readiness orientierungsunabhängig, Bottom-Bar-Zusammenfassung stabil
- `AppLanguageSupportTests` + 2 neue Tests: DE/EN Export-Checkout-Strings

### Unverändert

- `app_export`-Contract, GPXBuilder, KMLBuilder, KMZBuilder, CSVBuilder, GeoJSONBuilder
- ExportSelectionState, ExportSelectionContent, ExportPreviewData, ExportPreviewDataBuilder
- FileExporter-Flow, Live-Tracks-Export, InsightsDrilldown-Wiring, Area-Filter, Accuracy-Filter

---

## [2026-05-01] — feat: Insights Dashboard Redesign (ui/insights-dashboard-redesign)

### Neu: `LHInsightsComponents.swift`

Vier neue öffentliche Unterkomponenten für die Insights-Seite:
- `LHInsightsMetricGrid` + `LHInsightsMetricItem` — datengetriebenes 2×2-Grid aus `LHMetricCard`-Kacheln
- `LHInsightsChartCard` — Section-Card-Shell mit optionalem Share-Button und LH2GPXTheme-Oberfläche
- `LHInsightsTopDayRow` — kompakte Rang-Zeile (Rang-Badge, Datum, Primärwert)
- `LHInsightsActionRow` — Drilldown-Action-Zeile mit Icon + Pfeil

### `AppInsightsContentView.swift` — Visuelles Redesign

- Titel: `Text("Insights Overview")` → `Text("Insights")` mit `.title.weight(.bold)`, Identifier `insights.title`
- Active-Filter-Banner durch `LHContextBar` ersetzt
- Neues 4-KPI-Grid: Distanz (lila) / Aktive Tage (grün) / Routen (orange) / Orte (mint) via `LHMetricCard`; Identifier `insights.kpi.*`
- `AppHistoryDateRangeControl` mit Identifier `insights.range`
- `insightSection`-Hintergrund/Border/Shadow → `LH2GPXTheme.card / cardBorder / cardShadow`
- `periodComparisonRows`, `monthlyTrendRow`, `periodRow` → `LH2GPXTheme.card`
- Share-Button-Identifier: `"insights.section.share"` → `"insights.share.\(shareCardType.rawValue)"`
- `dayDrilldownTargets` nutzt jetzt `InsightsDrilldownTarget.drilldownTargets(for:)` (vollständiges Triple inkl. `showDayOnMap`)
- `dateRangeDrilldownTargets`: Labels "Show in Days" → "Open in Days", "Export This Period" → "Select for Export"

### `InsightsDrilldown.swift` — Drilldown-Labels aktualisiert

- `showDay`: "Show in Days" → "Open in Days"
- `exportDay`: "Export This Day" → "Select for Export"
- `showDayOnMap`: "Show on Map" (unverändert, jetzt DE-übersetzt)

### AppLanguageSupport — neue DE/EN Strings

"Open in Days"→"In Tage öffnen", "Select for Export"→"Für Export auswählen", "Show on Map"→"Auf Karte zeigen", "Activity Overview"→"Aktivitätsübersicht", "Activity Streak"→"Aktivitätsserie", "Period Comparison"→"Periodenvergleich", "Import More Data"→"Mehr Daten importieren"

### Tests

- `AppLanguageSupportTests` — 12 neue Tests für alle neuen Strings (DE + EN-Identity)
- `UIWiringTests` — 4 neue Tests: Drilldown-Label-Strings, Triple mit Map-Ziel, Range-Reset
- `InsightsCardPresentationTests` — 3 neue Tests: KPI-Summen, Empty State
- `LandscapeLayoutTests` — 2 neue Tests: KPI-Werte Landscape-unabhängig, SurfaceMode-Anzahl

### Nicht geändert

- Keine Chart-Berechnungslogik
- Keine Drilldown-Ziele entfernt
- Keine Map-Logik geändert
- Keine Live-Tracking-/Widget-/Dynamic-Island-Logik
- Kein App-Export-Contract geändert

### Checks

- `swift test`: 753 Tests, 0 Failures (Branch: `ui/insights-dashboard-redesign`)
- `git diff --check`: sauber
- `xcodebuild build -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS'`: BUILD SUCCEEDED

---

## [2026-04-30] — feat: Tage + Tagesdetail sichtbar auf neues LH2GPX-Dark-Redesign umgebaut

### Produkt-UI

- `AppContentSplitView.swift`, `AppDayListView.swift`: `Days` sichtbar auf grosses Titel-Layout mit echter schwarzer Flaeche umgebaut; kompakte Context-Zeile fuer Zeitraum und Suche; reduzierte Filterchips fuer `Alle`, `Mit Routen`, `Favoriten`, `Exportiert`; optionaler `LHCollapsibleMapHeader` mit bestehendem Day-Map-Kontext produktiv angebunden
- `AppDayListView.swift`, `DaySummaryRowPresentation.swift`: Day Rows sichtbar modernisiert; grosses Datum links, Wochentag und Zeitspanne, getrennte Kennzeichnung fuer Favorit vs. Exportstatus, getrennte Kennzahlen fuer Orte / Routen / Aktivitaeten / Distanz; bestehende Verdrahtung ueber `DayListPresentation.filteredSummaries`, `DaySummaryRowPresentationBuilder`, `selectedDayID`, `daySearchText`, `dayListFilter` und `favoritedDayIDs` bleibt erhalten
- `AppDayDetailView.swift`, `DayDetailPresentation.swift`, `DayDetailContentHierarchy.swift`: Day Detail auf map-first Layout umgebaut; `AppDayMapView` bleibt die bestehende Kartenkomponente; darunter KPI-Karten fuer Distanz, Routen, Aktivitaeten und Orte sowie Segmentumschaltung fuer `Uebersicht`, `Timeline`, `Routen`, `Orte`
- `AppDayDetailView.swift`: bestehende Aktionen bleiben erreichbar; Favorit, Teilen/Export, Route anzeigen, per-route Exportauswahl sowie display-only Route entfernen laufen weiter ueber die vorhandenen States und Confirmation-Dialoge
- `AppContentSplitView.swift`: bestehendes compact-/regular-SplitView-Verhalten, `daysNavigationPath`, `compactDayList`, Insights-Drilldown nach `Days`, Tab-Reselection und iPad/Mac-Verdrahtung bleiben erhalten

### Business-/Export-Grenzen

- keine Aenderung an Parser-, Import-, Producer- oder Export-Builder-Logik
- keine neue Route-Kappung, kein neues Road-Snapping, kein neues Map-Matching
- display-only entfernte importierte Routen bleiben display-only; Export-Truth und per-route Auswahl in `ExportSelectionState.routeSelections` bleiben unveraendert
- Hidden-Map-Invariante bleibt erhalten: bei `.hidden` wird der Days-Map-Builder nicht ausgewertet

### Strings / Tests

- `AppLanguageSupport.swift`: DE/EN-Strings fuer neue Days-/Day-Detail-Beschriftungen und Export-/Map-Labels ergaenzt bzw. sichtbar wiederverwendet
- aktualisierte Tests in `OverviewAndDaySummaryPresentationTests`, `DayDetailContentHierarchyTests`, `AppLanguageSupportTests`

### Checks

- `swift test`: 741 Tests, 0 Failures

## [2026-04-30] — feat: Startseite + Übersicht sichtbar auf neues LH2GPX-Redesign umgebaut

### Produkt-UI

- `AppShellRootView.swift`: import-first Startseite mit schwarzer Flaeche, grossem `LH2GPX`-Titel, kompaktem Subtitle, blauem Primary-Button `Datei importieren`, dunklen Action Rows fuer `Google Maps Export-Anleitung` und `Demo laden`
- `RecentFilesView.swift` + `RecentFilesStore.swift`: `Zuletzt verwendet` als echte Start-Card uebernommen; Dateiname, Datum und optionale Dateigroesse sichtbar; `Alle anzeigen` fuer laengere Listen; Dateigroesse wird beim Speichern des Recent-Entries mitpersistiert
- `AppContentSplitView.swift`: Overview sichtbar neu strukturiert mit Importstatus-Card, Zeitraum-Card, KPI-Grid, Highlights-Card und `Weiterarbeiten`-Card; bestehende Navigation (`Days`, `Insights`, `Export`, `onOpen`) bleibt verdrahtet
- `AppSessionStatusView.swift`: Importstatus-Card auf dunkles Kartenlayout gezogen; aktive Datei wird kompakter dargestellt; Link `Technische Details anzeigen` ersetzt die alte technische Disclosure-Beschriftung

### Design-System / Map-Header-Pilot

- `LH2GPXTheme.swift`: `LHCard` als einfacher Karten-Wrapper auf Basis von `cardChrome()` ergänzt
- `AppContentSplitView.swift`: `LHCollapsibleMapHeader` jetzt auf der ersten echten Produktseite (`Overview`) pilotiert; `LHPageScaffold` und `LHContextBar` dort ebenfalls produktiv im Einsatz
- `AppOverviewTracksMapView.swift`: fuer Header-Einbettung konfigurierbar (`fixedHeight`, optionaler Fullscreen-Button); Badge-Text repo-wahr auf `Simplified preview · export complete` / `Vereinfachte Vorschau · Export vollständig` umgestellt

### Strings / Tests

- `AppLanguageSupport.swift`: neue DE/EN-Strings fuer Startseite, neue Overview-Karten, Continue-Aktionen und den neuen Badge-Text ergänzt
- neue/aktualisierte Tests in `UIWiringTests`, `AppLanguageSupportTests`, `AppPreferencesTests`, `GoogleMapsExportHelpTests`

### Checks

- `swift test`: 739 Tests, 0 Failures
- `xcodebuild build -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS'`: BUILD SUCCEEDED

## [2026-04-30] — feat: Wiederverwendbare Seiten-Architektur (Map-Header-Shell)

### Neu: `LHCollapsibleMapHeader.swift`

**`LHMapHeaderVisibility`** — enum (`hidden | compact | expanded | fullscreen`), keine SwiftUI-Abhängigkeit, Linux-safe.

**`LHMapHeaderState`** — Value-Type mit Performance-Invariante: `shouldRenderMap = visibility != .hidden`. Karte liegt bei `.hidden` **nicht** im View-Tree (kein `.hidden()`, kein `.opacity(0)` — `@ViewBuilder`-Closure wird nicht ausgewertet). Übergänge: `toggleHidden`, `expand`, `collapse`, `enterFullscreen`, `exitFullscreen`.

**`LHCollapsibleMapHeader<MapContent: View>`** — SwiftUI-View mit Control-Bar, animiertem Map-Container und Fullscreen-Cover (`#if os(iOS) || os(visionOS)`).

### Neu: `LHPageScaffold.swift`

- `LHPageScaffold` — dünner VStack-Wrapper mit konfigurierbarem Padding/Spacing
- `LHContextBar` — kompaktes Sticky-Banner für aktive Filter / Drilldown-Kontext

### AppLanguageSupport — neue DE/EN Strings

Neue Einträge: "Show Map"→"Karte anzeigen", "Collapse Map"→"Karte einklappen", "Expand Map"→"Karte erweitern", "Close Map"→"Karte schließen", "Dismiss"→"Schließen" (bereits vorhanden: "Fullscreen"→"Vollbild", "Map Preview"→"Kartenvorschau").

### Tests

- `LHMapHeaderTests.swift` — 40 Tests in 7 Klassen (Visibility, RenderInvariant, FrameHeight, Transitions, Predicates, ButtonLabels, Equatable, Sequences)
- `AppLanguageSupportTests.swift` — 14 Tests (EN-Identity + DE-Übersetzungen für alle neuen Strings)

### Nicht geändert
- Keine bestehenden Map-Komponenten (AppOverviewTracksMapView, AppDayMapView, AppExportPreviewMapView, AppHeatmapView)
- Kein Live-Tracking-Business-Logic
- Kein Widget / Dynamic Island

### Checks
- `swift test`: 730 Tests, 0 Failures (Branch: `ui/map-header-shell`)

---

## [2026-04-30] — feat: LH2GPX Design-System (Theme-Tokens + UI-Bausteine)

### Neu: `LH2GPXTheme.swift`

Zentrales Design-System in `Sources/LocationHistoryConsumerAppSupport/LH2GPXTheme.swift`:

**Color Tokens (LH2GPXTheme):**
- Kartenoberfläche: `card`, `elevatedCard`, `cardBorder`, `cardShadow`, `separator`, `chipBackground`
- Semantische Aktionsfarben: `primaryBlue`, `liveMint`, `successGreen`, `warningOrange`, `dangerRed`, `favoriteYellow`, `insightPurple`, `routeOrange`, `distancePurple`
- Texthierarchie: `textPrimary`, `textSecondary`, `textTertiary`

**Wiederverwendbare UI-Bausteine:**
- `View.cardChrome()` — Standard-Kartenoberfläche (Padding, Fill, Hairline-Border, Shadow); ersetzt die private Extension aus `AppLiveTrackingView`
- `LHSectionHeader` — Abschnittstitel mit optionalem Subtitle
- `LHStatusChip` — Kompakter Capsule-Chip für Status-Labels (Recording / Upload / Permission)
- `LHMetricCard` — Linksbündige Metrikkachel (Icon + Label + Wert) für 2-Spalten-Grids
- `LHInsightBanner` — Informations-/Guidance-Banner mit Icon, Titel, Beschreibung
- `LHFilterChip` — Toggle-Capsule für Filterbars

### Migrierte Stellen

**`AppLiveTrackingView.swift`:**
- Private `cardChrome()` Extension entfernt → nutzt jetzt `LH2GPXTheme.View.cardChrome()`
- Private `statusChip()` entfernt → alle Call-Sites verwenden `LHStatusChip`
- Private `statCard()` entfernt → alle Call-Sites verwenden `LHMetricCard`
- Private `insightBanner()` entfernt → alle Call-Sites verwenden `LHInsightBanner`
- Betroffen: `statusChips`, `recordingSection` (8 Metrikkacheln), `uploadSection` (6 Metrikkacheln + Chip + 2 Banner), `savedTracksSection` (1 Banner), `advancedSection` (1 Banner)

**`AppDayListView.swift` (`AppDayFilterChipsView`):**
- Button-Chip-Body durch `LHFilterChip` ersetzt; gleiche Visuals, zentralisierte Token-Nutzung

**`RecentFilesView.swift`:**
- Hintergrund von `Color.secondary.opacity(0.07)` auf `LH2GPXTheme.card` migriert
- Hairline-Border (`LH2GPXTheme.cardBorder`) ergänzt — passt zur Card-Sprache im Rest der App

**`OverviewPresentation.swift` (`OverviewStatAccent.swiftUIColor`):**
- Hardcodierte `.blue`, `.purple`, `.green`, `.orange` → `LH2GPXTheme.primaryBlue` etc.

### Nicht geändert
- Keine Business-Logik, kein Presentation-Modell, keine Map-Logik
- Widget / Dynamic Island: nicht angefasst (System-Farben, kein rein-sicherer Token-Pfad)
- Kein komplettes Redesign; Farbidentität und Abstände sind unverändert

### Checks
- `swift test`: 667 Tests, 0 Failures
- `git diff --check`: kein Whitespace-Fehler

## [2026-04-30] — docs: GitHub Pages live verifiziert und Screenshot-Assets repo-wahr dokumentiert

### Geprüft und dokumentiert

**GitHub Pages (live, HTTP 200 bestätigt 2026-04-30):**
- `https://dev-roeber.github.io/iOS-App/` → HTTP 200, server: GitHub.com
- `https://dev-roeber.github.io/iOS-App/support.html` → HTTP 200
- `https://dev-roeber.github.io/iOS-App/privacy.html` → HTTP 200
- Last-Modified: 2026-04-30 (passt zum letzten Commit)
- Keine Tokens, Secrets oder private Pfade in den HTML-Dateien
- E-Mail `dev_roeber@icloud.com` in support.html und privacy.html: bewusst als Support-Kontakt vorhanden

**Screenshot-Assets lokal vorhanden (`docs/app-store-assets/screenshots/`):**
- `iphone-67/`: 6 PNG-Dateien, je 1290×2796 px — App Store 6.7"-Slot-konform
- `iphone-65/`: 6 PNG-Dateien, je 1242×2688 px — App Store 6.5"-Slot-konform
- Dateinamen: 01-import, 02-overview-map, 03-days, 04-insights, 05-export, 06-live-recording
- Kein privater Content, keine Debug-Overlays, keine feste Server-URL

### Bewusst nicht behauptet
- kein ASC-Screenshot-Upload in diesem Slice; Upload bleibt manuell ausstehend

### Checks
- `git diff --check`: kein Whitespace-Fehler
- `swift test`: nicht ausgefuehrt — ausschliesslich Doku-Aenderungen

## [2026-04-30] — docs: Support-URL und Privacy-URL in App Store Connect bestätigt

### Dokumentiert
- Support-URL `https://dev-roeber.github.io/iOS-App/support.html` manuell in App Store Connect eingetragen / geprüft
- Privacy Policy URL `https://dev-roeber.github.io/iOS-App/privacy.html` manuell in App Store Connect eingetragen / geprüft
- Build `52` bleibt unverändert im Review; kein neuer Build nachgereicht
- kein vollständiger Lock-Screen-/minimal-/No-Dynamic-Island-Nachweis in diesem Slice

### Verifiziert
- `git diff --check` (reine Doku-Änderung; kein `swift test` erforderlich)

### Bewusst nicht behauptet
- Lock Screen, `minimal`, deaktivierte Live Activities und No-Dynamic-Island-Geraete bleiben weiter ohne echten Hardware-Nachweis offen

## [2026-04-30] — fix: Pending-/Restart-Pfad nach App-Relaunch korrekt abgebildet

### Root Cause
Nach App-Terminate + Relaunch setzt `restoreInterruptedSessionState()` korrekt `hasInterruptedSession = true`, aber `resetPersistence` loescht den Demo-Content; der Live-Tab war daher nicht sichtbar. Gleichzeitig fehlte dem "Resume recording"-Banner ein `accessibilityIdentifier`, und der UI-Test wartete direkt auf `live.recording.stop`, ohne den Banner zu bestaetigen – das Stop-Element erscheint aber erst, wenn der User explizit "Resume" tappt.

### Fixed
- `AppLiveTrackingView`: "Resume recording"-Button erhaelt `.accessibilityIdentifier("live.interrupted.resume")` fuer zuverlässige AX-Ansteuerung in UI-Tests
- `LH2GPXWrapperUITests / runLiveActivityCaptureFlow`: Relaunch-Pfad laedt nach dem Reopen Demo-Daten nach, navigiert zum Live-Tab, tappt `live.interrupted.resume` (mit `allowLocationAccessIfNeeded()`), und wartet erst danach auf `live.recording.stop`

### Tests
- 4 neue Unit-Tests in `LiveLocationFeatureModelTests`:
  - `testInterruptedSessionDoesNotAutoResumeRecording` — kein Auto-Resume nach Init mit persistierter Session
  - `testResumeAfterInterruptedSessionStartsNewRecording` — Dismiss + setRecordingEnabled(true) → isRecording=true
  - `testPartialDefaultsTimestampOnlyNoInterruptedSession` — nur Timestamp ohne ID → kein falscher interrupted State
  - `testStopRecordingLeavesNoRestorationState` — Stop raeumt alle Restore-Keys auf
- `swift test`: 667 Tests, 0 Failures
- `xcodebuild ... build`: BUILD SUCCEEDED
- **Echter Device-Rerun (iPhone 15 Pro Max, iOS 26.4): `testLiveActivityHardwareCaptureUploadStatusPendingAndRestart` PASSED (62 s)**

## [2026-04-30] — docs: real-device Live Activity verification rerun

### Geaendert
- `docs/APPLE_VERIFICATION_CHECKLIST.md` und `wrapper/docs/LOCAL_IPHONE_RUNBOOK.md` auf den echten Rerun-Stand gezogen: Nach manuellem Trust des UITest-Runners liefen reale Device-Tests wieder auf dem verbundenen `iPhone 15 Pro Max` (`iOS 26.4`)
- repo-wahr dokumentiert: `testDeviceSmokeNavigationAndActions` auf echter Hardware gruen; Live-Activity-Capture-Tests fuer `Distance`, `Duration`, `Points` und `Upload Status (failed)` auf echter Hardware gruen
- repo-wahr dokumentiert: `testLiveActivityHardwareCaptureUploadStatusPendingAndRestart` scheitert weiter nach Relaunch, weil `live.recording.stop` nicht wieder erscheint; Lock Screen, `minimal`, deaktivierte Live Activities und No-Dynamic-Island-Geraete bleiben offen

## [2026-04-30] — docs: hardware verification blocker truth sync

### Geaendert
- `docs/APPLE_VERIFICATION_CHECKLIST.md` und `wrapper/docs/LOCAL_IPHONE_RUNBOOK.md` um den aktuellen echten Device-Blocker ergaenzt: `LH2GPXWrapperUITests.xctrunner` ist auf dem verbundenen `iPhone 15 Pro Max` derzeit nicht als vertrauenswuerdige Entwickler-App freigegeben; ein weiterer Live-Capture-Lauf brach zusaetzlich mit `CoreDeviceError / Mercury error 1001` nach Launch ab
- repo-wahr festgehalten, dass damit weiterhin kein neuer Voll-Nachweis fuer Lock Screen, `minimal`, weitere Primärwerte, deaktivierte Live Activities oder No-Dynamic-Island-Geraete vorliegt

## [2026-04-30] — live: restore-state hardening for interrupted sessions

### Fixed
- `LiveLocationFeatureModel`: interrupted-session Persistenz wird nicht mehr schon beim Init oder vor erfolgreichem Recording-Start geschrieben; Restore-State entsteht jetzt erst nach echtem Start der Aufnahme
- `LiveLocationFeatureModel`: denied/restricted sowie abgelehntes `Always`-Upgrade raeumen verwaisten Restore-State jetzt defensiv auf
- `LiveLocationFeatureModel`: `dismissInterruptedSession()` und sauberer Stop loeschen Persistenz und In-Memory-Restore-State konsistent

### Tests
- `LiveLocationFeatureModelTests`: Regressionen decken Initialisierung ohne Recording, Persistenz erst nach gueltigem Start, Cleanup bei Stop/Ignore sowie kaputte oder partielle `UserDefaults`-Werte ab
- Verifikation: `swift test` -> 663 Tests, 0 Failures; `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build` -> `BUILD SUCCEEDED`

## [2026-04-30] — docs: roadmap and review truth sync

### Geaendert
- `AGENTS.md`, `README.md`, `NEXT_STEPS.md`, `ROADMAP.md` und Apple-/Wrapper-Runbooks auf den aktuellen Repo- und ASC-Truth gezogen
- `NEXT_STEPS.md` von historischer Mischliste auf echte offene P0/P1/P2-Arbeit reduziert
- App-Store-Review-Entscheidung repo-wahr nachgezogen: Build `52` bleibt bewusst in Review; Build `57` wird nicht ohne Apple-Feedback oder bestaetigten release-kritischen Fehler nachgereicht
- veraltete Aussagen zu aktivem Repo, Split-Repos, Teststand, Xcode-Cloud-Buildnummer und Wrapper-Roadmap-Pfaden bereinigt

### Verifiziert
- `swift test`
- `git diff --check`
- `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build`

### Bewusst nicht behauptet
- kein Claim, dass App Review bestanden ist
- keine neue echte Hardware-Verifikation fuer Lock Screen, `minimal`, weitere Primärwerte oder Homescreen-Widget

## [2026-04-30] — docs: App Store Connect review status truth sync

### Geaendert
- App-Store-Connect-Status fuer `LH2GPX` Version `1.0` repo-wahr nachgezogen: Version ist eingereicht, Status `Warten auf Prüfung`
- dokumentiert, dass auf der Versionsseite derzeit Build `52` sichtbar ist, waehrend der Xcode-Cloud-Workflow `Release – Archive & TestFlight` bereits erfolgreiche Builds `55`, `56` und `57` zeigt
- offene Prueffrage explizit festgehalten: klaeren, ob Build `52` bewusst fuer Review ausgewaehlt wurde oder ob ein neuerer Build (`57`) nachgereicht werden soll
- Doku auf den neuen ASC-Truth angepasst: App Review ist nicht mehr durch fehlenden Upload blockiert; partielle Hardware-Verifikation fuer Live Activity / Dynamic Island bleibt weiter offen

### Verifiziert
- `swift test`
- `git diff --check`
- `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build`

### Bewusst nicht behauptet
- kein Claim, dass App Review bereits bestanden oder abgeschlossen ist
- keine neue echte Hardware-Verifikation fuer Lock Screen, `minimal`, weitere Primärwerte oder Fallback-Pfade

## [2026-04-30] — release: TestFlight archive path truth sync

### Geaendert
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: `CURRENT_PROJECT_VERSION` fuer App, Widget und Test-Targets auf `45` angehoben, damit ein neuer Release-Kandidat nicht hinter dem bereits dokumentierten TestFlight-Build `1.0 (44)` zurueckfaellt
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: explizite Release-`CODE_SIGN_IDENTITY = Apple Distribution` fuer App + Widget entfernt; `CODE_SIGN_STYLE = Automatic` bleibt der einzige Release-Signing-Pfad
- Release-/TestFlight-Doku auf den realen Host-Befund vom 2026-04-30 gezogen

### Verifiziert
- `swift test`: 660 Tests, 0 Failures
- `git diff --check`
- `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build`
- `xcodebuild archive -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -configuration Release -destination 'generic/platform=iOS' -archivePath /Users/sebastian/Desktop/LH2GPXWrapper.xcarchive`: `ARCHIVE SUCCEEDED`

### Bewusst nicht behauptet
- kein lokaler TestFlight-Upload: `xcodebuild -exportArchive` scheitert auf diesem Host mit `No signing certificate "iOS Distribution" found`
- kein automatisierter App Store Connect Upload: `altool` hat auf diesem Host keine konfigurierte JWT- oder Username/App-Password-Authentifizierung
- App Review bleibt fuer den Dynamic-Island-/Live-Activity-Scope weiter `NO-GO`

## [2026-04-30] — docs: partial real-device verification for Live Activity / Dynamic Island

### Geaendert
- realen Device-Nachweis fuer den aktuellen Live-Activity-/Dynamic-Island-Stand repo-wahr dokumentiert
- `docs/APPLE_VERIFICATION_CHECKLIST.md`, `NEXT_STEPS.md`, `ROADMAP.md`, `README.md`, `docs/APP_FEATURE_INVENTORY.md`: verifizierte Teilmenge (`iPhone 15 Pro Max`, `iOS 26.4`, `Debug`-Build via `xcodebuild test`) von offenen Punkten getrennt

### Verifiziert
- echter iPhone-Lauf auf `iPhone 15 Pro Max` (`iPhone16,2`) mit `iOS 26.4`
- Live Recording Start auf echter Hardware
- Dynamic Island compact fuer Primärwert `Distanz` (`0 m`) auf echter Hardware sichtbar
- Dynamic Island expanded fuer Primärwert `Distanz` auf echter Hardware sichtbar
- Stop-/Dismiss-Verhalten der Live Activity nach Ende der Aufnahme auf echter Hardware sichtbar

### Bewusst nicht behauptet
- kein repo-wahrer Lock-Screen-Nachweis in diesem Slice
- kein repo-wahrer Minimal-State-Nachweis in diesem Slice
- keine repo-wahre Hardware-Verifikation fuer `Dauer`, `Punkte`, `Upload-Status`, deaktivierte Live Activities oder Fallbacks ohne Support
- App Review bleibt bis zu weiterem echten Device-Nachweis fuer die offenen Live-Activity-Pfade `NO-GO`

## [2026-04-30] — docs: Dynamic Island verification truth sync

### Geaendert
- veraltete Doku-Aussagen fuer den Dynamic-Island-/Widget-Pfad auf aktuellen Repo-Truth gezogen
- `NEXT_STEPS.md`: historischer Live-Activity-Hinweis auf nutzbaren `iOS 16.2+`-Pfad korrigiert; Screenshot-Hinweis auf iPhone-only-v1 angepasst
- `ROADMAP.md`: veraltete Aussage entfernt, dass das Widget-Target noch manuell anzulegen sei
- `wrapper/README.md`, `wrapper/docs/LOCAL_IPHONE_RUNBOOK.md`, `wrapper/docs/TESTFLIGHT_RUNBOOK.md`: iPhone-only-Release-Truth (`TARGETED_DEVICE_FAMILY = 1`) und korrektes Deployment-Target (`iOS 16.0 / 16.2`) synchronisiert

### Verifiziert
- Repo-Truth-Audit gegen aktuellen Code und Projektdatei
- `swift test`
- `git diff --check`
- `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build`

## [2026-04-29] — fix: Interactive Overview-/Explore-Map audit hardened

### Geaendert
- `Sources/LocationHistoryConsumerAppSupport/AppOverviewTracksMapView.swift`: `loadData` cancelt jetzt alte Overlay-Rebuilds sofort beim Neu-Load; stale Detached-Tasks dürfen keine veralteten Overlays mehr nach einem neuen Load committen
- `Sources/LocationHistoryConsumerAppSupport/AppOverviewTracksMapView.swift`: nach Cancellation werden gescannte Partialdaten nicht mehr in den Model-State geschrieben
- `Sources/LocationHistoryConsumerAppSupport/AppOverviewTracksMapView.swift`: Viewport-Culling bleibt bounding-box-basiert; lange Routen, die den sichtbaren Bereich schneiden, bleiben priorisierbar, auch wenn ihr Midpoint außerhalb liegt
- `Sources/LocationHistoryConsumerAppSupport/AppLanguageSupport.swift`: DE-Lokalisierung für `Toggle map style` ergänzt

### Neue Tests
- `testBuildOverlaysFromCandidatesPrioritizesViewportIntersectionOverMidpoint`
- `testBuildOverlaysFromCandidatesViewportStillRespectsOverlayLimit`
- `testOverviewMapModelResetToFullViewRestoresFullSelectionAfterViewportUpdate`

### Verifiziert
- `swift test` grün
- `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -configuration Debug -destination 'generic/platform=iOS' build` grün
- `git diff --check` sauber

### Bewusst nicht behauptet
- Kein neuer Device-Nachweis speziell für die interaktive Overview-/Explore-Karte
- Kein neuer TestFlight-/App-Store-Claim aus diesem Audit-Batch

## [2026-04-29] — test: Overview-Map Performance-Audit – Coordinate-Budget-Invarianten

### Befund (kein weiterer Codefix nötig)

Vollständiger Performance-Audit des overlayLimit-Fixes ergab: kein separates globales Coordinate-Budget nötig.

Die Kombination aus `overlayLimit × maxPolylinePoints` erzeugt bereits ein implizites hartes Gesamtbudget:

| Tier | overlayLimit | maxPolylinePoints | Max. Koordinaten gesamt |
|---|---|---|---|
| Very heavy | 150 | 64 | 9.600 |
| Heavy | 200 | 96 | 19.200 |
| Medium-heavy | 250 | 120 | 30.000 |
| Medium | 300 | 160 | 48.000 |

Exportdaten sind unberührt. Badge erscheint nur wenn `isOptimized=true`:
- „Karte vereinfacht – Export vollständig": wenn `visibleRouteCount < totalRouteCount` (Route-Cap greift)
- „Optimierte Übersicht": wenn Vereinfachung greift, aber alle Routen sichtbar

### Neue Tests (3)

- `testTotalRenderedCoordinateCountBoundedByOverlayTimesPointsLimit`: 600 Routen × 200 Punkte → max 9.600 Koordinaten total
- `testIndividualRouteCoordinateCountBoundedByMaxPolylinePoints`: 1 Route × 1000 Punkte → max 220 Punkte nach Decimation
- `testIsOptimizedTrueWhenDecimationAppliedButRoutesNotCapped`: 130 Routen → isOptimized=true, kein Capping, Badge „Optimized overview"

`swift test`: 650 Tests, 0 Failures. `git diff --check`: sauber.

---

## [2026-04-29] — fix: Overview-Map Freeze/Crash-Fix – Hard Overlay Limit

### Problem (App-Store-Submission-Blocker)

`AppOverviewTracksMapView` fror ein oder crashte bei Auswahl „Gesamtzeitraum" mit großen importierten Datenmengen.
Root Cause: `selectCandidates` lieferte alle Kandidaten (keine Obergrenze); MapKit erhielt tausende `MapPolyline`-Overlays.

### Fix

- `OverviewMapRenderProfile`: neues Feld `overlayLimit: Int` – Hard Cap auf die Anzahl gerenderter MapPolyline-Objekte.
- Tier-basierte Limits: >500 Routen oder >150k Punkte → 150; >240/>60k → 200; >120/>30k → 250; >60/>15k → 300; klein → kein Cap.
- `selectCandidates`: nach Score-Sortierung wird auf `prefix(overlayLimit)` abgeschnitten (Top-Routen nach Score).
- `isOptimized = true` wenn Cap greift → View-Badge „Karte vereinfacht – Export vollständig" (DE/EN).
- Export-Daten und Rohdatenmodell sind nicht berührt; Export verwendet weiterhin vollständige Daten.

### Tests

- 5 neue Tests in `AppOverviewTracksMapViewTests`: Tier-basierte `overlayLimit`-Werte, synthetisches 600-Routen-Dataset gecapped, kleines Dataset ungecapped, Start-/Endpunkt-Erhaltung, Export-Daten-Unveränderlichkeit.
- `swift test`: 647 Tests, 0 Failures.
- `git diff --check`: sauber.

### Dokumentation

- `NEXT_STEPS.md`: Fix als erledigt markiert; neuer offener Punkt: TestFlight-Verifikation mit realen Daten.
- `ROADMAP.md`, `docs/APP_FEATURE_INVENTORY.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_APP_PREPARATION.md`: aktualisiert.
- App-Store-Submission bleibt offen, bis Fix auf TestFlight mit echten Daten verifiziert.

---

## [2026-04-29] — TestFlight Build 1.0 (44): Smoke-Test-Stand dokumentiert

### Dokumentarisch (kein Codeeingriff)

- **TestFlight Build 1.0 (44)**: Auf iPhone installierbar und grundsätzlich lauffähig. Interner Smoke-Test abgeschlossen.
- **Beobachtung**: Gelegentliche UI-Hänger/Ruckler auf echtem Gerät; kein bestätigter reproduzierbarer Crash.
- **App-Store-Submission**: Bewusst noch nicht eingereicht. Offen bis Build in App Store Connect tatsächlich unter Vertrieb ausgewählt und submitted.
- **NEXT_STEPS.md**: `Xcode Cloud Release-Workflow grün verifiziert` abgehakt; Performance-Smoke-Test und App-Store-Einreichung als offene Punkte ergänzt.
- **docs/APPLE_VERIFICATION_CHECKLIST.md**: Abschnitt „TestFlight-Smoke-Test-Kriterien vor App-Store-Submission" ergänzt.
- **swift test**: 643 Tests, 0 Failures (verifiziert 2026-04-29).
- **git diff --check**: sauber.


---

## [2026-04-29] — Dynamic Island Settings + Live Activity Fallbacks + Overview Heatmap Chip

### Geaendert
- `LiveActivityPresentation.swift` neu: zentrale, testbare Formatierung fuer Dynamic-Island-Werte (`Distance`, `Duration`, `Points`, `Upload Status`) sowie testbare Availability-/Fallback-Logik fuer Live Activities
- `AppPreferences` / `AppOptionsView`: Dynamic-Island-Wert ist jetzt als persistente Primärwert-Option ausgebaut; neuer Upload-Status-Wert verfuegbar; Live-Activity-Verfuegbarkeit wird in den Optionen sichtbar gemacht und deaktiviert die Konfiguration sauber auf nicht unterstuetzten / deaktivierten Geraeten
- `LiveLocationFeatureModel` -> `ActivityManager` -> `TrackingStatus`: Upload-/Pause-Zustand wird jetzt tatsaechlich bis in die Live Activity durchgereicht statt nur im Modell zu existieren; neue `uploadState`-Ableitung (`disabled`, `active`, `pending`, `failed`, `paused`)
- `TrackingLiveActivityWidget.swift`: Lock Screen, Dynamic Island expanded, compact trailing und minimal nutzen jetzt den gewaehlten Primärwert konsistent; Minimal bleibt bewusst icon-basiert, aber folgt der Auswahl stabil
- `AppContentSplitView`: der bisherige Heatmap-Action-Block wurde in der Overview zu einem kompakten Capsule-Chip harmonisiert, passend zu den uebrigen Filter-/Status-Chips

### Verifiziert
- `swift test` -> `650` Tests, `0` Failures
- `git diff --check` -> sauber
- `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build` -> **BUILD SUCCEEDED**

### Offen / nicht als verifiziert behauptet
- Realer Device-/Dynamic-Island-Nachweis bleibt offen
- `xcodebuild ... -testPlan CI ... -only-testing:LH2GPXWrapperTests test` konnte auf diesem Host nicht belastbar abgeschlossen werden; der Simulator-Lauf brach beim App-Launch mit `NSMachErrorDomain Code=-308 (ipc/mig server died)` ab
- Keine Aussage zu manuell geoeffneter Live Activity / Dynamic Island / Homescreen-Widget auf echter Apple-Hardware

## [2026-04-29] — Build 34 IPA-Forensik: Root Cause bewiesen — NFD/NFC-Normalisierungsmismatch in Designated Requirement

### Befund (bewiesen durch vollständige IPA-Forensik)

IPA: `LH2GPXWrapper 1.0 app-store-4/LH2GPXWrapper.ipa` (Build 34, CFBundleVersion=34).

| Prüfpunkt | Ergebnis |
|---|---|
| Authority | `Apple Distribution: Sebastian Röber (XAGR3K7XDJ)` ✅ |
| TeamIdentifier | `XAGR3K7XDJ` ✅ |
| Provisioning Profile App | `iOS Team Store Provisioning Profile: de.roeber.LH2GPXWrapper` ✅ |
| Provisioning Profile Widget | `iOS Team Store Provisioning Profile: de.roeber.LH2GPXWrapper.Widget` ✅ |
| ProvisionedDevices | NICHT vorhanden (korrekt für App Store) ✅ |
| application-identifier App | `XAGR3K7XDJ.de.roeber.LH2GPXWrapper` ✅ |
| application-identifier Widget | `XAGR3K7XDJ.de.roeber.LH2GPXWrapper.Widget` ✅ |
| App Groups App+Widget | `group.de.roeber.LH2GPXWrapper` ✅ |
| get-task-allow | `false` (Distribution korrekt) ✅ |
| Entitlements App | application-identifier, team-identifier, app-groups, beta-reports-active — vollständig korrekt ✅ |
| Run Script Build Phases | KEINE vorhanden ✅ |
| CODE_SIGN_REQUIREMENTS override | NICHT gesetzt ✅ |
| OTHER_CODE_SIGN_FLAGS | NICHT gesetzt ✅ |
| `codesign --verify` | **valid on disk** ✅ |
| `codesign --verify --strict` | **does not satisfy its designated Requirement** ❌ |

### Root Cause (bewiesen, nicht geraten)

Die Designated Requirement (DR) in App und Widget enthält den Zertifikats-CN in **Unicode NFD**-Kodierung,
das tatsächliche Zertifikat (aus dem Provisioning Profile extrahiert) hat den CN in **Unicode NFC**-Kodierung.
Der `certificate leaf[subject.CN] = 0x<hex>` Check im DR ist ein **Byte-für-Byte-Vergleich** — kein Unicode-normalisierter Vergleich.

| | Bytes für `ö` in "Röber" |
|---|---|
| DR im Binary (NFD) | `6f cc 88` = U+006F (o) + U+0308 (COMBINING DIAERESIS) |
| Zertifikat CN (NFC, aus Profil via RFC2253 `\C3\B6`) | `c3 b6` = U+00F6 (ö, präkomponiert) |

**Ursachenkette:**
1. Apple Distribution Certificate hat CN-Bytes in NFC (`c3 b6` für ö)
2. Xcode Cloud liest den CN via macOS Security/Keychain-Framework als CFString
3. macOS normalisiert den String zu NFD (`6f cc 88` für ö)
4. Xcode bettet diesen NFD-Hex-Wert in die Designated Requirement ein
5. Apple's Upload-Validator prüft `certificate leaf[subject.CN] = 0x<NFD>` byte-genau gegen das Zertifikat (NFC)
6. `6f cc 88` ≠ `c3 b6` → "Code failed to satisfy specified code requirement(s)"

### Was ausgeschlossen ist
- Repo-Signing-Konfiguration (**nicht** die Ursache)
- App ID / App Group Registrierung (**nicht** die Ursache, beides korrekt im Portal)
- Provisioning Profile (**nicht** die Ursache, korrekt iOS Team Store)
- Entitlements (**nicht** die Ursache, vollständig korrekt)
- Run Scripts oder nachträgliche Bundle-Manipulation (**keine** vorhanden)

### Nächste Schritte (manuell, kein Repo-Fix nötig)
1. **Apple ID-Namen ändern**: appleid.apple.com → persönliche Daten → Namen auf ASCII-only (`Sebastian Roeber`) ändern
2. **Neues Distribution-Zertifikat erstellen**: Xcode.app → Settings → Accounts → Manage Certificates → Distribution-Zertifikat revoken + neu generieren (CN wird dann ohne ö erzeugt)
3. Xcode Cloud Clean Build starten

---

## [2026-04-29] — Release Distribution Signing Fix (Build 32 → Build 33)

### Problem
Xcode Cloud Build 32: Apple lehnte Upload mit `Validation failed (409) – Invalid Signature` ab.
Root Cause: `CODE_SIGN_IDENTITY` fehlte in allen Release-BuildSettings → Xcode wählte automatisch
`"Apple Development"` (Development-Zertifikat) auch für Archive/Distribution-Builds.

### Geaendert
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`:
  - `"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution"` in **LH2GPXWrapper Release** ergänzt
  - `"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution"` in **LH2GPXWidget Release** ergänzt
  - `com.apple.ApplicationGroups` in `TargetAttributes.SystemCapabilities` für **LH2GPXWrapper** ergänzt
  - `LH2GPXWidget (9EBB00052F6C000100000005)` mit `com.apple.ApplicationGroups` in **TargetAttributes** eingetragen
  - `CURRENT_PROJECT_VERSION` 27 → **28**

### Verifiziert (lokal)
- `swift test`: 643 Tests, 0 Failures ✅
- `xcodebuild -showBuildSettings Release LH2GPXWrapper`: `CODE_SIGN_IDENTITY = Apple Distribution` ✅
- `xcodebuild -showBuildSettings Release LH2GPXWidget`: `CODE_SIGN_IDENTITY = Apple Distribution` ✅
- `git diff --check`: OK ✅
- Lokales `xcodebuild archive` schlägt erwartungsgemäß fehl (kein lokales Distribution-Zertifikat für diese App-IDs — normal für Developer-Maschine ohne ASC-Distribution-Profil)

### Noch ausstehend
- Xcode Cloud Build 33 starten und prüfen, ob Archive + TestFlight-Upload grün ist

## [2026-04-29] — App-Store-Signing für Xcode Cloud bereinigt

### Geaendert
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: Release-/Archive-Pfad fuer `LH2GPXWrapper` und `LH2GPXWidget` auf `CODE_SIGN_STYLE = Automatic` und `DEVELOPMENT_TEAM = XAGR3K7XDJ` bereinigt
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: explizite Release-Overrides fuer `CODE_SIGN_IDENTITY` und `PROVISIONING_PROFILE_SPECIFIER` entfernt, damit Xcode Cloud/App Store Connect die passende Distribution-Signatur selbst aufloest
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: `CURRENT_PROJECT_VERSION` auf `27` angehoben
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: Widget-Embed-Phase auf `CodeSignOnCopy` korrigiert
- `Sources/LocationHistoryConsumerAppSupport/AppLiveTrackingView.swift`: stabile Accessibility IDs fuer Start/Stop-Recording im Live-Tab ergänzt
- `wrapper/LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift`: Device-Smoke-Test auf die neuen Live-Button-IDs umgestellt

### Verifiziert
- `swift test`: 643 Tests, 0 Failures ✅
- `xcodebuild -target LH2GPXWrapper -configuration Release -showBuildSettings`: `CODE_SIGN_STYLE = Automatic`, `CURRENT_PROJECT_VERSION = 27`, `DEVELOPMENT_TEAM = XAGR3K7XDJ` ✅
- `xcodebuild -target LH2GPXWidget -configuration Release -showBuildSettings`: `CODE_SIGN_STYLE = Automatic`, `CURRENT_PROJECT_VERSION = 27`, `DEVELOPMENT_TEAM = XAGR3K7XDJ` ✅
- `TARGETED_DEVICE_FAMILY = 1`, `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO`, `SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO` im Wrapper-Target ✅
- `ITSAppUsesNonExemptEncryption = false` weiterhin in App + Widget gesetzt ✅

### Offen
- Lokaler Transporter-Upload vom 2026-04-29 wurde von Apple weiter mit `Invalid Signature` fuer App + Widget abgelehnt
- Der neu angelegte Xcode-Cloud-Workflow `Release – Archive & TestFlight` muss noch real gruen durchlaufen und den ersten gueltigen TestFlight-Build erzeugen

## [2026-04-29] — GitHub Pages: Support- und Projektseite

### Hinzugefügt
- `docs/support.html`: öffentliche Support-Seite für App Store Connect; enthält FAQ, Kontakt, Formatübersicht, Datenschutz-Link
  URL: `https://dev-roeber.github.io/iOS-App/support.html`
- `docs/index.html`: kleine Projektseite (kein Download-Button, da App noch nicht im Store); enthält Kernfunktionen, Datenschutz-Highlight, Links
  URL: `https://dev-roeber.github.io/iOS-App/`
- `docs/privacy.html`: Support-Link im Footer ergänzt

### Inhalt
- FAQ-Abschnitt mit verifizierten Antworten (Import-/Exportformate aus Repo-Truth)
- Kein offizieller Live-Receiver-Dienst genannt
- Keine Download-Buttons / keine Aussage „im App Store verfügbar"
- Kein Tracking, kein JS, keine externen CDNs/Fonts

## [2026-04-29] — App-Store-Screenshots (iPhone 15 Pro Max, UITest-basiert)

### Hinzugefügt
- `docs/app-store-assets/screenshots/iphone-67/`: 6 Screenshots (1290×2796 px) vom iPhone 15 Pro Max via `testAppStoreScreenshots` UITest
- `docs/app-store-assets/screenshots/iphone-65/`: 6 Screenshots (1242×2688 px) proportional skaliert für 6.5"-Slot
- `wrapper/LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift`: Screenshot-Test auf XCTAttachment-Verfahren umgestellt (xcresult-Bundle statt direkter Dateischreib auf Device); alle 6 Screens (Import, Overview, Days, Insights, Export, Live)

### Inhalt
- Ausschließlich Repo-Demo-Fixture-Daten (keine privaten Nutzerdaten)
- Keine Debug-Overlays, keine feste Server-URL im Live-Tab, kein Token sichtbar
- App-Store-Deklaration „Keine Daten erfasst" korrekt dargestellt

### Verifiziert
- `swift test`: 643 Tests, 0 Failures ✅
- UITest `testAppStoreScreenshots` auf iPhone 15 Pro Max: PASSED (41 s) ✅
- Alle 6 PNGs extrahiert und dimensioniert: 1290×2796 (iphone-67) + 1242×2688 (iphone-65) ✅

## [2026-04-29] — Datenschutzerklärung (GitHub Pages)

### Hinzugefügt
- `docs/privacy.html`: statische Datenschutzerklärung in Deutsch, mobil-lesbar, ohne externe Tracker/Fonts/CDN
- URL für App Store Connect: `https://dev-roeber.github.io/iOS-App/privacy.html`
- Inhalt basiert ausschließlich auf verifizierten Datenflüssen (lokal, kein Entwickler-Server); optionaler Live-Upload klar als nutzerkonfiguriert/default-deaktiviert beschrieben
- App Store „Keine Daten erfasst" bestätigt

## [2026-04-29] — Export-Compliance: ITSAppUsesNonExemptEncryption gesetzt

### Hinzugefügt
- `wrapper/Config/Info.plist`: `ITSAppUsesNonExemptEncryption = false` (Haupt-App)
- `wrapper/LH2GPXWidget/Info.plist`: `ITSAppUsesNonExemptEncryption = false` (Widget-Extension)

### Begründung
App verwendet keine nicht-ausgenommene Verschlüsselung. Einzige Netzwerkkommunikation ist optionaler nutzergesteuerter HTTPS-Upload via URLSession — systemseitige Standardverschlüsselung, gem. US-Exportrecht ausgenommen. Kein CryptoKit, CommonCrypto, AES, RSA, VPN, E2E oder proprietäre Crypto-Bibliotheken. Beim App-Store-Upload sind keine Export-Compliance-Unterlagen erforderlich.

### Verifiziert
- `swift test`: 643 Tests, 0 Failures, 0 Skips ✅
- `xcodebuild generic/platform=iOS`: BUILD SUCCEEDED ✅

## [2026-04-29] — Device-Verifikation + UITest-Fix (All-Time-Chip-Regression)

### Verifiziert auf iPhone 15 Pro Max (ios 26.3, UDID 00008130-00163D0A0461401C)
- `swift test`: 643 Tests, 0 Failures, 0 Skips — 2× bestätigt
- `xcodebuild generic/platform=iOS`: BUILD SUCCEEDED
- `xcodebuild platform=macOS (LocationHistoryConsumerApp)`: BUILD SUCCEEDED
- CI.xctestplan Wrapper-Unit-Tests (iPhone 17 Pro Max Simulator, iOS 26.3.1): TEST SUCCEEDED
- **UITests 6/6 PASSED auf echtem iPhone 15 Pro Max**:
  - `testLaunch` × 4: App startet sauber ✅
  - `testAppStoreScreenshots`: Demo-Daten + Screenshots ✅
  - `testDeviceSmokeNavigationAndActions` (55s): Demo-Load, Overview/All-Time, Heatmap, Insights Share, Export fileExporter, Live Start/Stop — alles auf echtem Gerät bestätigt ✅

### Fix: UITest-Regression nach Last-7-Days-Default (2026-04-15)
- **Root Cause**: `AppSessionState.show(content:)` setzt `historyDateRangeFilter = .last7Days`; Demo-Fixture (2024) fällt außerhalb dieses Fensters → Insights leer → kein `insights.section.share` Button → UITest-Failure
- **Fix AppHistoryDateRangeControl.swift**: `.accessibilityIdentifier("range.chip.\(preset.rawValue)")` an alle Preset-Chip-Buttons ergänzt
- **Fix LH2GPXWrapperUITests.swift**: Nach Demo-Load `range.chip.all` tippen um auf All Time zurückzusetzen, bevor Insights-Tab geöffnet wird
- `swift test` nach Fix: 643 Tests, 0 Failures, 0 Skips ✅

### Korrektur (aus vorherigem Audit)
- `docs/XCODE_APP_PREPARATION.md`: "Deployment Target iOS 26.2" → "iOS 16.0 / 16.2"

### Weiterhin offen (unverändert)
- Xcode Cloud Workflow, App ID/App Group im Developer Portal, Privacy Policy URL, Support URL, finales App Icon
- Großer Import, Track-Editor, Widget, Live Activity, Landscape — manuell prüfen

## [2026-04-15] — Overview: Last-7-Days-Default, Chip-Reihenfolge, Ladefortschritt-Karte

### Geändert
- `HistoryDateRangeFilter.swift`: Enum-Case-Reihenfolge geändert: `last7Days | last30Days | last90Days | thisYear | custom | all` — "Gesamtzeitraum" steht jetzt ganz rechts hinter "Benutzerdefiniert"; `allCases` und damit die Chips passen sich automatisch an
- `AppSessionState.swift`: `historyDateRangeFilter` Startwert `.all` → `.last7Days`; `show(content:)` setzt den Filter bei jedem Import auf `last7Days` zurück — bestehende User-Wahl wird nur bei neuem Import ersetzt, nicht bei Tab-Wechsel
- `AppOverviewTracksMapView.swift`: Neues `OverviewMapLoadingPhase`-Enum (`.analyzing` / `.building`); `loadMapData()` setzt Phase vor und nach dem Inner-Task; `loadingPlaceholder` als frosted-glass Karte mit Spinner, linearem `ProgressView` und Phasentext ersetzt den reinen Kringel
- `AppLanguageSupport.swift`: DE-Strings für "Analysing routes…" und "Building map…" ergänzt

### Effekt
- Standardmäßig wird nach Import nur der letzte 7-Tage-Zeitraum geladen → MapKit-Overlay-Last bei großen Dateien um Faktor ~50 reduziert (real größte Freeze-Ursache)
- User sieht sofort relevante, aktuelle Tracks statt den kompletten Gesamtzeitraum
- Ladefortschritt zeigt ehrliche Phase statt blindem Spinner

### Teststatus
643 Tests, 0 Failures, 0 Skips — BUILD SUCCEEDED ✅

## [2026-04-14] — Overview Map: Spinner-Freeze-Fix bei großen Dateien (Cancellation-Bug)

### Behoben
- `AppOverviewTracksMapView.swift`: `loadMapData()` — entfernt `!Task.isCancelled`-Guard; dieser war Root Cause eines permanenten Spinners: wenn SwiftUI die `.task(id:)`-Body cancelierte (z. B. kurze View-Transition nach Import), wurde das Ergebnis verworfen, aber kein neuer Task startete → `renderData` blieb ewig auf `.loading` hängen
- `AppOverviewTracksMapView.swift`: `loadMapData()` — ersetzt `Task.detached(...).value` durch `withTaskCancellationHandler` + `innerTask.cancel()` im `onCancel`-Handler: Cancellation des Outer-Tasks propagiert jetzt sofort in den Detached-Task
- `AppOverviewTracksMapView.swift`: `buildRenderDataFast()` — Cancellation-Check **vor** der teuren Douglas-Peucker-Phase: bei großen Dateien (46 MB / tausende Tracks) kann Cancellation jetzt den DP-Loop komplett überspringen statt ihn vollständig auszuführen
- `AppOverviewTracksMapView.swift`: `buildRenderDataFast()` — Overlay-Build-Loop von `compactMap` auf explizite `for`-Schleife mit `if Task.isCancelled { break }` umgestellt: Cancellation unterbricht die DP-Verarbeitung path-by-path statt am Ende zu prüfen
- `Tests/AppOverviewTracksMapViewTests.swift`: 2 neue Tests: `testBuildRenderDataFastExitsEarlyWhenCancelledBeforeDP` (canceled Task produziert keine Overlays), `testBuildRenderDataFastCancelledTaskDoesNotBlockSubsequentResult` (zwei parallele unkancelierte Runs liefern identische Routenzahl)

### Verhalten nach Fix
- Kein permanenter Spinner mehr nach Großdatei-Import wenn View kurz getransitioniert
- Bei taskKey-Wechsel (neue Generation aktiv): altes Ergebnis wird korrekt verworfen (generation-Guard bleibt)
- Bei View-Disappear ohne neuen Task: partielles oder leeres Ergebnis wird publiziert → Spinner klärt sich sofort

### Teststatus
636 Tests, 0 Failures, 0 Skips — BUILD SUCCEEDED ✅

## [2026-04-14] — Overview Map Performance: O(N) Fast Path für große Standortdateien

### Behoben
- `AppOverviewTracksMapView.swift`: `loadMapData()` ruft jetzt `OverviewMapPreparation.buildRenderDataFast(for:export:filter:)` statt des alten `buildRenderData(for:content:filter:)` auf — eliminiert O(N² log N)-Bottleneck bei großen Importdateien (z. B. 46 MB / tausende Tracks)
- `OverviewMapPreparation.buildRenderDataFast`: Neuer O(N) Single-Pass über `export.data.days` mit `Set<String>` für O(1)-Datum-Lookup; iteriert alle Tage genau einmal ohne per-date `projectedDays()`-Sortierung; laufende Bounding Box statt `allCoords`-Akkumulation; Cancellation-Check alle 100 Iterationen; Point Budget (2 Mio.); direkter Zugriff auf `Path.flatCoordinates` (schnellster Pfad) mit Fallback auf `Path.points`; Activity-Type-Filter aus `AppExportQueryFilter` angewandt
- `Tests/AppOverviewTracksMapViewTests.swift`: 4 neue Tests: `testBuildRenderDataFastProducesSameRouteCountAsLegacy_small`, `testBuildRenderDataFastEmptyDateSetReturnsEmpty`, `testBuildRenderDataFastActivityTypeFilterExcludesNonMatchingPaths`, `testBuildRenderDataFastLargeFixtureProducesValidResult`

### Teststatus
634 Tests, 0 Failures, 0 Skips — BUILD SUCCEEDED ✅

## [2026-04-14] — Tage UI/UX: Layout-Bugfixes (GeometryReader, ScrollView, Steuerzeile)

### Behoben
- `AppDayListView.swift` (`AppDayRow`): `GeometryReader` als Root-View in List-Rows entfernt — war Root Cause für überlappende/abgeschnittene Day-Rows (Row-Breite > Row-Höhe → `isLandscape = true` immer wahr); ersetzt durch `@Environment(\.verticalSizeClass)`
- `AppDayDetailView.swift`: `GeometryReader` in `contentView` entfernt — war Root Cause für schwarzen Leerraum/unsichtbaren Inhalt (innerhalb eines outer `ScrollView` bekommt `GeometryReader` height=0 → `isLandscape = true` immer wahr → Landscape-HStack mit 0 Höhe → nichts sichtbar); ersetzt durch `@Environment(\.verticalSizeClass)`
- `AppContentSplitView.swift`: outer `ScrollView` um `AppDayDetailView` im compact Nav-Destination entfernt — verursachte das GeometryReader-height=0-Problem; `AppDayDetailView.contentView` verwaltet seinen eigenen `ScrollView`
- `AppDayDetailView.swift`: Segmented Control + Globe-Button in eine gemeinsame Steuerzeile (`mapControlRow`) zusammengeführt — Globe-Button war isoliert als Overlay auf der Karte; jetzt sauber horizontal ausgerichtet
- `AppPreferences.swift`: Label `"Simplified (Beta)"` → `"Simplified"` — war zu lang für Segmented Control, verursachte Abschneiden
- `AppLanguageSupport.swift`: Veralteten Key `"Map-Matched (Beta)"` durch `"Simplified": "Vereinfacht"` ersetzt
- `AppDayMapView.swift`: Parameter `showStyleToggle: Bool = true` ergänzt — ermöglicht caller-seitige Steuerung des Style-Buttons ohne Regression bei bestehenden Callsites
- `Tests/DayListPresentationTests.swift`: 2 neue Regressionstests für PathDisplayMode-Labels ergänzt

### Teststatus
630 Tests, 0 Failures, 0 Skips — BUILD SUCCEEDED ✅

## [2026-04-14] — Historien-Track-Editor: Mutations-Reset bei Import-Wechsel

### Geaendert
- `AppImportedPathMutationStore.swift`: `validateSource(_:)` ergaenzt — vergleicht gespeicherten Source-Identifier (Dateiname) mit dem aktiven Import; setzt bei Wechsel alle Mutations zurueck und speichert neuen Identifier; `reset()` loescht jetzt auch den Identifier-Key
- `AppContentSplitView.swift`: `.onChange(of: session.source)` ergaenzt — ruft `pathMutationStore.validateSource(source.displayName)` bei jedem Import-Wechsel auf
- `Tests/ImportedPathMutationTests.swift`: 3 neue Tests: `testMutationsPreservedForSameSource`, `testMutationsResetOnSourceChange`, `testValidateSourcePersistsIdentifierAcrossReload`

### Verhalten
- Mutations bleiben erhalten, wenn dieselbe Datei nach App-Neustart wieder geoeffnet wird (gleicher Dateiname = gleicher Identifier)
- Mutations werden zurueckgesetzt, wenn eine andere Datei importiert wird (unterschiedlicher Identifier)
- Kein stiller Seiteneffekt bei unveraendertem Import

### Teststatus
628 Tests, 0 Failures, 0 Skips

## [2026-04-14] — Historien-Track-Editor: Safety-Fix + CI.xctestplan

### Geaendert
- `AppDayDetailView.swift`: Alert-Text korrigiert — falsches Restore-Versprechen entfernt; neu: "The original data is not modified." (kein reset()-UI existiert)
- `AppLanguageSupport.swift`: DE-Übersetzung entsprechend angepasst
- `wrapper/CI.xctestplan`: neuer CI-Testplan nur mit `LH2GPXWrapperTests` (ohne UITests — Location-Dialoge/Timing in Xcode Cloud nicht stabil)
- `wrapper/LH2GPXWrapper.xcscheme`: `CI.xctestplan` als zweite Testplan-Option registriert
- `Tests/ImportedPathMutationTests.swift`: `testDuplicateDeletionIsIgnored` ergänzt (dreifaches addDeletion → exakt 1 Eintrag)

### Teststatus
625 Tests, 0 Failures, 0 Skips — Commits `30192e1`, `8036a01`

## [2026-04-14] — ZIPFoundation: Fork-Dependency gehärtet (branch → exact-Tag)

### Geaendert
- `Package.swift`: ZIPFoundation-Pin von `branch: "development"` auf `exact: "0.9.20-devroeber.1"` umgestellt
- Tag `0.9.20-devroeber.1` im Fork `dev-roeber/ZIPFoundation` auf Commit `d6e0da4` erstellt und gepusht
- `Package.resolved` (root + wrapper): `state` von branch-Format auf version-Format (`"version": "0.9.20-devroeber.1"`) aktualisiert
- `docs/XCODE_CLOUD_RUNBOOK.md`: Fork-Sektion überarbeitet — Upgrade-Prozess, Begründung für `.exact()`, vorherige Branch-Strategie als deprecated markiert

### Hintergrund
`branch: "development"` ist nicht reproduzierbar — jeder neue Commit auf dem Branch ändert den Build.
`.exact("0.9.20-devroeber.1")` garantiert dieselbe Revision in jedem Xcode-Cloud- und lokalen Build.

### Teststatus
624 Tests, 0 Failures, 0 Skips — Build complete

## [2026-04-14] — ZIPFoundation: Umstellung auf eigenen Fork dev-roeber/ZIPFoundation

### Geaendert
- `Package.swift`: ZIPFoundation-Dependency von `weichsel/ZIPFoundation.git` auf `dev-roeber/ZIPFoundation.git` (Branch `development`) umgestellt
- `Package.resolved`: neu gepinnt auf Revision `d6e0da4509c22274b2775b0e8c741518194acba1` (Branch `development`)
- `wrapper/LH2GPXWrapper.xcodeproj/.../Package.resolved`: konsistent mit Root-Resolved aktualisiert; staler `originHash` entfernt (wird von Xcode automatisch neu berechnet)
- `docs/XCODE_CLOUD_RUNBOOK.md`: neuer Abschnitt "ZIPFoundation Fork-Abhängigkeit" inkl. Fork-URL, Revision, Sync-Anleitung

### Hintergrund
Xcode Cloud benötigt expliziten GitHub-Zugriff auf jedes referenzierte Repo.
Das Upstream-Repo `weichsel/ZIPFoundation` liegt außerhalb des eigenen GitHub-Accounts.
Durch Umstellung auf den eigenen Fork (`dev-roeber/ZIPFoundation`) liegt die einzige externe SPM-Abhängigkeit jetzt vollständig unter `dev-roeber/*`.

### Teststatus
624 Tests, 0 Failures, 0 Skips — Build complete

## [2026-04-13] — Historien-Track-Editor Slice: importierte Routen ausblenden

### Hinzugefuegt
- `ImportedPathMutation.swift` (neu in `LocationHistoryConsumer`): `ImportedPathDeletion` + `ImportedPathMutationSet` (Codable/Equatable); `DayDetailViewState.removingDeletedPaths(for:)` filtert Pfade ohne AppExport-Mutation
- `AppImportedPathMutationStore.swift` (neu in `LocationHistoryConsumerAppSupport`): `ObservableObject`, UserDefaults-JSON-Persistenz, `addDeletion()` (Duplikat-sicher) + `reset()`
- `AppDayDetailView`: "Route entfernen"-Button in `pathCard` (Portrait + Landscape); Confirmation-Alert; `mutations: ImportedPathMutationSet` + `onRemovePath` als optionale Parameter (bestehende Aufrufer bleiben unverändert)
- `AppLanguageSupport`: DE-Übersetzungen für `"Remove Route"`, `"Remove"` und die Alert-Message
- `ImportedPathMutationTests.swift`: 7 neue Tests (623 gesamt, 0 Skips, 0 Failures)

### Architektur
- Original-AppExport wird nie verändert; Mutations-Overlay wird nur zur Darstellungszeit angewandt
- `pathIndex` = 0-basierter Index in `Day.paths`; Out-of-bounds-Indizes und fremde dayKeys werden ignoriert
- Persistenz konsistent mit `AppPreferences`-Muster (UserDefaults + JSONEncoder/Decoder)

## [2026-04-13] — Xcode Cloud Hardprüfung + Doku-Korrekturen

### Behoben
- `wrapper/ci_scripts/ci_pre_build.sh` → umbenannt in `ci_pre_xcodebuild.sh`: `ci_pre_build.sh` ist kein gültiger Xcode Cloud Skriptname und würde stillschweigend ignoriert; korrekte Namen sind `ci_post_clone.sh`, `ci_pre_xcodebuild.sh`, `ci_post_xcodebuild.sh`
- `docs/XCODE_CLOUD_RUNBOOK.md`: beide `ci_pre_build.sh`-Referenzen auf `ci_pre_xcodebuild.sh` korrigiert; Hinweis auf gültige Skriptnamen ergänzt
- `wrapper/docs/TESTFLIGHT_RUNBOOK.md`: falscher Deployment Target `iOS 26.2` auf `iOS 16.0 / 16.2` (App/Widget) korrigiert
- `wrapper/docs/LOCAL_IPHONE_RUNBOOK.md`: veralteter Pfad `~/repos/LocationHistory2GPX-Monorepo` (2×) → `~/Desktop/XCODE/iOS-App`
- `wrapper/docs/TESTFLIGHT_RUNBOOK.md`: veralteter Pfad `~/repos/LocationHistory2GPX-Monorepo` (2×) → `~/Desktop/XCODE/iOS-App`
- `docs/XCODE_RUNBOOK.md`: veralteter Pfad `~/repos/LocationHistory2GPX-Monorepo` (2×) → `~/Desktop/XCODE/iOS-App`
- `wrapper/README.md`: veralteter Pfad `~/repos/LocationHistory2GPX-Monorepo` → `~/Desktop/XCODE/iOS-App`

### Verifikation
- `swift test`: 616 Tests, 0 Failures — `xcodebuild generic/platform=iOS`: BUILD SUCCEEDED

## [2026-04-13] — Apple-Developer-Basis + Xcode Cloud Setup

### Behoben
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: UITests Bundle ID `xagr3k7xdj.de.roeber.lh2gpxwrapper.uitests` → `de.roeber.LH2GPXWrapper.UITests` (beide Konfigurationen Debug + Release); Xcode hatte beim Anlegen des Targets die Team-ID als Prefix generiert

### Hinzugefuegt
- `wrapper/.xcode-version`: pinnt Xcode Cloud auf Version 26.3 (entspricht lokal installiertem Xcode)
- `wrapper/ci_scripts/ci_post_clone.sh`: Xcode Cloud Post-Clone-Hook (dokumentiert lokale SPM-Abhängigkeit, erweiterbar)
- `wrapper/ci_scripts/ci_pre_build.sh`: injiziert `CI_BUILD_NUMBER` als `CFBundleVersion` in App- und Widget-Info.plist; bei lokalem Build ohne `CI_BUILD_NUMBER` No-op
- `wrapper/ci_scripts/ci_post_xcodebuild.sh`: Post-Build-Logging mit Exit-Code und Action
- `docs/XCODE_CLOUD_RUNBOOK.md`: vollständiges Runbook für Xcode Cloud Setup inkl. manueller GUI-Schritte, Signing-Tabelle, Build-Nummern-Logik, Kompatibilitätsprüfung

### Doku aktualisiert
- `docs/APPLE_VERIFICATION_CHECKLIST.md`: 2026-04-13 Block mit verifizierten Schritten und offenen manuellen Apple-Gates
- `NEXT_STEPS.md`: Bundle-ID-Fix und Xcode-Cloud-Vorbereitungsschritte als erledigt markiert; manuelle Apple-Schritte als offene Aufgaben eingetragen

## [2026-04-13] — PathFilter: GPS-Jump-Filter als Vorverarbeitung im mapMatched-Modus

### Hinzugefuegt
- `PathFilter.swift` (neu): `removeOutliers(_:maxJumpMeters:)` auf `LocationCoordinate2D` (Linux-kompatibel) entfernt GPS-Ausreisser mit Sprung > 5000 m; `#if canImport(CoreLocation)` Wrapper fuer `CLLocationCoordinate2D`
- `AppDayMapView.swift`: im `.mapMatched`-Zweig wird `path.coordinates` jetzt zuerst durch `PathFilter.removeOutliers(...)` gefiltert, dann durch `PathSimplification.douglasPeucker(...)`; `.original`-Zweig bleibt unveraendert
- Fallback: wenn nach dem Filter < 2 Punkte uebrig bleiben, wird die Original-Sequenz unveraendert weitergereicht
- `PathFilterTests.swift`: 9 Unit-Tests (Edge-Cases, normale Tracks, Ausreisser-Entfernung, Fallback, Custom-Threshold) — 616 Tests gesamt, 0 Failures

### Hinweis
- Kein echtes Strassen-/Weg-Snapping — die `Simplified (Beta)`-Darstellung bleibt geometrische Vereinfachung + Ausreisserfilterung ohne Road-Network-Abgleich
- Kein Device-Run; Xcode iOS Build + swift build + swift test (macOS) gruen (Commit cf66dd1)

## [2026-04-13] — Live-Ausbau: Auto-Resume UX + Session-Restore

### Hinzugefuegt
- `LiveLocationFeatureModel`: `sessionStartedAt` wird beim App-Start aus UserDefaults wiederhergestellt, wenn eine unterbrochene Session vorliegt — der Banner zeigt jetzt den relativen Zeitstempel der Unterbrechung an
- `AppLiveTrackingView`: Unterbrochene-Session-Banner zeigt "Eine Aufzeichnung, die vor X Minuten gestartet wurde, wurde unterbrochen" statt generischer Meldung (via `RelativeDateTimeFormatter`)
- `AppGermanTranslations`: 16 neue DE-Strings fuer Live-Tracking-Banner, Follow-Mode, Fullscreen-Map und weitere UI-Elemente
- Neuer Test `testSessionStartedAtRestoredOnInitWhenSessionIDPresent` prueft dass gespeicherter Session-Timestamp beim Init korrekt geladen wird — 607 Tests gesamt, 0 Failures

## [2026-04-13] — Release-Haertung: Accessibility + Options UX

### Verbessert
- `AppLiveTrackingView`: stat-Karten (`statCard`) erhalten `.accessibilityElement(children: .ignore) + .accessibilityLabel("\(value), \(label)")` — VoiceOver liest Wert + Label als eine Einheit statt Einzelfragmente
- `AppInsightsContentView`: `summaryCard` und `avgCard` erhalten kombiniertes Accessibility-Element (Wert + Titel + optionaler Subtitel) fuer konsistente VoiceOver-Ausgabe
- `AppOptionsView` (Sektion "Language and Upload"): "Upload Batch Size" und "Upload Status" werden nur noch angezeigt wenn "Upload to Custom Server" aktiv ist — reduziert Informationsrauschen fuer die grosse Mehrheit der Nutzer ohne Upload-Konfiguration

## [2026-04-12] — Device-Smoke-Test, Widget Privacy Manifest, Archive-Verifikation

### Hinzugefuegt
- `wrapper/LH2GPXWidget/PrivacyInfo.xcprivacy` erstellt und im `.xcodeproj` verankert (UserDefaults CA92.1, kein Tracking)

### Verifiziert
- iPhone 15 Pro Max (00008130-00163D0A0461401C): App installiert, gestartet, kein Crash (PID stabil)
- ZIPFoundation 0.9.20 bringt eigenes Privacy Manifest mit (FileTimestamp 0A2A.1) — kein Handlungsbedarf
- Signing (Team XAGR3K7XDJ, Automatic) funktioniert fuer Device-Build
- Store-Archive-Pfad ist `wrapper/LH2GPXWrapper.xcodeproj`, nicht SPM-Scheme

## [2026-04-12] — Mac/Xcode Build Fix: Compiler Errors + Swift Test Regressions

### Fixed
- `AppDayDetailView.swift`: `landscapeContentColumn(detail: detail)` → `landscapeContentColumn(detail)` (anonymous label mismatch; caused Xcode build failure)
- `AppDayMapView.swift`: `fillHeight` promoted to init parameter `init(mapData:fillHeight:)` so landscape caller can pass `fillHeight: true` (previously `AppDayMapView(mapData:fillHeight:)` call failed to compile)
- `WidgetDataStore.swift`: added `import LocationHistoryConsumerAppSupport` so `DynamicIslandCompactDisplay` type resolves in widget target scope
- `AppInsightsContentView.swift`: body extracted into `loadedBody` + `insightsScrollContent(isLandscape:)` + `insightsModeContent` to fix "compiler unable to type-check expression in reasonable time"; also fixed latent `LazyVGrid(alignment: .top)` bug → `.leading` (HorizontalAlignment)
- `AppLiveTrackingView.swift`: `.fullScreenCover` wrapped in `#if os(iOS)` to fix `swift test` failure on macOS (unavailable API)
- `MapMatchingTests.swift`: empty array literal `[]` disambiguated as `[LocationCoordinate2D]()` to resolve ambiguity between `CLLocationCoordinate2D` and `LocationCoordinate2D` overloads

### Build/Test Status
- `xcodebuild build -scheme LH2GPXWrapper -destination iPhone 17 Simulator`: BUILD SUCCEEDED
- `swift test` (macOS): 606 Tests, 0 Failures, 0 Skips
- Xcode unit tests (LH2GPXWrapperTests): all passed
- UI automation tests (testDeviceSmokeNavigationAndActions, testAppStoreScreenshots): expected fail on Simulator (need real device + loaded content)

## [2026-04-12] — Truth Sync: Sorting, Overview Fidelity, Insights Range, Linux Testability

### Changed
- `AppSessionState`: app-weite Day-Summary-Projektion und gefilterte Days-Liste jetzt repo-wahr `neu -> alt`; Initialauswahl/Fallback bevorzugen den neuesten sichtbaren Tag statt des aeltesten
- `AppOverviewTracksMapView`: versteckte Route-Kappung fuer die Overview-Karte entfernt; alle Routen im aktiven Zeitraum bleiben erhalten, Performance laeuft weiter ueber Vereinfachung/Decimation statt stilles Weglassen
- `AppInsightsContentView` / `InsightsMonthlyTrendPresentation`: Monats-Trends respektieren jetzt den aktiven Zeitraum ohne 24-Monats-Cap; Tabellen-/Listenansicht zeigt neueste Monate zuerst

### Fixed
- Linux-Testbarkeit fuer Import-/Pfad-/Layout-Code nachgezogen: `PathSimplification`, GPX-/TCX-XML-Parser und zugehoerige Tests laufen jetzt ohne Apple-only Foundation/CoreLocation-Annahmen
- `LandscapeLayoutTests` und `DemoDataLoaderTests` auf aktuellen Produktstand korrigiert

### Tests
- `swift test` auf Linux: `575` Tests, `2` Skips, `0` Failures

### Not done
- kein echtes Road-/Path-Matching
- kein Auto-Resume laufender Live-Aufzeichnungen nach App-Neustart
- keine neue Apple-Device-/Portal-Verifikation; Linux-only Nachweis

## [2026-04-12] — Release-Härtung: TCX, Widget-Lokalisierung, Privacy, CI

### Fixed
- `TCXImportParser.swift`: bekannter `fatalError`-Pfad entfernt; Parser liefert jetzt typisierte `TCXImportError`-Faelle fuer invalides XML, fehlende Trackpoints, fehlende Pflichtdaten und Export-Roundtrip-Fehler
- `AppContentLoader.swift`: TCX-Parserfehler werden an der Loader-Grenze weiterhin kontrolliert auf `AppContentLoaderError.decodeFailed(...)` abgebildet; kein Crash im Import-Flow
- Widget-/Live-Activity-Texte in `wrapper/LH2GPXWidget/` auf lokalisierte `WidgetStr`-Zugriffe umgestellt; Widget bevorzugt jetzt die via App Group gespiegelte `AppLanguagePreference` und faellt sonst auf die Geraetesprache zurueck
- `AppPreferences.swift`: App-Sprache wird in die App-Group-Defaults gespiegelt, damit Widget und App denselben Sprachwunsch teilen koennen
- `PrivacyInfo.xcprivacy`: `NSPrivacyCollectedDataTypePreciseLocation` fuer den optionalen, standardmaessig deaktivierten Live-Upload explizit als `App Functionality`, nicht linked und nicht tracking-basiert deklariert

### Tests
- `swift test`: 586 Tests, 0 Failures
- Parser-Tests fuer invalides TCX, fehlende Pflichtdaten und unerwartete Trackpoint-Zustaende aktualisiert/ergaenzt
- `AppPreferencesTests`: neue Abdeckung fuer das Spiegeln der App-Sprache in die Widget-App-Group
- CI (`.github/workflows/swift-test.yml`): echter `xcodebuild`-Build fuer `LH2GPXWrapper` inklusive eingebettetem `LH2GPXWidget` statt reinem Kommentar-/Echo-Step

## [2026-04-12] — App Groups Entitlements + GPX/TCX fileImporter + Deep Link + Overview Map Budget Fix

### Added
- App Groups Entitlements: `LH2GPXWrapper.entitlements` und `LH2GPXWidget.entitlements` mit `com.apple.security.application-groups: group.de.roeber.LH2GPXWrapper` erstellt; `CODE_SIGN_ENTITLEMENTS` fuer alle 4 Build-Konfigurationen beider Targets in `project.pbxproj` gesetzt — Widget-Datenaustausch via `WidgetDataStore` (UserDefaults App Group) funktioniert jetzt korrekt; vorher zeigte Widget immer "Keine Aufzeichnung"
- `fileImporter` akzeptiert jetzt zusaetzlich `.gpx` und `.tcx`: `UTType.tcx` Extension in `GPXDocument.swift`, `allowedContentTypes` in `ContentView.swift` von `[.json, .zip]` auf `[.json, .zip, .gpx, .tcx]` erweitert
- Deep Link `lh2gpx://live`: `CFBundleURLTypes` mit Schema `lh2gpx://` in `Info.plist` registriert; `onOpenURL`-Handler + `handleDeepLink()` in `ContentView.swift`; `navigateToLiveTabRequested` Property in `LiveLocationFeatureModel.swift`; `onChange`-Observer in `AppContentSplitView.swift` navigiert zu Live-Tab (`selectedTab = 3`)

### Fixed
- `AppOverviewTracksMapView`: Komplette Neuimplementierung mit `OverviewMapRenderProfile` (adaptives Budget 72–180 Routen), Grid-basierter Kandidatenauswahl und Douglas-Peucker Simplifikation — Karte zeigte 294 Routen statt sinnvolles Budget
- `TCXImportParser.makeExport()`: `fatalError` durch `throw AppContentLoaderError.decodeFailed(fileName)` ersetzt — robustes Fehlerhandling statt Absturz bei ungueltigen TCX-Daten

### Tests
- `TCXImportParserTests`: neue dedizierte Tests fuer happy path (sample_import.tcx), error paths (leere Daten, kaputtes XML, kein Position-Element), isTCX-Detection, sourceType und Koordinatengenauigkeit
- 573 Tests, 0 Failures (historischer Stand dieses Batches)

## [2026-04-12] — Deep Audit + Homescreen Widget + Live Activity Improvements + Overview Map Performance

### Added
- Homescreen Widget (`LH2GPXHomeWidget`): systemSmall + systemMedium, zeigt letzte Aufzeichnung (Distanz, Dauer, Datum), Deep-Link `lh2gpx://live`
- `WidgetDataStore.swift`: App-Group UserDefaults (`group.de.roeber.LH2GPXWrapper`), graceful Fallback auf `.standard`
- `TrackingStatus` Erweiterungen: `isPaused`, `uploadQueueCount`, `lastUploadSuccess` (backward-compat `decodeIfPresent`)
- Live Activity UI: Pause-Indikator ("⏸ Pausiert"), Upload-Badge ("↑ N"), Pace-Label auf Lock Screen
- ActivityKit Update-Throttling: ≤1 Update/5s (`ThrottleGate` in `ActivityManager`)
- 4 neue `WidgetDataStoreTests`, 14 neue `LiveActivityTests`
- `wrapper/Makefile`: dynamisches Device-Deploy via `xcrun devicectl` (CoreDevice UUIDs)
- `.gitignore`: `xcuserdata/`, `*.xcuserstate`

### Performance
- Overview Map: einphasige Off-Main-Preparation statt altem 100-Day-Batching; veraltete Background-Loads werden über stärkeren Task-Key + Generation-Guard verworfen
- Overview Map: Route-Budget/LOD für große Zeiträume (`routeLimit`, Grid-Selektion pro Region-Zelle, Decimation pro Polyline) für robuste Darstellung bei hohen Datenmengen
- Douglas-Peucker Simplification 50–140m für Overview je nach Datenmenge (Detail bleibt feiner)
- Overview-Badge zeigt jetzt die tatsächlich dargestellten Overview-Routen; bei großen Datenmengen zusätzlich Kennzeichnung als optimierte Übersicht
- 3 neue `AppOverviewTracksMapViewTests` sichern Task-Key-Invaliderung, Small-Range-Verhalten und Large-Range-Optimierung

### Infrastructure
- `LocationHistory2GPX` (Python Pipeline) auf privat gesetzt
- 570 Tests total, 0 Failures ✅

## [2026-04-12] — KMZ Export + Live Activity Widget UI + Xcode Setup

### Added
- KMZ Export: `KMZBuilder.swift` (ZIPFoundation, temp-file pattern), `KMZDocument.swift` (BinaryExportDocument), `ExportFormat.kmz` case (archivebox.fill icon), vollständige Integration in `AppExportView` mit eigenem `fileExporter` für binäres KMZ
- 6 neue KMZ-Tests in `KMZExportTests.swift` (ZIP-Signatur, doc.kml Struktur, KML-Inhalt, Waypoint-Mode, Empty-Days)
- Live Activity Widget UI: `wrapper/LH2GPXWidget/` mit `TrackingLiveActivityWidget.swift` (Dynamic Island expanded/compact/minimal + Lock Screen Banner), `LH2GPXWidgetBundle.swift`, `Info.plist`
- `docs/WIDGET_XCODE_SETUP.md`: vollständige Schritt-für-Schritt-Anleitung für manuelles Xcode Widget Extension Target Setup
- 556 Tests total, 0 Failures (vorher 550)

### Infrastructure
- Xcode Build für iPhone 15 Pro Max: BUILD SUCCEEDED ✅
- Deploy + Launch auf iPhone 15 Pro Max (UDID 00008130-00163D0A0461401C) ✅

## [iOS-App Init] - 2026-04-12

### Changed
- iOS-App ist ab jetzt das zentrale aktive Repo (dev-roeber/iOS-App)
- Vollstaendige iOS-App aus LocationHistory2GPX-Monorepo konsolidiert (inkl. kompletter Git-History)
- LocationHistory2GPX-Monorepo, LocationHistory2GPX-iOS, LH2GPXWrapper sind historische Vorstufen

## [Prompt 4b] - 2026-04-12

### Changed
- Replaced subtle icon-only help button with prominent inline action on import start screen
- GoogleMapsExportHelpInlineAction: full text label "Google Maps Export on iPhone", map icon, chevron, accentColor background
- Positioned directly above the primary "Open location history file" button
- Removed icon-only GoogleMapsExportHelpButton from title row
- Added DE accessibilityHint for VoiceOver

## [Prompt 4] - 2026-04-12

### Added
- Google Maps export help sheet on start screen (GoogleMapsExportHelpView)
- Info button (questionmark.circle) next to source title in AppSourceSummaryCard
- Native bottom sheet: title, 4 concise steps for iPhone export, Takeout fallback hint
- DE/EN localization for all help strings (9 new entries in AppGermanTranslations)
- 4 new unit tests in GoogleMapsExportHelpTests

## [Prompt 3] - 2026-04-12

### Added
- Map Matching toggle in Days detail view: "Original" vs. "An Straße angepasst (Beta)"
- Douglas-Peucker path simplification (PathSimplification.swift, epsilon=15m, no external deps)
- AppDayPathDisplayMode enum (.original / .mapMatched) with @AppStorage persistence
- Live Activity / Dynamic Island support via ActivityKit (iOS 16.1+)
- TrackingAttributes + TrackingStatus (ActivityAttributes) for recording state
- ActivityManager singleton: start/update/end/cancelAll
- NSSupportsLiveActivities = true in Info.plist
- Integration in LiveLocationFeatureModel and LiveTrackRecorder
- 16 new tests (MapMatchingTests + LiveActivityTests), total: 546

## Audit 2026-04-12 — Prompt2/Prompt3 Truth Sync
- Prompt 2 (GPX/TCX Import): vollständig verifiziert — alle Parser, Tests, Doku repo-wahr ✅
- Prompt 3 (Map Matching + Dynamic Island): nicht repo-wahr nachweisbar — als offen dokumentiert ⚠️
- README Import-Abschnitt nachgezogen
- NEXT_STEPS Wiederanlauf-Plan für Prompt 3 erstellt

## [Unreleased] – 2026-04-12

### Feature: Multi-Source Import Foundation (GPX + TCX)

- **GPX import**: `GPXImportParser` parses GPX 1.1 XML (`<trk>/<trkseg>/<trkpt>` + `<wpt>`) into `AppExport`. Waypoints become Visit entries. Groups points into days by local calendar date (`.autoupdatingCurrent` timezone).
- **TCX import**: `TCXImportParser` parses TCX 2.0 XML (`<TrainingCenterDatabase>/<Activity>/<Lap>/<Track>/<Trackpoint>/<Position>`) into `AppExport`. Groups by local date.
- **AppContentLoader routing**: `decodeData()` detects GPX/TCX before JSON paths. ZIP scanning also looks for `.gpx`/`.tcx` entries when no LH2GPX or Google Timeline JSON is found.
- **fileImporter UTTypes**: `AppShellRootView.fileImporter` now accepts `.gpx` and `.tcx` in addition to `.json` and `.zip`.
- **Localization**: 7 new strings in `AppGermanTranslations`: "GPX file", "TCX file", "GPS Exchange Format", "Training Center XML", "GPX imported", "TCX imported", "File contains no track points".
- **Error messages**: `unsupportedFormat` and `jsonNotFoundInZip` error descriptions updated to mention GPX/TCX.
- **Fixtures**: `sample_import.gpx`, `sample_import.tcx`, `sample_import_empty.gpx` added to `Fixtures/contract/`.
- **Tests**: 19 new tests in `MultiSourceImportTests` covering parse correctness, fixture round-trips, edge cases, detection, AppContentLoader routing, data flow into `daySummaries()` + `insights()`, and regression tests for Google Timeline + LH2GPX. Total: 530 tests, 0 failures.
- **Deliberately NOT implemented**: FIT format (no maintainable Swift library without external dependency); GeoJSON import (complex edge cases — follow-up).
- **Protected (Prompt-1)**: `HistoryDateRangeFilter`, `AppInsightsContentView`, `AppContentSplitView`, `AppOverviewTracksMapView`, `AppDayListView`, `AppHeatmapView`, `OverviewFavoritesAndInsightsTests` — all untouched.

### Feature: Overview, Insights & Heatmap UI Polish (Tasks 1–10)

- **Task 1 – Time-range first**: `AppContentSplitView.overviewPaneContent` reordered so `AppHistoryDateRangeControl` appears at the very top of the overview pane
- **Task 2 – Favorites toggle**: New Capsule-style "Favorites Only / All Days" button appears below the time-range control when at least one day is favorited; state is held in `overviewShowOnlyFavorites`; `overviewFilteredDaySummaries` feeds the map and the summary stats
- **Task 3 – Overview tracks map**: New `AppOverviewTracksMapView` (iOS 17+) loads all polylines off-main-thread via `Task.detached`; reactive reload via `.task(id:)`; caps at 100 days; shows loading / empty states; embedded in overview pane
- **Task 4 – Heatmap chip styling**: Mode and Radius pickers replaced from `.pickerStyle(.segmented)` with custom `HStack<Button>` using Capsule clip shape + accent/secondary background — matches `AppDayFilterChipsView` exactly; controls wrapped in `ScrollView` for landscape usability
- **Tasks 5/8 – Stray bullet removed**: `AppDayRow` no longer renders a second `Text("No data")` beside the tray `Label`; the orphaned visual point in day list and Insights is gone
- **Task 6 – Top-days limit 20**: `InsightsTopDaysPresentation.topDays(from:by:limit:)` called with `limit: 20` in `AppInsightsContentView`; was previously hard-coded 5
- **Task 7a – Date-range timezone fix**: `HistoryDateRangeFilter.isoFormatter` now uses `.autoupdatingCurrent` instead of UTC; eliminates off-by-one day-boundary errors for users outside UTC
- **Task 7b – Insights metric state shift**: `refreshDerivedModel()` collects all proposed metric values first, then applies them atomically via `withTransaction(Transaction(animation: nil))` to prevent sequential re-renders and visible button shifts
- **Task 9 – German localization**: ~30 new DE strings in `AppGermanTranslations` covering "Favorites Only", "All Days", "No tracks in selected range", "Loading map…", "Computing heatmap…", Insights period-comparison messages, streak no-data message, accessibility labels, ranked-day metric labels, and several previously-untranslated strings
- **Task 10 – Landscape (partial)**: Heatmap control overlay wrapped in `ScrollView(.vertical)` with `maxHeight: 260` to prevent clipping in landscape
- **Tests**: New `OverviewFavoritesAndInsightsTests` (14 cases) covers favorites-filter state, local-timezone correctness of `fromDateString`/`toDateString`, top-days limit=20, German translations for all new keys, and English identity invariant; total test count 511, 0 failures

### Fix: Live Background Authorization Start Gate

- `LiveLocationFeatureModel`: Startfluss fuer Live-Recording als kleine Zustandsmaschine abgesichert (`idle`, `requestingWhenInUse`, `awaitingAlwaysUpgrade`, `readyToStart`, `recording`, `failedAuthorization`)
- `recorder.start()` und `client.startUpdatingLocation()` laufen bei aktivierter Hintergrundaufzeichnung jetzt erst, nachdem das `Always Allow`-Upgrade tatsaechlich aufgeloest wurde
- fehlgeschlagene `Always Allow`-Erweiterung bleibt nicht mehr im irrefuehrenden Pending-Zustand; die UI zeigt jetzt einen expliziten `Background Access Required`-Fehlerzustand
- mehrfaches Start-Triggern waehrend Pending/Recording fuehrt nicht mehr zu doppeltem Start
- `LiveLocationFeatureModelTests`: 5 neue Regressionstests fuer wartenden Start, erfolgreichen Upgrade-Pfad, denied/restricted ohne Start, doppeltes Triggern und Permission-Prompt-Failure
- Repo-Truth: die Deep-Audit-Race-Condition rund um `requestAlwaysAuthorization()` und `recorder.start()` war real und ist jetzt gezielt eingegrenzt behoben
- Nachweis: `swift test --filter LiveLocationFeatureModelTests` → `Executed 22 tests, with 0 failures (0 unexpected)`

### Test: Google Timeline Timezone / DST Verification

- `GoogleTimelineConverter`: Timezone-/DST-Audit-Vermutung gezielt verifiziert; keine Produktionslogik geändert
- Parsing verifiziert für ISO8601 mit `Z`, `+01:00` und `+02:00`; keine doppelte Offset-Anwendung nachweisbar
- UTC-Day-Grouping an lokalen Tagesgrenzen verifiziert: lokale `23:xx`/`00:xx`-Übergänge bleiben korrekt auf dem absoluten UTC-Tag gruppiert
- `timelinePath`-Punktzeiten über DST-Vorwärts- und DST-Rückwärtswechsel verifiziert; Offsets werden als absolute Zeit korrekt fortgeschrieben
- Downstream-Prüfung bestätigt: `AppExportQueries.daySummaries` und `AppExportQueries.insights` bleiben bei Google-Timeline-Imports auf denselben UTC-Day-Keys stabil
- 6 neue deterministische Tests in `GoogleTimelineConverterTests`: Zulu-Timestamp, `+01:00`, `+02:00`, DST vorwärts, DST rückwärts, Tagesgrenze mit nachgelagerten Queries/Insights
- Repo-Truth: Deep-Audit-Annahme einer möglichen Google-Timeline-Timezone-/DST-Schwäche ist durch Tests widerlegt
- Nachweis: `swift test` → `Executed 492 tests, with 0 failures (0 unexpected)`

### Fix: P1 Critical Security + Stability Fixes

- `LiveLocationServerUploadConfiguration.defaultTestEndpointURLString`: war bereits `""` (kein Default-Server); URL-Validierung erzwingt HTTPS (localhost erlaubt HTTP) — kein echtes User-Data-Risiko durch versehentlichen Upload
- `KeychainHelper.KeychainError`: neuer Case `encodingFailed` hinzugefügt; force-unwrap `value.data(using: .utf8)!` durch `guard let data = ... else { throw .encodingFailed }` ersetzt
- `AppExportQueries.effectiveDistance(for:day:)`: Logik von konfuser `guard pathDistance <= 0 else` auf explizites `if pathDistance > 0 { return }` umgestellt; Kommentar dokumentiert die Fallback-Hierarchie (pathDistance bevorzugt wenn > 0, sonst Aktivitätssumme)
- `GeoJSONBuilder`: neuer `GeoJSONBuildError.serializationFailed` (mit `LocalizedError`); `build()` ist jetzt `throws` statt silent fallback auf leere FeatureCollection; `AppExportView` fängt den Fehler im `do-catch`-Block ab und zeigt eine lokalisierbare Fehlermeldung
- `LiveLocationServerUploaderTests.MockURLProtocol.startLoading()`: liest `httpBodyStream` wenn `httpBody` nil ist (Apple-Platform-Fix: URLSession konvertiert POST-Body intern zu Stream); behebt pre-existing macOS-Crash in `testUploadEncodesBodyAsJSON`
- 9 neue Tests: `testEffectiveDistanceFallsBackToActivityDistanceWhenPathDistanceIsZero`, `testEffectiveDistancePrefersPathDistanceOverActivityDistance`, `testBuildEmptyDaysProducesValidFeatureCollection`, `testSaveAndRetrieveRoundTrip`, `testSaveEmptyStringRoundTrip`, `testEncodingFailedErrorCaseExists`
- Linux + macOS Nachweis: `swift test` → `Executed 481 tests, with 0 failures (0 unexpected)`; `git diff --check` sauber

## [Unreleased] – 2026-04-03

### Fix: Live-Settings Time Gap Bounds

- `RecordingIntervalPreference`: Untergrenze jetzt `0` statt `1`; `0` wird als `No minimum` modelliert und deaktiviert das harte Zeit-Gate sauber
- `RecordingIntervalPreference`: keine obere Clamp mehr; große Werte bleiben erhalten und die UI behandelt die Obergrenze explizit als `Unlimited`
- `AppOptionsView`: Live-Settings zeigen jetzt `Minimum Time Gap` als editierbare Einstellung mit `No minimum`-Anzeige für `0` plus separater `Maximum Time Gap: Unlimited`-Zeile
- `AppOptionsView`: die missverständliche Read-only-Zeile `Minimum Time Gap (from Detail)` entfällt; Footer erklärt jetzt klar die Rollen von Mindestabstand, unbegrenzter Obergrenze und `Recording Detail`
- `AppLanguageSupport`: neue DE-Texte für `Maximum Time Gap`, `No minimum`, `Unlimited` und die überarbeitete Live-Settings-Erklärung
- `RecordingIntervalPreferenceTests`: Grenzwert- und Anzeige-Tests auf `0`/`Unlimited` umgestellt; große Werte werden nicht mehr numerisch begrenzt
- `AppPreferences`: geladene `recordingInterval`-Werte werden beim Start jetzt validiert, damit ungültige persistierte Altwerte keine negativen Mindestabstände einschleusen
- `AppPreferencesTests`: Persistenz für `0` (`No minimum`), negative Altwerte und große Werte ohne obere Begrenzung ergänzt
- Recorder-/Upload-Semantik bleibt stabil: `minimumRecordingIntervalS == 0` deaktiviert weiter nur das harte Intervall-Gate; Upload-, Persistenz- und Qualitätslogik bleiben ansonsten unverändert

### Fix: Linux URLSession Test Coverage

- `LiveLocationServerUploaderTests.swift` (neu): 9 Tests für `HTTPSLiveLocationServerUploader` — fehlende Unit-Test-Abdeckung des Linux-spezifischen `dataTask`-Continuation-Pfades nachgeliefert
- Ursache: `URLSession.data(for:)` async-Overload ist auf Swift 5.9 Linux (FoundationNetworking) nicht verfügbar (confirmed per Compiler); der vorhandene `#if canImport(FoundationNetworking)`-Workaround war korrekt, aber nie durch Tests abgesichert
- Mock-Strategie: `URLProtocol`-Subklasse mit `URLSessionConfiguration.ephemeral` und lock-geschütztem statischem Handler — funktioniert auf Linux (FoundationNetworking) und Apple-Plattformen ohne echte Netzwerkaufrufe
- Abgedeckte Fälle: POST-Methode, korrekter Endpoint, `Content-Type`-Header, `Authorization: Bearer`-Header, fehlender Auth-Header wenn `bearerToken` nil, JSON-Body, 2xx-Erfolg, 4xx/5xx → `unsuccessfulStatusCode`, Netzwerkfehler-Propagation
- Linux-Nachweis: `swift test` → `Executed 444 tests, with 2 tests skipped and 0 failures (0 unexpected)`; `git diff --check` sauber

### Polish: Overview + Insights UX

- Summary card order: Active Days and Total Distance promoted to top; Days Loaded moved below
- Summary card subtitles: "Route distance with trace fallback" → "Total route distance"; "Across visible days" → "Daily average"; "Months with visible day entries" → "Months with activity"
- Header description shortened: "Overview, Patterns and Breakdowns for your imported history."
- Overview section order: Top Days (drilldown-capable) moved before Activity Streak (aggregated)
- Period Comparison at All-Time: explicit "All Time Selected" empty state card with `allTimeMessage()`; previously showed generic "No Range Active"
- Drilldown indicators unified: `ellipsis.circle` replaced with `chevron.right` in monthly-trend and period-breakdown rows — now matches highlight and top-day cards
- AppLanguageSupport: DE translations for "Total route distance", "Daily average", "Months with activity", "Overview, Patterns…", "All Time Selected", and period comparison messages

### Polish: Insights Presentation States

- Period Comparison: explicit `allTimeMessage()` when All-Time range selected (`"Period comparison is not available for All Time…"`); new `noDataMessage()` for empty periods
- Streak: clearer empty state via `noDataMessage()` — now actionable (`"No activity streak yet. Start recording to build your streak."`)
- TopDays: new `emptyRangeMessage()` for ranges with no recorded routes (`"No days with recorded routes in the selected range."`)
- AppLanguageSupport: DE translations for all three new state strings

### Fix: UX-/Text-Fix für Live-Recording-Settings

- `RecordingIntervalPreference.displayString`: Singular/Plural korrekt und lowercase (`1 second`, `2 seconds`, `1 minute`, `2 Stunden` via DE-Lokalisierung, etc.)
- `RecordingIntervalUnit.singularKey`: neues Property (`"second"` / `"minute"` / `"hour"`) für lowercase-Lokalisierungskeys
- `AppOptionsView` Stepper-Label: kompakteres Format `"Every 5 seconds"` / `"Alle 5 Sekunden"` statt `"Recording Interval: 5 Seconds"`
- `AppLanguageSupport`: neue Keys `"Every"` → `"Alle"` sowie lowercase-Keys `"second"/"seconds"` → `"Sekunde"/"Sekunden"`, `"minute"/"minutes"`, `"hour"/"hours"` (DE)
- `RecordingIntervalPreferenceTests`: displayString-Tests auf lowercase aktualisiert, auf camelCase-Naming umgestellt; neuer Test `testUnitSingularKey`

### Fix: Live-Recording-Settings UX

- `RecordingIntervalPreference.displayString`: korrekte Singular/Plural (1 Second / 2 Seconds etc.) — war bereits implementiert, Verhalten bestätigt
- `RecordingIntervalUnit.singularDisplayName`: neues Property (`"Second"` / `"Minute"` / `"Hour"`) für lokalisierbare Stepper-Labels
- `AppOptionsView` Stepper-Label: nutzt jetzt `singularDisplayName` wenn `value == 1` → korrekte Singular/Plural-Darstellung im UI
- `AppOptionsView`: `"Minimum Time Gap"` → `"Minimum Time Gap (from Detail)"` mit Footer-Hinweis, dass dieser Wert aus der Aufzeichnungsdetail-Einstellung stammt, nicht aus dem Aufnahmeintervall
- `AppLanguageSupport`: neue DE-Singular-Keys (`"Second"` → `"Sekunde"`, `"Minute"` → `"Minute"`, `"Hour"` → `"Stunde"`) sowie DE-Übersetzungen für neue Footer-Strings
- `RecordingIntervalPreferenceTests`: neuer Test `testUnitSingularDisplayName` für alle drei Einheiten

### Feature: Konfigurierbarer GPS-Aufnahmeintervall für Live-Recording

- `RecordingIntervalPreference.swift` (neu): `RecordingIntervalUnit` (`.seconds`/`.minutes`/`.hours`; `Codable`, `CaseIterable`, `Identifiable`, `Sendable`) und `RecordingIntervalPreference` (`Codable`, `Equatable`, `Sendable`) modellieren einen absoluten Mindest-Zeitabstand zwischen akzeptierten GPS-Punkten; `static .default` = 5 s; `static func validated(value:unit:)` klemmt auf gültige Einheits-Grenzen (s: 1–3600, min: 1–60, h: 1–24); `totalSeconds: TimeInterval`; `displayString: String` (EN, Singular/Plural)
- `LiveTrackRecorder.swift`: `LiveTrackRecorderConfiguration` um `minimumRecordingIntervalS: TimeInterval` (default `0` = kein Gate) erweitert; `append(_:)` verwirft Punkte wenn `timeDelta < minimumRecordingIntervalS > 0` – absolutes Zeit-Gate unabhängig von Distanz
- `AppPreferences.swift`: neues `@Published var recordingInterval: RecordingIntervalPreference`; UserDefaults-Key `"app.preferences.recordingInterval"` (JSON-encoded); `liveTrackRecorderConfiguration` übergibt `minimumRecordingIntervalS: recordingInterval.totalSeconds`; `reset()` setzt auf `.default` zurück
- `AppOptionsView.swift`: neue `Stepper` + `Picker`-Zeilen im Abschnitt „Live Recording" erlauben Wert und Einheit des Intervalls inline anzupassen; Footer erklärt Auswirkung auf Punktanzahl / Akku / Upload
- `AppLanguageSupport.swift`: neue DE-Keys: `"Recording Interval"`, `"Interval Unit"`, `"Seconds"`, `"Minutes"`, `"Hours"`, Hinweistext
- `RecordingIntervalPreferenceTests.swift` (neu): 21 Tests — Default, `totalSeconds` für alle Einheiten, Validation/Clamping, Codable-Roundtrip, Equality, `CaseIterable`, `Identifiable`, `displayString` Singular/Plural
- `LiveTrackRecorderTests.swift`: 3 neue Tests für `minimumRecordingIntervalS`-Gate (rejects early, accepts after interval, zero disables gate)
- `AppPreferencesTests.swift`: Default- und StoredValues-Tests prüfen `recordingInterval` und `minimumRecordingIntervalS`; Reset prüft Rückkehr auf `.default`
- Linux-Nachweis: `swift test` → `Executed 447 tests, with 0 failures (0 unexpected)` ✅; `xcodebuild test` → `Executed 447 tests, with 0 failures (0 unexpected)` ✅



### Feature Batch Phase B – New Insights, Charts und Export-Erweiterung

- `InsightsStreakPresentation.swift` (neu): `InsightsStreakStat` und `InsightsStreakPresentation.streak(from:)` berechnen Longest- und Recent-Streak sowie Active/Total-Day-Counts rein aus `[DaySummary]` ohne View-Logik; `sectionHint(dayCount:)` und `noDataMessage()` liefern saubere Empty-States
- `InsightsPeriodComparisonPresentation.swift` (neu): `InsightsPeriodComparisonStat` / `InsightsPeriodComparisonItem`; `comparison(currentSummaries:allSummaries:rangeFilter:)` vergleicht aktiven Zeitraum mit gleich langem Vorperiod aus ungefilterter Basis; `deltaText(current:prior:)` und `isPositiveDelta(current:prior:)` fuer Delta-Darstellung; `sectionHint()` / `noRangeMessage()` fuer Empty-States
- `ChartShareHelper.swift`: `InsightsCardType` um `.streak` und `.periodComparison` erweitert; bestehende `ChartShareHelper.payload(for:dateRange:)` unterstuetzt neue Typen automatisch; Dateiname-Format konsistent
- `AppInsightsContentView.swift`: neues Init-Argument `allDaySummaries: [DaySummary] = []` fuer Vorperiod-Basis; `InsightsDerivedModel` ergaenzt um `streakStat` und `periodComparisonStat`; `refreshDerivedModel()` berechnet beide neu; `onChange(of: rangeFilter)` ergaenzt damit Period-Comparison bei Range-Aenderung aktualisiert wird; `buildSummaryCards` erhaelt neue Karte `Active Days` (aktive vs. geladene Tage); neue Sektionen: `streakSection` in Overview-Tab, `periodComparisonSection` in Patterns-Tab mit Side-by-side Vergleichsrows (Prior | Current | Delta); `streakCard`- und `periodComparisonRow`-Hilfsviews eingefuehrt
- `AppContentSplitView.swift`: `AppInsightsContentView`-Aufruf ergaenzt um `allDaySummaries: session.daySummaries`
- `InsightsStreakPresentationTests.swift` (neu): 10 Tests — Empty-Input, alle-inaktiv, Einzeltag, volle Sequenz, Gap-bricht-Streak, inaktive-in-Range-bricht-Streak, Recent-vs-Longest, Active/Total-Counts, Section-Hint-Schwelle, unsortierte-Eingabe
- `InsightsPeriodComparisonPresentationTests.swift` (neu): 12 Tests — kein Range → nil, last7d-Range, leere Vorperiod, Delta-Text-Faelle (+/-/0/kein-Prior/Infinity), isPositiveDelta-Faelle, Aggregations-Genauigkeit, Static-Messages
- `ChartShareHelperTests.swift`: 3 neue Tests fuer `.streak` und `.periodComparison` Filename/Title-Format; bestehender `testAllCardTypesProduceNonEmptyPayloads` deckt neue Typen automatisch ab
- Linux-Nachweis: `swift test` → `Executed 398 tests, with 2 tests skipped and 0 failures (0 unexpected)`; `git diff --check` sauber

### Feature Batch Phase A – Days Range Filter + Insights Map Drilldown

- `AppContentSplitView.swift`: `drilldownDaySummaries` basiert jetzt auf `projectedDaySummaries` statt `session.daySummaries`; damit respektiert die `Days`-Tab-Liste denselben globalen Zeitraumfilter wie `Overview`, `Insights` und `Export` — keine separate Range-Logik fuer Days
- `AppContentSplitView.swift`: `HistoryDateRangeFilterBar` wird im kompakten Days-Tab als sichtbarer Section-Header eingeblendet, wenn ein Zeitraumfilter aktiv ist; im regulaeren Split-View als Toolbar-Item
- `AppContentSplitView.swift`: Empty-State in der kompakten Days-Liste hat jetzt eine Variante fuer aktiven Zeitraumfilter ohne Treffer (`"No Days in Range"` + Hinweis zum Aendern des Filters)
- `AppContentSplitView.swift`: `showDayOnMap`-Drilldown navigiert direkt in den Day-Detail-View (mit inline `AppDayMapView`) und setzt Navigation-Path bzw. Selektion
- `AppDayListView.swift`: neuer optionaler Parameter `isRangeFilterActive: Bool` (default `false`) steuert den Empty-State-Headline und die -Message, wenn keine Tage im gewaehlten Zeitraum liegen
- `InsightsDrilldown.swift`: neuer `InsightsDrilldownAction.showDayOnMap(String)` fuer Drilldowns mit echtem raeumlichem Datenbezug; neue Factory `InsightsDrilldownTarget.showDayOnMap(_:)` mit Map-Icon; `drilldownTargets(for:)` liefert jetzt drei Targets: `showDay`, `showDayOnMap`, `exportDay` — ohne Fake-Kartenziele fuer aggregierte Werte
- `InsightsDrilldownBridge.swift`: `dayListAction`, `exportAction`, `filteredSummaries`, `prefillDates` und `description` vollstaendig exhaustiv fuer den neuen `.showDayOnMap`-Fall; `filteredSummaries` filtert auf den genannten Einzeltag; `description` liefert lokalisierte Beschreibungen auf Deutsch/Englisch
- `UIWiringTests.swift`: `testDrilldownTargetsForDateProducesShowAndExport` → `testDrilldownTargetsForDateProducesShowMapAndExport`; erwartet jetzt 3 Targets; 10 neue Tests fuer Phase-A-Range-Wiring und Map-Drilldown
- `InsightsDrilldownBridgeTests.swift`: 2 neue Tests fuer `showDayOnMap`-Beschreibung (Deutsch/Englisch) und Bridge-Filterung auf Einzeltag
- Linux-Nachweis: `swift test` → `Executed 370 tests, with 2 tests skipped and 0 failures (0 unexpected)`; `git diff --check` sauber

### Linux URLSession Build Fix + UIWiringTests WIP Integration

- `LiveLocationServerUploader.swift`: `HTTPSLiveLocationServerUploader.upload(request:to:bearerToken:)` nutzte `URLSession.data(for:)` (async overload), der auf Linux (Swift 5.9 / FoundationNetworking) nicht verfuegbar ist; ersetzt durch `withCheckedThrowingContinuation` ueber `dataTask(with:completionHandler:)` hinter `#if canImport(FoundationNetworking)`, sodass Apple-Plattformen weiterhin den nativen async-Pfad verwenden
- `InsightsDrilldown.swift`: fehlende statische Factory `drilldownTargets(for:)` ergaenzt; liefert `[showDay(date), exportDay(date)]` und vervollstaendigt damit den vorhandenen Factory-Satz fuer datenverankerte Drilldown-Targets
- `UIWiringTests.swift` (bisher untracked WIP): Testerwartungen fuer `ExportSelectionState.toggleRoute` korrigiert; die einfache Ueberladung (ohne `availableRouteIndices`) verwendet ein Inklusionsmodell (erster Aufruf fuegt den Index explizit hinzu, zweiter entfernt ihn); `testEffectiveRouteIndicesReturnsSubsetAfterToggle` nutzt jetzt korrekt die `availableRouteIndices`-Ueberladung fuer Deselektions-Semantik; UIWiringTests.swift ist ab diesem Commit in der versionierten Testliste enthalten
- Linux-Nachweis: `swift test` → `Executed 359 tests, with 2 tests skipped and 0 failures (0 unexpected)`; `git diff --check` sauber

### Device Runtime Verification – Background-Recording + Upload E2E

- **Background-Recording auf echtem iPhone verifiziert**: Permission-Upgrade auf `Always Allow`, Aufnahme im Hintergrund und Stop-/Persistenzverhalten auf iPhone 15 Pro Max real geprüft und bestätigt (2026-04-02); Feature ist funktional vollständig verifiziert auf echtem Gerät
- **Upload-End-to-End zum eigenen Server auf echtem iPhone verifiziert**: optionaler nutzergesteuerter HTTPS-Upload an eigenen Server auf echtem Gerät durchgelaufen und bestätigt (2026-04-02); HTTPS-Erzwingung, Bearer-Token und Queue-Verhalten im realen Betrieb bestätigt
- Doku-Sync: `docs/APPLE_VERIFICATION_CHECKLIST.md`, `NEXT_STEPS.md`, `docs/PRIVACY_MANIFEST_SCOPE.md` und `README.md` auf verifizierten Stand gebracht

### Apple Device Verification – Mac / Xcode / iPhone (post-performance-fix)

- Wrapper `ContentView.swift`: deterministischer Launch-Reset fuer UI-Tests via `LH2GPX_UI_TESTING` + `LH2GPX_RESET_PERSISTENCE` Launch-Arguments; `prepareLaunchStateIfNeeded()` loescht ImportBookmarkStore, RecentFilesStore und AppPreferences vor dem Test-Lauf; `restoreBookmarkedFile()` nutzt jetzt `AppImportStateBridge.restoreLastImportIfEnabled` statt rohem `ImportBookmarkStore.restore()`
- `LH2GPXWrapperUITestsLaunchTests.swift`: `testLaunch` prueft nach sauberem Reset auf `Load Demo Data`-Erscheinen; Launch-Arguments werden gesetzt
- `LH2GPXWrapperUITests.swift`: neuer `testDeviceSmokeNavigationAndActions`-Test laeuft auf echtem iPhone durch: Demo-Load, Overview/Heatmap, Insights/Share, Export/fileExporter, Live/Start+Stop-Recording; portrait-Lock, scroll-robuste Elementsuche (`revealElement`), Predicate-Matches fuer kombinierte Button-Label, koordinatenbasierter Zellen-Tap fuer Export-Selektion (SwiftUI-TabView-Cell-Limitation), Location-Permission-Handling
- `AppExportView.swift`: `accessibilityIdentifier("export.days.selectAll")` / `"export.days.deselectAll"` auf Days-Section-Header-Buttons; `accessibilityIdentifier("export.action.primary")` auf Export-Action-Button; `accessibilityIdentifier("export.day.row")` auf Day-Rows (fuer kuenftige XCUI-Nutzung)
- Mac-Build, iOS-Build, iOS-Archiv, 363 Package-Tests: alle gruen auf Apple-Host (Xcode 26.3)
- Device-Smoke auf iPhone 15 Pro Max (iOS 26.3): PASSED — Heatmap-Sheet, ImageRenderer-Share, fileExporter, Live-Recording real verifiziert

## [Unreleased] – 2026-04-01

### Performance / Stability Phase 3 – Heatmap / Map / Day Detail / Truth Sync

- `AppHeatmapView.swift`: Heatmap-First-Open weiter entschärft; Route-Grids und vorbereitete Route-Tracks werden jetzt einmalig vorgezogen, waehrend Dichte-LODs erst bei echtem Wechsel in den Dichte-Modus lazy nachgerechnet werden statt immer schon beim Oeffnen des Sheets
- `AppHeatmapView.swift`: Route-Viewport-Wechsel traversieren nicht mehr jedes Mal den kompletten `AppExport`; vorbereitete Route-Tracks mit Bounding Box, Render-Koordinaten und gesampelten Midpoints reduzieren wiederholte Materialisierung und Scoring-Arbeit fuer grosse Kartenflaechen
- `AppSessionState.swift`, `AppContentSplitView.swift`, `AppDayDetailView.swift`: Day-Detail nutzt jetzt gecachte `DayMapData` aus der Session-Projektionsschicht statt die Kartenbasis bei jedem Render erneut aus dem Day-Detail-Modell aufzubauen
- `AppDayMapView.swift`, `AppExportPreviewMapView.swift`: Day- und Export-Maps halten stabile Renderdaten fuer Marker, Polylines und Regionen und bauen `CLLocationCoordinate2D`-Arrays nur noch bei echten Input-Aenderungen statt pro Body-Render neu auf
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`, `DemoSessionStateTests.swift`: neue Regressionen decken vorbereitete Heatmap-Route-Tracks sowie gecachte Day-Map-Projektion ab
- Linux-Nachweis fuer diesen Batch: `swift test` -> `Executed 363 tests, with 0 failures (0 unexpected)`; `git diff --check` sauber

### UI Wiring Phase 3 – Insights Drilldown / Chart Share

- `AppInsightsContentView.swift`, `AppContentSplitView.swift`, `AppDayListView.swift`, `AppExportView.swift`, `InsightsDrilldownBridge.swift`: der vorhandene `InsightsDrilldown`-Unterbau ist jetzt sichtbar in der echten App-UI verdrahtet; datenverankerte Highlights, `Top Days`, Distanz-Zeitreihe sowie Monats-/Periodenbereiche bieten jetzt einen echten Drilldown nach `Days` oder `Export`, inklusive sichtbarem und ruecksetzbarem Drilldown-Zustand in den Zielansichten
- `AppSessionState.swift`: aktiver Insights-Drilldown wird bei neuem Import, Start-Ladevorgang und `Clear` sauber zurueckgesetzt statt ueber Session-Wechsel zu leaken
- `AppInsightsContentView.swift`: sichtbare Share-Aktionen fuer die wichtigsten Insight-Sektionen nutzen den vorhandenen `ChartShareHelper`; auf Apple-Hosts wird per `ImageRenderer` eine PNG-Datei fuer den System-Share-Flow erzeugt, waehrend Linux-seitig nur Verdrahtung und Tests verifizierbar sind
- `InsightsChartSupport.swift`, `InsightsTopDaysPresentation.swift`: sichtbare Hinweistexte spiegeln jetzt korrekt den neuen Drilldown-Flow statt direkte Einzeltag-Navigation
- `AppLanguageSupport.swift`: neue sichtbare UI-Texte fuer Drilldown-Banner, Reset, Share-Flow und Chart-Share-Failures auf Deutsch/Englisch lokalisiert
- `Tests/LocationHistoryConsumerTests/InsightsDrilldownBridgeTests.swift`, `DemoSessionStateTests.swift`, `InsightsChartSupportTests.swift`, `InsightsTopDaysPresentationTests.swift`: neue und angepasste Tests decken Datumsbereichs-Mapping, Zieltrennung Days/Export, lokalisierte Drilldown-Beschreibung, Session-Reset sowie die neuen Drilldown-Hints ab
- Linux-Nachweis fuer diesen Batch: `swift test` -> `Executed 359 tests, with 0 failures (0 unexpected)`

### UI Wiring Phase 2 – Days / Day Detail / CSV Export

- `AppContentSplitView.swift`, `AppDayListView.swift`, `DayListPresentation.swift`, `AppDaySearch.swift`: der vorhandene `DayListFilter` ist jetzt sichtbar in der echten `Days`-Liste verdrahtet; Filterchips fuer `Favorites`, `Has Visits`, `Has Routes`, `Has Distance` und `Exportable` kombinieren sich sauber mit Suche und newest-first Sortierung, inklusive sauberem Empty-State bei 0 Treffern
- `AppContentSplitView.swift`, `AppDayListView.swift`, `AppDayDetailView.swift`: `DayFavoritesStore` ist jetzt sichtbar in Liste und Day Detail angebunden; Favoriten koennen per Swipe, Kontextmenue und Day-Detail-Action umgeschaltet werden und bleiben lokal persistent
- `AppDayDetailView.swift`, `ExportSelectionState.swift`, `ExportSelectionContent.swift`: die vorhandene per-route Auswahl ist jetzt real im Day Detail benutzbar; explizite Routen-Subsets bleiben rueckwaertskompatibel zu implizit allen exportierbaren Routen und fliessen in Export-Snapshot und Summary ein
- `AppExportView.swift`, `GPXDocument.swift`: `CSV` ist jetzt als echtes sichtbares Exportformat im bestehenden `fileExporter`-Flow verdrahtet; Disabled-Reasons, Summary, Dateiname und Distanzsumme respektieren Zeitraum, Day-Selection und explizite Route-Selektionen korrekt
- `AppLanguageSupport.swift`: neue sichtbare UI-Texte fuer Days-Filterchips, Favoriten, Route-Export und CSV-Hinweise auf Deutsch/Englisch lokalisiert
- `Tests/LocationHistoryConsumerTests/DayListPresentationTests.swift`, `ExportSelectionRouteTests.swift`, `ExportSelectionContentTests.swift`, `ExportPresentationTests.swift`: neue und erweiterte Tests decken Day-Filter/Search/newest-first, Favoriten-/Chip-Zusammenspiel, per-route Exportprojektion und CSV-Export-Verdrahtung ab
- Linux-Nachweis fuer diesen Batch: `swift test` -> `Executed 350 tests, with 0 failures (0 unexpected)`

### UI Wiring Phase 1 – Range / Recent Files / Auto-Restore

- `AppContentSplitView.swift`, `AppInsightsContentView.swift`, `AppExportView.swift`, `AppHistoryDateRangeControl.swift`, `AppHistoryDateRangeQueryBridge.swift`: der vorhandene `HistoryDateRangeFilter` ist jetzt sichtbar in `Overview`, `Insights` und `Export` verdrahtet; Presets, Custom-Range-Sheet, lokalisierte Anzeige und Reset auf Gesamtzeitraum nutzen den bestehenden Unterbau statt neuer View-Logik
- `AppExportView.swift`: Export projiziert den aktiven globalen Zeitraum jetzt vor lokalen Exportfiltern, zeigt den Zusammenhang sichtbar in der UI und exportiert `CSV` wieder korrekt ueber den bestehenden Export-Flow
- `AppShellRootView.swift`, `AppImportStateBridge.swift`, `ImportBookmarkStore.swift`: Import-Root zeigt jetzt eine echte Recent-Files-Liste mit `Open Again`, Entfernen einzelner Eintraege und `Clear History`; stale oder fehlende Bookmarks werden freundlich behandelt und nicht roh an Nutzer durchgereicht
- `AppOptionsView.swift`, `AppPreferences.swift`, `AppShellRootView.swift`: `Restore Last Import on Launch` ist jetzt als echter Toggle sichtbar; der App-Start bindet die vorhandene Restore-Logik opt-in an und degradiert sauber bei fehlender oder stale Datei
- `AppLanguageSupport.swift`: neue UI-Texte fuer Zeitraumsteuerung, Recent Files und Auto-Restore auf Deutsch/Englisch lokalisiert
- `AppHeatmapView.swift`: bestehende Heatmap-Logik an die tatsachliche Grid-Segmentierung angepasst, damit der verpflichtende Gesamtlauf `swift test` wieder gruen ist
- `Tests/LocationHistoryConsumerTests/AppImportAndHistoryDateRangeBridgeTests.swift`, `AppPreferencesTests.swift`: neue und erweiterte Tests decken Zeitraumprojektion, Import-Historie und Auto-Restore-Verdrahtung ab
- Linux-Nachweis fuer diesen Batch: `swift test` -> `Executed 343 tests, with 0 failures (0 unexpected)`

### Feature Batch – Range / Insights / Export / Import-Comfort / Days-Polish

**9 neue Features in 3 Phasen:**

#### Phase A – Range + Import-Comfort
1. **Globaler Zeitraumfilter** (`HistoryDateRangeFilter.swift`): Presets (7 d / 30 d / 90 d / dieses Jahr / Custom) + Validator; shared State in `AppSessionState.historyDateRangeFilter`; `fromDateString`/`toDateString` für `AppExportQueryFilter`-Integration; `chipLabel` für UI-Chip
2. **Recent Files / Import-Historie** (`RecentFilesStore.swift`): bis zu 10 Einträge (neueste zuerst), Deduplizierung, Stale-Prüfung, Migration von altem `lastImportedFileBookmark`-Key; `add/remove/clear/resolveURL`
3. **Auto-Restore als Option** (`AppPreferences.autoRestoreLastImport`): neuer Key `app.preferences.autoRestoreLastImport`, Default `false`; in `AppPreferences.reset()` bereinigt

#### Phase B – Export + Day-Level Power Features
4. **Per-Route Auswahl im Day Detail** (`ExportSelectionState`): `routeSelections: [String: Set<Int>]`; `toggleRoute/clearRouteSelection/isRouteSelected/effectiveRouteIndices`; `clearAll()` räumt Route-Selections mit auf; `hasExplicitRouteSelection`/`explicitRouteSelectionCount` für Summary
5. **CSV-Export** (`CSVBuilder.swift`, `CSVDocument.swift`): Header (16 Felder), Zeilen für Visit/Activity/Route/Empty-Day; RFC 4180 Escaping; `ExportFormat.csv` mit `.tablecells` Icon; `CSVDocument` als SwiftUI FileDocument
6. **Days-Filterchips** (`DayListFilter.swift`): `DayListFilterChip` (favorites/hasVisits/hasRoutes/hasDistance/exportable); `DayListFilter` mit AND-Logik; `passes(summary:isFavorited:)`
7. **Favoriten/Pinning** (`DayFavoritesStore.swift`): `add/remove/toggle/contains/clear` via UserDefaults; Key `app.dayFavorites`

#### Phase C – Insights Drilldown + Chart Share
8. **Insights-Drilldown** (`InsightsDrilldown.swift`): `InsightsDrilldownAction` (filterDays/filterDaysToDate/filterDaysToDateRange/prefillExportForDate/prefillExportForDateRange); `InsightsDrilldownTarget` mit Factory-Helpers; `AppSessionState.activeDrilldownFilter`
9. **Chart Share Helper** (`ChartShareHelper.swift`): `ChartSharePayload` + `InsightsCardType`; Dateiname-Format `LocationHistory_Insights_<type>_[<range>_]<date>.png`; UI-frei, testbar; Hinweis: ImageRenderer nur auf Apple-Host

**Tests:** 8 neue Test-Files (316 Tests, 2 Skips, 0 Failures)

## 2026-04-01

### DE Localisation – Analytics / Insights / Overview / Custom-Range (Truth-Sync aus iOS)

Diese Einträge dokumentieren die Localisation-Arbeit, die im historischen Split-Repo `LocationHistory2GPX-iOS` auf `main` gemergt wurde. Der Core-Code liegt im Monorepo-Root; die Commits wurden dort auf `main` entwickelt und sind hier zur Vollständigkeit festgehalten.

- `AppLanguageSupport.swift`: DE-Übersetzungen für Analytics-Preset-Chips, Range-Description-Keys, alle KPI-Labels und KPI-Notes, Custom-Date-Range-Sheet-Strings, Overlap-Map-Strings, Filter-Picker-Labels, Map-Meldungen und Empty/Sparse-States ergänzt; 3 Duplikat-Schlüssel beseitigt (verhinderten RuntimeFatal); alle 309 Tests grün, 2 Skips, 0 Failures
- `AppCustomDateRangeSheet.swift`: `@EnvironmentObject preferences` ergänzt; alle 9 user-facing Strings über `preferences.localized(_:)` – kein EN-Hardcode mehr
- `AppOverlapMapView.swift`: alle UI-Strings (map-style-switch, exportierbare-Routen-Hinweis, No-Route-Geometry, Tag/Track-Zähler-Chips) über privaten `t(_:)`-Helper

### DE Localisation Finish – Format-Strings + Monatsnamen

- `CustomDateRangeValidator.chipLabel(from:to:)`: neuer optionaler `locale`-Parameter (Default `.current`); Monatsnamen via `DateFormatter.shortMonthSymbols` statt hardkodiertem EN-Array; Tests übergeben `locale: Locale(identifier: "en_US")` für stabile Assertions
- `AppInsightsContentView`: fünf EN-Hardcodes ersetzt – `"of N total"`, `"N events"`, EN-Wochentagsnamen-Dictionary und `"N day/days"` über `t()` bzw. `localizedWeekdayName(_:)`; alle 309 Tests grün, 2 Skips, 0 Failures

### DE Localisation Final – rangeDescription Composite Strings

- `AppLanguagePreference.localized(_:pluralFmt:count:)`: neue Hilfsmethode für Singular/Plural-Format-Keys; 14 neue DE Format-String-Einträge für alle `rangeDescription`-Presets; Singular/Plural je Preset korrekt abgedeckt
- `AnalyticsDateRangeBuilder.rangeDescription(_:activeDays:)`: optionaler `language`-Parameter (Default `.english`); alle Preset-Fälle nutzen Format-String-Lookup mit korrekter Singular/Plural-Logik; kein hardkodierter `day`/`days`-Suffix mehr
- `OverviewPresentation.rangeKPIs(from:range:language:)`: reicht `language` an `rangeDescription` weiter; `rangeNote` ab Erzeugung lokalisiert
- `AppInsightsContentView`: alle drei `rangeKPIs`-Aufrufe mit `language: preferences.appLanguage`; `"active"` und `"%.0f%% active days"` über `t()` lokalisiert
- 10 neue Tests (EN/DE, Singular/Plural, alle Presets, Default-Language-Guard); alle 319 Tests grün, 2 Skips, 0 Failures

### InsightsChartSupport rangeNote Format-String Refactor + DE Localisation

- `InsightsChartSupport.distanceSectionMessage`, `.monthlyTrendSectionHint` und `.weekdaySectionHint`: je ein optionaler `language`-Parameter (Default `.english`); Basis-Strings und `"Showing %@."`-Suffix durch Format-String-Lookup statt EN-Hardcode
- `AppInsightsContentView`: alle drei Aufrufstellen auf `language: preferences.appLanguage` umgestellt; `t()`-Wrapper entfernt (Methoden liefern fertig lokalisierte Strings)
- `AppGermanTranslations.values`: `"Showing %@."` → `"Zeige %@."` ergänzt
- 6 neue Tests (EN/DE, mit/ohne rangeNote, alle drei Methoden); alle 325 Tests grün, 2 Skips, 0 Failures

## 2026-03-31

### Monorepo Truth-Sync Docs

- `AGENTS.md`: Zwei-Repo-Architektur-Block auf Monorepo-Architektur aktualisiert; veralteter SPM-Pfad `../../../Code/LocationHistory2GPX-iOS` entfernt; Core-Root und `wrapper/`-Verzeichnis als die zwei primaeren Bestandteile dokumentiert; historische Split-Repos als weiterbestehend eingeordnet
- Split-Repos `LocationHistory2GPX-iOS` und `LH2GPXWrapper` erhalten Monorepo-Verweise in README und AGENTS.md

### Monorepo-Migration + Testendpunkt-Bereinigung

- `wrapper/` via `git subtree` als Teil des Monorepos eingefuehrt; `LH2GPXWrapper` lebt jetzt unter `wrapper/` im Monorepo-Root
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: lokale SPM-Referenz von `../LocationHistory2GPX-iOS` auf `../..` (Monorepo-Root) umgestellt
- `wrapper/.github/workflows/xcode-test.yml`: separater Core-Clone entfernt, Pfad auf `-project wrapper/LH2GPXWrapper.xcodeproj` aktualisiert
- `wrapper/README.md`, `wrapper/docs/LOCAL_IPHONE_RUNBOOK.md`, `wrapper/docs/TESTFLIGHT_RUNBOOK.md`: alle `xcodebuild`-Pfade und Verzeichniswechsel auf Monorepo-Layout aktualisiert
- `Sources/LocationHistoryConsumerAppSupport/LiveLocationServerUploader.swift`: hart kodierter Testendpunkt `https://178-104-51-78.sslip.io/live-location` entfernt; `defaultTestEndpointURLString` ist jetzt `""` (kein Produktstandard-Testserver)
- `Sources/LocationHistoryConsumerAppSupport/AppOptionsView.swift`: `LabeledContent("Test Endpoint", ...)` und dazugehoeriger Footer-Hinweis auf den Testserver entfernt
- `Sources/LocationHistoryConsumerAppSupport/AppLanguageSupport.swift`: veraltete Uebersetzungen fuer `"Test Endpoint"` und den sslip.io-Footer-Hinweis entfernt; neuer kompakter Footer-String ergaenzt
- `swift test`: `228` Tests, `2` Skips, `0` Failures

### 4-Repo Status Documentation

- README-Rolle des Repos von zu kleinem Consumer-/Demo-Wording auf den realen Stand als eigentliche iOS-Produkt-UI korrigiert
- offener Produktpunkt fuer den hart kodierten Testendpunkt in `Sources/LocationHistoryConsumerAppSupport/LiveLocationServerUploader.swift` jetzt explizit in README, `NEXT_STEPS.md` und neuem Status-Audit dokumentiert; keine Code-Aenderung
- neue timestamped Status-/Audit-Dateien `audits/AUDIT_IOS_STATE_2026-03-31_08-48.md` und `audits/AUDIT_4REPO_MASTER_2026-03-31_08-48.md` halten den aktuellen Repo- und Cross-Repo-Stand repo-wahr fest

### Repo-Truth Deep Audit / Doc Sync

- repo-weite Deep-Audit-Synchronisierung gegen den tatsaechlichen Stand von Code, Tests und Host-Umgebung; veraltete Testzahlen in den aktuellen Truth-Bloecken auf den frischen Linux-Nachweis `228` Tests, `2` Skips, `0` Failures umgestellt
- historische Apple-/Xcode-/Device-Nachweise vom 2026-03-17 und 2026-03-30 explizit als historische Nachweise markiert; fuer den aktuellen Audit-Host wird jetzt klar festgehalten, dass `xcodebuild` auf diesem Linux-Server nicht verfuegbar ist
- `README.md`, `ROADMAP.md`, `NEXT_STEPS.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/CONTRACT.md`, `docs/XCODE_APP_PREPARATION.md` und `docs/XCODE_RUNBOOK.md` repo-wahr auf `offline-first + optionaler nutzergesteuerter Upload`, offene Apple-Verifikation und aktuelle Audit-Grenzen geglaettet

## 2026-03-31

### Insights Distance Hotfix + Patterns / Breakdowns Quick Batch

- `Sources/LocationHistoryConsumer/Queries/AppExportQueries.swift`: `Gesamtstrecke` und `Durchschnittsstrecke / Tag` im Insights-Stack jetzt repo-wahr aus importierten Routendistanzen berechnet; wenn diese fehlen, faellt die Aggregation gezielt auf vorhandene Pfadgeometrie (`points` / `flatCoordinates`) und erst danach auf belastbare Aktivitaets-Trace-Geometrie zurueck statt auf `0 m`
- `Sources/LocationHistoryConsumerAppSupport/AppInsightsContentView.swift`, `InsightsChartSupport.swift`: `Patterns` und `Breakdowns` um umschaltbare Wochentags- und Periodenmetriken fuer Ereignisse, Routen und Distanz erweitert; Hinweise und Achsenbeschriftungen erklaeren den jeweils sichtbaren Datenkontext
- `Tests/LocationHistoryConsumerTests/AppExportQueriesTests.swift`, `InsightsChartSupportTests.swift`: gezielte Regressionstests fuer Distanz-Fallback, Durchschnittsstrecke/Tag sowie neue Wochentags-/Periodenmetriken ergaenzt

## 2026-03-30

### UI Polish + Heatmap Detail Visibility Batch 2

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Detailansicht der Dichte-Heatmap nochmals sichtbar farbiger gemacht; fruehere Hue-Wechsel schon bei niedriger Dichte, detail-LOD-spezifisches Color-Position-Mapping, niedrigere Sichtbarkeitsschwellen fuer `medium`/`high` und etwas staerkere Sparse-Opacity ohne Architektur- oder Performance-Umbau
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Dichte-Legende an den frueheren Low-/Mid-Farbverlauf angepasst, damit Regler und sichtbare Heatmap wieder besser zusammenpassen
- `Sources/LocationHistoryConsumerAppSupport/AppLiveTrackingView.swift`, `AppInsightsContentView.swift`, `AppDayListView.swift`: kleiner Surface-Polish fuer Card-Chrome, Section-Hierarchie und Day-Row-Balance; bewusst ohne neue Grossbaustelle
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: Erwartungen fuer staerkere Low-/Mid-Lift und detail-LOD-spezifisches Farb-Mapping nachgeschaerft; auf diesem Linux-Server bleiben diese Apple-only Tests weiterhin korrekt ausgeklammert

### UI Polish + Heatmap Detail Visibility Batch

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Detailzoom der Dichte-Heatmap sichtbar staerker gemacht; niedrigere Sichtbarkeitsschwellen, kraeftigeres Low-/Mid-Intensity-Mapping, detailzoom-spezifischer Opacity-Boost, feinere Farbwirkung schon bei seltener Dichte und leicht angehobene Default-Deckkraft
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Heatmap-Legende an die sichtbarere Detaildarstellung angepasst; Slider-/Opacity-Verhalten bleibt weiter zur effektiven Darstellung passend
- `Sources/LocationHistoryConsumerAppSupport/AppLiveTrackingView.swift`: kleiner UI-Polish fuer Live-Tracking-Card-Hierarchie und Quick-Action-Wrapping auf engeren Breiten
- `Sources/LocationHistoryConsumerAppSupport/AppInsightsContentView.swift`: Insights-Sektionen mit klarerer Card-Hierarchie und ruhigerem Section-Chrome
- `Sources/LocationHistoryConsumerAppSupport/AppDayListView.swift`: Day-Row-Abstaende und no-content-/Export-Zustaende visuell leicht geglaettet
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: Heatmap-Erwartungen fuer die staerkere Detailsichtbarkeit nachgeschaerft; auf diesem Linux-Server bleiben diese Tests wegen Apple-Gating weiterhin nicht direkt ausfuehrbar

### Sync + Live / Upload / Insights / Days Batch

- `Sources/LocationHistoryConsumerAppSupport/AppLiveTrackingView.swift`: Live-Seite visuell und funktional neu aufgebaut; neue Kartenhierarchie fuer Map, Recording, Upload, Track-Library und Advanced-Optionen sowie klarere Status-Chips und Quick Actions
- `Sources/LocationHistoryConsumerAppSupport/LiveTrackingPresentation.swift`: neue abgeleitete Live-Metriken fuer aktuelle Geschwindigkeit, Durchschnittsgeschwindigkeit, letzte Teilstrecke, Update-Alter, Dauer und Distanz
- `Sources/LocationHistoryConsumerAppSupport/LiveLocationFeatureModel.swift`: Upload-Domain ausgebaut um Pause/Resume, manuellen Flush, Queue-/Failure-/Last-Success-Status, robustere Statuszusammenfassungen und Assistive-Messages fuer invaliden Endpunkt, fehlenden Bearer-Token, pausierte Uploads und Retry-Zustaende
- `Sources/LocationHistoryConsumerAppSupport/AppInsightsContentView.swift`: Insights-Seite stark ausgebaut mit segmentierten Oberflaechen (`Overview`, `Patterns`, `Breakdowns`), KPI-Karten, Highlight-Karten, `Top Days`-Picker und neuen Monatstrends
- `Sources/LocationHistoryConsumerAppSupport/InsightsMonthlyTrendPresentation.swift`: neue Monatsaggregation fuer Distanz-, Event-, Aktivitaets- und Visit-Trends
- `Sources/LocationHistoryConsumerAppSupport/DaySummaryDisplayOrdering.swift`, `AppDayListView.swift`, `AppSessionState.swift`: Day-Liste und initiale Tagesauswahl jetzt repo-wahr standardmaessig absteigend (`neu -> alt`) statt aelteste zuerst
- `Sources/LocationHistoryConsumerAppSupport/AppLanguageSupport.swift`: DE/EN-Abdeckung fuer neue Live-/Upload-/Insights- und Days-UI erweitert
- neue/erweiterte gezielte Tests fuer Live-, Upload-, Insight- und Day-Sortierlogik; Linux-Server-Checks fuer `swift test --filter Live`, `Insight`, `Day` und `Upload` in diesem Batch gruen

### Linux Test Portability

- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: Apple-only Heatmap-Renderingstests jetzt hinter `#if canImport(SwiftUI) && canImport(MapKit)`, damit non-Apple-`swift test` nicht mehr an fehlenden UI-Frameworks scheitert
- aktueller Linux-Server-Check: `swift test` wieder gruen mit `217` ausgefuehrten Tests, `2` Skips und `0` Failures

### Heatmap Hotfix Batch 7

- `AppHeatmapMode.swift`: Picker-Labels auf Deutsch umgestellt (`Routes` → `Routen`, `Density` → `Dichte`)
- `AppHeatmapView.swift`: `RoutePathExtractor` neu — verarbeitet jeden GPS-Track als ganzes Polyline statt fester 200-Punkte-Chunks; Intensitaet wird durch Sampling von bis zu 30 Bins entlang des gesamten Tracks bestimmt (Blend aus Max und Durchschnitt); radiale Artefakte / Stern-Optik damit behoben
- `AppHeatmapView.swift`: Downsampling langer Tracks auf max 500 Punkte fuer Render-Performance statt chunkbasierter Aufteilung
- `AppHeatmapView.swift`: `routeSelectionLimit` reduziert (macro 150→60, low 400→150, medium 800→300, high 1200→500) — Limits passten zu Chunks, nicht zu ganzen Tracks
- `AppHeatmapView.swift`: Density-Mode feiner — `overlayOpacityMultiplier` fuer medium (0.62→0.72) und high (0.78→0.86) erhoeht; `minimumNormalizedIntensity` fuer medium (0.025→0.018) und high (0.015→0.010) gesenkt; `selectionLimit` fuer medium (160→240) und high (280→400) erhoeht; LOD-Schwelle low→medium von 1.4°→1.0° vorgezogen
- `AppHeatmapView.swift`: `remappedControlOpacity` auf lineares Mapping vereinfacht (0.15–1.0 Slider → 0.22–1.0 effektiv) — Regler-Verhalten und Anzeige stimmen jetzt nachvollziehbar ueberein
- `AppHeatmapView.swift`: Slider-Range von 0.35–1.0 auf 0.15–1.0 erweitert; Startwert von 0.7 auf 0.8 angehoben

### Route Heatmap Visual Rebuild Batch 6

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: neuer `RoutePathExtractor` — extrahiert vollstaendige, zusammenhaengende Koordinatensequenzen direkt aus `paths.flatCoordinates`, `paths.points` und `activities.flatCoordinates`; zerlegt grosse Tracks in max-200-Punkt-Chunks (mit 1-Punkt-Ueberlapp fuer Kontinuitaet); weist jedem Chunk Korridorintensitaet per Grid-Lookup zu
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: neues `RoutePath`-Struct (id, coordinates, normalizedIntensity, coreLineWidth, glowLineWidth = 3× coreWidth, color) ersetzt die kurzstreckigen Bin-Diagonalen im Route-Mode
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: zweischichtiges Glow-Rendering im Route-Mode — Layer 1: breite, halbtransparente Bloom-Underlayer (Opazitaet 0.08–0.38); Layer 2: schmale, helle Kernlinie (Opazitaet 0.22–0.96); ergibt weichen Leuchteffekt analog Strava/Komoot-Heatmaps
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: `RoutePalette` von Cyan-Gruen auf Indigo→Cyan→Weiss/Warmgelb umgestellt — tiefes Indigo (selten) über Cyan (mittel) zu weissem Warmton (haeufig); optimiert fuer dunklen Kartenhintergrund
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Dark Map fuer Route-Mode — `MapStyle.imagery()` (Satellitenkarte) wenn im Route-Mode und kein Hybrid-Pref gesetzt; Density-Mode behaelt `.standard()`; liefert maximalen Kontrast fuer leuchtende Linien
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Viewport-Culling und LOD-basiertes Limit (routeSelectionLimit) auf `RoutePathExtractor` uebertragen; `routePathCache` als separater Cache analog `routeViewportCache`
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: `testRoutePaletteIsClearlyDistinctFromDensityPalette` an neues Indigo-Weiss-Schema angeglichen (prueft jetzt Rot-Komponente am unteren Ende und Gruen/Blau am oberen Ende statt Gruen-Dominanz)
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: 2 neue Tests — `testRoutePathExtractorProducesConnectedSequencesFromPaths` (mindestens ein Pfad mit ≥2 Coords aus Path-Daten) und `testRoutePathExtractorGlowWidthIsThreeCoreWidth` (glowLineWidth === 3× coreLineWidth fuer alle Paths)

### Route Heatmap + Heatmap Polish Batch 5

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: neuer `HeatmapMode`-Enum (`.route` / `.density`) — Standardmodus beim Oeffnen ist `.route`
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Segmented Picker "Routes / Density" im Bottom-Control-Panel; Radius-Picker nur im Density-Modus sichtbar; separate Legende je Modus
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: `RouteGridBuilder` — bricht `paths.flatCoordinates`, `paths.points` und `activities.flatCoordinates` in konsekutive Segmente auf, binnt Segmentmittelpunkte in LOD-abhaengige Grid-Zellen, zaehlt Durchlaeufe pro Zelle; vier LOD-Stufen mit eigenen `routeSegmentStep`-Werten (macro 0.08° / low 0.025° / medium 0.006° / high 0.0018°)
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Route-Heatmap rendert als `MapPolyline` mit variabler Linienbreite (1.5–7 pt) und `RoutePalette` (Cyan→Teal→Gruen→Gelbgruen→Orange→Rot-Orange); klar unterscheidbar von der blauen Dichte-Palette
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: `AppHeatmapModel` berechnet Dichte- und Routen-Grids parallel in derselben `Task.detached`-Vorberechnung; separate Viewport-Caches fuer beide Modi
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: `RouteViewportKey` fuer LOD-/Viewport-Caching der Route-Segmente analog zur bestehenden `HeatmapViewportKey`-Strategie
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: 8 neue Tests — HeatmapMode-Enum, RouteGridBuilder (Segmente aus Paths, Koernung, leerer Export, Viewport-Culling, Linienbreite vs. Intensitaet) und Palette-Unterscheidbarkeit Route vs. Dichte

## 2026-03-30

### Heatmap Fine Detail / Zoom Tuning Batch 4

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: LOD-Grid-Schritte fuer mittlere und hohe Zoom-Stufen verfeinert (medium: 0.018→0.012, high: 0.004→0.003) — weniger blockartige Grossflaechen, mehr Granularitaet bei Feinzoom
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: LOD-Umschaltschwellen frueher gesetzt (low→medium bei spanDelta>1.4 statt >1.6; medium→high bei >0.12 statt >0.16) — feinere Darstellung setzt bei weiterer Herausgezoomtheit ein
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: selectionLimit fuer medium (132→160) und high (220→280) angehoben — mehr sichtbare Zellen bei Feinzoom ohne macro-Limit zu beruehren
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: minimumNormalizedIntensity fuer low (0.06→0.04), medium (0.035→0.025) und high (0.02→0.015) gesenkt — schwache Dichtebereiche bleiben sichtbar und fallen nicht weg
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: displayIntensity-Kurve angepasst (Exponent 0.58 statt 0.72) — untere Intensitaetsstufen werden sichtbarer angehoben ohne Rauschen zu dominieren
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: effectiveOpacity-Emphasis-Basis leicht angehoben (0.82 statt 0.72) und Mindestopacity auf 0.06 gesetzt — niedrige Dichte bleibt dezent sichtbar statt zu verschwinden
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Farbpalette geschaerft: kuehles Blau minimal saettiger, Cyan/Gruen-Mitte ausgepraegterer Charakter, Orange/Rot-Hochbereich kraftvoller und sauberer; Legende an neue Palette angeglichen

### Heatmap Color / Contrast / Opacity Batch 3

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Heatmap-Farb- und Deckkraftwirkung deutlich verstaerkt, ohne den Polygon-/LOD-/Viewport-Renderer aus Batch 2 zurueckzubauen; 100 % im Deckkraft-Slider mappt jetzt ueber eine nichtlineare Kennlinie auf sichtbar vollere Darstellung
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Intensitaets-Mapping fuer mittlere und hohe Dichten angehoben, damit Hotspots staerker tragen und mittlere Dichte nicht zu stark absauft
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Farbskala von groben Stufen auf weich interpolierte Gradient-Stops mit staerkerem Warmbereich fuer hohe Dichte umgestellt; Legende an dieselbe Palette angeglichen
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: kleine Logiktests fuer Intensitaets-Lift, High-End-Opacity-Mapping und waermer werdende Palette hinzugefuegt
- `README.md`, `ROADMAP.md`, `NEXT_STEPS.md`, `docs/APP_FEATURE_INVENTORY.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_RUNBOOK.md`: Batch-3-Farb-/Kontrast-Update und der weiterhin offene Apple-Device-Nachweis repo-wahr nachgezogen

### Heatmap Visual & Performance Batch 2

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Heatmap-Renderer von sichtbar ueberlappenden Kreis-Stempeln auf geglaettete, aggregierte Polygon-Zellen umgestellt; LOD-abhaengige Zellgroessen, ruhigere Farb-/Deckkraftabstufung und weniger flaechiges Uebermalen bei mittleren/grossen Zoomstufen
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: viewport-basierte Zellselektion mit per-LOD gecappten sichtbaren Elementen und wiederverwendbarem Viewport-Cache eingebaut, um Renderlast und Rebuilds beim Zoomen/Pannen zu reduzieren
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: vorhandene Heatmap-Controls aus Batch 1 beibehalten und den Radius-Preset an den neuen Polygon-Renderer angebunden, damit die Darstellung weiter direkt steuerbar bleibt
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: kleine Render-/LOD-Regressionstests fuer grobere Aggregation und viewport-/limit-respektierende Zellselektion hinzugefuegt
- `README.md`, `ROADMAP.md`, `NEXT_STEPS.md`, `docs/APP_FEATURE_INVENTORY.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_RUNBOOK.md`: Heatmap-Rendering-/Performance-Strategie und der weiterhin offene Apple-Device-Nachweis repo-wahr nachgezogen

### Heatmap UX Batch 1

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Heatmap-Darstellung auf mittleren und grossen Zoomstufen sichtbar entschärft; LOD-abhaengige Radius-/Deckkraft-Abstufung, weniger dominante Flaechenwirkung und `fit-to-data`-Startzustand aus den vorhandenen Punktgrenzen
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: kleines Bottom-Control-Panel mit Deckkraft-Regler, Radius-Presets, `Auf Daten zoomen` und unaufdringlicher Dichte-Legende hinzugefuegt; Header bleibt ueber die Sheet-Navigation kompakter
- `Sources/LocationHistoryConsumerAppSupport/AppLanguageSupport.swift`: neue Heatmap-UX-Strings fuer Deutsch/Englisch ergaenzt
- `README.md`, `ROADMAP.md`, `NEXT_STEPS.md`, `docs/APP_FEATURE_INVENTORY.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_RUNBOOK.md`: Heatmap-UX-Umfang repo-wahr nachgezogen, ohne den noch offenen Apple-Device-Nachweis des Sheets als erledigt zu markieren

### Apple Device Verification Batch 1

- `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_RUNBOOK.md`, `NEXT_STEPS.md`: echter iPhone-15-Pro-Max-Lauf (iOS 26.3) repo-wahr nachgezogen
- reale Wrapper-UI-Automation auf dem verbundenen iPhone per `xcodebuild test -allowProvisioningUpdates` erneut belegt
- `LH2GPXWrapperUITestsLaunchTests.testLaunch` lief auf dem echten iPhone erfolgreich durch; der Wrapper startet auf aktueller Hardware stabil
- der fehlgeschlagene Screenshot-Test lieferte einen verwertbaren Device-Befund statt eines leeren Infra-Fehlers: beim Start war bereits eine importierte `location-history.zip` wiederhergestellt, `Heatmap` war als Aktion sichtbar und der dedizierte `Live`-Tab lag in der Tab-Bar vor
- Background-Recording, aktives Oeffnen des Heatmap-Sheets, aktive `Live`-Tab-Interaktion und End-to-End-Upload bleiben trotz dieser Teilbefunde offen

### Apple Stabilization Batch 2

- `Tests/LocationHistoryConsumerTests/AppPreferencesTests.swift`: Test-Setup an Apple-Realitaet angeglichen – Bearer-Token wird fuer `testStoredValuesAreLoaded` ueber den Keychain-Pfad gesetzt; Keychain wird in `setUp`/`tearDown` explizit bereinigt
- `Tests/LocationHistoryConsumerTests/DayDetailPresentationTests.swift`: Erwartung fuer `timeRange` auf den im Produktcode konsistent verwendeten Gedankenstrich `" – "` angepasst
- `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_RUNBOOK.md`, `NEXT_STEPS.md`, `README.md`, `ROADMAP.md`: Apple-CLI-Stand nach erneuter Verifikation auf gruen nachgezogen; offene Device-End-to-End-Themen bewusst offen gelassen

### Apple Stabilization Batch 1

- `AppOptionsView.swift`: `.textInputAutocapitalization(.never)` in `#if os(iOS)`-Guard eingeschlossen – iOS-only API war auf macOS ein Compile-Fehler
- `AppContentSplitView.swift`: `if #available(iOS 17.0, macOS 14.0, *)` statt `if #available(iOS 17.0, *)` fuer `AppLiveTrackingView` – fehlender macOS-Teil verhinderte macOS-Build
- `AppDayDetailView.swift`: `if #available(iOS 17.0, macOS 14.0, *)` statt `if #available(iOS 17.0, *)` fuer `AppLiveLocationSection` – gleiche Ursache
- `Sources/LocationHistoryConsumerDemo/RootView.swift`: `loadImportedFile(at:)` als `async` markiert und mit `Task { await ... }` aufgerufen – fehlte nach async-Aenderung in `DemoDataLoader.loadImportedContent`
- `Sources/LocationHistoryConsumerApp/AppShellRootView.swift`: analog zu RootView.swift – `loadImportedFile(at:)` async gemacht und Aufruf per `Task { await ... }` korrigiert
- `LiveLocationFeatureModelTests.swift`: `minimumBatchSize: 1` explizit in Upload-Test-Konfiguration gesetzt – Default ist 5, Tests prueften 1-Punkt-Upload (Test-Drift, kein Produktfehler)
- `LiveLocationFeatureModelTests.swift`: `testBackgroundPreferenceActivatesClientWhenAlwaysAuthorized` auf korrektes Produktverhalten angepasst – Client-Background-Konfiguration wird erst beim Recording-Start gesetzt, nicht bei blosser Preference-Aenderung (Test-Drift)
- `docs/APPLE_VERIFICATION_CHECKLIST.md`: ehrlicher Stand nach Apple Stabilization Batch 1 dokumentiert – CLI-Build/Test-Ergebnisse eingetragen, Einschraenkungen klar benannt
- `README.md`: "offline-only" in Beschreibung der App-Shell auf "offline-first, optionaler Upload" korrigiert – interner Widerspruch behoben
- README, ROADMAP, NEXT_STEPS und Xcode-Runbooks nach erneutem Apple-CLI-Rerun nachgeschaerft – Wrapper-Simulator-Tests als gruen eingetragen, die 2 verbleibenden roten macOS-/SwiftPM-Tests explizit offengelassen statt als "plattformbedingt" zu markieren

### Heatmap Compiler- und Diagnostik-Fixes
- `AppHeatmapView.body` in `mapView`- und `calculatingOverlay`-`@ViewBuilder`-Properties aufgeteilt, um Compiler-Timeout zu beheben
- `.blendMode(.plusLighter)` von `ForEach` (MapContent) auf den `Map`-View selbst verschoben
- `CLLocationCoordinate2D: @retroactive Equatable`-Extension ergaenzt, damit `.onChange(of: model.initialCenter)` kompiliert

### Audit Fix / Roadmap Granularization
- Audit `audits/AUDIT_LH2GPX_2026-03-30_09-11.md` gesichert und gegen den aktuellen Repo-Stand abgeglichen
- README, ROADMAP, NEXT_STEPS, Feature-Inventar und Apple-Runbooks auf Heatmap, `Live`-Tab, Upload-Batching, Wrapper-Auto-Restore und ehrlichen Teststatus synchronisiert
- stray-Dateien `lazygit` und `lazygit.tar.gz` aus dem Core-Repo entfernt und in `.gitignore` aufgenommen

## 2026-03-20

### Heatmap / Live Tab / Upload Batching
- `AppHeatmapView` als eigenes Heatmap-Sheet fuer importierte History auf iOS 17+/macOS 14+ eingebaut
- compact iPhone-Layout erhielt einen dedizierten `Live`-Tab fuer Live-Location und Live-Recording auf iOS 17+
- `AppPreferences` und Live-Upload-Konfiguration unterstuetzen jetzt Upload-Batching (`Every Point`, `Every 5 Points`, `Every 15 Points`, `Every 30 Points`)

### Navigation / Search / Sheet Stability
- `Days`-Suche funktioniert jetzt in compact und regular width und matcht nicht nur ISO-Datum, sondern auch formatiertes Datum, Wochentag und Monat
- iPhone-`Days` reagiert auf erneutes Tab-Selektieren, setzt Suche/Navigationspfad zurueck und springt auf den aktuellen Tag, wenn dieser im Import vorhanden ist
- `AppContentSplitView` nutzt jetzt einen einzigen Sheet-Praesentationszustand fuer Export, Optionen und Saved-Live-Track-Library statt konkurrierender `.sheet`-Ketten am Actions-Menue

### Saved Live Tracks / Local Recording
- Saved-Live-Track-Wording ueber Overview, Day Detail, Library, Sheet-Fallback und Editor vereinheitlicht
- gespeicherte Live-Tracks werden klarer als lokaler Nebenfluss ausserhalb importierter History bezeichnet
- Track-Editor-Titel benennt jetzt konkret das Bearbeiten eines gespeicherten Tracks
- Overview-Primary-Actions, Actions-Menue und Day Detail fuehren jetzt direkt in dieselbe dedizierte `Saved Live Tracks`-Library
- der Live-Recording-Bereich zeigt keinen zweiten halben Library-Flow mehr, sondern verweist gezielt auf die separate Library-Seite
- die Library-Seite selbst zeigt jetzt auch Zusammenfassung und neuesten gespeicherten Track als eigenen lokalen Arbeitsbereich
- Live-Recording hat jetzt echte Optionen fuer Accuracy-Filter und Recording-Detail statt harter Recorder-Defaults
- `AppPreferences` steuern jetzt die Recorder-Konfiguration fuer akzeptierte Genauigkeit, Mindestbewegung und Zeitabstand zwischen Punkten
- geaenderte Live-Recording-Optionen wirken direkt auf den lokalen Recorder-Flow
- Background-Recording kann jetzt lokal in den Optionen aktiviert werden und fordert bei While-In-Use eine `Always Allow`-Erweiterung an
- der Core-iOS-Client kann echte Background-Location-Updates aktivieren, wenn `authorizedAlways` vorhanden ist
- gespeicherte Live-Tracks markieren jetzt auch ihren Capture-Mode fuer Foreground-vs-Background-Aufnahmen
- Live-Recording kann akzeptierte Punkte jetzt optional an einen frei konfigurierbaren HTTP(S)-Server schicken
- der Server-Upload ist nutzerseitig ein-/ausschaltbar, akzeptiert Bearer-Token und nutzt eine Retry-on-next-sample-Strategie bei Fehlern
- der Standard-Testendpunkt ist mit `https://178-104-51-78.sslip.io/live-location` vorbelegt und damit konsistent zur HTTPS-Validierung des Codes
- der Live-Recording-Bereich zeigt jetzt auch einen sichtbaren Upload-Status, wenn der Server-Upload aktiv ist

### Sprache / Lokalisierung
- Optionen bieten jetzt eine Sprachwahl zwischen Englisch und Deutsch
- Shell-, Optionen-, Live-Recording-, Import-Entry- und zentrale Export-Oberflaechen reagieren jetzt auf die Sprachwahl
- Day List, Day Detail, Statuskarten, Saved-Live-Track-Library/-Editor, Karten-Hinweise und grosse Teile von Insights/Export reagieren jetzt ebenfalls auf die Sprachwahl
- noch nicht uebersetzte Strings fallen bewusst auf Englisch zurueck, statt fehlerhafte Platzhalter zu zeigen

### Insights / Empty-State Hardening
- Insights zeigen jetzt explizite Fallbacks fuer no-days-, low-data- und chart-unverfuegbare Faelle statt halbleerer Flaechen
- fehlende Distanz-, Activity-, Visit-, Weekday- und Period-Daten werden pro Sektion erklaert
- Imports mit sehr duennen, aber gueltigen Daten zeigen einen sichtbaren `Limited Insight Data`-Hinweis

### Charts / Export Polish
- Distance-, Activity-, Visit- und Weekday-Charts zeigen explizitere Achsen, Wertehinweise und Erklaertexte
- Export zeigt Auswahlzusammenfassung, Dateinamenvorschau und explizite Disabled-Reasons direkt im Flow
- Tage ohne GPX-faehige Routen werden in der Export-Liste klarer markiert und ausgewaehlte Zeilen deutlicher hervorgehoben
- gespeicherte Live-Tracks koennen jetzt direkt in derselben Exportseite mit ausgewaehlt und als GPX zusammen mit importierten Tagen exportiert werden
- die vorhandene Export-Vorschaukarte ist jetzt im sichtbaren Export-Flow verdrahtet und zeigt die aktuelle Auswahl mit Routen-, Distanz- und Legendenzusammenfassung
- `KML` ist jetzt neben `GPX` als aktives Exportformat in der UI freigeschaltet
- lokale Export-Filter fuer `From`, `To` und `Max accuracy` wirken jetzt sichtbar auf importierte History, Vorschau und den eigentlichen Export
- lokale Export-Filter greifen bewusst nicht auf gespeicherte Live-Tracks durch und raeumen ausgeblendete Tagesselektionen aus dem Exportzustand
- lokale Export-Filter bieten jetzt auch explizite `Has ...`- und `Activity type`-Auswahl fuer importierte History statt nur still vorhandenen Query-Unterbau
- lokale Export-Filter haben jetzt auch eine echte Bounding-Box-/Polygon-UI fuer importierte History; Upstream- und lokale Flaechenfilter werden konservativ kombiniert
- Export-Vorschaukarte zeigt jetzt auch Waypoint-only-Auswahlen statt nur Routen
- `GeoJSON` ist jetzt als drittes aktives Exportformat freigeschaltet
- Export kennt jetzt die Modi `Tracks`, `Waypoints` und `Both`
- Waypoint-Export nutzt importierte Visits sowie Activity-Start/-End-Koordinaten
- Dateiname, Disabled-Reasons und Hilfetexte reagieren jetzt auf den aktiven Exportmodus statt still route-only zu bleiben

### Overview / Days / Day Detail Polish
- Overview startet jetzt mit Status und einer `Primary Actions`-Sektion fuer Open, Days, Insights und Export
- Export-Selektion ist in der Day-Liste sichtbarer und fuehrt ueber einen expliziten Export-Kontext schneller in den Export-Flow
- Day Detail trennt importierte Tagesdaten klarer von lokalem Live Recording und gespeicherten Live-Tracks

## 2026-03-19

### Navigation / Dead-End Hardening
- no-content-Tage bleiben in der Day-Liste sichtbar, werden aber in compact und regular nicht mehr wie normale Detailziele behandelt
- initiale Tagesauswahl bevorzugt jetzt contentful days statt blind den ersten Kalendertag
- Export-Badge in gruppierter und ungruppierter Day-Liste vereinheitlicht

### Lokale Optionen / Produktsteuerung
- lokale Optionen-Seite fuer Distanz-Einheit, Start-Tab, Kartenstil und technische Importdetails eingebaut
- `AppPreferences` als zentrale `UserDefaults`-Domain fuer Core-App und Wrapper verdrahtet
- Distanz-/Speed-Formatierung, Kartenstil, Start-Tab und technische Metadaten folgen denselben Preferences

### Repo-Truth / Dokumentation
- repo-wahres Feature-Inventar ergaenzt und 19.x-Roadmap auf aktuelle lokale Priorisierung bereinigt
- README, ROADMAP und NEXT_STEPS auf den tatsaechlichen Stand von Optionen, Day-Navigation und offenem Fokus synchronisiert

## 2026-03-18

### Export / Recorded Tracks
- GPX-Export mit app-weiter Tagesselektion, Export-Tab/-Sheet und Dateinamenvorschlag eingebaut
- Recorded-Track-Library und Track-Editor fuer gespeicherte Live-Tracks eingefuehrt
- Track-Editor-Zugang in Overview und Live-Recording-Bereich auffindbarer gemacht

### Import Truth Sync
- verbliebene Core-UI-Texte von `app_export`-Spezialfall auf den echten JSON-/ZIP-Import-Scope umgestellt
- ZIP-Fehlermeldungen auf aktuelle Unterstuetzung fuer LH2GPX- und Google-Timeline-Archive korrigiert
- `AGENTS.md`, README und Apple-/Xcode-Doku auf den realen Importstand synchronisiert

### Live Recording MVP
- foreground-only Live-Location fuer die Kartenansicht eingebaut
- manuellen Ein/Aus-Schalter mit sauber modellierten Permission-Zustaenden hinzugefuegt
- Live-Track mit Accuracy-/Dedupe-/Mindestdistanz-Filtern und Polyline-Rendering umgesetzt
- abgeschlossene Live-Tracks getrennt von importierter History in einem dedizierten Store persistiert
- bewusst offen gelassen: Background-Tracking, Auto-Resume von Drafts, Export aufgezeichneter Live-Tracks
