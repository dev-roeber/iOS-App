# App Redesign · Interaktions- & iCloud-Strategie

Stand: **2026-05-22** · Branch `chore/redesign-interaction-spec` · basiert auf
`docs/DEEP_AUDIT_FULL_APP_REDESIGN_ICLOUD_2026-05-22.md` (HEAD vor diesem
Commit: `4f0813a`).

> Planungspapier. **Kein Code in diesem Commit**, keine Builds, keine Tests.
> Doku-Updates in NEXT_STEPS / ROADMAP / Feature-Inventory verweisen auf
> diese Spezifikation, behaupten aber keine Umsetzung.

---

## 1. Executive Summary

**Zielbild der App (v1.x):**
LH2GPX bleibt eine *private, lokal-first* iPhone-App für Auswertung und Export
persönlicher Standorthistorie. Kein Account, kein zentraler Dienst. Live-
Tracking und Upload sind und bleiben optional + Opt-in. iCloud kommt
ausschließlich als *Opt-in-Komfort* für (a) kleine Settings, (b) kleine
strukturierte Saved-Live-Track-Metadaten und (c) optionalen Export-Speicher.

**Kurzfristig sinnvoll:**
1. Doku-Truth-Sync: aktuelle HEAD-Aussagen + iPad-/Light-Mode-Ehrlichkeit.
2. UI-Komponentenbasis erweitern (neue additive Bausteine für `StatCard`,
   `EmptyState`, `ErrorState`, `LoadingState`, `SyncStatusCard` u. a.).
3. Cancel-Button im Default-Import.
4. Polygon-Filter-Map-Picker als Ersatz für Freitext.
5. Refactor der drei großen Hub-Views in mehrere Files.

**Bewusst verschoben:**
- iPad-Freischaltung (`TARGETED_DEVICE_FAMILY=1,2`) bis NavigationSplitView-
  Polish auf Apple-Hardware verifizierbar ist.
- Light-Mode: erst entscheiden, dann ausführen. Default-Empfehlung: bewusster
  Dark-only Status (`UIUserInterfaceStyle = Dark` in Info.plist).
- iCloud-Phase B (CloudKit Private Database) — nur sinnvoll, wenn Saved-Live-
  Tracks-Metadaten erweitert sind und ein klarer UX-Mehrwert da ist.
- Default-Rollout des LocalTimelineStore-Spikes — bleibt feature-flagged, bis
  46-MiB-Original-Asset-Hardware-Retest grün ist.

---

## 2. Informationsarchitektur (Zielstruktur)

### iPhone (Compact) — TabView mit fünf Tabs

| Tab | Zweck | Primärinhalt | Sekundärinhalte |
|---|---|---|---|
| `Start` | Übersicht / Quick-Actions | KPI-Strip · Hero-Map · Highlights · Continue-Card · Saved-Live-Tracks-Eingang | Import-Card · Demo-Card |
| `Tage` | chronologische Day-List | Hero-Map (sticky) · Filter-Chips · Day-Rows | Drilldown-Banner · Export-Auswahl-Bottom-Bar |
| `Karte` *(neu, optional)* | dauerhafter Map-Modus | Vollbild-Map mit Layer-Menü | Heatmap-Overlay · Tag-Selector |
| `Insights` | aggregierte Statistik | Overview · Patterns · Breakdowns | Share-Aktionen |
| `Export` | Auswahl + Format + Vorschau | Selection-Summary · Format-Pills · Preview · Filter | Custom-Filename · iCloud-Drive-Ziel |
| `Live` | manuelle Aufzeichnung | Status-Card · Karten-Card · Diagnostics · Upload-Card · Saved-Library | Permission-Card |

**Hinweis**: ein separater `Karte`-Tab ist nicht zwingend — Heatmap und Day-
Map sind heute kontextuell (Sheet/Day-Detail). Die Spec dokumentiert ihn als
*Option*, nicht als *Pflicht*. Entscheidung wird in Train D getroffen.

### Globaler Header / Toolbar

- `Actions`-Menu (Import, Demo, Options, Saved-Tracks, Clear) bleibt.
- *Neuer* `SyncStatus`-Indikator (klein, top-right, nur sichtbar wenn iCloud
  aktiviert) — siehe §6.

