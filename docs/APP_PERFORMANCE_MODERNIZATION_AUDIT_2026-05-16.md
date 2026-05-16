# App Performance Modernization Audit — 2026-05-16

> **Update 2026-05-16 (Train H-Wire-1):** `LiveTrackRenderCap` (in Train H als pure Logic gelandet) ist jetzt in `AppLiveTrackingView.refreshTrackPresentationState()` verdrahtet. Default-Cap **10 000 Punkte (ON)** über `private static let liveRenderPointCap` — konsistent mit dem bestehenden `uploadQueueLimit = 10_000` mental model. Wirkt ausschließlich auf View-State (`@State polylineCoordinates`, `@State trackSamples`); `liveLocation.liveTrackPoints` (Rohdaten), `LiveTrackRecorder`-Persistence und `RecordedTrack`-Export sind unverändert. Erste + letzte Position immer erhalten. Quieter DE/EN-Hinweis nur bei tatsächlich gekapptem Track. Linux `swift test` **1475 / 2 Skips / 0 Failures** (+6 neue `LiveRenderCapWiringTests`). Realer iOS-Frame-Time-Effekt nur am Gerät mit Instruments verifizierbar.
>
> **Update 2026-05-16 (Train H — App Performance / Stability / UX Hardening):** 4 produktive Commits (`a741b76`, `254875a`, `86b3da6`, `7288a5f`):
>
> - 12× iOS-16-`@available`-Attribute entfernt (durch iOS-17-Minimum redundant). 11× `if #available(iOS 16.x, *)`-Runtime-Checks bewusst nicht angefasst (Dedenting-Risiko, separater Cleanup).
> - `CSVBuilder.build` ruft jetzt `reserveCapacity` aus einem schnellen visits+activities+paths-Zähllauf pro Tag (vorher Outlier; GPX/KML/GeoJSON hatten es schon).
> - `LocalTimelineStore` setzt zusätzlich `PRAGMA journal_size_limit = 16777216;` und `PRAGMA wal_autocheckpoint = 1000;` (WAL-Wachstum gekappt, Default-Checkpoint explizit). `mmap_size` bewusst nicht gesetzt (iOS-Sandbox-Verhalten Linux-nicht-prüfbar).
> - Neuer Helper `LiveTrackRenderCap` mit reiner `apply(points:cap:)`-Funktion (Foundation-only, 10 Linux-Tests, deterministisch). Hält `cap/2` neueste Punkte verbatim + stride-dezimiert die ältere Hälfte; erste + letzte Position immer erhalten. **Bewusst noch nicht in `AppLiveTrackingView` verdrahtet** — Device-Validierung der Cap-Werte + UX-Hinweis-String sind Folge-Train H-Wire-1.
>
> Übersprungen mit Begründung: Identity B2 (Items haben keine garantiert uniquen IDs — Composite-Key-Migration würde Duplikat-ID-Warnungen riskieren), Heatmap-Debounce (`AppHeatmapView` nutzt bereits `.onMapCameraChange(frequency: .onEnd)`, zusätzlicher 100 ms-Debounce wäre nur Verzögerung), UX-Polish (an Live-Cap-Wiring gekoppelt).
>
> Linux `swift test` 1469/2/0 (+10 neue `LiveTrackRenderCapTests`). Build 175 enthält **keinen** Train-H-Commit; neuer Cloud-Build nötig.
>
> **Update 2026-05-16 (Train G1 — Befund: bereits migriert):** `rg "coordinateRegion:|annotationItems:|MapMarker|MapAnnotation\("` repo-weit **0 Treffer**. Alle 8 SwiftUI-`Map(...)`-Surfaces (DayMap, LiveTracking 2×, RecordedTrackEditor 2×, LiveLocationSection, Heatmap, OverviewTracksMapView 2×, ExportPreview) nutzen bereits `Map(position: $mapPosition) { MapContent }` mit `MapCameraPosition`, `Marker`, `Annotation`, `MapPolyline`. Die in der iOS-17-Decision-Matrix als „lebt weiter, falls noch genutzt" aufgeführten deprecated SwiftUI-Map-Initializer waren tatsächlich bereits in einer früheren Phase abgelöst worden. **Keine Code-Migration in G1 nötig** — nur diese Audit-Korrektur. MKMapView-Bridge / MKTileOverlay-Heatmap (UIKit-Pfad) bleiben als separate Hotspots (Mac/Instruments-only) bestehen. Linux `swift test` unverändert 1459/2/0.
>
> **Update 2026-05-16 (iOS-17-Deprecation-Fix + Build-174 extern bestätigt):** Xcode Cloud Build **174** (Workflow `Release – Archive & TestFlight`, letzter Commit `92dc447`) grün; TestFlight zeigt `LH2GPX 1.0.2 (174)`, App-Info „Erfordert iOS 17.0 oder neuer". Build-Nummer 174 aus `CI_BUILD_NUMBER`, Repo-`CURRENT_PROJECT_VERSION` bleibt 171. Im Build 174 gemeldete `onChange(of:perform:)`-Warnung (`ContentView.swift:125`) behoben + 23 weitere single-arg `onChange`-Stellen repo-weit auf Zwei-Parameter-Form migriert (24 Stellen total, semantik-exakt). Linux `swift test` 1459/2/0. Keine App-Review-Aussage, kein Hardware-Retest.
>
> **Update 2026-05-16 (Train F umgesetzt):** iOS-Deployment-Target im Cores (`Package.swift .iOS(.v17)`) und im Wrapper-pbxproj (alle 6 `IPHONEOS_DEPLOYMENT_TARGET = 17.0`) konsistent angehoben. `macOS(.v13)` unverändert. Marketing-Version + Build unverändert (`1.0.2 / 171`). `@available`-Gates bewusst nicht abgebaut. Damit ist die in §4 als Option 3 empfohlene Vorbereitung übersprungen — Repo geht direkt auf **Option 2 (iOS 17)**. Linux `swift test` 1459/2/0. Mac/Xcode-Cloud-Smoke + ASC-Reichweiten-Check extern Pflicht (siehe CHANGELOG).
>
> **Update 2026-05-16 (Train E1 umgesetzt):** `KMZBuilder` schreibt nun direkt in einen In-Memory-`Archive(accessMode: .create)` (ZIPFoundation `Archive(data:, accessMode:)` + `archive.data`). Damit entfällt das Temp-File-Roundtrip (`temporaryDirectory.appendingPathComponent(UUID...kmz)` + `Data(contentsOf:)`) komplett. **Code-Truth:** 1× Temp-Write + 1× Temp-Read entfernt; 1× UTF-8-KML-Buffer + 1× Zip-Buffer bleiben. iOS-Peak-RSS-Effekt nur am Gerät mit Instruments verifizierbar. Tests 1459/2/0. Hotspot E1 in §5/§6 damit **erledigt**.
>
> **Scope:** Repo-weite Performance-/Stabilitäts-/Speicher-/Rendering-Tiefenanalyse für die LH2GPX iOS-App (Core + Wrapper). Plus formale iOS-17-Deployment-Target-Entscheidung. **Audit-Train: keine produktive Code-Änderung.** Tests bleiben grün (1459/2/0).
>
> **Start-HEAD:** `1a4d859` (`perf: stabilize swiftui identity surfaces`).
> **Branch:** `main`.
> **Linux-Verifikation:** Swift 6.3.2 via swiftly, `libsqlite3-dev`. `swift build` clean, `swift test` 1459 / 2 Skips / 0 Failures, ~54 s.

