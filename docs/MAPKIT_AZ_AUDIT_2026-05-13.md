# MapKit A–Z Audit & Modernization — 2026-05-13

> Branch Train 1: `chore/mapkit-az-modernization-1` (HEAD `d6a6191`) — gepusht, **nicht** gemerged.
> Branch Train 2: `chore/mapkit-az-modernization-2` (Basis `d6a6191`) — gepusht, **nicht** gemerged.
> Branch Train 3: `chore/mapkit-az-modernization-3` (Basis `42e4415`) — gepusht, **nicht** gemerged.
> Kein Release, kein Build-Bump, kein ASC.

---

## TRAIN 3 — 2026-05-13 (Heatmap Golden-Output + Single-Pass-Multi-LOD API + ehrliche Performance-Befund)

### Phase 1 Heatmap-Pipeline-Inventur (Kurzfassung)

| Datei | Funktion | Phase | Komplexität | Hotspot |
|---|---|---|---|---|
| `AppHeatmapModel.swift` | `startPrecomputation` | Collect | O(N) | densityCap (500k) |
| `AppHeatmapModel.swift` | `ensureDensityPrecomputation` | Bin/Smooth/Normalize × 4 LOD | O(N × LODs) | per-LOD-Loop |
| `HeatmapGridBuilder.swift` | `computeGrid` | Bin → Smooth → Normalize → Result | 3 Passes pro LOD | Smoothing-Kernel |
| `HeatmapGridBuilder.swift` | `visibleCells` | Viewport-Cull + Sort + Trim | O(viewport-bins) | Sort dominiert |
| `AppHeatmapView.swift` | `onMapCameraChange(.onEnd)` | Region-Update | Cache-Lookup | – |

Caches: `lodGrids` (persistent), `viewportCache` (invalidated on scale change), SQLite `derived_cache` (extern, Phase-8B).

Pro Render: viewport-cull + Cache-Lookup, kein Re-Bin/Re-Smooth.

### Phase 2 Golden-Output-Tests (vor Optimierung)

`HeatmapGoldenOutputTests.swift` — 11 Cases, **alle grün gegen Baseline-Code** (vor jeder Codeänderung).

Fixtures (deterministisch generiert, keine externen Dateien):
1. empty `[]`
2. single point
3. `smallCluster` (5 Punkte um Berlin)
4. `twoClusters` (Berlin + München)
5. `synthetic1k` (LCG seed=1, ~1° × 1° um Europa)

Locked Contracts:
- empty input → empty grid für alle 4 LODs
- single-point → ≥ 1 Cell bei `.high`/`.medium`
- byte-identische `normalizedIntensity` (bitPattern) bei wiederholtem `computeGrid(for:lod:)` (Determinismus auf gleiche Insertion-Order)
- exakte Cell-Counts für `smallCluster` an allen 4 LODs
- Zwei Cluster bleiben am `.high`-LOD räumlich distinkt
- Multi-LOD-Äquivalenz: gleiche Key-Sets + integer-counts + Center-Koordinaten byte-identisch + `normalizedIntensity`-Drift ≤ 1e-14 (s.u.)

### Phase 3 Baseline-Benchmarks (XCTMeasure, macOS x86_64)

| Benchmark | Datensatz | Avg (10 Iter.) | RSD | Bemerkung |
|---|---|---|---|---|
| `testBaseline_PerLOD_1k` | 1 000 synth. Punkte × 4 LOD | **37 ms** | 2,3 % | stabil |
| `testBaseline_PerLOD_10k` | 10 000 × 4 LOD | **280 ms** | 10,8 % | mäßige Streuung |
| `testBaseline_PerLOD_50k` | 50 000 × 4 LOD | **1271 ms** | 6,7 % | stabil; Smoothing-Pass dominiert |

### Phase 4 Single-Pass-Multi-LOD Plan

- `computeMultiLODGrids(for:lods:scale:)` neu: ein Pass über `points`, `lonScale(forLatitude:)` einmal pro Punkt, dann 4 `floor(lat/step)`/`floor(lon*lonScale/step)`-Bins pro Punkt — gegenüber 4 separaten Passes mit je 1 cos pro Punkt.
- Smoothing + Normalisierung bleiben **per LOD** (LOD-spezifischer Kernel + Threshold).
- Refactor: `computeGrid` delegiert an zwei extrahierte Helfer `binRaw(points:lod:)` und `smoothAndNormalize(raw:lod:scale:)`. Beide privat-internal genug für Test-Wiederverwendung. **Output von `computeGrid(for:lod:)` byte-identisch zum Pre-Refactor** (Goldens lock).
- Cache: kein neuer Cache, keine neue Invalidierung.
- Worst-Case-Speicher: 4 × raw-Dict statt 1 × raw-Dict zur gleichen Zeit — bei 500k unique cells × 4 LODs × (GridKey + Double) ≈ 80 MB peak in der Detached-Task. Akzeptabel; <iPhone-Jetsam-Schwelle.

