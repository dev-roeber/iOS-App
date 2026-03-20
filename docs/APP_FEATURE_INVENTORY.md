# APP Feature Inventory

Last analysis: 2026-03-20

Repos in scope:
- `LocationHistory2GPX-iOS`: verified in this workspace
- `LH2GPXWrapper`: available in this workspace, but this inventory still only claims features that are verifiable from the core repo itself

Governance:
- Only document what is verifiable in repo/app.
- Do not list wishes, planned work or speculative wrapper behavior as present features.

## 1. App-Struktur / Navigation

Present:
- Import-first root screen when no content is loaded
- shared toolbar `Actions` menu for primary app commands
- compact layout uses `TabView` with `Overview`, `Days`, `Insights` and `Export`
- compact tabs each run inside their own `NavigationStack`
- regular-width layout uses `NavigationSplitView` with a day list and a detail pane
- regular-width day detail exposes an explicit `Overview` return action above the selected day
- modal sheets exist for `Options`, `Export` (regular width) and the recorded-tracks library
- the recorded-tracks library is directly reachable from Overview, the shared `Actions` menu and the live-recording area in day detail
- a separate SwiftUI demo app exists beside the product shell

Not present:
- dedicated onboarding flow or walkthrough
- custom bottom-sheet navigation model
- recent-files or import-history navigation

## 2. Import-Funktionen

Present:
- local file import via system file importer
- product app accepts `.json` and `.zip`
- supported content types: LH2GPX `app_export.json`, LH2GPX export ZIP, Google Timeline `location-history.json`, Google Timeline ZIP
- ZIP import is filename-agnostic for compatible JSONs
- user-facing import error titles for unsupported format, unreadable file, decode failure, empty ZIP and multiple exports in ZIP
- bundled demo fixture can be loaded as fallback
- imported file bookmark is saved after a successful import

Bewusst deaktiviert, aber vorhanden:
- `ImportBookmarkStore.restore()` exists as underlaying auto-restore mechanism
- bookmark persistence remains in code, but startup does not auto-restore the previous import

Not present:
- automatic restore of the last import on app launch
- drag-and-drop import UI
- multi-file import UI

## 3. Overview / Dashboard

Present:
- overview screen with statistics cards for days, visits, activities and routes
- overview starts with a source/status card and a dedicated `Primary Actions` section
- optional date-range header when days exist
- optional total-distance summary card when distance data exists
- highlight cards for busiest day and longest-distance day
- active-filter banner when export filters are present in metadata
- source/status card with optional technical disclosure details
- primary action cards can jump directly into file import, day browsing, insights and export
- primary actions include a direct jump into the separate `Saved Live Tracks` local library
- overview entry card for the `Saved Live Tracks` local library

Not present:
- dedicated onboarding dashboard state distinct from the import-first root
- customizable overview modules or reordering

## 4. Days / Day List

Present:
- sorted day list derived from export days
- month grouping when multiple months are present
- search on compact and regular day lists by date, formatted date, weekday and month text
- day rows show weekday, formatted date, visit/activity/route counts and optional distance
- no-content days stay visible in the list, but show a dedicated `No recorded entries` hint
- no-content days are not treated as normal detail targets in compact or regular navigation
- compact list can show highlight icons for busiest/longest day
- day rows support export-selection badge state and subtle highlight treatment in grouped and ungrouped layouts
- compact and regular day lists show an explicit export-context banner when selected days exist
- compact `Days` can jump back to the current day when the already selected tab is tapped again on iPhone
- regular-width list supports selection-driven detail display

Not present:
- favorites, pinning or manual sorting
- filter chips for activity types / semantic types directly in the list

## 5. Day Detail

Present:
- weekday/date header
- derived day time range when timed entries exist
- quick stats for visits, activities, routes and optional distance
- explicit separation between imported day data and local live-recording utilities
- structured sections for visits, activities and routes
- colored cards for visit/activity/route items
- empty states for `Select a Day`, `No Day Entries` and `Nothing Recorded`
- day timeline/Gantt visualization for visits and activities
- day detail is only entered for contentful days; empty calendar days remain list-only
- live recording section can appear inside day detail on supported platforms

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
- recenter button for live-location map

Not present:
- offline tile packs
- heatmap layer in the app UI
- manual map filters / overlay toggles beyond the base style toggle

## 6a. Local Recording / Saved Live Tracks

Present:
- foreground-only live recording with current-position marker and live polyline
- permission/status card and record toggle inside day detail
- completed recordings are persisted as separate local `Saved Live Tracks`
- dedicated recorded-tracks library page with summary, latest-track preview and editor navigation
- saved-track editor supports point editing, midpoint insertion and delete
- live-recording area links into the separate library instead of duplicating a second inline editor flow

Not present:
- background live tracking
- auto-resume of in-progress recordings after relaunch
- merging saved live tracks back into imported history

## 7. Insights / Statistiken / Diagramme

Present:
- distance-over-time chart when distance data exists
- daily averages cards when at least two days exist
- activity-type breakdown cards
- activity-type chart with `Count` / `Distance` toggle
- visit-type chart and list
- weekday chart when enough day data exists
- period breakdown cards when period stats exist
- explicit empty-state/fallback messaging for no-days, low-data and section-unavailable insight cases
- visible chart hints/labels for tap navigation, selected metric context and weekday averages
- insights are built from decoded stats with day-level fallbacks where implemented

Not present:
- custom chart density controls
- export/share for charts
- map-linked cross-filtering from insights

## 8. Optionen / Einstellungen

Present:
- distance-unit preference
- start-tab preference for compact layout
- default map-style preference
- toggle for showing technical import details
- reset-to-defaults action
- privacy info section clarifying local-only storage, no server upload and foreground-only live recording

Not present:
- sync/server toggles
- background-location settings
- per-chart or per-screen visual customization

## 9. Export / Teilen / Server / Sync

Present:
- dedicated `Export` tab on compact layout
- export sheet entry on regular width
- multi-day selection with `Select All` / `Deselect All`
- saved live tracks can be selected in the same export flow
- system `fileExporter` flow
- GPX generation from selected imported days and selected saved live tracks
- suggested export filename based on selected days
- export summary card with selected-day count, route-day count, distance total and filename preview
- disabled export button when nothing is selected or no selected day has routes
- explicit disabled-reason messaging and clearer marking of days without GPX route data

Bewusst deaktiviert, aber vorhanden:
- `ExportFormat` enum exists as an extension point for additional formats

Not present:
- active KML or CSV export in the app UI
- per-route selection inside a day
- waypoint export for visits / activities
- cloud sync, server upload or account-backed sharing

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
- `RecordedTrackFileStore` persists completed live tracks in app support storage
- demo support loads bundled golden fixtures through the same app-support layer

Not present:
- networking stack
- analytics / telemetry
- server-backed persistence

## 12. Noch bewusst deaktivierte, aber vorhandene Unterbauten

Present as underlaying code, but not active as product behavior:
- import bookmark restore infrastructure exists, but auto-restore on launch is parked
- recorded live tracks persist after recording stops, but there is no draft resume for an in-progress recording
- export architecture can grow beyond GPX, but only GPX is currently active

Explicitly not present as active product features:
- background location tracking
- automatic resume of live recording after app relaunch
- merge of recorded live tracks into imported history
- dedicated sync/server features
