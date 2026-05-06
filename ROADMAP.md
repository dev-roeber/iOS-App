# ROADMAP

## Aktiver Stand (2026-05-06, HEAD post-`70254ff`)
- Zentrales Repo: `iOS-App` (dev-roeber/iOS-App)
- Vorstufen: LocationHistory2GPX-Monorepo (historisch), LocationHistory2GPX-iOS (historisch), LH2GPXWrapper (historisch)

### Memory-Safety: Auto-Restore-Schutz gegen Jetsam (2026-05-06, abends)

**Reaktion auf realen Crash:** Xcode meldete auf iPhone 15 Pro Max einen Memory-Issue/Jetsam-Kill für `LH2GPXWrapper` beim App-Start nach Import einer 46 MB Google-Timeline (`location-history.zip`, ~65 k Timeline-Einträge). Auto-Restore re-parste die Datei vollständig im Launch-Pfad mit drei `JSONSerialization`-Vollparses → transienter RAM-Peak ~400–500 MB → Jetsam-fatal.

**Implementiert:**
- Sniffer-basierte Format-Detection (`GoogleTimelineConverter.isGoogleTimeline` + neuer `isJSONObject`) ersetzt drei volle `JSONSerialization`-Parses durch einen 1-KB-Byte-Check.
- Auto-Restore-Größenschutz: konservatives 50-MB-Cap (`AppContentLoader.autoRestoreMaxFileSizeBytes`), neuer Fehler `autoRestoreSkippedLargeFile`, User-Hinweis "Großer Google-Timeline-Import erkannt — bitte manuell importieren". ZIP-Inspektion via Entry-Metadaten ohne Extraktion.
- Query-Fast-Path: `AppExportQueryFilter.isPassthrough` + `AppExportQueries.projectedDays`-Fast-Path schneidet ~80–130 MB transient pro Aufruf auf 65 k-Tage-Imports.
- OverviewMap bounded coordinates: `OverviewMapPathCandidate.fullCoordinates` per `strideDecimate` auf max 512 Punkte gekappt — visuell verlustfrei (Douglas-Peucker läuft trotzdem in `makeOverlay`), spart ~70–90 % residenten RAM bei dichten Tracks.

**Verifikation:** `swift test`: 987 Tests, 2 skipped, 0 failures (vorher 973). 14 neue Tests in `LargeImportMemorySafetyTests`. `xcodebuild` (iPhone 17 Pro Max Sim 26.3.1): BUILD SUCCEEDED. Hardware-Verifikation des Schutzpfads auf realer 46-MB-Datei: pending.

**Ehrlich offen:** Echter Streaming-/Chunked-Google-Timeline-Parser noch nicht umgesetzt. `convert(...)` parst weiterhin in einen Foundation-Baum + re-serialisiert; für manuelle Importe > 50 MB greift kein Schutz, da der User dort bewusst wartet. JSON-Streaming-Parser bleibt in NEXT_STEPS verbleibender Arbeitspunkt.

### Map / Heatmap / Live Next-Level (2026-05-06)

Abgeschlossene Arbeit nach Phase 19.27 / nach dem Hardware-Verifikations-Block 2026-05-05, getrennt nach Feature-Themen:

- **MapLayerMenu (commit `70254ff`)**: alle Map-Layer-Controls auf jeder Map-Surface laufen über ein einziges Right-Side-Dropdown. Ersetzt `LHMapStyleToggleButton` (deprecated), Heatmap-Bottom-Sheet, Capsule-Chip-Cluster, Follow-Pill, Fullscreen-Close-X, standalone Style-/Fit-/Center-Buttons.
- **MapLayerMenu Wiring-Audit-Polish (Doku-Audit 2026-05-06 Abend)**: Day-Map mit `mapPosition`-State + Fit-to-Data, Export-Preview Fit-to-Data, Overview `isFullscreenActive` korrekt verdrahtet, Live-Tracking Landscape-Card nutzt geteilte MapContent-Helpers, Heatmap-Overlay-Pattern vereinheitlicht, tote Parameter (`verticalMapControls`, `showStyleToggle`) entfernt.
- **Heatmap Tier 1 + 2** (commits `e7a2379`, `a2f50bc`, `2e1c928`, `6a7c361`): Lens-Flare entfernt, weichere Kanten, i18n-Fix; pointy-top Hexagon-Polygone; Mercator-Korrektur; cos(lat)-Bin-Aggregation.
- **Heatmap P0 Follow-up Batches** (commits `f5de284`, `bbd9e3b`, `50b4c58`, `825a3de`): sane defaults für Streetzoom, weniger Burnout.
- **Heatmap Next-Level** (commit `9118ac6`): Magma/Inferno-Paletten, Log-Scale, Soft-Glow-Cells.
- **Routes-Modus aus Heatmap entfernt** (commit `fc3ccc5`): Density-only.
- **Maps next-level** (commit `ab054c7`): Tempolayer (Speed-Coloring), Halo-Strokes, Live-Polish.
- **Home-Screen Lightning-Background** (commit `fa006cd`).
- **SIGABRT-Defensivguards** (commit `74300a6`): defensive Patterns gegen Crash beim Live-Tracking-Launch.
- **Demo-Fixture-Swap** (commit `b1d65cb`): bundled Demo ist jetzt ein realer LH2GPX-Track (Oldenburg → Dänemark).
- **Build-Number-Bump** (commit `8854eef`): `CURRENT_PROJECT_VERSION = 100` lokal gesetzt; Xcode Cloud Build ≥100 als naechster ASC-Submit-Kandidat.

Frische Verifikation (2026-05-06 nach Doku-/Wiring-Audit):
- `swift test`: `964` Tests, `2` Skips, `0` Failures.
- `xcodebuild -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.3.1' build`: BUILD SUCCEEDED.
- iPhone-15-Pro-Max-Hardware-Verifikation für diesen kombinierten Stand: offen (letzte Hardware-Acceptance war 2026-05-05 vor Hero-Map-Rollout).

### Hardware-Verifikation iPhone 15 Pro Max (2026-05-05)

Ausgefuehrt auf: iPhone 15 Pro Max (UDID 00008130-00163D0A0461401C, iOS 26.4)

Implementiert und verifiziert:
- **swift test**: 927 Tests, 0 Failures ✅
- **xcodebuild** (iPhone 15 Pro Max): BUILD SUCCEEDED ✅
- **testAppStoreScreenshots** (iPhone 15 Pro Max): PASSED (44s) ✅ — 6 neue Screenshots 1290×2796
- **testDeviceSmokeNavigationAndActions** (iPhone 15 Pro Max): PASSED (70s) ✅
  - Demo-Load, Overview/All-Time, Heatmap, Insights-Share, Export fileExporter, Live Start/Stop ✅
- **Screenshot-Pflichtset**: 6 Slots (Option 1 — ohne Options-Tab), Dateinamen `iphone15pm_01–06_*.png`
- **UITest vereinfacht**: Slot 07 (Options) und Slot 08 (Day Detail) aus Pflichtset entfernt

Nicht als abgeschlossen markieren:
- Landscape auf allen Tabs: weiter ohne Hardware-Nachweis
- Live Activity / Dynamic Island Batch 5A/5B: Lock Screen, `minimal`, weitere Pfade offen
- Widget auf Homescreen: manuelle Interaktion nötig
- Großer Import-Performance-Test: kein 20MB-Fixture im Repo

### Verifikations-Batch Redesign 1–5B (2026-05-05)

Implementiert und verifiziert:
- **swift test**: 927 Tests, 0 Failures ✅
- **xcodebuild** (generic/platform=iOS + iPhone 17 Pro Max Simulator): BUILD SUCCEEDED ✅
- **CI-Tests** (iPhone 17 Pro Max Simulator, testPlan CI): TEST SUCCEEDED ✅
- **testAppStoreScreenshots** (iPhone 17 Pro Max Simulator): PASSED — 7/8 Screenshots ✅
- **Bugfix UITest**: `insights.section.share` → `insights.share.*` (Identifier-Rename seit Batch 4)
- **Screenshot-Kandidaten** (Simulator): 7 PNGs in `docs/app-store-assets/screenshots/simulator-iphone17promax/`
- **Visuell geprüft** (Simulator): Start, Overview, Days (Sticky Map), Insights (Hero), Export (Checkout), Live (Hero+Diagnostics), Day Detail

### UI/UX Redesign Batch 5B — Live Activity / Dynamic Island / Widget Safety (2026-05-05)

Implementiert und getestet:
- **Content-Safety-Review**: `TrackingStatus` (ContentState), `TrackingAttributes` (statisch) und `WidgetDataStore.LastRecording` enthalten keine Koordinaten, Server-URLs oder Bearer-Token — bestätigt durch Codable-Encoding-Tests und Mirror-Reflexion
- **`minimalView`-Bugfix** (`TrackingLiveActivityWidget.swift`): Tote Bedingung entfernt; Minimal-Icon zeigt nun konsistent `pause.circle.fill` (Pause) oder `location.fill.viewfinder` (aktiv)
- **Dynamic Island (Compact/Expanded/Lock Screen)**: Kein Änderungsbedarf — Inhalte sind bereits auf Statuswerte und Metriken begrenzt; keine sensitiven Felder
- 9 neue Safety-Tests (`LiveActivitySafetyBatch5BTests`), lokaler Nachweis: **927 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- Keine echte iPhone-/Hardware-Verifikation der Live Activity / Dynamic Island
- Keine Lock-Screen-Verifikation auf echter Hardware
- No-Dynamic-Island-Gerät (Pending-/Restart-Pfad) weiter ungeprüft

### UI/UX Redesign Batch 5A — Live Tracking Foundation (2026-05-05)

Implementiert und getestet:
- **Hero/Status-Card** (`heroStatusCard`): Klare Statusanzeige oben im Live-Tracking-Flow; leitet sich aus `isRecording`, `isAwaitingAuthorization` und `authorization` ab — keine neue State-Logik
- **Einklappbarer Diagnostics-Bereich** (`diagnosticsSection`): Alle 8 bestehenden Metriken kollabiert hinter einem Tippen-Trigger; `live.diagnostics.section`-Identifier
- **7 neue Accessibility-Identifier**: `live.status.hero`, `live.map.preview`, `live.recording.primaryAction`, `live.recording.stopAction`, `live.permission.card`, `live.server.status`, `live.diagnostics.section`
- **Token-Masking**: Bearer-Token bleibt in UI auf "Token set" / "No token" reduziert; kein Wert exposed
- 11 neue DE-Strings, lokaler Nachweis: **918 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- Keine echte iPhone-/Hardware-Verifikation
- Keine Landscape-/iPad-Verifikation
- Live Activity / Dynamic Island weiter ungeprüft auf echter Hardware
- Neue App-Store-Screenshots weiter ausstehend
- Server-/Token-Konfiguration funktional unverändert (Scope: nur UI)

