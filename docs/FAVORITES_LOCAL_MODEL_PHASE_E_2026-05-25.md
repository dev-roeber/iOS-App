# Favorites Local Model — Phase E (2026-05-25)

**Start-HEAD:** `1bbf743` (Phase D.1) · **Phase:** E · **Scope:** lokales `FavoriteEntry`-Modell + Persistenz in Application Support + idempotente Migration aus dem bestehenden `DayFavoritesStore`. **Foundation für Phase F (echter CloudKit-Favoriten-Sync).** Keine CloudKit-Operationen in Phase E.

## 1. Was wurde gebaut

| Komponente | Datei | Zweck |
|---|---|---|
| `FavoriteEntry` Codable struct | `Sources/.../FavoriteEntry.swift` | Cross-device-stabile Favoriten-Metadaten ohne sensible Felder |
| `FavoriteItemKind` enum | dito | persisted rawValue (`day`); neue Kinds appenden, nicht renamen |
| `FavoriteIDFactory` | dito | Deterministische `UUID` aus `(itemKind, legacyID)` via Foundation-only SHA-256 + RFC-4122-Layout (v5-Style) |
| `FavoriteEntryStore` | `Sources/.../FavoriteEntryStore.swift` | JSON-Persistenz in `Application Support/LocationHistory2GPX/Favorites/favorite_entries.json` + on-demand Legacy-Migration |
| 12 Unit-Tests | `Tests/.../FavoriteEntryStoreTests.swift` | Codable-Roundtrip, Privacy-Sweep, Deterministik, Disk-Pfade, Korrupt-Recovery, set/remove/toggle, Migration-Idempotenz, Backward-Compat zum bestehenden `DayFavoritesStore` |

## 2. Persistenz-Architektur

- **Pfad:** `<Application Support>/LocationHistory2GPX/Favorites/favorite_entries.json`
- **Format:**
  ```json
  {
    "schemaVersion": 1,
    "entries": [ { "favoriteID": "…", "legacyID": "2024-04-12", "itemKind": "day", "isFavorite": true, ... }, ... ]
  }
  ```
- **Write:** `Data.write(to:options: [.atomic])` — Apple-empfohlen für kleine JSON-Files. Verhindert Korruption bei Crash/Kill mid-write.
- **Read:** `JSONDecoder` mit `.iso8601`-Date-Strategy. Fehlende Datei → leer + Legacy-Migration. Korrupte Datei → Quarantäne als `favorite_entries.corrupt-<timestamp>.json` + leer + Logger-Eintrag (ohne Payload).
- **`isExcludedFromBackup`:** Default (`false`) — Favoriten sind User-Daten und sollen ins iCloud-/iTunes-Backup mit.
- **FileProtection:** Default (`.completeUntilFirstUserAuthentication`) reicht — keine sensiblen Felder im Record.

## 3. Migration aus `DayFavoritesStore`

- **Legacy-Quelle:** `UserDefaults.standard` Key `"app.dayFavorites"` → `[String]` ISO-8601-Day-IDs → `Set<String>` (siehe `DayFavoritesStore.swift`).
- **Migration:** `FavoriteEntryStore.loadEntries()` ruft bei fehlender JSON-Datei einmalig `legacySource()` und mappt jeden ISO-Day-String auf einen aktiven `FavoriteEntry(itemKind: .day)` mit deterministischer `favoriteID`. Anschließend wird der Marker `"app.favorites.entry.legacyMigrated.v1"` in `UserDefaults` gesetzt.
- **Idempotenz:** Bei zweitem Aufruf (Marker = `true`) wird Legacy NICHT mehr gelesen — auch wenn der User in der Zwischenzeit lokal Favoriten gelöscht hat (Tombstone bleibt erhalten).
- **DayFavoritesStore bleibt unverändert.** Bestehende 13 UI-Call-Sites + 8 Tests funktionieren weiter. Phase F wird beide Layer synchron halten oder DayFavoritesStore deprecaten.

## 4. Privacy-Sweep — was im Record NIEMALS landet

Verifiziert durch `testFavoriteEntryHasNoSensitiveFields` (sucht im JSON-Output 13 verbotene Substrings):

- ❌ `latitude` / `longitude` / `coordinate`
- ❌ `polyline` / `rawLocation`
- ❌ `altitude` / `elevation` / `verticalAccuracy`
- ❌ `placeID` / `visitedPlace`
- ❌ `filePath` / `file://`
- ❌ `Bearer` / `Authorization` / `Token`

`legacyID` ist eine ISO-8601-Day-String — keine PII, keine Koordinate.

## 5. Apple-Doku (geprüft)

- **FileManager Application Support:** `url(for:.applicationSupportDirectory, ..., create: true)` legt das Verzeichnis auto an; Subdirs (`LocationHistory2GPX/Favorites/`) brauchen explizites `createDirectory`.
- **Data.WritingOptions:** `.atomic` ist Apple-Empfehlung für kleine JSON-Files.
- **`JSONEncoder/Decoder`:** `.iso8601`-Date-Strategy + `.prettyPrinted`/`.sortedKeys` matched Repo-Convention (`RecordedTrackStore`, `LiveTrackCloudBackup`).
- **UserDefaults-Migration:** Marker-Key-Pattern ist Apple-Konvention (siehe `RecentFilesStore.migrateIfNeeded`).
- **`isExcludedFromBackup`:** Default für User-Daten (Apple File System Programming Guide).

