# LocalTimelineStore — Architektur- und Machbarkeitsprüfung

Status: **Research + Phase-1-Spike eingecheckt** (CoordBlob + isolierter SQLite-Store, **nicht produktiv genutzt**, keine UI-/App-Flow-Umschaltung). Folge-Commit nach `45e5fcf`.

## Phase-2-Spike Snapshot (2026-05-08)

- **Eingecheckt**: Schema-Bump `userVersion` **1 → 2** mit neuen Tabellen `visits` und `activities` + Indizes (`idx_days_import_date`, `idx_paths_day_start`, `idx_visits_day_id`, `idx_activities_day_id`). Migration ist additiv (`CREATE TABLE/INDEX IF NOT EXISTS`); v1-DBs werden beim Re-Open transparent angehoben (Test `LocalTimelineStoreLifecycleTests.testMigrationFromSimulatedV1KeepsExistingRowsAndAddsNewTables`).
- **NEU `LocalTimelineImportWriter`**: gehaltene `BEGIN IMMEDIATE … COMMIT/ROLLBACK`-Transaktion, bounded per-day-Aggregat (`(dayId, routeCount, visitCount, distanceM)` pro Datum), Day-Summaries werden im `finalize()` per `UPDATE` geschrieben. Ungültige Entries werden gezählt und übersprungen; `LocalTimelineImportSummary` exponiert `totalEntries`/`skippedEntries`/`dayCount`. Activities mit gültigem `start`+`end` erzeugen automatisch einen 2-Punkt-Pfad in `paths.coord_blob`.
- **NEU `GoogleTimelineStoreImporter`**: `importFromFile`/`importFromData` orchestrieren `GoogleTimelineStreamReader` → Writer. **Materialisiert kein `AppExport`** — durch `testImporterReturnTypeIsSummaryNotAppExport` typgesichert. Visit/Activity/timelinePath-Dispatch analog zur bestehenden `GoogleTimelineConverter.ExportBuilder`-Semantik.
- **`LocalTimelineStore.deleteAll()`**: löscht in einer einzigen Transaktion alle Zeilen aus `activities`/`visits`/`paths`/`days`/`imports`. Idempotent (nicht-throwing auf leerer DB). **Scope explizit DB-only** — Caches/tmp werden in Phase 3 vor UI-Hook ergänzt; das ist im Doc-Kommentar der API und in NEXT_STEPS festgehalten.
- **Linux-Tests grün**: `LocalTimelineStoreLifecycleTests` (6), `LocalTimelineImportWriterTests` (4), `GoogleTimelineStoreImporterTests` (4) inkl. 50k-Visit-Smoke über 50 Tage. `swift test` 1071/2/0 (+14 vs. 1057).
- **Bewusst nicht in Phase 2**:
  - FileProtection-Flag an `sqlite3_open_v2` (iOS-Header).
  - `applicationSupportDirectory/LocationHistory2GPX/Imports/` als produktiver Pfad mit `isExcludedFromBackupKey = true`.
  - Caches/tmp-Lifecycle in `deleteAll()`.
  - Adapter zu `flatCoordinates`-Konsumenten (DayList/DayDetail/Map/Heatmap/Distance/Export).
  - `derived_cache`, RTree `path_bounds`.
  - App-Flow-Umschaltung gegen Conditional Gate.
- **Conditional Gate unverändert**: P0 falls 46-MB-Retest FAILED, P1/P2 falls PASSED. **46-MB-Crashfall bleibt FAILED / pending hardware retest.**

---

## Phase-1-Spike Snapshot (2026-05-08)

- **Eingecheckt**: `Sources/CSQLite/{module.modulemap, shim.h}` (Linux-Shim, pkgConfig `sqlite3`), `Sources/LocationHistoryConsumer/CoordBlob.swift`, `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStore{,Schema,Error}.swift`. Test-Surface: `CoordBlobEncoderTests` (13), `CoordBlobDistanceTests` (2), `LocalTimelineStoreTests` (8). Linux `swift test` 1057/2/0 (vorher 1034 → +23).
- **Encoding bestätigt**: `int32-microdeg-v1`, 8 Bytes/Punkt, lazy Sequence-Decode ohne `[Double]`-Materialisierung. Distanz-Iteration matched Haversine-Baseline auf <1e-5 Relativabweichung.
- **Spike-Schema**: `imports`/`days`/`paths` mit `ON DELETE CASCADE`, Indizes auf `import_id`/`date`/`day_id`, `PRAGMA user_version = 1`, `PRAGMA journal_mode = WAL`. **Nicht** im Spike: `visits`, `activities`, `derived_cache`, RTree `path_bounds` — Phase-2.
- **Bewusst weggelassen**:
  - FileProtection-Flag an `sqlite3_open_v2` (`SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN` ist iOS-only Header) — wird beim iOS-Rollout nachgezogen.
  - `LocalTimelineStore.deleteAll()` (DB + Caches + tmp) — Phase-2-Pflicht vor jedem produktiven App-Hook.
  - `URLResourceKey.isExcludedFromBackupKey` — nicht im Spike, weil Spike keinen `applicationSupportDirectory`-Pfad öffnet, sondern nur `tmpDirectory` für Tests.
  - Adapter zu `flatCoordinates`-Konsumenten — bewusst nicht in dieser Iteration, kein Contract-Break in `main`.
