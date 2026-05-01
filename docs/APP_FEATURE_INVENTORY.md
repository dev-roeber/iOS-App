# APP Feature Inventory

Last analysis: 2026-05-01 (truth sync)

Repos in scope:
- `dev-roeber/iOS-App`: active repo truth for the integrated app + wrapper

Governance:
- Only document what is verifiable in repo/app.
- Do not list wishes, planned work or speculative wrapper behavior as present features.

## 1. App-Struktur / Navigation

Present:
- Import-first root screen when no content is loaded
- import-first root can show a visible recent-files list with reopen, remove-entry and clear-history actions
- import-first root now uses the visible LH2GPX redesign: large `LH2GPX` title, short subtitle, prominent blue `Import File` primary action, dark help/demo rows and a dark `Recently Used` card
- shared toolbar `Actions` menu for primary app commands
- compact layout uses `TabView` with `Overview`, `Days`, `Insights`, `Export` and on iOS 17+ `Live`
- compact tabs each run inside their own `NavigationStack`, including the optional `Live` tab on iOS 17+
- regular-width layout uses `NavigationSplitView` with a day list and a detail pane
- regular-width day detail exposes an explicit `Overview` return action above the selected day
- modal sheets exist for `Options`, `Export` (regular width), `Heatmap` and the recorded-tracks library
- the recorded-tracks library is directly reachable from Overview, the shared `Actions` menu and the live-recording area in day detail
- a separate SwiftUI demo app exists beside the product shell
- Deep Link `lh2gpx://live`: URL schema `lh2gpx://` via `CFBundleURLTypes` in `Info.plist` registriert; `onOpenURL`-Handler in `ContentView` leitet zu `handleDeepLink()`; `LiveLocationFeatureModel.navigateToLiveTabRequested` triggert `AppContentSplitView`-Observer, der auf compact iPhone den dedizierten `Live`-Tab auswaehlt

Not present:
- dedicated onboarding flow or walkthrough
- custom bottom-sheet navigation model

## 2. Import-Funktionen

Present:
- local file import via system file importer
- product app accepts `.json`, `.zip`, `.gpx`, and `.tcx`
- supported content types: LH2GPX `app_export.json`, LH2GPX export ZIP, Google Timeline `location-history.json`, Google Timeline ZIP, GPX 1.1 track files, TCX 2.0 track files
- GPX import: parses `<trk>/<trkseg>/<trkpt>` + `<wpt>`; groups points by local calendar date; waypoints become Visit entries
- TCX import: parses `<TrainingCenterDatabase>/<Activity>/<Lap>/<Track>/<Trackpoint>/<Position>`; groups by local calendar date
- GPX/TCX files inside ZIP archives are also extracted and parsed
- ZIP import is filename-agnostic for compatible JSONs
- user-facing import error titles for unsupported format, unreadable file, decode failure, empty ZIP and multiple exports in ZIP
- bundled demo fixture can be loaded as fallback
- imported file bookmark is saved after a successful import
- recent files are persisted after successful imports and exposed in the empty import-first state
- recent-file reopen removes stale or unavailable entries instead of surfacing raw bookmark failures
- auto-restore of the last import exists as an opt-in startup path controlled by `AppPreferences.autoRestoreLastImport`
- missing or stale last-import bookmarks are skipped gracefully during auto-restore

Not present:
- FIT format import (no maintainable Swift library without external dependency; deliberate follow-up)
- GeoJSON import (as import source; export remains present; deliberate follow-up)
- drag-and-drop import UI
- multi-file import UI

## 3. Overview / Dashboard