## 6. Warum kein CloudKit-Favoriten-Sync in Phase E

- Phase E ist explizit **lokale Foundation**.
- Phase F (folgt) baut darauf:
  - `FavoritesCloudSyncService` mit `privateCloudDatabase.save/fetch/delete` für `FavoriteEntry`-Records,
  - Conflict-Policy aus 9.0 (`AppICloudSyncConflictPolicy`) wird angewendet,
  - Pull-Outbox, Retry, `serverRecordChanged`-Merge,
  - UI-Toggle „Sync Favorites to iCloud" in `AppICloudOptionsView`,
  - Anti-Claim-Reset für `FavoriteEntry`-Records (vergleichbar zu Phase D für `LH2GPXLiveTrackSummary`).
- Trennen Phase E/F minimiert Risiko (jeder Layer für sich testbar, Rollback eines Layers ist möglich).

## 7. UI-/Call-Site-Adoption

In Phase E **bewusst keine UI-Migration**:
- Die 13 UI-Call-Sites von `DayFavoritesStore` (in `AppContentSplitView`, `AppDayListView`, `AppExportView`) bleiben funktional unverändert.
- `FavoriteEntryStore` läuft parallel als Foundation.
- Phase F wird beide Layer synchron halten oder eine gemeinsame UI-Bridge bauen.

Begründung: Eine sofortige UI-Migration würde alle 13 Call-Sites + 8 bestehende Tests anfassen; das ist eigener Refactor-Train und nicht im Phase-E-Scope.

## 8. Tests (Pflicht, alle grün)

`swift test --filter FavoriteEntryStoreTests` → **12 Tests / 0 failures** (0,07 s):

1. `testFavoriteEntryCodableRoundtrip` — Encode/Decode-Identität, schemaVersion korrekt.
2. `testFavoriteEntryHasNoSensitiveFields` — 13 verbotene Substrings im JSON.
3. `testFavoriteIDFactoryIsDeterministic` — gleiche Eingabe → gleiche UUID.
4. `testFavoriteIDFactoryDiffersByLegacyIDAndKind` — unterschiedliche Eingaben → unterschiedliche UUIDs.
5. `testMissingFileReturnsEmptyStoreWhenNoLegacy` — kein File + kein Legacy = leer.
6. `testCorruptFileDoesNotCrashAndQuarantines` — invalid JSON → kein Crash + Quarantäne-Datei vorhanden.
7. `testSetAndRemoveDayFavoritePersists` — write→read→re-instantiate; Tombstone retained.
8. `testToggleDayFavoriteReturnsNewState` — toggle gibt korrekt `Bool` zurück.
9. `testLegacyMigrationImportsExistingDayFavoritesOnce` — Migration legt 3 Einträge an + Marker; zweiter Read ruft Legacy NICHT erneut.
10. `testLegacyMigrationIsIdempotentAcrossNewStoreInstances` — neue Store-Instanz importiert nicht erneut; Tombstones bleiben.
11. `testMigrationWithEmptyLegacyProducesEmptyStoreAndMarker` — leerer Legacy-Set + Marker korrekt gesetzt.
12. `testDayFavoritesStoreStillWorksUnchanged` — bestehende API funktioniert weiter.

Plus: `swift test --filter DayFavoritesStoreTests` → 8/0 weiterhin grün. Backward-Compat verifiziert.

## 9. Anti-Claims (verbindlich nach Phase E)

- ❌ Echter CloudKit-Favoriten-Sync implementiert
- ❌ `CKRecord`/`CKDatabase`/`CKQuery` für Favoriten
- ❌ Public/Shared CloudKit-Database
- ❌ `CKAsset` / `CKSubscription`
- ❌ Koordinaten / Polylines / Altitudes in `FavoriteEntry`
- ❌ UI komplett auf neuen Store migriert (bewusst Phase F)
- ❌ `DayFavoritesStore` deprecated (bleibt aktiv)
- ❌ Tests vollständig UITests (nur Unit-Tests in Phase E)

## 10. Nächster Schritt

**Phase F** — Echter CloudKit-Favoriten-Sync:
- `FavoritesCloudSyncService` mit `privateCloudDatabase.save/fetch/delete` für `FavoriteEntry`-Records.
- `CKRecord.ID(recordName: favoriteID.uuidString)` für deterministische cross-device-IDs.
- Conflict-Policy aus 9.0 (`AppICloudSyncConflictPolicy`) anwenden.
- Pull-on-launch + Settings-Refresh; keine CKSubscription initial.
- UI-Toggle in `AppICloudOptionsView`.
- Anti-Claim-Reset für `FavoriteEntry`-Records.
- Tests + Build-Verifikation.
