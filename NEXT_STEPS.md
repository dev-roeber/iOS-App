# NEXT_STEPS

Stand: 2026-05-06 (Hero-Map-Workspace auf Übersicht/Insights/Export/Live ausgerollt — Tage-Optik; Build 96 nötig vor Submit)

Diese Datei enthaelt bewusst nur offene, priorisierte Arbeit. Abgeschlossene oder rein historische Batches bleiben im `CHANGELOG.md` und in den archivierten Phasen der `ROADMAP.md`.

## P0 — Release / Review / Hardware-Verifikation

- [x] **Review-Response senden (Guideline 3.2)**: gesendet von Sebastian. Apple hat Build 74 nach Review-Response akzeptiert. Status: **Ausstehende Entwicklerfreigabe (Pending Developer Release)**. Guideline 3.2: resolved. (2026-05-05)
- [x] **Build 74 / 1.0-Train abgeschlossen**: Version 1.0 (Build 74) bleibt in „Pending Developer Release" — 1.0-Train ist in ASC geschlossen. Builds 80–83 scheiterten wegen geschlossenem 1.0-Train (ITMS-90186/90062), nicht wegen Code-Fehler.
- [x] **MARKETING_VERSION auf 1.0.1 angehoben** (2026-05-05): `project.pbxproj` alle 8 Konfigurationen auf `1.0.1`; Plists weiterhin via `$(MARKETING_VERSION)`. ASC hat Version `1.0.1` bereits angelegt.
- [x] **Xcode Cloud Build 84 erfolgreich** (2026-05-05): `1.0.1 (84)` — Archive ✅, TestFlight-interne Tests ✅. Erster valider Build für den 1.0.1-Train.
- [ ] **Xcode Cloud Build 96 triggern** (Pflicht vor Submit):
  - Build 95 ist veraltet — enthält weder den compact-controls-Fix noch den Statusbar/flush-Workspace-Fix vom 2026-05-06.
  - Neuester Commit: `fix: keep days map controls below status bar`
  - Xcode Cloud Workflow `Release – Archive & TestFlight` manuell anstoßen.
  - Visuelle Verifikation am echten iPhone 15 Pro Max steht noch aus (App ist installiert + gestartet).
- [ ] **Days-Screenshot (iphone15pm_03) neu aufnehmen**: UITest `testAppStoreScreenshots` auf iPhone 15 Pro Max ausführen — Days-Layout erneut verändert (Control-Clearance, kein schwarzer Gap, kompakter Filter). Neues PNG in `docs/app-store-assets/screenshots/iphone-67/` ablegen.
- [ ] **Version 1.0.1 in App Store Connect finalisieren** (nach neuem Cloud-Build):
  1. ASC → LH2GPX → Vertrieb → iOS-App Version `1.0.1` öffnen
  2. Neuen Build (**≥ 96**, nach diesem Commit) auswählen, speichern — **nicht Build 95 oder früher**
  3. Screenshots prüfen: 6 iPhone-15-Pro-Max-PNGs aus `docs/app-store-assets/screenshots/iphone-67/` hochladen (iphone15pm_01–06, 1290×2796 px)
  4. `Zur Prüfung einreichen` (`Submit for Review`)
  - Runbook: `docs/ASC_SUBMIT_RUNBOOK.md`