### UI/UX Redesign Batch 4 — Insights Dashboard (2026-05-05)

Implementiert und getestet:
- **Hero-Bereich**: `insightsDashboardHero` direkt unter dem Titel — zeigt Datumsbereich und Anzahl aktiver Tage aus repo-wahren Projektionen
- **Verbesserter Leer-Zustand**: `insightsFullEmptyState` mit Two-Path-Logik:
  - Filter aktiv + keine Treffer → kontextueller Hinweis + „Filter zurücksetzen"-Button
  - Keine Daten → statischer Hinweis
- **Overview-Tab Reihenfolge**: Highlights → Activity Streak → Top Days → Daily Averages (Streak prominenter für persönliches Engagement)
- Keine neuen Analyse-Engines, keine Fake-Metriken; alle bestehenden Drilldowns unverändert
- lokaler Nachweis: **897 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- keine neue Insights-Analyse, kein neues Chart-Format
- Insights-Tab visuell noch nicht auf echter Hardware verifiziert

### UI/UX Redesign Batch 3 — Export Checkout (2026-05-05)

Implementiert und getestet:
- Export-Flow in `AppExportView` als klarer Review-/Checkout-Flow neu geordnet: `Review Selection` → `Preview` → `Choose Format` → `What to include` → `Export Destination`
- `Review Selection` zeigt echte Auswahlmetriken aus bestehender Projektion: Tage, Zeitraum, Tracks, Punkte sowie Distanz-/Wegpunkt-/Routen-Badges
- Vorschau nutzt weiter die bestehende Export-Map; ohne stabile Geometrie fällt die UI auf eine kompakte Summary zurück statt eine Fake-Karte zu rendern
- `Export Destination` erklärt jetzt den realen vorhandenen Systempfad: generierte Datei über `.fileExporter` sichern oder teilen
- `ExportPresentation.reviewSnapshot(...)` und `selectionSummary(...)` ergänzen die Checkout-Präsentation, ohne neue Exportlogik einzuführen
- `AppContentSplitView` verdrahtet Rückführung aus dem Export zurück zu `Days` oder `Import`
- lokaler Nachweis: **881 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- keine neue Exportfunktion, kein neues Format, keine neue Serverfunktion
- keine neue Hardware- oder Landscape-Verifikation für Export
- iPad-/regular-width Export-Sheet visuell weiter ungeprüft
- App-Store-Screenshots müssen weiter neu aufgenommen werden; Export-Slot ist nach diesem Batch veraltet

### UI/UX Redesign Batch 2 — Start + Overview (2026-05-05)

Implementiert und getestet:
- **Startseite**: `HomeLocalPrivacyRow` — kompaktes Privacy-+Formate-Banner nach dem Titel; kein Account, lokal verarbeitet, JSON/ZIP/GPX/TCX
- **Übersicht — Reihenfolge**: Karte zuerst (vor Zeitraum/Filter), KPI direkt darunter; Dashboard-Struktur statt verstreuter Karten
- **Übersicht — Empty State**: `overviewEmptyCallToAction` wenn keine Daten geladen; Zeitraum-Card + Continue-Card bei leerem State ausgeblendet
- **Continue-Card vereinfacht**: "Browse Days" als visuell hervorgehobene Primär-Aktion; Insights/Export/Import als sekundäre Zeilen
- 19 neue Tests; Gesamt: **878 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- Hardware-Verifikation auf echtem iPhone ausstehend (Start + Overview)
- Landscape-Verifikation für Start + Overview ausstehend
- App-Store-Screenshots müssen neu aufgenommen werden (zeigen noch altes Layout)

### Sticky Map Workspace — Days-Tab (2026-05-05)

Implementiert und verifiziert:
- `LHMapHeaderState.isSticky`: neue Flag, die `toggleHidden()` blockiert — Map bleibt immer sichtbar
- `daysMapHeaderState` startet mit `.compact` + `isSticky: true` — Days-Map immer visible
- `daysListStickyHeader`: Map-Header + Kontext-Pills via `.safeAreaInset(edge: .top)` — fixed, scrollt nicht weg
- `daysExportSelectionBar`: persistente Export-Bottom-Bar via `.safeAreaInset(edge: .bottom)` — erscheint bei Auswahl
- 16 neue Tests in `LHMapHeaderStateStickyTests`; Gesamt: **849 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- Hardware-Verifikation der neuen sticky Map auf echtem Gerät ausstehend
- App-Store-Screenshots müssen neu aufgenommen werden (zeigen noch altes Layout)
- Landscape-Verifikation für Days sticky Header ausstehend

### Build 74 Accepted — Pending Developer Release (2026-05-05)

Repo-wahr dokumentiert:
- Apple hat Version 1.0 (Build 74) nach Review-Response **akzeptiert**
- ASC-Status: **Ausstehende Entwicklerfreigabe (Pending Developer Release)**
- Statusverlauf: Abgelehnt (2026-05-01) → Wird geprüft → Ausstehende Entwicklerfreigabe
- **Guideline 3.2**: resolved — kein offener Ablehnungsgrund
- **Build 74 wird bewusst nicht veröffentlicht**: Weiterentwicklung vor öffentlichem Release geplant
- Strategie für neuen Build: Developer Reject in ASC → neuen Xcode-Cloud-Build erzeugen → neuen Build + neue Screenshots einreichen
- App ist **nicht** im App Store live

### App Review Ablehnung + Public Audience Clarification (2026-05-05)

Repo-wahr dokumentiert:
- Apple lehnte Version 1.0 (Build 74) am 2026-05-01 unter **Guideline 3.2 — Business / Other Business Model Issues** ab
- Submission ID: `1d2cc080-13cd-45cd-b3e0-c0259a75ce5c`
- Ablehnungsgrund: App wurde fälschlich als organisationsgebundene Lösung eingestuft
- Sachverhalt: LH2GPX ist eine öffentliche Consumer-/Utility-App für persönliche Google-Maps-Standorthistorie
- Kein Account, kein Login, keine Organisationszugehörigkeit erforderlich
- Optionaler Live-Upload = nutzerkonfigurierter Self-hosted-Endpunkt, standardmäßig deaktiviert
- README, App-Feature-Inventory, TESTFLIGHT_RUNBOOK und APPLE_VERIFICATION_CHECKLIST klargestellt
- Response-Entwurf erstellt: `docs/APP_REVIEW_RESPONSE_GUIDELINE_3_2.md`
- Review-Response von Sebastian gesendet → Apple hat akzeptiert (s. Abschnitt oben)

### Build 73 + Screenshot-Submit-Vorbereitung (2026-05-01)

Repo-wahr dokumentiert:
- ASC Version 1.0: `Warten auf Prüfung`, sichtbarer Build `71`
- Xcode Cloud aktuellster erfolgreicher Build: `73`
- Repo-Stand für Build 73: `34734ce` (main HEAD nach Final Truth Sync)
- Screenshots in ASC: aus Build 71, altes UI-Layout — müssen neu aufgenommen werden
- Neue Screenshot-Slots 07 (Options) und 08 (Day Detail) in `testAppStoreScreenshots` vorbereitet
- Runbook für manuelle ASC-Schritte erstellt: `docs/ASC_SUBMIT_RUNBOOK.md`
- Noch nicht ausgeführt: Version aus Prüfung entfernen, Build 73 wählen, Screenshots ersetzen, Submit

### App Store Connect Truth Update (2026-04-30)

Repo-wahr dokumentiert:
- App Store Connect zeigt fuer `LH2GPX` Version `1.0` den Status `Warten auf Prüfung`
- die Version ist eingereicht; Veröffentlichung bleibt manuell
- auf der Versionsseite ist aktuell bewusst Build `52` sichtbar
- der Xcode-Cloud-Workflow `Release – Archive & TestFlight` hat erfolgreichere neuere Builds `55`, `56` und `57`

Nicht als abgeschlossen markieren:
- Build `52` bleibt bewusst in Review; Build `57` wird nicht ohne Apple-Feedback oder bestaetigten release-kritischen Fehler nachgereicht
- App Review ist nicht mehr durch Upload blockiert, aber weiterhin nicht durch vollstaendige Live-Activity-/Dynamic-Island-Hardware-Verifikation abgesichert

### Priorisierte Optimierungs-Roadmap (2026-04-30)

P0 — Release / Review / Hardware-Verifikation
- App-Review-Fortschritt auf Build `52` beobachten und rueckmelden
- offene ASC-Metadaten: Support-URL und Privacy-URL eingetragen (2026-04-30); GitHub Pages live (HTTP 200 verifiziert 2026-04-30); Screenshot-Assets lokal bereit, ASC-Upload manuell ausstehend
- Live Activity / Dynamic Island auf echter Hardware fuer Lock Screen, `minimal`, deaktivierte / nicht verfuegbare Live Activities und No-Dynamic-Island-Geraete vervollstaendigen (Pending-/Restart-Pfad gruen seit 2026-04-30)
- grossen echten Device-Smoke-Test fuer Overview-/Explore-Karte dokumentieren

P1 — Vorhandene Produktflaechen belastbar machen
- Chart-Share auf Apple-Hardware pruefen
- app-weite Landscape-Verifikation auf Apple-Hardware nachziehen
- Homescreen-Widget gesondert auf echter Hardware pruefen
- Simulator-/Host-Testlage fuer `LH2GPXWrapperTests` stabilisieren
- Track-Editor-/Export-Grenze weiter dokumentieren oder produktseitig spaeter anpassen

P2 — Nachgelagerte Optimierung
- Design-System (`LH2GPXTheme`) vollständig auf alle Produktionscreens ausgerollt (Start / Overview / Days / Day Detail / Insights / Export / Live Tracking / Live Tracks Library); Widget/Dynamic-Island nur bei sicherem Token-Pfad
- Apple-Review-/Privacy-Einordnung fuer den optionalen Server-Upload weiter sauber beobachten
- veraltete Notion-/Wrapper-/Split-Repo-Doku weiter abbauen
- echtes Road-/Path-Matching nur als spaeteren separaten Produktscope betrachten

