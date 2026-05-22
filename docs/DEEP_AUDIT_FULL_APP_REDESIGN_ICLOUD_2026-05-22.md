# Deep Audit — Full App, Redesign & iCloud-Machbarkeit

Stand: **2026-05-22** · Branch `main` · HEAD `d773957` · Linux-Host
Repo: `dev-roeber/iOS-App` (Monorepo Core + `wrapper/`)

> Read-only Audit. **Keine Builds, keine Tests, keine Dateiänderungen** in diesem
> Pass. Aussagen basieren auf Quelltext, Doku im Repo und Apple-Doku-Wissen;
> Apple-/Xcode-/Simulator-/Hardware-/ASC-/TestFlight-Aussagen werden **nicht
> verifiziert** und sind als solche markiert.

---

## 0. Executive Summary

LH2GPX ist eine sehr ausgereifte, größtenteils Foundation-/SwiftUI-only iPhone-App
mit klarer Architektur (Core Swift Package + Xcode-Wrapper), starkem
Decoder-/Query-Layer und einem dichten Test-Korpus (Linux `swift test` zuletzt
1578/2/0 laut Doku, HEAD `549c310`). Trotzdem leidet die App an drei strukturellen
Themen, die ein "Redesign + iCloud"-Train sauber benennen muss, bevor er
gestartet wird:

1. **Doku-Drift / Repo-Truth-Drift.** README, ROADMAP, NEXT_STEPS, Feature
   Inventory und mehrere Audit-Reports sind massiv ausgewuchert. Repo-Wahrheit
   (HEAD `d773957`, README zitiert HEAD `31c4351`) lässt sich aus den Dokus nur
   mit Mühe rekonstruieren. Für ein Redesign-Vorhaben ist das die größte
   Quelle für Reibung.
2. **iCloud ist heute nicht vorhanden** und in der Codebase aktiv ausgeschlossen
   (`isExcludedFromBackup = true` im LocalTimelineStore). Die Entitlements
   tragen ausschließlich `application-groups`. Es existiert weder ein
   `iCloud.*`-Container noch CloudKit-Code, noch ein `NSUbiquitous*`-Pfad.
3. **Verkabelungs-Lücken zwischen LegacyPath und LocalTimelineStore-Spike.**
   Der disk-first Store (Phasen 1–10A) ist tief implementiert, aber
   weiterhin `default OFF` (Feature-Flag `LH2GPX_LOCAL_TIMELINE_STORE` + UI-
   Toggle). Die Produktivpfade (Map/Heatmap/Overview/Export/Insights/Live)
   laufen weiter über den In-Memory-`AppExport`. Ein Redesign muss
   entscheiden, ob der Store **die** Plattform wird oder Spike bleibt.

Empfehlung: **Kein „großer Big-Bang-Redesign+iCloud-Train"**, sondern zwei
unabhängige Trains in dieser Reihenfolge:

- **Train „Truth Sync + UX Polish v1.1"** — Doku-Reset + sichtbarer
  iPad-Layout-Block + drei UI-Hardening-Tasks (siehe §10).
- **Train „CloudKit Private Database v0"** — *nur* App-Preferences,
  Favoriten und Saved-Live-Tracks-Metadaten, **nicht** importierte Historien.
  Importierte Historien sind potentiell hunderte MB groß, sind im
  LocalTimelineStore regenerierbar und sollten *nicht* in iCloud landen.

Detaillierte Trains sind in §10 priorisiert.

---

## 1. Preflight / Repo-Truth

| Punkt | Wert |
|---|---|
| `pwd` | `/home/sebastian/Repos/iOS_App` |
| `git status --short` | clean |
| `git branch --show-current` | `main` |
| HEAD | `d773957 docs: deep audit and sync repo truth` |
| Remote | `https://github.com/dev-roeber/iOS-App.git` |
| Letzte 20 Commits | überwiegend `docs:` + UI-/Helper-Trains (P, Q, R) |
| `MARKETING_VERSION` | `1.0.2` (8 pbxproj-Configs + 2 Info.plist) |
| `CURRENT_PROJECT_VERSION` | `171` (lokal); README erwähnt Xcode-Cloud-Build 179 als letzten extern grünen Build |
| `IPHONEOS_DEPLOYMENT_TARGET` | `17.0` |
| `TARGETED_DEVICE_FAMILY` | **`1` (iPhone)** in allen Targets — *iPad ist nicht freigeschaltet* |
| Bundle-ID | `de.roeber.LH2GPXWrapper` |
| Team | gesetzt (DEVELOPMENT_TEAM in pbxproj; ID hier bewusst nicht zitiert) |
| SDK-Min | iOS 17 (Package.swift `.iOS(.v17)`, alle pbxproj-Configs `17.0`) |

---

## 2. Ist-Architektur

### 2.1 Layering

```
Sources/
  LocationHistoryConsumer/           — Pure Foundation: Decoder, Modelle,
                                       Queries, Builder (GPX/KML/GeoJSON/CSV),
                                       PathDistanceCalculator, RouteQuality-
                                       Summary, ImportValidationSummary.
  LocationHistoryConsumerAppSupport/ — SwiftUI-Views, Session/Loader,
                                       Live-Domain, Heatmap, Karten,
                                       LocalTimelineStore (SQLite-Spike),
                                       LH2GPXTheme, LHCard/LHHeroMap...,
                                       LH2GPXAppFlow (geteilte Routing-Helper).
  LocationHistoryConsumerDemo*       — Standalone-Demo-Executable.
  LocationHistoryConsumerApp/        — Produkt-Einstieg auf Package-Ebene
                                       (`AppShellRootView`).
wrapper/LH2GPXWrapper/               — Xcode-iOS-Target (`ContentView.swift`
                                       repliziert AppShellRoot-Logik;
                                       App-Group, Widget, Entitlements).
wrapper/LH2GPXWidget/                — Home Widget + Live Activity.
```

