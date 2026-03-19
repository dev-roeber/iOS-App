# APP Feature Inventory

Last analysis: 2026-03-19

Repos in scope:
- `LocationHistory2GPX-iOS`: verified in this workspace
- `LH2GPXWrapper`: not available in this workspace during this audit; no wrapper-only features are claimed below

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
- import-status card and active export filters lead the overview before highlights and totals
- compact layout overview exposes a dedicated `Go To` block for `Days`, `Insights` and `Export`
- overview screen with statistics cards for days, visits, activities and routes, framed explicitly as imported history
- optional date-range header when days exist
- optional total-distance summary card when distance data exists
- highlight cards for busiest day and longest-distance day
- source/status card with optional technical disclosure details
- overview entry card for the saved-tracks library as a separate `Local Tools` block after imported-history content

Not present:
- dedicated onboarding dashboard state distinct from the import-first root
- customizable overview modules or reordering

## 4. Days / Day List

Present:
- sorted day list derived from export days
- month grouping when multiple months are present
- compact search by date string
- list-level export-selection summary card in compact and regular day lists
- day rows show weekday, formatted date, visit/activity/route counts and optional distance
- export-marked days carry a visible `Export` badge
- no-content days stay visible in the list, but show a dedicated `No recorded entries` hint
- search empty state explains when selected export days still remain after clearing the query
- no-content days are not treated as normal detail targets in compact or regular navigation
- compact list can show highlight icons for busiest/longest day
- day rows support export-selection badge state in grouped and ungrouped layouts
- regular-width list supports selection-driven detail display

Not present:
- favorites, pinning or manual sorting
- filter chips for activity types / semantic types directly in the list

## 5. Day Detail

Present:
- weekday/date header
- derived day time range when timed entries exist
- quick stats for visits, activities, routes and optional distance
- structured sections for visits, activities and routes
- colored cards for visit/activity/route items
- empty states for `Select a Day`, `No Day Entries` and `Nothing Recorded`
- day timeline/Gantt visualization for visits and activities
- day detail is only entered for contentful days; empty calendar days remain list-only
- live recording section can appear inside day detail on supported platforms, including direct access to saved tracks

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

## 7. Insights / Statistiken / Diagramme

Present:
- dedicated top-level empty state when an export has no day summaries
- distance-over-time chart when distance data exists
- distance-over-time section keeps a dedicated no-distance explanation instead of disappearing
- distance-over-time bars can navigate to the nearest matching day when day navigation is wired in
- sparse one-day exports explain that comparative insights are still limited
- daily averages section shows a readiness explanation when fewer than two days exist
- activity-type breakdown cards
- activity-type section shows an explicit empty state when no aggregated activity totals exist
- activity-type chart with `Count` / `Distance` toggle only when distance data exists
- visit-type chart and list
- visit-type section shows an explicit empty state when no semantic visit categories exist
- weekday chart with explicit low-data explanation when too few days or weekdays are present
- period breakdown section shows an explicit empty state when export stats contain no periods
- period breakdown cards when period stats exist
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
- system `fileExporter` flow
- GPX generation from selected days
- suggested export filename preview based on selected days
- explicit export-selection status card before the day list
- disabled export button with reason-specific helper copy when nothing is selected or no selected day has routes
- mixed selections explain when only part of the chosen days will contribute GPX routes

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