### Final UI/Localization Truth Sync (2026-05-01)

Implementiert und verifiziert:
- 9 fehlende deutsche Übersetzungen in `AppLanguageSupport.swift` ergänzt (Invalid URL, Widget & Live Activity, Live Activity, Reachable/Unreachable, Test Connection, Testing…, Automatic Widget Update, Last tour + weekly status)
- `widgetAutoUpdate` und `maximumRecordingGapSeconds` in `AppPreferencesTests` abgedeckt
- 2 neue Testgruppen in `AppLanguageSupportTests` für Truth-Sync-Strings
- lokaler Nachweis: `swift test` **832 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- App-Store-Screenshots zeigen noch das alte Options-Layout — Aktualisierung auf neue Designs ausstehend
- Apple-Hardware-Verifikation für alle Redesign-Screens weiterhin ausstehend

### Options + Widget/Live Settings Redesign Truth Update (2026-05-01)

Implementiert und lokal verifiziert:
- `AppOptionsView` vollständig auf NavigationLink-Grid mit 8 modular strukturierten Section-Rows umgestellt
- `RecordingPreset`-Enum mit deterministischem Computed-Property auf `AppPreferences` (kein neuer UserDefaults-Key)
- `LHOptionsComponents.swift`: `LHOptionsSectionRow`, `LHLiveRecordingPresetSelector`, `LHUploadSettingsCard` (Token nur als `SecureField`), `LHDynamicIslandPreviewCard`, `LHWidgetPreviewCard`
- `OptionsPresentation.swift`: statische Darstellungs-Helpers für Upload-Status
- 36 neue DE/EN-Strings in `AppLanguageSupport.swift`
- lokaler Nachweis: `swift test` **830 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- kein Apple-Hardware-Claim für Options-Redesign
- Dynamic Island / Widget / Live Activity weiterhin nur auf echter Hardware vollständig verifizierbar

### Live Tracking + Library Redesign Truth Update (2026-05-01)

Implementiert und lokal verifiziert:
- `AppLiveTrackingView` ist sichtbar auf LH2GPX-Dark-Layout umgestellt: `ScrollView`+`LHPageScaffold`+Sticky-`LHLiveBottomBar`, Mint-Polyline/-Standortpunkt, Status-Chips mit Accessibility-Identifiern, Recording-Card ohne eingebetteten Button, Upload-Quick-Actions in Upload-Sektion
- `AppRecordedTracksLibraryView` ist sichtbar neu strukturiert: `ScrollView`+`LHPageScaffold`, Info-Card, `LHLiveTrackRow`-Zeilen, Titel „Live Tracks"
- `LHLiveBottomBar` und `LHLiveTrackRow` als neue Komponenten in `LHLiveComponents.swift`
- `LiveTrackingPresentation` um testbare Helpers `gpsStatusLabel` und `uploadSectionVisible` erweitert
- Alle bestehenden Verdrahtungen vollständig erhalten
- lokaler Nachweis: `swift test` 793 Tests, 0 Failures

Nicht als abgeschlossen markieren:
- kein Apple-Hardware-Claim für Live-Tracking-Redesign
- Dynamic Island / Lock Screen / Live Activity nur auf echter Hardware verifizierbar
- `AppRecordedTrackEditorView` bewusst unverändert gelassen

### Export Checkout Redesign Truth Update (2026-05-01)

Implementiert und lokal verifiziert:
- `AppExportView` ist vollstaendig von `List`-basiertem Layout auf `ScrollView`+`LHPageScaffold`+Sticky-`LHExportBottomBar` umgestellt
- `LHExportStepIndicator`: 4-Schritt-Progress (Auswahl / Format / Inhalt / Fertig) mit completed/active/pending Zustaenden
- `LHExportBottomBar`: Sticky `.safeAreaInset`-Bar mit Item-Count + Format-Label und primaerem Export-Button; optionaler Disabled-Reason-Caption
- `LHExportFilterDisclosure`: kollabierbare Advanced-Filters-Card mit oranger Active-State-Border und Chip-Badge
- Auswahl-Summary-Card mit 4-KPI-Grid (Days / Routes / Period / Places); „Auswahl bearbeiten" scrollt per `ScrollViewReader` zur Tages-Card
- Format-Pills (GPX / KMZ / KML / GeoJSON / CSV) und Mode-Pills (Tracks / Waypoints / Both) mit aktivem Fill-Highlight
- `ExportPresentation.bottomBarSummary` und `ExportPresentation.disabledReason` neu; bestehende `ExportPresentation.readiness` unveraendert
- alle bestehenden Verdrahtungen erhalten: `fileExporter`, per-Route-Auswahl, Insights-Drilldown, alle Filter, `ExportSelectionState`, Builder, Kontrakt
- lokaler Nachweis: `swift test` 773 Tests, 0 Failures

Nicht als abgeschlossen markieren:
- kein neuer Apple-Hardware-Claim fuer den Export-Checkout-Umbau
- keine neue Exportfaehigkeit, kein neues Format, keine Kontrakt-Aenderung
- display-only Track-Editor-Mutations fliessen weiterhin nicht in den Export-Truth ein

### Days + Day Detail Redesign Truth Update (2026-04-30)

Implementiert und lokal verifiziert:
- `Days` ist sichtbar auf das neue LH2GPX-Dark-Layout umgestellt: grosser Titel, kompakte Zeitraum-/Suche-Context-Zeile, reduzierte Filterchips, dunkle Card-Rows und optionaler kollabierbarer Map-Header
- die Days-Map nutzt weiter den bestehenden projizierten / gefilterten Tageskontext; bei verborgenem Header bleibt die `LHCollapsibleMapHeader`-Performance-Invariante erhalten und die Map wird nicht instanziiert
- Day Rows trennen Favorit und Exportstatus jetzt sichtbar voneinander; Orte, Routen, Aktivitaeten und Distanz bleiben getrennt praesentiert
- Day Detail ist sichtbar map-first umgebaut: `AppDayMapView` direkt oben, danach KPI-Karten fuer Distanz / Routen / Aktivitaeten / Orte sowie Segmentumschaltung fuer `Overview`, `Timeline`, `Routes`, `Places`
- bestehende Business-Verdrahtung bleibt erhalten: `daysNavigationPath`, `selectedDayID`, `daySearchText`, `dayListFilter`, `DayListPresentation.filteredSummaries`, `DaySummaryRowPresentationBuilder`, `DayDetailPresentation`, `DayMapDataExtractor`, `ExportSelectionState.routeSelections`, `AppImportedPathMutationStore`, `ImportedPathDeletion`, Insights-Drilldown und SplitView-/Tab-Reselection-Verhalten
- lokaler Nachweis: `swift test` 741 Tests, 0 Failures

Nicht als abgeschlossen markieren:
- kein neuer Apple-Hardware-Claim fuer den sichtbaren Days-/Day-Detail-Umbau
- keine neue Exportfaehigkeit, kein neues Road-Snapping, kein neues Map-Matching
- keine Aenderung daran, dass display-only entfernte importierte Routen nicht in den Export-Truth einfliessen

### Start + Overview Redesign Truth Update (2026-04-30)

Implementiert und lokal verifiziert:
- import-first Startseite ist sichtbar auf das neue LH2GPX-Redesign umgestellt: schwarzer Hintergrund, grosser `LH2GPX`-Titel, kompakter Subtitle, grosser blauer Import-Button, dunkle Action Rows fuer Hilfe und Demo
- `RecentFilesView` ist jetzt die produktive `Zuletzt verwendet`-Card auf der Startseite; Dateiname, Datum und optionale Dateigroesse sind sichtbar, Reopen-/Remove-/Clear-Logik bleibt erhalten
- Overview ist sichtbar neu strukturiert: Importstatus-Card, Zeitraum-Card, KPI-Grid, Highlights-Card, `Weiterarbeiten`-Card
- `LHCollapsibleMapHeader` ist jetzt auf der ersten echten Produktseite (`Overview`) pilotiert; `LHPageScaffold` und `LHContextBar` sind dort ebenfalls produktiv im Einsatz
- `AppOverviewTracksMapView` bleibt die bestehende Overview-Karte; bei verborgenem Header wird die Map-Closure nicht ausgewertet, die bestehende Overlay-/Simplification-/Cancellation-Logik bleibt unveraendert
- lokaler Nachweis: `swift test` 739 Tests, 0 Failures

Prompt-2-Doku-Korrektur:
- der bisher noch offene NEXT_STEPS-/ROADMAP-Punkt zum ersten echten `LHCollapsibleMapHeader`-Pilot war nach Prompt 2 weiterhin korrekt offen; mit diesem Slice ist er repo-wahr erledigt und als offener Punkt entfernt bzw. auf weitere Rollout-Arbeit umformuliert

Nicht als abgeschlossen markieren:
- kein neuer Apple-Hardware-Claim fuer Home-/Overview-Layout, Heatmap, Range-Chips oder die neue Startseiten-IA
- keine Aussage zu App-Store-Screenshot-Aktualitaet nach dem sichtbaren UI-Umbau

### Dynamic Island / Live Activity Truth Update (2026-04-30)

Implementiert und lokal verifiziert:
- konfigurierbarer Dynamic-Island-Primärwert (`Distanz`, `Dauer`, `Punkte`, `Upload-Status`) mit Persistenz
- konsistente Wertedarstellung fuer Lock Screen, expanded, compact trailing und minimal (minimal bewusst icon-basiert)
- sichtbare Fallback-Logik in den Optionen fuer nicht verfuegbare / deaktivierte Live Activities
- Upload-/Pause-Zustand wird jetzt aus dem Live-Modell tatsaechlich in die Live Activity propagiert
- Overview-Heatmap-Einstieg als Capsule-Chip an die bestehende Chip-Sprache angepasst

Auf echter Hardware bestaetigt:
- `iPhone 15 Pro Max` (`iOS 26.4`, Debug-Build via `xcodebuild test`): Recording-Start, Dynamic Island `compact` fuer Primärwert `Distanz`, Dynamic Island `expanded` fuer Primärwert `Distanz`, Stop-/Dismiss-Verhalten nach Aufnahmeende

