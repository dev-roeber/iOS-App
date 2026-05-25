# Localization · Favorites-iCloud-Sync · iPad — Implementation Spec

**HEAD geprüft:** `48722f5` · **Train-ID:** Master-Train (L10n + Favorites + iCloud Sync + iPad) · **Phase A** abgeschlossen mit Doku-only, **Phasen B–H** stehen aus.

> **Status dieser Datei:** reine Architektur-Spezifikation. **Keine Funktion in dieser Phase implementiert.** Was hier als „geplant" beschrieben ist, ist noch nicht im Code.

---

## 1. Scope

Drei zusammenhängende Produktziele in einem phasierten Master-Train:

1. **Vollständige Lokalisierung** der gesamten App auf **Englisch** (Base) und **Deutsch**.
2. **Echter iCloud-Sync** ausschließlich für **Favoriten-Metadaten** (kein History-, Track- oder Koordinaten-Sync).
3. **iPad-Universal-Support** mit aktiviertem `TARGETED_DEVICE_FAMILY = 1,2` und Layout-Audit.

**Ausdrücklich nicht in diesem Master-Train:**
- Keine vollständige Standort-Historien-Synchronisation.
- Keine Track-/Polyline-Synchronisation.
- Kein automatischer Upload aus Import/Export.
- Keine Public/Shared CloudKit-Database.
- Keine CloudKit Assets.
- Keine CKSubscription (initial Pull-only).
- Keine externen Server.
- Kein iPad-Multi-Window/Stage-Manager-spezifischer Umbau.
- Kein Light-Mode-Support.

---

## 2. Apple-Doku-Abgleich (geprüft, mit Quellen)

### 2.1 Localization
- **Localizing and varying text with a string catalog** — `Localizable.xcstrings` ist die 2025/2026-empfohlene Mechanik. Speicherort pro Target: am Target-Root oder in `Resources/` mit `.process`-Rule. Bundle-Auflösung über `Bundle.module` pro Modul. Mischbetrieb SPM + Xcode-Wrapper ist explizit unterstützt.
  https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
- **Package.swift `defaultLocalization`** — Pflicht sobald Resources lokalisiert werden: `Package(name: "...", defaultLocalization: "en", ...)`.
  https://developer.apple.com/documentation/packagedescription/package
- **API-Wahl:** `LocalizedStringKey` für SwiftUI-Views (`Text("Key")` implizit), `LocalizedStringResource` (iOS 16+) für AppIntents/Cross-Module/Bundle-Override (lazy), `String(localized:)` für UIKit/Logic (eager).
  https://developer.apple.com/documentation/foundation/localizedstringresource