Trennung Core ↔ AppSupport ↔ Wrapper ist sauber durchgehalten:
`Sources/LocationHistoryConsumer/` zieht **kein** SwiftUI, kein MapKit, kein
UIKit. `LocationHistoryConsumerAppSupport/` ist die einzige Stelle mit
SwiftUI/MapKit-Code; alle MapKit-Surfaces nutzen SwiftUI-`Map { … }` mit
`MapCameraPosition` (kein `MKMapView`/`UIViewRepresentable` mehr — laut
ROADMAP Train G1 repo-weit verifiziert; Audit hat dies durch
`grep MKMapView` bestätigt, einzige Treffer sind Doku-Kommentare).

### 2.2 Datenfluss

- **Manuelle Importe**: `ContentView`/`AppShellRootView` →
  `LH2GPXAppFlow.loadImportedFileEnvelope` →
  `AppContentLoader.loadImportedContentEnvelope` → entweder
  `.inMemory(AppSessionContent)` (Default) oder `.localTimeline(LocalTimelineSession)`
  (Feature-Flag).
- **Auto-Restore**: Security-Scoped Bookmark + Größen-Gate gegen OOM. Echte
  Google-Timeline-Files werden bewusst von Auto-Restore ausgeschlossen.
- **Session-Modell**: `AppSessionState` ist Single-Source-of-Truth für UI; trägt
  zusätzlich `localTimelineSession`, `selectedLocalTimelineDayId`,
  `exportSelection`, `historyDateRangeFilter` und Drilldown-Filter.
- **Queries**: `AppExport.overview/daySummaries/insights/mapData(applying:)`
  arbeiten gegen `AppExportQueryFilter`. Caches via Foundation-only
  `BoundedLRU<K,V>`.
- **Export**: `ExportFormat` × `ExportMode` → Builder (Core) → `ExportDocument`
  → `fileExporter`. Single fileExporter pro View (Doku im Code begründet das).
- **Live**: `LiveLocationFeatureModel` (`@MainActor`, ObservableObject), nutzt
  `SystemLiveLocationClient` + `LiveTrackRecorder` + `LiveLocationServerUploader`
  (URLSession, HTTPS-only ausser localhost) + ActivityKit.
- **Widget/App-Group**: `WidgetDataStore` über App-Group-`UserDefaults`
  (`group.de.roeber.LH2GPXWrapper`).

### 2.3 SwiftUI-Komposition

- `ContentView` (Wrapper, **538 Zeilen**) ist Top-Level-Switch
  (Loaded → `AppContentSplitView`, Store-Session → `LocalTimelineSessionLandingView`,
  sonst Import-First Home).
- `AppContentSplitView` (**1608 Zeilen**) ist das integrierte
  Compact-`TabView` + Regular-`NavigationSplitView`. Zentrales Sammelbecken
  für 18+ `@State`, 7 Sheets, Tab-Reselection-Observer, Drilldown-Routing,
  Hero-Map-Workspace, History-Date-Range-Bar.
- Hub-Views (`AppExportView` 1919, `AppInsightsContentView` 1962,
  `AppLiveTrackingView` 1289) sind je ein eigenes Mini-Universum mit MARKs.
- Lokalisierung läuft über `AppPreferences.localized(_:)`/`localized(format:)`,
  nicht `Localizable.strings`. DE/EN-Hartstrings.
- Theme/Design-System: `LH2GPXTheme` + `LHCard`/`LHMetricCard`/`LHSectionHeader`/
  `LHFilterChip`/`LHStatusChip`/`LHContextBar`/`LHHeroMapLayout`/
  `LHCollapsibleMapHeader`/`LHPageScaffold`/`LHExportBottomBar`/`LHLiveBottomBar` —
  echte Token-Library.

### 2.4 LocalTimelineStore-Spike

SQLite-basiert (CSQLite-Linux-Shim, native SDK-SQLite3 auf Apple). Schema-
userVersion 2. Tabellen `imports`/`days`/`paths`/`visits`/`activities`/
`derived_cache` + bbox-Indizes. Streaming-Import via
`GoogleTimelineStoreImporter`, kooperativ stornierbar, WAL-Pragmas + Checkpoint.
Provider-Schicht (`StoreBackedMapDataProvider`,
`StoreBackedHeatmapDataProvider`, `StoreBackedExportWriter`,
`LocalTimelineMapPointLayerProvider`) komplett Foundation-only, ohne MapKit.

**Status: weiterhin Spike** — UI-aktiv nur als Landing-View + Day-List/Detail
hinter Feature-Flag; Map/Heatmap/Overview/Export bleiben Legacy. Default OFF.

---

## 3. Import-Pipeline

Quelle: `AppContentLoader.swift` (813 Zeilen), `GoogleTimelineConverter`,
`GoogleTimelineStreamReader` (321 Zeilen), `GPXImportParser`, `TCXImportParser`.

| Eingabe | Pfad | Notiz |
|---|---|---|
| `app_export.json` (LH2GPX) | `decodeFile` → `AppExportDecoder` | direkter Codable-Decode |
| `app_export.zip` | `loadZipContent` (ZIPFoundation) | genau ein kompatibler Entry |
| `location-history.json` (Google) | `GoogleTimelineStreamReader` → Konverter | echtes Streaming, kein Full-Read |
| Google Timeline `.zip` | ZIP-Extraktion → Streaming | filename-agnostisch |
| `.gpx` | `GPXImportParser` | `<trk>`/`<wpt>`, gruppiert nach Lokalkalender |
| `.tcx` | `TCXImportParser` | `<Trackpoint>`, gruppiert nach Lokalkalender |
| ZIP mit GPX/TCX | dito | extract + parse |

Schutz vor OOM auf 4-GB-Geräten: `decodeFile` lehnt `Data(contentsOf:)`-Reads
> 64 MiB für non-Google-Pfade kontrolliert ab (Error
`importTooLargeForInMemoryLoad`). Google-Timeline-JSON streamt unabhängig
davon. Auto-Restore hat eigene Größengrenze und überspringt Google-Timeline-
Quellen (Error `autoRestoreSkippedLargeFile`).