---

## 1. Geprüfte Bereiche und Dateien

**Sources (App-Support + Core):** `AppOverviewTracksMapView`, `AppDayMapView`, `AppHeatmap*`, `AppLiveTrackingView`, `AppExportPreviewMapView`, `LocalTimelineDayMapView`, `AppInsightsContentView`, `AppContentSplitView`, `AppDayDetailView`, `AppRecordedTrackEditorView`, `AppRecordedTracksLibraryView`, `AppLiveLocationSection`, `LHExportComponents`, `KMZBuilder`, `GPXBuilder`, `KMLBuilder`, `CSVBuilder`, `GeoJSONBuilder`, `GoogleTimelineConverter`, `GoogleTimelineStreamReader`, `AppContentLoader`, `LocalTimelineStore`, `LocalTimelineFileAttributes`, `TrackingAttributes`, `ActivityManager`, `LiveLocationFeatureModel`, `LiveLocationServerUploader`, `AppPreferences`, `HeatmapGridBuilder`, `AppHeatmapModel`.

**Build / Project:** `Package.swift`, `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`.

**Doku-Quellen:** `docs/MAPKIT_PERFORMANCE_AUDIT_2026-05-16.md`, `docs/MAPKIT_AZ_AUDIT_2026-05-13.md`, `docs/PERFORMANCE_DEEP_AUDIT_2026-05-12.md`, `docs/DEEP_AUDIT_2026-05-13_CLAUDE.md`, `docs/MAP_ARCHITECTURE_AUDIT.md`, `docs/APP_FEATURE_INVENTORY.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md`, `CHANGELOG.md`, `NEXT_STEPS.md`, `ROADMAP.md`, `wrapper/docs/TESTFLIGHT_RUNBOOK.md`.

