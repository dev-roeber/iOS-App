# Build-only Full-App-Modernization Sync — 2026-05-25 (Train 8.15)

**HEAD geprüft:** `bd99bf0` · **Vorher-Stand:** `bf0b6dc` · **Range:** `bf0b6dc..bd99bf0` (24 Commits).

Dieser finale Sync-Block schließt die build-only-Phase **8.0–8.14** komplett ab. **Punkt 10 — vollständige Tests + Xcode Cloud + TestFlight** ist der einzige verbleibende Schritt vor jeder neuen App-Store-Verifikation.

## 1. Train-Übersicht (chronologisch, alle build-only)

| Commit | Train | Was gebaut wurde | Tests |
|---|---|---|---|
| `627ca41` | **F.4** | sichtbare iCloud-/SyncStatusCard in Settings | ⏸️ deferred |
| `fe2809b` | **F.2** | CloudKit Private-Metadata-Schema (`LiveTrackMeta`) + PrivacyInfo `FileTimestamp 0A2A.1` | ⏸️ deferred |
| `31c75c0` | **F.3** | user-initiierter iCloud-Drive-Hint im Export | ⏸️ deferred |
| `ba41234` | **UI-Adoption I** | LHX* in Export/Insights/iCloud | ⏸️ deferred |
| `627a2df` | **Export UX I** | Privacy-Hinweis + Filename-Accessibility | ⏸️ deferred |
| `574d347` | **Import UX I** | Home-Screen-Accessibility + Privacy | ⏸️ deferred |
| `21edb68` | **Map/Timeline/Heatmap UX I** | Layer/Stats/Computing/Route-Display Identifier | ⏸️ deferred |
| `7009a0b` | **Insights Refactor I** | `InsightsStreakCardView` extrahiert | ⏸️ deferred |
| `0276ea2` | **Build-only Sync** | erster Sync-Report | ⏸️ deferred |
| `66de66a` | **8.0** Repo-Truth-Lock | `dev-roeber/iOS-App` als einziges aktives Repo | ⏸️ deferred |
| `5f6c739` | **8.1** Wiring Audit | `docs/UI_WIRING_MATRIX_2026-05-25.md` + Dead-Hint-Fix | ⏸️ deferred |
| `9aa4eaf` | **8.2** Settings Privacy Center | LHXInfoCard-Top-Banner + 2 neue Privacy-Rows | ⏸️ deferred |
| `edf017a` | **8.3** App Intents Skeleton | 3 Intents + AppShortcutsProvider | ⏸️ deferred |
| `c99f90c` | **8.4** Perf/Concurrency | **138 → 0 Build-Warnings** (nonisolated + Archive throwing) | ⏸️ deferred |
| `a8f41e2` | **8.5** A11y / Dynamic Type | Settings-Clamp + Hero-Icon hidden | ⏸️ deferred |
| `6de5a9c` | **8.6** Map Layer Identifier | 3 MapLayerMenu-Identifier + Hints | ⏸️ deferred |
| `b45d86d` | **8.7** Error Alert Identifier | 4 Alert-Button-Identifier + Log-Privacy-Review | ⏸️ deferred |
| `07e8473` | **8.8** Import-Pipeline Confirm | Doku-Confirm-Train (Pipeline bereits robust) | ⏸️ deferred |
| `95c43ee` | **8.9** Export-Pipeline UX | per-Format Identifier + Destination-Hint | ⏸️ deferred |
| `e8bc835` | **8.10** Live/Upload Control Center | Upload-Card 4 Hints + Status-Identifier | ⏸️ deferred |
| `3770f8c` | **8.11** Timeline/Days/DayDetail | routeDisplay+timeline Hints + 2. Picker Identifier | ⏸️ deferred |
| `9580ec9` | **8.12** Heatmap/Insights/Stats | Heatmap-Hints + KPI-Grid-Hint | ⏸️ deferred |
| `c9f06b2` | **8.13** Widget/Dynamic-Island | Doc-Confirm (bereits konsistent + privacy-safe) | ⏸️ deferred |
| `bd99bf0` | **8.14** App Store/Privacy Review | `docs/APP_REVIEW_READINESS_2026-05-25.md` | ⏸️ deferred |
| *(folgt)* | **8.15** Final Consolidation | dieser Report | ⏸️ deferred |

## 2. Build-only Validierung (kontinuierlich grün)

| Phase | swift build | xcodebuild Sim | xcodebuild generic iOS |
|---|---|---|---|
| F.4–Insights Refactor I | ✅ 0E/1W (pre-8.4) | ✅ | ✅ |
| 8.0–8.3 | ✅ 0E/1W | ✅ | ✅ |
| **8.4 (Warning-Fix)** | ✅ **0E/0W** ab hier | ✅ | ✅ |
| 8.5–8.14 | ✅ 0E/0W | ✅ | ✅ |