Cancellation/Progress: existiert *nur* im Store-Pfad
(`LocalTimelineImportCancellation`/`LocalTimelineImportProgress`). Im Default-
Pfad gibt es nur Phasen-Callbacks (`reading/parsing/building`) und keinen
Cancel-Button.

**Risiken / Schwächen:**
- 46-MiB-Klasse ist laut README über synthetisches UI-Test-Asset autonom grün;
  Original-Tester-Asset (Pfad-Geometrie statt visit-only) hardware-retest
  bleibt offen. *Nicht in diesem Audit verifiziert.*
- Kein User-sichtbarer Cancel-Button im Legacy-Pfad — bei sehr großem Import
  ist die einzige Option Force-Quit.
- ZIP mit mehreren kompatiblen Exporten wirft `multipleExportsInZip`; UX-
  Hinweis vorhanden, aber kein interaktiver Picker.

---

## 4. Export-Pipeline

Quellen: `Sources/LocationHistoryConsumer/{GPX,KML,GeoJSON,CSV}Builder.swift`,
`Sources/.../KMZBuilder.swift` (40 Zeilen, ZIPFoundation in-memory), `AppExportView`.

| Format | Builder | Kommentar |
|---|---|---|
| GPX 1.1 | `GPXBuilder` (240 Z.) | `reserveCapacity` |
| KML 2.2 | `KMLBuilder` (109 Z.) | direkte Coord-Loops |
| KMZ | `KMZBuilder` (in-memory Archive seit Train E1) | spart Temp-Datei-Roundtrip |
| GeoJSON | `GeoJSONBuilder` (113 Z.) | FeatureCollection |
| CSV | `CSVBuilder` (209 Z.) | RFC 4180, `joinEscapedRow`-Helper |
| TCX | nur **Import** | dokumentiert, in §2 Feature-Inventory |

Single `.fileExporter` im View (mit Begründung im Kommentar). Selection-
Pipeline: `ExportSelectionState` × `ExportSelectionContent.exportDays` +
`ExportRouteSanitizer` + `ImportedPathMutationSet` (nicht-destruktives Overlay,
greift jetzt im Export).

**Schwächen:**
- Export-Filter-UI hat extrem viele Sektionen (Range, Accuracy, Required-
  Content, Activity Types, Area/Polygon). Auf iPhone-Compact ist die Sicht-
  Hierarchie hoch.
- Keine Pre-Validation der Polygon-Eingabe als interaktive Map; nur Textfeld.
- Filename-Vorschau ist sichtbar, aber Custom-Filename nicht editierbar (nur
  via System-Save-Dialog umbenennbar).

---

## 5. Live-Tracking

`LiveLocationFeatureModel` (`@MainActor`, ObservableObject) zentralisiert
`authorization`, `isRecording`, `currentLocation`, `liveTrackPoints`,
`recordedTracks`, `serverUpload*`, `sessionID`, `sessionStartedAt`,
`hasInterruptedSession` und exponiert ~20 `@Published`. Background-Mode in
Info.plist `UIBackgroundModes: location`. ATT/IDFA nicht vorhanden.

ActivityKit/Live-Activity:
- `NSSupportsLiveActivities = true`
- `TrackingAttributes`/`TrackingStatus` + `LiveActivityPresentation`
- Widget-Surface separat (`wrapper/LH2GPXWidget`) mit eigener Entitlement.

Server-Upload (`LiveLocationServerUploader`):
- Default OFF, HTTPS-only außer `localhost`/`127.0.0.1`.
- Bearer-Token im Keychain, in der UI nur als `SecureField`/Maskierung.
- Payload enthält `source`, `sessionID`, `captureMode`, `sentAt`, Points
  (lat/lon/timestamp/accuracy) — bewusst keine Geräte-/User-IDs.

Render-Cap (`LiveTrackRenderCap`, default 10 000 Punkte) wirkt **nur auf den
View-State**, nicht auf Rohdaten/Persistenz/Export.

**Schwächen:**
- Kein Auto-Resume (bewusst); Restore-Banner sichtbar — dokumentiert.
- Lock-Screen-Sichtprüfung der Live Activity bleibt extern offen.
- Background-Recording erfordert "Always Allow", aber das System-Prompt-
  Recovery-Flow wenn der User "While Using" gewählt hat, ist UI-leicht
  versteckt (`AppOptionsView`).

---

## 6. MapKit / Heatmap / Routes / Timeline

Surfaces (alle SwiftUI-`Map(position:) { … }`):
1. `AppDayMapView` (Day-Detail)
2. `AppLiveTrackingView` (Live + Fullscreen)
3. `AppRecordedTrackEditorView` (Editor + Editor-Map)
4. `AppLiveLocationSection` (Day-Detail Live)
5. `AppHeatmapView` (Sheet)
6. `AppOverviewTracksMapView` (Overview + Days Hero)
7. `AppExportPreviewMapView` (Export-Preview)

Performance-Hardening: `MapCoordinateGuard`/`CoordinateValidity`,
`OverviewMapPreparation.scanCandidates` mit `strideDecimate(maxPoints: 1024)`,
`PathFilter.removeOutliers`, `PathSimplification` (Douglas-Peucker),
`HeatmapGridBuilder` Multi-LOD (overview/low/medium/high), `HeatmapPalette`,
`HeatmapVisualStyle`. Hard-Cap `densityPointCap = 500 000` mit
`truncatedDensityPoints`-Flag.

Layer-Steuerung zentralisiert: `MapLayerMenu` (Right-Side-Dropdown,
Configuration-driven).

**Schwächen:**
- Kein MKMapView-Bridge — auf country-zoom für 500 k+ Punkte limitiert
  (dokumentiert als Train D/G2).
- Tile-Style-Wechsel (Standard/Hybrid/Mute) sind teilweise im MapLayerMenu,
  aber kein Light-/Dark-Map-Toggle abseits Systemwert.
- Heatmap-Sheet ist modal — kein dauerhaftes Layer-Overlay über dem
  Overview/Day-Map.

---

## 7. UI/UX, Navigation, Accessibility, Dynamic Type, Dark Mode, Landscape, iPad