- **Conditional Gate unverändert**: P0 falls 46-MB-Retest FAILED, P1/P2 falls PASSED. **46-MB-Crashfall bleibt FAILED / pending hardware retest.**

---

## Original Research (unverändert)

Status: **Research / Plan**, kein Code in `main` umgesetzt.
Stand: 2026-05-08, HEAD-Anker `ebd8146`, Linux Swift 5.9, 1034/2/0 Tests grün.
Scope: Strukturelle Alternative zum aktuellen In-Memory-`AppExport`-Pfad für sehr große Google-Timeline-Importe (z. B. 46 MB ZIP). **Keine Kartenmodernisierung. Keine ASC-/TestFlight-Aussage. 46-MB-Crashfall bleibt FAILED bis Hardware-Retest.**

Dieses Dokument ist ein Engineering-Compliance-Check, keine Rechtsberatung und keine Apple-Review-Freigabe.

---

## 0. Kontext (Repo-Wahr, kurz)

- **Aktuell**: `AppContentLoader` → `GoogleTimelineStreamReader` → `GoogleTimelineConverter.IncrementalStreamConverter` → `AppExport` (komplett im RAM, `Day`-Liste mit Paths in `flatCoordinates: [Double]`-Form).
- Jetsam-Trigger 2026-05-07 auf iPhone 15 Pro Max iOS 26.4 wurde beim **Erst-Render der lazy projections** (`projectedDays()` / `daySummaries`) auf einer 46-MB-ZIP gemessen, nicht im Streaming-Reader selbst — Streaming + autoreleasepool sind seit `34bc369`/`37a22b7` stabil, das verbleibende Peak liegt im *Materialisieren* der Tagesprojektionen über die volle In-Memory-`[Day]`-Liste.
- **Persistenz heute**: `UserDefaults` (Preferences, `RecentFilesStore`, `WidgetDataStore` per App Group), `ImportBookmarkStore` (Security-Scoped Bookmark, **keine Inhaltsdaten**), `RecordedTrackStore` (`applicationSupportDirectory/LocationHistory2GPX/RecordedTracks/recorded_live_tracks.json`, atomic write, **eigener User-Track-Pfad, kein Import-Cache**). **Kein SQLite, kein CoreData, kein SwiftData, keine eigene Binary-DB.**
- Auto-Restore nach App-Start re-importiert die zuletzt gewählte Datei über den Bookmark — und cappt bei 50 MB, weil es kein lokal persistiertes parsed-State-Cache gibt.

Der LocalTimelineStore existiert **nicht** im Code; dieses Dokument beschreibt eine Zielarchitektur und prüft Machbarkeit.

---

## Aufgabe A — Engineering-Compliance-Check (Privacy / Storage / Backup / FileProtection)

### A.1 Was lokal gespeichert werden darf

Aus reiner Engineering-Sicht (Apple Data Privacy Guidelines + DSGVO-Datenminimierung als Designhilfe; **keine Rechtsberatung, keine Apple-Freigabe-Aussage**) ist on-device-Storage von Standortdaten genau dann unbedenklich, wenn der Nutzer der Importierende ist und die Daten das Gerät nicht verlassen:

| Kategorie | OK lokal? | Begründung im LH2GPX-Kontext |
|---|---|---|
| Importierte Google-Timeline-Daten (ZIP/JSON) | Ja | Nutzer initiierter Import; "All data stays local" ist Repo-Truth (README, APP_FEATURE_INVENTORY). |
| Normalisierte Tage / Pfade / Visits / Activities | Ja | Reiner View über die Importdaten, gleiche Privacy-Klasse. |
| Lokale Indizes (Datum, Bounding-Box) | Ja | Abgeleitet, nicht zusätzlich sensitiv. |
| Render-/Heatmap-/LOD-Caches | Ja | Reproduzierbar aus dem Import; reine Performance-Optimierung. |
| Optionaler Live-Recording-Track | Ja | Bereits heute in `RecordedTrackStore`. **Bleibt getrennt vom Importpfad.** |
| Bearer-Token / Server-URL für Live-Upload | Token Keychain, URL UserDefaults | **Bleibt** wie heute (`KeychainHelper`, `AppPreferences`). |
| Importdaten in `UserDefaults` | **Nein** | UserDefaults ist nicht für massive/sensitive Daten gedacht; Apple PrivacyInfo CA92.1 bezieht sich auf "App Functionality"-Preferences. |

### A.2 Wo gespeichert werden soll

| Verzeichnis | Verwendung im LocalTimelineStore | iOS-Backup-Verhalten | Begründung |
|---|---|---|---|
| `applicationSupportDirectory/LocationHistory2GPX/Imports/` | Persistente Import-DB (z. B. `timeline.sqlite` oder eigene `.bin`) | Backup default; **Empfehlung: `URLResourceKey.isExcludedFromBackupKey = true`**, weil reproduzierbar aus der Original-Quelldatei | Apple-Standard für App-interne dauerhafte App-Daten, aufräumbar nur durch App-Delete. |
| `cachesDirectory/LocationHistory2GPX/RenderCache/` | Heatmap-LOD-Tiles, Day-Snapshots, decimierte Overview-Geometrie | Nie gebackuped, system-purgeable | Reproduzierbar; perfekter Use-Case für `Caches`. |
| `tmpDirectory/LH2GPX-Import-<uuid>/` | Import-Staging (entpackte ZIP-Entries, Streaming-Pufferdateien), Export-Staging (`.gpx`/`.kml` vor User-Save) | Nie gebackuped, system-clean | Kurzlebig; muss am Ende oder beim nächsten Launch garbage-collected werden. |
| `documentsDirectory/` | **Nur** vom Nutzer initiierte Export-Dateien, falls Nutzer sie behalten will | Backup default | Sichtbar in Files-App; wäre Privacy-relevant, falls Importrohdaten dort lägen → **liegen sie nicht**. |
| `applicationSupportDirectory/LocationHistory2GPX/RecordedTracks/` | **Unverändert** (Live-Track-Pfad, separat vom Import) | Wie heute | Bleibt getrennt; Dokumentation-Hinweis im LocalTimelineStore-Doc nötig, dass dies *nicht* der LocalTimelineStore ist. |

### A.3 Privacy-Regeln (Engineering-Check)

1. **Lokal-only ist im Apple-PrivacyInfo-Modell keine "Data Collection".** Die `PrivacyInfo.xcprivacy` muss für reines on-device-Storage **nicht** um zusätzliche `NSPrivacyCollectedDataTypes` erweitert werden.
2. **Server-Upload ist Collection.** Der bestehende, optional aktivierbare Live-Upload (`PreciseLocation`, opt-in, default-off) bleibt **getrennt** vom Importpfad; Importdaten dürfen ohne expliziten neuen Nutzer-Consent **nicht** in den Upload-Pfad geleitet werden.
3. **Keine Standortdaten in `UserDefaults`** — bleibt eingehalten; LocalTimelineStore liegt in `Application Support`, nicht `UserDefaults`.
4. **Keychain-only für Tokens** — bleibt.
5. **Löschfunktion erforderlich.** Engineering-Anforderung an LocalTimelineStore: API `LocalTimelineStore.deleteAll()` muss DB-Datei + `Caches` + `tmp`-Reste entfernen, idempotent, ohne App-Neustart.
   - Exposed in Settings → "Importierte Daten löschen" (Engineering-Pflicht; nicht in dieser Iteration umzusetzen, aber Architekturanforderung).
6. **Privacy Policy Update (Doku, nicht Apple-Aussage)** — `docs/privacy.html` (und `docs/PRIVACY_MANIFEST_SCOPE.md`) müssten beim tatsächlichen Rollout erwähnen: lokale Verarbeitung, keine Drittweitergabe, Retention bis Nutzer-Delete, Backup-Verhalten. **Heute keine Änderung dort, weil LocalTimelineStore noch nicht implementiert ist.**

### A.4 Backup-Regeln