Nicht als abgeschlossen markieren:
- echte Apple-Hardware-Verifikation fuer Live Activity / Dynamic Island bleibt teilweise offen: Lock Screen, `minimal`, deaktivierte / nicht verfuegbare Live Activities und No-Dynamic-Island-Geraete sind noch nicht repo-wahr bestaetigt; Pending-/Restart-Pfad gruen seit 2026-04-30
- Wrapper-Simulator-Testlauf war auf diesem Host nicht belastbar abschliessbar (`NSMachErrorDomain Code=-308`)

### Live-Session-Restore Truth Update (2026-04-30)

Implementiert und lokal verifiziert:
- interrupted-session Persistenz wird erst nach echtem Recording-Start geschrieben, nicht mehr schon bei Initialisierung oder vor erfolgreichem Authorization-/Startpfad
- Restore-Banner erscheint nur noch bei gueltiger Kombination aus `sessionID` (UUID) und `sessionStartedAt` (gueltiger Timestamp)
- denied/restricted sowie abgelehntes `Always`-Upgrade raeumen verwaisten Restore-State jetzt defensiv auf
- `dismissInterruptedSession()` und sauberer Stop entfernen Persistenz und In-Memory-State konsistent
- Regressionstests decken Initialisierung ohne Recording, Persistenz beim Start, Loeschung bei Stop/Ignore sowie kaputte oder partielle `UserDefaults`-Werte ab

### Release / TestFlight Truth Update (2026-04-30)

Implementiert und lokal verifiziert:
- `CURRENT_PROJECT_VERSION = 45` im Wrapper-Projekt, damit ein neuer lokaler Release-Kandidat oberhalb des bereits dokumentierten TestFlight-Builds `1.0 (44)` liegt
- Release-Archive fuer `LH2GPXWrapper` sind lokal wieder erzeugbar
- Release-Signing-Konflikt im Repo bereinigt: keine explizite Release-`CODE_SIGN_IDENTITY`, `CODE_SIGN_STYLE = Automatic` bleibt aktiv

Nicht als abgeschlossen markieren:
- lokaler Export/Upload nach App Store Connect bleibt fuer diesen Host offen: aktueller Host hat keine verfuegbare Distribution-Identitaet und keine konfigurierte ASC-CLI-Authentifizierung; App Review selbst ist aber nicht mehr am Upload-Schritt blockiert
- App Review bleibt bis zur vollstaendigeren Hardware-Verifikation von Live Activity / Dynamic Island offen

## Aktueller Stand (2026-04-29)

### Overview-Map Freeze/Crash-Fix – Hard Overlay Limit (2026-04-29)

Abgeschlossen (647 Tests, 0 Failures):
- **Problem**: `AppOverviewTracksMapView` frierte ein oder crashte bei „Gesamtzeitraum" + großen Datenmengn. Root Cause: `selectCandidates` lieferte alle Kandidaten unsortiert ohne Overlay-Limit; MapKit erhielt tausende `MapPolyline`-Objekte.
- **Fix**: Hard `overlayLimit` in `OverviewMapRenderProfile` eingeführt. Tier-basierte Limits: sehr groß (>500 Routen/>150k Punkte) → 150, groß → 200, mittel-groß → 250, mittel → 300, klein → kein Cap.
- `selectCandidates` schneidet nach Score-Sortierung auf `overlayLimit` ab.
- `isOptimized` ist `true` wenn Cap greift — View zeigt Badge „Karte vereinfacht – Export vollständig".
- Export-Daten unverändert. Rohdatenmodell und Export-Pipeline kein Eingriff.
- 5 neue Tests (Fix): `overlayLimit`-Werte per Tier, synthetisches 600-Routen-Dataset gecapped, kleines Dataset ungecapped, Start-/Endpunkt-Erhaltung, Export-Daten-Unveränderlichkeit.
- **Performance-Audit (2026-04-29)**: `overlayLimit × maxPolylinePoints` ergibt implizites hartes globales Coordinate-Budget (max 9.600–48.000 je Tier). Kein separates globales Budget nötig. 3 neue Invarianten-Tests: Total-Coordinate-Cap, Einzelrouten-Decimation, Badge-Logik bei Simplification-ohne-Cap. 650 Tests, 0 Failures.

---

## Aktueller Stand (2026-04-12)

### Multi-Source Import Foundation — GPX + TCX (2026-04-12)

Abgeschlossen (530 Tests, 0 Failures):
- GPX 1.1 Import: `GPXImportParser` (trk/trkseg/trkpt + wpt → AppExport, local-date grouping)
- TCX 2.0 Import: `TCXImportParser` (TrainingCenterDatabase/Trackpoint/Position → AppExport)
- `AppContentLoader`: GPX/TCX-Routing in `decodeData()` und ZIP-Scan
- `fileImporter` akzeptiert `.gpx` und `.tcx` zusätzlich zu `.json` und `.zip`
- DE/EN-Strings für GPX/TCX-Import ergänzt
- 3 neue Contract-Fixtures (`sample_import.gpx`, `.tcx`, `_empty.gpx`)
- 19 neue Tests in `MultiSourceImportTests`
- FIT-Format: bewusst nicht implementiert (kein wartbares Swift-Framework ohne externe Dependency)
- GeoJSON-Import: bewusst als Follow-up aufgeschoben (Komplexität; Export bleibt unberührt)
- Prompt-1-Schutz: alle 7 geschützten Dateien unberührt

### UI Polish – Overview / Insights / Heatmap / Landscape (2026-04-12)

Abgeschlossen (511 Tests, 0 Failures):
- Overview-Pane umgeordnet: Time-Range-Control an erster Position
- Favorites-Only-Toggle (Capsule-Chip) im Overview; filtert Statistiken und Map reaktiv
- `AppOverviewTracksMapView`: async Polyline-Uebersichtskarte (iOS 17+), Task.detached, `.task(id:)`, keine versteckte Route-Kappung fuer den aktiven Zeitraum; Performance ueber Vereinfachung/Decimation
- Heatmap Mode/Radius-Picker als Capsule-Chips (passend zu `AppDayFilterChipsView`); Controls scrollbar in Landscape
- Stray `Text("No data")` aus `AppDayRow` entfernt (visueller Stray-Bullet behoben)
- `InsightsTopDaysPresentation.topDays(limit:)` von 5 auf 20 erhöht
- `HistoryDateRangeFilter.isoFormatter`: UTC → `.autoupdatingCurrent` (Timezone-Off-by-One-Fix)
- `AppInsightsContentView.refreshDerivedModel()`: Metric-State atomar ohne Animation angewendet (State-Shift-Fix)
- ~30 neue DE-Strings (`AppGermanTranslations`): Favorites, Range-Map, Heatmap, Insights, Accessibility
- 14 neue Unit-Tests (`OverviewFavoritesAndInsightsTests`): Favorites-Filter, Timezone, Top-Days, Lokalisierung

### P1 Critical Security + Stability Fixes (2026-04-12)

Abgeschlossen (481 Tests, 0 Failures):
- `KeychainHelper.encodingFailed`: force-unwrap durch throwing guard ersetzt
- `AppExportQueries.effectiveDistance`: Logik explizit und kommentiert
- `GeoJSONBuilder`: wirft `GeoJSONBuildError.serializationFailed` statt silent fallback
- `MockURLProtocol` macOS-Fix: `httpBodyStream` wird gelesen wenn `httpBody` nil ist

---

## Aktueller Stand (2026-04-01)

### Repo-Truth-Zusammenfassung
Die letzte real belegte Apple-/Device-Verifikation bleibt der dokumentierte Apple-Stand vom 2026-03-17 beziehungsweise 2026-03-30; in diesem Audit wurde kein neuer Apple-Host-Lauf vorgetaeuscht.
Der Audit-Block vom 2026-04-01 ist in dieser Revision eingearbeitet: sichtbare Zeitraumfilter-Verdrahtung, Recent Files, Auto-Restore, Days-Filterchips, Favoriten, per-route Auswahl, CSV-Export-Verdrahtung, Heatmap-Teststabilisierung, spaetere Live-/Projektions-Entschaerfung und der aktuelle Teststatus sind jetzt dokumentarisch an den aktuellen Code angeglichen.
Diese ROADMAP trennt ab hier explizit zwischen `fertig`, `implementiert aber noch nicht voll verifiziert` und `noch nicht umgesetzt`.
Historische Phasen weiter unten bleiben als Zeitstrahl stehen; wenn spaetere Commits fruehere Zwischenstaende ueberholt haben, gilt der aktuelle Kopfblock als massgeblicher Repo-Truth.
Der frische Host-Nachweis dieses Audits ist Linux-only: `swift test` lief am 2026-04-01 mit `Executed 363 tests, with 0 failures (0 unexpected)`, `git diff --check` ist sauber, und `xcodebuild` ist auf diesem Host nicht verfuegbar.
Der Live-/Upload-/Insights-/Days-Batch vom 2026-03-30 ist im Code umgesetzt und in dieser ROADMAP als repo-wahrer Produktstand eingearbeitet; fuer diesen Batch liegen auf Linux gezielte Teilnachweise vor, aber kein neuer Apple-UI-Nachweis.
Der spaetere UI-Polish-/Heatmap-Detail-Batch vom 2026-03-30 staerkt vor allem die Heatmap-Detailsichtbarkeit sowie kleine visuelle Kanten in `Live`, `Insights` und `Days`; auf diesem Linux-Host liegen dazu nur nicht-Apple-Nachweise vor.

### Repo-wahr abgeschlossen