---

## 2. Apple-Dokumentationsquellen

Es wurden ausschließlich offizielle Apple-Quellen als Primärbeleg betrachtet. URLs sind als von Apple gepflegte Pfade (`developer.apple.com/...`) zu verstehen; eine Live-Verifikation der Seiten ist auf der Linux-Build-Umgebung nicht möglich. Vor jeder Deployment-Target-Entscheidung muss `developer.apple.com/support/app-store/` zur aktuellen Verteilung abgerufen werden.

| Quelle | Kernregel für diese App |
|---|---|
| _Improving your app's performance_ | Instruments (Time Profiler, Allocations, Hangs) ist die Wahrheits-Quelle; vor jeder Optimierung messen, on-device, nicht Simulator. |
| _Demystify SwiftUI performance_ (WWDC23 / 10160) | Zwei Hebel dominieren: stabile Identität und enge Dependency-Scopes; `AnyView` und überweite `ObservableObject`-Scopes vermeiden. |
| _MapKit for SwiftUI_ (Map / MapContentBuilder / Marker / Annotation / MapPolyline / UserAnnotation / MapCameraPosition) | Ab iOS 17 ist `Map(position:) { MapContent }` die deklarative Form; `Map(coordinateRegion:)` und `annotationItems:` sind in iOS 17 deprecated. |
| _ActivityKit_ + HIG _Live Activities_ | ActivityKit min. iOS 16.1, Dynamic Island min. iOS 16.2 + iPhone 14 Pro+; APNs-Topic `liveactivity` für Push-Updates. |
| _Reducing your app's memory use_ | Extension-Targets haben harte Speicher-Budgets; Allocations + VM Tracker zur Regressions-Erkennung; Image-Caches und MapKit-Tile-Cache sind übliche Verdächtige. |
| _Reducing your app's launch time_ | Non-UI-Arbeit aus `App.init` und `application(_:didFinishLaunching…)` verschieben; Instruments _App Launch_ Template. |
| _Map_ (UIKit-Bridge / MKMapView / MKMultiPolyline / MKTileOverlay) | UIKit-Bridge bleibt für sehr große Polyline-/Tile-Volumina relevant; SwiftUI-`Map` ist für die Skalierungen dieser App im Normalfall ausreichend, Skalierungs-Spike bleibt offen (siehe Mac-only Train). |

**Was Linux nicht verifizieren kann:** iOS-Versions-Share, Instruments-Profile, ActivityKit-Runtime-Verhalten, MapKit-Render-Cost, MKTileOverlay-Hardwareverhalten. Diese Themen sind als _Mac/Device-only_ markiert.

---

## 3. Aktueller Stand (Repo-Truth)

- **Versionen:** `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171` (8 pbxproj-Configs + Info.plist App/Widget konsistent).
- **Deployment Target:** Package.swift `.iOS(.v16)`. Xcode pbxproj: 6× `IPHONEOS_DEPLOYMENT_TARGET = 16.0` und 2× `16.2` (Widget/Live-Activity).
- **Availability-Gates im Source:** **28× `@available(iOS 17, *)` oder `if #available(iOS 17, *)`**, **9× iOS 16.2**.
- **Performance-Baselines (Train A, 2026-05-16):** PathSimplification, PathFilter, Export-Builder (GPX/KML/CSV/GeoJSON), GoogleTimeline-Stream (5k + 10k). Alle Linux-portabel, kein Fail-Bar, Drift-Erkennung über Median.
- **SwiftUI-Identity (Train B1, 2026-05-16):** 3 Hotspots in `AppInsightsContentView` umgesetzt (`activityBreakdown`, `visitTypeBreakdown`, `periodBreakdown`).
- **Test-Stand:** Linux `swift test` 1459 / 2 Skips / 0 Failures, ~54 s.