## 3. Repo-Truth-Abgleich

| Claim | Verifiziert |
|---|---|
| Entitlements `icloud-container-identifiers = [iCloud.de.roeber.LH2GPXWrapper]` + `icloud-services = [CloudKit]` | ✅ |
| `CloudKitLiveTrackMetadataSchema.swift` mit `recordType = "LiveTrackMeta"`, `schemaVersion = 1`, 8 Felder ohne Koordinaten | ✅ |
| `PrivacyInfo.xcprivacy` mit `UserDefaults CA92.1` + `FileTimestamp 0A2A.1` + `PreciseLocation` (Linked=false, Tracking=false, AppFunctionality) | ✅ + `plutil -lint OK` |
| `AppICloudOptionsView.swift` mit `LHXSyncStatusCard` + `iCloudDriveExportHintCard` | ✅ |
| `AppExportView.swift` mit Format-Pill-Identifier + Destination-Card-Hint (8.9) | ✅ |
| `LHOptionsComponents.swift` mit 4 Upload-Hints + `options.upload.statusRow` (8.10) | ✅ |
| `AppDayDetailView.swift` mit 2 Picker-Hints + `dayDetail.routeDisplay.control` (8.11) | ✅ |
| `AppHeatmapView.swift` + `AppInsightsContentView.swift` mit Stats-Badge-Hint + Computing-Value + KPI-Grid-Hint (8.12) | ✅ |
| `LH2GPXAppIntents.swift` mit 3 daten-freien Intents + `AppShortcutsProvider` (8.3) | ✅ |
| `docs/UI_WIRING_MATRIX_2026-05-25.md` mit 33 Days/DayDetail-Identifier (8.1+8.11) | ✅ |
| `docs/APP_REVIEW_READINESS_2026-05-25.md` mit PrivacyInfo-Audit + Reviewer-Notes-Vorschlag (8.14) | ✅ |

## 4. Must-be-absent Sweeps (alle `Sources/` + `wrapper/`)