### Modale Surfaces

| Sheet | Trigger | Inhalt |
|---|---|---|
| `Options` | Actions-Menu | settings (Distanz/Sprache/Start-Tab/Map-Style/Live-Detail/Upload/Auto-Restore/iCloud) |
| `Heatmap` | Overview-Chip oder Karte-Tab | `AppHeatmapView` |
| `Tracks Library` | Overview-Card / Live / Actions | `AppRecordedTracksLibraryView` |
| `Export` *(Regular only)* | Actions-Menu | `AppExportView` |
| `Polygon Picker` *(neu)* | Export-Filter | interaktiver Map-Polygon-Editor |
| `iCloud Status` *(neu)* | Options-Card | Account-Status · letzte Sync-Zeit · Fehler |

### Empty / Error / Loading States

Jeder Tab + jede Card hat eine drei-Phasen-Zustandsmatrix:
- **Loading**: einheitliche `LoadingStateView` (Spinner + Phase-Label).
- **Empty**: einheitliche `EmptyStateView` (Icon · Headline · Body · primäre
  Aktion).
- **Error**: einheitliche `ErrorStateView` (Icon · Headline · Body · Retry-/
  Clear-Aktion).

---

## 3. Navigation

### 3.1 iPhone-First

- Compact (regulär iPhone): `TabView { ... }` mit fünf Tabs.
- Jeder Tab hat eigenen `NavigationStack`.
- Tab-Reselection: Days-Tab springt auf "heute" zurück
  (`IOSTabReselectionObserver`, bereits vorhanden).
- Deep Link `lh2gpx://live` → Live-Tab (bereits vorhanden, wird erhalten).

### 3.2 iPad (geplant — *nicht* in dieser Spec aktiviert)

`regularSplitView` ist im Code, ist aber durch `TARGETED_DEVICE_FAMILY = 1`
nicht aktivierbar. iPad-Aktivierung ist ein eigener Train mit:

- pbxproj: `TARGETED_DEVICE_FAMILY = "1,2"` in 8 Configs.
- Sidebar-Layout-Polish (NavigationSplitView ist da, aber unverifiziert).
- App-Icon-Asset für iPad-Größen prüfen.
- Hardware-Smoke iPad.

Bis dahin: README/ROADMAP sagen ehrlich "iPhone-only v1.0.2".

### 3.3 Landscape

- iPhone Landscape: bereits unterstützt (`UISupportedInterfaceOrientations~iphone`
  inkl. Landscape). Hero-Map kollabiert, Filter-Bar bleibt sichtbar.
- iPad Landscape: nicht aktivierbar bis Family=1,2.

### 3.4 Deep Links — Inventar

| Schema | Zustand | Aktion |
|---|---|---|
| `lh2gpx://live` | ✅ vorhanden | Live-Tab |
| `lh2gpx://import?path=…` | ❌ nicht implementiert | als *Optionale* Erweiterung Train G |
| `lh2gpx://export?days=…` | ❌ nicht implementiert | nicht geplant |

Universal Links sind heute nicht konfiguriert (kein `applinks`-Entitlement).
Bleibt out-of-scope.

---

## 4. UI-Komponenten-System

Alle Komponenten sind additiv und SwiftUI-only. Naming-Konvention `LHX*`
(neu) oder `LH*` (bestehend). Ziele: konsistente Paddings, einheitliche
States, einheitliche Accessibility-Identifier.

