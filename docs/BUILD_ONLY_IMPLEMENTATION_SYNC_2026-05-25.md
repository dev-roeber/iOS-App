# Build-only Implementation Sync — 2026-05-25

**HEAD geprüft:** `7009a0b` · **Vorher-Stand:** `bf0b6dc` · **Trains:** F.4 → F.2 → F.3 → UI-Adoption I → Export UX I → Import UX I → Map/Timeline/Heatmap UX I → Insights Refactor I.

Dieser Sync-Block schließt die build-only-Phase ab. **Punkt 10 — vollständige Tests** ist der einzige verbleibende Schritt vor jeder neuen Apple-Verifikation.

## 1. Train-Übersicht (chronologisch, alle build-only)

| Commit | Train | Was gebaut wurde | Tests in diesem Train |
|---|---|---|---|
| `627ca41` | **F.4** sichtbare iCloud-/SyncStatusCard | `AppICloudOptionsView.swift` neu mit `LHXSyncStatusCard` gegen `CloudSyncServiceFactory.makeProductionService`; sectionLink „iCloud" in `AppOptionsView` zwischen Privacy und Technical | ⏸️ deferred |
| `fe2809b` | **F.2** CloudKit Private-Metadata-Schema | `CloudKitLiveTrackMetadataSchema.swift` neu (Value-Type + `LiveTrackMetadataSchema`-Descriptor, 8 Felder ohne Koordinaten, `recordType = "LiveTrackMeta"`, `schemaVersion = 1`); `PrivacyInfo.xcprivacy` um `NSPrivacyAccessedAPICategoryFileTimestamp` Reason `0A2A.1` erweitert | ⏸️ deferred |
| `31c75c0` | **F.3** user-initiierter iCloud-Drive-/Files-Export-Hint | `AppExportView.exportTargetCard` zeigt `Suggest iCloud Drive`-Hinweis bei aktiver Preference; `AppICloudOptionsView.iCloudDriveExportHintCard` mit `Toggle($preferences.preferCloudDriveExport)`; bestehender `fileExporter`-Flow unverändert; **keine** Entitlement-Änderung | ⏸️ deferred |
| `ba41234` | **UI-Adoption I** LHX* in drei Kern-Screens | `AppExportView.emptyState` → `LHXEmptyState`; `AppInsightsContentView.insightsFullEmptyState` → `LHXEmptyState` (mit neuem `primaryActionAccessibilityIdentifier`-Parameter, der `insights.empty.resetFilter` erhält); `AppICloudOptionsView` Privacy-Footer → `LHXInfoCard` | ⏸️ deferred |
| `627a2df` | **Export UX I** Privacy-Hinweis + Filename-Accessibility | `AppExportView.selectionSummaryCard` Filename-Vorschau mit `doc.text`-Icon + VoiceOver-Label „Suggested filename"; neuer Privacy-Hinweis `export.selection.privacyHint`; `export.preview.emptySelection`-Identifier | ⏸️ deferred |
| `574d347` | **Import UX I** Home-Screen-Accessibility + Privacy | Home-Screen `emptyStateView` bekommt `home.title`/`home.subtitle`/`home.subtitle.formats`/`home.openFile`/`home.loadDemo`/`home.clearError`-Identifier, `accessibilityHint`s, 44 pt Hit-Targets, neue Format-Footnote; Overview-Empty bekommt `overview.empty.body` + `overview.empty.privacyHint` mit `lock.shield`-Icon | ⏸️ deferred |
| `21edb68` | **Map/Timeline/Heatmap UX I** | `AppHeatmapView` Overlays bekommen `heatmap.layerMenu`/`heatmap.computing`/`heatmap.statsBadge`-Identifier + VoiceOver-Label/Computed-Property `statsAccessibilityLabel`; `AppDayDetailView.dayHeroFilterPanel` Route-Display-Picker bekommt `dayDetail.routeDisplay`-Identifier | ⏸️ deferred |
| `7009a0b` | **Insights Refactor I** | Neue Datei `InsightsStreakCardView.swift` (`struct InsightsStreakCardView: View`, 49 LOC, pure Presentation); Dead-Code `pageEmptyState` (17 LOC, 0 Aufrufer) entfernt; `streakSection` Call-Sites bekommen `insights.streak.recent`/`insights.streak.best`-Identifier | ⏸️ deferred |

## 2. Repo-Truth-Abgleich (direkt per `rg` verifiziert)

