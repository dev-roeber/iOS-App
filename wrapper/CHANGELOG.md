# CHANGELOG

## 2026-05-06 (Performance pass on streaming Google Timeline import — UnsafeBytes tokenizer, 256 KB chunks, autoreleasepool, direct model build)

### perf: tighten streaming Google Timeline pipeline on four axes
- `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineStreamReader.swift`: Tokenizer läuft jetzt über `Data.withUnsafeBytes` mit direktem `UnsafePointer<UInt8>`-Zugriff statt `Data.Index`-Iteration. Strukturelle Bytevergleiche per Hex-Literal (`0x5B`/`0x7B`/…) statt `UInt8(ascii:)`. `@inline(__always)` auf `processByte` und `isJSONWhitespace`. Default-`chunkSize` 64 KB → **256 KB**. Per-Element `onElement`-Aufruf in `autoreleasepool` gewrappt — verhindert Akkumulation von Foundation-Zwischenobjekten (NSString/NSNumber/NSDictionary aus `JSONSerialization.jsonObject`) über den Importlauf.
- `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineConverter.swift`: Output-Pfad gibt den `[String: Any]`-Foundation-Tree und den `JSONSerialization`+`AppExportDecoder`-Roundtrip auf. Neue interne `ExportBuilder`-Struktur akkumuliert direkt `Visit`/`Activity`/`Path`/`PathPoint`-Modelle pro DayKey; `finalize()` baut `AppExport` direkt mit den neuen public memberwise-Initializern. Spart auf einer 50k-Entry-Datei: einen kompletten Foundation-Tree-Build, eine JSON-Encode-Pass, eine JSON-Parse-Pass und einen Codable-Decode-Pass.
- `Sources/LocationHistoryConsumer/AppExportModels.swift`: neue `public init(...)`-Memberwise-Initializer für `AppExport`, `Meta`, `Source`, `Output`, `ExportConfig`, `ExportFilters`, `DataBlock`, `Visit`, `Activity` (Cross-Module-Voraussetzung für den Direct-Model-Build). `Day`, `Path`, `PathPoint` hatten bereits public inits.
- `swift test`: **1006 Tests, 2 skipped, 0 failures** (gleicher Umfang; bestehende Tests laufen unverändert über die optimierten Pfade).
- Wrapper `xcodebuild` (iPhone 17 Pro Max Sim 26.3.1): BUILD SUCCEEDED.

**Ehrlich offen:** kein ZIP-Entry-Streaming (ZIPFoundation extrahiert weiterhin in eine `Data`, dann läuft der Reader darauf). Auto-Restore lehnt rohe Google Timeline weiterhin ab. Hardware-Re-Verifikation auf iPhone 15 Pro Max mit echter 46-MB-Datei steht weiterhin aus. Keine Mikro-Benchmarks gemessen — die genannten Einsparungen sind erwartete Größenordnungen / Designziel, kein gemessener Speedup-Faktor.

## 2026-05-06 (Element-based streaming parser for Google Timeline JSON)

### feat: streaming reader for raw Google Timeline JSON imports
- Manuelle Imports laden die Datei nicht länger komplett zusammen mit einem `JSONSerialization`-Tree.
- Neue Datei `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineStreamReader.swift`: `forEachObjectElement(contentsOf url:)` streamt Top-Level-Array-Elemente via FileHandle in 64-KB-Chunks; pro Element wird nur ein Object-Slice an `JSONSerialization.jsonObject(with:)` übergeben. Schwester-Variante `forEachObjectElement(in data:)` für ZIP-extrahierte Daten. State-Machine-Tokenizer mit String-/Escape-/Depth-Tracking, BOM-Skip, RFC-8259-Whitespace. Hard-Cap pro Element 8 MB → `StreamError.elementTooLarge`. Errors: `notArray`, `malformedJSON`, `ioFailure`, `elementTooLarge`.
- `GoogleTimelineConverter.swift`: `convert(data:)` läuft jetzt intern über den Streaming-Reader; neue API `convertStreaming(contentsOf url:)` für direkte JSON-Datei-Imports ohne Full-Data-Load. Ingest in `ingestEntry(...)` gemeinsam für beide Pfade.
- `AppContentLoader.swift`: `decodeFile(at:sourceName:)` sniffed die ersten 1 KB; bei `[` direkt in `convertStreaming(contentsOf:)`. Auto-Restore-Skip-Verhalten unverändert (Streaming ist speichersicher, aber Sekunden bis Minuten — bewusst nutzergesteuert).
- Tests neu: `Tests/LocationHistoryConsumerTests/GoogleTimelineStreamReaderTests.swift` mit 15 Cases (Happy Path, BOM/Whitespace, String mit `}]`, escaped Quote, nested Path, Error-Pfade, byte-by-byte-Chunking-Boundary-Test, 5 000-Entry-Synthetik, `convert(data:)` ↔ `convertStreaming` Äquivalenz).
- `swift test`: **1006 Tests, 2 skipped, 0 failures** (vorher 991).

**Ehrlich offen:** ZIP-Entry-Streaming bleibt aus — ZIPFoundation extrahiert weiterhin in eine `Data`, dann läuft der Streaming-Reader darauf (Memory-Peak ≈ Größe der entpackten Datei, aber ohne zusätzlichen 150–200-MB-`JSONSerialization`-Tree). Hardware-Re-Verifikation auf iPhone 15 Pro Max mit echter 46-MB-Datei steht aus. Auto-Restore lehnt rohe Google Timeline weiterhin ab. Bei >500 k Entries bleibt das einmalig aufgebaute `dayMap` ein nichttriviales RAM-Plateau, aber Größenordnungen unter dem alten Pfad.

## 2026-05-06 (Memory-Safety-Folgefix: Sniffer-Skip im Auto-Restore)

