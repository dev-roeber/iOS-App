# MapKit A–Z Audit & Modernization Train 1 — 2026-05-13

> Branch: `chore/mapkit-az-modernization-1` • Start-HEAD: `c1314dc` • Kein Release, kein Build-Bump, kein ASC, kein Merge nach main ohne explizite Freigabe.

## 0. Ausgangslage

Repo aktuell auf 1.0.2/171 (Release-Train-Commit `c1314dc`). Vorherige Map-Audits in `docs/MAP_ARCHITECTURE_AUDIT.md` (2026-05-08 ff.) bleiben die kanonische Bestandsaufnahme der Karten-Pipeline; dieser Train ergänzt punktuelle Härtung und Performance-Mikro-Verbesserungen für die `AppDayMapView`-Surface.

`swift build` und `swift test` (1524 / 2 skipped / 0 failures, 162 s) waren grün vor jedem Eingriff.

## 1. Online-Recherche (Phase 1) — Research-Matrix

Quellen ausschließlich offizielle Apple-Kanäle (developer.apple.com, WWDC). Kein WWDC25-Map-Material in den geprüften Quellen auffindbar — als „keine konkrete Apple-Aussage" markiert.

| Thema | Quelle | Empfehlung | Nutzen LH2GPX | Risiko | Einbauen jetzt? |
|---|---|---|---|---|---|
| MapKit for SwiftUI Basics (`Map`, `MapPolyline`, `Marker`, `Annotation`) | developer.apple.com/videos/play/wwdc2023/10043 | iOS 17+ deklarative API, in App bereits genutzt | Day/Overview/Heatmap/Live/Export bereits portiert | Keiner | Bereits drin |
| `MapCameraPosition` | WWDC23 10043 | `.region/.rect/.automatic` | Bereits in `AppDayMapView`, `AppHeatmapView` | – | Bereits drin |
| `onMapCameraChange(frequency:)` | WWDC23 10043 | `.onEnd` für Throttling, `.continuous` nur mit Debounce | Heatmap nutzt bereits `.onEnd` (`AppHeatmapView.swift:80`) | `.continuous` ohne Throttle = teuer | Kein Wechsel nötig |
| `MapStyle` (.realistic/.imagery) | WWDC23 10043 | Optional 3D | UX-Nice-to-have | GPU-Kosten, Apple-Doku ohne konkrete Werte | Nicht in Train 1 (Roadmap) |
| MKMapView+MKMultiPolyline-Bridging | developer.apple.com/documentation/mapkit/mkpolyline | Eine Overlay-Instanz statt N MapPolyline-Views | Heavy Overview/Heatmap | Hoher Refactor-Aufwand, eigene Messung Pflicht | **Map-Train 2** (s. MAP_ARCHITECTURE_AUDIT §5.6/§5.7) |
| WWDC24 10097 „Unlock the power of places" (Place ID, mapItemDetailSheet) | developer.apple.com/videos/play/wwdc2024/10097 | POI-Sheet auf Tap | Optional für Visit-Marker | iOS 18+ vermutlich, neue Apple-Server-Calls | **Map-Train 2** |
| WWDC25 Map-Sessions | – | **keine konkrete Apple-Aussage in den geprüften Quellen** | – | – | Nicht relevant |
| Performance bei vielen Annotationen/Overlays | WWDC23 10043 | **keine konkrete Apple-Aussage zu absoluten Limits** — eigene LOD + Simplifizierung weiter Pflicht | LH2GPX hat bereits LOD-Tiers (`OverviewMapRenderProfile`, `HeatmapLOD`) | – | Beibehalten |

**Regelkonform**: Keine API nur eingebaut, weil sie neu ist. Deployment Target laut `Package.swift`: iOS 16 / macOS 13 (Wrapper-Target höher). Alle berührten Files sind bereits `@available(iOS 17.0, macOS 14.0, *)` für SwiftUI-Map.

## 2. Map-A–Z-Inventur (Phase 2) — Kurzfassung

Vollständige Tabelle in `docs/MAP_ARCHITECTURE_AUDIT.md §1` (2026-05-08, ergänzt durch Phasen 8A–10C). Aktuelle Top-Punkte:

