# CHANGELOG

## [Unreleased] – 2026-04-02

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