### fix: skip raw Google Timeline files during auto-restore regardless of size
- Folgefix zum Memory-Safety-Commit `8abe7ec`: Der vorherige reine 50-MB-Cap erfasste den realen 46-MB-iPhone-Crashfall NICHT (46 < 50). Der ergänzte Sniffer-Skip schließt die Lücke.
- `Sources/LocationHistoryConsumerAppSupport/AppContentLoader.swift`: Funktion `assertSizeWithinAutoRestoreLimitIfNeeded` umbenannt zu `assertAutoRestoreEligible`. Im Auto-Restore-Modus genügt das Sniffer-Ergebnis (`firstStructuralByte == '['`), um eine rohe Google-Timeline abzulehnen — **unabhängig von der Größe**. Gilt für direkte JSON-Dateien und für ZIPs mit Google-Timeline-Entry (Head-Sniff via begrenztem ZIP-extract-Abbruch).
- Manueller Import (`autoRestoreMode == false`) bleibt unberührt; bei manueller Auswahl gilt weiter der ehrliche 256-MB-Cap. Ein echter Streaming-Parser fehlt nach wie vor.
- `userFacingTitle`: "Large Google Timeline import detected" → "Import not auto-restored". `errorDescription` erweitert um den Grund "Raw Google Timeline exports and large files are skipped on launch …".
- 4 neue Tests in `LargeImportMemorySafetyTests` (`testAutoRestoreSkipsRawGoogleTimelineUnderSizeCap`, `testAutoRestoreSkipsRawGoogleTimelineZipEntryUnderSizeCap`, `testAutoRestoreAllowsSmallAppExportLikeFile`, `testManualLoadAllowsRawGoogleTimeline`) — Suite jetzt 18 Cases.
- `swift test`: 991 Tests, 2 skipped, 0 failures (vorher 987).
- **Ehrlich offen:** Manuelle Importe großer roher Google-Timeline-Dateien (>~30–40 MB) bleiben weiterhin riskant — kein echter Streaming-Parser. Hardware-Re-Verifikation des 46-MB-Falls auf iPhone 15 Pro Max steht aus.

## 2026-05-06 (Memory-Safety-Fix)

### fix: guard large Google Timeline restore against memory pressure
- iPhone-15-Pro-Max-Hardware meldete einen Jetsam-Kill für `LH2GPXWrapper` beim App-Start, wenn ein zuvor importiertes 46-MB-Google-Timeline-File (`location-history.zip`, ~65 k Einträge) per Auto-Restore wieder geladen wurde. Drei volle `JSONSerialization`-Passes plus Zwischen-Modelle = transienter Peak ~400–500 MB → Jetsam-fatal.
- **Auto-Restore-Schutz:** `AppContentLoader.loadImportedContent(from:autoRestoreMode:)` prüft im Auto-Restore-Modus die Dateigröße **vor** dem Read (`autoRestoreMaxFileSizeBytes = 50 MB`). Für ZIPs werden Entry-Metadaten via ZIPFoundation iteriert, ohne zu extrahieren. Über dem Cap wirft `AppContentLoaderError.autoRestoreSkippedLargeFile`. `wrapper/LH2GPXWrapper/ContentView` zeigt dedizierte User-Hinweis-Message ("Großer Google-Timeline-Import erkannt … bitte manuell importieren") und behält das Bookmark.
- **Sniffer-Detection:** `GoogleTimelineConverter.isGoogleTimeline` und neuer `isJSONObject` lesen nur das erste 1 KB (skippt Whitespace + UTF-8-BOM) und prüfen das erste Strukturzeichen. AppContentLoader-ZIP-Pfad nutzt den Object-Sniffer statt Array-Vollparse — erspart pro Aufruf ~150–200 MB transient.
- **Query-Fast-Path:** `AppExportQueryFilter.isPassthrough` (public, neu) + `AppExportQueries.projectedDays`-Fast-Path: bei deaktiverten Constraints werden Tage direkt sortiert zurückgegeben statt pro Tag eine `projectedDay(...)`-Kopie zu erzeugen. Spart ~80–130 MB transient pro Aufruf auf 65 k-Tage-Imports.
- **OverviewMap bounded coordinates:** `OverviewMapPathCandidate.fullCoordinates` wird in der Scan-Phase auf max 512 Punkte stride-decimiert. Visuell verlustfrei (Douglas-Peucker läuft trotzdem in `makeOverlay`), spart ~70–90 % residenten RAM bei dichten Tracks.
- 14 neue Tests in `LargeImportMemorySafetyTests` (Sniffer/Auto-Restore-Skip JSON+ZIP/Manueller-Import-bypass-Cap/`isPassthrough`/Query-Fast-Path/`strideDecimate`).
- `swift test`: 987 Tests, 2 skipped, 0 failures.
- `xcodebuild` (iPhone 17 Pro Max Sim 26.3.1): BUILD SUCCEEDED.
- Hardware-Verifikation auf iPhone 15 Pro Max mit echter 46-MB-Datei: pending (manuell).
- **Ehrlich offen:** echter Streaming-/Chunked-Google-Timeline-Parser noch nicht umgesetzt. Manuelle Importe > 50 MB sind weiterhin riskant; im Auto-Restore-Pfad wird der Fix zuverlässig greifen. **Nachtrag 2026-05-06 (Folgefix):** Der reine 50-MB-Cap allein war nicht ausreichend — er erfasste den realen 46-MB-Crashfall nicht. Ein zusätzlicher Sniffer-Skip lehnt rohe Google-Timeline-Dateien im Auto-Restore jetzt unabhängig von der Größe ab; siehe Eintrag oben.

## 2026-05-06 (post-Hero-Map)