| Bereich | Datei | Renderer | Risiko |
|---|---|---|---|
| Overview | `AppOverviewTracksMapView.swift` | SwiftUI Map + N×MapPolyline | scanCandidates P1 (HIGH-RISK Refactor, bewusst deferred) |
| Day Detail | `AppDayMapView.swift` | SwiftUI Map + MapPolyline (halo+core) + Marker | **Sanitize fehlte; Speed-Segmente im body neu berechnet; ForEach mit `\.offset`** |
| Heatmap | `AppHeatmapView.swift` + `AppHeatmapModel.swift` | SwiftUI Map + MapPolygon | Multipass-LOD-Rebuild P1 (deferred) |
| Live | `AppLiveTrackingView.swift` | SwiftUI Map | Sanitize bereits aktiv (`MapCoordinateGuard`) |
| Export Preview | `AppExportPreviewMapView.swift` | SwiftUI Map | Doppel-Iter laut Phase-10C bereits gefixt |

## 3. Baseline (Phase 3)

- `swift build` 1,21 s ✅
- `swift test` **1524 / 2 skipped / 0 failures** in 162 s ✅

## 4. Audit-Befunde (Phase 4) — gegen `AppDayMapView`

1. **Sanitization-Lücke**: Day-Pfad reichte Coords ohne `MapCoordinateGuard.isValid` an MapKit. Ein einziger NaN/±Inf/Apple-Sentinel-Punkt aus `DayMapData.pathOverlays[*].coordinates` hätte den SwiftUI-Map-Renderer abreißen können. Live-Pfad sanitisiert bereits — Inkonsistenz.
2. **`SpeedTrackBuilder.segments()` im Map body**: `ForEach(SpeedTrackBuilder.segments(from: path.speedSamples))` rief pro Render und Pfad Smoothing + Percentile-Bounds neu auf. Body wird bei Map-Kamera-Wechseln (Zoom/Pan/User-Location) mehrfach pro Sekunde re-evaluiert.
3. **Instabile `id: \.offset` ForEach (3×)**: SwiftUI konnte Identität nicht stabil zuordnen, wenn `pathOverlays`-Array zwischen Renders die Reihenfolge ändert.
4. **Sample-Misalignment**: Eine Filterung der Coords ohne paralleles Filtern der Timestamps hätte Speed-Samples disaligned.

## 5. Top-Kandidaten und Auswahl (Phase 5)

Top-Kandidaten priorisiert nach Risk/Reward (Train-1-Scope: klein, testbar, risikoarm):

| # | Bereich | Problem | Beleg | Nutzen | Risiko | Entscheidung |
|---|---|---|---|---|---|---|
| 1 | `AppDayMapView.DayMapRenderData` | Keine Sanitisierung | Code Inspection | Crash-Resistenz | Sehr niedrig | **Train 1 — done** |
| 2 | `AppDayMapView` body | `SpeedTrackBuilder.segments()` pro Render | Code Inspection | Re-Render-CPU-Last | Niedrig | **Train 1 — done** |
| 3 | `AppDayMapView` ForEach | `id: \.offset` × 3 | Code Inspection | SwiftUI-Identität sauberer | Niedrig | **Train 1 — done** |
| 4 | `AppOverviewTracksMapView.scanCandidates` | Score auf full coords | `MAP_ARCHITECTURE_AUDIT.md §Phase-10C` | Memory Peak Overview | HOCH (Score-Reihenfolge-Tests müssen mitwandern) | **Map-Train 2** |
| 5 | `AppHeatmapModel` LOD-Rebuild | Multipass | Audit 2026-05-09 | Heatmap-Compute-Zeit | MITTEL | **Map-Train 2** |
| 6 | MKMapView+MKMultiPolyline für Heavy Overview | N MapPolyline → 1 Overlay | WWDC23 + MAP_ARCHITECTURE_AUDIT §4 | RAM-Peak | HOCH (Renderer-Wechsel, separate Messung) | **Map-Train 2** |
| 7 | Sanitize in Overview/Export-Pfad | analog Day | MAP_ARCHITECTURE_AUDIT §6 | Crash-Resistenz | Niedrig | **Map-Train 2** (eigener Commit, Tests pro Surface) |

## 6. Umsetzung (Phase 6)

**Datei: `Sources/LocationHistoryConsumerAppSupport/AppDayMapView.swift`**

1. `DayMapRenderData` jetzt `internal` (vorher `private`) für Testbarkeit. Kein API-Drift — Struct ist nicht öffentlich exportiert.
2. `PathOverlay` und `VisitAnnotation` jetzt `Identifiable` mit `id: Int` (Insertion-Index, stabil über Lebenszeit des Render-Snapshots — Snapshot wird bei `mapData`-Change vollständig ersetzt).
3. `MapCoordinateGuard.isValid` Filter pro `PathOverlay.coordinates` **und** parallel auf den ISO-Timestamp-Array → Sample-Alignment für Tempolayer bleibt korrekt. Pro `VisitAnnotation` ebenfalls Filter (invalid Visit → verworfen).
4. `PathOverlay.speedSegments: [SpeedSegment]` neu, einmalig in `init` befüllt aus `SpeedTrackBuilder.segments(from: samples)`. Body greift jetzt auf das Cache-Array zu.
5. SwiftUI `ForEach(Array(...enumerated()), id: \.offset)` × 3 → `ForEach(renderData.pathOverlays)` / `ForEach(renderData.visitAnnotations)` via `Identifiable`.