Present:
- overview screen uses the LH2GPX redesign with a large page title, dark cards and true-black background
- visible import-status/source card with active file and optional technical disclosure
- visible global time-range card with current range, reset action and quick chips for `Last 7 Days`, `Last 30 Days`, `Last 90 Days` and `This Year`
- KPI grid for distance, active days, routes and places
- highlights card for busiest day, longest distance and most activities plus a direct jump into insights
- continue/quick-action card for day browsing, insights, export and opening another file
- active-filter banner when export filters are present in metadata
- overview entry card for the `Saved Live Tracks` local library
- heatmap entry in the overview is a compact Capsule chip, aligned with the existing filter/status chip language instead of a larger dedicated action card
- favorites-only Capsule toggle appears below the time-range when at least one day is favorited
- `LHCollapsibleMapHeader` is now used as the actual overview-map shell; hidden state keeps the performance invariant that the map builder is not evaluated
- `AppOverviewTracksMapView` still provides the async interactive polyline overview map for all tracks in the active range (iOS 17+); loads off-main-thread via `Task.detached`; caches candidates once per data/filter change and rebuilds overlays on pan/zoom without re-scanning the export; uses viewport bounding-box intersection (not midpoint-only) so long routes crossing the visible region stay prioritizable; uses the existing tiered render profile (Douglas-Peucker simplification + stride decimation per route + hard `overlayLimit` cap) to keep MapKit within safe overlay and coordinate counts even for "All Time" on large datasets; `overlayLimit × maxPolylinePoints` = implicit global coordinate cap (9.600–48.000 per tier); shows `Simplified preview · export complete` when the cap fires; export data never affected; shows phase-based loading card with linear ProgressView

Not present:
- dedicated onboarding dashboard state distinct from the import-first root
- customizable overview modules or reordering

## 4. Days / Day List

Present:
- day list is repo-wahr sorted newest-first (`neu -> alt`) derived from export days
- month grouping when multiple months are present
- search on compact and regular day lists by date, formatted date, weekday and month text
- day list uses the visible LH2GPX dark redesign: large `Days` title, true-black background, compact context row for active range and search, and dark cards with hairline borders
- filter chips exposed in the visible redesign are `All`, `With Routes`, `Favorites`, `Exported`
- an optional collapsible map header sits above the month groups and reuses the existing projected/filtered day-map context; hidden state keeps the invariant that no map view is instantiated
- day rows show a large day number, weekday, formatted date, optional time range, separate places/routes/activities/distance metrics, a chevron, and visually separate favorite vs. exported status
- no-content days stay visible in the list, but show a dedicated `No recorded entries` hint
- no-content days are not treated as normal detail targets in compact or regular navigation
- compact list can show highlight icons for busiest/longest day
- day rows support export-selection badge state and subtle highlight treatment in grouped and ungrouped layouts
- compact and regular day lists show an explicit export-context banner when selected days exist
- compact `Days` can jump back to the current day when the already selected tab is tapped again on iPhone
- regular-width list supports selection-driven detail display
- **Days tab respects the global history date range filter** (same `historyDateRangeFilter` as Overview/Insights/Export); active filter is shown as a visible `HistoryDateRangeFilterBar` chip in the compact list and a toolbar item in the regular split view
- empty state when range filter is active and yields no days: `"No Days in Range"` headline with hint to adjust the range
- search, filter chips, favorites and newest-first ordering apply correctly on the range-projected day list

Not present:
- manual sorting beyond the repo-wahr fixed newest-first order
- filter chips for activity types / semantic types directly in the list

## 5. Day Detail

Present:
- day detail uses a visible map-first layout with `AppDayMapView` directly under navigation
- map controls remain available on the right side of the map area, including path display mode (`.original` / `.mapMatched`) and map style controls
- weekday/date header
- derived day time range when timed entries exist
- KPI cards for distance, routes, activities and places
- segment switcher for `Overview`, `Timeline`, `Routes` and `Places`
- a visible timeline card summarises start, route/drive and visit flow plus end when timed data exists
- explicit separation between imported day data and local live-recording utilities
- structured sections for visits, activities and routes
- colored cards for visit/activity/route items
- empty states for `Select a Day`, `No Day Entries` and `Nothing Recorded`
- day timeline/Gantt visualization for visits and activities
- day detail is only entered for contentful days; empty calendar days remain list-only
- live recording section can appear inside day detail on supported platforms
- favorite toggle, sharing/export entry, route visibility, per-route export selection and display-only imported-route removal remain reachable from day detail

Not present:
- inline editing of imported visits / activities / routes
- route drill-down per segment
- photos, notes or attachments for a day

## 6. Maps