### 7.1 Navigation
- Compact iPhone: `TabView` mit fünf Tabs (Overview/Days/Insights/Export/Live).
- Regular: `NavigationSplitView` (Sidebar Days, Detail-Pane).
- Pro Tab ein eigener `NavigationStack`.
- Deep Link `lh2gpx://live` → Live-Tab.
- Drilldowns vom Insights-Tab in Days/Export werden über `activeDrilldownFilter`
  geroutet, Banner mit Reset.

### 7.2 Accessibility
- `AppAccessibilityID`-Namespace mit Subnamespaces `Root/Tab/Map/ProductInfo/
  Action`. Aktuell ~38 zentrale Konstanten + ~155 verbleibende Inline-IDs.
- `accessibilityIdentifier`, `accessibilityLabel`, `accessibilityHidden` werden
  konsistent gesetzt (Stichproben in `ContentView.emptyStateView` und
  `AppContentSplitView`).
- VoiceOver-Gruppierung mittels `accessibilityElement(.contain)` in den
  Product-Info-Cards.
- **Schwäche**: Kein zentrales `Localizable.strings` → automatische
  System-Lokalisierung (z. B. Stimm- und Schriftpräferenzen, automatisches
  Mirroring für RTL) greift nicht überall.

### 7.3 Dynamic Type
- Stichproben (`emptyStateView`, `overviewKPISection`, `compactDayRow`) zeigen
  Standard-Font-Styles (`.title2`, `.subheadline`, `.caption`) und kein
  `.font(.system(size: …))` mit fixer Größe — gut.
- **Risiko**: Diverse Stellen nutzen `.font(.system(size: 34, weight: .bold,
  design: .rounded))` u. ä. (Beispiel `overviewPaneContent` Zeile 693). Bei
  XL/XXXL kann das Layout brechen, weil keine `dynamicTypeSize`-Kappen
  gesetzt sind.

### 7.4 Dark Mode
- Es gibt **kein** echtes Light/Dark — die App ist hart auf `preferredColorScheme(.dark)`
  und `Color.black` Backgrounds verdrahtet (siehe `compactDayList`,
  `compactOverview`, `ContentView`). Theme-Tokens (`LH2GPXTheme.elevatedCard`/`liveMint`
  etc.) sind statisch ohne `.accentColor`-Adaption.
- **Implikation**: Im Test bedeutet das, dass die App App-Store-Anforderungen
  zu Light/Dark *de facto* nicht erfüllt (Apple verlangt keine Light/Dark-
  Unterstützung, aber Konsistenz; force-dark ist akzeptabel, sollte aber
  bewusst sein).

### 7.5 Landscape / iPad
- `UISupportedInterfaceOrientations~ipad` enthält Portrait + beide Landscape
  + UpsideDown. `~iphone` Portrait + Landscape.
- **`TARGETED_DEVICE_FAMILY = 1`** in allen Configs → die App ist heute
  **technisch iPhone-only**. Der iPad läuft nur im Scaled-iPhone-Mode.
- README/ROADMAP sagen mehrfach "iPad-Layout offen / iPad offline" — das
  ist redaktionell so, aber pbxproj sagt klar: iPad ist gar nicht freigegeben.
  Das ist die wichtigste Doku-vs-Truth-Diskrepanz dieses Audits.
- `regularSplitView` ist trotzdem implementiert und würde auf iPad sofort
  rendern, wenn `TARGETED_DEVICE_FAMILY = 1,2` gesetzt würde.

---

## 8. iCloud-Fähigkeit und Datenmodell

### 8.1 Ist-Zustand

- **Keine iCloud-Container-Entitlement** (Entitlements enthalten nur
  `application-groups`).
- **Keine CloudKit-API-Nutzung** (`grep CloudKit/CKContainer/NSUbiquitous` →
  null Treffer).
- **`isExcludedFromBackup = true`** wird *aktiv* auf den LocalTimelineStore-
  Pfad gesetzt (`LocalTimelineFileAttributes`). Live-Track-Files in
  `RecordedTrackFileStore` ebenfalls aus Backup ausgeschlossen.
- Datenmodell ist heute drei-geteilt:
  1. *In-Memory* `AppExport` (Default-Pfad) — flüchtig pro Session.
  2. *Disk-First* `LocalTimelineStore` (SQLite) — Spike, default OFF,
     `isExcludedFromBackup`.
  3. *App-Group-UserDefaults* + Keychain + `RecordedTrackFileStore`
     (Saved Live Tracks), `DayFavoritesStore`, `RecentFilesStore`,
     `ImportBookmarkStore`, `AppPreferences`.

### 8.2 Machbarkeit & Empfehlung

iCloud kann auf drei Ebenen eingeführt werden:

1. **NSUbiquitousKeyValueStore** (sehr leichtgewichtig, 1 MiB Quota,
   eventually consistent, kein Konfliktmodell).
   *Geeignet für:* `AppPreferences`-Skalare (Startup-Tab, Distanzeinheit,
   Sprache, Heatmap-Defaults, Map-Style), Favorite-Day-IDs (Set bleibt
   klein), `RecentFilesStore`-Slugs (ohne Bookmark-Bytes).
   *Nicht geeignet für:* Bookmarks (Security-Scoped, Gerätbezug),
   importierte Historie, Saved Live Tracks > 1 MiB.

2. **CloudKit Private Database** (CKContainer, `iCloud.de.roeber.LH2GPX*`).
   *Geeignet für:* Saved-Live-Tracks-**Metadaten** (Datum, Distanz,
   Punktzahl, Source-Filename), Favoriten, Settings-Profile,
   Cross-Device-Quick-Sync. **Nicht** für Vollkoordinaten — eine 8-h-Live-
   Aufzeichnung sind schnell 30k+ Punkte ⇒ CloudKit-Quota-Cost wäre real.
   Pro CKAsset könnte man eine `.lh2gpx`-Datei (z. B. Gzip-GeoJSON) hängen,
   wenn der User das explizit will.