### Phase 5 Umsetzung

**`Sources/LocationHistoryConsumerAppSupport/HeatmapGridBuilder.swift`** (erweitert):
- `static func binRaw(points:lod:) -> [GridKey: Double]` extrahiert
- `static func smoothAndNormalize(raw:lod:scale:) -> [GridKey: HeatCell]` extrahiert
- `static func computeMultiLODGrids(for:lods:scale:) -> [HeatmapLOD: [GridKey: HeatCell]]` neu — Fused Single-Pass-Binning für N LODs in einem Pass; dedupliziert LOD-Liste; tolerant gegen empty points (gibt leere Grids pro requestierter LOD zurück); tolerant gegen empty `lods` (`[:]`).
- `static func computeGrid(for:lod:scale:)` delegiert jetzt an die beiden Helfer — Verhalten **strikt identisch zum Pre-Refactor**.

**`Sources/LocationHistoryConsumerAppSupport/AppHeatmapModel.swift`** — `ensureDensityPrecomputation`:
- Nach Benchmarking auf den per-LOD-Loop **zurückgesetzt** (kommentar mit Begründung im Code). Begründung: kein messbarer Wallclock-Gewinn auf 10k/50k (Smoothing dominiert); Output vom Pre-Train-3-Pfad **byte-identisch**. Fused-API steht als Train-4-Extension-Point bereit (per-LOD-Parallelism / GPU offload).

### Phase 6 Tests erweitert

`HeatmapGoldenOutputTests.swift` jetzt 11 Cases inkl.:
- `testMultiLODGridsEquivalentToPerLODWithinOneULP` — multi-LOD-Output äquivalent zu per-LOD-Output. Key-Sets, integer-counts und Center-Koordinaten **byte-identisch**; `normalizedIntensity` ≤ **1e-14** Absolut-Drift (~50 ULPs an 1.0, real beobachtet ~4 ULPs für 1k synthetisch unter Linear-Scale). Begründung: Swift Dictionary-Iteration-Order hängt von Insertion-Order ab; Smoothing-Fold akkumuliert FP-Summen in unterschiedlicher Reihenfolge zwischen per-LOD und fused → Endwert weicht um wenige ULPs ab. Rendering nutzt 8-bit Farbverlauf → < 1e-3 Drift sichtbar; 1e-14 Schwelle fängt echte Logikbugs, ignoriert Plattform-FP-Reorder.
- `testMultiLODGridsHandlesEmptyLODList` — `lods: []` → `[:]`
- `testMultiLODGridsDeduplicatesRequestedLODs` — `[.macro, .high, .macro]` → 2 Keys
- `testMultiLODGridsEmptyPointsProducesEmptyGridsForRequestedLODs` — empty points + non-empty lods → Keys vorhanden, alle Grids leer

`HeatmapPipelineBenchmarkTests.swift` neu — 6 XCTMeasure-Cases (3 per-LOD baseline + 3 fused).

### Phase 8 Nachmessung

| Benchmark | Datensatz | Per-LOD Baseline (Avg) | Fused Multi-LOD (Avg) | Δ | Aussagekraft |
|---|---|---|---|---|---|
| 1k synth. × 4 LOD | 1 000 | 37 ms | **32 ms** | **−13 %** | RSD 15 % → Richtwert |
| 10k synth. × 4 LOD | 10 000 | 280 ms | 282 ms | ~0 % | RSD 5–11 % → kein Unterschied |
| 50k synth. × 4 LOD | 50 000 | 1271 ms | 1281 ms | ~0 % | RSD 4–7 % → kein Unterschied |

**Ehrlicher Befund**: messbarer Wallclock-Gewinn nur für kleine Datensätze (1k), und auch dort RSD-grenzwertig. Bei 10k/50k dominiert die per-LOD-Smoothing-Phase die Laufzeit; die im Fused-Pfad gesparten ~3N `cos()`-Aufrufe (vier statt einem pro Punkt) sind gegen die Smoothing-Iteration über das Raw-Dict vernachlässigbar.