- LocalTimelineStore-DB ist **regenerierbarer Cache** aus der Original-Quelldatei (sofern die noch via Bookmark erreichbar ist) → `isExcludedFromBackupKey = true`.
- Ist die Quelldatei vom Nutzer im Files-App-Container und LH2GPX nur Konsument, dann ist **Re-Import billig**; Backup-Exklusion ist defensiv.
- Falls in Zukunft die DB selbst zur "Source of Truth" wird (d. h. Original-Datei wird nach Import gelöscht), müsste die Backup-Strategie auf **opt-in Backup mit explizitem Nutzer-Setting** umgestellt werden. Für den ersten Wurf bleibt: **DB = Cache, Original = Truth.**
- `Caches` und `tmp` werden nie als nonpurgeable Source of Truth genutzt; LOD-Tiles dürfen durch das System gelöscht werden.

### A.5 File-Protection

| Pfad | Empfohlene `FileProtection` | Begründung |
|---|---|---|
| LocalTimelineStore-DB-Datei | **`completeUnlessOpen`** | Standortdaten sind sensitiv; Background-Refresh / Live-Activity könnten das geöffnet halten. `complete` würde Live-Activity stören. |
| Temp-Exports (`tmp/...`) | `completeUnlessOpen` | Halbsensitiv (Geometrie); gleiche Kompromiss-Logik. |
| Render-Caches (`Caches/...`) | `completeUntilFirstUserAuthentication` (default) | Reine Performance-Tiles, keine direkten Koordinaten in lesbarer Form. |
| Recorded-Live-Tracks (`RecordedTrackStore`) | **Heute kein expliziter Schutz** — Empfehlung im LocalTimelineStore-Rollout: gleichzeitig auf `completeUnlessOpen` heben. |

Engineering-Note: `URLResourceKey.fileProtectionKey` setzen direkt nach Erstellung; bei SQLite via `sqlite3_open_v2` zusätzlich `SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN`-Flag (iOS-only Header).

---

## Aufgabe B — LocalTimelineStore-Architektur (Zielzustand)

### B.1 Pipeline

```
location-history.zip / .json
    │
    ▼
GoogleTimelineStreamReader (existing, unchanged)
    │   per-element JSON object (autoreleasepool on Darwin)
    ▼
LocalTimelineImportWriter (new, replaces ExportBuilder for the on-disk path)
    │   batched INSERTs / append-only writes; bounded RAM working-set
    ▼
LocalTimelineStore.sqlite  (or BinaryStore, see C)
    │
    ├──► LocalTimelineQuery (lazy)
    │       │
    │       ├── Day list      → SELECT day_key, summary_blob FROM days …
    │       ├── Day detail    → SELECT * FROM paths WHERE day_id=?
    │       ├── Overview      → bounds + decimierte Geometrie via path_bounds
    │       ├── Insights      → aggregierte days-Spalten
    │       ├── Heatmap       → derived_cache lookup oder bounded compute
    │       └── Export (GPX/KML/GeoJSON/CSV) → Cursor → Streaming-Builder → tmp/<file>
    │
    └──► AppExport-Compat-Adapter
            (rebuilds in-memory AppExport on demand for legacy UI surfaces;
             scoped/limited; not the default render path)
```

**Invarianten:**

- Beim Import wird **kein** vollständiger `AppExport` mehr im RAM materialisiert.
- Day/Path-Render-Pfade lesen ausschließlich über bounded Queries.
- Export streamt aus DB in eine `tmp/`-Datei; finaler `URL` wird an den iOS-Share-Sheet/`fileExporter` gegeben — keine vollständige Result-`Data` im RAM.

### B.2 Minimales Schema (SQLite-bevorzugt; gleiche Logik in BinaryStore)