- Import von LH2GPX-`app_export.json`/`.zip` sowie Google-Timeline-`location-history.json`/`.zip`
- Overview, Days, Day Detail, Insights und Export als produktnahe App-Shell
- Suche in compact und regular `Days`
- `Days` standardmaessig absteigend (`neu -> alt`) inklusive neuer newest-first Session-Projektion sowie contentful-first Initialauswahl/Fallbacks
- Re-Select-Verhalten fuer `Days` auf iPhone: erneutes Tab-Tippen fuehrt zum aktuellen Tag
- stabile Sheet-Praesentation fuer Optionen, Export, Heatmap und `Saved Live Tracks`
- eigene `Saved Live Tracks`-Library plus Editor fuer gespeicherte lokale Tracks
- aktuelle Position auf der Karte anzeigen
- Live-Recording mit lokalen Einstellungen fuer Accuracy-Filter und Recording-Detail
- Live-Tracking-Oberflaeche mit klarer Recording-/Upload-/Library-Hierarchie, erweiterten Stat-Karten und Quick Actions fuer Zentrieren, Pause/Resume der Uploads und manuellen Queue-Flush
- optionaler Server-Upload mit Queue-/Failure-/Last-Success-Status, Pause/Resume und manuellem Flush
- segmentierte Insights-Oberflaechen (`Overview`, `Patterns`, `Breakdowns`) mit KPI-Karten, Highlight-Karten, `Top Days` und Monatstrends
- Monatstrends respektieren den aktiven Zeitraum ohne 24-Monats-Cap; Tabellen-/Listenanzeige priorisiert neueste Monate
- GPX-, KML-, GeoJSON- und **CSV**-Export fuer importierte History und gespeicherte Live-Tracks
- Exportmodi fuer `Tracks`, `Waypoints` und `Both`
- Waypoint-Export aus importierten Visits sowie Activity-Start/-End-Koordinaten
- sichtbare Export-Vorschaukarte direkt auf der Export-Seite
- lokale Export-Filter fuer importierte History nach Datumsfenster, maximaler Genauigkeit, erforderlichem Inhalt, Aktivitaetstyp sowie Bounding Box oder Polygon
- **per-route Auswahl** innerhalb eines Tages (`ExportSelectionState.routeSelections`; implizit alle Routen wenn keine explizite Auswahl), sichtbar im Day Detail mit Reset auf implizit alle exportierbaren Routen
- **globaler Zeitraumfilter** (`HistoryDateRangeFilter`): Presets + Custom + Reset; sichtbar in `Overview`, `Insights` und `Export` verdrahtet
- **Recent Files** (`RecentFilesStore`): bis zu 10 Eintraege, Stale-Pruefung, Reopen/Remove/Clear im import-first Startzustand
- **Auto-Restore-Option** (`AppPreferences.autoRestoreLastImport`, Default `false`): sichtbarer Toggle plus opt-in Restore beim App-Start
- **Tage-Favoriten** (`DayFavoritesStore`): Stern-Marking, Persistenz, sichtbarer Toggle in Day-Liste und Day Detail, `DayListFilterChip.favorites`
- **Days-Filterchips** (`DayListFilter`): Favorites / Has Visits / Has Routes / Has Distance / Exportable; sichtbar in `Days` und mit Suche kombinierbar
- **Insights-Drilldown** (`InsightsDrilldown`): `filterDaysToDate`, `filterDaysToDateRange`, `prefillExportForDate`, `prefillExportForDateRange`; `activeDrilldownFilter` in `AppSessionState`
- **Chart-Share-Payload** (`ChartShareHelper`): UI-freier Payload-Builder; Dateiname-Format; sichtbare Share-Aktionen jetzt in den wichtigsten Insights-Sektionen verdrahtet; echte ImageRenderer-/Share-Sheet-Verifikation bleibt Apple-Host-Arbeit
- zentrale filter-key-basierte Session-Projektionsschicht fuer `Overview`, `Days`, `Insights`, `Export` und Day-Detail-Map-Daten; wiederholte Export-/Day-Projektionen laufen nicht mehr breit im UI-Renderpfad
- Live-Stabilitaet: geringerer Timer-bedingter Voll-Refresh, sauberere Upload-Cancellation/Serialisierung und entschärfte Queue-Mutationen fuer den optionalen Server-Upload
- Heatmap-/Map-Restoptimierung: vorbereitete Route-Tracks, lazy Density-LOD-Aufbau, gecachte `DayMapData` und stabile Renderdaten fuer Day-/Export-Maps reduzieren First-Open- und Re-Render-Arbeit ohne Semantikaenderung
- Sprachwahl `English` / `Deutsch` in den Optionen; breite DE-Abdeckung fuer Shell-, Optionen-, Live-Recording-, Import-Entry-, Export-, Days-/Day-Detail- und Analytics/Insights/Overview-Oberflaechen inkl. Format-Strings, Monatsnamen, rangeDescription-Singular/Plural, Custom-Date-Range-Sheet, Overlap-Map, Recent Files, Auto-Restore, Days-Filterchips, Route-Export-Aktionen und InsightsChartSupport-Hints (Stand 2026-04-01: `swift test` -> `Executed 363 tests, with 0 failures (0 unexpected)`)

### Implementiert, aber noch nicht voll verifiziert

- **Heatmap**
  `AppHeatmapView` und das Heatmap-Sheet sind implementiert und jetzt dokumentiert.
  Heatmap UX Batch 1 hat die Darstellung auf mittleren/grossen Zoomstufen beruhigt und kleine lokale Controls fuer Deckkraft, Radius und `Auf Daten zoomen` hinzugefuegt.
  Heatmap Visual & Performance Batch 2 hat danach auf geglaettete aggregierte Polygon-Zellen, viewport-basierte Zellselektion, per-LOD begrenzte sichtbare Elemente und einen wiederverwendbaren Viewport-Cache umgestellt, um den sichtbaren Kreis-/Stempel-Look zu reduzieren und Pan/Zoom ruhiger zu machen.
  Heatmap Color / Contrast / Opacity Batch 3 hat danach die Farbpalette von harten Stufen auf weich interpolierte Gradient-Stops umgestellt, mittlere/hohe Dichte per Intensitaets-Mapping sichtbar angehoben und die 100-%-Deckkraft ueber eine staerkere High-End-Kennlinie auf einen wirklich volleren Sichtbarkeitsmodus gemappt.
  Der UI-Polish-/Heatmap-Detail-Batch hat danach die Detailsichtbarkeit weiter angehoben: niedrigere Detailschwellen, fruehere Farbe bei duennen Daten, mehr sichtbare Low-/Mid-Density im Detailzoom und etwas klarere Legenden-/Opacity-Abstimmung.
  Der Phase-3-Restbatch vom 2026-04-01 baut Route-Grids und vorbereitete Route-Tracks jetzt einmalig vor, verschiebt Dichte-LOD-Aufbau auf echten Bedarf im Density-Modus und reduziert wiederholte Export-Traversierung bei Viewport-Wechseln auf groesseren Kartenflaechen.
  Kleine dedizierte Heatmap-Regressionstests fuer Aggregation, viewport-begrenzte Zellselektion und das neue Intensitaets-/Opacity-/Palette-Mapping sind jetzt vorhanden.
  Offen bleibt die visuelle/performance-seitige Apple-Verifikation dieses neuen Renderers samt Batch-3-Farbwirkung auf echter Hardware.
- **`Live`-Tab**
  Der dedizierte 5. Tab fuer compact iOS 17+ ist implementiert und jetzt dokumentiert.
  Der Batch vom 2026-03-30 hat den Tab inhaltlich deutlich ausgebaut (moderne Karten-/Card-Hierarchie, Quick Actions, mehr Live-Metriken, Upload-Zustaende).
  Offen bleiben echte iPhone-UX-/Device-Nachweise fuer diesen Pfad.
- **Background-Live-Tracking**
  Codepfad, Permissions-Upgrade und Wrapper-Deklaration sind vorhanden.
  Offen bleiben reale Apple-Hardware-Verifikation, Suspend/Resume-Kantenfaelle und ein sauber protokollierter Device-Durchlauf.
- **Auto-Restore / Recent Files**
  Recent Files und der opt-in Restore-Pfad sind jetzt in der App-Shell sichtbar verdrahtet.
  Offen bleibt eine frische Device-Verifikation fuer Reopen, Clear History und den Restore-beim-Start-Pfad.
- **Server-Upload**
  HTTPS-Upload, Bearer-Token, Retry-on-next-sample, Upload-Batching, Queue-/Failure-/Last-Success-Status, Pause/Resume und manueller Flush sind implementiert.
  Hart kodierter Testendpunkt (`sslip.io`) entfernt: `defaultTestEndpointURLString` ist jetzt `""`.
  Offen bleiben End-to-End-Device-Verifikation sowie finale Review-/Privacy-Einordnung auf Apple-Seite.
- **Insights / Days UX**
  Die Insights-Seite ist deutlich ausgebaut und `Days` ist jetzt repo-wahr `neu -> alt` sortiert.
  Insights-Drilldown nach `Days`/`Export` und sichtbare Share-Aktionen fuer zentrale Insight-Sektionen sind jetzt UI-seitig verdrahtet.
  Day-Detail nutzt jetzt gecachte `DayMapData`, und Day-/Export-Karten halten stabile Renderdaten fuer Marker, Polylines und Regionen statt wiederholter Koordinaten-Neuaufbereitung pro Render.
  Offen bleiben frische Apple-UI-Nachweise fuer die neue Informationsarchitektur, Chart-Lesbarkeit, den jetzt sichtbaren Zeitraumfilter in `Overview`/`Insights`/`Export`, die sichtbaren Days-Filterchips/Favoriten/per-route Actions, den neuen Insights-Drilldown sowie den echten Chart-Share-Flow auf Apple-Hardware.
- **Linux-/Apple-Teststatus**
  Historische Apple-Nachweise vom 2026-03-30 bleiben dokumentiert, gelten aber nicht als frischer Gegenlauf fuer diesen Audit.
  Der aktuelle Linux-Mindestnachweis dieses Audits ist `swift test` mit `Executed 363 tests, with 0 failures (0 unexpected)`; `git diff --check` ist sauber.
  Die 3 bekannten Problemfaelle sind als Test-Drift klassifiziert und behoben:
  `testAcceptedSamplesUploadToConfiguredServer` und `testFailedUploadRetriesWhenAnotherAcceptedSampleArrives` scheiterten an minimumBatchSize=5 (nicht Plattform), Tests auf minimumBatchSize=1 gesetzt;
  `testBackgroundPreferenceActivatesClientWhenAlwaysAuthorized` prueft jetzt korrektes Verhalten (Client-Config beim Recording-Start, nicht bei Preference-Aenderung).
  Batch 2 hat die 2 verbliebenen Test-vs-Code-Widersprueche repo-wahr aufgeloest:
  `AppPreferencesTests.testStoredValuesAreLoaded` folgt jetzt dem Keychain-first-Produktverhalten,
  `DayDetailPresentationTests.testTimeRangeFormattingAvoidsRawISOStrings` folgt jetzt der im Produktcode konsistent genutzten Gedankenstrich-Formatierung.
  Ein frischer Apple-CLI-Rerun fuer den aktuellen Stand bleibt offen, weil `xcodebuild` auf diesem Linux-Host nicht vorhanden ist.

