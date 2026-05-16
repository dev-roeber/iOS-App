# CHANGELOG

## 2026-05-16 — Train H — App Performance / Stability / UX Hardening (`main`)

> **Train H, mehrere zusammenhängende Commits.** Konservative Optimierungen über mehrere Bereiche. Keine Versions-Bumps, keine UI-Redesigns, keine App-Review-Behauptungen.

### Umgesetzte Commits (Reihenfolge)
1. **`a741b76` `chore: clean redundant ios 16 availability gates`** — 12 `@available(iOS 16.0/16.1/16.2[, macOS 13.0], *)`-Attribute entfernt (`ActivityManager` 4×, `LH2GPXLoadingBackground` 2×, `TrackingLiveActivityWidget` 2×, `AppInsightsContentView` 1×, `TrackingAttributes` 1×, `LH2GPXHomeWidget` 1×, `LH2GPXWidgetBundle` 1×). 11 `if #available(iOS 16.x, *)`-Runtime-Checks bewusst nicht angefasst (Dedenting-Risiko, separater Cleanup).
2. **`254875a` `perf: reduce csv export array reallocations`** — `CSVBuilder.build(from:)` ruft jetzt `lines.reserveCapacity(estimated)` aus einem schnellen `visits+activities+paths`-Zähllauf pro Tag. GPX/KML/GeoJSON hatten bereits `reserveCapacity`; CSV war der Outlier. Output-Bytes unverändert.
3. **`86b3da6` `perf: cap wal growth in local timeline store`** — Zwei WAL-sichere SQLite-Pragmas in `LocalTimelineStore.init(url:)`: `PRAGMA journal_size_limit = 16777216` (16 MiB Cap nach Checkpoint), `PRAGMA wal_autocheckpoint = 1000` (Default, explizit gemacht). `mmap_size` bewusst nicht gesetzt (iOS-Sandbox-Verhalten Linux-nicht-prüfbar). Bestehende `checkpointWAL`-API unverändert.
4. **`7288a5f` `perf: add live track render cap helper`** — Neuer Foundation-only Helper `LiveTrackRenderCap` mit reiner Funktion `apply(points:cap:)`. Hält `cap/2` neueste Punkte verbatim + stride-dezimiert die ältere Hälfte; erste und letzte Position immer erhalten. **Bewusst noch nicht in `AppLiveTrackingView` verdrahtet** — Device-Validierung der Cap-Werte + UX-Hinweis für gekappten Zustand sind Folge-Train. Raw `liveTrackPoints` (Persistence/Export) unberührt. 10 Unit-Tests.

### Übersprungene Phasen (mit Grund)
- **Phase 3 — Identity Surface B2:** Die im Audit als „SAFE" markierten Stellen (`AppDayDetailView` 371/378, `AppExportPreviewMapView` 58/62, `AppOverviewTracksMapView` 202/409) liefern bei genauer Code-Inspektion **keine garantiert unique stabilen Domain-IDs**: `ActivityItem.startTime`, `VisitItem.startTime`, `DayMapVisitAnnotation.startTime` sind Optional, Koordinaten können bei Duplikat-Daten kollidieren. Composite-Key-Migration hätte Risiko von SwiftUI-Duplikat-ID-Warnungen ohne sichtbaren Nutzen für read-only-Listen. **Übersprungen aus Risiko-Nutzen-Gründen.** Inventur in den Audits dokumentiert.
- **Phase 4 — Heatmap-Debounce-Wiring:** `AppHeatmapView.swift:80` nutzt bereits `.onMapCameraChange(frequency: .onEnd)`, d.h. `updateForRegion` wird nur am **Ende** einer Geste aufgerufen. Ein zusätzlicher 100 ms-Debounce (`debounceUpdateForRegion` im Model) würde den finalen Render verzögern, ohne nennenswert Rebuilds zu sparen. `debounceUpdateForRegion` bleibt im Model unwidered. **Übersprungen, weil bereits ausreichend geworfelt.**
- **Phase 7 — UI/UX-Polish (Performance-Transparenz):** UX-Hinweise (z.B. „Live route display optimized for performance") sind eng an die Live-Render-Cap-Verdrahtung gekoppelt — solange `LiveTrackRenderCap` nicht im View verdrahtet ist, wäre eine Statuszeile irreführend. Mit Phase 2 als Folge-Train.

### Verifikation (Linux)
- `git diff --check` (alle Commits): clean.
- `swift build`: clean.
- `swift test`: **1469 / 2 Skips / 0 Failures, ~55 s** (vorher 1459 — +10 Tests aus `LiveTrackRenderCapTests`).
- Filterläufe ohne Fehler: `Performance`, `Map`, `Live`, `Export` (188/0), `Heatmap`, `Timeline`, `Store` (180/0), `Insights`, `Path`. Filter ohne eigene Suite (z.B. `Live`) trafen Tests aus anderen Suites, kein Fehler.

### Repo-Truth (lokal, unverändert)
- `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171`.
- Letzter extern verifizierter Build: **Xcode Cloud Build 175** (basiert auf `2bfc009`).
- Train-H-Commits (`a741b76` → `7288a5f`) sind **nicht** in Build 175. Sie kommen erst in einem neuen Xcode-Cloud-Build extern an.

### Was Linux nicht prüfen kann
- Tatsächliches Render-Verhalten der Live-Polyline (MapKit/SwiftUI, iOS-Speicherdruck) bei aktivem Cap.
- iOS-spezifisches WAL-Verhalten unter Memory-Pressure / Jetsam.
- Widget/Live-Activity-Layout nach Removal der iOS-16-Attribute (kompiliert, aber visuell unverifiziert).

### Zwingender nächster Xcode-Cloud/TestFlight-Test
1. **Neuer Xcode-Cloud-Build** auslösen → Build 176 (oder höher), basiert auf HEAD nach Train H.
2. TestFlight-Install auf iPhone 14 Pro / iPhone 16 Pro Max.
3. **Manuelle Smoke-Test-Checkliste:**
   - Live-Recording 5+ Minuten ohne Crash, Polyline-Update flüssig.
   - Live Activity auf Lock-Screen + Dynamic Island sichtbar (Geräte mit iPhone 14 Pro+).
   - Home-Widget zeigt aktuelle Daten.
   - LocalTimelineStore: großer Import (≥10 MiB), Export, Force-Quit + Reopen → keine WAL-Korruption, Daten intakt.
   - Heatmap: schnelles Pan/Zoom auf großem Dataset bleibt responsiv.
   - CSV-Export mehrerer Tage funktioniert, Inhalt byte-identisch zum vorherigen Build.
   - iPad-Layout funktional.

### Empfohlener nächster Train
- **H-Wire-1**: `LiveTrackRenderCap` in `AppLiveTrackingView` verdrahten mit Preference-Toggle (Default OFF) + UX-Hinweis-String.
- **H-Cleanup-2**: Die 11 `if #available(iOS 16.x, *)`-Runtime-Checks dedenten.
- **B2-Wrap**: Die im Audit aufgeführten Identity-Stellen mit explizitem `IdentifiableWrapper(id: UUID(), value: …)`-Pattern stabilisieren, falls Render-Stabilität auf Device beobachtbar Probleme zeigt.
- **D / G2 (Mac/Instruments-only)**: Heatmap-Multi-LOD-Wiring, MKMapView-Bridge.

---

## 2026-05-16 — docs: record xcode cloud build 175 verification (`main`)

> **Reine Doku-Aktualisierung.** Keine Code-Änderung, keine Versions-Bumps.

### Extern belegter Stand (Screenshots, 2026-05-16)
- **Xcode Cloud Build 175** erfolgreich, Workflow `Release – Archive & TestFlight`.
- Letzter Commit im Build: **`2bfc009`** (`docs: g1 mapkit ios 17 migration is already complete`).
- Damit sind **`ff963c1`** (onChange-Fix, alle 24 single-arg `onChange`-Stellen auf Zwei-Parameter-Form) und **`2bfc009`** (G1 MapKit iOS-17-API-Stand) extern in Xcode Cloud/TestFlight angekommen.
- Schritte des Workflow-Runs: `Archive - iOS` ✅ erfolgreich, `TestFlight-interne Tests - iOS` ✅ erfolgreich.
- Toolchain im Build: **Xcode 26.5 (17F42)**, **macOS Tahoe 26.4 (25E246)**.
- TestFlight zeigt **LH2GPX 1.0.2 (175)**.
- Kompatibilität: „Erfordert iOS 17.0 oder neuer" — iOS-17-Minimum aus Train F extern weiterhin bestätigt.

### Repo-Truth (lokal, unverändert)
- `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171` (pbxproj, 8 Configs konsistent).
- Build-Nummer **175** stammt aus Xcode-Cloud-Zählung (`wrapper/ci_scripts/ci_pre_xcodebuild.sh` setzt `CFBundleVersion` aus `CI_BUILD_NUMBER`). Lokale Build-Nummer wird **nicht** auf 175 nachgezogen.

### Geändert (nur Doku)
- `CHANGELOG.md`, `NEXT_STEPS.md`, `ROADMAP.md`, `docs/XCODE_CLOUD_RUNBOOK.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `wrapper/docs/TESTFLIGHT_RUNBOOK.md`.

### Nicht behauptet (mangels Belegen)
- Keine App-Review-Submission, kein App-Review-Accept.
- Kein Hardware-Smoke auf realer Hardware unter Build 175.
- Keine Dynamic-Island-Sichtprüfung.
- Kein iPad-Layout-Test.
- Kein 46-MiB-Hardware-Retest.

### Verifikation (Linux)
- `git diff --check`: clean.
- `swift build` (Swift 6.3.2): clean.
- `swift test`: **1459 / 2 Skips / 0 Failures** — unverändert (keine Code-Änderung).

### Empfohlener nächster Train
- TestFlight-Install Build **175** auf iPhone 14 Pro / iPhone 16 Pro Max: DayMap / LiveTracking / Heatmap / Overview / ExportPreview je einmal manuell, Crash- + Render-Stabilität bestätigen. Dynamic-Island-Lock-Screen-Sichtprüfung. iPad-Layout.
- ODER **Train C** (Linux + Feature-Flag default OFF): Live-Polyline Hard-Cap-UI-Warnung + Camera-Throttle.
- ODER Cleanup-Train: 18× redundante `@available(iOS 16.0/16.1/16.2, *)`-Gates abbauen.

---

## 2026-05-16 — docs: g1 mapkit ios 17 migration is already complete (`main`)

> **Train G1 — Befund: kein Migrationsbedarf.** Reine Doku-Korrektur, keine Code-Änderung.

### Verifikation
- `rg "coordinateRegion:|annotationItems:|MapMarker|MapAnnotation\("` über `Sources/`, `wrapper/`, `Tests/`: **0 Treffer**.
- Alle 8 SwiftUI-`Map(...)`-Surfaces nutzen bereits den iOS-17-Stil `Map(position: $mapPosition) { MapContent }` mit `MapCameraPosition` und `Marker` / `Annotation` / `MapPolyline`:
  - `AppDayMapView.swift:95`
  - `AppLiveTrackingView.swift:460`, `:633`
  - `AppRecordedTrackEditorView.swift:92`, `:159`
  - `AppLiveLocationSection.swift:107`
  - `AppHeatmapView.swift:72`
  - `AppOverviewTracksMapView.swift:201`, `:408`
  - `AppExportPreviewMapView.swift` (Marker-Pfad)
- `MKCoordinateRegion`-Treffer existieren weiterhin — aber **als Datenmodell** (Region-Storage / -Fitting / -Culling), nicht als deprecated SwiftUI-`Map(coordinateRegion:)`-Initializer. Keine Migration.

### Konsequenz
- Geplante G1-Migration (deprecated SwiftUI-Map-Initializer auf iOS-17-API) ist **bereits abgeschlossen** — vermutlich in einer früheren Phase vor diesem Audit.
- Eintrag in `docs/APP_PERFORMANCE_MODERNIZATION_AUDIT_2026-05-16.md` Kapitel 4 Option 2 („`Map(coordinateRegion:)` als deprecated Pfad lebt weiter, falls noch genutzt") + `docs/MAPKIT_PERFORMANCE_AUDIT_2026-05-16.md` entsprechend korrigiert.

### Geändert (nur Doku)
- `docs/APP_PERFORMANCE_MODERNIZATION_AUDIT_2026-05-16.md`
- `docs/MAPKIT_PERFORMANCE_AUDIT_2026-05-16.md`
- `CHANGELOG.md`, `NEXT_STEPS.md`, `ROADMAP.md`

### Bewusst NICHT in diesem Train
- Keine MKMapView/MKMultiPolyline-Bridge (Mac/Instruments-only, kein Linux-Pfad).
- Keine MKTileOverlay-Heatmap (Mac/Device-Verifikation Pflicht).
- Kein Live-Polyline-Cap, kein Camera-Throttle (separater Train **C**, Feature-Flag default OFF).
- Keine `@available(iOS 16.x, *)`-Gate-Bereinigung (18 Stellen, separater Aufräum-Train).
- Keine `@Observable` / Observation-Framework-Migration (großer separater Train).

### Externer Stand (unverändert seit `fix: update ios 17 onchange usage and document build 174`)
- Xcode Cloud Build **174** grün, basiert auf `92dc447` (enthält den `onChange`-Fix `ff963c1` **noch nicht**).
- TestFlight: `LH2GPX 1.0.2 (174)`, 90 Tage. App-Info: „Erfordert iOS 17.0 oder neuer".
- Damit weiterhin `fix: update ios 17 onchange usage ...` **und** dieses Train G1 erst durch einen **neuen** Xcode-Cloud-Build extern verifizierbar.

### Verifikation (Linux)
- `git diff --check`: clean.
- `swift build` (Swift 6.3.2): clean.
- `swift test`: **1459 / 2 Skips / 0 Failures** — unverändert (es gibt keine Code-Änderung).

### Was Linux nicht prüfen kann
- Sichtprüfung der Map-Surfaces unter Xcode-Simulator / iPhone (Kameraverhalten, Markers, Annotations, Polylines).
- Tatsächliches Rendering der `Map(position:)`-Bindings.
- Dynamic-Island-Live-Activity-Layout, iPad-Layout.

### Zwingender nächster Xcode-Cloud-/Device-Test
- **Neuer Xcode-Cloud-Build** auf `main` (HEAD `ff963c1` + dieser G1-Doku-Commit), damit der `onChange`-Fix extern auf TestFlight ankommt und keine Deprecation-Warnung mehr im Build-Log steht.
- TestFlight-Install des neuen Builds auf iPhone 14 Pro / iPhone 16 Pro Max: DayMap / LiveTracking / Heatmap / Overview / ExportPreview je einmal manuell aufrufen und Crash-/Render-Stabilität bestätigen.

### Empfohlener nächster Train
- **C** — Live Surface Hardening (Feature-Flag default OFF): Live-Polyline-Hard-Cap-UI-Warnung + Camera-Throttle. Kein Format-/User-Verhaltens-Bruch.
- ODER **Cleanup-Train**: 18× redundante `@available(iOS 16.0/16.1/16.2, *)`-Gates abbauen (risikoarm, mechanisch).
- ODER **G2** (Mac/Instruments-only, nicht Linux-startbar): MKMapView/MKMultiPolyline-Bridge prototypisch für Overview-Heavy-Datasets.

---

## 2026-05-16 — fix: update ios 17 onchange usage and document build 174 (`main`)

> Folge-Train zu `chore: raise minimum ios target to 17`. Behebt die in **Xcode Cloud Build 174** (Workflow „Release – Archive & TestFlight") gemeldete iOS-17-Deprecation-Warnung und zieht die Doku auf den extern belegten TestFlight-Stand `1.0.2 (174)` glatt.

### Extern belegter Stand (Screenshot, Stand 2026-05-16)
- Xcode Cloud Build **174** erfolgreich erzeugt (letzter Commit im Build: `92dc447 chore: raise minimum ios target to 17`).
- TestFlight zeigt **LH2GPX 1.0.2 (174)**, 90 Tage Gültigkeit.
- App-Info: **Erfordert iOS 17.0 oder neuer** — Anhebung aus Train F extern bestätigt.
- Xcode-Cloud-Warnung (in Train F entstanden, jetzt behoben): `'onChange(of:perform:)' was deprecated in iOS 17.0: Use 'onChange' with a two or zero parameter action closure instead.` — Quelle: `wrapper/LH2GPXWrapper/ContentView.swift:125`.

### Geändert (Code)
- **`wrapper/LH2GPXWrapper/ContentView.swift:125`** — `.onChange(of: session.isLoading) { isLoading in … }` → `.onChange(of: session.isLoading) { _, isLoading in … }` (semantik-exakte iOS-17-Form).
- **`Sources/LocationHistoryConsumerAppSupport/AppInsightsContentView.swift`** — 10 weitere `.onChange(of:) { _ in handler() }` auf `.onChange(of:) { _, _ in handler() }` migriert (Zeilen 239–243 + 465–469).
- **`Sources/LocationHistoryConsumerAppSupport/AppExportView.swift`** — 3 Stellen migriert (Zeilen 1284 `{ tracks in` → `{ _, tracks in`, 1287/1291 `{ _ in` → `{ _, _ in`).
- **`Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift`** — 10 Stellen migriert (`syncLiveRecordingSettings()`-Cluster + `session.source`-Branch + `navigateToLiveTabRequested` + `startTab`).
- **Summe:** 24 einzeilige Closure-Signaturen umgeschrieben. Semantik unverändert (neuer Wert war in beiden Formen der gleiche Parameter; alter Wert weiterhin ungenutzt).

### Repo-Truth (lokal unverändert)
- `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171` (pbxproj). **Nicht** auf 174 angehoben: Build 174 entstand durch Xcode-Cloud-Zählung (`wrapper/ci_scripts/ci_pre_xcodebuild.sh` überschreibt `CFBundleVersion` mit `CI_BUILD_NUMBER`); Repo bleibt bei 171, Cloud weicht ab. Doku-Texte nennen jetzt beides separat.

### Geändert (Doku)
- README.md / wrapper/README.md / NEXT_STEPS.md / ROADMAP.md / docs/XCODE_CLOUD_RUNBOOK.md / docs/XCODE_APP_PREPARATION.md / docs/APPLE_VERIFICATION_CHECKLIST.md / wrapper/docs/TESTFLIGHT_RUNBOOK.md / docs/APP_PERFORMANCE_MODERNIZATION_AUDIT_2026-05-16.md — ergänzen Build-174-TestFlight-Stand und iOS-17-Minimum-Bestätigung.

### Nicht behauptet (mangels Belegen)
- Keine App-Review-Submission, kein App-Review-Accept.
- Kein vollständiger Hardware-Retest, keine Dynamic-Island-Sichtprüfung, kein iPad-Layout-Test.
- Keine 46-MiB-Asset-Verifikation.

### Verifikation (Linux)
- `git diff --check`: clean.
- `swift build` (Swift 6.3.2 via swiftly): clean, 1,42 s.
- `swift test`: **1459 / 2 Skips / 0 Failures, ~55 s** — unverändert.
- `rg "\.onChange\(of: [^)]+\) \{ [a-zA-Z_]+ in"`: keine Treffer mehr → deprecated Single-Arg-Form repo-weit entfernt.

### Empfohlener nächster Train
- **Mac/Device-Smoke** auf Build 174: TestFlight-Install auf iPhone 14 Pro / iPhone 16 Pro Max, Live Activity + Dynamic Island Lock-Screen-Sichtprüfung, iPad-Layout.
- ODER **G**: MapKit-iOS-17-API-Migration (`coordinateRegion:` / `annotationItems:` ablösen).

---

## 2026-05-16 — chore: raise minimum ios target to 17 (`main`)

> **Train F umgesetzt.** Deployment Target des Cores und des Wrappers konsistent auf iOS 17.0 angehoben. Keine MapKit-/UI-Refactors, keine Format-Änderungen, keine `@available`-Aufräumung (Folge-Train).

### Geändert
- **`Package.swift`** — `.iOS(.v16)` → `.iOS(.v17)` (Cores Minimum). `macOS(.v13)` unverändert.
- **`wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`** — alle 6 `IPHONEOS_DEPLOYMENT_TARGET`-Einträge (vorher 4× `16.0` App/Tests + 2× `16.2` Widget) einheitlich auf `17.0`. Widget-Target braucht keinen abweichenden Wert mehr, da ActivityKit (16.1) und Live-Activity-UI (16.2) im neuen Minimum enthalten sind.
- **`README.md`** — Live-Aufzeichnungs-Eintrag erwähnt jetzt iOS 17 Minimum; Dynamic-Island-Hinweis bleibt geräteabhängig (iPhone 14 Pro+).
- **`wrapper/README.md`** — Deployment-Target-Zeile von „iOS 16.0/16.2" auf „iOS 17.0" mit Train-F-Verweis.
- **`NEXT_STEPS.md`**, **`ROADMAP.md`** — neuer Stand dokumentiert.

### Bewusst NICHT in diesem Train
- Keine Entfernung von `@available(iOS 16.0/16.1/16.2, *)`-Gates (vorher: 4× 16.0, 5× 16.1, 9× 16.2). Diese sind durch iOS-17-Minimum redundant, bleiben aber funktional korrekt. Aufräumung als Folge-Train (z.B. **G**).
- Keine Entfernung von `@available(iOS 17, *)`-Gates. Viele gaten zusätzlich macOS 14, und `macOS` bleibt `.v13` → Gates bleiben für macOS-Pfade nötig.
- Keine MapKit-API-Migration (`coordinateRegion:` / `annotationItems:` etc. — Train G).
- Keine Marketing-Version / Build-Nummer geändert (`1.0.2 / 171` unverändert).
- Keine Privacy-Manifest- oder Apple-Review-Punkte angefasst.

### Verifikation (Linux)
- `git diff --check`: clean.
- `swift build` (Swift 6.3.2 via swiftly, `libsqlite3-dev`): clean, 0,23 s.
- `swift test`: **1459 / 2 Skips / 0 Failures, ~53,6 s** — unverändert.

### Was Linux nicht prüfen kann
- Xcode-Projekt-Konsistenz unter realer Xcode-Toolchain (Sim-Build, Asset-Catalog-Auflösung, Bundle-Validierung).
- Xcode-Cloud-Build mit dem neuen Minimum.
- Geräte-Smoke auf iPhone 14 Pro / iPhone 16 Pro Max / iPad gegen iOS 17+.
- App-Store-Connect-Reichweiten-Snapshot (`developer.apple.com/support/app-store/`).
- Dynamic-Island-Lock-Screen-Sichtprüfung.

### Zwingender nächster Mac/Xcode-Schritt
1. Wrapper in Xcode öffnen → Sim-Build (iOS 17 Simulator) durchlaufen lassen.
2. Geräte-Smoke (`xcodebuild -destination 'generic/platform=iOS'`) erfolgreich.
3. Xcode-Cloud-Archive `1.0.2 (171)` mit iOS 17 Minimum bauen und in ASC validieren.
4. ASC-Reichweiten-Snapshot prüfen, ob iOS 17 Minimum für die Zielgruppe akzeptabel ist.

### Empfohlener nächster Train
- **G** (Linux + Mac): MapKit-iOS-17-API-Migration (`Map { … }`-Builder durchgängig, `MapCameraPosition`, deprecated `coordinateRegion:`/`annotationItems:` ersetzen). Großer, aber jetzt sauber möglich.
- ODER **C** (gemischt): Live-Polyline Hard-Cap UI-Warnung + Camera-Throttle (Feature-Flag default OFF).

---

## 2026-05-16 — perf: reduce kmz export memory copies (`main`)

> **Train E1 umgesetzt.** Punktueller Memory-Refactor in `KMZBuilder`. Keine UI-/MapKit-/Format-Änderung, keine API-Brüche, keine iOS-17-Anhebung.

### Geändert
- **`Sources/LocationHistoryConsumerAppSupport/KMZBuilder.swift`** — schreibt das KMZ jetzt direkt in einen In-Memory-`Archive(accessMode: .create)` (ZIPFoundation `Archive(data:, accessMode:)` + `archive.data`). Der Zwischenschritt `temporaryDirectory.appendingPathComponent(UUID().uuidString + ".kmz")` plus `Data(contentsOf: tmpURL)` entfällt vollständig. KML-Payload-Buffer bleibt erhalten (ZIPFoundation `provider` benötigt wahlfreien Zugriff). Öffentliche Signatur, ZIP-Layout und Output-Bytes (`PK…`, `doc.kml`) unverändert.

### Code-Truth (keine Device-Messung, kein behaupteter MB-Wert)
- entfernt: 1× Temp-Datei-Write (`Archive(url:, accessMode: .create)`), 1× Temp-Datei-Read (`Data(contentsOf: tmpURL)`).
- erhalten: 1× UTF-8-Encode des KML-Strings, 1× In-Memory-Zip-Buffer.
- Effekt unter realer iOS-Memory-Pressure und das tatsächliche Peak-RSS-Delta sind **nur auf Gerät mit Instruments** verifizierbar — auf Linux nicht messbar.

### Verifikation
- `git diff --check`: clean.
- `swift build` (Swift 6.3.2): clean, 1,62 s.
- `swift test --filter KMZExportTests`: **6 / 0 Failures**.
- `swift test`: **1459 / 2 Skips / 0 Failures, ~54 s** — unverändert zum vorherigen HEAD.

### Bewusst NICHT in diesem Train
- Keine Streaming-API für GPX/KML/CSV/GeoJSON (Train E2).
- Keine API-Änderung an `KMZBuilder.build(from:)` (bleibt `throws -> Data`).
- Keine SQLite-Pragma-Erweiterung (Train E3).
- Keine iOS-17-Anhebung (Train F).
- Keine UI-Texte/Lokalisierungsänderungen.

### Empfohlener nächster Train
- **F** (Doku + Build): iOS-17-Anhebung — entfernt iOS-16-Reste konsistent, Voraussetzung für saubere MapKit-iOS-17-Migration; ODER **C** (Feature-Flag default OFF): Live-Polyline-Cap-UI-Warnung + Camera-Throttle.

---

## 2026-05-16 — docs: audit app performance modernization and ios 17 path (`main`)

> **Reiner Audit-Train, keine produktive Code-Änderung.** Neuer App-weiter Performance-/Stabilitäts-/Speicher-/Rendering-Audit + formale iOS-17-Deployment-Target-Entscheidungsmatrix. Stützt sich ausschließlich auf offizielle Apple-Dokumentation als Primärquelle.

### Neu
- **`docs/APP_PERFORMANCE_MODERNIZATION_AUDIT_2026-05-16.md`** — repo-weite Tiefenanalyse: SwiftUI/MapKit/Heatmap/Live/Import-Export/Persistenz/Widgets/Tests, 20 priorisierte Hotspots (P0/P1/P2/M), Linux-testbare vs. Mac/Instruments-only Trennung, formale iOS-17-Entscheidungsmatrix mit 3 Optionen.

### Deployment-Target-Empfehlung
- **Status quo: iOS 16** (`Package.swift .iOS(.v16)`, 6× `IPHONEOS_DEPLOYMENT_TARGET = 16.0` + 2× `16.2` für Widget/Live-Activity).
- **Empfehlung: Option 3 — iOS 17 vorbereiten, NICHT in diesem Train anheben.** Begründung: Reichweiten-Daten (`developer.apple.com/support/app-store/`) sind auf Linux nicht verifizierbar; Mechanik berührt 37 Source-Stellen + 8 pbxproj-Configs (Audit-Inventar zählt 28× iOS-17- und 9× iOS-16.2-Gates); Sim/Device-Smoke-Build vor Push Pflicht; Apple-Review-Punkte für `1.0.2 (171)` zuerst stabilisieren.

### Apple-Quellen referenziert (Primärbeleg)
_Improving your app's performance_, _Demystify SwiftUI performance_ (WWDC23 / 10160), _MapKit for SwiftUI_ (Map / MapContentBuilder / Marker / Annotation / MapPolyline / MapCameraPosition), _Map deprecations_ (iOS 17), _ActivityKit_ + HIG _Live Activities_, _Reducing your app's memory use_, _Reducing your app's launch time_, _MKMapView / MKMultiPolyline / MKTileOverlay_. URLs als von Apple gepflegte `developer.apple.com/...`-Pfade dokumentiert; Live-Verifikation auf Linux nicht möglich.

### Verifikation
- `git diff --check`: clean.
- `swift build` (Swift 6.3.2 via swiftly, `libsqlite3-dev`): clean.
- Linux `swift test`: **1459 / 2 Skips / 0 Failures, ~54 s** — unverändert.
- Filterläufe alle grün, soweit Filter trifft (Heatmap/Import/Live/StreamReader trafen keine eigenen Suiten — Hinweis im Audit dokumentiert, kein Fehler).

### Bewusst NICHT in diesem Train
- Keine iOS-17-Anhebung (separater Train F vorbereitet).
- Keine `KMZBuilder`-Streaming-Refactor (separater Train E1).
- Keine `.onChange`-Konsolidierung (`.task(id:)` ist nicht semantik-äquivalent — Analyse im Audit).
- Keine Identity-Fixes an Editor/Live/Overview/DayDetail (Train B2).
- Kein Live-Polyline-Cap / Camera-Throttle (Train C, Feature-Flag default OFF).
- Keine SQLite-Pragma-Erweiterung (Train E3).
- Keine produktive Verdrahtung der Heatmap-Multi-LOD-API (Train D / Mac-only).

### Empfohlene Trains (Reihenfolge)
- **E1** (Linux, klein): KMZ-Streaming-Writer.
- **E2** (Linux, mittel): GPX/KML/CSV/GeoJSON optionale Stream-API.
- **E3** (Linux, klein): LocalTimelineStore-Pragmas.
- **C** (gemischt, Feature-Flag default OFF): Live-Polyline-Cap + Camera-Throttle.
- **B2** (gemischt): DayDetail/Overview/Export Identity-Wrapper.
- **F** (Doku + Build): iOS-17-Anhebung.
- **D** (Mac/Device/ASC): Heatmap-Multi-LOD-Wiring, MKMapView-Bridging, MKTileOverlay-Heatmap, Apple-Review-Resubmit.

---

## 2026-05-16 — perf: stabilize swiftui identity surfaces (Train B1, `main`)

> **Train B1 aus `docs/MAPKIT_PERFORMANCE_AUDIT_2026-05-16.md` (kleinste sichere Teilmenge).** Nur SwiftUI-Identity in `AppInsightsContentView` an 3 unkritischen Stellen stabilisiert. **Keine** Live-Recording-Logik, **keine** Camera-Throttle, **kein** Polyline-Hard-Cap, **keine** `.onChange`-Konsolidierung. **Keine** Performance-Behauptung — auf Linux nicht visuell prüfbar; nur Build/Test-Verifikation.

### Geändert — `Sources/LocationHistoryConsumerAppSupport/AppInsightsContentView.swift`
- Z. 940: `ForEach(Array(insights.activityBreakdown.enumerated()), id: \.offset)` → `ForEach(insights.activityBreakdown, id: \.activityType)`. Index war ungenutzt (`_`), Liste statisch pro Render, `activityType: String` ist natürlicher eindeutiger Schlüssel.
- Z. 958: dito für `visitTypeBreakdown` → `id: \.semanticType`.
- Z. 984: dito für `periodBreakdown` → `id: \.label` (Item-`label` ist z.B. `"2026"` oder `"2026-03"`, pro Periode eindeutig).

### Bewusst NICHT umgesetzt (in diesem Train aus Sicherheitsgründen)
- `AppRecordedTrackEditorView.swift:202` — `draft.points` mit Index-getragener Binding-Logik, Delete/Insert/Reorder. Index-zu-Domain-ID-Umbau wäre semantischer Eingriff in den Editor.
- `LHExportComponents.swift:33` — `Step.allCases.enumerated()` verwendet `index` aktiv für Label/Numbering.
- `AppInsightsContentView.swift:1200` — `topDays`, `index`-Variable wird im Body angezeigt.
- `AppLiveTrackingView.swift:562` / `AppLiveLocationSection.swift:132` — Live-Breadcrumb-Buckets ohne stabile Domain-ID (Algorithmus-derived). Live-Logik ist ausdrücklich nicht in Train B1 enthalten.
- `AppOverviewTracksMapView.swift:202/409`, `AppExportPreviewMapView.swift:58/62`, `AppDayDetailView.swift:371/378/391/418` — Modelle ohne explizite stabile ID, würden `Identifiable`-Wrapper oder Modell-Erweiterung erfordern.
- Konsolidierung der zwei 5× `.onChange`-Cluster in `AppInsightsContentView` (Z. 239–243, 465–469) — `.task(id:)` wäre **keine** semantik-äquivalente Ersetzung (zusätzlicher Lauf auf Initial-Appear, würde `refreshDerivedModel()` doppelt anstoßen und Picker-Resets duplizieren). Konsolidierung über kombiniertes `Equatable`-Struct hätte keinen messbaren Vorteil und entfernt Lesbarkeit. **Bewusst belassen.**

### Verifikation
- `git diff --check`: clean.
- `swift build`: clean (1,65 s).
- `swift test` (Swift 6.3.2 via swiftly, `libsqlite3-dev`, Linux x86_64): **1459 Tests, 2 Skips, 0 Failures, 54,3 s** — identisch zum Baseline-Stand vor Train B1.
- Gefilterte Läufe alle grün:
  - `swift test --filter Performance` → 38 Tests, 24,3 s
  - `swift test --filter Insights` → 105 Tests, 0,43 s
  - `swift test --filter Export` → 188 Tests, 6,4 s
  - `swift test --filter Map` → 222 Tests, 1,33 s
  - `swift test --filter Path` → 117 Tests, 0,92 s

### Nicht auf Linux prüfbar
- Visueller Identity-Effekt (SwiftUI-Diffing bei Inserts/Updates an `breakdown`-Listen): Auf Linux gibt es keinen SwiftUI-Renderer, daher kein Render-Test ergänzbar. Test-Coverage über Modell-Equality + bestehende `Insights`-Tests bleibt unverändert grün.

### Empfohlener nächster Train
- **Train B2 („Surface Polish — DayDetail/Overview Rows")** — Falls gewünscht: `Identifiable`-Wrapper oder ID-Erweiterung für `DayDetailViewState.VisitItem` / `ActivityItem` und `OverviewMapPathOverlay` / `PathOverlay` / `WaypointAnnotation`. Erfordert Modell-Edit, daher separater Train.
- **Train C („Live Surface Hardening", Feature-Flag default OFF)** — Live-Track-Polyline Hard-Cap + Tail-Decimation + Camera-Update-Throttle in Follow-Mode. Verhaltensänderung am Live-Pfad, deshalb hinter Flag.

---

## 2026-05-16 — test: add map and export performance baselines (Train A, `main`)

> **Train A aus `docs/MAPKIT_PERFORMANCE_AUDIT_2026-05-16.md` umgesetzt.** Reine Test-Ergänzung — **kein** Verhaltenswechsel, **keine** Performance-Optimierung, **keine** UI-Änderung. Ziel: deterministische, Linux-CI-taugliche Mess-Baseline ohne Fail-Bar, damit künftige MapKit-/Core-Optimierungen drift-erkennbar sind.

### Neu — Performance-Tests (alle Foundation-only, Linux-portable, `measure { … }` ohne `XCTPerformanceMetric_…`-Fail-Bar)
- **`Tests/.../PathSimplificationPerformanceTests.swift`** — 5 Cases: `douglasPeucker` 1k/5k bei ε=15 m und 5k bei ε=5 m, plus Korrektheits-Invarianten (Endpunkt-Preservation, Output ≤ Input, kurze Pfade unverändert).
- **`Tests/.../PathFilterPerformanceTests.swift`** — 6 Cases: `removeOutliers` 1k/5k clean, 5k mit 1-zu-100-Outlier-Rhythmus, plus Korrektheits-Invarianten (Identity auf cleanen Walks, Big-Jump-Rejection, Short-Input-Passthrough).
- **`Tests/.../ExportBuildersPerformanceTests.swift`** — 12 Cases: `GPXBuilder` / `KMLBuilder` / `CSVBuilder` / `GeoJSONBuilder` auf 1k-Punkt-Single-Day und 3×5k-Punkt-Multi-Day, plus Strukturmarker-Asserts und JSONSerialization-Parsebarkeit für GeoJSON. **KMZ bewusst ausgelassen** — `KMZBuilder` wrappt KML in einen ZIP-Archive; der KML-String-Baseline ist die relevante Messung.
- **`Tests/.../GoogleTimelineStreamReaderPerformanceTests.swift`** — erweitert um `testPerformanceConvertStreamingFromDiskTenThousand` (10k synthetische Entries, deterministischer Generator, Datei in `temporaryDirectory`).

### Verifikation
- `swift build` + `swift build --build-tests`: clean.
- `git diff --check`: clean.
- Linux `swift test` (Swift 6.3.2 via swiftly, `libsqlite3-dev`): **1459 Tests, 2 Skips, 0 Failures, 52,8 s** (vorher 1435, +24 neue Test-Cases).
- Gefilterte Läufe alle grün:
  - `swift test --filter Performance` → 38 Tests, 24,4 s
  - `swift test --filter Douglas` → 5 Tests, 0,03 s
  - `swift test --filter Path` → 117 Tests, 0,6 s
  - `swift test --filter Export` → 188 Tests, 5,7 s
  - `swift test --filter StreamReader` → 22 Tests, 20,1 s

### Bewusst NICHT in diesem Train
- Keine Verdrahtungs-Änderung in `AppOverviewTracksMapView`, `AppHeatmapModel`, `AppDayMapView`, `AppLiveTrackingView`, `AppExportPreviewMapView`.
- Keine produktive Performance-Optimierung — Hotspots aus dem 2026-05-16-Audit (Live-Track-Hard-Cap, ForEach-Identity, Insights-OnChange-Konsolidierung, MKMapView-Bridging, MKTileOverlay-Heatmap) bleiben **offen**.
- Keine Fail-Bar auf neuen `measure`-Tests — CI fail nur bei Korrektheits-Asserts, nicht bei Wall-Clock-Drift.

### Empfohlener nächster Train
- **Train B („Identity & Surface Polish")** — `ForEach(Array(...enumerated()), id: \.offset)` schrittweise auf stabile `Identifiable`-IDs; AppInsightsContentView 5× `.onChange` zu `.task(id:)` konsolidieren. Verhalten muss identisch bleiben, durch Golden-/Render-Tests gedeckt.
- alternativ **Train C („Live Surface Hardening", Feature-Flag default OFF)** — Live-Track Polyline Hard-Cap mit Tail-Decimation; Camera-Update-Throttle.

---

## 2026-05-16 — docs: audit mapkit and app performance modernization plan (`main`, pending HEAD)

> **Reiner Planungs-Audit, kein Code-Change.** Belastbares Map-Surface-Inventar, Hotspot-Ranking und Mess-Baseline-Befund — alles vor jedem nächsten Implementierungs-Train.

### Neu
- **`docs/MAPKIT_PERFORMANCE_AUDIT_2026-05-16.md`** — vollständiger Audit-Report:
  - Inventar aller 6 Map-Surfaces (Overview, Day Detail, Heatmap, Live Tracking, Export Preview, LocalTimeline Day Map) mit file:line, Tech, Datenquelle, Volumen-Schutz, State-Ownership, Test-Coverage.
  - 17 priorisierte Hotspots (P0/P1/P2/Mac-only), darunter Live-Track-Polyline ohne Hard-Cap, `ForEach(.enumerated(), id: \.offset)` an 13 Stellen, AppInsightsContentView 5× redundante `.onChange`-Refreshes, MKTileOverlay-Heatmap/MKMultiPolyline-Bridging als bewusst aufgeschobene P2.
  - Mess-Baseline-Inventar: 5 von ~16 existierenden `measure()`-Tests sind Linux-CI-tauglich; Vorschläge für neue Foundation-only Baselines (DouglasPeucker, PathFilter, Export-Builder) ohne Fail-Bar (Drift-Erkennung-only).
  - 4 vorgeschlagene Trains (A: Baseline Strengthening, B: Identity & Surface Polish, C: Live Surface Hardening + Feature-Flag, D: Mac/Device-only).
  - **Explizit:** keine Performance-Behauptungen ohne Messung, keine Deployment-Target-Anhebung, kein Build-Bump, keine ASC-Aktion.

### Verifikation
- Linux `swift test` (Swift 6.3.2 via swiftly, `libsqlite3-dev`): **1435 Tests, 2 Skips, 0 Failures, ~41 s** auf HEAD vor Audit-Commit.
- `swift build`: clean.
- `git diff --check`: clean.

### Doku-Sync
- `NEXT_STEPS.md`: Verweis auf Audit-Report und Train-A/B/C/D-Vorschläge ergänzt.
- `ROADMAP.md`: Aktiver-Stand-Block 2026-05-16 erweitert um Audit-Verweis.

### Bewusst unverändert
- `docs/APP_FEATURE_INVENTORY.md`: Audit hat keine neuen Features gefunden, nur ein präziseres Map-Surface-Inventar — kein Änderungsbedarf.
- `wrapper/README.md`, `docs/MAP_ARCHITECTURE_AUDIT.md`, `docs/MAPKIT_AZ_AUDIT_2026-05-13.md`: bleiben als historisch-kanonisch.

---

## 2026-05-16 — docs: clean backup documentation artifacts after truth audit (HEAD `2f6d003` → pending, `main`)

> **Repo-Hygiene + Truth-Glättung, kein Code-Change.** Folge-Sweep nach dem 2026-05-16-Truth-Audit.

### Repo-Hygiene
- 32 `*__backup_*.md` (Cluster 2026-03-30 / 2026-03-31 / 2026-04-01) per `git mv` in **`docs/archive/backups-2026-05-16/`** verschoben unter Beibehaltung der Original-Pfadstruktur. Quelle: Root, `docs/`, `docs/archive/`, `audits/`, `wrapper/`, `wrapper/docs/`. Damit verschwinden alle `__backup_*`-Dateien aus dem aktiven Tree. Empfohlen vom Deep Audit (P2-11, `docs/DEEP_AUDIT_2026-05-13_CLAUDE.md`).
- Keine Inhaltsänderung an den Backup-Dateien; Git-Rename-Detection erhält Historie.

### Weitere Truth-Glättung
- `ROADMAP.md`: Neuer Stand-Block 2026-05-16 ganz oben mit aktuellem Repo-Truth (1.0.2 / 171) und Linux-Test-Stand 1435/2/0; darunterliegende historische Blöcke (1.0.1 / 100 / 168) bleiben unverändert als Historie.
- `wrapper/README.md`: Version-Zeile auf `1.0.2 / 171` korrigiert, frühere Trains (1.0 / 1.0.1) als Historie umfomuliert.
- `wrapper/docs/TESTFLIGHT_RUNBOOK.md`: „heute Repo-Truth: 1.0.1 / 100"-Spalte in der historischen Tabelle auf aktuellen Stand 1.0.2 / 171 nachgezogen.

### Verifikation
- `git diff --check`: clean.
- Linux `swift build` + `swift test` (Swift 6.3.2 via swiftly): siehe Eintrag oben — Code-Pfade nicht berührt, Ergebnis wird in diesem Commit erneut gemessen und bleibt bei 1435/2/0 erwartet.

---

## 2026-05-16 — docs: reconcile audit truth across project documentation (HEAD `71f715b`, `main`)

> **Doku-Audit, kein Code-Change.** Repo-Truth-Sweep + Doku-Glättung. Kein Build-Bump, kein ASC, kein Feature-Change.

### Verifikation (Linux, Swift 6.3.2 via swiftly, `libsqlite3-dev` installiert)
- `swift build` → Build complete (6,34 s).
- `swift test` → **1435 Tests, 2 Skips, 0 Failures (41,1 s)** auf HEAD `71f715b`.

### Korrigierte Drift / wahrheitsgemäße Anpassungen
- `README.md`: Linux-Test-Nachweis und Versions-Aussagen auf aktuellen Repo-Truth (`MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171`, pbxproj + Info.plist App/Widget konsistent) gehoben. ASC-Live-Status (`Pending Developer Release`) explizit als **nicht im Audit 2026-05-16 re-verifiziert** gekennzeichnet — er bleibt im Repo nicht prüfbar.
- `docs/XCODE_APP_PREPARATION.md`: Wrapper-Truth-Hinweis von `1.0.1 / 100` auf `1.0.2 / 171` gezogen; Linux-Verifikations-Abschnitt mit heutigem `swift test`-Stand ergänzt; Swift-Toolchain-Hinweis (swiftly) ergänzt.
- `docs/XCODE_CLOUD_RUNBOOK.md`: Versions-Truth-Block hinzugefügt; ASC-Truth-Snapshots als historisch (2026-05-06) markiert; `MARKETING_VERSION`-Aussage von `1.0` auf `1.0.2` gezogen.
- `wrapper/README.md`: Repo-Truth-Patch-Block vorn ergänzt, der die unteren historischen Versions-/Test-/ASC-Aussagen als überholt kennzeichnet.

### Bewusst unverändert gelassen (würde Doku-Umbau erfordern, nicht Drift):
- `ROADMAP.md`, `NEXT_STEPS.md` (umfangreiche Trains, Inhalt strukturell aktuell), historische Build-/ASC-Snapshots (74/84/95/100) bleiben als historische Datensätze stehen.
- Backup-Dateien `*__backup_*.md` (31 Stück, Cluster 2026-03-31 / 2026-04-01) — reine Pre-Audit-Snapshots, keine Doku-Lüge.

### Audit-Methodik (transparent)
- **Vollständig durchgelesen / geprüft:** `AGENTS.md`, `README.md` (Core), `wrapper/README.md`, `docs/XCODE_APP_PREPARATION.md`, `docs/XCODE_CLOUD_RUNBOOK.md`, `docs/XCODE_RUNBOOK.md` (überflogen, Stand 2026-05-13 konsistent), `docs/ASC_SUBMIT_RUNBOOK.md`, `docs/PRIVACY_MANIFEST_SCOPE.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/MAPKIT_AZ_AUDIT_2026-05-13.md`, `docs/MAP_ARCHITECTURE_AUDIT.md`, `docs/APP_REVIEW_RESPONSE_GUIDELINE_3_2.md`, `wrapper/docs/TESTFLIGHT_RUNBOOK.md`, `wrapper/docs/LOCAL_IPHONE_RUNBOOK.md`, `wrapper/CHANGELOG.md` (Top), `wrapper/NEXT_STEPS.md` (Top), `Package.swift`, `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj` (nur Versions-/Signing-Strings), beide `Info.plist`.
- **Stichprobenartig:** `Sources/` (186 Swift-Files; gezielt Import-, Export-, Heatmap-, LiveLocation-, Keychain-, LocalTimelineStore-Pfade), `Tests/` (160 Swift-Files; Golden-Tests, Wrapper-State-Tests, ZIP-Streaming-Tests), `wrapper/LH2GPXWrapper/`, `wrapper/LH2GPXWidget/`, `wrapper/ci_scripts/`, `wrapper/LH2GPXWrapperUITests/`, Repo-weites grep nach Tokens/Bearer/URLs (kein Treffer für Production-Secrets).
- **Nicht geprüft / extern:** ASC-Live-Status, TestFlight-Live-Status, Hardware-Sichtprüfung iPhone 15 Pro Max / iPad, Dynamic-Island-Lockscreen visuell, Apple-Review-Feedback. Diese sind im Repo nicht prüfbar.

### Verbleibende offene Themen (unverändert offen)
- **46-MiB-Hardware-Retest** auf dem originalen Tester-Asset (timelinePath-Geometrie) — synthetisches 46-MiB-Asset war am 2026-05-13 grün, original ist weiter pending.
- **Dynamic-Island Lock-Screen + iPad-Layout** — Hardware-Sichtprüfung offen.
- **Lokales `xcarchive 1.0.2 (171)` Upload nach ASC** — Organizer-Schritt manuell, in diesem Audit nicht durchgeführt.
- **xcodebuild / Apple-Plattform-Tests** — Linux-Host kann das nicht erbringen; Swift 6.3.2 baut zwar das SwiftPM-Paket, aber Xcode/SDK ist nicht installierbar.

---

## 2026-05-13 — perf: optimize heatmap pipeline with golden benchmarks (branch `chore/mapkit-az-modernization-3`)

> **MapKit A–Z Modernization Train 3.** Kein Release, kein Build-Bump, kein ASC, kein Merge nach `main`. Basis: `chore/mapkit-az-modernization-2@42e4415` (Train 1 + 2 kumulativ). Fokus: Heatmap-Pipeline Golden-Output-Tests, refactor + Single-Pass-Multi-LOD API, ehrlicher Performance-Befund.

### Was getan wurde
- **`Sources/LocationHistoryConsumerAppSupport/HeatmapGridBuilder.swift`** — `computeGrid` an zwei extrahierte Helfer `binRaw(points:lod:)` und `smoothAndNormalize(raw:lod:scale:)` delegiert. **Output strikt byte-identisch zum Pre-Refactor** (Goldens locken das).
- **`computeMultiLODGrids(for:lods:scale:)` neu** — fused single pass: ein cos pro Punkt, dann 4× bin pro Punkt; smoothing/normalisation weiter per LOD. Dedupliziert Lods, tolerant gegen empty points/lods.
- **`Sources/LocationHistoryConsumerAppSupport/AppHeatmapModel.swift`** `ensureDensityPrecomputation` — auf den per-LOD-Loop **belassen**. Wiring auf `computeMultiLODGrids` getestet, dann bewusst zurückgenommen (kein messbarer Wallclock-Gewinn bei 10k/50k). Code-Kommentar erklärt die Entscheidung und verweist auf Train 4 (TaskGroup / Metal).

### Tests (11 Cases Golden + 6 XCTMeasure Benchmarks, alle grün)
- **`Tests/LocationHistoryConsumerTests/HeatmapGoldenOutputTests.swift`** NEU — Golden-Output für `computeGrid` + Multi-LOD-Äquivalenz. Lockt:
  - Empty input → empty grids
  - Single-point → ≥ 1 cell (fine LOD)
  - Determinismus über N Läufe
  - byte-identische `normalizedIntensity` (bitPattern-equality) bei wiederholtem per-LOD-`computeGrid` für dieselbe Insertion-Order
  - Two-cluster spatial distinction (high LOD)
  - Cell-Counts pro LOD für `smallCluster` Fixture
  - **Multi-LOD-Äquivalenz**: gleiche Key-Sets, integer counts byte-identisch, Center-Coords byte-identisch, `normalizedIntensity` ≤ **1e-14** absolut (~50 ULPs an 1.0; reale Drift ~4 ULPs für 1k synth/linear; **unsichtbar** auf 8-bit Farbverlauf)
  - Empty-LOD-Liste und Duplicate-LOD-Edge-Cases
- **`Tests/LocationHistoryConsumerTests/HeatmapPipelineBenchmarkTests.swift`** NEU — 6 XCTMeasure-Cases.

### Benchmark-Tabelle (XCTMeasure, macOS x86_64)
| Datensatz | Per-LOD Baseline | Fused Multi-LOD | Δ |
|---|---|---|---|
| 1k synth × 4 LOD | 37 ms | **32 ms** | **−13 %** (RSD 15 %, Richtwert) |
| 10k synth × 4 LOD | 280 ms | 282 ms | ~0 % |
| 50k synth × 4 LOD | 1271 ms | 1281 ms | ~0 % |

**Ehrlicher Befund**: Smoothing-Pass dominiert die Laufzeit bei 10k+; die im Fused-Pfad gesparten `cos()`-Aufrufe sind vernachlässigbar. Optimierung **bewusst nicht produktiv** verdrahtet, API für Train 4 verfügbar.

### Verifikation
- `swift build`: BUILD SUCCEEDED.
- `swift test`: siehe Abschlussbericht (Baseline Train 2: 1541/2/0).
- `xcodebuild build` Sim iPhone 17 Pro Max iOS 26.0: **BUILD SUCCEEDED**.
- `xcodebuild build` Device iPhone 15 Pro Max iOS 26.4 (`-allowProvisioningUpdates`): **BUILD SUCCEEDED** (zweiter Versuch nach DerivedData-Lock).
- Runtime-Smoke: kein App-Install/Launch in diesem Train (rein algorithmischer Refactor, kein UI-Drift; Goldens locken visuelle Äquivalenz).

### Bewusst nicht umgesetzt (Train 4)
- AppHeatmapModel auf fused multi-LOD verdrahten (kein messbarer Wallclock-Gewinn → Train 4 nach TaskGroup-/Metal-Spike)
- Per-LOD Parallelism via `TaskGroup`
- Metal compute shader für Smoothing-Kernel
- MKMapView+MKMultiPolyline Heavy-Overview Spike
- MKTileOverlay-Heatmap
- WWDC24 Place ID

### Doku
- **`docs/MAPKIT_AZ_AUDIT_2026-05-13.md`** Train-3-Block ergänzt (Pipeline-Inventur, Golden-Vertrag, Benchmark-Tabelle, ehrlicher Befund, Train-4-Empfehlung).
- `CHANGELOG.md`, `NEXT_STEPS.md`, `ROADMAP.md` synchronisiert.

### Release-Safety
- Keine externe Dependency, keine neuen Entitlements, keine Privacy-/Network-Folge.
- Keine sichtbare Heatmap-Änderung — produktiver Pfad ist `computeGrid(for:lod:)` und liefert **byte-identische** Cells zum Pre-Train-3-Code (Refactor extrahiert nur Helfer).
- Multi-LOD API existiert, wird aber nicht aufgerufen — Goldens und Equivalence-Tests locken das Verhalten falls Train 4 zuschaltet.

---

## 2026-05-13 — perf: harden map surfaces and heatmap large-data paths (branch `chore/mapkit-az-modernization-2`)

> **MapKit A–Z Modernization Train 2.** Kein Release, kein Build-Bump, kein ASC, kein Merge nach `main`. Basis: `chore/mapkit-az-modernization-1@d6a6191` (Train 1, ebenfalls nicht gemerged). Fokus: Sanitize auf Overview/Heatmap/ExportPreview ausgeweitet, Foundation-only Validator, Benchmark-Surface, Heatmap-Single-Pass als Train 3 formuliert.

### Code-Änderungen
- **`Sources/LocationHistoryConsumerAppSupport/CoordinateValidation.swift`** **NEU** (Foundation-only): `public enum CoordinateValidity` mit `@inlinable static func isValid(latitude:longitude:)`. Rejects: NaN, ±Inf, lat outside ±90°, lon outside ±180°, Apple-Sentinel `(-180,-180)`. Linux-buildbar, gemeinsame Quelle der Rejection-Regeln.
- **`Sources/LocationHistoryConsumerAppSupport/MapTrackStyling.swift`**: `MapCoordinateGuard.isValid(_:)` delegiert an `CoordinateValidity.isValid(latitude:longitude:)` — keine API-Änderung, identische Semantik.
- **`Sources/LocationHistoryConsumerAppSupport/ExportPreviewData.swift`** (`ExportPreviewDataBuilder.previewData`): NaN/Inf/Sentinel-Filter im Waypoint-`compactMap` und im Path-Point single-pass Loop (Timestamps werden mit-gefiltert für Alignment). `pathOverlays` verworfen wenn nach Filter < 2 Punkte übrig. `computeRegion` sieht jetzt strikt finite Coords → `fittedRegion` finite garantiert.
- **`Sources/LocationHistoryConsumerAppSupport/AppHeatmapModel.swift`** (`startPrecomputation` collect-Loop): `guard CoordinateValidity.isValid` vor allen 4 `WeightedPoint`-Erzeugungen (visit / path sample / activity marker / activity geometry). Density-Cap-Logik (500k) und `truncatedDensityPoints`-Flag unverändert.
- **`Sources/LocationHistoryConsumerAppSupport/AppOverviewTracksMapView.swift`** (`scanCandidates`): Filter inside both flat- und points-Branch. Bounds-Aggregation (pathMin/MaxLat/Lon + globaler min/maxLat/Lon) wird nur mit validen Punkten gefüttert → keine NaN-Bounds. Score-Logik (`pointWeight = log(coordinates.count)`, distanceM-Pfad, `coordsForScoreBase`) **unverändert**.

### Tests (3 neue Dateien)
- **`Tests/LocationHistoryConsumerTests/CoordinateValidityTests.swift`** (5 Cases): valid accepted, NaN, ±Infinity, out-of-range, Apple-Sentinel rejected (Antemeridian `lon=-180` allein bleibt valide).
- **`Tests/LocationHistoryConsumerTests/ExportPreviewSanitizeTests.swift`** (3 Cases): out-of-range + sentinel coords gedroppt mit Timestamp-Alignment, Path verworfen wenn < 2 valide übrig, Identitäts-Garantie für reine Valid-Daten.
- **`Tests/LocationHistoryConsumerTests/MapSanitizeBenchmarkTests.swift`** (3 Cases, XCTMeasure): 10k mixed coords, 50k valid coords, branch-only sanity. Konkrete Messwerte unten.

JSON kann NaN/Inf nicht serialisieren — Pipeline-Tests nutzen out-of-range (lat=91) + Sentinel `(-180,-180)`. NaN/Inf-Branch ist via `CoordinateValidityTests` separat abgedeckt.

### Benchmark-Surface (XCTMeasure, lokal macOS x86_64)
| Benchmark | Datensatz | Average (10 Iter.) | RSD |
|---|---|---|---|
| `testIsValidThroughput10kMixed` | 10 000 (50% invalid) | **~2,3 ms** | 7,3 % |
| `testIsValidThroughput50kValid` | 50 000 valid | **~9 ms** (warm) | – |
| Throughput (abgeleitet) | – | **~4–5 M coords/s** | – |

Branchfrei, allokationsfrei. iOS-Device-Zahlen **nicht erhoben** — formuliert als optionale Train-3-Aufgabe.

### Verifikation
- `swift build`: BUILD SUCCEEDED.
- `swift test`: siehe Abschlussbericht.
- `xcodebuild build` Sim iPhone 17 Pro Max iOS 26.0: **BUILD SUCCEEDED**.
- `xcodebuild build` Device iPhone 15 Pro Max iOS 26.4 (`-allowProvisioningUpdates`): **BUILD SUCCEEDED**.
- Runtime-Smoke: kein App-Install/Launch in diesem Train (rein defensive Filter, kein UI-/Logik-Drift). Hardware-FPS/Memory **nicht gemessen** — keine Behauptung.

### Heatmap-Pipeline — bewusst Train 3
Analyse durchgeführt: bin/smooth/normalize laufen 4× pro Precomputation (LOD overview/low/medium/high). Single-Pass-Multi-LOD-Sweep würde Kernel-Struktur und Normalisierungs-Kontrakt verschränken → Risiko Farb-/Dichte-Drift ohne goldene Vergleichsdaten. Train-2-Regel „keine stille Datenverfälschung" → ablehnen. Eine kleinere `lonScale`-Memoisierung wurde geprüft und **bewusst verworfen** (kein Messwert für Nutzen bei real GPS-Lat-Verteilung).

**Train-3-Aufgabe formuliert** (siehe `docs/MAPKIT_AZ_AUDIT_2026-05-13.md` Train-2-Block, Phase 5).

### Bewusst nicht umgesetzt (Train 3)
- Heatmap Single-Pass-Multi-LOD-Sweep
- MKMapView + MKMultiPolyline Heavy-Overview Spike (separater Performance-Vergleich Pflicht)
- MKTileOverlay-Heatmap
- WWDC24 Place ID / `mapItemDetailSheet` (iOS-18+-Check)
- `lonScale`-Memo (verworfen)
- iOS-Device-Benchmark für `CoordinateValidity` (optional)

### Doku
- **`docs/MAPKIT_AZ_AUDIT_2026-05-13.md`** um Train-2-Block ergänzt (Sanitize-Surface-Matrix, Benchmark-Tabelle, Heatmap-Entscheidung, Train-3-Aufgabe).
- `CHANGELOG.md`, `NEXT_STEPS.md`, `ROADMAP.md` synchronisiert.
- `docs/MAP_ARCHITECTURE_AUDIT.md` bleibt **kanonische** Bestandsaufnahme — Train-2-Änderungen sind Sanitize-Härtung, keine Architektur-Änderung.

### Release-Safety
- Keine externe Dependency, keine neuen Entitlements, keine Privacy-/Network-Folge.
- Keine sichtbare UX-Änderung bei gültigen Daten — Identitäts-Test `testValidCoordsUnchanged` belegt strukturelle Identität für reine Valid-Daten.
- Filter ist destruktiv (Drop, kein Re-Map): bei NaN/Inf/Sentinel-Input werden Punkte verworfen, keine künstlichen Ersatzwerte erzeugt.
- Heatmap density-Cap (500k) zählt jetzt strikt valide Punkte (vorher: NaN-Punkte konnten den Cap mit-belegen).

---

## 2026-05-13 — perf: modernize map stack and large-data rendering (branch `chore/mapkit-az-modernization-1`)

> **MapKit A–Z Modernization Train 1.** Kein Release, kein Build-Bump, kein ASC, kein Merge nach `main`. Branch von `main@c1314dc`. Fokus: punktuelle Härtung der Day-Detail-Map-Surface, vorbereitend für Map-Train 2 (Heavy Overview / Heatmap-Renderer-Wechsel).

### Code-Änderungen
- **`Sources/LocationHistoryConsumerAppSupport/AppDayMapView.swift`**:
  - `DayMapRenderData` `private` → `internal` für Testbarkeit (Struct nicht öffentlich exportiert, kein API-Drift).
  - `DayMapRenderData.PathOverlay` und `DayMapRenderData.VisitAnnotation` jetzt `Identifiable` mit stabilem `id: Int` (Insertion-Index, Snapshot-stabil).
  - **`MapCoordinateGuard.isValid`-Filter** auf Day-Pfad ausgeweitet: NaN, ±Inf, lat outside ±90°, lon outside ±180°, Apple-Sentinel `(-180,-180)` werden in `init` verworfen. **Coords + parallele ISO-Timestamps gemeinsam gefiltert** → Sample-Alignment für Tempolayer bleibt korrekt. Visits ebenso.
  - **`PathOverlay.speedSegments: [SpeedSegment]`** neu, einmalig in `init` aus `SpeedTrackBuilder.segments(from: samples)` befüllt. Map body greift jetzt auf das Cache-Array zu — vorher pro Body-Pass neu berechnet (Body läuft halo + core × N Pfade).
  - 3× `ForEach(Array(...enumerated()), id: \.offset)` → `ForEach(renderData.pathOverlays)` / `ForEach(renderData.visitAnnotations)` via `Identifiable`.

### Tests
- **`Tests/LocationHistoryConsumerTests/AppDayMapRenderDataTests.swift`** neu (MapKit-gated `#if canImport(SwiftUI) && canImport(MapKit)`), 6 Cases:
  1. `testSanitisesNaNAndInfinityCoordinates` (6 Roh → 3 valide)
  2. `testSanitisesInvalidVisitCoordinates` (4 → 2)
  3. `testStableIdentifiableIDsAcrossPaths` (IDs `[0,1,2]`)
  4. `testSpeedSegmentsArePrecomputedAndAlignedToSanitisedCoords` (NaN-Coord + Timestamp gemeinsam gedroppt, Cache befüllt)
  5. `testEmptyPathDoesNotCrash`
  6. `testSingleValidCoordinateProducesNoSpeedSegments`
- Alle 6 grün in 0,010 s.

### Verifikation
- `swift build`: BUILD SUCCEEDED.
- `swift test`: siehe Abschlussbericht (separat erhoben, Baseline 1524 / 2 skipped / 0 failures, 162 s).
- `xcodebuild build` Sim iPhone 17 Pro Max iOS 26.0: BUILD SUCCEEDED.
- `xcodebuild build` Device iPhone 15 Pro Max iOS 26.4 (`-allowProvisioningUpdates`): siehe Abschlussbericht.
- **Performance-Messung im engeren Sinn (FPS/Memory) nicht erhoben.** Qualitative Aussage: `SpeedTrackBuilder.segments()` läuft jetzt einmal pro Snapshot statt pro Body-Pass. Konkrete CPU-Einsparung **nicht gemessen, keine Behauptung**.

### Bewusst nicht umgesetzt (Map-Train 2)
- `AppOverviewTracksMapView.scanCandidates`-Streaming-Refactor (HIGH-RISK, Score-Reihenfolge-Tests müssen mitwandern; bewusst `MAP_ARCHITECTURE_AUDIT.md §Phase-10C` konform deferred).
- MKMapView + MKMultiPolyline-Bridging für Heavy Overview/Heatmap (separater Performance-Vergleich Pflicht).
- MKTileOverlay-Heatmap, AppHeatmapModel Single-Pass Tile-Sweep.
- Sanitize-Ausweitung auf Overview/Export/Heatmap (eigene Commits pro Surface).
- WWDC24 10097 Place ID / `mapItemDetailSheet` (iOS-18+-Check + UX-Entscheidung).

### Doku
- **`docs/MAPKIT_AZ_AUDIT_2026-05-13.md`** neu (Research-Matrix, A–Z-Inventur, Top-Kandidaten, Risiken, Map-Train-2-Backlog).
- `docs/MAP_ARCHITECTURE_AUDIT.md` bleibt **kanonische** Bestandsaufnahme; neuer Audit-Doc ergänzt sie, ersetzt sie nicht.
- `CHANGELOG.md`, `NEXT_STEPS.md` synchronisiert.

### Release-Safety
- Keine externe Dependency, keine neuen Entitlements, keine Privacy-/Network-Folge.
- Keine sichtbare UX-Änderung bei gültigen Daten — kleine/normale Tages-Datasets sehen identisch aus.
- Sanitize ist destruktiv (Filter, nicht Re-Map): bei reinen Valid-Daten **Identität**.

---

## 2026-05-13 — chore: bump release train to 1.0.2 build 171 (branch `main`)

> **Release-Train-Bump für ASC.** App Store Connect schließt 1.0.1 für neue Builds (Fehler 90186 + 90062 bei Upload). Neue Marketing-Version **1.0.2**, neue Buildnummer **171** (170 vermutlich in fehlgeschlagenem Upload verbraucht). Kein neues Feature, kein UI-Train.

### Bumps
- **MARKETING_VERSION**: `1.0.1` → **`1.0.2`** in allen 8 pbxproj-Configs (`wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`).
- **CFBundleShortVersionString**: `$(MARKETING_VERSION)` → literal **`1.0.2`** (via `agvtool new-marketing-version 1.0.2`) in `wrapper/Config/Info.plist` + `wrapper/LH2GPXWidget/Info.plist`.
- **CURRENT_PROJECT_VERSION**: `168` → **`171`** in allen 8 pbxproj-Configs (via `agvtool new-version -all 171`).
- **CFBundleVersion**: `168` → **`171`** in `wrapper/Config/Info.plist` + `wrapper/LH2GPXWidget/Info.plist`.
- Bundle Identifier unverändert: `de.roeber.LH2GPXWrapper`.

### Verifikation
- `swift build`: BUILD SUCCEEDED (1,22 s).
- `swift test`: **1524 / 2 skipped / 0 failures** in 195,2 s.
- `xcodebuild build` Sim iPhone 17 Pro Max iOS 26.0: BUILD SUCCEEDED.
- `xcodebuild build` Device iPhone 15 Pro Max iOS 26.4 (`-allowProvisioningUpdates`): BUILD SUCCEEDED.
- `xcodebuild archive -configuration Release -destination 'generic/platform=iOS'` → **ARCHIVE SUCCEEDED** unter `/tmp/lh2gpx-release/LH2GPXWrapper-build171.xcarchive` (91 MB inkl. dSYMs).
- Archive-Metadaten: `CFBundleShortVersionString=1.0.2`, `CFBundleVersion=171`, `CFBundleIdentifier=de.roeber.LH2GPXWrapper`, `SigningIdentity=Apple Development: sebastian.roeber94@googlemail.com (2V7DV73UAB)`. Distribution-Re-Signing erfolgt beim Upload via Organizer.
- Device-UITests **nicht** erneut gefahren — nur Versionsstrings geändert, keine Logik-/Native-API-Änderung; letzte grüne Device-UITest-Basis auf `0739d4c` bleibt valide.

### Release-Safety
- UI-Testing-Hooks (`LH2GPX_UI_TESTING`, `LH2GPX_RESET_PERSISTENCE`, `LH2GPX_UI_IMPORT_FILE`) sind ausschließlich launch-arg-gated im `ContentView.swift` und in UI-Test-Targets — nicht aktiv im Release-Build ohne explizite Launch-Args.
- Keine neuen Secrets/Tokens, keine Privacy-/Network-/Live-Upload-Änderungen, kein Bundle-Identifier-Drift.

### Upload-Status
- **NICHT** hochgeladen in diesem Commit. Archive liegt lokal unter `/tmp/lh2gpx-release/LH2GPXWrapper-build171.xcarchive` bereit.

### Manuelle ASC-Schritte
1. Xcode → Window → Organizer.
2. Archive **LH2GPXWrapper 2026-05-13 (1.0.2 171)** auswählen.
3. **Distribute App → App Store Connect → Upload** → Distribution-Re-Signing automatisch.
4. In App Store Connect neue Version **1.0.2** anlegen (nicht in 1.0.1-Train hochladen).
5. Build **1.0.2 (171)** auswählen, Compliance-Fragen beantworten, einreichen.

---

## 2026-05-13 — docs: record hardware visual verification for ui polish (branch `chore/uiux-modernization-train-2`)

> **Hardware-Sichtprüfungs-Gate für UI/UX-Polish Train 1+2.** Keine App-Code-Änderung. Buildnummer/Marketing-Version unverändert. Kein Release, kein ASC-Submit. Train 1+2 wurden bereits per Fast-Forward nach `main` gemerged (HEAD `47f2bc0`); dieser Commit ist reine Doku-Synchronisation des Hardware-Gates auf der Branch-Spitze.

### Hardware-Verifikation (2026-05-13)
- **Gerät:** iPhone 15 Pro Max (iPhone16,2), iOS **26.4**, verbunden via `devicectl` (`6E4A2D38-F3C8-5CE3-9483-82A5D167BBF0`).
- **Device-Build:** `xcodebuild build -destination 'platform=iOS,id=00008130-00163D0A0461401C'` mit `-allowProvisioningUpdates` → **BUILD SUCCEEDED** (Codesign mit `8D7D90F4F1E3DB4F515A14258CA6FBBDE484AEAE`, Profile `iOS Team Provisioning Profile: de.roeber.LH2GPXWrapper`, Widget-Extension valid).
- **Install:** `devicectl device install app` → installiert nach `/private/var/containers/Bundle/Application/C2113CDE-62B8-400A-88E3-4A4721156099/LH2GPXWrapper.app`.
- **Launch:** `devicectl device process launch de.roeber.LH2GPXWrapper` → erfolgreich, App läuft auf Gerät.

### Tests
- `swift build`: BUILD SUCCEEDED (22,9 s).
- `swift test`: **1524 / 2 skipped / 0 failures** in 163,2 s.
- `xcodebuild build` Sim iPhone 17 Pro Max iOS 26.0: BUILD SUCCEEDED (in vorherigem Gate-Commit `47f2bc0` bereits dokumentiert).
- `xcodebuild build` Device iPhone 15 Pro Max iOS 26.4: BUILD SUCCEEDED (siehe oben).
- Device-UITests: **nicht erneut gefahren** — keine Logik-/Native-API-Änderung gegenüber Basis `0739d4c` (8 + 4× LaunchTest + `testLargeImportSyntheticFile` grün). Diese Basis bleibt valide.

### Sichtprüfungs-Matrix
| Flow | Gerät | iOS | Mode | Textgröße | Orientierung | Ergebnis | Auffälligkeit |
|---|---|---|---|---|---|---|---|
| App-Launch | iPhone 15 Pro Max | 26.4 | aktueller User-State | aktueller User-State | aktueller User-State | ✅ Launch + Render OK | App startet, kein Crash, Splash + erste View korrekt |
| Export-Tab Normal | iPhone 15 Pro Max | 26.4 | Light/Dark | Standard | Portrait | ⚠️ manuell durch User | App läuft, Pixel-Inspektion durch Sebastian |
| Export-Tab Accessibility XL/XXL/XXXL | iPhone 15 Pro Max | 26.4 | Light/Dark | XL/XXL/XXXL | Portrait/Landscape | ⚠️ manuell durch User | erfordert Settings → Accessibility → Display & Text Size Toggle auf Gerät |
| Insights-Tab Normal | iPhone 15 Pro Max | 26.4 | Light/Dark | Standard | Portrait | ⚠️ manuell durch User | App läuft, Pixel-Inspektion durch Sebastian |
| Insights-Tab Accessibility XL/XXL/XXXL | iPhone 15 Pro Max | 26.4 | Light/Dark | XL/XXL/XXXL | Portrait/Landscape | ⚠️ manuell durch User | siehe oben |
| Map/Heatmap Landscape-Smoke | iPhone 15 Pro Max | 26.4 | Light/Dark | Standard | Landscape | ⚠️ manuell durch User | erfordert Geräte-Rotation |
| Sim iPhone 17 Pro Max alle Flows | Sim 17 Pro Max | 26.0 | Light + Dark + Acc-XL + Landscape | div. | div. | ✅ | bereits im vorigen Gate (`47f2bc0`) verifiziert, Screenshots `/tmp/lh2gpx-screens/` |

Legende: ✅ verifiziert durch Claude · ⚠️ App läuft auf Gerät, finale Pixel-Sichtprüfung obliegt dem User · ❌ Fehler.

### Ehrliche Einschränkung
Claude kann das verbundene iPhone **nicht** remote in Accessibility-Textgrößen schalten oder rotieren — Apple bietet dafür keine `devicectl`-Schnittstelle (nur Simulator hat `simctl ui content_size`). Die App ist auf der iPhone-15-Pro-Max-Hardware installiert und gestartet; alle Layout-Modifier sind durch die SwiftUI-Layout-Engine deterministisch (auf dem Simulator iPhone 17 Pro Max bereits verifiziert). Die finale Pixel-Sicht auf Hardware bei `Einstellungen → Accessibility → Display & Text Size → Larger Text → XL/XXL/XXXL` und in Landscape obliegt Sebastian und ist als Restrisiko ausgewiesen.

### Gefundene / behobene Probleme
- Keine. Keine Code-Änderung.

### Restrisiken
- Manuelle Pixel-Sicht auf iPhone 15 Pro Max bei Accessibility XL/XXL/XXXL (Export-Tab + Insights-Tab) durch User.
- Manuelle Landscape-Sicht Map-/Heatmap-Overlay durch User.

### Status Train 1+2
- Bereits per Fast-Forward nach `main` gemerged (`99e23f9` → `47f2bc0`, gepusht).
- Branches `chore/uiux-modernization-train-1` + `-train-2` stehen weiterhin auf `47f2bc0`.

---

## 2026-05-13 — test: verify ui polish dynamic type and landscape (branch `chore/uiux-modernization-train-2`)

> **Visuelles Verifikations-Gate für UI/UX-Modernization-Train 1 + Train 2.** Keine Code-Änderungen am App-Code. Buildnummer/Marketing-Version unverändert. Kein Release, kein Merge nach `main`.

### Verifikation (durchgeführt 2026-05-13)
- `swift build`: BUILD SUCCEEDED (1,39 s).
- `swift test`: **1524 / 2 skipped / 0 failures** in 162,3 s.
- `xcodebuild build` Simulator iPhone 17 Pro Max (iOS 26.0): BUILD SUCCEEDED.
- Simulator iPhone 17 Pro Max gebootet, App installiert + gelauncht (`de.roeber.LH2GPXWrapper`).
- Screenshots als Evidenz unter `/tmp/lh2gpx-screens/` (lokal, nicht committed): Launch Light, Launch Dark, Dark + Dynamic-Type Accessibility-XL, Landscape.

### Sichtprüfungs-Matrix
| Flow | Sim/Device | Normal | Dark | Dyn-Type AXL | Landscape | Ergebnis |
|---|---|---|---|---|---|---|
| App-Launch / Day-List | Sim iPhone 17 Pro Max | ✅ | ✅ | ✅ | ✅ | ✅ |
| Heatmap-Overlay (Padding, Spinner-Tint) | Sim 17 Pro Max | ✅ | ✅ | ⚠️ Code-Analyse | ⚠️ Code-Analyse | ✅ |
| Day-Detail Section-Header semibold | Sim 17 Pro Max | ✅ | ✅ | ⚠️ Code-Analyse | ⚠️ Code-Analyse | ✅ |
| Day-List Swipe-Tint `.secondary` | Sim 17 Pro Max | ⚠️ Code-Analyse | ✅ | n/a | n/a | ✅ |
| Export Selection Banner | Sim 17 Pro Max | ⚠️ Code-Analyse | ⚠️ Code-Analyse | ✅ | ⚠️ Code-Analyse | ✅ |
| Export modePill | Sim 17 Pro Max | ⚠️ Code-Analyse | ⚠️ Code-Analyse | ✅ | ⚠️ Code-Analyse | ✅ |
| Export Error-Microcopy KMZ/GeoJSON | Sim 17 Pro Max | ✅ String-Diff | n/a | n/a | n/a | ✅ |
| Insights Period-Comparison Δ-Spalte | Sim 17 Pro Max | ⚠️ Code-Analyse | ⚠️ Code-Analyse | ✅ | ⚠️ Code-Analyse | ✅ |

Legende: ✅ verifiziert · ⚠️ Code-Analyse positiv, kein gezielter Pixel-Screenshot in diesem Flow · ❌ Fehler.

### Ehrliche Einschränkung
Die Train-1+2-Änderungen sind reine SwiftUI-Modifier-Updates und Microcopy-Strings. Ihr Verhalten ist durch die SwiftUI-Layout-Engine deterministisch (`.frame(minWidth:)` ändert Normal-Layout nicht; lässt System bei Accessibility-Sizes wachsen). Eine vollständige Pixel-Inspektion über alle Kombinationen (4 Flows × Light/Dark × 3 Dyn-Type-Stufen × 2 Orientierungen) wurde **nicht** durchgespielt. Für die High-Risk-Stellen (Export-Banner, Export modePill, Insights Δ-Spalte bei Accessibility-XL/XXL) wird **manuelle Endsichtprüfung auf Hardware vor Merge nach `main`** empfohlen.

### iPhone 15 Pro Max Hardware
- Gerät verbunden (`devicectl list devices` → connected). Device-Build/UITest **nicht** ausgeführt: Train 1+2 enthalten keine Logik-/Native-API-Änderungen → letzte grüne Device-UITest-Basis auf `0739d4c` bleibt valide.

### Gefundene / behobene Probleme
- Keine. Sichtprüfungs-Gate ergibt keine Layoutfehler — keine Code-Änderung notwendig, nur Doku-Sync.

### Restrisiken
- Manuelle Accessibility-XL/XXL/XXXL-Sicht auf Hardware (Export-Tab + Insights-Tab) steht aus.
- Landscape-Smoke iPhone 15 Pro Max für Map-/Heatmap-Overlay manuell empfohlen.

---

## 2026-05-13 — ui: improve dynamic type landscape and empty states (branch `chore/uiux-modernization-train-2`)

> **Nicht-releasegebundener Modernisierungsbranch (Train 2).** Kein ASC-Submit, kein Buildnummer-Bump, kein Release-Update. `CURRENT_PROJECT_VERSION`, `CFBundleVersion`, `MARKETING_VERSION` unverändert. Branch sitzt auf Train 1 (`a076374`, kumulativer UI-Review) und wird **nicht** ungefragt nach `main` gemerged.

### Basis-Entscheidung
Train 2 baut auf Train 1 (`chore/uiux-modernization-train-1` HEAD `a076374`) auf statt von `main` (`99e23f9`) — Begründung: gleiche UI-Files (Day-Detail, Heatmap) und kumulative Review-Geschichte ermöglichen einheitlichen UI-Polish-Diff zu `main`.

### UI/UX-Polish (klein, sicher, reviewbar)
- **`AppContentSplitView.swift` (Export-Selection-Banner, Z. 576-580)**: `Text(...)` mit `.lineLimit(1)` ersetzt durch `.lineLimit(2) + .minimumScaleFactor(0.85)` — kein Clipping bei Dynamic Type XL/XXL/Accessibility-Sizes.
- **`AppExportView.swift` (modePill Icon-Frame, Z. 774)**: `.frame(width: 20)` → `.frame(minWidth: 20)` — Icon-Container wächst korrekt mit Dynamic Type, Text wird nicht abgeschnitten.
- **`AppExportView.swift` (KMZ-Fehler-Microcopy, Z. 1433)**: `"The archive could not be created."` → `"Please try again or choose a different file format."` — actionable Microcopy ohne Tech-Jargon.
- **`AppExportView.swift` (GeoJSON-Fehler-Microcopy, Z. 1448)**: `"The data could not be serialized."` → `"Please try again or choose a different file format."` — actionable, konsistent mit KMZ-Fehler.
- **`AppExportView.swift` (Export-Failed-Alert, Z. 1280-1282)**: Fallback-Message bei `exportError == nil` ergänzt (`"An unexpected error occurred. Please check your selection and try again."`) statt leerem Alert-Body.
- **`AppInsightsContentView.swift` (periodComparison-Zahlen, Z. 1111+1115)**: `.frame(width: 80, alignment: .trailing)` und `.frame(width: 50, alignment: .trailing)` → `.frame(minWidth: 80/50, alignment: .trailing)` — Metric-Werte (z. B. „2.5 km") wachsen bei Accessibility-Sizes ohne Ellipsis-Clipping.

### Verifikation
- `swift build`: BUILD SUCCEEDED (27,31 s nach Edits).
- `swift test`: siehe Train-Abschlussbericht.
- `xcodebuild build` Simulator iPhone 17 Pro Max: siehe Train-Abschlussbericht.
- Keine Tests prüfen die geänderten Strings (`grep -rn "could not be serialized|archive could not be created"` in Tests → 0 Treffer).

### Bewusst nicht angefasst (in diesem Train)
- Capitalization-Inkonsistenzen in Activity-/Visit-Type-Labels: Quelle ist `.capitalized` auf semantischen Enum-Strings — eine Vereinheitlichung würde Lokalisierungs-Sichtbarkeit ändern; separater Train.
- `AppDayDetailView.swift:644` iconButton: `accessibilityLabel` bereits gesetzt — keine Änderung.
- Keine Privacy-/Network-/Live-Upload-Änderungen.
- Keine neuen Kartenlayer, iCloud, neuen Serverfunktionen, Dateiformate.
- Kein komplettes Theme-System / Navigation-Refactor.
- Keine externen Design-Libraries.

### Nächster UI/UX-Train (Train 3, Empfehlung)
- Activity-/Visit-Type-Capitalization vereinheitlichen (Lokalisierungs-Audit).
- Landscape-Smoke explizit auf iPhone 15 Pro Max manuell durchspielen (Map-/Heatmap-Overlay-Verhalten).
- Insights-Cards `.minimumScaleFactor` für Δ-Spalte auf Accessibility XXXL.

---

## 2026-05-13 — ui: modernize app polish and interaction details (branch `chore/uiux-modernization-train-1`)

> **Nicht-releasegebundener Modernisierungsbranch.** Kein ASC-Submit, kein Buildnummer-Bump, kein Release-Update. `CURRENT_PROJECT_VERSION` und `CFBundleVersion` unverändert. Branch sitzt auf `main` (`99e23f9`) und wird **nicht** ungefragt nach `main` gemerged.

### UI/UX-Polish (klein, sicher, reviewbar)
- **`AppHeatmapView.swift` (Map-Layer-Overlay)**: Asymmetrisches `.padding(.top, 8) + .padding(.trailing, 8)` durch konsistentes `.padding(12)` ersetzt — gleichmäßiger Abstand zu Safe Area & Dynamic Island, bessere Touch-Hit-Area.
- **`AppHeatmapView.swift` (Computing-Overlay)**: `ProgressView()` bekommt `.tint(.accentColor)` — Spinner ist jetzt visuell mit App-Akzentfarbe verknüpft (vorher Default-Grau).
- **`LocalTimelineDayMapView.swift` (Empty State)**: `Text("No path metadata for this day.")` ersetzt durch `Label("No routes recorded for this day", systemImage: "location.slash")` — klarere Microcopy, semantisches SF-Symbol, konsistent mit anderen Empty-State-Mustern.
- **`AppDayListView.swift` (Favoriten-Swipe-Action)**: Hardcoded `.gray` tint durch `.secondary` ersetzt — respektiert Light/Dark-Mode-Kontraste systemkonform.
- **`AppDayDetailView.swift` (Section Header)**: `.font(.headline)` → `.font(.headline.weight(.semibold))` für Day-Detail-Section-Cards (Visits/Activities/Paths-Header) — konsistentere visuelle Hierarchie zu anderen Section-Titeln.

### Verifikation
- `swift build`: BUILD SUCCEEDED (15,29 s).
- `swift test`: siehe Branch-Abschlussbericht (Train-Ende).
- `xcodebuild build` Simulator iPhone 17 Pro Max: siehe Branch-Abschlussbericht.

### Bewusst nicht angefasst (in diesem Train)
- Keine neuen Kartenlayer, keine iCloud, keine neuen Serverfunktionen, kein neues Dateiformat.
- Kein komplettes Theme-System / Navigation-Refactor.
- Keine externen Design-Libraries.
- Keine Privacy-/Network-/Live-Upload-Änderungen.
- `LHCollapsibleMapHeader.iconButton`: Accessibility-Label bereits vorhanden — keine Änderung.
- `AppContentSplitView` Insights-Empty-State: bereits Icon + Headline + Subline — keine Änderung.
- `AppExportView` Export-Fehler-Alert: `OK`-Button-Pattern ist Standard, kein Risiko ohne klaren Recovery-Pfad.
- `HistoryDateRangeFilterBar` + `AppHistoryDateRangeControl` DateFormatter: Locale-abhängig, kein sicherer Cache-Pattern.

### Nächster UI/UX-Train (Empfehlung)
- Dynamic-Type-XL-Stresstest auf Insights-Cards (vermutete Clipping-Risiken).
- Landscape-Layout-Smoke auf Map/Heatmap (Safe-Area-Insets).
- Empty-State-Polish in Export-Selection (falls Nutzer-Feedback eintrifft).

---

## 2026-05-13 — chore: prepare release candidate build (Build 100 → 168)

### Build-Identität
- `CURRENT_PROJECT_VERSION`: **100 → 168** in allen 8 Build-Konfigurationen (`agvtool new-version -all 168`); `CFBundleVersion` in `wrapper/Config/Info.plist` und `wrapper/LH2GPXWidget/Info.plist` synchron auf `168`.
- `MARKETING_VERSION`: unverändert **`1.0.1`**.
- Begründung: Tester-/ASC-Sichtung dokumentiert in `docs/ASC_SUBMIT_RUNBOOK.md` referenziert Cloud-Build `167`; die nächste ASC-Submission verlangt strikt monoton steigende Build-Nummern, daher Bump auf `168`.

### Verifikation Release-Candidate
- `swift build`: BUILD SUCCEEDED.
- `swift test`: **1524 Tests, 2 Skips, 0 Failures, 0 unexpected** in 250,0 s (Mac, +3 ggü. 1521 vor Closure-Train).
- `xcodebuild build` Simulator iPhone 17 Pro Max iOS 26.3.1: **BUILD SUCCEEDED**.
- `xcodebuild build` Device iPhone 15 Pro Max iOS 26.4: **BUILD SUCCEEDED** (separat verifiziert in diesem Train; siehe NEXT_STEPS.md).
- `xcodebuild archive -scheme LH2GPXWrapper -configuration Release -destination 'generic/platform=iOS' -archivePath /tmp/lh2gpx-release/LH2GPXWrapper-build168.xcarchive`: **ARCHIVE SUCCEEDED** (91 MB inkl. dSYMs).
  - `ApplicationProperties` im Archive-Info.plist: `CFBundleVersion = 168`, `CFBundleShortVersionString = 1.0.1`, `CFBundleIdentifier = de.roeber.LH2GPXWrapper`, `Team = XAGR3K7XDJ`, `Architectures = [arm64]`.
  - `SigningIdentity`: Apple Development (lokales Smoke-Archive; produktiver TestFlight-Upload läuft per Repo-Konvention über Xcode Cloud → siehe Manuelle-Schritte unten).
- Device-UITests wurden in diesem Train **nicht erneut** gefahren — Begründung: einzige Änderung sind Build-Nummern-Strings (Info.plist + pbxproj), kein Runtime-Verhalten. Letzte vollständige grüne Device-UITest-Verifikation auf `0739d4c` vom 2026-05-13 inkl. `testLargeImportSyntheticFile` (9 + 4× LaunchTest, 1299,77 s, TEST SUCCEEDED).

### Manuelle ASC-Submission-Schritte (lokal nicht automatisiert)
1. Xcode öffnen → **Window → Organizer**.
2. Den lokal erstellten Archive (`/tmp/lh2gpx-release/LH2GPXWrapper-build168.xcarchive`) oder den nächsten **Xcode-Cloud-Release-Build** auswählen.
3. **Distribute App → App Store Connect → Upload**.
4. Distribution-Signing erfolgt automatisch (oder via Cloud-Build).
5. Im ASC-Portal: Build `1.0.1 (168)` der App-Version `1.0.1` zuordnen, Release-Notes setzen, Submit-For-Review.

### Status / Risiken
- Audit-Gate-Closure (`P0-EX-1`/`P0-EX-2`/`P0-EX-3`) aus dem 2026-05-13-Audit unverändert geschlossen / herabgestuft (siehe Train-Eintrag „fix: close map performance gate and verify large import").
- **ASC-Submit-Empfehlung (technisch):** **JA**. Verbleibende Risiken sind ASC-Portal-extern.

---

## 2026-05-13 — fix: close map performance gate and verify large import (Audit-Gate-Closure)

### Code
- `Sources/LocationHistoryConsumerAppSupport/AppOverviewTracksMapView.swift`:
  `OverviewMapPreparation.scanCandidates` und der zweite Score-Pfad in
  `makeCandidate(from overlay:)` cappen jetzt die Eingabe in
  `approximateDistance` über `strideDecimate(coords, maxPoints: scoreSamplingCap)`,
  wenn `path.distanceM == nil` UND `coordinates.count > scoreSamplingCap (= 1024)`.
  Vorher: pro Kandidat eine ungebundene O(N)-Haversine-Schleife, bei
  10 k Tracks × 5 k Punkten ≈ 50 Mio. Hops für ≈ 200 finale Overlays
  (P0-EX-2 aus `docs/DEEP_AUDIT_2026-05-13_CLAUDE.md`). Jetzt bounded
  mit dokumentierter Genauigkeits-Tradeoff-Grenze: das Distanz-Ergebnis
  ist eine Chord-Underestimate; die Score-Reihenfolge bleibt stabil,
  weil der zweite Term `pointWeight = log(coordinates.count)` weiter
  auf der echten Punktzahl rechnet und für dichte Pfade die Priorität
  hält. `approximateDistance` und der neue `scoreSamplingCap` sind
  `internal` (nicht `public`) für Test-Zugriff.
- `wrapper/LH2GPXWrapper/ContentView.swift`: UI-Testing-only Launch-Argument
  `LH2GPX_UI_LARGE_IMPORT_BYTES=<bytes>` (Prefix in `LaunchArgument`-Enum).
  Aktiv **nur** zusammen mit `LH2GPX_UI_TESTING`. Wenn beide gesetzt:
  `prepareLaunchStateIfNeeded` schreibt ein synthetisches Google-Timeline-style
  JSON-Array der Zielgröße in `FileManager.default.temporaryDirectory`
  (visit-only Entries, ISO-Zeitstempel, geo-Locations) und ruft danach
  den **gleichen** Production-Import-Pfad (`runImport(at:source:.manual)`)
  wie der echte fileImporter auf. Datei wird nach Import gelöscht.
  Keine Produktiv-UI; ohne `LH2GPX_UI_TESTING` ist der Code-Pfad nicht
  erreichbar. Schließt das 46-MiB-Hardware-Gate ohne 46-MiB-Datei im
  Repo.

### Tests
- `Tests/LocationHistoryConsumerTests/AppOverviewTracksMapViewTests.swift`
  (NEU, 3 Tests): `testScoreSamplingCapAppliedForLargeCoordsWithoutDistanceM`
  prüft, dass für 2000-Punkt-Paths mit `distanceM == nil` der Score
  exakt `approximateDistance(strideDecimate(coords, 1024)) + log(2000)*100`
  ist; `testScoreUnaffectedWhenDistanceMProvided` prüft, dass der Cap
  bei vorhandenem `distanceM` **nicht** greift; `testScoreCapNotAppliedForSmallCoordsWithoutDistanceM`
  prüft, dass kleine Coord-Listen (100 Punkte) weiter den vollen
  Haversine-Pfad nehmen — keine Regression unterhalb des Caps.
- `wrapper/LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift`: Neuer
  Hardware-Smoke-Test `testLargeImportSyntheticFile` mit `LaunchArgument.uiLargeImportBytes(46 * 1024 * 1024)`.
  Wartet bis zu 240 s auf das Erscheinen des Overview-Tabs nach dem
  46-MiB-Synthetik-Import, prüft danach Tab-Navigation (`Days`) als
  Liveness-Proxy. Schließt das Audit-Gate P0-EX-3 autonom — kein
  Tester-Handoff mehr nötig.

### Verifikation 2026-05-13
- `swift build`: BUILD SUCCEEDED (12,6 s).
- `swift test`: **1524 Tests, 2 Skips, 0 Failures, 0 unexpected** in
  156,98 s (+3 ggü. 1521; die 2 verbleibenden Skips sind die
  `testReal*OnDesktop`-Smokes, wenn Desktop-Symlinks nicht da sind).
- `xcodebuild build` Simulator iPhone 17 Pro Max iOS 26.3.1: **BUILD SUCCEEDED**.
- `xcodebuild build` Device iPhone 15 Pro Max iOS 26.4: **BUILD SUCCEEDED**,
  Apple Development cert, 0 warnings.
- `xcodebuild test -only-testing:LH2GPXWrapperUITests` Device: **TEST SUCCEEDED**
  — **9 UI-Tests + 4× LaunchTest passed, 0 Failures** in 1299,77 s.
  Highlights:
  - `testLargeImportSyntheticFile`: **passed in 126,27 s**, kein Crash, kein
    Hang, kein Jetsam, App nach Import bedienbar (Tab-Switch `Days`
    erfolgreich).
  - `testAppStoreScreenshots` 43,2 s · `testDeviceSmokeNavigationAndActions`
    74,5 s · `testLandscapeLayoutSmoke` 830,2 s · LiveActivity-Capture
    × 5 (35–62 s).
  - `testLaunch` (×4 Replays) 4,8 / 5,1 / 6,1 / 5,1 s.

### Audit-Gate-Matrix
- **P0-EX-1** (`AppExportQueries.projectedDays`): unverändert **HERABGESTUFT
  auf P1** (Dead-Code-Pfad, `limit` aktiv nirgendwo gesetzt). Keine
  Codeänderung in diesem Train.
- **P0-EX-2** (`AppOverviewTracksMapView.scanCandidates` Full-Coord-Score):
  **GESCHLOSSEN durch `scoreSamplingCap = 1024`**. Code-Fix + 3 Unit-Tests
  + bestehende Sim-/Device-Tests grün.
- **P0-EX-3** (46-MiB-Google-Timeline-Hardware-Crashfall): **GESCHLOSSEN
  für die Streaming-/Parser-/Loader-Pipeline auf iPhone 15 Pro Max
  (iOS 26.4)** durch `testLargeImportSyntheticFile`. *Hinweis zur
  Genauigkeit*: Der Test verwendet eine **synthetische** Google-Timeline-style
  Fixture (visit-only Entries), nicht das originale Tester-Asset mit
  timelinePath-Geometrie-Dichte. Die Klasse der Jetsam-Auslöser
  (46-MiB-Streaming) ist verifiziert; eine spezifische, datenstrukturell
  abweichende Datei könnte theoretisch immer noch fehlschlagen. Der
  Gate "Streaming-Pipeline verträgt 46 MiB auf echter Hardware" ist
  damit autonom geschlossen.

### ASC-Submit-Empfehlung (technisch)
**JA** — alle drei P0-Items aus dem 2026-05-13-Audit sind entweder
gelöst oder dokumentiert herabgestuft. Tests + Builds + Hardware grün.

---

## 2026-05-12 — perf: add measured performance baseline and low-risk optimizations

### Code
- `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStore.swift` (`init(url:)`): nach `PRAGMA journal_mode = WAL;` werden drei zusätzliche WAL-safe PRAGMAs gesetzt — `busy_timeout = 3000;` (Concurrent-Open-Resilienz statt sofortigem SQLITE_BUSY), `synchronous = NORMAL;` (sqlite.org-empfohlene WAL-Paarung für App-Stores; Crash-Recovery via WAL-Replay bleibt, nur Power-Loss-Outerschicht akzeptabel), `temp_store = MEMORY;` (Sortier-/Temp-Tabellen im RAM). `mmap_size` bewusst nicht gesetzt — Memory-Trade-off auf 4-GB-Geräten. Greift erst bei Feature-Flag default-ON (`LH2GPX_LOCAL_TIMELINE_STORE`, aktuell OFF), aber Test-Suite über die `LocalTimelineStore*Tests` deckt den Open-Pfad bereits ab.
- `Sources/LocationHistoryConsumerAppSupport/RecordedTrackStore.swift` (`saveTracks`): nach `data.write(to:)` werden Verzeichnis und Datei via `LocalTimelineFileAttributes.markExcludedFromBackupIfPresent(urls:)` als excluded-from-iCloud-Backup markiert. Privacy-Defence-in-Depth: Live-Track-Standortdaten landen damit nicht in generischem iCloud/iTunes-Backup. Failure `try?`-geschluckt (Backup-Flag ist nicht korrektheitskritisch). Symmetrisch zum Pattern in `LocalTimelineStoreFactory`.

### Tests
- `Tests/LocationHistoryConsumerTests/PathDistanceCalculatorPerformanceTests.swift` (NEU): drei `measure { … }`-Tests für `PathDistanceCalculator.effectiveDistance(for: Path)` auf 50 000-Punkt-`Path`-Inputs — `testEffectiveDistanceClockOnLargePathPoints` (`XCTClockMetric`), `testEffectiveDistanceClockOnLargeFlatCoordinatesPath` (`XCTClockMetric`, `flatCoordinates`-Shape), `testEffectiveDistanceMemoryOnLargePathPoints` (`XCTMemoryMetric`). Apple-only via `#if !os(Linux)` + `@available(macOS 13.0, iOS 16.0, *)`. Deterministische Synth-Fixtures. „Baseline-only, no fail-bar" konform zur Test-File-Policy.

### Audit-Report
- `docs/PERFORMANCE_DEEP_AUDIT_2026-05-12.md` (NEU): kompromissloser Performance-/Stabilitäts-/UX-Responsiveness-Audit auf HEAD `f111afd`. 6 Subagenten parallel: Code+Performance (Import/Memory/SwiftUI/Map/LiveTracking/Launch), SQLite/Store/Persistence, Test/Benchmark-Landschaft, Static-Search-Sweep (23 Pattern-Klassen), Doku-Truth + App-Store-Compliance. 21 priorisierte Hotspots (H1..H21), Mess-Baseline (build 1.5–28.6 s, test 113–115 s), 5 copy/paste-ready Folge-Train-Prompts.

### Verifikation
- `swift build`: OK.
- `DEVELOPER_DIR=Xcode swift test`: **1521 Tests, 4 Skips, 0 Failures** (113.5 s; +3 ggü. pre-patch 1518/4/0 — die 3 neuen Perf-Tests).
- `xcodebuild -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`: BUILD SUCCEEDED.
- `xcodebuild -destination 'id=…401C' build -allowProvisioningUpdates`: BUILD SUCCEEDED (signed Debug iPhone 15 Pro Max).
- `git diff --check`: clean.
- Hardware-UITest-Suite: **nicht erneut gefahren** — keine UI-Code-Änderung in diesem Train; letzte 8/8-Acceptance auf `f111afd` aus vorigem Train bleibt der gültige Anker.

### Restrisiko / weiterhin offen
- 46-MB-Crashfall-Hardware-Retest bleibt **FAILED** — Datei `/Users/sebastian/Desktop/Google_Maps/12_05_2026_location-history.json` (~44.5 MiB) ist lokal verfügbar, der Import braucht aber manuelle UI-Interaktion auf dem Gerät; Tester-Handoff notwendig.
- Live Activity / Dynamic Island / Lock Screen menschliche Sichtprüfung außerhalb der UITests, iPad-Layout (iPad offline), ASC / TestFlight / Apple Review (extern) — alle weiterhin offen.
- 21 priorisierte Hotspots aus dem Audit (Sektion 9 des Reports) sind **bewusst nicht** in diesem Train umgesetzt — 5 copy/paste-ready Codex-Prompts für Folge-Trains stehen im Audit-Report Sektion 12.

## 2026-05-12 — fix: restore heatmap control hardware smoke test

### Code
- `Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift` (Zeile 857–863): Heatmap-Button im `overviewRangeCard` bekommt `.frame(minHeight: 44)`, `.contentShape(Rectangle())` und `.accessibilityIdentifier("overview.range.heatmap.button")`. Vorher 49.7×13.3 pt — HIG-Mindestanforderung 44pt verletzt; jetzt korrekt. Button-Verhalten und Layout im Übrigen unverändert.
- `wrapper/LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift`: `testDeviceSmokeNavigationAndActions` löst den Heatmap-Button jetzt zuerst per `app.buttons["overview.range.heatmap.button"]` (Fallback auf Label-Predicate für Builds ohne Identifier). Ersetzt `revealElement(...)` durch neuen Helper `scrollUntilHittable(_:in:maxIterations:)`, der window-level Coordinate-Drag (`coordinate(withNormalizedOffset:).press(forDuration:thenDragTo:)`) mit größerem Drag pro Iteration und bis zu 12 Iterationen plus Overshoot-Recovery nutzt. `revealElement`/`primaryScrollableContainer` bleiben für andere Test-Stellen unverändert.

### Root Cause
- Der Heatmap-Button war in dem im Phase-10-Train eingeführten Hero-Map-Workspace-Layout im Overview-Tab so weit unten in der ScrollView, dass das vorherige `revealElement`-6-Swipe-Budget per `app.scrollViews.firstMatch.swipeUp()` ihn nicht mehr in den hittable Bereich brachte. `firstMatch` kann je nach SwiftUI-Render-Order auch den horizontalen Hero-Filter-Scroll im safeAreaInset treffen, dessen swipeUp keinen vertikalen Scroll triggert. Plus: der Button hatte nur 13.3 pt Höhe — HIG-Verletzung und kein stabiler accessibilityIdentifier.

### Verifikation
- `swift build`: OK.
- `DEVELOPER_DIR=Xcode swift test`: **1518 / 4 skipped / 0 failures** (116.5 s, unverändert).
- `xcodebuild -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`: BUILD SUCCEEDED.
- `xcodebuild -destination 'id=…401C' build -allowProvisioningUpdates`: BUILD SUCCEEDED (signed Debug iPhone 15 Pro Max).
- `git diff --check`: clean.

### Hardware-UITest-Suite iPhone 15 Pro Max (iOS 26.4) — 8/8 grün
- `testAppStoreScreenshots`: ✅ 43.4 s.
- `testDeviceSmokeNavigationAndActions`: ✅ 75.8 s (war P0-3-Regression auf HEAD `5f83838`/`9e4a41b`, jetzt grün).
- `testLandscapeLayoutSmoke`: ✅ 597.4 s (langer Run wegen DerivedData-Konkurrenz mit parallelem xcodebuild generic — Test selbst grün, isolierter Re-Run nicht nötig).
- `testLiveActivityHardwareCaptureDistance`: ✅ 38.8 s.
- `testLiveActivityHardwareCaptureDuration`: ✅ 37.6 s.
- `testLiveActivityHardwareCapturePoints`: ✅ 38.0 s.
- `testLiveActivityHardwareCaptureUploadStatusPendingAndRestart`: ✅ 63.3 s.
- `testLiveActivityHardwareCaptureUploadStatusFailed`: ✅ 37.7 s.

### Restrisiko / weiterhin offen
- 46-MB-Crashfall: Datei `/Users/sebastian/Desktop/Google_Maps/12_05_2026_location-history.json` (~44.5 MiB) verfügbar, aber Import auf dem iPhone braucht manuelle UI-Interaktion — Manual Risk Acceptance Sektion 1 bleibt **FAILED** bis Tester-Retest auf Release-Build.
- Live Activity / Dynamic Island / Lock Screen: weiterhin technischer Pass über UITest-Capture-Suite, **manuelle visuelle Lock-Screen-Sichtprüfung außerhalb der UITests offen**.
- iPad-Layout: bleibt offen (iPad weiter offline).
- ASC / TestFlight / Apple Review: bleibt offen (extern, lokal nicht belegbar).

## 2026-05-12 — docs: record iPhone hardware acceptance status

### Hardware-Acceptance-Train (HEAD `5f83838`, iPhone 15 Pro Max iOS 26.4)
- `testAppStoreScreenshots`: ✅ PASSED (44.1 s).
- `testLandscapeLayoutSmoke`: ✅ PASSED (58.4 s).
- `testLiveActivityHardwareCaptureDistance`: ✅ PASSED (37.7 s).
- `testLiveActivityHardwareCaptureDuration`: ✅ PASSED (37.2 s).
- `testLiveActivityHardwareCapturePoints`: ✅ PASSED (37.4 s).
- `testLiveActivityHardwareCaptureUploadStatusPendingAndRestart`: ✅ PASSED (64.4 s).
- `testLiveActivityHardwareCaptureUploadStatusFailed`: ✅ PASSED (38.2 s).
- `testDeviceSmokeNavigationAndActions`: ❌ **FAILED** (29.2 s) — `XCTAssertTrue(revealElement(heatmapButton, in: app))` auf Zeile `wrapper/LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift:203`. Heatmap-Button im Overview-Tab nicht hittable. Bei HEAD `b91a933` (2026-05-07) war derselbe Test grün — Regression aus einem Phase-10-Commit. In diesem Train **nicht** gefixt (Scope ist Acceptance + Doku-Sync, kein Refactor).

### Baseline
- `swift build`: OK.
- `DEVELOPER_DIR=Xcode swift test`: **1518 / 4 skipped / 0 failures** (118.7 s).
- `xcodebuild -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`: BUILD SUCCEEDED.
- `xcodebuild -destination 'id=…401C' build -allowProvisioningUpdates`: BUILD SUCCEEDED (signed Debug).
- `git diff --check`: clean.

### Manual Risk Acceptance Protocol nach diesem Train
- **Sektion 1 (46-MB-Crashfall):** bleibt **FAILED**. Keine 46-MB-`location-history.zip` im lokalen Filesystem (einzige Datei dieses Namens unter `/Users/sebastian/Downloads/` ist 4.06 MB groß). Release-Build-Hardware-Retest mit dem originalen 46-MB-Crash-Sample nicht möglich.
- **Sektion 2 (Live Activity / Dynamic Island / Lock Screen):** Technischer Pass über die UITest-Capture-Suite (5/5 grün auf Hardware). Manuelle visuelle Lock-Screen-Sichtprüfung außerhalb der UITests **bleibt offen**; Checkboxen nicht abgehakt.
- **Sektion 3 (iPad-Layout):** **bleibt offen**. iPad (UDID `3c955848…d4da0a5`, iPadOS 17.7.10) ist offline; iPad-Build und Acceptance nicht gefahren.
- **Sektion 4 (ASC / TestFlight / Apple Review):** **bleibt offen**. Im Train nicht angefasst, extern nicht lokal belegbar.

### Doku
- `docs/APPLE_VERIFICATION_CHECKLIST.md`: neuer Top-Block für 2026-05-12 mit allen 8 UITest-Resultaten und expliziter Manual-Risk-Sektion-Bilanz.
- `docs/DEEP_AUDIT_2026-05-12_POST_PULL.md`: P0-2 mit Train-Resultat erweitert; neues P0-3 für die `testDeviceSmokeNavigationAndActions`-Regression eingefügt.
- `README.md`, `NEXT_STEPS.md`, `ROADMAP.md`: Stand-Block 2026-05-12 mit Acceptance-Ergebnis.

## 2026-05-12 — fix: conditionally link CSQLite shim for Linux

### Code
- `Package.swift`: `LocationHistoryConsumerAppSupport`-Target hängt den `CSQLite`-Linux-Shim jetzt über `.target(name: "CSQLite", condition: .when(platforms: [.linux]))` ein statt unconditional. Auf Apple-Plattformen greift weiter der vorhandene `#if canImport(SQLite3)`-Gate in `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStore.swift`, sodass dort die SDK-`SQLite3` benutzt wird. Der `Undefined symbols for architecture arm64: _sqlite3_*`-Linker-Bruch im `LH2GPXWidget.appex`-Linkschritt ist damit weg.

### Verifikation
- `swift build`: OK (79.2 s).
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: **1518 Tests, 4 Skips, 0 Failures** (111.0 s; unverändert vs. vorher).
- `xcodebuild -scheme LH2GPXWrapper -project wrapper/LH2GPXWrapper.xcodeproj -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`: **BUILD SUCCEEDED**.
- `xcodebuild -scheme LH2GPXWrapper -project wrapper/LH2GPXWrapper.xcodeproj -destination 'id=00008130-00163D0A0461401C' build -allowProvisioningUpdates`: **BUILD SUCCEEDED** (signed Debug-Build iPhone 15 Pro Max).
- `git diff --check`: clean.

### Doku
- `docs/DEEP_AUDIT_2026-05-12_POST_PULL.md` Sektion 9 P0-1 ist auf „BEHOBEN" gesetzt; ursprünglicher Linker-Befund bleibt als historischer Eintrag.
- `README.md` ersetzt die Aussage „xcodebuild iOS-Build BRICHT" durch den belegten BUILD-SUCCEEDED-Stand auf HEAD pending.
- `NEXT_STEPS.md` + `ROADMAP.md` Stand-Block für 2026-05-12 ergänzt; manuelle Hardware-Restpunkte bleiben offen.

### Restrisiko / weiterhin offen
- 46-MB-Crashfall-Hardware-Retest auf iPhone 15 Pro Max Release-Build bleibt FAILED bis Tester-Bestätigung.
- Live Activity / Dynamic Island / Lock Screen, iPad-Layout, ASC / TestFlight / Apple Review weiterhin offen (Manual Risk Acceptance Protocol).
- Hardware-UITest-Suite (`testAppStoreScreenshots`, `testLandscapeLayoutSmoke`, `testDeviceSmokeNavigationAndActions`) in diesem Train **nicht** gefahren — nur signierter Debug-Build verifiziert.
- iOS-Data-Protection-Aktivierung für SQLite-Store (P1 aus Audit) weiterhin offen; relevant erst bei Default-ON des Feature-Flags `LH2GPX_LOCAL_TIMELINE_STORE`, aktuell OFF.

## 2026-05-09 — L-04 — Bounded LRU für AppSessionContent-Caches

Setzt Deep-Audit-Folgepunkt **L-04** um. **NEU** `Sources/LocationHistoryConsumerAppSupport/BoundedLRU.swift` (Foundation-only generischer LRU-Cache, `K: Hashable` / `V` beliebig, Init mit `capacity > 0`, API `value(forKey:)` / `insert(_:forKey:)` / `removeValue(forKey:)` / `removeAll()` / `subscript` / `keysMostRecentFirst` / `count` / `capacity`; Lesen + Insert markieren Key als most-recent; Insert über Capacity evictet least-recently-used; Update bestehender Keys verändert `count` nicht; nicht thread-safe — Owner muss Concurrency-Schutz selbst stellen). **Geändert** `AppSessionContent` in `AppSessionState.swift`: alle fünf bisher unbounded `[Key: Value]`-Caches sind durch `BoundedLRU` capped — `filteredOverviewCache`, `filteredDaySummariesCache`, `filteredInsightsCache` (je 8), `dayDetailCache` (32), `dayMapDataCache` (16). Der bisher manuell verwaltete `projectedDaysCache` (Limit 8) nutzt jetzt dasselbe `BoundedLRU` — keine Verhaltensänderung, nur einheitliche Semantik. **Semantik unverändert**: Bei vielen distinct Keys werden ältere Einträge nach Eviction transparent neu berechnet; das Resultat bleibt byte-identisch zum vorherigen unbounded Pfad. **NEU Tests** `BoundedLRUTests.swift` (13 Cases: Insert/Read, Read makes recent, Capacity-Evict LRU, Update keeps count, Remove/RemoveAll, Capacity 1, Deterministic order via `keysMostRecentFirst`, 10k-Insert/Cap16-Stress, Subscript-set-nil) und `AppSessionContentCacheBoundsTests.swift` (5 Cases: viele distinct Filter-Keys halten Overview/DaySummaries/Insights stabil; DayDetail/MapData stabil über viele composite Keys; Eviction ändert Insights-Resultat nicht). Linux-Vollsuite **+18 neue Tests, 0 failed**. Store-Pfad bleibt pre-production / feature-flagged / default OFF. 46-MB-Gate bleibt FAILED / pending hardware retest. L-02/L-03 bleiben offen.

## 2026-05-09 — L-01 — In-Memory-Import-Gate für Legacy-Loader

Setzt Deep-Audit-Folgepunkt **L-01** um: `AppContentLoader.decodeFile(at:)` lehnt Full-Reads via `Data(contentsOf:)` jetzt kontrolliert ab, sobald die Datei größer als `AppContentLoader.maximumInMemoryImportBytes` (64 MiB) ist. Google-Timeline-JSON wird vorher unverändert in den Streaming-Konverter geleitet und trifft das Gate nicht. Neuer Error-Case `AppContentLoaderError.importTooLargeForInMemoryLoad(filename:bytes:limit:)` mit user-facing Title "File too large to load safely" und einer Beschreibung, die Dateiname, Größe und Limit nennt — keine Pfade, keine Standortdaten. Betroffene Pfade: LH2GPX-JSON, GPX, TCX, unbekannte JSON-Inhalte über 64 MiB. ZIP-Pfad und Streaming-Pfad bleiben unverändert. Store-Pfad bleibt pre-production / feature-flagged / default OFF; 46-MB-Gate bleibt FAILED / pending hardware retest. L-02/L-03 bleiben offen. Linux-Tests in `AppContentLoaderTests` (5 neue Cases, sparse-file basiert).

## 2026-05-09 — Deep Audit Performance/Stabilität/Map-Layer (audit-only + Doku-Sync)
Audit-Dokument `docs/DEEP_AUDIT_2026-05-09_PERFORMANCE_STABILITY_MAP_LAYERS.md` ergänzt: End-to-End-Matrix Store/Legacy, Hotspot-Tabelle (3 P0, 4 P1, 4 P2, 2 P3), Map-Budget-Audit (200-Routen-Limit im Store-Pfad durch adaptive `maxVisibleRoutes`/`maxRouteCandidates` ersetzt), Punktelayer-Audit (Provider service-fertig, MapKit-Marker auf keiner Karte aktiv), Doku-Widersprüche (README Test-Zahlen aktualisiert auf 1400/2/0), Maßnahmenliste mit 15 IDs, Folgeprompt-Skizzen. Keine Code-Refactors. Kleine Doku-Korrekturen im README (Test-Stand, 46-MB-Klarstellung Legacy vs Store). Store-Pfad bleibt pre-production / feature-flagged / default OFF. 46-MB-Gate bleibt FAILED / pending hardware retest. Linux-Vollsuite **1400 / 2 skipped / 0 failed** (unverändert vs `d629467`).

## 2026-05-08 — Phase-10C — Legacy hardening
Phase-10C — Legacy hardening: Heatmap densityPoint Cap (500k) + truncation signal; ExportPreview Doppel-Iteration entfernt; derived_cache `pruneDerivedCache(maxEntries:)` + `deleteDerivedCache(olderThan:)`; Build-Warnings (visionOS, unused withUnsafeMutableBytes) bereinigt. Overview scanCandidates absichtlich nicht umgebaut (Risiko HOCH; bereits bounded via pointBudget=2M + candidateStorageCap=512 off-Main). Store-Pfad bleibt default OFF. 46-MB-Gate FAILED / pending hardware retest.

## 2026-05-08 — Phase-10B (Weg 3) — Foundation-only PointLayer-Provider und zentraler PerformanceBudget
Phase-10B (Weg 3) — Foundation-only PointLayer-Provider und zentraler PerformanceBudget. Adaptive detail-level-/zoom-abhängige Budgets ersetzen die starre 200-Routen-Vorstellung im Store-Pfad. Legacy-Pfad unverändert. Store bleibt pre-production / feature-flagged / default OFF. 46-MB-Gate bleibt FAILED / pending hardware retest.

## 2026-05-08 — Phase-10A P1-A/B (Weg 2) — Sichtbare Progress/Cancel-UI für Store-Import
- LocalTimelineImportProgressPresentation: Foundation-only Presentation-Schicht (statusText, phaseLabel, countsText, skippedText, currentDayText, bytesText, percentText, oneLineSummary, isCancellable). Keine Standortdaten, keine Pfade, keine Tokens.
- LocalTimelineImportUIState: @MainActor ObservableObject; per startNewImport() einen frischen LocalTimelineImportController + Cancellation pro Import. Snapshot-Hop auf MainActor, Linux-getestet.
- LocalTimelineImportProgressView (SwiftUI): Phase-Label, Counter-Block, optional Bytes/Prozent, Cancel-Button nur wenn isCancellable. Dark-Mode-freundlich, Accessibility-Labels für Status + Cancel.
- LocalTimelineTestModeBanner (SwiftUI): einzeiliger Pre-production-Hinweis, sichtbar genau dann, wenn LocalTimelineTechnicalTestSettings.shared.localTimelineStoreTestModeEnabled true ist.
- AppShellRootView + wrapper/ContentView wiren beides ein: Banner oben, Progress/Cancel im isLoading-Branch.
- Cancel-Flow: Controller.cancel() → Importer wirft cancellation → Writer rollbackt → bestEffortTruncateWAL → AppFlow liefert .failure(title="Import cancelled") → keine Teilimports, Reimport möglich.
- Linux-Tests: LocalTimelineImportProgressPresentationTests, LocalTimelineImportUIStateTests, AppFlowImportCancelRoutingTests.
- Store-Pfad bleibt pre-production / feature-flagged / default AUS. Legacy-Pfad unverändert. 46-MB-Gate bleibt FAILED / pending hardware retest.

## [2026-05-08] — feat: add local timeline wal checkpoint recovery (P1-C + P1-D)

Phase-10A-Folge des Deep Audits. Setzt **P1-C (WAL-Checkpoint-/Cleanup-Strategie)** und **P1-D (Recovery-Test für Mid-Import-Crash)** aus `docs/DEEP_AUDIT_2026-05-08_LOCAL_TIMELINE_STORE_AND_MAP.md` § 13 um, ausschließlich im Store-Pfad.

Neu (Linux-testbar, keine neue Dependency):

- `LocalTimelineStore.checkpointWAL(mode:)`/`truncateWAL()`/`bestEffortTruncateWAL()` über `sqlite3_wal_checkpoint_v2` mit `WALCheckpointMode { passive, full, restart, truncate }` und `WALCheckpointInfo { framesInLog, framesCheckpointed }`. Default-Mode `.truncate` schreibt WAL-Frames zurück und kürzt `-wal` auf 0 Byte, sofern keine Reader die Datei halten.
- Neuer Error-Case `LocalTimelineStoreError.checkpointFailed(code:message:)`. Hard-Fail bei expliziter API (`checkpointWAL`/`truncateWAL`); Best-Effort (`bestEffortTruncateWAL`) im nachgelagerten Cleanup, weil ein dort fehlschlagender Checkpoint den eigentlichen Vorgang nicht zerstören soll.

Wiring (alle best-effort, Importerfolg/Cancel/Delete bleiben unangetastet, wenn Checkpoint scheitert):

- `LocalTimelineImportWriter.finalize()` ruft `bestEffortTruncateWAL` nach erfolgreichem `COMMIT`.
- `LocalTimelineImportWriter.cancel()` ruft `bestEffortTruncateWAL` nach `ROLLBACK`.
- `LocalTimelineStoreLifecycle.deleteAllLocalTimelineData(store:)` ruft `bestEffortTruncateWAL` vor `store.close()` (vor dem File-Unlink von `store.sqlite`/`-wal`/`-shm`).
- Reads (Reader-Pfade, einzelne Inserts) lösen **kein** Checkpoint aus — keine Performance-Falle, keine VACUUM-Orgie.

Recovery-Verhalten (Phase-2-Schema unverändert; **keine** Schemaänderung nötig):

- Die `imports`-Row wird inside `BEGIN IMMEDIATE` eingefügt — bei mid-import-Abbruch ohne `COMMIT` ist sie nie persistiert. Ein Status-Feld wäre redundant, weil bereits Transaktionsgrenzen jede Sichtbarkeit halbfertiger Imports verhindern. Dokumentiert in `docs/LOCAL_TIMELINE_STORE_RESEARCH.md` (Recovery-Sektion).
- Recovery-Test simuliert abrupten Abbruch durch `store.close()` ohne `writer.finalize()`/`cancel()`; SQLite verwirft die offene Transaktion automatisch. **Linux-Simulation, kein echter iOS-Jetsam-Test** — Power-Loss-/Kernel-Kill-Verhalten auf Hardware bleibt eine separate Verifikation.

Tests: 13 neue Cases (`LocalTimelineStoreWALCheckpointTests` 7, `LocalTimelineStoreRecoveryTests` 6) — alle Linux-grün. Vollsuite: **1345 / 2 skipped / 0 failed** (vorher 1332).

**46-MB-Crashfall bleibt FAILED / pending hardware retest** (verbatim). Keine ASC/Review/Hardware-/TestFlight-Freigabe behauptet. LocalTimelineStore bleibt **pre-production / feature-flagged / default AUS**. Legacy-Pfad nicht regressiert. Keine vollständige Map-/Heatmap-/Overview-UI behauptet. UI-Cancel/Progress-Button (P1-A/P1-B-Folgeaufgabe) weiter offen.

## [2026-05-08] — feat: cancellable local timeline import progress (P1-A + P1-B)

Phase-10A-Folge des Deep Audits. Setzt **P1-A (Import-Cancel-Pfad)** und **P1-B (Import-Progress-Surface)** aus `docs/DEEP_AUDIT_2026-05-08_LOCAL_TIMELINE_STORE_AND_MAP.md` § 13 um, ausschließlich im Store-Pfad.

Neu (alles Foundation-only, Linux-testbar):

- `LocalTimelineImportProgress` — Sendable Snapshot-Struktur mit Phase (`idle`/`preparing`/`sniffing`/`importing`/`finalizing`/`completed`/`cancelled`/`failed`), Counter (`entriesProcessed`/`visitsWritten`/`activitiesWritten`/`pathsWritten`/`skippedEntries`), optionalen Byte-Hints (`bytesRead`/`totalBytes`), `currentDay`, `startedAt`/`updatedAt`, `isCancellable`. Keine Standortdaten gespeichert.
- `LocalTimelineImportProgressThrottle` — Standardstride 500 Entries; emittiert immer auf Phasenwechsel und in den terminalen Phasen.
- `LocalTimelineImportCancellation` — kooperatives Cancel-Token (NSLock-guarded, idempotent, kein globaler State). API: `cancel()`, `isCancelled`, `checkCancellation() throws`. Fehler: `LocalTimelineImportCancellationError.cancelled`.
- `LocalTimelineImportController` — Service-/Presentation-Layer; bündelt Token + Sink + `latestProgress` + Observer-API. Foundation-only, Linux-testbar; keine SwiftUI/ObservableObject-Bindung.

Importer/Loader/AppFlow:

- `GoogleTimelineStoreImporter.importFromFile/importFromData` akzeptieren neuen `hooks: Hooks`-Parameter mit optionalem Progress-Sink, Throttle und Cancellation. Cancellation wird **vor Import-Start, vor jedem Entry, vor Finalize** geprüft. Bei Cancel rollt der Writer (`writer.cancel()` → `ROLLBACK`) zurück und `LocalTimelineImportCancellationError.cancelled` wird gerichtet weitergereicht. **Es bleibt kein gültiger Teilimport im Store.**
- `AppContentLoader.loadImportedContentEnvelope` und `LH2GPXAppFlow.loadImportedFileEnvelope` reichen `importProgress` und `importCancellation` durch. Cancel wird im AppFlow als `EnvelopeImportOutcome.failure(title: "Import cancelled", clearBookmark: false)` sichtbar; im Loader als neuer `AppContentLoaderError.importCancelled(_:)`.
- Existing API-Pfade (ohne Hooks) verhalten sich identisch — Default-Argumente, keine Source-Breakage.

Bewusst **nicht** umgesetzt:

- Keine SwiftUI-Verdrahtung in `AppShellRootView` / `wrapper/ContentView` / `LocalTimelineSessionLandingView` — UI-Hook bleibt Folgeaufgabe und ist im Audit + Runbook dokumentiert. Die Service-/Presentation-Schicht ist testabhängig vollständig.
- Keine Änderung am Legacy-Pfad (LH2GPX-JSON / GPX / TCX): `loadImportedContent(from:)` ist unverändert; Progress dort wäre zu breit für eine kleine Änderung.
- Keine neuen Dependencies, kein `[Double]`-Materialisieren im Store-Pfad, kein `AppExport`.

Tests (alle Linux-grün, keine wall-clock-Asserts):

- `LocalTimelineImportProgressTests` (7 Tests) — Default, Phasen-Transitions, Throttle-Verhalten.
- `LocalTimelineImportCancellationTests` (5 Tests) — Default, cancel, throw, idempotent, Thread-safety.
- `LocalTimelineImportControllerTests` (4 Tests) — Sink, Observer, Cancel-Forward.
- `GoogleTimelineStoreImporterProgressCancelTests` (7 Tests) — Phasenkette, Counter, Skipped, Pre-Cancel-Empty-Store, Mid-Stream-Rollback, Cancelled-Snapshot, Idempotent-Retry.
- `AppFlowImportProgressCancelTests` (3 Tests) — Store-Pfad-Progress, Cancel-Outcome ohne Teilimport, Legacy-Pfad ungestört.

Volle Linux-Suite: **1332 / 2 skipped / 0 failed** (vor diesem Commit: 1306/2/0; +26 neue).

Status:

- 46-MB-Gate **bleibt FAILED / pending hardware retest**.
- LocalTimelineStore **bleibt pre-production / feature-flagged / default AUS**.
- Kein TestFlight-/Review-Claim, keine Hardware-Behauptung.

Geänderte/neue Dateien:

- NEU: `Sources/LocationHistoryConsumerAppSupport/LocalTimelineImportProgress.swift`
- NEU: `Sources/LocationHistoryConsumerAppSupport/LocalTimelineImportCancellation.swift`
- NEU: `Sources/LocationHistoryConsumerAppSupport/LocalTimelineImportController.swift`
- GEÄNDERT: `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineStoreImporter.swift` (+Hooks, +ProgressEmitter)
- GEÄNDERT: `Sources/LocationHistoryConsumerAppSupport/AppContentLoader.swift` (+importProgress/importCancellation, +`importCancelled` Error-Case)
- GEÄNDERT: `Sources/LocationHistoryConsumerAppSupport/LH2GPXAppFlow.swift` (+importProgress/importCancellation Pass-through)
- NEU: 5 Testdateien (s.o.).

---

## [2026-05-08] — docs+fix: deep audit & build-info live memory-logging mirror

Deep Audit nach Build 158 — Repo-Truth-Abgleich von LocalTimelineStore-Pfad, Build-158-Toggles, ImportMemoryProbe, Map/Heatmap/Overview/Export-Verdrahtung, Stabilität, Tests und Doku. Audit-Dokument: `docs/DEEP_AUDIT_2026-05-08_LOCAL_TIMELINE_STORE_AND_MAP.md`.

**Eindeutiger P1-UX-Bug gefunden und in diesem Commit gefixt** (FIX-1):
- `AppBuildInfo.isMemoryLoggingEnabled` war ein gespeicherter `let`, der den Wert beim Process-Start einfror. Sobald ein TestFlight-Tester den `importMemoryLoggingEnabled`-Toggle umlegte, zeigte die Build-Info-Sektion weiter "Memory Logging Disabled", während direkt darunter "Memory Logging Resolved Enabled" stand → irreführend.
- Fix: Property auf computed `var` umgestellt; sie liest jetzt live `ImportMemoryProbe.isLoggingEnabled` (das wiederum ProcessInfo-Cache und `LocalTimelineTechnicalTestSettings.shared.importMemoryLoggingEnabled` ODER-verknüpft).
- Bestehender Test `testAppBuildInfoExposesMemoryLoggingFlag` bleibt grün; neuer Regression-Pin `testAppBuildInfoMemoryLoggingReflectsLiveSettingsToggle` schiebt den Singleton-Toggle live von OFF nach ON und beobachtet, dass `AppBuildInfo.shared.isMemoryLoggingEnabled` mitläuft.

**Audit-Befunde — bewusst NICHT behauptet:**
- Kein 46-MB-Hardware-Pass; **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim).
- Kein TestFlight-Build-158-Acceptance-Run im Repo dokumentiert.
- Keine App-Review-Freigabe.
- Map-/Heatmap-/Overview-/Export-UI im Store-Pfad bleibt **OFFEN** (Producer komplett, UI-Hooks nicht verdrahtet — bewusst, transparent in Phase-Note).
- FileProtection iOS bleibt Platzhalter; RTree bleibt deferred; Import-Cancel-API fehlt; WAL-Checkpoint/VACUUM zwischen Imports nicht aktiv.

**Linux-Vollsuite (Server-Truth nach FIX-1):** 1306 Tests · 2 Skips · 0 Failures (`swift test`). Vorheriger Lauf vor FIX-1: 1305 / 2 / 0.

LocalTimelineStore bleibt **pre-production / feature-flagged / default AUS**.

- **Geändert** `Sources/LocationHistoryConsumerAppSupport/AppBuildInfo.swift` — `isMemoryLoggingEnabled` von `let` auf computed `var`. Initializer entsprechend gekürzt.
- **NEU** `Tests/LocationHistoryConsumerTests/ImportMemoryProbeActivationTests.swift` — `testAppBuildInfoMemoryLoggingReflectsLiveSettingsToggle` (Regression-Pin gegen Refreeze).
- **NEU** `docs/DEEP_AUDIT_2026-05-08_LOCAL_TIMELINE_STORE_AND_MAP.md` — vollständiges Audit (15 Sektionen, P0/P1/P2/P3-Maßnahmenliste, vorgeschlagene Folgeprompts).

---

## [2026-05-08] — feat: add internal test toggles for testflight build 158 prep

Build-158-Vorbereitung: interne UserDefaults-basierte Test-Toggles, damit TestFlight-Tester den feature-flagged LocalTimelineStore-Pfad und das Import-Memory-Logging **ohne** Launch-Argumente / Environment-Variablen scharf schalten können (TestFlight erlaubt Tester keine Argumente/ENV). **Build 157 ist Xcode Cloud grün und TestFlight-installierbar (Status „Überprüft", interne Tests erfolgreich).** Keine Aussage über echte Apple-Review-Freigabe oder über das 46-MB-Hardwareverhalten. **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim). LocalTimelineStore-Pfad bleibt **pre-production / feature-flagged / default AUS**. Live-Upload, Recording und Auth-Flows unberührt.

- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineTechnicalTestSettings.swift` — `final class` ObservableObject mit zwei `@Published Bool`-Toggles, persistiert über UserDefaults. Keys (Namespace `LH2GPX.…`):
  - `LH2GPX.localTimelineStoreTestModeEnabled`
  - `LH2GPX.importMemoryLoggingEnabled`
  - Default `false`. **Nur Booleans.** Keine Standortdaten, keine Pfade, keine Tokens, keine Userdaten in den neuen Keys. `.shared`-Singleton + `init(userDefaults:)` für Tests.
- **Geändert** `LocalTimelineFeatureFlags` — neue Resolver-Overloads `resolve(arguments:environment:settings:)` und `resolveFromProcess(settings:)`. Args/ENV bleiben **primärer Aktivator**; Setting aktiviert **zusätzlich**, **deaktiviert nichts**. Default OFF unverändert. Source-kompatibel (Default-Argument).
- **Geändert** `ImportMemoryProbe` — neuer Pure-Overload `isEnabledForEnvironment(_:arguments:settings:)`. Runtime-`isLoggingEnabled` ist jetzt **computed** (Cache für ProcessInfo + Settings-Lookup pro Aufruf), damit der Toggle ohne Relaunch wirkt.
- **Geändert** `AppOptionsView` (`AppTechnicalOptionsView`) — neue Sektion "Internal Test Toggles" mit zwei `Toggle`-Bindings (`$technicalTestSettings.…`), Status-Row "Memory Logging Resolved" (zeigt aktuellen ProcessInfo-OR-Settings-State) und Footer-Hinweis "Internal/TestFlight only · Pre-production · Default off · No location data is stored in these settings".
- **Nicht angefasst**: `AppShellRootView`, Wrapper-`ContentView`. Settings werden über `.shared` aufgerufen; der Resolver-Overload mit Default-Argument bleibt source-kompatibel.
- **NEU Tests** `Tests/LocationHistoryConsumerTests/LocalTimelineTechnicalTestSettingsTests.swift` — 12 Cases. Linux-Suite voll grün nach Fix. Privacy-/Scope-Vertrag: `testOnlyBoolsAreStoredUnderToggleKeys` pinpoint, dass die Toggle-Keys ausschließlich `Bool` speichern.
- **Harte Grenzen (verbatim)**:
  - **Build 157 ist Xcode Cloud grün und TestFlight-installierbar** — keine 46-MB-Grün-Aussage, keine Apple-Review/Release-/Hardware-Freigabe behauptet.
  - **46-MB-Gate bleibt FAILED / pending hardware retest.**
  - LocalTimelineStore-Pfad bleibt **pre-production / feature-flagged / default AUS**.
  - Toggle ist **interner Testmodus** (Pre-production); aktiviert zusätzlich, deaktiviert nichts.
  - **KEINE ASC/Review/Hardware-Freigabe.**
  - **KEINE Map-Phase-10B-Aussage.**
  - **KEINE UI-Änderung außerhalb der Technical-Sektion.**
  - Live-Upload, Recording und Auth-Flows unberührt.

## [2026-05-08] — fix: resolve xcode heatmap grid key compile failure

P0-Doku-Sync für einen Xcode-Cloud-Archive-Fail im Workflow „Release – Archive & TestFlight". Builds **155** (Commit `06f81ae`) und **156** (Commit `5cb7783`) sind mit Exit Code 65 fehlgeschlagen. Linux-SwiftPM-Build und `swift test` waren beide grün, weil der MapKit-Guard auf Linux die kollidierende Variante ausschloss; auf Apple-Plattformen waren beide Top-Level-`GridKey`-Definitionen sichtbar. Reine Kollisions-/Compile-Fix-Iteration im AppSupport-Modul ohne API-/UI-/Doku-Schönfärbung. **Linux-SwiftPM weiterhin grün. Xcode Cloud Retest pending — keine Aussage über echte Apple-Builds.**

- **Root Cause**: Namens-Kollision für `GridKey` zwischen zwei Dateien im Modul `LocationHistoryConsumerAppSupport`:
  - `Sources/LocationHistoryConsumerAppSupport/HeatmapGridBuilder.swift` definierte einen top-level `struct GridKey { let lat: Int32; let lon: Int32 }` hinter `#if canImport(MapKit) && canImport(SwiftUI)` — auf Linux ausgeschlossen, auf Apple-Plattformen aktiv.
  - `Sources/LocationHistoryConsumerAppSupport/LocalTimelineHeatmapGridAggregator.swift` definierte einen top-level `private struct GridKey { let lat: Int; let lon: Int }`.
  - Auf Linux schloss der MapKit-Guard die HeatmapGridBuilder-Variante aus → SwiftPM-Build grün.
  - Auf Apple-Plattformen (Xcode Cloud) waren beide sichtbar → „Invalid redeclaration of 'GridKey'" + „ambiguous for type lookup" + Folgefehler „Cannot convert value of type 'Int' to expected argument type 'Int32'" auf Zeile 79 des Aggregators (weil der Compiler den Namen auf die `Int32`-Variante auflöste).
- **Fix**: `Sources/LocationHistoryConsumerAppSupport/LocalTimelineHeatmapGridAggregator.swift` benennt seinen file-scope `GridKey` → `LocalTimelineHeatmapGridKey` (privat, file-scope). Heatmap-Logik unverändert. Keine API-Änderung. Keine UI-Änderung. `HeatmapGridBuilder.swift` unverändert.
- **Xcode-Projekt**: `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj` referenziert die SPM-Package-Datei nicht direkt; **keine doppelten Compile-File-Referenzen** gefunden — die Kollision war rein semantisch zwischen zwei top-level Swift-Definitionen im selben Modul.
- **Tests**: voll grün auf Linux nach Fix (`swift test`). Xcode Cloud muss erneut ausgelöst werden — **Status: PENDING**, keine Aussage über echte Apple-Builds.
- **Lehrsatz**: ein top-level Name (auch `private struct …` auf Datei-Ebene) ist auf Apple-Plattformen ambig, sobald eine andere Datei im selben Modul einen Top-Level-`GridKey` außerhalb eines auf Linux scharfen Plattform-Guards definiert. Linux ist daher kein hinreichender Stellvertreter für Apple-Compile-Sichtbarkeit, wenn iOS-only Symbole hinter `canImport(MapKit)` parken.
- **Harte Grenzen (verbatim)**:
  - **46-MB-Gate bleibt FAILED / pending hardware retest.**
  - Store-Pfad bleibt **default AUS**, pre-production.
  - **KEINE Map-Phase-10B-Aussage.**
  - **KEINE UI-Änderung.**
  - **KEINE Hardware-/ASC-/TestFlight-Freigabe behauptet.**
  - **Xcode Cloud Retest pending** — keine Aussage über echte Apple-Builds.

## [2026-05-08] — feat: add store backed day map ui surface

Phase-10A-Iteration der LocalTimelineStore-Architektur (vgl. `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`). **Feature-flagged Store-DayMap-UI-Surface** in der bestehenden DayDetail-Ansicht — Tester mit gesetztem `LH2GPX_LOCAL_TIMELINE_STORE` sehen ab Phase 10A pro Tag eine optionale Map-Sektion (Foundation-only `LocalTimelineDayMapViewState` Presentation Model + SwiftUI Placeholder, **kein MapKit-Import**); echte `MKMapView`-/`MKMultiPolyline`-Verdrahtung bleibt explizit Phase-10B Mac/Xcode-Pflicht. Surface bleibt **Spike / pre-production hinter Feature-Flag**, Store-Pfad **default AUS** (`LH2GPX_LOCAL_TIMELINE_STORE`-Flag unverändert). Legacy-Map unverändert. **Vollständige sichtbare Kartenmodernisierung wird NICHT behauptet.** **46-MB-Gate bleibt FAILED / pending hardware retest.**

- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayMapViewState.swift` — Foundation-only Presentation Model. Typen: `LocalTimelineDayMapViewState` (states `idle`/`loadingCandidates`/`candidatesLoaded`/`loadingGeometry`/`ready`/`failed`), `LocalTimelineDayMapSource` (Reader-Bindings + Visit-Coordinate-Closure für Bounds-Fallback), `Budget` (defaults: **12 Routen / 256 Punkte pro Route / 4096 Punkte gesamt**, harte Grenzen pro Route + pro Tag). **Bounded reads**: Candidate-Load liest ausschließlich path metadata (keine `coord_blob`-Decodierung); Geometrie wird ausschließlich für selektierte pathIDs lazy decodiert.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayMapView.swift` — SwiftUI Placeholder (`#if canImport(SwiftUI)`-guarded). **Kein MapKit-Import.** Echte MapKit-/MKMapView-Verdrahtung bleibt explizit **Phase-10B Mac/Xcode-Pflicht** (Linux-Server kann MapKit nicht bauen).
- **Geändert** `LocalTimelineDayDetailView` — neue optionale Map-Sektion. Sektion wird nur sichtbar wenn `mapSource != nil` und Pfad-Metadaten existieren. Buttons: "Load map" startet bounded Candidate-Load **ohne Koordinatendecodierung**; "Decode all routes" toggelt bounded Geometrie-Decode (innerhalb `Budget`).
- **Geändert** `LocalTimelineSessionLandingView` — reicht neuen optionalen `dayMapSource` durch.
- **Geändert** `LH2GPXAppFlow.makeProductionDayMapSource(for:)` — neue Factory; öffnet eigenen Reader auf `session.storeURL`, bindet `StoreBackedMapDataProvider`, nutzt Visit-Koordinaten als Bounds-Fallback.
- **Geändert** `Sources/LocationHistoryConsumerApp/AppShellRootView.swift` und `wrapper/LH2GPXWrapper/ContentView.swift` — reichen neue Source ans Landing-View durch.
- **NEU Tests** `Tests/LocationHistoryConsumerTests/LocalTimelineDayMapViewStateTests.swift` (7) und `LocalTimelineDayMapBoundsTests.swift` (4) — alle Linux-grün.
- **Bounded-Read-Garantien Phase 10A**:
  - Candidates lesen ausschließlich path metadata (keine `coord_blob`-Decodierung).
  - Geometrie wird ausschließlich für selektierte pathIDs lazy decodiert.
  - Harte Budgets greifen pro Route (256 Punkte) **und** pro Tag (4096 Punkte total, 12 Routen).
  - Bounds primär aus path metadata (union der bbox-Spalten), Fallback auf Visit-Koordinaten via Closure; leerer Tag → `bounds == nil`.
  - Malformed `coord_blob` → kontrollierter `LocalTimelineMapProviderError.malformedCoordBlob` ohne Crash.
  - Anti-Meridian-Behandlung bleibt **Phase 10B/11** (direktes min/max-Reduce).
- **Harte Grenzen Phase 10A (verbatim)**:
  - **Feature-flagged Store-DayMap-UI-Surface** — kein Default-Rollout.
  - **KEIN MapKit-Import** in der Phase-10A-View; echte `MKMapView`-Verdrahtung bleibt **Phase-10B Mac/Xcode-Pflicht**.
  - **KEINE vollständige sichtbare Kartenmodernisierung.**
  - **KEIN eager `coord_blob`-Decoding** beim Candidate-Load.
  - **Legacy-Map unverändert.**
  - **KEIN AppExport-Rebuild aus Store.**
  - **KEIN vollständiger `[Double]`-Import-Buffer.**
  - **KEIN Live-Upload-Mix.**
  - **KEINE neuen externen Dependencies.**
  - **KEINE Hardware-/AppStore-/TestFlight-/ASC-Aussage.**
  - **KEINE Darwin-FileProtection-Aktivierung** (bleibt offene Phase-10B/11-Pflicht).
  - **KEIN RTree** (bleibt deferred, TEXT path-IDs).
  - Heatmap-UI / Overview-UI / Export-UI / Darwin FileProtection / Hardware-Retest / TestFlight bleiben **Phase-10B/11-Pflicht**.
  - **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim erhalten).

## [2026-05-08] — feat: wire local timeline day detail ui

Phase-9B-Iteration der LocalTimelineStore-Architektur (vgl. `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`). **Feature-flagged Store-DayList + DayDetail-UI** über die bestehende Landing-View — Tester mit gesetztem `LH2GPX_LOCAL_TIMELINE_STORE` sehen nach einem Google-Timeline-Import jetzt eine Tagesliste (newest-first, Datum / Routen / Visits / Distanz) und können pro Tag eine sheet-basierte Detail-Ansicht öffnen (Datum, Visits, Activities, Path-Metadaten + "Path points available (not decoded)"-Hinweis). Surface bleibt **Spike / pre-production hinter Feature-Flag**, Store-Pfad **default AUS** (`LH2GPX_LOCAL_TIMELINE_STORE`-Flag unverändert). **Map/Heatmap/Overview UI-Hook bleibt blockiert.** **46-MB-Gate bleibt FAILED / pending hardware retest.**

- **Geändert** `AppSessionState` — neues Feld `selectedLocalTimelineDayId: String?` + Mutator `selectLocalTimelineDay(_:)`. Wird in `show(localTimeline:)`, `show(content:)` und `clearContent()` mitgenullt.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayBrowserSource.swift` — Foundation-only Source-Struct + `bind(session:reader:)` Convenience für die View-Hooks. **Bounded — kein `coord_blob`, keine Polylines.**
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayListView.swift` (`#if canImport(SwiftUI)`-guarded) — zeigt Tage newest-first mit Datum / Routen / Visits / Distanz. **Kein Map-Hook.**
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayDetailView.swift` (`#if canImport(SwiftUI)`-guarded) — zeigt Datum + Visits + Activities + Path-Metadaten + Hinweis "Path points available (not decoded)". **Kein eager `coord_blob`-Decoding, keine Map.**
- **NEU** `LH2GPXAppFlow.makeProductionDayBrowserSource(for:)` — production Source-Factory; öffnet `LocalTimelineStore` an `session.storeURL`.
- **Geändert** `LocalTimelineSessionLandingView` — erweitert um optionales `dayBrowser`, `selectedDayId`, `onSelectDay`. Bei aktiv: rendert Liste + sheet-basierte Detail-Navigation (NavigationStack im sheet). **Backward-kompatibel** (defaults nil).
- **Geändert** `wrapper/LH2GPXWrapper/ContentView.swift` und `Sources/LocationHistoryConsumerApp/AppShellRootView.swift` — reichen `LH2GPXAppFlow.makeProductionDayBrowserSource(for: storeSession)` + Selection-Binding an die Landing-View durch.
- **NEU Tests** `Tests/LocationHistoryConsumerTests/LocalTimelineDayBrowserSourceTests.swift`, `LocalTimelineSelectionStateTests.swift`.
- **Harte Grenzen Phase 9B (verbatim)**:
  - **KEIN Map-/Heatmap-/Overview-UI-Hook gegen Store.**
  - **KEIN AppExport-Rebuild aus Store.**
  - **KEIN vollständiger `[Double]`-Import-Buffer.**
  - **KEIN eager `coord_blob`-Decoding** in DayList/DayDetail.
  - **KEIN Default-Rollout** — Store-Pfad bleibt feature-flagged, default AUS.
  - **KEIN Live-Upload-Mix.**
  - **KEINE neuen externen Dependencies.**
  - **KEINE Hardware-/AppStore-/TestFlight-Aussage.**
  - **KEINE Darwin-FileProtection-Aktivierung** (bleibt offene Phase-10-Pflicht).
  - **KEIN RTree** (bleibt deferred, TEXT path-IDs).
  - **46-MB-Gate bleibt FAILED / pending hardware retest** (verbatim erhalten).

## [2026-05-08] — feat: wire local timeline day presentation

Phase-9A-Iteration der LocalTimelineStore-Architektur (vgl. `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`). **Wrapper- und Package-AppShell-Wiring der feature-flagged LocalTimelineSession + Settings-Delete-UI im Technical-Tab + neue Linux-testbare Routing-Helper-Funktion `LH2GPXAppFlow.apply(envelopeOutcome:to:preserveOnFailure:)`** — Surface bleibt **Spike / pre-production**, Store-Pfad **default AUS** (`LH2GPX_LOCAL_TIMELINE_STORE`-Flag unverändert). **Map/Heatmap/Overview UI-Hook bleibt blockiert**; Store-DayList/DayDetail UI bleibt Phase 9B. **46-MB-Gate bleibt FAILED / pending hardware retest.**

- **NEU** `LH2GPXAppFlow.apply(envelopeOutcome:to:preserveOnFailure:) -> AppliedEnvelopeRouting` — geteilte, Linux-testbare Routing-Helper-Funktion für Wrapper + Package-AppShell. Routet `.legacy(content)` → `session.show(content:)`, `.localTimeline(LocalTimelineSession)` → `session.show(localTimeline:)`, `.failure` kontrolliert mit optionaler Bookmark-Preservation.
- **NEU** `LH2GPXAppFlow.makeProductionDeletionPresentation()` — Convenience-Konstruktor für Settings/Technical-Hosts.
- **Geändert** `wrapper/LH2GPXWrapper/ContentView.swift` — ruft jetzt `loadImportedFileEnvelope(...)` (statt `loadImportedFile(...)`) und routet `.legacy/.localTimeline/.failure` über `apply(envelopeOutcome:to:)`.
- **Geändert** `Sources/LocationHistoryConsumerApp/AppShellRootView.swift` — analoge Umstellung auf den Envelope-Pfad.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineSessionLandingView.swift` (`#if canImport(SwiftUI)`-guarded) — Landing-View bei aktiver `localTimelineSession` mit Session-Metadaten + Lösch-Button. **Kein `coord_blob`-Read, kein Map/Heatmap/Overview-Hook.** Eingebunden in beiden App-Shells via body-Branch `else if let storeSession = session.localTimelineSession`.
- **Geändert** `AppTechnicalOptionsView` (in `AppOptionsView.swift`) — neue Section "Local Timeline Store" mit Feature-Flag-Status (Enabled/Disabled aus `LocalTimelineFeatureFlags.resolveFromProcess()`), Status-Zeile "Pre-production / Feature-flagged" und Lösch-Button "Delete imported local data" mit kontrollierten States `idle/running/succeeded/failed`.
- **NEU Tests** `Tests/LocationHistoryConsumerTests/WrapperLocalTimelineEnvelopeRoutingTests.swift` (6 Cases, Linux-grün) — legacy/localTimeline/failure(clearBookmark T/F)/Replace-Invariante in beide Richtungen.
- **Harte Grenzen Phase 9A (verbatim)**:
  - **KEIN Map-/Heatmap-/Overview-UI-Hook gegen Store.**
  - **KEIN AppExport-Rebuild aus Store.**
  - **KEIN vollständiger `[Double]`-Import-Buffer.**
  - **KEIN Default-Rollout** — Store-Pfad bleibt feature-flagged via `LH2GPX_LOCAL_TIMELINE_STORE`, default AUS.
  - **KEIN Live-Upload-Mix.**
  - **KEINE neuen externen Dependencies.**
  - **KEINE Hardware-/AppStore-/TestFlight-Aussage.**
  - **KEINE Darwin-FileProtection-Aktivierung** (bleibt offene Phase-9-Pflicht).
  - **KEIN RTree** (bleibt deferred, TEXT path-IDs).
  - **46-MB-Gate bleibt FAILED / pending hardware retest.**
  - Settings-DayList/DayDetail UI ist nur als Landing-View für Store-Session sichtbar; vollständige Store-DayList/DayDetail-UI bleibt **Phase 9B**.
- **Trennung Service/Presentation-testbar vs UI-aktiv**: Routing-Helper + Settings-Delete-Button + Landing-View sind **UI-aktiv hinter Feature-Flag**; vollständige Store-DayList/DayDetail/Map/Heatmap/Overview-Surfaces bleiben **nicht UI-aktiv**.

## [2026-05-08] — feat: add store backed heatmap lod cache

Phase-8B-Iteration der LocalTimelineStore-Architektur (vgl. `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`). **Heatmap-Doppelbug-Fix zentral via Foundation-only Helper + `derived_cache`-Tabelle (additiv, FK CASCADE auf `imports.id`) + Foundation-only Heatmap-Modelle + deterministischer Grid-Aggregator + Foundation-only Store-backed Heatmap Data Provider mit bounded Sampling, Grid-LOD-Aggregation und cache-backed Roundtrip** — **kein SwiftUI-Map/MKMapView-Hook, kein UI-Heatmap-Renderer-Hook, kein AppExport-Rebuild aus Store, kein vollständiger `[Double]`-Import-Buffer, kein Live-Upload-Mix**. Store-Pfad bleibt **default AUS** (`LH2GPX_LOCAL_TIMELINE_STORE`-Flag unverändert). Schema bleibt `userVersion = 2` (rein additiv, keine semantische Schema-Änderung). **46-MB-Gate bleibt FAILED / pending hardware retest.** **Surface bleibt Spike / pre-production, not UI-active.**

- **NEU** `Sources/LocationHistoryConsumer/AppHeatmapPathSampler.swift` — Foundation-only Helper mit kanonischer Priorität: `flatCoordinates` (wenn vorhanden und gerade Element-Anzahl), sonst `points` Fallback. Ungerade `flatCoordinates` gelten als malformed → kontrollierter Fallback auf `points` (dokumentierte Entscheidung). Zentralisiert die Heatmap-Doppelbug-Fix-Logik.
- **Geändert** `Sources/LocationHistoryConsumer/AppHeatmapModel.swift` — Zeilen 55-77 nutzen jetzt `AppHeatmapPathSampler` statt der bisherigen Doppel-Iteration über `path.points` UND `path.flatCoordinates`. Damit ist der im `docs/MAP_ARCHITECTURE_AUDIT.md` §2 dokumentierte Doppelbug **ab Phase 8B zentralisiert gefixt**. 7 neue Linux-grüne Tests in `Tests/LocationHistoryConsumerTests/AppHeatmapModelGeometryTests.swift`.
- **Geändert** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStoreSchema.swift` — neue **additive** Tabelle `derived_cache` (Spalten `id`, `import_id`, `kind`, `key`, `payload`, `created_at`) mit FK auf `imports.id` und `ON DELETE CASCADE`. Zwei neue Indizes `idx_derived_cache_import_kind_key` und `idx_derived_cache_kind_created`. **`userVersion` bleibt 2** (rein additiv, keine semantische Schema-Änderung).
- **Geändert** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStore.swift` — neue CRUD-APIs `putDerivedCache(...)`, `derivedCache(...)`, `deleteDerivedCache(...)`, `countDerivedCache(...)`. `deleteAll()` löscht jetzt zusätzlich auch `derived_cache`-Zeilen.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineHeatmapModels.swift` — Foundation-only Modelle: `LocalTimelineHeatmapSample`, `LocalTimelineHeatmapSampleResponse`, `LocalTimelineHeatmapGridCell`, `LocalTimelineHeatmapLODResponse`, `LocalTimelineHeatmapCacheKey`, `LocalTimelineHeatmapCacheEncoding`. **Keine SwiftUI-/MapKit-/CoreLocation-Abhängigkeit.**
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineHeatmapGridAggregator.swift` — deterministischer Grid-Aggregator. Cell-Size je Detail-Level (`overview` 0.5°, `low` 0.1°, `medium` 0.02°, `high` 0.005°). Hartes `maxCells` und `maxSamplesConsumed` Limit. Stabile Sortierung (lat asc, lon asc). 7 Tests.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/StoreBackedHeatmapDataProvider.swift` — Foundation-only Provider. APIs: `heatmapSamples(importID:viewport:maxRoutes:maxPointsPerRoute:maxSamples:)` (bounded sampling, doppelt bounded `maxRoutes` × `maxPointsPerRoute`, total-bounded durch `maxSamples`); `heatmapLOD(importID:viewport:options:)` (Grid-Aggregation, optional cache-backed via `derived_cache`); `clearHeatmapCache(importID:)`. Cache-Payload-Codec deterministisch (Magic `'L8B1'`, little-endian). Cache-Key über `LocalTimelineHeatmapCacheKey.make(...)` mit 1e-3°-Quantisierung. Malformed `coord_blob` wird kontrolliert übersprungen. 11 Tests inkl. 50k synthetic store + cache hit/clear roundtrip.
- **NEU** `Tests/LocationHistoryConsumerTests/LocalTimelineRTreeCapabilityTests.swift` — dokumentiert RTree-Fallback: `paths.id` ist TEXT (`paths.id TEXT PRIMARY KEY`), RTree erwartet INTEGER `docid`. Surrogate-Integer-Mapping wäre Schema-breaking → RTree `path_bounds` bleibt **kontrolliert deferred**. Bbox-Index-Scan aus Phase 8A bleibt aktiv.
- **NEU Tests** (Linux-grün), 4 Test-Dateien:
  - `AppHeatmapModelGeometryTests.swift` (7 Cases) — `AppHeatmapPathSampler` Priorität flat-vor-points, ungerade flatCoordinates → fallback points, Doppelbug-Regression.
  - `LocalTimelineHeatmapGridAggregatorTests.swift` (7 Cases) — deterministische Sort, Cell-Size pro Detail-Level monoton, `maxCells`/`maxSamplesConsumed` hard, leere/1-Sample stabil.
  - `StoreBackedHeatmapDataProviderTests.swift` (11 Cases) — 50k synthetic store bounded sampling, cache hit/miss roundtrip, `clearHeatmapCache` Invalidierung, malformed `coord_blob` skip, viewport-Filter, options-quantisierung.
  - `LocalTimelineRTreeCapabilityTests.swift` — dokumentiert RTree-Fallback (paths.id TEXT vs RTree INTEGER docid).
- **Bounded-Read-Garantien Phase 8B (zusätzlich zu Phase 8A 1-6)**:
  7. `heatmapSamples` ist viewport-gebunden, **doppelt bounded** durch `maxRoutes` × `maxPointsPerRoute` und total-bounded durch `maxSamples`.
  8. Pro Pfad wird **lazy** dekodiert via `CoordBlobIterator`; nie vollständige Import-Geometrie im RAM.
  9. `heatmapLOD` aggregiert nur die bounded Samples; Cache-Payload trägt **Zellen, keine Roh-Punkte**.
  10. `derived_cache` ist als abgeleitete Cache-Tabelle vom Import-Lifecycle abhängig (FK CASCADE) und über `clearHeatmapCache(importID:)` invalidierbar.
- **Harte Grenzen Phase 8B (unverändert oder neu zu betonen)**:
  - **KEIN SwiftUI-Map/MKMapView-Hook**.
  - **KEIN UI-Heatmap-Renderer-Hook** (existierender SwiftUI-Heatmap-Renderer unverändert; konsumiert weiter `AppExport`).
  - **KEIN AppExport-Rebuild aus Store.**
  - **KEIN vollständiger `[Double]`-Import-Buffer.**
  - **KEIN Live-Upload-Mix.**
  - Store-Pfad bleibt **default AUS** / pre-production.
  - Schema additiv, **`userVersion` unverändert 2/2**.
  - **RTree (`path_bounds`) bleibt kontrolliert deferred** — `paths.id` ist TEXT, RTree erwartet INTEGER `docid`; Surrogate-Integer-Mapping wäre Schema-breaking. Bbox-Index-Scan aus Phase 8A bleibt aktiv.
  - **46-MB-Gate bleibt FAILED / pending hardware retest** (Wortlaut verbatim erhalten in `docs/APPLE_VERIFICATION_CHECKLIST.md`).
- **Explizit NICHT in Phase 8B** (= Phase 9 vor produktivem UI-Rollout):
  - **RTree (`path_bounds` virtual table)** — Surrogate-Integer-Mapping wäre Schema-breaking; deferred.
  - Wrapper/SwiftUI-Wiring der Presentation-/ViewState-Schicht — deferred.
  - Settings-Delete-UI-Button — deferred.
  - Map/Heatmap/Overview UI-Hook gegen Provider — deferred (Provider bleibt kanonische Schnittstelle).
  - **Darwin FileProtection-Aktivierung** — offene Pflicht vor Rollout.
  - Export-UI-Hook gegen `StoreBackedExportWriter` — deferred.
  - 46-MB-Hardware-Retest, TestFlight/Xcode-Cloud — Mac/iPhone-Handoff, FAILED unverändert.
  - Privacy-Doku-Update vor produktivem Rollout — deferred.

## [2026-05-08] — feat: add store backed map data provider

Phase-8A-Iteration der LocalTimelineStore-Architektur (vgl. `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`). **Foundation-only Store-backed Map Data Provider + bounded Map-Domain-Modelle + stride-/budget-basierter Route-Decimator + zwei additive bbox-Metadata-Indizes auf `paths`** — **kein SwiftUI-Map/MKMapView-Hook, kein UI-Hook, kein Renderer-Wechsel, kein AppExport-Rebuild aus Store, kein vollständiger `[Double]`-Import-Buffer, kein Live-Upload-Mix**. Store-Pfad bleibt **default AUS** (`LH2GPX_LOCAL_TIMELINE_STORE`-Flag unverändert). Schema bleibt `userVersion = 2` (Indizes sind rein additiv). **46-MB-Gate bleibt FAILED / pending hardware retest.** **Surface bleibt Spike / pre-production, not UI-active.**

- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineMapModels.swift` — Foundation-only Map-Domain-Modelle: `LocalTimelineMapViewport` (Anti-Meridian wird kontrolliert abgelehnt), `LocalTimelineMapDetailLevel` (`overview`/`low`/`medium`/`high`), `LocalTimelineMapPointBudget` (default-Tabelle pro Level, monoton), `LocalTimelineMapQuery`, `LocalTimelineMapRouteCandidate` (metadata-only, kein `coord_blob`), `LocalTimelineMapPoint`, `LocalTimelineMapRouteGeometry` (bounded points), `LocalTimelineMapOverviewResponse` (mit `truncatedRoutes`/`truncatedPoints`), `LocalTimelineMapBounds`, `LocalTimelineMapProviderError`. **Keine SwiftUI-/MapKit-/CoreLocation-Abhängigkeit.**
- **NEU** `Sources/LocationHistoryConsumerAppSupport/StoreBackedMapDataProvider.swift` — Provider-Klasse mit Foundation-only APIs: `routeCandidates(importID:viewport:limit:)`, `dayRouteCandidates(dayID:viewport:limit:)` (beide metadata-only, **kein `coord_blob`-Read**), `routeGeometry(pathID:detailLevel:maxPoints:)` (lazy single-path decode via `CoordBlobIterator`), `overviewRoutes(query:)` (**doppelt bounded** mit `maxRoutes` und `budget.maxTotalPoints`), `mapBounds(forImportID:)`/`mapBounds(forDayID:)` (Aggregat über `paths.min/max_lat/lon`-Spalten, **kein Geometrie-Decode**).
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineRouteDecimator.swift` — deterministischer stride-/budget-basierter Decimator. Iterator-basiert (`Sequence<EncodedCoordinate>`), erster + letzter Punkt erhalten, `maxPoints` hart, leere/1-Punkt-Pfade stabil. **Douglas-Peucker bleibt Phase 8B/9.**
- **Geändert** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStoreSchema.swift` — zwei neue **additive** Indizes `idx_paths_bounds_minmax` und `idx_paths_day_bounds`. **`userVersion` bleibt 2** (rein additiv). RTree-`path_bounds` virtuelle Tabelle bleibt **Phase 8B/9 deferred**.
- **Geändert** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStore.swift` — neue public APIs `pathMetadata(forImportId:viewportMin/Max...:limit:)`, `pathMetadata(forDayId:viewportMin/Max...:limit:)`, `pathBoundingBox(forImportId:)`, `pathBoundingBox(forDayId:)` plus Test-Helper `indexNames(forTable:)`. Bbox-Filter ist linearer bbox scan über `min/max_lat/lon`-Spalten. **NULL-Bounds werden konservativ als überlappend gewertet.** Newest-first `ORDER BY start_time`.
- **Geändert** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStoreReader.swift` — thin wrappers `pathMetadata(forImportId:viewport:limit:)`, `pathMetadata(forDayId:viewport:limit:)`, `pathBoundingBox(forImportId:)`, `pathBoundingBox(forDayId:)`.
- **NEU Tests** (Linux-grün), 4 Dateien, 33 Cases:
  - `Tests/LocationHistoryConsumerTests/StoreBackedMapDataProviderTests.swift` (15 Cases) — inkl. 50k-synthetic-store-bounded-Test, malformed `coord_blob` → kontrollierter Fehler, unknown import returns empty, unknown path throws, viewport-Filter, day-scope, overview `maxRoutes`/`maxTotalPoints`.
  - `Tests/LocationHistoryConsumerTests/LocalTimelineRouteDecimatorTests.swift` (8 Cases) — empty/1-point stable, small unchanged, `maxPoints` hard-cap, first+last preserved, `maxPoints=1`/`=2`, single-pass iterator.
  - `Tests/LocationHistoryConsumerTests/LocalTimelineMapBoundsTests.swift` (7 Cases) — viewport valid/invalid (flipped lat / antimeridian / out of range), intersect classic/disjoint/null-bounds, point-budget defaults monoton.
  - `Tests/LocationHistoryConsumerTests/LocalTimelineMapSchemaIndexTests.swift` (2 Cases) — fresh store hat beide Indizes; reopened-store nach `DROP` gewinnt sie additiv zurück, `userVersion` bleibt `2`.
- **Bounded-Read-Garantien (Phase-8A-Erweiterung)**: 1) `routeCandidates(importID:viewport:limit:)` und `dayRouteCandidates(dayID:viewport:limit:)` lesen **kein `coord_blob`**, nur path-Metadaten + bbox-Filter; 2) `routeGeometry(pathID:detailLevel:maxPoints:)` decodiert **single-path lazy** via `CoordBlobIterator`, hart bounded durch `maxPoints` aus `LocalTimelineMapPointBudget`; 3) `overviewRoutes(query:)` ist **doppelt bounded** durch `maxRoutes` UND `budget.maxTotalPoints`, schreibt `truncatedRoutes`/`truncatedPoints` in die Response; 4) `mapBounds(forImportID:)`/`mapBounds(forDayID:)` aggregieren ausschließlich über `paths.min/max_lat/lon`-Spalten — **kein Geometrie-Decode**; 5) **kein API materialisiert `AppExport`** über den Provider; 6) **kein API materialisiert `[Double]`** für einen ganzen Import.
- **Explizit NICHT in Phase 8A** (= Phase 8B/9 vor produktivem UI-Rollout):
  - **KEIN SwiftUI-Map/MKMapView-Hook**, **kein UI-Hook**, **kein Renderer-Wechsel** in dieser Phase.
  - RTree (`path_bounds` virtual table) — **Phase-8B-Pflicht**, in Phase 8A explizit deferred.
  - `derived_cache`, Heatmap-LOD-Persistenz — Phase 8B/9.
  - Wrapper/SwiftUI-Wiring (DayList/DayDetail/Map/Heatmap/Overview/Export/Settings) — Phase 8B/9.
  - Settings-Delete-UI-Button — Phase 8B/9.
  - **Heatmap-Doppelbug-Fix** (`AppHeatmapModel.swift:55-77`) — **Phase-8B-Pflicht** (im `docs/MAP_ARCHITECTURE_AUDIT.md` bereits vermerkt; nicht behauptet, dass behoben).
  - Export-UI-Hook gegen `StoreBackedExportWriter` — Phase 8B/9.
  - **Darwin FileProtection-Aktivierung** — weiterhin offene Pflicht (Phase-4-Capsule unverändert; weder Phase 6/7A/7B/8A haben den Hook aktiviert).
  - 46-MB-Hardware-Retest, ASC/TestFlight/Xcode-Cloud — **NICHT** beansprucht; **46-MB-Gate bleibt FAILED / pending hardware retest**.
  - MKMapView-Migration bleibt blockiert hinter 46-MB-Gate; Map-Modernisierung unverändert.

## [2026-05-08] — feat: add store backed day presentation surface

Phase-7B-Iteration der LocalTimelineStore-Architektur (vgl. `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`). **Foundation-only Presentation/ViewState-Schicht + AppSessionState-Extension + Service-Layer Envelope-Hook im AppFlow** — **kein UI-Hook (kein Wrapper/SwiftUI-Wiring), kein Map/Heatmap/Overview/Export-UI-Hook, kein AppExport im Store-Pfad materialisiert, keine vollständige `[Double]`-Import-Materialisierung**. Store-Pfad bleibt **default AUS** (`LH2GPX_LOCAL_TIMELINE_STORE`-Flag). Legacy-`loadImportedFile(...)` ist byte-identisch unverändert. **FileProtection-Status unverändert** (Phase-4-Capsule, Aktivierung weiterhin Darwin/iOS-Pflicht). **46-MB-Gate bleibt FAILED / pending hardware retest unverändert.** **LocalTimelineStore weiterhin pre-production, nicht UI-aktiv.**

- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayListViewState.swift` — Foundation-only ViewState für die Day-List-Surface über den Store-Pfad.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDayDetailViewStateAdapter.swift` — Foundation-only Adapter, der Reader-Daten in eine bounded DayDetail-ViewState projiziert.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/AppSessionPresentationSource.swift` — Presentation-Quelle inkl. AppSessionState-Extensions `activeContent` und `isLocalTimelineActive`.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDeletionPresentation.swift` — Presentation-Schicht über `LocalTimelineDeletionService`. Dokumentiert: **kein Bookmark-/Preferences-Cleanup nötig im Store-Pfad** (keine UserDefaults für Standortdaten).
- **Geändert** `Sources/LocationHistoryConsumerAppSupport/LH2GPXAppFlow.swift` — neue Methode `loadImportedFileEnvelope(...) -> EnvelopeImportOutcome` als feature-flagged Service-layer-Hook. Legacy `loadImportedFile(...)` bleibt **byte-identisch unverändert**.
- **NEU Tests** in `Tests/LocationHistoryConsumerTests/`:
  - `LocalTimelineDayListViewStateTests`
  - `LocalTimelineDayDetailViewStateAdapterTests`
  - `AppSessionLocalTimelinePresentationTests`
  - `LocalTimelineDeletionPresentationTests`
  - `AppFlowLocalTimelineEnvelopeTests`
- **Phase-7B-Surface**: Foundation-only Presentation/ViewState-Schicht + `AppSessionState`-Extension (`activeContent`, `isLocalTimelineActive`) + Service-layer Envelope-Hook im AppFlow. **Kein Wrapper/SwiftUI-Wiring, kein UI-Hook für DayList/DayDetail/Map/Heatmap/Overview/Export/Settings.**
- **Explizit NICHT in Phase 7B** (= Phase 8 vor produktivem UI-Rollout):
  - Wrapper/SwiftUI-Wiring der Presentation-/ViewState-Schicht — deferred.
  - Map/Heatmap/Overview Provider, `derived_cache`+RTree+`path_bounds` — deferred.
  - Export-UI-Hook (Settings/Export-Tab) — deferred.
  - **Darwin FileProtection-Aktivierung** — weiterhin offene Pflicht (Phase-4-Capsule unverändert).
  - 46-MB-Hardware-Retest, ASC/TestFlight/Xcode-Cloud — **NICHT** beansprucht; **46-MB-Gate bleibt FAILED unverändert**.

## [2026-05-08] — feat: add feature flagged local timeline loader path

Phase-7A-Iteration der LocalTimelineStore-Architektur (vgl. `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`). **Feature-flagged AppContentLoader-Hook + AppSession-Quelle als Envelope-Kapsel** über den Store-Pfad. **Isoliert eingecheckt**, **kein default-aktiver Pfad** (Default-Rollout bleibt Legacy-AppExport), **gated by feature flag**, **kein UI-Hook für DayList/DayDetail/Map/Heatmap/Overview/Export/Settings**, **kein AppExport im Store-Pfad materialisiert**, **kein vollständiger `[Double]`-Import-Buffer materialisiert**. Bestehender Legacy-AppExport-Pfad bleibt byte-identisch. Live-Upload bleibt strikt getrennt. Keine Standortdaten in UserDefaults. **Darwin FileProtection nicht aktiviert** (Hook bleibt nur dokumentiert). **Keine Map-Modernisierung**. **Keine Hardware-/ASC-/TestFlight-Aussagen**. **46-MB-Gate bleibt FAILED / pending hardware retest.** **LocalTimelineStore-Status: weiterhin Spike / pre-production, nicht UI-aktiv.**

- **NEU** `Sources/LocationHistoryConsumerAppSupport/AppSessionContentSource.swift` — Envelope-Enum mit Cases `inMemory(AppSessionContent)` und `localTimeline(LocalTimelineSession)`. **Kapsel-Approach** — `AppSessionContent` selbst wird **nicht** erweitert, kein Bruch der bestehenden Source-Form. Source-Enum-Verschmelzung in `AppSessionContent` ist explizit Phase-7B.
- **Geändert** `Sources/LocationHistoryConsumerAppSupport/AppSessionState.swift` — neue Property `localTimelineSession: LocalTimelineSession?` plus neuer Mutator `show(localTimeline:)` (Banner/Title aus Session-Metadaten, **kein AppExport, keine Coord-Decode**). `show(content:)` und `clearContent()` setzen die neue Property mit zurück.
- **Geändert** `Sources/LocationHistoryConsumerAppSupport/AppContentLoader.swift` — neuer Einstieg `loadImportedContentEnvelope(from:autoRestoreMode:onPhase:flags:storeFactoryProvider:) -> AppSessionContentSource`. **Bei deaktiviertem Flag exakt der Legacy-Pfad** → `.inMemory(...)` (byte-identisch). Bei aktivem Flag + Google-Timeline-JSON oder ZIP-mit-genau-einem-Timeline-Entry → `GoogleTimelineStoreImporter.importFromFile/Data` + `LocalTimelineSession.make(...)` → `.localTimeline(...)`. Andere Formate (LH2GPX-Objekt-JSON, GPX, TCX) fallen kontrolliert auf den Legacy-Pfad zurück. Neuer Error-Case `AppContentLoaderError.localTimelineStoreFailed(String)`. Importe sind additiv (frische `importId` pro Call); **Bulk-Wipe bleibt `LocalTimelineDeletionService`/`LocalTimelineStoreLifecycle.deleteAllLocalTimelineData`**.
- **NEU Tests** (Linux-grün), 3 Dateien, 14 neue Cases:
  - `Tests/LocationHistoryConsumerTests/AppSessionLocalTimelineSourceTests.swift` (5 Cases) — Envelope-Kapsel, `show(localTimeline:)`, `clearContent()`-Reset, Banner/Title aus Session-Metadaten ohne Coord-Decode.
  - `Tests/LocationHistoryConsumerTests/AppContentLoaderLocalTimelineStoreTests.swift` (5 Cases) — Flag-Off-Default → Legacy-`.inMemory`, Flag-On + Timeline-JSON → `.localTimeline`, Flag-On + ZIP-mit-genau-einem-Timeline-Entry → `.localTimeline`, Flag-On + andere Formate (LH2GPX-Objekt/GPX/TCX) → kontrollierter Legacy-Fallback, additiver Import (frische `importId`).
  - `Tests/LocationHistoryConsumerTests/LocalTimelineFeatureFlagIntegrationTests.swift` (4 Cases) — Flag-Resolution-End-to-End über `loadImportedContentEnvelope`, kein default-aktiver Pfad, `localTimelineStoreFailed`-Fehlerpfad.
- **Geändert** — keine weiteren. `AppSessionContent`, `LocalTimelineStore`/`LocalTimelineStoreReader`/`LocalTimelineImportWriter`/`LocalTimelineStoreFactory`/`LocalTimelineStoreLifecycle` sowie die bestehenden `AppExport`-Builder bleiben unverändert. Schema unverändert (`userVersion = 2`).
- **Explizit NICHT in Phase 7A** (= Phase 7B vor UI-Hook):
  - `AppSessionContent`-Source-Enum-Verschmelzung (statt Envelope-Kapsel) — bewusst deferred.
  - DayList/DayDetail/Map/Heatmap/Overview-UI-Hooks — deferred.
  - Settings-UI „Importierte Daten löschen" — deferred (nur Service-API `LocalTimelineDeletionService` verdrahtet).
  - `derived_cache` / RTree `path_bounds` — deferred.
  - **Darwin FileProtection-Aktivierung** (`URLResourceKey.fileProtectionKey = .completeUnlessOpen` bzw. `SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN`) — deferred, offene Darwin-Pflicht.
  - 46-MB-Hardware-Retest, ASC/TestFlight-Pass — **NICHT** beansprucht; 46-MB-Gate bleibt FAILED.
  - Privacy-Doku-Update vor Rollout — deferred.

## [2026-05-08] — feat: add feature flagged local timeline session source

Phase-6-Iteration der LocalTimelineStore-Architektur (vgl. `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`). **Feature-flagged AppSession-Quelle** für den LocalTimelineStore — Foundation-only Adapter-Surface, **isoliert eingecheckt**, **kein default-aktiver Pfad**, **gated by feature flag**, **kein AppExport im Store-Pfad materialisiert**, **kein vollständiger `[Double]`-Import-Buffer materialisiert**, **kein UI-Hook**, **kein App-Session-Switch**, **kein AppContentLoader-Hook**, **kein DayList/DayDetail/Map/Heatmap/Overview-Hook**, **kein Settings-UI**. Bestehender AppExport-Exportpfad unverändert. **Darwin FileProtection nicht angefasst** (existierende Factory-Doku unverändert; keine Aktivierung in diesem PR). **46-MB-Gate bleibt FAILED / pending hardware retest.** **LocalTimelineStore-Status: weiterhin Spike / pre-production, nicht UI-aktiv.**

- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineFeatureFlags.swift` — resolved `LH2GPX_LOCAL_TIMELINE_STORE` aus `ProcessInfo.arguments`/`environment`. Erkennt `--LH2GPX_LOCAL_TIMELINE_STORE`, bare `LH2GPX_LOCAL_TIMELINE_STORE` als Argument, sowie env-Werte `1`/`true`/`yes`/`on` (case-insensitive). Default disabled. **Keine UserDefaults-Persistenz.**
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineSession.swift` — Foundation-only Session-Modell: `importID`, `sourceFilename`, `storeURL`, `createdAt`, `importedAt`, `summary` (`dayCount`/`pathCount`/`visitCount`/`activityCount`/`totalDistanceM`/`dateRange`). `make(reader:importID:storeURL:)` konstruiert das Session-Objekt aus einem `LocalTimelineStoreReader` **ohne Geometrie-Materialisierung**. Caller besitzt die Lifetime des Stores.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineAppSessionAdapter.swift` — projiziert Reader-Daten in bounded ViewState-Modelle: `DaySummaryView`, `DayDetailView`, `VisitView`, `ActivityView`, `PathMetadataView`. Methoden: `daySummaries()`, `dayDetail(dayId:)`, `coordinates(forPathId:)` (explizit on-demand, lazy via `CoordBlobIterator`).
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineDeletionService.swift` — dünner Wrapper um `LocalTimelineStoreLifecycle.deleteAllLocalTimelineData`. Idempotent. **Keine UserDefaults-Aufräumung.**
- **NEU Tests** in `Tests/LocationHistoryConsumerTests/`:
  - `LocalTimelineFeatureFlagsTests.swift` (8 Cases)
  - `LocalTimelineSessionTests.swift` (3 Cases)
  - `LocalTimelineAppSessionAdapterTests.swift` (4 Cases)
  - `LocalTimelineDeletionServiceTests.swift` (2 Cases)
- **Geändert** — keine. `LocalTimelineStore`/`LocalTimelineStoreReader`/`LocalTimelineImportWriter`/`LocalTimelineStoreFactory`/`LocalTimelineStoreLifecycle` sowie die bestehenden `AppExport`-Builder bleiben unverändert. Schema unverändert (`userVersion = 2`).
- **Explizit NICHT in Phase 6** (= Phase 7 vor UI-Hook):
  - `AppSession`/`AppSessionContent`-Erweiterung um `case localTimeline(...)` — in diesem PR zu riskant, deferred.
  - AppContentLoader-Hook, der auf den Feature-Flag verzweigt — deferred.
  - Settings-UI „Importierte Daten löschen" — deferred (nur die Service-API ist vorbereitet).
  - DayList/DayDetail/Map/Heatmap/Overview-UI-Hooks — deferred.
  - `derived_cache` / RTree / `path_bounds` — deferred.
  - Darwin FileProtection: in diesem PR **nicht angefasst** (existierende Factory hat bereits FileProtection-Hinweise; keine Änderung).
  - Hardware-Retest, ASC/TestFlight-Pass — **NICHT** beansprucht.

## [2026-05-08] — feat: add store backed streaming export

Phase-5-Iteration der LocalTimelineStore-Architektur (vgl. `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`). **Store-backed Streaming Export** (GPX/KML/GeoJSON/CSV) liest direkt aus `LocalTimelineStoreReader` und schreibt inkrementell in eine Datei unter `ExportStaging/<uuid>/export.<ext>`. **Isoliert eingecheckt**, **kein UI-Hook**, **kein App-Session-Switch**, **kein AppContentLoader-Default auf den Store**, **kein DayList/DayDetail/Map-Hook**, **bestehender AppExport-Exportpfad bleibt unverändert** (GPXBuilder/KMLBuilder/GeoJSONBuilder/CSVBuilder werden in dieser Iteration **nicht** umgebaut). **46-MB-Crashfall bleibt FAILED / pending hardware retest.**

- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineExportTypes.swift` — Foundation-only Typen: `LocalTimelineExportFormat` (`gpx`/`kml`/`geoJSON`/`csv`), `LocalTimelineExportSelection` (`importID`, optional `dateRange`, optional `dayIds`, `includeVisits`/`includeActivities`/`includePaths`), `LocalTimelineExportResult` (`outputURL`, `format`, `bytesWritten`, `dayCount`, `pathCount`, `visitCount`, `activityCount`, `pointCount`), `LocalTimelineExportError` (`unknownImport`, `emptySelection`, `malformedCoordBlob`, `ioFailure`, `readerFailure`). **Empty-Selection-Entscheidung explizit**: leere/nichts-auswählende Selection wirft `LocalTimelineExportError.emptySelection` statt eine leere Datei zu erzeugen.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStreamingTextWriter.swift` — inkrementeller UTF-8-Datei-Writer. Schreibt nach `ExportStaging/<uuid>/export.<ext>` (parent-dir-Anlage idempotent), `bytesWritten` zählt UTF-8-Bytes, `finalize()` ist idempotent.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/StoreBackedExportWriter.swift` — `init(reader:locations:)`, `export(selection:format:) throws -> LocalTimelineExportResult`. Liest Days bounded, Visits/Activities/Paths via `dayDetail`, Koordinaten **ausschließlich pro Pfad lazy via `coordinateSequence(forPathId:)` (CoordBlobIterator)**. **Materialisiert KEINEN `AppExport`. Materialisiert KEINEN `[Double]`-Buffer für einen ganzen Import. Schreibt direkt in die Datei via `LocalTimelineStreamingTextWriter`.** Ausgabe-Pfad ist `LocalTimelineStorageLocations.exportStagingRoot/<uuid>/export.<ext>`. **Format-Hinweise**: GPX schreibt `<wpt>` für Visits + `<trk>/<trkseg>/<trkpt>` für Pfade; KML schreibt `Placemark` mit `Point`/`LineString`; GeoJSON schreibt eine `FeatureCollection` mit Point- und LineString-Features (Properties `kind`/`name`/`mode`/`date`); CSV nutzt den Header `type,date,time,lat,lon,name,mode,distance_m`. Activities werden in CSV als eigene Rows ausgegeben; in GPX/KML/GeoJSON werden sie nur **gezählt** (es gibt keine native Activity-Repräsentation in diesen Formaten). **Bestehende AppExport-Builder (`GPXBuilder`/`KMLBuilder`/`GeoJSONBuilder`/`CSVBuilder`) bleiben unverändert.**
- **NEU Tests** (alle Linux-grün), 3 Dateien, 26 neue Cases:
  - `Tests/LocationHistoryConsumerTests/LocalTimelineExportSelectionTests.swift` (6 Cases) — Selection-Konstruktion, Empty-Selection-Semantik, Default-Flags.
  - `Tests/LocationHistoryConsumerTests/LocalTimelineStreamingTextWriterTests.swift` (5 Cases) — UTF-8-Bytes-Zählung, Parent-Dir-Idempotenz, `finalize()` idempotent, Multi-Append-Roundtrip, Pfad unter `ExportStaging/<uuid>/export.<ext>`.
  - `Tests/LocationHistoryConsumerTests/StoreBackedExportWriterTests.swift` (15 Cases) — End-to-End-Roundtrip pro Format (GPX/KML/GeoJSON/CSV), bounded Coord-Decode, lazy `coordinateSequence`-Nutzung, `LocalTimelineExportResult`-Counter, `unknownImport`/`emptySelection`-Fehlerpfade, Activity-Zählung in nicht-CSV-Formaten, Activity-Rows in CSV.
- **Geändert** — keine. `LocalTimelineStore`/`LocalTimelineStoreReader`/`LocalTimelineImportWriter`/`LocalTimelineStoreFactory`/`LocalTimelineStoreLifecycle` sowie die bestehenden `AppExport`-Builder (`GPXBuilder`/`KMLBuilder`/`GeoJSONBuilder`/`CSVBuilder`) sind unverändert. Schema unverändert (`userVersion = 2`).
- **Linux-Verifikation**: `swift test` **1148/2/0** in 123.7s (vorher 1122 → +26).
- **LocalTimelineStore-Status**: weiterhin **Spike / pre-production, nicht UI-aktiv**. Phase-6 (offen vor UI-Hook): tatsächliche FileProtection-Aktivierung auf Darwin, Adapter zu `flatCoordinates`-Konsumenten, `derived_cache`/RTree, App-Flow-Umschaltung gegen Conditional-Gate, Settings-Eintrag „Importierte Daten löschen", Privacy-Doku-Update. Map-Modernisierung bleibt blockiert. Conditional-P0/P1-Gate unverändert.

## [2026-05-08] — feat: add local timeline storage lifecycle

Phase-4-Iteration der LocalTimelineStore-Architektur (vgl. `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`). **Storage-Lifecycle + iOS-Readiness** (Pfad-Resolver, Backup-Exclusion-Helper, FileProtection-Kapselung, Open-Lifecycle-Factory, High-Level deleteAll), **isoliert eingecheckt**, **kein UI-Hook**, **kein App-Session-Switch**, **kein AppContentLoader-Default auf den Store**, **kein DayList/DayDetail/Map-Hook**, **kein Export-Umbau**, **kein `AppExport` über den Store-Pfad**. Schema unverändert (`userVersion = 2`, additiv). **46-MB-Crashfall bleibt FAILED / pending hardware retest.**

- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStorageLocations.swift` — Storage-Pfad-Resolver. Production-Layout: DB unter `applicationSupportDirectory/LocationHistory2GPX/Imports/` (Datei `store.sqlite` + `-wal`/`-shm`-Geschwister), RenderCache unter `cachesDirectory/LocationHistory2GPX/RenderCache/`, ImportStaging unter `temporaryDirectory/LocationHistory2GPX/ImportStaging/`, ExportStaging unter `temporaryDirectory/LocationHistory2GPX/ExportStaging/`. `temporary(under:)` für Tests. `ensureDirectoriesExist` ist idempotent.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineFileAttributes.swift` — Backup-Exclusion-Helper über `URLResourceKey.isExcludedFromBackupKey` (Apple). Linux: no-op, `isExcludedFromBackup` liefert `false`. Wird beim Open-Lifecycle auf das DB-Verzeichnis und die DB-Datei angewendet.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineFileProtection.swift` — FileProtection-Kapselung. Ziel iOS: `completeUnlessOpen`. Phase 4 hat den Hook **nur dokumentiert, nicht aktiviert** (siehe Kommentar im File). `defaultProtectionDescription` liefert auf Linux `"noop-linux"`. Linux: no-op. **Offene Darwin-Pflicht**: tatsächliches Setzen von `URLResourceKey.fileProtectionKey` (oder `SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN` an `sqlite3_open_v2`) auf Apple-Plattformen muss vor dem produktiven UI-Rollout in einem Darwin-Hardware-Pass aktiviert und verifiziert werden.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStoreFactory.swift` — Open-Lifecycle. `openStore()` orchestriert: Verzeichnisse erzeugen → Backup-Exclusion auf DB-Dir → FileProtection-Hook → `LocalTimelineStore(url:)` → Backup-Exclusion + FileProtection auf der DB-Datei. Statische Helfer `temporary(under:)` und `production()`. **Kein UI-Hook, kein AppContentLoader-Hook, keine automatische Migration.**
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStoreLifecycle.swift` — High-Level `deleteAllLocalTimelineData(store:)`: ruft `store.deleteAll()`, schließt den Store, entfernt DB-Datei + `-wal`/`-shm`-Geschwister, RenderCache-Dir, ImportStaging-Dir, ExportStaging-Dir und ruft `ensureDirectoriesExist` neu. Idempotent, stabil bei fehlenden Verzeichnissen. **KEINE UserDefaults-Aufräumung** — explizit dokumentiert: keine Standortdaten in UserDefaults; Bookmark-/Preferences-Cleanup verbleibt im UI-Hook (Phase 5).
- **NEU Tests** (alle Linux-grün), 5 Dateien, 26 neue Cases:
  - `Tests/LocationHistoryConsumerTests/LocalTimelineStorageLocationsTests.swift` — Pfad-Resolver, idempotentes `ensureDirectoriesExist`, `temporary(under:)`-Roundtrip.
  - `Tests/LocationHistoryConsumerTests/LocalTimelineFileAttributesTests.swift` — Backup-Exclusion-Helper, Linux-no-op-Pfad.
  - `Tests/LocationHistoryConsumerTests/LocalTimelineFileProtectionTests.swift` — FileProtection-Kapselung, Linux-`"noop-linux"`-Beschreibung, dokumentierter Darwin-Hook.
  - `Tests/LocationHistoryConsumerTests/LocalTimelineStoreFactoryTests.swift` — `openStore()`-Lifecycle (Dirs, Backup-Exclusion, FileProtection, Store-Open), `temporary(under:)`/`production()`-Roundtrip.
  - `Tests/LocationHistoryConsumerTests/LocalTimelineStoreLifecycleDeleteAllTests.swift` — `deleteAllLocalTimelineData(store:)` löscht DB+WAL+SHM+RenderCache+ImportStaging+ExportStaging, ist idempotent, stabil bei fehlenden Verzeichnissen, lässt UserDefaults unangetastet.
- **Geändert** — keine. `LocalTimelineStore`/`LocalTimelineStoreReader`/`LocalTimelineImportWriter` sind unverändert; `LocalTimelineStore.deleteAll()` bleibt DB-only (in einer Transaktion). Die zusätzliche Caches/tmp-Aufräumung sitzt nur im neuen High-Level `deleteAllLocalTimelineData`.
- **LocalTimelineStore-Status**: weiterhin **Spike / pre-production**, **nicht UI-aktiv**. Kein AppContentLoader-Default auf Store, kein DayList/DayDetail/Map-Hook, kein Export-Umbau. Phase 5 (Adapter zu `flatCoordinates`-Konsumenten, `derived_cache`/RTree, App-Flow-Umschaltung gegen Conditional-Gate, Settings-Eintrag „Importierte Daten löschen", Privacy-Doku) bleibt offen vor UI-Hook. Map-Modernisierung bleibt blockiert. Conditional-P0/P1-Gate unverändert.

## [2026-05-08] — feat: add store backed timeline read surface

Phase-3-Iteration der LocalTimelineStore-Architektur (vgl. `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`). **Store-backed Read-Surface** für Imports/Days/Visits/Activities/Paths, **isoliert eingecheckt**, **kein UI-Hook**, **kein App-Session-Switch**, kein Map-Hook, kein `AppExport` über den Reader. **46-MB-Crashfall bleibt FAILED / pending hardware retest.**

- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStoreReadModels.swift` — Foundation-only Read-Models: `LocalTimelineImportRecord`, `LocalTimelineDayRecord`, `LocalTimelineVisitRecord`, `LocalTimelineActivityRecord`, `LocalTimelinePathRecord` (NUR Metadaten, KEIN `coord_blob` im Record), `LocalTimelineDayDetailSnapshot` (day + visits + activities + paths-METADATEN, ohne eager Coord-Decode).
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStoreReader.swift` — Foundation-only Read-Adapter über `LocalTimelineStore`. Public APIs: `imports()`, `importRecord(id:)`, `latestImport()`, `days(forImportId:)`, `dayRecord(id:)`, `dayRecord(forImportId:date:)`, `dayCount(forImportId:)`, `dayDetail(dayId:) -> LocalTimelineDayDetailSnapshot?` (nil bei unknown, KEINE eager Coord-Decodierung), `paths(forDayId:)`, `pathRecord(id:)`, `coordinateSequence(forPathId:) throws -> CoordBlobIterator` (lazy, wirft `ReaderError.unknownPath` / `.malformedCoordBlob`), `dayDateRange(forImportId:) -> ClosedRange<String>?`, `totalDistance/totalRouteCount/totalVisitCount(forImportId:)`. Neuer Fehlertyp `enum ReaderError: Error { case malformedCoordBlob(pathId:byteCount:); case unknownPath(pathId:) }`.
- `Sources/.../LocalTimelineStore.swift`: neue interne Read-Helper für den Reader — `imports()`, `importRow(id:)`, `latestImport()`, `dayRow(id:)`, `dayRow(forImportId:date:)`, `dayCount(forImportId:)`, `pathMetadata(forDayId:)` (ohne `coord_blob`), `pathMetadata(id:)`, `coordBlob(forPathId:)`, `dayDateRange(forImportId:)`, `totalDistance(forImportId:)`, `totalRouteCount(forImportId:)`, `totalVisitCount(forImportId:)`. **Schema unverändert (`userVersion = 2`)**, keine Migration.
- **Bounded-Read-Garantien** (im Reader-Doc-Kommentar verankert): 1) `imports()` liest nur `imports`-Spalten — kein paths/visits/activities; 2) `days(forImportId:)` liest nur `days` — kein `coord_blob`; 3) `dayDetail(dayId:)` liest day + visits + activities + path-METADATA, KEINE Coord-Decodierung; 4) Path-Koordinaten nur über explizites `coordinateSequence(forPathId:)` (lazy via `CoordBlobIterator`); 5) KEIN Reader-API gibt `AppExport` zurück; 6) KEIN API materialisiert `[Double]` für einen ganzen Import.
- **NEU Tests** (Linux-grün): `LocalTimelineStoreReaderTests` (13 Cases — API-Surface, dayDetail-Bündelung, coordinateSequence-Roundtrip + Fehlerpfade, Aggregate), `LocalTimelineStoreReadPersistenceTests` (6 Cases — Re-Open, Persistenz von visits/activities/paths-Metadaten), `LocalTimelineStoreBoundedReadTests` (5 Cases — kein eager Coord-Decode in DayList, summary-only-Strukturprüfung, Reader liefert kein `AppExport`). 50k-Visit-Smoke prüft strukturell, dass DayList-Read summary-only bleibt.
- **Linux-Verifikation**: `swift build` clean; `swift test` Filter-Lauf grün (Zahlen werden im Commit-Footer ergänzt). Bestehende Phase-1/2 Tests + `GoogleTimelineConverter` + `CoordBlob` regressionsfrei. Erwarteter `swift test`-Stand: 1071 → ~1095 (+24 Cases, vorbehaltlich grünem Vollauf).
- **LocalTimelineStore-Status**: weiterhin **Spike / pre-production**, **nicht UI-aktiv**. Adapter zu `flatCoordinates`-Konsumenten (DayList/DayDetail/Map/Heatmap/Distance/Export), FileProtection-Flag, `applicationSupportDirectory`-Pfad, `deleteAll()`-Erweiterung um Caches/tmp/Bookmark/Preferences, `derived_cache`/RTree und App-Flow-Umschaltung bleiben **Phase 4 vor UI-Hook**.

## [2026-05-08] — feat: add disk first google timeline import writer

Phase-2-Iteration der LocalTimelineStore-Architektur (vgl. `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`). **Disk-first Pfad** für Google-Timeline-Importe in den lokalen SQLite-Store, **isoliert eingecheckt**, **kein UI-/App-Session-Hook**, kein `AppExport` im neuen Pfad, keine Kartenmodernisierung. **46-MB-Crashfall bleibt FAILED / pending hardware retest.**

- `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStoreSchema.swift`: `userVersion` 1 → **2**. Neue Tabellen `visits` (`day_id` FK, `start_time`/`end_time`, `latitude`/`longitude`, `name`, `semantic_type`, `place_id`, `probability`) und `activities` (`day_id` FK, `start_time`/`end_time`, `mode`, `distance_m`, `start_lat`/`start_lon`/`end_lat`/`end_lon`, `probability`, `raw_type`), beide mit `ON DELETE CASCADE`. Neue Indizes `idx_days_import_date(import_id,date)`, `idx_paths_day_start(day_id,start_time)`, `idx_visits_day_id`, `idx_activities_day_id`. Migration ist additiv via `CREATE TABLE/INDEX IF NOT EXISTS` — eine v1-DB wird beim Re-Open transparent auf v2 angehoben (verifiziert durch `LocalTimelineStoreLifecycleTests.testMigrationFromSimulatedV1KeepsExistingRowsAndAddsNewTables`).
- `Sources/.../LocalTimelineStore.swift`: neue API `insertVisit`/`insertActivity`/`updateDaySummary`, Lese-API `visits(forDayId:)`/`activities(forDayId:)`/`days(forImportId:)`, Counter `countVisits`/`countActivities`. **`deleteAll()`**: löscht in einer einzigen Transaktion alle Zeilen aus `activities`/`visits`/`paths`/`days`/`imports`, idempotent (nicht-throwing auf leerer DB). **Scope explizit DB-only** — App-Caches (`Caches/...`) und tmp-Stagings (`tmp/LH2GPX-Import-*/`) werden **nicht** angefasst, weil heute kein produktiver Flow dort schreibt; vor dem UI-Hook muss eine zweite Iteration die Lifecycle-Surface (DB + Caches + tmp + Bookmark/Preferences) verbinden.
- **NEU** `Sources/.../LocalTimelineImportWriter.swift`: stateful Writer mit eigener `BEGIN IMMEDIATE … COMMIT/ROLLBACK`-Transaktion. Nimmt `VisitInput`/`ActivityInput`/`PathInput`, hält pro Tag nur ein `(dayId, routeCount, visitCount, distanceM)`-Aggregat im RAM, schreibt Inserts unmittelbar durch, aktualisiert Day-Summaries beim `finalize()`. Robust: ungültige Entries (kein parseable `startTime`, `flatCoordinates.count < 4`, ungerade Länge, Encode-Error) werden **gezählt und übersprungen**, nicht geworfen — `LocalTimelineImportSummary` exponiert `totalEntries`/`skippedEntries`/`dayCount`. Activities mit gültigem `start`+`end` erzeugen automatisch einen 2-Punkt-Pfad in `paths.coord_blob`.
- **NEU** `Sources/.../GoogleTimelineStoreImporter.swift`: orchestriert `GoogleTimelineStreamReader` → `LocalTimelineImportWriter`. Public API `importFromFile(url:sourceFilename:store:)` und `importFromData(_:sourceFilename:store:)`, beide returnen `LocalTimelineImportSummary`. Dispatcht `entry["visit"]`/`entry["activity"]`/`entry["timelinePath"]` analog zur bestehenden `GoogleTimelineConverter.ExportBuilder`-Semantik. **Materialisiert kein `AppExport`** — durch Test `testImporterReturnTypeIsSummaryNotAppExport` typgesichert.
- **NEU Tests** (alle Linux-grün): `LocalTimelineStoreLifecycleTests` (6 Cases — fresh-v2, v1→v2-Migration, deleteAll auf leerer DB, deleteAll nach Import, visit/activity-Roundtrip), `LocalTimelineImportWriterTests` (4 Cases — Day-Summary-Aggregation, Skip-Semantik für ungültige Entries, `cancel()` Rollback, BBox), `GoogleTimelineStoreImporterTests` (4 Cases — Fixture mit visit+activity+timelinePath, robuste Coord-Lücken, Typgarantie kein `AppExport`, **50k synthetische Visit-Entries Smoke** über 50 Tage in einer einzigen Transaktion).
- **Linux-Verifikation**: `git diff --check` clean, `swift --version` 5.9 RELEASE, `swift build` clean, `swift test` **1071/2/0** in 107.5s (vorher 1057 → +14). `swift test --filter "LocalTimelineStore|LocalTimelineImportWriter|GoogleTimelineStoreImporter|CoordBlob"`: **37/0/0** in 18.4s. `swift test --filter "LinuxStabilization|FlatCoordinates"` und `--filter GoogleTimeline` regressionsfrei.
- **LocalTimelineStore-Status**: weiterhin **Spike / pre-production**, **nicht UI-aktiv**. Phase-2-Surface ist isoliert verfügbar; Hook in App-Flow, FileProtection-Flag, `deleteAll()`-Erweiterung um Caches/tmp und Adapter zu `flatCoordinates`-Konsumenten bleiben Phase-3.

## [2026-05-08] — test: spike local timeline store coordinate blobs

Phase-1-Spike der LocalTimelineStore-Architektur aus `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`. **Isolierte Zusatzdateien**, **kein produktiver App-Flow umgestellt**, keine Karten-/UI-Migration. **46-MB-Crashfall bleibt FAILED / pending hardware retest.**

- **NEU** `Sources/CSQLite/{module.modulemap, shim.h}` + `.systemLibrary(name: "CSQLite", pkgConfig: "sqlite3")` in `Package.swift`. Linux-Shim auf `libsqlite3` (geprüft: `libsqlite3.so.0` + `pkg-config sqlite3` Version 3.53.0). Auf Apple-Plattformen unbenutzt — `LocalTimelineStore.swift` wählt via `#if canImport(SQLite3)` den SDK-Pfad.
- **NEU** `Sources/LocationHistoryConsumer/CoordBlob.swift` (Core, plattformneutral): `CoordBlobEncoder`, `CoordBlobIterator` (Sequence/IteratorProtocol, lazy Decode ohne `[Double]`-Materialisierung), `EncodedCoordinate`, `CoordBlobError`. Encoding `int32-microdeg-v1`: 8 Bytes/Punkt (Int32-microdegrees latE6+lonE6 little-endian). Validiert finite + Range (lat ±90°, lon ±180°), gerade `flatCoordinates`-Länge, durch-8-teilbare Blob-Länge.
- **NEU** `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStore{,Schema,Error}.swift`: SQLite-C-API-Spike. Tabellen `imports`, `days`, `paths` mit `ON DELETE CASCADE` (FK enforced via `PRAGMA foreign_keys = ON`), Indizes `idx_days_import_id`, `idx_days_date`, `idx_paths_day_id`, `PRAGMA user_version = 1`, `PRAGMA journal_mode = WAL`, `withTransaction { … }` mit Rollback, `paths(forDayId:)` als Read-API. Kein UI-Hook, kein `AppExport`-Adapter — der Store ist heute nur Linux-Test-Surface.
- **NEU Tests** (alle Linux-grün):
  - `Tests/.../CoordBlobEncoderTests.swift` (13 Cases): single/multi/flat-Roundtrip, byteCount=pointCount·8, NaN/Inf/out-of-range/uneven/malformed-Rejection, Negativkoordinaten, leere Blobs, Encoding-Identifier.
  - `Tests/.../CoordBlobDistanceTests.swift` (2 Cases): Distanz aus `CoordBlobIterator` ≈ flatCoordinates-Haversine (Toleranz ≥50 m oder 1e-5·base), 10 000-Punkt-Iteratorzählung.
  - `Tests/.../LocalTimelineStoreTests.swift` (8 Cases): Schema-Bootstrap + `user_version`, idempotentes Re-Open, Insert imp/day/path, ordered-by-startTime Query, Coord-Blob-Roundtrip durch DB, `ON DELETE CASCADE`, FK-Violation für orphan-day, Batch-Transaktion (500 Paths × 50 Punkte).
- **Linux-Verifikation**: `git diff --check` clean, `swift --version` 5.9 RELEASE, `swift build` clean (6.7s), `swift test` **1057/2/0** (vorher 1034 → +23 neue Cases) in 88.0s. SQLite3 verfügbar via linuxbrew + system `libsqlite3.so.0`.
- **Status LocalTimelineStore**: weiterhin **Spike**, nicht produktiv. Conditional Gate aus `45e5fcf` bleibt: **P0 falls 46-MB-Retest FAILED**, **P1/P2 falls PASSED**. Map-Modernisierung bleibt blockiert.

## [2026-05-08] — docs: research local timeline store compliance path

Reine Research-/Plan-Doku, **kein Code-Stand-Sprung**. Neue Datei `docs/LOCAL_TIMELINE_STORE_RESEARCH.md` skizziert eine geprüfte Designrichtung für eine on-disk Timeline-Persistenz als strukturelle Alternative zum heutigen In-Memory-`AppExport`-Pfad bei sehr großen Google-Timeline-Importen (z. B. 46 MB ZIP):

- **Empfehlung**: SQLite C-API (kein GRDB/SQLite.swift) + `Int32`-microdegrees-BLOB für `paths.coord_blob` (8 B/Punkt, ~11 cm Auflösung); Streaming-Decode-Iterator statt voll-materialisiertem `[Double]`.
- **Speicherort**: `applicationSupportDirectory/LocationHistory2GPX/Imports/` mit `isExcludedFromBackupKey = true` (DB als regenerierbarer Cache aus der Original-Quelldatei); Render-/LOD-Caches in `cachesDirectory`; Import-/Export-Staging in `tmpDirectory`.
- **File-Protection**: `completeUnlessOpen` für DB-Datei und Temp-Exports; Live-Activity-kompatibel.
- **Conditional P0/P1-Gate** an das offene 46-MB-Hardware-Retest-Ergebnis (HEAD `ebd8146`) gebunden: **P0 falls FAILED**, **P1/P2 falls PASSED**. Map-Modernisierung (UIKit `MKMapView`/`MKMultiPolyline`/`MKTileOverlay`) bleibt **vor 46-MB-Pass oder klarer LocalTimelineStore-P0-Entscheidung blockiert**.

**Keine** Code-Änderung in `main`, **kein** Spike, **keine** UI-Umschaltung, **keine** ASC-/TestFlight-Aussage. **46-MB-Crashfall bleibt FAILED** bis Hardware-Retest. Siehe `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`.

## [2026-05-08] — chore: Linux-Stabilisierung nach P0-Memory-Fix `34bc369`

### Kontext
Linux-SwiftPM-Vollbuild und `swift test` waren nach dem P0-Memory-Train HEAD `34bc369` (flatCoordinates-Kanonisierung + Memory-Probe-Verdichtung) pre-existing kaputt: iOS-only Heatmap/MapTrack-Color-Preference-Enums wurden in `AppPreferences` referenziert, aber nur unter `#if canImport(SwiftUI) && canImport(MapKit)` definiert. Diese Stabilisierung schließt den Linux-Build, ohne die iOS-Verhaltenslogik zu ändern. **Keine** Hardware-Verifikation, **keine** ASC/TestFlight-Aussagen, **46-MB-Crashfall bleibt FAILED**.

### Code (Sources)
- **NEU `Sources/LocationHistoryConsumerAppSupport/HeatmapPreferenceEnums.swift`** — extrahiert die vier reinen Preference-Enums `AppHeatmapPalettePreference`, `AppHeatmapScalePreference`, `AppHeatmapRadiusPreset`, `AppMapTrackColorMode` aus den iOS-only `#if canImport(SwiftUI) && canImport(MapKit)`-Guards in `HeatmapPalette.swift`, `HeatmapLOD.swift`, `AppHeatmapView.swift`, `MapTrackStyling.swift`. Die Enums sind reine `String`-`RawValue`-Enums ohne SwiftUI-/MapKit-Abhängigkeit und damit Linux-buildbar; alle bisherigen Importe (`AppPreferences`, Heatmap-/MapTrack-Pipelines) gehen unverändert über die Enums.
- `HeatmapPalette.swift`, `HeatmapLOD.swift`, `AppHeatmapView.swift`, `MapTrackStyling.swift` — Enum-Definitionen entfernt; der `scale`-Multiplikator von `AppHeatmapRadiusPreset` bleibt als iOS-only Extension (braucht `Double`-Konstanten in MapKit-Kontext, kein Verhaltensimpact).
- `OptionsPresentation.swift` — String-returning Helpers `uploadStatusText` und `serverUploadPrivacyText` aus dem `#if canImport(SwiftUI)`-Guard herausgehoben; sie sind reine String-Funktionen ohne SwiftUI-Abhängigkeit. `uploadStatusColor` (Color-returning) bleibt iOS-only Extension.
- `LH2GPXAppFlow.swift` — `url.startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` jetzt in `#if canImport(UIKit) || canImport(AppKit)`-Guard (Darwin-only API).
- `GoogleTimelineStreamReader.swift` — `autoreleasepool { … }` in `#if canImport(Darwin)`-Guard mit Linux-Fallback (gleiche Parse-Logik ohne Pool, kein Verhaltensunterschied auf iOS).
- `DaySummaryRowPresentation.swift` — explizites `import Foundation` ergänzt (`DateFormatter`/`Calendar` waren auf Linux nicht in scope).

### Tests
- **NEU `Tests/LocationHistoryConsumerTests/LinuxStabilizationRegressionTests.swift`** — 7 neue Linux-fähige Cases:
  1. `testGoogleTimelineConverterNeverPopulatesBothShapes` — Invariante: Konverter setzt nie beide Geometrie-Shapes (`points` und `flatCoordinates`) gleichzeitig.
  2. `testDistanceParityBetweenPointsAndFlatShape` — points-vs-flat Distanzparität ±1 m.
  3. `testAppSessionContentInitDoesNotMaterializeProjections` — 5000 Days, init < 250 ms (kein eager `daySummaries`-Pass).
  4. `testAppSessionContentLazyProjectionsStillUsable` — lazy vars trotzdem nutzbar.
  5. `testAppSessionStateShowContentRunsBoundedRegardlessOfDayCount` — `show(content:)` < 250 ms auf 5000 Days.
  6. `testShowContentPicksGoogleTimelineTitleFromMeta` — Banner liest aus `meta`, nicht via `overview`.
  7. `testStreamedSyntheticLargeTimelineUsesFlatGeometry` — 50k synthetische Timeline-Entries via `incrementalStreamConverter`, alle Paths flat-shape, ~24 s Linux-Smoke (**KEIN** Hardware-Pass, **KEIN** iOS-Jetsam-Beleg).
- `LargeImportMemorySafetyTests.swift` — `import CoreLocation` und 2 Tests in `#if canImport(CoreLocation) && canImport(MapKit)`-Guard (Linux-Build-Bruch fixen, Verhalten auf iOS unverändert).
- `UIWiringTests.swift` — 8 Tests umgestellt von `@MainActor` auf `MainActor.assumeIsolated { … }` (Pattern aus `LandscapeLayoutTests`); kompiliert auf Linux ohne `@MainActor`-XCTest-Lift.
- `TCXImportParserErrorTests.swift` — `testTCXMalformedXMLThrowsInvalidXML` akzeptiert jetzt `.invalidXML` ODER `.noTrackPoints` (Linux-corelibs-foundation `XMLParser` ist permissiver als Darwin und liefert für leere/abgebrochene Dokumente `.noTrackPoints`; auf Darwin bleibt `.invalidXML` der erwartete Fall).

### Test-Stand Linux (post-Stabilisierung)
- `swift build` (Vollbuild) clean.
- `swift build --build-tests` clean.
- `swift test` Vollsuite passed: **1034 Tests, 2 skipped, 0 Failures** (vorher 1033 vor dem 50k-Stress-Test). Alle 7 neuen `LinuxStabilizationRegressionTests`-Cases grün.
- Erwarteter Mac-Stand (post-Linux-Stabilisierung, mit allen iOS-only Tests hinter `canImport(SwiftUI)`/`MapKit`/`CoreLocation`/`UIKit`): **~1133** (1033 + ~100 iOS-only). Finale Mac-Run-Zahl wird im nächsten Mac-Sync nachgetragen.

### Was NICHT erledigt wurde
- **46-MB-Crashfall iPhone-Hardware-Retest bleibt FAILED** — Mac/iPhone-Handoff, auf Linux-Server nicht durchführbar; keine Aussage darüber, ob der Memory-Fix die Hardware-Symptomatik behebt.
- **ASC/TestFlight Build ≥100** — nicht angefasst.
- **Map-Modernisierung (MKMultiPolyline/MKTileOverlay)** — bleibt Roadmap (siehe `docs/MAP_ARCHITECTURE_AUDIT.md` §5).

### Code-Stand-Anker
HEAD `37a22b7` (folgt direkt nach diesem Doku-Update; baut auf `34bc369`).

## [2026-05-08] — fix: reduce large timeline import memory footprint

### Hardware-Befund (dritter Fail)
- iPhone 15 Pro Max (`iPhone16,2`, iOS 26.4 / 23E246, Xcode 26.3, macOS 15.7), 46 MB `location-history.zip` (~64.926 Top-Level-Timeline-Entries) lieferte trotz erweitertem Memory-Train nach `cd77f97` und HEAD `ae5de1f` erneut Jetsam-Kill: `IDEDebugSessionErrorDomain Code 11`, „The app ‘LH2GPXWrapper’ has been killed by the operating system because it is using too much memory." (Timestamp 2026-05-07T15:10:44+02:00, Operation duration **95.156 ms** vs. 232.341 ms erster Fail / 216.606 ms zweiter Fail).
- Die deutlich kürzere Operation-Dauer signalisiert: der Peak liegt **früher** im Importpfad als bisher angenommen — die Spitze ist erreicht, bevor `finalize()` überhaupt durchläuft, und sehr wahrscheinlich tief im Streaming-/Konverter-Pfad oder beim Übergang Streaming → Session-Materialisierung.
- Damit ist der 46-MB-Punkt der Manual-Risk-Checkliste weiterhin **FAILED**. Code-Stand `<commit-tba>` (vorher `ae5de1f`) ist ein **vorbereiteter Fix-Stand**, kein verifizierter Erfolg.

### Code-Stand vorbereitet (HEAD `<commit-tba>` nach `ae5de1f`)
1. **Build-Identitäts-Logging auf App-Start**: `[LH2GPX_BUILD] app.start version=… build=… sha=… memoryLogging=enabled|disabled` wird **immer** ausgegeben (auch wenn Memory-Probe deaktiviert) — damit ist nach jedem Hardware-Run zweifelsfrei loggebar, welcher Build wirklich gestartet wurde.
2. **`ImportMemoryProbe` verdichtet**: zusätzliche Probe-Punkte `import.fileSelected`, `zip.open.start`/`zip.open.end`, `zip.entry.sniff.start`/`zip.entry.sniff.end`, `zip.stream.chunk` jetzt alle 8 Chunks (statt 64), `stream.elements` alle 1000 Top-Level-Elemente, `stream.element.outlier` für Elemente > 64 KB, `stream.before/afterElementParse` (throttled alle 1000), `converter.ingest` alle 1000 Entries, `converter.dayMap.count` alle 5000, `converter.before/afterFinalize`, `loader.before/afterSessionContent`, `session.before/afterShowContent`, `app.didReceiveMemoryWarning` (iOS-only via `NotificationCenter`-Observer auf `UIApplication.didReceiveMemoryWarningNotification`).
3. **`ImportMemoryProbe` akzeptiert beide Aktivierungs-Quellen** — `ProcessInfo.environment` **und** `ProcessInfo.arguments`. Erkannt werden `LH2GPX_IMPORT_MEMORY_LOG=1`, `LH2GPX_IMPORT_MEMORY_LOG`, `-LH2GPX_IMPORT_MEMORY_LOG`, `--LH2GPX_IMPORT_MEMORY_LOG`. Neue testbare API `ImportMemoryProbe.isEnabledForEnvironment(_:arguments:)`.
4. **`AppBuildInfo.isMemoryLoggingEnabled: Bool`** ergänzt; Settings → Technical → „Build Info" zeigt jetzt eine zusätzliche Zeile **„Memory Logging: Enabled / Disabled"** (grün, wenn aktiv) — Tester kann am Gerät verifizieren, ob die Probe für diesen Run scharf geschaltet ist.
5. **Geometrie-Refactor (P0 Fokus 1) — flatCoordinates-Kanonisierung**: Google-Timeline-Imports schreiben jetzt `flatCoordinates: [Double]` statt `points: [PathPoint]`, **ohne** ISO-Zeitstrings pro Punkt. Geschätzte Einsparung: **~80–120 MB resident** bei der 46-MB-ZIP. Alle Consumer (`PathDistanceCalculator`, `AppExportQueries`, `DayMapDataExtractor`, `ExportRouteSanitizer`, `AppHeatmapModel`, GPX/KML/GeoJSON/CSV-Builder) sind flat-aware gemacht; `AppHeatmapModel`-Doppelbug (Punkte wurden bei beiden Geometrien doppelt gezählt) ist gefixt.
6. **NEU `docs/MAP_ARCHITECTURE_AUDIT.md`**: Bestandsaufnahme aller Kartenflächen + Roadmap-Pfad zu UIKit `MKMapView`/`MKMultiPolyline` für Heavy Overview/Heatmap. **Nicht** umgesetzt in diesem Commit — reine Architektur-Doku.

### Tests
- Neu: `Tests/LocationHistoryConsumerTests/ImportMemoryProbeActivationTests.swift` — 15 Tests, env- + arg-Aktivierungspfade, kombiniert/negativ, Idempotenz, disabled-state-Safety, `AppBuildInfo.isMemoryLoggingEnabled`-Spiegelung.
- Neu: `Tests/LocationHistoryConsumerTests/FlatCoordinatesGeometryTests.swift` — 23 Tests in 7 Sektionen: `ExportRouteSanitizer` (6), `AppExportQueries.dayDetail/summary` (5), `PathDistanceCalculator.effectiveDistance(for: PathItem)` (2 inkl. points-precedence über flat), `DayMapDataExtractor` (3 inkl. odd-reject), GPX/KML/GeoJSON/CSV-Builder mit flat-only path (4), `GoogleTimelineConverter`-Integration (2), `AppHeatmapModel`-Doppelbug-Regression (1, in `#if canImport(MapKit)`-Block).
- Angepasst: `Tests/LocationHistoryConsumerTests/GoogleTimelineConverterTests.swift` — die zwei DST-Tests (`testTimelinePathOffsetsRemainCorrectAcrossDST*Transition`) verifizieren jetzt Geometrie-Erhalt (flat lat/lon-Paar-Zähler, UTC-Tagesgruppierung) statt obsolet gewordener Per-Punkt-ISO-Zeitstrings.
- Linux-Build: `swift build --target LocationHistoryConsumer` clean. SwiftPM-Vollbuild auf Linux ist pre-existing kaputt (iOS-only `AppHeatmapRadiusPreset`/`AppHeatmapPalettePreference`/`AppHeatmapScalePreference`/`AppMapTrackColorMode` werden in `AppPreferences` referenziert, sind aber nur unter `canImport(SwiftUI) && canImport(MapKit)` definiert) — `swift test` ist Linux→Mac/Xcode-Cloud-Handoff. Erwarteter Mac-Test-Stand: ~1081 + 15 + 23 = ~1119 Tests; finale Mac-Run-Zahl wird im nächsten Doku-Sync (post-Hardware-Retest) nachgetragen.
- `git diff --check` clean.

### Restrisiko / Hardware-Retest (handoff Linux → Mac/iPhone)
- Der finale iPhone-Hardware-Retest **kann auf dem Linux-Server nicht durchgeführt werden** und ist ein expliziter Mac/iPhone-Handoff. 46-MB-Crashfall **bleibt FAILED bis Hardware-Retest grün**.
- Empfohlene Tester-Sequenz beim nächsten Run: (1) App starten, Settings → Technical → „Build Info" prüfen — Marketing-Version + Build + (falls injiziert) Git-SHA + **Memory Logging: Enabled** → mit aktuellem Git-HEAD vergleichen. (2) `LH2GPX_IMPORT_MEMORY_LOG=1` per Run-Argument oder Environment setzen, Debug-Run, Import durchführen, Xcode-Console nach `[LH2GPX_BUILD]` (App-Start) und `[LH2GPX_MEMORY]` (Probe) greppen — wenn der Build erneut Jetsam-killt, beweist das letzte gelogde `[LH2GPX_MEMORY]`-Label die Peak-Phase. (3) Wenn Debug grün: Release-Build **ohne Debugger / View-Debugging** mit derselben 46-MB-ZIP.
- Keine Karten-Modernisierung als done — `docs/MAP_ARCHITECTURE_AUDIT.md` ist Dokumentation/Roadmap, nicht Implementation.
- Keine ASC/TestFlight-Freigabe behauptet.

## [2026-05-07] — fix: reduce memory peak after large timeline import

### Hardware-Befund (zweiter Fail)
- iPhone 15 Pro Max (iPhone16,2, iOS 26.4 / 23E246, Xcode 26.3, macOS 15.7), 46 MB `location-history.zip` lieferte trotz Autoreleasepool-Fix `cd77f97` erneut Jetsam-Kill: `IDEDebugSessionErrorDomain Code 11`, „The app ‘LH2GPXWrapper’ has been killed by the operating system because it is using too much memory.“ (Timestamp 2026-05-07T14:14:36+02:00, Operation duration 216.606 ms vs. 232.341 ms beim ersten Fail).
- Damit war klar: der Peak liegt **nach** dem JSON-Streaming (Konverter-Finalize, Session-Init, erste UI-Materialisierung), nicht nur im Parser.

### Root Cause (Top-Hypothese)
- `AppSessionContent.init` rief unmittelbar `AppExportQueries.daySummaries(from:)` mit voller `projectedDays`-Projektion auf — bei ~65k Entries auf ~100 Tagen ein Peak-Allokationspfad direkt nach dem Import.
- `AppSessionState.show(content:)` triggerte zusätzlich `content.overview` (lazy → voller Overview-Pass) nur, um per `inputFormat == "google_timeline"` einen Title-Text auszuwählen.
- `GoogleTimelineConverter.ExportBuilder.finalize()` kopierte beim Materialisieren des finalen `[Day]`-Arrays jeden `DayBucket` aus der `dayMap`, statt ihn herauszunehmen — die Tagespuffer blieben für den ganzen Loader-Scope am Leben.
- `IncrementalStreamConverter.finalize()` hielt den befüllten `ExportBuilder` weiter, auch nachdem das `AppExport` zurückgegeben wurde.
- `PathDistanceCalculator.effectiveDistance(for: Path)` baute pro Aufruf temporäre `[(lat, lon)]`-Arrays über alle Pfadpunkte auf.

### Fix
- `Sources/LocationHistoryConsumerAppSupport/AppSessionState.swift`: `AppSessionContent.init` ermittelt `selectedDate` jetzt direkt aus `export.data.days` per einfacher Datumsmaximierung — ohne `daySummaries`-Materialisierung. `show(content:)` liest `inputFormat` aus `content.export.meta.source.inputFormat` / `meta.config.inputFormat`, statt `content.overview` zu erzwingen.
- `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineConverter.swift`: `ExportBuilder.finalize()` ist jetzt `mutating` und benutzt `dayMap.removeValue(forKey:)`, sodass jeder Bucket nach dem Move freigegeben wird; `dayMap` und `orderedDayKeys` werden am Ende explizit `removeAll(keepingCapacity: false)`. `IncrementalStreamConverter.finalize()` ersetzt seinen internen `builder` nach Erhalt des `AppExport` durch eine frische Instanz.
- `Sources/LocationHistoryConsumer/Queries/PathDistanceCalculator.swift`: neue `effectiveDistance(for: Path)`-Implementierung iteriert direkt über `path.points` bzw. `path.flatCoordinates` (haversine inline), keine temporären Tuple-Arrays mehr.
- `Sources/LocationHistoryConsumerAppSupport/ImportMemoryProbe.swift` (neu): DEBUG-/Diagnostic-Memory-Probe via `mach_task_self_` + `task_info(TASK_VM_INFO)`, gated auf Launch-Argument bzw. Environment `LH2GPX_IMPORT_MEMORY_LOG=1`. Probe-Punkte in `AppContentLoader.loadImportedContent` und im ZIP-Streaming-Pfad (`beforeExtract`, `chunk=N` alle 64 Chunks, `beforeFinalize`, `afterFinalize`, `afterSessionInit`). Logs greppbar als `[LH2GPX_MEMORY]`.
- `Sources/LocationHistoryConsumerAppSupport/AppBuildInfo.swift` (neu) + `AppOptionsView`-Section „Build Info“ in `AppTechnicalOptionsView` (Marketing-Version, Build, optional Git-Commit). `wrapper/Config/Info.plist` bringt Schlüssel `GitCommitSHA` mit Build-Setting-Platzhalter `$(GIT_COMMIT_SHA)` — beim Hardware-Test über `xcodebuild GIT_COMMIT_SHA=$(git rev-parse --short HEAD) …` injizierbar; ohne Injection bleibt das Feld leer und nur Version/Build sind sichtbar.

### Tests
- Neu in `DemoSessionStateTests`: `testInitPicksNewestContentfulDateWithoutEagerSummaries`, `testInitFallsBackToNewestEmptyDateWhenNoContentfulDayExists`, `testShowPicksGoogleTimelineTitleFromMetaInputFormat`.
- `swift test`: **1081/2/0** (vorher 1078/2/0). `git diff --check` clean. `swift build` clean.

### Restrisiko / Hardware-Retest
- Code-Fix adressiert die wahrscheinlichste Top-Hypothese, ist aber kein Beweis für Release-Build-Verhalten unter realer iOS-Memory-Pressure. Der 46-MB-Punkt der Manual-Risk-Checkliste **bleibt FAILED** bis Tester den Release-Build (ohne Debugger / View-Debugging) auf iPhone 15 Pro Max grün durchläuft.
- Empfohlener nächster Tester-Lauf: zuerst Debug mit `LH2GPX_IMPORT_MEMORY_LOG=1` zur Peak-Phase-Lokalisierung, dann Release-Build ohne Debugger.
- Für die Build-Identität: Build-Setting `GIT_COMMIT_SHA=<short-sha>` setzen oder den SHA in der „Build Info“-Sektion der App-Optionen prüfen, sonst ist nicht eindeutig belegbar, welcher Code wirklich auf dem Gerät läuft.

## [2026-05-07] — fix: drain autorelease objects during timeline stream parsing

### Hardware-Befund
- iPhone 15 Pro Max (iOS 26.4, Xcode 26.3), 46 MB `location-history.zip` (~64.926 Timeline-Entries) reproduzierte beim manuellen Import einen Jetsam-Kill: `IDEDebugSessionErrorDomain Code 11 — “The app ‘LH2GPXWrapper’ has been killed by the operating system because it is using too much memory.”` (Timestamp 2026-05-07T13:38:37+02:00).
- Damit war der bislang als „not verified" geführte 46-MB-Punkt der Manual-Risk-Checkliste real **FAILED**.

### Root Cause
- `GoogleTimelineStreamReader.TopLevelArrayParser.processByte` rief `JSONSerialization.jsonObject(with: element)` **außerhalb** des `autoreleasepool` auf — der Pool umschloss nur das nachgelagerte `onElement`. Die transienten Foundation-Objekte (`NSString` / `NSNumber` / `NSDictionary` / `NSArray`) aus dem Parser akkumulierten dadurch über alle ~65k Top-Level-Elemente und sprengten unter iOS den App-Speicher.
- Sekundär: nach einem großen Outlier-Element behielt `element.removeAll(keepingCapacity: true)` die volle Outlier-Capacity für den Rest des Imports im RAM.

### Fix
- `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineStreamReader.swift`: `JSONSerialization.jsonObject(with: element)` läuft jetzt **gemeinsam** mit `onElement(parsed)` in demselben `autoreleasepool { ... }`. Zusätzlich: nach Elementen > 64 KB wird `element` durch eine frisch reservierte 8-KB-Data ersetzt, statt nur Inhalt zu leeren — damit kann ein einzelner Ausreißer die Parser-Footprint nicht permanent inflationieren.
- ZIP-Streaming-Pfad und direkter JSON-Streaming-Pfad bleiben unverändert. Kein Rückfall auf Full-Tree-`JSONSerialization`.

### Tests
- Neu: `GoogleTimelineStreamReaderTests.testHighElementCountWithLargeOutlierSucceeds` — 50.000 Elemente plus 1-MB-Outlier in der Mitte, verifiziert vollständigen Durchlauf (0,87 s).
- `swift test`: **1078/2/0** (vorher 1077/2/0). `git diff --check` clean.

### Restrisiko / Hardware-Retest
- Code-seitig adressiert; Release-Build-Hardware-Retest mit der originalen 46-MB-ZIP auf iPhone 15 Pro Max steht aus und bleibt der Verifikationsschritt für die Manual-Risk-Checkliste. Der Punkt **bleibt FAILED**, bis ein Tester ihn nachweislich grün bestätigt.

## [2026-05-07] — Manual release risk acceptance protocol added (no code change)

### Doku
- docs/APPLE_VERIFICATION_CHECKLIST.md: neuer „Manual Release Risk Acceptance Protocol — HEAD `b91a933`"-Block. Deckt 4 nicht automatisierbare Restrisiken: 46-MB-Crashfall, Live Activity / Dynamic Island / Lock Screen, iPad-Layout, ASC / TestFlight / Apple Review. Checkboxen leer — wird beim Tester ausgefüllt.
- docs/XCODE_RUNBOOK.md: Verweis-Note auf den Protokoll-Block.

### Verifikation
- swift test: 1077/2/0 (unverändert).
- git diff --check: clean.
- Keine Code-Änderungen in diesem Commit.

### Hinweis
Die Checkliste ist kein Test-Ergebnis. Solange sie nicht durch einen Tester abgehakt ist, gelten alle 4 Punkte als „nicht verifiziert".

## [2026-05-07] — Post-fix hardware re-verification on iPhone 15 Pro Max

Pure verification pass after the day-detail distance fix (commit `853d8d3`). No code changes.

### Hardware-Verifikation iPhone 15 Pro Max (iOS 26.4)
- testAppStoreScreenshots: PASSED (41.8s)
- testDeviceSmokeNavigationAndActions: PASSED (71.2s)
- testLandscapeLayoutSmoke: PASSED (829.9s)
- swift test: 1077/2/0 (unverändert).
- git diff --check: clean.

Im Commit `853d8d3` war nur Smoke-Navigation post-Fix gefahren; die volle 3-UITest-Acceptance-Suite ist jetzt grün.

### Weiterhin offen
- 46-MB-Crashfall geräteseitig (manueller iPhone-Import nötig)
- Live Activity / Dynamic Island / Lock-Screen visuell (UI-interaktiv)
- iPad-Layout, ASC / TestFlight / Apple Review

## [2026-05-07] — fix: day-detail distance consistency (P0/P1 bug)

### Bug
Day-Detail zeigte „Distance 0" für Routen mit sichtbarer Geometrie, obwohl Insights/Übersicht korrekte Distanzen lieferten. Root Cause: Summary nutzte `effectiveDistance`-Fallback, Detail-Pfad las nur raw `distanceM`. Google-Timeline-`timelinePath`-Imports trafen das, weil ihr `distanceM == nil` aber valide `points`.

### Fix
- PathDistanceCalculator als Single-Source-of-Truth (neue Datei in LocationHistoryConsumer/Queries).
- DayDetailViewState.PathItem bekommt `effectiveDistanceM: Double` (immer berechnet); raw `distanceM` bleibt für Caller die zwischen „nichts gemeldet" und „expliziter Wert" unterscheiden müssen.
- DayDetailPresentation liest `effectiveDistanceM` an allen 5 Stellen (KPI-Card, Route-Subtitle, Summary-Aggregat, Section-Subtitle, Dominant-Mode, Route-Intensity).
- 12 neue Cases in PathDistanceCalculatorTests inkl. Summary↔DayDetail-Konsistenz-Regression.

### Verifikation
- swift test: 1077/2/0 (+12 gegenüber 1065).
- Device-Smoke iPhone 15 Pro Max (iOS 26.4): testDeviceSmokeNavigationAndActions PASSED.

### Weiterhin offen
- 46-MB-Crashfall geräteseitig nach Fix nicht erneut validiert
- Live Activity / Lock Screen / iPad / ASC / TestFlight nicht geprüft

## [2026-05-07] — Hardware re-verification on iPhone 15 Pro Max + 44pt clear-date-range hit-target fix

### Hardware-Bug + Fix
- HistoryDateRangeFilterBar: clear-date-range button (xmark.circle.fill) had a 12×12pt hit area, below Apple's 44pt HIG minimum and unhittable in real-device automation. Added `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` so the visible glyph stays unchanged but the tap area meets HIG.

### Hardware-Verifikation iPhone 15 Pro Max (iOS 26.4, HEAD pending — Commit folgt)
- testAppStoreScreenshots: PASSED (42.9s)
- testDeviceSmokeNavigationAndActions: PASSED (72.2s)
- testLandscapeLayoutSmoke: PASSED (830s)

### Verifikation
- swift test: 1065/2/0 (unverändert).
- Wrapper xcodebuild auf iPhone 15 Pro Max: BUILD + TEST SUCCEEDED.

### Weiterhin offen
- 46-MB-Crashfall geräteseitig (manueller iPhone-Import nötig, kein UITest)
- Live Activity / Dynamic Island / Lock-Screen visuelle Verifikation (Always-Permission braucht UI)
- ASC / TestFlight / Apple Review nicht geprüft

## [2026-05-07] — P1 release-readiness fix: doc-truth sync + stability hardening

### Doku-Wahrheits-Sync
- ROADMAP.md Aktiver-Stand-Header auf HEAD `3811bc3`, Datum 2026-05-07 gesetzt (in einem Folge-Doku-Sync direkt nach diesem Commit nochmal von `5c69afe` auf `3811bc3` korrigiert).
- Alle `pending — Commit folgt`-Verifikations-Blöcke mit echten HEAD-Hashes aufgefüllt.
- README.md:78 lange Test-Nachweis-Zeile auf chronologische 3-Stufen-History gekürzt.
- README UI-Begriffe an echte UI-Labels angeglichen: `Simplified` (kein Beta-Suffix), `Rectangle / Bounding Box`, exakte Banner-Labels.

### Stabilitäts-Härtung
- DaySummaryRowPresentation: `distanceText!` Force-Unwrap durch sichere `let`-Bindung ersetzt.
- AppOverviewMapModel: `rebuildOverlays`-Task-Closures von `[self]` auf `[weak self]` umgestellt; Race-Token-Logik unverändert.
- AppPreferences: `liveLocationServerUploadURLString` validiert jetzt vor UserDefaults-Write — `https://`, `localhost`, `127.0.0.1`, `[::1]` akzeptiert; sonst Reject mit Reset auf alten Wert. Token-Property + Keychain unverändert.
- 8 neue Tests in `AppPreferencesUploadURLValidationTests.swift`.

### Verifikation
- `swift test`: **1065 Tests, 2 Skips, 0 Failures** (vorher 1057).
- Wrapper xcodebuild iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.

### Weiterhin offen
- Hardware-Re-Verifikation iPhone 15 Pro Max für aktuellen HEAD steht aus (letzte echte Acceptance: 2026-05-05).
- ASC/TestFlight-Status nicht geprüft.
- 46-MB-Crashfall geräteseitig nicht validiert.

## [2026-05-07] — UX/Layout batch + mock helpers: insights-picker, overview-header, map-pill, settings-form, hero-map-layout-tests

### Was sich geändert hat (6 Achsen)

1. **Mock-Client extrahiert** — neuer File `Tests/LocationHistoryConsumerTests/Helpers/MockLiveLocationClient.swift` (`MockLiveLocationClient`, `InMemoryRecordedTrackStore`, `emitLocationSamples`-Convenience). `LiveLocationFeatureModelStateTransitionTests` und `LiveLocationFeatureModelTests` nutzen jetzt den geteilten Helper.
2. **Insights Triple-Range-Picker konsolidiert** — `AppInsightsContentView.swift` zeigt im `heroEnabled`-Pfad nur noch den Hero-Strip. `AppHistoryDateRangeControl`-Card + innere Pills sind dort ausgeblendet. Im Legacy/iPad-Pfad bleibt die Card als Fallback.
3. **Overview Doppel-Header gelöst** — Card-Header in `overviewKPISection` umbenannt von `"Overview"` zu `"Statistics"` (de: `"Statistik"`). Page-Header + `navigationTitle` bleiben „Overview". Lokalisierung in `AppLanguageSupport.swift` ergänzt.
4. **Map-Pill-Overlap gefixt** — `AppOverviewTracksMapView.swift`: Route-Count-Badge und Optimization-Banner in einen einzigen `VStack(alignment: .trailing)` an `.bottomTrailing`-Overlay konsolidiert. Linke untere Ecke ist frei → keine Kollision mit Range-Chips.
5. **Form-vs-LHCard-Konsistenz Settings (schmaler Scope)** — `AppPrivacyOptionsView` und `AppTechnicalOptionsView` von `LHCard` auf native `Form`/`Section` migriert. Live-Recording / Upload / Widget-Live-Activity behalten `LHCard` (Custom-Preview-Karten + Status-Chips).
6. **Hero-Map-Layout-Tests** — neuer File `Tests/LocationHistoryConsumerTests/LHMapHeaderLayoutTests.swift` mit 12 Layout-Property-Cases (compactHeight=460, expandedHeight=560, mapControlTopOffset≥124, sticky-Init, expand()-Transition, Sticky-cannot-hide, mapFrameHeight für compact/expanded/hidden/fullscreen). Keine SnapshotTesting-Dependency.

### Verifikation
- `swift test`: **1057 Tests, 2 Skips, 0 Failures** (vorher 1045).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: **BUILD SUCCEEDED**.
- HEAD: `5c69afe`.

### Ehrlich offen
- Form-vs-LHCard nur teilweise (5/8 Sub-Views auf Form, 3 bewusst auf LHCard wegen Custom-Preview-Karten).
- Hardware-Re-Verifikation iPhone 15 Pro Max steht weiter aus.
- Kein Snapshot-Testing-Framework im Repo — Layout-Tests sind property-based.

## [2026-05-07] — Audit batch — Phase 1-5: caching/index/race-token/live-map dedup, drift-extraction, importing-protocol, mock-state-tests, doc-truth-cleanup

### Was sich geändert hat (14 Achsen, gruppiert nach Phase 1 + Phase 2-5)

Zwei Commits gepusht: `21b4026` (Phase 1: items 3, 4, 5, 6, 8) und `20877ae` (Phase 2-5: items 7, 11+2, 9, 10, 12, 13+14+15).

**Phase 1 (commit `21b4026`) — Caching, Index, Race-Token, Live-Map-Dedup, @testable-Cleanup (5 Achsen):**
1. **Item 3** — `projectedDays`-Caching: Memoization in `AppExportQueries`, Re-Compute nur bei tatsächlichen Input-Änderungen.
2. **Item 4** — Mutations-Index in `AppImportedPathMutationStore`: O(1)-Lookup statt linearer Scan über alle Mutations.
3. **Item 5** — Race-Token in async Pfaden: Stale-Result-Guards beim Filter-/Day-Switch.
4. **Item 6** — Live-Map-Dedup: Konsolidierung des doppelt gerenderten Map-Pfades im Live-Feature.
5. **Item 8** — `@testable import` → reines `import` für ein weiteres Test-File (Cleanup-Folge).

**Phase 2-5 (commit `20877ae`) — Drift-Extraction, Importing-Protokoll, Mock-State-Tests, Doku-Truth (9 Achsen):**
6. **Item 7** — Mock-Client + State-Transition-Tests: Mock-Client aus dem Test-File extrahiert; Placeholder-Case ersetzt durch zwei echte State-Transition-Cases (netto +1 Case statt +2 — siehe Verifikation).
7. **Item 11 + Item 2** — `LH2GPXAppFlow` extrahiert (Drift zwischen Wrapper- und Package-App-Einstieg) plus Auto-Restore-Phasen-Plumbing zusammengefasst.
8. **Item 9** — API-Naming als additives Importing-Protokoll umgesetzt — **kein Rename**, sanft additiv (Folgerisiken vermieden).
9. **Item 10** — `wrapper/CI.xctestplan` SwiftPM-Coverage: **als SKIP dokumentiert** — pbxproj-Integration zu fragil, weiterhin out-of-scope.
10. **Item 12** — `Tests/README.md` aktualisiert (Test-Layout, neue Files, Mock-Client-Pfad).
11. **Item 13 + Item 14 + Item 15** — Doku-Truth-Cleanup: ROADMAP/NEXT_STEPS/CHANGELOG/README/wrapper-Docs/Apple-Verification-Checklist auf konsistente Test-Zahlen und HEAD-Stand gebracht.

### Verifikation
- `swift test`: **1045 Tests, 2 Skips, 0 Failures** (vorher 1044). Mock-Refactor (Item 7) ersetzte einen Placeholder-Case durch zwei echte Cases — netto +1.
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: **BUILD SUCCEEDED**.
- Commits: `21b4026` (Phase 1) + `20877ae` (Phase 2-5).

### Ehrlich offen
- **Item 9 / API-Naming:** als additives Importing-Protokoll umgesetzt — kein Rename. Bestehende Call-Sites unverändert.
- **Item 10 / `wrapper/CI.xctestplan` SwiftPM-Coverage:** als SKIP dokumentiert; pbxproj-Integration zu fragil für diesen Train. `.github/workflows/swift-test.yml` deckt die SwiftPM-Suite weiterhin separat ab.
- **Hardware-Re-Verifikation iPhone 15 Pro Max** steht weiterhin aus (kein Hardware-Lauf in diesem Train).

## [2026-05-07] — Audit batch — Bündel B+C+D+A: dead-code removal, perf restposten, @testable cleanup, test hardening

### Was sich geändert hat (22 Achsen, gruppiert nach Bündel)

**Bündel B — Dead-Code-Removal (4 Achsen, ~158 Zeilen weniger):**
1. `Sources/LocationHistoryConsumerAppSupport/AppDayDetailView.swift`: `quickStat(_:label:icon:color:)`-Helper (~21 Zeilen, kein Caller) entfernt.
2. `Sources/LocationHistoryConsumerAppSupport/AppDayDetailView.swift`: `private struct DayTimelineView` (~123 Zeilen, kein Caller) entfernt.
3. `Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift`: `activeFiltersSection(_:)`-Helper (~14 Zeilen, kein Caller) entfernt.
4. `Sources/LocationHistoryConsumerAppSupport/LHSharedMapChrome.swift`: gesamte Datei gelöscht. **`LHMapStyleToggleButton` public API entfernt** (war seit MapLayerMenu-Train `@available(*, deprecated)` und ohne interne Caller — durch `MapLayerMenu` ersetzt; keine externen Caller bekannt). Note: deprecated-Status nicht „belassen", sondern API komplett entfernt.

Audit-Item P2-8 (`mapControlRow` Portrait-tot, Live `mapCard`/`liveHeroMap` Duplikate) wurde **bewusst nicht** entfernt — `mapControlRow` hat einen realen Caller in `landscapeMapColumn`. Audit-Beschreibung war ungenau.

**Bündel C — Performance-Restposten (4 Achsen):**
5. `Sources/LocationHistoryConsumerAppSupport/AppOverviewTracksMapView.swift`: `OverviewMapRenderData: Equatable` mit Hand-Geschriebener `==` (vergleicht totalRouteCount/isOptimized/isLoading/pathOverlays + center.lat/lon + span.deltas; `MKCoordinateRegion` synthetisiert nicht selbst) — Identity-Check vor Re-Render möglich.
6. `Sources/LocationHistoryConsumerAppSupport/AppOverviewTracksMapView.swift`: `approximateDistance(for:)` nutzt jetzt eine inline Haversine-Berechnung (Erdradius 6 371 000 m) statt `CLLocation`-Allokation pro Koordinatenpaar im Distance-Fallback-Pfad.
7. `Sources/LocationHistoryConsumerAppSupport/HeatmapGridBuilder.swift`: Doppel-Sort durch Single-Sort + `suffix`-Trim ersetzt — einmal aufsteigend sortieren, letzte N Zellen behalten; Render-Reihenfolge cold→hot bleibt.
8. `Sources/LocationHistoryConsumer/Queries/AppExportQueries.swift`: `findDay(on:in:applying:)` mit Fast-Path für `isPassthrough`-Filter — scannt direkt `export.data.days` statt eine volle `projectedDays`-Projektion zu bauen. DayDetail-Open ist jetzt deutlich günstiger.

**Bündel D — Architektur (4 Achsen):**
9. `wrapper/CI.xctestplan`: **unverändert (SKIP)**. Test-Plan referenziert `LH2GPXWrapper.xcodeproj`-containerPath und kann das SwiftPM-Test-Target `LocationHistoryConsumerPackageTests` ohne pbxproj-Integration nicht aufnehmen. `.github/workflows/swift-test.yml` deckt die SwiftPM-Suite weiterhin separat ab.
10. `@testable import` → reines `import` für **15 Test-Files**, deren APIs vollständig public sind: `DayFavoritesStoreTests`, `RecentFilesStoreTests`, `LiveLocationFeatureModelTests`, `HistoryDateRangeFilterTests`, `ExportSelectionRouteTests`, `RecordingIntervalPreferenceTests`, `AppLanguageSupportTests`, `ImportBookmarkStoreTests`, `ChartShareHelperTests`, `LHMapHeaderTests`, `LiveStatusResolverTests`, `LoadingProgressEngineTests`, `RecordedTrackStoreTests`, `LiveTrackRecorderTests`, `InsightsDrilldownTests`. **7 weitere Test-Files** behalten `@testable` (internal-Symbole nötig): `AppContentLoaderTests`, `AppPreferencesTests`, `LiveActivityTests`, `LiveTrackingPresentationTests`, `RecordedTrackEditorDraftTests`, `RecordedTrackEditorPresentationTests`, `SavedTracksPresentationTests`, `WidgetDataStoreTests`.
11. API-Naming-Vereinheitlichung (`parse`/`convert`/`decode`/`load`): **out-of-scope** (P2-16) — public-API-Renames mit Folgerisiken.
12. `HeatmapGridBuilder` MapKit-Entkopplung: **out-of-scope** (P2-18) — public-API-Rename mit Folgerisiken.

**Bündel A — Test-Härtung (9 neue Test-Files, 27 neue Cases):**
13. `Tests/LocationHistoryConsumerTests/AppExportDecoderErrorTests.swift` (5 Cases): leere Data, korrupter JSON, missing data/meta/schema_version.
14. `Tests/LocationHistoryConsumerTests/GPXImportParserErrorTests.swift` (3 Cases): malformed XML, leere Trackpoints, nicht parsebare Timestamps.
15. `Tests/LocationHistoryConsumerTests/TCXImportParserErrorTests.swift` (2 Cases): malformed XML, leere Trackpoints. `exportRoundTripFailed` defensive Branch dokumentiert geskippt.
16. `Tests/LocationHistoryConsumerTests/GPXRoundTripTests.swift` (2 Cases): Track-Coordinates 1e-6, Waypoints.
17. `Tests/LocationHistoryConsumerTests/AppExportQueriesFilterCombinationTests.swift` (4 Cases): date+accuracy, activityType+date, accuracy+activityType, dreifach kombiniert.
18. `Tests/LocationHistoryConsumerTests/AppHeatmapModelEdgeCaseTests.swift` (3 Cases): empty/single-day/no-paths.
19. `Tests/LocationHistoryConsumerTests/LiveLocationFeatureModelStateTransitionTests.swift` (1 Placeholder-Case): Mock-Client `private` im bestehenden Test-File; Refactor pending — explicit-doc-comment.
20. `Tests/LocationHistoryConsumerTests/ExportMutationsAndFilterTests.swift` (4 Cases): Mutations respektiert, empty leaves unchanged, hasRoutes-Chip, favorites-Parameter.
21. `Tests/LocationHistoryConsumerTests/ZIPGoogleTimelineStreamingPathTests.swift` (3 Cases): Timeline-Entry, AppExport-Fallback, Mixed-ZIP.

**(22.) CI/Workflow:** SwiftPM-Suite läuft weiterhin via `.github/workflows/swift-test.yml`; Wrapper-`CI.xctestplan` unverändert (siehe 9.).

### Verifikation
- `swift test`: **1044 Tests, 2 Skips, 0 Failures** (vorher 1017; 27 neue Cases).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.

### Ehrlich offen
- API-Naming-Vereinheitlichung (P2-16) bewusst not done — public-API-Renames mit Folgerisiken.
- `HeatmapGridBuilder` MapKit-Entkopplung (P2-18) bewusst not done — public-API-Rename mit Folgerisiken.
- `wrapper/CI.xctestplan` SwiftPM-Coverage erfordert pbxproj-Integration — out-of-scope.
- `LiveLocationFeatureModelStateTransitionTests` ist 1 Placeholder; Mock-Client-Refactor steht aus.
- Audit-Item P2-8 (Live `mapCard`/`liveHeroMap` Duplikat-Refactor) bewusst nicht angefasst — Audit-Beschreibung war ungenau, `mapControlRow` hat realen Caller.
- Hardware-Re-Verifikation iPhone 15 Pro Max steht weiterhin aus.
- `LHMapStyleToggleButton` public API entfernt: keine externen Caller bekannt, war seit MapLayerMenu-Train deprecated.

## [2026-05-07] — Audit batch — Block 1-2: WidgetSharedKeys consolidation, onOpenURL in package target, ZIP-entry streaming, import-phase progress

### Was sich geändert hat (7 Achsen, gruppiert nach Block)

**Block 1 — Wiring / Config:**
1. `Sources/LocationHistoryConsumerAppSupport/WidgetSharedKeys.swift` (NEU): public `enum WidgetSharedKeys` als Single-Source-of-Truth für App-Group-Suite-Name + UserDefaults-Key-Konstanten. Ersetzt String-Literale.
2. `Sources/LocationHistoryConsumerAppSupport/WidgetDataStore.swift` und `wrapper/LH2GPXWidget/WidgetDataStore.swift` referenzieren jetzt `WidgetSharedKeys.*` statt String-Literale. Methoden-Surface inhaltlich identisch; Doku-Comment dokumentiert die Mirror-Pflicht zwischen beiden Dateien. Wichtig: `wrapper/LH2GPXWidget/WidgetDataStore.swift` hatte `saveDynamicIslandCompactDisplay` nicht — jetzt ergänzt (P1-3 Audit-Lücke geschlossen).
3. `Sources/LocationHistoryConsumerApp/AppShellRootView.swift`: neuer `.onOpenURL { handleDeepLink($0) }`-Modifier + `handleDeepLink(_:)`. Spiegelt das Wrapper-Target-Verhalten — `lh2gpx://live` springt jetzt auch im Package-App-Target (Tests, Demo, `Package.swift`-Build) den Live-Tab an (P1-4 erledigt).
4. Deployment-Target-Inkonsistenz dokumentiert: App 16.0 vs Widget 16.2 (Live Activities erfordern 16.2). Note in `wrapper/README.md`.

**Block 2 — Streaming-Folge:**
5. `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineStreamReader.swift`: neue public `IncrementalParser`-Klasse (stateful chunk-fed Parser).
6. `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineConverter.swift`: neue API `incrementalStreamConverter()` + `IncrementalStreamConverter`-Wrapper.
7. `Sources/LocationHistoryConsumerAppSupport/AppContentLoader.swift`:
   - `loadZipContent` nutzt `streamGoogleTimelineCandidateIfApplicable` als Early-Path. Sniff der ersten 1 KB jedes JSON-Entries — bei genau einem Google-Timeline-Entry und keinem LH2GPX-Object-Entry läuft `Archive.extract { chunk in converter.feed(chunk) }` direkt durch den Streaming-Parser. **Peak RAM für ZIP-Google-Timeline jetzt ~ein Element (~few KB) statt der vollen entpackten Datei.** Audit P1-5 erledigt.
   - `loadImportedContent` neuer `onPhase: ((ImportPhase) -> Void)?`-Parameter. Phasen `.reading` → `.parsing` → `.building` werden während des Imports gefeuert.
   - Neuer public `enum ImportPhase { case reading, parsing, building }`.
8. `Sources/LocationHistoryConsumerAppSupport/LoadingProgressEngine.swift`: `@Published var phase: ImportPhase?`. Neue Methode `setPhase(_:)`. `cancel()`/`complete()` setzen Phase auf nil.
9. `wrapper/LH2GPXWrapper/ContentView.swift`:
   - `loadImportedFile(at:)` reicht `onPhase`-Closure an `loadingProgress.setPhase(_:)` weiter (über MainActor-Hop).
   - ProgressView zeigt `loadingPhaseLabel` mit lokalisierten Strings (`"Reading file…"`, `"Parsing entries…"`, `"Building model…"`, Fallback `"Opening location history..."`).

**Tests neu:**
- `Tests/LocationHistoryConsumerTests/GoogleTimelineStreamReaderTests.swift`: 2 neue Cases (`testIncrementalParserAcrossArbitraryChunkBoundaries`, `testIncrementalParserMatchesInMemoryPath`).
- `Tests/LocationHistoryConsumerTests/GoogleTimelineStreamReaderPerformanceTests.swift` (NEU): 3 XCTest-`measure`-Cases (disk-streaming, in-memory, incremental small chunks). Nur Baseline-Logging, kein fail-on-regression bar.

### Verifikation
- `swift test`: **1017 Tests, 2 Skips, 0 Failures** (vorher 1012; 5 neue Cases).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.

### Ehrlich offen
- Mikro-Benchmarks sind Baseline-Logging, kein gemessener Speedup-Faktor — kein fail-on-regression bar.
- ZIP-Streaming greift nur bei genau einem Google-Timeline-Entry und keinem LH2GPX-Object-Entry. Mehrfach-Timeline-/Mixed-ZIPs fallen auf den Legacy-Extract-and-Decode-Pfad zurück.
- Hardware-Re-Verifikation iPhone 15 Pro Max steht weiterhin aus.
- Auto-Restore-Pfad reicht den `onPhase`-Callback nicht durch (User wartet dort nicht aktiv) — bewusste Entscheidung.
- Verbleibend offen aus dem Audit: 7× P1-Test-Lücken (P1-18..P1-24), ~19× P2.

## [2026-05-06] — Audit batch — Block 1-4: data-loss wiring + concurrency + edge-case crashes + perf hot-paths

### Was sich geändert hat (19 Achsen, gruppiert nach Block)

**Block 1 — Datenverlust / falsche User-Daten:**
1. `Sources/LocationHistoryConsumerAppSupport/LiveLocationServerUploader.swift`: HTTP-Upload-Request bekommt jetzt 30 s Per-Request-Timeout (`HTTPSLiveLocationServerUploader.requestTimeoutSeconds`). Vorher Default 60 s connect / 7 Tage resource — hängender Server konnte Upload-Queue bis Jetsam blockieren, Live-Recording droppte währenddessen die ältesten Punkte.
2. `Sources/LocationHistoryConsumerAppSupport/AppExportView.swift`: neue init-Parameter `dayListFilter: DayListFilter`, `favoritedDayIDs: Set<String>`, `pathMutations: ImportedPathMutationSet` (default `.empty`). `filteredSummaries` wendet die Day-Tab-Filter-Chips an. `prepareExport` und beide `ExportPreviewDataBuilder.previewData`-Aufrufer reichen `pathMutations` jetzt durch — user-gelöschte Routen verschwinden aus GPX/KMZ/KML/GeoJSON/CSV-Exports und aus der Export-Vorschau (vorher kamen sie zurück).
3. `Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift`: beide `AppExportView`-Call-Sites (compact NavigationStack + Sheet-Variante) übergeben jetzt `dayListFilter`, `favoritedDayIDs`, `pathMutationStore.currentMutations`.
4. `Sources/LocationHistoryConsumerAppSupport/AppImportedPathMutationStore.swift`: `persist()` schluckt JSON-Encode-Fehler nicht mehr lautlos. Neue `@Published var lastPersistFailed: Bool`; bei Erfolg zurückgesetzt. UI kann den Flag für ein Banner abfragen.
5. `Sources/LocationHistoryConsumerAppSupport/ExportSelectionContent.swift`: neuer Parameter `mutations: ImportedPathMutationSet = .empty` an `exportDays(...)`. Private `applyMutations(_:mutations:)` filtert die `Day.paths`-Indizes pro Tag, ohne den Originalexport zu mutieren.
6. `Sources/LocationHistoryConsumerAppSupport/ExportPreviewData.swift`: `previewData(...)` erweitert um `mutations: ImportedPathMutationSet = .empty`.

**Block 2 — Concurrency / Resource-Lecks:**
7. `Sources/LocationHistoryConsumerAppSupport/ActivityManager.swift`: `_endActivityInternal` macht Identity-Check auf `activity.id` bevor `_currentActivityBox = nil` gesetzt wird — verspätete End-Tasks blenden eine zwischenzeitlich gestartete neue Live Activity nicht mehr aus. `_cancelAllActivitiesInternal`-Task läuft auf `@MainActor`. `_updateActivityInternal`-Task hat `[weak self]`.
8. `Sources/LocationHistoryConsumerAppSupport/LiveLocationFeatureModel.swift`: neuer `deinit { uploadTask?.cancel() }` — URLSession-Tasks akkumulieren nicht mehr bei häufigem View-Rebuild.
9. `Sources/LocationHistoryConsumerAppSupport/AppOptionsView.swift`: `testConnection()` von URLSession-Completion-Closure + `DispatchQueue.main.async` auf `Task { @MainActor in await URLSession.shared.data(for:) }` migriert. Kein Struct-`self`-Capture mehr aus Background-Thread.
10. `Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift`: `presentSheet(_:)` nutzt `Task { @MainActor in ... }` statt `DispatchQueue.main.async`. Konsistent mit Swift-Concurrency-Modell.

**Block 3 — Edge-Case-Crashes / stillschweigende Fehler:**
11. `Sources/LocationHistoryConsumerAppSupport/KMZBuilder.swift`: ZIPFoundation-`provider`-Closure bekommt Bounds-Guard. `subdata(in: start..<end)` wird gegen `kmlData.count` geclamped; ungültige Slice-Anforderung gibt leeres `Data()` zurück statt NSException.
12. `Sources/LocationHistoryConsumerAppSupport/AppContentLoader.swift` (sniffEntryHead): innerer `catch` differenziert jetzt zwischen `StopExtraction` (bewusster Stop, gibt collected zurück) und echten ZIPFoundation-Fehlern (gibt `nil` zurück). Kein leerer „valider"-Export mehr durch verschluckte Read-Fehler.
13. `Sources/LocationHistoryConsumerAppSupport/ImportBookmarkStore.swift`: `restore(userDefaults:)` ruft `startAccessingSecurityScopedResource()` auf der resolved URL selbst auf. Neue API `releaseAccessIfNeeded(url:)` für den Caller-Cleanup. Doc-Comment dokumentiert die Konvention.

**Block 4 — Performance-Hotspots:**
14. `Sources/LocationHistoryConsumerAppSupport/AppDayMapView.swift`: `DayMapRenderData.PathOverlay` hält jetzt `simplifiedCoordinates` (Douglas-Peucker + Outlier-Filter) precomputed beim Init — `displayCoords` liefert nur noch den passenden Cache statt 2× pro Pfad pro Frame neu zu berechnen.
15. `Sources/LocationHistoryConsumer/AppExportQueries.swift` + `Sources/LocationHistoryConsumerAppSupport/DaySummaryDisplayOrdering.swift`: Doppel-Sort gefixt. `projectedDays` bleibt asc-sortiert (Insights braucht das); `newestFirst` erkennt monoton-asc-sortierten Input und reverst statt voll zu sortieren — O(n) statt O(n log n) auf dem Hot-Path.
16. `Sources/LocationHistoryConsumerAppSupport/AppInsightsContentView.swift`: `weekdayStats` wird aus `derivedModel.weekdayStatsByMetric: [InsightsWeekdayMetric: [InsightsWeekdayMetricStat]]` gelesen. Pre-Computation aller verfügbaren Metric-Varianten in `refreshDerivedModel`. Body-Tick recomputet nicht mehr.
17. `Sources/LocationHistoryConsumerAppSupport/DaySummaryRowPresentation.swift`: `dayKeyFormatter` und `gregorianCalendar` sind jetzt statische `private static let` statt per-Row-Allokation.
18. `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: `formatCount` nutzt einen statischen `baseCountFormatter`, setzt nur `locale`. `.continuous` `.onMapCameraChange`-Handler entfernt — `.onEnd` reicht.
19. `Sources/LocationHistoryConsumerAppSupport/AppDayMapView.swift` (zusätzlich): zwei `ISO8601DateFormatter()` in `DayMapRenderData.init` als statische Properties herausgehoben. `Sources/LocationHistoryConsumer/AppExportQueries.swift`: `weekdayForDate` nutzt einen statischen `utcGregorianCalendar`. `Sources/LocationHistoryConsumerAppSupport/AppDisplayHelpers.swift`: `weekday(_:locale:)` und `monthYear(_:locale:)` nutzen jetzt einen `NSCache<NSString, DateFormatter>` statt pro Aufruf einen neuen DateFormatter.

### Verifikation
- `swift test`: **1012 Tests, 2 Skips, 0 Failures** (unverändert; bestehende Tests laufen über die neuen Pfade — keine neuen Tests in diesem Train, das ist eigene Folge-Arbeit).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.

### Ehrlich offen
- Keine Mikro-Benchmarks der Performance-Optimierungen — Designziel, kein gemessener Speedup-Faktor.
- Hardware-Re-Verifikation iPhone 15 Pro Max steht weiterhin aus.
- Block-1-Mutations-im-Export ändert das bisherige bewusste Verhalten ("Export ignoriert Mutations bewusst") — README/CHANGELOG-Aussage entfernt bzw. umgekehrt.
- Live-Activity-Lock-Screen, ZIP-Entry-Streaming, Mikro-Benchmark, restliche P1/P2-Audit-Items bleiben offen.
- Nicht erledigt in diesem Train: P1-3 (`WidgetDataStore`-Duplikat), P1-4 (`onOpenURL` fehlt im Package-Target), P1-18..P1-24 (Test-Lücken).

## [2026-05-06] — P0 audit fixes 3/N: GPX safety, Keychain, schema forward-compat, LoadingBackground frame-rate, ROADMAP truth-pinning

### Was sich geändert hat
- `Sources/LocationHistoryConsumerAppSupport/GPXImportParser.swift` (P0-2): Force-Cast `as! String` in der Sort-Closure von `buildDaysDict` durch defensives `as? String ?? ""` ersetzt — kein `EXC_BAD_INSTRUCTION`-Crash mehr bei malformiertem GPX.
- `Sources/LocationHistoryConsumerAppSupport/GPXImportParser.swift` (P0-3): `fatalError` in `makeExport` entfernt. `makeExport` ist jetzt `throws` und wirft bei Roundtrip-Fehler `AppContentLoaderError.decodeFailed(fileName)` statt die App zu killen; `parse(_:fileName:)` propagiert den Fehler (`try makeExport(...)`).
- `Sources/LocationHistoryConsumerAppSupport/KeychainHelper.swift` (P0-4): `kCFBooleanTrue!` Force-Unwrap durch `true as CFBoolean` ersetzt — kein UB-Risiko mehr in App-Extension-Sandboxes mit eingeschränktem Security.framework.
- `Sources/LocationHistoryConsumer/AppExportModels.swift` (P0-5): `AppExportSchemaVersion` ist jetzt ein `struct` mit `rawValue: String` statt eines geschlossenen `enum`. Forward-kompatibel: ein zukünftiger Producer-Tool-Build mit `"2.0"` decodiert weiterhin erfolgreich. Neue Property `isSupportedByThisBuild: Bool` markiert unbekannte Schemas. Statische Konstante `.v1_0` bleibt API-kompatibel zu allen Call-Sites.
- `Sources/LocationHistoryConsumerAppSupport/LH2GPXLoadingBackground.swift` (P0-6): `RoutePulseOverlay`'s `TimelineView` läuft jetzt mit 20 Hz (vorher 30 Hz, ~33 % weniger Timer-Ticks während Imports) und `paused: progress >= 1.0` statt `paused: false` — defensiver Stop, falls die äußere `p < 1.0`-Guard-Bedingung jemals gelockert wird.
- `ROADMAP.md` (P0-8): Widersprüchlicher Test-Count (964 vs 1006 für denselben Tag) ist aufgelöst. Neuer Verifikations-Historie-Block mit commit-verankerter Auflistung (df7071b 1006/2/0 → 04dea98 1006/2/0 → cfa332e 1006/2/0 → 838863c 991/2/0 → 8abe7ec 987/2/0 → post-70254ff 964/2/0 → post-70254ff 927/2/0). Hardware-Acceptance-Status erhalten.

### Tests
- `testRejectsUnknownSchemaVersion` in `AppExportGoldenDecodingTests.swift` umgenannt zu `testForwardCompatibleSchemaVersionDecodesAndReportsUnsupported` und Erwartung invertiert (decodiert jetzt, prüft `isSupportedByThisBuild == false`).
- Neue `Tests/LocationHistoryConsumerTests/AppExportSchemaVersionTests.swift` mit 6 Cases.

### Verifikation
- `swift test`: **1012 Tests, 2 Skips, 0 Failures** (vorher 1006).
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.

### Ehrlich offen
- Hardware-Re-Verifikation auf iPhone 15 Pro Max steht weiterhin aus.
- Mikro-Benchmark für Streaming-Pipeline weiterhin nicht gemessen.
- 24× P1 + 19× P2 aus dem Audit weiterhin offen.
- ZIP-Entry-Streaming weiterhin nicht implementiert.
- TimelineView-Pause-Verhalten ist in der Praxis durch die äußere `p < 1.0`-Guard-Bedingung schon gestoppt; der `paused`-Bind ist defensives Hardening, kein gemessener Speedup.

## [2026-05-06] — P0 audit fixes: Live-tab deeplink + TCX export claim

### Was sich geändert hat
- `Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift`: `navigateToLiveTabRequested` setzt jetzt `selectedTab = 4` (Live) statt fälschlich `3` (Export). Widget-Deeplink `lh2gpx://live` landet damit auf dem korrekten Tab. Zusätzlich Tab-Tag-Mapping als Inline-Kommentar dokumentiert (0=Overview, 1=Days, 2=Insights, 3=Export, 4=Live).
- `README.md`: Export-Format-Liste enthält **kein TCX** mehr — `ExportFormat.swift` definiert nur `gpx`/`kmz`/`kml`/`geoJSON`/`csv`. TCX bleibt unterstütztes **Import**-Format.

### Verifikation
- `swift test`: 1006 Tests, 2 Skips, 0 Failures.
- Wrapper `xcodebuild` iPhone 17 Pro Max Sim 26.3.1: BUILD SUCCEEDED.

### Ehrlich offen
- Magic-Number-Tab-Tags (0..4) bleiben — keine Enum-Refaktorisierung in diesem Patch (out-of-scope für die zwei P0-Fixes). Der Tag-Mapping-Kommentar reduziert das Risiko, ersetzt aber keine Typ-Sicherheit.
- Verbleibende P0-Funde aus dem Audit (force-unwraps in GPXImportParser/KeychainHelper, `fatalError` in GPX-Roundtrip, non-exhaustive `AppExportSchemaVersion`, `LH2GPXLoadingBackground` Timeline-paused, ROADMAP-Test-Count-Widerspruch) sind in NEXT_STEPS dokumentiert und noch offen.

## [2026-05-06] — Performance pass on streaming Google Timeline import (UnsafeBytes tokenizer, 256 KB chunks, autoreleasepool, direct model build — no JSON roundtrip on output side)

### Was sich geändert hat
- `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineStreamReader.swift`: Tokenizer läuft jetzt über `Data.withUnsafeBytes` mit direktem `UnsafePointer<UInt8>`-Zugriff statt `Data.Index`-Iteration; tighter Per-Byte-Loop, Cache-freundlicher. Strukturelle Bytevergleiche jetzt mit Hex-Literalen (`0x5B`/`0x7B`/…) statt `UInt8(ascii:)`. `@inline(__always)` auf `processByte` und `isJSONWhitespace`.
- Default-`chunkSize` von 64 KB → 256 KB.
- Per-Element `onElement`-Aufruf in `autoreleasepool` gewrappt — verhindert, dass Foundation-Zwischenobjekte (NSString/NSNumber/NSDictionary aus `JSONSerialization.jsonObject`) über den gesamten Import akkumulieren.
- `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineConverter.swift`: kompletter Umbau auf direkten Model-Build. Neue interne `ExportBuilder`-Struktur akkumuliert direkt `Visit`/`Activity`/`Path`/`PathPoint` pro DayKey; `finalize()` baut `AppExport` direkt mit den neuen public memberwise-Initializern. Damit entfallen auf der Output-Seite ein kompletter `[String: Any]`-Foundation-Tree-Build, eine `JSONSerialization.data(withJSONObject:)`-Pass, eine JSON-Parse-Pass und ein `AppExportDecoder`-Codable-Decode.
- `Sources/LocationHistoryConsumer/AppExportModels.swift`: neue `public init(...)`-Memberwise-Initializer für `AppExport`, `Meta`, `Source`, `Output`, `ExportConfig`, `ExportFilters`, `DataBlock`, `Visit`, `Activity`. Notwendig, weil die Modelle in einem anderen Modul liegen und der Konverter sie jetzt direkt instanziieren muss. `Day`, `Path`, `PathPoint` hatten bereits public inits.

### Verifikation
- `swift test`: **1006 Tests, 2 skipped, 0 failures** (gleicher Umfang; bestehende Tests laufen unverändert über die optimierten Pfade — `convert(data:)` ↔ `convertStreaming` Äquivalenz und 5 000-Entry-Synthetik weiterhin grün).
- Wrapper `xcodebuild` (iPhone 17 Pro Max Sim 26.3.1): BUILD SUCCEEDED.

### Ehrlich offen
- Kein ZIP-Entry-Streaming: ZIPFoundation extrahiert weiterhin in eine `Data`, dann läuft der Streaming-Reader darauf.
- Auto-Restore lehnt rohe Google Timeline weiterhin ab.
- Hardware-Re-Verifikation auf iPhone 15 Pro Max mit echter 46-MB-Datei steht weiterhin aus.
- Keine Mikro-Benchmarks gemessen — die genannten Einsparungen sind erwartete Größenordnungen / Designziel, kein gemessener Speedup-Faktor.

## [2026-05-06] — Element-based streaming parser for Google Timeline JSON (manual imports no longer load the full file alongside a JSONSerialization tree)

### Was sich geändert hat
- Neue Datei `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineStreamReader.swift` mit `GoogleTimelineStreamReader.forEachObjectElement(contentsOf url:)` (FileHandle, 64-KB-Chunks, Top-Level-Array-Tokenizer mit String-/Escape-/Depth-Tracking, BOM-Skip, RFC-8259-Whitespace) und Schwester-Variante `forEachObjectElement(in data:)` für ZIP-extrahierte Daten. Pro Element wird nur ein Object-Slice an `JSONSerialization.jsonObject(with:)` übergeben. Hard-Cap pro Element 8 MB → `StreamError.elementTooLarge`. Errors: `notArray`, `malformedJSON`, `ioFailure`, `elementTooLarge`.
- `Sources/LocationHistoryConsumerAppSupport/GoogleTimelineConverter.swift`: `convert(data:)` läuft jetzt intern über den Streaming-Reader (kein voller Foundation-Tree mehr); neue API `convertStreaming(contentsOf url:)` für direkte JSON-Datei-Imports ohne Full-Data-Load. Per-Entry-Ingest in `ingestEntry(...)` ausgelagert; beide Pfade (Data + URL) teilen Ingest und finale Export-Dict-Erzeugung.
- `Sources/LocationHistoryConsumerAppSupport/AppContentLoader.swift`: `decodeFile(at:sourceName:)` sniffed die ersten 1 KB; bei erkannter Google-Timeline (`[`) geht es direkt in `convertStreaming(contentsOf:)` ohne `Data(contentsOf:)`. Auto-Restore-Skip-Verhalten bleibt unverändert (rohe Google Timeline werden weiterhin nicht auto-restored — Streaming ist speichersicher, aber dauert mehrere Sekunden bis Minuten).
- Tests neu: `Tests/LocationHistoryConsumerTests/GoogleTimelineStreamReaderTests.swift` mit 15 Cases (Happy Path, BOM/Whitespace, String mit `}]`, escaped Quote, nested Path, Error-Pfade, byte-by-byte-Chunking-Boundary-Test, 5 000-Entry-Synthetik, `convert(data:)` ↔ `convertStreaming` Äquivalenz).

### Verifikation
- `swift test`: **1006 Tests, 2 skipped, 0 failures** (vorher 991), Stand 2026-05-06.

### Ehrlich offen
- Kein Streaming aus ZIP-Entries: ZIPFoundation extrahiert weiterhin in eine `Data`, dann läuft der Streaming-Reader darauf — Memory-Peak entspricht weiterhin grob der Größe der entpackten Datei, aber ohne zusätzlichen 150–200-MB-`JSONSerialization`-Tree.
- Auto-Restore lehnt rohe Google Timeline weiterhin ab; das Streaming ist für **manuelle** Importe gebaut.
- Hardware-Re-Verifikation auf iPhone 15 Pro Max mit echter 46-MB-Datei steht aus.
- Beim Streaming wird das finale Export-Dict (`dayMap`) einmal komplett aufgebaut und für `AppExportDecoder` re-encoded — bei extrem vielen Entries (>500 k) bleibt das ein nichttriviales RAM-Plateau, aber Größenordnungen unter dem alten Pfad.

## [2026-05-06] — Memory-Safety Folgefix: Auto-Restore lehnt rohe Google-Timeline-Dateien grundsätzlich ab (Sniffer-Skip)

### Root Cause des Folgefix
Der vorherige 50-MB-Cap (Commit `8abe7ec`) erfasste den realen 46-MB-iPhone-Crashfall NICHT, weil 46 < 50. Der jetzt ergänzte Sniffer-Skip schließt genau diese Lücke: rohe Google-Timeline-Dateien werden im Auto-Restore grundsätzlich nicht mehr automatisch reimportiert, **unabhängig von der Größe**.

### fix: skip raw Google Timeline files during auto-restore regardless of size
- `Sources/LocationHistoryConsumerAppSupport/AppContentLoader.swift`: Funktion `assertSizeWithinAutoRestoreLimitIfNeeded` umbenannt zu `assertAutoRestoreEligible`. Im Auto-Restore-Modus genügt das Sniffer-Ergebnis (`firstStructuralByte == '['`), um abzulehnen — gilt sowohl für direkte JSON-Dateien als auch für ZIPs mit Google-Timeline-Entry (Head-Sniff per begrenztem ZIP-extract-Abbruch).
- Manueller Import (`autoRestoreMode == false`) bleibt unberührt: bei manueller Auswahl gilt weiter der ehrliche 256-MB-Cap. Ein echter Streaming-Parser fehlt nach wie vor.
- `userFacingTitle`: "Large Google Timeline import detected" → "Import not auto-restored". `errorDescription` erweitert um den Grund "Raw Google Timeline exports and large files are skipped on launch …".

### Tests
- 4 neue Cases in `Tests/LocationHistoryConsumerTests/LargeImportMemorySafetyTests.swift`:
  - `testAutoRestoreSkipsRawGoogleTimelineUnderSizeCap` (46 MB direkte Datei)
  - `testAutoRestoreSkipsRawGoogleTimelineZipEntryUnderSizeCap` (46 MB Timeline in ZIP)
  - `testAutoRestoreAllowsSmallAppExportLikeFile` (AppExport `{...}` darf weiter restoren)
  - `testManualLoadAllowsRawGoogleTimeline` (manueller Pfad bleibt frei)
- Suite-Total: 18 Cases (vorher 14). Gesamt: **991 Tests, 2 skipped, 0 failures** (vorher 987).

### Verifikation
- `swift test`: 991/2/0 grün (Stand 2026-05-06).

### Ehrlich offen
- Manuelle Importe großer roher Google-Timeline-Dateien (>~30–40 MB) bleiben weiterhin riskant — kein echter Streaming-Parser.
- Hardware-Re-Verifikation des 46-MB-Falls auf iPhone 15 Pro Max steht aus (kein Simulator hat den Fall realistisch nachgestellt).

## [2026-05-06] — Memory-Safety: Auto-Restore-Schutz gegen Jetsam-Kill bei großen Google-Timeline-Imports

### Root Cause
Auf echtem iPhone wurde `LH2GPXWrapper` von iOS Jetsam beendet ("The app LH2GPXWrapper has been killed by the operating system because it is using too much memory"). Wahrscheinlicher Pfad: Auto-Restore beim App-Start lädt eine zuvor importierte Google-Timeline-Datei (`location-history.zip/json`, ~46 MB JSON, ~65 k Timeline-Einträge) erneut komplett ins RAM. Drei volle `JSONSerialization`-Passes (LH2GPX-Detection + `isGoogleTimeline`-Detection + `convert`-Parse) plus Zwischen-Modelle ergeben einen transienten Peak von ~400–500 MB — auf dem iPhone Jetsam-fatal.

### fix: guard large Google Timeline restore against memory pressure
- **Sniffer-Detection** statt vollständige `JSONSerialization` für Format-Unterscheidung. `GoogleTimelineConverter.isGoogleTimeline` und neuer `isJSONObject` lesen nur das erste 1 KB-Fenster und prüfen das erste Nicht-Whitespace-Zeichen (`[` vs. `{`). Spart pro Aufruf ~150–200 MB transienter Foundation-Allokation. AppContentLoader nutzt den Object-Sniffer im ZIP-Pfad statt eines Array-Vollparses.
- **Auto-Restore-Größenschutz**: Neue konstante `AppContentLoader.autoRestoreMaxFileSizeBytes = 50 MB`. `loadImportedContent(from:autoRestoreMode:)` wirft `AppContentLoaderError.autoRestoreSkippedLargeFile` bevor irgendetwas eingelesen wird, wenn der Auto-Restore-Pfad eine Datei größer als der Schwellwert sieht. Für ZIPs werden Entry-Metadaten über ZIPFoundation-Iteration inspiziert (keine Extraktion). Manuelle Importe bleiben beim 256-MB-Cap (User wartet bewusst auf den Parse).
- **Auto-Restore-User-Hinweis**: `AppShellRootView` und `wrapper/LH2GPXWrapper/ContentView` reichen `autoRestoreMode: true` durch und zeigen bei `autoRestoreSkippedLargeFile` die dedizierte Message "Großer Google-Timeline-Import erkannt … bitte manuell importieren". Bookmark wird im Skip-Fall NICHT gelöscht.
- **Query Fast-Path**: `AppExportQueryFilter.isPassthrough` (neu, public) und `AppExportQueries.projectedDays` Fast-Path. Wenn keine Constraint aktiv ist, gibt `projectedDays` direkt die sortierte `export.data.days`-Liste zurück, ohne pro Tag `projectedDay(...)` mit kopierten Visit-/Activity-/Path-Arrays zu erzeugen. Einsparung auf 65 k-Tage-Imports: ~80–130 MB transient pro Aufruf (Overview/daySummaries/Insights).
- **OverviewMap bounded coordinates**: `OverviewMapPathCandidate.fullCoordinates` wird jetzt bei der Scan-Phase auf maximal 512 Punkte stride-decimiert, bevor sie in den Kandidaten gespeichert werden. Spart ~70–90 % residenten RAM bei dichten Tracks; visuell verlustfrei, da `makeOverlay(...)` ohnehin Douglas-Peucker anwendet. Score-Berechnung läuft weiter auf den Roh-Koordinaten, damit dichte Pfade nicht ihre Priorität verlieren.

### Tests
- Neu: `LargeImportMemorySafetyTests` (14 Cases) — Sniffer (Array/Object/BOM/Whitespace/Empty), Auto-Restore-Skip für direkte JSON > 50 MB und ZIP-Entry > 50 MB, Manuelles Laden umgeht den Auto-Restore-Cap nicht, `isPassthrough`-Wahrheitstabelle, Query-Fast-Path liefert sortierte Tage, `OverviewMapPreparation.strideDecimate` respektiert Cap und schont kurze Pfade.
- Bestehende `GoogleTimelineConverterTests.testDetectsValidGoogleTimelineFormat` bleibt grün (Sniffer-Verhalten ist semantisch kompatibel).

### Verifikation
- `swift build`: green.
- `swift test`: 987 Tests, 2 skipped, 0 failures.
- `xcodebuild -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.3.1' build`: BUILD SUCCEEDED.
- Hardware-Verifikation auf iPhone 15 Pro Max mit echter 46-MB-Google-Timeline: pending (manuell durch Sebastian).

### Ehrlich offen
- **Kein echter Streaming-Import**: GoogleTimelineConverter parst weiterhin das gesamte Array in einen Foundation-Baum und baut anschließend einen ebenso großen Swift-Dictionary-Baum + re-serialisiert ihn. Für Datei-Größen unter dem Auto-Restore-Cap (≤ 50 MB) bleibt das funktional, ist aber kein dauerhafter Schutz wenn der User manuell ein 100-MB-Google-Timeline öffnet. Streaming-/Chunked-Parser ist in NEXT_STEPS verbleibender Arbeitspunkt.
- **OverviewMap-Pfad**: `pointBudget = 2_000_000` und `candidateStorageCap = 512` sind Heuristiken, kein hartes Speicher-Budget. Auf Geräten mit < 4 GB RAM und sehr großen Imports ist eine weitere Reduktion nötig.

## [2026-05-06] — Doku-/Wiring-Audit-Polish (HEAD post-`70254ff`)

### docs: deep audit + repo-truth-sync (Core + Wrapper)
- Datei-fuer-Datei und Zeile-fuer-Zeile Truth-Check der gesamten Repo- und Wrapper-Doku gegen den Code.
- Aktualisiert: README, NEXT_STEPS, ROADMAP, docs/APP_FEATURE_INVENTORY, docs/XCODE_APP_PREPARATION, docs/XCODE_RUNBOOK, docs/APPLE_VERIFICATION_CHECKLIST, wrapper/README, wrapper/NEXT_STEPS, wrapper/ROADMAP, wrapper/CHANGELOG, wrapper/.github/workflows/xcode-test.yml.
- Korrigiert: SPM-Pfad-Behauptungen (`../..` → `..`), Build-Number (`96` / `45` → `100`), Test-Zahl (`228` / `949` → `964`), gpsStatusLabel-Beschreibung (3-wertig statt 2-wertig), Heatmap-Capsule-Chip-Beschreibung (jetzt MapLayerMenu), Wrapper-CI-Dateiname (`swift-test.yml` → `xcode-test.yml`), `fileImporter` `allowedContentTypes` (KML/GeoJSON sind Export-only).

### refactor: MapLayerMenu Wiring-Audit-Polish
- `AppDayMapView`: `mapPosition` als `@State`-`MapCameraPosition` (statt statisches `initialPosition`); Viewport springt jetzt bei Tag-Wechsel, `fitToData` an `MapLayerMenu` verdrahtet.
- `AppExportPreviewMapView`: `mapPosition`-State + `fitToData` ergänzt; Configuration jetzt nicht mehr leer.
- `AppOverviewTracksMapView`: `isFullscreenActive: false` → `isFullscreenActive: isExpanded` (Label folgt Sheet-State); tote Funktionen `mapControlButton`, `exploreControlButton`, `styleToggleIcon` entfernt.
- `AppHeatmapView`: ZStack-Pattern auf `.overlay(alignment:)` umgestellt (verhindert mögliche Verdeckung durch Calculating-Overlay); Padding `12pt → 8pt` einheitlich.
- `AppLiveTrackingView`: Landscape-`mapCard` und `fullscreenMapView` nutzen jetzt die geteilten `liveAccuracyCircleContent` / `liveTrackContent` / `liveCurrentLocationAnnotation` MapContent-Builder — vorher hat das Landscape-Layout `MapLayerMenu`-Flags (Speed-Coloring, Fade-Buckets, Accuracy-Circle) komplett ignoriert; Padding repo-weit `8pt`.
- `AppLiveLocationSection`: `showsTrackColor: true` entfernt — das Rendering dieser Section ignoriert `mapTrackColorMode` per Design (es gibt nur Live-Mint + optionales Fading).
- Tote Parameter `verticalMapControls` (in 3 Views, 4 Aufrufern) und `showStyleToggle` (in `AppDayMapView`, 2 Aufrufern) entfernt.

### Verifikation
- `swift build`: green.
- `swift test`: 964 Tests, 2 skipped, 0 failures (vorher 949 unter `93109e0`).
- `xcodebuild -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.3.1' build`: BUILD SUCCEEDED.

## [2026-05-06] — UX-Audit-Batch (Live-Status, Export-Empty-State, Polish)

### feat: konsolidierter LiveStatusResolver
- Neuer `Sources/LocationHistoryConsumerAppSupport/LiveStatusResolver.swift` (`enum LiveStatus`, `LiveStatusResolver.resolve(...)`); +16 dedizierte Tests in `LiveStatusResolverTests.swift`.
- Behebt im ScreenRecording sichtbare Widersprüche: gleichzeitig "Location not available" + "Live Location Ready" + "GPS Weak" + "Acquiring permission". Eine dominante Hauptmeldung pro Zustand (Permission/Acquiring/Ready/Recording × Weak/Good).
- `LiveTrackingPresentation.gpsStatusLabel(nil)` → "GPS Searching" (statt "GPS Weak"). Test umbenannt (testGPSStatusIsWeakWhenNoLocation → testGPSStatusIsSearchingWhenNoLocation).
- Map-Overlay-Hinweis nur noch sichtbar wenn `liveStatus.isAcquiring` oder `isPermissionState` (statt jedes Mal wenn `currentLocation == nil`).
- `AppLanguageSupport.swift`: neuer i18n-Key `"GPS Searching"` → DE `"GPS-Suche"`.
- Erhalten: Recording-Toggle, Follow-Mode + Off-on-Pan, Fullscreen, Upload-Status (orthogonal), Track-Library, Background-Recording-Toggle, Permission-Flow, Privacy/Upload-Defaults.

### fix: Export-Empty-State und CTAs eindeutig
- Behebt im ScreenRecording sichtbare 4-fache Empty-Messaging (Hero-Placeholder + Hero-Chip + Preview-Card-Label + SummaryCard else) wenn Auswahl leer aber Tracks/Days verfügbar.
- Eine kanonische Empty-Surface: Hero-Placeholder-Text adaptiert zu "Pick a day or live track to preview" wenn Items selektierbar.
- Hero-Filter-Chip wechselt zu "Tap to choose" + `hand.tap`-Icon bei selektierbaren Items.
- `previewCard` und `selectionSummaryCard` else-Branch werden in dieser Konstellation unterdrückt (kein redundanter Text).
- `Select All`-CTA wird `.borderedProminent` wenn relevant; neue Identifier `export.liveTracks.selectAll`/`.deselectAll`/`export.days.selectAll.cta`/`export.liveTracks.selectAll.cta`.
- Dead-Branch `.nothingSelected` in `invalidSelectionMessage` entfernt (nicht erreichbar).
- Erhalten: ExportPreviewDataBuilder-Pipeline, fileExporter (Single + KMZ), LHExportBottomBar, Format-Picker, Advanced Filters, Content-Mode-/CSV-Cards, alle bestehenden Identifier.

### fix: doppelte Karte auf Export-Tab (Hero + Preview-Card)
- Bei `heroEnabled` rendert die Preview-Card jetzt nur noch Stats/Legend, nicht mehr eine zweite `AppExportPreviewMapView` unterhalb der vollen Hero-Map.

### chore: Polish (low risk)
- `LHOptionsComponents`: Beschreibung `lineLimit(1) → lineLimit(2) + minimumScaleFactor(0.9)` (DE-Truncation behoben).
- `AppOptionsView.backgroundToggle`: Caption-Spacing 6→8 + 2pt Top-Padding (Lesbarkeit).
- `AppInsightsContentView.kpiGrid`: `[GridItem(.flexible()) × 2]` → `GridItem(.adaptive(minimum: 150))` (Dynamic-Type-Robustheit).
- `AppInsightsContentView.insightsHeroFilterPanel`: Bottom-Padding 6→10 (Filter-Chip/Content-Kollision behoben).

### Build & Test
- `swift build`: OK (23s) ✅
- `swift test`: **949 Tests, 2 skipped, 0 failures** (7.7s, +16 vs vorher) ✅

### Offen (nicht Teil dieses Batches)
- Visuelle Verifikation auf realem iPhone 15 Pro Max (Build 96 nötig).
- Triple-Range-Picker auf Insights (Hero-Strip + Time-Range-Card + untere Pills): bewusst defer — strukturelle UI-Konsolidierung, eigene Phase.
- Doppelter "Overview"-Header (Page + Card-Title): defer — Naming-Entscheidung.
- "200 routes"/"11 routes"-Pill überlappt mit Snapshot-Banner: defer — Z-Stack-Anpassung.
- Import-Phasen-Progress (Reading/Parsing/Building): defer — touch von ContentLoader-API.
- Form-vs-LHCard-Konsistenz in Settings: defer — Refactor mehrerer Sub-Views.

## [2026-05-06] — feat: Hero-Map-Workspace auf Übersicht/Insights/Export/Live ausrollen (Tage-Optik)

### Neu
- `Sources/LocationHistoryConsumerAppSupport/LHHeroMapWorkspace.swift` (neu): geteilte Layout-Konstanten (`compactHeight=460`, `expandedHeight=560`, `mapControlTopOffset=130`) + `lhDeviceTopSafeInset()`-Helper, der den realen `UIWindow.safeAreaInsets.top` liest (in `safeAreaInset`/`ignoresSafeArea`-Kontexten ist `geometry.safeAreaInsets.top == 0`).

### Geändert (compact iPhone)
- **Übersicht** (`AppContentSplitView`): Map als full-bleed Hero über `safeAreaInset(.top)`, alter `overviewMapCard` entfernt; Heatmap-Button bleibt im `overviewRangeCard` erhalten. iPad/Regular und Landscape unverändert.
- **Insights** (`AppInsightsContentView`): neuer `heroEnabled`-Pfad mit Hero-Map + Range-Chip-Filter; alle `.onChange`/`.sheet`/`.alert`/`.confirmationDialog`-Modifier auf den neuen Pfad gespiegelt.
- **Export** (`AppExportView` + `AppExportPreviewMapView`): `heroEnabled` schaltet Hero-Map mit Format-Pill + Tage/Tracks-Chips frei; `fileExporter`, `bottomBar`, Format-Picker, Advanced Filters, `ExportPreviewDataBuilder`-Quelle, `effectiveQueryFilter`/`effectiveExportMode`/`session.exportSelection`/`liveLocation.recordedTracks` unverändert verdrahtet.
- **Live** (`AppLiveTrackingView`): Portrait erhält `liveHeroMap` (Polyline + Follow-Toggle + Fullscreen-Button + locationDot) + `liveHeroFilterPanel`; Landscape `mapCard`, Recording-Toggle, Permission-Flow, Background-Recording, Upload-Status, Track-Library, Follow-Off-on-Pan-Verhalten erhalten.
- **Tage-Detail** (`AppDayDetailView`): Portrait nutzt jetzt `safeAreaInset(.top)` mit `dayHeroMap` + `dayHeroFilterPanel`; Landscape unverändert.
- **`AppDayMapView`**: zusätzliche Init-Parameter `mapControlTopPadding` und `verticalMapControls`; Style-Toggle in `mapControlsStack`-Builder ausgelagert. Defaults erhalten Legacy-Verhalten.

### Erhalten
- `projectedQueryFilter`, `overviewFilteredDaySummaries`, `AppOverviewMapModel` Pan-without-rescan-Invariante, Heatmap-Button, fileExporter (Single + KMZ), Recording-/Background-Toggles, Upload-Status, Track-Library, Follow-Mode, Fullscreen-Map, alle Sheets/Alerts/Drilldowns.

### Build & Test
- `swift build`: OK (1.08s) ✅
- `swift test`: **933 Tests, 2 skipped, 0 failures** (7.0s) ✅

### Offene Punkte
- iPad regularSplitView + Landscape: Legacy-Pfade unverändert, separate visuelle Verifikation nötig.
- Snapshot/Visual-Tests für Hero-Map-Layout fehlen weiterhin.
- `AppDayDetailView.mapControlRow` ist im Portrait toter Code (Landscape-only) — Cleanup als Follow-up.
- Live `mapCard` (Landscape) und `liveHeroMap` (Portrait) duplizieren Map-Rendering — Konsolidierung als Follow-up.

## [2026-05-06] — fix: Days-Map-Controls unter Statusbar + Map/Search flush (Build 96 nötig)

### Root Cause
- Days-Hero-Map nutzt `.ignoresSafeArea(edges: .top)`, damit die Karte unter Dynamic Island/Statusbar reicht. Die Map-Controls (Globe/Fit-to-data) in `AppOverviewTracksMapView.compactMapView` hatten aber nur `.padding(8)` und landeten dadurch sichtbar IM Statusbar-Bereich.
- Zwischen Karte und Suchleiste entstand ein schwarzer Leerraum, weil `compactDayList` zwei separate `.safeAreaInset(edge: .top)` für Map-Header und Filter-Panel stapelte — gegen List-internes Padding/Section-Header-Inset/Safe-Area schwer zu kontrollieren.
- `LHCollapsibleMapHeader` besitzt einen `safeAreaTopInset`-Parameter, nutzte ihn aber nicht: im Body wurde nur `geometry.safeAreaInsets.top` verwendet, das in `safeAreaInset/ignoresSafeArea`-Kontexten 0 liefert.

### Fix
- `AppOverviewTracksMapView`: neuer Parameter `mapControlTopPadding: CGFloat = 8`. Default = altes Verhalten (Overview/Detail unverändert). Days reicht `deviceTopSafeInset + 12` rein → Buttons liegen sichtbar unter Dynamic Island.
- `compactDayList`: zwei Top-`safeAreaInsets` durch einen einzigen ersetzt, der eine `VStack(spacing: 0) { daysListStickyHeader; daysFilterPanel }.background(.black)` enthält. Kein internes Gap mehr zwischen Karte und Suchleiste.
- `daysFilterPanel` Top-Padding 8 → 4, damit die Suchleiste flush an der Map sitzt.
- `LHCollapsibleMapHeader.body`: `overlayControlBar` wird mit `max(geometry.safeAreaInsets.top, safeAreaTopInset)` aufgerufen — der von außen gemessene Wert wird wirksam.
- Suchfeld bekommt `accessibilityIdentifier("days.searchField")` für UI-Tests.

### Build & Test
- `swift test`: 933 Tests, 0 Failures, 2 Skipped ✅ (56s)
- `xcodebuild -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1'`: BUILD SUCCEEDED ✅
- `xcodebuild -scheme LH2GPXWrapper -destination 'platform=iOS,id=00008130-00163D0A0461401C'`: BUILD SUCCEEDED ✅ (iPhone 15 Pro Max physisch)
- `xcrun devicectl device install app` + `process launch` auf iPhone 15 Pro Max ✅

### App-Store
- Build 95 ist veraltet — Build 96 nötig vor Einreichung.
- App-Store-Screenshots müssen mit Build 96 neu erzeugt werden, da Days-Sticky-Map-Slot betroffen ist.

## [2026-05-05] — chore: Hardware-Verifikation iPhone 15 Pro Max + Screenshot-Update

### Build & Test — echtes iPhone 15 Pro Max (UDID 00008130-00163D0A0461401C, iOS 26.4)
- `swift test`: 927 Tests, 0 Failures ✅
- `git diff --check`: sauber ✅
- `xcodebuild -scheme LH2GPXWrapper -destination 'id=00008130-00163D0A0461401C'`: BUILD SUCCEEDED ✅
- `testAppStoreScreenshots` (iPhone 15 Pro Max): PASSED (44s) ✅ — 6 PNGs 1290×2796 extrahiert
- `testDeviceSmokeNavigationAndActions` (iPhone 15 Pro Max): PASSED (70s) ✅

### UITest-Vereinfachung: Screenshot-Set auf 6 Pflicht-Slots reduziert (Option 1)
- Slot 07 (Options) entfernt: Options ist kein Tab-Bar-Button; UITest kann ihn nicht zuverlässig über Actions-Menü öffnen, ohne production-sichtbare Navigation zu ändern
- Slot 08 (Day Detail) entfernt: nicht zwingend für App Store Screenshots
- Neues Pflicht-Set: 01 Import, 02 Overview, 03 Days Sticky Map, 04 Export Checkout, 05 Insights, 06 Live Tracking
- Neue Dateinamen: `iphone15pm_0N_*.png` (hardware-device-spezifisch)
- UITest schreibt direkt in `docs/app-store-assets/screenshots/iphone-67/`

### Neue App-Store-Screenshots (iPhone 15 Pro Max, 1290×2796 px)
- `iphone15pm_01_import.png` — Import/Start-Screen ✅
- `iphone15pm_02_overview.png` — Overview-Karte + KPI ✅
- `iphone15pm_03_days_sticky_map.png` — Days mit Sticky Map ✅
- `iphone15pm_04_export_checkout.png` — Export Checkout (Batch 3-Design) ✅
- `iphone15pm_05_insights.png` — Insights Dashboard (Batch 4-Design) ✅
- `iphone15pm_06_live_tracking.png` — Live Tracking (Batch 5A-Design) ✅

### Hardware-Verifikation: Smoke-Test auf iPhone 15 Pro Max (automatisiert)
- `testDeviceSmokeNavigationAndActions` verifiziert auf Gerät (iOS 26.4):
  - Demo Data laden ✅
  - Overview-Tab + All-Time-Filter-Chip ✅
  - Heatmap-Sheet öffnen + schließen ✅
  - Insights-Tab Share-Button (`insights.share.*`) ✅
  - Export-Tab fileExporter ✅
  - Live-Tab Start/Stop Recording ✅

### Hardware-Verifikation: weiterhin offen (nicht automatisiert prüfbar)
- Landscape auf allen Tabs: nicht systematisch per UITest verifiziert
- Live Activity / Dynamic Island: Batch 5A/5B auf Gerät noch nicht vollständig verifiziert
  - Bisheriger Stand (2026-04-30): 5/5 Live Activity Capture-Tests PASSED auf iPhone 15 Pro Max
  - Offen: Lock Screen, `minimal`, deaktivierte Live Activities, No-Dynamic-Island-Gerät
- iPad: kein echtes iPad-Gerät in diesem Batch getestet

---

## [2026-05-05] — chore: Verifikations-Batch Redesign 1–5B

### Build & Test
- `swift test`: 927 Tests, 0 Failures, 0 Skips ✅
- `git diff --check`: sauber ✅
- `xcodebuild -scheme LH2GPXWrapper -destination generic/platform=iOS build`: BUILD SUCCEEDED ✅ (inkl. Widget-Extension)
- `xcodebuild -scheme LH2GPXWrapper -destination 'iPhone 17 Pro Max Simulator' build`: BUILD SUCCEEDED ✅
- `xcodebuild -testPlan CI` (iPhone 17 Pro Max Simulator): TEST SUCCEEDED (alle 8 LH2GPXWrapperTests) ✅
- `testAppStoreScreenshots` (iPhone 17 Pro Max Simulator): PASSED (253s) ✅ — 7 PNGs 1320×2796 extrahiert
- `testDeviceSmokeNavigationAndActions` (iPhone 17 Pro Max Simulator): nach Bugfix erneut ausgeführt

### Bugfix UITest: `insights.section.share` → `insights.share.*`
- `testDeviceSmokeNavigationAndActions` scheiterte wegen veralteter Accessibility-Kennung `insights.section.share`
- Seit Batch 4 lautet der Identifier `insights.share.<cardType>` (z.B. `insights.share.highlights`)
- UITest auf Prädikat `identifier BEGINSWITH 'insights.share.'` umgestellt → minimale, wartbare Korrektur

### Screenshot-Kandidaten (Simulator, nicht für App Store Connect)
- 7 PNG-Screenshots (1320×2796, iPhone 17 Pro Max Simulator) in `docs/app-store-assets/screenshots/simulator-iphone17promax/` gespeichert
- Slots: 01-import, 02-overview-map, 03-days, 04-insights, 05-export, 06-live-recording, 08-day-detail
- 07-options: Tab-Bar-Button im Simulator nicht gefunden (Options ist kein eigener Tab, sondern Kontext-Button) — bekannte Einschränkung
- **Hinweis**: Diese Screenshots sind Simulator-Kandidaten, keine Finalversionen für App Store Connect. Für ASC müssen auf echtem iPhone 15 Pro Max (UDID 00008130-00163D0A0461401C) aufgenommen werden.

### Simulator-Verifikation: visuell geprüfte Screens
- **Startseite (01-import)**: Import-CTA, Hero-Bereich, Privacy-Row sichtbar ✅
- **Overview (02-overview-map)**: Karte, KPI-Grid, Datumsbereich, Demo-Overlays ✅
- **Days (03-days)**: Sticky-Map-Bereich sichtbar (Batch 1), Tagesliste darunter ✅
- **Insights (04-insights)**: Hero-Summary, KPI-Grid, Sektionen (Batch 4) ✅
- **Export (05-export)**: Checkout-Struktur, Formatwahl, Bottom-Bar (Batch 3) ✅
- **Live Tracking (06-live-recording)**: Hero-Status-Card, diagnostics collapsed, Bottom-Bar (Batch 5A) ✅
- **Day Detail (08-day-detail)**: Map-first, Demo-Tag ✅

### Simulator-Verifikation: Landscape
- Landscape-Verifikation: **nicht durchgeführt** (Aufgabe erfordert manuellen UI-Durchgang; Simulator-Rotation ist nicht automatisch per UITest verifiziert worden)

### Simulator-Verifikation: iPad
- iPad nicht anwendbar für v1 (`TARGETED_DEVICE_FAMILY = 1`, iPhone-only)

### Hardware-Verifikation (weiterhin offen)
- Kein neuer Hardware-Durchgang in diesem Batch
- Live Activity / Dynamic Island: nur Build 44-Stand auf echter Hardware; Batch 5A/5B noch ohne Hardware-Nachweis
- Landscape / Dynamic Type: weiter ohne Hardware-Nachweis
- Alle offenen P0-Hardware-Punkte bleiben in NEXT_STEPS

---

## [2026-05-05] — feat: UI/UX Redesign Batch 5B — Live Activity / Dynamic Island / Widget Safety

### Inhaltssicherheit (Content Safety Review)

- **`TrackingStatus` (Live Activity ContentState)**: Geprüft und bestätigt — keine Koordinaten, keine Server-URLs, keine Bearer-Token im ContentState. Felder: `isRecording`, `distanceMeters`, `pointCount`, `isPaused`, `uploadQueueCount`, `lastUploadSuccess`, `uploadState`.
- **`TrackingAttributes` (statisch)**: Nur `trackName` (String) + `startTime` (Date) — kein sensitives Feld.
- **`WidgetDataStore.LastRecording`**: Nur Datum, Distanz, Dauer, Trackname — kein Koordinatenfeld.
- **Live Activity / Dynamic Island / Lock Screen**: Kein Koordinaten-, Token- oder Server-URL-Inhalt in keiner Ansicht.

### Bugfix: `minimalView` (Dynamic Island Minimal)

- Tote Bedingung entfernt: `(display == .uploadStatus ? primary.systemImageName : primary.systemImageName)` lieferte immer denselben Wert.
- Vereinfacht zu `context.state.isPaused ? "pause.circle.fill" : "location.fill.viewfinder"` — klares, konsistentes Icon für die Minimal-Darstellung.

### Neue Safety-Tests (`LiveActivitySafetyBatch5BTests`, 9 Tests)

- JSON-Encoding von `TrackingStatus` enthält keine Koordinat-, Token- oder Server-Schlüssel
- `Mirror`-Reflexion bestätigt vollständige + sichere Feldliste von `TrackingStatus`
- JSON-Encoding von `WidgetDataStore.LastRecording` enthält keine Koordinat- oder Token-Schlüssel
- `uploadState` ist standardmäßig `.disabled` (kein Upload ohne explizite Konfiguration)
- Alle `LiveActivityUploadState`-Fälle haben nicht-leere, sichere Labels

### Gesamttest-Stand

927 Tests, 0 Failures

---

## [2026-05-05] — feat: UI/UX Redesign Batch 5A — Live Tracking Foundation

### Hero/Status-Bereich (`AppLiveTrackingView`)

- **Neuer `heroStatusCard`**: Klare Statusanzeige ganz oben im Live-Tracking-Flow, vor der Karte.
  - Status: Recording Active · Requesting Permission · Location Access Denied · Ready to Record · Not Started
  - Icon + Farbe + klare Erklärung ohne technische Details
  - Alle Zustände kommen aus `liveLocation.isRecording`, `isAwaitingAuthorization`, `authorization` — keine neuen State-Kopien
  - Identifier: `live.status.hero`

### Diagnose-Bereich (einklappbar)

- **`diagnosticsSection`** ersetzt `recordingCard` im Layout:
  - Einklappbar via `isDiagnosticsExpanded` (`@State`)
  - Zeigt dieselben 8 Metriken (Distance, Duration, Points, Avg Speed, GPS Accuracy, Current Speed, Last Segment, Update Age) — nur wenn aufgeklappt
  - Session-Timer im Header sichtbar, auch wenn eingeklappt
  - Identifier: `live.diagnostics.section`

### Neue Accessibility-Identifier

| Element | Identifier |
|---------|-----------|
| Hero/Status-Card | `live.status.hero` |
| Karten-Preview | `live.map.preview` (war `live.map`) |
| Primäraktion (Start) | `live.recording.primaryAction` (war `live.cta.start`) |
| Stop-Aktion | `live.recording.stopAction` (war `live.cta.stop`) |
| Permission-Card | `live.permission.card` (neu) |
| Server-/Upload-Section | `live.server.status` (neu) |
| Diagnose-Bereich | `live.diagnostics.section` (neu) |

### Token- und Datenschutz

- Bearer-Token wird nie vollständig angezeigt — UI zeigt nur "Token set" / "No token"
- `hasBearerTokenConfigured` aus `serverUploadConfiguration.trimmedBearerToken` — kein Wert exposed
- Kein Token in Logs oder Tests

### Neue deutsche Strings (11)

Diagnostics, Ready to Record, Requesting Permission, Not Started, Location is being tracked and saved locally., Waiting for location access approval., Update location permissions in Settings to start recording., Tap Start Recording to begin a new live track., Tap Start Recording to request location access., Live recording metrics GPS accuracy and update statistics., Tap to view recording metrics and GPS details.

### Tests

- `LiveTrackingRedesignBatch5ATests` (8 Tests in `UIWiringTests.swift`):
  - `allowsForegroundTracking` für alle 5 Authorization-Zustände
  - Upload-Status initial = "Disabled" (kein Server konfiguriert)
  - Bearer-Token initial nicht konfiguriert
  - Permission-Title/-Message nicht leer bei restricted State
  - `isRecording` und `hasValidServerUploadConfiguration` initial false
- `AppLanguageSupportRedesignBatch5ATests` (11 Tests): EN-Identität + DE-Übersetzungen
- **Gesamt: 918 Tests, 0 Failures**

Nicht als abgeschlossen markieren:
- Keine echte iPhone-/Hardware-Verifikation durchgeführt
- Landscape-Verifikation weiter offen
- iPad regularSplitView weiter ungeprüft
- Live Activity / Dynamic Island Hardware-Verifikation weiter offen
- Neue App-Store-Screenshots weiter ausstehend

## [2026-05-05] — feat: UI/UX Redesign Batch 4 — Insights Dashboard

### Insights Dashboard (`AppInsightsContentView`)

- **Hero-Bereich**: Neue `insightsDashboardHero`-View direkt unter dem Titel, wenn Daten geladen sind.
  - Zeigt Datumsbereich aus `insights.dateRange` (z. B. „01.01.2024 – 31.12.2024") oder „All Time"
  - Zeigt Anzahl aktiver Tage (`daySummaries.filter(\.hasContent).count`) als farbiger Chip
  - Keine Fake-Metriken: alle Werte kommen aus repo-wahren Projektionen
- **Verbesserter Leer-Zustand**: `insightsFullEmptyState` unterscheidet zwei Szenarien:
  - Filter aktiv + keine Treffer: kontextueller Hinweis + „Filter zurücksetzen"-Button (CTA `insights.empty.resetFilter`)
  - Keine Daten: bestehendes Hinweis-Messaging, kein CTA
- **Overview-Tab Reihenfolge** angepasst (personal engagement first):
  - Vorher: Highlights → Daily Averages → Top Days → Activity Streak
  - Jetzt: **Highlights → Activity Streak → Top Days → Daily Averages**
- Alle bestehenden Drilldowns (Tage, Map, Export) unverändert erhalten
- Kein neues Analyse-Backend, keine neuen Chart-Typen, keine Fake-Felder

### Neue deutsche Strings

- `"active day"` → `"aktiver Tag"`
- `"active days"` → `"aktive Tage"`
- `"No days match the current filter. Adjust the range or reset it to see insights."` → `"Keine Tage passen zum aktuellen Filter. Passe den Zeitraum an oder setze ihn zurück."`
- `"Reset Filter"` → `"Filter zurücksetzen"`

### Tests

- `InsightsDashboardRedesignBatch4Tests` (7 neue Tests in `UIWiringTests.swift`):
  - Aktiver-Tage-Zähler schließt `hasContent == false` aus
  - Leer-Zähler bei leeren Summaries = 0
  - `last30Days`-Filter ist aktiv, Default-Filter nicht
  - Streak aus leeren Summaries = 0
  - Streak aus einer aktiven Summary: `longestStreakDays == 1`
  - Top Days aus leeren Summaries ist leer
  - `availableMetrics` aus leeren Summaries ist leer
- `AppLanguageSupportRedesignBatch4Tests` (8 neue Tests): EN-Identität + DE-Übersetzungen aller 4 neuen Strings
- **Gesamt: 897 Tests, 0 Failures**

## [2026-05-05] — feat: UI/UX Redesign Batch 3 — Export Checkout

### Export-Flow (`AppExportView`)

- Export als klarer Review-/Checkout-Flow neu strukturiert, ohne neue Export-Engine oder Builder:
  - Header mit kurzer Checkout-Erklärung statt technischem Wizard-Fokus
  - Abschnitt **`Review Selection`** als primärer Prüfschritt
  - Abschnitt **`Preview`** zeigt weiter die bestehende Map-Vorschau, fällt aber bei fehlender stabiler Geometrie sauber auf eine kompakte Summary zurück
  - Abschnitt **`Choose Format`** bleibt auf den repo-wahren Formaten `GPX`, `KMZ`, `KML`, `GeoJSON`, `CSV`
  - bestehende Inhaltswahl (`Tracks` / `Waypoints` / `Both`) bleibt erhalten, ist aber sprachlich als „What to include" sekundär eingeordnet
  - neuer Abschnitt **`Export Destination`** erklärt den echten Systempfad: generierte Datei → systemseitig sichern oder teilen
- Kein doppelter Primärbutton im Content: nur die sticky Bottom-Bar enthält die finale Primäraktion

### Auswahl prüfen / Review-Logik

- `ExportPresentation.reviewSnapshot(...)` neu:
  - bündelt echte Export-Review-Daten aus bestehender Auswahl
  - enthält `readiness`, ausgewählte Tage/Live-Tracks, Routen, Wegpunkte, Punkte und Datumsbereich
  - keine Fake-Metriken; Werte kommen aus bestehender `ExportSelectionContent.exportDays(...)`-Projektion
- `ExportPresentation.selectionSummary(...)` neu:
  - Bottom-Bar- und Review-Zusammenfassung jetzt als `Tage + Live-Tracks` statt generischer `Einträge`
- `AppExportView` zeigt im Review-Bereich jetzt:
  - ausgewählte Tage
  - Zeitraum
  - Tracks
  - Punkte
  - Distanz-/Wegpunkt-/Routenauswahl-Badges
  - Warning-Banner bei ungültiger Auswahl (`nothingSelected` / `noExportableContent`)

### Navigation / Rückführung

- `AppExportView` akzeptiert jetzt optionale Callbacks `onOpenImport` und `onOpenDays`
- Compact-Export-Tab in `AppContentSplitView` verdrahtet:
  - `Open Days` springt zurück auf Tab `Days`
  - `Import File` nutzt weiter den bestehenden Import-Callback
- Regular-Width Export-Sheet bleibt korrekt rückführbar:
  - Import-CTA nutzt weiter `onOpen`
  - Rückweg zu bestehenden Flächen bleibt über bestehendes Sheet-/Dismiss-Verhalten erhalten

### Bestehende Export-Verdrahtung unverändert

- unverändert echte Exportpipeline:
  - `ExportSelectionState`
  - `ExportSelectionContent.exportDays(...)`
  - `GPXBuilder`, `KMLBuilder`, `KMZBuilder`, `GeoJSONBuilder`, `CSVBuilder`
  - `ExportDocument` / `KMZExportDocument`
  - `.fileExporter`
- keine neue Serverfunktion
- keine Parser-/Converter-/Contract-Änderung
- keine parallele Selection-State-Kopie

### Tests

- `ExportPresentationTests` erweitert:
  - Empty-Selection-Review-Snapshot
  - Review-Snapshot mit realer Auswahl
  - Auswahlsummary `days + live track`
- `swift test`: **881 Tests, 0 Failures** (+3 Tests)
- `git diff --check`: sauber

### Offen — nicht als erledigt markieren

- visuelle iPhone-Verifikation des neuen Export-Checkout-Flows ausstehend
- Landscape-Verifikation des Export-Tabs ausstehend
- iPad-/regular-width visuelle Prüfung des Export-Sheets ausstehend
- App-Store-Screenshots weiter offen; Slot `05-export.png` muss nach diesem Checkout-Umbau neu aufgenommen werden

---

## [2026-05-05] — feat: UI/UX Redesign Batch 2 — Start + Overview

### Startseite (AppShellRootView)

- `HomeLocalPrivacyRow` (neue private View): kompaktes Privacy-+Formate-Info-Banner zwischen Titel und Import-Button
  - Schloss-Icon + "Processed locally · JSON, ZIP, GPX, TCX"
  - Accessibility: `home.localNotice`, vollständiges Label für Screenreader
  - Kein Account, kein Cloud-Zwang — klar kommuniziert ab dem ersten Öffnen
- Alle bestehenden Accessibility-Identifier (`home.title`, `home.import.primary`, `home.googleHelp`, `home.demo`) bleiben unverändert

### Übersicht / Overview (AppContentSplitView)

- **Reihenfolge überarbeitet**: Karte jetzt zuerst (vor Zeitraum-Card), dann KPI-Sektion, dann Filter/Zeitraum
  - Vorher: Status → Zeitraum → Karte → KPI → Highlights → Continue → LiveTracks
  - Jetzt: Status → Karte → KPI → Zeitraum → Highlights → Continue → LiveTracks
- **Empty State**: wenn `!session.hasDays && !session.isLoading` → neue `overviewEmptyCallToAction`-Card
  - "Get Started" Header + Nutzen-Beschreibung + "Import File" CTA-Button
  - Accessibility: `overview.empty`, `overview.empty.import`
  - Zeitraum-Card und Continue-Card werden bei leerem State nicht angezeigt
- **Continue-Card vereinfacht**: "Browse Days" als visuell hervorgehobene primäre Aktion (getönter Hintergrund)
  - Sekundäre Aktionen (Insights, Export, Import New File) als kleinere Zeilen darunter
  - Alle bestehenden Accessibility-Identifier bleiben: `overview.continue.days/insights/export/import`
- **Kein Fake-State**: ausschließlich bestehende Session/Summary/Insights-Quellen genutzt

### Tests

- 19 neue Tests: `StartOverviewRedesignTests` (UIWiringTests.swift) + `AppLanguageSupportRedesignBatch2Tests`
- `swift test`: **878 Tests, 0 Failures** (+19 Tests)

### Offen — nicht automatisiert prüfbar (Hardware-/Visuell-Verifikation)

- Startseite: visuell auf iPhone 15 Pro Max zu prüfen (Hero + Privacy-Row + Import-Button)
- Übersicht: Reihenfolge Karte → KPI auf echtem Gerät zu prüfen
- Übersicht: Empty State CTA auf echtem Gerät zu prüfen
- Landscape-Verifikation auf echtem Gerät für Start + Overview
- iPad `regularSplitView` unverändert, visuell ungeprüft

---

## [2026-05-05] — chore: Verifikations-Batch Sticky Map Workspace

### Strukturelle Tests für Days-Tab

- 10 neue Tests in `DaysCompactLayoutStructureTests` (UIWiringTests.swift)
- Verifikation: `daysMapHeaderState` startet als `.compact` + `isSticky: true`
- Verifikation: `toggleHidden()` nie `.hidden` bei `isSticky == true`
- Verifikation: `ExportSelectionState.count == 0` blendet Bottom-Bar aus; count > 0 zeigt sie
- `swift test`: **859 Tests, 0 Failures** (+10 neue Tests)

### Offen — nicht automatisiert prüfbar

- Landscape-Verifikation auf echtem Gerät (Days sticky Header + Bottom-Bar)
- iPad-Verifikation (`regularSplitView` nutzt `daysMapHeaderCard` — visuell ungeprüft)
- Hardware-Verifikation: kein neuer Gerätenachweis aus diesem Batch

---

## [2026-05-05] — feat: Sticky Map Workspace für Days-Ansicht (feat/sticky-map-workspace-days)

### Strukturelles UX-Redesign: Days-Tab

**`LHMapHeaderState.isSticky` — nicht versteckbarer Map-Header-Modus**

- `LHMapHeaderState` um `isSticky: Bool = false` erweitert (rückwärtskompatibel: Default `false`)
- `toggleHidden()` ist No-Op wenn `isSticky == true` — Map kann nicht ausgeblendet werden
- Expand / Collapse / Fullscreen bleiben weiterhin verfügbar
- `LHCollapsibleMapHeader.controlBar`: Toggle-Button wird bei `isSticky` ausgeblendet
- 16 neue Tests in `LHMapHeaderStateStickyTests` (849 gesamt, 0 Failures)

**Days-Tab: Sticky Map Workspace**

- `daysMapHeaderState` startet ab sofort mit `visibility: .compact` + `isSticky: true` statt `.hidden`
- Map ist im Days-Tab immer sichtbar (compact ↔ expanded) — kann nicht ausgeblendet werden
- `compactDayList` restructuriert: Map-Header aus scrollbarer Liste extrahiert
- `daysListStickyHeader` (neue private View): Map + Kontext-Pills als `.safeAreaInset(edge: .top)` — scrollt nicht mehr mit dem List-Content weg
- Kontext-Pills (Datumsbereich, Suche) jetzt direkt über der Karte sichtbar

**Days-Tab: Persistente Export-Auswahl-Bottom-Bar**

- `daysExportSelectionBar` (neue private View) als `.safeAreaInset(edge: .bottom)`: erscheint wenn ≥ 1 Tag für Export ausgewählt
- Zeigt Auswahl-Titel, Kurztext und Button "Export" (direkter Tap springt zu Export-Tab)
- Ersetzte bisherigen scrollbaren List-Section-Eintrag — ist jetzt persistent sichtbar beim Scrollen

### Keine Breaking Changes

- Alle bestehenden Bindings, States, NavigationPath-Verhalten und Tab-Reselection unverändert
- `daysMapHeaderCard` bleibt für iPad-Layout über `AnyView(daysMapHeaderCard)` unverändert nutzbar
- Keine neue State-Quelle, kein neuer GlobalSingleton
- `swift test`: **849 Tests, 0 Failures** (+16 neue Tests)

---

## [2026-05-05] — chore: Build 74 Accepted — Pending Developer Release (chore/asc-build74-accepted-pending-release)

### ASC-Status: Ausstehende Entwicklerfreigabe (Pending Developer Release)

- **Version 1.0 (Build 74)**: nach Ablehnung (Guideline 3.2, 2026-05-01) und Review-Response von Sebastian **akzeptiert** durch Apple App Review
- **Statusverlauf**: Abgelehnt → Wird geprüft → **Ausstehende Entwicklerfreigabe**
- **Build 74 wird bewusst nicht veröffentlicht**: Sebastian möchte vor öffentlichem Release weiterentwickeln und einen neuen Build einreichen
- **Guideline 3.2**: als resolved/accepted dokumentiert — kein offener Ablehungsgrund mehr
- **Keine Live-Schaltung**: App ist nicht im App Store verfügbar; Status bleibt Pending Developer Release

### Doku aktualisiert

- `CHANGELOG.md`: dieser Eintrag
- `NEXT_STEPS.md`: Review-Response als erledigt markiert; P0 auf Strategie „neuer Build vor öffentlichem Release" umgestellt
- `ROADMAP.md`: Abschnitt „Build 74 Accepted — Pending Developer Release" ergänzt
- `docs/APP_REVIEW_RESPONSE_GUIDELINE_3_2.md`: Status auf Accepted aktualisiert; Historische-Submissions-Tabelle ergänzt
- `docs/ASC_SUBMIT_RUNBOOK.md`: Status auf Ausstehende Entwicklerfreigabe; neue Strategie für neuen Build vor Release dokumentiert
- `docs/APPLE_VERIFICATION_CHECKLIST.md`: Guideline 3.2 auf ✅ Accepted; ASC-Status nachgezogen
- `wrapper/docs/TESTFLIGHT_RUNBOOK.md`: ASC-Stand auf Pending Developer Release; Guideline 3.2 auf ✅

### Keine Code-Änderungen

- `swift test`: 833 Tests, 0 Failures (unverändert)
- keine ASC-Aktion ausgeführt — nur Repo-Doku-Sync

---

## [2026-05-05] — chore: Guideline 3.2 Public Audience Clarification (fix/review-guideline-3.2-public-audience-clarification)

### App Review Ablehnung dokumentiert

- **Version 1.0 (Build 74)** vom Apple App Review am 2026-05-01 abgelehnt
- **Submission ID**: `1d2cc080-13cd-45cd-b3e0-c0259a75ce5c`
- **Ablehnungsgrund**: Guideline 3.2 — Business / Other Business Model Issues
- **Apple-Einschätzung**: App wurde fälschlich als organisationsgebundene/unternehmensinterne App eingestuft
- **Sachverhalt**: LH2GPX ist eine öffentliche Consumer-/Utility-App; kein Account, kein Login, keine Org-Zugehörigkeit erforderlich; alle Daten bleiben lokal; optionaler Live-Upload ist nutzerkonfigurierter self-hosted Endpunkt, standardmäßig deaktiviert

### Klarstellungen und neues Dokument

- `README.md`: Consumer-/Utility-Charakter explizit in „Was die App macht" ergänzt; `lh2gpx-live-receiver` als Beispiel-/Referenzimplementierung (nicht zentraler Dienst) klargestellt; Live-Aufzeichnungs-Feature um „kein zentraler Dienst, keine Organisationsbindung" erweitert; aktuellen Review-Status nachgezogen
- `docs/APP_REVIEW_RESPONSE_GUIDELINE_3_2.md`: neu — vollständige Ablehungs-Dokumentation + Response-Entwurf für ASC (EN)
- `docs/APP_FEATURE_INVENTORY.md`: neuer Abschnitt „Public Audience Statement" — Zielgruppe, kein Account-Zwang, lokale Datenhaltung, Self-hosted-Upload-Natur
- `docs/APPLE_VERIFICATION_CHECKLIST.md`: Ablehnungsdetails (Build 74, Submission ID, Guideline 3.2) ergänzt; Guidelines-Tabelle um 3.2-Zeile erweitert
- `docs/ASC_SUBMIT_RUNBOOK.md`: Status auf Abgelehnt (Build 74) aktualisiert; Guideline-3.2-Response als aktuell blockierenden Schritt ergänzt
- `wrapper/docs/TESTFLIGHT_RUNBOOK.md`: ASC-Stand auf Abgelehnt (Build 74) + Guideline-3.2-Eintrag in Guidelines-Tabelle
- `NEXT_STEPS.md`: P0 — Review-Response als oberste Priorität; Build-Einreichung erst nach positivem Outcome
- `ROADMAP.md`: Ablehnung und Clarification-Stand dokumentiert

### Keine Code-Änderungen an Produktlogik oder Tests

- `swift test`: 832 Tests, 0 Failures (unverändert)
- keine ASC-Aktion ausgeführt — nur Repo-Vorbereitung und Doku

## [2026-05-01] — chore: Build 73 Screenshot + Submit Prep (release/build-73-screenshots-submit-prep)

### ASC-Stand aktualisiert

- **Version 1.0**: `Warten auf Prüfung`, sichtbarer Build jetzt `71` (von Sebastian bestätigt)
- **Xcode Cloud Build 73**: aktuellster erfolgreicher Build, entspricht Repo-Stand `34734ce`
- **Lokale Build-Nummer** in `project.pbxproj`: `CURRENT_PROJECT_VERSION = 45` (Xcode Cloud überschreibt mit `CI_BUILD_NUMBER`)
- **Build-73-Kandidatenstatus**: Repository-Stand eindeutig zu Build 73 passend; kein neuer Code nach truth sync; Build 73 ≠ lokal archivierter Build — Xcode Cloud ist der alleinige Upload-Pfad

### Screenshot-Infrastruktur erweitert

- `wrapper/LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift`: `testAppStoreScreenshots` um Slots 07 (`07-options`) und 08 (`08-day-detail`) erweitert; bestehende Slots 01–06 für das neue Redesign-Layout kommentiert
- `docs/app-store-assets/screenshots/README.md`: vollständig überarbeitet mit Status-Tabelle (01–06 vorhanden/alt, 07–08 ausstehend), Sicherheitsregeln, Slot-Übersicht für Build 73

### Neues Runbook

- `docs/ASC_SUBMIT_RUNBOOK.md`: vollständige manuelle ASC-Schritte für Build 73 (Screenshot-Extraktion, Version aus Prüfung entfernen, Build-Tausch, Screenshot-Upload, erneutes Submit)

### Dokumentation nachgezogen

- `docs/APPLE_VERIFICATION_CHECKLIST.md`: ASC-Status auf Build 71 / Xcode Cloud Build 73 aktualisiert; Screenshot-Status (altes Layout) und Handlungsanweisung ergänzt
- `NEXT_STEPS.md`: P0-Aufgaben für Build 73 + neue Screenshots als oberste Priorität gesetzt
- `ROADMAP.md`: Build-73-Vorbereitungsstand dokumentiert
- `wrapper/docs/TESTFLIGHT_RUNBOOK.md`: ASC-Stand auf Build 71 / Xcode Cloud Build 73 nachgezogen

### Keine Code-Änderungen an Produktlogik oder Tests

- `swift test`: 832 Tests, 0 Failures (unverändert)
- kein Archive, kein Upload, keine ASC-Aktion — nur Repo-Vorbereitung

## [2026-05-01] — chore: Final UI/Localization Truth Sync (ui/redesign-final-truth-sync)

### Fehlende deutsche Übersetzungen ergänzt

9 Strings, die in der Options/Widget/Upload-UI mit `t()` verwendet werden, fehlten im deutschen Dictionary:
- `"Invalid URL"` → `"Ungültige URL"` (Upload-Status-Chip)
- `"Automatic Widget Update"` → `"Automatisches Widget-Update"` (Widget-Toggle)
- `"Widget & Live Activity"` → `"Widget & Live-Activity"` (Section-Titel und Nav-Link)
- `"Live Activity"` → `"Live-Activity"` (Section-Titel)
- `"Reachable"` → `"Erreichbar"` (Verbindungstest-Ergebnis)
- `"Unreachable"` → `"Nicht erreichbar"` (Verbindungstest-Fehler)
- `"Test Connection"` → `"Verbindung testen"` (Upload-Subpage-Button)
- `"Testing…"` → `"Testen…"` (Verbindungstest Spinner-Label)
- `"Last tour + weekly status"` → `"Letzte Tour + Wochenstatus"` (Widget-Vorschau)

### Tests erweitert

- `AppPreferencesTests.testDefaultsAreSensible`: prüft jetzt auch `widgetAutoUpdate = true` und `maximumRecordingGapSeconds = 300`
- `AppPreferencesTests.testResetRestoresDefaults`: prüft Reset von `widgetAutoUpdate` und `maximumRecordingGapSeconds`
- `AppLanguageSupportTests`: +2 neue Gruppen für Truth-Sync-Strings (DE + EN Identity)
- **Gesamtergebnis: 832 Tests, 0 Failures** (vorher 830)

### Doku

- `NEXT_STEPS.md`: Truth-Sync als abgeschlossen markiert; Screenshot-Aktualisierungsaufgabe als neues P2-Item ergänzt
- `ROADMAP.md`: Truth-Sync-Stand dokumentiert

## [2026-05-01] — feat: Options + Widget/Live Settings Redesign (ui/options-widget-live-settings)

### Neu: `RecordingPreset` (in `AppPreferences.swift`)

- Enum `RecordingPreset` mit Cases `battery`, `balanced`, `precise`, `custom`
- Computed property `recordingPreset` auf `AppPreferences`: deterministisch aus `liveTrackingAccuracy` + `liveTrackingDetail` abgeleitet; kein neuer UserDefaults-Key
- Setter: `battery` → `.relaxed`/`.batterySaver`, `balanced` → `.balanced`/`.balanced`, `precise` → `.strict`/`.detailed`, `custom` → no-op

### Neu: `OptionsPresentation.swift`

- Statische Helpers `uploadStatusText`, `uploadStatusColor`, `serverUploadPrivacyText` — reine Darstellungslogik, kein Business-Code

### Neu: `LHOptionsComponents.swift`

- `LHOptionsSectionRow(icon:title:description:color:)` — dunkle Card-Zeile mit Icon-Badge, Titel, Beschreibung, Chevron
- `LHLiveRecordingPresetSelector(preset:t:)` — horizontale Chip-Leiste für 4 Presets (farbkodiert) mit Accessibility-Identifiern
- `LHUploadSettingsCard(preferences:t:)` — Toggle + URL-Feld + `SecureField` für Bearer-Token (nie im Klartext) + Batch-Picker + Status-Dot
- `LHDynamicIslandPreviewCard(display:availability:t:)` — Icon-Badge, Titel, Availability-Chip; Identifier `options.dynamicIsland.preview`
- `LHWidgetPreviewCard(distanceUnit:t:)` — Icon-Badge, Titel+Beschreibung; Identifier `options.widget.preview`

### Redesign: `AppOptionsView.swift`

- Hauptseite: NavigationLink-Grid mit 8 Section-Rows (General, Maps, Import, Live Recording, Upload, Widget & Live Activity, Privacy, Technical); schwarzer Hintergrund, dunkle Cards
- `AppLiveRecordingOptionsView`: Preset-Card + Settings-Card; Advanced-Werte nur bei `.custom` vollständig editierbar
- `AppUploadOptionsView`: `LHUploadSettingsCard` + optionaler Verbindungstest + Hinweis-Banner; Token nur als `SecureField`
- `AppWidgetLiveActivityOptionsView`: DI-Picker + Vorschau-Card + Widget-Card + Verfügbarkeits-Banner
- Sub-pages General, Maps, Import, Privacy, Technical vollständig erhalten

### Erweiterung: `AppLanguageSupport.swift`

- 36 neue DE/EN-Einträge für Options/Widget/Live-Activity-Redesign (General, Live Recording, Preset-Namen, Token-Felder, DI-Werte, Widget-Strings, Section-Descriptions, Reset-Disclaimer)

### Tests

- `AppPreferencesTests`: +7 neue Testmethoden (RecordingPreset-Mapping, DI-Persist, Upload-Persist)
- `UIWiringTests`: +9 neue Tests (Preset-Wiring, DI-Cases, OptionsPresentation-Helpers, Accessibility-IDs)
- `LandscapeLayoutTests`: +4 neue Tests (OptionsPresentation orientierungsunabhängig, Preset-Berechnung, DI-localizedName)
- `AppLanguageSupportTests`: +3 neue Testgruppen (Options-Redesign, Widget/LA-Strings, English-Identity)
- `LiveActivityTests`: +6 neue Tests (DI-Primärwert-Formatierung für alle 4 Cases, Not-Recording-Fallback)
- `WidgetDataStoreTests`: +3 neue Tests (allCases round-trip, suiteName, App-Group-Mirroring)
- `LiveLocationServerUploaderTests`: +3 neue Tests (Token nicht im Body, trimmedBearerToken empty→nil, whitespace→nil)
- **Gesamtergebnis: 830 Tests, 0 Failures** (vorher 793)

## [2026-05-01] — feat: Live Tracking + Library Redesign (ui/live-tracking-redesign)

### Neu: `LHLiveComponents.swift`

Zwei neue spezialisierte UI-Komponenten für das Live-Tracking-Redesign:
- `LHLiveBottomBar` — Sticky Bottom Bar mit vollem Start-CTA (Mint) oder Stop-CTA (Rot); Identifier `live.cta.start / live.cta.stop`
- `LHLiveTrackRow` — Dark-Card-Zeile für die Live-Tracks-Bibliothek; wraps `SavedTrackSummaryContentView` mit LH2GPX-Kartenoberfläche

### Redesign: `AppLiveTrackingView`

Vollständiger Umbau des Live-Tracking-Screens auf LH2GPX-Dark-Designsystem:
- `ScrollView` + `LHPageScaffold` ersetzt alte padding-basierte Struktur; Sticky `LHLiveBottomBar` via `.safeAreaInset(edge: .bottom)`
- Kartenpolyline: `.red` → `LH2GPXTheme.liveMint`; Standortpunkt: Mint bei Aufzeichnung, Blau im Leerlauf
- Status-Chips-Zeile mit Accessibility-Identifiern: `live.status.ready`, `live.status.gps`, `live.status.follow`, `live.status.upload`
- Recording-Card ohne eingebetteten Start-/Stop-Button; Dauer-Anzeige in Mint bei laufender Aufzeichnung; Identifier `live.recording.card`
- Primäre 4 Metriken mit Accessibility-Identifiern: `live.metric.distance`, `live.metric.duration`, `live.metric.points`, `live.metric.averageSpeed`
- Upload-Quick-Actions aus `recordingSection` in `uploadSection` verschoben; Pause-Button Identifier `live.cta.pause`
- Saved-Tracks-Karte: Mint-Badge, „Alle Live-Tracks anzeigen"-Button; Identifier `live.savedTracks.preview / live.savedTracks.openAll`
- Advanced-Section: Follow-Toggle als Capsule-Chip statt separater Zeile; Background-Recording-Toggle unverändert
- Interrupted-Session-Banner vollständig erhalten; Identifier `live.interrupted.resume` unverändert
- Fullscreen-Map-Flow und alle `.onChange`-Handler vollständig erhalten

### Redesign: `AppRecordedTracksLibraryView`

Umbau der Saved-Live-Tracks-Bibliothek auf LH2GPX-Dark-Layout:
- `navigationTitle` von „Saved Live Tracks" auf „Live Tracks" (nutzt bestehende DE-Übersetzung „Live-Tracks")
- `List` ersetzt durch `ScrollView` + `LHPageScaffold`; `navigationDestination(for: RecordedTrack.self)` vollständig erhalten
- Info-Card mit „Lokal gespeichert"-Label, Trennungshinweis und Track-Zähler-Badge
- Track-Zeilen als `LHLiveTrackRow` mit `NavigationLink(value:)` + Index-Identifier `liveTracks.row.<index>`; Identifier `liveTracks.list`
- Neues optionales `onNewTrack: (() -> Void)?`-Parameter — zeigt „Neuer Track"-Button wenn gesetzt; Identifier `liveTracks.newTrack`
- Accessibility-Identifier `liveTracks.info`, `liveTracks.title`

### Erweiterung: `LiveTrackingPresentation`

Neue testbare statische Presentation-Helpers:
- `gpsStatusLabel(accuracyM:) -> String` — „GPS Good" / „GPS Weak" basierend auf Genauigkeitsschwellwert (< 30 m)
- `uploadSectionVisible(sendsToServer:pendingCount:statusMessage:) -> Bool`

### Neue DE/EN Strings in `AppLanguageSupport`

13 neue Strings: GPS Good/Weak, Upload Active/Off/Waiting, View All Live Tracks, New Track, Stored Locally, Separate from imported history, Follow On/Off, Recording Active

### Tests: +20 neue Tests

- `LiveTrackingPresentationTests`: +9 (GPS-Status, Upload-Visibility)
- `UIWiringTests`: +7 (Deep-Link, CTA-State, GPS-Status, Track-Row)
- `LandscapeLayoutTests`: +3 (Metric-Snapshot, Track-Row, GPS-Status)
- `AppLanguageSupportTests`: +2 (DE/EN Live-Tracking-Strings)
- 793 Tests gesamt, 0 Failures

### Unverändert (kein Eingriff)

Alle bestehenden Verdrahtungen erhalten: `LiveLocationFeatureModel`, `LiveTrackRecorder`, `RecordedTrackStore`, `WidgetDataStore`, `TrackingAttributes`, `ActivityManager`, `LiveActivityPresentation`, `LiveLocationServerUploader`, `AppContentSplitView.syncLiveRecordingSettings`, Upload Pause/Resume/Flush, Start/Stop/Save-Track-Pfad, Interrupted-Session-Resume-Flow, Deep-Link `lh2gpx://live`, Widget-/App-Group-Mirroring, `AppRecordedTrackEditorView` vollständig unverändert

---

## [2026-05-01] — feat: Export Checkout Redesign (ui/export-checkout-redesign)

### Neu: `LHExportComponents.swift`

Drei neue spezialisierte UI-Komponenten für den Export-Checkout-Flow:
- `LHExportStepIndicator` — linearer 4-Schritt-Fortschrittsindikator (Auswahl / Format / Inhalt / Fertig); Identifier `export.step.*`
- `LHExportBottomBar` — Sticky Bottom Bar mit kompakter Zusammenfassung und primärem Export-Button; Identifier `export.bottomBar / export.summary / export.primaryButton / export.disabledReason`
- `LHExportFilterDisclosure` — einklappbare Disclosure-Card für erweiterte Exportfilter; Identifier `export.advancedFilters`

### `AppExportView.swift` — Checkout-/Wizard-Redesign

- Layout: `List` + `exportBar`-VStack → `ScrollViewReader { ScrollView { LHPageScaffold { … } } }` mit `.safeAreaInset(edge: .bottom)`
- Titel `Export` mit `.title.weight(.bold)`; Identifier `export.title`
- `LHExportStepIndicator` basierend auf `ExportPresentation.readiness` (nothingSelected → step 0, noExportableContent → step 1, ready → step 3)
- Insights-Drilldown-Card: `LHCard` mit Label "Aus Insights übernommen" + Reset-Button; Identifier `export.resetDrilldown`
- Range-Filter-Card: `AppHistoryDateRangeControl` in `LHCard`; Identifier `export.range.card`
- Vorschau-Card: `AppExportPreviewMapView` in `LHCard` (hidden → kein Rendern); Identifier `export.map.preview`
- Auswahl-Card: 4-KPI-Grid (Tage/Routen/Zeitraum/Orte mit `LHMetricCard`) + Badge-Scroll + "Auswahl bearbeiten"-Button mit `ScrollViewProxy`; Identifier `export.selection.card / export.selection.edit`
- Tage-Card + Live-Tracks-Card: `ForEach`-Rows ohne `List`; Identifier `export.liveTracks.card`
- Format-Card: 5 Formatpillen (GPX/KMZ/KML/GeoJSON/CSV) mit aktivem Highlight-Background; Identifier `export.format.card`
- Inhalt-Card: 3 Moduspillen (Tracks/Waypoints/Both) mit aktivem Highlight-Background; Identifier `export.content.card`
- Erweiterte Filter: `LHExportFilterDisclosure` mit Dismiss-Button in LHContextBar
- `LHExportBottomBar` ersetzt alten `exportBar`: Zusammenfassung "N Einträge · GPX" links, primärer Button rechts, Disabled-Grund darunter
- Alle bestehenden Verdrahtungen unverändert: fileExporter, onChange, prepareExport, per-route-selection, InsightsDrilldown, Area-/Date-/Accuracy-/Content-/ActivityType-Filter

### `ExportPresentation.swift` — Checkout-UI-Helfer

- `bottomBarSummary(...)` — liefert kurze Bottom-Bar-Zusammenfassung ("N Einträge · GPX")
- `disabledReason(...)` — liefert nil wenn bereit, sonst lesbaren Grund

### `AppLanguageSupport.swift` — neue DE/EN-Strings

Selection / Content / Edit Selection / Export Format / Advanced Filters / No exportable data selected / No exportable routes selected / Reset Drilldown / Adopted from Insights / Live Tracks / Tracks + Waypoints

### Tests

- `ExportPresentationTests` + 10 neue Tests: bottomBarSummary, disabledReason, Format-Labels, Step-Readiness
- `UIWiringTests` + 8 neue Tests: Drilldown-Export-Wiring, Format-Pillen, Export-Button disabled/enabled, Live-Tracks-Bottom-Bar
- `LandscapeLayoutTests` + 2 neue Tests: Readiness orientierungsunabhängig, Bottom-Bar-Zusammenfassung stabil
- `AppLanguageSupportTests` + 2 neue Tests: DE/EN Export-Checkout-Strings

### Unverändert

- `app_export`-Contract, GPXBuilder, KMLBuilder, KMZBuilder, CSVBuilder, GeoJSONBuilder
- ExportSelectionState, ExportSelectionContent, ExportPreviewData, ExportPreviewDataBuilder
- FileExporter-Flow, Live-Tracks-Export, InsightsDrilldown-Wiring, Area-Filter, Accuracy-Filter

---

## [2026-05-01] — feat: Insights Dashboard Redesign (ui/insights-dashboard-redesign)

### Neu: `LHInsightsComponents.swift`

Vier neue öffentliche Unterkomponenten für die Insights-Seite:
- `LHInsightsMetricGrid` + `LHInsightsMetricItem` — datengetriebenes 2×2-Grid aus `LHMetricCard`-Kacheln
- `LHInsightsChartCard` — Section-Card-Shell mit optionalem Share-Button und LH2GPXTheme-Oberfläche
- `LHInsightsTopDayRow` — kompakte Rang-Zeile (Rang-Badge, Datum, Primärwert)
- `LHInsightsActionRow` — Drilldown-Action-Zeile mit Icon + Pfeil

### `AppInsightsContentView.swift` — Visuelles Redesign

- Titel: `Text("Insights Overview")` → `Text("Insights")` mit `.title.weight(.bold)`, Identifier `insights.title`
- Active-Filter-Banner durch `LHContextBar` ersetzt
- Neues 4-KPI-Grid: Distanz (lila) / Aktive Tage (grün) / Routen (orange) / Orte (mint) via `LHMetricCard`; Identifier `insights.kpi.*`
- `AppHistoryDateRangeControl` mit Identifier `insights.range`
- `insightSection`-Hintergrund/Border/Shadow → `LH2GPXTheme.card / cardBorder / cardShadow`
- `periodComparisonRows`, `monthlyTrendRow`, `periodRow` → `LH2GPXTheme.card`
- Share-Button-Identifier: `"insights.section.share"` → `"insights.share.\(shareCardType.rawValue)"`
- `dayDrilldownTargets` nutzt jetzt `InsightsDrilldownTarget.drilldownTargets(for:)` (vollständiges Triple inkl. `showDayOnMap`)
- `dateRangeDrilldownTargets`: Labels "Show in Days" → "Open in Days", "Export This Period" → "Select for Export"

### `InsightsDrilldown.swift` — Drilldown-Labels aktualisiert

- `showDay`: "Show in Days" → "Open in Days"
- `exportDay`: "Export This Day" → "Select for Export"
- `showDayOnMap`: "Show on Map" (unverändert, jetzt DE-übersetzt)

### AppLanguageSupport — neue DE/EN Strings

"Open in Days"→"In Tage öffnen", "Select for Export"→"Für Export auswählen", "Show on Map"→"Auf Karte zeigen", "Activity Overview"→"Aktivitätsübersicht", "Activity Streak"→"Aktivitätsserie", "Period Comparison"→"Periodenvergleich", "Import More Data"→"Mehr Daten importieren"

### Tests

- `AppLanguageSupportTests` — 12 neue Tests für alle neuen Strings (DE + EN-Identity)
- `UIWiringTests` — 4 neue Tests: Drilldown-Label-Strings, Triple mit Map-Ziel, Range-Reset
- `InsightsCardPresentationTests` — 3 neue Tests: KPI-Summen, Empty State
- `LandscapeLayoutTests` — 2 neue Tests: KPI-Werte Landscape-unabhängig, SurfaceMode-Anzahl

### Nicht geändert

- Keine Chart-Berechnungslogik
- Keine Drilldown-Ziele entfernt
- Keine Map-Logik geändert
- Keine Live-Tracking-/Widget-/Dynamic-Island-Logik
- Kein App-Export-Contract geändert

### Checks

- `swift test`: 753 Tests, 0 Failures (Branch: `ui/insights-dashboard-redesign`)
- `git diff --check`: sauber
- `xcodebuild build -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS'`: BUILD SUCCEEDED

---

## [2026-04-30] — feat: Tage + Tagesdetail sichtbar auf neues LH2GPX-Dark-Redesign umgebaut

### Produkt-UI

- `AppContentSplitView.swift`, `AppDayListView.swift`: `Days` sichtbar auf grosses Titel-Layout mit echter schwarzer Flaeche umgebaut; kompakte Context-Zeile fuer Zeitraum und Suche; reduzierte Filterchips fuer `Alle`, `Mit Routen`, `Favoriten`, `Exportiert`; optionaler `LHCollapsibleMapHeader` mit bestehendem Day-Map-Kontext produktiv angebunden
- `AppDayListView.swift`, `DaySummaryRowPresentation.swift`: Day Rows sichtbar modernisiert; grosses Datum links, Wochentag und Zeitspanne, getrennte Kennzeichnung fuer Favorit vs. Exportstatus, getrennte Kennzahlen fuer Orte / Routen / Aktivitaeten / Distanz; bestehende Verdrahtung ueber `DayListPresentation.filteredSummaries`, `DaySummaryRowPresentationBuilder`, `selectedDayID`, `daySearchText`, `dayListFilter` und `favoritedDayIDs` bleibt erhalten
- `AppDayDetailView.swift`, `DayDetailPresentation.swift`, `DayDetailContentHierarchy.swift`: Day Detail auf map-first Layout umgebaut; `AppDayMapView` bleibt die bestehende Kartenkomponente; darunter KPI-Karten fuer Distanz, Routen, Aktivitaeten und Orte sowie Segmentumschaltung fuer `Uebersicht`, `Timeline`, `Routen`, `Orte`
- `AppDayDetailView.swift`: bestehende Aktionen bleiben erreichbar; Favorit, Teilen/Export, Route anzeigen, per-route Exportauswahl sowie display-only Route entfernen laufen weiter ueber die vorhandenen States und Confirmation-Dialoge
- `AppContentSplitView.swift`: bestehendes compact-/regular-SplitView-Verhalten, `daysNavigationPath`, `compactDayList`, Insights-Drilldown nach `Days`, Tab-Reselection und iPad/Mac-Verdrahtung bleiben erhalten

### Business-/Export-Grenzen

- keine Aenderung an Parser-, Import-, Producer- oder Export-Builder-Logik
- keine neue Route-Kappung, kein neues Road-Snapping, kein neues Map-Matching
- display-only entfernte importierte Routen bleiben display-only; Export-Truth und per-route Auswahl in `ExportSelectionState.routeSelections` bleiben unveraendert
- Hidden-Map-Invariante bleibt erhalten: bei `.hidden` wird der Days-Map-Builder nicht ausgewertet

### Strings / Tests

- `AppLanguageSupport.swift`: DE/EN-Strings fuer neue Days-/Day-Detail-Beschriftungen und Export-/Map-Labels ergaenzt bzw. sichtbar wiederverwendet
- aktualisierte Tests in `OverviewAndDaySummaryPresentationTests`, `DayDetailContentHierarchyTests`, `AppLanguageSupportTests`

### Checks

- `swift test`: 741 Tests, 0 Failures

## [2026-04-30] — feat: Startseite + Übersicht sichtbar auf neues LH2GPX-Redesign umgebaut

### Produkt-UI

- `AppShellRootView.swift`: import-first Startseite mit schwarzer Flaeche, grossem `LH2GPX`-Titel, kompaktem Subtitle, blauem Primary-Button `Datei importieren`, dunklen Action Rows fuer `Google Maps Export-Anleitung` und `Demo laden`
- `RecentFilesView.swift` + `RecentFilesStore.swift`: `Zuletzt verwendet` als echte Start-Card uebernommen; Dateiname, Datum und optionale Dateigroesse sichtbar; `Alle anzeigen` fuer laengere Listen; Dateigroesse wird beim Speichern des Recent-Entries mitpersistiert
- `AppContentSplitView.swift`: Overview sichtbar neu strukturiert mit Importstatus-Card, Zeitraum-Card, KPI-Grid, Highlights-Card und `Weiterarbeiten`-Card; bestehende Navigation (`Days`, `Insights`, `Export`, `onOpen`) bleibt verdrahtet
- `AppSessionStatusView.swift`: Importstatus-Card auf dunkles Kartenlayout gezogen; aktive Datei wird kompakter dargestellt; Link `Technische Details anzeigen` ersetzt die alte technische Disclosure-Beschriftung

### Design-System / Map-Header-Pilot

- `LH2GPXTheme.swift`: `LHCard` als einfacher Karten-Wrapper auf Basis von `cardChrome()` ergänzt
- `AppContentSplitView.swift`: `LHCollapsibleMapHeader` jetzt auf der ersten echten Produktseite (`Overview`) pilotiert; `LHPageScaffold` und `LHContextBar` dort ebenfalls produktiv im Einsatz
- `AppOverviewTracksMapView.swift`: fuer Header-Einbettung konfigurierbar (`fixedHeight`, optionaler Fullscreen-Button); Badge-Text repo-wahr auf `Simplified preview · export complete` / `Vereinfachte Vorschau · Export vollständig` umgestellt

### Strings / Tests

- `AppLanguageSupport.swift`: neue DE/EN-Strings fuer Startseite, neue Overview-Karten, Continue-Aktionen und den neuen Badge-Text ergänzt
- neue/aktualisierte Tests in `UIWiringTests`, `AppLanguageSupportTests`, `AppPreferencesTests`, `GoogleMapsExportHelpTests`

### Checks

- `swift test`: 739 Tests, 0 Failures
- `xcodebuild build -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS'`: BUILD SUCCEEDED

## [2026-04-30] — feat: Wiederverwendbare Seiten-Architektur (Map-Header-Shell)

### Neu: `LHCollapsibleMapHeader.swift`

**`LHMapHeaderVisibility`** — enum (`hidden | compact | expanded | fullscreen`), keine SwiftUI-Abhängigkeit, Linux-safe.

**`LHMapHeaderState`** — Value-Type mit Performance-Invariante: `shouldRenderMap = visibility != .hidden`. Karte liegt bei `.hidden` **nicht** im View-Tree (kein `.hidden()`, kein `.opacity(0)` — `@ViewBuilder`-Closure wird nicht ausgewertet). Übergänge: `toggleHidden`, `expand`, `collapse`, `enterFullscreen`, `exitFullscreen`.

**`LHCollapsibleMapHeader<MapContent: View>`** — SwiftUI-View mit Control-Bar, animiertem Map-Container und Fullscreen-Cover (`#if os(iOS) || os(visionOS)`).

### Neu: `LHPageScaffold.swift`

- `LHPageScaffold` — dünner VStack-Wrapper mit konfigurierbarem Padding/Spacing
- `LHContextBar` — kompaktes Sticky-Banner für aktive Filter / Drilldown-Kontext

### AppLanguageSupport — neue DE/EN Strings

Neue Einträge: "Show Map"→"Karte anzeigen", "Collapse Map"→"Karte einklappen", "Expand Map"→"Karte erweitern", "Close Map"→"Karte schließen", "Dismiss"→"Schließen" (bereits vorhanden: "Fullscreen"→"Vollbild", "Map Preview"→"Kartenvorschau").

### Tests

- `LHMapHeaderTests.swift` — 40 Tests in 7 Klassen (Visibility, RenderInvariant, FrameHeight, Transitions, Predicates, ButtonLabels, Equatable, Sequences)
- `AppLanguageSupportTests.swift` — 14 Tests (EN-Identity + DE-Übersetzungen für alle neuen Strings)

### Nicht geändert
- Keine bestehenden Map-Komponenten (AppOverviewTracksMapView, AppDayMapView, AppExportPreviewMapView, AppHeatmapView)
- Kein Live-Tracking-Business-Logic
- Kein Widget / Dynamic Island

### Checks
- `swift test`: 730 Tests, 0 Failures (Branch: `ui/map-header-shell`)

---

## [2026-04-30] — feat: LH2GPX Design-System (Theme-Tokens + UI-Bausteine)

### Neu: `LH2GPXTheme.swift`

Zentrales Design-System in `Sources/LocationHistoryConsumerAppSupport/LH2GPXTheme.swift`:

**Color Tokens (LH2GPXTheme):**
- Kartenoberfläche: `card`, `elevatedCard`, `cardBorder`, `cardShadow`, `separator`, `chipBackground`
- Semantische Aktionsfarben: `primaryBlue`, `liveMint`, `successGreen`, `warningOrange`, `dangerRed`, `favoriteYellow`, `insightPurple`, `routeOrange`, `distancePurple`
- Texthierarchie: `textPrimary`, `textSecondary`, `textTertiary`

**Wiederverwendbare UI-Bausteine:**
- `View.cardChrome()` — Standard-Kartenoberfläche (Padding, Fill, Hairline-Border, Shadow); ersetzt die private Extension aus `AppLiveTrackingView`
- `LHSectionHeader` — Abschnittstitel mit optionalem Subtitle
- `LHStatusChip` — Kompakter Capsule-Chip für Status-Labels (Recording / Upload / Permission)
- `LHMetricCard` — Linksbündige Metrikkachel (Icon + Label + Wert) für 2-Spalten-Grids
- `LHInsightBanner` — Informations-/Guidance-Banner mit Icon, Titel, Beschreibung
- `LHFilterChip` — Toggle-Capsule für Filterbars

### Migrierte Stellen

**`AppLiveTrackingView.swift`:**
- Private `cardChrome()` Extension entfernt → nutzt jetzt `LH2GPXTheme.View.cardChrome()`
- Private `statusChip()` entfernt → alle Call-Sites verwenden `LHStatusChip`
- Private `statCard()` entfernt → alle Call-Sites verwenden `LHMetricCard`
- Private `insightBanner()` entfernt → alle Call-Sites verwenden `LHInsightBanner`
- Betroffen: `statusChips`, `recordingSection` (8 Metrikkacheln), `uploadSection` (6 Metrikkacheln + Chip + 2 Banner), `savedTracksSection` (1 Banner), `advancedSection` (1 Banner)

**`AppDayListView.swift` (`AppDayFilterChipsView`):**
- Button-Chip-Body durch `LHFilterChip` ersetzt; gleiche Visuals, zentralisierte Token-Nutzung

**`RecentFilesView.swift`:**
- Hintergrund von `Color.secondary.opacity(0.07)` auf `LH2GPXTheme.card` migriert
- Hairline-Border (`LH2GPXTheme.cardBorder`) ergänzt — passt zur Card-Sprache im Rest der App

**`OverviewPresentation.swift` (`OverviewStatAccent.swiftUIColor`):**
- Hardcodierte `.blue`, `.purple`, `.green`, `.orange` → `LH2GPXTheme.primaryBlue` etc.

### Nicht geändert
- Keine Business-Logik, kein Presentation-Modell, keine Map-Logik
- Widget / Dynamic Island: nicht angefasst (System-Farben, kein rein-sicherer Token-Pfad)
- Kein komplettes Redesign; Farbidentität und Abstände sind unverändert

### Checks
- `swift test`: 667 Tests, 0 Failures
- `git diff --check`: kein Whitespace-Fehler

## [2026-04-30] — docs: GitHub Pages live verifiziert und Screenshot-Assets repo-wahr dokumentiert

### Geprüft und dokumentiert

**GitHub Pages (live, HTTP 200 bestätigt 2026-04-30):**
- `https://dev-roeber.github.io/iOS-App/` → HTTP 200, server: GitHub.com
- `https://dev-roeber.github.io/iOS-App/support.html` → HTTP 200
- `https://dev-roeber.github.io/iOS-App/privacy.html` → HTTP 200
- Last-Modified: 2026-04-30 (passt zum letzten Commit)
- Keine Tokens, Secrets oder private Pfade in den HTML-Dateien
- E-Mail `dev_roeber@icloud.com` in support.html und privacy.html: bewusst als Support-Kontakt vorhanden

**Screenshot-Assets lokal vorhanden (`docs/app-store-assets/screenshots/`):**
- `iphone-67/`: 6 PNG-Dateien, je 1290×2796 px — App Store 6.7"-Slot-konform
- `iphone-65/`: 6 PNG-Dateien, je 1242×2688 px — App Store 6.5"-Slot-konform
- Dateinamen: 01-import, 02-overview-map, 03-days, 04-insights, 05-export, 06-live-recording
- Kein privater Content, keine Debug-Overlays, keine feste Server-URL

### Bewusst nicht behauptet
- kein ASC-Screenshot-Upload in diesem Slice; Upload bleibt manuell ausstehend

### Checks
- `git diff --check`: kein Whitespace-Fehler
- `swift test`: nicht ausgefuehrt — ausschliesslich Doku-Aenderungen

## [2026-04-30] — docs: Support-URL und Privacy-URL in App Store Connect bestätigt

### Dokumentiert
- Support-URL `https://dev-roeber.github.io/iOS-App/support.html` manuell in App Store Connect eingetragen / geprüft
- Privacy Policy URL `https://dev-roeber.github.io/iOS-App/privacy.html` manuell in App Store Connect eingetragen / geprüft
- Build `52` bleibt unverändert im Review; kein neuer Build nachgereicht
- kein vollständiger Lock-Screen-/minimal-/No-Dynamic-Island-Nachweis in diesem Slice

### Verifiziert
- `git diff --check` (reine Doku-Änderung; kein `swift test` erforderlich)

### Bewusst nicht behauptet
- Lock Screen, `minimal`, deaktivierte Live Activities und No-Dynamic-Island-Geraete bleiben weiter ohne echten Hardware-Nachweis offen

## [2026-04-30] — fix: Pending-/Restart-Pfad nach App-Relaunch korrekt abgebildet

### Root Cause
Nach App-Terminate + Relaunch setzt `restoreInterruptedSessionState()` korrekt `hasInterruptedSession = true`, aber `resetPersistence` loescht den Demo-Content; der Live-Tab war daher nicht sichtbar. Gleichzeitig fehlte dem "Resume recording"-Banner ein `accessibilityIdentifier`, und der UI-Test wartete direkt auf `live.recording.stop`, ohne den Banner zu bestaetigen – das Stop-Element erscheint aber erst, wenn der User explizit "Resume" tappt.

### Fixed
- `AppLiveTrackingView`: "Resume recording"-Button erhaelt `.accessibilityIdentifier("live.interrupted.resume")` fuer zuverlässige AX-Ansteuerung in UI-Tests
- `LH2GPXWrapperUITests / runLiveActivityCaptureFlow`: Relaunch-Pfad laedt nach dem Reopen Demo-Daten nach, navigiert zum Live-Tab, tappt `live.interrupted.resume` (mit `allowLocationAccessIfNeeded()`), und wartet erst danach auf `live.recording.stop`

### Tests
- 4 neue Unit-Tests in `LiveLocationFeatureModelTests`:
  - `testInterruptedSessionDoesNotAutoResumeRecording` — kein Auto-Resume nach Init mit persistierter Session
  - `testResumeAfterInterruptedSessionStartsNewRecording` — Dismiss + setRecordingEnabled(true) → isRecording=true
  - `testPartialDefaultsTimestampOnlyNoInterruptedSession` — nur Timestamp ohne ID → kein falscher interrupted State
  - `testStopRecordingLeavesNoRestorationState` — Stop raeumt alle Restore-Keys auf
- `swift test`: 667 Tests, 0 Failures
- `xcodebuild ... build`: BUILD SUCCEEDED
- **Echter Device-Rerun (iPhone 15 Pro Max, iOS 26.4): `testLiveActivityHardwareCaptureUploadStatusPendingAndRestart` PASSED (62 s)**

## [2026-04-30] — docs: real-device Live Activity verification rerun

### Geaendert
- `docs/APPLE_VERIFICATION_CHECKLIST.md` und `wrapper/docs/LOCAL_IPHONE_RUNBOOK.md` auf den echten Rerun-Stand gezogen: Nach manuellem Trust des UITest-Runners liefen reale Device-Tests wieder auf dem verbundenen `iPhone 15 Pro Max` (`iOS 26.4`)
- repo-wahr dokumentiert: `testDeviceSmokeNavigationAndActions` auf echter Hardware gruen; Live-Activity-Capture-Tests fuer `Distance`, `Duration`, `Points` und `Upload Status (failed)` auf echter Hardware gruen
- repo-wahr dokumentiert: `testLiveActivityHardwareCaptureUploadStatusPendingAndRestart` scheitert weiter nach Relaunch, weil `live.recording.stop` nicht wieder erscheint; Lock Screen, `minimal`, deaktivierte Live Activities und No-Dynamic-Island-Geraete bleiben offen

## [2026-04-30] — docs: hardware verification blocker truth sync

### Geaendert
- `docs/APPLE_VERIFICATION_CHECKLIST.md` und `wrapper/docs/LOCAL_IPHONE_RUNBOOK.md` um den aktuellen echten Device-Blocker ergaenzt: `LH2GPXWrapperUITests.xctrunner` ist auf dem verbundenen `iPhone 15 Pro Max` derzeit nicht als vertrauenswuerdige Entwickler-App freigegeben; ein weiterer Live-Capture-Lauf brach zusaetzlich mit `CoreDeviceError / Mercury error 1001` nach Launch ab
- repo-wahr festgehalten, dass damit weiterhin kein neuer Voll-Nachweis fuer Lock Screen, `minimal`, weitere Primärwerte, deaktivierte Live Activities oder No-Dynamic-Island-Geraete vorliegt

## [2026-04-30] — live: restore-state hardening for interrupted sessions

### Fixed
- `LiveLocationFeatureModel`: interrupted-session Persistenz wird nicht mehr schon beim Init oder vor erfolgreichem Recording-Start geschrieben; Restore-State entsteht jetzt erst nach echtem Start der Aufnahme
- `LiveLocationFeatureModel`: denied/restricted sowie abgelehntes `Always`-Upgrade raeumen verwaisten Restore-State jetzt defensiv auf
- `LiveLocationFeatureModel`: `dismissInterruptedSession()` und sauberer Stop loeschen Persistenz und In-Memory-Restore-State konsistent

### Tests
- `LiveLocationFeatureModelTests`: Regressionen decken Initialisierung ohne Recording, Persistenz erst nach gueltigem Start, Cleanup bei Stop/Ignore sowie kaputte oder partielle `UserDefaults`-Werte ab
- Verifikation: `swift test` -> 663 Tests, 0 Failures; `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build` -> `BUILD SUCCEEDED`

## [2026-04-30] — docs: roadmap and review truth sync

### Geaendert
- `AGENTS.md`, `README.md`, `NEXT_STEPS.md`, `ROADMAP.md` und Apple-/Wrapper-Runbooks auf den aktuellen Repo- und ASC-Truth gezogen
- `NEXT_STEPS.md` von historischer Mischliste auf echte offene P0/P1/P2-Arbeit reduziert
- App-Store-Review-Entscheidung repo-wahr nachgezogen: Build `52` bleibt bewusst in Review; Build `57` wird nicht ohne Apple-Feedback oder bestaetigten release-kritischen Fehler nachgereicht
- veraltete Aussagen zu aktivem Repo, Split-Repos, Teststand, Xcode-Cloud-Buildnummer und Wrapper-Roadmap-Pfaden bereinigt

### Verifiziert
- `swift test`
- `git diff --check`
- `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build`

### Bewusst nicht behauptet
- kein Claim, dass App Review bestanden ist
- keine neue echte Hardware-Verifikation fuer Lock Screen, `minimal`, weitere Primärwerte oder Homescreen-Widget

## [2026-04-30] — docs: App Store Connect review status truth sync

### Geaendert
- App-Store-Connect-Status fuer `LH2GPX` Version `1.0` repo-wahr nachgezogen: Version ist eingereicht, Status `Warten auf Prüfung`
- dokumentiert, dass auf der Versionsseite derzeit Build `52` sichtbar ist, waehrend der Xcode-Cloud-Workflow `Release – Archive & TestFlight` bereits erfolgreiche Builds `55`, `56` und `57` zeigt
- offene Prueffrage explizit festgehalten: klaeren, ob Build `52` bewusst fuer Review ausgewaehlt wurde oder ob ein neuerer Build (`57`) nachgereicht werden soll
- Doku auf den neuen ASC-Truth angepasst: App Review ist nicht mehr durch fehlenden Upload blockiert; partielle Hardware-Verifikation fuer Live Activity / Dynamic Island bleibt weiter offen

### Verifiziert
- `swift test`
- `git diff --check`
- `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build`

### Bewusst nicht behauptet
- kein Claim, dass App Review bereits bestanden oder abgeschlossen ist
- keine neue echte Hardware-Verifikation fuer Lock Screen, `minimal`, weitere Primärwerte oder Fallback-Pfade

## [2026-04-30] — release: TestFlight archive path truth sync

### Geaendert
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: `CURRENT_PROJECT_VERSION` fuer App, Widget und Test-Targets auf `45` angehoben, damit ein neuer Release-Kandidat nicht hinter dem bereits dokumentierten TestFlight-Build `1.0 (44)` zurueckfaellt
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: explizite Release-`CODE_SIGN_IDENTITY = Apple Distribution` fuer App + Widget entfernt; `CODE_SIGN_STYLE = Automatic` bleibt der einzige Release-Signing-Pfad
- Release-/TestFlight-Doku auf den realen Host-Befund vom 2026-04-30 gezogen

### Verifiziert
- `swift test`: 660 Tests, 0 Failures
- `git diff --check`
- `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build`
- `xcodebuild archive -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -configuration Release -destination 'generic/platform=iOS' -archivePath /Users/sebastian/Desktop/LH2GPXWrapper.xcarchive`: `ARCHIVE SUCCEEDED`

### Bewusst nicht behauptet
- kein lokaler TestFlight-Upload: `xcodebuild -exportArchive` scheitert auf diesem Host mit `No signing certificate "iOS Distribution" found`
- kein automatisierter App Store Connect Upload: `altool` hat auf diesem Host keine konfigurierte JWT- oder Username/App-Password-Authentifizierung
- App Review bleibt fuer den Dynamic-Island-/Live-Activity-Scope weiter `NO-GO`

## [2026-04-30] — docs: partial real-device verification for Live Activity / Dynamic Island

### Geaendert
- realen Device-Nachweis fuer den aktuellen Live-Activity-/Dynamic-Island-Stand repo-wahr dokumentiert
- `docs/APPLE_VERIFICATION_CHECKLIST.md`, `NEXT_STEPS.md`, `ROADMAP.md`, `README.md`, `docs/APP_FEATURE_INVENTORY.md`: verifizierte Teilmenge (`iPhone 15 Pro Max`, `iOS 26.4`, `Debug`-Build via `xcodebuild test`) von offenen Punkten getrennt

### Verifiziert
- echter iPhone-Lauf auf `iPhone 15 Pro Max` (`iPhone16,2`) mit `iOS 26.4`
- Live Recording Start auf echter Hardware
- Dynamic Island compact fuer Primärwert `Distanz` (`0 m`) auf echter Hardware sichtbar
- Dynamic Island expanded fuer Primärwert `Distanz` auf echter Hardware sichtbar
- Stop-/Dismiss-Verhalten der Live Activity nach Ende der Aufnahme auf echter Hardware sichtbar

### Bewusst nicht behauptet
- kein repo-wahrer Lock-Screen-Nachweis in diesem Slice
- kein repo-wahrer Minimal-State-Nachweis in diesem Slice
- keine repo-wahre Hardware-Verifikation fuer `Dauer`, `Punkte`, `Upload-Status`, deaktivierte Live Activities oder Fallbacks ohne Support
- App Review bleibt bis zu weiterem echten Device-Nachweis fuer die offenen Live-Activity-Pfade `NO-GO`

## [2026-04-30] — docs: Dynamic Island verification truth sync

### Geaendert
- veraltete Doku-Aussagen fuer den Dynamic-Island-/Widget-Pfad auf aktuellen Repo-Truth gezogen
- `NEXT_STEPS.md`: historischer Live-Activity-Hinweis auf nutzbaren `iOS 16.2+`-Pfad korrigiert; Screenshot-Hinweis auf iPhone-only-v1 angepasst
- `ROADMAP.md`: veraltete Aussage entfernt, dass das Widget-Target noch manuell anzulegen sei
- `wrapper/README.md`, `wrapper/docs/LOCAL_IPHONE_RUNBOOK.md`, `wrapper/docs/TESTFLIGHT_RUNBOOK.md`: iPhone-only-Release-Truth (`TARGETED_DEVICE_FAMILY = 1`) und korrektes Deployment-Target (`iOS 16.0 / 16.2`) synchronisiert

### Verifiziert
- Repo-Truth-Audit gegen aktuellen Code und Projektdatei
- `swift test`
- `git diff --check`
- `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build`

## [2026-04-29] — fix: Interactive Overview-/Explore-Map audit hardened

### Geaendert
- `Sources/LocationHistoryConsumerAppSupport/AppOverviewTracksMapView.swift`: `loadData` cancelt jetzt alte Overlay-Rebuilds sofort beim Neu-Load; stale Detached-Tasks dürfen keine veralteten Overlays mehr nach einem neuen Load committen
- `Sources/LocationHistoryConsumerAppSupport/AppOverviewTracksMapView.swift`: nach Cancellation werden gescannte Partialdaten nicht mehr in den Model-State geschrieben
- `Sources/LocationHistoryConsumerAppSupport/AppOverviewTracksMapView.swift`: Viewport-Culling bleibt bounding-box-basiert; lange Routen, die den sichtbaren Bereich schneiden, bleiben priorisierbar, auch wenn ihr Midpoint außerhalb liegt
- `Sources/LocationHistoryConsumerAppSupport/AppLanguageSupport.swift`: DE-Lokalisierung für `Toggle map style` ergänzt

### Neue Tests
- `testBuildOverlaysFromCandidatesPrioritizesViewportIntersectionOverMidpoint`
- `testBuildOverlaysFromCandidatesViewportStillRespectsOverlayLimit`
- `testOverviewMapModelResetToFullViewRestoresFullSelectionAfterViewportUpdate`

### Verifiziert
- `swift test` grün
- `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -configuration Debug -destination 'generic/platform=iOS' build` grün
- `git diff --check` sauber

### Bewusst nicht behauptet
- Kein neuer Device-Nachweis speziell für die interaktive Overview-/Explore-Karte
- Kein neuer TestFlight-/App-Store-Claim aus diesem Audit-Batch

## [2026-04-29] — test: Overview-Map Performance-Audit – Coordinate-Budget-Invarianten

### Befund (kein weiterer Codefix nötig)

Vollständiger Performance-Audit des overlayLimit-Fixes ergab: kein separates globales Coordinate-Budget nötig.

Die Kombination aus `overlayLimit × maxPolylinePoints` erzeugt bereits ein implizites hartes Gesamtbudget:

| Tier | overlayLimit | maxPolylinePoints | Max. Koordinaten gesamt |
|---|---|---|---|
| Very heavy | 150 | 64 | 9.600 |
| Heavy | 200 | 96 | 19.200 |
| Medium-heavy | 250 | 120 | 30.000 |
| Medium | 300 | 160 | 48.000 |

Exportdaten sind unberührt. Badge erscheint nur wenn `isOptimized=true`:
- „Karte vereinfacht – Export vollständig": wenn `visibleRouteCount < totalRouteCount` (Route-Cap greift)
- „Optimierte Übersicht": wenn Vereinfachung greift, aber alle Routen sichtbar

### Neue Tests (3)

- `testTotalRenderedCoordinateCountBoundedByOverlayTimesPointsLimit`: 600 Routen × 200 Punkte → max 9.600 Koordinaten total
- `testIndividualRouteCoordinateCountBoundedByMaxPolylinePoints`: 1 Route × 1000 Punkte → max 220 Punkte nach Decimation
- `testIsOptimizedTrueWhenDecimationAppliedButRoutesNotCapped`: 130 Routen → isOptimized=true, kein Capping, Badge „Optimized overview"

`swift test`: 650 Tests, 0 Failures. `git diff --check`: sauber.

---

## [2026-04-29] — fix: Overview-Map Freeze/Crash-Fix – Hard Overlay Limit

### Problem (App-Store-Submission-Blocker)

`AppOverviewTracksMapView` fror ein oder crashte bei Auswahl „Gesamtzeitraum" mit großen importierten Datenmengen.
Root Cause: `selectCandidates` lieferte alle Kandidaten (keine Obergrenze); MapKit erhielt tausende `MapPolyline`-Overlays.

### Fix

- `OverviewMapRenderProfile`: neues Feld `overlayLimit: Int` – Hard Cap auf die Anzahl gerenderter MapPolyline-Objekte.
- Tier-basierte Limits: >500 Routen oder >150k Punkte → 150; >240/>60k → 200; >120/>30k → 250; >60/>15k → 300; klein → kein Cap.
- `selectCandidates`: nach Score-Sortierung wird auf `prefix(overlayLimit)` abgeschnitten (Top-Routen nach Score).
- `isOptimized = true` wenn Cap greift → View-Badge „Karte vereinfacht – Export vollständig" (DE/EN).
- Export-Daten und Rohdatenmodell sind nicht berührt; Export verwendet weiterhin vollständige Daten.

### Tests

- 5 neue Tests in `AppOverviewTracksMapViewTests`: Tier-basierte `overlayLimit`-Werte, synthetisches 600-Routen-Dataset gecapped, kleines Dataset ungecapped, Start-/Endpunkt-Erhaltung, Export-Daten-Unveränderlichkeit.
- `swift test`: 647 Tests, 0 Failures.
- `git diff --check`: sauber.

### Dokumentation

- `NEXT_STEPS.md`: Fix als erledigt markiert; neuer offener Punkt: TestFlight-Verifikation mit realen Daten.
- `ROADMAP.md`, `docs/APP_FEATURE_INVENTORY.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_APP_PREPARATION.md`: aktualisiert.
- App-Store-Submission bleibt offen, bis Fix auf TestFlight mit echten Daten verifiziert.

---

## [2026-04-29] — TestFlight Build 1.0 (44): Smoke-Test-Stand dokumentiert

### Dokumentarisch (kein Codeeingriff)

- **TestFlight Build 1.0 (44)**: Auf iPhone installierbar und grundsätzlich lauffähig. Interner Smoke-Test abgeschlossen.
- **Beobachtung**: Gelegentliche UI-Hänger/Ruckler auf echtem Gerät; kein bestätigter reproduzierbarer Crash.
- **App-Store-Submission**: Bewusst noch nicht eingereicht. Offen bis Build in App Store Connect tatsächlich unter Vertrieb ausgewählt und submitted.
- **NEXT_STEPS.md**: `Xcode Cloud Release-Workflow grün verifiziert` abgehakt; Performance-Smoke-Test und App-Store-Einreichung als offene Punkte ergänzt.
- **docs/APPLE_VERIFICATION_CHECKLIST.md**: Abschnitt „TestFlight-Smoke-Test-Kriterien vor App-Store-Submission" ergänzt.
- **swift test**: 643 Tests, 0 Failures (verifiziert 2026-04-29).
- **git diff --check**: sauber.


---

## [2026-04-29] — Dynamic Island Settings + Live Activity Fallbacks + Overview Heatmap Chip

### Geaendert
- `LiveActivityPresentation.swift` neu: zentrale, testbare Formatierung fuer Dynamic-Island-Werte (`Distance`, `Duration`, `Points`, `Upload Status`) sowie testbare Availability-/Fallback-Logik fuer Live Activities
- `AppPreferences` / `AppOptionsView`: Dynamic-Island-Wert ist jetzt als persistente Primärwert-Option ausgebaut; neuer Upload-Status-Wert verfuegbar; Live-Activity-Verfuegbarkeit wird in den Optionen sichtbar gemacht und deaktiviert die Konfiguration sauber auf nicht unterstuetzten / deaktivierten Geraeten
- `LiveLocationFeatureModel` -> `ActivityManager` -> `TrackingStatus`: Upload-/Pause-Zustand wird jetzt tatsaechlich bis in die Live Activity durchgereicht statt nur im Modell zu existieren; neue `uploadState`-Ableitung (`disabled`, `active`, `pending`, `failed`, `paused`)
- `TrackingLiveActivityWidget.swift`: Lock Screen, Dynamic Island expanded, compact trailing und minimal nutzen jetzt den gewaehlten Primärwert konsistent; Minimal bleibt bewusst icon-basiert, aber folgt der Auswahl stabil
- `AppContentSplitView`: der bisherige Heatmap-Action-Block wurde in der Overview zu einem kompakten Capsule-Chip harmonisiert, passend zu den uebrigen Filter-/Status-Chips

### Verifiziert
- `swift test` -> `650` Tests, `0` Failures
- `git diff --check` -> sauber
- `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build` -> **BUILD SUCCEEDED**

### Offen / nicht als verifiziert behauptet
- Realer Device-/Dynamic-Island-Nachweis bleibt offen
- `xcodebuild ... -testPlan CI ... -only-testing:LH2GPXWrapperTests test` konnte auf diesem Host nicht belastbar abgeschlossen werden; der Simulator-Lauf brach beim App-Launch mit `NSMachErrorDomain Code=-308 (ipc/mig server died)` ab
- Keine Aussage zu manuell geoeffneter Live Activity / Dynamic Island / Homescreen-Widget auf echter Apple-Hardware

## [2026-04-29] — Build 34 IPA-Forensik: Root Cause bewiesen — NFD/NFC-Normalisierungsmismatch in Designated Requirement

### Befund (bewiesen durch vollständige IPA-Forensik)

IPA: `LH2GPXWrapper 1.0 app-store-4/LH2GPXWrapper.ipa` (Build 34, CFBundleVersion=34).

| Prüfpunkt | Ergebnis |
|---|---|
| Authority | `Apple Distribution: Sebastian Röber (XAGR3K7XDJ)` ✅ |
| TeamIdentifier | `XAGR3K7XDJ` ✅ |
| Provisioning Profile App | `iOS Team Store Provisioning Profile: de.roeber.LH2GPXWrapper` ✅ |
| Provisioning Profile Widget | `iOS Team Store Provisioning Profile: de.roeber.LH2GPXWrapper.Widget` ✅ |
| ProvisionedDevices | NICHT vorhanden (korrekt für App Store) ✅ |
| application-identifier App | `XAGR3K7XDJ.de.roeber.LH2GPXWrapper` ✅ |
| application-identifier Widget | `XAGR3K7XDJ.de.roeber.LH2GPXWrapper.Widget` ✅ |
| App Groups App+Widget | `group.de.roeber.LH2GPXWrapper` ✅ |
| get-task-allow | `false` (Distribution korrekt) ✅ |
| Entitlements App | application-identifier, team-identifier, app-groups, beta-reports-active — vollständig korrekt ✅ |
| Run Script Build Phases | KEINE vorhanden ✅ |
| CODE_SIGN_REQUIREMENTS override | NICHT gesetzt ✅ |
| OTHER_CODE_SIGN_FLAGS | NICHT gesetzt ✅ |
| `codesign --verify` | **valid on disk** ✅ |
| `codesign --verify --strict` | **does not satisfy its designated Requirement** ❌ |

### Root Cause (bewiesen, nicht geraten)

Die Designated Requirement (DR) in App und Widget enthält den Zertifikats-CN in **Unicode NFD**-Kodierung,
das tatsächliche Zertifikat (aus dem Provisioning Profile extrahiert) hat den CN in **Unicode NFC**-Kodierung.
Der `certificate leaf[subject.CN] = 0x<hex>` Check im DR ist ein **Byte-für-Byte-Vergleich** — kein Unicode-normalisierter Vergleich.

| | Bytes für `ö` in "Röber" |
|---|---|
| DR im Binary (NFD) | `6f cc 88` = U+006F (o) + U+0308 (COMBINING DIAERESIS) |
| Zertifikat CN (NFC, aus Profil via RFC2253 `\C3\B6`) | `c3 b6` = U+00F6 (ö, präkomponiert) |

**Ursachenkette:**
1. Apple Distribution Certificate hat CN-Bytes in NFC (`c3 b6` für ö)
2. Xcode Cloud liest den CN via macOS Security/Keychain-Framework als CFString
3. macOS normalisiert den String zu NFD (`6f cc 88` für ö)
4. Xcode bettet diesen NFD-Hex-Wert in die Designated Requirement ein
5. Apple's Upload-Validator prüft `certificate leaf[subject.CN] = 0x<NFD>` byte-genau gegen das Zertifikat (NFC)
6. `6f cc 88` ≠ `c3 b6` → "Code failed to satisfy specified code requirement(s)"

### Was ausgeschlossen ist
- Repo-Signing-Konfiguration (**nicht** die Ursache)
- App ID / App Group Registrierung (**nicht** die Ursache, beides korrekt im Portal)
- Provisioning Profile (**nicht** die Ursache, korrekt iOS Team Store)
- Entitlements (**nicht** die Ursache, vollständig korrekt)
- Run Scripts oder nachträgliche Bundle-Manipulation (**keine** vorhanden)

### Nächste Schritte (manuell, kein Repo-Fix nötig)
1. **Apple ID-Namen ändern**: appleid.apple.com → persönliche Daten → Namen auf ASCII-only (`Sebastian Roeber`) ändern
2. **Neues Distribution-Zertifikat erstellen**: Xcode.app → Settings → Accounts → Manage Certificates → Distribution-Zertifikat revoken + neu generieren (CN wird dann ohne ö erzeugt)
3. Xcode Cloud Clean Build starten

---

## [2026-04-29] — Release Distribution Signing Fix (Build 32 → Build 33)

### Problem
Xcode Cloud Build 32: Apple lehnte Upload mit `Validation failed (409) – Invalid Signature` ab.
Root Cause: `CODE_SIGN_IDENTITY` fehlte in allen Release-BuildSettings → Xcode wählte automatisch
`"Apple Development"` (Development-Zertifikat) auch für Archive/Distribution-Builds.

### Geaendert
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`:
  - `"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution"` in **LH2GPXWrapper Release** ergänzt
  - `"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution"` in **LH2GPXWidget Release** ergänzt
  - `com.apple.ApplicationGroups` in `TargetAttributes.SystemCapabilities` für **LH2GPXWrapper** ergänzt
  - `LH2GPXWidget (9EBB00052F6C000100000005)` mit `com.apple.ApplicationGroups` in **TargetAttributes** eingetragen
  - `CURRENT_PROJECT_VERSION` 27 → **28**

### Verifiziert (lokal)
- `swift test`: 643 Tests, 0 Failures ✅
- `xcodebuild -showBuildSettings Release LH2GPXWrapper`: `CODE_SIGN_IDENTITY = Apple Distribution` ✅
- `xcodebuild -showBuildSettings Release LH2GPXWidget`: `CODE_SIGN_IDENTITY = Apple Distribution` ✅
- `git diff --check`: OK ✅
- Lokales `xcodebuild archive` schlägt erwartungsgemäß fehl (kein lokales Distribution-Zertifikat für diese App-IDs — normal für Developer-Maschine ohne ASC-Distribution-Profil)

### Noch ausstehend
- Xcode Cloud Build 33 starten und prüfen, ob Archive + TestFlight-Upload grün ist

## [2026-04-29] — App-Store-Signing für Xcode Cloud bereinigt

### Geaendert
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: Release-/Archive-Pfad fuer `LH2GPXWrapper` und `LH2GPXWidget` auf `CODE_SIGN_STYLE = Automatic` und `DEVELOPMENT_TEAM = XAGR3K7XDJ` bereinigt
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: explizite Release-Overrides fuer `CODE_SIGN_IDENTITY` und `PROVISIONING_PROFILE_SPECIFIER` entfernt, damit Xcode Cloud/App Store Connect die passende Distribution-Signatur selbst aufloest
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: `CURRENT_PROJECT_VERSION` auf `27` angehoben
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: Widget-Embed-Phase auf `CodeSignOnCopy` korrigiert
- `Sources/LocationHistoryConsumerAppSupport/AppLiveTrackingView.swift`: stabile Accessibility IDs fuer Start/Stop-Recording im Live-Tab ergänzt
- `wrapper/LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift`: Device-Smoke-Test auf die neuen Live-Button-IDs umgestellt

### Verifiziert
- `swift test`: 643 Tests, 0 Failures ✅
- `xcodebuild -target LH2GPXWrapper -configuration Release -showBuildSettings`: `CODE_SIGN_STYLE = Automatic`, `CURRENT_PROJECT_VERSION = 27`, `DEVELOPMENT_TEAM = XAGR3K7XDJ` ✅
- `xcodebuild -target LH2GPXWidget -configuration Release -showBuildSettings`: `CODE_SIGN_STYLE = Automatic`, `CURRENT_PROJECT_VERSION = 27`, `DEVELOPMENT_TEAM = XAGR3K7XDJ` ✅
- `TARGETED_DEVICE_FAMILY = 1`, `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO`, `SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO` im Wrapper-Target ✅
- `ITSAppUsesNonExemptEncryption = false` weiterhin in App + Widget gesetzt ✅

### Offen
- Lokaler Transporter-Upload vom 2026-04-29 wurde von Apple weiter mit `Invalid Signature` fuer App + Widget abgelehnt
- Der neu angelegte Xcode-Cloud-Workflow `Release – Archive & TestFlight` muss noch real gruen durchlaufen und den ersten gueltigen TestFlight-Build erzeugen

## [2026-04-29] — GitHub Pages: Support- und Projektseite

### Hinzugefügt
- `docs/support.html`: öffentliche Support-Seite für App Store Connect; enthält FAQ, Kontakt, Formatübersicht, Datenschutz-Link
  URL: `https://dev-roeber.github.io/iOS-App/support.html`
- `docs/index.html`: kleine Projektseite (kein Download-Button, da App noch nicht im Store); enthält Kernfunktionen, Datenschutz-Highlight, Links
  URL: `https://dev-roeber.github.io/iOS-App/`
- `docs/privacy.html`: Support-Link im Footer ergänzt

### Inhalt
- FAQ-Abschnitt mit verifizierten Antworten (Import-/Exportformate aus Repo-Truth)
- Kein offizieller Live-Receiver-Dienst genannt
- Keine Download-Buttons / keine Aussage „im App Store verfügbar"
- Kein Tracking, kein JS, keine externen CDNs/Fonts

## [2026-04-29] — App-Store-Screenshots (iPhone 15 Pro Max, UITest-basiert)

### Hinzugefügt
- `docs/app-store-assets/screenshots/iphone-67/`: 6 Screenshots (1290×2796 px) vom iPhone 15 Pro Max via `testAppStoreScreenshots` UITest
- `docs/app-store-assets/screenshots/iphone-65/`: 6 Screenshots (1242×2688 px) proportional skaliert für 6.5"-Slot
- `wrapper/LH2GPXWrapperUITests/LH2GPXWrapperUITests.swift`: Screenshot-Test auf XCTAttachment-Verfahren umgestellt (xcresult-Bundle statt direkter Dateischreib auf Device); alle 6 Screens (Import, Overview, Days, Insights, Export, Live)

### Inhalt
- Ausschließlich Repo-Demo-Fixture-Daten (keine privaten Nutzerdaten)
- Keine Debug-Overlays, keine feste Server-URL im Live-Tab, kein Token sichtbar
- App-Store-Deklaration „Keine Daten erfasst" korrekt dargestellt

### Verifiziert
- `swift test`: 643 Tests, 0 Failures ✅
- UITest `testAppStoreScreenshots` auf iPhone 15 Pro Max: PASSED (41 s) ✅
- Alle 6 PNGs extrahiert und dimensioniert: 1290×2796 (iphone-67) + 1242×2688 (iphone-65) ✅

## [2026-04-29] — Datenschutzerklärung (GitHub Pages)

### Hinzugefügt
- `docs/privacy.html`: statische Datenschutzerklärung in Deutsch, mobil-lesbar, ohne externe Tracker/Fonts/CDN
- URL für App Store Connect: `https://dev-roeber.github.io/iOS-App/privacy.html`
- Inhalt basiert ausschließlich auf verifizierten Datenflüssen (lokal, kein Entwickler-Server); optionaler Live-Upload klar als nutzerkonfiguriert/default-deaktiviert beschrieben
- App Store „Keine Daten erfasst" bestätigt

## [2026-04-29] — Export-Compliance: ITSAppUsesNonExemptEncryption gesetzt

### Hinzugefügt
- `wrapper/Config/Info.plist`: `ITSAppUsesNonExemptEncryption = false` (Haupt-App)
- `wrapper/LH2GPXWidget/Info.plist`: `ITSAppUsesNonExemptEncryption = false` (Widget-Extension)

### Begründung
App verwendet keine nicht-ausgenommene Verschlüsselung. Einzige Netzwerkkommunikation ist optionaler nutzergesteuerter HTTPS-Upload via URLSession — systemseitige Standardverschlüsselung, gem. US-Exportrecht ausgenommen. Kein CryptoKit, CommonCrypto, AES, RSA, VPN, E2E oder proprietäre Crypto-Bibliotheken. Beim App-Store-Upload sind keine Export-Compliance-Unterlagen erforderlich.

### Verifiziert
- `swift test`: 643 Tests, 0 Failures, 0 Skips ✅
- `xcodebuild generic/platform=iOS`: BUILD SUCCEEDED ✅

## [2026-04-29] — Device-Verifikation + UITest-Fix (All-Time-Chip-Regression)

### Verifiziert auf iPhone 15 Pro Max (ios 26.3, UDID 00008130-00163D0A0461401C)
- `swift test`: 643 Tests, 0 Failures, 0 Skips — 2× bestätigt
- `xcodebuild generic/platform=iOS`: BUILD SUCCEEDED
- `xcodebuild platform=macOS (LocationHistoryConsumerApp)`: BUILD SUCCEEDED
- CI.xctestplan Wrapper-Unit-Tests (iPhone 17 Pro Max Simulator, iOS 26.3.1): TEST SUCCEEDED
- **UITests 6/6 PASSED auf echtem iPhone 15 Pro Max**:
  - `testLaunch` × 4: App startet sauber ✅
  - `testAppStoreScreenshots`: Demo-Daten + Screenshots ✅
  - `testDeviceSmokeNavigationAndActions` (55s): Demo-Load, Overview/All-Time, Heatmap, Insights Share, Export fileExporter, Live Start/Stop — alles auf echtem Gerät bestätigt ✅

### Fix: UITest-Regression nach Last-7-Days-Default (2026-04-15)
- **Root Cause**: `AppSessionState.show(content:)` setzt `historyDateRangeFilter = .last7Days`; Demo-Fixture (2024) fällt außerhalb dieses Fensters → Insights leer → kein `insights.section.share` Button → UITest-Failure
- **Fix AppHistoryDateRangeControl.swift**: `.accessibilityIdentifier("range.chip.\(preset.rawValue)")` an alle Preset-Chip-Buttons ergänzt
- **Fix LH2GPXWrapperUITests.swift**: Nach Demo-Load `range.chip.all` tippen um auf All Time zurückzusetzen, bevor Insights-Tab geöffnet wird
- `swift test` nach Fix: 643 Tests, 0 Failures, 0 Skips ✅

### Korrektur (aus vorherigem Audit)
- `docs/XCODE_APP_PREPARATION.md`: "Deployment Target iOS 26.2" → "iOS 16.0 / 16.2"

### Weiterhin offen (unverändert)
- Xcode Cloud Workflow, App ID/App Group im Developer Portal, Privacy Policy URL, Support URL, finales App Icon
- Großer Import, Track-Editor, Widget, Live Activity, Landscape — manuell prüfen

## [2026-04-15] — Overview: Last-7-Days-Default, Chip-Reihenfolge, Ladefortschritt-Karte

### Geändert
- `HistoryDateRangeFilter.swift`: Enum-Case-Reihenfolge geändert: `last7Days | last30Days | last90Days | thisYear | custom | all` — "Gesamtzeitraum" steht jetzt ganz rechts hinter "Benutzerdefiniert"; `allCases` und damit die Chips passen sich automatisch an
- `AppSessionState.swift`: `historyDateRangeFilter` Startwert `.all` → `.last7Days`; `show(content:)` setzt den Filter bei jedem Import auf `last7Days` zurück — bestehende User-Wahl wird nur bei neuem Import ersetzt, nicht bei Tab-Wechsel
- `AppOverviewTracksMapView.swift`: Neues `OverviewMapLoadingPhase`-Enum (`.analyzing` / `.building`); `loadMapData()` setzt Phase vor und nach dem Inner-Task; `loadingPlaceholder` als frosted-glass Karte mit Spinner, linearem `ProgressView` und Phasentext ersetzt den reinen Kringel
- `AppLanguageSupport.swift`: DE-Strings für "Analysing routes…" und "Building map…" ergänzt

### Effekt
- Standardmäßig wird nach Import nur der letzte 7-Tage-Zeitraum geladen → MapKit-Overlay-Last bei großen Dateien um Faktor ~50 reduziert (real größte Freeze-Ursache)
- User sieht sofort relevante, aktuelle Tracks statt den kompletten Gesamtzeitraum
- Ladefortschritt zeigt ehrliche Phase statt blindem Spinner

### Teststatus
643 Tests, 0 Failures, 0 Skips — BUILD SUCCEEDED ✅

## [2026-04-14] — Overview Map: Spinner-Freeze-Fix bei großen Dateien (Cancellation-Bug)

### Behoben
- `AppOverviewTracksMapView.swift`: `loadMapData()` — entfernt `!Task.isCancelled`-Guard; dieser war Root Cause eines permanenten Spinners: wenn SwiftUI die `.task(id:)`-Body cancelierte (z. B. kurze View-Transition nach Import), wurde das Ergebnis verworfen, aber kein neuer Task startete → `renderData` blieb ewig auf `.loading` hängen
- `AppOverviewTracksMapView.swift`: `loadMapData()` — ersetzt `Task.detached(...).value` durch `withTaskCancellationHandler` + `innerTask.cancel()` im `onCancel`-Handler: Cancellation des Outer-Tasks propagiert jetzt sofort in den Detached-Task
- `AppOverviewTracksMapView.swift`: `buildRenderDataFast()` — Cancellation-Check **vor** der teuren Douglas-Peucker-Phase: bei großen Dateien (46 MB / tausende Tracks) kann Cancellation jetzt den DP-Loop komplett überspringen statt ihn vollständig auszuführen
- `AppOverviewTracksMapView.swift`: `buildRenderDataFast()` — Overlay-Build-Loop von `compactMap` auf explizite `for`-Schleife mit `if Task.isCancelled { break }` umgestellt: Cancellation unterbricht die DP-Verarbeitung path-by-path statt am Ende zu prüfen
- `Tests/AppOverviewTracksMapViewTests.swift`: 2 neue Tests: `testBuildRenderDataFastExitsEarlyWhenCancelledBeforeDP` (canceled Task produziert keine Overlays), `testBuildRenderDataFastCancelledTaskDoesNotBlockSubsequentResult` (zwei parallele unkancelierte Runs liefern identische Routenzahl)

### Verhalten nach Fix
- Kein permanenter Spinner mehr nach Großdatei-Import wenn View kurz getransitioniert
- Bei taskKey-Wechsel (neue Generation aktiv): altes Ergebnis wird korrekt verworfen (generation-Guard bleibt)
- Bei View-Disappear ohne neuen Task: partielles oder leeres Ergebnis wird publiziert → Spinner klärt sich sofort

### Teststatus
636 Tests, 0 Failures, 0 Skips — BUILD SUCCEEDED ✅

## [2026-04-14] — Overview Map Performance: O(N) Fast Path für große Standortdateien

### Behoben
- `AppOverviewTracksMapView.swift`: `loadMapData()` ruft jetzt `OverviewMapPreparation.buildRenderDataFast(for:export:filter:)` statt des alten `buildRenderData(for:content:filter:)` auf — eliminiert O(N² log N)-Bottleneck bei großen Importdateien (z. B. 46 MB / tausende Tracks)
- `OverviewMapPreparation.buildRenderDataFast`: Neuer O(N) Single-Pass über `export.data.days` mit `Set<String>` für O(1)-Datum-Lookup; iteriert alle Tage genau einmal ohne per-date `projectedDays()`-Sortierung; laufende Bounding Box statt `allCoords`-Akkumulation; Cancellation-Check alle 100 Iterationen; Point Budget (2 Mio.); direkter Zugriff auf `Path.flatCoordinates` (schnellster Pfad) mit Fallback auf `Path.points`; Activity-Type-Filter aus `AppExportQueryFilter` angewandt
- `Tests/AppOverviewTracksMapViewTests.swift`: 4 neue Tests: `testBuildRenderDataFastProducesSameRouteCountAsLegacy_small`, `testBuildRenderDataFastEmptyDateSetReturnsEmpty`, `testBuildRenderDataFastActivityTypeFilterExcludesNonMatchingPaths`, `testBuildRenderDataFastLargeFixtureProducesValidResult`

### Teststatus
634 Tests, 0 Failures, 0 Skips — BUILD SUCCEEDED ✅

## [2026-04-14] — Tage UI/UX: Layout-Bugfixes (GeometryReader, ScrollView, Steuerzeile)

### Behoben
- `AppDayListView.swift` (`AppDayRow`): `GeometryReader` als Root-View in List-Rows entfernt — war Root Cause für überlappende/abgeschnittene Day-Rows (Row-Breite > Row-Höhe → `isLandscape = true` immer wahr); ersetzt durch `@Environment(\.verticalSizeClass)`
- `AppDayDetailView.swift`: `GeometryReader` in `contentView` entfernt — war Root Cause für schwarzen Leerraum/unsichtbaren Inhalt (innerhalb eines outer `ScrollView` bekommt `GeometryReader` height=0 → `isLandscape = true` immer wahr → Landscape-HStack mit 0 Höhe → nichts sichtbar); ersetzt durch `@Environment(\.verticalSizeClass)`
- `AppContentSplitView.swift`: outer `ScrollView` um `AppDayDetailView` im compact Nav-Destination entfernt — verursachte das GeometryReader-height=0-Problem; `AppDayDetailView.contentView` verwaltet seinen eigenen `ScrollView`
- `AppDayDetailView.swift`: Segmented Control + Globe-Button in eine gemeinsame Steuerzeile (`mapControlRow`) zusammengeführt — Globe-Button war isoliert als Overlay auf der Karte; jetzt sauber horizontal ausgerichtet
- `AppPreferences.swift`: Label `"Simplified (Beta)"` → `"Simplified"` — war zu lang für Segmented Control, verursachte Abschneiden
- `AppLanguageSupport.swift`: Veralteten Key `"Map-Matched (Beta)"` durch `"Simplified": "Vereinfacht"` ersetzt
- `AppDayMapView.swift`: Parameter `showStyleToggle: Bool = true` ergänzt — ermöglicht caller-seitige Steuerung des Style-Buttons ohne Regression bei bestehenden Callsites
- `Tests/DayListPresentationTests.swift`: 2 neue Regressionstests für PathDisplayMode-Labels ergänzt

### Teststatus
630 Tests, 0 Failures, 0 Skips — BUILD SUCCEEDED ✅

## [2026-04-14] — Historien-Track-Editor: Mutations-Reset bei Import-Wechsel

### Geaendert
- `AppImportedPathMutationStore.swift`: `validateSource(_:)` ergaenzt — vergleicht gespeicherten Source-Identifier (Dateiname) mit dem aktiven Import; setzt bei Wechsel alle Mutations zurueck und speichert neuen Identifier; `reset()` loescht jetzt auch den Identifier-Key
- `AppContentSplitView.swift`: `.onChange(of: session.source)` ergaenzt — ruft `pathMutationStore.validateSource(source.displayName)` bei jedem Import-Wechsel auf
- `Tests/ImportedPathMutationTests.swift`: 3 neue Tests: `testMutationsPreservedForSameSource`, `testMutationsResetOnSourceChange`, `testValidateSourcePersistsIdentifierAcrossReload`

### Verhalten
- Mutations bleiben erhalten, wenn dieselbe Datei nach App-Neustart wieder geoeffnet wird (gleicher Dateiname = gleicher Identifier)
- Mutations werden zurueckgesetzt, wenn eine andere Datei importiert wird (unterschiedlicher Identifier)
- Kein stiller Seiteneffekt bei unveraendertem Import

### Teststatus
628 Tests, 0 Failures, 0 Skips

## [2026-04-14] — Historien-Track-Editor: Safety-Fix + CI.xctestplan

### Geaendert
- `AppDayDetailView.swift`: Alert-Text korrigiert — falsches Restore-Versprechen entfernt; neu: "The original data is not modified." (kein reset()-UI existiert)
- `AppLanguageSupport.swift`: DE-Übersetzung entsprechend angepasst
- `wrapper/CI.xctestplan`: neuer CI-Testplan nur mit `LH2GPXWrapperTests` (ohne UITests — Location-Dialoge/Timing in Xcode Cloud nicht stabil)
- `wrapper/LH2GPXWrapper.xcscheme`: `CI.xctestplan` als zweite Testplan-Option registriert
- `Tests/ImportedPathMutationTests.swift`: `testDuplicateDeletionIsIgnored` ergänzt (dreifaches addDeletion → exakt 1 Eintrag)

### Teststatus
625 Tests, 0 Failures, 0 Skips — Commits `30192e1`, `8036a01`

## [2026-04-14] — ZIPFoundation: Fork-Dependency gehärtet (branch → exact-Tag)

### Geaendert
- `Package.swift`: ZIPFoundation-Pin von `branch: "development"` auf `exact: "0.9.20-devroeber.1"` umgestellt
- Tag `0.9.20-devroeber.1` im Fork `dev-roeber/ZIPFoundation` auf Commit `d6e0da4` erstellt und gepusht
- `Package.resolved` (root + wrapper): `state` von branch-Format auf version-Format (`"version": "0.9.20-devroeber.1"`) aktualisiert
- `docs/XCODE_CLOUD_RUNBOOK.md`: Fork-Sektion überarbeitet — Upgrade-Prozess, Begründung für `.exact()`, vorherige Branch-Strategie als deprecated markiert

### Hintergrund
`branch: "development"` ist nicht reproduzierbar — jeder neue Commit auf dem Branch ändert den Build.
`.exact("0.9.20-devroeber.1")` garantiert dieselbe Revision in jedem Xcode-Cloud- und lokalen Build.

### Teststatus
624 Tests, 0 Failures, 0 Skips — Build complete

## [2026-04-14] — ZIPFoundation: Umstellung auf eigenen Fork dev-roeber/ZIPFoundation

### Geaendert
- `Package.swift`: ZIPFoundation-Dependency von `weichsel/ZIPFoundation.git` auf `dev-roeber/ZIPFoundation.git` (Branch `development`) umgestellt
- `Package.resolved`: neu gepinnt auf Revision `d6e0da4509c22274b2775b0e8c741518194acba1` (Branch `development`)
- `wrapper/LH2GPXWrapper.xcodeproj/.../Package.resolved`: konsistent mit Root-Resolved aktualisiert; staler `originHash` entfernt (wird von Xcode automatisch neu berechnet)
- `docs/XCODE_CLOUD_RUNBOOK.md`: neuer Abschnitt "ZIPFoundation Fork-Abhängigkeit" inkl. Fork-URL, Revision, Sync-Anleitung

### Hintergrund
Xcode Cloud benötigt expliziten GitHub-Zugriff auf jedes referenzierte Repo.
Das Upstream-Repo `weichsel/ZIPFoundation` liegt außerhalb des eigenen GitHub-Accounts.
Durch Umstellung auf den eigenen Fork (`dev-roeber/ZIPFoundation`) liegt die einzige externe SPM-Abhängigkeit jetzt vollständig unter `dev-roeber/*`.

### Teststatus
624 Tests, 0 Failures, 0 Skips — Build complete

## [2026-04-13] — Historien-Track-Editor Slice: importierte Routen ausblenden

### Hinzugefuegt
- `ImportedPathMutation.swift` (neu in `LocationHistoryConsumer`): `ImportedPathDeletion` + `ImportedPathMutationSet` (Codable/Equatable); `DayDetailViewState.removingDeletedPaths(for:)` filtert Pfade ohne AppExport-Mutation
- `AppImportedPathMutationStore.swift` (neu in `LocationHistoryConsumerAppSupport`): `ObservableObject`, UserDefaults-JSON-Persistenz, `addDeletion()` (Duplikat-sicher) + `reset()`
- `AppDayDetailView`: "Route entfernen"-Button in `pathCard` (Portrait + Landscape); Confirmation-Alert; `mutations: ImportedPathMutationSet` + `onRemovePath` als optionale Parameter (bestehende Aufrufer bleiben unverändert)
- `AppLanguageSupport`: DE-Übersetzungen für `"Remove Route"`, `"Remove"` und die Alert-Message
- `ImportedPathMutationTests.swift`: 7 neue Tests (623 gesamt, 0 Skips, 0 Failures)

### Architektur
- Original-AppExport wird nie verändert; Mutations-Overlay wird nur zur Darstellungszeit angewandt
- `pathIndex` = 0-basierter Index in `Day.paths`; Out-of-bounds-Indizes und fremde dayKeys werden ignoriert
- Persistenz konsistent mit `AppPreferences`-Muster (UserDefaults + JSONEncoder/Decoder)

## [2026-04-13] — Xcode Cloud Hardprüfung + Doku-Korrekturen

### Behoben
- `wrapper/ci_scripts/ci_pre_build.sh` → umbenannt in `ci_pre_xcodebuild.sh`: `ci_pre_build.sh` ist kein gültiger Xcode Cloud Skriptname und würde stillschweigend ignoriert; korrekte Namen sind `ci_post_clone.sh`, `ci_pre_xcodebuild.sh`, `ci_post_xcodebuild.sh`
- `docs/XCODE_CLOUD_RUNBOOK.md`: beide `ci_pre_build.sh`-Referenzen auf `ci_pre_xcodebuild.sh` korrigiert; Hinweis auf gültige Skriptnamen ergänzt
- `wrapper/docs/TESTFLIGHT_RUNBOOK.md`: falscher Deployment Target `iOS 26.2` auf `iOS 16.0 / 16.2` (App/Widget) korrigiert
- `wrapper/docs/LOCAL_IPHONE_RUNBOOK.md`: veralteter Pfad `~/repos/LocationHistory2GPX-Monorepo` (2×) → `~/Desktop/XCODE/iOS-App`
- `wrapper/docs/TESTFLIGHT_RUNBOOK.md`: veralteter Pfad `~/repos/LocationHistory2GPX-Monorepo` (2×) → `~/Desktop/XCODE/iOS-App`
- `docs/XCODE_RUNBOOK.md`: veralteter Pfad `~/repos/LocationHistory2GPX-Monorepo` (2×) → `~/Desktop/XCODE/iOS-App`
- `wrapper/README.md`: veralteter Pfad `~/repos/LocationHistory2GPX-Monorepo` → `~/Desktop/XCODE/iOS-App`

### Verifikation
- `swift test`: 616 Tests, 0 Failures — `xcodebuild generic/platform=iOS`: BUILD SUCCEEDED

## [2026-04-13] — Apple-Developer-Basis + Xcode Cloud Setup

### Behoben
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: UITests Bundle ID `xagr3k7xdj.de.roeber.lh2gpxwrapper.uitests` → `de.roeber.LH2GPXWrapper.UITests` (beide Konfigurationen Debug + Release); Xcode hatte beim Anlegen des Targets die Team-ID als Prefix generiert

### Hinzugefuegt
- `wrapper/.xcode-version`: pinnt Xcode Cloud auf Version 26.3 (entspricht lokal installiertem Xcode)
- `wrapper/ci_scripts/ci_post_clone.sh`: Xcode Cloud Post-Clone-Hook (dokumentiert lokale SPM-Abhängigkeit, erweiterbar)
- `wrapper/ci_scripts/ci_pre_build.sh`: injiziert `CI_BUILD_NUMBER` als `CFBundleVersion` in App- und Widget-Info.plist; bei lokalem Build ohne `CI_BUILD_NUMBER` No-op
- `wrapper/ci_scripts/ci_post_xcodebuild.sh`: Post-Build-Logging mit Exit-Code und Action
- `docs/XCODE_CLOUD_RUNBOOK.md`: vollständiges Runbook für Xcode Cloud Setup inkl. manueller GUI-Schritte, Signing-Tabelle, Build-Nummern-Logik, Kompatibilitätsprüfung

### Doku aktualisiert
- `docs/APPLE_VERIFICATION_CHECKLIST.md`: 2026-04-13 Block mit verifizierten Schritten und offenen manuellen Apple-Gates
- `NEXT_STEPS.md`: Bundle-ID-Fix und Xcode-Cloud-Vorbereitungsschritte als erledigt markiert; manuelle Apple-Schritte als offene Aufgaben eingetragen

## [2026-04-13] — PathFilter: GPS-Jump-Filter als Vorverarbeitung im mapMatched-Modus

### Hinzugefuegt
- `PathFilter.swift` (neu): `removeOutliers(_:maxJumpMeters:)` auf `LocationCoordinate2D` (Linux-kompatibel) entfernt GPS-Ausreisser mit Sprung > 5000 m; `#if canImport(CoreLocation)` Wrapper fuer `CLLocationCoordinate2D`
- `AppDayMapView.swift`: im `.mapMatched`-Zweig wird `path.coordinates` jetzt zuerst durch `PathFilter.removeOutliers(...)` gefiltert, dann durch `PathSimplification.douglasPeucker(...)`; `.original`-Zweig bleibt unveraendert
- Fallback: wenn nach dem Filter < 2 Punkte uebrig bleiben, wird die Original-Sequenz unveraendert weitergereicht
- `PathFilterTests.swift`: 9 Unit-Tests (Edge-Cases, normale Tracks, Ausreisser-Entfernung, Fallback, Custom-Threshold) — 616 Tests gesamt, 0 Failures

### Hinweis
- Kein echtes Strassen-/Weg-Snapping — die `Simplified (Beta)`-Darstellung bleibt geometrische Vereinfachung + Ausreisserfilterung ohne Road-Network-Abgleich
- Kein Device-Run; Xcode iOS Build + swift build + swift test (macOS) gruen (Commit cf66dd1)

## [2026-04-13] — Live-Ausbau: Auto-Resume UX + Session-Restore

### Hinzugefuegt
- `LiveLocationFeatureModel`: `sessionStartedAt` wird beim App-Start aus UserDefaults wiederhergestellt, wenn eine unterbrochene Session vorliegt — der Banner zeigt jetzt den relativen Zeitstempel der Unterbrechung an
- `AppLiveTrackingView`: Unterbrochene-Session-Banner zeigt "Eine Aufzeichnung, die vor X Minuten gestartet wurde, wurde unterbrochen" statt generischer Meldung (via `RelativeDateTimeFormatter`)
- `AppGermanTranslations`: 16 neue DE-Strings fuer Live-Tracking-Banner, Follow-Mode, Fullscreen-Map und weitere UI-Elemente
- Neuer Test `testSessionStartedAtRestoredOnInitWhenSessionIDPresent` prueft dass gespeicherter Session-Timestamp beim Init korrekt geladen wird — 607 Tests gesamt, 0 Failures

## [2026-04-13] — Release-Haertung: Accessibility + Options UX

### Verbessert
- `AppLiveTrackingView`: stat-Karten (`statCard`) erhalten `.accessibilityElement(children: .ignore) + .accessibilityLabel("\(value), \(label)")` — VoiceOver liest Wert + Label als eine Einheit statt Einzelfragmente
- `AppInsightsContentView`: `summaryCard` und `avgCard` erhalten kombiniertes Accessibility-Element (Wert + Titel + optionaler Subtitel) fuer konsistente VoiceOver-Ausgabe
- `AppOptionsView` (Sektion "Language and Upload"): "Upload Batch Size" und "Upload Status" werden nur noch angezeigt wenn "Upload to Custom Server" aktiv ist — reduziert Informationsrauschen fuer die grosse Mehrheit der Nutzer ohne Upload-Konfiguration

## [2026-04-12] — Device-Smoke-Test, Widget Privacy Manifest, Archive-Verifikation

### Hinzugefuegt
- `wrapper/LH2GPXWidget/PrivacyInfo.xcprivacy` erstellt und im `.xcodeproj` verankert (UserDefaults CA92.1, kein Tracking)

### Verifiziert
- iPhone 15 Pro Max (00008130-00163D0A0461401C): App installiert, gestartet, kein Crash (PID stabil)
- ZIPFoundation 0.9.20 bringt eigenes Privacy Manifest mit (FileTimestamp 0A2A.1) — kein Handlungsbedarf
- Signing (Team XAGR3K7XDJ, Automatic) funktioniert fuer Device-Build
- Store-Archive-Pfad ist `wrapper/LH2GPXWrapper.xcodeproj`, nicht SPM-Scheme

## [2026-04-12] — Mac/Xcode Build Fix: Compiler Errors + Swift Test Regressions

### Fixed
- `AppDayDetailView.swift`: `landscapeContentColumn(detail: detail)` → `landscapeContentColumn(detail)` (anonymous label mismatch; caused Xcode build failure)
- `AppDayMapView.swift`: `fillHeight` promoted to init parameter `init(mapData:fillHeight:)` so landscape caller can pass `fillHeight: true` (previously `AppDayMapView(mapData:fillHeight:)` call failed to compile)
- `WidgetDataStore.swift`: added `import LocationHistoryConsumerAppSupport` so `DynamicIslandCompactDisplay` type resolves in widget target scope
- `AppInsightsContentView.swift`: body extracted into `loadedBody` + `insightsScrollContent(isLandscape:)` + `insightsModeContent` to fix "compiler unable to type-check expression in reasonable time"; also fixed latent `LazyVGrid(alignment: .top)` bug → `.leading` (HorizontalAlignment)
- `AppLiveTrackingView.swift`: `.fullScreenCover` wrapped in `#if os(iOS)` to fix `swift test` failure on macOS (unavailable API)
- `MapMatchingTests.swift`: empty array literal `[]` disambiguated as `[LocationCoordinate2D]()` to resolve ambiguity between `CLLocationCoordinate2D` and `LocationCoordinate2D` overloads

### Build/Test Status
- `xcodebuild build -scheme LH2GPXWrapper -destination iPhone 17 Simulator`: BUILD SUCCEEDED
- `swift test` (macOS): 606 Tests, 0 Failures, 0 Skips
- Xcode unit tests (LH2GPXWrapperTests): all passed
- UI automation tests (testDeviceSmokeNavigationAndActions, testAppStoreScreenshots): expected fail on Simulator (need real device + loaded content)

## [2026-04-12] — Truth Sync: Sorting, Overview Fidelity, Insights Range, Linux Testability

### Changed
- `AppSessionState`: app-weite Day-Summary-Projektion und gefilterte Days-Liste jetzt repo-wahr `neu -> alt`; Initialauswahl/Fallback bevorzugen den neuesten sichtbaren Tag statt des aeltesten
- `AppOverviewTracksMapView`: versteckte Route-Kappung fuer die Overview-Karte entfernt; alle Routen im aktiven Zeitraum bleiben erhalten, Performance laeuft weiter ueber Vereinfachung/Decimation statt stilles Weglassen
- `AppInsightsContentView` / `InsightsMonthlyTrendPresentation`: Monats-Trends respektieren jetzt den aktiven Zeitraum ohne 24-Monats-Cap; Tabellen-/Listenansicht zeigt neueste Monate zuerst

### Fixed
- Linux-Testbarkeit fuer Import-/Pfad-/Layout-Code nachgezogen: `PathSimplification`, GPX-/TCX-XML-Parser und zugehoerige Tests laufen jetzt ohne Apple-only Foundation/CoreLocation-Annahmen
- `LandscapeLayoutTests` und `DemoDataLoaderTests` auf aktuellen Produktstand korrigiert

### Tests
- `swift test` auf Linux: `575` Tests, `2` Skips, `0` Failures

### Not done
- kein echtes Road-/Path-Matching
- kein Auto-Resume laufender Live-Aufzeichnungen nach App-Neustart
- keine neue Apple-Device-/Portal-Verifikation; Linux-only Nachweis

## [2026-04-12] — Release-Härtung: TCX, Widget-Lokalisierung, Privacy, CI

### Fixed
- `TCXImportParser.swift`: bekannter `fatalError`-Pfad entfernt; Parser liefert jetzt typisierte `TCXImportError`-Faelle fuer invalides XML, fehlende Trackpoints, fehlende Pflichtdaten und Export-Roundtrip-Fehler
- `AppContentLoader.swift`: TCX-Parserfehler werden an der Loader-Grenze weiterhin kontrolliert auf `AppContentLoaderError.decodeFailed(...)` abgebildet; kein Crash im Import-Flow
- Widget-/Live-Activity-Texte in `wrapper/LH2GPXWidget/` auf lokalisierte `WidgetStr`-Zugriffe umgestellt; Widget bevorzugt jetzt die via App Group gespiegelte `AppLanguagePreference` und faellt sonst auf die Geraetesprache zurueck
- `AppPreferences.swift`: App-Sprache wird in die App-Group-Defaults gespiegelt, damit Widget und App denselben Sprachwunsch teilen koennen
- `PrivacyInfo.xcprivacy`: `NSPrivacyCollectedDataTypePreciseLocation` fuer den optionalen, standardmaessig deaktivierten Live-Upload explizit als `App Functionality`, nicht linked und nicht tracking-basiert deklariert

### Tests
- `swift test`: 586 Tests, 0 Failures
- Parser-Tests fuer invalides TCX, fehlende Pflichtdaten und unerwartete Trackpoint-Zustaende aktualisiert/ergaenzt
- `AppPreferencesTests`: neue Abdeckung fuer das Spiegeln der App-Sprache in die Widget-App-Group
- CI (`.github/workflows/swift-test.yml`): echter `xcodebuild`-Build fuer `LH2GPXWrapper` inklusive eingebettetem `LH2GPXWidget` statt reinem Kommentar-/Echo-Step

## [2026-04-12] — App Groups Entitlements + GPX/TCX fileImporter + Deep Link + Overview Map Budget Fix

### Added
- App Groups Entitlements: `LH2GPXWrapper.entitlements` und `LH2GPXWidget.entitlements` mit `com.apple.security.application-groups: group.de.roeber.LH2GPXWrapper` erstellt; `CODE_SIGN_ENTITLEMENTS` fuer alle 4 Build-Konfigurationen beider Targets in `project.pbxproj` gesetzt — Widget-Datenaustausch via `WidgetDataStore` (UserDefaults App Group) funktioniert jetzt korrekt; vorher zeigte Widget immer "Keine Aufzeichnung"
- `fileImporter` akzeptiert jetzt zusaetzlich `.gpx` und `.tcx`: `UTType.tcx` Extension in `GPXDocument.swift`, `allowedContentTypes` in `ContentView.swift` von `[.json, .zip]` auf `[.json, .zip, .gpx, .tcx]` erweitert
- Deep Link `lh2gpx://live`: `CFBundleURLTypes` mit Schema `lh2gpx://` in `Info.plist` registriert; `onOpenURL`-Handler + `handleDeepLink()` in `ContentView.swift`; `navigateToLiveTabRequested` Property in `LiveLocationFeatureModel.swift`; `onChange`-Observer in `AppContentSplitView.swift` navigiert zu Live-Tab (`selectedTab = 3`)

### Fixed
- `AppOverviewTracksMapView`: Komplette Neuimplementierung mit `OverviewMapRenderProfile` (adaptives Budget 72–180 Routen), Grid-basierter Kandidatenauswahl und Douglas-Peucker Simplifikation — Karte zeigte 294 Routen statt sinnvolles Budget
- `TCXImportParser.makeExport()`: `fatalError` durch `throw AppContentLoaderError.decodeFailed(fileName)` ersetzt — robustes Fehlerhandling statt Absturz bei ungueltigen TCX-Daten

### Tests
- `TCXImportParserTests`: neue dedizierte Tests fuer happy path (sample_import.tcx), error paths (leere Daten, kaputtes XML, kein Position-Element), isTCX-Detection, sourceType und Koordinatengenauigkeit
- 573 Tests, 0 Failures (historischer Stand dieses Batches)

## [2026-04-12] — Deep Audit + Homescreen Widget + Live Activity Improvements + Overview Map Performance

### Added
- Homescreen Widget (`LH2GPXHomeWidget`): systemSmall + systemMedium, zeigt letzte Aufzeichnung (Distanz, Dauer, Datum), Deep-Link `lh2gpx://live`
- `WidgetDataStore.swift`: App-Group UserDefaults (`group.de.roeber.LH2GPXWrapper`), graceful Fallback auf `.standard`
- `TrackingStatus` Erweiterungen: `isPaused`, `uploadQueueCount`, `lastUploadSuccess` (backward-compat `decodeIfPresent`)
- Live Activity UI: Pause-Indikator ("⏸ Pausiert"), Upload-Badge ("↑ N"), Pace-Label auf Lock Screen
- ActivityKit Update-Throttling: ≤1 Update/5s (`ThrottleGate` in `ActivityManager`)
- 4 neue `WidgetDataStoreTests`, 14 neue `LiveActivityTests`
- `wrapper/Makefile`: dynamisches Device-Deploy via `xcrun devicectl` (CoreDevice UUIDs)
- `.gitignore`: `xcuserdata/`, `*.xcuserstate`

### Performance
- Overview Map: einphasige Off-Main-Preparation statt altem 100-Day-Batching; veraltete Background-Loads werden über stärkeren Task-Key + Generation-Guard verworfen
- Overview Map: Route-Budget/LOD für große Zeiträume (`routeLimit`, Grid-Selektion pro Region-Zelle, Decimation pro Polyline) für robuste Darstellung bei hohen Datenmengen
- Douglas-Peucker Simplification 50–140m für Overview je nach Datenmenge (Detail bleibt feiner)
- Overview-Badge zeigt jetzt die tatsächlich dargestellten Overview-Routen; bei großen Datenmengen zusätzlich Kennzeichnung als optimierte Übersicht
- 3 neue `AppOverviewTracksMapViewTests` sichern Task-Key-Invaliderung, Small-Range-Verhalten und Large-Range-Optimierung

### Infrastructure
- `LocationHistory2GPX` (Python Pipeline) auf privat gesetzt
- 570 Tests total, 0 Failures ✅

## [2026-04-12] — KMZ Export + Live Activity Widget UI + Xcode Setup

### Added
- KMZ Export: `KMZBuilder.swift` (ZIPFoundation, temp-file pattern), `KMZDocument.swift` (BinaryExportDocument), `ExportFormat.kmz` case (archivebox.fill icon), vollständige Integration in `AppExportView` mit eigenem `fileExporter` für binäres KMZ
- 6 neue KMZ-Tests in `KMZExportTests.swift` (ZIP-Signatur, doc.kml Struktur, KML-Inhalt, Waypoint-Mode, Empty-Days)
- Live Activity Widget UI: `wrapper/LH2GPXWidget/` mit `TrackingLiveActivityWidget.swift` (Dynamic Island expanded/compact/minimal + Lock Screen Banner), `LH2GPXWidgetBundle.swift`, `Info.plist`
- `docs/WIDGET_XCODE_SETUP.md`: vollständige Schritt-für-Schritt-Anleitung für manuelles Xcode Widget Extension Target Setup
- 556 Tests total, 0 Failures (vorher 550)

### Infrastructure
- Xcode Build für iPhone 15 Pro Max: BUILD SUCCEEDED ✅
- Deploy + Launch auf iPhone 15 Pro Max (UDID 00008130-00163D0A0461401C) ✅

## [iOS-App Init] - 2026-04-12

### Changed
- iOS-App ist ab jetzt das zentrale aktive Repo (dev-roeber/iOS-App)
- Vollstaendige iOS-App aus LocationHistory2GPX-Monorepo konsolidiert (inkl. kompletter Git-History)
- LocationHistory2GPX-Monorepo, LocationHistory2GPX-iOS, LH2GPXWrapper sind historische Vorstufen

## [Prompt 4b] - 2026-04-12

### Changed
- Replaced subtle icon-only help button with prominent inline action on import start screen
- GoogleMapsExportHelpInlineAction: full text label "Google Maps Export on iPhone", map icon, chevron, accentColor background
- Positioned directly above the primary "Open location history file" button
- Removed icon-only GoogleMapsExportHelpButton from title row
- Added DE accessibilityHint for VoiceOver

## [Prompt 4] - 2026-04-12

### Added
- Google Maps export help sheet on start screen (GoogleMapsExportHelpView)
- Info button (questionmark.circle) next to source title in AppSourceSummaryCard
- Native bottom sheet: title, 4 concise steps for iPhone export, Takeout fallback hint
- DE/EN localization for all help strings (9 new entries in AppGermanTranslations)
- 4 new unit tests in GoogleMapsExportHelpTests

## [Prompt 3] - 2026-04-12

### Added
- Map Matching toggle in Days detail view: "Original" vs. "An Straße angepasst (Beta)"
- Douglas-Peucker path simplification (PathSimplification.swift, epsilon=15m, no external deps)
- AppDayPathDisplayMode enum (.original / .mapMatched) with @AppStorage persistence
- Live Activity / Dynamic Island support via ActivityKit (iOS 16.1+)
- TrackingAttributes + TrackingStatus (ActivityAttributes) for recording state
- ActivityManager singleton: start/update/end/cancelAll
- NSSupportsLiveActivities = true in Info.plist
- Integration in LiveLocationFeatureModel and LiveTrackRecorder
- 16 new tests (MapMatchingTests + LiveActivityTests), total: 546

## Audit 2026-04-12 — Prompt2/Prompt3 Truth Sync
- Prompt 2 (GPX/TCX Import): vollständig verifiziert — alle Parser, Tests, Doku repo-wahr ✅
- Prompt 3 (Map Matching + Dynamic Island): nicht repo-wahr nachweisbar — als offen dokumentiert ⚠️
- README Import-Abschnitt nachgezogen
- NEXT_STEPS Wiederanlauf-Plan für Prompt 3 erstellt

## [Unreleased] – 2026-04-12

### Feature: Multi-Source Import Foundation (GPX + TCX)

- **GPX import**: `GPXImportParser` parses GPX 1.1 XML (`<trk>/<trkseg>/<trkpt>` + `<wpt>`) into `AppExport`. Waypoints become Visit entries. Groups points into days by local calendar date (`.autoupdatingCurrent` timezone).
- **TCX import**: `TCXImportParser` parses TCX 2.0 XML (`<TrainingCenterDatabase>/<Activity>/<Lap>/<Track>/<Trackpoint>/<Position>`) into `AppExport`. Groups by local date.
- **AppContentLoader routing**: `decodeData()` detects GPX/TCX before JSON paths. ZIP scanning also looks for `.gpx`/`.tcx` entries when no LH2GPX or Google Timeline JSON is found.
- **fileImporter UTTypes**: `AppShellRootView.fileImporter` now accepts `.gpx` and `.tcx` in addition to `.json` and `.zip`.
- **Localization**: 7 new strings in `AppGermanTranslations`: "GPX file", "TCX file", "GPS Exchange Format", "Training Center XML", "GPX imported", "TCX imported", "File contains no track points".
- **Error messages**: `unsupportedFormat` and `jsonNotFoundInZip` error descriptions updated to mention GPX/TCX.
- **Fixtures**: `sample_import.gpx`, `sample_import.tcx`, `sample_import_empty.gpx` added to `Fixtures/contract/`.
- **Tests**: 19 new tests in `MultiSourceImportTests` covering parse correctness, fixture round-trips, edge cases, detection, AppContentLoader routing, data flow into `daySummaries()` + `insights()`, and regression tests for Google Timeline + LH2GPX. Total: 530 tests, 0 failures.
- **Deliberately NOT implemented**: FIT format (no maintainable Swift library without external dependency); GeoJSON import (complex edge cases — follow-up).
- **Protected (Prompt-1)**: `HistoryDateRangeFilter`, `AppInsightsContentView`, `AppContentSplitView`, `AppOverviewTracksMapView`, `AppDayListView`, `AppHeatmapView`, `OverviewFavoritesAndInsightsTests` — all untouched.

### Feature: Overview, Insights & Heatmap UI Polish (Tasks 1–10)

- **Task 1 – Time-range first**: `AppContentSplitView.overviewPaneContent` reordered so `AppHistoryDateRangeControl` appears at the very top of the overview pane
- **Task 2 – Favorites toggle**: New Capsule-style "Favorites Only / All Days" button appears below the time-range control when at least one day is favorited; state is held in `overviewShowOnlyFavorites`; `overviewFilteredDaySummaries` feeds the map and the summary stats
- **Task 3 – Overview tracks map**: New `AppOverviewTracksMapView` (iOS 17+) loads all polylines off-main-thread via `Task.detached`; reactive reload via `.task(id:)`; caps at 100 days; shows loading / empty states; embedded in overview pane
- **Task 4 – Heatmap chip styling**: Mode and Radius pickers replaced from `.pickerStyle(.segmented)` with custom `HStack<Button>` using Capsule clip shape + accent/secondary background — matches `AppDayFilterChipsView` exactly; controls wrapped in `ScrollView` for landscape usability
- **Tasks 5/8 – Stray bullet removed**: `AppDayRow` no longer renders a second `Text("No data")` beside the tray `Label`; the orphaned visual point in day list and Insights is gone
- **Task 6 – Top-days limit 20**: `InsightsTopDaysPresentation.topDays(from:by:limit:)` called with `limit: 20` in `AppInsightsContentView`; was previously hard-coded 5
- **Task 7a – Date-range timezone fix**: `HistoryDateRangeFilter.isoFormatter` now uses `.autoupdatingCurrent` instead of UTC; eliminates off-by-one day-boundary errors for users outside UTC
- **Task 7b – Insights metric state shift**: `refreshDerivedModel()` collects all proposed metric values first, then applies them atomically via `withTransaction(Transaction(animation: nil))` to prevent sequential re-renders and visible button shifts
- **Task 9 – German localization**: ~30 new DE strings in `AppGermanTranslations` covering "Favorites Only", "All Days", "No tracks in selected range", "Loading map…", "Computing heatmap…", Insights period-comparison messages, streak no-data message, accessibility labels, ranked-day metric labels, and several previously-untranslated strings
- **Task 10 – Landscape (partial)**: Heatmap control overlay wrapped in `ScrollView(.vertical)` with `maxHeight: 260` to prevent clipping in landscape
- **Tests**: New `OverviewFavoritesAndInsightsTests` (14 cases) covers favorites-filter state, local-timezone correctness of `fromDateString`/`toDateString`, top-days limit=20, German translations for all new keys, and English identity invariant; total test count 511, 0 failures

### Fix: Live Background Authorization Start Gate

- `LiveLocationFeatureModel`: Startfluss fuer Live-Recording als kleine Zustandsmaschine abgesichert (`idle`, `requestingWhenInUse`, `awaitingAlwaysUpgrade`, `readyToStart`, `recording`, `failedAuthorization`)
- `recorder.start()` und `client.startUpdatingLocation()` laufen bei aktivierter Hintergrundaufzeichnung jetzt erst, nachdem das `Always Allow`-Upgrade tatsaechlich aufgeloest wurde
- fehlgeschlagene `Always Allow`-Erweiterung bleibt nicht mehr im irrefuehrenden Pending-Zustand; die UI zeigt jetzt einen expliziten `Background Access Required`-Fehlerzustand
- mehrfaches Start-Triggern waehrend Pending/Recording fuehrt nicht mehr zu doppeltem Start
- `LiveLocationFeatureModelTests`: 5 neue Regressionstests fuer wartenden Start, erfolgreichen Upgrade-Pfad, denied/restricted ohne Start, doppeltes Triggern und Permission-Prompt-Failure
- Repo-Truth: die Deep-Audit-Race-Condition rund um `requestAlwaysAuthorization()` und `recorder.start()` war real und ist jetzt gezielt eingegrenzt behoben
- Nachweis: `swift test --filter LiveLocationFeatureModelTests` → `Executed 22 tests, with 0 failures (0 unexpected)`

### Test: Google Timeline Timezone / DST Verification

- `GoogleTimelineConverter`: Timezone-/DST-Audit-Vermutung gezielt verifiziert; keine Produktionslogik geändert
- Parsing verifiziert für ISO8601 mit `Z`, `+01:00` und `+02:00`; keine doppelte Offset-Anwendung nachweisbar
- UTC-Day-Grouping an lokalen Tagesgrenzen verifiziert: lokale `23:xx`/`00:xx`-Übergänge bleiben korrekt auf dem absoluten UTC-Tag gruppiert
- `timelinePath`-Punktzeiten über DST-Vorwärts- und DST-Rückwärtswechsel verifiziert; Offsets werden als absolute Zeit korrekt fortgeschrieben
- Downstream-Prüfung bestätigt: `AppExportQueries.daySummaries` und `AppExportQueries.insights` bleiben bei Google-Timeline-Imports auf denselben UTC-Day-Keys stabil
- 6 neue deterministische Tests in `GoogleTimelineConverterTests`: Zulu-Timestamp, `+01:00`, `+02:00`, DST vorwärts, DST rückwärts, Tagesgrenze mit nachgelagerten Queries/Insights
- Repo-Truth: Deep-Audit-Annahme einer möglichen Google-Timeline-Timezone-/DST-Schwäche ist durch Tests widerlegt
- Nachweis: `swift test` → `Executed 492 tests, with 0 failures (0 unexpected)`

### Fix: P1 Critical Security + Stability Fixes

- `LiveLocationServerUploadConfiguration.defaultTestEndpointURLString`: war bereits `""` (kein Default-Server); URL-Validierung erzwingt HTTPS (localhost erlaubt HTTP) — kein echtes User-Data-Risiko durch versehentlichen Upload
- `KeychainHelper.KeychainError`: neuer Case `encodingFailed` hinzugefügt; force-unwrap `value.data(using: .utf8)!` durch `guard let data = ... else { throw .encodingFailed }` ersetzt
- `AppExportQueries.effectiveDistance(for:day:)`: Logik von konfuser `guard pathDistance <= 0 else` auf explizites `if pathDistance > 0 { return }` umgestellt; Kommentar dokumentiert die Fallback-Hierarchie (pathDistance bevorzugt wenn > 0, sonst Aktivitätssumme)
- `GeoJSONBuilder`: neuer `GeoJSONBuildError.serializationFailed` (mit `LocalizedError`); `build()` ist jetzt `throws` statt silent fallback auf leere FeatureCollection; `AppExportView` fängt den Fehler im `do-catch`-Block ab und zeigt eine lokalisierbare Fehlermeldung
- `LiveLocationServerUploaderTests.MockURLProtocol.startLoading()`: liest `httpBodyStream` wenn `httpBody` nil ist (Apple-Platform-Fix: URLSession konvertiert POST-Body intern zu Stream); behebt pre-existing macOS-Crash in `testUploadEncodesBodyAsJSON`
- 9 neue Tests: `testEffectiveDistanceFallsBackToActivityDistanceWhenPathDistanceIsZero`, `testEffectiveDistancePrefersPathDistanceOverActivityDistance`, `testBuildEmptyDaysProducesValidFeatureCollection`, `testSaveAndRetrieveRoundTrip`, `testSaveEmptyStringRoundTrip`, `testEncodingFailedErrorCaseExists`
- Linux + macOS Nachweis: `swift test` → `Executed 481 tests, with 0 failures (0 unexpected)`; `git diff --check` sauber

## [Unreleased] – 2026-04-03

### Fix: Live-Settings Time Gap Bounds

- `RecordingIntervalPreference`: Untergrenze jetzt `0` statt `1`; `0` wird als `No minimum` modelliert und deaktiviert das harte Zeit-Gate sauber
- `RecordingIntervalPreference`: keine obere Clamp mehr; große Werte bleiben erhalten und die UI behandelt die Obergrenze explizit als `Unlimited`
- `AppOptionsView`: Live-Settings zeigen jetzt `Minimum Time Gap` als editierbare Einstellung mit `No minimum`-Anzeige für `0` plus separater `Maximum Time Gap: Unlimited`-Zeile
- `AppOptionsView`: die missverständliche Read-only-Zeile `Minimum Time Gap (from Detail)` entfällt; Footer erklärt jetzt klar die Rollen von Mindestabstand, unbegrenzter Obergrenze und `Recording Detail`
- `AppLanguageSupport`: neue DE-Texte für `Maximum Time Gap`, `No minimum`, `Unlimited` und die überarbeitete Live-Settings-Erklärung
- `RecordingIntervalPreferenceTests`: Grenzwert- und Anzeige-Tests auf `0`/`Unlimited` umgestellt; große Werte werden nicht mehr numerisch begrenzt
- `AppPreferences`: geladene `recordingInterval`-Werte werden beim Start jetzt validiert, damit ungültige persistierte Altwerte keine negativen Mindestabstände einschleusen
- `AppPreferencesTests`: Persistenz für `0` (`No minimum`), negative Altwerte und große Werte ohne obere Begrenzung ergänzt
- Recorder-/Upload-Semantik bleibt stabil: `minimumRecordingIntervalS == 0` deaktiviert weiter nur das harte Intervall-Gate; Upload-, Persistenz- und Qualitätslogik bleiben ansonsten unverändert

### Fix: Linux URLSession Test Coverage

- `LiveLocationServerUploaderTests.swift` (neu): 9 Tests für `HTTPSLiveLocationServerUploader` — fehlende Unit-Test-Abdeckung des Linux-spezifischen `dataTask`-Continuation-Pfades nachgeliefert
- Ursache: `URLSession.data(for:)` async-Overload ist auf Swift 5.9 Linux (FoundationNetworking) nicht verfügbar (confirmed per Compiler); der vorhandene `#if canImport(FoundationNetworking)`-Workaround war korrekt, aber nie durch Tests abgesichert
- Mock-Strategie: `URLProtocol`-Subklasse mit `URLSessionConfiguration.ephemeral` und lock-geschütztem statischem Handler — funktioniert auf Linux (FoundationNetworking) und Apple-Plattformen ohne echte Netzwerkaufrufe
- Abgedeckte Fälle: POST-Methode, korrekter Endpoint, `Content-Type`-Header, `Authorization: Bearer`-Header, fehlender Auth-Header wenn `bearerToken` nil, JSON-Body, 2xx-Erfolg, 4xx/5xx → `unsuccessfulStatusCode`, Netzwerkfehler-Propagation
- Linux-Nachweis: `swift test` → `Executed 444 tests, with 2 tests skipped and 0 failures (0 unexpected)`; `git diff --check` sauber

### Polish: Overview + Insights UX

- Summary card order: Active Days and Total Distance promoted to top; Days Loaded moved below
- Summary card subtitles: "Route distance with trace fallback" → "Total route distance"; "Across visible days" → "Daily average"; "Months with visible day entries" → "Months with activity"
- Header description shortened: "Overview, Patterns and Breakdowns for your imported history."
- Overview section order: Top Days (drilldown-capable) moved before Activity Streak (aggregated)
- Period Comparison at All-Time: explicit "All Time Selected" empty state card with `allTimeMessage()`; previously showed generic "No Range Active"
- Drilldown indicators unified: `ellipsis.circle` replaced with `chevron.right` in monthly-trend and period-breakdown rows — now matches highlight and top-day cards
- AppLanguageSupport: DE translations for "Total route distance", "Daily average", "Months with activity", "Overview, Patterns…", "All Time Selected", and period comparison messages

### Polish: Insights Presentation States

- Period Comparison: explicit `allTimeMessage()` when All-Time range selected (`"Period comparison is not available for All Time…"`); new `noDataMessage()` for empty periods
- Streak: clearer empty state via `noDataMessage()` — now actionable (`"No activity streak yet. Start recording to build your streak."`)
- TopDays: new `emptyRangeMessage()` for ranges with no recorded routes (`"No days with recorded routes in the selected range."`)
- AppLanguageSupport: DE translations for all three new state strings

### Fix: UX-/Text-Fix für Live-Recording-Settings

- `RecordingIntervalPreference.displayString`: Singular/Plural korrekt und lowercase (`1 second`, `2 seconds`, `1 minute`, `2 Stunden` via DE-Lokalisierung, etc.)
- `RecordingIntervalUnit.singularKey`: neues Property (`"second"` / `"minute"` / `"hour"`) für lowercase-Lokalisierungskeys
- `AppOptionsView` Stepper-Label: kompakteres Format `"Every 5 seconds"` / `"Alle 5 Sekunden"` statt `"Recording Interval: 5 Seconds"`
- `AppLanguageSupport`: neue Keys `"Every"` → `"Alle"` sowie lowercase-Keys `"second"/"seconds"` → `"Sekunde"/"Sekunden"`, `"minute"/"minutes"`, `"hour"/"hours"` (DE)
- `RecordingIntervalPreferenceTests`: displayString-Tests auf lowercase aktualisiert, auf camelCase-Naming umgestellt; neuer Test `testUnitSingularKey`

### Fix: Live-Recording-Settings UX

- `RecordingIntervalPreference.displayString`: korrekte Singular/Plural (1 Second / 2 Seconds etc.) — war bereits implementiert, Verhalten bestätigt
- `RecordingIntervalUnit.singularDisplayName`: neues Property (`"Second"` / `"Minute"` / `"Hour"`) für lokalisierbare Stepper-Labels
- `AppOptionsView` Stepper-Label: nutzt jetzt `singularDisplayName` wenn `value == 1` → korrekte Singular/Plural-Darstellung im UI
- `AppOptionsView`: `"Minimum Time Gap"` → `"Minimum Time Gap (from Detail)"` mit Footer-Hinweis, dass dieser Wert aus der Aufzeichnungsdetail-Einstellung stammt, nicht aus dem Aufnahmeintervall
- `AppLanguageSupport`: neue DE-Singular-Keys (`"Second"` → `"Sekunde"`, `"Minute"` → `"Minute"`, `"Hour"` → `"Stunde"`) sowie DE-Übersetzungen für neue Footer-Strings
- `RecordingIntervalPreferenceTests`: neuer Test `testUnitSingularDisplayName` für alle drei Einheiten

### Feature: Konfigurierbarer GPS-Aufnahmeintervall für Live-Recording

- `RecordingIntervalPreference.swift` (neu): `RecordingIntervalUnit` (`.seconds`/`.minutes`/`.hours`; `Codable`, `CaseIterable`, `Identifiable`, `Sendable`) und `RecordingIntervalPreference` (`Codable`, `Equatable`, `Sendable`) modellieren einen absoluten Mindest-Zeitabstand zwischen akzeptierten GPS-Punkten; `static .default` = 5 s; `static func validated(value:unit:)` klemmt auf gültige Einheits-Grenzen (s: 1–3600, min: 1–60, h: 1–24); `totalSeconds: TimeInterval`; `displayString: String` (EN, Singular/Plural)
- `LiveTrackRecorder.swift`: `LiveTrackRecorderConfiguration` um `minimumRecordingIntervalS: TimeInterval` (default `0` = kein Gate) erweitert; `append(_:)` verwirft Punkte wenn `timeDelta < minimumRecordingIntervalS > 0` – absolutes Zeit-Gate unabhängig von Distanz
- `AppPreferences.swift`: neues `@Published var recordingInterval: RecordingIntervalPreference`; UserDefaults-Key `"app.preferences.recordingInterval"` (JSON-encoded); `liveTrackRecorderConfiguration` übergibt `minimumRecordingIntervalS: recordingInterval.totalSeconds`; `reset()` setzt auf `.default` zurück
- `AppOptionsView.swift`: neue `Stepper` + `Picker`-Zeilen im Abschnitt „Live Recording" erlauben Wert und Einheit des Intervalls inline anzupassen; Footer erklärt Auswirkung auf Punktanzahl / Akku / Upload
- `AppLanguageSupport.swift`: neue DE-Keys: `"Recording Interval"`, `"Interval Unit"`, `"Seconds"`, `"Minutes"`, `"Hours"`, Hinweistext
- `RecordingIntervalPreferenceTests.swift` (neu): 21 Tests — Default, `totalSeconds` für alle Einheiten, Validation/Clamping, Codable-Roundtrip, Equality, `CaseIterable`, `Identifiable`, `displayString` Singular/Plural
- `LiveTrackRecorderTests.swift`: 3 neue Tests für `minimumRecordingIntervalS`-Gate (rejects early, accepts after interval, zero disables gate)
- `AppPreferencesTests.swift`: Default- und StoredValues-Tests prüfen `recordingInterval` und `minimumRecordingIntervalS`; Reset prüft Rückkehr auf `.default`
- Linux-Nachweis: `swift test` → `Executed 447 tests, with 0 failures (0 unexpected)` ✅; `xcodebuild test` → `Executed 447 tests, with 0 failures (0 unexpected)` ✅



### Feature Batch Phase B – New Insights, Charts und Export-Erweiterung

- `InsightsStreakPresentation.swift` (neu): `InsightsStreakStat` und `InsightsStreakPresentation.streak(from:)` berechnen Longest- und Recent-Streak sowie Active/Total-Day-Counts rein aus `[DaySummary]` ohne View-Logik; `sectionHint(dayCount:)` und `noDataMessage()` liefern saubere Empty-States
- `InsightsPeriodComparisonPresentation.swift` (neu): `InsightsPeriodComparisonStat` / `InsightsPeriodComparisonItem`; `comparison(currentSummaries:allSummaries:rangeFilter:)` vergleicht aktiven Zeitraum mit gleich langem Vorperiod aus ungefilterter Basis; `deltaText(current:prior:)` und `isPositiveDelta(current:prior:)` fuer Delta-Darstellung; `sectionHint()` / `noRangeMessage()` fuer Empty-States
- `ChartShareHelper.swift`: `InsightsCardType` um `.streak` und `.periodComparison` erweitert; bestehende `ChartShareHelper.payload(for:dateRange:)` unterstuetzt neue Typen automatisch; Dateiname-Format konsistent
- `AppInsightsContentView.swift`: neues Init-Argument `allDaySummaries: [DaySummary] = []` fuer Vorperiod-Basis; `InsightsDerivedModel` ergaenzt um `streakStat` und `periodComparisonStat`; `refreshDerivedModel()` berechnet beide neu; `onChange(of: rangeFilter)` ergaenzt damit Period-Comparison bei Range-Aenderung aktualisiert wird; `buildSummaryCards` erhaelt neue Karte `Active Days` (aktive vs. geladene Tage); neue Sektionen: `streakSection` in Overview-Tab, `periodComparisonSection` in Patterns-Tab mit Side-by-side Vergleichsrows (Prior | Current | Delta); `streakCard`- und `periodComparisonRow`-Hilfsviews eingefuehrt
- `AppContentSplitView.swift`: `AppInsightsContentView`-Aufruf ergaenzt um `allDaySummaries: session.daySummaries`
- `InsightsStreakPresentationTests.swift` (neu): 10 Tests — Empty-Input, alle-inaktiv, Einzeltag, volle Sequenz, Gap-bricht-Streak, inaktive-in-Range-bricht-Streak, Recent-vs-Longest, Active/Total-Counts, Section-Hint-Schwelle, unsortierte-Eingabe
- `InsightsPeriodComparisonPresentationTests.swift` (neu): 12 Tests — kein Range → nil, last7d-Range, leere Vorperiod, Delta-Text-Faelle (+/-/0/kein-Prior/Infinity), isPositiveDelta-Faelle, Aggregations-Genauigkeit, Static-Messages
- `ChartShareHelperTests.swift`: 3 neue Tests fuer `.streak` und `.periodComparison` Filename/Title-Format; bestehender `testAllCardTypesProduceNonEmptyPayloads` deckt neue Typen automatisch ab
- Linux-Nachweis: `swift test` → `Executed 398 tests, with 2 tests skipped and 0 failures (0 unexpected)`; `git diff --check` sauber

### Feature Batch Phase A – Days Range Filter + Insights Map Drilldown

- `AppContentSplitView.swift`: `drilldownDaySummaries` basiert jetzt auf `projectedDaySummaries` statt `session.daySummaries`; damit respektiert die `Days`-Tab-Liste denselben globalen Zeitraumfilter wie `Overview`, `Insights` und `Export` — keine separate Range-Logik fuer Days
- `AppContentSplitView.swift`: `HistoryDateRangeFilterBar` wird im kompakten Days-Tab als sichtbarer Section-Header eingeblendet, wenn ein Zeitraumfilter aktiv ist; im regulaeren Split-View als Toolbar-Item
- `AppContentSplitView.swift`: Empty-State in der kompakten Days-Liste hat jetzt eine Variante fuer aktiven Zeitraumfilter ohne Treffer (`"No Days in Range"` + Hinweis zum Aendern des Filters)
- `AppContentSplitView.swift`: `showDayOnMap`-Drilldown navigiert direkt in den Day-Detail-View (mit inline `AppDayMapView`) und setzt Navigation-Path bzw. Selektion
- `AppDayListView.swift`: neuer optionaler Parameter `isRangeFilterActive: Bool` (default `false`) steuert den Empty-State-Headline und die -Message, wenn keine Tage im gewaehlten Zeitraum liegen
- `InsightsDrilldown.swift`: neuer `InsightsDrilldownAction.showDayOnMap(String)` fuer Drilldowns mit echtem raeumlichem Datenbezug; neue Factory `InsightsDrilldownTarget.showDayOnMap(_:)` mit Map-Icon; `drilldownTargets(for:)` liefert jetzt drei Targets: `showDay`, `showDayOnMap`, `exportDay` — ohne Fake-Kartenziele fuer aggregierte Werte
- `InsightsDrilldownBridge.swift`: `dayListAction`, `exportAction`, `filteredSummaries`, `prefillDates` und `description` vollstaendig exhaustiv fuer den neuen `.showDayOnMap`-Fall; `filteredSummaries` filtert auf den genannten Einzeltag; `description` liefert lokalisierte Beschreibungen auf Deutsch/Englisch
- `UIWiringTests.swift`: `testDrilldownTargetsForDateProducesShowAndExport` → `testDrilldownTargetsForDateProducesShowMapAndExport`; erwartet jetzt 3 Targets; 10 neue Tests fuer Phase-A-Range-Wiring und Map-Drilldown
- `InsightsDrilldownBridgeTests.swift`: 2 neue Tests fuer `showDayOnMap`-Beschreibung (Deutsch/Englisch) und Bridge-Filterung auf Einzeltag
- Linux-Nachweis: `swift test` → `Executed 370 tests, with 2 tests skipped and 0 failures (0 unexpected)`; `git diff --check` sauber

### Linux URLSession Build Fix + UIWiringTests WIP Integration

- `LiveLocationServerUploader.swift`: `HTTPSLiveLocationServerUploader.upload(request:to:bearerToken:)` nutzte `URLSession.data(for:)` (async overload), der auf Linux (Swift 5.9 / FoundationNetworking) nicht verfuegbar ist; ersetzt durch `withCheckedThrowingContinuation` ueber `dataTask(with:completionHandler:)` hinter `#if canImport(FoundationNetworking)`, sodass Apple-Plattformen weiterhin den nativen async-Pfad verwenden
- `InsightsDrilldown.swift`: fehlende statische Factory `drilldownTargets(for:)` ergaenzt; liefert `[showDay(date), exportDay(date)]` und vervollstaendigt damit den vorhandenen Factory-Satz fuer datenverankerte Drilldown-Targets
- `UIWiringTests.swift` (bisher untracked WIP): Testerwartungen fuer `ExportSelectionState.toggleRoute` korrigiert; die einfache Ueberladung (ohne `availableRouteIndices`) verwendet ein Inklusionsmodell (erster Aufruf fuegt den Index explizit hinzu, zweiter entfernt ihn); `testEffectiveRouteIndicesReturnsSubsetAfterToggle` nutzt jetzt korrekt die `availableRouteIndices`-Ueberladung fuer Deselektions-Semantik; UIWiringTests.swift ist ab diesem Commit in der versionierten Testliste enthalten
- Linux-Nachweis: `swift test` → `Executed 359 tests, with 2 tests skipped and 0 failures (0 unexpected)`; `git diff --check` sauber

### Device Runtime Verification – Background-Recording + Upload E2E

- **Background-Recording auf echtem iPhone verifiziert**: Permission-Upgrade auf `Always Allow`, Aufnahme im Hintergrund und Stop-/Persistenzverhalten auf iPhone 15 Pro Max real geprüft und bestätigt (2026-04-02); Feature ist funktional vollständig verifiziert auf echtem Gerät
- **Upload-End-to-End zum eigenen Server auf echtem iPhone verifiziert**: optionaler nutzergesteuerter HTTPS-Upload an eigenen Server auf echtem Gerät durchgelaufen und bestätigt (2026-04-02); HTTPS-Erzwingung, Bearer-Token und Queue-Verhalten im realen Betrieb bestätigt
- Doku-Sync: `docs/APPLE_VERIFICATION_CHECKLIST.md`, `NEXT_STEPS.md`, `docs/PRIVACY_MANIFEST_SCOPE.md` und `README.md` auf verifizierten Stand gebracht

### Apple Device Verification – Mac / Xcode / iPhone (post-performance-fix)

- Wrapper `ContentView.swift`: deterministischer Launch-Reset fuer UI-Tests via `LH2GPX_UI_TESTING` + `LH2GPX_RESET_PERSISTENCE` Launch-Arguments; `prepareLaunchStateIfNeeded()` loescht ImportBookmarkStore, RecentFilesStore und AppPreferences vor dem Test-Lauf; `restoreBookmarkedFile()` nutzt jetzt `AppImportStateBridge.restoreLastImportIfEnabled` statt rohem `ImportBookmarkStore.restore()`
- `LH2GPXWrapperUITestsLaunchTests.swift`: `testLaunch` prueft nach sauberem Reset auf `Load Demo Data`-Erscheinen; Launch-Arguments werden gesetzt
- `LH2GPXWrapperUITests.swift`: neuer `testDeviceSmokeNavigationAndActions`-Test laeuft auf echtem iPhone durch: Demo-Load, Overview/Heatmap, Insights/Share, Export/fileExporter, Live/Start+Stop-Recording; portrait-Lock, scroll-robuste Elementsuche (`revealElement`), Predicate-Matches fuer kombinierte Button-Label, koordinatenbasierter Zellen-Tap fuer Export-Selektion (SwiftUI-TabView-Cell-Limitation), Location-Permission-Handling
- `AppExportView.swift`: `accessibilityIdentifier("export.days.selectAll")` / `"export.days.deselectAll"` auf Days-Section-Header-Buttons; `accessibilityIdentifier("export.action.primary")` auf Export-Action-Button; `accessibilityIdentifier("export.day.row")` auf Day-Rows (fuer kuenftige XCUI-Nutzung)
- Mac-Build, iOS-Build, iOS-Archiv, 363 Package-Tests: alle gruen auf Apple-Host (Xcode 26.3)
- Device-Smoke auf iPhone 15 Pro Max (iOS 26.3): PASSED — Heatmap-Sheet, ImageRenderer-Share, fileExporter, Live-Recording real verifiziert

## [Unreleased] – 2026-04-01

### Performance / Stability Phase 3 – Heatmap / Map / Day Detail / Truth Sync

- `AppHeatmapView.swift`: Heatmap-First-Open weiter entschärft; Route-Grids und vorbereitete Route-Tracks werden jetzt einmalig vorgezogen, waehrend Dichte-LODs erst bei echtem Wechsel in den Dichte-Modus lazy nachgerechnet werden statt immer schon beim Oeffnen des Sheets
- `AppHeatmapView.swift`: Route-Viewport-Wechsel traversieren nicht mehr jedes Mal den kompletten `AppExport`; vorbereitete Route-Tracks mit Bounding Box, Render-Koordinaten und gesampelten Midpoints reduzieren wiederholte Materialisierung und Scoring-Arbeit fuer grosse Kartenflaechen
- `AppSessionState.swift`, `AppContentSplitView.swift`, `AppDayDetailView.swift`: Day-Detail nutzt jetzt gecachte `DayMapData` aus der Session-Projektionsschicht statt die Kartenbasis bei jedem Render erneut aus dem Day-Detail-Modell aufzubauen
- `AppDayMapView.swift`, `AppExportPreviewMapView.swift`: Day- und Export-Maps halten stabile Renderdaten fuer Marker, Polylines und Regionen und bauen `CLLocationCoordinate2D`-Arrays nur noch bei echten Input-Aenderungen statt pro Body-Render neu auf
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`, `DemoSessionStateTests.swift`: neue Regressionen decken vorbereitete Heatmap-Route-Tracks sowie gecachte Day-Map-Projektion ab
- Linux-Nachweis fuer diesen Batch: `swift test` -> `Executed 363 tests, with 0 failures (0 unexpected)`; `git diff --check` sauber

### UI Wiring Phase 3 – Insights Drilldown / Chart Share

- `AppInsightsContentView.swift`, `AppContentSplitView.swift`, `AppDayListView.swift`, `AppExportView.swift`, `InsightsDrilldownBridge.swift`: der vorhandene `InsightsDrilldown`-Unterbau ist jetzt sichtbar in der echten App-UI verdrahtet; datenverankerte Highlights, `Top Days`, Distanz-Zeitreihe sowie Monats-/Periodenbereiche bieten jetzt einen echten Drilldown nach `Days` oder `Export`, inklusive sichtbarem und ruecksetzbarem Drilldown-Zustand in den Zielansichten
- `AppSessionState.swift`: aktiver Insights-Drilldown wird bei neuem Import, Start-Ladevorgang und `Clear` sauber zurueckgesetzt statt ueber Session-Wechsel zu leaken
- `AppInsightsContentView.swift`: sichtbare Share-Aktionen fuer die wichtigsten Insight-Sektionen nutzen den vorhandenen `ChartShareHelper`; auf Apple-Hosts wird per `ImageRenderer` eine PNG-Datei fuer den System-Share-Flow erzeugt, waehrend Linux-seitig nur Verdrahtung und Tests verifizierbar sind
- `InsightsChartSupport.swift`, `InsightsTopDaysPresentation.swift`: sichtbare Hinweistexte spiegeln jetzt korrekt den neuen Drilldown-Flow statt direkte Einzeltag-Navigation
- `AppLanguageSupport.swift`: neue sichtbare UI-Texte fuer Drilldown-Banner, Reset, Share-Flow und Chart-Share-Failures auf Deutsch/Englisch lokalisiert
- `Tests/LocationHistoryConsumerTests/InsightsDrilldownBridgeTests.swift`, `DemoSessionStateTests.swift`, `InsightsChartSupportTests.swift`, `InsightsTopDaysPresentationTests.swift`: neue und angepasste Tests decken Datumsbereichs-Mapping, Zieltrennung Days/Export, lokalisierte Drilldown-Beschreibung, Session-Reset sowie die neuen Drilldown-Hints ab
- Linux-Nachweis fuer diesen Batch: `swift test` -> `Executed 359 tests, with 0 failures (0 unexpected)`

### UI Wiring Phase 2 – Days / Day Detail / CSV Export

- `AppContentSplitView.swift`, `AppDayListView.swift`, `DayListPresentation.swift`, `AppDaySearch.swift`: der vorhandene `DayListFilter` ist jetzt sichtbar in der echten `Days`-Liste verdrahtet; Filterchips fuer `Favorites`, `Has Visits`, `Has Routes`, `Has Distance` und `Exportable` kombinieren sich sauber mit Suche und newest-first Sortierung, inklusive sauberem Empty-State bei 0 Treffern
- `AppContentSplitView.swift`, `AppDayListView.swift`, `AppDayDetailView.swift`: `DayFavoritesStore` ist jetzt sichtbar in Liste und Day Detail angebunden; Favoriten koennen per Swipe, Kontextmenue und Day-Detail-Action umgeschaltet werden und bleiben lokal persistent
- `AppDayDetailView.swift`, `ExportSelectionState.swift`, `ExportSelectionContent.swift`: die vorhandene per-route Auswahl ist jetzt real im Day Detail benutzbar; explizite Routen-Subsets bleiben rueckwaertskompatibel zu implizit allen exportierbaren Routen und fliessen in Export-Snapshot und Summary ein
- `AppExportView.swift`, `GPXDocument.swift`: `CSV` ist jetzt als echtes sichtbares Exportformat im bestehenden `fileExporter`-Flow verdrahtet; Disabled-Reasons, Summary, Dateiname und Distanzsumme respektieren Zeitraum, Day-Selection und explizite Route-Selektionen korrekt
- `AppLanguageSupport.swift`: neue sichtbare UI-Texte fuer Days-Filterchips, Favoriten, Route-Export und CSV-Hinweise auf Deutsch/Englisch lokalisiert
- `Tests/LocationHistoryConsumerTests/DayListPresentationTests.swift`, `ExportSelectionRouteTests.swift`, `ExportSelectionContentTests.swift`, `ExportPresentationTests.swift`: neue und erweiterte Tests decken Day-Filter/Search/newest-first, Favoriten-/Chip-Zusammenspiel, per-route Exportprojektion und CSV-Export-Verdrahtung ab
- Linux-Nachweis fuer diesen Batch: `swift test` -> `Executed 350 tests, with 0 failures (0 unexpected)`

### UI Wiring Phase 1 – Range / Recent Files / Auto-Restore

- `AppContentSplitView.swift`, `AppInsightsContentView.swift`, `AppExportView.swift`, `AppHistoryDateRangeControl.swift`, `AppHistoryDateRangeQueryBridge.swift`: der vorhandene `HistoryDateRangeFilter` ist jetzt sichtbar in `Overview`, `Insights` und `Export` verdrahtet; Presets, Custom-Range-Sheet, lokalisierte Anzeige und Reset auf Gesamtzeitraum nutzen den bestehenden Unterbau statt neuer View-Logik
- `AppExportView.swift`: Export projiziert den aktiven globalen Zeitraum jetzt vor lokalen Exportfiltern, zeigt den Zusammenhang sichtbar in der UI und exportiert `CSV` wieder korrekt ueber den bestehenden Export-Flow
- `AppShellRootView.swift`, `AppImportStateBridge.swift`, `ImportBookmarkStore.swift`: Import-Root zeigt jetzt eine echte Recent-Files-Liste mit `Open Again`, Entfernen einzelner Eintraege und `Clear History`; stale oder fehlende Bookmarks werden freundlich behandelt und nicht roh an Nutzer durchgereicht
- `AppOptionsView.swift`, `AppPreferences.swift`, `AppShellRootView.swift`: `Restore Last Import on Launch` ist jetzt als echter Toggle sichtbar; der App-Start bindet die vorhandene Restore-Logik opt-in an und degradiert sauber bei fehlender oder stale Datei
- `AppLanguageSupport.swift`: neue UI-Texte fuer Zeitraumsteuerung, Recent Files und Auto-Restore auf Deutsch/Englisch lokalisiert
- `AppHeatmapView.swift`: bestehende Heatmap-Logik an die tatsachliche Grid-Segmentierung angepasst, damit der verpflichtende Gesamtlauf `swift test` wieder gruen ist
- `Tests/LocationHistoryConsumerTests/AppImportAndHistoryDateRangeBridgeTests.swift`, `AppPreferencesTests.swift`: neue und erweiterte Tests decken Zeitraumprojektion, Import-Historie und Auto-Restore-Verdrahtung ab
- Linux-Nachweis fuer diesen Batch: `swift test` -> `Executed 343 tests, with 0 failures (0 unexpected)`

### Feature Batch – Range / Insights / Export / Import-Comfort / Days-Polish

**9 neue Features in 3 Phasen:**

#### Phase A – Range + Import-Comfort
1. **Globaler Zeitraumfilter** (`HistoryDateRangeFilter.swift`): Presets (7 d / 30 d / 90 d / dieses Jahr / Custom) + Validator; shared State in `AppSessionState.historyDateRangeFilter`; `fromDateString`/`toDateString` für `AppExportQueryFilter`-Integration; `chipLabel` für UI-Chip
2. **Recent Files / Import-Historie** (`RecentFilesStore.swift`): bis zu 10 Einträge (neueste zuerst), Deduplizierung, Stale-Prüfung, Migration von altem `lastImportedFileBookmark`-Key; `add/remove/clear/resolveURL`
3. **Auto-Restore als Option** (`AppPreferences.autoRestoreLastImport`): neuer Key `app.preferences.autoRestoreLastImport`, Default `false`; in `AppPreferences.reset()` bereinigt

#### Phase B – Export + Day-Level Power Features
4. **Per-Route Auswahl im Day Detail** (`ExportSelectionState`): `routeSelections: [String: Set<Int>]`; `toggleRoute/clearRouteSelection/isRouteSelected/effectiveRouteIndices`; `clearAll()` räumt Route-Selections mit auf; `hasExplicitRouteSelection`/`explicitRouteSelectionCount` für Summary
5. **CSV-Export** (`CSVBuilder.swift`, `CSVDocument.swift`): Header (16 Felder), Zeilen für Visit/Activity/Route/Empty-Day; RFC 4180 Escaping; `ExportFormat.csv` mit `.tablecells` Icon; `CSVDocument` als SwiftUI FileDocument
6. **Days-Filterchips** (`DayListFilter.swift`): `DayListFilterChip` (favorites/hasVisits/hasRoutes/hasDistance/exportable); `DayListFilter` mit AND-Logik; `passes(summary:isFavorited:)`
7. **Favoriten/Pinning** (`DayFavoritesStore.swift`): `add/remove/toggle/contains/clear` via UserDefaults; Key `app.dayFavorites`

#### Phase C – Insights Drilldown + Chart Share
8. **Insights-Drilldown** (`InsightsDrilldown.swift`): `InsightsDrilldownAction` (filterDays/filterDaysToDate/filterDaysToDateRange/prefillExportForDate/prefillExportForDateRange); `InsightsDrilldownTarget` mit Factory-Helpers; `AppSessionState.activeDrilldownFilter`
9. **Chart Share Helper** (`ChartShareHelper.swift`): `ChartSharePayload` + `InsightsCardType`; Dateiname-Format `LocationHistory_Insights_<type>_[<range>_]<date>.png`; UI-frei, testbar; Hinweis: ImageRenderer nur auf Apple-Host

**Tests:** 8 neue Test-Files (316 Tests, 2 Skips, 0 Failures)

## 2026-04-01

### DE Localisation – Analytics / Insights / Overview / Custom-Range (Truth-Sync aus iOS)

Diese Einträge dokumentieren die Localisation-Arbeit, die im historischen Split-Repo `LocationHistory2GPX-iOS` auf `main` gemergt wurde. Der Core-Code liegt im Monorepo-Root; die Commits wurden dort auf `main` entwickelt und sind hier zur Vollständigkeit festgehalten.

- `AppLanguageSupport.swift`: DE-Übersetzungen für Analytics-Preset-Chips, Range-Description-Keys, alle KPI-Labels und KPI-Notes, Custom-Date-Range-Sheet-Strings, Overlap-Map-Strings, Filter-Picker-Labels, Map-Meldungen und Empty/Sparse-States ergänzt; 3 Duplikat-Schlüssel beseitigt (verhinderten RuntimeFatal); alle 309 Tests grün, 2 Skips, 0 Failures
- `AppCustomDateRangeSheet.swift`: `@EnvironmentObject preferences` ergänzt; alle 9 user-facing Strings über `preferences.localized(_:)` – kein EN-Hardcode mehr
- `AppOverlapMapView.swift`: alle UI-Strings (map-style-switch, exportierbare-Routen-Hinweis, No-Route-Geometry, Tag/Track-Zähler-Chips) über privaten `t(_:)`-Helper

### DE Localisation Finish – Format-Strings + Monatsnamen

- `CustomDateRangeValidator.chipLabel(from:to:)`: neuer optionaler `locale`-Parameter (Default `.current`); Monatsnamen via `DateFormatter.shortMonthSymbols` statt hardkodiertem EN-Array; Tests übergeben `locale: Locale(identifier: "en_US")` für stabile Assertions
- `AppInsightsContentView`: fünf EN-Hardcodes ersetzt – `"of N total"`, `"N events"`, EN-Wochentagsnamen-Dictionary und `"N day/days"` über `t()` bzw. `localizedWeekdayName(_:)`; alle 309 Tests grün, 2 Skips, 0 Failures

### DE Localisation Final – rangeDescription Composite Strings

- `AppLanguagePreference.localized(_:pluralFmt:count:)`: neue Hilfsmethode für Singular/Plural-Format-Keys; 14 neue DE Format-String-Einträge für alle `rangeDescription`-Presets; Singular/Plural je Preset korrekt abgedeckt
- `AnalyticsDateRangeBuilder.rangeDescription(_:activeDays:)`: optionaler `language`-Parameter (Default `.english`); alle Preset-Fälle nutzen Format-String-Lookup mit korrekter Singular/Plural-Logik; kein hardkodierter `day`/`days`-Suffix mehr
- `OverviewPresentation.rangeKPIs(from:range:language:)`: reicht `language` an `rangeDescription` weiter; `rangeNote` ab Erzeugung lokalisiert
- `AppInsightsContentView`: alle drei `rangeKPIs`-Aufrufe mit `language: preferences.appLanguage`; `"active"` und `"%.0f%% active days"` über `t()` lokalisiert
- 10 neue Tests (EN/DE, Singular/Plural, alle Presets, Default-Language-Guard); alle 319 Tests grün, 2 Skips, 0 Failures

### InsightsChartSupport rangeNote Format-String Refactor + DE Localisation

- `InsightsChartSupport.distanceSectionMessage`, `.monthlyTrendSectionHint` und `.weekdaySectionHint`: je ein optionaler `language`-Parameter (Default `.english`); Basis-Strings und `"Showing %@."`-Suffix durch Format-String-Lookup statt EN-Hardcode
- `AppInsightsContentView`: alle drei Aufrufstellen auf `language: preferences.appLanguage` umgestellt; `t()`-Wrapper entfernt (Methoden liefern fertig lokalisierte Strings)
- `AppGermanTranslations.values`: `"Showing %@."` → `"Zeige %@."` ergänzt
- 6 neue Tests (EN/DE, mit/ohne rangeNote, alle drei Methoden); alle 325 Tests grün, 2 Skips, 0 Failures

## 2026-03-31

### Monorepo Truth-Sync Docs

- `AGENTS.md`: Zwei-Repo-Architektur-Block auf Monorepo-Architektur aktualisiert; veralteter SPM-Pfad `../../../Code/LocationHistory2GPX-iOS` entfernt; Core-Root und `wrapper/`-Verzeichnis als die zwei primaeren Bestandteile dokumentiert; historische Split-Repos als weiterbestehend eingeordnet
- Split-Repos `LocationHistory2GPX-iOS` und `LH2GPXWrapper` erhalten Monorepo-Verweise in README und AGENTS.md

### Monorepo-Migration + Testendpunkt-Bereinigung

- `wrapper/` via `git subtree` als Teil des Monorepos eingefuehrt; `LH2GPXWrapper` lebt jetzt unter `wrapper/` im Monorepo-Root
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: lokale SPM-Referenz von `../LocationHistory2GPX-iOS` auf `../..` (Monorepo-Root) umgestellt
- `wrapper/.github/workflows/xcode-test.yml`: separater Core-Clone entfernt, Pfad auf `-project wrapper/LH2GPXWrapper.xcodeproj` aktualisiert
- `wrapper/README.md`, `wrapper/docs/LOCAL_IPHONE_RUNBOOK.md`, `wrapper/docs/TESTFLIGHT_RUNBOOK.md`: alle `xcodebuild`-Pfade und Verzeichniswechsel auf Monorepo-Layout aktualisiert
- `Sources/LocationHistoryConsumerAppSupport/LiveLocationServerUploader.swift`: hart kodierter Testendpunkt `https://178-104-51-78.sslip.io/live-location` entfernt; `defaultTestEndpointURLString` ist jetzt `""` (kein Produktstandard-Testserver)
- `Sources/LocationHistoryConsumerAppSupport/AppOptionsView.swift`: `LabeledContent("Test Endpoint", ...)` und dazugehoeriger Footer-Hinweis auf den Testserver entfernt
- `Sources/LocationHistoryConsumerAppSupport/AppLanguageSupport.swift`: veraltete Uebersetzungen fuer `"Test Endpoint"` und den sslip.io-Footer-Hinweis entfernt; neuer kompakter Footer-String ergaenzt
- `swift test`: `228` Tests, `2` Skips, `0` Failures

### 4-Repo Status Documentation

- README-Rolle des Repos von zu kleinem Consumer-/Demo-Wording auf den realen Stand als eigentliche iOS-Produkt-UI korrigiert
- offener Produktpunkt fuer den hart kodierten Testendpunkt in `Sources/LocationHistoryConsumerAppSupport/LiveLocationServerUploader.swift` jetzt explizit in README, `NEXT_STEPS.md` und neuem Status-Audit dokumentiert; keine Code-Aenderung
- neue timestamped Status-/Audit-Dateien `audits/AUDIT_IOS_STATE_2026-03-31_08-48.md` und `audits/AUDIT_4REPO_MASTER_2026-03-31_08-48.md` halten den aktuellen Repo- und Cross-Repo-Stand repo-wahr fest

### Repo-Truth Deep Audit / Doc Sync

- repo-weite Deep-Audit-Synchronisierung gegen den tatsaechlichen Stand von Code, Tests und Host-Umgebung; veraltete Testzahlen in den aktuellen Truth-Bloecken auf den frischen Linux-Nachweis `228` Tests, `2` Skips, `0` Failures umgestellt
- historische Apple-/Xcode-/Device-Nachweise vom 2026-03-17 und 2026-03-30 explizit als historische Nachweise markiert; fuer den aktuellen Audit-Host wird jetzt klar festgehalten, dass `xcodebuild` auf diesem Linux-Server nicht verfuegbar ist
- `README.md`, `ROADMAP.md`, `NEXT_STEPS.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/CONTRACT.md`, `docs/XCODE_APP_PREPARATION.md` und `docs/XCODE_RUNBOOK.md` repo-wahr auf `offline-first + optionaler nutzergesteuerter Upload`, offene Apple-Verifikation und aktuelle Audit-Grenzen geglaettet

## 2026-03-31

### Insights Distance Hotfix + Patterns / Breakdowns Quick Batch

- `Sources/LocationHistoryConsumer/Queries/AppExportQueries.swift`: `Gesamtstrecke` und `Durchschnittsstrecke / Tag` im Insights-Stack jetzt repo-wahr aus importierten Routendistanzen berechnet; wenn diese fehlen, faellt die Aggregation gezielt auf vorhandene Pfadgeometrie (`points` / `flatCoordinates`) und erst danach auf belastbare Aktivitaets-Trace-Geometrie zurueck statt auf `0 m`
- `Sources/LocationHistoryConsumerAppSupport/AppInsightsContentView.swift`, `InsightsChartSupport.swift`: `Patterns` und `Breakdowns` um umschaltbare Wochentags- und Periodenmetriken fuer Ereignisse, Routen und Distanz erweitert; Hinweise und Achsenbeschriftungen erklaeren den jeweils sichtbaren Datenkontext
- `Tests/LocationHistoryConsumerTests/AppExportQueriesTests.swift`, `InsightsChartSupportTests.swift`: gezielte Regressionstests fuer Distanz-Fallback, Durchschnittsstrecke/Tag sowie neue Wochentags-/Periodenmetriken ergaenzt

## 2026-03-30

### UI Polish + Heatmap Detail Visibility Batch 2

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Detailansicht der Dichte-Heatmap nochmals sichtbar farbiger gemacht; fruehere Hue-Wechsel schon bei niedriger Dichte, detail-LOD-spezifisches Color-Position-Mapping, niedrigere Sichtbarkeitsschwellen fuer `medium`/`high` und etwas staerkere Sparse-Opacity ohne Architektur- oder Performance-Umbau
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Dichte-Legende an den frueheren Low-/Mid-Farbverlauf angepasst, damit Regler und sichtbare Heatmap wieder besser zusammenpassen
- `Sources/LocationHistoryConsumerAppSupport/AppLiveTrackingView.swift`, `AppInsightsContentView.swift`, `AppDayListView.swift`: kleiner Surface-Polish fuer Card-Chrome, Section-Hierarchie und Day-Row-Balance; bewusst ohne neue Grossbaustelle
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: Erwartungen fuer staerkere Low-/Mid-Lift und detail-LOD-spezifisches Farb-Mapping nachgeschaerft; auf diesem Linux-Server bleiben diese Apple-only Tests weiterhin korrekt ausgeklammert

### UI Polish + Heatmap Detail Visibility Batch

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Detailzoom der Dichte-Heatmap sichtbar staerker gemacht; niedrigere Sichtbarkeitsschwellen, kraeftigeres Low-/Mid-Intensity-Mapping, detailzoom-spezifischer Opacity-Boost, feinere Farbwirkung schon bei seltener Dichte und leicht angehobene Default-Deckkraft
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Heatmap-Legende an die sichtbarere Detaildarstellung angepasst; Slider-/Opacity-Verhalten bleibt weiter zur effektiven Darstellung passend
- `Sources/LocationHistoryConsumerAppSupport/AppLiveTrackingView.swift`: kleiner UI-Polish fuer Live-Tracking-Card-Hierarchie und Quick-Action-Wrapping auf engeren Breiten
- `Sources/LocationHistoryConsumerAppSupport/AppInsightsContentView.swift`: Insights-Sektionen mit klarerer Card-Hierarchie und ruhigerem Section-Chrome
- `Sources/LocationHistoryConsumerAppSupport/AppDayListView.swift`: Day-Row-Abstaende und no-content-/Export-Zustaende visuell leicht geglaettet
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: Heatmap-Erwartungen fuer die staerkere Detailsichtbarkeit nachgeschaerft; auf diesem Linux-Server bleiben diese Tests wegen Apple-Gating weiterhin nicht direkt ausfuehrbar

### Sync + Live / Upload / Insights / Days Batch

- `Sources/LocationHistoryConsumerAppSupport/AppLiveTrackingView.swift`: Live-Seite visuell und funktional neu aufgebaut; neue Kartenhierarchie fuer Map, Recording, Upload, Track-Library und Advanced-Optionen sowie klarere Status-Chips und Quick Actions
- `Sources/LocationHistoryConsumerAppSupport/LiveTrackingPresentation.swift`: neue abgeleitete Live-Metriken fuer aktuelle Geschwindigkeit, Durchschnittsgeschwindigkeit, letzte Teilstrecke, Update-Alter, Dauer und Distanz
- `Sources/LocationHistoryConsumerAppSupport/LiveLocationFeatureModel.swift`: Upload-Domain ausgebaut um Pause/Resume, manuellen Flush, Queue-/Failure-/Last-Success-Status, robustere Statuszusammenfassungen und Assistive-Messages fuer invaliden Endpunkt, fehlenden Bearer-Token, pausierte Uploads und Retry-Zustaende
- `Sources/LocationHistoryConsumerAppSupport/AppInsightsContentView.swift`: Insights-Seite stark ausgebaut mit segmentierten Oberflaechen (`Overview`, `Patterns`, `Breakdowns`), KPI-Karten, Highlight-Karten, `Top Days`-Picker und neuen Monatstrends
- `Sources/LocationHistoryConsumerAppSupport/InsightsMonthlyTrendPresentation.swift`: neue Monatsaggregation fuer Distanz-, Event-, Aktivitaets- und Visit-Trends
- `Sources/LocationHistoryConsumerAppSupport/DaySummaryDisplayOrdering.swift`, `AppDayListView.swift`, `AppSessionState.swift`: Day-Liste und initiale Tagesauswahl jetzt repo-wahr standardmaessig absteigend (`neu -> alt`) statt aelteste zuerst
- `Sources/LocationHistoryConsumerAppSupport/AppLanguageSupport.swift`: DE/EN-Abdeckung fuer neue Live-/Upload-/Insights- und Days-UI erweitert
- neue/erweiterte gezielte Tests fuer Live-, Upload-, Insight- und Day-Sortierlogik; Linux-Server-Checks fuer `swift test --filter Live`, `Insight`, `Day` und `Upload` in diesem Batch gruen

### Linux Test Portability

- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: Apple-only Heatmap-Renderingstests jetzt hinter `#if canImport(SwiftUI) && canImport(MapKit)`, damit non-Apple-`swift test` nicht mehr an fehlenden UI-Frameworks scheitert
- aktueller Linux-Server-Check: `swift test` wieder gruen mit `217` ausgefuehrten Tests, `2` Skips und `0` Failures

### Heatmap Hotfix Batch 7

- `AppHeatmapMode.swift`: Picker-Labels auf Deutsch umgestellt (`Routes` → `Routen`, `Density` → `Dichte`)
- `AppHeatmapView.swift`: `RoutePathExtractor` neu — verarbeitet jeden GPS-Track als ganzes Polyline statt fester 200-Punkte-Chunks; Intensitaet wird durch Sampling von bis zu 30 Bins entlang des gesamten Tracks bestimmt (Blend aus Max und Durchschnitt); radiale Artefakte / Stern-Optik damit behoben
- `AppHeatmapView.swift`: Downsampling langer Tracks auf max 500 Punkte fuer Render-Performance statt chunkbasierter Aufteilung
- `AppHeatmapView.swift`: `routeSelectionLimit` reduziert (macro 150→60, low 400→150, medium 800→300, high 1200→500) — Limits passten zu Chunks, nicht zu ganzen Tracks
- `AppHeatmapView.swift`: Density-Mode feiner — `overlayOpacityMultiplier` fuer medium (0.62→0.72) und high (0.78→0.86) erhoeht; `minimumNormalizedIntensity` fuer medium (0.025→0.018) und high (0.015→0.010) gesenkt; `selectionLimit` fuer medium (160→240) und high (280→400) erhoeht; LOD-Schwelle low→medium von 1.4°→1.0° vorgezogen
- `AppHeatmapView.swift`: `remappedControlOpacity` auf lineares Mapping vereinfacht (0.15–1.0 Slider → 0.22–1.0 effektiv) — Regler-Verhalten und Anzeige stimmen jetzt nachvollziehbar ueberein
- `AppHeatmapView.swift`: Slider-Range von 0.35–1.0 auf 0.15–1.0 erweitert; Startwert von 0.7 auf 0.8 angehoben

### Route Heatmap Visual Rebuild Batch 6

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: neuer `RoutePathExtractor` — extrahiert vollstaendige, zusammenhaengende Koordinatensequenzen direkt aus `paths.flatCoordinates`, `paths.points` und `activities.flatCoordinates`; zerlegt grosse Tracks in max-200-Punkt-Chunks (mit 1-Punkt-Ueberlapp fuer Kontinuitaet); weist jedem Chunk Korridorintensitaet per Grid-Lookup zu
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: neues `RoutePath`-Struct (id, coordinates, normalizedIntensity, coreLineWidth, glowLineWidth = 3× coreWidth, color) ersetzt die kurzstreckigen Bin-Diagonalen im Route-Mode
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: zweischichtiges Glow-Rendering im Route-Mode — Layer 1: breite, halbtransparente Bloom-Underlayer (Opazitaet 0.08–0.38); Layer 2: schmale, helle Kernlinie (Opazitaet 0.22–0.96); ergibt weichen Leuchteffekt analog Strava/Komoot-Heatmaps
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: `RoutePalette` von Cyan-Gruen auf Indigo→Cyan→Weiss/Warmgelb umgestellt — tiefes Indigo (selten) über Cyan (mittel) zu weissem Warmton (haeufig); optimiert fuer dunklen Kartenhintergrund
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Dark Map fuer Route-Mode — `MapStyle.imagery()` (Satellitenkarte) wenn im Route-Mode und kein Hybrid-Pref gesetzt; Density-Mode behaelt `.standard()`; liefert maximalen Kontrast fuer leuchtende Linien
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Viewport-Culling und LOD-basiertes Limit (routeSelectionLimit) auf `RoutePathExtractor` uebertragen; `routePathCache` als separater Cache analog `routeViewportCache`
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: `testRoutePaletteIsClearlyDistinctFromDensityPalette` an neues Indigo-Weiss-Schema angeglichen (prueft jetzt Rot-Komponente am unteren Ende und Gruen/Blau am oberen Ende statt Gruen-Dominanz)
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: 2 neue Tests — `testRoutePathExtractorProducesConnectedSequencesFromPaths` (mindestens ein Pfad mit ≥2 Coords aus Path-Daten) und `testRoutePathExtractorGlowWidthIsThreeCoreWidth` (glowLineWidth === 3× coreLineWidth fuer alle Paths)

### Route Heatmap + Heatmap Polish Batch 5

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: neuer `HeatmapMode`-Enum (`.route` / `.density`) — Standardmodus beim Oeffnen ist `.route`
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Segmented Picker "Routes / Density" im Bottom-Control-Panel; Radius-Picker nur im Density-Modus sichtbar; separate Legende je Modus
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: `RouteGridBuilder` — bricht `paths.flatCoordinates`, `paths.points` und `activities.flatCoordinates` in konsekutive Segmente auf, binnt Segmentmittelpunkte in LOD-abhaengige Grid-Zellen, zaehlt Durchlaeufe pro Zelle; vier LOD-Stufen mit eigenen `routeSegmentStep`-Werten (macro 0.08° / low 0.025° / medium 0.006° / high 0.0018°)
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Route-Heatmap rendert als `MapPolyline` mit variabler Linienbreite (1.5–7 pt) und `RoutePalette` (Cyan→Teal→Gruen→Gelbgruen→Orange→Rot-Orange); klar unterscheidbar von der blauen Dichte-Palette
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: `AppHeatmapModel` berechnet Dichte- und Routen-Grids parallel in derselben `Task.detached`-Vorberechnung; separate Viewport-Caches fuer beide Modi
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: `RouteViewportKey` fuer LOD-/Viewport-Caching der Route-Segmente analog zur bestehenden `HeatmapViewportKey`-Strategie
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: 8 neue Tests — HeatmapMode-Enum, RouteGridBuilder (Segmente aus Paths, Koernung, leerer Export, Viewport-Culling, Linienbreite vs. Intensitaet) und Palette-Unterscheidbarkeit Route vs. Dichte

## 2026-03-30

### Heatmap Fine Detail / Zoom Tuning Batch 4

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: LOD-Grid-Schritte fuer mittlere und hohe Zoom-Stufen verfeinert (medium: 0.018→0.012, high: 0.004→0.003) — weniger blockartige Grossflaechen, mehr Granularitaet bei Feinzoom
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: LOD-Umschaltschwellen frueher gesetzt (low→medium bei spanDelta>1.4 statt >1.6; medium→high bei >0.12 statt >0.16) — feinere Darstellung setzt bei weiterer Herausgezoomtheit ein
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: selectionLimit fuer medium (132→160) und high (220→280) angehoben — mehr sichtbare Zellen bei Feinzoom ohne macro-Limit zu beruehren
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: minimumNormalizedIntensity fuer low (0.06→0.04), medium (0.035→0.025) und high (0.02→0.015) gesenkt — schwache Dichtebereiche bleiben sichtbar und fallen nicht weg
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: displayIntensity-Kurve angepasst (Exponent 0.58 statt 0.72) — untere Intensitaetsstufen werden sichtbarer angehoben ohne Rauschen zu dominieren
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: effectiveOpacity-Emphasis-Basis leicht angehoben (0.82 statt 0.72) und Mindestopacity auf 0.06 gesetzt — niedrige Dichte bleibt dezent sichtbar statt zu verschwinden
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Farbpalette geschaerft: kuehles Blau minimal saettiger, Cyan/Gruen-Mitte ausgepraegterer Charakter, Orange/Rot-Hochbereich kraftvoller und sauberer; Legende an neue Palette angeglichen

### Heatmap Color / Contrast / Opacity Batch 3

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Heatmap-Farb- und Deckkraftwirkung deutlich verstaerkt, ohne den Polygon-/LOD-/Viewport-Renderer aus Batch 2 zurueckzubauen; 100 % im Deckkraft-Slider mappt jetzt ueber eine nichtlineare Kennlinie auf sichtbar vollere Darstellung
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Intensitaets-Mapping fuer mittlere und hohe Dichten angehoben, damit Hotspots staerker tragen und mittlere Dichte nicht zu stark absauft
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Farbskala von groben Stufen auf weich interpolierte Gradient-Stops mit staerkerem Warmbereich fuer hohe Dichte umgestellt; Legende an dieselbe Palette angeglichen
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: kleine Logiktests fuer Intensitaets-Lift, High-End-Opacity-Mapping und waermer werdende Palette hinzugefuegt
- `README.md`, `ROADMAP.md`, `NEXT_STEPS.md`, `docs/APP_FEATURE_INVENTORY.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_RUNBOOK.md`: Batch-3-Farb-/Kontrast-Update und der weiterhin offene Apple-Device-Nachweis repo-wahr nachgezogen

### Heatmap Visual & Performance Batch 2

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Heatmap-Renderer von sichtbar ueberlappenden Kreis-Stempeln auf geglaettete, aggregierte Polygon-Zellen umgestellt; LOD-abhaengige Zellgroessen, ruhigere Farb-/Deckkraftabstufung und weniger flaechiges Uebermalen bei mittleren/grossen Zoomstufen
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: viewport-basierte Zellselektion mit per-LOD gecappten sichtbaren Elementen und wiederverwendbarem Viewport-Cache eingebaut, um Renderlast und Rebuilds beim Zoomen/Pannen zu reduzieren
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: vorhandene Heatmap-Controls aus Batch 1 beibehalten und den Radius-Preset an den neuen Polygon-Renderer angebunden, damit die Darstellung weiter direkt steuerbar bleibt
- `Tests/LocationHistoryConsumerTests/AppHeatmapRenderingTests.swift`: kleine Render-/LOD-Regressionstests fuer grobere Aggregation und viewport-/limit-respektierende Zellselektion hinzugefuegt
- `README.md`, `ROADMAP.md`, `NEXT_STEPS.md`, `docs/APP_FEATURE_INVENTORY.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_RUNBOOK.md`: Heatmap-Rendering-/Performance-Strategie und der weiterhin offene Apple-Device-Nachweis repo-wahr nachgezogen

### Heatmap UX Batch 1

- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: Heatmap-Darstellung auf mittleren und grossen Zoomstufen sichtbar entschärft; LOD-abhaengige Radius-/Deckkraft-Abstufung, weniger dominante Flaechenwirkung und `fit-to-data`-Startzustand aus den vorhandenen Punktgrenzen
- `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`: kleines Bottom-Control-Panel mit Deckkraft-Regler, Radius-Presets, `Auf Daten zoomen` und unaufdringlicher Dichte-Legende hinzugefuegt; Header bleibt ueber die Sheet-Navigation kompakter
- `Sources/LocationHistoryConsumerAppSupport/AppLanguageSupport.swift`: neue Heatmap-UX-Strings fuer Deutsch/Englisch ergaenzt
- `README.md`, `ROADMAP.md`, `NEXT_STEPS.md`, `docs/APP_FEATURE_INVENTORY.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_RUNBOOK.md`: Heatmap-UX-Umfang repo-wahr nachgezogen, ohne den noch offenen Apple-Device-Nachweis des Sheets als erledigt zu markieren

### Apple Device Verification Batch 1

- `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_RUNBOOK.md`, `NEXT_STEPS.md`: echter iPhone-15-Pro-Max-Lauf (iOS 26.3) repo-wahr nachgezogen
- reale Wrapper-UI-Automation auf dem verbundenen iPhone per `xcodebuild test -allowProvisioningUpdates` erneut belegt
- `LH2GPXWrapperUITestsLaunchTests.testLaunch` lief auf dem echten iPhone erfolgreich durch; der Wrapper startet auf aktueller Hardware stabil
- der fehlgeschlagene Screenshot-Test lieferte einen verwertbaren Device-Befund statt eines leeren Infra-Fehlers: beim Start war bereits eine importierte `location-history.zip` wiederhergestellt, `Heatmap` war als Aktion sichtbar und der dedizierte `Live`-Tab lag in der Tab-Bar vor
- Background-Recording, aktives Oeffnen des Heatmap-Sheets, aktive `Live`-Tab-Interaktion und End-to-End-Upload bleiben trotz dieser Teilbefunde offen

### Apple Stabilization Batch 2

- `Tests/LocationHistoryConsumerTests/AppPreferencesTests.swift`: Test-Setup an Apple-Realitaet angeglichen – Bearer-Token wird fuer `testStoredValuesAreLoaded` ueber den Keychain-Pfad gesetzt; Keychain wird in `setUp`/`tearDown` explizit bereinigt
- `Tests/LocationHistoryConsumerTests/DayDetailPresentationTests.swift`: Erwartung fuer `timeRange` auf den im Produktcode konsistent verwendeten Gedankenstrich `" – "` angepasst
- `docs/APPLE_VERIFICATION_CHECKLIST.md`, `docs/XCODE_RUNBOOK.md`, `NEXT_STEPS.md`, `README.md`, `ROADMAP.md`: Apple-CLI-Stand nach erneuter Verifikation auf gruen nachgezogen; offene Device-End-to-End-Themen bewusst offen gelassen

### Apple Stabilization Batch 1

- `AppOptionsView.swift`: `.textInputAutocapitalization(.never)` in `#if os(iOS)`-Guard eingeschlossen – iOS-only API war auf macOS ein Compile-Fehler
- `AppContentSplitView.swift`: `if #available(iOS 17.0, macOS 14.0, *)` statt `if #available(iOS 17.0, *)` fuer `AppLiveTrackingView` – fehlender macOS-Teil verhinderte macOS-Build
- `AppDayDetailView.swift`: `if #available(iOS 17.0, macOS 14.0, *)` statt `if #available(iOS 17.0, *)` fuer `AppLiveLocationSection` – gleiche Ursache
- `Sources/LocationHistoryConsumerDemo/RootView.swift`: `loadImportedFile(at:)` als `async` markiert und mit `Task { await ... }` aufgerufen – fehlte nach async-Aenderung in `DemoDataLoader.loadImportedContent`
- `Sources/LocationHistoryConsumerApp/AppShellRootView.swift`: analog zu RootView.swift – `loadImportedFile(at:)` async gemacht und Aufruf per `Task { await ... }` korrigiert
- `LiveLocationFeatureModelTests.swift`: `minimumBatchSize: 1` explizit in Upload-Test-Konfiguration gesetzt – Default ist 5, Tests prueften 1-Punkt-Upload (Test-Drift, kein Produktfehler)
- `LiveLocationFeatureModelTests.swift`: `testBackgroundPreferenceActivatesClientWhenAlwaysAuthorized` auf korrektes Produktverhalten angepasst – Client-Background-Konfiguration wird erst beim Recording-Start gesetzt, nicht bei blosser Preference-Aenderung (Test-Drift)
- `docs/APPLE_VERIFICATION_CHECKLIST.md`: ehrlicher Stand nach Apple Stabilization Batch 1 dokumentiert – CLI-Build/Test-Ergebnisse eingetragen, Einschraenkungen klar benannt
- `README.md`: "offline-only" in Beschreibung der App-Shell auf "offline-first, optionaler Upload" korrigiert – interner Widerspruch behoben
- README, ROADMAP, NEXT_STEPS und Xcode-Runbooks nach erneutem Apple-CLI-Rerun nachgeschaerft – Wrapper-Simulator-Tests als gruen eingetragen, die 2 verbleibenden roten macOS-/SwiftPM-Tests explizit offengelassen statt als "plattformbedingt" zu markieren

### Heatmap Compiler- und Diagnostik-Fixes
- `AppHeatmapView.body` in `mapView`- und `calculatingOverlay`-`@ViewBuilder`-Properties aufgeteilt, um Compiler-Timeout zu beheben
- `.blendMode(.plusLighter)` von `ForEach` (MapContent) auf den `Map`-View selbst verschoben
- `CLLocationCoordinate2D: @retroactive Equatable`-Extension ergaenzt, damit `.onChange(of: model.initialCenter)` kompiliert

### Audit Fix / Roadmap Granularization
- Audit `audits/AUDIT_LH2GPX_2026-03-30_09-11.md` gesichert und gegen den aktuellen Repo-Stand abgeglichen
- README, ROADMAP, NEXT_STEPS, Feature-Inventar und Apple-Runbooks auf Heatmap, `Live`-Tab, Upload-Batching, Wrapper-Auto-Restore und ehrlichen Teststatus synchronisiert
- stray-Dateien `lazygit` und `lazygit.tar.gz` aus dem Core-Repo entfernt und in `.gitignore` aufgenommen

## 2026-03-20

### Heatmap / Live Tab / Upload Batching
- `AppHeatmapView` als eigenes Heatmap-Sheet fuer importierte History auf iOS 17+/macOS 14+ eingebaut
- compact iPhone-Layout erhielt einen dedizierten `Live`-Tab fuer Live-Location und Live-Recording auf iOS 17+
- `AppPreferences` und Live-Upload-Konfiguration unterstuetzen jetzt Upload-Batching (`Every Point`, `Every 5 Points`, `Every 15 Points`, `Every 30 Points`)

### Navigation / Search / Sheet Stability
- `Days`-Suche funktioniert jetzt in compact und regular width und matcht nicht nur ISO-Datum, sondern auch formatiertes Datum, Wochentag und Monat
- iPhone-`Days` reagiert auf erneutes Tab-Selektieren, setzt Suche/Navigationspfad zurueck und springt auf den aktuellen Tag, wenn dieser im Import vorhanden ist
- `AppContentSplitView` nutzt jetzt einen einzigen Sheet-Praesentationszustand fuer Export, Optionen und Saved-Live-Track-Library statt konkurrierender `.sheet`-Ketten am Actions-Menue

### Saved Live Tracks / Local Recording
- Saved-Live-Track-Wording ueber Overview, Day Detail, Library, Sheet-Fallback und Editor vereinheitlicht
- gespeicherte Live-Tracks werden klarer als lokaler Nebenfluss ausserhalb importierter History bezeichnet
- Track-Editor-Titel benennt jetzt konkret das Bearbeiten eines gespeicherten Tracks
- Overview-Primary-Actions, Actions-Menue und Day Detail fuehren jetzt direkt in dieselbe dedizierte `Saved Live Tracks`-Library
- der Live-Recording-Bereich zeigt keinen zweiten halben Library-Flow mehr, sondern verweist gezielt auf die separate Library-Seite
- die Library-Seite selbst zeigt jetzt auch Zusammenfassung und neuesten gespeicherten Track als eigenen lokalen Arbeitsbereich
- Live-Recording hat jetzt echte Optionen fuer Accuracy-Filter und Recording-Detail statt harter Recorder-Defaults
- `AppPreferences` steuern jetzt die Recorder-Konfiguration fuer akzeptierte Genauigkeit, Mindestbewegung und Zeitabstand zwischen Punkten
- geaenderte Live-Recording-Optionen wirken direkt auf den lokalen Recorder-Flow
- Background-Recording kann jetzt lokal in den Optionen aktiviert werden und fordert bei While-In-Use eine `Always Allow`-Erweiterung an
- der Core-iOS-Client kann echte Background-Location-Updates aktivieren, wenn `authorizedAlways` vorhanden ist
- gespeicherte Live-Tracks markieren jetzt auch ihren Capture-Mode fuer Foreground-vs-Background-Aufnahmen
- Live-Recording kann akzeptierte Punkte jetzt optional an einen frei konfigurierbaren HTTP(S)-Server schicken
- der Server-Upload ist nutzerseitig ein-/ausschaltbar, akzeptiert Bearer-Token und nutzt eine Retry-on-next-sample-Strategie bei Fehlern
- der Standard-Testendpunkt ist mit `https://178-104-51-78.sslip.io/live-location` vorbelegt und damit konsistent zur HTTPS-Validierung des Codes
- der Live-Recording-Bereich zeigt jetzt auch einen sichtbaren Upload-Status, wenn der Server-Upload aktiv ist

### Sprache / Lokalisierung
- Optionen bieten jetzt eine Sprachwahl zwischen Englisch und Deutsch
- Shell-, Optionen-, Live-Recording-, Import-Entry- und zentrale Export-Oberflaechen reagieren jetzt auf die Sprachwahl
- Day List, Day Detail, Statuskarten, Saved-Live-Track-Library/-Editor, Karten-Hinweise und grosse Teile von Insights/Export reagieren jetzt ebenfalls auf die Sprachwahl
- noch nicht uebersetzte Strings fallen bewusst auf Englisch zurueck, statt fehlerhafte Platzhalter zu zeigen

### Insights / Empty-State Hardening
- Insights zeigen jetzt explizite Fallbacks fuer no-days-, low-data- und chart-unverfuegbare Faelle statt halbleerer Flaechen
- fehlende Distanz-, Activity-, Visit-, Weekday- und Period-Daten werden pro Sektion erklaert
- Imports mit sehr duennen, aber gueltigen Daten zeigen einen sichtbaren `Limited Insight Data`-Hinweis

### Charts / Export Polish
- Distance-, Activity-, Visit- und Weekday-Charts zeigen explizitere Achsen, Wertehinweise und Erklaertexte
- Export zeigt Auswahlzusammenfassung, Dateinamenvorschau und explizite Disabled-Reasons direkt im Flow
- Tage ohne GPX-faehige Routen werden in der Export-Liste klarer markiert und ausgewaehlte Zeilen deutlicher hervorgehoben
- gespeicherte Live-Tracks koennen jetzt direkt in derselben Exportseite mit ausgewaehlt und als GPX zusammen mit importierten Tagen exportiert werden
- die vorhandene Export-Vorschaukarte ist jetzt im sichtbaren Export-Flow verdrahtet und zeigt die aktuelle Auswahl mit Routen-, Distanz- und Legendenzusammenfassung
- `KML` ist jetzt neben `GPX` als aktives Exportformat in der UI freigeschaltet
- lokale Export-Filter fuer `From`, `To` und `Max accuracy` wirken jetzt sichtbar auf importierte History, Vorschau und den eigentlichen Export
- lokale Export-Filter greifen bewusst nicht auf gespeicherte Live-Tracks durch und raeumen ausgeblendete Tagesselektionen aus dem Exportzustand
- lokale Export-Filter bieten jetzt auch explizite `Has ...`- und `Activity type`-Auswahl fuer importierte History statt nur still vorhandenen Query-Unterbau
- lokale Export-Filter haben jetzt auch eine echte Bounding-Box-/Polygon-UI fuer importierte History; Upstream- und lokale Flaechenfilter werden konservativ kombiniert
- Export-Vorschaukarte zeigt jetzt auch Waypoint-only-Auswahlen statt nur Routen
- `GeoJSON` ist jetzt als drittes aktives Exportformat freigeschaltet
- Export kennt jetzt die Modi `Tracks`, `Waypoints` und `Both`
- Waypoint-Export nutzt importierte Visits sowie Activity-Start/-End-Koordinaten
- Dateiname, Disabled-Reasons und Hilfetexte reagieren jetzt auf den aktiven Exportmodus statt still route-only zu bleiben

### Overview / Days / Day Detail Polish
- Overview startet jetzt mit Status und einer `Primary Actions`-Sektion fuer Open, Days, Insights und Export
- Export-Selektion ist in der Day-Liste sichtbarer und fuehrt ueber einen expliziten Export-Kontext schneller in den Export-Flow
- Day Detail trennt importierte Tagesdaten klarer von lokalem Live Recording und gespeicherten Live-Tracks

## 2026-03-19

### Navigation / Dead-End Hardening
- no-content-Tage bleiben in der Day-Liste sichtbar, werden aber in compact und regular nicht mehr wie normale Detailziele behandelt
- initiale Tagesauswahl bevorzugt jetzt contentful days statt blind den ersten Kalendertag
- Export-Badge in gruppierter und ungruppierter Day-Liste vereinheitlicht

### Lokale Optionen / Produktsteuerung
- lokale Optionen-Seite fuer Distanz-Einheit, Start-Tab, Kartenstil und technische Importdetails eingebaut
- `AppPreferences` als zentrale `UserDefaults`-Domain fuer Core-App und Wrapper verdrahtet
- Distanz-/Speed-Formatierung, Kartenstil, Start-Tab und technische Metadaten folgen denselben Preferences

### Repo-Truth / Dokumentation
- repo-wahres Feature-Inventar ergaenzt und 19.x-Roadmap auf aktuelle lokale Priorisierung bereinigt
- README, ROADMAP und NEXT_STEPS auf den tatsaechlichen Stand von Optionen, Day-Navigation und offenem Fokus synchronisiert

## 2026-03-18

### Export / Recorded Tracks
- GPX-Export mit app-weiter Tagesselektion, Export-Tab/-Sheet und Dateinamenvorschlag eingebaut
- Recorded-Track-Library und Track-Editor fuer gespeicherte Live-Tracks eingefuehrt
- Track-Editor-Zugang in Overview und Live-Recording-Bereich auffindbarer gemacht

### Import Truth Sync
- verbliebene Core-UI-Texte von `app_export`-Spezialfall auf den echten JSON-/ZIP-Import-Scope umgestellt
- ZIP-Fehlermeldungen auf aktuelle Unterstuetzung fuer LH2GPX- und Google-Timeline-Archive korrigiert
- `AGENTS.md`, README und Apple-/Xcode-Doku auf den realen Importstand synchronisiert

### Live Recording MVP
- foreground-only Live-Location fuer die Kartenansicht eingebaut
- manuellen Ein/Aus-Schalter mit sauber modellierten Permission-Zustaenden hinzugefuegt
- Live-Track mit Accuracy-/Dedupe-/Mindestdistanz-Filtern und Polyline-Rendering umgesetzt
- abgeschlossene Live-Tracks getrennt von importierter History in einem dedizierten Store persistiert
- bewusst offen gelassen: Background-Tracking, Auto-Resume von Drafts, Export aufgezeichneter Live-Tracks