→ **AppHeatmapModel bleibt auf dem per-LOD-Pfad**. Fused-Funktion bleibt im Code als API verfügbar, gilt aber als **Architektur-Vorbereitung für Train 4** (per-LOD parallel via TaskGroup oder GPU-Offload pro LOD). Keine User-sichtbare Änderung im Train-3-Commit.

### Phase 9 Bewusst nicht umgesetzt (Train 4+)

- **AppHeatmapModel-Verdrahtung auf `computeMultiLODGrids`** — bewusst zurückgenommen, da kein messbarer Wallclock-Gewinn auf 10k/50k
- **Per-LOD Parallelism** via `TaskGroup` über `HeatmapLOD.allCases` (TaskGroup-Overhead vs. Smoothing-Kosten benchmarken)
- **GPU-Offload** für Smoothing (Metal compute) — natürliche Train-4+-Aufgabe
- **MKTileOverlay-Heatmap** — Big Design
- **MKMapView+MKMultiPolyline Heavy-Overview Spike**
- **WWDC24 Place ID / `mapItemDetailSheet`**
- **`lonScale`-Memo** in `binRaw` — bereits in Train 2 verworfen

### Phase 10 Offene Risiken

- 1-ULP-Drift im fused-Pfad ist **invisible** (1e-14 absolut auf einer 8-bit Farbskala). API ist getestet aber wird produktiv **nicht genutzt** — ein latentes Risiko, falls künftiger Code auf `computeMultiLODGrids` umsteigt: Goldens müssen weiter mit 1e-14-Toleranz interpretiert werden.
- `computeMultiLODGrids` reserviert vorab 4 Raw-Dicts → Speicher-Peak höher als per-LOD-Pfad. Bei 500k-densityCap × 4 LODs theoretisch ~80 MB peak in der Detached-Task. Akzeptabel, aber Train 4 sollte vor Aktivierung iPhone-Memory-Probe einbauen.
- Goldens hängen an stabiler Swift-Dictionary-Iterations-Reihenfolge auf einem gegebenen Toolchain-Build. Wenn Swift-Compiler/Runtime in Zukunft die Dict-Insertion-Order ändert, könnten Goldens 1 ULP driften — `1e-14`-Toleranz im Multi-LOD-Test fängt das ab, der per-LOD-`testSmallClusterGoldenIntensitiesByteIdentical`-Test würde im Worst-Case neu kalibriert werden müssen.

### Empfehlung Map-Train 4

1. **Per-LOD Parallelism** via `TaskGroup` einbauen + benchmarken — wenn TaskGroup-Overhead < Smoothing-Zeit, Wallclock-Halbierung auf 10k+ möglich
2. **Metal compute shader** für Smoothing-Kernel — größter erwarteter Win, größtes Risiko (Plattform-FP-Drift, GPU-Bound-Latenz)
3. **MKMapView+MKMultiPolyline** Spike als getrennter Branch (Performance-Vergleich)
4. **MKTileOverlay-Heatmap** nach Spike-Erkenntnissen

---

## TRAIN 2 — 2026-05-13 (Sanitize-Ausweitung, Benchmark-Surface, Heatmap-Train-3-Aufgabe)

---

## TRAIN 2 — 2026-05-13 (Sanitize-Ausweitung, Benchmark-Surface, Heatmap-Train-3-Aufgabe)

### Phase 1 Recherche-Update
Für Train 2 keine neuen Apple-API-Quellen — die Sanitize-Ausweitung nutzt ausschließlich die existierende `MapCoordinateGuard`-Logik, jetzt als gemeinsame Foundation-only Implementation `CoordinateValidity`. Keine neue Map-API eingebaut.

### Phase 2 Sanitize-Surface-Matrix

| Surface | Datei | Sanitize vor Train 2 | Sanitize nach Train 2 | Parallele Arrays |
|---|---|---|---|---|
| Day Detail Map | `AppDayMapView.swift` | ✅ (Train 1) | ✅ unverändert | Timestamps für Speed-Layer |
| Live Tracking | `AppLiveTrackingView.swift` | ✅ | ✅ unverändert | — |
| Live Location Section | `AppLiveLocationSection.swift` | ✅ | ✅ unverändert | — |
| Overview Map | `AppOverviewTracksMapView.swift` (`scanCandidates`) | ❌ | ✅ **NEU** | Bounds (min/max lat/lon), Score-Sampling |
| Heatmap Model | `AppHeatmapModel.swift` (collect loop) | ❌ | ✅ **NEU** | Density-Cap (500k) |
| ExportPreview Builder | `ExportPreviewData.swift` (Foundation) | ❌ | ✅ **NEU** | Timestamps für ggf. Speed-Layer |
| Heatmap Grid Builder | `HeatmapGridBuilder.swift` | n/a (interpolierte Cell-Center) | n/a | — |
| Export Preview Renderer | `AppExportPreviewMapView.swift` | indirekt via Builder | indirekt via Builder | — |