```sql
-- Header pro Importvorgang. Mehrere Importe könnten koexistieren; v1: nur ein "current".
CREATE TABLE imports (
    id              INTEGER PRIMARY KEY,
    source          TEXT NOT NULL,        -- 'google_timeline' | 'lh2gpx_app_export' | 'gpx' | 'tcx'
    file_name       TEXT NOT NULL,
    file_size       INTEGER NOT NULL,
    file_sha256     TEXT,
    imported_at     INTEGER NOT NULL,     -- epoch
    schema_version  INTEGER NOT NULL,
    input_format    TEXT,                 -- AppExportInputFormat raw value
    meta_json       TEXT                  -- AppExportMeta JSON; small
);

CREATE TABLE days (
    id              INTEGER PRIMARY KEY,
    import_id       INTEGER NOT NULL REFERENCES imports(id) ON DELETE CASCADE,
    day_key         TEXT NOT NULL,        -- 'YYYY-MM-DD' UTC
    bounds_min_lat  REAL, bounds_max_lat REAL,
    bounds_min_lon  REAL, bounds_max_lon REAL,
    distance_m      REAL,                 -- aggregated effective distance
    visit_count     INTEGER,
    path_count      INTEGER,
    activity_count  INTEGER,
    summary_blob    BLOB                  -- compact `DaySummary` (Codable→CBOR/JSON)
);
CREATE INDEX idx_days_import_day ON days(import_id, day_key);

CREATE TABLE paths (
    id              INTEGER PRIMARY KEY,
    day_id          INTEGER NOT NULL REFERENCES days(id) ON DELETE CASCADE,
    start_epoch     INTEGER, end_epoch INTEGER,
    distance_m      REAL,
    bounds_min_lat  REAL, bounds_max_lat REAL,
    bounds_min_lon  REAL, bounds_max_lon REAL,
    point_count     INTEGER NOT NULL,
    coord_blob      BLOB NOT NULL          -- Int32 microdegrees (lat,lon pairs)
);
CREATE INDEX idx_paths_day ON paths(day_id);

CREATE TABLE visits (
    id              INTEGER PRIMARY KEY,
    day_id          INTEGER NOT NULL REFERENCES days(id) ON DELETE CASCADE,
    start_epoch     INTEGER, end_epoch INTEGER,
    lat             REAL, lon REAL,
    label           TEXT,
    confidence      REAL
);
CREATE INDEX idx_visits_day ON visits(day_id);

CREATE TABLE activities (
    id              INTEGER PRIMARY KEY,
    day_id          INTEGER NOT NULL REFERENCES days(id) ON DELETE CASCADE,
    kind            TEXT,                  -- raw activity-type string
    start_epoch     INTEGER, end_epoch INTEGER,
    distance_m      REAL,
    coord_blob      BLOB                   -- optional, same encoding as paths
);
CREATE INDEX idx_activities_day ON activities(day_id);

-- Render-/Insights-Caches; rein abgeleitet, jederzeit verwerfbar.
CREATE TABLE derived_cache (
    cache_key       TEXT PRIMARY KEY,      -- e.g. 'heatmap.zoom=10.viewport=…'
    payload         BLOB NOT NULL,
    generated_at    INTEGER NOT NULL,
    schema_version  INTEGER NOT NULL
);

-- Optional: nur falls SQLite RTree-Modul verfügbar ist (iOS bringt es mit).
CREATE VIRTUAL TABLE path_bounds USING rtree(
    id,
    min_lat, max_lat,
    min_lon, max_lon
);
```

**Hinweise:**
- `paths.coord_blob` speichert **Int32 microdegrees** (siehe B.3). Kein redundantes `points`-Feld; `flatCoordinates` ist ein in-memory-View auf den Blob.
- `summary_blob` und `meta_json` halten kleine, schnell deserialisierbare Aggregate; keine Geometrie.
- Single-Import-Modell für v1 (`imports`-Tabelle hat genau eine Zeile bei "current"); `ON DELETE CASCADE` macht "Importierte Daten löschen" zur Ein-Zeilen-Operation.

### B.3 Coordinate-Encoding — Vergleich und Empfehlung

| Variante | Bytes/Punkt | CPU-Decode | Genauigkeit | Streaming-fähig | Bewertung |
|---|---|---|---|---|---|
| `Double`-Pair BLOB (16 B) | 16 | trivial (`load(fromByteOffset:as:)`) | volle IEEE-754 | ja | Status quo `flatCoordinates`. **Zu groß** für 1 M-Punkt-Importe (~16 MB pro Pfad-Layer in DB). |
| **`Int32`-microdegrees BLOB (8 B)** | 8 | trivial (`Int32` × 1e-6) | ~11 cm Lat-Auflösung; >> GPS-Rauschen | ja | **Empfohlen.** Halbiert Speicher gegenüber Double; reine Bitshift-Decode; vollständig kompatibel zur bestehenden `flatCoordinates`-Konsument-Logik (Adapter projiziert `Int32` → `Double` lazy). |
| Encoded Polyline (Google Algorithmus) | ~3–5 B (variable) | nicht-trivial; sequenziell | ~1 cm bei `precision=5` | nur sequenziell | Beste Kompression, aber **kein Random-Access**, kein Bounding-Box-Scan ohne Voll-Decode. Ungeeignet für Heatmap-LOD-Iteration. |
| Delta-encoded Int32 + Varint | ~2–3 B | mittel | gleich Int32 | sequenziell | Erspart weitere ~30 %, lohnt sich erst bei sehr großen Pfaden; **Phase 2**. |