---

## 4. Deployment-Target-Entscheidungsmatrix

### Option 1 — iOS 16 behalten (Status quo)

- **Vorteile:** Kein Migrationsaufwand, kein Reichweiten-Risiko, alle bisherigen TestFlight-Tester bleiben kompatibel.
- **Nachteile:** 28 iOS-17-Availability-Gates + 9 iOS-16.2-Gates bleiben als kognitive Last und Code-Komplexität. **Korrektur 2026-05-16 (Train G1):** `Map(coordinateRegion:)` und `Map(annotationItems:)` sind im Repo **nicht** mehr in Verwendung (repo-weiter `rg`: 0 Treffer); alle 8 `Map`-Surfaces (DayMap, LiveTracking, RecordedTrackEditor, LiveLocationSection, Heatmap, OverviewTracksMapView 2×, ExportPreview) nutzen bereits `Map(position: $mapPosition) { MapContent }` mit `MapCameraPosition` plus `Marker` / `Annotation` / `MapPolyline`. Die deprecated-API-Migration ist bereits abgeschlossen, vermutlich in einer früheren Phase vor diesem Audit. `@Observable` aus iOS 17 (Observation-Framework) bleibt unzugänglich.
- **Performance-Auswirkung:** Neutral; SwiftUI-`Map` läuft auf iOS 16 mit eingeschränkterem MapContentBuilder.
- **Wartungsaufwand:** Mittel — duale Pfade müssen weiter gepflegt werden.

### Option 2 — iOS 17 als Minimum (Anhebung)

- **Konkrete Vorteile für diese App:**
  - MapKit-/SwiftUI-Verflechtung deutlich kleiner: `Map(position:)`, `MapPolyline`, `Marker`, `Annotation`, `UserAnnotation`, `MapCameraPosition`, `.mapStyle`, `.mapControls` unconditional → **28 Gates entfallen**.
  - Observation-Framework (`@Observable`) ermöglicht feinkörnigeres Invalidierungs-Diffing — potentieller, aber **unmeasured** Gewinn in Insights/Day-Detail-Views.
  - ScrollView-Erweiterungen (`.scrollPosition(id:)`, `.scrollTargetBehavior`, `.containerRelativeFrame`, `.scrollTransition`, `.scrollClipDisabled`) für künftige Listen-/Detail-Polish.
  - `ContentUnavailableView`, `.symbolEffect`, `PhaseAnimator`, `KeyframeAnimator`, `.sensoryFeedback` als optionale UX-Hebel.
  - `.onChange(of:) { old, new in }` (Zwei-Parameter-Form) — verbessert Lesbarkeit der bestehenden 10 `.onChange`-Cluster.
  - 9 iOS-16.2-Gates für ActivityKit/Dynamic-Island entfallen (17 > 16.2).
- **Entfernbare Kompatibilitätszweige:** 37 in Summe (28 + 9).
- **Betroffene Dateien (vollständige Liste, repo-truth):**
  - `Package.swift` (`.iOS(.v16)` → `.iOS(.v17)`).
  - `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj` (8 Konfigurationen — `IPHONEOS_DEPLOYMENT_TARGET = 16.0` und `16.2` → `17.0`).
  - 28 Quelldateien mit `@available(iOS 17, *)` / `if #available(iOS 17, *)`.
  - 9 Quelldateien mit `@available(iOS 16.2, *)`.
  - `README.md`, `wrapper/README.md`, `docs/XCODE_APP_PREPARATION.md`, `docs/XCODE_CLOUD_RUNBOOK.md`, `wrapper/docs/TESTFLIGHT_RUNBOOK.md`, `docs/APPLE_VERIFICATION_CHECKLIST.md` müssen synchron auf iOS 17 referenzieren.
- **Risiken:**
  - TestFlight-/App-Store-Nutzer auf iOS 16 erhalten keine neuen Updates. Apple liefert ihnen automatisch die zuletzt kompatible Version aus (App-Store-Fallback) — kein Brick-Risiko, aber Coverage-Verlust.
  - Reichweite auf iOS 16 im Mid-2026 vermutlich klein, aber **unverified** ohne aktuelle `developer.apple.com/support/app-store/`-Daten.
  - Apple-Review könnte Re-Submission verlangen (kein App-Store-blocker, aber organisatorisch).