| Komponente | Status heute | Zielzustand | Wichtigste Props |
|---|---|---|---|
| `LHCard` / `LHMetricCard` | ✅ vorhanden | bleibt | – |
| `LHSectionHeader` | ✅ | bleibt | – |
| `LHFilterChip` | ✅ | bleibt | – |
| `LHStatusChip` | ✅ | bleibt | – |
| `LHContextBar` | ✅ | bleibt | – |
| `LHCollapsibleMapHeader` / `LHHeroMapLayout` | ✅ | bleibt | – |
| `LHExportBottomBar` / `LHLiveBottomBar` | ✅ | bleibt | – |
| `ProductInfoCard` | ✅ (Train Q) | bleibt | – |
| **`LHXStatCard`** | ❌ neu | dünner Wrapper über `LHMetricCard` mit `value`/`unit`/`trend?` | icon, label, value, unit?, trend? |
| **`LHXActionCard`** | ❌ neu | Card mit primärer + sekundärer Aktion | title, body, primaryAction, secondaryAction? |
| **`LHXInfoCard`** | ❌ neu | reiner Hinweis-Card-Stil | title, body, icon, kind (info/warn/error) |
| **`LHXEmptyState`** | ❌ neu | konsolidiert die ~10 vorhandenen ad-hoc Empty-States | icon, title, body, primaryAction? |
| **`LHXErrorState`** | ❌ neu | konsolidiert Error-UI | icon, title, body, retry?, dismiss? |
| **`LHXLoadingState`** | ❌ neu | konsolidiert ProgressView+Phase-Label | progress?, phaseLabel?, cancel? |
| **`LHXPrimaryActionButton`** / **`LHXSecondaryActionButton`** | ❌ neu | konsistente Buttons mit DynamicType-Kappung | title, icon?, role, isDisabled, disabledReason? |
| **`LHXMapOverlayControl`** | ❌ neu | konsolidiert Floating-Map-Controls | icon, action, identifier |
| **`LHXTimelineScrubber`** | ❌ neu | horizontaler Day-Selector (kommt erst mit Karte-Tab) | days, selection, onSelect |
| **`LHXSyncStatusCard`** | ❌ neu | iCloud-Status-Card in Options | accountStatus, lastSyncAt?, errorMessage? |
| **`LHXImportValidationSummaryCard`** | ✅ (Train Q als `importSummaryCard` in `AppExportView`) | als reusable Component extrahieren | export |
| **`LHXExportPreviewCard`** | ⚠️ teilweise als Inline-Section in `AppExportView` | extrahieren | selection, format, mode, filename |

---

## 5. Interaktivitätsmodell — was muss real verdrahtet sein

Jede sichtbare Aktion hat einen Pflichtweg in §9 (Vollverdrahtungs-Matrix).
Hier nur die Kernaktions-Kataloge:

| Aktionsfamilie | Trigger | Zielfunktion |
|---|---|---|
| Import starten | Home-Button / Actions-Menu / Recent-Files | `fileImporter` → `LH2GPXAppFlow.loadImportedFileEnvelope` |
| Import abbrechen | *neuer Cancel-Button im Loading-Branch* | aktuell nur Store-Pfad; soll auch Default-Pfad signalisieren können (best-effort) |
| Importfehler anzeigen | Loader-Outcome `.failure` | `AppMessageCard` + Retry/Clear-Aktion |
| Tag auswählen | Day-Row / Drilldown / Tab-Reselection | `session.selectDayForDisplay` |
| Timeline-Element auswählen | Day-Detail-Tile | scroll-to + accentuate (heute teilweise) |
| Route auf Karte fokussieren | Day-Detail-Map-Pin | `MapCameraPosition.region(...)` (heute fit-to-data) |
| Heatmap-Layer wechseln | `MapLayerMenu` Picker | `AppHeatmapView` Bindings |
| Exportformat wählen | Format-Pills | `selectedFormat` |
| Exportvorschau anzeigen | live | `AppExportPreviewMapView` |
| Exportziel wählen | Export-Button | `fileExporter` (lokal); *Phase C*: iCloud Drive optional |
| Live Tracking starten/stoppen | `LHLiveBottomBar` | `liveLocation.startRecording`/`stopRecording` |
| iCloud-Status anzeigen | Options → `LHXSyncStatusCard` | reads `CloudSyncService.status` (Service in Train F) |
| Settings ändern | Options-Sheet | `AppPreferences` + persist UserDefaults / KV-Store (Phase A) |

**Regel:** Wenn ein Button heute *nicht* verdrahtet ist, MUSS er entweder
gelöscht werden oder `.disabled(true)` + sichtbarer `disabledReason`-Tooltip
(z. B. via `LHXPrimaryActionButton.disabledReason`).