**Empfehlung Phase 1**: Int32 microdegrees als 8-Byte little-endian Pairs.

```swift
// Encoder: lat,lon: Double in [-180, 180] → Int32 microdegrees
let latI = Int32((lat * 1_000_000).rounded())
let lonI = Int32((lon * 1_000_000).rounded())
// 8 bytes per point; appendLittleEndian-style write
```

**Streaming-Decode-Iterator** (Pflicht; **kein vollständiges `[Double]`-Materialisieren** für Overview/Export):

```swift
public struct CoordBlobIterator: Sequence, IteratorProtocol {
    public typealias Element = (lat: Double, lon: Double)
    private let blob: Data
    private var offset: Int = 0
    public mutating func next() -> Element? {
        guard offset + 8 <= blob.count else { return nil }
        let latI: Int32 = blob.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset,     as: Int32.self) }
        let lonI: Int32 = blob.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset + 4, as: Int32.self) }
        offset += 8
        return (Double(latI) * 1e-6, Double(lonI) * 1e-6)
    }
}
```

Tests müssen invariant prüfen: **Iterator-Konsumenten allokieren nie ein voll-materialisiertes `[Double]`** (Distance, GPX/KML/GeoJSON-Builder, Heatmap-Aggregator). Stichprobentest: Pfad mit 1 M-Punkten, Memory-Probe vor/nach Distanz-Berechnung darf < 1 MB Delta haben.

### B.4 Query-Architektur

| UI-Surface | Heutiger Pfad | Ziel-Pfad |
|---|---|---|
| Day list | `AppExportQueries.projectedDays()` über volle `[Day]` | `SELECT day_key, distance_m, visit_count, path_count, summary_blob FROM days WHERE import_id=? ORDER BY day_key` (LRU 8). |
| Day detail | Index in `[Day]` | `SELECT * FROM days WHERE id=?`, dann `paths`/`visits`/`activities` per `day_id`. |
| Overview-Karte | Volle Coords-Materialisierung pro Pfad | RTree-Range-Query → Top-N-Pfade nach Bounds-Overlap → Decode-Iterator + Stride-Decimierung (`MapPolyline`-Limit, **bestehende** `OverviewMap`-Logik). |
| Insights | Reduktion über `[Day]` | Aggregation per SQL (`SUM(distance_m)`, `COUNT()`) für Top-Level; Detail-Reductions weiterhin in-Swift, aber bounded. |
| Heatmap | `AppHeatmapModel` über volle Coords | Lookup `derived_cache` für Zoom/Viewport → Cache-Hit; Cache-Miss → bounded compute über RTree-Filter + Decode-Iterator. |
| Export | `[Day]` → String → `Data` | Cursor `SELECT … ORDER BY day_id, path_id` → `CoordBlobIterator` → `OutputStream`-write nach `tmp/<uuid>/<file>.gpx`. **Nie** Voll-String im RAM. |

### B.5 Kompatibilität & Migration

- **Contract bleibt unangetastet.** `AppExport`/`AppExportDecoder`/`AppExportEncoder` bleiben für *Import* (v. a. LH2GPX-Format aus Producer) und *Export* (Roundtrip-Test) erhalten.
- **Bestehende `flatCoordinates: [Double]`-Konsumenten** werden über einen **In-Memory-Adapter** bedient: der LocalTimelineStore-Render-Pfad konvertiert *für eine begrenzte Day-Auswahl* on-demand in den heute erwarteten `Path`-Wert mit `flatCoordinates`. Großdatei-Pfade lassen den Adapter aus und gehen direkt über `CoordBlobIterator`.
- **Demo-/Onboarding-Pfade** (kleine Fixtures) gehen weiterhin über In-Memory-`AppExport` ohne DB; LocalTimelineStore wird **nur** für tatsächlich importierte Dateien aktiviert. Dies hält Tests klein und Onboarding schnell.
- **Heatmap-LOD-Cache** kann sofort vom RAM in `derived_cache` migrieren — schon heute reproduzierbar, Kandidat für Phase 1.5.

---

## Aufgabe C — Machbarkeit im Code (SQLite vs. BinaryStore vs. CoreData)