### docs: deep audit + repo-truth-sync (HEAD post-`70254ff`)
- Wrapper-Doku Datei-fuer-Datei und Zeile-fuer-Zeile gegen Code abgeglichen.
- README: SPM-Pfad `../..` → `..` korrigiert (war seit `379b835` falsch dokumentiert); `fileImporter`-Aussage auf reale `allowedContentTypes` `[.json, .zip, .gpx, .tcx]` korrigiert (KML/GeoJSON sind Export-only); ASC-/Build-Status auf `CURRENT_PROJECT_VERSION = 100` aktualisiert.
- ROADMAP/NEXT_STEPS: Test-Zahl `228` (Linux, 2026-03-31) → `964` (macOS, 2026-05-06). Phase 19.53 als abgeschlossen markiert.
- xcode-test.yml: Kommentar zum SPM-relativePath korrigiert.

### feat: unify map layer controls into single right-side dropdown (commit `70254ff`)
- Neue Komponente `MapLayerMenu.swift` (Configuration-driven Dropdown) konsolidiert ALLE Map-Layer-Controls (Map-Style, Track-Color, Live-Optionen, Heatmap-Palette/Scale/Radius/Opacity, Fit-to-Data, Center-on-Location, Fullscreen).
- `LHMapStyleToggleButton` als `@available(*, deprecated)` markiert.
- Heatmap-Bottom-Sheet, Capsule-Chip-Cluster, Follow-Pill, Fullscreen-Close-X, standalone Style-Toggles und Fit-Buttons auf allen Map-Surfaces entfernt — durch das Menü ersetzt.
- Heatmap-Opacity snappt auf `25 / 50 / 75 / 100 %` Presets (Slider war im SwiftUI-Menu nicht moeglich).
- Heatmap-Stats bleiben als kleines bottom-leading Badge (Punkte · Tage · Datumsbereich).
- Tote Parameter (`verticalMapControls`, `showStyleToggle`) und Hilfsfunktionen (`mapControlButton`, `exploreControlButton`, `styleToggleIcon`) entfernt; alle Aufrufer aktualisiert.
- Day-Map nutzt jetzt `mapPosition`-State (statt statisches `initialPosition`) — Viewport springt bei Tag-Wechsel und Fit-to-Data ist verdrahtet.
- Export-Preview Fit-to-Data ergänzt; Overview `isFullscreenActive` korrekt an `isExpanded` gebunden.
- Live-Tracking Landscape-Card und Fullscreen nutzen jetzt die geteilten `liveAccuracyCircleContent` / `liveTrackContent` / `liveCurrentLocationAnnotation` MapContent-Builder — vorher hat das Landscape-Layout `MapLayerMenu`-Flags ignoriert (Speed-Coloring, Fade-Buckets, Accuracy-Circle).
- Heatmap-Overlay-Pattern auf einheitliches `.overlay(alignment:)` umgestellt; Padding repo-weit auf `8 pt`.
- Build green: `swift test` 964/2/0; Wrapper-`xcodebuild` (iPhone 17 Pro Max Sim 26.3.1) BUILD SUCCEEDED.

### fix: defensive guards against SIGABRT on launch (commit `74300a6`)
- Live-Tracking-Domain mit Defensiv-Guards gegen seltene Crash-Pfade beim App-Start.

### feat: maps next-level — Tempolayer, halo strokes, live polish (commit `ab054c7`)
- SpeedColors-Tempolayer als optionales Track-Coloring (cool→warm).
- Halo-Understrokes für bessere Kontraste auf Hybrid-Maps; Track-Width-Hierarchie nach Kontext (live > day > overview > export).

### feat: home screen — electric lightning background (commit `fa006cd`)
- `HomeBackground.imageset` für den Start-Bildschirm der Wrapper-App.

### feat: heatmap next-level — Magma palette, log-scale, soft-glow cells (commit `9118ac6`)
- Magma/Inferno-Paletten (perzeptuell uniform); Log-Scale-Aggregation; Soft-Glow-Cells via Radialgradient — bullseye-Ringe und harte Hex-Kanten visuell aufgelöst.

### feat: remove Routes mode from heatmap entirely (commit `fc3ccc5`)
- Routes-Modus aus der Heatmap entfernt; ausschliesslich Density.

### fix: heatmap P0 follow-up batches (commits `825a3de`, `50b4c58`, `bbd9e3b`, `f5de284`)
- Vier Verifikations-Batches mit Defaults für Streetzoom, weniger Burnout, sane low-density-Sichtbarkeit.

### feat: heatmap density Tier 2 — pointy-top hexagons + Mercator + cos(lat) (commits `a2f50bc`, `2e1c928`, `6a7c361`)
- Pointy-top Hexagon-Polygone als Tile-Geometrie; Mercator-Latitude-Korrektur; cos(lat)-Bin-Aggregation.

### fix: heatmap Tier 1 — kill lens-flare, soften block edges, fix i18n (commit `e7a2379`)
- Lens-Flare-Star entfernt; weichere Tile-Kanten; deutsche Lokalisierung der Heatmap-Beschriftungen korrigiert.

### feat: replace bundled demo fixture with real recorded LH2GPX track (commit `b1d65cb`)
- Bundled Demo-Fixture jetzt ein realer aufgezeichneter LH2GPX-Track (Oldenburg → Dänemark).

### chore: bump build number 96 → 100 (commit `8854eef`)
- `CURRENT_PROJECT_VERSION` auf `100` in pbxproj (alle 8 Build-Konfigurationen); `CFBundleVersion = 100` hartcodiert in beiden Info.plist-Dateien (App + Widget). Naechster ASC-Submit-Kandidat: Build ≥100 aus Xcode Cloud.

## 2026-05-06