| Claim | Verifiziert |
|---|---|
| `wrapper/LH2GPXWrapper/LH2GPXWrapper.entitlements` enthält `com.apple.developer.icloud-container-identifiers = [iCloud.de.roeber.LH2GPXWrapper]` + `com.apple.developer.icloud-services = [CloudKit]` | ✅ |
| `Sources/.../AppICloudOptionsView.swift` enthält `LHXSyncStatusCard` | ✅ |
| `Sources/.../CloudKitLiveTrackMetadataSchema.swift` enthält `recordType = "LiveTrackMeta"` + `currentSchemaVersion = 1` + 8 Felder | ✅ |
| `wrapper/LH2GPXWrapper/PrivacyInfo.xcprivacy` enthält `NSPrivacyAccessedAPICategoryFileTimestamp` + `0A2A.1` | ✅ |
| `AppExportView.exportTargetCard` referenziert `preferences.preferCloudDriveExport`; `AppICloudOptionsView` hat `iCloudDriveExportHintCard`-Toggle | ✅ |
| `AppExportView.emptyState` und `AppInsightsContentView.insightsFullEmptyState` nutzen `LHXEmptyState`; `AppICloudOptionsView` nutzt `LHXInfoCard` | ✅ |
| `AppExportView` enthält `export.selection.privacyHint` | ✅ |
| `wrapper/.../ContentView.swift` enthält `home.openFile`/`home.loadDemo`/`home.subtitle.formats`; `AppContentSplitView.swift` enthält `overview.empty.privacyHint` | ✅ |
| `AppHeatmapView.swift` enthält `heatmap.layerMenu`/`heatmap.computing`/`heatmap.statsBadge`; `AppDayDetailView.swift` enthält `dayDetail.routeDisplay` | ✅ |
| `InsightsStreakCardView.swift` existiert; `AppInsightsContentView.swift` hat **kein** `pageEmptyState` und **kein** `private func streakCard(...)`, nutzt stattdessen `InsightsStreakCardView` | ✅ |

## 3. Must-be-absent Sweeps (alle Sources + wrapper)

| Pattern | Treffer | Status |
|---|---|---|
| `publicCloudDatabase` | 0 (außer Anti-Claim-Doku) | ✅ |
| `sharedCloudDatabase` | 0 (außer Anti-Claim-Doku) | ✅ |
| `CKSubscription` | 0 | ✅ |
| `CKAsset` | 0 | ✅ |
| `CKQuery` | 0 | ✅ |
| `.save(`/`.fetch(` in `CloudKit*.swift` | 0 | ✅ |
| Positive Behauptung „history.sync"/„automatic.sync"/„Cloud Backup aktiv"/„Sync aktiv" (ohne Negation) | 0 | ✅ |

Die 3 Treffer für `delete*` sind: (1) Doc-Kommentar in `CloudKitLiveTrackMetadataSchema.swift:57` der explizit sagt, dass save/fetch/delete/modifyRecords **nicht** aufgerufen werden, (2) `LiveLocationFeatureModel.deleteRecordedTrack(id:)` ist lokaler UUID-Delete für gespeicherte Live-Tracks (kein CloudKit), (3) Aufruf desselben in `AppRecordedTrackEditorView`.

## 4. Privacy-Manifest gegen Code-Realität