Gemeinsame Foundation-Logik in **`CoordinateValidation.swift`** neu: `CoordinateValidity.isValid(latitude:longitude:)`. `MapCoordinateGuard.isValid(_:)` delegiert dort hin → identische Rejection-Regeln für Apple- und Linux-buildbare Surfaces.

### Phase 3 Sanitize-Ausweitung — Umsetzung

**`Sources/LocationHistoryConsumerAppSupport/CoordinateValidation.swift`** (NEU, Foundation-only):
- `public enum CoordinateValidity` mit `@inlinable static func isValid(latitude:longitude:) -> Bool`
- Rejects: NaN, ±Inf, lat outside ±90°, lon outside ±180°, Sentinel (-180,-180)

**`MapTrackStyling.swift`**:
- `MapCoordinateGuard.isValid(_:)` delegiert an `CoordinateValidity.isValid(latitude:longitude:)`

**`ExportPreviewData.swift`** (`ExportPreviewDataBuilder.previewData`):
- Waypoints: `compactMap` mit Validity-Filter
- Path-Points: Filter im single-pass Loop, parallele Timestamps werden mitgefiltert
- `pathOverlays` werden verworfen wenn nach Filter < 2 Punkte übrig

**`AppHeatmapModel.swift`** (Collect-Loop in `startPrecomputation`):
- Visit/Sample/Activity-Marker/Activity-Geometry: `guard CoordinateValidity.isValid` vor `WeightedPoint`-Erzeugung
- Cap-Logik unverändert; truncated-Flag unverändert

**`AppOverviewTracksMapView.swift`** (`scanCandidates`):
- Filter inside both flat- und points-Branch
- Bounds-Aggregation (pathMin/MaxLat/Lon + globaler min/maxLat/Lon) wird nur mit validen Punkten gefüttert → keine NaN-Bounds
- Score-Logik unverändert; `pointWeight = log(count)` sieht jetzt strikt validere Punkte

### Phase 3 Tests
3 neue Test-Dateien, alle grün:

1. **`CoordinateValidityTests.swift`** (5 Cases): valid accepted, NaN rejected, Infinity rejected, out-of-range rejected, Apple sentinel rejected (lon=-180 alone bleibt valide).
2. **`ExportPreviewSanitizeTests.swift`** (3 Cases): out-of-range + sentinel coords gedroppt mit Timestamp-Alignment, Path verworfen wenn < 2 valide übrig, Identitäts-Garantie für reine Valid-Daten.
3. **`MapSanitizeBenchmarkTests.swift`** (3 Cases, XCTMeasure): siehe Phase 4.

Hinweis: JSON kann NaN/Inf nicht serialisieren — Pipeline-Tests nutzen out-of-range (lat=91) + Sentinel `(-180,-180)`. NaN/Inf-Branch ist in `CoordinateValidityTests` separat abgedeckt.

### Phase 4 Benchmark-Messoberfläche

`MapSanitizeBenchmarkTests.swift` (XCTMeasure auf macOS x86_64):

| Benchmark | Datensatz | Average (10 Iter.) | RSD | Aussagekraft |
|---|---|---|---|---|
| `testIsValidThroughput10kMixed` | 10 000 coords (50% invalid) | **~2.3 ms** | 7.3 % | Hot-Path Foundation-Filter |
| `testIsValidThroughput50kValid` | 50 000 coords (all valid) | **~9 ms** | 48 % (Cold) / ~9 ms warm | Heatmap collect / Overview scan inner-loop |
| `testIsValidIsBranchOnlyNoAllocations` | 1024 coords | Sanity-Probe | – | Verifiziert konsistente Validierung |

Daraus abgeleiteter Foundation-Throughput: **~4–5 M coords/s** auf der lokalen Mac-Build-Maschine. Branch-frei, keine Allokationen pro Coord. Auf iOS-Hardware ist `cos()` ähnlich teuer; konkrete Device-Zahlen wurden **nicht** erhoben — als Train-3-Aufgabe geparkt, falls Bedarf.

### Phase 5 Heatmap-Pipeline — Train 3