Present:
- day-detail map for visit markers and route polylines on supported Apple platform versions
- fitted region computed from available coordinates
- visit-marker tinting by semantic type
- route color coding by activity type
- map style toggle between standard and satellite hybrid
- live-location map with current-position marker and live polyline while recording
- recenter/follow action for the live-location map
- fullscreen live map mode
- dedicated `Heatmap` sheet for imported history on iOS 17+/macOS 14+ with precomputed LOD grids, smoothed aggregated polygon cells, viewport-capped cell selection, calmer low-zoom rendering, local opacity/radius controls, `fit to data`, a small density legend, and stronger nonlinear opacity/intensity/color mapping with earlier low-/mid-density hue separation so sparse detail zoom stays visible and more differentiated instead of fading to near-grey
- Heatmap Mode and Radius controls rendered as Capsule chip buttons (matching `AppDayFilterChipsView` style); control overlay is scrollable in landscape via `ScrollView(.vertical)`

- path display mode toggle in day-detail map: `.original` (raw coordinates) vs. `.mapMatched` (`Simplified`); persisted via `AppDayPathDisplayMode` in UserDefaults; Steuerzeile kombiniert Picker + Map-Style-Toggle in einer `mapControlRow` (kein separates Globe-Overlay mehr)
- in `.mapMatched` mode: GPS outlier pre-filter (`PathFilter.removeOutliers`, distance-based, default maxJumpMeters=5000) applied before Douglas-Peucker simplification (epsilon=15m); fallback to original sequence if fewer than 2 points remain after filtering
- NOTE: no road/path network snapping; `Simplified` is geometric simplification + outlier filtering only
- Layout-Bugfix 2026-04-14: `GeometryReader` aus `AppDayRow` (List-Overlap-Bug) und `AppDayDetailView.contentView` (zero-height-Bug in ScrollView) entfernt; outer `ScrollView` aus compact Nav-Destination entfernt; Layout-Erkennung jetzt via `@Environment(\.verticalSizeClass)`
- Historien-Track-Editor Overlay: `ImportedPathDeletion` + `ImportedPathMutationSet` (Codable), `AppImportedPathMutationStore` (`@StateObject` in `AppContentSplitView`, UserDefaults JSON-Persistenz, duplicate-safe `addDeletion`, `validateSource(_:)` für Import-Wechsel-Invalidierung, `reset()`); "Route entfernen"-Button + Confirmation-Alert in `AppDayDetailView` (Portrait + Landscape); filteredDetail + resolvedMapData für konsistente Karten-Anzeige; original `AppExport` bleibt unverändert; Export ignoriert Mutations bewusst (display-only overlay); bei Import-Wechsel (anderer Dateiname) werden Mutations automatisch zurückgesetzt, bei gleichem Dateinamen nach App-Neustart bleiben sie erhalten

Not present:
- offline tile packs
- persistent heatmap overlay toggle inside the day-detail map
- persistent heatmap display preferences across launches

## 6a. Local Recording / Saved Live Tracks

