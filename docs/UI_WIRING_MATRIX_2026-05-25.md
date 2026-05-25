# UI Wiring Matrix — 2026-05-25 (Train 8.1)

**HEAD geprüft:** `66de66a` · **Scope:** sichtbare UI-Aktionen, Navigationen, Toggles, Menüs, Sheets, Alerts, Export/Import/Live/iCloud/Map/Insights-Aktionen.

| Screen | UI-Element | Aktion | Ziel-Funktion | State-Quelle | Fehlerzustand | Empty State | Accessibility | Status | Code-Referenz |
|---|---|---|---|---|---|---|---|---|---|
| Home (Wrapper) | „Open location history file" | öffnet System-fileImporter | `isImportingFile = true` → `.fileImporter` → `handleImportResult` | `@State isImportingFile` | `exportError`-Alert / `AppMessageCard` | `emptyStateView` | `home.openFile` + Hint | wired | `wrapper/.../ContentView.swift:264` |
| Home (Wrapper) | „Load Demo Data" | lädt Demo-Fixture | `loadBundledDemo()` → `DemoDataLoader` | `session` | `session.message` | n/a | `home.loadDemo` + Hint | wired | `wrapper/.../ContentView.swift:270` |
| Home (Wrapper) | „Clear" | leert geladenen Inhalt | `clearCurrentContent()` | `session` (nur sichtbar bei Error) | n/a | n/a | `home.clearError` + Hint | wired (conditional) | `wrapper/.../ContentView.swift:274` |
| Home (Wrapper) | Privacy-Chip | rein informativ | — | statisch | n/a | n/a | `home.localNotice` + Label | wired | `wrapper/.../ContentView.swift:283` |
| Home Menu | „Open File" / „Demo" / „Options" / „Clear" | wie oben + Options-Sheet | jeweilige Closures | `session` + `isShowingOptions` | n/a | n/a | **NEU** `appshell.menu.*` + Hint (Train 8.1) | wired | `wrapper/.../ContentView.swift:184-203` |
| Overview Empty | „Import File" | öffnet System-fileImporter über `onOpen` | `onOpen()` | `session.hasLoadedContent == false` | — | echte CTA-Card | `overview.empty.import` + Body + Privacy-Hint | wired | `Sources/.../AppContentSplitView.swift:825` |
| Settings | 9 sectionLinks (General/Maps/Import/Live Recording/Upload/Widget&LA/Privacy/iCloud/Technical) | NavigationLink in jeweilige Sub-View | `AppGeneral…View`/`AppMapsOptionsView`/…/`AppICloudOptionsView`/`AppTechnicalOptionsView` | `preferences` (AppPreferences) | jede Sub-View intern | n/a | `options.title` + 9× `options.<name>` | wired | `Sources/.../AppOptionsView.swift:17-110` |
| Settings → iCloud | `LHXSyncStatusCard` | Toggle iCloud-Status | `preferences.iCloudSyncEnabled.toggle()` → `viewModel.setEnabled` → `CKContainer.accountStatus()` | `AppPreferences.iCloudSyncEnabled` + `CloudSyncService.status` | `LHXSyncStatusCard.kind = .error(message)` | `.disabled` Kind | `options.icloud.statusCard` | wired | `Sources/.../AppICloudOptionsView.swift:66-77` |
| Settings → iCloud | „Refresh status" | manueller AccountStatus-Refresh | `Task { await viewModel.refresh() }` | `viewModel.status.isWorking` | UI-Update mit `.error`-Kind | n/a | `options.icloud.refresh` + Label + **NEU** Hint (Train 8.1) | wired | `Sources/.../AppICloudOptionsView.swift:80-91` |
| Settings → iCloud | „Suggest iCloud Drive" Toggle (F.3) | flippt UI-Hint im Export | `preferences.preferCloudDriveExport` (UserDefaults) | `AppPreferences` | — | — | `options.icloud.driveExportToggle` + Caption + Footer | wired (UI-Hint, dokumentiert kosmetisch) | `Sources/.../AppICloudOptionsView.swift:167-184` |
| Settings → iCloud | `LHXInfoCard` Privacy-Footer | rein informativ | — | statisch | n/a | n/a | `options.icloud.footer` | wired | `Sources/.../AppICloudOptionsView.swift:93-100` |
| Export | Format-Picker (5 Formate) | wählt `selectedFormat` | `@State selectedFormat` | lokal | — | — | `export.format.card` + `export.hero.formatPill` | wired | `Sources/.../AppExportView.swift:707-719` |
| Export | `LHXEmptyState` „Nothing to Export" | informativ + `selectionFallbackActions` | — | `session.daySummaries.isEmpty && liveLocation.recordedTracks.isEmpty` | — | echte LHXEmptyState | `export.emptyState` | wired (UI-Adoption I) | `Sources/.../AppExportView.swift:1346-1357` |
| Export | „Select All Days" / „Select All Tracks" | Selection-CTAs | `session.exportSelection.selectAll(...)` | `session.exportSelection` | — | — | `export.days.selectAll.cta` / `export.liveTracks.selectAll.cta` | wired | `Sources/.../AppExportView.swift:1295-1313` |
| Export | „Open Days" / „Import File" Fallback | Navigation/Import | `openDaysReview()` / `onOpenImport?()` | `onOpenDays`/`onOpenImport`-Closures | — | — | (inherited) | wired (Split-View-Pfad: TODO 8.6 verfeinern) | `Sources/.../AppExportView.swift:1267-1281` |
| Export | `exportTargetCard` Privacy-Hint (F.3) | informativ + Suggest iCloud Drive | — | `preferences.preferCloudDriveExport` (read-only) | n/a | n/a | `export.target.card` + `export.target.iCloudDriveHint*` | wired | `Sources/.../AppExportView.swift:915-930` |
| Export | `selectionSummaryCard` Filename + Privacy (Export UX I) | informativ | `exportFilenamePreview(...)` | `session.exportSelection` | — | n/a | `export.selection.filenamePreview` + `export.selection.privacyHint` | wired | `Sources/.../AppExportView.swift:581-608` |
| Export | „Export"-Button (Bottom Bar) | öffnet System-fileExporter | `prepareExport(...)` → `isExporting = true` → `.fileExporter` | `@State isExporting`, `exportDocument` | `exportError`-Alert + `LHContextBar`-Invalid | `LHXEmptyState` | `export.primaryButton` (in LHExportBottomBar) | wired | `Sources/.../AppExportView.swift:1337-1366` |
| Insights | Range-Filter, Surface-Picker, KPIs, Charts | reine UI-State-Updates | jeweilige `@State`-Bindings | `derivedModel` (Cache) | `LHXEmptyState` „No Insights Yet" | `LHXEmptyState` mit optionalem „Reset Filter" | `insights.emptyState` + `insights.empty.resetFilter` (UI-Adoption I) | wired | `Sources/.../AppInsightsContentView.swift:426-454` |
| Insights | Streak-Section | renderingsicheres `InsightsStreakCardView` (Insights Refactor I) | präsentational | `derivedModel.streak` | `insightsEmptyCard` | bei `streakStat.activeDaysCount == 0` | `insights.streak.recent` / `insights.streak.best` | wired | `Sources/.../AppInsightsContentView.swift:996-1032` |
| Heatmap | `MapLayerMenu` Overlay | Palette/Scale/Radius/Opacity/Fit | `preferences.heatmap*` + `fitToData` | `preferences` + `model` | informativ | `calculatingOverlay` | `heatmap.layerMenu` + `heatmap.computing` + `heatmap.statsBadge` (Map UX I) | wired | `Sources/.../AppHeatmapView.swift:28-50` |
| Day Detail | Route-Display-Picker | wählt `dayPathDisplayMode` | `preferences.dayPathDisplayMode` | `preferences` | — | — | `dayDetail.routeDisplay` (Map UX I) | wired | `Sources/.../AppDayDetailView.swift:268-278` |
| Day Detail | Hero-Map + Collapsible Header | Layer/Fit/Fullscreen | `LHCollapsibleMapHeader` + `MapLayerMenu` | `dayMapHeaderState` | — | — | `dayDetail.map` + `dayDetail.stickyHeader` | wired | `Sources/.../AppDayDetailView.swift:240-282` |
| Days List | Day-Row (selectable) | NavigationLink → Day Detail | `selectedDayId`-Binding | `session.daySummaries` | — | — | `days.row.<date>` + **NEU** Hint bei `!hasContent` (Train 8.1) | wired | `Sources/.../AppDayListView.swift:374-377` |
| Live | Pause/Resume Uploads-Button | `liveLocation.togglePauseUploads()` | `liveLocation.canPauseUploads` | `LiveLocationFeatureModel` | live-eigene Fehler-Pfade | — | `live.cta.pause` + **NEU** Hint (Train 8.1) | wired | `Sources/.../AppLiveTrackingView.swift:887-892` |
| Live | „Flush Queue"-Button | `liveLocation.flushPendingUploads()` | `liveLocation.canFlushPendingUploads` + `pendingUploadPointCount > 0` | `LiveLocationFeatureModel` | — | — | **NEU** `live.cta.flushQueue` + Hint (Train 8.1) | wired | `Sources/.../AppLiveTrackingView.swift:894-903` |