### C.1 SQLite C-API (libsqlite3.tbd auf iOS, libsqlite3 auf Linux)

| Punkt | Bewertung |
|---|---|
| iOS-Verfügbarkeit | **Ja, ohne Dependency.** `libsqlite3` ist Teil des iOS-SDK; in Swift via `import SQLite3` nach `linkerSettings(.linkedLibrary("sqlite3"))` in `Package.swift`. |
| Linux-Verfügbarkeit | **Ja**, distributionsabhängig (`sudo apt install libsqlite3-dev`). Im aktuellen Container vorhanden? Zu prüfen via `pkg-config --modversion sqlite3` beim Spike-Start. |
| SwiftPM-Setup | Ein neuer `linkerSettings(.linkedLibrary("sqlite3"))` reicht für iOS; Linux braucht `pkgConfig: "sqlite3"` oder system-include-Pfade. **Risiko**: pkgConfig nicht in allen CI-Linux-Containern, evtl. Fallback-Spike-Pfad nötig. |
| RTree-Modul | iOS-`libsqlite3` enthält `SQLITE_ENABLE_RTREE` standardmäßig. Linux hängt vom Build der Distro ab; im Zweifel als optional behandeln (Schema bedingt anlegen, sonst Fallback auf "Index über bounds_min/max + Linear-Scan"). |
| FileProtection | Per `sqlite3_open_v2(... | SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN, ...)` (iOS-Header). Auf Linux ignoriert, wie erwartet. |
| Test-Aufwand | Headless XCTest-Suite ist machbar; CRUD + RTree-Smoke + Iterator-Invariant-Tests in 4–8 Tests abdeckbar. |

### C.2 Eigener BinaryStore

Append-only File mit Header + indexierten Records (Format vergleichbar zu Capnproto/FlatBuffers light):

| Punkt | Bewertung |
|---|---|
| iOS- und Linux-Verfügbarkeit | **Ja** (reines `Foundation.FileHandle` + `Data`). Keine Dependency. |
| Schema-Evolution | Wir müssen Versionsnummer + Migration selbst bauen; SQLite hat dafür `PRAGMA user_version` + bewährte Patterns. |
| Range-Queries / RTree-Äquivalent | Müssten wir selbst implementieren (z. B. einfacher Bounding-Box-Index als sortiertes Sub-File). Aufwand non-trivial. |
| Reaktionsfähigkeit auf Apple-Reviews | Ein eigener Storage-Layer ist okay, erhöht aber Test-/Review-Oberfläche. |

### C.3 CoreData / SwiftData

| Punkt | Bewertung |
|---|---|
| iOS-Verfügbarkeit | Ja. |
| **Linux-Verfügbarkeit** | **Nein.** `CoreData`/`SwiftData` sind Darwin-only — würde unsere Linux-CI-Test-Strategie brechen. |
| Strikter Modellzwang | Mehr Boilerplate; weniger natürliche Abbildung des `coord_blob`-Modells. |

### C.4 Empfehlung

**SQLite-C-API** (Phase 1), mit klar definierten Linux-Test-Guards:

1. Keine neue externe Swift-Dependency (kein GRDB/SQLite.swift initial), sondern direkter `import SQLite3` + ein dünner `LH2GPXSQLite`-Wrapper im AppSupport-Target.
2. Linker-Setting in `Package.swift`:
   - iOS-Targets: `.linkedLibrary("sqlite3")`
   - Linux-Test-Target: gleiche Library; falls Container-Variation existiert, Fallback-Skip-Mechanismus (ähnlich `#if canImport(MapKit)`-Skips bestehender Tests).
3. **Falls** Linux-Build `libsqlite3-dev` nicht zur Verfügung stellt, **dann** als Fallback BinaryStore-Spike rein in Foundation; SQLite bleibt iOS-Pfad. Diese Entscheidung fällt beim Spike-Aufschlag, nicht in diesem Doku-Commit.
4. **Kein** GRDB/SQLite.swift in v1 — vermeidet Apple-Review-Komplikation und Lieferketten-Risiko.

### C.5 Mini-Probe / Spike — Scope für nächste Iteration

Wenn ein Spike kommt, dann **isoliert**:

- `Sources/LocationHistoryConsumerAppSupport/LocalTimelineStorePlan.swift` als pure-Swift Schema-Plan-Datei (keine UI-Umschaltung).
- `Tests/LocationHistoryConsumerTests/CoordinateBlobEncodingTests.swift`:
  - Encode/Decode round-trip, microdegree-Genauigkeit.
  - Streaming-Iterator allokiert kein `[Double]` (Memory-Probe Delta < Threshold).