Present:
- live recording with current-position marker and live polyline
- dedicated `Live` tab on compact iOS 17+ with separate cards for map, recording, upload, saved tracks and advanced options
- interrupted-session banner appears only for a valid persisted live-recording session (`sessionID` + `sessionStartedAt`); malformed or partial restore defaults are cleared defensively
- Live Activity / Dynamic Island options expose a persisted primary value selection: `Distance`, `Duration`, `Points` or `Upload Status`
- options surface Live Activity availability explicitly and disable the configuration on unsupported / disabled devices instead of leaving a dead control
- hardware verification status: `iPhone 15 Pro Max` (`iOS 26.4`, Debug-Build) confirms recording start plus Dynamic Island `compact`/`expanded` for `Distance` and end/dismiss after stop; lock screen, `minimal`, additional primary values and fallback paths remain open
- status chips for recording state, foreground/background state, upload state and queued points
- quick actions for centering the live map, pausing/resuming uploads, manually flushing the upload queue and opening the saved-track library
- live stats include accuracy, duration, points, distance, current speed, average speed, last segment and update age
- live-recording options can change accepted accuracy and capture density for the local recorder
- live-recording minimum time gap is configurable (seconds/minutes/hours) via Options; `0` disables the hard floor (`No minimum`) and the setting has no numeric upper clamp (`Maximum Time Gap: Unlimited`)
- background live recording can be enabled in local settings and becomes active when the app has `Always Allow` authorization
- accepted live-recording points can optionally be sent to a user-configured HTTP(S) endpoint with an optional bearer token
- permission/status card and record toggle inside day detail
- upload area can show ready, invalid-endpoint, paused, uploading, retry-pending, queued, last-success and last-failure states when server upload is enabled
- Live Activity state propagation includes upload status and pause state (`disabled`, `active`, `pending`, `failed`, `paused`) instead of distance / points only
- completed recordings are persisted as separate local `Saved Live Tracks`
- dedicated recorded-tracks library page with summary, latest-track preview and editor navigation
- saved-track editor supports point editing, midpoint insertion and delete
- live-recording area links into the separate library instead of duplicating a second inline editor flow
- **Live Tracking + Library Redesign (2026-05-01):** `AppLiveTrackingView` and `AppRecordedTracksLibraryView` fully ported to LH2GPX dark design system
- `LHLiveBottomBar` — sticky `.safeAreaInset(edge: .bottom)` CTA bar; mint tint when idle (Start), red tint when recording (Stop); `accessibilityIdentifier` `live.cta.start` / `live.cta.stop`
- `LHLiveTrackRow` — dark card row wrapping `SavedTrackSummaryContentView` with `LH2GPXTheme.card` surface and `cardBorder` overlay; used in the library list
- `AppLiveTrackingView` map card uses mint polyline (`LH2GPXTheme.liveMint`) and `live.map` accessibility identifier
- status chips row exposes four named identifiers: `live.status.gps`, `live.status.upload`, `live.status.follow`, `live.status.ready`
- recording card (no embedded button) shows duration in mint; four metric identifiers: `live.metric.distance`, `live.metric.duration`, `live.metric.points`, `live.metric.averageSpeed`
- upload quick actions include pause button with `live.cta.pause` identifier
- saved-tracks preview card has `live.savedTracks.preview` and `live.savedTracks.openAll` identifiers
- `AppRecordedTracksLibraryView` uses `ScrollView` + `LHPageScaffold` replacing the previous `List`; navigation title "Live Tracks"; `liveTracks.title`, `liveTracks.info`, `liveTracks.list`, `liveTracks.row.<index>`, `liveTracks.newTrack` accessibility identifiers
- `LiveTrackingPresentation.gpsStatusLabel(accuracyM:)` — returns `"GPS Good"` (< 30 m) or `"GPS Weak"`
- `LiveTrackingPresentation.uploadSectionVisible(sendsToServer:pendingCount:statusMessage:)` — visibility predicate for the upload section
- **Options + Widget/Live Settings Redesign (2026-05-01):** `AppOptionsView` vollständig auf NavigationLink-Grid mit 8 modularen Section-Rows umgestellt
- `RecordingPreset` enum (`battery`, `balanced`, `precise`, `custom`) als Computed-Property auf `AppPreferences`; deterministisch aus `liveTrackingAccuracy` + `liveTrackingDetail`; kein neuer UserDefaults-Key
- `LHOptionsSectionRow` — dunkle Card-Zeile mit Icon-Badge, Titel, Beschreibung, Chevron
- `LHLiveRecordingPresetSelector` — horizontale Chip-Leiste für 4 Presets (farbkodiert)
- `LHUploadSettingsCard` — Upload-Toggle + URL-Feld + `SecureField` (Bearer-Token nie im Klartext) + Batch-Picker + Status-Dot
- `LHDynamicIslandPreviewCard` / `LHWidgetPreviewCard` — Info-Cards für Dynamic Island und Home Widget
- `OptionsPresentation` — statische Helpers `uploadStatusText`, `uploadStatusColor`, `serverUploadPrivacyText`
- Bearer-Token: ausschließlich als `SecureField` in der UI; `LiveLocationServerUploadConfiguration.trimmedBearerToken` gibt bei leerem/whitespace-only Token `nil` zurück (kein Authorization-Header)
- Accessibility-Identifiers: `options.title`, `options.livePreset.*`, `options.upload.*`, `options.dynamicIsland.*`, `options.widget.preview`

Not present:
- auto-resume of in-progress recordings after relaunch
- merging saved live tracks back into imported history

## 7. Insights / Statistiken / Diagramme