| Manifest-Eintrag | Code-Beleg | Bewertung |
|---|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` Reason `CA92.1` | `AppPreferences`, `WidgetDataStore`, `LocalTimelineTechnicalTestSettings` — alle nutzen `UserDefaults.standard` für app-eigene Settings | ✅ korrekt |
| `NSPrivacyAccessedAPICategoryFileTimestamp` Reason `0A2A.1` | `AppContentLoader.swift:433/721/752` + `GoogleTimelineStoreImporter.swift:61-62` rufen `FileManager.attributesOfItem(atPath:)` gegen User-File-Picker-Dateien (`.size`-Read) | ✅ korrekt (F.2-Erweiterung) |
| `NSPrivacyCollectedDataTypePreciseLocation` (Linked=false, Tracking=false, Purpose=AppFunctionality) | Optionaler Live-Upload an user-konfigurierten HTTPS-Endpoint, default `false` (`AppPreferences.sendsLiveLocationToServer = false`) | ✅ korrekt |
| `NSPrivacyTracking = false`, `NSPrivacyTrackingDomains = []` | Keine Tracking-Calls im Code, keine Werbung | ✅ korrekt |
| **Reine Schema-Definition F.2** (CKRecord ohne save/fetch) | Apple: nutzerinitiierter Export der eigenen Daten ≠ Data Collection; reine Schema-Definition ohne Write zählt nicht als Sammlung — kein neuer `NSPrivacyCollectedDataType` nötig | ✅ korrekt |

## 5. iCloud-Doku-Trennung (F.1/F.2/F.3/F.4)

| Train | Was wird behauptet | Was wird **explizit nicht** behauptet |
|---|---|---|
| F.1 | Entitlement-Keys gesetzt; `iCloud.de.roeber.LH2GPXWrapper`-Container im Apple Developer Portal registriert; Cloud-Distribution-Signing-Pass via Xcode Cloud Build 190 | Keine Records geschrieben/gelesen; kein Sync |
| F.2 | `LiveTrackMeta`-Schema (Datenform-Definition) + `PrivacyInfo`-Erweiterung; reines `CKRecord`-Mapping ohne save/fetch | Keine Records werden tatsächlich angelegt; keine Koordinaten/Polylines/Place-IDs im Schema |
| F.3 | UI-Hint im Export-Sheet (Toggle + Hinweis-Label); bestehender `fileExporter`-Flow unverändert | Kein automatischer Upload; keine iCloud-Documents-Capability ergänzt; System-Save-Sheet entscheidet weiterhin |
| F.4 | Settings → iCloud zeigt `LHXSyncStatusCard` gegen `CloudSyncService.status`; einzelner `CKContainer.accountStatus()`-Call bei Toggle/Refresh | Kein Sync, keine Records, keine Subscriptions, keine Assets, keine Public/shared DB, keine Historien-Synchronisation |

## 6. UI-Adoption (LHX*) — keine toten Aktionen

`LHXSyncStatusCard` (F.4 in `AppICloudOptionsView`), `LHXEmptyState` (UI-Adoption I in `AppExportView.emptyState` + `AppInsightsContentView.insightsFullEmptyState`), `LHXInfoCard` (UI-Adoption I in `AppICloudOptionsView` Privacy-Footer). Alle CTAs feuern denselben Closure wie vorher (`selectAll(from:)`, `rangeFilter = .default`, `preferences.iCloudSyncEnabled.toggle()`, `preferences.preferCloudDriveExport`-Bind). `LHXEmptyState` zusätzlich additiv um `primaryActionAccessibilityIdentifier`-Parameter erweitert (Default `nil`, kein API-Bruch).

## 7. Build-only Validierung (in diesem Sync)

- `swift build` ✅ 0E/1W (pre-existing F.1 Swift-6-Concurrency-Warning in `CloudKitCloudSyncService.swift:48`, `defaultContainerIdentifier` MainActor-Isoliert — wurde dokumentiert, nicht aus diesen Trains).
- `xcodebuild -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build` ✅ BUILD SUCCEEDED.
- `xcodebuild -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build` ✅ BUILD SUCCEEDED.

## 8. Pflicht-Anti-Claims (unverändert wahr nach allen Trains)

- ❌ Echter iCloud-Sync implementiert.
- ❌ Automatischer Upload aus Import oder Export.
- ❌ CloudKit Records werden tatsächlich geschrieben/gelesen.
- ❌ Historien-Synchronisation aktiv.
- ❌ Public / shared Database genutzt.
- ❌ CKSubscription / CKAsset / CKQuery genutzt.
- ❌ iPad-Layout aktiviert (`TARGETED_DEVICE_FAMILY = 1`).
- ❌ Light Mode unterstützt (`UIUserInterfaceStyle` undeklariert / Force-Dark).
- ❌ Neuer Xcode-Cloud-Build / TestFlight-Build verfügbar — letzter extern grüner Stand bleibt **190** auf `b25c27d`.
- ❌ App Review für 1.0.2 (190) bestanden / eingereicht.

## 9. Apple-Doku-Referenz (kompakt nach Topic)

**CloudKit** — `CKContainer`/`privateCloudDatabase`/`publicCloudDatabase`/`sharedCloudDatabase`/`CKRecord`/`CKRecord.RecordType`/`CKAccountStatus`/Encrypting User Data
**File I/O** — `SwiftUI.View.fileImporter`/`fileExporter`/`FileDocument`/`ReferenceFileDocument`/`UIDocumentPickerViewController`/`UIDocumentPickerDelegate`/`UniformTypeIdentifiers.UTType`/`NSFileCoordinator`/`URL.startAccessingSecurityScopedResource()`
**Privacy** — Privacy Manifest Files, Describing data use in privacy manifests, Describing use of required reason API, App Privacy Details, User Privacy and Data Use
**HIG** — Layout · Buttons · Settings · Maps · Feedback · Accessibility · Privacy · Lists and Tables · SF Symbols · Loading · File Management
**App Store Review Guidelines** — Privacy (§5.1), Data Collection and Storage (§5.1.1), Data Use and Sharing (§5.1.2), Location (Privacy section)

## 10. Nächster Schritt

**Punkt 10 — vollständige automatisierte Tests & Cloud-Verifikation:**
- `swift test` (Mac-Host, Linux-Host)
- `xcodebuild test -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,…'`
- UITests Simulator + Device (iPhone 15 Pro Max iOS 26.4, alle bisherigen Identifier inkl. der neuen aus diesen Trains)
- Manueller iPhone-Smoke
- Xcode Cloud Workflow `Release – Archive & TestFlight` triggern → Build > 190 erwartet
- TestFlight-Smoke voll (Overview/Import/Demo/Tage/Karte/Heatmap/Insights/Export/Live/Settings, Settings → iCloud-Block-Sichtprüfung)
- Hardware-Smoke gegen echten iCloud-Login (F.2 hat das Schema vorbereitet — F.x-Train für tatsächliche Records-Writes wäre der nächste Implementations-Train **nach** Punkt 10)