3. **iCloud Documents (ubiquity container)**.
   *Geeignet für:* User-sichtbare Exporte (GPX/KMZ/GeoJSON/CSV) als
   "in iCloud Drive ablegen"-Option und für *manuell* in iCloud Drive
   gelegte Importdateien (zugänglich über bestehenden `fileImporter`).
   *Nicht geeignet für:* automatischer Sync der LocalTimelineStore-SQLite
   (Datei-Lock-Konflikte, WAL/SHM-Files nicht koordinierbar).

**Empfehlung — "CloudKit Private Database v0"-Train (siehe §10)**:

- Phase A (KV-Store, low-risk): `NSUbiquitousKeyValueStore` für
  `AppPreferences`-Skalare + `DayFavoritesStore` + `RecentFilesStore`-
  Slugs (ohne Bookmark). Kein Schema, kein Mergebedarf, ein Entitlement.
- Phase B (CKContainer Private): Saved-Live-Tracks-Metadaten als
  `CKRecord`-Type `LiveTrackMeta`, optional CKAsset für komprimierte
  Geometrie. Kein Auto-Sync importierter Historien.
- Phase C (iCloud Drive Export-Ziel): Reines UI/UX im Export-Sheet — kein
  CloudKit, sondern `URL` aus ubiquity container.

**Bewusst nicht empfohlen**: importierte Google-Timeline-/LH2GPX-Daten in
iCloud syncen. Das ist regenerierbar, dateigrößenkritisch, und würde die
Quote schnell sprengen. Für Multi-Device-Restore reicht "User-managed
File in iCloud Drive" mit `fileImporter`.

### 8.3 Migrationen

- App-Group-`UserDefaults` muss bleiben (Widget-Bridge).
- `NSUbiquitousKeyValueStore` + `UserDefaults` parallel führen mit
  *KV-as-Truth*-Migration auf Read; UserDefaults bleibt Cache.
- `isExcludedFromBackup` für `LocalTimelineStore` und
  `RecordedTrackFileStore` bleibt — die Daten gehen *nicht* in iCloud-
  Backup. Das ist die heutige Wahrheit und sollte als Privacy-Versprechen
  erhalten bleiben.

---

## 9. App-Store-Risiken & Privacy

### 9.1 Privacy / DSA
- `PrivacyInfo.xcprivacy` deklariert `NSPrivacyCollectedDataTypePreciseLocation`
  für den optionalen Server-Upload (Purpose: AppFunctionality, nicht
  Tracking, nicht Linked).
- `NSPrivacyAccessedAPICategoryUserDefaults` mit Reason `CA92.1` ist
  deklariert.
- **Lücken**: `NSPrivacyAccessedAPICategoryFileTimestamp` (potentiell —
  `isExcludedFromBackup`/`URLResourceValues`-Sets können da relevant
  werden), `NSPrivacyAccessedAPICategorySystemBootTime`,
  `NSPrivacyAccessedAPICategoryDiskSpace` — *vermutlich* nicht benutzt,
  sollte aber per `rg` re-verifiziert werden, bevor ein neuer Build
  hochgeht.
- DSA-Trader-Disclosure ist ASC-Aufgabe, nicht im Repo verifizierbar.

### 9.2 App Review Guideline 3.2 (Build 74)
- Historisch: 1.0 (Build 74) wurde am 2026-05-01 als "Business / Other
  Business Model Issues" abgelehnt (Fehleinschätzung als
  org-gebundene App). Response gesendet, laut Doku Pending Developer
  Release. *In diesem Audit nicht extern verifiziert.*
- Risiko bleibt, dass künftige Builds dieselbe Fehleinschätzung
  abbekommen. Mitigation:
  - "Public Audience Statement" in `docs/APP_FEATURE_INVENTORY.md`
    pflegen.
  - Im App-Store-Marketing-Description explizit: "No account, no
    organization, fully personal, no central server."

### 9.3 Sonstige Review-Risiken
- **Background Location** + `Always Allow` → Apple verlangt deutlichen
  User-Mehrwert in der UI. Aktuell sichtbar: Status-Card, Banner,
  Permission-Erklärung. Das sollte reichen, könnte aber durch ein
  klar gelabeltes "What this does in the background"-Sheet hardened
  werden.
- **HTTP-Upload an non-https-Localhost**: korrekt gegated, aber ATS-
  Override im Info.plist *nicht* gesetzt — `localhost` ist von ATS
  ausgenommen und braucht das nicht.
- **`NSSupportsLiveActivities = true`** — keine Review-Probleme bekannt.
- **App-Group-Container** ohne iCloud — unproblematisch.

---

## 10. Play-Store-Vorausblick (ohne Android-Code)

LH2GPX ist *iPhone-only/SwiftUI/MapKit/ActivityKit/WidgetKit/AppIntents-frei*
und damit nicht trivial nach Android portierbar. Empfehlung *für später*,
**ohne** in diesem Repo Android-Code zu starten:

1. **Lock-in-Verminderung jetzt**: Kernlogik bleibt in `LocationHistoryConsumer/`
   Foundation-only. Das ist 1:1-portierbar in ein Swift-Server-/CLI-Tool
   oder als Referenz für eine Kotlin-Reimplementation.
2. **Datenformate sind standardisiert** (GPX, KML, GeoJSON, CSV) — Play-
   Store-Twin müsste nicht das Kombinations-Schema neu erfinden.
3. **Live-Activity/Widget/MapKit** lassen sich nicht 1:1 portieren —
   für Android dann WorkManager + Foreground Service + Maps SDK +
   AppWidget. Konzeptionell, kein Codeaufwand jetzt.

Konkret in diesem Repo: **nichts tun**, außer die Trennung Core ↔
AppSupport diszipliniert halten.

---

## 11. Performance & Speicher

- Streaming-Importer (`GoogleTimelineStreamReader`) hält den Heap niedrig
  bei großen Imports.
- Hard-Caps: `densityPointCap = 500_000` (Heatmap), `LiveTrackRenderCap`
  (View-State), `overlayLimit` × `maxPolylinePoints` (Overview-Map).
- `BoundedLRU` für sechs Filter-/Detail-Caches.
- `WAL`-Pragmas + Checkpoint (Store-Pfad).
- SQLite-Pragmas im Default-Pfad nicht relevant (kein SQLite).
- Memory-Warning-Listener: `ContentView` ruft `ImportMemoryProbe.logMemoryWarning()`.