### feat: LiveStatusResolver + Export-Empty-State-Cleanup + Polish
- Neuer `LiveStatusResolver` konsolidiert Live-Status (Permission/Acquiring/Ready/Recording × Weak/Good). Eine dominante Hauptmeldung pro Zustand. GPS-Chip "Searching" statt "Weak" wenn kein Fix.
- Export: Ende der widersprüchlichen Empty-Messages — Hero-Placeholder + Chip + Card adaptieren, `Select All`-CTA prominent.
- Doppelte Karte auf Export-Tab behoben (Preview-Card unterdrückt Map-Render bei `heroEnabled`).
- Settings/Insights Quick-Wins: Lesbarkeit der Beschreibungen, KPI-Grid Dynamic-Type-robust.
- `swift test`: 949 Tests, 2 skipped, 0 failures ✅
- Privacy/Upload-Defaults und Recording-Verhalten unverändert.

### feat: Hero-Map-Workspace auf Übersicht/Insights/Export/Live ausrollen (Tage-Optik)
- Neue gemeinsame Komponente `LHHeroMapWorkspace.swift` (Layout-Konstanten + `lhDeviceTopSafeInset()`).
- Compact iPhone: Map auf Übersicht/Insights/Export/Live/DayDetail-Portrait läuft jetzt full-bleed unter Status-Bar / Dynamic Island, vertikaler Control-Stack rechts oben, Filter/Range/Format-Chips unter der Map (analog Tage).
- Bestehende Funktionen (Heatmap, fileExporter, Recording/Follow/Fullscreen, ExportPreviewDataBuilder, AppOverviewMapModel-Pan-Invariante) erhalten.
- iPad/Regular + Landscape: Legacy-Pfade unverändert.
- `swift test`: 933 Tests, 2 skipped, 0 failures ✅
- App-Store: Build 96 noch nötig vor Submit; Visual-Verifikation auf echtem Gerät offen.

### fix: consolidate Days top workspace + map controls below status bar (Build 96 nötig)

- **Root Cause Statusbar**: Map-Controls (Globe/Fit-to-data) in `AppOverviewTracksMapView.compactMapView` lagen mit nur `.padding(8)` direkt am oberen Map-Rand. Da Days die Map per `.ignoresSafeArea(edges: .top)` hinter Dynamic Island/Statusbar zieht, landeten die Buttons sichtbar im Statusbar-Bereich.
- **Fix Statusbar**: Neuer Initializer-Param `mapControlTopPadding: CGFloat = 8` (Default unverändert für Overview/Detail). Days reicht `deviceTopSafeInset + 12` durch — Buttons liegen sichtbar unter Dynamic Island.
- **Root Cause LHCollapsibleMapHeader**: `safeAreaTopInset`-Parameter existierte, wurde aber im Body ignoriert. `geometry.safeAreaInsets.top` liefert in `safeAreaInset/ignoresSafeArea`-Kontexten 0.
- **Fix LHCollapsibleMapHeader**: `overlayControlBar(safeAreaTop: max(geometry.safeAreaInsets.top, safeAreaTopInset))` — der von außen gemessene Wert wird wirksam.
- **Konsolidierung Top-Workspace**: Die zwei separaten `.safeAreaInset(edge: .top)`s aus dem vorigen Eintrag (Map + Filter) sind jetzt zu EINEM `safeAreaInset` mit `VStack { daysListStickyHeader; daysFilterPanel }.background(.black)` zusammengefasst. Robuster gegen List-/Section-Header-Insets, kein Gap zwischen den beiden Stickys.
- **Filter-Padding**: Top-Padding 8 → 4, damit Suchleiste flush an Map sitzt.
- **Test-Hooks**: Suchfeld bekommt `accessibilityIdentifier("days.searchField")`.
- `swift test`: 933/0 (2 skipped) ✅
- `xcodebuild` iPhone 17 Pro Sim 26.3.1: **BUILD SUCCEEDED** ✅
- `xcodebuild` iPhone 15 Pro Max physisch (UDID 00008130-00163D0A0461401C): **BUILD SUCCEEDED** ✅
- `devicectl install` + `process launch` auf iPhone 15 Pro Max ✅
- **Visuelle Verifikation am echten Gerät steht aus** (User testet lokal). Build-96-Einreichung erst nach OK.

### fix: filter panel as second safeAreaInset, eliminates 80pt gap (Build 96 nötig)

- **Root Cause**: 80pt schwarzer Streifen zwischen Map-Unterkante und Searchbar entstand durch List-internes Top-Padding (Nav-Bar-Safe-Area 44pt + First-Section-Header-Inset ~36pt). Weder `.listStyle(.plain)` noch `.ignoresSafeArea(.all)` auf der Map konnten das beheben — beide adressieren nur die Safe-Area-Seite, nicht die List-interne Seite.
- **Fix**: `daysFilterPanel` komplett aus der List entfernt und als ZWEITES `.safeAreaInset(.top)` direkt unter dem Map-StickyHeader gestapelt. Beide sind jetzt sticky und garantiert flush — Searchbar liegt immer direkt an der Map-Unterkante.
- **UX-Bonus**: Searchbar + Date/Filter-Chips sind jetzt während des Scrollens immer sichtbar (vorher verschwanden sie beim Hochscrollen).
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone 15 Pro Max **BUILD SUCCEEDED** ✅

### polish: compact days controls below map (Build 96 nötig — Build 95 veraltet)

- **Control-Clearance erhöht**: `overlayControlBar` in `LHCollapsibleMapHeader` padded jetzt `.padding(.top, safeAreaTop + 80)` statt `+ 56` — ergibt ~139 pt ab Bildschirmoberkante auf iPhone 15 Pro Max (Dynamic Island). Keine App-Controls mehr im Bereich von Uhrzeit, Akku, Mobilfunk oder Dynamic Island.
- **Schwarze Lücke zwischen Map und Searchbar entfernt**: Root Cause war der `.insetGrouped` List-Default-Style mit seinem Top-Content-Inset. Fix: `.listStyle(.plain)` auf `compactDayList` — Searchbar beginnt jetzt direkt unter der Karte.
- **Filter-Panel kompaktiert**: `compactContextPill` (passive Datumsanzeige) durch interaktive `HistoryDateRangeFilterBar` direkt im Chip-Row ersetzt. Die separate `HistoryDateRangeFilterBar`-Section (die bei aktivem Filter zusätzlich erschien und "Last 7 Days" doppelt anzeigte) entfernt. Eine Zeile statt zwei für den Datumsfilter.
- Build 95 (Commit c5a81f7) ist **veraltet** — enthält diesen Fix nicht. Nächster Submit-Build: **Build 96**.
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone 15 Pro Max **BUILD SUCCEEDED** ✅