- [x] **Neue Screenshots aufnehmen**: UITest `testAppStoreScreenshots` auf iPhone 15 Pro Max ausgeführt → 6 neue PNGs (iphone15pm_01_import bis iphone15pm_06_live_tracking, 1290×2796 px) in `docs/app-store-assets/screenshots/iphone-67/` gespeichert (2026-05-05). Screenshot-Pflichtset auf 6 Top-Level-Flows reduziert: Options (kein Tab) entfernt.
- [x] Support-URL in App Store Connect eingetragen: `https://dev-roeber.github.io/iOS-App/support.html` (2026-04-30)
- [x] Privacy-URL in App Store Connect eingetragen: `https://dev-roeber.github.io/iOS-App/privacy.html` (2026-04-30)
- [x] GitHub Pages fuer `/docs` live und oeffentlich erreichbar (HTTP 200 verifiziert 2026-04-30): `https://dev-roeber.github.io/iOS-App/`, `/support.html`, `/privacy.html`
- [ ] Live Activity / Dynamic Island auf echter Hardware vervollstaendigen: Lock Screen, `minimal`, Fallback bei deaktivierten / nicht verfuegbaren Live Activities, No-Dynamic-Island-Geraet (Pending-/Restart-Pfad jetzt gruen)
- [x] Live Tracking / Live Tracks Library auf echter Apple-Hardware verifiziert: UITest `testDeviceSmokeNavigationAndActions` auf iPhone 15 Pro Max (iOS 26.4) PASSED (2026-05-05); Start/Stop Recording, Live-Tab-Navigation bestätigt
- [x] Days-Tab: Landscape-Verifikation auf echtem Gerät — `testLandscapeLayoutSmoke` auf iPhone 15 Pro Max PASSED (62s), 5 Tabs ohne Crash (2026-05-05); Live-Start-Button Accessibility in Landscape als UITest-Limit dokumentiert
- [ ] Days-Tab: iPad-Verifikation — `regularSplitView` nutzt `daysMapHeaderCard` via `AnyView`, visuell ungeprüft
- [ ] **Hero-Map-Workspace iPad/Landscape-Verifikation**: Compact iPhone vereinheitlicht (commit e11d4d7, 2026-05-06) — Übersicht/Insights/Export/Live nutzen Tage-Hero-Stil. iPad-Regular und Landscape behalten Legacy-Pfade; visuelle Verifikation an realem iPad + iPhone-Landscape steht aus.
- [ ] **Hero-Map-Snapshot-Tests ergänzen**: aktuell nur State/Wiring getestet (`LHMapHeaderTests`, `UIWiringTests`); Layout-Snapshots (Höhen 460/560, Control-Position unter Statusbar, full-bleed Clipping) fehlen.
- [ ] **Cleanup-Follow-up Hero-Map**: `AppDayDetailView.mapControlRow` ist im Portrait toter Code (Landscape-only). Live `mapCard` (Landscape) und `liveHeroMap` (Portrait) duplizieren Map-Rendering — Konsolidierung in shared ViewBuilder.
- [x] **Startseite**: auf iPhone 15 Pro Max verifiziert — Screenshot iphone15pm_01_import erzeugt (2026-05-05)
- [x] **Übersicht**: auf iPhone 15 Pro Max verifiziert — Screenshot iphone15pm_02_overview erzeugt (2026-05-05)
- [x] **Export**: auf iPhone 15 Pro Max verifiziert — Screenshot iphone15pm_04_export_checkout erzeugt (2026-05-05)
- [ ] Performance-Smoke-Test auf echtem iPhone mit grosser realer History (>20 MB, Gesamtzeitraum) fuer Overview-/Explore-Karte dokumentieren

## P1 — Produktverifikation und Ausbau vorhandener Flaechen

- [ ] Chart-Share / ImageRenderer auf Apple-Hardware gezielt verifizieren
- [ ] app-weite Landscape-Verifikation fuer `Overview`, `Days`, `Insights`, `Export`, `Live`
- [ ] Homescreen-Widget auf echter Hardware gezielt verifizieren
- [ ] Track-Editor-Verhalten gegen reale Export-Erwartung entscheiden und dokumentieren: Mutations bleiben derzeit display-only und fliessen bewusst nicht in Exporte ein
- [ ] Wrapper-Simulator-Testlauf fuer `LH2GPXWrapperTests` auf diesem Host stabilisieren oder auf anderem Apple-Host gegentesten (`NSMachErrorDomain Code=-308`)
- [x] **Stop-Ship Bug 1 — Auto-Split Datenverlust** (2026-05-05): `start()` löscht `splitOffTrack` nicht mehr; `handleLocationSamples` draint Split-Track, persistiert ihn als `RecordedTrack` und setzt neue `currentRecordingSessionID`. 4 neue Tests in `LiveTrackRecorderTests`, 2 neue in `LiveLocationFeatureModelTests`.
- [x] **Stop-Ship Bug 2 — Widget Echtdaten** (2026-05-05): `stopRecordingFlow()` und Split-Drain rufen `updateWidgetData()` auf → `WidgetDataStore.save(recording:)` + `saveWeeklyStats()`. `ContentView` reloaded via `WidgetCenter.shared.reloadAllTimelines()` bei `widgetAutoUpdate == true`.
- [x] **Stop-Ship Bug 3 — Widget Family-Switch** (2026-05-05): `LH2GPXWidgetEntryView` mit `@Environment(\.widgetFamily)` → `systemSmall` → `LH2GPXSmallWidgetView`, sonst `LH2GPXMediumWidgetView`.