## Train 8.1 — behobene Dead-Hint-Stellen

| Stelle | Vorher | Nachher (Train 8.1) |
|---|---|---|
| `wrapper/.../ContentView.swift:184-203` (Home-Actions-Menu) | 4 Menüpunkte ohne `accessibilityIdentifier`/`accessibilityHint` | 4 Identifier (`appshell.menu.openFile`/`loadDemo`/`options`/`clear`) + Hint je Menüpunkt; Menü-Root-Identifier `appshell.actionsMenu` |
| `Sources/.../AppLiveTrackingView.swift:887-892` (Pause/Resume Uploads) | `.disabled(!canPauseUploads)` ohne Hint | Bedingter Hint („Available while a live recording is running and uploads are enabled in Settings." vs. „Stops sending live points to your server…") |
| `Sources/.../AppLiveTrackingView.swift:894-903` (Flush Queue) | `.disabled(!canFlushPendingUploads)` ohne Identifier/Hint | **Neuer** Identifier `live.cta.flushQueue` + bedingter Hint |
| `Sources/.../AppICloudOptionsView.swift:80-91` (Refresh status) | `.disabled(isWorking)` ohne Hint | Bedingter Hint („Checking iCloud — please wait…" vs. „Re-checks whether iCloud is available…") |
| `Sources/.../AppDayListView.swift:374-377` (Day Row) | `.disabled(!summary.hasContent)` ohne Hint | Hint bei leerem Tag („This day has no exportable routes or visits.") |

## Train 8.1 — bewusst nicht angefasst (deferred)

| Stelle | Grund / wann |
|---|---|
| `AppExportView.swift:1267-1281` `openDaysReview()` Split-View-Routing | iPad-Split-View-Pfad ist Map/Navigation-Layout-Thema → **Train 8.6** (Map Layer & Route Interaction) |
| `AppLiveTrackingView.swift:938` „Open Library"-Bedingungsrender | reine Sichtbarkeitsfrage; höheres Risiko bei Layout-Änderung → **Train 8.10** (Live Tracking / Upload Control Center) |
| `preferCloudDriveExport` als „rein kosmetisch" | dokumentiert (F.3 + CHANGELOG); inhaltlich korrekt — kein Eingriff nötig |

## Forbidden-Pattern-Sweep (Train 8.1)

| Pattern | Treffer | Status |
|---|---|---|
| `publicCloudDatabase` | 0 (außer Anti-Claim-Doku) | ✅ |
| `sharedCloudDatabase` | 0 (außer Anti-Claim-Doku) | ✅ |
| `CKSubscription` / `CKAsset` / `CKQuery` | 0 | ✅ |
| `.save(`/`.fetch(` in `CloudKit*.swift` | 0 | ✅ |
| `coming soon` / `dummy` / `not implemented` / `fatalError` / `preconditionFailure` (außer kontrollierten Bestandskommentaren) | 0 neu in Train 8.1 | ✅ |
| `.disabled(true)` ohne Grund | 0 (3 Treffer in `LH2GPXLoadingBackground` sind dekorativ `allowsHitTesting(false)`-Layer) | ✅ |