---

## 6. iCloud-Strategie in Phasen

### Sicherheitslinie (alle Phasen)

- **Keine Public Database** (CloudKit `publicCloudDatabase` ist verboten).
- **Kein automatischer Upload** importierter Historien — sie sind dafür zu
  groß und zu sensibel.
- **Lokal-First bleibt Default**. iCloud ist *Komfort*, nicht *Notwendigkeit*.
- **iCloud deaktivierbar** in Options.
- **Account-Status-Resilienz**: `CKAccountStatus.noAccount` /
  `.restricted` / `.couldNotDetermine` → klar kommuniziert, lokale Funktion
  unverändert.
- **Keine sensiblen Daten in Logs**: Koordinaten, Tokens, Bearer-Header
  niemals geloggt.

### Phase A — `NSUbiquitousKeyValueStore` (Settings & kleine Sets)

**Was hinein darf** (low-risk, 1 MiB Hard-Quota):
- `AppPreferences`-Skalare: `distanceUnit`, `appLanguage`, `startTab`,
  `mapStyle`, `liveTrackingAccuracy`, `liveTrackingDetail`,
  `liveTrackingUploadBatch`, `dynamicIslandCompactDisplay`,
  `autoRestoreLastImport`, `widgetAutoUpdate`.
- `DayFavoritesStore` (Set von Day-IDs, typisch < 10 KB).
- `RecentFilesStore`-*Slugs* (nur `displayName` + `lastOpenedAt`, **keine**
  `bookmarkData`).

**Was *nicht* hinein darf:**
- Security-Scoped-Bookmarks (gerätbezogen, nicht portierbar).
- Bearer-Token (bleibt im Keychain).
- Upload-URL (kann theoretisch, aber bewusst erst in Phase B).
- Saved-Live-Tracks (zu groß).
- LocalTimelineStore-Inhalte.

**Kritische Bewertung**: Phase A bringt echten Nutzen *nur*, wenn der User
mehrere Apple-Geräte besitzt. Ohne Multi-Device-User ist das Code-Mehr-
gewicht nicht gerechtfertigt. **Empfehlung**: Phase A als *optional / low-
priority* markieren. Erste Implementation kann auf reines `AppPreferences`-
Skalare beschränkt bleiben (kleinster Risiko-Footprint).

### Phase B — CloudKit `privateCloudDatabase`

**Inhalt**: `LiveTrackMeta` Records (Datum, Dauer, Punktzahl, Distanz,
Source-Filename) + optional `CKAsset` für komprimierte Geometrie
(gzip GeoJSON) — *nur wenn User explizit "Live-Track in iCloud sichern"
aktiviert*.

**Container**: `iCloud.de.roeber.LH2GPXWrapper` (separater iCloud-Container,
nicht App-Group).

**Schema-Versions-Pflicht** ab Tag 1 (`schemaVersion: Int` in jeder Record).

**Konfliktstrategie**: Last-Write-Wins für Metadaten, Asset überschreibt
nur bei explizitem User-Confirm.

**Account-Status-Pfade**:
- `available` → normaler Sync.
- `noAccount` / `restricted` → iCloud-Card zeigt "Nicht eingeloggt" + Link
  zu Einstellungen.
- `couldNotDetermine` → Retry mit Backoff.
- `temporarilyUnavailable` → Banner, lokale Funktion unverändert.

**Push**: optional CloudKit Subscriptions (`CKQuerySubscription`) für
Cross-Device-Refresh. *Nicht* in v0 — erst wenn Phase B Stabil ist.

### Phase C — iCloud Drive / Document Picker

**Inhalt**: User-sichtbare Exporte (GPX/KMZ/GeoJSON/CSV) und *manuell* in
iCloud Drive abgelegte Importdateien.

**Mechanik**:
- Export: `fileExporter` zeigt iCloud-Drive bereits, wenn `iCloud Drive`
  systemweit aktiv ist. Phase C ändert *nichts* am Code — nur Doku +
  Privacy-Hinweis.
- Import: `fileImporter` greift automatisch auch in iCloud Drive zu, sobald
  Container aktiv. Keine Code-Änderung nötig.