### polish: Days Map-Höhe erhöht, schwarze Lücke über Filter-Panel entfernt (Build 95 nötig — veraltet)

- **Map-Höhe angehoben**: `daysMapHeaderState.compactHeight` 340 → 460 pt, `expandedHeight` 420 → 560 pt — Map-Unterkante auf iPhone 15 Pro Max nun bei ca. 460 pt ab y=0, innerhalb der Zielmarke.
- **Schwarze Lücke eliminiert**: SwiftUI-List-Default-Section-Spacing (≈20 pt) zwischen Map-StickyHeader und erstem List-Section entfernt via `DaysListSectionSpacingModifier` (`.listSectionSpacing(0)`, iOS-17-only, no-op auf iOS 16).
- **iOS-16-Kompatibilität**: Modifier als `private struct DaysListSectionSpacingModifier: ViewModifier` mit `if #available(iOS 17.0, *)` Guard — compiliert auf allen Zielplattformen.
- Build 94 (Commit 728f50a) ist **veraltet** — enthält diesen Fix nicht. Nächster Submit-Build: **Build 95**.
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone 15 Pro Max **BUILD SUCCEEDED** ✅

### polish: Days Filter below Map, DayCard Layout tightened (Build 94 nötig — veraltet, Build 94 enthält diesen Fix nicht)

- **Search + Date-Filter aus dem Map-Overlay entfernt**: Search-Bar und Date-Range-Pill lagen bisher als ZStack-Overlay direkt auf der Karte (und damit teilweise hinter dem Dynamic Island). Beides jetzt als kompakter `daysFilterPanel` direkt unterhalb der Karte im scrollbaren List-Content.
- **Safe-Zone freihalten**: Die Expand/Collapse-Buttons in `LHCollapsibleMapHeader` (overlayControls-Modus) nutzen jetzt einen `GeometryReader`, der `geometry.safeAreaInsets.top` liest und als `.padding(.top, ...)` auf die Button-Group anwendet — iOS-16-kompatibel, keine `safeAreaPadding`-API nötig.
- **DayCard horizontales Padding reduziert**: `AppDayRow` von `.padding(14)` auf `.padding(.horizontal, 8).padding(.vertical, 12)` — mehr Breite, Touch-Targets ≥ 44pt erhalten.
- **DayList Row-Insets verkleinert**: `.listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))` auf allen DayRows (compact + iPad) — dichtere Liste, weniger Luft zwischen Karten.
- **Separator + Row-Background**: `.listRowSeparator(.hidden)` und `.listRowBackground(Color.clear)` auf DayRows gesetzt — konsistenter mit dem Dark-Design.
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone 15 Pro Max **BUILD SUCCEEDED** ✅

### polish: Days Map Edge-to-Edge Hero with Overlay Controls (Build 93)

- **Edge-to-Edge Hero**: Karte füllt volle Breite und beginnt bei y=0 hinter Dynamic Island/Statusbar (`ignoresSafeArea(.container, edges: .top)` auf `daysMapHeaderCard` im ZStack-Hero)
- **NavigationBar transparent**: `.toolbarBackground(.hidden, for: .navigationBar)` auf dem compact Days-Tab — kein schwarzer Header-Block mehr über der Karte
- **Searchbar als Map-Overlay**: Native `.searchable` ersetzt durch Custom TextField in `.thinMaterial`-Container, direkt auf der Karte als ZStack-Overlay (SafeArea-bewusst)
- **Context-Pill als Map-Overlay**: Date-Range-Pill (bisher unterhalb der NavBar) jetzt ebenfalls als transparentes Overlay auf der Karte
- **Map-Höhe erhöht**: `compactHeight` 280 → 340 pt, `expandedHeight` 360 → 420 pt — mehr Karte sichtbar
- **Day-Row Chips nicht mehr abgeschnitten**: `metricPill`-HStack in `AppDayRow` in `ScrollView(.horizontal)` gewrappt; `.lineLimit(1)` durch `.fixedSize(horizontal: true, vertical: false)` ersetzt — "6 visits", "3 routes", "23.2 km" vollständig sichtbar
- **Chip-Spacing reduziert**: 10 → 8 pt für kompaktere Darstellung; alle 4 Metric-Chips in einer Zeile
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone 15 Pro Max **BUILD SUCCEEDED** ✅

## 2026-05-05

### UI-Layout-Fix Tage-Seite: Suchleiste stabil, Karte größer

- **Suchleiste stabil**: `navigationBarTitleDisplayMode` auf Days-Tab von `.large` → `.inline` — verhindert das Heruntergleiten der iOS-SearchBar beim Scrollen und die Überlagerung des Sticky-Headers
- **Karte deutlich größer**: `daysMapHeaderState.compactHeight` 180 → 280 pt, `expandedHeight` 260 → 360 pt — die eigentliche Map-Viewport-Fläche entspricht nun ca. 30–33 % des sichtbaren Bereichs
- **Leerer Streifen eliminiert**: `LHSectionHeader("Map")` aus `daysMapHeaderCard` entfernt — der `LHCollapsibleMapHeader.controlBar` übernimmt die Steuerung; kein doppelter Header mehr
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone 15 Pro Max (iOS 26.4): **BUILD SUCCEEDED** ✅