**Schwäche**: kein Cache-Drop-Listener auf `UIApplication.didReceiveMemoryWarningNotification`
in `AppContentSplitView` oder `AppSessionState` — der Listener loggt nur,
verwirft aber keine BoundedLRU-Inhalte. Bei knappem RAM könnte das helfen.

---

## 12. Vollverdrahtungs-Matrix (UI-Aktion → tatsächliche Funktion)

Aussagebasis: `grep`/Lesung. Status: ✅ verdrahtet · ⚠️ verdrahtet aber
mit Caveat · ❌ stub/leere Implementation. *Apple-/Hardware-/Sichtprüfung
nicht in diesem Audit.*

| Surface | Aktion | Ziel-Funktion | Status |
|---|---|---|---|
| Home / Empty | "Open location history file" | `isImportingFile = true` → `fileImporter` → `handleImportResult` → `LH2GPXAppFlow.loadImportedFileEnvelope` | ✅ |
| Home / Empty | "Load Demo Data" | `DemoDataLoader.loadDefaultContent` → `AppSessionContent` | ✅ |
| Home / Empty | "Clear" (Fehler) | `clearCurrentContent` → ImportBookmarkStore.clear + session.clearContent | ✅ |
| Home / Empty | Google-Maps-Inline-Hilfe | `GoogleMapsExportHelpInlineAction` → `GoogleMapsExportHelpView` | ✅ |
| Actions-Menu | Open / Demo / Options / Tracks / Clear | direkt verdrahtet | ✅ |
| Tab `Overview` | KPI-Karten, Highlights, Continue-Card | Buttons rufen `navigate(for:)`/`presentSheet(.heatmap)` | ✅ |
| Tab `Overview` | Hero-Map + Range-Chips | `AppOverviewTracksMapView`, `HistoryDateRangeFilter` | ✅ |
| Tab `Overview` | "Heatmap" Capsule | `presentSheet(.heatmap)` | ✅ |
| Tab `Overview` | Favorites-Only Toggle | `overviewShowOnlyFavorites` | ✅ |
| Tab `Days` | Sticky-Map + Filter-Chips + Search | `daySearchText`, `dayListFilter`, `historyDateRangeFilter` | ✅ |
| Tab `Days` | Range-Reset, Drilldown-Banner | `session.historyDateRangeFilter.reset()`, `clearActiveDayDrilldown` | ✅ |
| Tab `Days` | Swipe-/Context-Favorite | `DayFavoritesStore.toggle` | ✅ |
| Tab `Days` | "Today reselect" Behaviour | `IOSTabReselectionObserver` → `handleDaysTabReselection` | ✅ |
| Tab `Days` | Export-Bar | `selectedTab = 3` | ✅ |
| Day-Detail | Path-Display-Mode `.original/.mapMatched` | `AppDayPathDisplayMode` UserDefaults + `PathFilter`/`PathSimplification` | ✅ |
| Day-Detail | "Route entfernen" | `pathMutationStore.addDeletion` + Export Sanitizer | ✅ |
| Day-Detail | Per-Route-Export-Selection | `ExportSelectionState.toggleRoute` | ✅ |
| Day-Detail | Favorite | `DayFavoritesStore.toggle` | ✅ |
| Tab `Insights` | Segmented + Top-Days + Monthly | direkt aus `ExportInsights` | ✅ |
| Tab `Insights` | Drilldown "Open in Days/Map/Export" | `applyInsightsDrilldown` | ✅ |
| Tab `Insights` | Share | `ChartShareHelper` + `ImageRenderer` | ⚠️ Apple-host-only |
| Tab `Export` | Format-Pills | `selectedFormat` + `exportContentType` | ✅ |
| Tab `Export` | Mode-Pills (`Tracks/Waypoints/Both`) | `selectedMode` (CSV erzwingt `.both`) | ✅ |
| Tab `Export` | Filter (Range/Accuracy/Activity/Area) | `effectiveQueryFilter` | ✅ |
| Tab `Export` | Polygon-Eingabe | Textfeld, kein interaktiver Picker | ⚠️ UX-Schwäche |
| Tab `Export` | Export-Button | `isExporting = true` → `fileExporter` | ✅ |
| Tab `Export` | Filename-Vorschau | `ExportPresentation.suggestedFilename` | ⚠️ nicht editierbar |
| Tab `Live` | Start/Stop | `liveLocation.startRecording`/`stopRecording` | ✅ |
| Tab `Live` | Follow-Mode + Center | `isFollowingLocation`, `MapLayerMenu.centerOnLocation` | ✅ |
| Tab `Live` | Pause/Flush Upload | `liveLocation` flush/pause | ✅ |
| Tab `Live` | Fullscreen | `MapLayerMenu.toggleFullscreen` | ✅ |
| Tab `Live` | Saved Library | `presentSheet(.tracksLibrary)` | ✅ |
| Tracks-Library | Editor (Point-/Midpoint-/Delete) | `AppRecordedTrackEditorView` | ✅ |
| Options | Distance-Unit, Start-Tab, Map-Style, Language | `AppPreferences` UserDefaults | ✅ |
| Options | Live-Recording Detail/Accuracy/Min-Gap | `AppPreferences.liveTrack*` | ✅ |
| Options | Background Tracking Toggle | `AppPreferences.allowsBackgroundLiveTracking` | ✅ |
| Options | Auto-Restore | `AppPreferences.autoRestoreLastImport` | ✅ |
| Options | Server-Upload URL/Token/Batch | `LiveLocationServerUploadConfiguration` + Keychain | ✅ |
| Options | Reset-to-Defaults | `AppPreferences.reset()` | ✅ |
| Options | "Delete imported local data" | `LocalTimelineDeletionService` (Store-Pfad only) | ⚠️ nur Store-Pfad |
| Options | Internal Test Toggles | `LocalTimelineTechnicalTestSettings` | ⚠️ pre-production |
| Widget | Live-Activity Distance/Duration/Points/Upload | `DynamicIslandCompactDisplay` | ⚠️ Sichtprüfung extern offen |
| Deep Link `lh2gpx://live` | `handleDeepLink` → Live-Tab | ✅ |