- Optional: explizites "in iCloud sichern"-Toggle pro Export.

**Privacy**: Phase C ist die *am wenigsten* invasive Variante. Empfehlung:
diese Phase als erste konkrete UI-Verbesserung umsetzen ("Save to iCloud
Drive"-Affordance im Export-Sheet).

### Empfohlene Reihenfolge

1. **Phase C** zuerst (kein Sync-Code nötig).
2. **Phase B** danach (echter Mehrwert für Live-Tracks-Cross-Device).
3. **Phase A** *optional*, nur falls Multi-Device-User explizit nachgefragt.

---

## 7. Datenschutz / App Store

### 7.1 Privacy-Manifest-Pflicht-Updates pro Phase

| Phase | `NSPrivacyAccessedAPITypes` | `NSPrivacyCollectedDataTypes` |
|---|---|---|
| Heute | `UserDefaults (CA92.1)` | `PreciseLocation` (App Functionality) |
| Phase A | + ggf. `NSPrivacyAccessedAPICategoryFileTimestamp` (KV-Store-Timestamps) | unchanged |
| Phase B | + `…UbiquityContainerIdentifiers` (Entitlement) | + ggf. *Other Data Types* falls Metadata-Klassifikation greift |
| Phase C | + `…UbiquityContainerIdentifiers` | unchanged |

**Verifikationspflicht** vor jedem TestFlight-Upload:
- `rg -n "(NSAllowsArbitraryLoads|NSExceptionDomains)" wrapper/`
- `rg -n "URLResourceValues" Sources/` → prüfen ob FileTimestamp-Reason fällig
- `rg -n "ProcessInfo.processInfo.systemUptime" Sources/` → SystemBootTime
- `rg -n "(volumeAvailableCapacity|systemFreeSize)" Sources/` → DiskSpace

### 7.2 App Store Review Risiken

| Risiko | Mitigation |
|---|---|
| Guideline 3.2 (Build 74 historisch abgelehnt) | Marketing-Description: "Public consumer/utility app. No account, no organization, no central server." Public Audience Statement bleibt im Feature Inventory. |
| Background Location | Banner + Status-Card + Permission-Card. *Neu*: dediziertes "What this does in the background"-Sheet (Train C). |
| HTTPS-Upload + Bearer Token | Bereits sauber: HTTPS-only außer localhost, SecureField, Keychain. |
| iCloud-Container ohne sichtbaren Mehrwert | Phase B nicht aktivieren, bevor mind. eine sichtbare Surface (Live-Track-Cross-Device-Restore) implementiert ist. |
| Konflikt-UX | `LHXSyncStatusCard` zeigt Konflikte sichtbar; lokale Datei wird nicht blind überschrieben. |

### 7.3 Opt-in-Texte (Vorlage)

- iCloud aktivieren: *"Wenn du iCloud Sync aktivierst, werden ausgewählte
  Einstellungen und Saved Live Tracks zwischen deinen Geräten über deinen
  privaten iCloud-Account synchronisiert. Importierte Standorthistorien
  werden niemals automatisch synchronisiert. Du kannst iCloud jederzeit
  wieder deaktivieren."*
- Background Location: bestehender String unverändert (`NSLocationAlways…`).

---

## 8. Refactor-Plan für große Views

### 8.1 `AppContentSplitView` (1608 Zeilen)

**Problem heute:** ein File für (a) iPhone-Tab-Layout, (b) iPad-Split-Layout,
(c) Sheets, (d) Hero-Map-Workspaces für Overview + Days + Export, (e)
Drilldown-Routing, (f) Live-Tracking-Observer, (g) Actions-Menu.

**Zielstruktur** (in `Sources/LocationHistoryConsumerAppSupport/Shell/`):
- `AppShell.swift` — root switch zwischen `CompactShellView` und `RegularShellView`.
- `CompactShellView.swift` — `TabView` + Tab-Selection + Reselection.
- `RegularShellView.swift` — `NavigationSplitView` (für Phase iPad).
- `Tabs/OverviewTabView.swift`
- `Tabs/DaysTabView.swift`
- `Tabs/InsightsTabView.swift`
- `Tabs/ExportTabView.swift`
- `Tabs/LiveTabView.swift`
- `Shell/ActionsMenuView.swift`
- `Shell/AppShellRouter.swift` — `applyInsightsDrilldown`, `navigate(for:)`,
  `presentSheet`.
- `Shell/AppShellSheets.swift` — `PresentedSheet` enum + sheet content
  switch.

**Risiko**: alle existierenden Identifier müssen unverändert bleiben.
**Reihenfolge**: pro Tab ein eigener Mini-Train (`Extract DaysTabView`,
`Extract OverviewTabView`, …); jeweils byte-äquivalent zu prüfen.

### 8.2 `AppExportView` (1919 Zeilen)

**Problem heute**: Format-Filter-Selection-Preview-Bottom-Bar-Layout-State
in einem Container.

**Zielstruktur** (in `…/Export/`):
- `ExportRootView.swift` (hero-Layout + bottom-bar).
- `ExportContent.swift` (selection + cards).
- `Sections/ExportFormatSection.swift`
- `Sections/ExportModeSection.swift`
- `Sections/ExportRangeFilterSection.swift`
- `Sections/ExportAdvancedFiltersSection.swift`
- `Sections/ExportPolygonPickerSection.swift` *(neu, Train C)*
- `Sections/ExportPreviewSection.swift`
- `Sections/ExportDaysSection.swift`
- `Sections/ExportLiveTracksSection.swift`
- `ExportState.swift` — alle `@State` zentralisiert (oder besser:
  `@Observable` ViewModel ab iOS 17).

**Risiko**: viel `@State`-Bindings; sauberer Ein-Tab-Per-Train-Refactor.

### 8.3 `AppInsightsContentView` (1962 Zeilen)

**Problem**: ähnlich — Overview/Patterns/Breakdowns + Share-Helper + Drilldown.

**Zielstruktur** (in `…/Insights/`):
- `InsightsRootView.swift`
- `Sections/InsightsOverviewSection.swift`
- `Sections/InsightsPatternsSection.swift`
- `Sections/InsightsBreakdownsSection.swift`
- `Sections/InsightsHeroSection.swift`
- `Sections/InsightsShareSheet.swift`
- `InsightsState.swift`

---

## 9. Vollverdrahtungs-Zielmatrix

Legende: 🟢 = heute vollständig · 🟡 = teilweise · 🔴 = fehlt · 🆕 = neu in
Redesign-Spec.

| Screen | UI-Aktion | Heutiger Status | Ziel-Verhalten | State | Service | Empty/Error | A11y | Train |
|---|---|---|---|---|---|---|---|---|
| Start | Import-File-Button | 🟢 | unchanged | `isImportingFile` | `fileImporter`+`LH2GPXAppFlow` | Loading/Error/Empty | label + identifier vorhanden | C |
| Start | Cancel-Import 🆕 | 🔴 (nur Store-Pfad) | best-effort cancel im Default-Pfad | neuer `ImportCancellation` | `LH2GPXAppFlow` (erweitern) | – | "Cancel import" | C |
| Start | KPI-Karten | 🟢 | unchanged | `projectedOverview` | – | – | label per KPI | B |
| Start | Heatmap-Chip | 🟢 | unchanged | `presentedSheet` | `AppHeatmapView` | – | label | – |
| Start | iCloud-Status-Indikator 🆕 | 🔴 | optionaler Icon + Tap → Options | `CloudSyncService.status` | `CloudSyncService` (Train F) | offline → grau | "iCloud status" | F |
| Tage | Day-Row | 🟢 | unchanged | `daysNavigationPath` | – | "No results" | label | – |
| Tage | Filter-Chip | 🟢 | unchanged | `dayListFilter` | – | – | "Filter X" | – |
| Tage | Favorite-Swipe | 🟢 | unchanged | `DayFavoritesStore` | – | – | "Toggle favorite" | – |
| Karte | Polygon-Picker 🆕 | 🔴 | interaktiver Map-Polygon | `polygonCoords` | bestehender Filter | "Tap to add point" | label | C |
| Heatmap | Layer-Auswahl | 🟢 | unchanged | `AppHeatmapModel` | – | – | label | – |
| Insights | Drilldown | 🟢 | unchanged | `activeDrilldownFilter` | `InsightsDrilldownBridge` | – | label | – |
| Insights | Share | 🟡 Apple-host-only | unchanged | `ChartShareHelper` | `ImageRenderer` | – | "Share insights" | – |
| Export | Format-Pill | 🟢 | unchanged | `selectedFormat` | – | – | label | – |
| Export | Custom-Filename 🆕 | 🔴 | TextField vor Save-Dialog | neuer `customFilename` | – | leer → fallback | label | C |
| Export | iCloud-Drive-Ziel 🆕 | 🟡 (System-Default) | sichtbarer Toggle "Save to iCloud Drive" | `AppPreferences.preferCloudDriveExport` | `fileExporter` | – | label | F (Phase C) |
| Live | Start/Stop | 🟢 | unchanged | `liveLocation` | `LiveTrackRecorder` | Permission-Card | "Start/Stop" | – |
| Live | Upload-Pause | 🟢 | unchanged | `liveLocation` | `LiveLocationServerUploader` | Failure-Card | label | – |
| Options | iCloud aktivieren 🆕 | 🔴 | Toggle + Account-Status | `AppPreferences.iCloudSyncEnabled` | `CloudSyncService` | "Not signed in" | label | F |
| Options | iCloud-Status-Card 🆕 | 🔴 | `LHXSyncStatusCard` | `CloudSyncService.status` | `CloudSyncService` | – | grouped a11y | F |
| Options | Save to iCloud Drive (Default) 🆕 | 🔴 | Toggle | `AppPreferences.preferCloudDriveExport` | – | – | label | F (Phase C) |

---

## 10. Umsetzungstrains

Pro Train: Branchname-Vorschlag, klare Scope-Liste, Risiko, Test-/Build-
Pflicht *am Ende* (in Train H). Jeder Train ist klein gehalten, einzeln
mergebar.

### Train A — Doc-Truth + Head-/Status-Korrektur · `chore/doc-truth-sync-v3`
- Aktualisiere README/ROADMAP/NEXT_STEPS auf aktuelle HEAD-Story.
- iPad-Aussage ehrlich: "iPhone-only v1.0.2" + iPad als geplanter Train.
- Force-Dark-Status sauber dokumentieren.
- Risiko: minimal.

### Train B — UI-Komponentenbasis · `chore/full-app-redesign-foundation`
- Neue additive Komponenten `LHXStatCard`, `LHXActionCard`, `LHXInfoCard`,
  `LHXEmptyState`, `LHXErrorState`, `LHXLoadingState`,
  `LHXPrimaryActionButton`, `LHXSecondaryActionButton`,
  `LHXMapOverlayControl`, `LHXSyncStatusCard`.
- KEINE Änderung bestehender Views.
- Dokumentation pro Komponente.
- Risiko: gering (additiv).

### Train C — Start/Import/Export UX · `chore/ux-import-export-polish`
- Cancel-Button im Loading-Branch des Default-Imports.
- Polygon-Picker (interaktive Map).
- Custom-Filename in Export.
- "What background recording does"-Sheet.
- Risiko: mittel (mehrere Touch-Points).

### Train D — Karte/Timeline/Heatmap Interaktion · `chore/map-interaction-polish`
- Optional dauerhafter Karte-Tab (Entscheidung).
- TimelineScrubber für Day-Auswahl (Karte-Tab).
- Heatmap-Density-Truncation-Hinweis (UX-Hinweis bei Cap-Treffer).
- Risiko: mittel.

### Train E — Insights Refactor · `chore/insights-view-refactor`
- Aufteilung von `AppInsightsContentView` in Sections + State.
- Byte-äquivalent zu prüfen.
- Risiko: mittel.

### Train F — iCloud Optional Foundation · `feature/icloud-sync-foundation`
- `CloudSyncService` Foundation-only Interface + Default-Impl.
- `LHXSyncStatusCard` Anbindung.
- `AppPreferences.iCloudSyncEnabled` + `preferCloudDriveExport`.
- Phase A (KV-Store) optional, Phase C als Export-Hinweis verdrahtet,
  Phase B *nicht* in v0.
- Entitlement + pbxproj-Capability ausschließlich in Xcode UI setzen
  (Linux-Edits am pbxproj sind Risiko).
- Risiko: mittel-hoch (Capability ist Apple-Xcode-Pflicht).

### Train G — Vollverdrahtung · `chore/full-app-wiring-pass`
- Wiring-Matrix aus §9 abarbeiten.
- Disabled-Buttons + Reasons systematisieren.
- Identifier-Migration auf `AppAccessibilityID`.
- Risiko: gering–mittel.

### Train H — Tests / Builds / Xcode Cloud / TestFlight · `release/v1.1-rc`
- `swift test` lokal.
- `xcodebuild` Sim + Device.
- Xcode Cloud Workflow.
- TestFlight Upload.
- Hardware-Smoke.
- 46-MiB-Original-Asset-Retest.
- iPad-Smoke (wenn Family=1,2 in dieser Phase).
- Risiko: bekannt.

---

## 11. Nicht-Ziele (explizit)

- **Keine** automatische Synchronisation importierter Standorthistorien.
- **Kein** Public CloudKit, weder Database noch Schema.
- **Kein** iPad-Claim ohne `TARGETED_DEVICE_FAMILY = 1,2` UND
  Hardware-Smoke.
- **Kein** Light-Mode-Claim ohne sichtbare Theme-Implementierung +
  Sichtprüfung.
- **Kein** "alles fertig"-Statement vor Train H.
- **Kein** Default-Rollout des LocalTimelineStore-Spikes ohne 46-MiB-
  Original-Asset-Retest.
- **Kein** Push-Notifications-Feature.
- **Kein** Multi-Device-Live-Tracking ohne explizite User-Aktion.
- **Kein** Sharing von Saved Live Tracks an andere User (kein
  `sharedCloudDatabase`).

---

## 12. Apple-Doku — relevante Anker (Stand 2026-05-22)

- *Human Interface Guidelines* — Bottom-Sheets, Tab-Bars, Navigation, Map
  Overlays, Accessibility.
- *SwiftUI* — `NavigationStack`, `NavigationSplitView`,
  `.toolbar(...)`, `.safeAreaInset`, `MapCameraPosition`.
- *MapKit* — `Map(position:)`, `Marker`, `Annotation`, `MapPolyline`,
  `MKMultiPolyline` (für Heavy-Overview, später).
- *CloudKit* — `CKContainer`, `CKDatabase.privateCloudDatabase`,
  `CKQuerySubscription`, `CKAccountStatus`, `CKError`.
- *iCloud Documents* — `FileManager.url(forUbiquityContainerIdentifier:)`,
  `NSMetadataQuery`, Document picker.
- *Foundation* — `NSUbiquitousKeyValueStore`.
- *App Privacy* — Privacy Manifest categories + reason codes.
- *App Review Guidelines* — 2.5.13 (Live Activities), 5.1.1 (privacy),
  3.2 (Business).

*Online-Quellen wurden für diese Spec konsultiert; konkrete API-Signaturen
gehören in den Implementations-Train, nicht in die Spec.*

---

## 13. Doku-Sync-Konsequenzen

Mit diesem Commit werden minimal aktualisiert:

- `NEXT_STEPS.md` — Hinweis auf diese Spec + Train-Übersicht.
- `ROADMAP.md` — Hinweis auf diese Spec als kanonisches Redesign-Dokument
  bis zur nächsten Audit-Welle.
- `README.md` — kleines "Repo-Truth-Patch 2026-05-22": HEAD-Korrektur +
  ehrliche iPhone-only-Aussage + iCloud-Status "geplant, nicht
  implementiert".
- `docs/APP_FEATURE_INVENTORY.md` — kleiner Stand-Block 2026-05-22 mit
  Hinweis: Spec liegt vor, keine Code-Änderung.

Keine Feature-Häkchen werden gesetzt. Keine Trains werden als "fertig"
markiert.

---

*Ende der Spezifikation.*