**Befund (Analyse-Agent gegen `AppHeatmapModel.swift` + `HeatmapGridBuilder.swift`):**

Pipeline: collect (1×) → bin (4× pro LOD) → smooth (4× pro LOD, Kernel) → normalize+filter (4×) → viewport-cull (1× pro Region-Update).

- **Mehrfach-Iteration**: bin/smooth/normalize laufen **4× pro Precomputation** (LOD overview/low/medium/high). Wird in `ensureDensityPrecomputation` orchestriert.
- `lonScale(forLatitude:)` (`HeatmapGridBuilder.swift:61`) wird je 1× pro Punkt im bin-Loop (Z. 79) und 1× pro Cell in `makeCell` (Z. 167) aufgerufen — verschiedene Code-Pfade, keine Redundanz im selben Loop.
- Caches: `lodGrids` + `viewportCache` + `derived_cache` (SQLite) bereits aktiv; Zoom/Pan re-binned nicht, sondern viewport-cult + cache-lookup.

**Entscheidung: Train 3.**

Begründung: Eine Single-Pass-Multi-LOD-Berechnung würde die Kernel-Struktur (LOD-spezifischer Smoothing-Kernel, LOD-spezifische `minimumNormalizedIntensity * precomputationVisibilityFactor`-Schwellen, eigene Normalisierung pro LOD) verschränken. Risiko Farb-/Dichte-Drift ohne goldene Vergleichsdaten — laut Train-2-Regel „keine stille Datenverfälschung" inakzeptabel.

Eine kleinere `lonScale`-Memoisierung wurde **bewusst verworfen**: realer GPS-Track produziert selten exakt identische Latitudes; Dict-Lookup vermutlich teurer als `cos()`. Sähe nach Optimierung aus, ist aber nicht messbar besser. „Keine Performance-Aussage ohne Messwert" → ablehnen.

**Train-3-Aufgabe (formuliert):**
> Refactor `computeGrid(for:lod:scale:)` to support batch multi-LOD computation with intra-pass kernel aggregation, eliminating redundant point-iteration while preserving per-LOD normalization contract. Benchmark memory vs. time for 4-LOD sweep on 50k–500k synthetic point sets. Require golden-output cell-stability tests against the current single-LOD pipeline before merge. Document acceptance via byte-identical normalized intensities for a fixed 1k-point fixture.

### Phase 6 Runtime Smoke
Siehe Abschlussbericht des Trains. Sim+Device-Build-Status separat erhoben. Keine Hardware-FPS-/Memory-Messung — Änderungen sind defensive Filter, kein Render-Pfad-Wechsel.

### Phase 9 Bewusst nicht umgesetzt
- Heatmap Single-Pass-Multi-LOD-Sweep → **Train 3**
- MKMapView + MKMultiPolyline Heavy-Overview Spike → **Train 3** (separater Performance-Vergleich)
- MKTileOverlay-Heatmap → **Train 3+**
- WWDC24 Place ID / `mapItemDetailSheet` → optional (iOS-18+-Check)
- `lonScale`-Memo → bewusst verworfen (kein Messwert für Nutzen)

### Phase 10 Risiken
- Filter ist destruktiv. Bei reinen Valid-Daten **strukturelle Identität** (durch Identity-Test `testValidCoordsUnchanged` belegt).
- Overview-Score: `pointWeight = log(count)` sieht jetzt Filter-bereinigte `coordinates.count`. Bei reinen Valid-Daten kein Effekt; bei 1–2 NaN-Punkten in einem 1000-Punkt-Pfad ist `log(1000) vs log(998)` 0,2 % — irrelevant für Score-Reihenfolge.
- Heatmap density-Cap (500k) wird jetzt strikt valider gemessen — wenn ein Datensatz vorher Cap durch NaN-Punkte „auffüllte", zählt der Cap jetzt nur valide Punkte; im realen Datensatz minimal.
- ExportPreview region-Bounds garantiert finite — vorher bei NaN-Input degraded.

---

## TRAIN 1 — 2026-05-13

### Phase 0 Ausgangslage

Repo aktuell auf 1.0.2/171 (Release-Train-Commit `c1314dc`). Vorherige Map-Audits in `docs/MAP_ARCHITECTURE_AUDIT.md` (2026-05-08 ff.) bleiben die kanonische Bestandsaufnahme der Karten-Pipeline; dieser Train ergänzt punktuelle Härtung und Performance-Mikro-Verbesserungen für die `AppDayMapView`-Surface.

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