Zusammenfassung: **keine** echten Stubs gefunden. Wesentliche Caveats:
- iPad-Layout existiert in `regularSplitView`, ist aber durch
  `TARGETED_DEVICE_FAMILY = 1` nicht aktivierbar.
- Light-Mode existiert nicht (force-dark).
- Custom-Export-Filename ist nicht direkt editierbar.
- Insights-Share ist Linux-untestbar (`ImageRenderer`).

---

## 13. Doku-Wahrheit vs Code

| Behauptung in README/ROADMAP | Code-Realität | Bewertung |
|---|---|---|
| README §"iPad-Layout offen" | `TARGETED_DEVICE_FAMILY = 1` in allen 8 Configs | ❌ iPad ist nicht "offen offen" — er ist *aktiv ausgeschlossen* |
| ROADMAP "iOS-17-Minimum extern bestätigt" | `Package.swift .iOS(.v17)`, alle pbxproj `17.0` | ✅ konsistent |
| README "iPad UDID `3c95…` offline" | irrelevant, da Family=1 — iPad würde gar nicht installierbar sein als iPad-Build | ⚠️ Doku-Detail |
| `MARKETING_VERSION 1.0.2 / CURRENT_PROJECT_VERSION 171` | bestätigt in 8 Configs + 2 Info.plist | ✅ |
| README "Linux 1578/2/0 auf HEAD `549c310`" | HEAD ist heute `d773957` — die zwei zuletzt gemergten Commits sind `bd8a4bc` + `d773957`, beide reine `docs:` | ⚠️ Test-Snapshot vermutlich weiter gültig, aber nicht re-verifiziert |
| FeatureInventory "Live Activity / Dynamic Island Lock-Screen verifiziert" | `iPhone 15 Pro Max` confirms `compact`/`expanded` für `Distance`; `minimal`, Lock-Screen, weitere Primärwerte "open" | ⚠️ teilverifiziert, klar dokumentiert |
| FeatureInventory "App-Review 3.2 Pending Developer Release" | extern; nicht im Repo prüfbar | ⚠️ extern |
| Code: `densityPointCap = 500_000` | confirmed in `AppHeatmapModel` | ✅ |
| Code: `isExcludedFromBackup = true` Store | confirmed `LocalTimelineFileAttributes` | ✅ |
| ROADMAP Train M-R View-Wiring | confirmed in `AppExportView.exportContent` (importSummary/formatGuidance/selectionSummary cards) | ✅ |
| Privacy-Manifest: "kein Tracking" | `NSPrivacyTracking=false`, keine `AdSupport`/`ATT`-Imports | ✅ |
| NEXT_STEPS "Phasen 19.23-19.27 abgeschlossen" (aus Memory) | passt nicht zu aktueller HEAD-Topology — *Memory veraltet*, NEXT_STEPS heute beschreibt Trains O–R | ⚠️ User-Memory Drift |

---

## 14. UI/UX-Schwächen (priorisiert)

1. **iPad-Block ist nominell** (`TARGETED_DEVICE_FAMILY=1`). Doku spricht von
   "iPad offen", Code sagt "iPhone-only". Entscheiden: iPad freischalten
   (Family=1,2) oder Doku ehrlich auf "iPhone-only v1.0" ziehen.
2. **`AppContentSplitView` ist 1608 Zeilen**, `AppExportView` 1919 Zeilen,
   `AppInsightsContentView` 1962 Zeilen. Zwischen Subviews, MARK-Sections und
   Helper-Funktionen schwer wartbar. Refactor in mehrere Files je Tab.
3. **Kein Light-Mode**. Wenn das Designziel "always-dark" ist, sollte das in
   `Info.plist` (`UIUserInterfaceStyle = Dark`) deklariert werden — dann
   verschwindet auch das System-Theme-Flackern beim Launch.
4. **Polygon-Filter-UI ist Textfeld** statt interaktivem Map-Picker.
5. **Custom-Filename im Export nicht direkt editierbar.**
6. **Cancel-Button im Default-Importpfad fehlt.**
7. **Heatmap nur als Sheet** — kein dauerhaftes Overview/Day-Map-Overlay.
8. **Dynamic Type ≥ XXL**: viele `.font(.system(size: 34))` o. ä. — Layout-
   Risk nicht systematisch begrenzt.
9. **Status-Banner-Hierarchie**: Drilldown-Banner, Range-Filter, Test-Mode-
   Banner, Filter-Active-Banner können sich übereinander stapeln.
10. **Lokalisierung als Code, nicht `Localizable.strings`**: schwer für
    spätere Drittsprachen.

---

## 15. Redesign-Zielbild (Vorschlag, nicht beschlossen)

Idee: keine UI-Revolution, sondern drei Konsolidierungen.

**A) "iPhone v1.1 — UX-Polish"**
- iPad-Frage entscheiden + Doku-Sync.
- Light-Mode deklarieren ODER `UIUserInterfaceStyle = Dark` setzen.
- Default-Import-Cancel-Button und Progress-Snapshot in `LoadingProgressEngine`.
- `dynamicTypeSize(.xSmall ... .xxLarge)` als Kappe an den drei Hauptzonen.
- Polygon-Editor als interaktiver Map-Picker.
- Custom-Export-Filename editierbar.

**B) "Data Plane v0 — CloudKit Private DB"**
- Phase A: `NSUbiquitousKeyValueStore` für Preferences/Favoriten/RecentSlugs.
- Phase B: `CKContainer` private DB für Saved-Live-Tracks-Metadaten +
  optional CKAsset. Importierte Historien explizit *nicht* gesynct.
- Phase C: iCloud-Drive-Export-Ziel als zusätzliche `fileExporter`-Quelle.
- Privacy-Manifest erweitern, App-Store-Beschreibung anpassen.

