# APP Feature Inventory

Last analysis: 2026-05-07 (Day-Detail-Distance-Bug-Fix — Day-Detail nutzt jetzt `effectiveDistanceM` (Polyline-Fallback bei `distanceM == nil`); konsistent mit Summary/Insights. `PathDistanceCalculator` als zentralisierte Distance-Semantik, Single-Source-of-Truth für raw>0-vs-Polyline-Fallback in `Sources/LocationHistoryConsumer/Queries/PathDistanceCalculator.swift`.)

Davor: 2026-05-06 (UX-Audit-Batch — LiveStatusResolver + Export-Empty-State + Polish; Hero-Map-Workspace bereits ausgerollt)

Repos in scope:
- `dev-roeber/iOS-App`: active repo truth for the integrated app + wrapper

Governance:
- Only document what is verifiable in repo/app.
- Do not list wishes, planned work or speculative wrapper behavior as present features.

## Public Audience Statement

LH2GPX is a **public consumer/utility app**. It is not an organization-specific app, a custom app for a business, a client/employee/partner app, or an enterprise tool.

- **Target audience**: any individual who wants to view and export their personal Google Maps location history privately
- **No account required**: no login, no organization ID, no employee credentials, no partner affiliation
- **All data stays local**: imported location history never leaves the device; no mandatory cloud sync or server
- **Optional live recording upload**: disabled by default; requires the user to explicitly configure a self-hosted server URL; no central LH2GPX service exists; no organizational backend
- **App Store Review context**: version 1.0 (Build 74) was rejected on 2026-05-01 under Guideline 3.2 (Business); review response sent and accepted — Build 74 status now **Pending Developer Release** (2026-05-05). 1.0.1-Train started, Cloud-Build 84 successful, `CURRENT_PROJECT_VERSION = 100` locally set (commit `8854eef`); Xcode Cloud Build ≥100 required before next submit.

## 1. App-Struktur / Navigation

Present:
- Import-first root screen when no content is loaded
- import-first root can show a visible recent-files list with reopen, remove-entry and clear-history actions
- import-first root now uses the visible LH2GPX redesign: large `LH2GPX` title, short subtitle, `HomeLocalPrivacyRow` (compact banner: lock icon + "Processed locally · JSON, ZIP, GPX, TCX"), prominent blue `Import File` primary action, dark help/demo rows and a dark `Recently Used` card
- shared toolbar `Actions` menu for primary app commands
- compact layout uses `TabView` with `Overview`, `Days`, `Insights`, `Export` and on iOS 17+ `Live`
- Days-Tab (compact): sticky Map-Workspace via `.safeAreaInset(edge: .top)` — Karte bleibt oben fixiert, scrollt nicht weg; `LHMapHeaderState.isSticky: true` verhindert Ausblenden
- Days-Tab (compact): persistente Export-Auswahl-Bottom-Bar via `.safeAreaInset(edge: .bottom)` — erscheint wenn ≥ 1 Tag ausgewählt; direkter Button zu Export-Tab
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
- (Phase-10A, Store-Pfad only, **default OFF**, **UI-Hook umgesetzt 2026-05-08 (Weg 2)**) cooperative import cancellation: `LocalTimelineImportCancellation` token; `LocalTimelineImportController.cancel()` rolls back the open SQLite transaction so no partial import is persisted; SwiftUI Cancel-Button im Loading-Branch von AppShellRootView + wrapper/LH2GPXWrapper/ContentView
- (Phase-10A, Store-Pfad only, **default OFF**, **UI-Hook umgesetzt 2026-05-08 (Weg 2)**) throttled import progress: `LocalTimelineImportProgress` snapshots with phase + counters + optional byte hints; default throttle 500 entries; emitted on every phase change and terminal phase; `LocalTimelineImportProgressView` zeigt Counter + optional Bytes/% live
- (Phase-10A, Store-Pfad only, **default OFF**, **UI-Hook umgesetzt 2026-05-08 (Weg 2)**) SwiftUI cancel-button + progress-counters in `wrapper/LH2GPXWrapper/ContentView.swift` / `AppShellRootView` (Loading-Branch); Test-Mode-Banner (`LocalTimelineTestModeBanner`) sichtbar bei aktivem `LocalTimelineTechnicalTestSettings.shared.localTimelineStoreTestModeEnabled`

Not present:
- FIT format import (no maintainable Swift library without external dependency; deliberate follow-up)
- GeoJSON import (as import source; export remains present; deliberate follow-up)
- drag-and-drop import UI
- multi-file import UI
- SwiftUI cancel-button + progress-counters in `LocalTimelineSessionLandingView` (Landing-View-Variante) — UX-Polish offen (Loading-Branch-Variante in `wrapper/LH2GPXWrapper/ContentView.swift` / `AppShellRootView` ist seit 2026-05-08 (Weg 2) implementiert, siehe Sektion 2)

## 3. Overview / Dashboard