- **Test-/Release-Aufwand:**
  - Linux `swift test` — bleibt grün, Gates fallen weg.
  - Sim-Build: `BUILD SUCCEEDED` zu prüfen auf iOS 17/18-Simulator.
  - Device-Build auf realem iOS-17-Gerät: Live-Activity, Dynamic Island, Map-Surfaces, Heatmap, Export.
  - TestFlight-Upload `1.0.3 (172)` oder höher; bestehender 1.0.2 (171)-Stand bleibt für iOS-16-Nutzer.
- **Rückfallplan:** `git revert` der DeploymentBump-Commit + erneuter Build `1.0.3 (173)` mit iOS 16. Verlust ist gering, da iOS-17-only Pfade nicht produktiv neu eingeführt würden, nur Gates entfernt.

### Option 3 — iOS 17 vorbereiten, aber **nicht** in diesem Train anheben (empfohlen)

- **Zwischenlösung:**
  - Audit ist abgeschlossen (dieses Dokument), Migrationspfad ist klar.
  - Kein Code-Eingriff. Kein Versions-Bump.
  - Vor der eigentlichen Anhebung: aktuelle `developer.apple.com/support/app-store/`-Daten prüfen.
- **Empfohlene Reihenfolge wenn iOS 17 angehoben wird:**
  1. Doku-Update + Package.swift + pbxproj in einem Commit.
  2. Schrittweises Entfernen der 28 + 9 Availability-Gates pro Datei, jeweils mit Linux-`swift test`-Lauf.
  3. Sim+Device Smoke-Build.
  4. TestFlight `1.0.3 (172)`.
- **Feature Flags / Availability Gates:** nicht erforderlich, weil keine Verhaltensänderungen, nur Floor-Anhebung.

**Empfehlung dieses Audits:** **Option 3** — iOS 17 vorbereiten, aber **nicht in diesem Train** anheben. Begründung:
- Reichweiten-Datenstand ist nicht verifizierbar auf Linux.
- Anhebung ist mechanisch, aber berührt 37 Source-Stellen und 8 pbxproj-Configs; das ist kein „kleiner Train" mehr.
- Linux-Verifikation alleine reicht für eine echte Deployment-Target-Anhebung nicht aus; Sim/Device-Smoke-Build vor dem Push ist Pflicht.
- Aktuelle App-Release-Status (1.0.2 mit Apple-Review-Punkten offen, siehe `wrapper/docs/TESTFLIGHT_RUNBOOK.md` + hauptsession.md) sollte erst stabilisiert sein, bevor das Deployment-Target sich bewegt.

---

## 5. Top-20-Hotspots

> **Notation:** P0 = direkte Korrektheit/Stabilität; P1 = Performance-/UX-Risiko; P2 = Skalierungs-Potenzial, braucht Hardware-Messung; M = Mac/Device-only-Verifikation.