- `Tests/LocationHistoryConsumerTests/LocalTimelineStoreSchemaPlanTests.swift`:
  - DDL-String-Stabilität (kanonische Schema-Hash-Snapshot-Test, damit Schema-Änderungen review-pflichtig werden).
  - Migrationspfad `schema_version=1 → 2` skizzieren.
- **Keine** Migration der App-UI in dem Commit.

In **diesem** Commit hier wird kein Spike eingecheckt — das Doc setzt nur das Gate.

---

## Aufgabe D — P0-Entscheidungsgate

Bindend an das offene 46-MB-Hardware-Retest-Ergebnis (HEAD `ebd8146`):

- **Wenn `ebd8146` Hardware-Retest PASSED** (vollständige `[LH2GPX_MEMORY]`-Logs, kein Jetsam-Kill, Day/Insights/Export-Smoke grün, Tester-Template aus `docs/APPLE_VERIFICATION_CHECKLIST.md` vollständig ausgefüllt zurückgemeldet): LocalTimelineStore wird **P1/P2 Robustheits-/Skalierungsprojekt** — Adressat sind Importe deutlich >50 MB und Geräte mit knapperem RAM-Budget (4 GB-Klasse). Reihenfolge nach P0-Restpunkten (Live Activity / iPad / Apple Review).
- **Wenn `ebd8146` Hardware-Retest FAILED** (erneuter Jetsam, gleiche oder neue Repro): LocalTimelineStore wird **P0-Fixpfad** — geht *vor* Map-Modernisierung und vor weiterer UI-Politur. Begründung: weiteres Stream-Tuning hat in `34bc369` und `37a22b7` bereits den Streaming-Reader gehärtet; verbleibender Peak liegt im *Render-Materialisieren* der lazy projections und ist ohne strukturelle Änderung (= Storage statt RAM) nicht weiter zu drücken.
- **Map-Modernisierung** (Overview UIKit MKMapView/MKMultiPolyline/MKTileOverlay, Heatmap-Tile-Overlay) bleibt **vor 46-MB-Pass oder klarer LocalTimelineStore-P0-Entscheidung blockiert**, weil sie ein bewegliches Ziel auf einem instabilen Datenmodell wäre.

---

## Offene Risiken (nur Engineering)

1. **Linux-`libsqlite3`-Verfügbarkeit** in der konkreten CI-Container-Variante muss beim Spike geprüft werden; sonst BinaryStore-Fallback.
2. **Schema-Migration** ist v1 nicht ausgereizt (single-import Modell). Multi-Import / mehrere Quellen gleichzeitig ist eine Phase-2-Erweiterung.
3. **Adapter-Aufwand**: Bestehende `Path.flatCoordinates`-Konsumenten umzustellen ist eher Surface-Aufwand als Algorithmus-Aufwand, aber breit verteilt (DayMap, Heatmap, Distance, ExportBuilder, Snapshots). Die Adapter-Strategie hält v1 kompatibel; v2 entfernt den Adapter.
4. **Apple-Review**: Reine on-device-Persistenz ohne neuen Datenpunkt erfordert *kein* `PrivacyInfo.xcprivacy`-Update; sollte sich der Speicherort (`Application Support`) oder die Backup-Strategie ändern, ist eine Aktualisierung von `docs/PRIVACY_MANIFEST_SCOPE.md` und `docs/privacy.html` Pflicht **vor** TestFlight-Resubmit. **Keine Apple-Freigabe-Aussage hier.**
5. **46-MB-Crashfall bleibt FAILED**, bis ein vollständiges Tester-Ergebnis-Template mit `Ergebnis: PASSED` zurückgemeldet ist. Nichts in diesem Doku-Commit ändert daran.

---

## Zusammenfassung für CHANGELOG/NEXT_STEPS

- Research-Doku angelegt: `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`.
- Empfehlung: **SQLite-C-API + Int32-microdegrees-BLOB**, Application-Support-Speicherort, `completeUnlessOpen`, backup-excluded.
- Conditional-P0-Gate definiert; Map-Modernisierung weiter blockiert.
- Kein Code in `main` umgeschaltet. Spike in dedizierter Folge-Iteration; Test-Plan dort: `CoordinateBlobEncodingTests`, `LocalTimelineStoreSchemaPlanTests`, Iterator-No-Allocation-Invariant.