Present:
- segmented insight surface with `Overview`, `Patterns` and `Breakdowns`
- large `Insights` title with bold heading; LH2GPX dark-redesign applied (LH2GPXTheme card surface, hairline borders, semantic colors)
- focused 4-KPI grid (Distance / Active Days / Routes / Places) via `LHMetricCard`; accessibility identifiers `insights.kpi.*`
- active filter context shown via `LHContextBar`; date range control with `insights.range` identifier
- share button identifiers updated to `insights.share.<cardType>` for per-section targeting
- drilldown labels updated: "Open in Days", "Select for Export", "Show on Map"
- `dayDrilldownTargets` now uses full triple (Days + Map + Export)
- new `LHInsightsMetricGrid`, `LHInsightsChartCard`, `LHInsightsTopDayRow`, `LHInsightsActionRow` components in `LHInsightsComponents.swift`
- highlight cards for busiest day, most visits, most routes and longest distance
- top-days module with switchable ranking metrics; shows up to 20 entries (limit raised from 5)
- monthly-trends module with switchable metrics derived from visible days and no fixed 24-month cap
- distance-over-time chart when distance data exists; prefers imported route totals and otherwise falls back to recorded path/trace geometry where verifiable
- daily averages cards when at least two days exist
- activity-type breakdown cards
- activity-type chart with `Count` / `Distance` toggle
- visit-type chart and list
- weekday chart when enough day data exists, with switchable `Events` / `Routes` / `Distance` metrics
- period breakdown cards and chart when period stats exist, with switchable `Days` / `Events` / `Distance` metrics
- explicit empty-state/fallback messaging for no-days, low-data and section-unavailable insight cases
- visible chart hints/labels for tap navigation, selected metric context and weekday averages
- visible global time-range control reusing the shared app session filter
- insights are built from decoded stats with day-level fallbacks where implemented
- visible cross-filter drilldown from data-anchored insight elements into `Days` or `Export`
- visible drilldown-state banners with reset action in the receiving `Days` and `Export` flows
- visible share actions for the key insights sections backed by `ChartShareHelper`

Not present:
- custom chart density controls
- map-linked cross-filtering from insights
- Linux-verifiable end-to-end Apple share-sheet proof

## 8. Optionen / Einstellungen

Present:
- distance-unit preference
- start-tab preference for compact layout
- default map-style preference
- widget/live-activity settings section including Dynamic-Island compact display preference
- toggle for showing technical import details
- live-recording accuracy filter preference
- live-recording detail preference for movement/time capture density
- live-recording minimum-time-gap preference (seconds/minutes/hours) with `0 = No minimum` and no upper clamp
- toggle for allowing background live recording
- app-language preference with `English` / `Deutsch`
- broad UI localization across shell, options, status UI, day list/detail, saved-track library/editor, live-recording and large parts of export/insights
- toggle for restoring the last import on launch
- toggle for optional live-location server upload
- configurable server URL and optional bearer token for live-location upload
- upload-batch preference for `Every Point`, `Every 5 Points`, `Every 15 Points` or `Every 30 Points`
- reset-to-defaults action
- privacy info section clarifying local storage by default, optional server upload and optional background live recording after `Always Allow`

Not present:
- sync/server toggles
- full end-to-end localization coverage across every string in the app
- per-chart or per-screen visual customization

## 9. Export / Teilen / Server / Sync

Present:
- dedicated `Export` tab on compact layout
- export sheet entry on regular width
- multi-day selection with `Select All` / `Deselect All`
- saved live tracks can be selected in the same export flow
- visible global time-range section clarifies that export uses the active app-wide range before local export filters
- local export filters for imported history by date window, maximum accuracy, required content, activity type, bounding box and polygon
- export mode picker for `Tracks`, `Waypoints` and `Both`
- export preview map for the current selection with route and waypoint context
- system `fileExporter` flow
- GPX, KMZ, KML, GeoJSON and CSV generation from selected imported days and selected saved live tracks
- waypoint export from imported visits plus activity start/end coordinates
- suggested export filename based on selected days, saved tracks and the active format
- export summary card with selected source count, route/waypoint count, distance total and filename preview
- disabled export button when nothing is selected or the active mode has no exportable content
- explicit disabled-reason messaging and clearer marking of days without exportable route data
- day-detail route subset selections flow into export summary, distance totals and exported imported-day content
- **Export Checkout Redesign (2026-05-01):** `ScrollView`+`LHPageScaffold` layout replacing the previous `List`-based layout
- `LHExportStepIndicator` — 4-step linear progress indicator (Auswahl / Format / Inhalt / Fertig) with completed/active/pending node states
- `LHExportBottomBar` — sticky bottom bar (`.safeAreaInset`) with item count + format summary label and primary export button; optional disabled-reason caption
- `LHExportFilterDisclosure` — collapsible card for Advanced Filters with orange active-state border and chip badge; replaces inline filter section
- selection summary card with 4-KPI grid: Days / Routes / Period / Places using `LHMetricCard`; "Edit Selection" scrolls to the days card
- format pills (GPX / KMZ / KML / GeoJSON / CSV) and mode pills (Tracks / Waypoints / Both) with active fill highlight
- `ExportPresentation.bottomBarSummary` and `ExportPresentation.disabledReason` — new static presentation helpers