| # | Surface / Datei | Befund | Prio | Linux-testbar? |
|---|---|---|---|---|
| 1 | `AppRecordedTrackEditorView.swift:202` — `ForEach(Array(draft.points.enumerated()), id: \.offset)` | Index-getragene `Binding<…>`-Logik, Delete/Insert/Reorder. Index-zu-Domain-ID-Umbau wäre semantischer Eingriff. **Mutables Editor-Verhalten — höchstes Identity-Risiko.** | P0 | Nein (Binding-/Editor-State) |
| 2 | `AppInsightsContentView.swift:1200` — `topDays.enumerated()` | Index wird angezeigt; `id: \.offset` ist semantisch korrekt, aber Drift-Risiko falls Sortierung wechselt. | P1 | Nein |
| 3 | `LHExportComponents.swift:33` — `Step.allCases.enumerated()` | Index aktiv im Label/Numbering. Statisches `allCases`, daher in der Praxis stabil — aber `id: \.offset` ist hier _akzeptabel_, nicht _ideal_. | P2 | Nein |
| 4 | `AppExportPreviewMapView.swift:58/62` — Waypoint-/Path-Overlays, `id: \.offset` | Render-Daten sind pro Build immutable; Identity-Drift unwahrscheinlich, aber im Diff bei `presentExport`-Wechsel möglich. | P1 | Nein |
| 5 | `AppOverviewTracksMapView.swift:202/409` — Path-Overlays, `id: \.offset` | Render-Daten immutable pro Snapshot. Sicher per Konstruktion, aber inkonsistent mit `AppDayMapView`-Muster. | P2 | Nein |
| 6 | `AppDayDetailView.swift:371/378/391/418` — Activities/Visits, `id: \.offset` | Index unbenutzt; benötigt `Identifiable`-Wrapper oder Modell-Erweiterung in `DayDetailViewState.VisitItem`/`ActivityItem`. | P1 | Nein |
| 7 | `AppLiveTrackingView.swift:562`, `AppLiveLocationSection.swift:132` — Breadcrumb-Buckets, `id: \.offset` | Live-Pfad, algorithmus-derived. Identity-Drift bei Live-Update möglich (Buckets gewinnen/verlieren Stellen). | P1 | Nein |
| 8 | `AppInsightsContentView.swift:239–243 + 465–469` — Doppelter 5×`.onChange`-Cluster | `refreshDerivedModel()` wird pro Trigger einmal pro Cluster aufgerufen. **Analyse 2026-05-16:** `.task(id:)` ist keine semantik-äquivalente Ersetzung (würde Initial-Lauf duplizieren). **Status: KEEP AS IS.** | P2 | Nein |
| 9 | `AppContentSplitView.swift:197–222` — 7×`.onChange` → `syncLiveRecordingSettings()` | Analoges Muster zu (8). Konsolidierung über kombiniertes `Equatable`-Struct ohne messbaren Vorteil, `.task(id:)`-Duplizierung droht. **Status: KEEP AS IS.** | P2 | Nein |
| 10 | `AppLiveTrackingView` / `LiveLocationFeatureModel` — Live-Polyline ohne Hard-Cap | `uploadQueueLimit = 10_000` Punkte; keine Tail-Decimation. Bei sehr langen Sessions: stille Drop-Logik via `trimToLast()`, kein UI-Hinweis. | P1 | Teilweise (Modelllogik ja, Map-Render nein) |
| 11 | `AppLiveTrackingView` — Camera-Follow ohne Throttle | `centerOnCurrentLocation()` wird pro neuer Location getriggert; kein Debounce. UX-Jank bei dichten GPS-Updates möglich. | P1 | Nein |
| 12 | `KMZBuilder.swift:7–31` — Doppel-Pufferung | `kmlData` (Full-String → Data) + `tmpURL` (Disk) + erneutes `Data(contentsOf: tmpURL)` → bis zu **2× Peak-Memory** der KML-Output-Größe. Bei 100k Punkten ggf. > 100 MB. | P1 | Ja |
| 13 | `GPXBuilder` / `KMLBuilder` / `CSVBuilder` / `GeoJSONBuilder` — String-Akkumulation | Builder bauen `[String]` und `joined(separator:)`. Final-String ~1.5–2× Peak-Memory. Streaming-Writer-API möglich. | P2 | Ja |
| 14 | `LocalTimelineStore.swift:41–54` — SQLite WAL ohne explizite Growth-Limits | WAL-Mode aktiv, NORMAL sync, busy_timeout 3000, temp_store MEMORY. **Fehlt:** `journal_size_limit`, `wal_autocheckpoint`, `mmap_size`. Risiko: unbounded WAL-Sidecar-Wachstum bei langen Sessions. | P2 | Ja |
| 15 | `HeatmapGridBuilder.computeMultiLODGrids` (definiert, nicht verdrahtet) | Fused Multi-LOD-API existiert; `AppHeatmapModel.ensureDensityPrecomputation` nutzt sie nicht (Per-LOD-Loop). Bewusst nicht verdrahtet wegen Test-Stabilität (byte-identisches Output-Lock). Kein Performance-Blocker. | P2 / M | Teilweise (API-Korrektheit ja, Wallclock-Vergleich nein) |
| 16 | `AppHeatmapModel.debounceUpdateForRegion` | Debounce-Definition vorhanden, **aber Map-Surface verdrahtet nur `updateForRegion` ohne Throttle** auf `.onMapCameraChange` (siehe AppHeatmapView). Schnelles Pan/Zoom: ungebremste Re-Computation möglich. | P1 | Nein |
| 17 | MKMapView+MKMultiPolyline-Bridging für Overview (P2-9 aus Vor-Audit) | Skalierung bei sehr großen Routen; nur sinnvoll mit Side-by-Side-Hardware-Messung. Bewusst offen. | P2 / M | Nein |
| 18 | MKTileOverlay-Heatmap (P2-10 aus Vor-Audit) | GPU-Offload für Smoothing — braucht Mac-only Spike, Instruments-Profil. | P2 / M | Nein |
| 19 | `OverviewMapPreparation.scanCandidates` Streaming-Refactor (P2-11 aus Vor-Audit) | Memory-Spike bei großen Eingaben; profitierbar von Iterator-Refactor. Braucht Profiling. | P2 / M | Teilweise |
| 20 | ASC / TestFlight / Device-Verifikation (P1-/M-Themen aus `hauptsession.md`, Apple-Review-Punkte) | 46-MiB-Hardware-Retest, Dynamic-Island Lock-Screen, iPad-Layout, `xcarchive 1.0.2 (171)` Upload, Apple-Review-Resubmit. | M | Nein |