Keine externe Dependency, keine neuen Entitlements, keine Privacy-/Network-Folge.

## 7. Tests (Phase 7)

`Tests/LocationHistoryConsumerTests/AppDayMapRenderDataTests.swift` — 6 neue Tests, MapKit-gated (`#if canImport(SwiftUI) && canImport(MapKit)`):

1. `testSanitisesNaNAndInfinityCoordinates` — 6 Roh-Punkte mit NaN/±Inf/Sentinel, 3 valide übrig
2. `testSanitisesInvalidVisitCoordinates` — 4 Visits mit NaN/Sentinel, 2 valide übrig
3. `testStableIdentifiableIDsAcrossPaths` — IDs `[0,1,2]`, einzigartig
4. `testSpeedSegmentsArePrecomputedAndAlignedToSanitisedCoords` — NaN-Punkt + zugehöriger Timestamp gemeinsam gedroppt; `speedSegments` cached und ≤ coords-1
5. `testEmptyPathDoesNotCrash` — keine Punkte → keine Speed-Segmente
6. `testSingleValidCoordinateProducesNoSpeedSegments` — 1 Punkt → keine Speed-Segmente

Alle 6 Tests grün in 0,010 s.

## 8. Nachmessung (Phase 8)

- `swift test`: siehe Abschlussbericht (separat erhoben)
- `xcodebuild build` Sim iPhone 17 Pro Max iOS 26.0: siehe Abschlussbericht
- `xcodebuild build` Device iPhone 15 Pro Max iOS 26.4: siehe Abschlussbericht

**Performance-Messung im engeren Sinn** (FPS/Memory) **nicht erhoben** — Änderungen sind Algorithmus-/Identitäts-Hardening ohne automatisierte Benchmark-Surface. Qualitative Aussage: `SpeedTrackBuilder.segments()` läuft jetzt **einmal pro Snapshot** statt **pro Body-Pass** (Body läuft im Speed-Modus mindestens 2× pro Pfad pro Render: halo + core branch). Konkrete CPU-Einsparung in Prozent: **nicht gemessen, keine Behauptung**.

## 9. Bewusst nicht umgesetzt (Map-Train 2)

- **Overview scanCandidates**-Refactor zu Streaming-Score (HIGH-RISK, Score-Tests müssen mitwandern)
- **MKMapView+MKMultiPolyline**-Bridging für Heavy Overview/Heatmap (separater Performance-Vergleich erforderlich)
- **MKTileOverlay**-Tiles für Heatmap (Big Design)
- **AppHeatmapModel** Multipass-LOD → Single-Pass Tile-Sweep
- **Sanitize** auf Overview/Export/Heatmap-Pfade ausweiten (eigener Commit pro Surface, Tests pro Surface)
- **WWDC24 Place ID / mapItemDetailSheet** für Visit-Marker (iOS-18+-Check + UX-Entscheidung)

## 10. Risiken / Offene Punkte

- `id: Int = offset` ist **innerhalb eines Snapshots stabil**, aber **nicht** über `mapData`-Changes (neuer Snapshot reset). Da `renderData = newRender` bei `onChange(of: mapData)` einen Full-Replace macht, ist SwiftUI Diff dort sowieso vollständig — kein Regression-Risiko gegenüber dem alten `\.offset`-Verhalten.
- Sanitize-Filter ist destruktiv (Filter, nicht Re-Map). Verbleibende Coords sind die Originalwerte; keine künstlichen Punkte. Keine stille Sampling-/Decimation-Änderung — Outlier-Filter + Douglas-Peucker laufen wie bisher danach. Akzeptanzkriterium „kleine Daten sehen gleich aus" wird gewahrt, solange Eingang keine ungültigen Coords enthält (Regelfall).
- Speed-Segmente sind jetzt im Snapshot gefroren. Wenn Nutzer-Preferences die `adaptive`-Logik in Zukunft toggeln sollten, müsste das den Snapshot rebuilden. Aktueller `SpeedTrackBuilder.segments(..., adaptive: true)` ist hartcodiert — unverändert.

## 11. Abschluss

Branch `chore/mapkit-az-modernization-1` wird gepusht. **Kein Merge nach main**.