### Noch nicht umgesetzt

- echtes Road-/Path-Matching; aktuell gibt es nur Pfadvereinfachung im Day-Detail
- KMZ-Export — ✅ abgeschlossen (2026-04-12); KMZBuilder (ZIPFoundation), KMZDocument (BinaryExportDocument), ExportFormat.kmz, 6 neue Tests
- Live Activity Widget UI — ✅ Widget-Target und Swift-Dateien sind vorhanden (`wrapper/LH2GPXWidget/`); offene Arbeit ist reale Apple-Hardware-Verifikation, nicht Target-Anlage
- weitere Insight-Arbeit: Apple-Host-Verifikation fuer den jetzt verdrahteten Drilldown-/Chart-Share-Flow sowie optional spaeter map-linked Cross-Filtering
- Auto-Resume einer laufenden Live-Aufzeichnung nach App-Neustart
- breitere Lokalisierungsabdeckung und eine strengere Lokalisierungspruefung
- Cloud-/Sync- oder Account-Features

### Reihenfolge der naechsten offenen Bloecke

1. kurzen echten iPhone-Heatmap-Check fuer den neuen Aggregations-/Polygon-Renderer inklusive Batch-3-Farb-/Kontrast-Mapping und des spaeteren Detail-Visibility-Polish fahren und visuelle/performance-seitige Befunde dokumentieren
2. dedizierten iPhone-UI-Check fuer den deutlich umgebauten `Live`-Tab, die Upload-Zustaende und die neue `Days`-Default-Sortierung fahren und dokumentieren
3. Background-Recording auf echtem iPhone verifizieren und im Runbook belegen
4. Auto-Restore / Recent Files auf echtem iPhone erneut verifizieren und dokumentieren
5. `Days` / Day Detail / CSV-Export auf echter Apple-Hardware gegenpruefen und dokumentieren
6. optionalen Server-Upload end-to-end auf Device pruefen; Apple-Review-/Privacy-Einordnung fuer den Upload-Pfad weiter klaeren
7. erst danach weitere neue Feature-Arbeit (weiterer Insights-Ausbau, KMZ, `Days`-seitige Zeitraumsauswahl)

Apple-/ASC-/TestFlight-/Release-Themen sind nicht geparkt, sondern bleiben bis zu Apple-Feedback und vollstaendigerer Hardware-Verifikation aktiv. iPad bleibt nachrangig. Phase 21 bleibt fuer spaetere Folgearbeit reserviert.

### Phase 19.51 – Apple Stabilization Batch 1

**Datum:** 2026-03-30
**Ziel:** Audit-belegte P0/P1-Probleme beheben, Apple-Build-/Testlage auf belastbaren Stand bringen, Doku repo-wahr synchronisieren.

- [x] macOS-Compile-Fehler behoben: `.textInputAutocapitalization(.never)` in `#if os(iOS)` eingeschlossen
- [x] macOS-Compile-Fehler behoben: `if #available(iOS 17.0, macOS 14.0, *)` fuer `AppLiveTrackingView` und `AppLiveLocationSection`
- [x] Demo- und App-Shell-Compile-Fehler behoben: `loadImportedFile(at:)` async gemacht (fehlte nach `DemoDataLoader`-Aenderung)
- [x] Wrapper-SPM-Pfad korrigiert: `../../../Code/...` auf `../LocationHistory2GPX-iOS`
- [x] Upload-Tests als Test-Drift klassifiziert und korrigiert (minimumBatchSize=1 im Test-Setup)
- [x] Background-Preference-Test als Test-Drift klassifiziert und korrigiert
- [x] Privacy-Text in TestFlight-Runbook sachlich korrekt formuliert
- [x] README-Widerspruch (offline-only vs. optionaler Upload) behoben
- [x] `swift test` auf macOS: 222 Tests, 2 verbleibende rote Tests ausserhalb dieses Batch-Scope, alle 3 audit-relevanten Problemfaelle gruen
- [x] `xcodebuild test -scheme LocationHistoryConsumer-Package -destination 'platform=macOS'`: 222 Tests, dieselben 2 verbleibenden roten Tests
- [x] `xcodebuild build -scheme LH2GPXWrapper -destination generic/platform=iOS`: BUILD SUCCEEDED
- [x] `xcodebuild test -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -only-testing:LH2GPXWrapperTests`: TEST SUCCEEDED

**Nicht-Ziele:** Keine neue Produktfunktion, keine neue Apple-Device-Verifikation.

### Phase 19.50 – Audit Fix + Roadmap Granularization

**Datum:** 2026-03-30
**Ziel:** Audit vom 2026-03-30 in repo-wahre Doku, Roadmap und Verifikationsaussagen ueberfuehren, ohne neue Produktfeatures zu bauen.

- [x] Audit-Datei gesichert und gegen den aktuellen Repo-Stand abgeglichen
- [x] README, ROADMAP, NEXT_STEPS, Feature-Inventar und Runbooks auf Heatmap, `Live`-Tab, Upload-Batching und Wrapper-Auto-Restore synchronisiert
- [x] Default-Endpunkt in der Doku auf `https://178-104-51-78.sslip.io/live-location` korrigiert
- [x] Test-/Verifikationsstatus von historischem Xcode-Stand gegen den aktuellen Linux-Stand abgegrenzt
- [x] Core- und Wrapper-ROADMAP/NEXT_STEPS wieder inhaltlich synchronisiert

**Nicht-Ziele:** Keine neue Produktfunktion, keine neue Apple-Behauptung ohne Nachweis, keine kosmetischen Feature-Claims.

### Phase 19.41 – Exportmodi / Waypoints vs Tracks

**Datum:** 2026-03-20
**Ziel:** Export klar zwischen Route-, Waypoint- und Mischmodus unterscheiden, ohne bestehende GPX/KML-Flows zu zerbrechen.

- [x] neuer `ExportMode` fuer `Tracks`, `Waypoints` und `Both`
- [x] GPX-, KML- und GeoJSON-Builder respektieren jetzt den aktiven Modus
- [x] Waypoint-Export basiert auf importierten Visits sowie Activity-Start/-End-Koordinaten
- [x] Export-UI, Dateiname und Disabled-Reasons reagieren jetzt auf den aktiven Modus
- [x] Saved Live Tracks bleiben bewusst track-only und werden in Waypoint-only-Modi nicht faelschlich als exportierbar dargestellt
- Bewusst nicht in diesem Schritt: per-route Auswahl, Track-/Waypoint-Editierung importierter Daten

### Phase 19.40 – Weitere Exportformate

**Datum:** 2026-03-20
**Ziel:** Nach GPX/KML ein drittes sinnvolles Exportziel aktivieren, ohne einen unklaren Formatfriedhof aufzubauen.

- [x] `GeoJSON` als drittes aktives Exportformat freigeschaltet
- [x] `ExportDocument` / `UTType` und Export-UI kennen jetzt `.geojson`
- [x] GeoJSON exportiert Tracks als `LineString` und Waypoints als `Point`-Features
- [x] Tests decken das neue Format fuer route-only und mixed content ab
- Bewusst nicht in diesem Schritt: `CSV`, `KMZ`, serverseitige Zielsysteme

### Phase 19.39 – Export-Filter vervollstaendigen

**Datum:** 2026-03-20
**Ziel:** Die bereits vorhandenen Query-Unterbauten fuer Flaechenfilter sichtbar und produktiv nutzbar machen.

- [x] lokale Bounding-Box-UI fuer importierte History
- [x] lokale Polygon-UI per Koordinatenliste fuer importierte History
- [x] Upstream- und lokale Area-Filter werden konservativ kombiniert statt gegenseitig still zu ueberschreiben
- [x] Vorschau und Export reagieren jetzt auf Bounding-Box/Punkt-in-Polygon-Filter
- [x] Nutzerhinweise machen explizit, dass lokale Filter nur importierte History betreffen und Saved Live Tracks unberuehrt lassen
- Bewusst nicht in diesem Schritt: interaktives Polygonzeichnen auf der Karte

### Phase 19.38 – Export-UX-Politur

**Datum:** 2026-03-20
**Ziel:** Export-Flow fuer GPX sichtbarer machen, ohne neue Formate oder neue Exportlogik einzufuehren.

- [x] Export-Selektion zeigt jetzt einen eigenen Summary-Block mit Anzahl, route-faehigen Tagen und Distanzsumme
- [x] Dateinamenvorschau wird direkt aus der aktuellen Auswahl angezeigt
- [x] Day Rows markieren Tage ohne GPX-faehige Routen expliziter
- [x] Disabled-Reasons unterhalb des Export-Buttons erklaeren jetzt klar, warum kein Export moeglich ist
- [x] ausgewaehlte Day Rows erhalten zusaetzlich eine subtile visuelle Hervorhebung
- Bewusst nicht in diesem Schritt: KML/CSV, per-route Export, neue Share-Ziele

### Phase 19.37 – Visualisierung / Charts-Politur

**Datum:** 2026-03-20
**Ziel:** Vorhandene Insights-Visualisierungen lesbarer und erklaerender machen, ohne neue Analysemetriken zu erfinden.

- [x] Distance-, Activity- und Visit-Charts zeigen jetzt explizitere Achsen statt weitgehend versteckter Skalen
- [x] Distance-Chart erklaert die Tap-Navigation zu einzelnen Tagen direkt im UI
- [x] Activity- und Weekday-Charts ergaenzen kurze Erklaerhinweise fuer die gezeigte Metrik
- [x] Weekday-Chart zeigt zusaetzliche Werteannotationen ueber den Bars
- [x] Low-Data- und chart-unverfuegbar-Faelle bleiben weiter mit expliziten Empty States abgesichert
- Bewusst nicht in diesem Schritt: neue Statistiken, Zoom-/Density-Controls, Export von Charts

### Phase 19.36 – Track-Library / Track-Editor-Zugang

**Datum:** 2026-03-20
**Ziel:** Gespeicherte Live-Tracks ueber Overview, Day Detail, Library und Editor konsistenter benennen und klar als lokalen Nebenfluss markieren.