---

## 6. Linux-testbare Optimierungen (Kandidaten für künftige Trains)

Diese Punkte können Linux-only entwickelt und gegen die bestehenden Performance-Baselines vermessen werden, ohne MapKit/SwiftUI-Runtime:

- **L-a `KMZBuilder` als Streaming-Writer.** `KMLBuilder.build(into: FileHandle)` API, KMZ-Provider liest direkt aus der temporären KML-Datei, kein zweiter `Data(contentsOf:)` am Ende. Test: bestehende Builder-Performance-Suite + Peak-Memory-Check via `getrusage` (Linux-portabel).
- **L-b `GPX/KML/CSV/GeoJSON Builder` Stream-API.** Optionaler `build(into: URL)` zusätzlich zur bestehenden `build(from:)`-API. Bestehende Tests bleiben, neue Tests für Stream-Variante. Verhalten unverändert.
- **L-c `LocalTimelineStore` Pragmas.** `journal_size_limit`, `wal_autocheckpoint`, optional `mmap_size` (vorsichtig wegen iOS-VM). Linux-Testbar (Round-Trip + Pragma-Read-Check), Effekt auf iOS bleibt unmeasured.
- **L-d `Live-Polyline-Cap mit Tail-Decimation`.** Feature-Flag default OFF, Modell-Logik vollständig Linux-testbar (RecordedTrackPoint-Arrays, Cap-Verhalten, Decimation-Korrektheit). Map-Verhalten bleibt unmeasured.

---

## 7. Mac/Instruments-only Optimierungen

- **M-a Heatmap fused Multi-LOD API verdrahten.** Mit Instruments + Side-by-Side-Wallclock-Vergleich auf realem Gerät messen, dann Entscheidung.
- **M-b MKMapView + MKMultiPolyline Heavy-Overview Spike.** Memory + Frame-Time vergleichen, dann entscheiden, ob es Switching-Wert ist.
- **M-c MKTileOverlay Heatmap.** GPU-/Tile-Cache-Verhalten messen.
- **M-d Camera-Throttle in `AppLiveTrackingView`.** Linux kann das Verhalten nicht beobachten; Sim/Device-Messung + Frame-Drop-Profil.
- **M-e Apple-Review / TestFlight-Stabilisierung.** 46-MiB-Hardware-Retest, Dynamic Island Lock-Screen, iPad-Layout, Re-Submit.

---

## 8. Empfohlene Trains (Reihenfolge)

| Train | Inhalt | Verhaltensänderung? | Risiko |
|---|---|---|---|
| **E1** (Linux, klein) | KMZ-Streaming-Writer (L-a). Vorhandene Builder-Performance-Suite + Korrektheits-Tests reichen. | Nein (gleicher KMZ-Output, kleinere Peak-Memory) | Niedrig |
| **E2** (Linux, mittel) | GPX/KML/CSV/GeoJSON optionale Stream-API (L-b). Bestehende API bleibt. | Nein (neue API additiv) | Niedrig |
| **E3** (Linux, klein) | LocalTimelineStore Pragmas (L-c). Round-Trip-Tests. | Subtil ja — WAL-Sidecar-Wachstumsverhalten ändert sich. | Mittel (iOS-Effekt nicht Linux-prüfbar) |
| **C** (gemischt, Feature-Flag default OFF) | Live-Polyline-Cap + Tail-Decimation (L-d) + Camera-Throttle (M-d). Modelllogik Linux-testbar, Map-Verhalten Sim/Device-prüfbar. | Ja, hinter Flag | Mittel |
| **B2** (gemischt) | `DayDetailViewState`-Identity-Wrapper, Overview/Export-Overlay Domain-IDs. Modell-Edit + UI-Smoke auf Sim/Device. | Nein (SwiftUI-Diffing-Verhalten) | Niedrig–Mittel |
| **F** (Doku + Build, mittel) | iOS-17-Deployment-Anhebung (Option 2). Eigener Commit + Sim/Device-Smoke + TestFlight. | Nein (Floor-Bump) | Mittel (Reichweiten-Risiko prüfen) |
| **D** (Mac/Device/ASC) | M-a … M-e. Apple-Review-Resubmit. | Variabel | Hoch (Hardware) |