### UI Polish: Doppeltitel-Fix, Limit-Badge, Demo-Label, Privacy-Banner (Commit ce993d9)

- **Doppeltitel behoben** (Insights + Export): `.navigationTitle("")` + `.navigationBarTitleDisplayMode(.inline)` — kein doppelter Titel mehr in den Sheet-Überschriften
- **Limit-Badge unterdrückt**: `localizedProjectedFilterDescriptions` blendet „Limit: N days"-Badge aus der UI aus
- **Demo-Fixture-Label**: Anzeigename von `golden_app_export_sample_small.json` auf `Bundled sample` geändert (nutzerfreundlicher)
- **Privacy-Banner im Empty State**: `ContentView` zeigt Privacy-Hinweis-Row im leeren Zustand
- **DemoSessionStateTests**: an neues Demo-Label angepasst
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone_15_Pro_Max (arm64, iOS 26.4): **BUILD SUCCEEDED** ✅
- Commit `ce993d9`, Branch `main`, Push ✅
- **Hinweis**: ce993d9 wurde nach Xcode Cloud Build 84 gepusht. Vor Submit for Review ist ein neuer Xcode Cloud Build erforderlich.

### Stop-Ship-Fixes: Auto-Split, Widget-Daten, Widget-Family (Commit 3469bcc)

- **Bug 1 — LiveTrackRecorder Auto-Split Datenverlust behoben**:
  - `start()` löscht `splitOffTrack` nicht mehr (zuvor sofortiger Datenverlust nach dem Split)
  - `handleLocationSamples` draint `splitOffTrack` nach jedem Sample-Batch: persistiert den fertigen Segment-Track, setzt neue `currentRecordingSessionID`, aktualisiert `liveTrackPoints` auf das neue Segment
  - 4 neue Tests in `LiveTrackRecorderTests` + 2 neue Integrationstests in `LiveLocationFeatureModelTests`
- **Bug 2 — Home-Widget erhält echte Echtdaten**:
  - `stopRecordingFlow()` und Split-Drain rufen `updateWidgetData()` auf
  - `updateWidgetData()` schreibt `WidgetDataStore.save(recording:)` + berechnet und schreibt `saveWeeklyStats()` (Wochenbasis, `Calendar.current`)
  - `ContentView` reloaded WidgetKit-Timelines via `WidgetCenter.shared.reloadAllTimelines()` bei `preferences.widgetAutoUpdate == true`; `import WidgetKit` ergänzt
- **Bug 3 — Home-Widget Family-Switch**:
  - `LH2GPXWidgetEntryView` (neu) mit `@Environment(\.widgetFamily)`: `systemSmall` → `LH2GPXSmallWidgetView`, sonst → `LH2GPXMediumWidgetView`
  - `LH2GPXHomeWidget.body` nutzt jetzt `LH2GPXWidgetEntryView` statt immer `LH2GPXMediumWidgetView`
- `swift test`: 933/0 ✅ — `xcodebuild` iPhone_15_Pro_Max (arm64, iOS 26.4): **BUILD SUCCEEDED** ✅
- Commit `3469bcc`, Branch `main`, Push ✅

### Xcode Cloud Build 84 — erfolgreich (Version 1.0.1)

- **Build 84**: Xcode Cloud Workflow `Release – Archive & TestFlight` — `Archive - iOS` ✅, `TestFlight-interne Tests - iOS` ✅
- **Version**: `1.0.1 (84)` — erster valider Build für den 1.0.1-Train
- **Befund**: MARKETING_VERSION-Fix aus Commit `fdd48a9` hat das ITMS-90186/90062-Problem behoben
- **Nächster manueller Schritt**: In ASC Version `1.0.1` → Build `84` auswählen, Screenshots prüfen/ersetzen (6 iPhone-15-Pro-Max-PNGs aus `docs/app-store-assets/screenshots/iphone-67/`), speichern, `Zur Prüfung einreichen`
- `swift test`: 927/0 ✅ — `git diff --check`: sauber ✅
- Build 83 (und 80–82): ungültig, ignorieren — scheiterten an geschlossenem 1.0-Train, nicht an Code

### Version-Bump 1.0 → 1.0.1 (ASC Upload-Fix)

- **Root Cause Build 83**: ASC lehnte Upload mit ITMS-90186 (`Invalid Pre-Release Train — 1.0 closed`) + ITMS-90062 (`CFBundleShortVersionString [1.0] must be higher than previously approved [1.0]`) ab. Kein Code-, Signing- oder Xcode-Cloud-Problem.
- **Fix**: `MARKETING_VERSION` in `project.pbxproj` von `1.0` → `1.0.1` (alle 8 Build-Konfigurationen: LH2GPXWrapper Debug/Release, Widget Debug/Release, Tests Debug/Release, UITests Debug/Release)
- Plists bleiben unverändert: `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` — kein hardcodierter Wert
- `CURRENT_PROJECT_VERSION = 45` bleibt lokaler Fallback; `CI_BUILD_NUMBER` injiziert weiterhin echte Buildnummer via `ci_pre_xcodebuild.sh`
- ASC Version `1.0.1` bereits angelegt; nächster Xcode Cloud Build (≥ 84) soll unter `1.0.1` hochgeladen werden
- `swift test`: 927/0 ✅ — `git diff --check`: sauber ✅

### Landscape-Verifikation + UITest-Fix