Present:
- overview screen uses the LH2GPX redesign with a large page title, dark cards and true-black background
- **Layout-Reihenfolge (Redesign Batch 2)**: Status → Karte → KPI → Zeitraum → Highlights → Continue → Live Tracks
- visible import-status/source card with active file and optional technical disclosure
- visible global time-range card with current range, reset action and quick chips for `Last 7 Days`, `Last 30 Days`, `Last 90 Days` and `This Year` — only shown when `session.hasDays`
- KPI grid for distance, active days, routes and places — shown immediately below the map
- highlights card for busiest day, longest distance and most activities plus a direct jump into insights
- continue/quick-action card: "Browse Days" as visually highlighted primary action; Insights, Export, Import New File as secondary rows — only shown when `session.hasDays`
- **Empty state CTA** (`overviewEmptyCallToAction`): shown when content is loaded but has no day entries — "Get Started" header + import description + "Import File" button; Zeitraum-Card and Continue-Card hidden in this state
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
- **Unified `MapLayerMenu` dropdown (2026-05-06, commit `70254ff`):** alle Map-Layer-Controls auf jeder Map-Surface laufen über ein einziges Right-Side-Dropdown (SF Symbol `slider.horizontal.3`, oben rechts mit `.padding(8)`). Ersetzt: standalone `LHMapStyleToggleButton` (deprecated), Heatmap-Bottom-Sheet, Capsule-Chip-Cluster (Palette/Scale/Radius), Follow-Pill, Fullscreen-Close-X-Button, Fit-to-Data-Button. Configuration-driven über `MapLayerMenu.Configuration` (showsTrackColor / showsLiveOptions / showsHeatmapControls / fitToData / centerOnLocation / toggleFullscreen / isFullscreenActive).
- Heatmap-Opacity in `MapLayerMenu` als 4-Stufen-Picker `25 % / 50 % / 75 % / 100 %` (Slider war im SwiftUI-`Menu` nicht möglich); Snap-to-nearest-Preset auf Read.
- live-location map with current-position marker and live polyline while recording
- center-on-location action for the live-location map (verfügbar wenn `currentLocation != nil`); aktiviert Follow-Mode als Seiteneffekt
- fullscreen live map mode (über `MapLayerMenu` toggleFullscreen geöffnet/geschlossen; `isFullscreenActive: true` in der Fullscreen-Karte ändert das Label)
- dedicated `Heatmap` sheet for imported history on iOS 17+/macOS 14+ with precomputed LOD grids, smoothed aggregated polygon cells, viewport-capped cell selection, calmer low-zoom rendering, fit-to-data + heatmap controls (palette, scale, radius, opacity) via `MapLayerMenu`, and stronger nonlinear opacity/intensity/color mapping with earlier low-/mid-density hue separation so sparse detail zoom stays visible and more differentiated instead of fading to near-grey
- Heatmap-Stats verbleiben als kleines `bottom-leading` Info-Badge (Punkte · Tage · Datumsbereich); Bottom-Sheet mit Drag-Handle/Expand/Collapse wurde entfernt.

- path display mode toggle in day-detail map: `.original` (raw coordinates) vs. `.mapMatched` (`Simplified`); persisted via `AppDayPathDisplayMode` in UserDefaults; Picker `Route Display` ist Inhaltsfilter (nicht Layer-Style) und sitzt im Filter-Panel über bzw. neben der Karte, nicht im Layer-Menü.
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
- **Live Activity / Dynamic Island / Widget Safety Batch 5B (2026-05-05):** Content-Safety-Review: `TrackingStatus`/`TrackingAttributes`/`WidgetDataStore.LastRecording` enthalten keine Koordinaten, Server-URLs oder Token; `minimalView`-Bug (tote Bedingung) behoben → zeigt konsistent `location.fill.viewfinder` (aktiv) oder `pause.circle.fill` (Pause); 9 neue Safety-Tests
- **Live Tracking Foundation Batch 5A (2026-05-05):** Hero/Status-Card, collapsible Diagnostics section, 7 new accessibility identifiers
- `heroStatusCard`: Clear status display at top of Live Tracking screen, derived from `isRecording` / `isAwaitingAuthorization` / `authorization`; states: Recording Active, Requesting Permission, Location Access Denied, Ready to Record, Not Started; identifier: `live.status.hero`
- `diagnosticsSection`: Collapsible 8-metric diagnostics (was `recordingCard`); tap to expand/collapse; session timer visible in header; identifier: `live.diagnostics.section`
- `LHLiveBottomBar` — sticky `.safeAreaInset(edge: .bottom)` CTA bar; mint tint when idle (Start), red tint when recording (Stop); `accessibilityIdentifier` `live.recording.primaryAction` / `live.recording.stopAction`
- `LHLiveTrackRow` — dark card row wrapping `SavedTrackSummaryContentView` with `LH2GPXTheme.card` surface and `cardBorder` overlay; used in the library list
- map card identifier: `live.map.preview`; status chips: `live.status.gps`, `live.status.upload`, `live.status.follow`, `live.status.ready`
- metric identifiers: `live.metric.distance`, `live.metric.duration`, `live.metric.points`, `live.metric.averageSpeed`
- upload section identifier: `live.server.status`; permission banner: `live.permission.card`
- upload quick actions: pause button with `live.cta.pause`; saved-tracks: `live.savedTracks.preview`, `live.savedTracks.openAll`
- Token masking: `LHUploadSettingsCard` shows "Token set" / "No token" only — bearer token value never displayed in UI, logs, or tests
- `AppRecordedTracksLibraryView` uses `ScrollView` + `LHPageScaffold` replacing the previous `List`; navigation title "Live Tracks"; `liveTracks.title`, `liveTracks.info`, `liveTracks.list`, `liveTracks.row.<index>`, `liveTracks.newTrack` accessibility identifiers
- `LiveTrackingPresentation.gpsStatusLabel(accuracyM:)` — returns `"GPS Good"` (< 30 m), `"GPS Weak"` (≥ 30 m), or `"GPS Searching"` (when `accuracyM == nil`, i.e. no fix yet)
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
- **Dashboard Hero** (`insightsDashboardHero`): compact row below title showing date range from `insights.dateRange` and active day count; `insights.hero.summary` identifier; only shown when summaries are non-empty
- **Two-path empty state** (`insightsFullEmptyState`): filter-active path shows reset CTA (`insights.empty.resetFilter`); no-data path shows static message; `insights.emptyState` identifier
- **Overview tab order** (Batch 4): Highlights → Activity Streak → Top Days → Daily Averages
- large `Insights` title with bold heading; LH2GPX dark-redesign applied (LH2GPXTheme card surface, hairline borders, semantic colors)
- focused 4-KPI grid (Distance / Active Days / Routes / Places) via `LHMetricCard`; accessibility identifiers `insights.kpi.*`
- active filter context shown via `LHContextBar`; date range control with `insights.range` identifier
- share button identifiers updated to `insights.share.<cardType>` for per-section targeting
- drilldown labels updated: "Open in Days", "Select for Export", "Show on Map"
- `dayDrilldownTargets` now uses full triple (Days + Map + Export)
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
- internal test toggles section in technical options ("Internal Test Toggles", Build-158-Vorbereitung 2026-05-08): two UserDefaults-backed Bool toggles persisted via `LocalTimelineTechnicalTestSettings` — `LH2GPX.localTimelineStoreTestModeEnabled` (activates the feature-flagged LocalTimelineStore path in addition to `LH2GPX_LOCAL_TIMELINE_STORE`) and `LH2GPX.importMemoryLoggingEnabled` (activates `ImportMemoryProbe` in addition to `LH2GPX_IMPORT_MEMORY_LOG`); status row "Memory Logging Resolved" reflects the effective `ProcessInfo OR Settings` state on-device; footer hint "Internal/TestFlight only · Pre-production · Default off · No location data is stored in these settings". Toggles store **only Bool**; no location data, paths or tokens. Args/ENV remain the primary activator; the setting activates additionally and never deactivates. LocalTimelineStore path remains pre-production / feature-flagged / default off. 46-MB gate remains FAILED / pending hardware retest.
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
- export mode picker for `Tracks`, `Waypoints` and `Both` remains present, but is now secondary under `What to include`
- export preview map for the current selection with route and waypoint context; if the current selection has no stable exportable geometry, the UI falls back to a compact summary instead of rendering a fake map
- system `fileExporter` flow
- GPX, KMZ, KML, GeoJSON and CSV generation from selected imported days and selected saved live tracks
- waypoint export from imported visits plus activity start/end coordinates
- suggested export filename based on selected days, saved tracks and the active format
- export review card with selected days, selected saved live tracks, route/waypoint/point counts, period summary, distance badges and filename preview
- disabled export button when nothing is selected or the active mode has no exportable content
- explicit disabled-reason messaging and clearer marking of days without exportable route data
- day-detail route subset selections flow into export summary, distance totals and exported imported-day content
- **Export Checkout Redesign Batch 3 (2026-05-05):** Export is now structured as a clear final review flow:
  - `Review Selection` section with empty/invalid-state fallback and return path to `Days` / `Import`
  - `Preview` section using the existing map component when real geometry exists
  - `Choose Format` section for repo-wahr formats (`GPX`, `KMZ`, `KML`, `GeoJSON`, `CSV`)
  - `Export Destination` section describing the actual system save/share path