Bewusst deaktiviert, aber vorhanden:
- export architecture can still grow beyond the active `GPX`/`KMZ`/`KML`/`GeoJSON`/`CSV` formats

Not present:
- cloud sync or account-backed sharing

## 10. Fehlerzustände / Leerzustände / Status-UI

Present:
- import-first empty root state
- loading state during import/demo load
- preserved-content error state after failed replacement import
- no-days empty state in day list / detail
- no-search-results state in compact day search
- export empty state when no content is loaded
- live-location placeholder when recording/location is off
- empty-state messaging in the recorded-tracks library and live-location saved-tracks area
- message card for info and error feedback

Not present:
- dedicated retry controls per error type beyond reusing import/demo actions
- skeleton loading UI

## 11. Technische Infrastruktur mit sichtbarer Produktwirkung

Present:
- contract-based decoder and read-only query layer
- `AppSessionState` drives root/session presentation state
- `AppPreferences` persist user-visible local settings via `UserDefaults`
- `GoogleTimelineConverter` enables direct Google Timeline imports inside the app shell
- `ZIPFoundation` powers ZIP import support
- `LiveLocationFeatureModel` drives permission, recording, live polyline and recorded-track state
- a limited networking stack exists for optional live-location server upload (`URLSession`, JSON payload, bearer token)
- `RecordedTrackFileStore` persists completed live tracks in app support storage
- demo support loads bundled golden fixtures through the same app-support layer
- App Groups Entitlements (`com.apple.security.application-groups: group.de.roeber.LH2GPXWrapper`) in `LH2GPXWrapper.entitlements` und `LH2GPXWidget.entitlements`; `WidgetDataStore` nutzt App-Group-UserDefaults fuer Datenaustausch zwischen App und Widget-Extension
- Widget-/Live-Activity-Texte laufen ueber `WidgetLocalizedStrings`; bevorzugte Sprache kommt aus der via App Group gespiegelten `AppLanguagePreference`, mit Geraetesprache als Fallback
- `LH2GPXTheme` (2026-04-30): zentrales Design-System mit Color-Tokens und UI-Bausteinen; konsolidiert card/chip/metric/banner Patterns aus `AppLiveTrackingView`, `AppDayListView`, `RecentFilesView`, `OverviewPresentation` in benannte Tokens und wiederverwendbare SwiftUI-Komponenten (`LHStatusChip`, `LHMetricCard`, `LHInsightBanner`, `LHFilterChip`, `LHSectionHeader`, `View.cardChrome()`)

Not present:
- analytics / telemetry
- server-backed persistence

## 12. Noch bewusst deaktivierte, aber vorhandene Unterbauten

Present as underlaying code, but not active as product behavior:
- recorded live tracks persist after recording stops, but there is no draft resume for an in-progress recording
- export architecture can grow beyond GPX/KML, but further formats are still inactive

Explicitly not present as active product features:
- automatic resume of live recording after app relaunch
- merge of recorded live tracks into imported history
- dedicated sync/server features

## 12b. Feature-Batch 2026-04-01 – Range / Insights / Export / Import-Comfort / Days-Polish

### A1. Globaler Zeitraumfilter
Present:
- `HistoryDateRangeFilter` struct mit Presets (all/last7Days/last30Days/last90Days/thisYear/custom) + Validator
- `HistoryDateRangePreset` mit `title`/`shortLabel`/`computedRange(relativeTo:)`
- `HistoryDateRangeValidator.validate(start:end:)` prüft auf start-after-end, zu weit in Vergangenheit
- `effectiveRange: ClosedRange<Date>?`, `fromDateString`/`toDateString` für AppExportQueryFilter
- `chipLabel` für UI-Chip-Darstellung; `reset()` zurück auf .all
- Chip-Reihenfolge: `last7Days | last30Days | last90Days | thisYear | custom | all` ("Gesamtzeitraum" ganz rechts)
- In `AppSessionState.historyDateRangeFilter` als shared State; Startwert und Import-Reset: `.last7Days`
- sichtbare Verdrahtung in `Overview`, `Insights` und `Export` ueber `AppHistoryDateRangeControl`
- lokalisierte aktive Bereichsanzeige, Reset und Custom-Range-Sheet ohne neue parallele Range-Logik in Views