- **Koexistenz:** Bestehender Custom-Helper `AppLanguagePreference.localized(_:)` darf parallel zu `.xcstrings` laufen — `.xcstrings` ersetzt nur das Storage-Backend (`.strings`/`.stringsdict`). Kein Zwangs-Switch.
- **InfoPlist:** `InfoPlist.xcstrings` State-of-the-art 2025/2026. `INFOPLIST_KEY_*`-Build-Settings bleiben für statische Werte, werden bei Lokalisierungsbedarf überschrieben.
- **AppIntents:** `LocalizedStringResource` inline reicht (`@Parameter(title: "Key")`). Strings werden vom AppIntents-Compiler extrahiert.
- **String-Extraction:** Xcode 15+ Auto-Discovery via `SWIFT_EMIT_LOC_STRINGS=YES` bei jedem Build (Catalog-Entry-State „New"). `xcodebuild -exportLocalizations` weiterhin für XLIFF-Handoff.

### 2.2 CloudKit Favoriten-Sync
- **Initial-Fetch:** `CKDatabase.records(matching:inZoneWith:desiredKeys:resultsLimit:)` async (iOS 15+) ersetzt manuelles `CKQueryOperation`-Setup. Bei >100 Results: Cursor via Tuple-Return + `records(continuingMatchFrom:)`.
  https://developer.apple.com/documentation/cloudkit/ckdatabase/records(matching:inzonewith:desiredkeys:resultslimit:)
- **Schema-Deployment:** Development-Env erstellt unbekannte recordTypes/Felder **automatisch**. Production: **kein** Auto-Create — Promotion manuell im CK-Dashboard via „Deploy Schema to Production".
  https://developer.apple.com/documentation/cloudkit/designing-and-creating-a-cloudkit-database
- **`CKError.serverRecordChanged`:** Best-Practice ist **merge-by-field** auf `serverRecord` aus `userInfo` anwenden, dann re-save. Niemals `clientRecord` blind re-pushen. LWW nur wenn fachlich vertretbar.
  https://developer.apple.com/documentation/cloudkit/ckerror/code/serverrecordchanged
- **Offline-Queue:** `CKModifyRecordsOperation` mit `savePolicy = .ifServerRecordUnchanged` + persistenter Outbox. Retry via `CKErrorRetryAfterKey`. `NSPersistentCloudKitContainer` wäre Default — wird hier **nicht** verwendet, weil bestehende Persistenz kein Core Data nutzt.
  https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation
- **`CKQuerySubscription`:** für Push-Multi-Device-Sync nötig — wird in diesem Train **nicht** implementiert (Pull-on-launch + Settings-Refresh reicht für „eventual consistency"). Subscriptions benötigen Remote-Notifications-Entitlement.
  https://developer.apple.com/documentation/cloudkit/ckquerysubscription
- **Deterministic Record-ID:** `CKRecord.ID(recordName: favoriteID.uuidString, zoneID:)` ist Apple-Convention für stable cross-device-IDs. Idempotente Writes.
- **Privacy Manifest:** CloudKit ist **nicht** in der Required-Reason-API-Liste. Schreiben von Metadata-Records ohne PII/Location erfordert **keinen** neuen `NSPrivacyAccessedAPIType`-Eintrag.

### 2.3 iPad-Universal-Support
- **`TARGETED_DEVICE_FAMILY = 1,2`** als Build-Setting reicht; `UISupportedInterfaceOrientations~ipad` separat in Info.plist (im Repo bereits gesetzt).
  https://developer.apple.com/documentation/bundleresources/information-property-list/uisupportedinterfaceorientations
- **`TabView` vs `NavigationSplitView`:** `TabView` bleibt valid auf iPad (iOS 18/19); seit iOS 18 rendert es auf iPad standardmäßig als Sidebar-adaptive Tab Bar. `NavigationSplitView` für hierarchische Content-Browser. **Keine Pflicht zum Split-Layout-Umbau.**
- **`horizontalSizeClass`:** Fullscreen-iPad = `.regular`. Slide Over / schmales Split-Multitasking = `.compact`.
- **App-Icon:** Single Universal-Slot (1024×1024) genügt seit Xcode 14+. Widget-Extension nutzt eigenes Asset, Universal ausreichend.
- **Multitasking:** Slide Over + Split View automatisch wenn `UIRequiresFullScreen = false` (Default). Stage Manager: keine extra API.
- **`UIRequiresFullScreen`:** **nicht setzen** — Default `false` ermöglicht Multitasking.

### 2.4 App Review / Privacy
- **App Store Review Guidelines 5.1 Privacy** — unverändert 2025/2026. CA92.1 + 0A2A.1 weiterhin valide.
- **CloudKit-Favoriten ohne PII/Location:** kein neuer Privacy-Manifest-Eintrag nötig.
- **App Privacy Details (ASC):** CloudKit-Favoriten-Sync ist „Other User Content" (nicht-sensible Metadaten). Kein neuer Data-Type. Existierender `NSPrivacyCollectedDataTypePreciseLocation` bleibt unberührt (betrifft nur optionalen Live-Upload).

---

## 3. Architekturentscheidung — Localization

### 3.1 Mechanik
- **`Localizable.xcstrings`** pro Target:
  - `Sources/LocationHistoryConsumerAppSupport/Resources/Localizable.xcstrings` (SPM-Target, ~668 `t()`-Call-Sites)
  - `wrapper/LH2GPXWrapper/Localizable.xcstrings` (Xcode-Target, ~24 `t()`-Call-Sites + LocalTimeline-Views)
  - `wrapper/LH2GPXWidget/Localizable.xcstrings` (Widget-Target, falls user-facing Strings)
  - `wrapper/LH2GPXWrapper/InfoPlist.xcstrings` (Permission-Beschreibungen)
- **`Package.swift`:** `defaultLocalization: "en"` + `.process("Resources")` Resource-Rule für `LocationHistoryConsumerAppSupport`.
- **Base-Language:** **Englisch** (`en`). Deutsch (`de`) als gleichwertige Übersetzung.

### 3.2 Koexistenz
- **Bestehende `AppLanguagePreference.localized(_:)`** + `AppGermanTranslations` Dictionary (118+ Pairs) bleibt erhalten.
  - Vorteil: User-Sprachpräferenz wird per `AppPreferences.appLanguage` **app-intern** umgeschaltet (nicht via iOS-System-Locale). Das ist eine Produktentscheidung — Apple's Bundle-Lookup ehrt nur die System-Locale, nicht App-interne Settings.
- **`.xcstrings`** wird parallel angelegt mit **identischen Übersetzungen** (Export aus `AppGermanTranslations`). Vorteile:
  - Apple-Translation-Workflow (XLIFF-Export, Xcode-UI-Editor) möglich.
  - AppIntents/Widget/InfoPlist nutzen automatisch Apple-Mechanik.
  - Zukunftssicher, falls App-interne Sprach-Umschaltung später entfällt.
- **Migration der hardcoded Strings:** 37 `Text("…")`/`Button("…")`/etc. in `LocalTimeline*`-Views auf `t("…")` migrieren. Sicherstellt vollständige `AppLanguagePreference`-Coverage.
- **Single source of truth** für DE-Übersetzungen: weiterhin `AppGermanTranslations` Dictionary. `.xcstrings` wird daraus generiert/synchron gehalten.

### 3.3 Was nicht übersetzt wird
- `accessibilityIdentifier` (UITest-Hooks)
- `UserDefaults`-Keys
- `enum rawValues` mit Persistenz
- API-Field-Names, JSON-Keys
- CloudKit `recordType`/Field-Keys (technische Schema-Identifier)
- File-Extensions (`gpx`, `kml`, etc.), UTType-Identifier
- Log-Categories
- Test-Fixture-Filenames

### 3.4 Dynamic-Type-Risiken
- Deutsche Strings sind oft ~25–40 % länger als englische. Layout-Checks in Phase B nach Migration: keine harten `lineLimit(1)` ohne Grund, `fixedSize(horizontal: false, vertical: true)` an kritischen Stellen, ausreichend Padding in Settings-Rows.

---

## 4. Architekturentscheidung — Favoriten-iCloud-Sync

### 4.1 Datenmodell
**Neuer Codable struct `FavoriteEntry`** (in neuer Datei `Sources/.../FavoriteEntry.swift`):

```swift
public struct FavoriteEntry: Codable, Identifiable, Equatable, Sendable {
    public let favoriteID: UUID            // stabile ID, deterministisch
    public let schemaVersion: Int          // 1
    public let itemKind: FavoriteItemKind  // .day (Phase 1; weitere später)
    public let referenceKey: String        // z.B. ISO-Date "2025-04-12"
    public var isFavorite: Bool            // false = Tombstone
    public let createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?            // Soft-Delete
    public var localModifiedAt: Date       // für Outbox-Dirty-Flag
}

public enum FavoriteItemKind: String, Codable, CaseIterable, Sendable {
    case day
}
```

**Stable Favorite-ID:**
- Für migrierte Bestände aus `DayFavoritesStore` (UserDefaults Set<String> mit ISO-Date-IDs): `UUID(namespace: "lh2gpx.favorite.day", input: dateString)` (UUIDv5-ähnlich, lokal deterministisch).
- Für neue Favoriten: `UUID()`.

### 4.2 CloudKit Schema
**Neue Datei `Sources/.../CloudKitFavoriteEntrySchema.swift`** (analog zu bestehender `CloudKitLiveTrackMetadataSchema.swift`):

```
recordType:    "FavoriteEntry"
recordName:    favoriteID.uuidString  // deterministic
zoneID:        CKRecordZone.default()
fields:
  schemaVersion: Int64
  itemKind:      String
  referenceKey:  String
  isFavorite:    Int64 (0/1)
  createdAt:     Date
  updatedAt:     Date
  deletedAt:     Date?
  localModifiedAt: Date
```

**Was NICHT im Record steht:**
- ❌ `latitude`, `longitude`, `altitude`, `verticalAccuracy`
- ❌ Polyline, raw Path
- ❌ File-Pfade, Filenames
- ❌ Google Timeline Place-IDs, Adressen
- ❌ Bearer-Token, Auth-Headers
- ❌ Track-Punkte, Visit-Daten

### 4.3 Sync-Engine
**Neue Datei `Sources/.../FavoritesCloudSyncService.swift`** mit:

- `func enableSync()` / `func disableSync()` — Opt-in/Opt-out
- `func performSync()` — Pull remote + push pending local
- `func push(favorite: FavoriteEntry)` — markiert in Outbox als dirty
- `func delete(favoriteID: UUID)` — Tombstone-Write + remote-delete
- `func currentStatus` — `enum FavoritesSyncStatus { .disabled, .ready, .syncing, .error(...) }`

**Operationen:**
- `accountStatus` über bestehenden `CloudKitCloudSyncService`
- `privateCloudDatabase.save(_:)` (async)
- `privateCloudDatabase.records(matching:)` (async, iOS 15+) — initialer Full-Pull beim Enable + bei manuellem Refresh
- `privateCloudDatabase.deleteRecord(withID:)` (async) — für Tombstones
- **Keine CKSubscription** in diesem Train. Sync-Trigger:
  1. App-Launch (wenn Sync enabled)
  2. Settings-Refresh-Button
  3. Toggle „Favorite" → fügt zur Outbox + best-effort sofortiger Push

### 4.4 Conflict-Handling
- Nutzt bestehendes `AppICloudSyncConflictPolicy` Enum aus Train 9.0 (manual / preferLocal / preferCloud).
- Default `.manual` → bei Konflikt: User-Dialog mit „Local | Cloud" + Resolve.
- `.preferLocal` → bei `serverRecordChanged`: lokal gewinnt, re-push mit `savePolicy = .changedKeys`.
- `.preferCloud` → lokal verwerfen, remote übernehmen.
- **`isFavorite = false` (Tombstone) gewinnt** immer in `.manual` und `.preferCloud` (Lösch-Intention respektieren).

### 4.5 Offline-Outbox
- Persistente JSON-Datei `~/Library/Application Support/lh2gpx/favorites-outbox.json`.
- Pending-Liste pro `favoriteID` mit „last attempt" Timestamp.
- Retry: bei nächstem `performSync()` oder Account-Status-Wechsel auf `.available`.
- Bei `CKErrorRetryAfterKey`: Backoff respektieren.
- Outbox bleibt persistent über App-Restart.

### 4.6 UI
**Settings → iCloud (`AppICloudOptionsView`):**
- Neuer Toggle „Sync Favorites to iCloud" (`options.icloud.favoritesSync.toggle`).
- Status-Karte: „Last sync: X minutes ago / X favorites in cloud / N pending / error message".
- „Sync now" Button (`options.icloud.favoritesSync.now`).
- Destructive Action: „Delete cloud favorites" mit `confirmationDialog` (löscht **nur Cloud-Records**, lokale Favoriten bleiben).

**Day-Row Star-Toggle:**
- Bleibt funktional identisch (lokale Aktion).
- Wenn Sync enabled → schreibt parallel in Outbox + best-effort sofortiger Push.

### 4.7 Anti-Claim-Reset (verbindlich ab Phase D)
| Operation | vorher | jetzt erlaubt? |
|---|---|---|
| `CKContainer.accountStatus` | ✅ aktiv | ✅ unverändert |
| `privateCloudDatabase.save(_:)` für `FavoriteEntry` | ❌ verboten | ✅ **erlaubt** (FavoriteEntry only) |
| `privateCloudDatabase.records(matching:)` (CKQuery-Äquivalent) für `FavoriteEntry` | ❌ verboten | ✅ **erlaubt** (FavoriteEntry only) |
| `privateCloudDatabase.deleteRecord(withID:)` für `FavoriteEntry` | ❌ verboten | ✅ **erlaubt** (FavoriteEntry only) |
| `CKModifyRecordsOperation` für `FavoriteEntry` | ❌ verboten | ✅ **erlaubt** (Outbox-Batches) |
| Public/Shared CloudKit DB | ❌ verboten | ❌ **bleibt verboten** |
| `CKAsset` | ❌ verboten | ❌ **bleibt verboten** |
| `CKSubscription` | ❌ verboten | ❌ **bleibt verboten** in diesem Train |
| History-/Track-/Koordinaten-Sync | ❌ verboten | ❌ **bleibt verboten** |
| Auto-Upload aus Import/Export | ❌ verboten | ❌ **bleibt verboten** |

---

## 5. Architekturentscheidung — iPad-Universal-Support

### 5.1 Build-Setting
- `wrapper/LH2GPXWrapper.xcodeproj/project.pbxproj`: `TARGETED_DEVICE_FAMILY = "1,2"` an **allen 10 Stellen** des Wrapper-App-Targets.
- Widget-/Extension-Targets prüfen: nur ändern, wenn iPad-Widget gewünscht. **Default in Phase E: Widget bleibt iPhone**, falls Risiko unklar.
- Info.plist `UISupportedInterfaceOrientations~ipad` ist bereits gesetzt (Portrait/PortraitUpsideDown/LandscapeLeft/LandscapeRight). Keine Änderung nötig.

### 5.2 Layout-Audit
- `AppContentSplitView.swift:607` enthält bereits `NavigationSplitView`-Pfad für `horizontalSizeClass == .regular` (iPad-fullscreen). **Code-ready** — nur Build-Setting-Aktivierung nötig.
- Layout-Audit-Checkliste (Phase E):
  1. Settings/Privacy/iCloud nicht als schmale iPhone-Karten in iPad-Regular.
  2. Map-Controls nicht in Statusbar.
  3. Bottom-Sheets-Höhe iPad-tauglich.
  4. Landscape-Support.
  5. Variant-B-Pro-Tokens (9.0) sind size-class-agnostisch — keine Anpassung nötig.

### 5.3 Was iPad bewusst NICHT bekommt
- Stage-Manager-spezifisches Multi-Window-Setup.
- Pointer-Hover-Effekte über bestehende SwiftUI-Defaults hinaus.
- Keyboard-Shortcuts (außer SwiftUI-Defaults).
- iPad-spezifische Sidebar-Custom-UI (TabView mit iPadOS 18 Sidebar-Adaptive ist ausreichend).

### 5.4 Test-Verifikations-Plan (deferred)
- `xcrun simctl list devices available` → iPad Pro 13" (M4) oder iPad Air 13" (M3).
- `xcodebuild` build/test gegen iPad-Sim.
- Layout-Sichtprüfung in Phase G build-only; Test-Run in eigenem Folge-Train.

---

## 6. Migration / Backward Compatibility

### 6.1 Localization-Migration
- Bestehender `AppLanguageSupportTests.swift` (58 Tests) muss grün bleiben — der Dictionary-Lookup bleibt unverändert.
- `.xcstrings`-Anlage ändert **kein** Verhalten des bestehenden Codes.
- 37 hardcoded `Text("…")`-Migrationen ändern Verhalten nur insoweit, als deutsche User jetzt deutsche Strings sehen statt englischer.

### 6.2 Favoriten-Migration
- Beim ersten App-Start mit aktivierter Sync-Engine:
  1. Lese bestehende `DayFavoritesStore.load()` → `Set<String>` (ISO-Date-IDs).
  2. Für jeden Date-String → erzeuge `FavoriteEntry(favoriteID: deterministicUUID(date), itemKind: .day, referenceKey: date, isFavorite: true, ...)`.
  3. Persistiere lokales `[FavoriteEntry]` Array (neue Datei `~/Library/Application Support/lh2gpx/favorites.json`).
  4. Push in Outbox.
- `DayFavoritesStore` bleibt als **Read-Through-Cache** erhalten (kein Breaking Change für bestehende Reads in `AppContentSplitView:1174`).
- Reset löscht **nur lokal**, **nicht Cloud-Records** (sonst Datenverlust auf anderen Devices). Separate Action „Delete cloud favorites".

### 6.3 iPad-Migration
- `TARGETED_DEVICE_FAMILY`-Wechsel ist nicht-destructive: bestehende iPhone-Installationen bleiben unbeeinflusst, iPad-Installationen werden neu möglich.
- Keine Daten-Migration.

### 6.4 Backward-Compatible Codable
- `FavoriteEntry` mit `schemaVersion: Int` ab Tag 1. Decoder nutzt `decodeIfPresent` für später hinzukommende Felder.
- `DayFavoritesStore`-Format (Array<String>) bleibt lesbar; Migrations-Pfad einseitig (DayFavoritesStore → FavoriteEntry, nicht zurück).

---

## 7. Privacy / App-Store-Grenzen

### 7.1 PrivacyInfo.xcprivacy
- **Keine Änderung** nötig.
- CloudKit-Writes ohne PII/Location erfordern keinen neuen `NSPrivacyAccessedAPIType`.
- `NSPrivacyCollectedDataType` bleibt wie bisher (`PreciseLocation` Linked=false, Tracking=false, AppFunctionality).

### 7.2 App Privacy Details (ASC)
- Favoriten-Metadaten in iCloud Private DB sind nicht „Linked to User Identity" im Apple-Sinne (User authentifiziert sich gegen Apple, nicht gegen LH2GPX; keine eigene User-ID).
- Kein neuer Data-Type-Eintrag.

### 7.3 App Review Notes (zu ergänzen)
- iCloud sync is opt-in, default off.
- Sync scope: favorites (metadata only) — no imported history, no tracks, no coordinates.
- No public/shared CloudKit database.
- No external server.
- No CKAsset, no CKSubscription.
- Importierte Standort-Historien bleiben lokal.

### 7.4 UI-Hinweise (Phase D)
- Privacy-Card in Favorites-Sync-Section: „Synced through your private iCloud — your imported location history stays on this device. Cloud favorites only carry metadata (date reference + favorite flag), no coordinates."
- Disable-Toggle erklärt: „Turning sync off stops further cloud writes. Local favorites stay. To delete cloud favorites use the dedicated action."

---

## 8. Testplan (für späteren Verifikations-Train / Punkt 10)

In diesem Master-Train **bewusst keine Tests** (User-Direktive „vorerst ohne tests sauber implementieren").

Testplan für späteren Folge-Train:

### 8.1 Unit-Tests
- `FavoriteEntryCodableTests.swift`: round-trip, backward-compatibility (decodeIfPresent für später dazukommende Felder).
- `FavoriteEntryRecordMappingTests.swift`: `FavoriteEntry ↔ CKRecord` ohne Koordinaten, deterministic RecordID.
- `FavoritesOutboxTests.swift`: Persistenz, Retry-Logic, Backoff.
- `FavoritesConflictPolicyTests.swift`: alle 3 Policies × Tombstone-Vorrang.
- `LocalizationKeyAuditTests.swift`: alle `t()`-Keys im `AppGermanTranslations`-Dictionary vorhanden.
- `LocalizationXCStringsParityTests.swift`: `.xcstrings` JSON-Einträge ↔ Dictionary identisch.

### 8.2 Integration-Tests
- `FavoritesCloudSyncServiceMockTests.swift`: Mock-`CKDatabase`, kein realer iCloud-Account-Zwang.
- Pull-then-push-Szenario, Conflict-then-merge-Szenario.

### 8.3 UI-/Build-Tests
- `xcodebuild` build/test iPhone-Sim.
- `xcodebuild` build/test iPad-Sim (Layout-Verifikation).
- iPhone-Device-Test, falls verfügbar.
- Lokales Archive.

### 8.4 Real-CloudKit-Smoke (deferred)
- Manuell mit echtem iCloud-Account auf Device, **nicht automatisierbar** ohne CI-Account.
- Multi-Device-Smoke: Favorit auf iPhone setzen, in iPad-Sim sehen.

### 8.5 Xcode Cloud / TestFlight
- Wenn lokal grün → ASC-API-Trigger via User-Action.
- TestFlight-Smoke per User-Action.

---

## 9. Rollback / Failure Plan

| Failure | Mitigation |
|---|---|
| `.xcstrings`-Anlage bricht Build | Kein Code-Pfad-Change in Phase B nötig — `t()`-Helper unverändert. xcstrings-Datei einfach wieder löschen. |
| 37 hardcoded `Text("…")`-Migrationen brechen Layout | LocalTimeline-Views sind low-traffic; einzelner Revert pro File ohne Cascade. |
| Favoriten-Migration verliert lokale Favoriten | `DayFavoritesStore` bleibt unverändert als Source-of-Truth; `FavoriteEntry` ist additiv. Worst-Case: Sync-Toggle aus, lokale Favoriten unbeschädigt. |
| CloudKit Schema-Promotion vergessen | First-launch nach Production-Build → `CKError.unknownItem` für `FavoriteEntry`-Records. UI zeigt „Sync error: schema not deployed". Kein Crash. User kann ignorieren / Sync aus. |
| `serverRecordChanged`-Conflict-Loop | Backoff + Max-3-Retries; danach UI-Fehler + Outbox-Entry behalten. |
| iPad-Layout bricht in Landscape | `TARGETED_DEVICE_FAMILY` zurück auf `1` setzen; pbxproj-Change ist atomar reversibel. |
| Xcode Cloud rot auf iPad-Sim-Test | Hotfix-Train mit minimaler iPad-Layout-Korrektur. |

**Rollback-Strategie:** Jede Phase ist als eigener Commit geplant (kein All-in-one). `git revert <phase-commit>` ist sauber möglich.

---

## 10. Deferred-Themen (explizit nicht in diesem Master-Train)

- **Vollständiger History-/Track-Sync** über CloudKit — eigener Train, vermutlich mit `NSPersistentCloudKitContainer` und Schema-Migration.
- **CKSubscription für Multi-Device-Push** — Pull-only reicht für Phase 1; Subscription später wenn UX es erfordert.
- **iPad Stage-Manager-Multi-Window** — separater Layout-Train nach iPad-Foundation.
- **Light-Mode-Support** — separate Design-Iteration; aktuell bewusst Force-Dark.
- **Externe Höhen-/DEM-APIs** — bleibt kategorisch ausgeschlossen.
- **Höhenanreicherung importierter Google-History** — Phase 3+ mit user-initiated Enrichment.
- **String Catalog für AppIntents** (Apple-modern via `LocalizedStringResource`-inline) — wenn AppIntents in Phase B Strings haben, dort sauber; sonst Folge-Train.
- **Echte CloudKit-Production-Schema-Promotion** — User-Action im CloudKit-Dashboard nach lokaler Sync-Verifikation.
- **App Review Submission für ≥190** — User-Action nach Cloud-Build + Manual-Smoke.

---

## 11. Phasen-Reihenfolge (Master-Train)

| Phase | Inhalt | Status |
|---|---|---|
| **A** | Diese Spec-Doku | **abgeschlossen** mit diesem Commit |
| **B** | `Package.swift` `defaultLocalization` + AppSupport `Localizable.xcstrings` + LocalTimeline String-Catalog-Basis | **abgeschlossen** |
| **C** | Globales Map-Options-Menü + verstellbare Kartenhöhe compact/expanded | **abgeschlossen** |
| **D** | `FavoriteEntry` Codable + Migration aus `DayFavoritesStore` (lokal) | **offen** |
| **E** | `CloudKitFavoriteEntrySchema` + `FavoritesCloudSyncService` + UI-Toggle + Anti-Claim-Reset im Code | **offen** |
| **F** | `TARGETED_DEVICE_FAMILY = 1,2` + iPad-Sim Layout-Verify | **offen** |
| **G** | Doku-Sync (CHANGELOG/ROADMAP/NEXT_STEPS/ICLOUD_SYNC_ARCHITECTURE/APP_FEATURE_INVENTORY/UI_WIRING_MATRIX/APP_REVIEW_READINESS) | **offen** |
| **H** | `swift build` + `xcodebuild` Sim/iPad/Generic builds — **keine Tests** per User-Direktive | **offen** |
| **I** | Commit + Push direkt auf main | **offen** |

**Freigabe pro Phase einzeln durch User.**

---

## 12. Was diese Spec NICHT behauptet

- ✅ `.xcstrings` ist angelegt — **JA**, AppSupport `Localizable.xcstrings` seit Phase B.
- ❌ FavoriteEntry-Code existiert — **NEIN** (Phase D/E).
- ❌ CloudKit-Records werden bereits geschrieben — **NEIN** (Phase E).
- ❌ iPad-Support ist aktiviert — **NEIN** (Phase F).
- ❌ Tests sind durchgelaufen — **NEIN, per User-Direktive für diesen Master-Train deferred**.
- ❌ App Review für ≥190 ist eingereicht — **NEIN, weiterhin User-Action**.
- ❌ Neuer Cloud-Build > 190 verfügbar — **NEIN, letzter Stand bleibt 190 auf `b25c27d`**.

---

**Phase A abgeschlossen.** Phasen B–H stehen aus.