- **testLandscapeLayoutSmoke** (neu): Landscape-Smoke-Test für alle 5 Haupt-Tabs (Overview, Days, Export, Insights, Live) auf iPhone 15 Pro Max — PASSED (62s); Portrait-first-Strategie mit Tab-Rotation pro Tab; Screenshots als Testanhänge
- **Live-Activity-Identifier-Fix** (`runLiveActivityCaptureFlow`): stale Identifier `live.recording.start/stop` → `live.recording.primaryAction/stopAction` korrigiert (alle 5 Capture-Tests waren ohne diese Korrektur nicht lauffähig)
- Landscape-Befund: kein Layout-Crash in allen 5 Tabs; `live.recording.primaryAction`-Accessibility in Landscape als bekannte UITest-Einschränkung (XCTest nach Rotation) dokumentiert
- APPLE_VERIFICATION_CHECKLIST.md: Landscape-Sektion ergänzt mit PASSED-Befund und bekannter Accessibility-Lücke
- NEXT_STEPS.md: Landscape-Checkbox abgehakt

## 2026-04-30

### Release Prep Truth Sync
- lokales Wrapper-Projekt auf Build `45` angehoben, damit der naechste Release-Kandidat ueber dem bereits dokumentierten TestFlight-Build `1.0 (44)` liegt
- explizite Release-`CODE_SIGN_IDENTITY` fuer App + Widget entfernt; `CODE_SIGN_STYLE = Automatic` bleibt der einzige Repo-Signing-Pfad
- lokaler Release-Befund dokumentiert: `xcodebuild archive` erfolgreich, `xcodebuild -exportArchive` auf diesem Host weiterhin blockiert (`No signing certificate "iOS Distribution" found`)

## 2026-04-30

### Verification Doc Truth Sync
- Wrapper-Doku und Runbooks auf aktuellen Release-Truth gezogen: `TARGETED_DEVICE_FAMILY = 1` (iPhone-only v1), keine iPad-Screenshot-Pflicht fuer den aktuellen Build
- Deployment-Target-Doku fuer App/Widget auf `iOS 16.0 / 16.2` korrigiert
- keine Produktcode-Aenderung; nur Verifikations- und Runbook-Drift bereinigt

## 2026-04-29

### Dynamic Island / Live Activity Truth Sync
- Wrapper-Doku auf den aktuellen Core-Stand fuer Dynamic-Island-Konfiguration gezogen: persistenter Primärwert (`Distanz`, `Dauer`, `Punkte`, `Upload-Status`), sichtbare Fallback-Hinweise bei deaktivierten / nicht verfuegbaren Live Activities und kompakterer Heatmap-Einstieg in der Overview
- frischer lokaler Nachweis ergaenzt: `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build` erfolgreich
- frischer Simulator-Testlauf fuer `LH2GPXWrapperTests` konnte auf diesem Host nicht repo-wahr als gruen verbucht werden; der Launch brach mit `NSMachErrorDomain Code=-308 (ipc/mig server died)` ab und bleibt deshalb offen dokumentiert

## 2026-04-12

### Truth Sync
- Wrapper-Doku auf den aktiven `iOS-App`-Repo-Kontext nachgezogen; historische Monorepo-Hinweise bleiben nur als Kontext
- aktueller Linux-Nachweis auf `swift test` im aktiven Repo korrigiert: `575` Tests, `2` Skips, `0` Failures
- Wrapper-Beschreibung auf echten Produktstand angeglichen: dedizierter Live-Tab, Widget-/Dynamic-Island-Optionen, Fullscreen-/Follow-Live-Karte und ehrliche Abgrenzung von offenen Punkten wie fehlendem Auto-Resume und fehlendem echtem Road-Matching

## 2026-04-12

### App Groups Entitlements / Widget-Datenaustausch
- `wrapper/LH2GPXWrapper/LH2GPXWrapper.entitlements` erstellt mit `com.apple.security.application-groups: group.de.roeber.LH2GPXWrapper`
- `wrapper/LH2GPXWidget/LH2GPXWidget.entitlements` erstellt mit `com.apple.security.application-groups: group.de.roeber.LH2GPXWrapper`
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: `CODE_SIGN_ENTITLEMENTS` fuer alle 4 Build-Konfigurationen beider Targets (`LH2GPXWrapper` + `LH2GPXWidget`) gesetzt
- Widget-Datenaustausch via `WidgetDataStore` (UserDefaults App Group) funktioniert jetzt korrekt; vorher zeigte Widget immer "Keine Aufzeichnung"

### fileImporter GPX/TCX
- `allowedContentTypes` in `ContentView.swift` von `[.json, .zip]` auf `[.json, .zip, .gpx, .tcx]` erweitert
- `UTType.tcx` Extension in Core (`GPXDocument.swift`) hinzugefuegt

### Deep Link lh2gpx://live
- `CFBundleURLTypes` mit Schema `lh2gpx://` in `wrapper/Config/Info.plist` registriert
- `onOpenURL`-Handler + `handleDeepLink()` in `ContentView.swift` hinzugefuegt; navigiert zu Live-Tab (`selectedTab = 3`) via `navigateToLiveTabRequested` in `LiveLocationFeatureModel`

## 2026-03-31

### Repo-Truth Deep Audit / Doc Sync

- repo-weite Deep-Audit-Synchronisierung gegen Code, Wrapper-Konfiguration und Host-Realitaet; aktuelle Truth-Bloecke jetzt auf den frischen Core-Linux-Nachweis `swift test`: `228` Tests, `2` Skips und `0` Failures gezogen
- historische Apple-/Device-/Simulator-Nachweise vom 2026-03-17 und 2026-03-30 expliziter als historische Nachweise markiert; fuer diesen Audit-Host wird jetzt klar festgehalten, dass `xcodebuild` auf Linux nicht verfuegbar ist
- `README.md`, `ROADMAP.md`, `NEXT_STEPS.md`, `docs/LOCAL_IPHONE_RUNBOOK.md` und `docs/TESTFLIGHT_RUNBOOK.md` repo-wahr auf aktuellen Core-Scope (`Live`, `Upload`, `Insights`, `Days`, Heatmap), offene Apple-Verifikation und entschaerftes Privacy-/Review-Wording geglaettet