### A2. Recent Files / Import-Historie
Present:
- `RecentFilesStore` (enum): `load/add/remove/clear/resolveURL/isAvailable`
- `RecentFileEntry`: id/displayName/bookmarkData/lastOpenedAt, Codable, Identifiable
- Deduplizierung nach displayName; neueste zuerst; max. 10 Einträge
- Migration von altem `lastImportedFileBookmark`-Key beim ersten `load`-Aufruf
- sichtbare Recent-Files-Liste im Import-Root mit `Open Again`, Entfernen einzelner Eintraege und `Clear History`
- stale oder fehlende Bookmarks werden im UI freundlich behandelt und aus der Historie entfernt

### A3. Auto-Restore als Option
Present:
- `AppPreferences.autoRestoreLastImport: Bool` (Key: `app.preferences.autoRestoreLastImport`, Default: false)
- in `reset()` bereinigt
- Toggle in `AppOptionsView`
- opt-in Restore-Pfad beim App-Start ueber den vorhandenen Bookmark-Unterbau

### B1. Per-Route Auswahl im Day Detail
Present:
- `ExportSelectionState.routeSelections: [String: Set<Int>]`
- `toggleRoute(day:routeIndex:)`, `clearRouteSelection(day:)`, `isRouteSelected(day:routeIndex:)`
- `effectiveRouteIndices(day:allCount:) -> IndexSet`
- `hasExplicitRouteSelection`, `explicitRouteSelectionCount`
- `clearAll()` räumt routeSelections mit auf
- sichtbare Route-Selection im Day Detail fuer exportierbare Routen
- Reset auf implizit alle exportierbaren Routen pro Tag
- Export-Summary und Export-Snapshot respektieren explizite Routen-Subsets

### B2. CSV-Export
Present:
- `ExportFormat.csv` mit `.tablecells` Icon, `"csv"` Dateiendung
- `CSVBuilder.build(from:[Day]) -> String`: Header (16 Felder), visit/activity/route/empty-Rows; RFC 4180 Escaping
- `CSVDocument` (SwiftUI FileDocument) für `.fileExporter`-Integration
- CSV ist in `AppExportView` ueber den bestehenden fileExporter-Flow aktiv verdrahtet
- CSV zeigt sichtbaren UI-Hinweis, dass Tabellenzeilen fuer Visits, Activities und Routes exportiert werden
- Dateiname, Disabled-Reasons und Selection-Summary nutzen denselben sichtbaren Exportzustand wie die anderen Formate

### B3. Days-Filterchips
Present:
- `DayListFilterChip` (favorites/hasVisits/hasRoutes/hasDistance/exportable)
- `DayListFilter` mit `activeChips: Set<DayListFilterChip>`, `toggle`, `clearAll`, `isActive`
- `passes(summary:isFavorited:)` mit AND-Logik
- sichtbare Chip-Leiste in `Days`
- Chip-Filter kombinieren sich mit Suche und newest-first Sortierung
- eigener Filter-Empty-State bei 0 Treffern

### B4. Favoriten/Pinning
Present:
- `DayFavoritesStore` (enum): `add/remove/toggle/contains/clear` via UserDefaults
- Key: `app.dayFavorites`
- Stern-Indikator in der Day-Liste
- Favoriten-Toggle per Swipe und Kontextmenue in der Liste
- zusaetzlicher Favoriten-Toggle im Day Detail