| Pattern | Treffer | Status |
|---|---|---|
| `publicCloudDatabase` | 0 (außer Anti-Claim-Doku) | ✅ |
| `sharedCloudDatabase` | 0 (außer Anti-Claim-Doku) | ✅ |
| `CKSubscription` / `CKAsset` / `CKQuery` | 0 | ✅ |
| `.save(` / `.fetch(` / `deleteRecord` / `modifyRecords` in `CloudKit*.swift` | 0 (1 Doku-Kommentar: „no save/fetch/perform/delete/modifyRecords") | ✅ |
| Positive Sync-/Test-/Submission-Claims (`fully tested`, `App Store accepted`, `iCloud.*implemented`, …) | 1 Treffer in altem Verification-Doc (`FULL_APP_REDESIGN_ICLOUD_INTEGRATION_VERIFICATION_2026-05-22.md:65`) — **rg-Pattern-Beleg**, kein Claim | ✅ |
| `Bearer`/`Token`/`Authorization`/`API-Key`/`Secret`/`TEAM_ID` in Logs | 0 | ✅ |
| `coming soon`/`dummy`/`not implemented`/`fatalError`/`preconditionFailure` (außer kontrollierten Bestandskommentaren) | 0 neu seit `bf0b6dc` | ✅ |

## 5. Privacy-Manifest gegen Code-Realität

| Manifest-Eintrag | Code-Beleg | Bewertung |
|---|---|---|
| `NSPrivacyTracking = false` + `NSPrivacyTrackingDomains = []` | Keine Tracking-/Analytics-Calls | ✅ |
| `NSPrivacyCollectedDataTypePreciseLocation` (Linked=false, Tracking=false, AppFunctionality) | Optionaler `LiveLocationServerUploader` an user-konfigurierten HTTPS-Endpoint, Default off | ✅ |
| `NSPrivacyAccessedAPICategoryUserDefaults` Reason `CA92.1` | `AppPreferences`/`WidgetDataStore`/`LocalTimelineTechnicalTestSettings` | ✅ |
| `NSPrivacyAccessedAPICategoryFileTimestamp` Reason `0A2A.1` | `AppContentLoader.swift` (3 Sites) + `GoogleTimelineStoreImporter.swift` (1 Site), `.size`-Reads gegen user-picker-Dateien | ✅ |

## 6. App Intents (8.3)

| Intent | Datenfluss |
|---|---|
| `OpenLH2GPXAppIntent` | Öffnet App (kein Parameter, kein Datenrückgabe) |
| `OpenLH2GPXImportIntent` | Öffnet App (Navigation auf Import deferred bis Punkt-10-Phase) |
| `OpenLH2GPXSettingsIntent` | Öffnet App (Navigation auf Settings deferred) |
| `LH2GPXAppShortcuts: AppShortcutsProvider` | Listet die 3 Intents für Shortcuts-App |

**Kein** Datenparameter, **keine** Foto-/Standort-/Health-Permission, **keine** dynamische Datenrückgabe.

## 7. UI-Wiring (8.1 + 8.6 + 8.7 + 8.9 + 8.10 + 8.11 + 8.12)

- **Days/DayDetail:** 33 Identifier (`docs/UI_WIRING_MATRIX_2026-05-25.md` + 8.11-Addition).
- **Export:** Format-Card + 5 Format-Pills (per-Extension) + Selection-Filename-Privacy + Target-Card + Save-or-Share-Title (8.9).
- **Live/Upload:** Toggle/URL/Token/Status mit 4 Hints + `options.upload.statusRow` (8.10).
- **Heatmap/Insights:** Stats-Badge-Hint + Computing-Value + KPI-Grid-Hint (8.12).
- **Settings:** Top-Banner Privacy + 9 sectionLinks (8.2 + Bestand).
- **MapLayerMenu:** 3 Identifier + Hints (8.6).
- **Alerts:** 4 Alert-Button-Identifier (8.7).
- **Widget/Dynamic-Island:** keine UI-Änderung (8.13 = Doc-Confirm), Status-Begriffe konsistent.

## 8. Pflicht-Anti-Claims (unverändert wahr nach 8.0–8.14)

- ❌ Echter iCloud-Sync implementiert
- ❌ Automatischer Upload aus Import oder Export
- ❌ CloudKit Records save/fetch
- ❌ Historien-Synchronisation aktiv
- ❌ Public / shared Database genutzt
- ❌ CKSubscription / CKAsset / CKQuery genutzt
- ❌ iPad-Layout aktiviert
- ❌ Light Mode unterstützt
- ❌ Neuer Xcode-Cloud-Build / TestFlight-Build verfügbar — letzter extern grüner Stand bleibt **190** auf `b25c27d`
- ❌ App Review für 1.0.2 (190) bestanden / eingereicht
- ❌ Bearer-Token in Klartext-Logs
- ❌ Koordinaten auf glanceable Surfaces (Widget/Live-Activity/Dynamic-Island)
- ❌ Backwards-incompatible Schema-Migration (alle `Codable`-Decoder defensiv mit `decodeIfPresent`)

## 9. Punkt-10-Testplan

| # | Schritt |
|---|---|
| 1 | `swift test` (Mac-Host + Linux-Host für Cross-Plattform-Decoder/Presentation/CloudKit-Gate-Tests) |
| 2 | `xcodebuild test -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'` |
| 3 | UITests Simulator: alle neuen Identifier aus 8.6/8.9/8.10/8.11/8.12 (`export.format.pill.*`, `export.target.saveOrShare.title`, `options.upload.statusRow`, `dayDetail.routeDisplay.control`, plus Bestand) |
| 4 | UITests Device (iPhone 15 Pro Max iOS 26.4, UDID `00008130-00163D0A0461401C`) |
| 5 | Manueller iPhone-Smoke aller Hauptbereiche |
| 6 | Lokales Archive: `xcodebuild ... archive` |
| 7 | Xcode Cloud Workflow `Release – Archive & TestFlight` triggern → Build > 190 erwartet |
| 8 | TestFlight-Smoke voll (Overview/Import/Demo/Tage/Karte/Heatmap/Insights/Export/Live/Settings inkl. Settings → iCloud-Block-Sichtprüfung) |
| 9 | Hardware-Smoke gegen echten iCloud-Login (F.2-Schema vorbereitet — `LiveTrackMeta` write-Train erst nach Punkt 10) |

## 10. Offene Risiken nach 8.0–8.14

| Risiko | Mitigation |
|---|---|
| Tests stehen aus | Punkt 10 |
| iPad/Light Mode offen | bewusst nicht in Scope 8.x |
| Kein Cloud-Build > 190 | Punkt 10 erzeugt nächsten |
| App Review für ≥190 noch nicht durchlaufen | nach Punkt 10 Submission-Entscheidung |
| F.2-Schema noch nicht beschrieben (kein Records-Write) | bewusst — eigener Implementations-Train nach Punkt 10 |

## 11. Nächster Schritt

**Punkt 10 — Vollständige Tests / Xcode Cloud / TestFlight** (Test-Trains nun erlaubt + Pflicht).