**C) "View-Refactor"**
- `AppContentSplitView` in `OverviewTabView`/`DaysTabView`/`InsightsTabView`/
  `ExportTabView`/`LiveTabView` zerteilen, gemeinsame State-Bindings über
  ein dünnes `AppShellViewModel`.

---

## 16. Priorisierte Umsetzungstrains

| # | Train | Scope | Reihenfolge | Risiko |
|---|---|---|---|---|
| 1 | Doc-Truth-Sync v3 | README/ROADMAP/NEXT_STEPS/FeatureInventory auf HEAD `d773957` einrasten; iPad-Statement ehrlich machen; veraltete Phase-Banner archivieren | sofort | sehr klein |
| 2 | UX-Polish Mini-Train | Light/Dark-Entscheidung, Import-Cancel, dynamicTypeSize-Kappe, Polygon-Picker, Custom-Filename | nach #1 | klein bis mittel |
| 3 | iPad-Freischaltung (optional) | `TARGETED_DEVICE_FAMILY=1,2`, NavigationSplitView-Polish, App-Icon-Asset prüfen | nach #2 | mittel |
| 4 | View-Refactor | Aufteilung 1600+-Zeilen-Views | parallel zu #3 | mittel |
| 5 | KV-Cloud (Phase A) | `NSUbiquitousKeyValueStore` für Preferences + Favoriten + RecentSlugs; Migration Read-only | nach #1 | klein |
| 6 | CKContainer Phase B | Saved-Live-Tracks-Metadata + Privacy-Manifest-Update | nach #5 | mittel |
| 7 | iCloud-Drive-Export | optionales Export-Ziel | nach #6 | klein |
| 8 | LocalTimelineStore-Default-Rollout-Decision | Spike → Default oder Spike → Archiv | später, separater Train | groß |
| 9 | XCUITest-Target im Wrapper | Identifier-Konsumenten, Apple-host-only | wenn Mac verfügbar | klein |
| 10 | 46-MiB-Hardware-Retest mit Original-Asset | Tester-Handoff | extern | klein |

---

## 17. Risiken

1. **Doku-Drift** unterminiert jeden Audit-Anker. Ohne #1 wird jeder
   Folgeschritt unscharf.
2. **iPad-Mehrdeutigkeit** kann zu unangenehmen App-Review-Kommentaren
   führen ("warum bietet ihr keinen iPad-Build an, der NavigationSplitView
   ist offensichtlich vorhanden?").
3. **CloudKit-Schema-Lock-in** sobald Phase B live ist — jede Migration
   ist eine Daten-Migration. Schema-Versions-Pflicht von Tag 1.
4. **LocalTimelineStore-Spike** ist sehr fortgeschritten, aber default OFF
   — jeder „Default an"-Schritt braucht 46-MiB-Hardware-Retest auf
   Original-Asset.
5. **App-Review 3.2-Erinnerungseffekt** — Re-Submission braucht
   Public-Consumer-Statement im Marketing.
6. **`@available(iOS 17.0, macOS 14.0, *)`-Branches** sind teilweise
   redundant geworden (iOS-Min 17 ist schon im Package). Können aufgeräumt
   werden, sind aber kein Defekt.

---

## 18. Was NICHT verifiziert wurde (Test-Lauf separat)

In Übereinstimmung mit der Pflicht aus dem Prompt wurde in diesem Audit
**nichts** gebaut, getestet oder ausgeführt. Folgendes ist daher offen und
muss in einem Test-Train *vor* einem Merge belastbarer Aussagen
verifiziert werden:

- `swift build` auf aktueller HEAD.
- `swift test` auf aktueller HEAD (Doku zitiert 1578/2/0 auf HEAD `549c310`,
  HEAD ist heute `d773957`).
- `xcodebuild build/test` auf macOS/Xcode (Wrapper, Widget, UITests).
- Xcode-Cloud-Build (Workflow `Release – Archive & TestFlight`).
- TestFlight-Verteilung von Build > 179.
- App-Review-Status bei ASC (Build 74 Pending Developer Release).
- Hardware-Verifikation auf iPhone 15 Pro Max / iPhone 14 Pro für
  Dynamic Island Lock-Screen + alle vier Primärwerte.
- 46-MiB-Hardware-Retest mit Original-Tester-Asset (Pfad-Geometrie).
- iPad-Hardware-Smoke (sobald iPad freigeschaltet wäre).
- Light-Mode-Sichtprüfung (heute force-dark; bei Setting `UIUserInterfaceStyle`
  separat zu prüfen).
- `Localizable.strings`-Migration (heute Code-Lokalisierung).
- Tatsächliche `NSUbiquitousKeyValueStore`-Reachability + Conflict-Behaviour.
- Tatsächliche CloudKit-Schemata + Push-Notifications-Wiring.
- Insights-Share-Sheet auf Apple-Host (ImageRenderer Linux-untestbar).
- Privacy-Manifest-Vollständigkeit für `FileTimestamp`, `SystemBootTime`,
  `DiskSpace` u. a. — Linter-Lauf empfohlen.

---

## 19. Anhang — Kennzahlen

- Swift-Dateien: 198 in `Sources/`, 10 in `wrapper/`
- Test-Dateien: 180 in `Tests/` + `wrapper/LH2GPXWrapperTests` +
  `LH2GPXWrapperUITests`
- ~30 `@available(iOS 17.0,*)` / `#available(iOS 17,*)`-Gates noch im Code
  (Aufräum-Kandidat, da Min jetzt 17)
- `LocalTimelineStore`-Surface: ~30 Dateien (`LocalTimeline*.swift`)
- Hub-Views: `AppContentSplitView` 1608, `AppExportView` 1919,
  `AppInsightsContentView` 1962, `AppLiveTrackingView` 1289,
  `AppDayDetailView` 825, `AppOptionsView` 757, `AppHeatmapView` 223,
  `AppOverviewSection` 111
- Top-Level-Entitlement-Set heute: nur `application-groups`
- Privacy Manifest: 1 `CollectedDataType` (precise location),
  1 `AccessedAPIType` (UserDefaults `CA92.1`)

---

*Ende des Audit-Reports.*