### C1. Insights-Drilldown
Present:
- `InsightsDrilldownAction` (filterDays/filterDaysToDate/filterDaysToDateRange/prefillExportForDate/prefillExportForDateRange/**showDayOnMap**)
- `InsightsDrilldownTarget` mit id/label/systemImage/action; Factory: `showDay`/`showDayOnMap`/`exportDay`/`showFavorites`/`showDaysWithRoutes`
- `drilldownTargets(for: date)` liefert jetzt 3 Targets: `showDay`, `showDayOnMap`, `exportDay`
- `showDayOnMap` navigiert zum Day-Detail-View (inline `AppDayMapView`); nur fuer Drilldowns mit echtem raeumlichem Bezug (Einzeltage mit Kartendaten); keine Fake-Kartenziele fuer aggregierte Werte
- `AppSessionState.activeDrilldownFilter: InsightsDrilldownAction?`
- `InsightsDrilldownBridge` trennt Days-/Export-Ziele, behandelt `showDayOnMap` als Day-List-Aktion, baut Datumsbereiche fuer Monate/Perioden und liefert sichtbare Drilldown-Beschreibungen (DE/EN)
- `AppInsightsContentView` zeigt jetzt sichtbare Drilldown-Aktionen fuer Highlights, `Top Days`, Distanz-Zeitreihe sowie Monats-/Periodenbereiche
- `AppContentSplitView` und `AppExportView` wenden aktive Drilldowns jetzt sichtbar auf `Days` bzw. `Export` an und bieten Reset

### C2. Chart Share Helper
Present:
- `ChartShareHelper.payload(for:dateRange:) -> ChartSharePayload`
- `InsightsCardType` mit 9 Karten-Typen: `summaryCards`, `highlights`, `topDays`, `monthlyTrend`, `weekdayPattern`, `activityBreakdown`, `periodBreakdown`, `streak`, `periodComparison`
- Dateiname-Format: `LocationHistory_Insights_<type>_[<range>_]<date>.png`
- `AppInsightsContentView` rendert auf Apple-Hosts per `ImageRenderer` eine PNG-Datei und zeigt sichtbare Share-Aktionen fuer die wichtigsten Insights-Sektionen inkl. der neuen `Activity Streak`- und `Period Comparison`-Sektionen

Not verifiable on Linux:
- ImageRenderer-Integration und Share-Sheet-Interaktion nur auf Apple-Host verifizierbar

### C3. Activity Streak (Phase B)
Present:
- `InsightsStreakStat`: `longestStreakDays`, `longestStreakStart/End`, `recentStreakDays`, `recentStreakStart`, `activeDaysCount`, `totalDaysCount`
- `InsightsStreakPresentation.streak(from:)`: berechnet Longest- und Recent-Streak rein aus `[DaySummary]`; Recent = Streak endend am letzten aktiven Tag im sichtbaren Zeitraum; Longest = laengste ununterbrochene Folge
- `sectionHint(dayCount:)` und `noDataMessage()` fuer saubere Empty-States
- in `AppInsightsContentView` als `Activity Streak`-Sektion im Overview-Tab verdrahtet mit Share-Button
- kein Drilldown (aggregierter Wert ohne raeumlichen Bezug)

### C4. Period Comparison (Phase B)
Present:
- `InsightsPeriodComparisonItem`: `label`, `activeDays`, `events`, `distanceM`
- `InsightsPeriodComparisonStat`: `current` und `prior` als Paerchen
- `InsightsPeriodComparisonPresentation.comparison(currentSummaries:allSummaries:rangeFilter:)`: vergleicht den aktiven Zeitraum mit der gleich langen Periode unmittelbar davor; gibt `nil` zurueck wenn kein Range aktiv oder kein `effectiveRange` vorhanden
- `deltaText(current:prior:)` liefert `"+N%"` / `"-N%"` / `"+∞"` / `"–"`
- `isPositiveDelta(current:prior:)` fuer Farbindikation
- in `AppInsightsContentView` als `Period Comparison`-Sektion im Patterns-Tab verdrahtet; Empty-State wenn kein Range aktiv; Share-Button vorhanden
- `AppInsightsContentView.init` erhaelt `allDaySummaries: [DaySummary] = []`; `AppContentSplitView` uebergibt `session.daySummaries` (ungefiltert) als Vorperiod-Basis
- kein Drilldown (aggregierter Wert ohne raeumlichen Bezug)

### C5. Active Days Summary Card (Phase B)
Present:
- fuenfte Summary-Karte `Active Days` in `AppInsightsContentView.buildSummaryCards`: zeigt `N / M`-Format (aktive vs. geladene Tage) mit Teal-Farbgebung