---

## 9. In diesem Commit umgesetzt

- **Nur Doku.** `docs/APP_PERFORMANCE_MODERNIZATION_AUDIT_2026-05-16.md` (dieses Dokument) neu.
- Verweisaktualisierungen in `CHANGELOG.md`, `NEXT_STEPS.md`, `ROADMAP.md`, `docs/MAPKIT_PERFORMANCE_AUDIT_2026-05-16.md`.
- **Kein** Source-Eingriff. **Kein** Deployment-Target-Bump. **Kein** Feature-Flag-Switch.

## 10. Bewusst NICHT in diesem Train umgesetzt

- Keine iOS-17-Anhebung — Reichweiten-Datenstand auf Linux nicht verifizierbar; Mehraufwand nicht „klein". Empfehlung: Option 3 (vorbereiten).
- Keine `KMZBuilder`-Refaktorierung — API-Wechsel, separater Train E1.
- Keine `.onChange`-Konsolidierung in `AppInsightsContentView` oder `AppContentSplitView` — `.task(id:)` ist nicht semantik-äquivalent.
- Keine Identity-Fixes an `AppRecordedTrackEditorView`, `LHExportComponents`, `topDays`, Live-Breadcrumb-Buckets, DayDetail-Rows, Overview-/Export-Overlays — alle erfordern Domain-Modell-Erweiterung oder bergen Editor-/Live-Risiko.
- Kein Live-Polyline-Hard-Cap. Kein Camera-Throttle.
- Keine SQLite-Pragma-Erweiterung.
- Keine produktive Verdrahtung der Heatmap-Multi-LOD-API.

---

## 11. Teststatus (Linux, Swift 6.3.2 via swiftly, `libsqlite3-dev`)

- `git diff --check` ✅
- `swift build` ✅
- `swift test` ✅ **1459 Tests / 2 Skips / 0 Failures, ~54 s** — unverändert zum Stand vor diesem Audit-Commit.
- Filterläufe (Stand 1a4d859):
  - `--filter Performance` → 38/0
  - `--filter Insights` → 105/0
  - `--filter Export` → 188/0
  - `--filter Map` → 222/0
  - `--filter Path` → 117/0
- **Filter ohne Treffer:** `--filter Heatmap`, `--filter Import`, `--filter StreamReader` (letztere unter `Performance` enthalten), `--filter Live`. Werden in diesem Audit nicht als Fehler gewertet; Test-Naming-Konvention im Repo gruppiert sie unter anderen Prefixes.

---

## 12. Verbleibende Risiken

- **iOS-17-Anhebung wird verzögert** — solange iOS 16 Floor bleibt, müssen alle künftigen MapKit-/SwiftUI-Modernisierungen Availability-gated bleiben.
- **`KMZBuilder` Peak-Memory** — bei sehr großen Exports auf älteren iPhones potenziell Jetsam-Risiko. Aktuell ungemessen.
- **Live-Polyline 10k-Cap** — silent drop, keine UI-Warnung; lange Sessions verlieren ältere Punkte.
- **Camera-Follow ohne Throttle** — UX-Jank bei dichten GPS-Updates; nicht auf Linux beobachtbar.
- **Apple-Review-Punkte aus `hauptsession.md`** — 46-MiB-Hardware-Retest, Dynamic-Island Lock-Screen-Sichtprüfung, iPad-Layout, Privacy-Punkte. Diese sind extern und blockieren die Release-Pipeline 1.0.2 (171).

---

_Audit erstellt 2026-05-16, Branch `main`, Start-HEAD `1a4d859`. Keine produktive Code-Änderung in diesem Commit._