- [x] Overview-Karte fuehrt jetzt konsistent unter `Saved Live Tracks` statt mit wechselndem `Track Editor`-Wording
- [x] Library, Empty States und Sheet-Fallback nutzen jetzt dieselbe Benennung fuer gespeicherte Live-Tracks
- [x] Day-Detail-/Live-Recording-Bereich fuehrt gespeicherte Tracks jetzt klar als lokale Aufnahme-/Bearbeitungsfunktion
- [x] Track-Editor-Titel benennt den konkreten Bearbeitungszweck jetzt als `Edit Saved Track`
- [x] Trennung zwischen importierter History und lokal gespeicherten Tracks wird in den Begleittexten expliziter gemacht
- Bewusst nicht in diesem Schritt: neue Track-Funktionen, Merge in importierte History, Background-Resume

### Phase 19.35 – Day-Detail-Hierarchie

**Datum:** 2026-03-20
**Ziel:** Importierte Tagesdaten, Live-Recording und Track-bezogene Nebenfluesse im Day Detail klarer staffeln.

- [x] Quick-Stats direkt unter Header/Zeitraum gezogen
- [x] expliziter Abschnitt `Imported Day Data` vor Karte, Timeline und importierten Sections
- [x] `AppLiveLocationSection` unter die importierten Visits/Activities/Routes verschoben
- [x] separater Kontextblock `Local Recording` fuer foreground-only Aufnahme und gespeicherte Live-Tracks
- [x] keine neue Business-Logik, nur klare Trennung zwischen importierter History und lokalem Recording
- Bewusst nicht in diesem Schritt: neue Track-Funktionen, Background-Tracking, Import-Merge

### Phase 19.34 – Days List / Export-Koharenz

**Datum:** 2026-03-20
**Ziel:** Day-List-, Such- und Exportzustand visuell klarer zusammenfuehren, ohne die vorhandene Days-Navigation neu zu bauen.

- [x] Export-Selektion in Day Rows jetzt als deutlicheres `Export`-Badge statt nur als kleines Icon
- [x] exportierte Tage erhalten zusaetzlich eine subtile visuelle Hervorhebung in der Liste
- [x] compact `Days` zeigt bei aktiver Export-Selektion einen eigenen Export-Hinweis mit direktem Sprung in den Export-Tab
- [x] regular-width `Days` zeigt denselben Export-Kontext oberhalb der Liste
- [x] Such- und Leerzustaende bleiben erhalten, werden aber nicht mehr vom Exportzustand optisch verdraengt
- Bewusst nicht in diesem Schritt: neue Exportformate, per-route Auswahl, neue Filterlogik

### Phase 19.33 – Overview-Informationsarchitektur / Primaeraktionen

**Datum:** 2026-03-20
**Ziel:** Overview wieder staerker als Startpunkt fuer Status und Hauptnavigation ausrichten, ohne bestehende Inhalte zu verlieren.

- [x] `AppSessionStatusView` an den Anfang der Overview geholt
- [x] neue Sektion `Primary Actions` fuer `Open`, `Browse Days`, `Open Insights` und `Export GPX`
- [x] compact Overview kann jetzt direkt in die Kernbereiche springen statt nur Informationen zu zeigen
- [x] regular Overview behaelt denselben Primarfluss und oeffnet Export ueber das bestehende Sheet
- [x] Track-Library-/Track-Editor-Einstieg bleibt sichtbar, ist aber klar hinter Status, Primaeraktionen, Highlights und Statistik eingeordnet
- Bewusst nicht in diesem Schritt: neue Importquellen, neue Track-Features, iPad-spezifische Neustrukturierung

### Phase 19.32 – Insights Empty / No-Data Hardening

**Datum:** 2026-03-20
**Ziel:** Insights auch bei duennen oder unvollstaendigen Daten als klares Produktverhalten statt als halbleere Seite darstellen.

- [x] page-level Empty State fuer Imports ohne Day-Summaries
- [x] explizite section-level Empty States fuer fehlende Distanz-, Activity-, Visit-, Weekday- und Period-Daten
- [x] Daily Averages zeigen jetzt einen klaren Hinweis statt still zu verschwinden, wenn weniger als zwei Tage vorliegen
- [x] Charts zeigen einen erklaerenden Fallback fuer no-chart-/low-data-Faelle statt leerer Flaechen
- [x] `Limited Insight Data`-Hinweis fuer duenne, technisch gueltige Imports
- Bewusst nicht in diesem Schritt: neue Analysemetriken, Export/Share fuer Charts, Cross-Filtering

### Phase 19.31 – Navigation / Dead-End Hardening

**Datum:** 2026-03-19
**Ziel:** Day-Navigation und Auswahlverhalten fuer iPhone/regular width so haerten, dass no-content-Tage und implizite Dead Ends nicht wie normale Detailziele behandelt werden.

- [x] `DaySummary` fuehrt jetzt repo-wahr `hasContent`, abgeleitet aus Visits/Activities/Paths
- [x] `AppSessionContent` waehlt nach Import/Demo bevorzugt den ersten inhaltshaltigen Tag statt blind den ersten Kalendertag
- [x] `selectDayForDisplay(_:)` fuehrt UI-sichere Tagesauswahl ein und verwirft no-content-Ziele statt leere Detailnavigation zu erzwingen
- [x] compact `Days`-Navigation oeffnet nur noch Tage mit echtem Inhalt; no-content-Tage bleiben sichtbar, aber nicht tappbar
- [x] regular-width `Days`-Liste deaktiviert no-content-Tage als Detailziele und zeigt einen expliziten Rueckweg zur `Overview`
- [x] Export-Badge in gruppierter und ungruppierter Day-Liste jetzt konsistent
- [x] 2 neue Session-State-Tests und erweiterte Query-Assertions decken contentful-first Auswahl und no-content-Verhalten ab
- Bewusst nicht in diesem Schritt: Insights-No-Data-States, Day-Detail-Umbau, neue Exportformate oder Background-Tracking

### Phase 19.28 – Lokale Optionen / Produktsteuerung

**Datum:** 2026-03-19
**Ziel:** Eine echte Optionen-Seite fuer die iPhone-App einfuehren, mit wenigen glaubwuerdigen lokalen Einstellungen statt Fake-Toggles.

- [x] Neue `AppPreferences`-Domain auf Basis von `UserDefaults`
- [x] Option fuer Distanz-Einheit (`Kilometers` / `Miles`)
- [x] Option fuer den Start-Tab auf iPhone (`Overview`, `Days`, `Insights`, `Export`)
- [x] Option fuer den bevorzugten Kartenstil (`Standard`, `Satellite Hybrid`)
- [x] Option zum Ein-/Ausblenden technischer Importdetails
- [x] `AppOptionsView` als echte Optionen-Seite mit Bereichen fuer Darstellung, Karten, Privacy und Technical
- [x] Optionen im Core-App-Einstieg und im Wrapper ueber das bestehende Actions-Menue erreichbar
- [x] App-weite Wirkung: Distanz-/Speed-Formatierung, Kartenstil, Start-Tab und technische Metadaten folgen jetzt denselben lokalen Preferences
- [x] 4 neue Tests fuer Default-Werte, Persistenz, Reset und Fallback-Handling; `swift test` jetzt 135/135 gruen
- Bewusst nicht in diesem Schritt: Cloud-/Sync-/Server-Toggles, Background-Location-Optionen, Fake-Privacy-Controls

### Phase 19.30 – Live Recording MVP: aktueller Standort, foreground-only Track, getrennte Persistenz

**Datum:** 2026-03-18
**Ziel:** Nutzer kann den eigenen Standort auf der Karte anzeigen, foreground-only live aufzeichnen und den Track getrennt von importierter History lokal speichern.

- [x] `LiveLocationFeatureModel`: klar getrennte Recording-Domain ausserhalb von `AppSessionState`
- [x] `SystemLiveLocationClient`: `CLLocationManager`-Adapter mit while-in-use-Fokus, ohne Background-Mode
- [x] `LiveTrackRecorder`: Accuracy-/Duplikat-/Mindestdistanz-/Flood-Filter fuer Live-Punkte
- [x] `RecordedTrackFileStore`: dedizierte JSON-Persistenz fuer abgeschlossene Live-Tracks (`RecordedTracks/recorded_live_tracks.json`)
- [x] `AppLiveLocationSection`: Toggle, Permission-State, aktueller Standort, Live-Polyline, gespeicherte Live-Tracks
- [x] Integration in `AppDayDetailView` / `AppContentSplitView` / Wrapper-App
- [x] Wrapper-Info.plist: `NSLocationWhenInUseUsageDescription` fuer lokale While-In-Use-Funktion
- [x] 13 neue Tests (Recorder, Store, FeatureModel); `swift test` jetzt 125/125 gruen
- Bewusst nicht in diesem Schritt: Background-Tracking, Auto-Resume nach Neustart, Merge in importierte History, Export aufgezeichneter Live-Tracks

### Phase 19.29 – Export MVP: GPX-Export mit app-weiter Tages-Selektion

**Datum:** 2026-03-18
**Ziel:** Nutzer kann Tage fuer GPX-Export markieren und Datei per System-Share-Sheet speichern/teilen.

- [x] `GPXBuilder` (Core): GPX 1.1, Path.points → Tracks, XML-Escaping, Dateinamen-Helfer
- [x] `ExportSelectionState` (AppSupport): Value-Type Set<String>, in AppSessionState eingebettet
- [x] `GPXDocument: FileDocument` fuer fileExporter-Flow
- [x] `AppExportView`: Tage-Liste mit Checkboxen, Select All/Deselect All, GPX-Format-Badge,
      Export-Button (disabled bei leerer Auswahl oder keine Routes), Fehlermeldung, Empty State
- [x] `ExportFormat` Enum: GPX jetzt aktiv, Architektur fuer KML/CSV/etc. vorbereitet
- [x] 4. Tab "Export" (iPhone/compact) mit Badge fuer ausgewaehlte Tage
- [x] "Export..." Menueintrag + Sheet fuer iPad/regular Layout
- [x] AppDayRow: Export-Badge-Icon wenn Tag fuer Export markiert
- [x] 16 neue Tests (GPXBuilder + ExportSelectionState); 112/112 gruen
- Bewusst nicht in diesem Schritt: Visits als Waypoints, per-Track-Selektion, KML/CSV