## P2 — Nachgelagerte Optimierung

- [x] Verifikations-Batch Redesign 1–5B (2026-05-05): swift test 927/0, xcodebuild ✅, CI-Tests ✅, testAppStoreScreenshots Simulator PASSED (7/8 Slots), testDeviceSmokeNavigationAndActions Bugfix (`insights.section.share` → `insights.share.*`)
- [x] Design-System: Live Activity / Dynamic Island / Widget Safety Batch 5B implementiert (2026-05-05); Content-Safety-Review bestanden (keine Koordinaten/Token/URLs im ContentState), `minimalView`-Bug gefixt, 9 neue Safety-Tests, 927 Tests grün
- [x] Design-System: Live-Tracking-Redesign Batch 5A implementiert (2026-05-05); Hero/Status-Card, einklappbarer Diagnostics-Bereich, 7 neue Accessibility-Identifier, 11 neue DE-Strings, 918 Tests grün
- [x] Design-System: Insights-Dashboard-Redesign Batch 4 implementiert (2026-05-05); Hero-Bereich mit Datumsbereich + aktive Tage, verbesserte Leer-Zustände mit Reset-CTA, Sektion-Reihenfolge angepasst (Highlights → Streak → Top Days → Daily Averages)
- [x] Design-System: Export-Checkout-Redesign Batch 3 implementiert (2026-05-05); Export nutzt jetzt klare Review-/Checkout-Struktur mit Auswahlprüfung, Preview-Fallback, Formatwahl, Exportziel und finaler Bottom-Bar-CTA
- [x] Design-System: Live-Tracking-Redesign abgeschlossen (2026-05-01); Live Tracking + Live Tracks Library jetzt im LH2GPX-Dark-Redesign
- [x] Design-System: Options + Widget/Live Settings Redesign abgeschlossen (2026-05-01); alle 8 Sections modular, RecordingPreset-Wiring, Token nur als SecureField, 830 Tests
- [x] Final Truth-Sync: fehlende DE-Strings ergänzt (Invalid URL, Widget & Live Activity, Reachable/Unreachable, Test Connection, Automatic Widget Update etc.), widgetAutoUpdate/maximumRecordingGapSeconds getestet; 832 Tests (2026-05-01)
- [x] Days-Tab: Sticky Map Workspace (LHMapHeaderState.isSticky, daysListStickyHeader, daysExportSelectionBar) — 849 Tests, 0 Failures (2026-05-05)
- [x] App-Store-Screenshot-Aktualisierung: UITest `testAppStoreScreenshots` auf iPhone 15 Pro Max ausgeführt (2026-05-05) → 6 Slots iphone15pm_01–06 in `docs/app-store-assets/screenshots/iphone-67/` (1290×2796 px). Pflichtset auf 6 Flows reduziert (ohne Options-Slot).
- [ ] Widget/Dynamic-Island nur bei sicherem Token-Pfad weiter ausbauen
- [ ] `LHCollapsibleMapHeader` in erste echte Seite einbauen (Kandidat: Insights-Heatmap-Kontext oder Overview-Map); nur wenn Daten sauber verfügbar
- [ ] Apple-Review-/Privacy-Einordnung fuer den optionalen Server-Upload weiter beobachten und nach Review-Feedback repo-wahr nachziehen
- [ ] `docs/NOTION_SYNC_DRAFT.md` nur noch als manuell gepflegten Snapshot nutzen oder spaeter durch einen schlankeren Status-Export ersetzen
- [ ] historische Split-Repos `LocationHistory2GPX-iOS` und `LH2GPXWrapper` konsistent als historisch/mirror markieren
- [ ] echtes Road-/Path-Matching nur als spaeteren separaten Produktentscheid evaluieren; aktueller Stand bleibt bewusst `Simplified` statt Snapping