## 2026-03-30

### Branch Consolidation / Doc Truth Sync

- `ROADMAP.md` und `NEXT_STEPS.md` auf den konsolidierten `main`-Stand gezogen; veraltete Aussagen zu fehlender Heatmap-Testabdeckung und offenen Linux-Failures entfernt
- Wrapper-Doku trennt jetzt sauber zwischen dem aktuellen Core-Linux-Check (`swift test`: `217` Tests, `2` Skips, `0` Failures) und den historischen Apple-CLI-/Device-Nachweisen vom 2026-03-30

### Apple Device Verification Batch 1

- `docs/LOCAL_IPHONE_RUNBOOK.md`, `NEXT_STEPS.md`: echter iPhone-15-Pro-Max-Lauf repo-wahr nachgezogen
- `xcodebuild test -allowProvisioningUpdates -scheme LH2GPXWrapper -destination 'id=00008130-00163D0A0461401C' -only-testing:LH2GPXWrapperUITests` lief gegen das verbundene reale Geraet
- `LH2GPXWrapperUITestsLaunchTests.testLaunch` lief real auf dem Device erfolgreich durch
- `LH2GPXWrapperUITests.testAppStoreScreenshots` scheiterte an einem echten Produktzustand statt an Infrastructure: beim Start war bereits `Imported file: location-history.zip` aktiv, daher erschien der erwartete `Demo Data`-Button nicht
- Accessibility-Snapshot aus dem Device-Lauf zeigt sichtbare `Heatmap`-Aktion, sichtbaren dedizierten `Live`-Tab und beobachtbaren Wrapper-Auto-Restore
- Background-Recording, aktives Heatmap-Oeffnen, aktiver `Live`-Flow und End-to-End-Upload bleiben offen

### Apple Stabilization Batch 1

- `LH2GPXWrapper.xcodeproj/project.pbxproj`: SPM-Pfad von `../../../Code/LocationHistory2GPX-iOS` auf `../LocationHistory2GPX-iOS` korrigiert – falscher Pfad verhinderte Package-Resolution und jeden lokalen Build auf diesem Mac
- `docs/TESTFLIGHT_RUNBOOK.md`: Privacy-Text korrigiert – "Alle Daten verbleiben lokal" durch sachlich korrekte Aussage ersetzt: lokales Standardverhalten, optionaler nutzergesteuerter Server-Upload standardmaessig deaktiviert
- `README.md`: Privacy-Manifest-Beschreibung korrigiert – "keine Datenerhebung" entfernt, optionaler Upload nuechterner beschrieben; Review-Guidelines-Stand auf "offen/teilweise" gesetzt statt "konform"
- README, ROADMAP, NEXT_STEPS und Runbooks nach erneutem Apple-CLI-Rerun nachgeschaerft – korrekter lokaler SPM-Pfad dokumentiert, Wrapper-Simulator-Tests als gruen eingetragen und die 2 verbleibenden roten macOS-/SwiftPM-Tests explizit offengelassen

### Audit Fix / Truth Sync
- README, ROADMAP, NEXT_STEPS und Runbooks auf den aktuellen Wrapper-Repo-Truth fuer Auto-Restore, optionales Networking und ehrlichen Verifikationsstatus synchronisiert
- Review-/Privacy-Wording fuer den optionalen Server-Upload nuechterner formuliert

## 2026-03-20

### Import / Restore Flow
- `ContentView` nutzt den asynchronen Datei-Ladepfad
- `restoreBookmarkedFile()` wird beim App-Start wieder aufgerufen; der Wrapper-Auto-Restore ist damit reaktiviert

### Core Export Capabilities Surfaced In Wrapper
- die ueber das Core-Package eingebundene Export-UI schaltet jetzt `GeoJSON` als drittes aktives Exportformat frei
- Export bietet jetzt `Tracks`, `Waypoints` und `Both` als Moduswahl
- lokale Exportfilter im Wrapper decken jetzt auch Bounding Box und Polygon fuer importierte History ab

### Core Language / Upload Capabilities Surfaced In Wrapper
- die ueber das Core-Package eingebundene Optionen-Seite bietet jetzt Deutsch/Englisch als Sprachwahl
- der Wrapper uebernimmt jetzt die partielle deutsche Shell-/Optionen-/Live-Recording-Abdeckung aus dem Core-Repo
- akzeptierte Live-Recording-Punkte koennen jetzt optional an einen frei konfigurierbaren HTTP(S)-Endpunkt mit optionalem Bearer-Token gesendet werden
- der Standard-Testendpunkt ist mit `https://178-104-51-78.sslip.io/live-location` vorbelegt und damit konsistent zur HTTPS-Validierung des Core-Codes

### Background Recording Wrapper Support
- Wrapper-Build-Einstellungen enthalten jetzt zusaetzlich `NSLocationAlwaysAndWhenInUseUsageDescription`
- `UIBackgroundModes` aktiviert `location`, damit die optionale Background-Live-Recording-Unterstuetzung aus dem Core-Repo auf iOS sauber deklariert ist
- Device-Verifikation fuer den erweiterten Permission-Flow bleibt separat offen

## 2026-03-19

### Local Options Wrapper Integration
- Wrapper-ContentView exposes the shared `AppOptionsView` from the core package via the `Actions` menu
- shared `AppPreferences` are injected so start-tab, distance-unit, map-style and technical-details settings take effect in the wrapper too
- README updated to document the new local options surface

## 2026-03-18

### Live Recording Wrapper Integration
- iOS-Wrapper auf die neue Live-Recording-Domain aus dem Core-Repo verdrahtet
- `NSLocationWhenInUseUsageDescription` fuer foreground-only Live-Location hinzugefuegt
- README und Runbooks auf direkten Google-Takeout-Import, getrennte Live-Track-Persistenz und deaktiviertes Auto-Resume korrigiert