### Persistenz-Status
Auto-Restore (ImportBookmarkStore) ist technisch implementiert und funktioniert korrekt (Phase 15).
Aktuell repo-wahr aktivierbar: die App startet weiterhin manuell, solange `Restore Last Import on Launch` deaktiviert bleibt; bei aktivem Toggle wird der letzte erfolgreiche Import opt-in automatisch wiederhergestellt.
Recent Files sind im import-first Startzustand sichtbar und koennen dort erneut geoeffnet, einzeln entfernt oder komplett geleert werden.
Recorded Live-Tracks sind jetzt separat aktiv: save-on-stop in einem dedizierten Store, ohne Draft-Persistenz und ohne Auto-Resume.

### Phase 19.21b – Google Timeline JSON direkt importierbar

**Datum:** 2026-03-18
**Ziel:** Google Location History JSON (`location-history.json`) direkt importierbar (ohne ZIP-Verpackung).

- [x] `decodeFile`: erkennt JSON-Array-Root → probiert `GoogleTimelineConverter.convert` vor `AppExportDecoder`
- [x] `GoogleTimelineConverter.convert`: `hasValidEntry`-Guard – leere Arrays und `[{}]` ohne `startTime` werfen `notGoogleTimeline` (→ `unsupportedFormat`)
- [x] Real getestet: `location-history.json` mit 64.926 Eintraegen importiert korrekt
- [x] 2 neue Tests (`testImportsGoogleTimelineJsonDirectly`, `testRealLocationHistoryJsonOnDesktop`); 96/96 gruen

**Problem vorher:** Direkte JSON-Datei mit Array-Root warf sofort `unsupportedFormat`. Nur ZIP-Verpackung funktionierte.

---

### Phase 19.21 – Google Timeline ZIP direkt importierbar

**Datum:** 2026-03-18
**Ziel:** Google Takeout ZIP (`location-history.zip`) direkt in der App oeffnen ohne vorherige Konvertierung.

- [x] `GoogleTimelineConverter`: konvertiert Google Timeline JSON-Array → AppExport per JSON-Dictionary-Roundtrip
- [x] `loadGoogleTimelineFromZip`: Fallback wenn kein LH2GPX-Export im ZIP; bevorzugt `location-history.json` bei Mehrdeutigkeit
- [x] `isGoogleTimeline`: prueft Array-Root; `convert` prueft zusaetzlich auf mindestens einen gueltigen `startTime`-Eintrag
- [x] Unterstuetzt: `visit`, `activity`, `timelinePath`-Eintraege; `geo:lat,lon`-Format; `distanceMeters` als String oder Double
- [x] ISO8601-Parser mit und ohne Bruchteile; Zeitzonenoffsets (`+02:00`) korrekt behandelt
- [x] Real getestet: `location-history.zip` (64.926 Eintraege) importiert korrekt
- [x] 6 neue Tests fuer Google Timeline ZIP; 94/94 gruen

**Problem vorher:** ZIP musste einen LH2GPX-App-Export enthalten. Google Takeout ZIPs wurden mit `jsonNotFoundInZip` abgewiesen.

---

### Phase 19.20 – ZIP-Import: Dateiname-agnostisch

**Datum:** 2026-03-18
**Ziel:** ZIP-Import nicht mehr auf exakten Dateinamen `app_export.json` beschraenken.

- [x] `loadZipContent`: alle `.json`-Kandidaten im ZIP sammeln (case-insensitive, `__MACOSX/` + Hidden-Files ignoriert)
- [x] Jeden Kandidaten inhaltlich gegen AppExportDecoder pruefen (Contract unveraendert)
- [x] 0 gueltige → `jsonNotFoundInZip`; 1 gueltige → laden; mehrere gueltige → `app_export.json` bevorzugen, sonst `multipleExportsInZip`
- [x] Neuer Error-Case `multipleExportsInZip` mit `userFacingTitle` + `errorDescription`
- [x] `jsonNotFoundInZip` errorDescription nennt nicht mehr `app_export.json` als Pflicht
- [x] 7 neue Tests; 88/88 gruen
- [x] Wrapper README aktualisiert

**Problem vorher:** `loadZipContent` suchte exakt `app_export.json` an Root oder als `/app_export.json`-Pfadsuffix. Jede andere Benennung fiel durch.

---

### Phase 19.18 – Searchable Days List Dark Mode Fix

**Datum:** 2026-03-18
**Ziel:** Schwarz-Bug in der Days-List bei Sucheingabe beheben.

- [x] compactDayList: immer `List` als Root-View
- [x] No-Results-State und Empty-State als `.overlay` auf der List statt als VStack-Ersatz
- [x] Dark-Mode-Hintergrund der List bleibt korrekt bei jeder Sucheingabe erhalten

**Problem vorher:** compactDayList wechselte bei leerer Suche zwischen `List` (mit Hintergrund) und `VStack` (ohne Hintergrund). Im Dark Mode erschien der nackte NavigationStack-Hintergrund als schwarze Flaeche.

---

### Phase 19.17 – Import Entry / Error UX Hardening

**Datum:** 2026-03-18
**Ziel:** Fehlerbehandlung beim Import verbessern. Fehlertitel je Error-Typ spezifisch statt generisch. emptyStateView-Text nutzerfreundlicher.

- [x] `userFacingTitle` in `AppContentLoaderError` pro Case: "Unable to read file" / "Unsupported file format" / "File could not be opened" / "No export found in ZIP" / "Demo data unavailable"
- [x] Alle `errorDescription` Werte actionable und nutzerfreundlich; `jsonNotFoundInZip` erklaert Konvertierungs-Workflow
- [x] `loadImportedFile` in ContentView.swift (Wrapper) nutzt `userFacingTitle` statt generischem Titel
- [x] `loadImportedFile` in AppShellRootView.swift (Core) nutzt `userFacingTitle` statt generischem Titel
- [x] emptyStateView-Text in ContentView.swift und AppShellRootView.swift verbessert
- [x] 5 neue Tests fuer `userFacingTitle` + `jsonNotFoundInZip`-Beschreibung; 81/81 gruen

**Problem vorher:** Alle Import-Fehler zeigten denselben generischen Titel "Unable to open app export". Nutzer konnten nicht unterscheiden ob die Datei kaputt, falsch formatiert, oder kein app_export.json enthalten war.

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
- [x] AppContentLoader: loadImportedContent erkennt .zip per Dateiendung; loadZipContent sucht alle .json-Kandidaten im ZIP (dateiname-agnostisch, __MACOSX ignoriert)
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

**Nicht-Ziele:** In dieser damaligen Phase keine Heatmap. Kein Replay/Animation. Keine eigene Tile-Engine. Kein Offline-Map-Cache.

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

**Jetzt:** Jeder App-Start beginnt mit dem manuellen Einstieg (Open location history file / Load Demo Data). Persistenz-Logik ist vollstaendig erhalten und kann jederzeit wieder aktiviert werden.

**Spaeterer Repo-Truth:** Diese Phase bleibt als historischer Zwischenstand korrekt, ist aber nicht mehr der aktuelle Gesamtstatus. Die Core-App-Shell haelt Auto-Restore weiter geparkt, der Wrapper hat `restoreBookmarkedFile()` am 2026-03-20 wieder aktiviert und braucht dafuer eine frische Device-Verifikation.

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

**Historischer lokaler Nachweis (2026-03-17):** `xcodebuild archive` erfolgreich (v1.0, Build 1). `PrivacyInfo.xcprivacy` war vorhanden und dokumentierte lokal sichtbar kein Tracking plus UserDefaults CA92.1. Die damalige Review-Notiz war nur eine lokale Arbeitsbewertung und kein belastbarer Apple-Freigabeclaim. App Icon ersetzt (Map-Pin + LH2GPX, kein Gradient-Placeholder mehr). Screenshot-Simulator-Workflow dokumentiert. TestFlight-Runbook in `docs/TESTFLIGHT_RUNBOOK.md` im Wrapper-Repo.

**Lokal abgeschlossen (2026-03-17):** Screenshots via UI-Test erstellt (iPhone 17 Pro Max + iPad Pro 13" M5, iOS 26.3.1). Liegen in `docs/appstore-screenshots/` im Wrapper-Repo.

**Extern – bewusst geparkt (2026-03-17):** ASC-Zugang aktuell nicht verfuegbar. Verbleibend: App Store Connect Projekt anlegen, Metadaten eintragen, Upload, TestFlight-Beta aktivieren.

**Update 2026-04-29:** lokaler Transporter-Upload weiterhin ungueltig (`Invalid Signature` fuer `LH2GPXWrapper` + `LH2GPXWidget`). Repo-Signing fuer den Xcode-Cloud-Pfad wurde auf `Automatic` + Team `XAGR3K7XDJ` bereinigt; der Workflow `Release – Archive & TestFlight` ist angelegt und jetzt der bevorzugte Uploadpfad. Phase 20 bleibt offen, bis ein echter Build in App Store Connect erscheint.

**Update 2026-04-29 (Overview-/Explore-Map):** die frisch gepushte interaktive Overview-Karte wurde nachauditert und gehaertet: kein Re-Scan bei Pan/Zoom, Viewport-Auswahl per Bounding-Box-Intersection, stale Overlay-Tasks werden bei Neu-Load verworfen, Explore-Dismiss setzt wieder Full-View-Overlays. Der Batch liefert nur Code-/Test-/Xcode-Nachweise, keine neuen Device-Claims.

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

7. **Monorepo-Architektur-Grenze ehrlich abbilden.** Phasen, die den `wrapper/`-Bereich betreffen, muessen das klar benennen. Der Core-Root bleibt die Library-Quelle; kein Xcode-spezifischer Code wandert in den Core.

8. **Phase-8-Restpunkt `Produkt-UI` ist nach Phase 17 abgeschlossen.** Der offene Punkt aus Phase 8 wird nicht nachtraeglich abgehakt, sondern durch Phase 17 abgeloest.

9. **Apple-/ASC-/TestFlight-/Release-Themen bleiben geparkt.** Phasen 20 und 21 werden erst aktiviert, wenn Developer-Account-Zugang tatsaechlich vorhanden ist. Kein Checkbox-Update in diesen Phasen solange der Zugang fehlt.