- `LHExportBottomBar` — sticky bottom bar (`.safeAreaInset`) with selection summary (`days + live tracks · format`) and the single primary export button; optional disabled-reason caption
- `LHExportFilterDisclosure` — collapsible card for Advanced Filters with orange active-state border and chip badge; replaces inline filter section
- selection review card with 4-KPI grid: Days / Tracks / Period / Points using `LHMetricCard`; `Review in Days` returns to the selectable day list
- format pills (GPX / KMZ / KML / GeoJSON / CSV) and mode pills (Tracks / Waypoints / Both) with active fill highlight
- `ExportPresentation.reviewSnapshot`, `selectionSummary`, `bottomBarSummary` and `disabledReason` drive the Checkout presentation from the existing real export state

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

Planned (research-only, not implemented):
- **LocalTimelineStore Phase-10A-Folge — P1-C + P1-D (2026-05-08)**: WAL-Checkpoint-API + Recovery-Test. **NEU** API `LocalTimelineStore.checkpointWAL(mode:)`/`truncateWAL()`/`bestEffortTruncateWAL()` über `sqlite3_wal_checkpoint_v2`; `WALCheckpointMode { passive, full, restart, truncate }`; `WALCheckpointInfo { framesInLog, framesCheckpointed }`; neuer Error-Case `LocalTimelineStoreError.checkpointFailed`. Wiring: `LocalTimelineImportWriter.finalize`/`.cancel` und `LocalTimelineStoreLifecycle.deleteAllLocalTimelineData(store:)` rufen `bestEffortTruncateWAL` (best-effort, damit Importerfolg/Cancel/Delete nicht von einem fehlschlagenden Checkpoint zerstört werden). Reads checkpointen nicht. **Keine Schemaänderung**: `imports`-Row inside `BEGIN IMMEDIATE`, mid-import-Abbruch hinterlässt keine sichtbare Partial-Import-Row. **NEU Tests** `LocalTimelineStoreWALCheckpointTests` (7) + `LocalTimelineStoreRecoveryTests` (6); Recovery-Test ist **Linux-Simulation, kein echter iOS-Jetsam-Test** (Power-Loss-/Kernel-Kill-Verhalten auf Hardware bleibt separate Verifikation). Vollsuite 1345/2/0. **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim). Store bleibt **pre-production / feature-flagged / default AUS**.
- **LocalTimelineStore (Phase 1..10A abgeschlossen 2026-05-08, conditional P0/P1)** — Wrapper/AppFlow-Wiring + Settings-Delete-UI + Store-DayList/DayDetail-UI + **Store-DayMap-UI-Surface (Foundation-only Presentation Model + SwiftUI Placeholder, kein MapKit-Import)** **UI-aktiv hinter Feature-Flag** (`LH2GPX_LOCAL_TIMELINE_STORE`); echte MapKit-/`MKMapView`-Verdrahtung bleibt **Phase-10B Mac/Xcode-Pflicht**; Heatmap/Overview/Export-Surfaces bleiben **nicht UI-aktiv**; Store-Pfad **default AUS**. **Vollständige sichtbare Kartenmodernisierung wird nicht behauptet.** Legacy-Map unverändert. **Phase 10A (2026-05-08)**: **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayMapViewState.swift` (Foundation-only Presentation Model: `LocalTimelineDayMapViewState`, `LocalTimelineDayMapSource`, harte `Budget`-Grenzen — default **12 Routen / 256 Punkte pro Route / 4096 Punkte gesamt**). **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayMapView.swift` (SwiftUI `#if canImport(SwiftUI)`-guarded **Placeholder; KEIN MapKit-Import**). **Geändert** `LocalTimelineDayDetailView` (neue optionale Map-Sektion; nur sichtbar wenn `mapSource != nil` und Pfad-Metadaten existieren; "Load map"-Button startet bounded Candidate-Load **ohne `coord_blob`-Decodierung**; "Decode all routes" toggelt bounded Geometrie-Decode innerhalb `Budget`). **Geändert** `LocalTimelineSessionLandingView` (reicht neuen optionalen `dayMapSource` durch). **NEU** `LH2GPXAppFlow.makeProductionDayMapSource(for:)` (öffnet eigenen Reader auf `session.storeURL`, bindet `StoreBackedMapDataProvider`, nutzt Visit-Koordinaten als Bounds-Fallback). **Geändert** `Sources/LocationHistoryConsumerApp/AppShellRootView.swift` und `wrapper/LH2GPXWrapper/ContentView.swift` reichen neue Source ans Landing-View durch. **NEU Tests** `Tests/LocationHistoryConsumerTests/LocalTimelineDayMapViewStateTests.swift` (7), `LocalTimelineDayMapBoundsTests.swift` (4) — alle Linux-grün. **Bounded-Read-Garantien Phase 10A**: Candidates lesen ausschließlich path metadata; Geometrie ausschließlich für selektierte pathIDs lazy decodiert; harte Budgets pro Route + pro Tag; Bounds primär aus path metadata (union der bbox-Spalten), Fallback auf Visit-Koordinaten via Closure, leerer Tag → `bounds == nil`; malformed `coord_blob` → kontrollierter `LocalTimelineMapProviderError.malformedCoordBlob` ohne Crash; Anti-Meridian bleibt Phase 10B/11. **Harte Grenzen Phase 10A**: feature-flagged Store-DayMap-UI-Surface, kein Default-Rollout. **KEIN MapKit-Import** in der Phase-10A-View; echte `MKMapView`-Verdrahtung bleibt **Phase-10B Mac/Xcode-Pflicht**. **KEINE vollständige sichtbare Kartenmodernisierung.** Legacy-Map unverändert. KEIN AppExport-Rebuild. KEIN vollständiger `[Double]`-Import-Buffer. KEIN eager `coord_blob`-Decoding beim Candidate-Load. KEIN Live-Upload-Mix. KEINE neuen externen Dependencies. KEINE Darwin-FileProtection-Aktivierung. KEIN RTree. KEINE Hardware-/AppStore-/TestFlight-/ASC-Aussage. **46-MB-Gate bleibt FAILED / pending hardware retest.**
- **LocalTimelineStore Phase 9B (2026-05-08)**: Wrapper/AppFlow-Wiring + Settings-Delete-UI + **Store-DayList/DayDetail-UI** **UI-aktiv hinter Feature-Flag** (`LH2GPX_LOCAL_TIMELINE_STORE`); Map/Heatmap/Overview-Surfaces bleiben **nicht UI-aktiv**; Store-Pfad **default AUS**. **Phase 9B (2026-05-08)**: **Geändert** `AppSessionState` (neues Feld `selectedLocalTimelineDayId: String?` + Mutator `selectLocalTimelineDay(_:)`; in `show(localTimeline:)`/`show(content:)`/`clearContent()` mitgenullt). **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayBrowserSource.swift` (Foundation-only Source-Struct + `bind(session:reader:)` Convenience für die View-Hooks; **bounded — kein `coord_blob`, keine Polylines**). **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayListView.swift` (`#if canImport(SwiftUI)`-guarded; Tage newest-first mit Datum / Routen / Visits / Distanz; **kein Map-Hook**). **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayDetailView.swift` (`#if canImport(SwiftUI)`-guarded; Datum + Visits + Activities + Path-Metadaten + Hinweis "Path points available (not decoded)"; **kein eager `coord_blob`-Decoding, keine Map**). **NEU** `LH2GPXAppFlow.makeProductionDayBrowserSource(for:)` (öffnet `LocalTimelineStore` an `session.storeURL`). **Geändert** `LocalTimelineSessionLandingView` (erweitert um optionales `dayBrowser`/`selectedDayId`/`onSelectDay`; rendert Liste + sheet-basierte Detail-Navigation via NavigationStack; **backward-kompatibel**, defaults nil). **Geändert** Wrapper- und Package-AppShell-ContentViews reichen `makeProductionDayBrowserSource` + Selection-Binding durch. **NEU Tests** `Tests/LocationHistoryConsumerTests/LocalTimelineDayBrowserSourceTests.swift`, `LocalTimelineSelectionStateTests.swift`. **Harte Grenzen Phase 9B**: KEIN Map-/Heatmap-/Overview-UI-Hook gegen Store. KEIN AppExport-Rebuild. KEIN vollständiger `[Double]`-Import-Buffer. KEIN eager `coord_blob`-Decoding. KEIN Default-Rollout. KEIN Live-Upload-Mix. KEINE neuen externen Dependencies. KEINE Darwin-FileProtection-Aktivierung. KEIN RTree. **46-MB-Gate bleibt FAILED / pending hardware retest.**
- **LocalTimelineStore Phase 9A (2026-05-08)**: Wrapper/AppFlow-Wiring + Settings-Delete-Button + Landing-View für aktive Store-Session. **Phase 9A (2026-05-08)**: **NEU** `LH2GPXAppFlow.apply(envelopeOutcome:to:preserveOnFailure:) -> AppliedEnvelopeRouting` (geteilte Linux-testbare Routing-Helper-Funktion für Wrapper + Package-AppShell), `LH2GPXAppFlow.makeProductionDeletionPresentation()` (Convenience für Settings/Technical-Hosts). **Geändert** `wrapper/LH2GPXWrapper/ContentView.swift` und `Sources/LocationHistoryConsumerApp/AppShellRootView.swift` rufen jetzt `loadImportedFileEnvelope(...)` und routen `.legacy/.localTimeline/.failure` über `apply(...)`. **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineSessionLandingView.swift` (`#if canImport(SwiftUI)`-guarded) — Landing-View bei aktiver `localTimelineSession` mit Session-Metadaten + Lösch-Button; **kein `coord_blob`-Read, kein Map/Heatmap/Overview-Hook**; eingebunden in beiden App-Shells via body-Branch `else if let storeSession = session.localTimelineSession`. **Geändert** `AppTechnicalOptionsView` (in `AppOptionsView.swift`) — neue Section "Local Timeline Store" mit Feature-Flag-Status (Enabled/Disabled aus `LocalTimelineFeatureFlags.resolveFromProcess()`), Status-Zeile "Pre-production / Feature-flagged" und Lösch-Button "Delete imported local data" mit States idle/running/succeeded/failed. **NEU** `Tests/LocationHistoryConsumerTests/WrapperLocalTimelineEnvelopeRoutingTests.swift` (6 Cases, Linux-grün): legacy/localTimeline/failure(clearBookmark T/F)/Replace-Invariante. **Harte Grenzen Phase 9A**: KEIN Map-/Heatmap-/Overview-UI-Hook gegen Store. KEIN AppExport-Rebuild. KEIN vollständiger `[Double]`-Import-Buffer. KEIN Default-Rollout. KEIN Live-Upload-Mix. KEINE neuen externen Dependencies. KEINE Darwin-FileProtection-Aktivierung. KEIN RTree. **46-MB-Gate bleibt FAILED / pending hardware retest.** Settings-DayList/DayDetail UI nur als Landing-View für Store-Session sichtbar.
- **LocalTimelineStore (Phase 1..8B abgeschlossen 2026-05-08, conditional P0/P1)** — Spike / pre-production, not UI-active. On-disk Persistenz für sehr große Imports (z. B. 46 MB Google-Timeline-ZIP) als strukturelle Alternative zum heutigen In-Memory-`AppExport`-Pfad. Phase 1 (CoordBlob + SQLite-Schema), Phase 2 (visits/activities, disk-first ImportWriter, GoogleTimelineStoreImporter, deleteAll DB-only), Phase 3 (Foundation-only Read-Models + LocalTimelineStoreReader mit bounded Reads), Phase 4 (Storage-Pfad-Resolver `LocalTimelineStorageLocations` mit 4 Roots — DB unter `applicationSupportDirectory/LocationHistory2GPX/Imports/`, RenderCache unter `cachesDirectory`, ImportStaging + ExportStaging unter `temporaryDirectory` —, Backup-Exclusion-Helper `LocalTimelineFileAttributes`, FileProtection-Kapselung `LocalTimelineFileProtection` mit Ziel `completeUnlessOpen`, Open-Lifecycle-Factory `LocalTimelineStoreFactory`, High-Level `deleteAllLocalTimelineData` über DB+WAL+SHM+RenderCache+ImportStaging+ExportStaging), Phase 5 (store-backed Streaming Export), Phase 6 (feature-flagged AppSession-Quelle: `LocalTimelineFeatureFlags`, `LocalTimelineSession`, `LocalTimelineAppSessionAdapter`, `LocalTimelineDeletionService`) , **Phase 7A** (feature-flagged AppContentLoader-Hook über Envelope-Kapsel `AppSessionContentSource` + `AppSessionState.show(localTimeline:)`) und **Phase 7B** (Foundation-only Presentation/ViewState-Schicht + AppSessionState-Extension + Service-layer Envelope-Hook im AppFlow) sind als isolierte Spike-Surface eingecheckt.
  - **Phase 8B (Store-backed Heatmap LOD Cache + Heatmap-Doppelbug-Fix, Foundation-only, 2026-05-08)** — Status: **Spike / pre-production, not UI-active**. **NEU** `Sources/LocationHistoryConsumer/AppHeatmapPathSampler.swift` (Foundation-only Helper, kanonische Priorität: `flatCoordinates` wenn vorhanden + gerade Element-Anzahl, sonst `points` Fallback; ungerade flatCoordinates gelten als malformed → kontrollierter Fallback auf `points`). **Geändert** `AppHeatmapModel.swift:55-77` nutzt jetzt den Sampler statt der Doppel-Iteration über `path.points` UND `path.flatCoordinates` — **Heatmap-Doppelbug ist ab Phase 8B zentralisiert gefixt** (in `docs/MAP_ARCHITECTURE_AUDIT.md` §2 dokumentiert). **NEU** `LocalTimelineHeatmapModels.swift` (Foundation-only: `LocalTimelineHeatmapSample`, `LocalTimelineHeatmapSampleResponse`, `LocalTimelineHeatmapGridCell`, `LocalTimelineHeatmapLODResponse`, `LocalTimelineHeatmapCacheKey`, `LocalTimelineHeatmapCacheEncoding`), `LocalTimelineHeatmapGridAggregator.swift` (deterministischer Grid-Aggregator: cell-size pro Detail-Level overview=0.5°/low=0.1°/medium=0.02°/high=0.005°; hartes `maxCells`/`maxSamplesConsumed` Limit; stabile Sortierung lat asc, lon asc), `StoreBackedHeatmapDataProvider.swift` (`heatmapSamples(importID:viewport:maxRoutes:maxPointsPerRoute:maxSamples:)` bounded sampling, `heatmapLOD(importID:viewport:options:)` Grid-Aggregation optional cache-backed via `derived_cache`, `clearHeatmapCache(importID:)`; Cache-Payload-Codec deterministisch Magic 'L8B1' little-endian; Cache-Key über `LocalTimelineHeatmapCacheKey.make(...)` mit 1e-3°-Quantisierung; malformed `coord_blob` kontrolliert übersprungen). **Geändert** `LocalTimelineStoreSchema.swift` (neue **additive** Tabelle `derived_cache` mit FK auf `imports.id` + `ON DELETE CASCADE`; zwei neue Indizes `idx_derived_cache_import_kind_key` und `idx_derived_cache_kind_created`; **`userVersion` bleibt 2** rein additiv, keine semantische Schema-Änderung), `LocalTimelineStore.swift` (CRUD `putDerivedCache`, `derivedCache`, `deleteDerivedCache`, `countDerivedCache`; `deleteAll()` löscht jetzt auch `derived_cache`). **NEU** `Tests/LocationHistoryConsumerTests/AppHeatmapModelGeometryTests.swift` (7), `LocalTimelineHeatmapGridAggregatorTests.swift` (7), `StoreBackedHeatmapDataProviderTests.swift` (11 inkl. 50k synthetic store + cache hit/clear roundtrip), `LocalTimelineRTreeCapabilityTests.swift` (dokumentiert RTree-Fallback). **RTree (`path_bounds`) bleibt kontrolliert deferred** — `paths.id` ist TEXT, RTree erwartet INTEGER `docid`; Surrogate-Integer-Mapping wäre Schema-breaking. Bbox-Index-Scan aus Phase 8A bleibt aktiv. **KEIN SwiftUI-Map/MKMapView-Hook, KEIN UI-Heatmap-Renderer-Hook** (existierender SwiftUI-Heatmap-Renderer unverändert; konsumiert weiter `AppExport`). **KEIN AppExport-Rebuild aus Store. KEIN vollständiger `[Double]`-Import-Buffer. KEIN Live-Upload-Mix.** Store-Pfad bleibt default AUS. FileProtection-Status unverändert. **46-MB-Gate bleibt FAILED / pending hardware retest unverändert.** Phase-9-Pflichten: RTree path_bounds (Schema-breaking), Wrapper/SwiftUI-Wiring, Settings-Delete-UI-Button, Map/Heatmap/Overview UI-Hook gegen Provider, Darwin FileProtection-Aktivierung, Export-UI-Hook gegen `StoreBackedExportWriter`, 46-MB-Hardware-Retest, TestFlight/Xcode-Cloud, Privacy-Doku-Update.
  - **Phase 8A (Store-backed Map Data Provider, Foundation-only, 2026-05-08)** — Status: **Spike / pre-production, not UI-active**. **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineMapModels.swift` (Foundation-only Map-Domain-Modelle: `LocalTimelineMapViewport` mit Anti-Meridian-Reject, `LocalTimelineMapDetailLevel` overview/low/medium/high, `LocalTimelineMapPointBudget` default-Tabelle pro Level monoton, `LocalTimelineMapQuery`, `LocalTimelineMapRouteCandidate` metadata-only ohne `coord_blob`, `LocalTimelineMapPoint`, `LocalTimelineMapRouteGeometry` bounded points, `LocalTimelineMapOverviewResponse` mit `truncatedRoutes`/`truncatedPoints`, `LocalTimelineMapBounds`, `LocalTimelineMapProviderError`; **keine SwiftUI/MapKit/CoreLocation-Abhängigkeit**), `StoreBackedMapDataProvider.swift` (`routeCandidates`/`dayRouteCandidates` metadata-only ohne `coord_blob`, `routeGeometry` lazy single-path decode via `CoordBlobIterator`, `overviewRoutes` doppelt bounded mit `maxRoutes` + `budget.maxTotalPoints`, `mapBounds(forImportID:)`/`mapBounds(forDayID:)` Aggregat über `paths.min/max_lat/lon` ohne Geometrie-Decode), `LocalTimelineRouteDecimator.swift` (deterministischer stride-/budget-basierter Decimator, Iterator-basiert, erster + letzter Punkt erhalten, `maxPoints` hart, leere/1-Punkt-Pfade stabil; **Douglas-Peucker bleibt Phase 8B/9**). **Geändert** `LocalTimelineStoreSchema.swift` (zwei neue **additive** Indizes `idx_paths_bounds_minmax` und `idx_paths_day_bounds`; **`userVersion` bleibt 2**; RTree-`path_bounds` virtuelle Tabelle bleibt **Phase-8B-Pflicht**), `LocalTimelineStore.swift` (neue public APIs `pathMetadata(forImportId:viewport:limit:)`, `pathMetadata(forDayId:viewport:limit:)`, `pathBoundingBox(forImportId:)`, `pathBoundingBox(forDayId:)`; bbox-Filter linearer scan über `min/max_lat/lon`, NULL-Bounds konservativ als überlappend gewertet, newest-first), `LocalTimelineStoreReader.swift` (thin wrappers über die neuen Store-APIs). 4 neue Test-Dateien, 33 Cases (`StoreBackedMapDataProviderTests` 15 inkl. 50k-synthetic-store-bounded, `LocalTimelineRouteDecimatorTests` 8, `LocalTimelineMapBoundsTests` 7, `LocalTimelineMapSchemaIndexTests` 2). **Map/Heatmap/Overview-Surface bleibt unverändert UI-active im Legacy-Pfad.** **KEIN SwiftUI-Map/MKMapView-Hook in dieser Phase, KEIN UI-Hook, KEIN Renderer-Wechsel. KEIN AppExport-Rebuild aus Store. KEIN vollständiger `[Double]`-Import-Buffer. KEIN Live-Upload-Mix.** Provider ist ab jetzt die kanonische Schnittstelle für künftige UI-Hooks. Store-Pfad bleibt default AUS (`LH2GPX_LOCAL_TIMELINE_STORE`-Flag unverändert). FileProtection-Status unverändert. **46-MB-Gate bleibt FAILED / pending hardware retest unverändert.** Phase-8B-Pflichten: RTree `path_bounds` virtual table, derived_cache/Heatmap-LOD-Persistenz, Wrapper/SwiftUI-Wiring, Settings-Delete-UI-Button, Map/Heatmap/Overview UI-Hook gegen Provider, **Heatmap-Doppelbug-Fix `AppHeatmapModel.swift:55-77`**, Darwin FileProtection-Aktivierung, Export-UI-Hook, 46-MB-Hardware-Retest, TestFlight/Xcode-Cloud, Privacy-Doku-Update.
  - **Phase 7B (Foundation-only Presentation/ViewState-Schicht + AppSessionState-Extension + Service-layer Envelope-Hook im AppFlow, 2026-05-08)**: **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayListViewState.swift` (Foundation-only ViewState für Day-List-Surface über Store-Pfad), `LocalTimelineDayDetailViewStateAdapter.swift` (Foundation-only Adapter projiziert Reader-Daten in bounded DayDetail-ViewState), `AppSessionPresentationSource.swift` (Presentation-Quelle inkl. `AppSessionState`-Extensions `activeContent` und `isLocalTimelineActive`), `LocalTimelineDeletionPresentation.swift` (Presentation-Schicht über `LocalTimelineDeletionService`; dokumentiert: **kein Bookmark-/Preferences-Cleanup nötig im Store-Pfad** — keine UserDefaults für Standortdaten). **Geändert** `LH2GPXAppFlow.swift` (neue Methode `loadImportedFileEnvelope(...) -> EnvelopeImportOutcome` als feature-flagged Service-layer-Hook; **Legacy `loadImportedFile(...)` byte-identisch unverändert**). 5 neue Test-Dateien (`LocalTimelineDayListViewStateTests`, `LocalTimelineDayDetailViewStateAdapterTests`, `AppSessionLocalTimelinePresentationTests`, `LocalTimelineDeletionPresentationTests`, `AppFlowLocalTimelineEnvelopeTests`). **Surface bleibt Spike / pre-production, not UI-active. Store-Pfad bleibt default AUS (`LH2GPX_LOCAL_TIMELINE_STORE`-Flag). Kein UI-Hook (kein Wrapper/SwiftUI-Wiring), kein Map/Heatmap/Overview/Export-UI-Hook. Kein AppExport im Store-Pfad materialisiert; keine vollständige `[Double]`-Import-Materialisierung. FileProtection-Status unverändert (Phase-4-Capsule, Aktivierung weiterhin Darwin/iOS-Pflicht). Live-Upload strikt getrennt. Keine Standortdaten in UserDefaults. Keine Map-Modernisierung. Keine Hardware-/ASC-/TestFlight-Aussagen. 46-MB-Gate bleibt FAILED / pending hardware retest unverändert.**
  - **Phase 7A (Feature-flagged AppContentLoader-Hook, 2026-05-08)**: **NEU** `Sources/LocationHistoryConsumerAppSupport/AppSessionContentSource.swift` (Envelope-Enum `inMemory(AppSessionContent)` / `localTimeline(LocalTimelineSession)` — **Kapsel-Approach**, `AppSessionContent` selbst wird NICHT erweitert; Source-Enum-Verschmelzung ist explizit Phase 7B). **Geändert** `AppSessionState.swift` (neue Property `localTimelineSession: LocalTimelineSession?` + Mutator `show(localTimeline:)` — Banner/Title aus Session-Metadaten, kein AppExport, keine Coord-Decode; `show(content:)` und `clearContent()` setzen mit zurück). **Geändert** `AppContentLoader.swift` (neuer Einstieg `loadImportedContentEnvelope(from:autoRestoreMode:onPhase:flags:storeFactoryProvider:) -> AppSessionContentSource`; **Flag-Off → exakt der Legacy-Pfad** byte-identisch; Flag-On + Google-Timeline-JSON oder ZIP-mit-genau-einem-Timeline-Entry → `GoogleTimelineStoreImporter` + `LocalTimelineSession.make(...)` → `.localTimeline(...)`; LH2GPX-Objekt-JSON/GPX/TCX fallen kontrolliert zurück; neuer Error-Case `localTimelineStoreFailed(String)`; Importe additiv mit frischer `importId`; Bulk-Wipe bleibt `LocalTimelineDeletionService`). 3 neue Test-Dateien, 14 neue Cases (`AppSessionLocalTimelineSourceTests` 5, `AppContentLoaderLocalTimelineStoreTests` 5, `LocalTimelineFeatureFlagIntegrationTests` 4). **Store-Pfad ist NIE default — Default-Rollout bleibt Legacy-AppExport, gated by feature flag. Kein UI-Hook für DayList/DayDetail/Map/Heatmap/Overview/Export/Settings. Kein AppExport im Store-Pfad. Live-Upload strikt getrennt. Keine Standortdaten in UserDefaults. Darwin FileProtection nicht aktiviert. Keine Map-Modernisierung. Keine Hardware-/ASC-/TestFlight-Aussagen. 46-MB-Gate bleibt FAILED / pending hardware retest.**
  - **Phase 6 (Feature-flagged AppSession-Quelle, 2026-05-08)**: **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineFeatureFlags.swift` (resolved `LH2GPX_LOCAL_TIMELINE_STORE` aus `ProcessInfo.arguments`/`environment`; `--LH2GPX_LOCAL_TIMELINE_STORE`/bare arg/env-Werte `1`/`true`/`yes`/`on` case-insensitive; default disabled; **keine UserDefaults**), `LocalTimelineSession.swift` (Foundation-only Session-Modell `importID`/`sourceFilename`/`storeURL`/`createdAt`/`importedAt`/`summary` mit `dayCount`/`pathCount`/`visitCount`/`activityCount`/`totalDistanceM`/`dateRange`; `make(reader:importID:storeURL:)` ohne Geometrie-Materialisierung; Caller besitzt Store-Lifetime), `LocalTimelineAppSessionAdapter.swift` (projiziert Reader-Daten in bounded ViewState-Modelle `DaySummaryView`/`DayDetailView`/`VisitView`/`ActivityView`/`PathMetadataView`; Methoden `daySummaries()`/`dayDetail(dayId:)`/`coordinates(forPathId:)` explizit on-demand lazy via `CoordBlobIterator`), `LocalTimelineDeletionService.swift` (dünner Wrapper um `LocalTimelineStoreLifecycle.deleteAllLocalTimelineData`; idempotent; **keine UserDefaults-Aufräumung**). 4 neue Test-Dateien, 17 neue Cases (`LocalTimelineFeatureFlagsTests` 8, `LocalTimelineSessionTests` 3, `LocalTimelineAppSessionAdapterTests` 4, `LocalTimelineDeletionServiceTests` 2). **Store-Pfad gated by feature flag, kein default-aktiver Pfad. Kein AppExport im Store-Pfad materialisiert. Kein UI-Hook, kein App-Session-Switch, kein AppContentLoader-Hook, kein DayList/DayDetail/Map/Heatmap/Overview-Hook, kein Settings-UI. `AppSession`/`AppSessionContent`-Typen wurden NICHT erweitert. Darwin FileProtection in diesem PR nicht angefasst. Bestehender AppExport-Exportpfad unverändert.**
  - **Phase 5 (Store-backed Streaming Export, 2026-05-08)**: **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineExportTypes.swift` (Foundation-only Typen: `LocalTimelineExportFormat` `gpx`/`kml`/`geoJSON`/`csv`; `LocalTimelineExportSelection` mit `importID` + optional `dateRange`/`dayIds` + `includeVisits`/`includeActivities`/`includePaths`; `LocalTimelineExportResult` mit `outputURL`/`format`/`bytesWritten`/`dayCount`/`pathCount`/`visitCount`/`activityCount`/`pointCount`; `LocalTimelineExportError` `unknownImport`/`emptySelection`/`malformedCoordBlob`/`ioFailure`/`readerFailure` — empty-selection-Entscheidung explizit als Fehler), `LocalTimelineStreamingTextWriter.swift` (inkrementeller UTF-8-Datei-Writer nach `ExportStaging/<uuid>/export.<ext>`; parent-dir idempotent; `bytesWritten` zählt UTF-8-Bytes; `finalize()` idempotent), `StoreBackedExportWriter.swift` (`init(reader:locations:)`, `export(selection:format:)`; Days bounded, Visits/Activities/Paths via `dayDetail`, Koordinaten **ausschließlich pro Pfad lazy via `coordinateSequence(forPathId:)`/`CoordBlobIterator`**; **materialisiert KEINEN `AppExport`, KEINEN `[Double]`-Buffer für einen ganzen Import; schreibt direkt in die Datei**). GPX `<wpt>`+`<trk>/<trkseg>/<trkpt>`; KML `Placemark` mit `Point`/`LineString`; GeoJSON `FeatureCollection` mit Point-/LineString-Features (Properties `kind`/`name`/`mode`/`date`); CSV-Header `type,date,time,lat,lon,name,mode,distance_m`; Activities in CSV als eigene Rows, in GPX/KML/GeoJSON nur gezählt. 3 neue Test-Dateien, 26 neue Cases (`LocalTimelineExportSelectionTests` 6, `LocalTimelineStreamingTextWriterTests` 5, `StoreBackedExportWriterTests` 15). `swift test` **1148/2/0** (+26 vs. 1122). **Bestehende `AppExport`-Builder (`GPXBuilder`/`KMLBuilder`/`GeoJSONBuilder`/`CSVBuilder`) und der bestehende AppExport-Exportpfad bleiben unverändert.**
  - **Kein UI-Hook für DayList/DayDetail/Map/Heatmap/Overview/Export/Settings**, **kein App-Session-Switch auf Store als Default**, **kein Map-Hook**, **kein Wrapper/SwiftUI-Wiring**. AppContentLoader-Hook (Phase 7A) und Service-layer Envelope-Hook im AppFlow (Phase 7B) sind vorhanden, aber **NIE default-aktiv** — Store-Pfad ist gated by feature flag, Default-Rollout bleibt Legacy-AppExport. Status: **Spike / pre-production, not UI-active**. Offene Darwin-Pflicht: tatsächliche FileProtection-Aktivierung (Hook in Phase 4 nur dokumentiert; Phasen 6/7A/7B haben ihn nicht angefasst). **Phase 8 (offen vor produktivem UI-Rollout)** — in Phase 7B explizit deferred: Wrapper/SwiftUI-Wiring der Presentation-/ViewState-Schicht, Map/Heatmap/Overview Provider, `derived_cache`+RTree+`path_bounds`, Export-UI-Hook, **Darwin FileProtection-Aktivierung**, 46-MB-Hardware-Retest, TestFlight/Xcode-Cloud, App-Flow-Umschaltung, Privacy-Doku-Update vor Rollout. Conditional-P0/P1-Gate an 46-MB-Hardware-Retest gebunden. Details: `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`.

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

### C6. PointLayer (Store-Pfad, Phase-10B Foundation-only)
- **PointLayer (Store-Pfad, foundation-only, default OFF, in keinem View aktiv)**: Modelle + Provider eingecheckt (`LocalTimelineMapPointLayerModels.swift`, `LocalTimelineMapPointLayerProvider.swift`), zentrale adaptive Budgets via `LocalTimelineMapPerformanceBudget.swift`. UI-Verdrahtung WIP. Legacy-Pfad unverändert. 46-MB-Gate bleibt FAILED / pending hardware retest.
